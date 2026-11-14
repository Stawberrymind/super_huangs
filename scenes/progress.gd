extends RefCounted

# Saves which levels have been beaten, the best time and the most RTX 5090s
# collected per level. Stored in user://, which in a browser build is kept
# in the browser's storage, so progress survives reloading the itch.io page.

const PATH := "user://progress.cfg"

## Returns {} if the level has never been beaten, otherwise
## {"best_time": float, "coins": int, "total_coins": int}.
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
	}

## Records a finished run. Returns true if it is a new best time.
static func record(level_number: int, time: float, coins: int, total_coins: int) -> bool:
	var file := ConfigFile.new()
	file.load(PATH)   # fine if it doesn't exist yet
	var section := "level_%d" % level_number
	var best := float(file.get_value(section, "best_time", INF))
	var new_best := time < best
	if new_best:
		file.set_value(section, "best_time", time)
	file.set_value(section, "coins", maxi(coins, int(file.get_value(section, "coins", 0))))
	file.set_value(section, "total_coins", total_coins)
	file.save(PATH)
	return new_best

static func format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%04.1f" % [minutes, seconds - minutes * 60]
