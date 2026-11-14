"""Draft GPU-themed version of world_tileset.png.

Usage (from the project root):
    python tools/gpu_tileset.py [preview_dir]
Builds from tools/world_tileset_original.png and writes assets/sprites/world_tileset.png.

What it does
  * Tile rows 0-2 are copied unchanged, except the ?/! glyphs on the gray blocks
    (turned green) and on the terracotta blocks (turned red).
  * Everything below is recolored into a mostly gray/black palette with green accents.
  * New tiles are drawn into empty slots (see NEW_TILES / the printed map):
      flag:   (10,3) top with pennant, (10,5) pole (stack as many as you like), (10,7) base
      castle: brick wall, circuit-trim wall, battlements, window, door top/bottom,
              banner, roof tip + roof left/mid/right, ledge, pillar, JH plaque, floor grate
      tech:   server rack (11,6) top, (11,8) middle (stackable), (11,10) base;
              GPU card (12,6)+(13,6); fan (14,6); chip (15,6); cable horizontal (12,8),
              cable vertical (13,8), cable corner top->right (13,10); heatsink (14,8);
              monitor (15,8)
"""
import colorsys
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'world_tileset_original.png')   # untouched original
OUT = os.path.join(ROOT, 'assets', 'sprites', 'world_tileset.png')
T = 16

# ---------------------------------------------------------------- palettes (dark -> light)
GREEN = [(10, 30, 6), (28, 66, 6), (54, 108, 0), (84, 150, 0), (118, 185, 0), (160, 216, 50), (206, 246, 120)]
# foliage: shadows stay gray/black, only the lit side turns green
FOLIAGE = [(22, 24, 26), (38, 42, 46), (56, 62, 68), (78, 86, 92), (70, 128, 4), (118, 185, 0), (172, 228, 72)]
GUNMETAL = [(30, 32, 36), (44, 48, 54), (62, 68, 76), (84, 90, 98), (108, 114, 122), (138, 144, 152), (172, 178, 186)]
METAL = [(36, 40, 46), (62, 68, 76), (92, 98, 106), (126, 132, 140), (162, 168, 176), (200, 206, 212), (236, 240, 244)]
OUTLINE_NEW = (16, 16, 18)


def lum(rgb):
    r, g, b = (c / 255 for c in rgb)
    return 0.299 * r + 0.587 * g + 0.114 * b


def ramp(r, L, lo=0.08, hi=0.92):
    t = min(max((L - lo) / (hi - lo), 0), 1)
    return r[min(int(t * len(r)), len(r) - 1)]


def hsv(rgb):
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    return h * 360, s, v


def recolor_pixel(rgb, tx, ty):
    hue, s, v = hsv(rgb)
    L = lum(rgb)
    if v < 0.24:
        return OUTLINE_NEW
    # sky gradient columns: one green, the rest neutral
    if ty >= 9 and tx <= 3:
        return ramp([GREEN, METAL, GUNMETAL, METAL][tx], L, 0.05, 0.95)
    # liquids: saturated blue water -> green coolant, the rest falls through
    if ty >= 9 and 4 <= tx <= 7 and 190 <= hue <= 230 and s > 0.75:
        return ramp(GREEN, L, 0.1, 0.75)
    if s < 0.4 or 195 <= hue <= 265:
        return ramp(METAL, L)
    if 60 <= hue < 195:                       # greens / teals -> gray with green highlights
        return ramp(FOLIAGE, L, 0.12, 0.62)
    if 32 <= hue < 60:                        # oranges / yellows -> brushed silver
        return ramp(METAL, L, 0.2, 0.95)
    return ramp(GUNMETAL, L, 0.12, 0.75)      # browns / reds / purples -> gunmetal


# ---------------------------------------------------------------- glyph recolor (row 2)
GLYPH_SETS = {
    # tile: (glyph fill colour in original, new fill, new shade)
    (4, 2): ((231, 176, 156), (226, 44, 52), (150, 20, 30)),   # terracotta ?
    (5, 2): ((231, 176, 156), (226, 44, 52), (150, 20, 30)),   # terracotta !
    (7, 2): ((174, 180, 206), (118, 185, 0), (70, 120, 0)),    # gray ?
    (8, 2): ((174, 180, 206), (118, 185, 0), (70, 120, 0)),    # gray !
}


