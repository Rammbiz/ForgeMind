"""STEP / FCStd -> GLB for the in-chat 3D viewer.

Runs inside freecadcmd. The browser could read the STEP itself —
Online 3D Viewer carries OpenCascade compiled to WebAssembly — but
on a phone that means downloading the kernel and tessellating a
two-megabyte assembly on the handset. The tessellation already
happens here in a second, so the phone gets triangles.
"""

import json
import os
import sys

sys.path.insert(0, r"C:\ForgeMind")

import numpy as np

import cad
import glb

from bom import build_bom, part_signature


# The viewer needs a model to turn in the hand, not a master
# geometry: a coarser mesh than the drawing sheet uses keeps the
# download small enough to open over mobile data.
DEFLECTION_RATIO = 0.005
DEFLECTION_MIN = 0.08
DEFLECTION_MAX = 12.0

# Beyond this the file is too heavy for a phone, so the mesh gets
# coarser until it fits.
TARGET_TRIANGLES = 150000


def part_map(cad_file, parts):
    """What the viewer should say about each mesh it is given.

    The meshes go into the GLB in this order, so the viewer can
    look a clicked mesh straight up by its index. Everything in
    here the bot already worked out; the point of the Mini App is
    that a tap on a part shows it.
    """

    json_file = os.path.splitext(cad_file)[0] + ".json"

    try:

        with open(json_file, "r", encoding="utf-8") as f:
            data = json.load(f)

    except Exception:
        return []

    rows = build_bom(data)

    holes = {}

    for hole in data.get("holes", []):
        index = hole.get("part")
        holes[index] = holes.get(index, 0) + 1

    by_name = {}

    for part in data.get("parts", []):
        by_name[part.get("name")] = part

    # Identical parts share one position, and only one of them
    # carries its name, so the row is found by the same signature
    # the bill of materials grouped them with.
    positions = {}

    for row in rows:

        part = by_name.get(row["name"])

        if part is not None:
            positions[part_signature(part)] = row

    entries = []

    for obj in parts:

        part = by_name.get(obj.Name, {})

        row = positions.get(part_signature(part)) if part else None

        size = part.get("bounding_box", {}).get("size", {})

        entries.append({
            "name": obj.Name,
            "label": obj.Label or obj.Name,
            "position": row["position"] if row else None,
            "count": row["count"] if row else None,
            "holes": holes.get(part.get("index"), 0),
            "volume": part.get("volume_mm3"),
            "size": [
                size.get("x"),
                size.get("y"),
                size.get("z")
            ] if size else None
        })

    return entries


def build(cad_file, output_file):

    doc = cad.open_document(cad_file)

    parts = cad.solid_parts(doc)

    if not parts:
        return None, "no solid parts"

    low, high = cad.model_bounds(parts)

    diagonal = float(np.linalg.norm(high - low))

    deflection = cad.deflection_for(
        diagonal,
        DEFLECTION_RATIO,
        DEFLECTION_MIN,
        DEFLECTION_MAX
    )

    for attempt in range(4):

        scene = glb.Scene()

        triangles = 0

        for obj in parts:

            points, faces = cad.tessellate(obj.Shape, deflection)

            if points is None:
                continue

            triangles += len(faces)

            scene.add_part(points, faces, name=obj.Label or obj.Name)

        if triangles <= TARGET_TRIANGLES:
            break

        deflection *= 2.0

        print("TOO HEAVY:", triangles, "-> deflection", round(deflection, 3))

    print("DEFLECTION:", round(deflection, 3))
    print("TRIANGLES:", triangles)

    scene.save(output_file)

    with open(
        os.path.splitext(output_file)[0] + ".json",
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            {"parts": part_map(cad_file, parts)},
            f,
            ensure_ascii=False
        )

    return output_file, None


def main():

    if len(sys.argv) < 2:
        print("Usage: export_glb.py <cad_file>")
        sys.exit(1)

    cad_file = sys.argv[1]

    if not os.path.exists(cad_file):
        print("ERROR: file not found:", cad_file)
        sys.exit(1)

    output_file = os.path.splitext(cad_file)[0] + "_view.glb"

    print()
    print("=" * 90)
    print("FORGEMIND GLB EXPORT")
    print("=" * 90)
    print()

    result, error = build(cad_file, output_file)

    if result is None:
        print("ERROR:", error)
        sys.exit(1)

    print()
    print("GLB:", result)
    print("FILE SIZE:", os.path.getsize(result), "bytes")

    print()
    print("DONE")
    print("=" * 90)


if __name__ == "__main__":
    main()
