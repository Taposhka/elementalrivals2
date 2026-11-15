extends CanvasLayer
var arena

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F11:
		arena.set_option("fullscreen", not arena.options.fullscreen)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE:
		if is_instance_valid(arena.overlay_panel):
			arena.close_overlay()
		elif arena.state == "offline":
			arena.open_overlay("pause")
		else:
			return
		get_viewport().set_input_as_handled()
