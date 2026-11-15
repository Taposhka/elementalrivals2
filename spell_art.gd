extends RefCounted
const THUNDERFLAME = preload("res://thunderflame_art.gd")
const FLAME_TORNADO = preload("res://flame_tornado_art.gd")
const CRYSTAL_VOLCANO = preload("res://crystal_volcano_art.gd")

static func opacity(zone: Dictionary) -> float:
	return clampf((float(zone.duration) + float(zone.warning) - float(zone.age)) / 0.55, 0, 1)

static func draw_ground(canvas: Node2D, arena) -> void:
	for zone in arena.zones:
		var p: Vector2 = zone.pos
		var r: float = zone.radius
		var t: float = zone.age
		var fade := opacity(zone)
		if arena.get("options") != null and arena.options.reduced_flashes:
			fade *= 0.55
		var faction: Color = arena.BLUE if zone.team == 0 else arena.ORANGE
		if zone.key == "0:3":
			var d: Vector2 = zone.dir
			var side := d.orthogonal()*36
			canvas.draw_colored_polygon(PackedVector2Array([p-d*r-side,p+d*r-side,p+d*r+side,p-d*r+side]),Color(faction,0.12*fade))
			canvas.draw_line(p-d*r-side,p+d*r-side,Color(faction,0.6*fade),2,true)
			canvas.draw_line(p-d*r+side,p+d*r+side,Color(faction,0.6*fade),2,true)
			continue
		if zone.key in ["1:1", "1:2"]:
			var d: Vector2 = zone.dir
			var side := d.orthogonal()
			canvas.draw_colored_polygon(PackedVector2Array([p + d * 48 + side * r, p + d * 48 - side * r, p - d * 48 - side * r, p - d * 48 + side * r]), Color(faction, 0.09 * fade))
		else:
			canvas.draw_circle(p, r, Color(faction, 0.065 * fade))
			for i in range(12):
				var angle := float(i) * TAU / 12
				canvas.draw_arc(p, r, angle, angle + 0.32, 6, Color(faction, 0.55 * fade), 2, true)
		if t < zone.warning:
			canvas.draw_arc(p, r * clampf(t / zone.warning, 0.02, 1), 0, TAU, 64, Color(faction, 0.7), 2, true)
			continue
		var key: String = zone.key
		if key in ["2:2", "2:3", "2:4"]:
			canvas.draw_circle(p, r * 0.94, Color(0.55, 0.86, 0.96, 0.14 * fade))
			for i in range(8):
				var d := Vector2.from_angle(i * TAU / 8)
				canvas.draw_line(p + d * 20, p + d * r * 0.86, Color(0.75, 0.93, 1, 0.3 * fade), 1, true)
		elif key in ["1:3", "1:4", "0:1"]:
			canvas.draw_circle(p, r * 0.94, Color(0.13, 0.55, 0.92, 0.2 * fade))
			for i in range(3):
				canvas.draw_arc(p, r * fmod(t * 0.35 + i * 0.33, 1), 0, TAU, 48, Color(0.5, 0.85, 1, 0.3 * fade), 2, true)
		elif key in ["0:0", "0:2", "0:3", "0:4"]:
			canvas.draw_circle(p, r * 0.94, Color(0.7, 0.15, 0.03, 0.14 * fade))
			for i in range(9):
				var d := Vector2.from_angle(i * TAU / 9 + 0.2)
				canvas.draw_polyline(PackedVector2Array([p + d * 15, p + d * r * 0.35 + d.orthogonal() * 20, p + d * r * 0.72, p + d * r * 0.9 - d.orthogonal() * 14]), Color(1, 0.38, 0.08, 0.35 * fade), 2, true)
		elif key in ["3:3", "3:4"]:
			canvas.draw_circle(p, r * 0.94, Color(0.14, 0.16, 0.22, 0.24 * fade))

