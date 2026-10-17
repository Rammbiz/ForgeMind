#!/usr/bin/env python3
"""Builds the launcher icons from the owner's square icon artwork (tools/icon_source.jpg,
1024x1024 with white rounded corners).

    python3 crystal-rush/tools/make_icons_art.py [source.jpg]

Writes icon.png (project icon), the legacy Android icon and the adaptive layers. The adaptive
foreground holds the art inset so a launcher's mask (circle, squircle...) keeps the heroes and
the x2 gate; the background is a blurred fill that only shows at the edges and in animations.
The themed (monochrome) layer is left as it is.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "icons")
INSET = 56          # px of the 1024 source: removes the white rounded corners


def rounded(img, radius_frac=0.22):
    size = img.size[0]
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_frac), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def feathered(img, edge):
    size = img.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rectangle([edge, edge, size - 1 - edge, size - 1 - edge], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(edge * 0.6))
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def main(src):
    os.makedirs(OUT, exist_ok=True)
    art = Image.open(src).convert("RGB")
    s = art.size[0]
    sq = art.crop((INSET, INSET, s - INSET, s - INSET))
    rounded(sq.resize((256, 256), Image.LANCZOS)).save(os.path.join(ROOT, "icon.png"))
    rounded(sq.resize((192, 192), Image.LANCZOS)).save(os.path.join(OUT, "android_main_192.png"))
    bg = sq.resize((432, 432), Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))
    bg = Image.blend(bg, Image.new("RGB", (432, 432), (18, 10, 52)), 0.35)
    bg.save(os.path.join(OUT, "android_adaptive_bg_432.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = 312       # the 288 px launcher viewport shows the middle 92% of the art
    piece = feathered(sq.resize((inner, inner), Image.LANCZOS), 10)
    fg.alpha_composite(piece, ((432 - inner) // 2, (432 - inner) // 2))
    fg.save(os.path.join(OUT, "android_adaptive_fg_432.png"))
    print("icons written to", OUT)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "icon_source.jpg"))
