#!/usr/bin/env python3
"""Bakes the runner's textures into assets/textures/.

    python3 tools/gen_textures.py

  stone_floor.png   seamless pale paving stones for the bridge walkway (512x512)
  wall_stone.png    seamless block masonry for the parapets and piers (256x256)
  plus_tile.png     a "+1" floor tile (256x256, with alpha)
  cloud_noise.png   tileable fbm used by the sea shader (from tools/gen_cloud_noise.py)
"""

import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "textures")
FONT = os.path.join(ROOT, "assets", "fonts", "Rubik-ExtraBold.ttf")


def tileable_noise(size, cells, rng, octaves=4):
    out = np.zeros((size, size))
    amp = 0.5
    for k in range(octaves):
        c = cells * 2 ** k
        lat = rng.random((c, c))
        t = np.arange(size) * c / size
        i0 = np.floor(t).astype(int)
        f = t - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % c
        a, b = lat[np.ix_(i0, i0)], lat[np.ix_(i0, i1)]
        cc, d = lat[np.ix_(i1, i0)], lat[np.ix_(i1, i1)]
        fx, fy = f[None, :], f[:, None]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (cc * (1 - fx) + d * fx) * fy)
        amp *= 0.5
    return out / (1 - 0.5 ** octaves)


def paving(size, rows, base, mortar, rng, min_w, max_w, bevel):
    """Rows of rectangular stones with staggered joints, wrapped so the tile repeats."""
    img = Image.new("RGB", (size * 3, size * 3), mortar)
    draw = ImageDraw.Draw(img)
    row_h = size / rows
    noise = tileable_noise(size, 4, rng)
    for r in range(rows):
        widths = []
        while sum(widths) < size:
            widths.append(rng.uniform(min_w, max_w) * size)
        scale = size / sum(widths)
        widths = [w * scale for w in widths]
        x = rng.uniform(0, size)
        for w in widths:
            shade = rng.uniform(-0.07, 0.07)
            col = tuple(int(np.clip(c * (1 + shade) + rng.uniform(-4, 4), 0, 255)) for c in base)
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    x0 = size + x + ox
                    y0 = size + r * row_h + oy
                    draw.rounded_rectangle([x0 + bevel, y0 + bevel, x0 + w - bevel, y0 + row_h - bevel],
                                           radius=bevel * 2.2, fill=col)
            x += w
    img = img.crop((size, size, 2 * size, 2 * size)).filter(ImageFilter.GaussianBlur(0.7))
    arr = np.asarray(img).astype(float)
    arr *= (0.9 + 0.2 * noise)[:, :, None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def plus_tile(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = size * 0.05
    d.rounded_rectangle([m, m, size - m, size - m], radius=size * 0.12, fill=(30, 90, 210, 255),
                        outline=(150, 205, 255, 255), width=int(size * 0.045))
    d.rounded_rectangle([m * 2.6, m * 2.6, size - m * 2.6, size * 0.5], radius=size * 0.08, fill=(60, 130, 240, 255))
    font = ImageFont.truetype(FONT, int(size * 0.5))
    text = "+1"
    box = d.textbbox((0, 0), text, font=font, stroke_width=int(size * 0.03))
    tw, th = box[2] - box[0], box[3] - box[1]
    pos = ((size - tw) / 2 - box[0], (size - th) / 2 - box[1])
    d.text(pos, text, font=font, fill=(255, 255, 255, 255), stroke_width=int(size * 0.03), stroke_fill=(15, 45, 120, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    paving(512, 6, (205, 192, 168), (122, 110, 94), np.random.default_rng(7), 0.16, 0.34, 3).save(os.path.join(OUT, "stone_floor.png"))
    paving(256, 4, (178, 166, 148), (100, 90, 80), np.random.default_rng(11), 0.3, 0.55, 2).save(os.path.join(OUT, "wall_stone.png"))
    plus_tile(256).save(os.path.join(OUT, "plus_tile.png"))
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gen_cloud_noise.py")], check=True)
    print("textures written to", OUT)


if __name__ == "__main__":
    main()
