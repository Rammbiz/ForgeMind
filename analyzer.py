import json
import math
import os
import sys

# ------------------------------------------------------------
# Windows / FreeCAD console encoding
# ------------------------------------------------------------

try:
    sys.stdout.reconfigure(
        encoding="utf-8",
        errors="replace"
    )
    sys.stderr.reconfigure(
        encoding="utf-8",
        errors="replace"
    )
except Exception:
    pass


sys.path.insert(0, r"C:\ForgeMind")

import FreeCAD
import Import
import Part

import cad
import drawing


# ============================================================
# CONFIGURATION
# ============================================================

DIAMETER_TOL = 0.5
CENTER_TOL = 0.5
AXIS_ANGLE_TOL = 5.0

EPS = 0.5
RADIAL_SAMPLES = 8

MIN_HOLE_VOTES = 3
MAX_OUTER_VOTES_FOR_HOLE = 0

# Large internal cylindrical surfaces are treated conservatively.
# They remain cylindrical features instead of automatically
# becoming holes.
MAX_AUTOMATIC_HOLE_DIAMETER_MM = 100.0


# ============================================================
# VECTOR MATH
# ============================================================

def vector_length(v):
    return math.sqrt(
        v.x * v.x +
        v.y * v.y +
        v.z * v.z
    )


def normalize(v):
    n = vector_length(v)

    if n < 1e-12:
        return FreeCAD.Vector(0, 0, 0)

    return FreeCAD.Vector(
        v.x / n,
        v.y / n,
        v.z / n
    )


def dot(a, b):
    return (
        a.x * b.x +
        a.y * b.y +
        a.z * b.z
    )


def distance(a, b):
    return vector_length(
        FreeCAD.Vector(
            a.x - b.x,
            a.y - b.y,
            a.z - b.z
        )
    )


def angle_deg(a, b):
    a = normalize(a)
    b = normalize(b)

    d = abs(dot(a, b))
    d = max(-1.0, min(1.0, d))

    return math.degrees(math.acos(d))


# ============================================================
# FORMATTERS
# ============================================================

def point_tuple(p):
    return (
        round(p.x, 3),
        round(p.y, 3),
        round(p.z, 3)
    )


def canonical_axis(v):
    v = normalize(v)

    if abs(v.x) > 1e-8:
        if v.x < 0:
            v = v * -1

    elif abs(v.y) > 1e-8:
        if v.y < 0:
            v = v * -1

    elif abs(v.z) > 1e-8:
        if v.z < 0:
            v = v * -1

    return v


def axis_tuple(v):
    v = canonical_axis(v)

    return (
        round(v.x, 5),
        round(v.y, 5),
        round(v.z, 5)
    )


# ============================================================
# BOUNDING BOX
# ============================================================

def get_bbox_data(shape):
    # Shape.BoundBox is the conservative OCC box, built from the
    # control poles of the surfaces: on curved geometry it can
    # overstate the real extent by a wide margin (240 mm on a
    # 1 m part in testing). optimalBoundingBox measures the
    # actual geometry and costs no more.
    try:
        box = shape.optimalBoundingBox()
    except Exception:
        box = shape.BoundBox

    return {
        "min": {
            "x": round(box.XMin, 3),
            "y": round(box.YMin, 3),
            "z": round(box.ZMin, 3)
        },
        "max": {
            "x": round(box.XMax, 3),
            "y": round(box.YMax, 3),
            "z": round(box.ZMax, 3)
        },
        "size": {
            "x": round(box.XLength, 3),
            "y": round(box.YLength, 3),
            "z": round(box.ZLength, 3)
        }
    }


# ============================================================
# REAL PARTS
# ============================================================

def get_real_parts(doc):
    parts = []

    for obj in doc.Objects:

        if obj.TypeId != "Part::Feature":
            continue

        if not hasattr(obj, "Shape"):
            continue

        shape = obj.Shape

        if shape.isNull():
            continue

        if len(shape.Solids) != 1:
            continue

        parts.append(obj)

    return parts


# ============================================================
# CIRCULAR EDGES
# ============================================================

def get_circle(edge):
    try:
        curve = edge.Curve
    except Exception:
        return None

    try:
        if isinstance(curve, Part.Circle):
            return curve
    except Exception:
        return None

    return None


