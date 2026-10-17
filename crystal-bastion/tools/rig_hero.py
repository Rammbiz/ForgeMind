#!/usr/bin/env python3
"""Rigs a static Meshy hero GLB (A-pose) with a simple humanoid skeleton.

    python3 tools/rig_hero.py <in.glb> <rig.json> <out.glb> [--debug-colors debug.glb]

With --debug-colors the tool writes debug.glb instead of out.glb: no skin, vertices coloured
by their bone weights, to check the rig in any viewer.

The input is a single textured mesh (run tools/prepare_hero.mjs first to shrink it). The rig
file names the bones and where their joints sit, in a frame where the model stands with its
feet at y = 0, is 1 unit tall and faces +Z (Meshy's orientation). The output GLB has the mesh
in that frame, moved so the hips are above the origin, plus a skin: bones with identity rest
rotations (so a pose rotation is about the model's own axes) and four weights per vertex.
The game animates the bones in code (Models.animate_rig), so the file carries no clips.

Rig file:
  "bones":  [{"name", "parent", "head": [x, y, z], "tail": [x, y, z] (leaf bones only)}]
            "*.L" bones are mirrored to "*.R" (x negated) unless "*.R" is listed too.
  "torso":  bone names from the hips up; vertices that no limb claims blend along this chain.
  "limbs":  [{"bones": [...], "parent": bone, "radius": [r per joint, incl. the end],
             "root_blend": b, "blend": b, "normal": [x, y, z] (optional), "falloff": f}]
            A vertex belongs to a limb when it is past the plane through the limb's first
            joint (normal: "normal" or the first bone's direction, softened over root_blend)
            and within radius * falloff of the limb's bone chain (fading out from 1 to falloff).
            "split_x": b keeps a limb on its own side of x = 0 (blended over b), for legs.
            "*.L" limbs are mirrored too.

Weights are a function of position only, so the vertices Meshy splits along UV seams keep
identical weights and the skin never tears. A few rounds of smoothing over the mesh edges
then soften the cut lines.
"""

import json
import struct
import sys

import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# ------------------------------------------------------------------ GLB io

def read_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", d[off:off + 4])[0]
    return j, d[off + 8: off + 8 + bl]


def accessor(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = NC[a["type"]]
    dt = np.dtype(CT[a["componentType"]])
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or n * dt.itemsize
    count = a["count"]
    raw = np.frombuffer(b, dtype=np.uint8, count=stride * (count - 1) + n * dt.itemsize, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(count, n * dt.itemsize), strides=(stride, 1))
    out = np.ascontiguousarray(rows).view(dt).reshape(count, n)
    if a.get("normalized"):
        out = out.astype(np.float32) / np.iinfo(dt).max
    return out if n > 1 else out[:, 0]


def image_bytes(j, b, img):
    bv = j["bufferViews"][img["bufferView"]]
    s = bv.get("byteOffset", 0)
    return b[s: s + bv["byteLength"]]


class Writer:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            v["target"] = target
        self.bin += data
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr.astype(CT[ctype]))
        a = {"bufferView": self.view(arr.tobytes(), target), "componentType": ctype,
             "count": int(arr.shape[0]), "type": atype}
        if minmax:
            flat = arr.reshape(arr.shape[0], -1)
            a["min"] = [float(x) for x in flat.min(0)]
            a["max"] = [float(x) for x in flat.max(0)]
        self.accessors.append(a)
        return len(self.accessors) - 1


def write_glb(path, j):
    bn = bytes(j.pop("_bin"))
    bn += b"\0" * ((4 - len(bn) % 4) % 4)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(bn)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(bn), 0x004E4942))
        f.write(bn)


# ------------------------------------------------------------------ rig spec

def mirror_name(n):
    return n[:-2] + ".R" if n.endswith(".L") else n


