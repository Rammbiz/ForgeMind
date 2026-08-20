import math
import json

import FreeCAD
import Import
import Part


STEP_FILE = r"C:\ForgeMind\files\test.stp"

# ------------------------------------------------------------
# Налаштування
# ------------------------------------------------------------

ANGLE_TOL_DEG = 5.0
CENTER_TOL = 0.5
DIAMETER_TOL = 0.5

MIN_AXIS_LENGTH = 0.5

# Додатково відкидаємо явно гігантські апроксимації
MAX_REASONABLE_DIAMETER = 1000.0


# ------------------------------------------------------------
# Vector helpers
# ------------------------------------------------------------

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

    d = max(-1.0, min(1.0, abs(dot(a, b))))

    return math.degrees(math.acos(d))


# ------------------------------------------------------------
# Safe curve extraction
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Первинні реальні деталі
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Аналіз кругового ребра
# ------------------------------------------------------------

def circle_info(edge):

    circle = get_circle(edge)

    if circle is None:
        return None

    center = circle.Center
    axis = normalize(circle.Axis)
    diameter = circle.Radius * 2.0

    return {
        "diameter_mm": diameter,
        "center": center,
        "axis": axis
    }


# ------------------------------------------------------------
# Чи збігаються два круги?
# ------------------------------------------------------------

def circles_match(a, b):

    if abs(
        a["diameter_mm"] -
        b["diameter_mm"]
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
    ) > ANGLE_TOL_DEG:
        return False

    return True


# ------------------------------------------------------------
# Аналіз face:
#
# Шукаємо circular edges на perimeter.
#
# Особливо цікаві:
# - 2 circle edges
# - однаковий D
# - однакова вісь
# - різні центри вздовж осі
#
# Це сильний індикатор циліндричної стінки.
# ------------------------------------------------------------

def analyze_face(face):

    circles = []

    for edge in face.Edges:

        info = circle_info(edge)

        if info is None:
            continue

        circles.append(info)

    if not circles:
        return None

    # --------------------------------------------------------
    # Немає сенсу рахувати один і той самий круг багато разів
    # --------------------------------------------------------

    unique = []

    for c in circles:

        duplicate = False

        for u in unique:

            if circles_match(c, u):
                duplicate = True
                break

        if not duplicate:
            unique.append(c)

    if not unique:
        return None

    # --------------------------------------------------------
    # Для кожного кругового boundary будуємо кандидата
    # --------------------------------------------------------

    candidates = []

    for i in range(len(unique)):

        for j in range(i + 1, len(unique)):

            a = unique[i]
            b = unique[j]

            # Діаметри повинні збігатися
            if abs(
                a["diameter_mm"] -
                b["diameter_mm"]
            ) > DIAMETER_TOL:
                continue

            # Осі повинні бути паралельними
            if angle_deg(
                a["axis"],
                b["axis"]
            ) > ANGLE_TOL_DEG:
                continue

            # Центри повинні бути зміщені вздовж осі.
            delta = FreeCAD.Vector(
                b["center"].x - a["center"].x,
                b["center"].y - a["center"].y,
                b["center"].z - a["center"].z
            )

            length = vector_length(delta)

            if length < MIN_AXIS_LENGTH:
                continue

            axis = a["axis"]

            axial_component = abs(
                dot(delta, axis)
            )

            # Наскільки зміщення центрів лежить уздовж осі
            transverse = math.sqrt(
                max(
                    0.0,
                    length * length -
                    axial_component * axial_component
                )
            )

            if transverse > CENTER_TOL:
                continue

            candidates.append({
                "diameter_mm":
                    (a["diameter_mm"] +
                     b["diameter_mm"]) / 2.0,

                "center_a":
                    a["center"],

                "center_b":
                    b["center"],

                "axis":
                    axis,

                "length_mm":
                    axial_component
            })

    return {
        "boundary_circles": unique,
        "cylindrical_pairs": candidates
    }


