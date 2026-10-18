# Trace every plate's visible surface as smooth sub-pixel polygons, so an app can fill and outline muscles as vector
# paths (crisp at any zoom) instead of tinting pixels. Two shapes per plate:
#   outline  the plate's visible edge, smoothed: what a renderer would stroke to outline a plate (the fill grows from it)
#   fill     the outline grown GROW px into the groove around it, stopping at other plates: what a highlight fills.
#            A highlight multiplies the render, which leaves the near-black grooves near-black, so a fill that runs a
#            little past the edge is invisible there and covers the edge's anti-aliasing and bright tips completely.
#   python outlines.py [assets_dir=../assets]   -> <assets_dir>/outlines.json
#
# The surface. A plate is light and its edge is where the render drops into the dark groove or outline around it, but
# plates are shaded and darken a lot towards some rims (the outer calves), so no single brightness finds that edge.
# Each pixel of the plate's id region is measured against the plate's own brightness nearby (the brightest of its
# tinted core within RADIUS px): at least half of it is plate. Every such light piece within REACH px of the core
# belongs to the plate, which takes in thin light strips along an edge and the bright highlight at a tip. Narrow dark
# gaps inside the plate (creases, the faint line beside a strip) close up (CLOSE px) and enclosed ones fill, so the
# outline goes around the whole muscle rather than into it. Plates never merge: each is traced on its own id region.
#
# The edge. The outline is the half level of a sub-pixel field: the luminance ratio itself where the edge is a real
# luminance edge, pinned inside / outside the surface where the surface was decided otherwise. The body's silhouette
# comes from the alpha channel blurred BODY px (the cutout's edge is ragged and its transparent pixels store black,
# so their brightness is taken from their neighbours). Then the contour is smoothed along its own length: ARC px on
# gentle stretches, TIP_ARC px at tips and tight bends (chosen per point from the curvature), and SIL_ARC px where it
# runs within SIL_D px of the silhouette (the render's dark rim there varies in width; the silhouette does not).
#
# outlines.json: {"maps": {"male_front": {"w": 1254, "h": 1254, "plates": {"<id>": [[x0, y0, x1, y1, ...], ...]},
# "fills": {"<id>": [...]}}}} with coordinates in the asset's pixel space, rounded to 0.1 px, polygons closed implicitly.
import json, os, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from skimage import measure
from skimage.morphology import disk

ASSETS = sys.argv[1] if len(sys.argv) > 1 else "../assets"
MAPS = ["male_front", "male_back", "female_front", "female_back"]
RADIUS = 8           # px, how far a pixel looks for its plate's brightness
LEVEL = 0.5          # a pixel is plate while at least this fraction of that brightness
REACH = 4            # px, light pieces this close to the core are the plate's (strips, tips)
CLOSE = 3            # px, dark gaps inside a plate narrower than twice this close up
BODY = 1.2           # px, blur of the alpha channel for the silhouette
SIGMA = 0.6          # px, blur of the sub-pixel field
ARC = 2.2            # px, smoothing along gentle stretches of the outline
TIP_ARC = 0.4        # px, smoothing at tips and tight bends
TIP_CURVATURE = 0.4  # 1/px, curvature from which a bend counts as tight (fully so at twice this)
SIL_D = 4.0          # px, outline this close to the silhouette follows it...
SIL_ARC = 3.5        # px, ...with this much smoothing
GROW = 1.0           # px, how far the fill runs past the outline
MIN_AREA = 12.0      # px^2, drops specks
TOLERANCE = 0.15     # px, polygon simplification
U = 4                # supersampling of the fill raster


def resample(c, step=0.25):
    """A closed contour (rows, cols) resampled every `step` px along its length, and the actual spacing."""
    cc = np.vstack([c, c[:1]])
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(cc, axis=0), axis=1))])
    n = max(int(s[-1] / step), 8)
    t = np.linspace(0, s[-1], n, endpoint=False)
    return np.column_stack([np.interp(t, s, cc[:, 0]), np.interp(t, s, cc[:, 1])]), s[-1] / n


