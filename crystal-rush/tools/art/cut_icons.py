"""Cuts a Gemini icon sheet (icons on flat #BFBFBF in a cols x rows grid) into transparent square PNGs.
    py cut_icons.py sheet.png out_dir cols rows name1,name2,... [size=256] [tol=10]
Background: cutlib.cutout (flood from the borders against a local background field), then every opaque blob is
assigned to the grid cell holding its centre; a cell's blobs are cropped together, padded to a square with
PAD margin and resized. Writes <out>/icon_<name>.png plus <out>/preview.png (all icons on cream and on ink).
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, r"C:\ForgeMind\crystal-rush\tools\art")
from cutlib import cutout, clean  # noqa: E402

PAD = 0.06

src, out, cols, rows, names = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5].split(",")
size = int(sys.argv[6]) if len(sys.argv) > 6 else 256
tol = float(sys.argv[7]) if len(sys.argv) > 7 else 10.0
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert("RGB")
arr = cutout(im, tol=tol)
a0 = np.asarray(im).astype(np.float32)
bg = np.median(np.concatenate([a0[:6].reshape(-1, 3), a0[:, :6].reshape(-1, 3), a0[:, -6:].reshape(-1, 3)]), 0)
# Enclosed background (between a garland's flags, inside a handle): flat bg-coloured holes anywhere.
H0, W0 = arr.shape[:2]
cl, nh = clean(arr, bg, hole_regions=[(0, H0, 0, W0)], min_keep=60, hole_min=25, hole_std=4.0, hole_d=9)
arr = np.asarray(cl).astype(np.float32)
print("holes cleared px", nh)
# Defringe: a soft edge pixel is the icon colour blended with the grey; take the grey back out.
a = arr[..., 3:4] / 255.0
soft = (a > 0.02) & (a < 0.98)
rgb = np.where(soft, np.clip((arr[..., :3] - (1.0 - a) * bg) / np.maximum(a, 0.02), 0, 255), arr[..., :3])
arr = np.concatenate([rgb, arr[..., 3:4]], -1)
al = arr[..., 3]
solid = al > 40
lab, n = ndimage.label(solid)
H, W = al.shape
cw, ch = W / cols, H / rows
cells = {}
for i, sl in enumerate(ndimage.find_objects(lab)):
    if sl is None:
        continue
    m = lab[sl] == i + 1
    if m.sum() < 0.0004 * W * H:
        continue
    cy = (sl[0].start + sl[0].stop) / 2
    cx = (sl[1].start + sl[1].stop) / 2
    k = (int(cy // ch), int(cx // cw))
    cells.setdefault(k, []).append(sl)
icons = []
for r in range(rows):
    for c in range(cols):
        idx = r * cols + c
        if idx >= len(names):
            break
        sls = cells.get((r, c), [])
        if not sls:
            print("EMPTY cell", r, c, names[idx])
            continue
        y0 = min(s[0].start for s in sls); y1 = max(s[0].stop for s in sls)
        x0 = min(s[1].start for s in sls); x1 = max(s[1].stop for s in sls)
        crop = arr[y0:y1, x0:x1].copy()
        # keep only this cell's blobs (a neighbour's stray pixels inside the box are dropped)
        keep = np.zeros(crop.shape[:2], bool)
        for s in sls:
            ys, xs = s
            lid = lab[s].max()
            keep[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0] |= lab[s] > 0
        crop[..., 3] = np.where(ndimage.binary_dilation(keep, iterations=3), crop[..., 3], 0)
        h, w = crop.shape[:2]
        side = int(max(h, w) * (1 + 2 * PAD))
        sq = np.zeros((side, side, 4), np.float32)
        oy, ox = (side - h) // 2, (side - w) // 2
        sq[oy:oy + h, ox:ox + w] = crop
        img = Image.fromarray(sq.astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
        img.save(os.path.join(out, "icon_%s.png" % names[idx]))
        icons.append(img)
        print("icon", names[idx], "cell", r, c, "box", x1 - x0, "x", y1 - y0)
# preview: each icon at 96 px on cream and on ink
pv = Image.new("RGBA", (len(icons) * 112 + 16, 240), (0, 0, 0, 0))
for i, ic in enumerate(icons):
    for j, bgc in enumerate([(247, 241, 230, 255), (43, 53, 80, 255)]):
        tile = Image.new("RGBA", (112, 112), bgc)
        tile.alpha_composite(ic.resize((96, 96), Image.LANCZOS), (8, 8))
        pv.paste(tile, (8 + i * 112, 8 + j * 116))
pv.save(os.path.join(out, "preview.png"))
print("done", len(icons))
