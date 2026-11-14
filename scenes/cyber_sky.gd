extends CanvasLayer

# Cyberpunk backdrop: a purple-to-pink sky with stars, a striped synthwave sun
# and two layers of neon-lit skyline that scroll slower than the level
# (parallax). Everything is drawn in code as chunky pixels, no textures.

const PX := 3.0            # size of one sky pixel on screen
const PERIOD := 480        # the skyline repeats every this many sky pixels

const SKY := [
	Color(0.04, 0.02, 0.10), Color(0.10, 0.03, 0.20), Color(0.22, 0.04, 0.32),
	Color(0.40, 0.06, 0.42), Color(0.66, 0.12, 0.48), Color(0.92, 0.30, 0.52),
]
const SUN_TOP := Color(1.0, 0.86, 0.32)
const SUN_BOTTOM := Color(1.0, 0.25, 0.55)
const FAR_CITY := Color(0.20, 0.06, 0.30)
const NEAR_CITY := Color(0.06, 0.03, 0.12)
const NEON := [Color(0.0, 0.95, 1.0), Color(1.0, 0.2, 0.75), Color(0.75, 1.0, 0.2)]

var _stars: Array = []       # [x, y, phase]
var _far: Array = []         # [x, width, height]
var _near: Array = []        # [x, width, height, windows: Array[[x, y, colour]], sign colour or null]
var _time := 0.0

var _canvas: Node2D

func _ready() -> void:
	layer = -10
	_canvas = Node2D.new()
	_canvas.scale = Vector2(PX, PX)
	_canvas.draw.connect(_draw_sky)
	add_child(_canvas)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	for i in 90:
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
				if rng.randf() < 0.35:
					windows.append([wx, wy, NEON[rng.randi_range(0, NEON.size() - 1)]])
		var sign_colour = NEON[rng.randi_range(0, NEON.size() - 1)] if rng.randf() < 0.4 else null
		_near.append([x, w, h, windows, sign_colour])
		x += w + rng.randi_range(2, 10)

func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()

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

	# Twinkling stars in the top part.
	var cam := _camera_x()
	var star_shift := fposmod(cam * 0.02, PERIOD)
	for star in _stars:
		if star[1] > horizon * 0.6:
			continue
		var on := sin(_time * 2.0 + star[2]) > -0.3
		if on:
			for rep in range(0, int(w) + PERIOD, PERIOD):
				var sx: float = fposmod(star[0] - star_shift, PERIOD) + rep - PERIOD
				if sx >= 0 and sx < w:
					_canvas.draw_rect(Rect2(sx, star[1], 1, 1), Color(1, 0.9, 1, 0.9))

	# Synthwave sun, sitting on the horizon, with gaps in its lower half.
	var r := floorf(minf(w, h) * 0.22)
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

	# Neon line on the horizon.
	_canvas.draw_rect(Rect2(0, h - 2, w, 1), Color(1.0, 0.2, 0.75, 0.6))

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
				lit.a = 0.75
				_canvas.draw_rect(Rect2(bx + win[0], top + win[1], 2, 2), lit)
			if b[4] != null:
				var on := sin(_time * 3.0 + bx) > -0.6
				var sign_colour: Color = b[4]
				_canvas.draw_rect(Rect2(bx + 2, top - 3, bw - 4, 2), sign_colour if on else sign_colour.darkened(0.6))