def curvature(r, h):
    d1 = (np.roll(r, -1, 0) - np.roll(r, 1, 0)) / (2 * h)
    d2 = (np.roll(r, -1, 0) - 2 * r + np.roll(r, 1, 0)) / h ** 2
    return np.abs(d1[:, 0] * d2[:, 1] - d1[:, 1] * d2[:, 0]) / np.maximum(np.linalg.norm(d1, axis=1) ** 3, 1e-9)


def smooth(c, silhouette=None):
    """Smooth a closed contour along its length: ARC on gentle stretches, TIP_ARC at tight bends, SIL_ARC near the
    silhouette. `silhouette` is (distance to the body's edge, row offset, col offset) or None."""
    r, h = resample(c)
    if len(r) < 16:
        return r
    gentle = ndi.gaussian_filter1d(r, ARC / h, axis=0, mode="wrap")
    tight = ndi.gaussian_filter1d(r, TIP_ARC / h, axis=0, mode="wrap")
    w = np.clip(curvature(gentle, h) / TIP_CURVATURE - 1, 0, 1)
    w = ndi.gaussian_filter1d(ndi.maximum_filter1d(w, int(1.5 / h), mode="wrap"), 0.75 / h, mode="wrap")
    out = gentle + w[:, None] * (tight - gentle)
    if silhouette is not None:
        dist, dy, dx = silhouette
        rows = np.clip(np.round(r[:, 0] + dy).astype(int), 0, dist.shape[0] - 1)
        cols = np.clip(np.round(r[:, 1] + dx).astype(int), 0, dist.shape[1] - 1)
        ws = ndi.gaussian_filter1d(np.clip((SIL_D - dist[rows, cols]) / 1.5, 0, 1) * (1 - w), 1.0 / h, mode="wrap")
        out = out + ws[:, None] * (ndi.gaussian_filter1d(r, SIL_ARC / h, axis=0, mode="wrap") - out)
    return out


def contours(field, x0, y0, scale=1, silhouette=None):
    """The half-level contours of `field` (a crop at (x0, y0), `scale` samples per px), smoothed, as flat x, y lists
    in asset pixels (pixel centres)."""
    polys = []
    for c in measure.find_contours(np.pad(field, 1), 0.5):
        c = (c[:-1] - 1 + 0.5) / scale - 0.5            # undo the pad; samples -> px
        area = 0.5 * abs(np.dot(c[:, 0], np.roll(c[:, 1], 1)) - np.dot(c[:, 1], np.roll(c[:, 0], 1)))
        if area < MIN_AREA:
            continue
        c = smooth(c, silhouette)
        c = measure.approximate_polygon(np.vstack([c, c[:1]]), TOLERANCE)[:-1]
        flat = np.empty(len(c) * 2)
        flat[0::2], flat[1::2] = c[:, 1] + x0 + 0.5, c[:, 0] + y0 + 0.5
        polys.append([round(float(v), 1) for v in flat])
    return polys


def closing(mask, r):
    pad = r + 1
    return ndi.binary_closing(np.pad(mask, pad), structure=disk(r))[pad:-pad, pad:-pad]


def keep_touching(mask, seed):
    lab, _ = ndi.label(mask, structure=np.ones((3, 3)))
    return np.isin(lab, np.unique(lab[seed & (lab > 0)]))


def raster(polys, x0, y0, w, h):
    """Polygons (asset px) filled into a U-times supersampled crop at (x0, y0) of w x h px."""
    img = Image.new("L", (w * U, h * U), 0)
    d = ImageDraw.Draw(img)
    for poly in polys:
        d.polygon([((poly[k] - x0) * U, (poly[k + 1] - y0) * U) for k in range(0, len(poly), 2)], fill=255)
    return np.asarray(img) > 0


