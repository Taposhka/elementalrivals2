extends Control

func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var phase := Time.get_ticks_msec() / 650.0
	draw_arc(size / 2, 18, 0, TAU, 48, Color("#253742"), 2, true)
	draw_arc(size / 2, 18, phase, phase + PI * 1.2, 32, Color("#b7d9e7"), 2, true)