def circle_info(edge):
    circle = get_circle(edge)

    if circle is None:
        return None

    return {
        "diameter": circle.Radius * 2.0,
        "center": circle.Center,
        "axis": normalize(circle.Axis)
    }


def same_circle(a, b):

    if abs(
        a["diameter"] -
        b["diameter"]
    ) > DIAMETER_TOL:
        return False

    if distance(
        a["center"],
        b["center"]
    ) > CENTER_TOL:
        return False

    if angle_deg(
        a["axis"],
        b["axis"]
    ) > AXIS_ANGLE_TOL:
        return False

    return True


def unique_circles(circles):
    result = []

    for circle in circles:

        duplicate = False

        for existing in result:

            if same_circle(
                circle,
                existing
            ):
                duplicate = True
                break

        if not duplicate:
            result.append(circle)

    return result


# ============================================================
# SOLID POINT TEST
# ============================================================

def point_inside(shape, point):

    try:
        return bool(
            shape.isInside(
                point,
                0.01,
                True
            )
        )
    except Exception:
        return None


# ============================================================
# RADIAL BASIS
# ============================================================

def make_basis(axis):
    axis = normalize(axis)

    if abs(axis.x) < 0.8:
        reference = FreeCAD.Vector(1, 0, 0)
    else:
        reference = FreeCAD.Vector(0, 1, 0)

    e1 = normalize(
        axis.cross(reference)
    )

    e2 = normalize(
        axis.cross(e1)
    )

    return e1, e2


# ============================================================
# RADIAL TOPOLOGY CLASSIFICATION
# ============================================================

def classify_radially(
    shape,
    center,
    axis,
    radius
):
    e1, e2 = make_basis(axis)

    samples = []

    hole_votes = 0
    outer_votes = 0
    uncertain_votes = 0

    for i in range(RADIAL_SAMPLES):

        angle = (
            2.0 *
            math.pi *
            i /
            RADIAL_SAMPLES
        )

        radial = (
            e1 * math.cos(angle) +
            e2 * math.sin(angle)
        )

        radial = normalize(radial)

        inner_point = (
            center +
            radial * (
                radius - EPS
            )
        )

        outer_point = (
            center +
            radial * (
                radius + EPS
            )
        )

        inner_state = point_inside(
            shape,
            inner_point
        )

        outer_state = point_inside(
            shape,
            outer_point
        )

        samples.append({
            "angle_deg": round(
                math.degrees(angle),
                1
            ),
            "inner": inner_state,
            "outer": outer_state
        })

        # Hole wall:
        # R-eps = empty
        # R+eps = material
        if (
            inner_state is False
            and outer_state is True
        ):
            hole_votes += 1

        # Outer cylindrical wall:
        # R-eps = material
        # R+eps = empty
        elif (
            inner_state is True
            and outer_state is False
        ):
            outer_votes += 1

        else:
            uncertain_votes += 1

    if (
        hole_votes >= MIN_HOLE_VOTES
        and outer_votes <= MAX_OUTER_VOTES_FOR_HOLE
    ):
        classification = "hole_candidate"

    elif (
        outer_votes > hole_votes
        and outer_votes >= 2
    ):
        classification = "outer_cylindrical_wall"

    else:
        classification = "uncertain"

    return {
        "classification": classification,
        "hole_votes": hole_votes,
        "outer_votes": outer_votes,
        "uncertain_votes": uncertain_votes,
        "samples": samples
    }


# ============================================================
# CYLINDRICAL PAIR
# ============================================================

