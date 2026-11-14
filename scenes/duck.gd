extends CharacterBody2D

# Duck enemy. Touching one costs the knight a heart.
#  - brown hair:  walks back and forth. Jump over it (or use the sword).
#  - blonde hair: a guard. Stands its ground, can't be walked through and
#                 only goes away when hit with the sword.
#  - jumper (blue tint): walks back and forth like a brown duck but keeps
#                 hopping, so it's harder to jump over.

const SPEED = 30.0
const LAYER_WORLD = 1
const LAYER_ENEMY = 4
const LAYER_SOLID_ENEMY = 8

## Blonde ducks are guards that need the sword.
@export var blonde := false
## How far (in pixels) a brown duck walks to each side of where it starts.
@export var patrol_distance := 40.0
## Hops every second or so while it patrols.
@export var jumper := false

const HOP_VELOCITY = -230.0
const JUMPER_TINT = Color(0.6, 0.85, 1.25)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var _direction := -1
var _start_x := 0.0
var _dead := false
var _hint_cooldown := 0.0
var _hop_time := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurt_area: Area2D = $Hurt
@onready var _floor_check: RayCast2D = $FloorCheck

func _ready() -> void:
	add_to_group("enemies")
	_start_x = global_position.x
	collision_mask = LAYER_WORLD
	collision_layer = LAYER_ENEMY | LAYER_SOLID_ENEMY if blonde else LAYER_ENEMY
	_sprite.play("blonde" if blonde else "brown")
	if jumper and not blonde:
		_sprite.modulate = JUMPER_TINT
		_hop_time = randf_range(0.4, 1.2)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hint_cooldown -= delta
	if not is_on_floor():
		velocity.y += gravity * delta

	if blonde:
		velocity.x = 0.0
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			_direction = -1 if player.global_position.x < global_position.x else 1
	else:
		_patrol()
		velocity.x = _direction * SPEED
		if jumper and is_on_floor():
			_hop_time -= delta
			if _hop_time <= 0.0:
				_hop_time = randf_range(0.8, 1.4)
				velocity.y = HOP_VELOCITY
				_squash(Vector2(0.75, 1.3))

	# The picture faces left.
	_sprite.flip_h = _direction > 0
	move_and_slide()

	for body in _hurt_area.get_overlapping_bodies():
		if body.has_method("hurt") and body.hurt(global_position.x):
			if blonde and not body.has_sword and _hint_cooldown <= 0.0:
				_hint_cooldown = 4.0
				var level := get_tree().get_first_node_in_group("level")
				if level:
					level.show_message("This duck needs a sword - find a ! box")

func _patrol() -> void:
	if not is_on_floor():
		return
	var offset := global_position.x - _start_x
	if abs(offset) > patrol_distance:
		_direction = -1 if offset > 0.0 else 1
	elif is_on_wall():
		_direction = 1 if get_wall_normal().x > 0.0 else -1
	else:
		# Turn around at ledges.
		_floor_check.position.x = _direction * 8.0
		_floor_check.force_raycast_update()
		if not _floor_check.is_colliding():
			_direction = -_direction

## Called by the knight's sword.
func take_hit() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	_hurt_area.set_deferred("monitoring", false)
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.play_sound("explosion")
		level.spawn_puff(global_position + Vector2(0, -8), Color(1, 1, 1), 14, 80.0, 0.5)
		level.spawn_puff(global_position + Vector2(0, -8), Color(1.0, 0.75, 0.2), 6, 60.0, 0.4)
		level.shake(3.0, 0.15)
		level.hit_stop(0.07)
	_sprite.stop()
	_sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "rotation", PI, 0.35)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

func _squash(amount: Vector2) -> void:
	_sprite.scale = amount
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
