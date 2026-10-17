#!/usr/bin/env python3
"""Fit a sculpted arena model (Meshy image-to-3D GLB) onto a level's gameplay grid.

The arena concept art shows the same floating island and path as the level, so the
model only has to be levelled, rotated, scaled and moved until its painted path sits on
the path cells of the map. The fit is written next to the model and read by
scripts/game/arena.gd:

    assets/models/arenas/<level>.glb    the model (optimised GLB)
    assets/models/arenas/<level>.json   model -> map transform, per-cell heights, options

Usage:
    python3 tools/fit_arena.py meadow [--debug /tmp/fit] [--yaw 0 --sx 8 --sz 8 --dx 0 --dz 0]
                               [--path-cluster N] [--keep decor,water] [--lift 0.0]

Needs numpy, pillow, scipy and trimesh (pip install trimesh scipy pillow).
"""

import argparse
import json
import math
import os
import re
import sys

import numpy as np
import trimesh
from PIL import Image, ImageDraw
from scipy.cluster.vq import kmeans2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARENAS = os.path.join(ROOT, "assets", "models", "arenas")
GAME_DATA = os.path.join(ROOT, "scripts", "autoload", "game_data.gd")


# ----------------------------------------------------------------------------- level data

def read_level(level_id):
    """Map rows and theme colours of a level, parsed straight from game_data.gd."""
    src = open(GAME_DATA, encoding="utf-8").read()
    start = src.find('"id": "%s"' % level_id)
    if start < 0:
        sys.exit("level %r not found in game_data.gd" % level_id)
    block = src[start:]
    nxt = block.find('"id": "', 10)
    if nxt > 0:
        block = block[:nxt]
    m = re.search(r'"map":\s*\[(.*?)\]', block, re.S)
    rows = re.findall(r'"([^"]*)"', m.group(1))

    def colour(key):
        mm = re.search(r'"%s":\s*Color\(([^)]*)\)' % key, block)
        if not mm:
            return None
        v = [float(x) for x in mm.group(1).split(",")]
        return np.array(v[:3])

    return rows, {"path": colour("path"), "grass": colour("grass_a")}


def grid_masks(rows):
    h = len(rows)
    w = max(len(r) for r in rows)
    kind = np.full((h, w), "x", dtype="<U1")
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            kind[y, x] = ch
    path = np.isin(kind, ["#", "S", "C"])
    land = kind != "x"
    return kind, path, land, w, h


# ----------------------------------------------------------------------------- geometry

def load_mesh(path):
    scene = trimesh.load(path, force="scene", process=False)
    meshes = []
    for name, geom in scene.geometry.items():
        for node in scene.graph.geometry_nodes.get(name, []):
            g = geom.copy()
            g.apply_transform(scene.graph.get(node)[0])
            meshes.append(g)
    if not meshes:
        sys.exit("no meshes in %s" % path)
    return meshes


def face_colours(mesh):
    """Average base colour of every face, sampled from the base colour texture."""
    vis = mesh.visual
    n = len(mesh.faces)
    try:
        img = vis.material.baseColorTexture
        uv = vis.uv
    except AttributeError:
        img, uv = None, None
    if img is None or uv is None:
        try:
            return vis.face_colors[:, :3].astype(np.float64) / 255.0
        except Exception:
            return np.full((n, 3), 0.5)
    tri_uv = uv[mesh.faces]                      # (n, 3, 2)
    samples = [tri_uv.mean(axis=1)] + [tri_uv[:, i] * 0.6 + tri_uv.mean(axis=1) * 0.4 for i in range(3)]
    acc = np.zeros((n, 3))
    for s in samples:
        acc += trimesh.visual.color.uv_to_color(s, img)[:, :3] / 255.0
    return acc / len(samples)


def rotation_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else np.diag([1.0, -1.0, -1.0])
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def dominant_up(normals, areas):
    """Area-weighted mean normal of the island top (the big flat surface facing up)."""
    n = np.array([0.0, 1.0, 0.0])
    for cone in (0.5, 0.75, 0.88, 0.94, 0.96):
        sel = normals @ n > cone
        if areas[sel].sum() <= 0:
            break
        m = (normals[sel] * areas[sel, None]).sum(axis=0)
        n = m / np.linalg.norm(m)
    return n


