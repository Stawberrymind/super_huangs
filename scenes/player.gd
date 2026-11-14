
extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -300.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump with Space
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# WASD movement
	var direction = 0

	if Input.is_key_pressed(KEY_A):
		direction -= 1

	if Input.is_key_pressed(KEY_D):
		direction += 1

	velocity.x = direction * SPEED

	move_and_slide()
