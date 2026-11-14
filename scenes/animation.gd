extends AnimatedSprite2D

func _process(_delta: float) -> void:
	var player = get_parent()

	# The body can force an animation (the knight does this for "hit", "death" and "roll").
	var forced = player.get("anim_state")
	if forced is String and forced != "" and sprite_frames.has_animation(forced):
		var facing = player.get("facing")
		if facing is int and forced != "hit":
			flip_h = facing < 0
		if animation != forced:
			play(forced)
		return

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
