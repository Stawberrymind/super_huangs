extends RefCounted

# The list of levels, in play order. Add a new entry here and it shows up
# in the main menu and in the "next level" chain automatically.

const MAIN_MENU := "res://scenes/main_menu.tscn"

const LIST := [
	{"name": "Nvidia Castle", "scene": "res://scenes/game.tscn"},
	{"name": "Server Farm", "scene": "res://scenes/level_2.tscn"},
	{"name": "Overclock Tower", "scene": "res://scenes/level_3.tscn"},
	{"name": "Neon Rooftops", "scene": "res://scenes/level_4.tscn"},
	{"name": "Mainframe Core", "scene": "res://scenes/level_5.tscn"},
]
