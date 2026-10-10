# Cuts the button-parts sheet: background removed (cutlib, tolerance arg), defringed, each blob saved as part_<i>.png
# (sorted by row then x) with its box printed.
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, r"C:\ForgeMind\crystal-rush\tools\art")
from cutlib import cutout
src, out, tol = sys.argv[1], sys.argv[2], float(sys.argv[3])
os.makedirs(out, exist_ok=True)
im = Image.open(src).convert("RGB")
arr = cutout(im, tol=tol)
a0 = np.asarray(im).astype(np.float32)
bg = np.median(np.concatenate([a0[:6].reshape(-1, 3), a0[:, :6].reshape(-1, 3), a0[:, -6:].reshape(-1, 3)]), 0)
a = arr[..., 3:4] / 255.0
soft = (a > 0.02) & (a < 0.98)
rgb = np.where(soft, np.clip((arr[..., :3] - (1.0 - a) * bg) / np.maximum(a, 0.02), 0, 255), arr[..., :3])
arr = np.concatenate([rgb, arr[..., 3:4]], -1)
lab, n = ndimage.label(arr[..., 3] > 40)
objs = [(sl, (lab[sl] > 0).sum()) for sl in ndimage.find_objects(lab) if sl is not None]
objs = [o for o in objs if o[1] > 2000]
objs.sort(key=lambda o: (round((o[0][0].start + o[0][0].stop) / 2 / (arr.shape[0] / 3)), o[0][1].start))
for i, (sl, area) in enumerate(objs):
    y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
    crop = arr[max(0, y0 - 4):y1 + 4, max(0, x0 - 4):x1 + 4]
    Image.fromarray(crop.astype(np.uint8), "RGBA").save(os.path.join(out, "part_%d.png" % i))
    print(i, "box x", x0, x1, "y", y0, y1, "size", x1 - x0, "x", y1 - y0, "ratio %.2f" % ((x1 - x0) / (y1 - y0)))
