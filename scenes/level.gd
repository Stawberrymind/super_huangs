extends Node2D

# Attach this to the root node of a level scene. It expects child nodes called
# "Player" and "Princess" and takes care of everything that is the same in
# every level: the HUD (health, RTX 5090s, power-ups), respawning, restarting,
# going back to the menu, and the ending:
#   knight reaches the princess -> hearts, she follows him ->
#   with every RTX 5090 collected, both walk into the castle door (and the
#   flag comes down) -> "Level complete" screen.

const Levels = preload("res://scenes/levels.gd")
const UI_THEME = preload("res://scenes/ui_theme.tres")
const HEART = preload("res://assets/sprites/heart.png")
const GPU = preload("res://assets/sprites/rtx5090.png")
const SWORD_ICON = preload("res://assets/sprites/sword.png")
const DOUBLE_JUMP_ICON = preload("res://assets/sprites/double_jump.png")
const WORLD_TILES = preload("res://assets/sprites/world_tileset.png")
const FLAG_TOP := Vector2i(10, 3)
const FLAG_BASE := Vector2i(10, 7)
const SOUNDS = {
	"coin": preload("res://assets/sounds/coin.wav"),
	"hurt": preload("res://assets/sounds/hurt.wav"),
	"power_up": preload("res://assets/sounds/power_up.wav"),
	"tap": preload("res://assets/sounds/tap.wav"),
	"explosion": preload("res://assets/sounds/explosion.wav"),
}
const GREEN = Color(0.46, 0.73, 0)
const LAYER_PLAYER = 2

## Which level this is (1 = first entry in levels.gd).
@export var level_number: int = 1
## The knight dies when falling below this y position (in pixels).
@export var kill_y: float = 400.0
@export var background_color: Color = Color(0.3, 0.3, 0.3)
## Where the knight's feet are when he stands in the castle doorway (in pixels).
@export var castle_door: Vector2 = Vector2.ZERO

var completed := false
var princess_rescued := false
var coins := 0
var total_coins := 0

var _player: CharacterBody2D
var _princess: CharacterBody2D
var _door_area: Area2D
var _ending := false
var _ending_time := 0.0
var _entered: Array = []
var _love_time := 0.0
var _love_turn := 0

var _hearts: Array = []
var _coin_label: Label
var _sword_row: Control
var _double_jump_row: Control
var _message: Label
var _message_tween: Tween
var _win_screen: Control
var _win_coins: Label
var _flags: Array = []   # [cloth sprite, y to lower it to]

func _ready() -> void:
	add_to_group("level")
	RenderingServer.set_default_clear_color(background_color)
	_player = $Player
	_princess = $Princess
	total_coins = get_tree().get_nodes_in_group("coins").size()

	_add_goal(_princess)
	_add_door()
	_setup_flags()
	_build_hud()

	_player.health_changed.connect(_update_health)
	_player.powers_changed.connect(_update_powers)
	_player.respawned.connect(_snap_camera)
	_update_health(_player.health)
	_update_powers()
	_update_coins()

func _physics_process(delta: float) -> void:
	if completed:
		return
	if _ending:
		_update_ending(delta)
		return
	if _player.global_position.y > kill_y and not _player.is_bouncing():
		_player.kill()
	if _door_area and _door_area.overlaps_body(_player) and _player.is_on_floor():
		if not princess_rescued:
			show_message("Rescue the princess first!")
		elif coins < total_coins:
			show_message("Collect all the RTX 5090s first! (%d/%d)" % [coins, total_coins])
		else:
			_start_ending()