def recolor_glyphs(img):
    px = img.load()
    for (tx, ty), (old, new, _shade) in GLYPH_SETS.items():
        for y in range(2, 14):
            for x in range(4, 12):
                X, Y = tx * T + x, ty * T + y
                if px[X, Y][:3] == old:
                    px[X, Y] = new + (255,)


# ---------------------------------------------------------------- new tiles
NEW_PAL = {
    '#': (14, 13, 14),
    'k': (26, 28, 32),      # black brick
    'K': (40, 44, 50),      # brick face
    'q': (58, 62, 70),      # brick highlight
    'm': (98, 104, 112),    # mortar
    'M': (150, 156, 164),   # light metal
    'W': (236, 240, 236),   # white
    'G': (118, 185, 0),     # green
    'g': (70, 122, 0),      # dark green
    'L': (176, 232, 80),    # light green glow
    'b': (124, 74, 40),     # pole brown
    'B': (174, 114, 62),    # pole highlight
    'd': (78, 44, 26),      # pole shadow
    'y': (214, 178, 84),    # brass finial
    'Y': (250, 226, 140),
    'r': (90, 54, 34),      # door wood dark
    'R': (130, 82, 50),     # door wood
    'a': (240, 160, 40),    # amber LED
    'e': (226, 44, 52),     # red LED
    'c': (10, 22, 12),      # screen background
}

