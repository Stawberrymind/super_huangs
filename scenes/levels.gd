extends RefCounted

# The list of levels, in play order. Add a new entry here and it shows up
# in the main menu and in the "next level" chain automatically.
# "par" is the time (in seconds) to beat for the third star.

const MAIN_MENU := "res://scenes/main_menu.tscn"

const LIST := [
	{"name": "Nvidia Castle", "scene": "res://scenes/game.tscn", "par": 60.0},
	{"name": "Server Farm", "scene": "res://scenes/level_2.tscn", "par": 75.0},
	{"name": "Overclock Tower", "scene": "res://scenes/level_3.tscn", "par": 90.0},
	{"name": "Neon Rooftops", "scene": "res://scenes/level_4.tscn", "par": 120.0},
	{"name": "Mainframe Core", "scene": "res://scenes/level_5.tscn", "par": 150.0},
	{"name": "The Cloud", "scene": "res://scenes/level_6.tscn", "par": 240.0},
]
