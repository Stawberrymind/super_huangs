extends CharacterBody2D

# Scalper: a robber duck (striped beanie, eye mask, striped shirt) that
# steals RTX 5090s.
#  - Walks around; when the knight comes close it runs at him.
#  - Touching it steals one RTX 5090 (or costs a heart if you have none),
#    then it runs away with its loot held over its head.
#  - It has 3 hit points (health bar over its head). Each stomp on its head
#    or sword hit takes one and makes it drop one stolen RTX 5090; the last
#    hit knocks it out and it drops the rest.

const COIN_SCENE = preload("res://scenes/coin.tscn")
const GPU = preload("res://assets/sprites/rtx5090.png")
const WALK_SPEED = 30.0
const CHASE_SPEED = 75.0
const FLEE_SPEED = 115.0
const LAYER_WORLD = 1
const LAYER_ENEMY = 4
const MAX_HEALTH = 3
const HIT_COOLDOWN = 0.4      # one sword swing / one stomp only counts once
const STOMP_BOUNCE = -250.0
const BAR_WIDTH = 16.0

## How far (in pixels) it walks to each side of where it starts.
@export var patrol_distance := 40.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var stolen := 0
var health := MAX_HEALTH
var _hit_cooldown := 0.0
var _direction := -1
var _start_x := 0.0
var _start_position := Vector2.ZERO
var _dead := false
var _flee_time := 0.0
var _steal_cooldown := 0.0
var _hint_cooldown := 0.0
var _bob := 0.0
var _player_feet_before := INF   # the knight's feet last frame, for stomp detection

var _loot: Sprite2D
var _bar: Node2D
var _bar_fill: ColorRect

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
	_loot.position = Vector2(0, -34)
	_loot.visible = false
	add_child(_loot)

	# Health bar above its head.
	_bar = Node2D.new()
	_bar.position = Vector2(-BAR_WIDTH / 2.0 - 1.0, -23)
	_bar.z_index = 5
	var back := ColorRect.new()
	back.color = Color(0.08, 0.08, 0.1)
	back.size = Vector2(BAR_WIDTH + 2.0, 4)
	_bar.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = Vector2(BAR_WIDTH, 2)
	_bar.add_child(_bar_fill)
	add_child(_bar)
	_update_bar()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_flee_time -= delta
	_steal_cooldown -= delta
	_hint_cooldown -= delta
	_hit_cooldown -= delta
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
	_loot.position.y = -34.0 + sin(_bob) * 1.5
	move_and_slide()

	var level := get_tree().get_first_node_in_group("level")
	if level and global_position.y > level.kill_y:
		global_position = _start_position   # fell off: back to where it started, loot and all
		velocity = Vector2.ZERO

	if player and _check_stomp(player):
		return
	for body in _hurt_area.get_overlapping_bodies():
		if body is CharacterBody2D and body.is_in_group("player"):
			_touch(body)
			return

## Stomp = the knight's feet went from above its head to at/below the top of
## its head since last frame, while he was right over it. Done with positions
## rather than the Hurt area: the knight isn't solid to the scalper, so he
## falls through it and lands in 2-3 frames, and the area reports the overlap
## a frame late - by then he is standing on the floor and it looked like a
## plain bump (that was the bug).
func _check_stomp(player: CharacterBody2D) -> bool:
	var feet := player.global_position.y
	var before := _player_feet_before
	_player_feet_before = feet
	var head := global_position.y - 13.0
	var over := absf(player.global_position.x - global_position.x) <= 12.0
	if over and before <= head + 2.0 and feet > before and feet >= head - 2.0:
		player.velocity.y = STOMP_BOUNCE
		_steal_cooldown = 0.6     # don't get robbed while bouncing off
		take_hit()
		return true
	return false

func _touch(player: CharacterBody2D) -> void:
	var level := get_tree().get_first_node_in_group("level")
	if _steal_cooldown > 0.0 or _hit_cooldown > 0.0:
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

## Called by the knight's sword (and when stomped). Takes one hit point.
func take_hit() -> void:
	if _dead or _hit_cooldown > 0.0:
		return
	_hit_cooldown = HIT_COOLDOWN
	health -= 1
	_update_bar()
	if health <= 0:
		_knock_out()
		return
	# Still standing: flash, drop one stolen RTX 5090 and run for it.
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.play_sound("tap", 0.7)
		level.spawn_puff(global_position + Vector2(0, -10), Color(1, 1, 1), 6, 60.0)
		level.shake(2.0, 0.1)
		level.hit_stop(0.04)
	_drop_loot(1)
	_flee_time = 1.2
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	var squash := create_tween()
	_sprite.scale = Vector2(1.4, 0.6)
	squash.tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_bar() -> void:
	var ratio := float(health) / MAX_HEALTH
	_bar_fill.size.x = maxf(BAR_WIDTH * ratio, 0.0)
	_bar_fill.color = Color(0.46, 0.73, 0.0) if ratio > 0.5 else Color(0.95, 0.75, 0.15) if ratio > 0.25 else Color(0.9, 0.2, 0.2)
	_bar.visible = health > 0

func _knock_out() -> void:
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
	_drop_loot(stolen)
	_sprite.stop()
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "rotation", PI, 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

func _drop_loot(count: int) -> void:
	count = mini(count, stolen)
	for i in count:
		var coin := COIN_SCENE.instantiate() as Node2D
		var target := global_position + Vector2((i - (count - 1) / 2.0) * 14.0 - _direction * 16.0, -14.0)
		get_parent().add_child(coin)
		coin.global_position = global_position + Vector2(0, -16)
		var tween := coin.create_tween()
		tween.tween_property(coin, "global_position", target + Vector2(0, -12), 0.18).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "global_position", target, 0.2).set_ease(Tween.EASE_IN)
	stolen -= count
