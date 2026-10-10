"""Builds the "Royal Porcelain" button skins (2x art) for assets/ui/kit from the cut parts (cut_parts.py).
    py build_buttons.py <parts_dir> <out_dir>
A body part is scaled to 2x its 1x target height, then rebuilt as [left cap | narrow middle | right cap] so the
nine-patch stretches only a plain middle; caps hold the carved ends and the chamfers. Pressed / disabled states
that the sheet lacks are derived (deeper ivory / quiet faded porcelain). Prints the kit.json entries (1x units).
"""
import sys, os, json
import numpy as np
from PIL import Image, ImageEnhance

parts, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
SC = 2


def load(i):
    """A part cropped to its solid body (alpha > 200): the soft shadow under it is left out, so the face gets the
    height (the game's own frost and glow sit around buttons already)."""
    im = Image.open(os.path.join(parts, "part_%d.png" % i)).convert("RGBA")
    a = np.asarray(im)[..., 3]
    solid = Image.fromarray(((a > 200) * 255).astype(np.uint8))
    return im.crop(solid.getbbox())


def body(im, h1, cap_k, mid=8, fade=16):
    """[cap | mid | cap] at 2x of the 1x height h1; cap = cap_k x height. The middle is one averaged column of
    the plain face (the median over the body's middle 40 %, so no centre mark or light streak survives), and
    each cap's inner `fade` px blend into that column (no seam). Returns (image, cap px at 1x)."""
    h2 = h1 * SC
    w2 = round(im.width * h2 / im.height)
    a = np.asarray(im.resize((w2, h2), Image.LANCZOS)).astype(np.float32)
    cap = int(round(cap_k * h2))
    prof = np.median(a[:, int(w2 * 0.3):int(w2 * 0.7)], axis=1)            # (h2, 4)
    left = a[:, :cap].copy()
    right = a[:, w2 - cap:].copy()
    t = np.linspace(0.0, 1.0, fade)[None, :, None]
    left[:, cap - fade:] = left[:, cap - fade:] * (1 - t) + prof[:, None, :] * t
    right[:, :fade] = right[:, :fade] * t + prof[:, None, :] * (1 - t)
    middle = np.repeat(prof[:, None, :], mid, axis=1)
    o = np.concatenate([left, middle, right], axis=1)
    return Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA"), cap // SC


def pressed(im):
    a = np.asarray(im).astype(np.float32)
    rgb = a[..., :3] * np.array([0.955, 0.94, 0.915])     # a touch deeper and warmer
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a[..., 3]]).astype(np.uint8), "RGBA")


def disabled(im):
    g = ImageEnhance.Color(im).enhance(0.35)
    g = ImageEnhance.Contrast(g).enhance(0.75)
    a = np.asarray(g).astype(np.float32)
    rgb = a[..., :3] * 0.92 + 255 * 0.08
    return Image.fromarray(np.dstack([rgb, a[..., 3] * 0.85]).astype(np.uint8), "RGBA")


spec = {}


def save(name, im, cap1, h1, pad, expand):
    im.save(os.path.join(out, name + ".png"))
    top = int(round(h1 * 0.3))     # the gold rim, the inner line and the 45-degree cut; the face between is plain
    bot = top
    spec[name] = {"scale": SC, "margins": [cap1, top, cap1, bot], "pad": pad, "expand": expand}
    print(name, im.size, "1x", im.width // SC, "x", im.height // SC, "margins", spec[name]["margins"])


# The key CTA (ГРАТИ, Покращити): 1x body 96 tall (KitCTA.BODY_MAX).
p, c = body(load(0), 96, 0.62)
save("primary", p, c, 96, [36, 10], [0, 0, 0, 0])
pp, c2 = body(load(1), 96, 0.62)
save("primary_pressed", pp, c2, 96, [36, 10], [0, 0, 0, 0])
save("primary_disabled", disabled(p), c, 96, [36, 10], [0, 0, 0, 0])
# Narrow price CTAs: the long thin part, 1x 72 tall.
q, c3 = body(load(4), 72, 0.55)
save("primary_compact", q, c3, 72, [24, 8], [0, 0, 0, 0])
# Secondary cream button: 1x 72 tall.
b, c4 = body(load(2), 72, 0.62)
save("button", b, c4, 72, [28, 10], [0, 0, 0, 0])
save("button_pressed", pressed(b), c4, 72, [28, 10], [0, 0, 0, 0])
save("button_disabled", disabled(b), c4, 72, [28, 10], [0, 0, 0, 0])
# Round edge-button disc (76 at 1x) and the topaz (drawn at the CTA's gem size, up to 40 at 1x).
d = load(3).resize((76 * SC, 76 * SC), Image.LANCZOS)
d.save(os.path.join(out, "edge_button.png")); spec["edge_button"] = {"scale": SC}
t = load(5)
t = t.resize((80, round(80 * t.height / t.width)), Image.LANCZOS)
t.save(os.path.join(out, "cta_topaz.png")); spec["cta_topaz"] = {"scale": SC}
json.dump(spec, open(os.path.join(out, "spec.json"), "w"), indent=1)
print("done")