func _process(delta: float) -> void:
	# Little hearts above the two of them once they have met.
	if princess_rescued and not completed:
		_love_time -= delta
		if _love_time <= 0.0:
			_love_time = 0.55
			_love_turn += 1
			if _love_turn % 2 == 0:
				_spawn_love_heart(_player, -31.0)
			else:
				_spawn_love_heart(_princess, -19.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_go_to_menu()
	elif event.keycode == KEY_R and not completed:
		get_tree().reload_current_scene()

# ---------------------------------------------------------------- used by coins, boxes, ducks, the knight

func collect_coin() -> void:
	coins += 1
	_update_coins()
	play_sound("coin")

func play_sound(sound: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound]
	player.volume_db = -8.0
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## Shows a line of text near the top of the screen for a few seconds.
func show_message(text: String, seconds: float = 2.5) -> void:
	if _message.text == text and _message.modulate.a > 0.9:
		return
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)

# ---------------------------------------------------------------- princess and castle

# Touching the princess makes her follow the knight.
func _add_goal(princess: Node2D) -> void:
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var goal := Area2D.new()
	goal.name = "Goal"
	goal.collision_layer = 0
	goal.collision_mask = LAYER_PLAYER
	goal.add_child(collision)
	goal.body_entered.connect(_on_goal_body_entered)
	princess.add_child(goal)

func _add_door() -> void:
	if castle_door == Vector2.ZERO:
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 28)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_door_area = Area2D.new()
	_door_area.name = "CastleDoor"
	_door_area.collision_layer = 0
	_door_area.collision_mask = LAYER_PLAYER
	_door_area.position = castle_door + Vector2(0, -14)
	_door_area.add_child(collision)
	add_child(_door_area)

func _on_goal_body_entered(body: Node2D) -> void:
	if body != _player or princess_rescued:
		return
	princess_rescued = true
	_princess.start_following(_player)
	play_sound("power_up")
	if _door_area:
		show_message("Lead the princess into the castle", 4.0)
	else:
		_start_ending()

func _spawn_love_heart(above: Node2D, offset_y: float) -> void:
	if above.modulate.a < 0.5:
		return   # already inside the castle
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.z_index = 10
	heart.modulate.a = 0.0
	heart.position = above.global_position + Vector2(randf_range(-4.0, 4.0), offset_y)
	add_child(heart)
	var tween := heart.create_tween()
	tween.tween_property(heart, "modulate:a", 0.7, 0.3)
	tween.parallel().tween_property(heart, "position:y", heart.position.y - 12.0, 1.3)
	tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tween.tween_callback(heart.queue_free)

# Both walk to the door and disappear inside, then the level is complete.
func _start_ending() -> void:
	_ending = true
	_ending_time = 0.0
	_player.controls_locked = true
	var door_x := castle_door.x if _door_area else _player.global_position.x
	_player.walk_to(door_x)
	_princess.walk_to(door_x)
	_lower_flags()

func _update_ending(delta: float) -> void:
	_ending_time += delta
	var door_x := castle_door.x if _door_area else _player.global_position.x
	for actor in [_player, _princess]:
		if actor not in _entered and (abs(actor.global_position.x - door_x) <= 3.0 or _ending_time > 5.0):
			_entered.append(actor)
			create_tween().tween_property(actor, "modulate:a", 0.0, 0.4)
	if _entered.size() == 2:
		_complete()

func _complete() -> void:
	completed = true
	await get_tree().create_timer(0.8).timeout
	_win_coins.text = "RTX 5090s: %d/%d" % [coins, total_coins]
	_win_screen.show()
	var buttons := _win_screen.find_children("*", "Button", true, false)
	for button in buttons:
		button.disabled = false
	buttons[0].grab_focus()

# ---------------------------------------------------------------- flags

