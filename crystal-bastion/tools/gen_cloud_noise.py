#!/usr/bin/env python3
"""Bakes the tileable cloud noise used by the sea of clouds under sculpted arenas.

    python3 tools/gen_cloud_noise.py   # writes assets/textures/cloud_noise.png

Five octaves of value noise (smoothstep interpolation, base lattice of 8 cells across the
tile), wrapped so the 256x256 texture repeats seamlessly. The shader samples it instead of
computing noise per pixel: phone GPUs evaluate sin()-based hash noise with too little
precision (the clouds broke up into squares) and the per-pixel fbm was costly anyway.
"""

import os
import struct
import zlib

import numpy as np

SIZE = 256
BASE = 8
OCTAVES = 5


def value_noise(cells, rng):
    lattice = rng.random((cells, cells))
    t = np.arange(SIZE) * cells / SIZE
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3.0 - 2.0 * f)
    i1 = (i0 + 1) % cells
    a = lattice[np.ix_(i0, i0)]
    b = lattice[np.ix_(i0, i1)]
    c = lattice[np.ix_(i1, i0)]
    d = lattice[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def write_png(path, img):
    raw = b"".join(b"\0" + row.tobytes() for row in img)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 0, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    rng = np.random.default_rng(1234)
    v = np.zeros((SIZE, SIZE))
    amp = 0.5
    for k in range(OCTAVES):
        v += amp * value_noise(BASE * 2 ** k, rng)
        amp *= 0.5
    img = np.clip(np.round(v * 255.0), 0, 255).astype(np.uint8)
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "cloud_noise.png")
    write_png(out, img)
    print(f"wrote {os.path.normpath(out)}: {SIZE}x{SIZE}, range {img.min()}..{img.max()}, mean {img.mean():.1f}")


if __name__ == "__main__":
    main()
