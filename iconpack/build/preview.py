#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render the promo sheet that shows the pack at a glance."""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "src"))

import catalog  # noqa: E402
import glyphs  # noqa: E402
import render  # noqa: E402
import style  # noqa: E402

SHOW = [
    "diia", "monobank", "privat24", "nova_poshta", "ukrposhta", "rozetka", "olx", "kyivstar",
    "air_alert", "ukrzaliznytsia", "atb", "silpo", "uklon", "glovo", "megogo", "yasno",
    "telegram", "whatsapp", "viber", "instagram", "youtube", "tiktok", "google_maps", "gmail",
    "spotify", "chrome", "sys_phone", "sys_camera", "sys_gallery", "sys_settings", "netflix", "discord",
]

W, H = 1280, 1240
CELL, GAP = 128, 26


def background():
    x, y = np.meshgrid(np.linspace(0, 1, W, dtype=np.float32), np.linspace(0, 1, H, dtype=np.float32))
    c0, c1 = style.hex_rgb("#1A2133"), style.hex_rgb("#080A11")
    t = (0.55 * x + 0.45 * y)[..., None]
    base = c0 * (1 - t) + c1 * t
    bloom = np.clip(1.0 - np.sqrt((x - 0.18) ** 2 + (y - 0.08) ** 2) / 0.9, 0, 1) ** 2.2
    base = 1.0 - (1.0 - base) * (1.0 - style.hex_rgb("#4C6FFF") * (bloom * 0.35)[..., None])
    return Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")


def text(canvas, xy, string, size, color, face="geo"):
    font = glyphs.font(face, size)
    ImageDraw.Draw(canvas).text(xy, string, font=font, fill=color)


def main():
    apps = {a.slug: a for a in catalog.load()}
    canvas = background()

    text(canvas, (64, 56), "Лайв Такт", 64, "#F2F5FA")
    text(canvas, (66, 136), "Набір іконок · живі скляні картки", 26, "#9FB0C9", face="geo-bold")
    text(canvas, (66, 176), "%d намальованих іконок · %d застосунків · решта — на тій самій підкладці"
         % (len(apps), sum(len(a.packages) for a in apps.values())), 20, "#6D7E98", face="geo-bold")

    top = 246
    for i, slug in enumerate(SHOW):
        app = apps.get(slug)
        if app is None:
            continue
        icon = render.render_app(app).resize((CELL, CELL), Image.LANCZOS)
        r, c = divmod(i, 8)
        canvas.alpha_composite(icon, (64 + c * (CELL + GAP), top + r * (CELL + GAP)))

    strip = top + 4 * (CELL + GAP) + 18
    text(canvas, (66, strip), "Застосунки без власної іконки теж стають карткою:", 20, "#6D7E98",
         face="geo-bold")
    text(canvas, (66, strip + 30), "у наборі", 16, "#55657D", face="geo-bold")

    demo_colors = [("#E8453C", "A"), ("#3B82F6", "B"), ("#22C55E", "C"), ("#F59E0B", "D")]
    for i, (color, letter) in enumerate(demo_colors):
        original = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
        ImageDraw.Draw(original).rounded_rectangle([0, 0, 191, 191], radius=30, fill=color)
        original.alpha_composite(glyphs.render_text(letter, 192, width=0.48, height=0.48))
        tile = fallback(original, i)
        canvas.alpha_composite(tile.resize((CELL, CELL), Image.LANCZOS),
                               (64 + i * (CELL + GAP), strip + 52))
        canvas.alpha_composite(original.resize((84, 84), Image.LANCZOS),
                               (64 + i * (CELL + GAP) + 22, strip + 82 + CELL + 14))

    text(canvas, (66, strip + 62 + CELL + 14), "оригінал", 16, "#55657D", face="geo-bold")

    out = os.path.join(ROOT, "dist", "preview.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.convert("RGB").save(out, quality=95)
    print(out)


def fallback(original, index, scale=0.70):
    """Reproduce what a launcher does with an app the pack does not draw."""
    size = render.SIZE
    out = render.render_iconback(index % 4)
    inner = int(size * scale)
    out.alpha_composite(original.resize((inner, inner), Image.LANCZOS),
                        ((size - inner) // 2, (size - inner) // 2))
    arr = np.asarray(out, dtype=np.float32) / 255.0
    mask = np.asarray(render.render_iconmask(), dtype=np.float32) / 255.0
    arr[..., 3] *= 1.0 - mask[..., 3]
    out = Image.fromarray((arr * 255).astype(np.uint8), "RGBA")
    out.alpha_composite(render.render_iconupon())
    return out


if __name__ == "__main__":
    main()
