# Trace every plate's visible surface as smooth sub-pixel polygons, so an app can fill and outline muscles as vector
# paths (crisp at any zoom) instead of tinting pixels.
#   python outlines.py [assets_dir=../assets]   -> <assets_dir>/outlines.json
#
# The visible surface of plate p is where the id map's tint mask (green channel) is at least half on. Grooves carry the
# plate's id but not its tint, so tracing the tint rather than the id keeps outlines on the light plate and out of the
# dark grooves. The base alpha is left out on purpose: at the silhouette the traced edge then reaches the body's very
# edge (a fill drawn from the render itself shows nothing past it), leaving no untinted rim. A light blur before
# tracing removes pixel stair-steps; tiny fragments (specks of a plate's id inside another plate) are dropped.
#
# outlines.json: {"maps": {"male_front": {"w": 1254, "h": 1254, "plates": {"<id>": [[x0, y0, x1, y1, ...], ...]}}}}
# with coordinates in the asset's pixel space, rounded to 0.1 px, each polygon closed implicitly.
import json, os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

ASSETS = sys.argv[1] if len(sys.argv) > 1 else "../assets"
MAPS = ["male_front", "male_back", "female_front", "female_back"]
LEVEL = 0.5          # the tint mask's half-on level
BLUR = 0.9           # px, smooths stair-steps without moving the edge
MIN_AREA = 40.0      # px^2, drops specks
TOLERANCE = 0.25     # px, polygon simplification

out = {"maps": {}}
for name in MAPS:
    ids = np.asarray(Image.open(f"{ASSETS}/{name}_ids.png").convert("RGB"))
    plate, tint = ids[..., 0], ids[..., 1].astype(float) / 255
    h, w = plate.shape
    plates, points, dropped = {}, 0, 0
    for p in np.unique(plate):
        if p == 0:
            continue
        ys, xs = np.nonzero(plate == p)
        y0, y1, x0, x1 = max(ys.min() - 4, 0), min(ys.max() + 5, h), max(xs.min() - 4, 0), min(xs.max() + 5, w)
        field = np.where(plate[y0:y1, x0:x1] == p, tint[y0:y1, x0:x1], 0.0)
        field = ndi.gaussian_filter(field, BLUR)
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
