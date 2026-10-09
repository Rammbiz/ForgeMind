"""Splash cut-out: flat-grey background removal seeded from chosen borders, optional hole cleanup in regions."""
import numpy as np
from PIL import Image
from scipy import ndimage


def cutout(img, tol=12.0, sigma=40, seed_bottom=True, top_skip=None):
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    border = np.concatenate([a[:6].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    bgc = np.median(border, 0)
    mask = np.sqrt(((a - bgc) ** 2).sum(-1)) < 14
    dist = None
    for _ in range(2):
        m = mask.astype(np.float32)
        den = ndimage.gaussian_filter(m, sigma) + 1e-4
        field = np.stack([ndimage.gaussian_filter(a[..., c] * m, sigma) / den for c in range(3)], -1)
        dist = np.sqrt(((a - field) ** 2).sum(-1))
        cand = dist < tol
        lab, _ = ndimage.label(cand)
        top = lab[0].copy()
        if top_skip:   # a prop touching the top edge (a bow limb) must not seed the background flood
            top[top_skip[0]:top_skip[1]] = 0
        edges = [top, lab[:, 0], lab[:, -1]] + ([lab[-1]] if seed_bottom else [])
        ids = set(np.unique(np.concatenate(edges))) - {0}
        mask = np.isin(lab, list(ids))
    mask = ndimage.binary_opening(mask, iterations=1)
    alpha = 1.0 - ndimage.gaussian_filter(mask.astype(np.float32), 0.8)
    edge = ndimage.binary_dilation(mask, iterations=2) & ~mask
    alpha = np.where(edge, np.minimum(alpha, np.clip((dist - 6) / 26, 0, 1)), alpha)
    return np.dstack([a, np.clip(alpha, 0, 1) * 255])


def clean(arr, bg, hole_regions=None, min_keep=300, hole_min=400, hole_std=3.5, hole_d=9):
    rgb = arr[..., :3]; al = arr[..., 3]
    d = np.sqrt(((rgb - bg) ** 2).sum(-1))
    holes = np.zeros(d.shape, bool)
    if hole_regions is not None:
        reg = np.zeros(d.shape, bool)
        for (y0, y1, x0, x1) in hole_regions:
            reg[y0:y1, x0:x1] = True
        cand = (d < hole_d) & (al > 0) & reg
        lab, n = ndimage.label(cand)
        sizes = ndimage.sum(cand, lab, range(1, n + 1))
        for i, s in enumerate(sizes):
            if s > hole_min:
                m = lab == (i + 1)
                if rgb[m].std(0).max() < hole_std:
                    holes |= m
        al = np.where(ndimage.binary_dilation(holes, iterations=1), 0, al)
    solid = al > 40
    lab, n = ndimage.label(solid)
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    keep = ndimage.binary_dilation(np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > min_keep]), iterations=3)
    al = np.where(keep, al, 0)
    return Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), 'RGBA'), int(holes.sum())


def preview(o, path, k=0.4):
    b = Image.new('RGBA', o.size, (30, 30, 40, 255)); b.alpha_composite(o)
    b.convert('RGB').resize((int(o.width * k), int(o.height * k))).save(path)
