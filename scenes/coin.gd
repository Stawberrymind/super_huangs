extends Area2D

# An RTX 5090 to collect.

var _time := 0.0
var _base_y := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("coins")
	_base_y = _sprite.position.y
	_time = randf() * TAU
	_sprite.play("spin")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta * 3.0
	_sprite.position.y = _base_y + sin(_time) * 1.5

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.collect_coin()
	queue_free()