static func draw_foreground(canvas: Node2D, arena) -> void:
	for zone in arena.zones:
		var t: float = zone.age - zone.warning
		if t < 0:
			continue
		var p: Vector2 = zone.pos
		var r: float = zone.radius
		var fade := opacity(zone)
		if arena.get("options") != null and arena.options.reduced_flashes:
			fade *= 0.55
		var key: String = zone.key
		var detail: bool = arena.get("options") == null or arena.options.quality == 1
		match key:
			"3:4":

				cloud(canvas, p + Vector2(0, -48), r, t, Color(0.43, 0.46, 0.5, 0.38 * fade))
				for i in range(18 if detail else 9):
					var x := sin(i * 13.1 + 0.5) * r * 0.88
					var y := fmod(t * 170 + i * 19, 110.0) - 50
					canvas.draw_line(p + Vector2(x, y), p + Vector2(x - 5, y + 13), Color(0.75, 0.8, 0.88, 0.27 * fade), 1, true)
				for i in range(5):
					if fmod(t * 2.1 + i * 0.27, 1) < 0.22 or zone.pulse > 0.18:
						var end := p + Vector2(sin(i * 8.3 + floorf(t * 2)) * r * 0.78, cos(i * 5.1) * r * 0.45)
						bolt(canvas, end - Vector2(15, 110), end, t + i, Color(0.8, 0.72, 1, fade))
			"0:0":
				for i in range(36 if detail else 18):
					var a := i * 2.399
					var distance := sqrt(float(i) / 36) * r * 0.9
					var pos := p + Vector2.from_angle(a) * distance
					var height := 22 + 22 * (sin(t * 7 + i * 2) * 0.5 + 0.5)
					flame(canvas, pos, height, fade)
				canvas.draw_arc(p, r * 0.9, 0, TAU, 64, Color(1, 0.35, 0.04, 0.5 * fade), 4, true)
			"0:1":
				for i in range(7):
					var base := p + Vector2.from_angle(i * TAU / 7) * r * 0.5
					var height := 50 + 30 * sin(t * 3 + i)
					canvas.draw_line(base, base - Vector2(0, height), Color(0.65, 0.85, 0.94, 0.3 * fade), 20, true)
					cloud(canvas, base - Vector2(0, height), 40, t + i, Color(0.86, 0.9, 0.91, 0.17 * fade))
			"0:2":
				CRYSTAL_VOLCANO.draw(canvas,p,r,t,fade)
			"0:3":
				var cycle := fmod(t,float(zone.interval))
				for i in range(7):
					var point := p+Vector2(zone.dir)*r*(float(i)/6.0*1.8-0.9)
					THUNDERFLAME.draw(canvas,point,46,cycle,fade)
					if cycle < 0.18:
						bolt(canvas,point-Vector2(0,320),point,float(i)+floorf(t/zone.interval),Color(1,0.88,0.4,fade*(1-cycle/0.18)))
			"1:1":
				var dir: Vector2 = zone.dir
				var side := dir.orthogonal()
				var crest := PackedVector2Array()
				for i in range(33):
					var offset := (float(i) / 32 * 2 - 1) * r
					crest.append(p + side * offset + dir * (sin(offset * 0.045 + t * 5) * 9 + 28))
				var water := crest.duplicate()
				water.append(p + side * r - dir * 48)
				water.append(p - side * r - dir * 48)
				canvas.draw_colored_polygon(water, Color(0.14, 0.55, 0.94, 0.48 * fade))
				canvas.draw_polyline(crest, Color(0.78, 0.97, 1, 0.92 * fade), 7, true)
				for i in range(16):
					var pos := p + side * (i / 15.0 * 2 - 1) * r - dir * fmod(t * 30 + i * 7, 48)
					canvas.draw_arc(pos, 6, t + i, t + i + PI, 10, Color(0.85, 0.97, 1, 0.65 * fade), 2, true)
			"1:2":
				var side := Vector2(zone.dir).orthogonal()
				var crest := PackedVector2Array()
				for i in range(33):
					var offset := (i / 32.0 * 2 - 1) * r
					crest.append(p + side * offset + Vector2(zone.dir) * (28 + sin(offset * 0.06 + t * 4) * 9))
				var body := crest.duplicate()
				body.append(p + side * r - Vector2(zone.dir) * 48)
				body.append(p - side * r - Vector2(zone.dir) * 48)
				canvas.draw_colored_polygon(body, Color(0.3, 0.7, 0.92, 0.4 * fade))
				canvas.draw_polyline(crest, Color(0.75, 0.98, 1, 0.9 * fade), 6, true)
				for i in range(13):
					var base := p + side * (i / 12.0 * 2 - 1) * r * 0.94
					crystal(canvas, base, Vector2(0, -1), 30 + sin(i * 3.1 + t) * 10, Color(0.65, 0.92, 1, 0.9 * fade))
			"1:3":
				for i in range(9):
					var a := i * 2.399 + floorf(t * 3) * 0.4
					var start := p + Vector2.from_angle(a) * r * 0.3
					var end := p + Vector2.from_angle(a + 1.2) * r * 0.85
					bolt(canvas, start, end, i + t, Color(0.5, 0.85, 1, 0.65 * fade))
				canvas.draw_arc(p, r * 0.91, 0, TAU, 64, Color(0.34, 0.65, 1, 0.8 * fade), 3, true)
			"2:2":
				snow(canvas, p, r, t, fade, false)
				cloud(canvas, p - Vector2(0, 30), r * 0.7, t, Color(0.76, 0.88, 0.94, 0.12 * fade))
			"2:3":
				for i in range(22 if detail else 11):
					var d := Vector2.from_angle(i * 2.399 + t * 0.5)
					var pos := p + d * sqrt(float(i + 1) / 23) * r * 0.9
					crystal(canvas, pos - Vector2(0, fmod(t * 70 + i * 11, 65)), d, 11, Color(0.8, 0.75, 1, 0.9 * fade))
					if i % 4 == 0:
						bolt(canvas, pos - Vector2(0, 55), pos, i + t, Color(0.84, 0.74, 1, 0.65 * fade))
			"3:3":
				for i in range(7):
					var end := p + Vector2.from_angle(i * TAU / 7 + floorf(t * 2) * 0.4) * r * 0.7
					canvas.draw_arc(end, 19, 0, TAU, 24, Color(0.72, 0.5, 1, 0.4 * fade), 2, true)
					if fmod(t * 2 + i * 0.2, 1) < 0.35 or zone.pulse > 0.15:
						bolt(canvas, end - Vector2(10, 145), end, i + t, Color(0.87, 0.77, 1, fade))
			"0:4":
				FLAME_TORNADO.draw(canvas,p,r,t,fade)
			"1:4", "2:4", "4:4":
				var color := Color(0.78, 0.88, 0.87, 0.5 * fade)
				if key == "1:4": color = Color(0.25, 0.7, 0.98, 0.6 * fade)
				elif key == "2:4": color = Color(0.78, 0.94, 1, 0.5 * fade)
				vortex(canvas, p, r, t, color)
				if key == "2:4":
					snow(canvas, p, r, t, fade, true)
				elif key == "1:4":
					for i in range(12):
						var pos := p + Vector2.from_angle(t * 3 + i) * r * 0.65
						canvas.draw_circle(pos - Vector2(0, fmod(i * 19 + t * 35, 95)), 4, Color(0.65, 0.92, 1, 0.65 * fade))

