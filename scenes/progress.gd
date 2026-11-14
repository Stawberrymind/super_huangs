extends RefCounted

# Saves which levels have been beaten, the best time and the most RTX 5090s
# collected per level. Stored in user://, which in a browser build is kept
# in the browser's storage, so progress survives reloading the itch.io page.

const PATH := "user://progress.cfg"

## Returns {} if the level has never been beaten, otherwise
## {"best_time": float, "coins": int, "total_coins": int, "stars": int}.
## stars is a bit mask: 1 = finished, 2 = no deaths, 4 = beat the par time.
static func get_level(level_number: int) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return {}
	var section := "level_%d" % level_number
	if not file.has_section(section):
		return {}
	return {
		"best_time": float(file.get_value(section, "best_time", 0.0)),
		"coins": int(file.get_value(section, "coins", 0)),
		"total_coins": int(file.get_value(section, "total_coins", 0)),
		"stars": int(file.get_value(section, "stars", 1)),
	}

## Records a finished run. Returns true if it is a new best time.
static func record(level_number: int, time: float, coins: int, total_coins: int, stars: int = 1) -> bool:
	var file := ConfigFile.new()
	file.load(PATH)   # fine if it doesn't exist yet
	var section := "level_%d" % level_number
	var best := float(file.get_value(section, "best_time", INF))
	var new_best := time < best
	if new_best:
		file.set_value(section, "best_time", time)
	file.set_value(section, "coins", maxi(coins, int(file.get_value(section, "coins", 0))))
	file.set_value(section, "total_coins", total_coins)
	file.set_value(section, "stars", int(file.get_value(section, "stars", 0)) | stars)
	file.save(PATH)
	return new_best

static func format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60]

static func star_count(stars: int) -> int:
	return (stars & 1) + ((stars >> 1) & 1) + ((stars >> 2) & 1)

const _STAR := [
	"....#....",
	"...###...",
	"...###...",
	"#########",
	".#######.",
	"..#####..",
	"..#####..",
	".###.###.",
	".##...##.",
]
static var _star_cache := {}

## A 9x9 pixel star: gold when earned, dark when not.
static func star_texture(earned: bool) -> Texture2D:
	if _star_cache.has(earned):
		return _star_cache[earned]
	var fill := Color(1.0, 0.82, 0.25) if earned else Color(0.25, 0.26, 0.3)
	var shade := Color(0.85, 0.55, 0.1) if earned else Color(0.18, 0.19, 0.22)
	var image := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in 9:
		for x in 9:
			if _STAR[y][x] == "#":
				image.set_pixel(x, y, shade if y >= 6 or x >= 6 else fill)
	var texture := ImageTexture.create_from_image(image)
	_star_cache[earned] = texture
	return texture