# ------------------------------------------------------------
# Аналіз STEP
# ------------------------------------------------------------

Import.open(STEP_FILE)

doc = FreeCAD.ActiveDocument

parts = get_real_parts(doc)

print()
print("=" * 90)
print("BOUNDARY CYLINDER PROBE")
print("=" * 90)
print()

print("REAL PARTS:", len(parts))
print()


all_faces = 0
bspline_faces = 0
faces_with_circles = 0
cylindrical_candidates = []


for part_index, obj in enumerate(parts, 1):

    shape = obj.Shape

    for face_index, face in enumerate(shape.Faces, 1):

        all_faces += 1

        try:
            surface = face.Surface
            surface_type = type(surface).__name__
        except Exception:
            continue

        if surface_type == "BSplineSurface":
            bspline_faces += 1

        analysis = analyze_face(face)

        if analysis is None:
            continue

        faces_with_circles += 1

        for pair in analysis["cylindrical_pairs"]:

            diameter = pair["diameter_mm"]

            if diameter > MAX_REASONABLE_DIAMETER:
                continue

            axis = normalize(pair["axis"])

            cylindrical_candidates.append({
                "part": part_index,
                "name": obj.Name,
                "face": face_index,
                "surface_type": surface_type,
                "diameter_mm":
                    round(diameter, 3),

                "length_mm":
                    round(pair["length_mm"], 3),

                "center_a": (
                    round(pair["center_a"].x, 3),
                    round(pair["center_a"].y, 3),
                    round(pair["center_a"].z, 3)
                ),

                "center_b": (
                    round(pair["center_b"].x, 3),
                    round(pair["center_b"].y, 3),
                    round(pair["center_b"].z, 3)
                ),

                "axis": (
                    round(axis.x, 5),
                    round(axis.y, 5),
                    round(axis.z, 5)
                )
            })


# ------------------------------------------------------------
# Виведення
# ------------------------------------------------------------

print("TOTAL FACES:", all_faces)
print("BSPLINE FACES:", bspline_faces)
print("FACES WITH CIRCULAR BOUNDARIES:", faces_with_circles)

print()
print(
    "CYLINDRICAL BOUNDARY CANDIDATES:",
    len(cylindrical_candidates)
)
print()


for i, item in enumerate(
    cylindrical_candidates,
    1
):

    print(
        f"[{i}] "
        f"PART={item['part']} "
        f"FACE={item['face']} "
        f"SURFACE={item['surface_type']} "
        f"Ø{item['diameter_mm']} "
        f"L={item['length_mm']} "
        f"AXIS={item['axis']}"
    )

    print(
        "    CENTER A:",
        item["center_a"]
    )

    print(
        "    CENTER B:",
        item["center_b"]
    )

    print()


# ------------------------------------------------------------
# Групування діаметрів
# ------------------------------------------------------------

diameter_groups = {}

for item in cylindrical_candidates:

    d = item["diameter_mm"]

    key = round(d, 1)

    diameter_groups[key] = (
        diameter_groups.get(key, 0) + 1
    )


print("=" * 90)
print("DIAMETER GROUPS")
print("=" * 90)

if not diameter_groups:

    print("No cylindrical boundary candidates.")

else:

    for diameter, count in sorted(
        diameter_groups.items()
    ):

        print(
            f"Ø{diameter} : {count}"
        )


# ------------------------------------------------------------
# JSON результат
# ------------------------------------------------------------

output_file = r"C:\ForgeMind\files\surface_probe.json"

json_data = {
    "step_file": STEP_FILE,
    "real_parts": len(parts),
    "total_faces": all_faces,
    "bspline_faces": bspline_faces,
    "faces_with_circular_boundaries":
        faces_with_circles,
    "cylindrical_boundary_candidates":
        cylindrical_candidates,
    "diameter_groups":
        diameter_groups
}


with open(
    output_file,
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
print("=" * 90)
print("JSON:", output_file)
print("=" * 90)