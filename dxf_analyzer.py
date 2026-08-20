import json
import math
import os
import sys

import ezdxf

from ezdxf import path as ezpath
from ezdxf.disassemble import recursive_decompose


# ============================================================
# CONFIGURATION
# ============================================================

# Curve flattening quality, relative to model size.
FLATTEN_RATIO = 0.0004
FLATTEN_MIN = 0.01
FLATTEN_MAX = 0.5

# Endpoint snapping tolerance when stitching separate LINE/ARC
# entities back into one contour, relative to model size.
JOIN_RATIO = 0.00002
JOIN_MIN = 0.01

# A closed inner contour counts as a round hole when its radius
# varies by less than this fraction around its centroid.
ROUNDNESS_TOLERANCE = 0.02

# DXF unit handling.
#
# Sheet-metal DXF is millimetres by convention, and the $INSUNITS
# header is frequently absent or simply wrong: CAD tools will
# happily declare "metres" for a 300 mm part, and trusting that
# blindly inflates every dimension by 1000. Only an explicit inch
# declaration is honoured, being the one alternative that really
# occurs in this trade.
INCH_UNIT_CODE = 1

MM_PER_INCH = 25.4

UNIT_NAME = {
    0: "unitless",
    1: "in",
    2: "ft",
    4: "mm",
    5: "cm",
    6: "m"
}


# ============================================================
# GEOMETRY HELPERS
# ============================================================

def polyline_length(points):

    total = 0.0

    for i in range(len(points) - 1):

        dx = points[i + 1][0] - points[i][0]
        dy = points[i + 1][1] - points[i][1]

        total += math.hypot(dx, dy)

    return total


def polygon_area(points):
    """Absolute shoelace area of a closed point ring."""

    total = 0.0

    for i in range(len(points) - 1):

        x1, y1 = points[i]
        x2, y2 = points[i + 1]

        total += x1 * y2 - x2 * y1

    return abs(total) / 2.0


def point_in_polygon(point, polygon):

    x, y = point

    inside = False

    for i in range(len(polygon) - 1):

        x1, y1 = polygon[i]
        x2, y2 = polygon[i + 1]

        if (y1 > y) != (y2 > y):

            t = (y - y1) / (y2 - y1)

            if x < x1 + t * (x2 - x1):
                inside = not inside

    return inside


def centroid(points):

    xs = [p[0] for p in points[:-1]]
    ys = [p[1] for p in points[:-1]]

    if not xs:
        return 0.0, 0.0

    return sum(xs) / len(xs), sum(ys) / len(ys)


def is_round(points):
    """Returns the radius when the ring is near-circular, else None."""

    if len(points) < 8:
        return None

    cx, cy = centroid(points)

    radii = [
        math.hypot(p[0] - cx, p[1] - cy)
        for p in points[:-1]
    ]

    r_min = min(radii)
    r_max = max(radii)

    if r_max <= 0:
        return None

    if (r_max - r_min) / r_max > ROUNDNESS_TOLERANCE:
        return None

    return sum(radii) / len(radii)


# ============================================================
# LOADING
# ============================================================

def read_document(dxf_file):

    try:
        return ezdxf.readfile(dxf_file)

    except Exception:

        # Damaged or non-standard files often still recover.
        from ezdxf import recover

        doc, _ = recover.readfile(dxf_file)

        return doc


def get_unit_scale(doc):
    """Returns (scale to mm, working unit, declared unit)."""

    try:
        code = int(doc.header.get("$INSUNITS", 0))
    except Exception:
        code = 0

    declared = UNIT_NAME.get(code, f"code {code}")

    if code == INCH_UNIT_CODE:
        return MM_PER_INCH, "in", declared

    return 1.0, "mm", declared


