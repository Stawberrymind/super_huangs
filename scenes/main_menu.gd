extends Control

const Levels = preload("res://scenes/levels.gd")
const Progress = preload("res://scenes/progress.gd")
const GREEN = Color(0.46, 0.73, 0)
const CONTROLS := [
	["A / D", "Move"],
	["SPACE", "Jump"],
	["SPACE in the air", "Double jump (once you have it)"],
	["LEFT CLICK", "Swing the sword (once you have it)"],
	["R", "Restart the level"],
	["F", "Toggle fullscreen"],
	["ESC", "Back to the menu"],
]

@onready var _buttons: VBoxContainer = %Buttons
@onready var _layout: Control = $Center/Layout

var _controls_screen: Control
var _controls_button: Button
var _fullscreen_button: Button

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.07))

	for i in Levels.LIST.size():
		var level: Dictionary = Levels.LIST[i]
		var button := Button.new()
		button.text = "Level %d - %s" % [i + 1, level["name"]]
		var saved := Progress.get_level(i + 1)
		if not saved.is_empty():
			button.text += "   BEST %s" % Progress.format_time(saved["best_time"])
		button.pressed.connect(_start_level.bind(level["scene"]))
		_buttons.add_child(button)

	_controls_button = Button.new()
	_controls_button.text = "Controls"
	_controls_button.pressed.connect(_show_controls)
	_buttons.add_child(_controls_button)

	_fullscreen_button = Button.new()
	_fullscreen_button.pressed.connect(Fullscreen.toggle)
	Fullscreen.changed.connect(_update_fullscreen_text)
	_update_fullscreen_text(Fullscreen.is_fullscreen())
	_buttons.add_child(_fullscreen_button)

	_controls_screen = _build_controls_screen()
	_controls_screen.hide()
	add_child(_controls_screen)

	# Lets the menu be driven with the keyboard / a controller as well.
	_buttons.get_child(0).grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _controls_screen.visible:
		_hide_controls()

func _update_fullscreen_text(on: bool) -> void:
	_fullscreen_button.text = "Exit Fullscreen" if on else "Fullscreen"

func _start_level(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func _show_controls() -> void:
	_layout.hide()
	_controls_screen.show()
	_controls_screen.find_child("Back", true, false).grab_focus()

func _hide_controls() -> void:
	_controls_screen.hide()
	_layout.show()
	_controls_button.grab_focus()

func _build_controls_screen() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var heading := Label.new()
	heading.text = "CONTROLS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 48)
	heading.add_theme_color_override("font_color", GREEN)
	box.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 12)
	for row in CONTROLS:
		var key := Label.new()
		key.text = row[0]
		key.add_theme_color_override("font_color", GREEN)
		grid.add_child(key)
		var action := Label.new()
		action.text = row[1]
		grid.add_child(action)
	box.add_child(grid)

	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.pressed.connect(_hide_controls)
	box.add_child(back)
	return center
