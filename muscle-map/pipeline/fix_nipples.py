# Remove nipples while preserving the plate's edge shading: every pixel in the patch is copied from the nearest
# pixel of the same plate that lies at the same distance from the plate's outline (so the rounded bevel continues).
#   python fix_nipples.py <name> x,y,r ...
import sys
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
name = sys.argv[1]
im = np.asarray(Image.open(f"work/{name}_base.png").convert("RGBA")).astype(float)
g = im[..., :3].mean(2)
cc = np.load(f"work/{name}_cc.npy")
yy, xx = np.mgrid[:im.shape[0], :im.shape[1]]
out = im.copy()
for spec in sys.argv[2:]:
    x, y, r = map(int, spec.split(","))
    pid = cc[y, x] or np.bincount(cc[y - 6:y + 7, x - 6:x + 7].ravel()[cc[y - 6:y + 7, x - 6:x + 7].ravel() > 0]).argmax()
    # plate region incl. its bevel down into the groove (light-ish pixels touching the plate)
    plate = ndi.binary_dilation(cc == pid, iterations=6) & (g > 40)
    plate = ndi.binary_fill_holes(plate)
    d = ndi.distance_transform_edt(plate)                       # distance to the plate outline
    rr = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
    patch = (rr <= r) & plate & (d >= 2.5)                     # never touch the outline itself
    src = plate & (rr > r + 2) & (rr < r + 50) & (d >= 1.5)
    sy, sx = np.where(src); sd = d[sy, sx]
    py, px = np.where(patch)
    for i in range(len(py)):
        dp = d[py[i], px[i]]
        m = np.abs(sd - dp) < 0.6
        cols, ws = [], []
        for side in (-1, 1):                                    # nearest same-depth pixel left and right of the patch
            c = np.where(m & ((sx - x) * side > 0))[0]
            if not len(c): continue
            dist2 = (sy[c] - py[i]) ** 2 + (sx[c] - px[i]) ** 2
            k = c[np.argsort(dist2)[:6]]                          # average a few -> no texture seams
            cols.append(im[sy[k], sx[k], :3].mean(0)); ws.append(1 / (np.sqrt(dist2.min()) + 1e-3))
        if cols:
            out[py[i], px[i], :3] = sum(c * w for c, w in zip(cols, ws)) / sum(ws)
    # soften the transplant: light smoothing inside the patch only, then feathered blend at its rim
    sm = out.copy()
    for c in range(3):
        sm[..., c] = ndi.gaussian_filter(out[..., c], 2.0)
    w = np.clip((r - rr) / 4, 0, 1) * patch * np.clip((d - 2.5) / 2, 0, 1)
    out[..., :3] = out[..., :3] * (1 - w[..., None] * 0.8) + sm[..., :3] * (w[..., None] * 0.8)
    print("fixed", spec, "plate", pid, "px", len(py))
Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA").save(f"work/{name}_base.png")
