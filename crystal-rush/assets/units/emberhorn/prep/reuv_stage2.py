"""Stage 2 of the crowd-unit re-UV pipeline: bakes the high-poly source's albedo onto the new
UV atlas of the simplified mesh (stage 1). For every covered texel: its point and normal on the low
mesh, the nearest point on a dense sampling of the high mesh's surface whose normal agrees, that
point's original UV, a bilinear read of the original texture. Islands are padded (dilated) so mips
do not bleed, then the 2x render is filtered down.
  python3 reuv_stage2.py HI.glb LOW.glb OUT.jpg [SIZE=512] [GLOW_BOX=x0,y0,z0,x1,y1,z1]
With GLOW_BOX (model space, rest pose) also writes OUT_glow.png: a mask of the bright, warm
texels inside the box (the Emberhorn's glowing eyes) for the shader's emission.
"""
import sys
import numpy as np
import trimesh
from PIL import Image
from scipy.spatial import cKDTree
from scipy import ndimage

hi_path, lo_path, out_path = sys.argv[1:4]
size = int(sys.argv[4]) if len(sys.argv) > 4 else 512
R = size * 2


def first_mesh(path):
    s = trimesh.load(path, process=False, force='scene')
    geoms = list(s.geometry.values())
    return geoms[0]


hi = first_mesh(hi_path)
lo = first_mesh(lo_path)
tex = hi.visual.material.baseColorTexture if hasattr(hi.visual.material, 'baseColorTexture') else hi.visual.material.image
tex = np.asarray(tex.convert('RGB')).astype(np.float32) / 255.0
th, tw = tex.shape[:2]
print('hi', hi.vertices.shape, hi.faces.shape, 'tex', tex.shape, 'lo', lo.vertices.shape, lo.faces.shape)

# Dense surface samples of the high mesh with their UVs and face normals.
hv, hf, huv = hi.vertices, hi.faces, hi.visual.uv
areas = hi.area_faces
n_samples = 3_000_000
counts = np.maximum(1, np.round(areas / areas.sum() * n_samples)).astype(int)
fid = np.repeat(np.arange(len(hf)), counts)
r1 = np.random.default_rng(1).random(len(fid))
r2 = np.random.default_rng(2).random(len(fid))
s1 = np.sqrt(r1)
b0, b1, b2 = 1 - s1, s1 * (1 - r2), s1 * r2
tri = hv[hf[fid]]
pts = tri[:, 0] * b0[:, None] + tri[:, 1] * b1[:, None] + tri[:, 2] * b2[:, None]
tuv = huv[hf[fid]]
uvs = tuv[:, 0] * b0[:, None] + tuv[:, 1] * b1[:, None] + tuv[:, 2] * b2[:, None]
fn = hi.face_normals[fid]
tree = cKDTree(pts)
print('samples', len(pts))

# Rasterise the low mesh in its new UV space.
lv, lf, luv = lo.vertices, lo.faces, lo.visual.uv
ln = lo.vertex_normals
P = np.zeros((R, R, 3), np.float32)
N = np.zeros((R, R, 3), np.float32)
M = np.zeros((R, R), bool)
for f in lf:
    uv = luv[f] * R
    uv[:, 1] = R - uv[:, 1]  # glTF UV origin top-left vs image rows: v down
    x0, y0 = np.floor(uv.min(0)).astype(int)
    x1, y1 = np.ceil(uv.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, R - 1), min(y1, R - 1)
    if x1 < x0 or y1 < y0:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    a, b, c = uv
    v0, v1 = b - a, c - a
    d = v0[0] * v1[1] - v1[0] * v0[1]
    if abs(d) < 1e-12:
        continue
    px, py = xs - a[0], ys - a[1]
    w1 = (px * v1[1] - v1[0] * py) / d
    w2 = (v0[0] * py - px * v0[1]) / d
    w0 = 1 - w1 - w2
    eps = -0.02
    inside = (w0 >= eps) & (w1 >= eps) & (w2 >= eps)
    if not inside.any():
        continue
    iy = ys[inside].astype(int)
    ix = xs[inside].astype(int)
    W = np.stack([w0[inside], w1[inside], w2[inside]], 1)
    P[iy, ix] = W @ lv[f]
    N[iy, ix] = W @ ln[f]
    M[iy, ix] = True
print('covered texels', M.sum(), 'of', R * R)

q = P[M]
qn = N[M]
qn /= np.linalg.norm(qn, axis=1, keepdims=True) + 1e-9
dist, nn = tree.query(q, k=12)
ok = (fn[nn] * qn[:, None, :]).sum(-1) > 0.2
first = np.where(ok.any(1), ok.argmax(1), 0)
pick = nn[np.arange(len(q)), first]
suv = uvs[pick]
# Bilinear read.
sx = np.clip(suv[:, 0] * tw - 0.5, 0, tw - 1.001)
sy = np.clip((1.0 - suv[:, 1]) * th - 0.5, 0, th - 1.001)  # trimesh UVs: v up
xi, yi = sx.astype(int), sy.astype(int)
fx, fy = (sx - xi)[:, None], (sy - yi)[:, None]
col = (tex[yi, xi] * (1 - fx) * (1 - fy) + tex[yi, xi + 1] * fx * (1 - fy)
       + tex[yi + 1, xi] * (1 - fx) * fy + tex[yi + 1, xi + 1] * fx * fy)
img = np.zeros((R, R, 3), np.float32)
img[M] = col
# Pad the islands: every empty texel takes its nearest covered texel.
_, (iy, ix) = ndimage.distance_transform_edt(~M, return_indices=True)
img = img[iy, ix]
out = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((size, size), Image.LANCZOS)
out.save(out_path, quality=93)
print('wrote', out_path)
if len(sys.argv) > 5:
    box = np.array([float(x) for x in sys.argv[5].split(',')]).reshape(2, 3)
    inbox = np.all((P >= box[0]) & (P <= box[1]), axis=-1) & M
    c = np.zeros((R, R, 3), np.float32)
    c[M] = col
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    warm = np.clip((r - 0.8) / 0.15, 0, 1) * np.clip((g - 0.42) / 0.25, 0, 1) * np.clip((lum - 0.45) / 0.2, 0, 1)
    mask = np.where(inbox, warm, 0.0)
    # Keep the two biggest blobs (the eyes); thin warm trim edges in the box drop out.
    lab, n = ndimage.label(mask > 0.15)
    if n > 2:
        sizes = ndimage.sum(np.ones_like(mask), lab, range(1, n + 1))
        keep = np.argsort(sizes)[-2:] + 1
        mask = np.where(np.isin(lab, keep), mask, 0.0)
    mask = ndimage.grey_dilation(mask, size=3)
    mask = ndimage.gaussian_filter(mask, 1.2)
    gimg = Image.fromarray((np.clip(mask / max(mask.max(), 1e-6), 0, 1) * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
    gpath = out_path.rsplit('.', 1)[0] + '_glow.png'
    gimg.save(gpath)
    print('glow texels', int((mask > 0.2).sum()), 'wrote', gpath)