NEW_TILES = {
    # ---------------- flag (pole at x=3..4, stackable)
    (10, 3): [  # flag top: finial + green pennant with logo-style mark
        "..##............",
        ".#Yy#...........",
        ".#yy#...........",
        "..##............",
        "..#Bd###........",
        "..#Bd#GG##......",
        "..#Bd#GGGG##....",
        "..#Bd#GWWWGG##..",
        "..#Bd#WGGgWGGG##",
        "..#Bd#WGgGWGGGG#",
        "..#Bd#GWWWGGG##.",
        "..#Bd#GGGG##....",
        "..#Bd#GG##......",
        "..#Bd###........",
        "..#Bd#..........",
        "..#Bd#..........",
    ],
    (10, 5): [  # pole segment
        "..#Bd#..........",
    ] * 16,
    (10, 7): [  # base
        "..#Bd#..........",
        "..#Bd#..........",
        "..#Bd#..........",
        "..#Bd#..........",
        "..#Bd#..........",
        ".##Bd##.........",
        ".#MMMM#.........",
        ".######.........",
        "#qqqqqq#........",
        "#KKKKKK#........",
        "#GGGGGG#........",
        "#KKKKKK#........",
        "#KkKKkK#........",
        "#kkkkkk#........",
        "########........",
        "................",
    ],
    # ---------------- castle kit
    (11, 3): [  # brick wall
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKKKkmKKKKKKkm",
        "KKKKKkkmKKKKKkkm",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKKKkmKKKKKKkm",
        "KKKKKkkmKKKKKkkm",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
    ],
    (12, 3): [  # brick wall with green circuit trim band
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKKKkmKKKKKKkm",
        "KKKKKkkmKKKKKkkm",
        "################",
        "gGGGGGGGGGGGGGGg",
        "GLGGGGLGGGGLGGGG",
        "gGGGGGGGGGGGGGGg",
        "################",
        "qKKKKKKmqKKKKKKm",
        "KKKKKKkmKKKKKKkm",
        "KKKKKkkmKKKKKkkm",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
    ],
    (13, 3): [  # battlements (wall top)
        "................",
        "######....######",
        "#qqqq#....#qqqq#",
        "#KKKK#....#KKKK#",
        "#KKKk#....#KKKk#",
        "#KkKk######KkKk#",
        "#kkkk#qqqq#kkkk#",
        "mmmmmmmmmmmmmmmm",
        "MMMMMMMMMMMMMMMM",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKKkkmKKKKKkkm",
    ],
    (14, 3): [  # arched window with green glow
        "mmmmmmmmmmmmmmmm",
        "qKKKK#####KKKKKm",
        "KKKK#MMMMM#KKKkm",
        "KKK#M#LLL#M#Kkkm",
        "mmm#M#LGL#M#mmmm",
        "KK#M#LGGGL#M#KKK",
        "Kk#M#GGGGG#M#KKK",
        "kk#M#GGgGG#M#KKk",
        "mm#M#######M#mmm",
        "qK#M#GGgGG#M#KKm",
        "KK#M#GgggG#M#Kkm",
        "KK#M#ggggg#M#kkm",
        "mm#MMMMMMMMM#mmm",
        "KK###########KKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
    ],
    (11, 4): [  # door top (arch)
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKK######KKKkm",
        "KKKK#MMMMMM#Kkkm",
        "mmm#M######M#mmm",
        "KK#M#rRRRRr#M#KK",
        "Kk#M#RRrRRR#M#KK",
        "k#M#rRRrRRRr#M#k",
        "m#M#RRRrRRRR#M#m",
        "q#M#RRRrRRRR#M#m",
        "K#M#rRRrRRRr#M#m",
        "K#M#RRRrRRRR#M#m",
        "m#M#RRRrRRRR#M#m",
        "K#M#rRRrRRRr#M#K",
        "K#M#RRRrRRRR#M#K",
        "k#M#RRRrRRRR#M#k",
    ],
    (11, 5): [  # door bottom
        "K#M#rRRrRRRr#M#K",
        "K#M#RRRrRRRR#M#K",
        "m#M#RRRrRRRR#M#m",
        "q#M#rRRrRRRr#M#m",
        "K#M#RRRrRRGG#M#m",
        "K#M#RRRrRRGL#M#m",
        "m#M#rRRrRRRr#M#m",
        "K#M#RRRrRRRR#M#K",
        "K#M#RRRrRRRR#M#K",
        "k#M#rRRrRRRr#M#k",
        "m#M#RRRrRRRR#M#m",
        "q#M#RRRrRRRR#M#m",
        "K#M#rRRrRRRr#M#m",
        "K#M#RRRrRRRR#M#m",
        "#MMMMMMMMMMMMMM#",
        "################",
    ],
    (12, 4): [  # hanging banner with logo-style mark (on brick)
        "mmmmmmmmmmmmmmmm",
        "q#############Km",
        "K#MMMMMMMMMMM#km",
        "K##GGGGGGGGG##km",
        "mm#GGGGGGGGG#mmm",
        "KK#GGWWWWWGG#KKK",
        "Kk#GWGGgGWGG#KKK",
        "kk#WGGgGGWGG#KKk",
        "mm#GWGGGWGGG#mmm",
        "qK#GGWWWGGGG#KKm",
        "KK#GGGGGGGGG#Kkm",
        "KK#GGGGGGGGG#kkm",
        "mm#GGG#G#GGG#mmm",
        "KK#GG#.#.#GG#KKK",
        "Kk#G#.....#G#KKK",
        "kk##.......##KKk",
    ],
    (13, 4): [  # roof tip
        ".......##.......",
        "......#LG#......",
        "......#GG#......",
        "......#GG#......",
        ".....#GGgg#.....",
        ".....#GGgg#.....",
        "....#GGGggg#....",
        "....#kkkkkk#....",
        "...#GGGGgggg#...",
        "...#GGGGgggg#...",
        "..#GGGGGggggg#..",
        "..#kkkkkkkkkk#..",
        ".#GGGGGGgggggg#.",
        ".#GGGGGGgggggg#.",
        "#GGGGGGGggggggg#",
        "#kkkkkkkkkkkkkk#",
    ],
    (12, 5): [  # roof left slope
        "...............#",
        "..............#G",
        ".............#GG",
        "............#kkk",
        "...........#GGGG",
        "..........#GGGGG",
        ".........#GGGGGG",
        "........#kkkkkkk",
        ".......#GGGGGGGG",
        "......#GGGGGGGGG",
        ".....#GGGGGGGGGG",
        "....#kkkkkkkkkkk",
        "...#GGGGGGGGGGGG",
        "..#GGGGGGGGGGGGG",
        ".#GGGGGGGGGGGGGG",
        "################",
    ],
    (13, 5): [  # roof middle
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "kkkkkkkkkkkkkkkk",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "kkkkkkkkkkkkkkkk",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "kkkkkkkkkkkkkkkk",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "GGGGGGGGgggggggg",
        "################",
    ],
    (14, 5): [  # roof right slope
        "#...............",
        "g#..............",
        "gg#.............",
        "kkk#............",
        "gggg#...........",
        "ggggg#..........",
        "gggggg#.........",
        "kkkkkkk#........",
        "gggggggg#.......",
        "ggggggggg#......",
        "gggggggggg#.....",
        "kkkkkkkkkkk#....",
        "gggggggggggg#...",
        "ggggggggggggg#..",
        "gggggggggggggg#.",
        "################",
    ],
    (14, 4): [  # metal ledge / walkable cap
        "################",
        "#WMMMMMMMMMMMMM#",
        "#MMMMMMMMMMMMMm#",
        "#mmmmmmmmmmmmmm#",
        "################",
        "#GLGGGGLGGGGLGG#",
        "################",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "KKKKKKkmKKKKKKkm",
        "KKKKKkkmKKKKKkkm",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
    ],
    (15, 3): [  # pillar (stackable)
        "..#MMMMMMMMMM#..",
        "..#WMMMMMMMmm#..",
        "..#WMMgMMMMmm#..",
        "..#WMMGMMMMmm#..",
        "..#WMMGMMMMmm#..",
        "..#WMMgMMMMmm#..",
        "..#WMMMMMMMmm#..",
        "..#WMMMMMMMmm#..",
        "..#WMMMMMMMmm#..",
        "..#WMMgMMMMmm#..",
        "..#WMMGMMMMmm#..",
        "..#WMMGMMMMmm#..",
        "..#WMMgMMMMmm#..",
        "..#WMMMMMMMmm#..",
        "..#WMMMMMMMmm#..",
        "..#MMMMMMMMMM#..",
    ],
    (15, 4): [  # "JH" plaque on brick
        "mmmmmmmmmmmmmmmm",
        "qKKKKKKmqKKKKKKm",
        "K##############m",
        "K#MMMMMMMMMMMM#m",
        "m#MGGG#GG#GG#M#m",
        "K#M##G#GG#GG#M#K",
        "K#M##G#GGGGG#M#K",
        "k#MG#G#GG#GG#M#k",
        "m#MGGG#GG#GG#M#m",
        "q#M####G##G##M#m",
        "K#MMMMMMMMMMMM#m",
        "K##############m",
        "mmmmmmmmmmmmmmmm",
        "KKmqKKKKKKmqKKKK",
        "KkmKKKKKKkmKKKKK",
        "kkmKKKKKkkmKKKKk",
    ],
    (15, 5): [  # floor grate (walkable)
        "################",
        "#MMMMMMMMMMMMMM#",
        "#M#M#M#M#M#M#Mm#",
        "#MkMkMkMkMkMkMm#",
        "#M#M#M#M#M#M#Mm#",
        "#mmmmmmmmmmmmmm#",
        "################",
        "#kGkkkkkkkkGkkk#",
        "#kkkkkkkkkkkkkk#",
        "#kkkkkGkkkkkkkk#",
        "#kkkkkkkkkkkkGk#",
        "#kGkkkkkkkkkkkk#",
        "#kkkkkkkGkkkkkk#",
        "#kkkkkkkkkkkkkk#",
        "#kkkGkkkkkkkGkk#",
        "################",
    ],
}