# The flag cloth is baked into the flag-top tile, so swap that tile for two
# sprites (pole and cloth) to be able to slide the cloth down the pole.
func _setup_flags() -> void:
	var tilemap := get_node_or_null("TileMap") as TileMap
	if not tilemap:
		return
	for layer in tilemap.get_layers_count():
		for cell in tilemap.get_used_cells_by_id(layer, -1, FLAG_TOP):
			var base := cell + Vector2i.DOWN
			while base.y < cell.y + 32 and tilemap.get_cell_atlas_coords(layer, base) != FLAG_BASE:
				base += Vector2i.DOWN
			tilemap.erase_cell(layer, cell)
			var top_left := tilemap.map_to_local(cell) - Vector2(8, 8)
			# Pole and knob: columns 0-5 of the tile. Cloth: columns 6-15, rows 4-13.
			tilemap.add_child(_tile_sprite(Rect2(160, 48, 6, 16), top_left))
			var cloth := _tile_sprite(Rect2(166, 52, 10, 10), top_left + Vector2(6, 4))
			tilemap.add_child(cloth)
			var lowest := tilemap.map_to_local(base).y - 8.0 - 10.0
			_flags.append([cloth, lowest])

func _tile_sprite(region: Rect2, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = WORLD_TILES
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.position = at
	return sprite

func _lower_flags() -> void:
	for flag in _flags:
		var cloth: Sprite2D = flag[0]
		var tween := cloth.create_tween()
		tween.tween_property(cloth, "position:y", flag[1], 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _snap_camera() -> void:
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.global_position = _player.global_position

func _has_next_level() -> bool:
	return level_number < Levels.LIST.size()

func _go_to_next_level() -> void:
	get_tree().change_scene_to_file(Levels.LIST[level_number]["scene"])

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(Levels.MAIN_MENU)

# ---------------------------------------------------------------- HUD

func _update_health(health: int) -> void:
	for i in _hearts.size():
		_hearts[i].modulate = Color.WHITE if i < health else Color(0.2, 0.2, 0.22, 0.7)

func _update_powers() -> void:
	_sword_row.visible = _player.has_sword
	_double_jump_row.visible = _player.has_double_jump

func _update_coins() -> void:
	_coin_label.text = "%d/%d" % [coins, total_coins]

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var root := Control.new()
	root.theme = UI_THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Top left: level name, health, power-ups.
	var left := VBoxContainer.new()
	left.position = Vector2(16, 12)
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)

	var title := Label.new()
	title.text = "LEVEL %d - %s" % [level_number, _level_name().to_upper()]
	left.add_child(title)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 6)
	for i in _player.MAX_HEALTH:
		var heart := _make_icon(HEART, Vector2(28, 24))
		health_row.add_child(heart)
		_hearts.append(heart)
	left.add_child(health_row)

	_sword_row = _make_power_row(SWORD_ICON, "SWORD")
	left.add_child(_sword_row)
	_double_jump_row = _make_power_row(DOUBLE_JUMP_ICON, "DOUBLE JUMP")
	left.add_child(_double_jump_row)

	# Top right: RTX 5090 counter.
	var right := HBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -216.0
	right.offset_right = -16.0
	right.offset_top = 8.0
	right.offset_bottom = 40.0
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)

	var gpu_icon := AtlasTexture.new()
	gpu_icon.atlas = GPU
	gpu_icon.region = Rect2(0, 0, 16, 16)
	right.add_child(_make_icon(gpu_icon, Vector2(32, 32)))
	_coin_label = Label.new()
	right.add_child(_coin_label)

	# Top middle: messages.
	_message = Label.new()
	_message.anchor_right = 1.0
	_message.offset_top = 132.0
	_message.offset_bottom = 156.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.07))
	_message.add_theme_constant_override("outline_size", 8)
	_message.modulate.a = 0.0
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message)

	_win_screen = _build_win_screen()
	_win_screen.hide()
	root.add_child(_win_screen)

func _make_icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_power_row(texture: Texture2D, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_make_icon(texture, Vector2(32, 32)))
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.8)
	row.add_child(label)
	return row

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
	heading.text = "LEVEL COMPLETE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 48)
	heading.add_theme_color_override("font_color", GREEN)
	box.add_child(heading)

	var sub := Label.new()
	sub.text = "You've rescued the princess."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_win_coins = Label.new()
	_win_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_coins.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_win_coins)

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
