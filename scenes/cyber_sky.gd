extends CanvasLayer

# Cyberpunk backdrop: a purple-to-pink sky with stars, a striped synthwave sun
# and two layers of neon-lit skyline that scroll slower than the level
# (parallax). Everything is drawn in code as chunky pixels, no textures.
# Kept dark and muted, with nothing blinking, so it stays in the background.

const PX := 3.0            # size of one sky pixel on screen
const PERIOD := 480        # the skyline repeats every this many sky pixels

const SKY := [
	Color(0.04, 0.03, 0.08), Color(0.06, 0.04, 0.11), Color(0.09, 0.05, 0.14),
	Color(0.12, 0.06, 0.17), Color(0.16, 0.07, 0.19), Color(0.20, 0.09, 0.21),
]
const SUN_TOP := Color(0.42, 0.26, 0.24)
const SUN_BOTTOM := Color(0.34, 0.12, 0.24)
const FAR_CITY := Color(0.09, 0.05, 0.13)
const NEAR_CITY := Color(0.05, 0.03, 0.08)
const NEON := [Color(0.2, 0.55, 0.62), Color(0.58, 0.22, 0.48), Color(0.45, 0.55, 0.22)]
const WINDOW_ALPHA := 0.45

var _stars: Array = []       # [x, y, phase]
var _far: Array = []         # [x, width, height]
var _near: Array = []        # [x, width, height, windows: Array[[x, y, colour]], sign colour or null]

var _canvas: Node2D

func _ready() -> void:
	layer = -10
	_canvas = Node2D.new()
	_canvas.scale = Vector2(PX, PX)
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	for i in 40:
		_stars.append([rng.randi_range(0, PERIOD), rng.randi_range(0, 120), rng.randf() * TAU])
	var x := 0
	while x < PERIOD:
		var w := rng.randi_range(14, 34)
		_far.append([x, w, rng.randi_range(40, 95)])
		x += w + rng.randi_range(0, 6)
	x = 0
	while x < PERIOD:
		var w := rng.randi_range(18, 40)
		var h := rng.randi_range(25, 70)
		var windows := []
		for wy in range(4, h - 2, 5):
			for wx in range(3, w - 3, 4):
				if rng.randf() < 0.15:
					windows.append([wx, wy, NEON[rng.randi_range(0, NEON.size() - 1)]])
		var sign_colour = NEON[rng.randi_range(0, NEON.size() - 1)] if rng.randf() < 0.2 else null
		_near.append([x, w, h, windows, sign_colour])
		x += w + rng.randi_range(2, 10)

func _process(_delta: float) -> void:
	_canvas.queue_redraw()   # for the parallax

func _camera_x() -> float:
	var camera := get_viewport().get_camera_2d()
	return camera.get_screen_center_position().x if camera else 0.0

func _draw_sky() -> void:
	var size := get_viewport().get_visible_rect().size / PX
	var w := ceilf(size.x) + 1.0
	var h := ceilf(size.y) + 1.0
	var horizon := floorf(h * 0.72)

	# Sky in hard-edged bands.
	var band := ceilf(horizon / SKY.size())
	for i in SKY.size():
		_canvas.draw_rect(Rect2(0, i * band, w, band + 1), SKY[i])
	_canvas.draw_rect(Rect2(0, horizon, w, h - horizon), NEAR_CITY)

	# A few faint stars in the top part.
	var cam := _camera_x()
	var star_shift := fposmod(cam * 0.02, PERIOD)
	for star in _stars:
		if star[1] > horizon * 0.6:
			continue
		for rep in range(0, int(w) + PERIOD, PERIOD):
			var sx: float = fposmod(star[0] - star_shift, PERIOD) + rep - PERIOD
			if sx >= 0 and sx < w:
				_canvas.draw_rect(Rect2(sx, star[1], 1, 1), Color(0.8, 0.75, 0.9, 0.12 + 0.18 * absf(sin(star[2]))))

	# Synthwave sun, sitting on the horizon, with gaps in its lower half.
	var r := floorf(minf(w, h) * 0.15)
	var cx := floorf(w * 0.5)
	var cy := horizon - floorf(r * 0.35)
	for dy in range(-int(r), int(r) + 1):
		var y := cy + dy
		if y >= horizon:
			break
		var t := float(dy + r) / (2.0 * r)
		if dy > 0 and dy % 6 < 1 + floori(dy / 6.0):
			continue
		var half := floorf(sqrt(r * r - dy * dy))
		_canvas.draw_rect(Rect2(cx - half, y, half * 2.0 + 1.0, 1), SUN_TOP.lerp(SUN_BOTTOM, t))

	# Far skyline, then near skyline with lit windows and neon signs.
	_draw_city(_far, cam * 0.04, horizon, w, FAR_CITY, false)
	_draw_city(_near, cam * 0.12, horizon + 6.0, w, NEAR_CITY, true)


func _draw_city(buildings: Array, scroll: float, base: float, w: float, colour: Color, detailed: bool) -> void:
	var shift := fposmod(scroll, PERIOD)
	for rep in range(0, int(w) + PERIOD * 2, PERIOD):
		for b in buildings:
			var bx: float = floorf(b[0] - shift + rep - PERIOD)
			var bw: float = b[1]
			if bx + bw < 0 or bx > w:
				continue
			var top: float = base - b[2]
			_canvas.draw_rect(Rect2(bx, top, bw, b[2] + 200), colour)
			if not detailed:
				continue
			for win in b[3]:
				var lit: Color = win[2]
				lit.a = WINDOW_ALPHA
				_canvas.draw_rect(Rect2(bx + win[0], top + win[1], 1, 1), lit)
			if b[4] != null:
				var sign_colour: Color = b[4]
				sign_colour.a = WINDOW_ALPHA
				_canvas.draw_rect(Rect2(bx + 2, top - 2, bw - 4, 1), sign_colour)