out = {"maps": {}}
for name in MAPS:
    rgba = np.asarray(Image.open(f"{ASSETS}/{name}.png").convert("RGBA")).astype(float)
    ids = np.asarray(Image.open(f"{ASSETS}/{name}_ids.png").convert("RGB"))
    plate, tint = ids[..., 0], ids[..., 1].astype(float) / 255
    alpha = rgba[..., 3] / 255
    lum = rgba[..., :3].mean(2)
    near = ndi.gaussian_filter(lum * alpha, 1.0) / np.maximum(ndi.gaussian_filter(alpha, 1.0), 1e-3)
    lum = np.where(alpha > 0.9, lum, near)            # the ragged edge's transparent pixels store black
    smooth_alpha = ndi.gaussian_filter(alpha, BODY)
    body = smooth_alpha >= 0.5
    edge = np.clip((smooth_alpha - 0.5) * 3 + 0.5, 0, 1)
    to_edge = ndi.distance_transform_edt(body)
    h, w = plate.shape

    outlines, boxes = {}, {}
    for p in np.unique(plate):
        if p == 0:
            continue
        ys, xs = np.nonzero(plate == p)
        m = RADIUS + 8
        y0, y1, x0, x1 = max(ys.min() - m, 0), min(ys.max() + m + 1, h), max(xs.min() - m, 0), min(xs.max() + m + 1, w)
        mine = (plate[y0:y1, x0:x1] == p) & body[y0:y1, x0:x1]
        core = mine & (tint[y0:y1, x0:x1] >= 0.5)
        if not core.any():
            continue
        cl, k = ndi.label(core, structure=np.ones((3, 3)))     # the core's main pieces (not rim-light slivers)
        sizes = ndi.sum(core, cl, range(1, k + 1))
        main = np.isin(cl, [i + 1 for i in range(k) if sizes[i] >= 0.25 * sizes.max()])
        L = lum[y0:y1, x0:x1]
        bright = ndi.grey_dilation(np.where(core, L, 0), footprint=disk(RADIUS))
        ratio = np.where(mine & (bright > 0), L / np.maximum(bright, 1), 0)
        light = (ratio >= LEVEL) | core
        surface = keep_touching(light, light & ndi.binary_dilation(main, structure=disk(REACH)))
        surface = ndi.binary_fill_holes(closing(surface, CLOSE) & mine) & mine
        surface = keep_touching(surface, main & surface)
        # the sub-pixel field: the ratio (0.5 at LEVEL), at least 0.62 inside the surface rising to 1 a few px in,
        # at most 0.38 outside it, and never past the silhouette
        field = np.clip(ratio / (2 * LEVEL), 0, 1)
        inside = ndi.gaussian_filter(ndi.distance_transform_edt(surface), 1.0)
        field = np.where(surface, np.maximum(field, np.clip(0.5 + inside / 6, 0.62, 1)), np.minimum(field, 0.38))
        field = np.minimum(field, edge[y0:y1, x0:x1])
        polys = contours(ndi.gaussian_filter(field, SIGMA), x0, y0, silhouette=(to_edge, y0, x0))
        if polys:
            outlines[str(int(p))] = polys
            boxes[str(int(p))] = (x0, y0, x1 - x0, y1 - y0)

    fills = {}
    for p, polys in outlines.items():
        x0, y0, bw, bh = boxes[p]
        mask = raster(polys, x0, y0, bw, bh)
        others = raster([q for o, ps in outlines.items() if o != p for q in ps], x0, y0, bw, bh)
        grown = ndi.distance_transform_edt(~mask) <= GROW * U
        grown = keep_touching(grown & ~ndi.binary_dilation(others, iterations=U // 2), mask) | mask
        fills[p] = contours(ndi.gaussian_filter(grown.astype(float), U * 0.4), x0, y0, scale=U)
    out["maps"][name] = {"w": w, "h": h, "plates": outlines, "fills": fills}
    print(f"{name}: {len(outlines)} plates, {sum(len(q) // 2 for ps in outlines.values() for q in ps)} outline points, "
          f"{sum(len(q) // 2 for ps in fills.values() for q in ps)} fill points")

with open(f"{ASSETS}/outlines.json", "w") as f:
    json.dump(out, f, separators=(",", ":"))
print(f"wrote {ASSETS}/outlines.json ({os.path.getsize(f'{ASSETS}/outlines.json') // 1024} KB)")