def make_pair(a, b):

    if abs(
        a["diameter"] -
        b["diameter"]
    ) > DIAMETER_TOL:
        return None

    if angle_deg(
        a["axis"],
        b["axis"]
    ) > AXIS_ANGLE_TOL:
        return None

    delta = FreeCAD.Vector(
        b["center"].x -
        a["center"].x,

        b["center"].y -
        a["center"].y,

        b["center"].z -
        a["center"].z
    )

    center_distance = vector_length(
        delta
    )

    if center_distance < 1.0:
        return None

    axis = normalize(
        a["axis"]
    )

    axial_length = abs(
        dot(delta, axis)
    )

    transverse = math.sqrt(
        max(
            0.0,
            center_distance ** 2 -
            axial_length ** 2
        )
    )

    if transverse > CENTER_TOL:
        return None

    center = FreeCAD.Vector(
        (
            a["center"].x +
            b["center"].x
        ) / 2.0,

        (
            a["center"].y +
            b["center"].y
        ) / 2.0,

        (
            a["center"].z +
            b["center"].z
        ) / 2.0
    )

    diameter = (
        a["diameter"] +
        b["diameter"]
    ) / 2.0

    return {
        "diameter": diameter,
        "length": axial_length,
        "center": center,
        "axis": axis
    }


# ============================================================
# FEATURE COMPARISON
# ============================================================

def feature_same(a, b):

    if abs(
        a["diameter_mm"] -
        b["diameter_mm"]
    ) > DIAMETER_TOL:
        return False

    if abs(
        a["length_mm"] -
        b["length_mm"]
    ) > 0.5:
        return False

    ca = FreeCAD.Vector(
        *a["center"]
    )

    cb = FreeCAD.Vector(
        *b["center"]
    )

    if distance(ca, cb) > CENTER_TOL:
        return False

    aa = FreeCAD.Vector(
        *a["axis"]
    )

    ab = FreeCAD.Vector(
        *b["axis"]
    )

    if angle_deg(
        aa,
        ab
    ) > AXIS_ANGLE_TOL:
        return False

    return True


def deduplicate_features(features):
    result = []

    for feature in features:

        duplicate = False

        for existing in result:

            if feature_same(
                feature,
                existing
            ):
                duplicate = True
                break

        if not duplicate:
            result.append(feature)

    return result


# ============================================================
# CYLINDRICAL ANALYSIS
# ============================================================

def analyze_cylindrical_features(parts):

    raw_features = []
    circular_edges = []

    for part_index, obj in enumerate(
        parts,
        1
    ):

        shape = obj.Shape

        # ----------------------------------------------------
        # Circular edges
        # ----------------------------------------------------

        for edge_index, edge in enumerate(
            shape.Edges,
            1
        ):

            info = circle_info(edge)

            if info is None:
                continue

            circular_edges.append({
                "part": part_index,
                "name": obj.Name,
                "edge": edge_index,
                "diameter_mm": round(
                    info["diameter"],
                    3
                ),
                "center": point_tuple(
                    info["center"]
                ),
                "axis": axis_tuple(
                    info["axis"]
                )
            })

        # ----------------------------------------------------
        # Face pairs
        # ----------------------------------------------------

        for face_index, face in enumerate(
            shape.Faces,
            1
        ):

            circles = []

            for edge in face.Edges:

                info = circle_info(edge)

                if info is not None:
                    circles.append(info)

            circles = unique_circles(
                circles
            )

            if len(circles) < 2:
                continue

            for i in range(
                len(circles)
            ):

                for j in range(
                    i + 1,
                    len(circles)
                ):

                    pair = make_pair(
                        circles[i],
                        circles[j]
                    )

                    if pair is None:
                        continue

                    classification = (
                        classify_radially(
                            shape,
                            pair["center"],
                            pair["axis"],
                            pair["diameter"] / 2.0
                        )
                    )

                    raw_features.append({
                        "part": part_index,
                        "name": obj.Name,
                        "face": face_index,

                        "diameter_mm": round(
                            pair["diameter"],
                            3
                        ),

                        "length_mm": round(
                            pair["length"],
                            3
                        ),

                        "center": point_tuple(
                            pair["center"]
                        ),

                        "axis": axis_tuple(
                            pair["axis"]
                        ),

                        "classification":
                            classification[
                                "classification"
                            ],

                        "hole_votes":
                            classification[
                                "hole_votes"
                            ],

                        "outer_votes":
                            classification[
                                "outer_votes"
                            ],

                        "uncertain_votes":
                            classification[
                                "uncertain_votes"
                            ],

                        "radial_samples":
                            classification[
                                "samples"
                            ]
                    })

    unique_features = (
        deduplicate_features(
            raw_features
        )
    )

    holes = []
    outer_walls = []
    uncertain = []

    for feature in unique_features:

        diameter = feature[
            "diameter_mm"
        ]

        classification = feature[
            "classification"
        ]

        if (
            classification == "hole_candidate"
            and feature["hole_votes"] >= MIN_HOLE_VOTES
            and feature["outer_votes"] == 0
            and diameter <= MAX_AUTOMATIC_HOLE_DIAMETER_MM
        ):

            feature["classification"] = "hole"

            holes.append(
                feature
            )

        elif (
            classification ==
            "outer_cylindrical_wall"
        ):

            feature[
                "classification"
            ] = "outer_cylindrical_wall"

            outer_walls.append(
                feature
            )

        else:

            feature[
                "classification"
            ] = "uncertain_cylindrical_feature"

            uncertain.append(
                feature
            )

    return {
        "raw_features":
            raw_features,

        "unique_features":
            unique_features,

        "holes":
            holes,

        "outer_walls":
            outer_walls,

        "uncertain":
            uncertain,

        "circular_edges":
            circular_edges
    }


