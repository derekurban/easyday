"""Cut the Android launcher icons from the generated brand image, tool/icon-source.png.

The mark is a level dumbbell whose bar is a horizon, with a half sun rising behind it, on a morning-blue tile. It was
generated as one picture (an image model, not a drawing), so this script takes the picture apart instead of redrawing it:

  background   a smooth colour model fitted to the tile's own blue, which also continues it past the tile's edge
  foreground   the dumbbell, the sun and their soft shadows, lifted off that blue with an alpha channel
  monochrome   the foreground's silhouette for themed icons, the sun at part strength so the dumbbell still reads

The generated picture is a pixel or two off left-right symmetry, so the left half is mirrored onto the right.

  python -I tool/icons.py          writes prod icons under android/app/src/main/res and staging ones under
                                   android/app/src/staging/res (the same mark on a dawn tile, indigo to peach,
                                   so the two are told apart)

Legacy ic_launcher.png is the full rounded square. The adaptive icon (API 26+) is a background layer, the transparent
foreground, and the monochrome layer. The source tile is what a launcher shows: the middle 72 of the 108-unit canvas.
To change the mark, replace tool/icon-source.png with another picture of one tile on a flat grey canvas and rerun.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SOURCE = os.path.join(ROOT, 'tool', 'icon-source.png')
TILE_RADIUS = 22    # legacy icon corner radius, in hundredths of the tile
GLYPH_SCALE = 1.0   # the mark's size against the source picture
MONO_SUN = 0.5      # the sun's strength in the monochrome layer
NOISE, EDGE, SOLID = 7.0, 150.0, 40.0   # colour distance from the tile: grain below, a full edge, surely the mark
# the staging tile, top (-1) to bottom (1): the dawn sky from docs/inspiration/icon-makeover/round-2/03-dawn-tile.png
DAWN = [(-1.0, (46, 30, 155)), (-0.73, (59, 38, 166)), (-0.49, (79, 49, 185)), (-0.24, (103, 61, 200)),
        (0.0, (128, 75, 206)), (0.24, (154, 92, 201)), (0.49, (191, 112, 188)), (0.73, (233, 137, 162)),
        (0.87, (250, 160, 147)), (1.0, (255, 175, 133))]


def terms(u, v):
    """A full cubic in the tile's own coordinates, -1 to 1 each way."""
    return np.stack([np.ones_like(u), u, v, u * u, u * v, v * v, u ** 3, u * u * v, u * v * v, v ** 3], -1)


def shrink(mask, px):
    return np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(2 * px + 1))) > 0


