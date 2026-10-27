"""Side by side: approved design (prototype golden) | real app screenshot,
same width, labelled, saved as one JPEG per screen."""
import sys
from PIL import Image, ImageDraw, ImageFont
proto_dir, real_dir, out_dir = sys.argv[1:4]
ids = sys.argv[4:]
font = ImageFont.truetype('/home/user/aarast-production/mobile/assets/fonts/IBMPlexSansArabic-Bold.ttf', 30)
W = 780
for i in ids:
    a = Image.open(f'{proto_dir}/{i}.png').convert('RGB')
    b = Image.open(f'{real_dir}/{i}.png').convert('RGB')
    a = a.resize((W, int(a.height * W / a.width))); b = b.resize((W, int(b.height * W / b.width)))
    h = max(a.height, b.height) + 70
    c = Image.new('RGB', (W * 2 + 30, h), (255, 255, 255))
    d = ImageDraw.Draw(c)
    d.text((20, 18), f'APPROVED DESIGN  ({i})', fill=(11, 110, 105), font=font)
    d.text((W + 50, 18), 'REAL APP  (demo seed, 390pt wide)', fill=(184, 67, 42), font=font)
    c.paste(a, (0, 70)); c.paste(b, (W + 30, 70))
    c = c.resize((c.width // 2, c.height // 2))
    c.save(f'{out_dir}/{i}.jpg', quality=82)
    print('saved', i)