# ============================================================
# HOLE GROUPING
# ============================================================

def group_holes(holes):

    groups = {}

    for hole in holes:

        key = (
            round(
                hole["diameter_mm"],
                1
            ),
            round(
                hole["length_mm"],
                1
            )
        )

        groups.setdefault(
            key,
            []
        ).append(
            hole
        )

    result = []

    for (
        diameter,
        length
    ), items in sorted(
        groups.items()
    ):

        result.append({
            "diameter_mm": diameter,
            "length_mm": length,
            "count": len(items)
        })

    return result


# ============================================================
# MAIN ANALYSIS
# ============================================================

# A part with more faces than this is not sheet metal, and the flat
# test on every one of them is not worth the wait.
BEND_FACE_LIMIT = 400


def add_bend_data(result, parts, holes):
    """Straight runs, bend angles and radii, part by part.

    The manufacturability check reads this and never opens the model
    again: a bent flange too short to hold, or a hole sitting in the
    radius, are questions about geometry that is already measured.
    """

    by_index = {
        part["index"]: part
        for part in result["parts"]
    }

    found = 0

    for index, obj in enumerate(parts, 1):

        shape = obj.Shape

        if len(shape.Faces) > BEND_FACE_LIMIT:
            continue

        size = cad.box_size(cad.optimal_box(shape))

        deflection = cad.deflection_for(
            float(sum(v * v for v in size) ** 0.5)
        )

        points, faces = cad.tessellate(shape, deflection)

        if points is None:
            continue

        try:

            rotation, extents, centre = drawing.oriented_frame(
                points,
                faces
            )

            rotation, view = drawing.reordered_frame(
                rotation,
                extents,
                drawing.view_axis(points, faces, rotation)
            )

            profile, rotation, view = cad.bent_profile(
                shape,
                rotation,
                centre,
                view,
                deflection
            )

        except Exception:
            continue

        if profile is None:
            continue

        found += 1

        by_index[index]["bend"] = {
            "runs": [round(v, 3) for v in profile["lengths"]],
            "angles": [round(v, 2) for v in profile["angles"]],
            "thickness": round(profile["thickness"], 3),
            "developed_mm": round(profile["developed"], 3),
            "radii": cad.bend_radii(shape, rotation[2])
        }

        # The inside of a fold is a cylindrical face, and the hole
        # detector cannot tell it from a drilled hole. It can be
        # told apart here: a bend runs along the fold axis, a hole
        # through a flange runs across it.
        axis = rotation[2]

        for hole in list(holes):

            if hole.get("part") != index or not hole.get("axis"):
                continue

            if abs(float(
                sum(a * b for a, b in zip(hole["axis"], axis))
            )) > 0.99:
                holes.remove(hole)

        # Where each hole sits relative to the folds. In the part's
        # own frame a bend is a point on the profile, so the whole
        # question is a distance in two dimensions.
        line = profile["line"]

        for hole in holes:

            if hole.get("part") != index or not hole.get("center"):
                continue

            local = drawing.to_frame(
                [hole["center"]],
                rotation,
                centre
            )[0][:2]

            nearest = None

            for vertex in line[1:-1]:

                gap = float(
                    sum((a - b) ** 2 for a, b in zip(local, vertex))
                    ** 0.5
                ) - hole.get("diameter_mm", 0.0) / 2.0

                if nearest is None or gap < nearest:
                    nearest = gap

            if nearest is not None:
                hole["bend_distance_mm"] = round(max(nearest, 0.0), 3)

    return found


