# Punches the background seen through a net (or any lattice) out of an installed cut-out: in a region, the small
# neutral-grey components close to the sheet's background and ringed by net strands become clear; their 2-px rims
# fade by colour distance.
#   py net_holes.py <src.jpg> <card.png> <out.png> <y0> <y1> <x0> <x1> (fractions) [tol]
import sys, numpy as np
from PIL import Image
from scipy import ndimage
src, card, out = sys.argv[1:4]
fy0, fy1, fx0, fx1 = map(float, sys.argv[4:8])
tol = float(sys.argv[8]) if len(sys.argv) > 8 else 18
o = np.asarray(Image.open(card).convert('RGBA')).astype(np.float32)
h, w = o.shape[:2]
a = np.asarray(Image.open(src).convert('RGB').resize((w, h), Image.LANCZOS)).astype(np.float32)
bg = np.median(np.concatenate([a[:6].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)]), 0)
d = np.sqrt(((a - bg) ** 2).sum(-1))
reg = np.zeros(d.shape, bool)
reg[int(fy0 * h):int(fy1 * h), int(fx0 * w):int(fx1 * w)] = True
gold = ((a[..., 0] - a[..., 2]) > 12) | (o[..., 3] < 40)    # a net strand (gold) or already clear


def strands(lab, sl, k):
    """The share of a component's 3-px ring that is net strand or clear: a cell of the net is ringed by gold,
    a pale patch of fabric is not."""
    y0, y1 = max(sl[0].start - 4, 0), sl[0].stop + 4
    x0, x1 = max(sl[1].start - 4, 0), sl[1].stop + 4
    m = lab[y0:y1, x0:x1] == k
    ring = ndimage.binary_dilation(m, iterations=3) & ~m
    return gold[y0:y1, x0:x1][ring].mean() if ring.any() else 0.0


holes = np.zeros(d.shape, bool)
kept = 0
for tt in sorted({12, 16, 20, 24, tol}):    # several tolerances: a shaded cell passes at a wider one, a clean cell at a tight one
    cand = (d < tt) & reg & (o[..., 3] > 0) & ~holes
    lab, n = ndimage.label(cand)
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = lab[sl] == i + 1
        s = m.sum()
        if s < 12 or s > 20000:
            continue
        px = a[sl][m]
        chroma = np.abs(px - px.mean(1, keepdims=True)).max(1).mean()
        if chroma < 5 and px.std(0).max() < 9 and strands(lab, sl, i + 1) > 0.55:
            holes[sl] |= m
            kept += 1
al = o[..., 3].copy()
core = ndimage.binary_dilation(holes, iterations=1)
al[core] = 0
rim = ndimage.binary_dilation(core, iterations=2) & ~core
al = np.where(rim, np.minimum(al, np.clip((d - 6) / 26, 0, 1) * 255), al)
o[..., 3] = al
Image.fromarray(o.astype(np.uint8), 'RGBA').save(out, optimize=True)
print('holes', kept, 'px', int(core.sum()))
