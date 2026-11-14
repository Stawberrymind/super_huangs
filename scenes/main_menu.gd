extends Control

const Levels = preload("res://scenes/levels.gd")

@onready var _buttons: VBoxContainer = %Buttons

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.07))

	for i in Levels.LIST.size():
		var level: Dictionary = Levels.LIST[i]
		var button := Button.new()
		button.text = "Level %d - %s" % [i + 1, level["name"]]
		button.pressed.connect(_start_level.bind(level["scene"]))
		_buttons.add_child(button)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(get_tree().quit)
	_buttons.add_child(quit)

	# Lets the menu be driven with the keyboard / a controller as well.
	_buttons.get_child(0).grab_focus()

func _start_level(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