# ---------------------------------------------------------------- tech props
def _rack_unit(leds):
    """One 1U server slot, 4 rows tall, 16 wide. `leds` is 4 chars of LED colours."""
    return [
        "#k############k#",
        "#k#qqqqqqqqqq#k#",
        "#k#" + leds[0] + "k" + leds[1] + "k" + leds[2] + "k" + leds[3] + "mmm#k#",
        "#k#KKKKKKKKKK#k#",
    ]


RACK_TOP = [
    "################",
    "#MMMMMMMMMMMMMM#",
    "#mmmmmmmmmmmmmm#",
    "#kkkkkkkkkkkkkk#",
] + _rack_unit("GLGa") + _rack_unit("GGkG") + _rack_unit("LGaG")
RACK_MID = _rack_unit("GaGL") + _rack_unit("GGGk") + _rack_unit("LkGe") + _rack_unit("GLGG")
RACK_BASE = _rack_unit("GGaG") + _rack_unit("kLGG") + [
    "#k############k#",
    "#k#mkmkmkmkmk#k#",
    "#k#kmkmkmkmkm#k#",
    "#k#mkmkmkmkmk#k#",
    "#k############k#",
    "#kkkkkkkkkkkkkk#",
    "################",
    "#M#..........#M#",
]


def _fan(grid, cx, cy, r):
    """Draw a round fan (outline, blades, green hub) into a mutable char grid."""
    import math
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            d = math.hypot(x - cx, y - cy)
            if d > r + 0.5:
                continue
            if d > r - 0.6:
                grid[y][x] = '#'
            elif d <= 1.2:
                grid[y][x] = 'L'
            elif d <= 2.0:
                grid[y][x] = 'G'
            else:
                ang = (math.degrees(math.atan2(y - cy, x - cx)) + d * 25) % 72
                grid[y][x] = 'M' if ang < 30 else 'K'


