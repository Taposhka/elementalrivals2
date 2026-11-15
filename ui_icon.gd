extends Button
const ELEMENT_ART = preload("res://element_art.gd")

var glyph: String = "pause"
var accent := Color("#e4e9ee")

func _init() -> void:
	text = ""
	custom_minimum_size = Vector2(64, 64)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#17232d") if state == "normal" else Color("#263845")
		style.set_corner_radius_all(16)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("#b9d7df")
			style.set_border_width_all(2)
		add_theme_stylebox_override(state, style)

func _draw() -> void:
	draw_set_transform(size / 2, 0.0, Vector2.ONE * minf(size.x, size.y) / 64.0)
	var p := Vector2.ZERO
	var color := accent if not disabled else Color("#51606b")
	var element_index: int = ["fire", "water", "ice"].find(glyph)
	if element_index >= 0:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect(ELEMENT_ART.texture_for(element_index), Rect2(Vector2(-19,-19),Vector2(38,38)), false, Color.WHITE if not disabled else Color(0.5,0.5,0.5))
		draw_set_transform(Vector2.ZERO)
		return
	match glyph:
		"pause":
			draw_line(p + Vector2(-5, -8), p + Vector2(-5, 8), color, 3, true)
			draw_line(p + Vector2(5, -8), p + Vector2(5, 8), color, 3, true)
		"close":
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), color, 2, true)
			draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), color, 2, true)
		"back":
			draw_polyline(PackedVector2Array([p + Vector2(4, -9), p + Vector2(-5, 0), p + Vector2(4, 9)]), color, 2, true)
		"settings":
			for index in range(3):
				var y := -8.0 + index * 8
				draw_line(p + Vector2(-11, y), p + Vector2(11, y), color, 2, true)
				draw_circle(p + Vector2(-4 if index % 2 == 0 else 5, y), 3.5, Color("#17232d"))
				draw_arc(p + Vector2(-4 if index % 2 == 0 else 5, y), 3.5, 0, TAU, 16, color, 2, true)
		"fusion":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, 0), p + Vector2(0, 12), p + Vector2(-9, 0)]), color)
		"fire":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(10, 3), p + Vector2(6, 12), p + Vector2(-6, 12), p + Vector2(-10, 3), p + Vector2(-4, -6), p + Vector2(-3, 2)]), color)
		"water":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(9, 2), p + Vector2(7, 10), p + Vector2(0, 13), p + Vector2(-7, 10), p + Vector2(-9, 2)]), color)
		"ice":
			for index in range(3):
				var d := Vector2.from_angle(index * PI / 3) * 12
				draw_line(p - d, p + d, color, 2, true)
		"thunder":
			draw_colored_polygon(PackedVector2Array([p + Vector2(2, -14), p + Vector2(-9, 3), p + Vector2(-1, 3), p + Vector2(-3, 14), p + Vector2(10, -4), p + Vector2(2, -4)]), color)
		"wind":
			for index in range(3):
				var y := -7 + index * 7
				draw_line(p + Vector2(-11 + index * 3, y), p + Vector2(7, y), color, 2, true)
				draw_arc(p + Vector2(7, y - 3), 3, -PI / 2, PI / 2, 12, color, 2, true)
	draw_set_transform(Vector2.ZERO)