def collect_geometry(doc, scale):
    """Flattens every drawable entity into a scaled polyline."""

    msp = doc.modelspace()

    entity_counts = {}
    skipped = {}

    raw = []

    for entity in recursive_decompose(msp):

        kind = entity.dxftype()

        try:
            p = ezpath.make_path(entity)

        except Exception:
            skipped[kind] = skipped.get(kind, 0) + 1
            continue

        raw.append((kind, entity, p))

        entity_counts[kind] = entity_counts.get(kind, 0) + 1

    if not raw:
        return [], entity_counts, skipped

    # Model size from control points, so curve flattening can be
    # scaled to the drawing instead of a fixed guess.
    xs = []
    ys = []

    for _, _, p in raw:

        for v in p.control_vertices():
            xs.append(v.x)
            ys.append(v.y)

    if not xs:
        diagonal = 100.0
    else:
        diagonal = math.hypot(
            max(xs) - min(xs),
            max(ys) - min(ys)
        ) * scale

    distance = min(
        FLATTEN_MAX,
        max(FLATTEN_MIN, diagonal * FLATTEN_RATIO)
    ) / max(scale, 1e-9)

    shapes = []

    for kind, entity, p in raw:

        try:
            points = [
                (v.x * scale, v.y * scale)
                for v in p.flattening(distance)
            ]
        except Exception:
            skipped[kind] = skipped.get(kind, 0) + 1
            continue

        if len(points) < 2:
            continue

        shapes.append({
            "type": kind,
            "entity": entity,
            "points": points,
            "closed": bool(p.is_closed)
        })

    return shapes, entity_counts, skipped


# ============================================================
# CONTOUR STITCHING
# ============================================================

def stitch_open_shapes(shapes, tolerance):
    """Joins open segments that share endpoints into single chains.

    CAD exports routinely split one contour into separate LINE and
    ARC entities, so an unstitched drawing reports far too many
    contours and pierces.
    """

    open_shapes = [s for s in shapes if not s["closed"]]

    if not open_shapes:
        return []

    def key(point):
        return (
            int(round(point[0] / tolerance)),
            int(round(point[1] / tolerance))
        )

    # Endpoint index, with neighbour buckets to survive rounding
    # right on a cell boundary.
    buckets = {}

    for index, shape in enumerate(open_shapes):

        for point in (shape["points"][0], shape["points"][-1]):

            buckets.setdefault(key(point), set()).add(index)

    def candidates(point):

        kx, ky = key(point)

        found = set()

        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                found |= buckets.get((kx + dx, ky + dy), set())

        return found

    def close_enough(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1]) <= tolerance

    used = set()

    chains = []

    for start in range(len(open_shapes)):

        if start in used:
            continue

        used.add(start)

        points = list(open_shapes[start]["points"])

        # Extend from the tail, then from the head.
        for reverse in (False, True):

            if reverse:
                points.reverse()

            extended = True

            while extended:

                extended = False

                for index in candidates(points[-1]):

                    if index in used:
                        continue

                    other = open_shapes[index]["points"]

                    if close_enough(points[-1], other[0]):
                        points.extend(other[1:])

                    elif close_enough(points[-1], other[-1]):
                        points.extend(list(reversed(other))[1:])

                    else:
                        continue

                    used.add(index)
                    extended = True
                    break

        closed = (
            len(points) > 3
            and close_enough(points[0], points[-1])
        )

        if closed:
            points[-1] = points[0]

        chains.append({
            "points": points,
            "closed": closed
        })

    return chains


# ============================================================
# CONTOURS
# ============================================================