def _gpu():
    W, H = 32, 16
    g = [['.'] * W for _ in range(H)]
    for y in range(1, 13):                       # shroud
        for x in range(0, 29):
            edge = y in (1, 12) or x in (0, 28)
            g[y][x] = '#' if edge else ('q' if y == 2 else 'k')
    for x in range(2, 27):                       # green accent stripe
        g[3][x] = 'G'
    for x in range(20, 27):
        g[11][x] = 'G'
    _fan(g, 7.5, 7.0, 4.6)
    _fan(g, 18.5, 7.0, 4.6)
    for x in range(1, 29):                       # PCB + PCIe gold fingers
        g[13][x] = 'g' if x not in (1, 28) else '#'
        g[14][x] = '#'
    for x in range(6, 24):
        g[14][x] = 'y' if x % 2 == 0 else '#'
        g[15][x] = 'y' if x % 2 == 0 else '.'
    for y in range(0, 15):                       # IO bracket
        g[y][29] = '#'
        g[y][30] = 'M' if y % 4 else 'k'
        g[y][31] = '#'
    g[0][29:32] = list('###')
    g[14][29:32] = list('###')
    rows = [''.join(r) for r in g]
    return [r[:16] for r in rows], [r[16:] for r in rows]


def _fan_block():
    g = [list("################")] + [list("#KKKKKKKKKKKKKK#") for _ in range(14)] + [list("################")]
    for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
        g[y][x] = 'm'
    _fan(g, 7.5, 7.5, 5.6)
    return [''.join(r) for r in g]


GPU_L, GPU_R = _gpu()

CHIP = [
    "................",
    "...y.y.y.y.y....",
    "..############..",
    ".y#kkkkkkkkkk#y.",
    "..#kMkkkkkkkk#..",
    ".y#kk######kk#y.",
    "..#kk#gGGg#kk#..",
    ".y#kk#GLLG#kk#y.",
    "..#kk#GLLG#kk#..",
    ".y#kk#gGGg#kk#y.",
    "..#kk######kk#..",
    ".y#kkkkkkkkkk#y.",
    "..#kkkkkkkkkk#..",
    "..############..",
    "...y.y.y.y.y....",
    "................",
]

HEATSINK = [
    "################",
    "#M#M#M#M#M#M#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "#M#m#M#m#M#m#M##",
    "################",
    "#WMMMMMMMMMMMMm#",
    "#MMMMMMMMMMMMMm#",
    "#mmmmmmmmmmmmmm#",
    "################",
]

