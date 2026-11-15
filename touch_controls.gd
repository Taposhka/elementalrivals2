extends Control

var arena
var move_finger: int = -1
var aim_finger: int = -1
var move_vector := Vector2.ZERO
var aim_vector := Vector2.RIGHT
var firing: bool = false
var move_origin := Vector2.ZERO
var aim_origin := Vector2.ZERO
var move_tip := Vector2.ZERO
var aim_tip := Vector2.ZERO
var stick_radius: float = 68.0
var last_active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset_touches() -> void:
	move_finger = -1
	aim_finger = -1
	move_vector = Vector2.ZERO
	firing = false
	queue_redraw()

func active() -> bool:
	return arena.state == "offline" and arena.touch_enabled() and not is_instance_valid(arena.overlay_panel)

func local_player():
	for player in arena.players:
		if player.human_index == 0: return player
	return null

func ultimate_center() -> Vector2:
	var safe: Rect2 = arena.safe_bounds()
	return Vector2(safe.end.x - 90, safe.end.y - 235)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and arena.touch_override == 0: arena.touch_used = true
	if not active():
		if move_finger >= 0 or aim_finger >= 0: reset_touches()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.distance_to(ultimate_center()) < 48:
				var player = local_player()
				if player != null: arena.cast_ultimate(player)
				get_viewport().set_input_as_handled()
				return
			if event.position.y < 105: return
			if event.position.x < size.x * 0.48 and move_finger == -1:
				move_finger = event.index
				move_origin = event.position
				move_tip = event.position
			elif event.position.x >= size.x * 0.48 and aim_finger == -1:
				aim_finger = event.index
				aim_origin = event.position
				aim_tip = event.position
				var player = local_player()
				if player != null:
					var target = arena.nearest_enemy(player)
					if target != null: aim_vector = (target.position - player.position).normalized()
				firing = true
		else:
			var owned: bool = event.index == move_finger or event.index == aim_finger
			if event.index == move_finger:
				move_finger = -1
				move_vector = Vector2.ZERO
			if event.index == aim_finger:
				aim_finger = -1
				firing = false
			if not owned: return
		if event.index == move_finger or event.index == aim_finger or not event.pressed:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			move_tip = move_origin + (event.position - move_origin).limit_length(stick_radius)
			move_vector = (move_tip - move_origin) / stick_radius
			if move_vector.length() < 0.12: move_vector = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif event.index == aim_finger:
			aim_tip = aim_origin + (event.position - aim_origin).limit_length(stick_radius)
			var direction: Vector2 = aim_tip - aim_origin
			if direction.length() > 8: aim_vector = direction.normalized()
			firing = true
			get_viewport().set_input_as_handled()
	queue_redraw()

func _process(_delta: float) -> void:
	visible = active()
	if visible != last_active:
		last_active = visible
		arena.schedule_layout()
	if visible: queue_redraw()

func _draw() -> void:
	if not active(): return
	var safe: Rect2 = arena.safe_bounds()
	var left := move_origin if move_finger >= 0 else Vector2(safe.position.x + 110, safe.end.y - 105)
	var right := aim_origin if aim_finger >= 0 else Vector2(safe.end.x - 110, safe.end.y - 105)
	for center in [left, right]:
		draw_circle(center, stick_radius, Color(0.04, 0.08, 0.12, 0.25))
		draw_arc(center, stick_radius, 0, TAU, 48, Color(0.8, 0.9, 0.95, 0.2), 2, true)
	draw_circle(move_tip if move_finger >= 0 else left, 25, Color(0.75, 0.86, 0.92, 0.4))
	draw_circle(aim_tip if aim_finger >= 0 else right, 25, Color(0.96, 0.7, 0.58, 0.5))
	var player = local_player()
	var ready: bool = player != null and arena.squad and arena.fusion[player.team].ready and (arena.practice or arena.elapsed >= arena.team_ult_next[player.team])
	var center := ultimate_center()
	var color := Color("#e7cb81") if ready else Color("#60717e")
	draw_circle(center, 48, Color(0.04, 0.08, 0.12, 0.65))
	draw_arc(center, 48, 0, TAU, 40, Color(color, 0.8), 2, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -20), center + Vector2(14, 0), center + Vector2(0, 20), center + Vector2(-14, 0)]), color)
