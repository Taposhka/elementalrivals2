extends RefCounted

static func draw_floods(canvas: Node2D, arena) -> void:
	if arena.get("floods") == null: return
	for flood in arena.floods:
		if flood.life <= 0: continue
		var pos: Vector2 = flood.pos
		var radius: float = flood.radius
		var fade := minf(1.0, float(flood.life) / 0.5)
		var faction: Color = arena.BLUE if flood.team == 0 else arena.ORANGE
		canvas.draw_circle(pos, radius, Color(0.07, 0.38, 0.73, 0.14 * fade))
		canvas.draw_arc(pos, radius, 0, TAU, 48, Color(faction, 0.5 * fade), 1.5, true)
		for ring in range(1):
			var wave := fmod(float(flood.age) * 0.6 + ring * 0.33, 1.0)
			canvas.draw_arc(pos, radius * wave, 0, TAU, 40, Color(0.45, 0.84, 1.0, (1.0 - wave) * 0.5 * fade), 1.5, true)

static func draw_attacks(canvas: Node2D, arena) -> void:
	if arena.get("combat_visuals") == null: return
	for fx in arena.combat_visuals:
		if fx.life <= 0: continue
		var progress: float = 1.0 - float(fx.life) / float(fx.max_life)
		if fx.kind == "dash":
			canvas.draw_line(fx.pos, fx.end, Color(1.0, 0.32, 0.08, 0.22 * (1.0 - progress)), 12, true)
			canvas.draw_line(fx.pos, fx.end, Color(1.0, 0.75, 0.35, 0.85 * (1.0 - progress)), 3, true)
			continue
		var color: Color = arena.ELEMENT_COLORS[int(fx.element)]
		var pos: Vector2 = fx.pos
		var direction: Vector2 = fx.dir
		var angle: float = fx.angle
		var radius: float = fx.radius
		var start := direction.angle() - angle
		var shape := PackedVector2Array([pos])
		for index in range(25):
			shape.append(pos + Vector2.from_angle(start + 2.0 * angle * index / 24.0) * radius)
		canvas.draw_line(pos + direction * 15, pos + direction * radius * 0.8, Color(color, 0.3 * (1.0 - progress)), 2, true)
		for ring in range(1):
			var reach := radius * clampf(progress + 0.15 + ring * 0.15, 0.1, 1.0)
			canvas.draw_arc(pos, reach, start, start + angle * 2, 32, Color(color, (1.0 - progress) * (0.9 - ring * 0.2)), 4.0 - ring, true)