def load_contours(dxf_file):
    """Reads a DXF into classified contours.

    Shared by the analyzer and the renderer so that both agree on
    what a contour is, which ones are outer, and where the holes
    sit.
    """

    doc = read_document(dxf_file)

    scale, unit_name, declared_unit = get_unit_scale(doc)

    shapes, entity_counts, skipped = collect_geometry(doc, scale)

    data = {
        "scale": scale,
        "units": unit_name,
        "units_declared": declared_unit,
        "entity_counts": entity_counts,
        "skipped": skipped,
        "bbox": None,
        "contours": []
    }

    if not shapes:
        return data

    # --------------------------------------------------------
    # Bounding box
    # --------------------------------------------------------

    xs = []
    ys = []

    for shape in shapes:
        for x, y in shape["points"]:
            xs.append(x)
            ys.append(y)

    data["bbox"] = (
        min(xs),
        min(ys),
        max(xs),
        max(ys)
    )

    diagonal = math.hypot(
        max(xs) - min(xs),
        max(ys) - min(ys)
    )

    tolerance = max(JOIN_MIN, diagonal * JOIN_RATIO)

    # --------------------------------------------------------
    # Build contours
    # --------------------------------------------------------

    contours = []

    for shape in shapes:

        if not shape["closed"]:
            continue

        points = list(shape["points"])

        if points[0] != points[-1]:
            points.append(points[0])

        contours.append({
            "points": points,
            "closed": True,
            "inner": False,
            "is_hole": False,
            "hole_index": 0,
            "type": shape["type"],
            "entity": shape["entity"]
        })

    for chain in stitch_open_shapes(shapes, tolerance):

        contours.append({
            "points": chain["points"],
            "closed": chain["closed"],
            "inner": False,
            "is_hole": False,
            "hole_index": 0,
            "type": "CHAIN",
            "entity": None
        })

    # --------------------------------------------------------
    # Outer / inner classification
    # --------------------------------------------------------

    closed_contours = [c for c in contours if c["closed"]]

    for contour in closed_contours:
        contour["area"] = polygon_area(contour["points"])

    ranked = sorted(
        closed_contours,
        key=lambda c: -c["area"]
    )

    for i, contour in enumerate(ranked):

        probe = contour["points"][0]

        # Only a larger contour can contain this one.
        for bigger in ranked[:i]:

            if point_in_polygon(probe, bigger["points"]):
                contour["inner"] = True
                break

    data["contours"] = contours

    return data


def find_holes(contours, scale):
    """Round inner contours, reported as diameter and centre.

    Also tags the contours themselves with is_hole/hole_index so
    the renderer can outline exactly what the report counted.
    """

    found = []

    for contour in contours:

        if not contour["closed"] or not contour["inner"]:
            continue

        diameter = None
        center = None

        entity = contour.get("entity")

        if entity is not None and contour["type"] == "CIRCLE":

            # Measured off the flattened path, not read off the
            # entity. A block inserted mirrored transforms the
            # geometry and leaves dxf.center pointing at where the
            # circle would have been unmirrored, which put a dozen
            # holes of one part outside its own outline.
            measured = is_round(contour["points"])

            declared = entity.dxf.radius * scale

            # The declared radius is the exact one and survives a
            # mirror; a block scaled on insertion is what the
            # measured one is kept for.
            diameter = 2.0 * (
                declared
                if measured is None or abs(measured - declared) < declared * 0.05
                else measured
            )

            center = centroid(contour["points"])

        else:

            # Holes exported as polylines are still holes.
            radius = is_round(contour["points"])

            if radius is not None:
                diameter = radius * 2.0
                center = centroid(contour["points"])

        if diameter is None:
            continue

        found.append((
            contour,
            {
                "index": 0,
                "diameter_mm": round(diameter, 3),
                "center": [
                    round(center[0], 3),
                    round(center[1], 3)
                ]
            }
        ))

    found.sort(
        key=lambda item: (
            item[1]["diameter_mm"],
            item[1]["center"]
        )
    )

    holes = []

    for i, (contour, hole) in enumerate(found, 1):

        hole["index"] = i

        contour["is_hole"] = True
        contour["hole_index"] = i

        holes.append(hole)

    return holes


# ============================================================
# ANALYSIS
# ============================================================

# Two contours this close in length, area and position are the same
# path drawn twice: the machine would cut it twice, and the second
# pass runs in air over a part that has already dropped.
DUPLICATE_TOLERANCE = 0.05

