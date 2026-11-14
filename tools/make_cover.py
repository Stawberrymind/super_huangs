import sys, random
from PIL import Image, ImageDraw, ImageFont
R = sys.argv[1]
W, H = 315, 250
T = 16
img = Image.new('RGBA', (W, H))
d = ImageDraw.Draw(img)
# banded pixel sky
top, bot = (58, 120, 214), (150, 205, 245)
bands = 10
for i in range(bands):
    t = i / (bands - 1)
    c = tuple(int(top[k] + (bot[k] - top[k]) * t) for k in range(3))
    d.rectangle([0, i * H // bands, W, (i + 1) * H // bands], fill=c + (255,))
# pixel clouds
def cloud(x, y, s):
    for dx, dy, w, h in [(2, 0, 6, 2), (0, 2, 12, 3), (1, 5, 10, 1)]:
        d.rectangle([x + dx * s, y + dy * s, x + (dx + w) * s - 1, y + (dy + h) * s - 1], fill=(255, 255, 255, 235))
cloud(14, 70, 3); cloud(250, 60, 2); cloud(205, 108, 2)

sheet = Image.open(f'{R}/assets/sprites/world_tileset.png').convert('RGBA')
def tile(ax, ay): return sheet.crop((ax * T, ay * T, ax * T + T, ay * T + T))
def put(t, x, y): img.alpha_composite(t, (x, y))
def frame(name, fx=0, fy=0, size=32, flip=False):
    f = Image.open(f'{R}/assets/sprites/{name}.png').convert('RGBA').crop((fx * size, fy * size, fx * size + size, fy * size + size))
    return f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f

ground_y = H - 2 * T - 6
cols = W // T + 1
# castle backdrop on the right
cx0, cx1, door = 13, 19, 16
for x in range(cx0, cx1 + 1):
    for r in range(1, 5):
        put(tile(11, 3), x * T, ground_y - r * T)
    put(tile(12, 3), x * T, ground_y - 5 * T)
    put(tile(13, 3), x * T, ground_y - 6 * T)
for x in range(door - 1, door + 2):
    put(tile(11, 3), x * T, ground_y - 6 * T)
    put(tile(12, 3), x * T, ground_y - 7 * T)
put(tile(12, 5), (door - 1) * T, ground_y - 8 * T)
put(tile(13, 5), door * T, ground_y - 8 * T)
put(tile(14, 5), (door + 1) * T, ground_y - 8 * T)
put(tile(13, 4), door * T, ground_y - 9 * T)
put(tile(11, 4), door * T, ground_y - 2 * T)
put(tile(11, 5), door * T, ground_y - T)
put(tile(15, 4), door * T, ground_y - 4 * T)
put(tile(12, 4), (door - 2) * T, ground_y - 3 * T)
put(tile(12, 4), (door + 2) * T, ground_y - 3 * T)
put(tile(14, 3), (cx0 + 1) * T, ground_y - 3 * T)
# flag
fx = 11
put(tile(10, 7), fx * T, ground_y - T)
for r in range(2, 5):
    put(tile(10, 5), fx * T, ground_y - r * T)
put(tile(10, 3), fx * T, ground_y - 5 * T)
# ground
for x in range(cols):
    put(tile(0, 0), x * T, ground_y)
    put(tile(0, 1), x * T, ground_y + T)
    put(tile(0, 1), x * T, ground_y + 2 * T)
# decoration
put(tile(6, 8), 2 * T, ground_y - T)
put(tile(11, 10), 8 * T, ground_y - T); put(tile(11, 8), 8 * T, ground_y - 2 * T); put(tile(11, 6), 8 * T, ground_y - 3 * T)
# floating brick platform with GPUs
for x in range(3, 7):
    put(tile(5, 0), x * T, ground_y - 4 * T)
gpu = Image.open(f'{R}/assets/sprites/rtx5090.png').convert('RGBA').crop((0, 0, 16, 16))
for gx, gy in [(3 * T + 8, ground_y - 6 * T + 4), (5 * T, ground_y - 6 * T - 2), (6 * T + 8, ground_y - 6 * T + 4),
               (9 * T + 8, ground_y - 5 * T), (1 * T, ground_y - 3 * T)]:
    put(gpu, gx, gy)
# sword "!" box
put(tile(5, 2), 4 * T + 8, ground_y - 7 * T - 10)
# characters (scaled 1x, sprites are 32x32 with feet near bottom)
knight = frame('knight')
princess = frame('princess', flip=True)
duck = frame('duck', size=16)
put(knight, 3 * T, ground_y - 32 + 2)
put(duck, 6 * T + 4, ground_y - 16)
put(princess, (door - 2) * T - 4, ground_y - 32 + 2)
sword = Image.open(f'{R}/assets/sprites/sword.png').convert('RGBA')
heart = Image.open(f'{R}/assets/sprites/heart.png').convert('RGBA')
put(heart, (door - 2) * T + 8, ground_y - 40)
put(heart, (door - 2) * T + 16, ground_y - 46)

# title: crisp pixel text with outline + drop shadow
def text(s, size, y, fill, font='PixelOperator8-Bold.ttf'):
    f = ImageFont.truetype(f'{R}/assets/fonts/{font}', size)
    w = int(d.textlength(s, font=f))
    x = (W - w) // 2
    m = Image.new('L', (W, H)); ImageDraw.Draw(m).text((x, y), s, font=f, fill=255)
    m = m.point(lambda v: 255 if v > 127 else 0)
    def stamp(mask, col, ox, oy):
        layer = Image.new('RGBA', (W, H), col); img.paste(layer, (ox, oy), mask)
    stamp(m, (20, 24, 30, 255), 2, 3)              # shadow
    for ox in (-2, -1, 0, 1, 2):
        for oy in (-2, -1, 0, 1, 2):
            if abs(ox) + abs(oy) <= 3:
                stamp(m, (20, 24, 30, 255), ox, oy)  # outline
    stamp(m, fill, 0, 0)
text('GEE PEE YOU', 24, 18, (118, 186, 0, 255))
text('COLLECT EVERY GPU - RESCUE THE PRINCESS', 8, 54, (255, 255, 255, 255))

out = img.resize((W * 2, H * 2), Image.NEAREST).convert('RGB')
out.save(sys.argv[2])
