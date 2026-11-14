"""Generates scenes/world_tileset.tres, scenes/level_2.tscn and scenes/level_3.tscn.

Usage (from the project root):
    python tools/build_levels.py [preview_dir]

The level layouts live in level_2() / level_3() below as lists of platforms, so
tweaking a level is a matter of editing a few numbers and re-running this.
(You can also just edit the generated scenes in the Godot editor - but then
don't re-run this script, it overwrites them.)

Coordinates are tile coordinates (16 px tiles, y grows downwards).
The player jumps ~2.8 tiles high and ~3.8 tiles far, so keep steps <= 2 tiles
up and gaps <= 3 tiles wide.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENES = os.path.join(ROOT, 'scenes')
T = 16

# ---------------------------------------------------------------- tile atlas coords
GRASS, DIRT = (0, 0), (0, 1)
STONE_TOP, STONE = (8, 0), (8, 1)
BRICK_TOP, BRICK = (5, 0), (5, 1)
Q_BLOCK, E_BLOCK = (7, 2), (8, 2)
BRIDGE_L, BRIDGE_M, BRIDGE_R = (9, 0), (10, 0), (11, 0)
# decoration (no collision)
FLAG_TOP, FLAG_POLE, FLAG_BASE = (10, 3), (10, 5), (10, 7)
RACK_TOP, RACK_MID, RACK_BASE = (11, 6), (11, 8), (11, 10)
GPU_L, GPU_R, FAN, CHIP, HEATSINK, MONITOR = (12, 6), (13, 6), (14, 6), (15, 6), (14, 8), (15, 8)
BUSH, ROCK = (6, 8), (5, 8)
WALL_BG, WALL_BG_TRIM, WINDOW, BANNER = (11, 3), (12, 3), (14, 3), (12, 4)
BATTLEMENT = (13, 3)
SOLID = {GRASS, DIRT, STONE_TOP, STONE, BRICK_TOP, BRICK, Q_BLOCK, E_BLOCK, BRIDGE_L, BRIDGE_M, BRIDGE_R}


class Level:
    def __init__(self):
        self.cells = {}
        self.back = {}   # backdrop tiles, drawn behind everything else

    def put(self, x, y, tile, keep=False):
        if keep and (x, y) in self.cells:
            return
        self.cells[(x, y)] = tile

    def fill(self, x0, x1, y0, y1, tile, keep=False):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.put(x, y, tile, keep)

    def ground(self, x0, x1, top, bottom, cap=GRASS, body=DIRT):
        self.fill(x0, x1, top, top, cap)
        self.fill(x0, x1, top + 1, bottom, body)

    def bridge(self, x0, x1, y):
        self.put(x0, y, BRIDGE_L)
        self.fill(x0 + 1, x1 - 1, y, y, BRIDGE_M)
        self.put(x1, y, BRIDGE_R)

    def rack(self, x, floor, height=3):
        """Server rack standing on the tile row `floor`."""
        self.put(x, floor - 1, RACK_BASE)
        self.fill(x, x, floor - height + 1, floor - 2, RACK_MID)
        self.put(x, floor - height, RACK_TOP)

    def flag(self, x, floor, height=4):
        self.put(x, floor - 1, FLAG_BASE)
        self.fill(x, x, floor - height + 1, floor - 2, FLAG_POLE)
        self.put(x, floor - height, FLAG_TOP)

    @staticmethod
    def tile_data(cells):
        out = []
        for (x, y), (ax, ay) in sorted(cells.items(), key=lambda c: (c[0][1], c[0][0])):
            cell = (y << 16) + (x & 0xFFFF)
            if cell >= 1 << 31:
                cell -= 1 << 32
            out += [cell, ax << 16, ay]
        return ', '.join(str(v) for v in out)


def feet(x, floor):
    """Player position standing on tile row `floor`, centred on tile x."""
    return (x * T + 8, floor * T)


def princess_at(x, floor):
    px, py = feet(x, floor)
    return (px, py - 15)   # her origin is at her centre


# ---------------------------------------------------------------- level 2: Server Farm
def level_2():
    lv = Level()
    bottom = 5
    lv.ground(-6, 8, 0, bottom)
    lv.ground(11, 16, 0, bottom)            # 2-wide pit
    lv.ground(20, 23, -1, bottom)           # 3-wide pit, one step up
    lv.bridge(24, 29, -1)
    lv.ground(30, 34, -1, bottom)
    lv.fill(36, 37, -3, -3, Q_BLOCK)        # floating block staircase over a pit
    lv.fill(40, 41, -5, -5, E_BLOCK)
    lv.ground(44, 50, -6, bottom, STONE_TOP, STONE)   # the mesa
    lv.fill(53, 55, -4, -4, BRICK_TOP)      # and back down
    lv.fill(58, 60, -2, -2, BRICK_TOP)
    lv.ground(63, 76, 0, bottom)

    lv.fill(-6, -6, -4, -1, STONE)          # wall so you can't walk off the left edge
    lv.fill(76, 76, -4, -1, STONE)
    lv.put(-6, -5, STONE_TOP)
    lv.put(76, -5, STONE_TOP)

    lv.rack(-4, 0, 4)
    lv.rack(-3, 0, 3)
    lv.put(4, -1, MONITOR)
    lv.put(6, -1, BUSH)
    lv.rack(13, 0, 3)
    lv.rack(14, 0, 4)
    lv.put(15, -1, HEATSINK)
    lv.put(21, -2, ROCK)
    lv.put(32, -2, MONITOR)
    lv.rack(33, -1, 3)
    lv.rack(45, -6, 4)
    lv.rack(46, -6, 4)
    lv.put(47, -7, GPU_L)
    lv.put(48, -7, GPU_R)
    lv.put(49, -7, FAN)
    lv.put(65, -1, BUSH)
    lv.rack(67, 0, 3)
    lv.put(68, -1, CHIP)
    lv.flag(70, 0, 5)
    lv.put(74, -1, ROCK)
    return dict(
        file='level_2.tscn', node='level_2', number=2, level=lv,
        player=feet(0, 0), princess=princess_at(72, 0),
        kill_y=(bottom + 6) * T, background=(0.07, 0.09, 0.11),
    )


# ---------------------------------------------------------------- level 3: Overclock Tower
def level_3():
    lv = Level()
    top = -26                                # the floor the princess stands on
    for x in range(1, 15):                   # dark interior backdrop
        for y in range(top - 5, 0):
            lv.back[(x, y)] = (2, 14)
    lv.ground(-2, 17, 0, 3, STONE_TOP, STONE)
    lv.fill(0, 0, top - 5, -1, STONE)        # tower walls
    lv.fill(15, 15, top - 5, -1, STONE)
    lv.put(0, top - 6, BATTLEMENT)
    lv.put(15, top - 6, BATTLEMENT)

    # (x0, x1, y, tile) - each one is 2 tiles above the previous.
    # Careful: a platform 4 tiles above another one blocks the jump off it
    # (the player bumps their head), so step N+2 must never hang over the
    # edge that step N is left from.
    steps = [
        (3, 5, -2, BRICK_TOP),
        (7, 9, -4, BRICK_TOP),
        (11, 14, -6, BRICK_TOP),
        (6, 8, -8, Q_BLOCK),
        (2, 4, -10, BRICK_TOP),
        (7, 11, -12, 'bridge'),
        (13, 14, -14, BRICK_TOP),
        (9, 10, -16, E_BLOCK),
        (5, 7, -18, BRICK_TOP),
        (1, 3, -20, BRICK_TOP),
        (6, 7, -22, Q_BLOCK),
        (9, 11, -24, BRICK_TOP),
        (1, 6, top, STONE_TOP),
    ]
    for x0, x1, y, tile in steps:
        if tile == 'bridge':
            lv.bridge(x0, x1, y)
        else:
            lv.fill(x0, x1, y, y, tile)

    for x, y in [(2, -5), (13, -9), (2, -14), (13, -19), (2, -23), (13, -23)]:
        lv.put(x, y, WINDOW)
    for x, y in [(12, -3), (5, -13), (12, -21)]:
        lv.put(x, y, BANNER)
    lv.rack(12, 0, 3)
    lv.rack(13, 0, 2)
    lv.put(8, -5, MONITOR)
    lv.put(3, -11, FAN)
    lv.put(14, -15, CHIP)
    lv.put(2, -21, HEATSINK)
    lv.put(4, top - 1, GPU_L)
    lv.put(5, top - 1, GPU_R)
    lv.flag(1, top, 4)
    return dict(
        file='level_3.tscn', node='level_3', number=3, level=lv,
        player=feet(8, 0), princess=princess_at(2, top),
        kill_y=12 * T, background=(0.04, 0.05, 0.07),
    )


# ---------------------------------------------------------------- writers
def write_tileset():
    """Pulls the tileset out of game.tscn so the new levels share one copy."""
    src = open(os.path.join(SCENES, 'game.tscn'), encoding='utf-8').read()
    atlas = re.search(r'\[sub_resource type="TileSetAtlasSource" id="[^"]+"\]\n(.*?)\n\n', src, re.S).group(1)
    atlas = re.sub(r'ExtResource\("[^"]+"\)', 'ExtResource("1_tiles")', atlas)
    text = (
        '[gd_resource type="TileSet" format=3]\n\n'
        '[ext_resource type="Texture2D" uid="uid://ckwm7iqr41hap" path="res://assets/sprites/world_tileset.png" id="1_tiles"]\n\n'
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_world"]\n'
        + atlas + '\n\n'
        '[resource]\n'
        'physics_layer_0/collision_layer = 1\n'
        'sources/0 = SubResource("TileSetAtlasSource_world")\n'
    )
    with open(os.path.join(SCENES, 'world_tileset.tres'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


SCENE = '''[gd_scene format=3]

[ext_resource type="Script" path="res://scenes/level.gd" id="1_level"]
[ext_resource type="TileSet" path="res://scenes/world_tileset.tres" id="2_tiles"]
[ext_resource type="PackedScene" uid="uid://be8qbmt0fe144" path="res://scenes/player.tscn" id="3_player"]
[ext_resource type="PackedScene" uid="uid://bq0wai1cb1c8j" path="res://scenes/princess.tscn" id="4_princess"]
[ext_resource type="Script" uid="uid://4mb07anxhm0d" path="res://scenes/follow_player.gd" id="5_camera"]

[node name="{node}" type="Node2D"]
script = ExtResource("1_level")
level_number = {number}
kill_y = {kill_y}.0
background_color = Color({bg}, 1)

[node name="TileMap" type="TileMap" parent="."]
tile_set = ExtResource("2_tiles")
format = 2
{layers}

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2({px}, {py})

[node name="Princess" parent="." instance=ExtResource("4_princess")]
position = Vector2({qx}, {qy})

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2({px}, {py})
zoom = Vector2(2, 2)
script = ExtResource("5_camera")
'''


def write_level(spec):
    lv = spec['level']
    if lv.back:
        layers = ('layer_0/name = "Backdrop"\n'
                  'layer_0/tile_data = PackedInt32Array(%s)\n'
                  'layer_1/name = "World"\n'
                  'layer_1/tile_data = PackedInt32Array(%s)' % (lv.tile_data(lv.back), lv.tile_data(lv.cells)))
    else:
        layers = 'layer_0/tile_data = PackedInt32Array(%s)' % lv.tile_data(lv.cells)
    text = SCENE.format(
        node=spec['node'], number=spec['number'], kill_y=spec['kill_y'],
        bg=', '.join(str(c) for c in spec['background']),
        layers=layers,
        px=spec['player'][0], py=spec['player'][1],
        qx=spec['princess'][0], qy=spec['princess'][1],
    )
    with open(os.path.join(SCENES, spec['file']), 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def preview(spec, out_dir):
    from PIL import Image
    sheet = Image.open(os.path.join(ROOT, 'assets', 'sprites', 'world_tileset.png')).convert('RGBA')
    cells = spec['level'].cells
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    x0, y0 = min(xs) - 1, min(ys) - 2
    w, h = max(xs) - x0 + 2, max(ys) - y0 + 2
    bg = tuple(int(c * 255) for c in spec['background']) + (255,)
    img = Image.new('RGBA', (w * T, h * T), bg)
    for (x, y), (ax, ay) in list(spec['level'].back.items()) + list(cells.items()):
        tile = sheet.crop((ax * T, ay * T, ax * T + T, ay * T + T))
        img.alpha_composite(tile, ((x - x0) * T, (y - y0) * T))
    for (px, py), colour in ((spec['player'], (255, 60, 60, 255)), (spec['princess'], (255, 120, 220, 255))):
        img.alpha_composite(Image.new('RGBA', (6, 6), colour), (int(px) - x0 * T - 3, int(py) - y0 * T - 6))
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    img.save(os.path.join(out_dir, spec['file'].replace('.tscn', '.png')))


if __name__ == '__main__':
    write_tileset()
    for spec in (level_2(), level_3()):
        write_level(spec)
        print('wrote scenes/' + spec['file'], '(%d tiles)' % len(spec['level'].cells))
        if len(sys.argv) > 1:
            os.makedirs(sys.argv[1], exist_ok=True)
            preview(spec, sys.argv[1])
