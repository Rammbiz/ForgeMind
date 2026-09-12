# -*- coding: utf-8 -*-
"""Rasterise the catalogue into the PNGs that ship inside the APK."""

import os

import numpy as np
from PIL import Image

import glyphs
import marks
import style

SIZE = 192
PREVIEW_BG = ("#1B2030", "#0B0E15")


# --------------------------------------------------------------------------- #

def card_for(spec):
    kind, color, glow = spec
    if kind == "brand":
        return style.Card.brand(color, glow=glow) if glow else style.Card.brand(color)
    if kind == "graphite":
        return style.Card.graphite(glow=glow)
    if kind == "porcelain":
        return style.Card.porcelain(glow=glow)
    raise ValueError(kind)


def _card_mid(card):
    mid = (card.top + card.bottom) / 2.0
    return "#%02X%02X%02X" % tuple(int(round(float(c) * 255)) for c in mid)


def glyph_for(app, card, size=SIZE):
    kind, value, opts = app.glyph
    px = max(8, int(round(size * app.scale)))
    if kind == "mark":
        body = marks.MARKS[value]().replace("{fg}", app.fg).replace("{bg}", _card_mid(card))
        return glyphs.render_svg(body, px)
    if kind == "text":
        return glyphs.render_text(value, px, color=app.fg, **opts)
    raise ValueError(kind)


def render_app(app, size=SIZE):
    card = card_for(app.card)
    glyph = glyphs.place(glyph_for(app, card, size), size, app.scale, dy=app.dy)
    return style.compose(card, glyph, size=size)


# --------------------------------------------------------------------------- #
# fallback assets: every app the pack does not draw by hand still gets the card
# --------------------------------------------------------------------------- #

ICONBACK_TINTS = [
    ("#39414F", "#151A22", "#5B7CFF"),
    ("#3B4250", "#161B24", "#8E6BFF"),
    ("#374451", "#131A21", "#2BC4C4"),
    ("#3F4350", "#1A1B22", "#FF8A5B"),
]


def render_iconback(index, size=SIZE):
    top, bottom, glow = ICONBACK_TINTS[index]
    card = style.Card(top, bottom, glow=glow, glow_strength=0.26)
    return style.compose(card, None, size=size)


def render_iconmask(size=SIZE):
    """Opaque outside the card, clear inside - launchers apply it with DST_OUT."""
    alpha, _ = style.squircle(size, style.INSET)
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., 3] = ((1.0 - alpha) * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def render_iconupon(size=SIZE):
    """The glass on top: rim light and sheen, so foreign icons sit under it too."""
    alpha, f = style.squircle(size, style.INSET)
    half = (size - 2 * style.INSET) / 2.0
    rim_w = 1.7 / half
    vert = style.linear_field(size, 90.0)

    rim = style.smoothstep(1.0 - rim_w, 1.0 - rim_w * 0.25, f) * alpha
    a = rim * (1.0 - style.smoothstep(0.0, 0.62, vert)) * 0.55
    a = a + rim * style.smoothstep(0.45, 1.0, vert) * 0.14
    a = a + style.band_field(size, 34.0, -0.22, 0.12) * alpha * 0.10
    a = a + style.radial_field(size, 0.2, 0.05, 1.0, power=2.6) * alpha * 0.10

    rgb = np.ones((size, size, 3), dtype=np.float32)
    data = np.concatenate([rgb * 255.0, np.clip(a, 0, 1)[..., None] * 255.0], axis=2)
    return Image.fromarray(data.astype(np.uint8), "RGBA")


def render_launcher_icon(size=SIZE):
    card = style.Card.brand("#4C6FFF", glow="#8FD3FF")
    body = marks.MARKS["cards_stack"]().replace("{fg}", "#FFFFFF").replace("{bg}", "#3A56C8")
    glyph = glyphs.place(glyphs.render_svg(body, int(size * 0.56)), size, 0.56)
    return style.compose(card, glyph, size=size)


# --------------------------------------------------------------------------- #

def render_all(apps, out_dir, size=SIZE, progress=None):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for i, app in enumerate(apps):
        path = os.path.join(out_dir, "%s.png" % app.slug)
        render_app(app, size).save(path, optimize=True)
        written.append(app.slug)
        if progress and i % 25 == 0:
            progress(i, len(apps))
    for i in range(len(ICONBACK_TINTS)):
        render_iconback(i, size).save(os.path.join(out_dir, "iconback_%d.png" % i), optimize=True)
    render_iconmask(size).save(os.path.join(out_dir, "iconmask.png"), optimize=True)
    render_iconupon(size).save(os.path.join(out_dir, "iconupon.png"), optimize=True)
    render_launcher_icon(size).save(os.path.join(out_dir, "ic_launcher.png"), optimize=True)
    return written


def contact_sheet(images, cols=10, cell=SIZE, pad=18):
    rows = (len(images) + cols - 1) // cols
    w, h = cols * (cell + pad) + pad, rows * (cell + pad) + pad
    x, y = np.meshgrid(np.linspace(0, 1, w, dtype=np.float32), np.linspace(0, 1, h, dtype=np.float32))
    c0, c1 = style.hex_rgb(PREVIEW_BG[0]), style.hex_rgb(PREVIEW_BG[1])
    t = (0.6 * x + 0.4 * y)[..., None]
    canvas = Image.fromarray(((c0 * (1 - t) + c1 * t) * 255).astype(np.uint8), "RGB").convert("RGBA")
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        canvas.alpha_composite(im, (pad + c * (cell + pad), pad + r * (cell + pad)))
    return canvas
