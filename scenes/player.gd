extends CharacterBody2D

signal health_changed(health: int)
signal powers_changed
signal respawned

const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const MAX_HEALTH = 3

# Physics layers used by the game.
const LAYER_WORLD = 1         # tiles, "!" boxes
const LAYER_PLAYER = 2        # the knight
const LAYER_ENEMY = 4         # every duck (what the sword hits)
const LAYER_SOLID_ENEMY = 8   # ducks the knight cannot walk through

const SWORD_TEXTURE = preload("res://assets/sprites/sword.png")
const ATTACK_TIME = 0.22

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var health := MAX_HEALTH
var has_sword := false
var has_double_jump := false
var facing := 1
var spawn_position := Vector2.ZERO
## Read by animation.gd: "" = normal, otherwise the animation to force ("hit", "death", "roll").
var anim_state := ""
## Set by the level during the ending so the player can't interfere.
var controls_locked := false

var _hurt_time := 0.0
var _invulnerable_time := 0.0
var _attack_time := 0.0
var _dead := false
var _bouncing := false
var _used_double_jump := false
var _jump_was_down := false
var _click_was_down := false
var _auto_walk := false
var _auto_walk_x := 0.0

var _sword_pivot: Node2D
var _sword_area: Area2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD | LAYER_SOLID_ENEMY
	_build_sword()

func _physics_process(delta: float) -> void:
	_hurt_time = max(_hurt_time - delta, 0.0)
	_invulnerable_time = max(_invulnerable_time - delta, 0.0)
	_update_look()

	if _bouncing:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		_used_double_jump = false

	var jump_down := Input.is_key_pressed(KEY_SPACE)
	var click_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if _auto_walk:
		# The ending: walk to a spot on our own.
		var distance := _auto_walk_x - global_position.x
		var direction := 0.0
		if abs(distance) > 2.0:
			direction = sign(distance)
			facing = int(direction)
		velocity.x = direction * SPEED * 0.7
	elif _dead or _hurt_time > 0.0 or controls_locked:
		# No control: slide to a stop (keeps the knock-back from a hit).
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		# Jump with Space (and once more in the air with the double jump)
		if jump_down and is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif jump_down and not _jump_was_down and not is_on_floor() \
				and has_double_jump and not _used_double_jump:
			velocity.y = JUMP_VELOCITY
			_used_double_jump = true

		# WASD movement
		var direction := 0
		if Input.is_key_pressed(KEY_A):
			direction -= 1
		if Input.is_key_pressed(KEY_D):
			direction += 1
		if direction != 0:
			facing = direction
		velocity.x = direction * SPEED

		# Swing the sword with the left mouse button
		if click_down and not _click_was_down and has_sword and _attack_time <= 0.0:
			_attack_time = ATTACK_TIME
			_play_sound("tap")

	_jump_was_down = jump_down
	_click_was_down = click_down

	_update_sword(delta)
	move_and_slide()

# ---------------------------------------------------------------- health

## Called by enemies. `from_x` is where the hit came from (for the knock-back).
## Returns true if the hit actually landed.
func hurt(from_x: float) -> bool:
	if _dead or _bouncing or _auto_walk or controls_locked or _invulnerable_time > 0.0:
		return false
	health -= 1
	health_changed.emit(health)
	_play_sound("hurt")

	var away: float = sign(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 130.0, -170.0)
	_hurt_time = 0.35
	_invulnerable_time = 1.2
	_attack_time = 0.0
	if health <= 0:
		_die()
	return true

func _die() -> void:
	_dead = true
	await get_tree().create_timer(1.0).timeout
	respawn()

## Back to the start of the level with full health. Power-ups are kept.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	_dead = false
	_hurt_time = 0.0
	_invulnerable_time = 1.0
	health_changed.emit(health)
	respawned.emit()

# ---------------------------------------------------------------- power-ups

func grant_power(power: String) -> void:
	if power == "sword":
		has_sword = true
	elif power == "double_jump":
		has_double_jump = true
	powers_changed.emit()

## The "!" boxes: fly back to the start of the level in a big arc.
func bounce_back() -> void:
	if _bouncing or _dead:
		return
	_bouncing = true
	_attack_time = 0.0
	_hurt_time = 0.0
	velocity = Vector2.ZERO

	var from := global_position
	var distance := from.distance_to(spawn_position)
	var height: float = clamp(40.0 + distance * 0.25, 48.0, 160.0)
	var duration: float = clamp(distance / 260.0, 0.7, 1.6)
	if spawn_position.x != from.x:
		facing = int(sign(spawn_position.x - from.x))

	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(spawn_position, t) + Vector2(0.0, -4.0 * height * t * (1.0 - t)),
		0.0, 1.0, duration)
	await tween.finished
	_bouncing = false
	_used_double_jump = false
	_invulnerable_time = 0.5

func is_bouncing() -> bool:
	return _bouncing

# ---------------------------------------------------------------- ending

## Makes the knight walk to `x` on their own (used when entering the castle).
func walk_to(x: float) -> void:
	_auto_walk = true
	_auto_walk_x = x
	_attack_time = 0.0

# ---------------------------------------------------------------- sword

func _build_sword() -> void:
	_sword_pivot = Node2D.new()
	_sword_pivot.name = "Sword"
	_sword_pivot.position = Vector2(0, -11)
	_sword_pivot.visible = false
	var blade := Sprite2D.new()
	blade.texture = SWORD_TEXTURE
	blade.position = Vector2(0, -9)
	_sword_pivot.add_child(blade)
	add_child(_sword_pivot)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 26)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_sword_area = Area2D.new()
	_sword_area.name = "SwordReach"
	_sword_area.collision_layer = 0
	_sword_area.collision_mask = LAYER_ENEMY
	_sword_area.add_child(collision)
	add_child(_sword_area)

func _update_sword(delta: float) -> void:
	_sword_area.position = Vector2(facing * 15, -13)
	if _attack_time <= 0.0:
		_sword_pivot.visible = false
		return
	_attack_time -= delta
	var progress: float = 1.0 - max(_attack_time, 0.0) / ATTACK_TIME
	_sword_pivot.visible = true
	_sword_pivot.scale.x = facing
	_sword_pivot.rotation = lerp(deg_to_rad(-20.0), deg_to_rad(130.0), progress)
	for body in _sword_area.get_overlapping_bodies():
		if body.has_method("take_hit"):
			body.take_hit()

# ---------------------------------------------------------------- looks / sound

func _update_look() -> void:
	if _dead:
		anim_state = "death"
	elif _bouncing:
		anim_state = "roll"
	elif _hurt_time > 0.0:
		anim_state = "hit"
	else:
		anim_state = ""
	# Blink while invulnerable after a hit.
	var blink := _invulnerable_time > 0.0 and not _dead and int(_invulnerable_time * 16.0) % 2 == 0
	_sprite.modulate.a = 0.35 if blink else 1.0

func _play_sound(sound: String) -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.play_sound(sound)
