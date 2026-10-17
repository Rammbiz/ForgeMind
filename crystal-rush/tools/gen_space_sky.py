#!/usr/bin/env python3
"""Bakes the space world's sky: an equirectangular panorama (2048x1024) with nebulae and stars.

    python3 tools/gen_space_sky.py   # writes assets/worlds/space/sky.png

The camera looks down at the road, so most of what shows behind it is the lower half of the
sphere: both halves get stars and nebula clouds. Noise is wrapped horizontally so the seam at
the back of the panorama does not show.
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
W, H = 2048, 1024


def noise(cells_x, cells_y, rng, octaves=5):
    out = np.zeros((H, W))
    amp = 0.5
    for k in range(octaves):
        cx, cy = cells_x * 2 ** k, cells_y * 2 ** k
        lat = rng.random((cy + 1, cx))
        tx = np.arange(W) * cx / W
        ty = np.arange(H) * cy / H
        x0 = np.floor(tx).astype(int)
        y0 = np.floor(ty).astype(int)
        fx = tx - x0
        fy = ty - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        x1 = (x0 + 1) % cx
        y1 = np.minimum(y0 + 1, cy)
        a, b = lat[np.ix_(y0, x0)], lat[np.ix_(y0, x1)]
        c, d = lat[np.ix_(y1, x0)], lat[np.ix_(y1, x1)]
        fx, fy = fx[None, :], fy[:, None]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        amp *= 0.5
    return out / (1 - 0.5 ** octaves)


def main():
    rng = np.random.default_rng(42)
    y = np.linspace(0, 1, H)[:, None]
    base = np.zeros((H, W, 3))
    base[:] = np.array([0.02, 0.025, 0.07])
    base += (0.5 - np.abs(y - 0.5))[:, :, None] * np.array([0.04, 0.03, 0.1])
    # Two nebula layers in violet/magenta and teal, with darker dust lanes.
    n1 = noise(6, 3, rng)
    n2 = noise(9, 5, rng)
    dust = noise(14, 7, rng)
    violet = np.clip((n1 - 0.48) * 3.2, 0, 1) ** 1.6
    teal = np.clip((n2 - 0.52) * 3.0, 0, 1) ** 1.8
    lanes = np.clip((dust - 0.45) * 2.0, 0, 1)
    base += violet[:, :, None] * np.array([0.42, 0.14, 0.55]) * (0.6 + 0.4 * lanes[:, :, None])
    base += teal[:, :, None] * np.array([0.05, 0.32, 0.45]) * (0.5 + 0.5 * lanes[:, :, None])
    img = np.clip(base, 0, 1)
    # Stars: many faint pinpoints, some bright ones with a soft halo.
    count = 6000
    xs = rng.integers(0, W, count)
    ys = rng.integers(0, H, count)
    mags = rng.random(count) ** 6
    tint = rng.choice([np.array([1, 1, 1]), np.array([0.8, 0.9, 1.0]), np.array([1.0, 0.9, 0.75])], count)
    for x, yy, m, t in zip(xs, ys, mags, tint):
        bright = 0.35 + 0.65 * m
        img[yy, x] = np.clip(img[yy, x] + t * bright, 0, 1)
        if m > 0.35:
            r = 2 if m < 0.8 else 3
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    dd = (dx * dx + dy * dy) ** 0.5
                    if 0 < dd <= r:
                        px, py = (x + dx) % W, min(max(yy + dy, 0), H - 1)
                        img[py, px] = np.clip(img[py, px] + t * bright * 0.35 / dd, 0, 1)
    out = os.path.join(ROOT, "assets", "worlds", "space", "sky.png")
    Image.fromarray((img ** (1 / 1.1) * 255).astype(np.uint8)).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