def yaw_matrix(deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    # Rotation about +Y (Godot convention: x' = c*x + s*z, z' = -s*x + c*z).
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


# ----------------------------------------------------------------------------- alignment

def score(px, pz, pw, gx, gz, gw, path, land, w, h, tw):
    """F-score of painted path points against the path cells (plus grass penalty)."""
    cx = np.floor(px + w * 0.5).astype(int)
    cz = np.floor(pz + h * 0.5).astype(int)
    ok = (cx >= 0) & (cx < w) & (cz >= 0) & (cz < h)
    hit = np.zeros(pw.shape, bool)
    hit[ok] = path[cz[ok], cx[ok]]
    precision = pw[hit].sum() / tw
    cell_w = np.zeros((h, w))
    np.add.at(cell_w, (cz[ok], cx[ok]), pw[ok])
    expect = tw / max(path.sum(), 1)
    coverage = (cell_w[path] > expect * 0.25).mean()
    gcx = np.floor(gx + w * 0.5).astype(int)
    gcz = np.floor(gz + h * 0.5).astype(int)
    gok = (gcx >= 0) & (gcx < w) & (gcz >= 0) & (gcz < h)
    ghit = np.zeros(gw.shape, bool)
    ghit[gok] = path[gcz[gok], gcx[gok]]
    grass_in_path = gw[ghit].sum() / max(gw.sum(), 1e-9)
    f = 2 * precision * coverage / max(precision + coverage, 1e-9)
    return f - grass_in_path * 0.5


# ----------------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("level")
    ap.add_argument("--glb")
    ap.add_argument("--debug", help="directory for debug images")
    ap.add_argument("--yaw", type=float)
    ap.add_argument("--sx", type=float, help="model->map scale along x (with --yaw --sz --dx --dz: skip the search)")
    ap.add_argument("--sz", type=float, help="model->map scale along z")
    ap.add_argument("--dx", type=float)
    ap.add_argument("--dz", type=float)
    ap.add_argument("--lift", type=float, default=0.0, help="extra vertical offset of the model")
    ap.add_argument("--path-cluster", help="comma list of colour clusters that form the path (see debug output)")
    ap.add_argument("--clusters", type=int, default=6)
    ap.add_argument("--keep", default="", help="procedural parts kept on top: decor,water,portal_base,crystal_base,clouds")
    ap.add_argument("--no-level", action="store_true", help="skip auto levelling")
    ap.add_argument("--grid-strength", type=float, default=0.22)
    ap.add_argument("--tint", default="ffffff")
    args = ap.parse_args()

    glb = args.glb or os.path.join(ARENAS, args.level + ".glb")
    rows, theme = read_level(args.level)
    kind, path, land, w, h = grid_masks(rows)

    meshes = load_mesh(glb)
    verts, faces, cols = [], [], []
    base = 0
    for m in meshes:
        verts.append(np.asarray(m.vertices, float))
        faces.append(np.asarray(m.faces) + base)
        cols.append(face_colours(m))
        base += len(m.vertices)
    V = np.concatenate(verts)
    F = np.concatenate(faces)
    C = np.concatenate(cols)
    mesh = trimesh.Trimesh(V, F, process=False)
    normals = mesh.face_normals
    areas = mesh.area_faces
    print("model: %d verts, %d faces, bounds %s" % (len(V), len(F), np.round(mesh.bounds, 3).tolist()))

    # 1. Level the island top.
    up = np.array([0.0, 1.0, 0.0]) if args.no_level else dominant_up(normals, areas)
    R = rotation_between(up, np.array([0.0, 1.0, 0.0]))
    tilt = math.degrees(math.acos(max(-1.0, min(1.0, up[1]))))
    print("top normal %s -> tilt %.1f deg" % (np.round(up, 3).tolist(), tilt))
    LV = V @ R.T
    centroids = LV[F].mean(axis=1)
    ln = normals @ R.T

    # 2. Ground level: most common height of up-facing area.
    flat = ln[:, 1] > 0.85
    ys = centroids[flat, 1]
    hist, edges = np.histogram(ys, bins=240, weights=areas[flat])
    k = int(hist.argmax())
    lo, hi = edges[max(k - 2, 0)], edges[min(k + 3, len(edges) - 1)]
    sel = flat & (centroids[:, 1] >= lo) & (centroids[:, 1] <= hi)
    ground = float(np.average(centroids[sel, 1], weights=areas[sel]))
    xz = LV[:, [0, 2]]
    tol = 0.04 * float((xz.max(axis=0) - xz.min(axis=0)).max())
    on_ground = flat & (np.abs(centroids[:, 1] - ground) < tol)
    gxz = centroids[on_ground][:, [0, 2]]
    centre = np.array([np.median(gxz[:, 0]), ground, np.median(gxz[:, 1])])
    ext = np.percentile(gxz, 98, axis=0) - np.percentile(gxz, 2, axis=0)
    print("ground y=%.4f  ground footprint %.3f x %.3f (model units)" % (ground, ext[0], ext[1]))

    # 3. Colour clusters of the ground surface (one of them is the painted path).
    gc = C[on_ground]
    ga = areas[on_ground]
    rng = np.random.default_rng(1)
    pick = rng.choice(len(gc), size=min(len(gc), 20000), replace=False, p=ga / ga.sum())
    cents, _ = kmeans2(gc[pick], args.clusters, minit="++", seed=7)
    d = ((gc[:, None, :] - cents[None, :, :]) ** 2).sum(axis=2)
    lab = d.argmin(axis=1)
    frac = np.array([ga[lab == i].sum() for i in range(len(cents))]) / ga.sum()
    target = theme["path"] if theme["path"] is not None else np.array([0.8, 0.7, 0.5])
    for i, c in enumerate(cents):
        print("  cluster %d: rgb %s  area %.1f%%" % (i, np.round(c, 3).tolist(), frac[i] * 100))
    land_w = land.any(axis=0).sum()
    s0 = land_w / max(ext.max(), 1e-6)
    rel = centroids[on_ground] - centre
    cells = np.argwhere(path)
    mcx = float((cells[:, 1] + 0.5 - w * 0.5).mean())
    mcz = float((cells[:, 0] + 0.5 - h * 0.5).mean())

    def align(is_path):
        """Best (score, (yaw, kx, kz, dx, dz)) for a painted-path mask of the ground faces."""
        pts, pw = rel[is_path], ga[is_path]
        gpts, gw = rel[~is_path], ga[~is_path]
        if len(pts) > 6000:
            i = rng.choice(len(pts), 6000, replace=False, p=pw / pw.sum())
            pts, pw = pts[i], np.full(6000, pw.sum() / 6000)
        if len(gpts) > 6000:
            i = rng.choice(len(gpts), 6000, replace=False, p=gw / gw.sum())
            gpts, gw = gpts[i], np.full(6000, gw.sum() / 6000)
        tw = pw.sum()
        rot_cache = {}

        def evaluate(yaw, kx, kz, dx, dz):
            key = round(float(yaw), 3)
            if key not in rot_cache:
                r = yaw_matrix(yaw)
                rot_cache[key] = (pts @ r.T, gpts @ r.T)
            rp, rg = rot_cache[key]
            return score(rp[:, 0] * kx + dx, rp[:, 2] * kz + dz, pw, rg[:, 0] * kx + dx, rg[:, 2] * kz + dz,
                         gw, path, land, w, h, tw)

        if None not in (args.yaw, args.sx, args.sz, args.dx, args.dz):
            return evaluate(args.yaw, args.sx, args.sz, args.dx, args.dz), (args.yaw, args.sx, args.sz, args.dx, args.dz)
        # Coarse: for every yaw and every (scale, aspect) pair, put the painted path's centroid
        # on the map path's centroid and score. The island rim can be much wider than the
        # playable grid and image-to-3D often stretches depth, so both are searched widely.
        yaws = [args.yaw] if args.yaw is not None else list(np.arange(0, 360, 4.0))
        f, best = -1e9, None
        for y2 in yaws:
            rp = pts @ yaw_matrix(y2).T
            pcx = float(np.average(rp[:, 0], weights=pw))
            pcz = float(np.average(rp[:, 2], weights=pw))
            for kx2 in s0 * np.geomspace(0.6, 2.2, 28):
                for asp in np.arange(0.6, 1.66, 0.05):
                    kz2 = kx2 * asp
                    dx2, dz2 = mcx - kx2 * pcx, mcz - kz2 * pcz
                    f2 = evaluate(y2, kx2, kz2, dx2, dz2)
                    if f2 > f:
                        f, best = f2, (y2, kx2, kz2, dx2, dz2)
        yaw, kx, kz, dx, dz = best
        # Fine: coordinate descent over (kx, dx), (kz, dz) and yaw until nothing improves.
        for _ in range(6):
            before = f
            for axis in ("x", "z"):
                k0, d0 = (kx, dx) if axis == "x" else (kz, dz)
                for k2 in k0 * np.arange(0.8, 1.2501, 0.025):
                    for d2 in np.arange(d0 - 0.6, d0 + 0.601, 0.05):
                        f2 = evaluate(yaw, k2, kz, d2, dz) if axis == "x" else evaluate(yaw, kx, k2, dx, d2)
                        if f2 > f + 1e-9:
                            f = f2
                            if axis == "x":
                                kx, dx = k2, d2
                            else:
                                kz, dz = k2, d2
            for y2 in np.arange(yaw - 3, yaw + 3.01, 0.5):
                f2 = evaluate(y2, kx, kz, dx, dz)
                if f2 > f + 1e-9:
                    f, yaw = f2, y2
            if f <= before + 1e-6:
                break
        return f, (yaw, kx, kz, dx, dz)

    # 4. Which colour is the path? Try every plausible cluster (plus clusters of almost the
    # same colour) and keep the one whose layout fits the map path best.
    if args.path_cluster:
        candidates = [[int(v) for v in args.path_cluster.split(",")]]
    else:
        candidates = []
        order = np.argsort(np.sqrt(((cents - target) ** 2).sum(axis=1)))
        for i in order:
            if not 0.05 <= frac[i] <= 0.5:
                continue
            group = sorted(j for j in range(len(cents)) if np.linalg.norm(cents[j] - cents[i]) < 0.12)
            if group not in candidates and sum(frac[j] for j in group) <= 0.5:
                candidates.append(group)
    f, params, pcs = -1e9, None, None
    for group in candidates:
        f2, p2 = align(np.isin(lab, group))
        print("  path = clusters %s: score %.3f" % (group, f2))
        if f2 > f:
            f, params, pcs = f2, p2, group
    yaw, kx, kz, dx, dz = params
    pc = pcs[0]
    print("path clusters: %s" % pcs)
    ky = math.sqrt(kx * kz)
    print("fit: yaw %.1f  scale x %.4f z %.4f (aspect %.3f)  offset (%.2f, %.2f)  score %.3f"
          % (yaw, kx, kz, kz / kx, dx, dz, f))

    # 5. Model -> map transform: level, centre, yaw, scale, offset; ground to y = 0.
    Y = yaw_matrix(yaw)
    S = np.diag([kx, ky, kz])
    B = S @ Y @ R
    origin = -S @ (Y @ centre) + np.array([dx, args.lift, dz])
    world = V @ B.T + origin

    # 6. Surface height of each cell (low quantile of a few rays, so foliage does not lift towers).
    wm = trimesh.Trimesh(world, F, process=False)
    ray = trimesh.ray.ray_triangle.RayMeshIntersector(wm)
    offs = [(0, 0), (0.22, 0.22), (-0.22, 0.22), (0.22, -0.22), (-0.22, -0.22)]
    heights = []
    origins, cells = [], []
    for y in range(h):
        for x in range(w):
            for ox, oz in offs:
                origins.append([x - w * 0.5 + 0.5 + ox, 50.0, y - h * 0.5 + 0.5 + oz])
                cells.append((y, x))
    origins = np.array(origins)
    dirs = np.tile([0.0, -1.0, 0.0], (len(origins), 1))
    locs, idx_ray, _ = ray.intersects_location(origins, dirs, multiple_hits=False)
    hits = {}
    for loc, ir in zip(locs, idx_ray):
        hits.setdefault(cells[ir], []).append(loc[1])
    for y in range(h):
        row = []
        for x in range(w):
            v = hits.get((y, x))
            if not v or kind[y, x] == "x":
                row.append(None)
                continue
            v = sorted(v)
            q = v[0] if kind[y, x] in ("t", "r") else float(np.percentile(v, 30))
            row.append(round(float(q), 3))
        heights.append(row)
    # Buildability that matches the model: no towers on its boulders and trees, and bare
    # flat grass where the map has a tree or rock becomes a build spot.
    blocked, opened = [], []
    for y in range(h):
        for x in range(w):
            v = sorted(hits.get((y, x), []))
            ch = kind[y, x]
            if not v or ch == "x":
                continue
            tall = sum(1 for t in v if t > 0.2)
            if ch == "." and (heights[y][x] > 0.12 or tall >= 2):
                blocked.append([x, y])
            elif ch in "tr" and len(v) == len(offs) and tall == 0 and v[-1] - v[0] < 0.15 and abs(heights[y][x]) < 0.05:
                opened.append([x, y])
    print("blocked build cells: %s" % blocked)
    print("opened build cells:  %s" % opened)
    flat_h = [v for r in heights for v in r if v is not None]
    print("cell heights: min %.3f  median %.3f  max %.3f" % (min(flat_h), float(np.median(flat_h)), max(flat_h)))

    fit = {
        "source": os.path.basename(glb),
        "xf": [round(float(v), 6) for v in list(B[:, 0]) + list(B[:, 1]) + list(B[:, 2]) + list(origin)],
        "heights": heights,
        "keep": [p for p in args.keep.split(",") if p],
        "blocked": blocked,
        "opened": opened,
        "grid_strength": args.grid_strength,
        "tint": args.tint,
        "fit": {"yaw": round(float(yaw), 2), "sx": round(float(kx), 5), "sz": round(float(kz), 5),
                "dx": round(float(dx), 3), "dz": round(float(dz), 3),
                "tilt": round(tilt, 2), "score": round(float(f), 3), "path_clusters": pcs},
    }
    out = os.path.join(ARENAS, args.level + ".json")
    os.makedirs(ARENAS, exist_ok=True)
    with open(out, "w") as fh:
        json.dump(fit, fh, indent=1)
        fh.write("\n")
    print("wrote", out)

    if args.debug:
        os.makedirs(args.debug, exist_ok=True)
        debug_image(world, F, C, ln, kind, w, h, os.path.join(args.debug, args.level + "_top.png"), lab_all=None)
        cl = np.zeros(len(F), int) - 1
        cl[np.where(on_ground)[0]] = lab
        debug_image(world, F, C, ln, kind, w, h, os.path.join(args.debug, args.level + "_clusters.png"), lab_all=cl,
                    cents=cents, path_clusters=pcs)


def debug_image(world, F, C, ln, kind, w, h, out, lab_all=None, cents=None, path_clusters=()):
    """Top-down raster of the fitted model with the gameplay grid drawn on top."""
    ppu = 48
    pad = 3
    W, H = (w + pad * 2) * ppu, (h + pad * 2) * ppu
    img = Image.new("RGB", (W, H), (40, 44, 52))
    dr = ImageDraw.Draw(img)
    tri = world[F]
    order = np.argsort(tri[:, :, 1].mean(axis=1))      # paint low to high
    for i in order:
        t = tri[i]
        if lab_all is not None:
            if lab_all[i] < 0:
                col = (70, 70, 70)
            else:
                c = cents[lab_all[i]]
                col = (255, 40, 200) if lab_all[i] in path_clusters else tuple(int(v * 255) for v in c)
        else:
            shade = 0.6 + 0.4 * max(0.0, ln[i, 1])
            col = tuple(int(min(1.0, v * shade) * 255) for v in C[i])
        pts = [((p[0] + w * 0.5 + pad) * ppu, (p[2] + h * 0.5 + pad) * ppu) for p in t]
        dr.polygon(pts, fill=col)
    for y in range(h):
        for x in range(w):
            ch = kind[y, x]
            if ch == "x":
                continue
            x0, y0 = (x + pad) * ppu, (y + pad) * ppu
            col = {"#": (255, 230, 60), "S": (200, 80, 255), "C": (60, 230, 255)}.get(ch, (255, 255, 255))
            wid = 3 if ch in "#SC" else 1
            dr.rectangle([x0 + 2, y0 + 2, x0 + ppu - 2, y0 + ppu - 2], outline=col, width=wid)
            if ch in "tr":
                dr.text((x0 + ppu / 2 - 3, y0 + ppu / 2 - 6), ch, fill=(255, 255, 255))
    img.save(out)
    print("debug:", out)


if __name__ == "__main__":
    main()
