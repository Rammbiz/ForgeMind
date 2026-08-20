import json
import math

import FreeCAD
import Import
import Part


STEP_FILE = r"C:\ForgeMind\files\test.stp"
OUTPUT_FILE = r"C:\ForgeMind\files\hole_detector.json"

DIAMETER_TOL = 0.5
CENTER_TOL = 0.5
AXIS_ANGLE_TOL = 5.0
LENGTH_TOL = 0.5


def vec_len(v):
    return math.sqrt(
        v.x * v.x +
        v.y * v.y +
        v.z * v.z
    )


def normalize(v):
    n = vec_len(v)

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
    return vec_len(
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


def circle_record(edge):
    circle = get_circle(edge)

    if circle is None:
        return None

    return {
        "diameter": circle.Radius * 2.0,
        "center": circle.Center,
        "axis": normalize(circle.Axis)
    }


def circle_same(a, b):
    if abs(a["diameter"] - b["diameter"]) > DIAMETER_TOL:
        return False

    if distance(a["center"], b["center"]) > CENTER_TOL:
        return False

    if angle_deg(a["axis"], b["axis"]) > AXIS_ANGLE_TOL:
        return False

    return True


def unique_circles(circles):
    result = []

    for circle in circles:
        duplicate = False

        for existing in result:
            if circle_same(circle, existing):
                duplicate = True
                break

        if not duplicate:
            result.append(circle)

    return result


def make_pair(a, b):

    if abs(a["diameter"] - b["diameter"]) > DIAMETER_TOL:
        return None

    if angle_deg(a["axis"], b["axis"]) > AXIS_ANGLE_TOL:
        return None

    delta = FreeCAD.Vector(
        b["center"].x - a["center"].x,
        b["center"].y - a["center"].y,
        b["center"].z - a["center"].z
    )

    distance_between_centers = vec_len(delta)

    if distance_between_centers < 0.001:
        return None

    axis = a["axis"]

    axial_length = abs(dot(delta, axis))

    transverse = math.sqrt(
        max(
            0.0,
            distance_between_centers ** 2 -
            axial_length ** 2
        )
    )

    if transverse > CENTER_TOL:
        return None

    return {
        "diameter_mm": (
            a["diameter"] +
            b["diameter"]
        ) / 2.0,

        "length_mm": axial_length,

        "center_a": a["center"],
        "center_b": b["center"],

        "axis": axis
    }


def pair_same(a, b):

    if abs(
        a["diameter_mm"] -
        b["diameter_mm"]
    ) > DIAMETER_TOL:
        return False

    if abs(
        a["length_mm"] -
        b["length_mm"]
    ) > LENGTH_TOL:
        return False

    if angle_deg(
        FreeCAD.Vector(*a["axis"]),
        FreeCAD.Vector(*b["axis"])
    ) > AXIS_ANGLE_TOL:
        return False

    ca = FreeCAD.Vector(*a["center_a"])
    cb = FreeCAD.Vector(*b["center_a"])

    if distance(ca, cb) > CENTER_TOL:
        return False

    return True


def deduplicate_pairs(pairs):
    result = []

    for pair in pairs:

        duplicate = False

        for existing in result:

            if pair_same(pair, existing):
                duplicate = True
                break

        if not duplicate:
            result.append(pair)

    return result


def point_tuple(p):
    return (
        round(p.x, 3),
        round(p.y, 3),
        round(p.z, 3)
    )


def axis_tuple(v):
    return (
        round(v.x, 5),
        round(v.y, 5),
        round(v.z, 5)
    )


# ------------------------------------------------------------
# LOAD STEP
# ------------------------------------------------------------

Import.open(STEP_FILE)

doc = FreeCAD.ActiveDocument

parts = get_real_parts(doc)


print()
print("=" * 90)
print("HOLE DETECTOR")
print("=" * 90)
print()

print("REAL PARTS:", len(parts))
print()


all_features = []


# ------------------------------------------------------------
# ANALYZE EACH FACE
# ------------------------------------------------------------

for part_index, obj in enumerate(parts, 1):

    shape = obj.Shape

    for face_index, face in enumerate(shape.Faces, 1):

        try:
            surface_type = type(face.Surface).__name__
        except Exception:
            surface_type = "Unknown"

        circles = []

        for edge in face.Edges:

            info = circle_record(edge)

            if info is not None:
                circles.append(info)

        circles = unique_circles(circles)

        if len(circles) < 2:
            continue

        for i in range(len(circles)):

            for j in range(i + 1, len(circles)):

                pair = make_pair(
                    circles[i],
                    circles[j]
                )

                if pair is None:
                    continue

                feature = {
                    "part": part_index,
                    "name": obj.Name,
                    "face": face_index,
                    "surface_type": surface_type,

                    "diameter_mm": round(
                        pair["diameter_mm"],
                        3
                    ),

                    "length_mm": round(
                        pair["length_mm"],
                        3
                    ),

                    "center_a": point_tuple(
                        pair["center_a"]
                    ),

                    "center_b": point_tuple(
                        pair["center_b"]
                    ),

                    "axis": axis_tuple(
                        pair["axis"]
                    )
                }

                all_features.append(feature)


# ------------------------------------------------------------
# DEDUPLICATE
# ------------------------------------------------------------

features = deduplicate_pairs(all_features)


# ------------------------------------------------------------
# CLASSIFICATION
# ------------------------------------------------------------

for feature in features:

    # На цьому етапі це чесний geometry candidate.
    # Hole classification буде наступним рівнем.
    feature["classification"] = (
        "cylindrical_feature"
    )


# ------------------------------------------------------------
# GROUPS
# ------------------------------------------------------------

groups = {}

for feature in features:

    key = (
        round(feature["diameter_mm"], 1),
        round(feature["length_mm"], 1)
    )

    groups[key] = groups.get(key, 0) + 1


# ------------------------------------------------------------
# PRINT
# ------------------------------------------------------------

print("RAW PAIRS:", len(all_features))
print("UNIQUE FEATURES:", len(features))
print()

if features:

    for i, feature in enumerate(features, 1):

        print(
            f"[{i}] "
            f"PART={feature['part']} "
            f"FACE={feature['face']} "
            f"Ø{feature['diameter_mm']} "
            f"L={feature['length_mm']} "
            f"KIND={feature['classification']}"
        )

        print(
            "    CENTER A:",
            feature["center_a"]
        )

        print(
            "    CENTER B:",
            feature["center_b"]
        )

        print(
            "    AXIS:",
            feature["axis"]
        )

        print()

else:

    print("No cylindrical features found.")


print("=" * 90)
print("GROUPS")
print("=" * 90)

if groups:

    for (diameter, length), count in sorted(groups.items()):

        print(
            f"Ø{diameter} × {length} mm : {count} шт."
        )

else:

    print("No groups.")


# ------------------------------------------------------------
# JSON
# ------------------------------------------------------------

result = {
    "step_file": STEP_FILE,
    "real_parts": len(parts),
    "raw_pairs": len(all_features),
    "unique_features": len(features),
    "features": features,
    "groups": {
        f"{d}x{l}": count
        for (d, l), count in sorted(groups.items())
    }
}


with open(
    OUTPUT_FILE,
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        result,
        f,
        indent=2,
        ensure_ascii=False
    )


print()
print("JSON:", OUTPUT_FILE)
print("=" * 90)
print("END")
print("=" * 90)