extends Camera2D

@export var target: CharacterBody2D
@export var follow_speed: float = 8.0

func _ready() -> void:
	target = get_node("../Player") as CharacterBody2D
	make_current()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var weight = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(
		target.global_position,
		weight
	)
