"""The "Live Takt" card: a tactile glass tile that every icon in the pack sits on.

Each icon is one squircle card built from a handful of stacked light layers -
brand gradient, accent bloom, top-left key light, a diagonal sheen streak, a
bottom-right falloff, and a glass rim - with the app's mark embossed on top.
Everything is computed as float arrays so the anti-aliasing stays clean at the
192 px the launchers actually draw.
"""

import math

import numpy as np
from PIL import Image, ImageFilter

SIZE = 192          # xxxhdpi: 48dp
INSET = 6           # breathing room for the drop shadow
SQUIRCLE = 4.35     # superellipse exponent; 2 = circle, inf = square


# --------------------------------------------------------------------------- #
# colour helpers
# --------------------------------------------------------------------------- #

def hex_rgb(value):
    value = value.lstrip("#")
    if len(value) == 3:
        value = "".join(c * 2 for c in value)
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def _hsv(rgb):
    r, g, b = float(rgb[0]), float(rgb[1]), float(rgb[2])
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0.0
    elif mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h / 6.0, (0.0 if mx == 0 else d / mx), mx


def _rgb(h, s, v):
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    table = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]
    return np.array(table[i], dtype=np.float32)


def shade(color, dv=0.0, ds=0.0, dh=0.0):
    """Nudge a colour in HSV - used to derive gradient stops from one brand hue."""
    h, s, v = _hsv(color)
    return np.clip(_rgb((h + dh) % 1.0, min(max(s + ds, 0.0), 1.0), min(max(v + dv, 0.0), 1.0)), 0, 1)


def gradient_stops(brand):
    """Top and bottom stop for a brand colour: lifted and warmed, then deepened."""
    top = shade(brand, dv=+0.16, ds=-0.07, dh=+0.012)
    bottom = shade(brand, dv=-0.20, ds=+0.06, dh=-0.014)
    return top, bottom


# --------------------------------------------------------------------------- #
# field helpers - everything below works on (SIZE, SIZE) float32 arrays
# --------------------------------------------------------------------------- #

def _coords(size):
    a = (np.arange(size, dtype=np.float32) + 0.5) / size
    return np.meshgrid(a, a)  # x, y in 0..1


def squircle(size=SIZE, inset=INSET, n=SQUIRCLE):
    """Anti-aliased squircle coverage plus its normalised radius field."""
    x, y = _coords(size)
    half = (size - 2 * inset) / 2.0
    cx = cy = size / 2.0
    px = (x * size - cx) / half
    py = (y * size - cy) / half
    f = (np.abs(px) ** n + np.abs(py) ** n) ** (1.0 / n)
    # One pixel of the normalised field, used as the anti-aliasing width.
    edge = 1.0 / half
    alpha = np.clip((1.0 - f) / edge + 0.5, 0.0, 1.0)
    return alpha.astype(np.float32), f.astype(np.float32)


def linear_field(size, angle_deg):
    """0..1 ramp along `angle_deg` (0 = left to right, 90 = top to bottom)."""
    x, y = _coords(size)
    a = math.radians(angle_deg)
    v = x * math.cos(a) + y * math.sin(a)
    lo, hi = v.min(), v.max()
    return ((v - lo) / (hi - lo)).astype(np.float32)


def radial_field(size, cx, cy, radius, power=2.0):
    """1 at the centre, 0 at `radius` (both in 0..1 units of the icon)."""
    x, y = _coords(size)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / radius
    return np.clip(1.0 - d, 0.0, 1.0) ** power


def band_field(size, angle_deg, offset, width):
    """A soft straight streak - the moving highlight that makes the card 'live'."""
    x, y = _coords(size)
    a = math.radians(angle_deg)
    d = (x - 0.5) * math.sin(a) - (y - 0.5) * math.cos(a) - offset
    return np.exp(-(d / width) ** 2).astype(np.float32)


def ellipse_field(size, cx, cy, rx, ry, edge=0.22):
    """Soft-edged ellipse - the shape of a reflection sitting on the glass."""
    x, y = _coords(size)
    d = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    return (1.0 - smoothstep(1.0 - edge, 1.0 + edge * 0.35, d)).astype(np.float32)


