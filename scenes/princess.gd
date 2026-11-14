extends CharacterBody2D

# The princess stands still until the knight reaches her, then follows him.

const SPEED = 95.0
const JUMP_VELOCITY = -300.0
const KEEP_DISTANCE = 20.0   # how close she walks up to the knight
const LEASH = 200.0          # further away than this and she catches up instantly
const FEET = 15.0            # her origin is at her centre; her feet are this far below

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var _target: CharacterBody2D
var _auto_walk := false
var _auto_walk_x := 0.0

func _ready() -> void:
	# She only collides with the world, so the knight can walk past her.
	collision_layer = 0
	collision_mask = 1

func start_following(target: CharacterBody2D) -> void:
	_target = target

func is_following() -> bool:
	return _target != null

## Makes her walk to `x` on her own (used when entering the castle).
func walk_to(x: float) -> void:
	_auto_walk = true
	_auto_walk_x = x

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := 0.0
	if _auto_walk:
		var distance := _auto_walk_x - global_position.x
		if abs(distance) > 2.0:
			direction = sign(distance)
	elif _target:
		var to_target := _target.global_position - (global_position + Vector2(0, FEET))
		if _target.is_on_floor() and (abs(to_target.x) > LEASH or abs(to_target.y) > 100.0):
			# Left behind (fell in a pit, got stuck...): catch up.
			global_position = _target.global_position - Vector2(0, FEET)
			velocity = Vector2.ZERO
		elif abs(to_target.x) > KEEP_DISTANCE:
			direction = sign(to_target.x)
			# Hop over steps, and up to the knight if he is standing higher.
			if is_on_floor() and (is_on_wall() or (to_target.y < -20.0 and abs(to_target.x) < 48.0)):
				velocity.y = JUMP_VELOCITY

	velocity.x = direction * SPEED
	move_and_slide()
