"""Minimal glTF-binary writer for tessellated CAD parts.

Pure standard library: a GLB is a JSON chunk describing the scene
plus one binary chunk holding the vertex data, and both are easier
to write by hand than to pull a dependency in for.

Vertices are written per triangle rather than indexed. That costs
three times the points and buys the only shading a machined part
should have: a viewer with no normals in the file computes them
from the triangles it is given, so every facet stays flat instead
of being smoothed into a blob.
"""

import json
import struct


# ============================================================
# CONFIGURATION
# ============================================================

MAGIC = 0x46546C67
VERSION = 2

JSON_CHUNK = 0x4E4F534A
BINARY_CHUNK = 0x004E4942

ARRAY_BUFFER = 34962

FLOAT = 5126

# Parts are tinted so an assembly reads as separate pieces rather
# than one grey lump; the tints stay close together so it still
# looks like metal.
PALETTE = [
    (0.62, 0.66, 0.72),
    (0.70, 0.66, 0.60),
    (0.58, 0.65, 0.68),
    (0.68, 0.63, 0.66),
    (0.60, 0.68, 0.62),
    (0.72, 0.70, 0.64)
]

METALLIC = 0.25
ROUGHNESS = 0.55


def _pad(data, fill=b"\x00"):
    """Chunks and buffer views must both start on a 4-byte boundary."""

    remainder = len(data) % 4

    if remainder == 0:
        return data

    return data + fill * (4 - remainder)


class Scene:
    """Parts added one at a time, then written out as one GLB."""

    def __init__(self):

        self.blocks = []
        self.meshes = []
        self.materials = []

        self.offset = 0

    def add_part(self, points, faces, name=None, color=None):
        """Adds one tessellated solid as its own node.

        `points` and `faces` are the arrays FreeCAD's tessellate
        gives back: vertices, and triangles indexing into them.
        """

        if points is None or faces is None or len(faces) == 0:
            return

        flat = points[faces].reshape(-1, 3)

        minimum = flat.min(axis=0)
        maximum = flat.max(axis=0)

        data = flat.astype("<f4").tobytes()

        self.blocks.append(data)

        if color is None:
            color = PALETTE[len(self.meshes) % len(PALETTE)]

        self.materials.append({
            "name": (name or "part") + " material",
            "pbrMetallicRoughness": {
                "baseColorFactor": [color[0], color[1], color[2], 1.0],
                "metallicFactor": METALLIC,
                "roughnessFactor": ROUGHNESS
            },
            "doubleSided": True
        })

        self.meshes.append({
            "name": name or "part {}".format(len(self.meshes) + 1),
            "count": len(flat),
            "offset": self.offset,
            "length": len(data),
            "min": [float(v) for v in minimum],
            "max": [float(v) for v in maximum]
        })

        self.offset += len(data)

    def _document(self):

        views = []
        accessors = []
        meshes = []
        nodes = []

        for index, mesh in enumerate(self.meshes):

            views.append({
                "buffer": 0,
                "byteOffset": mesh["offset"],
                "byteLength": mesh["length"],
                "target": ARRAY_BUFFER
            })

            accessors.append({
                "bufferView": index,
                "componentType": FLOAT,
                "count": mesh["count"],
                "type": "VEC3",
                "min": mesh["min"],
                "max": mesh["max"]
            })

            meshes.append({
                "name": mesh["name"],
                "primitives": [{
                    "attributes": {"POSITION": index},
                    "material": index
                }]
            })

            nodes.append({"mesh": index, "name": mesh["name"]})

        return {
            "asset": {
                "version": "2.0",
                "generator": "ForgeMind"
            },
            "scene": 0,
            "scenes": [{"nodes": list(range(len(nodes)))}],
            "nodes": nodes,
            "meshes": meshes,
            "materials": self.materials,
            "accessors": accessors,
            "bufferViews": views,
            "buffers": [{"byteLength": self.offset}]
        }

    def save(self, path):

        if not self.meshes:
            raise ValueError("nothing to write")

        binary = _pad(b"".join(self.blocks))

        text = _pad(
            json.dumps(
                self._document(),
                separators=(",", ":")
            ).encode("utf-8"),
            b" "
        )

        total = 12 + 8 + len(text) + 8 + len(binary)

        with open(path, "wb") as f:

            f.write(struct.pack("<III", MAGIC, VERSION, total))

            f.write(struct.pack("<II", len(text), JSON_CHUNK))
            f.write(text)

            f.write(struct.pack("<II", len(binary), BINARY_CHUNK))
            f.write(binary)

        return path
