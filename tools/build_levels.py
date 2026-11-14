"""Generates scenes/world_tileset.tres, scenes/level_2.tscn and scenes/level_3.tscn
(tiles, coins, ducks, "!" boxes, princess and castle).

Usage (from the project root):
    python tools/build_levels.py [preview_dir]

The level layouts live in level_2() / level_3() below as lists of platforms, so
tweaking a level is a matter of editing a few numbers and re-running this.
(You can also just edit the generated scenes in the Godot editor - but then
don't re-run this script, it overwrites them.)

Coordinates are tile coordinates (16 px tiles, y grows downwards).
The player jumps ~2.8 tiles high and ~3.8 tiles far, so keep steps <= 2 tiles
up and gaps <= 3 tiles wide. With the double jump: ~5.7 tiles high, ~7 far -
steps of 4 tiles and gaps of 6 need it.
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
E_BLOCK = (8, 2)
BRIDGE_L, BRIDGE_M, BRIDGE_R = (9, 0), (10, 0), (11, 0)
# decoration (no collision)
FLAG_TOP, FLAG_POLE, FLAG_BASE = (10, 3), (10, 5), (10, 7)
RACK_TOP, RACK_MID, RACK_BASE = (11, 6), (11, 8), (11, 10)
GPU_L, GPU_R, FAN, CHIP, HEATSINK, MONITOR = (12, 6), (13, 6), (14, 6), (15, 6), (14, 8), (15, 8)
BUSH, ROCK = (6, 8), (5, 8)
WALL_BG, WALL_BG_TRIM, WINDOW, BANNER = (11, 3), (12, 3), (14, 3), (12, 4)
BATTLEMENT = (13, 3)
DOOR_TOP, DOOR_BOTTOM, PLAQUE = (11, 4), (11, 5), (15, 4)
ROOF_TIP, ROOF_L, ROOF_M, ROOF_R = (13, 4), (12, 5), (13, 5), (14, 5)
SWORD, DOUBLE_JUMP = 0, 1   # bounce_box.gd Power values
SOLID = {GRASS, DIRT, STONE_TOP, STONE, BRICK_TOP, BRICK, E_BLOCK, BRIDGE_L, BRIDGE_M, BRIDGE_R}


class Level:
    def __init__(self):
        self.cells = {}
        self.back = {}    # backdrop tiles, drawn behind everything else
        self.coins = []   # (x, y) tile coordinates
        self.ducks = []   # (x, floor, blonde, patrol_distance)
        self.boxes = []   # (x, y, power)  power: 0 = sword, 1 = double jump

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

    def castle(self, x0, x1, floor, door_x):
        """Nvidia castle front standing on the tile row `floor` (decoration only).
        The door is where the level ends - see `castle_door` in the returned spec."""
        for x in range(x0, x1 + 1):
            for y in range(floor - 4, floor):
                self.back[(x, y)] = WALL_BG
            self.back[(x, floor - 5)] = WALL_BG_TRIM
            self.put(x, floor - 6, BATTLEMENT)
        for x in range(door_x - 1, door_x + 2):     # the keep above the door
            self.back[(x, floor - 6)] = WALL_BG
            self.back[(x, floor - 7)] = WALL_BG_TRIM
            self.cells.pop((x, floor - 6), None)
        self.put(door_x - 1, floor - 8, ROOF_L)
        self.put(door_x, floor - 8, ROOF_M)
        self.put(door_x + 1, floor - 8, ROOF_R)
        self.put(door_x, floor - 9, ROOF_TIP)
        self.put(door_x, floor - 2, DOOR_TOP)
        self.put(door_x, floor - 1, DOOR_BOTTOM)
        self.put(door_x, floor - 4, PLAQUE)
        self.put(door_x - 2, floor - 3, BANNER)
        self.put(door_x + 2, floor - 3, BANNER)
        for x in (x0 + 1, x1 - 1):
            self.put(x, floor - 3, WINDOW)

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
# Needs the DOUBLE JUMP: the "!" box before the wide pit hands it out (and
# bounces you back to the start, so it sits a couple of pits in to make the
# trip back take some effort); the wide pit and the mesa wall need it.
def level_2():
    lv = Level()
    bottom = 5
    s = 9                                   # everything after the "!" box moved right by this
    lv.ground(-6, 8, 0, bottom)
    lv.ground(11, 17, 0, bottom)            # 2-wide pit
    lv.fill(14, 15, -2, -2, BRICK_TOP)      # little step on the way
    lv.ground(20, 26, 0, bottom)            # 2-wide pit again
    lv.boxes.append((24, -1, DOUBLE_JUMP))  # sits on the ground: hop over it or onto it
    lv.ground(24 + s, 28 + s, 0, bottom)    # 6-wide pit: double jump only
    lv.bridge(29 + s, 34 + s, 0)
    lv.ground(35 + s, 39 + s, 0, bottom)
    lv.ground(40 + s, 47 + s, -4, bottom, STONE_TOP, STONE)   # 4-high wall: double jump only
    lv.fill(50 + s, 52 + s, -2, -2, BRICK_TOP)                # and back down
    lv.ground(55 + s, 78 + s, 0, bottom)

    lv.fill(-6, -6, -4, -1, STONE)          # wall so you can't walk off the left edge
    lv.fill(78 + s, 78 + s, -4, -1, STONE)
    lv.put(-6, -5, STONE_TOP)
    lv.put(78 + s, -5, STONE_TOP)

    lv.castle(63 + s, 73 + s, 0, 68 + s)

    lv.rack(-4, 0, 4)
    lv.rack(-3, 0, 3)
    lv.put(4, -1, MONITOR)
    lv.put(6, -1, BUSH)
    lv.rack(12, 0, 3)
    lv.put(17, -1, HEATSINK)
    lv.rack(21, 0, 3)
    lv.put(25 + s, -1, ROCK)
    lv.put(36 + s, -1, MONITOR)
    lv.rack(45 + s, -4, 4)
    lv.rack(46 + s, -4, 4)
    lv.put(42 + s, -5, GPU_L)
    lv.put(43 + s, -5, GPU_R)
    lv.put(57 + s, -1, BUSH)
    lv.flag(61 + s, 0, 5)
    lv.put(76 + s, -1, ROCK)

    lv.coins += [(3, -2), (5, -2), (9, -3), (10, -3), (14, -4), (15, -4), (18, -3), (19, -3)]
    lv.coins += [(x + s, y) for x, y in [(20, -4), (21, -4), (26, -3), (31, -2), (32, -2),
                                         (42, -7), (43, -7), (51, -4), (56, -2)]]
    lv.ducks += [(26 + s, 0, False, 24), (37 + s, 0, False, 24), (43 + s, -4, False, 40)]
    return dict(
        file='level_2.tscn', node='level_2', number=2, level=lv,
        player=feet(0, 0), princess=princess_at(59 + s, 0), castle_door=feet(68 + s, 0),
        kill_y=(bottom + 6) * T, background=(0.07, 0.09, 0.11),
    )


# ---------------------------------------------------------------- level 3: Overclock Tower
# Needs BOTH power-ups. The double jump "!" box (bottom left) is for the 4-tile
# steps; the sword "!" box sits halfway up the tower, and since it bounces you
# back to the start you have to climb up again to beat the blonde duck
# guarding the corridor near the top.
def level_3():
    lv = Level()
    top = -19                                # the floor with the princess and the castle
    roof = top - 10
    for x in range(1, 19):                   # dark interior backdrop
        for y in range(roof, 0):
            lv.back[(x, y)] = (2, 14)
    lv.ground(-2, 21, 0, 3, STONE_TOP, STONE)
    lv.fill(0, 0, roof, -1, STONE)           # tower walls
    lv.fill(19, 19, roof, -1, STONE)
    lv.put(0, roof - 1, BATTLEMENT)
    lv.put(19, roof - 1, BATTLEMENT)

    lv.boxes.append((2, -1, DOUBLE_JUMP))

    lv.fill(5, 8, -4, -4, BRICK_TOP)         # 4 tiles up each time: double jump only
    lv.fill(12, 15, -8, -8, BRICK_TOP)
    lv.boxes.append((15, -9, SWORD))        # halfway up
    lv.fill(1, 10, -12, -12, STONE_TOP)      # the guarded floor
    lv.fill(4, 8, -18, -15, STONE)           # low ceiling: no jumping over the guard
    lv.ducks.append((6, -12, True, 0))
    lv.put(1, -16, BRICK_TOP)                # ledge in the shaft behind the guard
    lv.fill(4, 18, top, top, STONE_TOP)

    lv.castle(11, 17, top, 14)

    for x, y in [(2, -5), (17, -9), (17, -15), (2, -22), (9, -23)]:
        lv.put(x, y, WINDOW)
    for x, y in [(10, -3), (3, -9), (13, -14)]:
        lv.put(x, y, BANNER)
    lv.rack(11, 0, 3)
    lv.rack(12, 0, 2)
    lv.put(6, -5, MONITOR)
    lv.put(17, -5, FAN)
    lv.put(10, -13, CHIP)
    lv.flag(5, top, 4)

    lv.coins += [(6, -6), (7, -6), (10, -9), (13, -10), (14, -10), (2, -14), (2, -19), (7, -21)]
    lv.ducks.append((14, 0, False, 36))
    return dict(
        file='level_3.tscn', node='level_3', number=3, level=lv,
        player=feet(9, 0), princess=princess_at(9, top), castle_door=feet(14, top),
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
[ext_resource type="PackedScene" path="res://scenes/coin.tscn" id="6_coin"]
[ext_resource type="PackedScene" path="res://scenes/duck.tscn" id="7_duck"]
[ext_resource type="PackedScene" path="res://scenes/bounce_box.tscn" id="8_box"]

[node name="{node}" type="Node2D"]
script = ExtResource("1_level")
level_number = {number}
kill_y = {kill_y}.0
background_color = Color({bg}, 1)
castle_door = Vector2({dx}, {dy})

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
{entities}'''


def entity_nodes(lv):
    """Scene text for the coins, ducks and "!" boxes of a level."""
    out = ''
    for i, (x, y, power) in enumerate(lv.boxes, 1):
        out += '\n[node name="BounceBox%d" parent="." instance=ExtResource("8_box")]\n' % i
        out += 'position = Vector2(%d, %d)\n' % (x * T + 8, y * T + 8)
        if power != DOUBLE_JUMP:   # double jump is the scene's default
            out += 'power = %d\n' % power
    for i, (x, floor, blonde, patrol) in enumerate(lv.ducks, 1):
        out += '\n[node name="Duck%d" parent="." instance=ExtResource("7_duck")]\n' % i
        out += 'position = Vector2(%d, %d)\n' % feet(x, floor)
        if blonde:
            out += 'blonde = true\n'
        else:
            out += 'patrol_distance = %d.0\n' % patrol
    for i, (x, y) in enumerate(lv.coins, 1):
        out += '\n[node name="Coin%d" parent="." instance=ExtResource("6_coin")]\n' % i
        out += 'position = Vector2(%d, %d)\n' % (x * T + 8, y * T + 8)
    return out


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
        dx=spec['castle_door'][0], dy=spec['castle_door'][1],
        entities=entity_nodes(lv),
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
    lv = spec['level']
    marks = [(spec['player'], (255, 60, 60, 255)), (spec['princess'], (255, 120, 220, 255))]
    marks += [((x * T + 8, y * T + 11), (255, 220, 0, 255)) for x, y in lv.coins]
    marks += [(feet(x, f), (255, 255, 255, 255) if not b else (255, 160, 0, 255)) for x, f, b, _ in lv.ducks]
    marks += [((x * T + 8, y * T + 11), (0, 255, 255, 255)) for x, y, _ in lv.boxes]
    for (px, py), colour in marks:
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