def expand(spec):
    bones = []
    names = {b["name"] for b in spec["bones"]}
    for b in spec["bones"]:
        bones.append(b)
    for b in spec["bones"]:
        if b["name"].endswith(".L") and mirror_name(b["name"]) not in names:
            m = {"name": mirror_name(b["name"]), "parent": mirror_name(b["parent"]),
                 "head": [-b["head"][0], b["head"][1], b["head"][2]]}
            if "tail" in b:
                m["tail"] = [-b["tail"][0], b["tail"][1], b["tail"][2]]
            bones.append(m)
    limbs = []
    for l in spec["limbs"]:
        limbs.append(l)
        if any(n.endswith(".L") for n in l["bones"]):
            m = dict(l)
            m["bones"] = [mirror_name(n) for n in l["bones"]]
            m["parent"] = mirror_name(l["parent"])
            if "normal" in l:
                m["normal"] = [-l["normal"][0], l["normal"][1], l["normal"][2]]
            limbs.append(m)
    return bones, limbs


def bone_tail(bones, i):
    b = bones[i]
    if "tail" in b:
        return np.array(b["tail"], float)
    kids = [k for k in bones if k["parent"] == b["name"]]
    if len(kids) != 1 and b["name"] not in ("root",):
        # More than one child (chest): the tail is the child on the bone's own chain, i.e. the
        # one closest to straight above/along. Callers only use tails for chain bones.
        kids = sorted(kids, key=lambda k: abs(k["head"][0]))
    return np.array(kids[0]["head"], float)


# ------------------------------------------------------------------ weights

