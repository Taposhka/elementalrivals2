extends Node2D
var arena
var viewer
var view
const MAP := Rect2(14, 32, 160, 90)

func _process(_delta: float) -> void:
	queue_redraw()

func map_pos(world: Vector2) -> Vector2:
	return MAP.position + world / Vector2(1920, 1080) * MAP.size

func _draw() -> void:
	if not is_instance_valid(viewer):
		return
	var font := ThemeDB.fallback_font
	draw_style_box(panel(), Rect2(8, 8, 172, 139))
	draw_string(font, Vector2(16, 24), "P%d · ЛИЧНАЯ КАМЕРА" % (viewer.human_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_texture_rect(arena.MAP_TEXTURE, MAP, false, Color(0.55, 0.65, 0.58))
	var center: Vector2 = view.camera.get_screen_center_position()
	var viewport_size: Vector2 = view.container.size
	var a := map_pos(center - viewport_size / 2)
	var b := map_pos(center + viewport_size / 2)
	draw_rect(Rect2(a, b - a).intersection(MAP), Color(1, 1, 1, 0.5), false, 1)
	var flag_color: Color = Color("#e2d29c") if arena.flag_owner < 0 else (arena.BLUE if arena.flag_owner == 0 else arena.ORANGE)
	draw_circle(map_pos(arena.FLAG_POSITION), 5, flag_color)
	for player in arena.players:
		if player.is_dead:
			continue
		if player.team == viewer.team:
			draw_circle(map_pos(player.position), 3, arena.BLUE if viewer.team == 0 else arena.ORANGE)
			if player == viewer:
				draw_arc(map_pos(player.position), 5, 0, TAU, 18, Color.WHITE, 1, true)
		elif arena.is_revealed(player, viewer.team):
			draw_circle(map_pos(player.position), 4, Color("#ff6174"))
	draw_string(font, Vector2(16, 138), "ВРАГ: ПОПАДАНИЕ → 2 СЕК", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9baebe"))

func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.11, 0.92)
	style.border_color = Color("#4c6070")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