def blur(field, sigma):
    im = Image.fromarray((np.clip(field, 0, 1) * 255).astype(np.uint8), "L")
    im = im.filter(ImageFilter.GaussianBlur(sigma))
    return np.asarray(im, dtype=np.float32) / 255.0


def shift(field, dx, dy):
    out = np.zeros_like(field)
    h, w = field.shape
    sx0, sx1 = max(0, -dx), min(w, w - dx)
    sy0, sy1 = max(0, -dy), min(h, h - dy)
    out[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = field[sy0:sy1, sx0:sx1]
    return out


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _screen(base, color, amount):
    """Screen blend - light adds without blowing the hue out."""
    a = amount[..., None] if amount.ndim == 2 else amount
    return 1.0 - (1.0 - base) * (1.0 - color * a)


def _over(base, color, amount):
    a = amount[..., None] if amount.ndim == 2 else amount
    return base * (1.0 - a) + color * a


# --------------------------------------------------------------------------- #
# the card
# --------------------------------------------------------------------------- #

class Card:
    """Style parameters for one tile."""

    def __init__(self, top, bottom, glow=None, glow_strength=0.34,
                 rim=0.72, sheen=0.15, key=0.22, shadow=0.34, glass=1.35):
        self.top = hex_rgb(top) if isinstance(top, str) else top
        self.bottom = hex_rgb(bottom) if isinstance(bottom, str) else bottom
        self.glow = hex_rgb(glow) if isinstance(glow, str) else glow
        self.glow_strength = glow_strength
        self.rim = rim
        self.sheen = sheen
        self.key = key
        self.shadow = shadow
        # How much of the glass treatment to lay on: gloss cap, refracted
        # edges, the bounce along the bottom.
        self.glass = glass

    @classmethod
    def brand(cls, color, **kw):
        """A card carved out of one brand colour."""
        top, bottom = gradient_stops(hex_rgb(color) if isinstance(color, str) else color)
        kw.setdefault("glow", shade(top, dv=+0.10, ds=-0.18))
        return cls(top, bottom, **kw)

    @classmethod
    def graphite(cls, glow=None, **kw):
        """Neutral dark glass - for marks that must keep their own colours."""
        kw.setdefault("glow_strength", 0.30)
        return cls("#39414F", "#151A22", glow=glow, **kw)

    @classmethod
    def porcelain(cls, glow=None, **kw):
        """Neutral light glass - for dark or outline marks."""
        kw.setdefault("glow_strength", 0.22)
        kw.setdefault("rim", 0.85)
        kw.setdefault("key", 0.14)
        kw.setdefault("sheen", 0.10)
        return cls("#FDFDFE", "#DFE4ED", glow=glow, **kw)


def render_card(card, size=SIZE, inset=INSET):
    """Return (rgb, alpha) float arrays for the bare tile.

    The stack reads like a piece of glass lit from the upper left: body
    gradient, accent bloom under the mark, key light, a gloss cap where the
    light source reflects, a specular streak, refraction brightening the edges,
    and finally the rim - bright on top, a thinner bounce along the bottom.
    """
    alpha, f = squircle(size, inset)
    white = np.ones((1, 1, 3), dtype=np.float32)
    black = np.zeros((1, 1, 3), dtype=np.float32)
    glass = card.glass
    vert = linear_field(size, 90.0)
    half = (size - 2 * inset) / 2.0

    ramp = linear_field(size, 118.0)
    rgb = card.top[None, None, :] * (1.0 - ramp[..., None]) + card.bottom[None, None, :] * ramp[..., None]

    # Accent bloom sitting behind where the mark will be.
    if card.glow is not None:
        bloom = radial_field(size, 0.5, 0.44, 0.68, power=2.2) * card.glow_strength
        rgb = _screen(rgb, card.glow[None, None, :], bloom)

    # Key light from the top left.
    rgb = _screen(rgb, white, radial_field(size, 0.22, 0.06, 1.05, power=2.6) * card.key)

    # Gloss cap: the reflection of the light source across the top of the pane,
    # strongest at the very top and fading before it reaches the middle.
    cap = ellipse_field(size, 0.5, -0.24, 0.98, 0.80, edge=0.26) * alpha
    cap = cap * (1.0 - smoothstep(0.04, 0.56, vert)) ** 1.3
    rgb = _screen(rgb, white, cap * 0.30 * glass)

    # Specular streak running across the upper third.
    rgb = _screen(rgb, white, band_field(size, 34.0, -0.21, 0.11) * alpha * card.sheen)
    rgb = _screen(rgb, white, band_field(size, 34.0, -0.05, 0.045) * alpha * card.sheen * 0.55)

    # Falloff into the bottom right corner keeps the tile from floating flat.
    rgb = _over(rgb, black, radial_field(size, 0.92, 1.02, 0.95, power=1.7) * 0.21)

    # Refraction: light gathers in the thickness of the glass near the edges,
    # and pools along the bottom where it bounces back up through the body.
    thickness = smoothstep(1.0 - 9.0 / half, 1.0 - 1.6 / half, f) * alpha
    rgb = _screen(rgb, white, thickness * smoothstep(0.30, 1.0, vert) * 0.20 * glass)
    rgb = _screen(rgb, white, thickness * (1.0 - smoothstep(0.0, 0.35, vert)) * 0.10 * glass)

    # A darker line just inside the top rim reads as the edge of the pane.
    inner = smoothstep(1.0 - 5.0 / half, 1.0 - 1.8 / half, f) * alpha
    rgb = _over(rgb, black, inner * (1.0 - smoothstep(0.0, 0.30, vert)) * 0.16 * glass)

    # Rim: bright hairline on top, thinner bounce along the bottom edge.
    rim_w = 1.9 / half
    rim = smoothstep(1.0 - rim_w, 1.0 - rim_w * 0.2, f) * alpha
    rim_top = rim * (1.0 - smoothstep(0.0, 0.58, vert)) * card.rim
    rim_bottom = rim * smoothstep(0.40, 1.0, vert) * (card.rim * 0.42)
    rgb = _screen(rgb, white, rim_top + rim_bottom)

    return np.clip(rgb, 0, 1), alpha


def emboss(mask, size=SIZE, depth=0.30, sigma=2.4, dy=3):
    """Soft contact shadow cast by a mark onto the card below it."""
    return blur(shift(mask, 0, dy), sigma) * depth


def compose(card, glyph_rgba, size=SIZE, inset=INSET, glyph_shadow=True):
    """Stack the tile, its drop shadow and the mark into one RGBA image."""
    rgb, alpha = render_card(card, size, inset)

    out_rgb = np.zeros((size, size, 3), dtype=np.float32)
    out_a = np.zeros((size, size), dtype=np.float32)

    # Drop shadow beneath the tile.
    if card.shadow > 0:
        sh = blur(shift(alpha, 0, 4), 4.2) * card.shadow
        sh = np.clip(sh - alpha * 0.85, 0, 1)
        out_a = sh
        out_rgb = np.zeros_like(out_rgb)

    # The tile itself.
    out_rgb, out_a = _blend(out_rgb, out_a, rgb, alpha)

    if glyph_rgba is not None:
        g = np.asarray(glyph_rgba, dtype=np.float32) / 255.0
        g_rgb, g_a = g[..., :3], g[..., 3]
        if glyph_shadow:
            sh = emboss(g_a, size) * alpha
            out_rgb, out_a = _blend(out_rgb, out_a, np.zeros_like(out_rgb), sh)
        out_rgb, out_a = _blend(out_rgb, out_a, g_rgb, g_a * alpha)

    data = np.concatenate(
        [np.clip(out_rgb, 0, 1) * 255.0, np.clip(out_a, 0, 1)[..., None] * 255.0], axis=2
    ).astype(np.uint8)
    return Image.fromarray(data, "RGBA")


def _blend(dst_rgb, dst_a, src_rgb, src_a):
    """Straight-alpha source-over."""
    sa = src_a[..., None]
    out_a = src_a + dst_a * (1.0 - src_a)
    safe = np.where(out_a[..., None] > 1e-6, out_a[..., None], 1.0)
    out_rgb = (src_rgb * sa + dst_rgb * dst_a[..., None] * (1.0 - sa)) / safe
    return out_rgb, out_a
