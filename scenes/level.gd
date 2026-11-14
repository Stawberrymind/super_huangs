extends Node2D

# Attach this to the root node of a level scene. It expects child nodes called
# "Player" and "Princess" and takes care of everything that is the same in
# every level: the HUD, respawning, restarting, going back to the menu, and
# the "level complete" screen when the player reaches the princess.

const Levels = preload("res://scenes/levels.gd")
const UI_THEME = preload("res://scenes/ui_theme.tres")

## Which level this is (1 = first entry in levels.gd).
@export var level_number: int = 1
## The player respawns when falling below this y position (in pixels).
@export var kill_y: float = 400.0
@export var background_color: Color = Color(0.3, 0.3, 0.3)

var completed := false

var _player: CharacterBody2D
var _spawn: Vector2
var _win_screen: Control

func _ready() -> void:
	RenderingServer.set_default_clear_color(background_color)
	_player = $Player
	_spawn = _player.global_position
	_add_goal($Princess)
	_build_hud()

func _physics_process(_delta: float) -> void:
	if not completed and _player.global_position.y > kill_y:
		_respawn()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_go_to_menu()
	elif event.keycode == KEY_R and not completed:
		get_tree().reload_current_scene()

func _respawn() -> void:
	_player.global_position = _spawn
	_player.velocity = Vector2.ZERO
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.global_position = _spawn

# Touching the princess finishes the level.
func _add_goal(princess: Node2D) -> void:
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var goal := Area2D.new()
	goal.name = "Goal"
	goal.add_child(collision)
	goal.body_entered.connect(_on_goal_body_entered)
	princess.add_child(goal)

func _on_goal_body_entered(body: Node2D) -> void:
	if body == _player and not completed:
		_complete()

func _complete() -> void:
	completed = true
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_win_screen.show()
	# Short delay so a jump that is still being held doesn't press a button.
	await get_tree().create_timer(0.4).timeout
	var buttons := _win_screen.find_children("*", "Button", true, false)
	for button in buttons:
		button.disabled = false
	buttons[0].grab_focus()

func _has_next_level() -> bool:
	return level_number < Levels.LIST.size()

func _go_to_next_level() -> void:
	get_tree().change_scene_to_file(Levels.LIST[level_number]["scene"])

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(Levels.MAIN_MENU)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var root := Control.new()
	root.theme = UI_THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := Label.new()
	title.text = "LEVEL %d - %s" % [level_number, _level_name().to_upper()]
	title.position = Vector2(16, 12)
	root.add_child(title)

	var help := Label.new()
	help.text = "A/D MOVE   SPACE JUMP   R RESTART   ESC MENU"
	help.modulate = Color(1, 1, 1, 0.6)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position += Vector2(16, -12)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(help)

	_win_screen = _build_win_screen()
	_win_screen.hide()
	root.add_child(_win_screen)

func _build_win_screen() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var heading := Label.new()
	heading.text = "LEVEL COMPLETE!" if _has_next_level() else "YOU WIN!"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 48)
	heading.add_theme_color_override("font_color", Color(0.46, 0.73, 0))
	box.add_child(heading)

	var sub := Label.new()
	sub.text = "You reached the princess." if _has_next_level() else "You rescued the princess from every level."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	if _has_next_level():
		box.add_child(_make_button("Next Level", _go_to_next_level))
	box.add_child(_make_button("Main Menu", _go_to_menu))
	return dim

func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = true
	button.pressed.connect(action)
	return button

func _level_name() -> String:
	if level_number >= 1 and level_number <= Levels.LIST.size():
		return Levels.LIST[level_number - 1]["name"]
	return ""