# A contour with no area is a leftover: a doubled-back polyline or a
# zero-length entity. It still costs a pierce.
MIN_CONTOUR_AREA = 0.01
MIN_CONTOUR_LENGTH = 0.05


def find_duplicates(contours):
    """Contours that trace the same path as another one."""

    seen = {}

    duplicates = 0

    for contour in contours:

        points = contour["points"]

        length = polyline_length(points)

        if length < MIN_CONTOUR_LENGTH:
            continue

        middle = centroid(points)

        step = max(DUPLICATE_TOLERANCE, length * DUPLICATE_TOLERANCE)

        key = (
            round(length / step),
            round(abs(polygon_area(points)) / max(step * step, 1e-9)),
            round(middle[0] / step),
            round(middle[1] / step)
        )

        if key in seen:
            duplicates += 1
        else:
            seen[key] = True

    return duplicates


def find_degenerate(contours):
    """Contours that enclose nothing but still cost a pierce."""

    count = 0

    for contour in contours:

        points = contour["points"]

        if polyline_length(points) < MIN_CONTOUR_LENGTH:
            count += 1

        elif (
            contour["closed"]
            and abs(polygon_area(points)) < MIN_CONTOUR_AREA
        ):
            count += 1

    return count


# ============================================================
# GEOMETRY FOR THE VIEWER
#
# The report says how many holes there are; the Mini App has to
# draw them. So the flattened contours are written out beside the
# file in the smallest form that still draws: flat coordinate
# arrays, rounded to a hundredth of a millimetre, which is finer
# than any laser cuts and a third of the size of a pretty JSON.
# ============================================================

VIEWER_DECIMALS = 2


def flat_geometry(data, holes):

    outline = []
    kinds = []
    open_paths = []

    for contour in data["contours"]:

        points = []

        for x, y in contour["points"]:
            points.append(round(x, VIEWER_DECIMALS))
            points.append(round(y, VIEWER_DECIMALS))

        if len(points) < 4:
            continue

        if not contour["closed"]:
            open_paths.append(points)
            continue

        outline.append(points)

        kinds.append(
            2 if contour.get("is_hole")
            else (1 if contour["inner"] else 0)
        )

    return {
        "bbox": [round(v, VIEWER_DECIMALS) for v in data["bbox"]],
        "outline": outline,
        "kinds": kinds,
        "open": open_paths,
        "holes": [
            [
                hole["diameter_mm"],
                round(hole["center"][0], VIEWER_DECIMALS),
                round(hole["center"][1], VIEWER_DECIMALS),
                hole["index"]
            ]
            for hole in holes
        ]
    }


def save_flat(dxf_file, data, holes):
    """Writes the drawing the Mini App shows, beside the file."""

    if data.get("bbox") is None:
        return None

    target = os.path.splitext(dxf_file)[0] + "_flat.json"

    try:

        with open(target, "w", encoding="utf-8") as f:
            json.dump(flat_geometry(data, holes), f, separators=(",", ":"))

    except Exception:
        return None

    return target