def open_cad_document(path):
    """Opens a CAD file, whatever flavour it is.

    FreeCAD's own documents already contain built shapes and must
    be opened, not imported.
    """

    if os.path.splitext(path)[1].lower() == ".fcstd":
        return FreeCAD.openDocument(path)

    Import.open(path)

    return FreeCAD.ActiveDocument


def analyze_step(step_file):

    doc = open_cad_document(
        step_file
    )

    parts = get_real_parts(
        doc
    )

    result = {
        "file": os.path.abspath(
            step_file
        ),

        "parts_count": len(
            parts
        ),

        "bounding_box": None,

        "parts": [],

        "circular_edges": [],

        "cylindrical_features": [],

        "holes": [],

        "hole_groups": [],

        "cylindrical_statistics": {},

        "total": {
            "solids": 0,
            "faces": 0,
            "edges": 0,
            "volume_mm3": 0.0
        }
    }

    # --------------------------------------------------------
    # Global bounding box
    # --------------------------------------------------------

    if parts:

        compound = Part.makeCompound(
            [
                obj.Shape
                for obj in parts
            ]
        )

        result["bounding_box"] = (
            get_bbox_data(
                compound
            )
        )

    # --------------------------------------------------------
    # Part analysis
    # --------------------------------------------------------

    for index, obj in enumerate(
        parts,
        1
    ):

        shape = obj.Shape

        part_data = {
            "index": index,
            "name": obj.Name,

            "solids":
                len(shape.Solids),

            "faces":
                len(shape.Faces),

            "edges":
                len(shape.Edges),

            "volume_mm3":
                round(
                    shape.Volume,
                    3
                ),

            "bounding_box":
                get_bbox_data(
                    shape
                ),

            "circular_edges": []
        }

        # What the body looks like, so the bill of materials can
        # tell a screw from a part somebody has to cut.
        box = part_data["bounding_box"]["size"]

        try:

            facts = cad.hardware_facts(
                shape,
                (box["x"], box["y"], box["z"])
            )

        except Exception:
            facts = None

        if facts is not None:
            part_data["shape"] = facts

        for edge in shape.Edges:

            info = circle_info(
                edge
            )

            if info is None:
                continue

            part_data[
                "circular_edges"
            ].append({
                "diameter_mm":
                    round(
                        info["diameter"],
                        3
                    ),

                "center":
                    point_tuple(
                        info["center"]
                    ),

                "axis":
                    axis_tuple(
                        info["axis"]
                    )
            })

        result["parts"].append(
            part_data
        )

        result["total"]["solids"] += (
            len(shape.Solids)
        )

        result["total"]["faces"] += (
            len(shape.Faces)
        )

        result["total"]["edges"] += (
            len(shape.Edges)
        )

        result["total"]["volume_mm3"] += (
            shape.Volume
        )

    result["total"][
        "volume_mm3"
    ] = round(
        result["total"]["volume_mm3"],
        3
    )

    # --------------------------------------------------------
    # Cylindrical analysis
    # --------------------------------------------------------

    cylindrical = (
        analyze_cylindrical_features(
            parts
        )
    )

    result["circular_edges"] = (
        cylindrical["circular_edges"]
    )

    result["holes"] = (
        cylindrical["holes"]
    )

# --------------------------------------------------------
    # Bends
    # --------------------------------------------------------

    print(
        "BENT PARTS:",
        add_bend_data(result, parts, result["holes"])
    )

    result["hole_groups"] = (
        group_holes(
            cylindrical["holes"]
        )
    )

    result["cylindrical_features"] = (
        cylindrical["outer_walls"]
        +
        cylindrical["uncertain"]
    )

    result["cylindrical_statistics"] = {
        "raw_pairs":
            len(
                cylindrical[
                    "raw_features"
                ]
            ),

        "unique_features":
            len(
                cylindrical[
                    "unique_features"
                ]
            ),

        "holes":
            len(
                cylindrical[
                    "holes"
                ]
            ),

        "outer_cylindrical_walls":
            len(
                cylindrical[
                    "outer_walls"
                ]
            ),

        "uncertain":
            len(
                cylindrical[
                    "uncertain"
                ]
            )
    }

    return result


