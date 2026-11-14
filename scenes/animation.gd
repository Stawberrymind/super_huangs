extends AnimatedSprite2D

func _process(_delta: float) -> void:
	var player = get_parent()

	# Flip sprite based on movement direction
	if player.velocity.x < 0:
		flip_h = true
	elif player.velocity.x > 0:
		flip_h = false

	# Handle animations
	if not player.is_on_floor():
		play("jump")
	elif abs(player.velocity.x) > 0:
		play("run")
	else:
		play("idle")