def analyze_dxf(dxf_file):

    data = load_contours(dxf_file)

    contours = data["contours"]

    result = {
        "file": os.path.abspath(dxf_file),
        "format": "dxf",
        "units": data["units"],
        "units_declared": data["units_declared"],
        "bounding_box": None,
        "contours": {
            "total": 0,
            "closed": 0,
            "open": 0,
            "outer": 0,
            "inner": 0
        },
        "cut_length_mm": 0.0,
        "pierces": 0,
        "area_mm2": 0.0,
        "perimeter_mm": 0.0,
        "holes": [],
        "hole_groups": [],
        "entity_counts": data["entity_counts"],
        "skipped_entities": data["skipped"]
    }

    if not contours:
        return result

    bbox = data["bbox"]

    result["bounding_box"] = {
        "min": {"x": round(bbox[0], 3), "y": round(bbox[1], 3)},
        "max": {"x": round(bbox[2], 3), "y": round(bbox[3], 3)},
        "size": {
            "x": round(bbox[2] - bbox[0], 3),
            "y": round(bbox[3] - bbox[1], 3)
        }
    }

    closed_contours = [c for c in contours if c["closed"]]
    open_contours = [c for c in contours if not c["closed"]]

    outer = [c for c in closed_contours if not c["inner"]]
    inner = [c for c in closed_contours if c["inner"]]

    result["contours"] = {
        "total": len(contours),
        "closed": len(closed_contours),
        "open": len(open_contours),
        "outer": len(outer),
        "inner": len(inner),
        "duplicate": find_duplicates(contours),
        "degenerate": find_degenerate(contours)
    }

    result["cut_length_mm"] = round(
        sum(polyline_length(c["points"]) for c in contours),
        3
    )

    # Every separate contour needs its own pierce.
    result["pierces"] = len(contours)

    result["area_mm2"] = round(
        sum(c["area"] for c in outer)
        - sum(c["area"] for c in inner),
        3
    )

    # The outside edge on its own. Cut length counts every contour,
    # holes included; the perimeter is what somebody deburrs, edges,
    # paints or wraps, and it is a different number.
    result["perimeter_mm"] = round(
        sum(polyline_length(c["points"]) for c in outer),
        3
    )

    holes = find_holes(contours, data["scale"])

    result["holes"] = holes

    groups = {}

    for hole in holes:

        key = round(hole["diameter_mm"], 1)

        groups[key] = groups.get(key, 0) + 1

    result["hole_groups"] = [
        {"diameter_mm": diameter, "count": count}
        for diameter, count in sorted(groups.items())
    ]

    save_flat(dxf_file, data, holes)

    return result


# ============================================================
# OUTPUT
# ============================================================

def save_json(result, dxf_file):

    json_file = os.path.splitext(dxf_file)[0] + ".json"

    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    return json_file


# IMPORTANT: ASCII ONLY.
# The Windows console on this setup can use cp1251.
def print_summary(result):

    print()
    print("=" * 90)
    print("FORGEMIND DXF ANALYZER")
    print("=" * 90)
    print()

    print("FILE:", result["file"])

    print(
        "UNITS:",
        result["units"],
        f'(file declares: {result["units_declared"]})'
    )

    bbox = result["bounding_box"]

    if bbox:
        print(
            "SIZE:",
            f'{bbox["size"]["x"]:.3f} x '
            f'{bbox["size"]["y"]:.3f} mm'
        )

    contours = result["contours"]

    print("CONTOURS:", contours["total"])
    print("  CLOSED:", contours["closed"])
    print("  OPEN:", contours["open"])
    print("  OUTER:", contours["outer"])
    print("  INNER:", contours["inner"])

    print("CUT LENGTH:", f'{result["cut_length_mm"]:.3f}', "mm")
    print("PIERCES:", result["pierces"])
    print("AREA:", f'{result["area_mm2"]:.3f}', "mm2")

    print("PERIMETER:", f'{result["perimeter_mm"]:.3f}', "mm")

    print()
    print("HOLES:", len(result["holes"]))

    for group in result["hole_groups"]:
        print(
            f'  D{group["diameter_mm"]} mm - '
            f'{group["count"]} pcs.'
        )

    if result["skipped_entities"]:
        print()
        print("SKIPPED ENTITIES:", result["skipped_entities"])

    print()
    print("=" * 90)


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    if len(sys.argv) < 2:
        print("Usage: dxf_analyzer.py <dxf_file>")
        sys.exit(1)

    dxf_file = sys.argv[1]

    if not os.path.exists(dxf_file):
        print("ERROR: DXF file not found:")
        print(dxf_file)
        sys.exit(1)

    try:

        result = analyze_dxf(dxf_file)

        json_file = save_json(result, dxf_file)

        print_summary(result)

        print()
        print("JSON:", json_file)

    except Exception as e:

        print()
        print("ANALYSIS ERROR:")
        print(repr(e))

        raise
