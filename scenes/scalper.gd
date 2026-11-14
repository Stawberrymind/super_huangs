extends CharacterBody2D

# Scalper: a robber duck (striped beanie, eye mask, striped shirt) that
# steals RTX 5090s.
#  - Walks around; when the knight comes close it runs at him.
#  - Touching it steals one RTX 5090 (or costs a heart if you have none),
#    then it runs away with its loot held over its head.
#  - Jump on its head or hit it with the sword: it drops everything it stole.

const COIN_SCENE = preload("res://scenes/coin.tscn")
const GPU = preload("res://assets/sprites/rtx5090.png")
const WALK_SPEED = 30.0
const CHASE_SPEED = 75.0
const FLEE_SPEED = 115.0
const LAYER_WORLD = 1
const LAYER_ENEMY = 4

## How far (in pixels) it walks to each side of where it starts.
@export var patrol_distance := 40.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var stolen := 0
var _direction := -1
var _start_x := 0.0
var _start_position := Vector2.ZERO
var _dead := false
var _flee_time := 0.0
var _steal_cooldown := 0.0
var _hint_cooldown := 0.0
var _bob := 0.0

var _loot: Sprite2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurt_area: Area2D = $Hurt
@onready var _floor_check: RayCast2D = $FloorCheck

func _ready() -> void:
	add_to_group("enemies")
	_start_x = global_position.x
	_start_position = global_position
	collision_mask = LAYER_WORLD
	collision_layer = LAYER_ENEMY
	_sprite.play("walk")

	# The stolen RTX 5090, held up while running away.
	var icon := AtlasTexture.new()
	icon.atlas = GPU
	icon.region = Rect2(0, 0, 16, 16)
	_loot = Sprite2D.new()
	_loot.texture = icon
	_loot.position = Vector2(0, -24)
	_loot.visible = false
	add_child(_loot)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_flee_time -= delta
	_steal_cooldown -= delta
	_hint_cooldown -= delta
	if not is_on_floor():
		velocity.y += gravity * delta

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var speed := WALK_SPEED
	if _flee_time > 0.0 and player:
		_direction = 1 if player.global_position.x < global_position.x else -1
		speed = FLEE_SPEED
	elif player and abs(player.global_position.x - global_position.x) < 110.0 \
			and abs(player.global_position.y - global_position.y) < 32.0:
		_direction = -1 if player.global_position.x < global_position.x else 1
		speed = CHASE_SPEED
	else:
		_patrol()
	if _at_ledge_or_wall():
		if _flee_time > 0.0 or speed == CHASE_SPEED:
			speed = 0.0    # don't run off the edge
		else:
			_direction = -_direction
	velocity.x = _direction * speed

	_sprite.flip_h = _direction > 0
	_sprite.speed_scale = 2.0 if speed > WALK_SPEED else 1.0
	_bob += delta * 10.0
	_loot.visible = stolen > 0
	_loot.position.y = -24.0 + sin(_bob) * 1.5
	move_and_slide()

	var level := get_tree().get_first_node_in_group("level")
	if level and global_position.y > level.kill_y:
		global_position = _start_position   # fell off: back to where it started, loot and all
		velocity = Vector2.ZERO

	for body in _hurt_area.get_overlapping_bodies():
		if body is CharacterBody2D and body.is_in_group("player"):
			_touch(body)
			return

func _touch(player: CharacterBody2D) -> void:
	var level := get_tree().get_first_node_in_group("level")
	# Landing on its head knocks it out.
	if player.velocity.y > 0.0 and player.global_position.y < global_position.y - 8.0:
		player.velocity.y = -230.0
		take_hit()
		return
	if _steal_cooldown > 0.0:
		return
	_steal_cooldown = 1.0
	if level and level.steal_coin():
		stolen += 1
		_flee_time = 2.2
		level.play_sound("hurt", 1.3)
		level.shake(2.5, 0.15)
		level.spawn_puff(global_position + Vector2(0, -20), Color(0.75, 1.0, 0.4), 8, 50.0)
		if _hint_cooldown <= 0.0:
			_hint_cooldown = 5.0
			level.show_message("A scalper stole an RTX 5090! Jump on him to get it back")
	else:
		player.hurt(global_position.x)

func _patrol() -> void:
	var offset := global_position.x - _start_x
	if abs(offset) > patrol_distance:
		_direction = -1 if offset > 0.0 else 1

func _at_ledge_or_wall() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall() and sign(get_wall_normal().x) == -_direction:
		return true
	_floor_check.position.x = _direction * 8.0
	_floor_check.force_raycast_update()
	return not _floor_check.is_colliding()

## Called by the knight's sword (and when stomped).
func take_hit() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	_hurt_area.set_deferred("monitoring", false)
	_loot.visible = false
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.play_sound("explosion")
		level.spawn_puff(global_position + Vector2(0, -8), Color(1, 1, 1), 10, 80.0, 0.5)
		level.spawn_puff(global_position + Vector2(0, -12), Color(0.8, 0.17, 0.2), 6, 60.0, 0.4)
		level.shake(3.0, 0.15)
		level.hit_stop(0.07)
	_drop_loot()
	_sprite.stop()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "rotation", PI, 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

func _drop_loot() -> void:
	for i in stolen:
		var coin := COIN_SCENE.instantiate() as Node2D
		var target := global_position + Vector2((i - (stolen - 1) / 2.0) * 14.0, -14.0)
		get_parent().add_child(coin)
		coin.global_position = global_position + Vector2(0, -16)
		var tween := coin.create_tween()
		tween.tween_property(coin, "global_position", target + Vector2(0, -12), 0.18).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "global_position", target, 0.2).set_ease(Tween.EASE_IN)
	stolen = 0
