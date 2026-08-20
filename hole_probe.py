import FreeCAD
import Import


STEP_FILE = r"C:\ForgeMind\files\test.stp"

Import.open(STEP_FILE)

doc = FreeCAD.ActiveDocument

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


print("REAL PARTS:", len(parts))
print()


count = 0


for part_index, obj in enumerate(parts, 1):

    shape = obj.Shape

    for face_index, face in enumerate(shape.Faces, 1):

        try:
            wires = face.Wires
        except Exception:
            continue

        if len(wires) <= 1:
            continue

        count += 1

        print(
            f"PART {part_index} | FACE {face_index} | "
            f"WIRES: {len(wires)}"
        )

        for wire_index, wire in enumerate(wires):

            circles = []

            for edge in wire.Edges:

                try:
                    curve = edge.Curve
                except Exception:
                    continue

                try:
                    if type(curve).__name__ == "Circle":
                        circles.append(round(curve.Radius * 2, 3))
                except Exception:
                    continue

            print(
                f"  WIRE {wire_index} | "
                f"EDGES: {len(wire.Edges)} | "
                f"CIRCULAR DIAMETERS: {circles}"
            )


print()
print("FACES WITH MULTIPLE WIRES:", count)