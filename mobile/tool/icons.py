"""Draw the Android launcher icons from the brand mark in ../app/icon.svg.

The mark is two brackets around a dumbbell tilted 45 degrees, the closing bracket in the accent green, on a dark
rounded square. Its proportions follow the design system's logo: a square frame, arms 15.6% of the bracket height,
and strokes at 1.3x the logo's weight so they hold up at launcher sizes. Everything sits inside Android's safe zone.

Rather than rasterising the SVG (no cairo here) this redraws it with Pillow, supersampled. Every stroke is horizontal
or vertical before the tilt, so each one is an exact rounded rectangle. The dumbbell is drawn upright on a mask and
rotated, and colour is painted through masks so rotated edges stay clean.

  python -I tool/icons.py          writes prod icons under android/app/src/main/res and staging ones under
                                   android/app/src/staging/res (amber closing bracket, so the two are told apart)

Legacy ic_launcher.png is the full rounded square. The adaptive icon (API 26+) is a solid background colour
plus a transparent foreground with the mark inside the safe zone, and a white monochrome layer for themed icons.
"""
import os
from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
INK, PAPER = (27, 27, 27, 255), (238, 238, 238, 255)
ACCENT = {'prod': (134, 171, 122, 255), 'staging': (224, 160, 48, 255)}
SS = 4  # supersample

# the SVG's 100-unit tile: what the launcher shows. Brackets: (x, y) points, stroke width.
W = 7.09
LEFT = [(30.05, 21), (21, 21), (21, 79), (30.05, 79)]
RIGHT = [(69.95, 21), (79, 21), (79, 79), (69.95, 79)]
# the dumbbell before rotate(-45 50 50): the bar as a stroke, the plates as (x, y, w, h, corner radius)
BAR, BAR_W = [(32, 50), (68, 50)], 5.32
PLATES = [(34.36, 38, 10.28, 24, 2), (55.36, 38, 10.28, 24, 2), (27.78, 42.5, 7.44, 15, 1.8), (64.78, 42.5, 7.44, 15, 1.8)]
TILE_RADIUS = 22


def stroke(d, pts, width, tf):
    """A polyline of horizontal and vertical segments with round caps and joins, one rounded rectangle per segment."""
    r = width / 2
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        (ax, ay), (bx, by) = tf(min(x0, x1), min(y0, y1)), tf(max(x0, x1), max(y0, y1))
        d.rounded_rectangle([ax - r, ay - r, bx + r, by + r], radius=r, fill=255)


def masks(s, unit, off):
    """Paper and accent masks at s pixels, the 100-unit tile scaled by `unit` pixels and shifted by `off`."""
    def tf(x, y):
        return (off + x * unit, off + y * unit)
    paper, accent, bell = (Image.new('L', (s, s), 0) for _ in range(3))
    stroke(ImageDraw.Draw(paper), LEFT, W * unit, tf)
    stroke(ImageDraw.Draw(accent), RIGHT, W * unit, tf)
    d = ImageDraw.Draw(bell)
    stroke(d, BAR, BAR_W * unit, tf)
    for x, y, w, h, r in PLATES:
        d.rounded_rectangle([*tf(x, y), *tf(x + w, y + h)], radius=r * unit, fill=255)
    bell = bell.rotate(45, resample=Image.BICUBIC, center=tf(50, 50))  # Pillow turns counterclockwise, as SVG's -45 does
    return ImageChops.lighter(paper, bell), accent


def paint(im, paper, accent, colours):
    im.paste(colours[0], (0, 0), paper)
    im.paste(colours[1], (0, 0), accent)
    return im


def legacy(size, accent):
    s = size * SS
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle([0, 0, s - 1, s - 1], radius=TILE_RADIUS * s / 100, fill=INK)
    paint(im, *masks(s, s / 100, 0), (PAPER, accent))
    return im.resize((size, size), Image.LANCZOS)


def foreground(size, accent, mono=False):
    """108-unit adaptive canvas; launchers show the middle 72, so that is where the 100-unit tile goes."""
    s = size * SS
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    paint(im, *masks(s, s * 72 / 108 / 100, s * 18 / 108), (PAPER, PAPER if mono else accent))
    return im.resize((size, size), Image.LANCZOS)


DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def write(flavor, res):
    accent = ACCENT[flavor]
    for name, k in DENSITY.items():
        folder = os.path.join(res, f'mipmap-{name}')
        os.makedirs(folder, exist_ok=True)
        legacy(round(48 * k), accent).save(os.path.join(folder, 'ic_launcher.png'))
        foreground(round(108 * k), accent).save(os.path.join(folder, 'ic_launcher_foreground.png'))
        if flavor == 'prod':
            foreground(round(108 * k), accent, mono=True).save(os.path.join(folder, 'ic_launcher_monochrome.png'))
    if flavor == 'prod':
        any_ = os.path.join(res, 'mipmap-anydpi-v26')
        os.makedirs(any_, exist_ok=True)
        with open(os.path.join(any_, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                    '    <background android:drawable="@color/ic_launcher_background"/>\n'
                    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n</adaptive-icon>\n')
        values = os.path.join(res, 'values')
        os.makedirs(values, exist_ok=True)
        with open(os.path.join(values, 'colors.xml'), 'w', encoding='utf-8') as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#1b1b1b</color>\n</resources>\n')
    # a 512 preview beside the script, handy for the store listing and for checking the drawing
    legacy(512, accent).save(os.path.join(ROOT, 'tool', f'icon-{flavor}.png'))


if __name__ == '__main__':
    write('prod', os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res'))
    write('staging', os.path.join(ROOT, 'android', 'app', 'src', 'staging', 'res'))
    print('icons written')
