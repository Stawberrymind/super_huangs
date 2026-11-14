extends Node

# Autoload: press F anywhere (or use the menu button) to toggle fullscreen.
# The project uses stretch mode "canvas_items" with aspect "keep", so going
# fullscreen just makes the same view bigger: same aspect ratio (black bars
# if the screen's shape differs), you don't see more of the level, and
# everything is redrawn at the higher resolution, so nothing gets blurry.

signal changed(is_fullscreen: bool)

func _input(event: InputEvent) -> void:
	# Browsers only allow fullscreen from inside a key or click event, so
	# this toggles right here in the input handler.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		toggle()
		get_viewport().set_input_as_handled()

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func toggle() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	changed.emit(is_fullscreen())
