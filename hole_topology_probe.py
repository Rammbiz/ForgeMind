import json
import math

import FreeCAD
import Import
import Part


STEP_FILE = r"C:\ForgeMind\files\holes_test.stp"
OUTPUT_FILE = r"C:\ForgeMind\files\hole_topology_probe.json"

DIAMETER_TOL = 0.5
CENTER_TOL = 0.5
AXIS_ANGLE_TOL = 5.0

EPS = 0.5
INSIDE_TOL = 0.01

# Кількість напрямків навколо циліндра
RADIAL_SAMPLES = 8


def norm(v):
    return math.sqrt(
        v.x * v.x +
        v.y * v.y +
        v.z * v.z
    )


def normalize(v):
    n = norm(v)

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
    return norm(
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


def real_parts(doc):

    result = []

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

        result.append(obj)

    return result


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

    for c in circles:

        duplicate = False

        for existing in result:

            if same_circle(c, existing):
                duplicate = True
                break

        if not duplicate:
            result.append(c)

    return result


def make_basis(axis):

    axis = normalize(axis)

    if abs(axis.x) < 0.8:
        reference = FreeCAD.Vector(1, 0, 0)
    else:
        reference = FreeCAD.Vector(0, 1, 0)

    e1 = normalize(axis.cross(reference))
    e2 = normalize(axis.cross(e1))

    return e1, e2


def point_inside(shape, point):

    try:

        return bool(
            shape.isInside(
                point,
                INSIDE_TOL,
                True
            )
        )

    except Exception:

        return None


def classify_radially(
    shape,
    center,
    axis,
    radius
):

    e1, e2 = make_basis(axis)

    results = []

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
            radial * (radius - EPS)
        )

        outer_point = (
            center +
            radial * (radius + EPS)
        )

        inner_state = point_inside(
            shape,
            inner_point
        )

        outer_state = point_inside(
            shape,
            outer_point
        )

        results.append({
            "angle_deg":
                round(
                    math.degrees(angle),
                    1
                ),

            "inner":
                inner_state,

            "outer":
                outer_state
        })

    hole_votes = 0
    outer_votes = 0
    uncertain_votes = 0

    for result in results:

        inner = result["inner"]
        outer = result["outer"]

        if (
            inner is False and
            outer is True
        ):
            hole_votes += 1

        elif (
            inner is True and
            outer is False
        ):
            outer_votes += 1

        else:
            uncertain_votes += 1

    if (
        hole_votes > outer_votes and
        hole_votes >= 2
    ):
        classification = "hole_wall"

    elif (
        outer_votes > hole_votes and
        outer_votes >= 2
    ):
        classification = "outer_cylindrical_wall"

    else:
        classification = "uncertain"

    return {
        "classification": classification,
        "hole_votes": hole_votes,
        "outer_votes": outer_votes,
        "uncertain_votes": uncertain_votes,
        "samples": results
    }


def point_tuple(p):

    return (
        round(p.x, 3),
        round(p.y, 3),
        round(p.z, 3)
    )


def axis_tuple(v):

    v = normalize(v)

    # Канонізуємо знак осі
    if abs(v.x) > 1e-8:

        if v.x < 0:
            v = v * -1

    elif abs(v.y) > 1e-8:

        if v.y < 0:
            v = v * -1

    elif abs(v.z) > 1e-8:

        if v.z < 0:
            v = v * -1

    return (
        round(v.x, 5),
        round(v.y, 5),
        round(v.z, 5)
    )


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

    distance_between_centers = norm(delta)

    if distance_between_centers < 1.0:
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
            distance_between_centers ** 2 -
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

    return {
        "diameter":
            (
                a["diameter"] +
                b["diameter"]
            ) / 2.0,

        "length":
            axial_length,

        "center":
            center,

        "axis":
            axis
    }


# ============================================================
# LOAD
# ============================================================

Import.open(STEP_FILE)

doc = FreeCAD.ActiveDocument

parts = real_parts(doc)


print()
print("=" * 100)
print("HOLE TOPOLOGY PROBE v2")
print("=" * 100)
print()

print("REAL PARTS:", len(parts))
print()


raw = []


# ============================================================
# SEARCH CIRCULAR PAIRS
# ============================================================

for part_index, obj in enumerate(
    parts,
    1
):

    shape = obj.Shape

    for face_index, face in enumerate(
        shape.Faces,
        1
    ):

        circles = []

        for edge in face.Edges:

            info = circle_info(edge)

            if info is not None:
                circles.append(info)

        circles = unique_circles(circles)

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

                classification = classify_radially(
                    shape,
                    pair["center"],
                    pair["axis"],
                    pair["diameter"] / 2.0
                )

                raw.append({

                    "part": part_index,

                    "name": obj.Name,

                    "face": face_index,

                    "diameter_mm":
                        round(
                            pair["diameter"],
                            3
                        ),

                    "length_mm":
                        round(
                            pair["length"],
                            3
                        ),

                    "center":
                        point_tuple(
                            pair["center"]
                        ),

                    "axis":
                        axis_tuple(
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
                        ]
                })


# ============================================================
# PRINT
# ============================================================

print(
    "RAW CYLINDRICAL PAIRS:",
    len(raw)
)

print()


for i, item in enumerate(
    raw,
    1
):

    print(
        f"[{i}] "
        f"P{item['part']} "
        f"F{item['face']} "
        f"Ø{item['diameter_mm']} "
        f"L={item['length_mm']} "
        f"{item['classification']} "
        f"H={item['hole_votes']} "
        f"O={item['outer_votes']} "
        f"U={item['uncertain_votes']}"
    )

    print(
        "    CENTER:",
        item["center"]
    )

    print(
        "    AXIS:",
        item["axis"]
    )

    print()


# ============================================================
# SUMMARY
# ============================================================

summary = {}

for item in raw:

    kind = item["classification"]

    summary[kind] = (
        summary.get(kind, 0) + 1
    )


print("=" * 100)
print("CLASSIFICATION")
print("=" * 100)

for kind, count in sorted(
    summary.items()
):

    print(
        f"{kind}: {count}"
    )


# ============================================================
# Ø10 SUMMARY
# ============================================================

diameter_summary = {}

for item in raw:

    if (
        abs(
            item["diameter_mm"] -
            10.0
        ) < DIAMETER_TOL
    ):

        key = item["classification"]

        diameter_summary[key] = (
            diameter_summary.get(
                key,
                0
            ) + 1
        )


print()
print("=" * 100)
print("Ø10 CLASSIFICATION")
print("=" * 100)

if diameter_summary:

    for kind, count in sorted(
        diameter_summary.items()
    ):

        print(
            f"Ø10 {kind}: {count}"
        )

else:

    print("No Ø10 candidates.")


# ============================================================
# JSON
# ============================================================

json_data = {

    "step_file":
        STEP_FILE,

    "real_parts":
        len(parts),

    "raw_candidates":
        len(raw),

    "summary":
        summary,

    "diameter_10_summary":
        diameter_summary,

    "candidates":
        raw
}


with open(
    OUTPUT_FILE,
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        json_data,
        f,
        indent=2,
        ensure_ascii=False
    )


print()
print("=" * 100)
print("JSON:", OUTPUT_FILE)
print("=" * 100)
print("END")
print("=" * 100)