"""Draws the Aarast launcher icon and launch image in the teal identity (D0).

The mark is the first letter of the wordmark, a white «ع», with the
wordmark's saffron dot, on the brand teal.

  python tool/brand/draw_icon.py            # from mobile/

Writes every Android and iOS size the native assets test expects.
"""
import os

from PIL import Image, ImageDraw, ImageFont

TEAL = (11, 110, 105)       # AarastV3Color.primary 0xFF0B6E69
SAFFRON = (242, 169, 59)    # the wordmark dot
WHITE = (255, 255, 255)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Tajawal-Bold.ttf')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
IOS = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets')
WORK = 2048


def _glyph(ch, size):
    font = ImageFont.truetype(FONT, size)
    im = Image.new('L', (size * 3, size * 3), 0)
    ImageDraw.Draw(im).text((size, size), ch, font=font, fill=255)
    return im.crop(im.getbbox())


def mark(size, bg=True, scale=1.0):
    """The mark on a square of [size] px; [scale] shrinks it inside the square."""
    s = WORK
    img = Image.new('RGBA', (s, s), TEAL + (255,) if bg else (0, 0, 0, 0))
    ain = _glyph('ع', int(s * 0.62 * scale))
    x = (s - ain.width) // 2 + int(s * 0.035 * scale)
    y = (s - ain.height) // 2
    img.paste(WHITE + (255,), (x, y), ain)
    r = s * 0.056 * scale
    cx, cy = x - s * 0.105 * scale, y + s * 0.075 * scale
    ImageDraw.Draw(img).ellipse([cx - r, cy - r, cx + r, cy + r], fill=SAFFRON + (255,))
    return img.resize((size, size), Image.LANCZOS)


def _save(img, path, opaque=True):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        flat = Image.new('RGB', img.size, TEAL)
        flat.paste(img, mask=img.split()[3])
        img = flat
    img.save(path, optimize=True)


def _round(img):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, img.size[0] - 1, img.size[1] - 1], fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, mask=m)
    return out


def main():
    for folder, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        icon = mark(px)
        _save(icon, os.path.join(RES, 'mipmap-' + folder, 'ic_launcher.png'))
        _save(_round(icon), os.path.join(RES, 'mipmap-' + folder, 'ic_launcher_round.png'), opaque=False)
    # The adaptive-icon foreground (108dp, mark inside the 66dp safe zone).
    # It is also the Android 12 splash icon.
    for folder, px in (('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432)):
        _save(mark(px, bg=False, scale=0.62), os.path.join(RES, 'drawable-' + folder, 'ic_launcher_foreground.png'), opaque=False)
    # The launch image sits on the teal native splash, so it is the mark alone.
    for folder, px in (('mdpi', 96), ('hdpi', 144), ('xhdpi', 192), ('xxhdpi', 288), ('xxxhdpi', 384)):
        _save(mark(px, bg=False), os.path.join(RES, 'drawable-' + folder, 'launch_image.png'), opaque=False)
    for name, px in (('LaunchImage.png', 128), ('LaunchImage@2x.png', 256), ('LaunchImage@3x.png', 384)):
        _save(mark(px, bg=False), os.path.join(IOS, 'LaunchImage.imageset', name), opaque=False)
    ios = {
        'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
    }
    for name, px in ios.items():
        _save(mark(px), os.path.join(IOS, 'AppIcon.appiconset', name))
    print('icons written')


if __name__ == '__main__':
    main()
