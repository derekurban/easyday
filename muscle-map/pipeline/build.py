# Build web assets for the flat muscle map: base RGBA image, plate-id map, metadata. Also writes verification images.
#   python build.py [out_dir=../assets]   (reads work/ from segment.py + fix_nipples.py, labels from labels.py)
import sys, os, json
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from labels import LABELS, GROUPS

OUT = sys.argv[1] if len(sys.argv) > 1 else "../assets"; os.makedirs(OUT, exist_ok=True); os.makedirs("verify", exist_ok=True)
font = ImageFont.truetype("arial.ttf", 18)
GCOL = {g: c for g, c in zip(GROUPS, [(230, 25, 75), (60, 180, 75), (255, 225, 25), (0, 130, 200), (245, 130, 48), (145, 30, 180),
                                       (70, 240, 240), (240, 50, 230), (210, 245, 60), (250, 190, 212), (0, 128, 128), (220, 190, 255),
                                       (170, 110, 40), (255, 250, 200), (128, 0, 0), (170, 255, 195), (0, 0, 128)])}
meta = {"groups": GROUPS, "maps": {}}
report = []
for name, labels in LABELS.items():
    rgba = np.asarray(Image.open(f"work/{name}_base.png").convert("RGBA")).copy()
    # remove stray semi-transparent specks outside the body: keep only the main connected silhouette
    alab, ak = ndi.label(rgba[..., 3] > 0, structure=np.ones((3, 3)))
    asz = ndi.sum(np.ones_like(alab), alab, range(1, ak + 1))
    stray = (alab > 0) & (alab != np.argmax(asz) + 1)
    report.append(f"{name}: removed {int(stray.sum())} stray background px in {ak - 1} specks")
    rgba[stray] = 0
    # de-fringe: semi-transparent edge pixels carry light background halo from the cutout -> give them the colour of
    # the nearest fully opaque pixel (the body's dark outline), keep their alpha for anti-aliasing
    opaque = rgba[..., 3] >= 200          # source alpha is noisy (240-253 inside the body)
    fr = (rgba[..., 3] > 0) & ~opaque
    # smooth fill: normalized Gaussian average of nearby opaque colours (no stair-steps), nearest-copy as fallback
    w = opaque.astype(float); fill = np.zeros(rgba.shape[:2] + (3,))
    den = ndi.gaussian_filter(w, 1.6)
    for c in range(3):
        fill[..., c] = ndi.gaussian_filter(rgba[..., c].astype(float) * w, 1.6) / np.maximum(den, 1e-6)
    _, (oy, ox) = ndi.distance_transform_edt(~opaque, return_indices=True)
    far = den < 0.02
    fill[far] = rgba[oy[far], ox[far], :3]
    rgba[fr, :3] = np.clip(fill[fr], 0, 255).astype(np.uint8)
    report.append(f"{name}: de-fringed {int(fr.sum())} edge px")
    g = rgba[..., :3].astype(float).mean(2); fig = rgba[..., 3] > 128
    T = json.load(open(f"work/{name}_seg.json"))["T"]
    cc = np.load(f"work/{name}_cc.npy").astype(np.int32)
    n = int(cc.max())
    missing = sorted(set(range(1, n + 1)) - set(labels)); extra = sorted(set(labels) - set(range(1, n + 1)))
    assert not missing and not extra, (name, missing, extra)
    # --- extend plate ids by watershed on luminance: plates grow outward until they meet at the darkest line of the
    # groove between them (never past it). Limited to pixels within 14 px of a plate core.
    from skimage.segmentation import watershed, find_boundaries
    dist = ndi.distance_transform_edt(cc == 0)
    region = (rgba[..., 3] > 0) & (dist <= 14)
    ids = watershed(-ndi.gaussian_filter(g, 0.7), markers=cc, mask=region | (cc > 0)).astype(np.int32)
    # keep only the main connected body of each plate (drops 1-30 px specks along silhouette / inside grooves)
    for i in range(1, n + 1):
        lab, k = ndi.label(ids == i)
        if k > 1:
            sizes = ndi.sum(np.ones_like(lab), lab, range(1, k + 1))
            ids[(lab > 0) & (lab != (np.argmax(sizes) + 1))] = 0
    # verification 1: light pixels that are not covered by any plate
    uncovered = fig & (g > T) & (ids == 0)
    # verification 2: does any plate id cross a dark groove into another plate's region? (each id must stay connected)
    split = [i for i in range(1, n + 1) if ndi.label(ids == i)[1] != 1]
    report.append(f"{name}: plates {n}, uncovered light px {int(uncovered.sum())}, disconnected ids {split}")
    # per-pixel tint strength: bright (luminance) AND not inside a groove (black top-hat = local valley depth).
    # This keeps faint grooves between plates untinted, so a highlight can never bridge two plates.
    a_lum = np.clip((g - (T - 38)) / 50, 0, 1)
    seam = find_boundaries(ids, mode="inner") & (ids > 0)
    alpha = a_lum * (ids > 0) * np.where(seam, 0.25, 1.0)   # hairline at seams (edge AA handled by base alpha in the renderer)
    # tint may only reach pixels connected to the plate's own core (drops rim-light slivers beyond the outline)
    for pid, thr in [(p_, t_) for t_ in (0.02, 0.1) for p_ in range(1, n + 1)]:
        lab, k = ndi.label((ids == pid) & (alpha > thr), structure=np.ones((3, 3)))
        if k > 1:
            keep = np.unique(lab[(cc == pid) & (lab > 0)]) if thr < 0.05 else [np.argmax(ndi.sum(np.ones_like(lab), lab, range(1, k + 1))) + 1]
            alpha[(lab > 0) & ~np.isin(lab, keep)] = 0
    np.save(f"work/{name}_alpha.npy", alpha)
    Image.fromarray(np.dstack([ids.astype(np.uint8), (alpha * 255).round().astype(np.uint8), np.zeros_like(ids, np.uint8)]), "RGB").save(f"{OUT}/{name}_ids.png")
    Image.fromarray(rgba).save(f"{OUT}/{name}.png")
    plates = []
    coms = ndi.center_of_mass(cc > 0, cc, range(1, n + 1))
    for i in range(1, n + 1):
        m, grp = labels[i]
        plates.append({"id": i, "muscle": m, "group": grp, "cx": round(coms[i - 1][1]), "cy": round(coms[i - 1][0])})
    meta["maps"][name] = {"T": T, "w": rgba.shape[1], "h": rgba.shape[0], "plates": plates}
    # verification 3: every plate painted with its group colour + muscle names, uncovered light px in magenta
    lut = np.zeros((256, 3), np.uint8)
    for i in range(1, n + 1):
        grp = labels[i][1]; lut[i] = GCOL[grp] if grp else (90, 90, 90)
    a = np.clip((g - (T - 35)) / 50, 0, 1)[..., None]
    base = np.dstack([g, g, g]) * 0.9
    vis = np.where((ids > 0)[..., None], base * (1 - a * 0.75) + lut[ids] * a * 0.75, base)
    vis[~(rgba[..., 3] > 0)] = 255
    vis[uncovered] = (255, 0, 255)
    im = Image.fromarray(vis.astype(np.uint8)); d = ImageDraw.Draw(im)
    for p in plates:
        d.text((p["cx"] - 8, p["cy"] - 9), str(p["id"]), fill=(0, 0, 0), font=font)
    im.save(f"verify/{name}_groups.png")
json.dump(meta, open(f"{OUT}/flat.json", "w"), indent=1)
print("\n".join(report))
# legend
leg = Image.new("RGB", (260, 22 * len(GROUPS) + 10), "white"); d = ImageDraw.Draw(leg)
for k, gname in enumerate(GROUPS):
    d.rectangle((8, 8 + k * 22, 26, 24 + k * 22), fill=GCOL[gname]); d.text((34, 7 + k * 22), gname, fill=(0, 0, 0), font=font)
leg.save("verify/legend.png")
