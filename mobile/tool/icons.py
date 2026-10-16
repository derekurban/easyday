"""Draw the Android launcher icons from the brand mark in ../app/icon.svg.

The mark is two brackets around a bar, the closing bracket in the accent green, on a dark rounded square.
Rather than rasterising the SVG (no cairo here) this redraws its three stroked paths with Pillow, supersampled.

  python -I tool/icons.py          writes prod icons under android/app/src/main/res and staging ones under
                                   android/app/src/staging/res (amber closing bracket, so the two are told apart)

Legacy ic_launcher.png is the full rounded square. The adaptive icon (API 26+) is a solid background colour
plus a transparent foreground with the glyph inside the safe zone, and a white monochrome layer for themed icons.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
INK, PAPER = (27, 27, 27, 255), (238, 238, 238, 255)
ACCENT = {'prod': (134, 171, 122, 255), 'staging': (224, 160, 48, 255)}
SS = 4  # supersample

# the SVG: a 64-unit box, the paths in a 100-unit space transformed by translate(-0.8) scale(0.656)
LEFT = [(30, 22), (20, 22), (20, 78), (30, 78)]
RIGHT = [(70, 22), (80, 22), (80, 78), (70, 78)]
BAR = [[(34, 50), (66, 50)], [(34, 42), (34, 58)], [(42, 37), (42, 63)], [(58, 37), (58, 63)], [(66, 42), (66, 58)]]


def stroke(d, pts, width, color, tf):
    """A polyline with round caps and joins."""
    p = [tf(x, y) for x, y in pts]
    r = width / 2
    for a, b in zip(p, p[1:]):
        d.line([a, b], fill=color, width=max(1, round(width)))
    for x, y in p:
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def glyph(d, unit, accent, mono=None, offset=(0, 0)):
    """Draw the mark with the 64-unit box scaled by `unit` pixels and shifted by `offset`."""
    def tf(x, y):
        return (offset[0] + (-0.8 + 0.656 * x) * unit, offset[1] + (-0.8 + 0.656 * y) * unit)
    w9, w8 = 9 * 0.656 * unit, 8 * 0.656 * unit
    fg = mono or PAPER
    stroke(d, LEFT, w9, fg, tf)
    for seg in BAR:
        stroke(d, seg, w8, fg, tf)
    stroke(d, RIGHT, w9, mono or accent, tf)


def legacy(size, accent):
    s = size * SS
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    unit = s / 64
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=14 * unit, fill=INK)
    glyph(d, unit, accent)
    return im.resize((size, size), Image.LANCZOS)


def foreground(size, accent, mono=False):
    """108-unit adaptive canvas; the 64-unit box spans 80 units so the glyph sits inside the 66-unit safe circle."""
    s = size * SS
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    unit = s * 80 / 108 / 64
    off = (s - 64 * unit) / 2
    glyph(d, unit, accent, mono=PAPER if mono else None, offset=(off, off))
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