static func cloud(canvas: Node2D, p: Vector2, radius: float, t: float, color: Color) -> void:
	for i in range(13):
		var x := (i / 12.0 * 2 - 1) * radius * 0.78
		var y := sin(i * 2.2 + t * 0.7) * radius * 0.13
		var size := radius * (0.17 + 0.05 * sin(i * 3.3 + t))
		canvas.draw_circle(p + Vector2(x, y), size, color)
		canvas.draw_circle(p + Vector2(x + 6, y - size * 0.38), size * 0.7, Color(color.lightened(0.22), color.a * 0.7))

static func bolt(canvas: Node2D, start: Vector2, end: Vector2, phase: float, color: Color) -> void:
	var points := PackedVector2Array([start])
	var side := (end - start).normalized().orthogonal()
	for i in range(1, 6):
		points.append(start.lerp(end, i / 6.0) + side * sin(i * 8.1 + floorf(phase * 9)) * 11)
	points.append(end)
	canvas.draw_polyline(points, Color(color, color.a * 0.18), 9, true)
	canvas.draw_polyline(points, color, 3, true)
	canvas.draw_polyline(points, Color(1, 1, 1, color.a * 0.85), 1, true)

static func flame(canvas: Node2D, p: Vector2, height: float, fade: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-5, -height * 0.5), p + Vector2(3, -height), p + Vector2(10, -height * 0.24), p + Vector2(8, 0)]), Color(1, 0.31, 0.05, 0.55 * fade))
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 0), p + Vector2(2, -height * 0.6), p + Vector2(5, 0)]), Color(1, 0.82, 0.3, 0.72 * fade))

static func crystal(canvas: Node2D, p: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var side := direction.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([p + direction * size, p + side * size * 0.34, p - direction * size * 0.5, p - side * size * 0.34]), color)
	canvas.draw_line(p - direction * size * 0.4, p + direction * size, Color(1, 1, 1, color.a * 0.7), 1, true)

static func vortex(canvas: Node2D, p: Vector2, radius: float, t: float, color: Color) -> void:
	for layer in range(10):
		var ring := PackedVector2Array()
		var width := radius * (0.15 + layer * 0.065)
		for i in range(33):
			var angle := i / 32.0 * TAU + t * (2.8 + layer * 0.07)
			ring.append(p + Vector2(cos(angle) * width, sin(angle) * width * 0.26 - layer * 11))
		canvas.draw_polyline(ring, Color(color, color.a * (0.4 + layer * 0.06)), 3 + layer * 0.25, true)
	for i in range(3):
		canvas.draw_arc(p, radius * (0.55 + i * 0.16), t * 2 + i * 2, t * 2 + i * 2 + 3, 32, Color(color, color.a * 0.5), 2, true)

static func snow(canvas: Node2D, p: Vector2, radius: float, t: float, fade: float, spiral: bool) -> void:
	for i in range(48):
		var pos: Vector2
		if spiral:
			pos = p + Vector2.from_angle(i * 2.399 + t * 1.4) * radius * sqrt(float(i + 1) / 50)
		else:
			pos = p + Vector2(sin(i * 31.7) * radius * 0.85, fmod(i * 17 + t * 80, radius * 1.7) - radius * 0.85)
		canvas.draw_line(pos - Vector2(3, 0), pos + Vector2(3, 0), Color(0.9, 0.98, 1, 0.75 * fade), 1, true)
		canvas.draw_line(pos - Vector2(0, 3), pos + Vector2(0, 3), Color(0.9, 0.98, 1, 0.75 * fade), 1, true)
