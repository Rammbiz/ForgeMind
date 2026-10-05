#!/usr/bin/env python3
"""Composes the launcher icons from hero portraits rendered by the game.

    xvfb-run -a godot --path crystal-rush --rendering-driver opengl3 -- --shot=/tmp/p.png --screen=portraits
    python3 crystal-rush/tools/make_icons.py /tmp/p_bolt.png /tmp/p_titan.png
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "icons")


def background(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=(int(40 + 40 * t), int(110 + 60 * t), int(220 - 20 * t)))
    # A pale bridge running up the middle.
    d.polygon([(size * 0.42, 0), (size * 0.58, 0), (size * 0.95, size), (size * 0.05, size)], fill=(214, 204, 186))
    return img


def main(bolt_path, titan_path):
    os.makedirs(OUT, exist_ok=True)
    bolt = Image.open(bolt_path).convert("RGBA")
    titan = Image.open(titan_path).convert("RGBA")
    size = 432
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    t = titan.resize((300, 300), Image.LANCZOS)
    b = bolt.resize((300, 300), Image.LANCZOS)
    fg.alpha_composite(t, (150, 70))
    fg.alpha_composite(b, (-10, 90))
    # Soft shadow under the heroes for contrast on any wallpaper.
    shadow = fg.split()[3].filter(ImageFilter.GaussianBlur(8))
    shade = Image.new("RGBA", (size, size), (10, 20, 50, 0))
    shade.putalpha(shadow.point(lambda a: int(a * 0.55)))
    fg_full = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fg_full.alpha_composite(shade, (0, 6))
    fg_full.alpha_composite(fg)
    fg_full.save(os.path.join(OUT, "android_adaptive_fg_432.png"))
    bg = background(size)
    bg.save(os.path.join(OUT, "android_adaptive_bg_432.png"))
    mono = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mono.putalpha(fg.split()[3])
    white = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    white.putalpha(fg.split()[3])
    white.save(os.path.join(OUT, "android_monochrome_432.png"))
    full = bg.convert("RGBA")
    full.alpha_composite(fg_full)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=90, fill=255)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(full, (0, 0), mask)
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "android_main_192.png"))
    icon.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "icon.png"))
    print("icons written to", OUT)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