def smoothstep(a, b, x):
    t = np.clip((x - a) / max(b - a, 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def chain_fit(P, pts, tau=0.01):
    """Arc parameter along a polyline (soft-min over segments, so it is continuous) and the
    distance to it."""
    segs = []
    cum = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        cum.append(cum[-1] + np.linalg.norm(b - a))
    dists = []
    params = []
    for k, (a, b) in enumerate(zip(pts[:-1], pts[1:])):
        ab = b - a
        L2 = float(ab @ ab)
        t = (P - a) @ ab / L2
        lo = -np.inf if k == 0 else 0.0
        hi = np.inf if k == len(pts) - 2 else 1.0
        tc = np.clip(t, 0.0, 1.0)
        d = np.linalg.norm(P - (a + tc[:, None] * ab), axis=1)
        dists.append(d)
        params.append(cum[k] + np.clip(t, lo, hi) * np.sqrt(L2))
    D = np.stack(dists, 1)
    S = np.stack(params, 1)
    dmin = D.min(1)
    w = np.exp(-(D - dmin[:, None]) / tau)
    s = (S * w).sum(1) / w.sum(1)
    return s, dmin, np.array(cum)


def chain_weights(s, cum, blend):
    """Partition of unity over the bones of a chain from the arc parameter."""
    n = len(cum) - 1
    steps = [np.ones_like(s)]
    for k in range(1, n):
        steps.append(smoothstep(cum[k] - blend, cum[k] + blend, s))
    steps.append(np.zeros_like(s))
    return [steps[k] - steps[k + 1] for k in range(n)]


def compute_weights(P, bones, limbs, torso, adjacency, smooth_iters):
    idx = {b["name"]: i for i, b in enumerate(bones)}
    W = np.zeros((len(P), len(bones)))
    # Torso: blend along the hips -> chest chain.
    tpts = [np.array(bones[idx[n]]["head"], float) for n in torso] + [bone_tail(bones, idx[torso[-1]])]
    s, _, cum = chain_fit(P, tpts)
    torso_w = chain_weights(s, cum, 0.03)
    infl_total = np.zeros(len(P))
    limb_parts = []
    for l in limbs:
        pts = [np.array(bones[idx[n]]["head"], float) for n in l["bones"]] + [bone_tail(bones, idx[l["bones"][-1]])]
        s, dist, cum = chain_fit(P, pts)
        normal = np.array(l.get("normal", pts[1] - pts[0]), float)
        normal /= np.linalg.norm(normal)
        plane = (P - pts[0]) @ normal
        rb = float(l.get("root_blend", 0.03))
        inside = smoothstep(-rb, rb, plane)
        radius = np.interp(s, cum, l["radius"])
        q = dist / radius
        mask = 1.0 - smoothstep(1.0, float(l.get("falloff", 1.3)), q)
        infl = inside * mask
        if "split_x" in l:
            # Left/right limbs that share a root plane (legs) stay on their own side.
            side = 1.0 if pts[0][0] >= 0.0 else -1.0
            sb = float(l["split_x"])
            infl = infl * smoothstep(-sb, sb, P[:, 0] * side)
        infl_total += infl
        limb_parts.append((l, infl, chain_weights(s, cum, float(l.get("blend", 0.02)))))
    scale = np.where(infl_total > 1.0, 1.0 / np.maximum(infl_total, 1e-9), 1.0)
    rest = 1.0 - np.minimum(infl_total, 1.0)
    for name, w in zip(torso, torso_w):
        W[:, idx[name]] += rest * w
    for l, infl, cw in limb_parts:
        f = infl * scale
        for name, w in zip(l["bones"], cw):
            W[:, idx[name]] += f * w
    # Soften the cut lines along the mesh edges.
    for _ in range(smooth_iters):
        W = 0.5 * W + 0.5 * adjacency @ W
    return W


def top4(W):
    order = np.argsort(-W, axis=1)[:, :4]
    w = np.take_along_axis(W, order, 1)
    w = np.where(w < 0.02, 0.0, w)
    w /= w.sum(1, keepdims=True)
    return order.astype(np.uint8), w.astype(np.float32)


def unique_adjacency(P, tris):
    """Row-normalised vertex adjacency over unique positions (seam duplicates merged)."""
    from scipy.sparse import coo_matrix
    key = np.round(P, 6)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    t = inv[tris]
    rows = np.concatenate([t[:, 0], t[:, 1], t[:, 2], t[:, 1], t[:, 2], t[:, 0]])
    cols = np.concatenate([t[:, 1], t[:, 2], t[:, 0], t[:, 0], t[:, 1], t[:, 2]])
    n = int(inv.max()) + 1
    A = coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).reshape(-1)
    deg[deg == 0] = 1.0
    from scipy.sparse import diags
    return diags(1.0 / deg) @ A, inv


# ------------------------------------------------------------------ main

DEBUG_PALETTE = [
    (0.6, 0.6, 0.6), (1, 0.2, 0.2), (0.2, 0.9, 0.2), (0.2, 0.4, 1), (1, 0.9, 0.2), (1, 0.3, 1),
    (0.2, 1, 1), (1, 0.6, 0.2), (0.6, 0.3, 1), (0.4, 1, 0.6), (1, 0.6, 0.7), (0.5, 0.35, 0.2),
    (0.9, 0.9, 0.9), (0.1, 0.5, 0.3), (0.5, 0.1, 0.2), (0.3, 0.3, 0.7), (0.8, 0.8, 0.4),
    (0.2, 0.7, 0.9), (0.9, 0.4, 0.1), (0.4, 0.9, 0.1), (0.7, 0.2, 0.9), (0.1, 0.9, 0.6),
]


def main():
    args = sys.argv[1:]
    debug = None
    if "--debug-colors" in args:
        k = args.index("--debug-colors")
        debug = args[k + 1]
        del args[k:k + 2]
    src, rig_path, out = args
    spec = json.load(open(rig_path))
    j, b = read_glb(src)
    prim = j["meshes"][0]["primitives"][0]
    P = accessor(j, b, prim["attributes"]["POSITION"]).astype(np.float64)
    N = accessor(j, b, prim["attributes"]["NORMAL"]).astype(np.float32)
    UV = accessor(j, b, prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
    I = accessor(j, b, prim["indices"]).astype(np.uint32)
    node = j["nodes"][j["scenes"][0]["nodes"][0]]
    if any(k in node for k in ("rotation", "scale", "matrix", "translation")):
        sys.exit("expected an untransformed mesh node")

    # Feet at 0, height 1 (the frame the rig file is written in).
    lo, hi = P.min(0), P.max(0)
    H = hi[1] - lo[1]
    P = (P - np.array([0.0, lo[1], 0.0])) / H

    bones, limbs = expand(spec)
    idx = {bb["name"]: i for i, bb in enumerate(bones)}
    tris = I.reshape(-1, 3)
    A, inv = unique_adjacency(P, tris)
    Pu = np.zeros((A.shape[0], 3))
    Pu[inv] = P
    Wu = compute_weights(Pu, bones, limbs, spec["torso"], A, int(spec.get("smooth", 4)))
    W = Wu[inv]
    J4, W4 = top4(W)

    # Centre the hips over the origin.
    hips = np.array(bones[idx[spec["torso"][0]]]["head"], float)
    shift = np.array([hips[0], 0.0, hips[2]])
    P = P - shift
    heads = {bb["name"]: np.array(bb["head"], float) - shift for bb in bones}

    w = Writer()
    attrs = {
        "POSITION": w.accessor(P.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": w.accessor(N, 5126, "VEC3", 34962),
        "TEXCOORD_0": w.accessor(UV, 5126, "VEC2", 34962),
    }
    if debug is None:
        attrs["JOINTS_0"] = w.accessor(J4, 5121, "VEC4", 34962)
        attrs["WEIGHTS_0"] = w.accessor(W4, 5126, "VEC4", 34962)
    else:
        pal = np.array([DEBUG_PALETTE[i % len(DEBUG_PALETTE)] for i in range(len(bones))], np.float32)
        col = (W[:, :, None] * pal[None, :, :]).sum(1)
        attrs["COLOR_0"] = w.accessor(np.c_[col, np.ones(len(col))].astype(np.float32), 5126, "VEC4", 34962)
    indices = w.accessor(I, 5125, "SCALAR", 34963)

    # Material, textures and images, copied as they are.
    # Images are named by role, so Godot extracts them as <hero>_albedo.jpg / <hero>_normal.jpg.
    roles = {}
    for mat in j.get("materials", []):
        for role, ref in (("albedo", mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")),
                          ("normal", mat.get("normalTexture"))):
            if ref is not None:
                roles[j["textures"][ref["index"]]["source"]] = role
    images = []
    for i, img in enumerate(j.get("images", [])):
        images.append({"bufferView": w.view(image_bytes(j, b, img)), "mimeType": img["mimeType"],
                       "name": roles.get(i, "image%d" % i)})
    materials = j.get("materials", [])
    if debug is not None:
        materials = [{"pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.9}}]

    nodes = [{"name": "HeroMesh", "mesh": 0}]
    joint_nodes = []
    for bb in bones:
        joint_nodes.append(len(nodes))
        parent = bb["parent"]
        local = heads[bb["name"]] - (heads[parent] if parent else np.zeros(3))
        nodes.append({"name": bb["name"], "translation": [float(x) for x in local]})
    for bb in bones:
        if bb["parent"]:
            pn = nodes[joint_nodes[idx[bb["parent"]]]]
            pn.setdefault("children", []).append(joint_nodes[idx[bb["name"]]])
    roots = [joint_nodes[i] for i, bb in enumerate(bones) if not bb["parent"]]
    out_j = {
        "asset": {"version": "2.0", "generator": "crystal-bastion rig_hero.py"},
        "scene": 0,
        "scenes": [{"nodes": roots + [0]}],
        "nodes": nodes,
        "meshes": [{"name": "Hero", "primitives": [{"attributes": attrs, "indices": indices, "material": 0}]}],
        "materials": materials,
    }
    if debug is None:
        ibm = []
        for bb in bones:
            m = np.eye(4)
            m[:3, 3] = -heads[bb["name"]]
            ibm.append(m.T.reshape(-1))  # column-major
        out_j["skins"] = [{"inverseBindMatrices": w.accessor(np.array(ibm, np.float32), 5126, "MAT4"),
                           "joints": joint_nodes, "skeleton": roots[0]}]
        nodes[0]["skin"] = 0
        out_j["images"] = images
        out_j["textures"] = j.get("textures", [])
        if "samplers" in j:
            out_j["samplers"] = j["samplers"]
    out_j["accessors"] = w.accessors
    out_j["bufferViews"] = w.views
    out_j["buffers"] = [{"byteLength": len(w.bin)}]
    out_j["_bin"] = w.bin
    write_glb(debug or out, out_j)
    used = sorted({int(x) for x in J4[W4 > 0.0]})
    print(f"{debug or out}: {len(P)} verts, {len(tris)} tris, {len(bones)} bones "
          f"({len(used)} with weights), height 1.0, hips at {np.round(hips, 3).tolist()}")


if __name__ == "__main__":
    main()
