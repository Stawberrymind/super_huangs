"""Draws the small hand-made sprites: RTX 5090 "coin", duck enemy, heart, sword, double-jump icon.

Usage (from the project root):
    python tools/make_sprites.py

Each sprite is a little ASCII picture below - edit the picture, re-run, done.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sprites')

PALETTE = {
    '.': (0, 0, 0, 0),
    'k': (20, 20, 24, 255),      # outline
    'd': (52, 56, 62, 255),      # dark metal
    'f': (150, 156, 164, 255),   # light metal
    's': (214, 222, 230, 255),   # silver
    'g': (118, 185, 0, 255),     # green
    'G': (172, 228, 72, 255),    # light green
    'y': (230, 190, 60, 255),    # gold
    'w': (246, 246, 240, 255),   # white feathers
    'a': (206, 210, 214, 255),   # feather shadow
    'o': (240, 140, 30, 255),    # orange bill / feet
    'h': (110, 74, 40, 255),     # wood
    'r': (232, 59, 82, 255),     # heart red
    'R': (255, 170, 180, 255),   # heart shine
    'H': None,                   # hair, replaced per duck
    'J': None,                   # hair highlight
}

GPU = [
    "................",
    "................",
    "................",
    ".kkkkkkkkkkkkkk.",
    "kgGggggggggggGgk",
    "kdkkkkddddkkkkdk",
    "kdkfskddddkfskdk",
    "kdksfkddddksfkdk",
    "kdkkkkddddkkkkdk",
    "kddddddddddddddk",
    ".kkkkkkkkkkkkkk.",
    "...yy.yy.yy.yy..",
    "................",
    "................",
    "................",
    "................",
]

DUCK = [
    "......HH........",
    ".....HJHH.......",
    "....kHHHHk......",
    "...kkkwwwwk.....",
    "...kwkwwwwk.....",
    ".ooowwwwwwk.....",
    ".ooowwwwwwkkk...",
    "...kwwwwwwwwwk..",
    "..kwwwwaaaawwwk.",
    "..kwwwaaaaaawwk.",
    "..kwwwwaaaawwwk.",
    "..kwwwwwwwwwwk..",
    "...kkwwwwwwkk...",
    ".....kkkkkk.....",
]
DUCK_FEET = [
    ["......o...o.....", ".....oo..oo....."],
    [".....o.....o....", "....oo....oo...."],
]
HAIR = {
    'brown': ((110, 66, 30, 255), (158, 100, 48, 255)),
    'blonde': ((240, 200, 70, 255), (255, 236, 150, 255)),
}

HEART = [
    ".rr.rr.",
    "rRrrrrr",
    "rrrrrrr",
    ".rrrrr.",
    "..rrr..",
    "...r...",
]

SWORD = [
    ".......k........",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "......ksk.......",
    "...kkkkkkkkk....",
    "...kgggGgggk....",
    "...kkkkhkkkk....",
    "......khk.......",
    "......kgk.......",
    ".......k........",
]

DOUBLE_JUMP = [
    "................",
    "................",
    ".......GG.......",
    "......GggG......",
    ".....Ggggggk....",
    "....Ggg..gggk...",
    "...Ggg....gggk..",
    "...kk......kkk..",
    ".......GG.......",
    "......GggG......",
    ".....Ggggggk....",
    "....Ggg..gggk...",
    "...Ggg....gggk..",
    "...kk......kkk..",
    "................",
    "................",
]


def draw(rows, palette=PALETTE):
    img = Image.new('RGBA', (len(rows[0]), len(rows)))
    for y, row in enumerate(rows):
        assert len(row) == len(rows[0]), row
        for x, ch in enumerate(row):
            img.putpixel((x, y), palette[ch])
    return img


def save(img, name):
    img.save(os.path.join(OUT, name))
    print('wrote assets/sprites/' + name, img.size)


def gpu_sheet():
    """12 frames like coin.png: the card spins around its vertical axis."""
    card = draw(GPU)
    sheet = Image.new('RGBA', (16 * 12, 16))
    for i, width in enumerate([16, 12, 8, 4, 8, 12, 16, 12, 8, 4, 8, 12]):
        frame = card.resize((width, 16), Image.NEAREST)
        sheet.alpha_composite(frame, (i * 16 + (16 - width) // 2, 0))
    return sheet


def duck_sheet():
    """Row 0 = brown hair, row 1 = blonde hair; 2 walk frames each."""
    sheet = Image.new('RGBA', (32, 32))
    for row, (dark, light) in enumerate(HAIR.values()):
        palette = dict(PALETTE, H=dark, J=light)
        for frame, feet in enumerate(DUCK_FEET):
            sheet.alpha_composite(draw(DUCK + feet, palette), (frame * 16, row * 16))
    return sheet


if __name__ == '__main__':
    save(gpu_sheet(), 'rtx5090.png')
    save(duck_sheet(), 'duck.png')
    save(draw(HEART), 'heart.png')
    save(draw(SWORD), 'sword.png')
    save(draw(DOUBLE_JUMP), 'double_jump.png')
