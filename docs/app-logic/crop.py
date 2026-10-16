"""Trim white margins from build/*.png (keeps a 24px border). Run via the pipeline venv python."""
import sys, glob, os
import numpy as np, imageio.v3 as iio
for p in glob.glob(os.path.join(os.path.dirname(__file__), "build", "*.png")):
    im = iio.imread(p)[..., :3]
    mask = (im < 245).any(axis=2)
    ys, xs = np.where(mask)
    if len(ys) == 0: continue
    pad = 24
    y0, y1 = max(ys.min()-pad, 0), min(ys.max()+pad, im.shape[0])
    x0, x1 = max(xs.min()-pad, 0), min(xs.max()+pad, im.shape[1])
    iio.imwrite(p, im[y0:y1, x0:x1])
    print(os.path.basename(p), im.shape[1], im.shape[0], "->", x1-x0, y1-y0)