CABLE_H = [
    "................",
    "................",
    "................",
    "................",
    "################",
    "GGGGGGGGGGGGGGGG",
    "gggggggggggggggg",
    "################",
    "KKKKKKKKKKKKKKKK",
    "kkkkkkkkkkkkkkkk",
    "################",
    "................",
    "................",
    "................",
    "................",
    "................",
]
# cable cross-section, outer -> inner; green runs on the inner side so all pieces join up
_BAND = "#kK#gG#"
CABLE_V = [''.join(_BAND[x - 4] if 4 <= x <= 10 else '.' for x in range(16)) for _ in range(16)]


def _cable_corner():
    """Cable coming down from the top and turning right."""
    rows = []
    for y in range(16):
        row = ''
        for x in range(16):
            ox, oy = x - 4, y - 4
            if 4 <= x <= 10 and y < 4:
                row += _BAND[ox]
            elif x > 10 and 4 <= y <= 10:
                row += _BAND[6 - oy]
            elif 4 <= x <= 10 and 4 <= y <= 10:
                row += _BAND[min(ox, 6 - oy)]
            else:
                row += '.'
        rows.append(row)
    return rows


CABLE_CORNER = _cable_corner()

MONITOR = [
    "################",
    "#MMMMMMMMMMMMMm#",
    "#M############m#",
    "#M#cccccccccc#m#",
    "#M#cGGGcGGccc#m#",
    "#M#cccccccccc#m#",
    "#M#cLGGGGcccc#m#",
    "#M#cccccccccc#m#",
    "#M#cGGcGGGGcc#m#",
    "#M#cccccccccc#m#",
    "#M############m#",
    "#mmmmmmmGmmmmmm#",
    "################",
    "......#MM#......",
    "....########....",
    "....#mmmmmm#....",
]

NEW_TILES.update({
    (11, 6): RACK_TOP, (11, 8): RACK_MID, (11, 10): RACK_BASE,
    (12, 6): GPU_L, (13, 6): GPU_R,
    (14, 6): _fan_block(),
    (15, 6): CHIP,
    (12, 8): CABLE_H, (13, 8): CABLE_V, (13, 10): CABLE_CORNER,
    (14, 8): HEATSINK,
    (15, 8): MONITOR,
})


def draw_new_tiles(img):
    px = img.load()
    for (tx, ty), rows in NEW_TILES.items():
        assert len(rows) == 16 and all(len(r) == 16 for r in rows), (tx, ty)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                X, Y = tx * T + x, ty * T + y
                px[X, Y] = (NEW_PAL[ch] + (255,)) if ch in NEW_PAL else (0, 0, 0, 0)


# ---------------------------------------------------------------- build
def build():
    src = Image.open(SRC).convert('RGBA')
    out = src.copy()
    sp, op = src.load(), out.load()
    for y in range(3 * T, src.height):            # rows 0-2 untouched
        for x in range(src.width):
            r, g, b, a = sp[x, y]
            if a:
                op[x, y] = recolor_pixel((r, g, b), x // T, y // T) + (a,)
    recolor_glyphs(out)
    for (tx, ty) in NEW_TILES:                     # new tiles only go into empty slots
        assert src.crop((tx * T, ty * T, tx * T + T, ty * T + T)).getbbox() is None, (tx, ty)
    draw_new_tiles(out)
    return src, out


def main():
    src, out = build()
    out.save(OUT)
    print('wrote', OUT)
    if len(sys.argv) > 1:
        d = sys.argv[1]
        side = Image.new('RGBA', (src.width * 2 + 8, src.height), (60, 60, 70, 255))
        for i, im in enumerate((src, out)):
            bg = Image.new('RGBA', src.size, (120, 170, 220, 255))
            bg.alpha_composite(im)
            side.paste(bg, (i * (src.width + 8), 0))
        side.resize((side.width * 2, side.height * 2), Image.NEAREST).save(os.path.join(d, 'gpu_side_by_side.png'))
        big = Image.new('RGBA', src.size, (120, 170, 220, 255))
        big.alpha_composite(out)
        big.resize((src.width * 4, src.height * 4), Image.NEAREST).save(os.path.join(d, 'gpu_x4.png'))


if __name__ == '__main__':
    main()
