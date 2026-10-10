"""Builds the porcelain UI ornaments (2x art) for assets/ui/kit from the parts that cut_parts.py cut out of the
ornaments sheet (art_src/ui/ornaments_src.jpg):
    py build_ornaments.py <parts_dir> <sheet.jpg> <out_dir>
part 0 card_frame (the enclosed grey inside cleared), 1 ribbon, 2 plate (also pill), 3 socket_cream, 4 socket_slate,
6 badge_gem, 7 tag_new. Bodies are rebuilt as [cap | averaged plain middle | cap] like build_buttons.py. Writes the
PNGs and spec.json (the kit.json entries, 1x margins, "scale": 2).
"""
import sys, os, json
import numpy as np
from PIL import Image
from scipy import ndimage

parts, sheet, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
SC = 2
spec = {}


def load(i):
    im = Image.open(os.path.join(parts, "part_%d.png" % i)).convert("RGBA")
    a = np.asarray(im)[..., 3]
    return im.crop(Image.fromarray(((a > 200) * 255).astype(np.uint8)).getbbox())


def body(im, h1, cap_k, mid=8, fade=16):
    h2 = h1 * SC
    w2 = round(im.width * h2 / im.height)
    a = np.asarray(im.resize((w2, h2), Image.LANCZOS)).astype(np.float32)
    cap = int(round(cap_k * h2))
    prof = np.median(a[:, int(w2 * 0.35):int(w2 * 0.65)], axis=1)
    left, right = a[:, :cap].copy(), a[:, w2 - cap:].copy()
    t = np.linspace(0.0, 1.0, fade)[None, :, None]
    left[:, cap - fade:] = left[:, cap - fade:] * (1 - t) + prof[:, None, :] * t
    right[:, :fade] = right[:, :fade] * t + prof[:, None, :] * (1 - t)
    o = np.concatenate([left, np.repeat(prof[:, None, :], mid, axis=1), right], axis=1)
    return Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA"), cap // SC


def save(name, im, entry):
    im.save(os.path.join(out, name + ".png"))
    spec[name] = dict(entry, scale=SC)
    print(name, im.size, entry)


# card_frame: the frame only; the enclosed grey (the inside and the gaps between the double lines) becomes clear.
im = load(0)
a = np.asarray(im).astype(np.float32)
src = np.asarray(Image.open(sheet).convert("RGB")).astype(np.float32)
bg = np.median(np.concatenate([src[:6].reshape(-1, 3), src[:, :6].reshape(-1, 3)]), 0)
grey = (np.sqrt(((a[..., :3] - bg) ** 2).sum(-1)) < 14) & (a[..., 3] > 0)
lab, n = ndimage.label(grey)
sizes = ndimage.sum(grey, lab, range(1, n + 1))
holes = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 30])
a[..., 3] = np.where(ndimage.binary_dilation(holes, iterations=1), 0, a[..., 3])
fr = Image.fromarray(a.astype(np.uint8), "RGBA").resize((432, 600), Image.LANCZOS)
save("card_frame", fr, {"margins": [24, 24, 24, 24], "pad": [0, 0], "expand": [0, 0, 0, 0]})
# ribbon (title plate, 44 tall at 1x), plate / pill (52), tag_new (24)
rb, c = body(load(1), 44, 0.9)
save("ribbon", rb, {"margins": [c, 14, c, 14], "pad": [30, 6], "expand": [0, 0, 0, 0]})
pl, c = body(load(2), 52, 0.42)
save("plate", pl, {"margins": [c, 16, c, 16], "pad": [16, 6], "expand": [0, 0, 0, 0]})
save("pill", pl, {"margins": [c, 16, c, 16], "pad": [16, 6], "expand": [0, 0, 0, 0]})
tg, c = body(load(7), 24, 0.75)
save("tag_new", tg, {"margins": [c, 8, c, 8], "pad": [8, 1], "expand": [0, 0, 0, 0]})
# discs and the gem badge (square, drawn at their rect)
for i, name, px in [(3, "socket_cream", 64), (4, "socket_slate", 64), (6, "badge_gem", 40)]:
    save(name, load(i).resize((px * SC, px * SC), Image.LANCZOS), {})
json.dump(spec, open(os.path.join(out, "spec.json"), "w"), indent=1)
print("done")
