import json
import math
import os
import struct
import sys
import xml.etree.ElementTree as ElementTree
import zipfile

import numpy as np


# ============================================================
# CONFIGURATION
# ============================================================

# Vertices closer than this fraction of the model diagonal are
# treated as one. STL stores every triangle separately, so the
# mesh has to be welded before anything topological can be said
# about it.
WELD_RATIO = 1e-6

# Edges whose two faces diverge by more than this are drawn as
# feature edges by the renderer.
FEATURE_ANGLE_DEG = 30.0

# STL carries no units. Millimetres is the universal convention
# in this trade, and there is nothing in the file to check it
# against.
UNITS = "mm"


# ============================================================
# READING
# ============================================================

def read_binary_stl(path, count):

    dtype = np.dtype([
        ("normal", "<f4", (3,)),
        ("v", "<f4", (3, 3)),
        ("attr", "<u2")
    ])

    data = np.fromfile(
        path,
        dtype=dtype,
        offset=84,
        count=count
    )

    return data["v"].astype(np.float64)


def read_ascii_stl(path):

    values = []

    with open(path, "r", errors="replace") as f:

        for line in f:

            parts = line.split()

            if len(parts) >= 4 and parts[0].lower() == "vertex":

                try:
                    values.append((
                        float(parts[1]),
                        float(parts[2]),
                        float(parts[3])
                    ))
                except ValueError:
                    continue

    if len(values) < 3:
        return np.zeros((0, 3, 3))

    # Drop a trailing partial triangle rather than fail.
    usable = (len(values) // 3) * 3

    return np.array(
        values[:usable],
        dtype=np.float64
    ).reshape(-1, 3, 3)


def read_stl(path):
    """Returns triangles as an (T, 3, 3) array of raw coordinates.

    Binary files often start with the word "solid" too, so the
    format is decided by whether the declared triangle count
    matches the file size exactly.
    """

    size = os.path.getsize(path)

    with open(path, "rb") as f:
        head = f.read(84)

    if len(head) == 84:

        count = struct.unpack("<I", head[80:84])[0]

        if size == 84 + count * 50:
            return read_binary_stl(path, count)

    return read_ascii_stl(path)


# ------------------------------------------------------------
# OBJ
# ------------------------------------------------------------

def read_obj(path):
    """Wavefront OBJ. Only geometry is read; materials are not."""

    vertices = []
    faces = []

    with open(path, "r", errors="replace") as f:

        for line in f:

            parts = line.split()

            if not parts:
                continue

            tag = parts[0]

            if tag == "v" and len(parts) >= 4:

                try:
                    vertices.append((
                        float(parts[1]),
                        float(parts[2]),
                        float(parts[3])
                    ))
                except ValueError:
                    continue

            elif tag == "f" and len(parts) >= 4:

                corners = []

                for token in parts[1:]:

                    # "v", "v/vt", "v//vn" and "v/vt/vn" all
                    # start with the vertex index.
                    try:
                        index = int(token.split("/")[0])
                    except ValueError:
                        corners = []
                        break

                    # OBJ indices are 1-based, and negative ones
                    # count back from the current end.
                    if index < 0:
                        corners.append(len(vertices) + index)
                    else:
                        corners.append(index - 1)

                # Polygons are split into a triangle fan.
                for i in range(1, len(corners) - 1):
                    faces.append((
                        corners[0],
                        corners[i],
                        corners[i + 1]
                    ))

    if not vertices or not faces:
        return np.zeros((0, 3, 3))

    points = np.array(vertices, dtype=np.float64)
    index = np.array(faces, dtype=np.int64)

    valid = np.all(
        (index >= 0) & (index < len(points)),
        axis=1
    )

    return points[index[valid]]


# ------------------------------------------------------------
# 3MF
# ------------------------------------------------------------

def local_name(tag):

    return tag.rsplit("}", 1)[-1]


def parse_3mf_transform(text):
    """3MF stores a 4x3 row-major matrix as twelve numbers."""

    if not text:
        return None

    values = text.split()

    if len(values) != 12:
        return None

    try:
        numbers = [float(v) for v in values]
    except ValueError:
        return None

    return (
        np.array(numbers[:9], dtype=np.float64).reshape(3, 3),
        np.array(numbers[9:], dtype=np.float64)
    )


def read_3mf(path):
    """3MF: a zip holding an XML model.

    Object transforms are applied, so multi-body files land in
    the right places instead of stacking at the origin.
    """

    with zipfile.ZipFile(path) as archive:

        name = None

        for candidate in archive.namelist():
            if candidate.lower().endswith(".model"):
                name = candidate
                break

        if name is None:
            return np.zeros((0, 3, 3))

        root = ElementTree.fromstring(archive.read(name))

    objects = {}
    build = []

    for element in root.iter():

        if local_name(element.tag) != "object":
            continue

        object_id = element.get("id")

        if object_id is None:
            continue

        points = []
        index = []
        components = []

        for child in element.iter():

            kind = local_name(child.tag)

            if kind == "vertex":

                try:
                    points.append((
                        float(child.get("x", 0.0)),
                        float(child.get("y", 0.0)),
                        float(child.get("z", 0.0))
                    ))
                except ValueError:
                    continue

            elif kind == "triangle":

                try:
                    index.append((
                        int(child.get("v1")),
                        int(child.get("v2")),
                        int(child.get("v3"))
                    ))
                except (TypeError, ValueError):
                    continue

            elif kind == "component":

                components.append((
                    child.get("objectid"),
                    parse_3mf_transform(child.get("transform"))
                ))

        objects[object_id] = {
            "points": points,
            "index": index,
            "components": components
        }

    for element in root.iter():

        if local_name(element.tag) != "item":
            continue

        build.append((
            element.get("objectid"),
            parse_3mf_transform(element.get("transform"))
        ))

    # A file without a build section still has geometry worth
    # showing, so fall back to every object at its own origin.
    if not build:
        build = [(key, None) for key in objects]

    def collect(object_id, transform, depth=0):

        if depth > 8 or object_id not in objects:
            return []

        entry = objects[object_id]

        result = []

        if entry["points"] and entry["index"]:

            points = np.array(entry["points"], dtype=np.float64)
            index = np.array(entry["index"], dtype=np.int64)

            valid = np.all(
                (index >= 0) & (index < len(points)),
                axis=1
            )

            if transform is not None:
                matrix, offset = transform
                points = points @ matrix + offset

            result.append(points[index[valid]])

        for child_id, child_transform in entry["components"]:

            combined = child_transform

            if transform is not None and child_transform is not None:
                matrix, offset = transform
                child_matrix, child_offset = child_transform

                combined = (
                    child_matrix @ matrix,
                    child_offset @ matrix + offset
                )

            elif transform is not None:
                combined = transform

            result.extend(
                collect(child_id, combined, depth + 1)
            )

        return result

    meshes = []

    for object_id, transform in build:
        meshes.extend(collect(object_id, transform))

    if not meshes:
        return np.zeros((0, 3, 3))

    return np.concatenate(meshes)


# ------------------------------------------------------------
# DISPATCH
# ------------------------------------------------------------

READERS = {
    ".stl": read_stl,
    ".obj": read_obj,
    ".3mf": read_3mf
}


def read_mesh(path):

    extension = os.path.splitext(path)[1].lower()

    reader = READERS.get(extension)

    if reader is None:
        raise ValueError(f"unsupported mesh format: {extension}")

    return reader(path)


# ============================================================
# MESH TOPOLOGY
# ============================================================

def weld_vertices(tris):
    """Merges coincident corners into a shared vertex list."""

    flat = tris.reshape(-1, 3)

    span = flat.max(axis=0) - flat.min(axis=0)

    diagonal = float(np.linalg.norm(span))

    tolerance = max(diagonal * WELD_RATIO, 1e-9)

    keys = np.round(flat / tolerance).astype(np.int64)

    _, first, inverse = np.unique(
        keys,
        axis=0,
        return_index=True,
        return_inverse=True
    )

    inverse = inverse.reshape(-1)

    points = flat[first]
    faces = inverse.reshape(-1, 3)

    return points, faces


def face_normals(points, faces):

    v0 = points[faces[:, 0]]
    v1 = points[faces[:, 1]]
    v2 = points[faces[:, 2]]

    normals = np.cross(v1 - v0, v2 - v0)

    lengths = np.linalg.norm(normals, axis=1)

    areas = lengths / 2.0

    safe = np.where(lengths < 1e-15, 1.0, lengths)

    return normals / safe[:, None], areas


def build_edges(faces):
    """Edge table of the welded mesh.

    Returns the unique edges, how many faces each one has, and
    the two adjoining faces for the manifold ones.
    """

    triangle_count = len(faces)

    pairs = np.concatenate([
        faces[:, [0, 1]],
        faces[:, [1, 2]],
        faces[:, [2, 0]]
    ])

    pairs = np.sort(pairs, axis=1)

    unique, inverse, counts = np.unique(
        pairs,
        axis=0,
        return_inverse=True,
        return_counts=True
    )

    inverse = inverse.reshape(-1)

    face_of_entry = np.tile(
        np.arange(triangle_count),
        3
    )

    order = np.argsort(inverse, kind="stable")

    starts = np.concatenate([
        [0],
        np.cumsum(counts)[:-1]
    ])

    shared = counts == 2

    face_a = face_of_entry[order[starts[shared]]]
    face_b = face_of_entry[order[starts[shared] + 1]]

    return {
        "edges": unique,
        "counts": counts,
        "shared_mask": shared,
        "face_a": face_a,
        "face_b": face_b
    }


def feature_edges(points, faces, normals, edges):
    """Sharp edges plus mesh boundaries, for drawing.

    A mesh has no feature curves of its own, so the visible
    outline has to be derived from where the surface bends.
    """

    limit = math.cos(math.radians(FEATURE_ANGLE_DEG))

    dots = np.sum(
        normals[edges["face_a"]] * normals[edges["face_b"]],
        axis=1
    )

    sharp = edges["edges"][edges["shared_mask"]][dots < limit]

    boundary = edges["edges"][edges["counts"] == 1]

    if len(boundary):
        return np.concatenate([sharp, boundary])

    return sharp


# ============================================================
# MEASUREMENTS
# ============================================================

def mesh_volume(points, faces):
    """Signed tetrahedron sum; only meaningful if watertight."""

    v0 = points[faces[:, 0]]
    v1 = points[faces[:, 1]]
    v2 = points[faces[:, 2]]

    return abs(
        float(
            np.sum(v0 * np.cross(v1, v2)) / 6.0
        )
    )


def load_mesh(mesh_file):
    """Reads and welds an STL into shared geometry.

    Used by the analyzer and the renderer so both describe the
    same mesh.
    """

    tris = read_mesh(mesh_file)

    if len(tris) == 0:
        return None

    points, faces = weld_vertices(tris)

    normals, areas = face_normals(points, faces)

    edges = build_edges(faces)

    return {
        "points": points,
        "faces": faces,
        "normals": normals,
        "areas": areas,
        "edges": edges
    }


def analyze_mesh(mesh_file):

    result = {
        "file": os.path.abspath(mesh_file),
        "format": os.path.splitext(mesh_file)[1].lower().lstrip("."),
        "units": UNITS,
        "triangles": 0,
        "vertices": 0,
        "bounding_box": None,
        "surface_area_mm2": 0.0,
        "volume_mm3": 0.0,
        "mesh": {
            "closed": False,
            "watertight": False,
            "open_edges": 0,
            "non_manifold_edges": 0,
            "degenerate_triangles": 0
        }
    }

    mesh = load_mesh(mesh_file)

    if mesh is None:
        return result

    points = mesh["points"]
    faces = mesh["faces"]

    result["triangles"] = int(len(faces))
    result["vertices"] = int(len(points))

    low = points.min(axis=0)
    high = points.max(axis=0)

    result["bounding_box"] = {
        "min": {
            "x": round(float(low[0]), 3),
            "y": round(float(low[1]), 3),
            "z": round(float(low[2]), 3)
        },
        "max": {
            "x": round(float(high[0]), 3),
            "y": round(float(high[1]), 3),
            "z": round(float(high[2]), 3)
        },
        "size": {
            "x": round(float(high[0] - low[0]), 3),
            "y": round(float(high[1] - low[1]), 3),
            "z": round(float(high[2] - low[2]), 3)
        }
    }

    result["surface_area_mm2"] = round(
        float(mesh["areas"].sum()),
        3
    )

    counts = mesh["edges"]["counts"]

    open_edges = int(np.sum(counts == 1))
    non_manifold = int(np.sum(counts > 2))

    degenerate = int(np.sum(mesh["areas"] < 1e-12))

    # An unclosed surface has no enclosed volume, so open edges
    # are what invalidate it. Non-manifold edges usually just
    # mean several bodies touching in one file, which is normal
    # for an assembly exported as a single mesh.
    closed = open_edges == 0

    result["mesh"] = {
        "closed": closed,
        "watertight": closed and non_manifold == 0,
        "open_edges": open_edges,
        "non_manifold_edges": non_manifold,
        "degenerate_triangles": degenerate
    }

    if closed:
        result["volume_mm3"] = round(
            mesh_volume(points, faces),
            3
        )

    return result


# ============================================================
# OUTPUT
# ============================================================

def save_json(result, mesh_file):

    json_file = os.path.splitext(mesh_file)[0] + ".json"

    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    return json_file


# IMPORTANT: ASCII ONLY.
# The Windows console on this setup can use cp1251.
def print_summary(result):

    print()
    print("=" * 90)
    print("FORGEMIND MESH ANALYZER")
    print("=" * 90)
    print()

    print("FILE:", result["file"])
    print("TRIANGLES:", result["triangles"])
    print("VERTICES:", result["vertices"])

    bbox = result["bounding_box"]

    if bbox:
        print(
            "SIZE:",
            f'{bbox["size"]["x"]:.3f} x '
            f'{bbox["size"]["y"]:.3f} x '
            f'{bbox["size"]["z"]:.3f} mm'
        )

    print(
        "SURFACE AREA:",
        f'{result["surface_area_mm2"]:.3f}',
        "mm2"
    )

    mesh = result["mesh"]

    if mesh["closed"]:
        print(
            "VOLUME:",
            f'{result["volume_mm3"]:.3f}',
            "mm3"
        )
    else:
        print("VOLUME: n/a (mesh is not closed)")

    print()
    print("CLOSED:", mesh["closed"])
    print("WATERTIGHT:", mesh["watertight"])
    print("OPEN EDGES:", mesh["open_edges"])
    print("NON-MANIFOLD EDGES:", mesh["non_manifold_edges"])
    print("DEGENERATE TRIANGLES:", mesh["degenerate_triangles"])

    print()
    print("=" * 90)


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":

    if len(sys.argv) < 2:
        print("Usage: mesh_analyzer.py <mesh_file>")
        sys.exit(1)

    mesh_file = sys.argv[1]

    if not os.path.exists(mesh_file):
        print("ERROR: mesh file not found:")
        print(mesh_file)
        sys.exit(1)

    try:

        result = analyze_mesh(mesh_file)

        json_file = save_json(result, mesh_file)

        print_summary(result)

        print()
        print("JSON:", json_file)

    except Exception as e:

        print()
        print("ANALYSIS ERROR:")
        print(repr(e))

        raise
