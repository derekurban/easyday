# Pixel-level verification of the shipped maps (../assets/*_ids.png: R = plate id, G = tint alpha).
#  A) islands:   each plate's tinted pixels (alpha > 0.1) form ONE connected piece (no tint jumping a groove)
#  B) seams:     where two plates touch, the seam lies in the groove valley (seam darker than both plates' interiors)
#  C) coverage:  every light plate pixel (lum > T + 8, inside the body) is tinted >= 0.9
#  D) edge:      the silhouette is anti-aliased: no opaque pixel within 1.5 px of it differs from the alpha-weighted
#                blur (0.8 px) of its neighbours' colour by EDGE_STEP or more (an unsmoothed edge's 1 px outline steps
#                between light and dark pixels by 40 to 70)
import json
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.segmentation import find_boundaries
A = "../assets/"
meta = json.load(open(A + "flat.json"))
ok_all = True
for n, m in meta["maps"].items():
    rgba = np.asarray(Image.open(A + n + ".png").convert("RGBA")); g = rgba[..., :3].astype(float).mean(2)
    idm = np.asarray(Image.open(A + n + "_ids.png")); ids = idm[..., 0].astype(int); a = idm[..., 1] / 255
    T = m["T"]
    islands = []
    for pid in range(1, ids.max() + 1):
        lab, k = ndi.label((ids == pid) & (a > 0.1), structure=np.ones((3, 3)))
        if k > 1:
            sz = np.sort(ndi.sum(np.ones_like(lab), lab, range(1, k + 1)))[::-1]
            islands.append((pid, int(sz[1:].sum())))
    # seams: for each pair of touching plates, compare luminance on the seam vs 3 px inside each plate
    seam_bad = []
    bnd = find_boundaries(ids, mode="inner") & (ids > 0)
    inner = {pid: (ids == pid) & (a > 0.95) for pid in range(1, ids.max() + 1)}
    pairs = {}
    ys, xs = np.where(bnd)
    for y, x in zip(ys, xs):
        nb = ids[max(0, y - 1):y + 2, max(0, x - 1):x + 2].ravel()
        for q in set(nb.tolist()) - {0, ids[y, x]}:
            key = tuple(sorted((ids[y, x], q))); pairs.setdefault(key, []).append(g[y, x])
    for (p, q), vals in pairs.items():
        if len(vals) < 6: continue
        seam = float(np.median(vals))
        # interior luminance near the seam: dilate the seam a bit and sample each plate's inner pixels there
        near = ndi.binary_dilation(bnd & np.isin(ids, [p, q]), iterations=6)
        ip = g[near & inner[p]]; iq = g[near & inner[q]]
        if len(ip) and len(iq) and seam > min(np.median(ip), np.median(iq)) - 4:
            seam_bad.append((p, q, round(seam), round(float(np.median(ip))), round(float(np.median(iq)))))
    lightm = (g > T + 8) & (rgba[..., 3] > 200)
    lr, lk = ndi.label(lightm, structure=np.ones((3, 3)))
    plate_regions = np.unique(lr[(a > 0.95) & lightm])          # light regions that belong to a plate
    cover = lightm & np.isin(lr, plate_regions[plate_regions > 0]) & (a < 0.9)
    lab, k = ndi.label(cover, structure=np.ones((3, 3)))
    gaps = [(int(c[1]), int(c[0]), int(s)) for c, s in zip(ndi.center_of_mass(cover, lab, range(1, k + 1)), ndi.sum(cover, lab, range(1, k + 1))) if s >= 4]
    EDGE_STEP = 35
    alpha = rgba[..., 3] / 255
    inside = ndi.gaussian_filter(alpha, 1.2) >= 0.5
    ring = inside & (ndi.distance_transform_edt(inside) <= 1.5) & (alpha >= 0.8)
    near = ndi.gaussian_filter(g * alpha, 0.8) / np.maximum(ndi.gaussian_filter(alpha, 0.8), 1e-6)
    step = np.where(ring, np.abs(g - near), 0)
    rough = [(int(x), int(y), int(step[y, x])) for y, x in zip(*np.nonzero(step >= EDGE_STEP))][:5]
    ok = not islands and not seam_bad and not rough
    ok_all &= ok
    print(f"{n}: {'PASS' if ok else 'FAIL'}  islands={islands}  touching pairs={len(pairs)} bad seams={seam_bad}  coverage gaps(>=4px)={gaps}  rough edge={rough} (largest step {step.max():.0f})")
print("ALL PASS" if ok_all else "FAILURES")
