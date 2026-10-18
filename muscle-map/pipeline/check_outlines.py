# Verify ../assets/outlines.json (from outlines.py) against the render, per plate, at 4x supersampling:
#  A) notches:   no narrow inlet in an outline (the closing of its shape by a 1.25 px disk adds under 1 px^2)
#  B) coverage:  the fill covers every pixel of the plate's surface: light against the plate's own brightness
#                (>= 0.6 of the brightest of its core within 8 px) and joined to its core
#  C) contains:  the outline lies inside its own fill (under 0.5 px^2 of it outside, from rounding)
#  D) overlap:   no fill reaches onto another plate's outline (under 1 px^2)
# Exits 1 and names the plate and place of every failure.   python check_outlines.py [assets_dir=../assets]
import json, os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage.morphology import disk

A = sys.argv[1] if len(sys.argv) > 1 else "../assets"
U = 4
maps = json.load(open(f"{A}/outlines.json"))["maps"]


def raster(polys, x0, y0, w, h):
    img = Image.new("L", (w * U, h * U), 0)
    d = ImageDraw.Draw(img)
    for poly in polys:
        d.polygon([((poly[k] - x0) * U, (poly[k + 1] - y0) * U) for k in range(0, len(poly), 2)], fill=255)
    return np.asarray(img) > 0


def blobs(mask, scale):
    """(area in px^2, x, y) of each connected piece of mask, centres in crop px."""
    lab, k = ndi.label(mask, structure=np.ones((3, 3)))
    if not k:
        return []
    sizes = ndi.sum(mask, lab, range(1, k + 1)) / scale ** 2
    return [(s, c[1] / scale, c[0] / scale) for s, c in zip(sizes, ndi.center_of_mass(mask, lab, range(1, k + 1)))]


failures = []
for name, m in maps.items():
    rgba = np.asarray(Image.open(f"{A}/{name}.png").convert("RGBA")).astype(float)
    ids = np.asarray(Image.open(f"{A}/{name}_ids.png").convert("RGB"))
    plate, tint = ids[..., 0], ids[..., 1] / 255
    lum, body = rgba[..., :3].mean(2), rgba[..., 3] >= 200
    H, W = plate.shape
    counts = dict(notch=0, uncovered=0, outside=0, overlap=0)
    for pid, polys in m["plates"].items():
        p, fill = int(pid), m["fills"].get(pid, [])
        xs = [v for q in polys + fill for v in q[0::2]]
        ys = [v for q in polys + fill for v in q[1::2]]
        x0, y0 = max(int(min(xs)) - 12, 0), max(int(min(ys)) - 12, 0)
        w, h = min(int(max(xs)) + 13, W) - x0, min(int(max(ys)) + 13, H) - y0
        O, F = raster(polys, x0, y0, w, h), raster(fill, x0, y0, w, h)

        def fail(kind, s, cx, cy):
            counts[kind] += 1
            failures.append(f"{kind:9s} {name} plate {p} at ({x0 + cx:.0f}, {y0 + cy:.0f}): {s:.1f} px^2")

        pad = 10
        notch = (ndi.binary_closing(np.pad(O, pad), disk(int(1.25 * U))) & ~np.pad(O, pad))[pad:-pad, pad:-pad]
        for s, cx, cy in blobs(notch, U):
            if s >= 1.0:
                fail("notch", s, cx, cy)

        mine = (plate[y0:y0 + h, x0:x0 + w] == p) & body[y0:y0 + h, x0:x0 + w]
        core = mine & (tint[y0:y0 + h, x0:x0 + w] >= 0.5)
        L = lum[y0:y0 + h, x0:x0 + w]
        bright = ndi.grey_dilation(np.where(core, L, 0), footprint=disk(8))
        surface = mine & (L >= 0.6 * np.maximum(bright, 1)) & (bright > 0)
        lab, _ = ndi.label(surface, structure=np.ones((3, 3)))
        surface = np.isin(lab, np.unique(lab[core & (lab > 0)]))
        covered = ndi.binary_dilation(F, iterations=U // 2).reshape(h, U, w, U).any(axis=(1, 3))   # 0.5 px tolerance
        for s, cx, cy in blobs(surface & ~covered, 1):
            if s >= 2:
                fail("uncovered", s, cx, cy)

        out = (O & ~F).sum() / U ** 2
        if out >= 0.5:
            ys_, xs_ = np.nonzero(O & ~F)
            fail("outside", out, xs_.mean() / U, ys_.mean() / U)

        others = raster([q for o, ps in m["plates"].items() if o != pid for q in ps], x0, y0, w, h)
        for s, cx, cy in blobs(F & ndi.binary_erosion(others, iterations=U // 2), U):
            if s >= 1.0:
                fail("overlap", s, cx, cy)
    print(f"{name}: {len(m['plates'])} plates, " + ", ".join(f"{k} {v}" for k, v in counts.items()))

if failures:
    print(f"\n{len(failures)} failures:\n  " + "\n  ".join(failures))
    sys.exit(1)
print("outlines OK")
