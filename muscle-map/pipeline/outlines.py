# Trace every plate's visible surface as smooth sub-pixel polygons, so an app can fill and outline muscles as vector
# paths (crisp at any zoom) instead of tinting pixels.
#   python outlines.py [assets_dir=../assets]   -> <assets_dir>/outlines.json
#
# A plate's surface is light and its edge is where the render drops sharply into the dark groove or outline around it.
# Plates are shaded, though, and darken a lot towards some edges (the outer calves), so no single brightness level
# finds that edge everywhere: the tint mask's half-on level (lum ~95) stops short of a shaded rim. Instead each pixel
# of the plate's id region is measured against the plate's own brightness nearby (the brightest of its tinted core
# within RADIUS px): a gently shaded rim stays above half of it, the groove's sharp drop falls well below. Grooves
# carry the plate's id but stay out, and plates never merge, since each plate is traced on its own id region.
#
# The traced field is blurred by BLUR px before the contour is taken, which rounds off what pixel noise leaves at the
# edge: nicks where a faint crease half-separates a light strip of the plate, hooks, stair-steps. That blur would also
# round sharp tips short, so the tint mask's half-on surface (lightly blurred, its main pieces only) is laid over the
# field to keep them. Pixels outside the body's silhouette (alpha below half) are never part of a plate, so outlines
# follow the body's edge instead of the cutout's noise. Tiny fragments are dropped.
#
# outlines.json: {"maps": {"male_front": {"w": 1254, "h": 1254, "plates": {"<id>": [[x0, y0, x1, y1, ...], ...]}}}}
# with coordinates in the asset's pixel space, rounded to 0.1 px, each polygon closed implicitly.
import json, os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure
from skimage.morphology import disk

ASSETS = sys.argv[1] if len(sys.argv) > 1 else "../assets"
MAPS = ["male_front", "male_back", "female_front", "female_back"]
RADIUS = 8           # px, how far a pixel looks for its plate's brightness
LEVEL = 0.5          # a pixel is plate while at least half as bright as that
BLUR = 2.0           # px, rounds off edge noise
TIP_BLUR = 0.9       # px, the tint surface that keeps tips
MIN_AREA = 40.0      # px^2, drops specks
TOLERANCE = 0.25     # px, polygon simplification


def main_pieces(mask):
    """mask without its small disconnected pieces (under a quarter of the largest): rim-light slivers."""
    lab, k = ndi.label(mask, structure=np.ones((3, 3)))
    if k <= 1:
        return mask
    sizes = ndi.sum(mask, lab, range(1, k + 1))
    return np.isin(lab, [i + 1 for i in range(k) if sizes[i] >= 0.25 * sizes.max()])


out = {"maps": {}}
for name in MAPS:
    rgba = np.asarray(Image.open(f"{ASSETS}/{name}.png").convert("RGBA")).astype(float)
    ids = np.asarray(Image.open(f"{ASSETS}/{name}_ids.png").convert("RGB"))
    plate, tint = ids[..., 0], ids[..., 1].astype(float) / 255
    lum, body = rgba[..., :3].mean(2), rgba[..., 3] >= 128
    h, w = plate.shape
    plates, points, dropped = {}, 0, 0
    for p in np.unique(plate):
        if p == 0:
            continue
        ys, xs = np.nonzero(plate == p)
        m = RADIUS + 4
        y0, y1, x0, x1 = max(ys.min() - m, 0), min(ys.max() + m + 1, h), max(xs.min() - m, 0), min(xs.max() + m + 1, w)
        mine = (plate[y0:y1, x0:x1] == p) & body[y0:y1, x0:x1]
        t = np.where(mine, tint[y0:y1, x0:x1], 0.0)
        core = mine & (t >= 0.5)
        if not core.any():
            continue
        L = lum[y0:y1, x0:x1]
        bright = ndi.grey_dilation(np.where(core, L, 0), footprint=disk(RADIUS))
        field = np.where(mine & (bright > 0), np.clip(L / np.maximum(bright, 1), 0, 1), 0)
        field[core] = 1
        lab, _ = ndi.label(field >= LEVEL)                  # only what joins the core
        field[(lab > 0) & ~np.isin(lab, lab[core])] = 0
        t[~main_pieces(t >= 0.5) & (t >= 0.5)] = 0
        field = np.maximum(ndi.gaussian_filter(field, BLUR), ndi.gaussian_filter(t, TIP_BLUR))
        polys = []
        for c in measure.find_contours(np.pad(field, 1), LEVEL):
            c = c - 1                                      # undo the pad
            area = 0.5 * abs(np.dot(c[:, 0], np.roll(c[:, 1], 1)) - np.dot(c[:, 1], np.roll(c[:, 0], 1)))
            if area < MIN_AREA:
                dropped += 1
                continue
            c = measure.approximate_polygon(c, TOLERANCE)[:-1]   # closed: drop the repeated first point
            flat = np.empty(len(c) * 2)
            flat[0::2], flat[1::2] = c[:, 1] + x0 + 0.5, c[:, 0] + y0 + 0.5   # (row, col) -> (x, y), pixel centres
            polys.append([round(float(v), 1) for v in flat])
            points += len(c)
        if polys:
            plates[str(int(p))] = polys
    out["maps"][name] = {"w": w, "h": h, "plates": plates}
    print(f"{name}: {len(plates)} plates, {points} points, {dropped} specks dropped")

with open(f"{ASSETS}/outlines.json", "w") as f:
    json.dump(out, f, separators=(",", ":"))
print(f"wrote {ASSETS}/outlines.json ({os.path.getsize(f'{ASSETS}/outlines.json') // 1024} KB)")