def layers():
    """The 108-unit canvas at the source's resolution: background model (RGB), foreground (RGBA), monochrome (L)."""
    im = np.asarray(Image.open(SOURCE).convert('RGB')).astype(np.float64)
    h, w, _ = im.shape
    canvas = im[5:40, 5:40].reshape(-1, 3).mean(0)
    tile = np.sqrt(((im - canvas) ** 2).sum(2)) > 40
    ys, xs = np.where(tile)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    for y in range(y0, y1):  # a near-white mark is as close to the grey canvas as to anything: fill each row across
        row = np.where(tile[y])[0]
        tile[y, row.min():row.max() + 1] = True
    cx, cy, half = (x0 + x1) / 2, (y0 + y1) / 2, max(x1 - x0, y1 - y0) / 2
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = (xx + 0.5 - cx) / half, (yy + 0.5 - cy) / half

    # the tile's colour: start from its outer ring, where the mark never is, then take in every pixel that agrees
    inner = shrink(tile, 12)
    fit = inner & ((np.abs(u) > 0.8) | (np.abs(v) > 0.8))
    for _ in range(5):
        coef, *_ = np.linalg.lstsq(terms(u[fit], v[fit]), im[fit], rcond=None)
        back = terms(u, v) @ coef
        dist = np.sqrt(((im - back) ** 2).sum(2))
        fit = inner & (dist < 6)

    # alpha: solid well inside the mark, a ramp across its edge and its shadows, nothing in the tile's grain
    alpha = np.clip((dist - NOISE) / (EDGE - NOISE), 0, 1)
    alpha[shrink(dist > SOLID, 4)] = 1
    alpha *= inner
    ys, xs = np.where(alpha >= 1)
    near = (xx > xs.min() - 60) & (xx < xs.max() + 60) & (yy > ys.min() - 60) & (yy < ys.max() + 60)
    alpha *= near  # the tile's own rim is not part of the mark
    colour = np.clip(back + (im - back) / np.maximum(alpha, 0.02)[..., None], 0, 255)

    # the mirror axis that best matches the silhouette to itself, to the half pixel
    span = int(half * 0.85)
    axis = min((round(2 * cx) + k for k in range(-40, 41)),
               key=lambda c2: np.abs(alpha[:, c2 // 2 - span:c2 // 2] - alpha[:, (c2 + 1) // 2:(c2 + 1) // 2 + span][:, ::-1]).sum())
    left, right = axis // 2, (axis + 1) // 2  # left half ends before `left`, right half starts at `right`
    for a in (alpha, colour):
        a[:, right:right + span] = a[:, left - span:left][:, ::-1]

    # sun or dumbbell, by warmth: the sun is yellow to coral, the dumbbell white to pale blue
    warm = np.clip((colour[..., 0] - colour[..., 2] - 20) / 40, 0, 1)
    mono = np.clip((alpha - 0.25) / 0.5, 0, 1) * (1 - (1 - MONO_SUN) * warm)

    # onto the 108-unit canvas, the tile in its middle 72 and the mark's axis on the centre line
    n = 2 * round(half * 108 / 72)
    ox, oy = n // 2 - (axis + 1) // 2, n // 2 - round(cy)
    fore = np.zeros((n, n, 4))
    shade = np.zeros((n, n))
    fore[oy:oy + h, ox:ox + w, :3], fore[oy:oy + h, ox:ox + w, 3], shade[oy:oy + h, ox:ox + w] = colour, alpha * 255, mono * 255
    gy, gx = np.mgrid[0:n, 0:n]
    gu, gv = np.clip((gx - ox + 0.5 - cx) / half, -1, 1), np.clip((gy - oy + 0.5 - cy) / half, -1, 1)
    sky = np.clip(terms(gu, gv) @ coef, 0, 255)
    stops = np.array([s for s, _ in DAWN])
    dawn = np.stack([np.interp(gv, stops, [c[i] for _, c in DAWN]) for i in range(3)], -1)

    def image(a):
        return Image.fromarray(a.round().astype(np.uint8))

    def scaled(im):
        if GLYPH_SCALE == 1:
            return im
        small = im.resize((round(n * GLYPH_SCALE),) * 2, Image.LANCZOS)
        out = Image.new(im.mode, (n, n), 0)
        out.paste(small, ((n - small.width) // 2,) * 2)
        return out

    return {'prod': image(sky), 'staging': image(dawn)}, scaled(image(fore)), scaled(image(shade))


BACK, FORE, MONO = layers()


def background(size, flavor):
    return BACK[flavor].resize((size, size), Image.LANCZOS)


def foreground(size):
    return FORE.resize((size, size), Image.LANCZOS)


def monochrome(size):
    white = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    white.putalpha(MONO.resize((size, size), Image.LANCZOS))
    return white


def legacy(size, flavor):
    """The tile as a launcher shows it: the middle 72 of the 108, in a rounded square."""
    n = FORE.width
    box = (n // 6, n // 6, n - n // 6, n - n // 6)
    flat = BACK[flavor].convert('RGBA')
    flat.alpha_composite(FORE)
    flat = flat.crop(box).resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=TILE_RADIUS * size * 4 / 100, fill=255)
    flat.putalpha(mask.resize((size, size), Image.LANCZOS))
    return flat


DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def write(flavor, res):
    for name, k in DENSITY.items():
        folder = os.path.join(res, f'mipmap-{name}')
        os.makedirs(folder, exist_ok=True)
        legacy(round(48 * k), flavor).save(os.path.join(folder, 'ic_launcher.png'), optimize=True)
        background(round(108 * k), flavor).save(os.path.join(folder, 'ic_launcher_background.png'), optimize=True)
        if flavor == 'prod':  # staging takes the mark itself from main
            foreground(round(108 * k)).save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)
            monochrome(round(108 * k)).save(os.path.join(folder, 'ic_launcher_monochrome.png'), optimize=True)
    if flavor == 'prod':
        any_ = os.path.join(res, 'mipmap-anydpi-v26')
        os.makedirs(any_, exist_ok=True)
        with open(os.path.join(any_, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                    '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
                    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n</adaptive-icon>\n')
    # a 512 preview beside the script, handy for the store listing and for checking the cut
    legacy(512, flavor).save(os.path.join(ROOT, 'tool', f'icon-{flavor}.png'), optimize=True)


if __name__ == '__main__':
    write('prod', os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res'))
    write('staging', os.path.join(ROOT, 'android', 'app', 'src', 'staging', 'res'))
    print('icons written')
