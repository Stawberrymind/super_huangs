extends StaticBody2D

# A "!" box. Jump on top of it and it shows "Bounce Back", hands the knight
# a power-up and bounces him back to the start of the level.

enum Power { SWORD, DOUBLE_JUMP }

const FONT = preload("res://assets/fonts/PixelOperator8-Bold.ttf")
# Which "!" tile of the tileset to show: red for the sword, green for the double jump.
const TILE = { Power.SWORD: Vector2(5, 2), Power.DOUBLE_JUMP: Vector2(8, 2) }
const POWER_NAME = { Power.SWORD: "sword", Power.DOUBLE_JUMP: "double_jump" }
const MESSAGE = {
	Power.SWORD: "Sword! Left click to swing it",
	Power.DOUBLE_JUMP: "Double jump! Press SPACE again in the air",
}

@export var power: Power = Power.DOUBLE_JUMP

var _cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _top: Area2D = $Top

func _ready() -> void:
	_sprite.region_rect = Rect2(TILE[power] * 16.0, Vector2(16, 16))

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	for body in _top.get_overlapping_bodies():
		# Only when standing on top of the box, not when brushing past it.
		if body.has_method("bounce_back") and body.is_on_floor() \
				and body.global_position.y <= global_position.y - 6.0:
			_trigger(body)
			return

func _trigger(player: Node2D) -> void:
	_cooldown = 2.5
	player.grant_power(POWER_NAME[power])
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.play_sound("power_up")
		level.show_message(MESSAGE[power], 4.0)
	_show_text()
	_squash()
	player.bounce_back()

func _show_text() -> void:
	var label := Label.new()
	label.text = "Bounce Back"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.08))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 12)
	label.position = global_position + Vector2(-60, -30)
	label.z_index = 20
	get_parent().add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16.0, 1.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tween.tween_callback(label.queue_free)

func _squash() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.25, 0.7), 0.08)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.2)
