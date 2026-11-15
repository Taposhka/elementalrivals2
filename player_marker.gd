extends RefCounted

static func points(center: Vector2, radii: Vector2, start: float = 0.0, sweep: float = TAU) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in range(49):
		var angle := start + sweep * float(index) / 48.0
		polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return polygon

static func draw_marker(canvas: Node2D, position: Vector2, color: Color, local: bool, charged: bool, time: float) -> void:
	var feet := position + Vector2(0, 18)
	canvas.draw_colored_polygon(points(feet, Vector2(21, 8)), Color(0.025, 0.04, 0.06, 0.55))
	canvas.draw_polyline(points(feet, Vector2(21, 8)), Color(color, 0.95), 2.0, true)
	if local:
		canvas.draw_polyline(points(feet, Vector2(24, 10)), Color(0.95, 0.98, 1.0, 0.75), 1.0, true)
	if charged:
		for index in range(3):
			canvas.draw_polyline(points(feet, Vector2(27, 12), time * 1.8 + index * TAU / 3, 1.15), Color("#ffe7a2"), 2.0, true)
