"""Marks that sit on the cards.

Two sources: vector recreations drawn as SVG (rendered through cairo) and
letter marks set in a geometric sans.  Both return a straight-alpha RGBA image
the card compositor can paste, so the rest of the pipeline does not care which
one an app uses.
"""

import io
import os

import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "fonts")
_FONT_CACHE = {}

# Variable fonts, so one file covers every weight - and, unlike the Google Fonts
# CSS subsets, they carry Cyrillic.
FONTS = {
    "geo": ("Montserrat-var.ttf", {"wght": 800}),
    "geo-bold": ("Montserrat-var.ttf", {"wght": 700}),
    "grotesk": ("Inter-var.ttf", {"opsz": 28, "wght": 800}),
    "grotesk-bold": ("Inter-var.ttf", {"opsz": 28, "wght": 700}),
    "round": ("Manrope-var.ttf", {"wght": 800}),
}


def font(name, size):
    key = (name, int(size))
    if key not in _FONT_CACHE:
        filename, axes = FONTS[name]
        f = ImageFont.truetype(os.path.join(FONT_DIR, filename), int(size))
        try:
            # Pillow reports axes by human name, in fvar order.
            wanted = []
            for axis in f.get_variation_axes():
                name = axis["name"].decode() if isinstance(axis["name"], bytes) else axis["name"]
                tag = {"Weight": "wght", "Optical size": "opsz"}.get(name, name)
                wanted.append(axes.get(tag, axis["default"]))
            f.set_variation_by_axes(wanted)
        except Exception:
            # A static font (or a FreeType without variation support) is fine too.
            pass
        _FONT_CACHE[key] = f
    return _FONT_CACHE[key]


# --------------------------------------------------------------------------- #
# svg marks
# --------------------------------------------------------------------------- #

SVG_HEAD = (
    '<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" '
    'viewBox="0 0 100 100">'
)


def render_svg(body, px, defs=""):
    """Rasterise an SVG fragment drawn in a 100x100 box."""
    svg = SVG_HEAD.format(px=px) + (("<defs>%s</defs>" % defs) if defs else "") + body + "</svg>"
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=px, output_height=px)
    return Image.open(io.BytesIO(png)).convert("RGBA")


# --------------------------------------------------------------------------- #
# letter marks
# --------------------------------------------------------------------------- #

def render_text(text, px, color="#FFFFFF", face="geo", tracking=-0.02, width=0.78, height=0.62):
    """Set `text` as a mark, fitted to a box inside the px-square glyph area.

    Letter marks carry a lot of these icons, so they are measured and optically
    centred rather than baseline-positioned.
    """
    canvas = px * 3  # oversample, then fit
    probe = font(face, canvas // 3)
    track_px = tracking * (canvas // 3)

    def measure(f, t):
        total_w, top, bottom = 0.0, None, None
        for i, ch in enumerate(t):
            box = f.getbbox(ch)
            adv = f.getlength(ch)
            if box:
                if top is None or box[1] < top:
                    top = box[1]
                if bottom is None or box[3] > bottom:
                    bottom = box[3]
            total_w += adv + (track_px if i < len(t) - 1 else 0)
        if top is None:
            top, bottom = 0, 1
        return total_w, top, bottom

    w, top, bottom = measure(probe, text)
    h = bottom - top
    if w <= 0 or h <= 0:
        w, h = 1, 1
    scale = min((px * width) / w, (px * height) / h)
    size = max(6, int(round((canvas // 3) * scale)))

    f = font(face, size)
    track_px = tracking * size
    w, top, bottom = measure(f, text)
    h = bottom - top

    im = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = (px - w) / 2.0
    y = (px - h) / 2.0 - top
    for i, ch in enumerate(text):
        d.text((x, y), ch, font=f, fill=color)
        x += f.getlength(ch) + (track_px if i < len(text) - 1 else 0)
    return im


def fit(image, px):
    if image.size != (px, px):
        image = image.resize((px, px), Image.LANCZOS)
    return image


def place(glyph, size, scale=0.56, dx=0, dy=0):
    """Centre a mark on the icon canvas at `scale` of the card."""
    px = int(round(size * scale))
    g = fit(glyph, px) if glyph.size != (px, px) else glyph
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(g, ((size - px) // 2 + dx, (size - px) // 2 + dy))
    return out


def tint(image, color):
    """Recolour a mask-like mark, keeping its alpha."""
    from style import hex_rgb
    rgb = hex_rgb(color) if isinstance(color, str) else color
    arr = np.asarray(image, dtype=np.float32)
    arr[..., :3] = rgb * 255.0
    return Image.fromarray(arr.astype(np.uint8), "RGBA")