# ============================================================
# SAVE JSON
# ============================================================

def save_json(
    result,
    step_file
):

    json_file = (
        os.path.splitext(
            step_file
        )[0]
        + ".json"
    )

    with open(
        json_file,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            result,
            f,
            indent=2,
            ensure_ascii=False
        )

    return json_file


# ============================================================
# CONSOLE SUMMARY
# IMPORTANT: ASCII ONLY.
# FreeCADCmd on this Windows setup can use cp1251.
# ============================================================

def print_summary(result):

    print()
    print("=" * 90)
    print("FORGEMIND CAD ANALYZER")
    print("=" * 90)
    print()

    print(
        "FILE:",
        result["file"]
    )

    print(
        "PARTS:",
        result["parts_count"]
    )

    bbox = result["bounding_box"]

    if bbox:

        size = bbox["size"]

        print(
            "SIZE:",
            f'{size["x"]:.3f} x '
            f'{size["y"]:.3f} x '
            f'{size["z"]:.3f} mm'
        )

    print(
        "VOLUME:",
        f'{result["total"]["volume_mm3"]:.3f}',
        "mm3"
    )

    print(
        "SOLIDS:",
        result["total"]["solids"]
    )

    print(
        "FACES:",
        result["total"]["faces"]
    )

    print(
        "EDGES:",
        result["total"]["edges"]
    )

    print()

    print(
        "CIRCULAR EDGES:",
        len(
            result["circular_edges"]
        )
    )

    stats = result[
        "cylindrical_statistics"
    ]

    print(
        "RAW CYLINDRICAL PAIRS:",
        stats["raw_pairs"]
    )

    print(
        "UNIQUE CYLINDRICAL FEATURES:",
        stats["unique_features"]
    )

    print(
        "HOLES:",
        stats["holes"]
    )

    print(
        "OUTER CYLINDRICAL WALLS:",
        stats["outer_cylindrical_walls"]
    )

    print(
        "UNCERTAIN:",
        stats["uncertain"]
    )

    print()

    print("=" * 90)
    print("HOLE GROUPS")
    print("=" * 90)

    if not result["hole_groups"]:

        print(
            "No confirmed holes."
        )

    else:

        for group in result[
            "hole_groups"
        ]:

            print(
                f'D{group["diameter_mm"]} x '
                f'{group["length_mm"]} mm - '
                f'{group["count"]} pcs.'
            )

    print()

    print("=" * 90)
    print("HOLE DETAILS")
    print("=" * 90)

    if not result["holes"]:

        print(
            "No confirmed holes."
        )

    else:

        for index, hole in enumerate(
            result["holes"],
            1
        ):

            center = hole[
                "center"
            ]

            axis = hole[
                "axis"
            ]

            print(
                f'[{index}] '
                f'PART={hole["part"]} '
                f'FACE={hole["face"]} '
                f'D={hole["diameter_mm"]} '
                f'L={hole["length_mm"]}'
            )

            print(
                "    CENTER:",
                f'X={center[0]:.3f} '
                f'Y={center[1]:.3f} '
                f'Z={center[2]:.3f}'
            )

            print(
                "    AXIS:",
                f'({axis[0]:.3f}, '
                f'{axis[1]:.3f}, '
                f'{axis[2]:.3f})'
            )

    print()

    print("=" * 90)


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    if len(sys.argv) < 2:

        print(
            "Usage: analyzer.py <step_file>"
        )

        sys.exit(1)

    step_file = sys.argv[1]

    if not os.path.exists(
        step_file
    ):

        print(
            "ERROR: STEP file not found:"
        )

        print(
            step_file
        )

        sys.exit(1)

    try:

        result = analyze_step(
            step_file
        )

        json_file = save_json(
            result,
            step_file
        )

        print_summary(
            result
        )

        print()

        print(
            "JSON:",
            json_file
        )

    except Exception as e:

        print()
        print(
            "ANALYSIS ERROR:"
        )

        print(
            repr(e)
        )

        raise