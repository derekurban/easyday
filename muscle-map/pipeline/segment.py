# Plate segmentation: luminance threshold + black top-hat (catches faint thin grooves), noise removal,
# nipple inpainting. Writes work/<name>_cc.npy, numbered overlay, and cleaned RGBA base.
#   python segment.py <name> [x,y,r ...]   (optional disks to inpaint, e.g. nipples)
import sys, json, os
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from skimage.restoration import inpaint_biharmonic
os.makedirs("work", exist_ok=True)
name = sys.argv[1]
spots = [tuple(map(int, s.split(","))) for s in sys.argv[2:]]
im = np.asarray(Image.open(f"source/{name}.png").convert("RGBA")).astype(float)
rgb, alpha = im[..., :3].copy(), im[..., 3]
# --- paint out nipples (biharmonic inpaint inside small disks)
yy, xx = np.mgrid[:rgb.shape[0], :rgb.shape[1]]
if spots:
    mask = np.zeros(rgb.shape[:2], bool)
    for x, y, *r in [(*s, ) for s in spots]:
        rad = r[0] if r else 11
        mask |= (xx - x) ** 2 + (yy - y) ** 2 <= rad ** 2
    y0, y1 = max(0, yy[mask].min() - 30), yy[mask].max() + 30; x0, x1 = max(0, xx[mask].min() - 30), xx[mask].max() + 30
    sub = rgb[y0:y1, x0:x1] / 255
    for c in range(3):
        sub[..., c] = inpaint_biharmonic(sub[..., c], mask[y0:y1, x0:x1])
    rgb[y0:y1, x0:x1] = sub * 255
Image.fromarray(np.dstack([rgb, alpha]).clip(0, 255).astype(np.uint8), "RGBA").save(f"work/{name}_base.png")
g = rgb.mean(2); fig = alpha > 128
vals = g[fig]
hist, edges = np.histogram(vals, 256, (0, 256)); cen = (edges[:-1] + edges[1:]) / 2
w0 = np.cumsum(hist); w1 = w0[-1] - w0; s = np.cumsum(hist * cen)
m0 = s / np.maximum(w0, 1); m1 = (s[-1] - s) / np.maximum(w1, 1)
T = float(cen[np.argmax(w0 * w1 * (m0 - m1) ** 2)])
tophat = ndi.grey_closing(g, size=(9, 9)) - g          # thin dark lines -> large values
light = (g > T) & (tophat < 28) & fig
light = ndi.binary_erosion(fig, iterations=2) & ndi.binary_opening(light, structure=np.ones((3, 3)))
lab, n = ndi.label(light)
areas = ndi.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
keep = np.where(areas >= 60)[0] + 1
remap = np.zeros(n + 1, np.int32); remap[keep] = np.arange(1, len(keep) + 1)
lab = remap[lab]; n = len(keep)
np.save(f"work/{name}_cc.npy", lab.astype(np.int16))
json.dump({"T": T}, open(f"work/{name}_seg.json", "w"))
areas = ndi.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
print(name, "T", round(T, 1), "plates", n, "smallest", sorted(areas.astype(int).tolist())[:6])
rng = np.random.default_rng(7); pal = (rng.random((n + 1, 3)) * 150 + 90).astype(np.uint8); pal[0] = 0
base = (rgb * 0.35).astype(np.uint8); base[~fig] = 40
ov = np.where(lab[..., None] > 0, pal[lab], base)
o = Image.fromarray(ov.astype(np.uint8)).resize((2508, 2508), Image.NEAREST); d = ImageDraw.Draw(o)
font = ImageFont.truetype("arial.ttf", 22)
for i, (cy, cx) in enumerate(ndi.center_of_mass(lab > 0, lab, range(1, n + 1)), start=1):
    d.text((cx * 2 - 10, cy * 2 - 11), str(i), fill=(0, 0, 0), font=font)
o.save(f"work/{name}_numbered.png")
o.crop((600, 300, 1910, 1300)).save(f"work/{name}_num_top.png"); o.crop((800, 1000, 1710, 2250)).save(f"work/{name}_num_bot.png")
