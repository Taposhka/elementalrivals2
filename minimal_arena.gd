extends "res://rivals_arena.gd"

const ICON = preload("res://ui_icon.gd")
const TOUCH = preload("res://touch_controls.gd")
const GLYPHS := ["fire", "water", "ice", "thunder", "wind"]
var touch_controls: Control
var pause_button: Button
var menu_width: float = 480
var bot_ult_next: Array[float] = [14.0, 18.0]
var team_ult_next: Array[float] = [0.0, 0.0]
var using_gamepad: bool = false
var layout_pending: bool = false
var touch_override: int = 0
var touch_used: bool = false
var input_resume_at: int = 0

func _ready() -> void:
	configure_scale()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK: touch_override = clampi(int(config.get_value("settings", "touch_mode", 0)), 0, 2)
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	touch_controls = Control.new()
	touch_controls.set_script(TOUCH)
	touch_controls.arena = self
	layer.add_child(touch_controls)
	get_viewport().size_changed.connect(schedule_layout)
	get_tree().auto_accept_quit = true
	schedule_layout()
	if mobile_device(): Engine.max_fps = 60

func configure_scale() -> void:
	var size := get_tree().root.size
	var design := Vector2i(720, 1280) if size.y > size.x else Vector2i(1280, 720)
	if get_tree().root.content_scale_size != design:
		get_tree().root.content_scale_size = design

func mobile_device() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

func touch_enabled() -> bool:
	if touch_override != 0: return touch_override == 1
	return mobile_device() or touch_used

func safe_bounds() -> Rect2:
	var bounds := get_viewport_rect()
	if not mobile_device(): return bounds.grow(-20)
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe.size.x <= 0: return bounds.grow(-24)
	var ratio := bounds.size / screen_size
	return Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio).intersection(bounds).grow(-20)

func schedule_layout() -> void:
	if layout_pending: return
	layout_pending = true
	call_deferred("refresh_layout")

func refresh_layout() -> void:
	layout_pending = false
	configure_scale()
	if is_instance_valid(match_ui): layout_match()
	if is_instance_valid(touch_controls):
		touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		touch_controls.queue_redraw()
	for surface in [menu, overlay_panel]:
		if is_instance_valid(surface):
			for scroll in surface.find_children("*", "ScrollContainer", true, false):
				if scroll.get_child_count() > 0: fit_scroll(scroll, scroll.get_child(0))

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("#0c141b"))

func create_menu_card(width: float) -> VBoxContainer:
	clear_menu()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	return menu_content(menu, width)

func menu_content(parent: Control, width: float) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	parent.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = minf(width, get_viewport_rect().size.x - 48)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = minf(width, get_viewport_rect().size.x - 64)
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)
	box.minimum_size_changed.connect(func(): fit_scroll(scroll, box))
	return box

func fit_scroll(scroll: ScrollContainer, box: Control) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(box): return
	scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, get_viewport_rect().size.y - 48)

func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button := super.make_button(parent, text, action)
	button.custom_minimum_size.y = 96 if touch_enabled() else 64
	button.add_theme_font_size_override("font_size", 28 if touch_enabled() else 21)
	button.add_theme_stylebox_override("normal", panel_style(Color("#17232d"), Color.TRANSPARENT, 18, 14))
	button.add_theme_stylebox_override("hover", panel_style(Color("#243641"), Color.TRANSPARENT, 18, 14))
	button.add_theme_stylebox_override("pressed", panel_style(Color("#304653"), Color.TRANSPARENT, 18, 14))
	button.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, Color("#7999a7"), 18, 14))
	return button

func style_field(field: Control) -> void:
	field.add_theme_stylebox_override("normal", panel_style(Color("#17232d"), Color.TRANSPARENT, 14, 12))
	field.add_theme_stylebox_override("hover", panel_style(Color("#243641"), Color.TRANSPARENT, 14, 12))
	field.add_theme_stylebox_override("pressed", panel_style(Color("#304653"), Color.TRANSPARENT, 14, 12))
	field.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, Color("#7999a7"), 14, 12))

func icon_button(parent: Node, glyph: String, action: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.set_script(ICON)
	button.glyph = glyph
	button.custom_minimum_size = Vector2.ONE * (96 if touch_enabled() else 64)
	button.tooltip_text = hint
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func show_main_menu() -> void:
	close_overlay()
	practice = false
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(420)
	var title := make_label(box, "ELEMENT", 42, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := make_button(box, "Играть", func(): show_mode_menu(false))
	if not touch_enabled(): play.call_deferred("grab_focus")
	if not mobile_device(): make_button(box, "Вдвоём", func(): show_mode_menu(true))
	make_button(box, "Онлайн", show_online_menu)
	var row := CenterContainer.new()
	box.add_child(row)
	icon_button(row, "settings", func(): open_overlay("settings"), "Настройки")

func show_mode_menu(two_players: bool) -> void:
	var box := create_menu_card(600 if touch_enabled() else 480)
	icon_button(box, "back", show_main_menu, "Назад").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_element_choices(box, true)
	make_button(box, "Дуэль", func(): start_offline("duel_local" if two_players else "duel_bot"))
	make_button(box, "Команда", func(): start_offline("squad_coop" if two_players else "squad_bot"))
	if not two_players:
		make_button(box, "Тренировка", start_practice)

func add_element_choices(box: VBoxContainer, two: bool) -> void:
	for slot in range(2 if two else 1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		for element in range(5):
			var button := icon_button(row, GLYPHS[element], func():
				selected_elements[slot] = element
				for child in row.get_children():
					child.button_pressed = child.get_index() == element
			, ELEMENT_NAMES[element])
			button.toggle_mode = true
			button.button_pressed = selected_elements[slot] == element
			button.accent = ELEMENT_COLORS[element]
			button.custom_minimum_size = Vector2.ONE * (96 if touch_enabled() else 72)
			button.add_theme_stylebox_override("pressed", panel_style(Color("#314755"), ELEMENT_COLORS[element], 10, 16))

func show_online_menu(message: String = "") -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(600 if touch_enabled() else 480)
	icon_button(box, "back", show_main_menu, "Назад").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_element_choices(box, false)
	var row := HBoxContainer.new()
	box.add_child(row)
	address_field = LineEdit.new()
	style_field(address_field)
	address_field.placeholder_text = "IP"
	address_field.text = "127.0.0.1"
	address_field.custom_minimum_size.y = 96 if touch_enabled() else 64
	address_field.add_theme_font_size_override("font_size", 28 if touch_enabled() else 21)
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(address_field)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = DEFAULT_PORT
	port_field.custom_minimum_size = Vector2(140, 96 if touch_enabled() else 64)
	port_field.get_line_edit().add_theme_font_size_override("font_size", 28 if touch_enabled() else 21)
	row.add_child(port_field)
	host_button = make_button(box, "Создать", func(): start_host(int(port_field.value)))
	join_button = make_button(box, "Подключиться", func(): start_join(address_field.text, int(port_field.value)))
	start_online_button = make_button(box, "Начать", start_online_round)
	start_online_button.disabled = true
	status_label = make_label(box, message, 18, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 460

func update_lobby() -> void:
	var address := ""
	for ip in IP.get_local_addresses():
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			address = ip
			break
	var message := "%d / 4  ·  %s:%d" % [roster.size(), address, lobby_port]
	if is_instance_valid(status_label): status_label.text = message
	if is_instance_valid(start_online_button): start_online_button.disabled = roster.size() < 2
	for peer in roster:
		if int(peer) != 1: net_lobby.rpc_id(int(peer), roster, message)

func create_match_ui() -> void:
	for player in players: player.hud.hide()
	flag_label = make_label(match_ui, "", 1, WHITE)
	flag_label.hide()
	flag_banner = make_label(match_ui, "", 1, WHITE)
	flag_banner.hide()
	score_label = make_label(match_ui, "", 24, WHITE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_color_override("font_shadow_color", Color("#0c141b"))
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	countdown_label = make_label(match_ui, "", 48, WHITE)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var humans := players.filter(func(player): return player.human_index >= 0)
	for human in humans:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match_ui.add_child(container)
		match_ui.move_child(container, 0)
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally = false
		container.add_child(viewport)
		var view := Node2D.new()
		view.set_script(VIEW_SCRIPT)
		view.arena = self
		view.viewer = human
		view.container = container
		viewport.add_child(view)
		views.append(view)
	pause_button = icon_button(match_ui, "pause", func(): open_overlay("pause"), "Esc")
	layout_match()
	update_flag_ui()

func layout_match() -> void:
	var area := get_viewport_rect().size
	var split := views.size() > 1
	var portrait := area.y > area.x
	for index in range(views.size()):
		var view = views[index]
		view.container.position = Vector2(0, index * area.y / 2) if split and portrait else Vector2(index * area.x / 2 if split else 0, 0)
		view.container.size = Vector2(area.x, area.y / 2 - 1) if split and portrait else Vector2(area.x / 2 - 1 if split else area.x, area.y)
	var safe := safe_bounds()
	score_label.position = Vector2(area.x / 2 - 60, safe.position.y + 12)
	score_label.size = Vector2(120, 36)
	countdown_label.position = area / 2 - Vector2(60, 40)
	countdown_label.size = Vector2(120, 80)
	var target_size := 96.0 if touch_enabled() else 64.0
	pause_button.custom_minimum_size = Vector2.ONE * target_size
	pause_button.size = Vector2.ONE * target_size
	pause_button.position = Vector2(safe.end.x - target_size, safe.position.y)

func update_flag_ui() -> void:
	if not is_instance_valid(score_label): return
	var seconds := ceili(time_left)
	score_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	score_label.modulate = Color("#ffc5ac") if time_left < 20 else WHITE

func update_fusion_ui() -> void:
	pass

func begin_match(mode: String, epoch: int) -> void:
	bot_ult_next = [14.0, 18.0]
	team_ult_next = [0.0, 0.0]
	super.begin_match(mode, epoch)
	layout_match()

func cast_ultimate(player) -> bool:
	if not practice and elapsed < team_ult_next[player.team]: return false
	if player.bot:
		var partner = teammate(player)
		if partner != null and not partner.bot: return false
		if elapsed < bot_ult_next[player.team] or not squad or not fusion[player.team].ready or fusion[player.team].age < 2.4: return false
		for zone in zones:
			if zone.team == player.team: return false
		var target = nearest_enemy(player)
		if target == null or target.position.distance_to(player.position) > 330 or target.hp < 40: return false
		player.aim_direction = (target.position - player.position).normalized()
	var cast := super.cast_ultimate(player)
	if cast and not practice:
		team_ult_next[player.team] = elapsed + 8.0
		if player.bot: bot_ult_next[player.team] = elapsed + 20.0
	return cast

func snapshot_for(peer: int) -> Dictionary:
	var data := super.snapshot_for(peer)
	data["ult_wait"] = [maxf(0, team_ult_next[0] - elapsed), maxf(0, team_ult_next[1] - elapsed)]
	return data

func uses_directional_aim(_player) -> bool:
	return touch_enabled() or using_gamepad

func control_human(player) -> void:
	if online_active and int(player.get_meta("peer_id", 0)) != multiplayer.get_unique_id():
		var data: Dictionary = net_inputs.get(int(player.get_meta("peer_id", 0)), {})
		if not data.is_empty() and Time.get_ticks_msec() - int(data.time) < 400:
			player.move_intent = data.direction
			player.attack_intent = data.attack
			player.aim_direction = data.aim
		return
	if is_instance_valid(overlay_panel) or Time.get_ticks_msec() < input_resume_at:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		return
	if player.human_index == 0 and touch_enabled() and is_instance_valid(touch_controls):
		player.move_intent = touch_controls.move_vector
		player.attack_intent = touch_controls.firing
		if touch_controls.aim_vector.length_squared() > 0.04:
			player.aim_direction = touch_controls.aim_vector.normalized()
		return
	super.control_human(player)
	if online_active and int(player.get_meta("peer_id", 0)) != multiplayer.get_unique_id(): return
	if player.human_index == 0:
		for view in views:
			if view.viewer == player and Rect2(view.container.position, view.container.size).has_point(get_viewport().get_mouse_position()):
				player.aim_direction = (view.mouse_world() - player.position).normalized()
		if get_viewport().gui_get_hovered_control() is BaseButton: player.attack_intent = false
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): using_gamepad = false
	if player.human_index < 0 or player.human_index >= pads.size(): return
	var pad: int = pads[player.human_index]
	var move := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	var aim := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	using_gamepad = move.length() > 0.2 or aim.length() > 0.2 or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)
	if move.length() > 0.2: player.move_intent = move.limit_length()
	if aim.length() > 0.2: player.aim_direction = aim.normalized()
	player.attack_intent = player.attack_intent or Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.3 or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER)

func close_overlay() -> void:
	super.close_overlay()
	input_resume_at = Time.get_ticks_msec() + 160

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not mobile_device(): touch_used = false
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and not mobile_device(): touch_used = false
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			if is_instance_valid(overlay_panel): close_overlay()
			elif state == "offline": open_overlay("pause")
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_LEFT_SHOULDER and state == "offline" and not is_instance_valid(overlay_panel):
			using_gamepad = true
			for player in players:
				if player.human_index >= 0 and player.human_index < Input.get_connected_joypads().size() and Input.get_connected_joypads()[player.human_index] == event.device:
					cast_ultimate(player)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and (event.alt_pressed or event.meta_pressed):
		set_option("fullscreen", not options.fullscreen)
		get_viewport().set_input_as_handled()

func add_effect(pos: Vector2, color: Color, radius: float, _caption: String) -> void:
	super.add_effect(pos, color, minf(24.0, radius * 0.45), "")

func open_overlay(page: String) -> void:
	if not is_instance_valid(overlay_layer): return
	if is_instance_valid(overlay_panel):
		overlay_panel.hide()
		overlay_panel.queue_free()
	overlay_page = page
	if is_instance_valid(menu): menu.hide()
	if is_instance_valid(touch_controls): touch_controls.reset_touches()
	get_tree().paused = state == "offline" and not online_active
	overlay_panel = Control.new()
	overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(overlay_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.055, 0.075, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_panel.add_child(shade)
	var box := menu_content(overlay_panel, 480 if page != "codex" else 600)
	icon_button(box, "close", close_overlay, "Esc").size_flags_horizontal = Control.SIZE_SHRINK_END
	match page:
		"pause":
			make_button(box, "Продолжить", close_overlay)
			make_button(box, "Настройки", func(): open_overlay("settings"))
			make_button(box, "В меню", show_main_menu)
		"settings": build_settings(box)
		"codex": build_codex(box)

func build_settings(box: VBoxContainer) -> void:
	var row_height := 96.0 if touch_enabled() else 60.0
	var font_size := 28 if touch_enabled() else 20
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	if not mobile_device():
		add_toggle(grid, "Полный экран", "fullscreen")
		add_toggle(grid, "VSync", "vsync")
	add_toggle(grid, "Плавная камера", "camera_smoothing")
	add_toggle(grid, "Меньше вспышек", "reduced_flashes")
	make_label(grid, "Звук", font_size, WHITE)
	var volume := HSlider.new()
	volume.custom_minimum_size = Vector2(180, row_height)
	volume.min_value = 0
	volume.max_value = 100
	volume.value = float(options.volume) * 100
	volume.value_changed.connect(func(value: float): set_option("volume", value / 100.0))
	grid.add_child(volume)
	make_label(grid, "Эффекты", font_size, WHITE)
	var quality := OptionButton.new()
	quality.custom_minimum_size = Vector2(180, row_height)
	quality.add_theme_font_size_override("font_size", font_size)
	quality.add_item("Низкие")
	quality.add_item("Высокие")
	quality.select(int(options.quality))
	style_field(quality)
	quality.item_selected.connect(func(index: int): set_option("quality", index))
	grid.add_child(quality)
	make_label(grid, "Сенсорный ввод", font_size, WHITE)
	var touch := OptionButton.new()
	touch.custom_minimum_size = Vector2(180, row_height)
	touch.add_theme_font_size_override("font_size", font_size)
	for value in ["Авто", "Вкл.", "Выкл."]: touch.add_item(value)
	touch.select(touch_override)
	style_field(touch)
	touch.item_selected.connect(func(index: int):
		touch_override = index
		if is_instance_valid(touch_controls): touch_controls.reset_touches()
		save_options()
		schedule_layout()
	)
	grid.add_child(touch)

func add_toggle(grid: GridContainer, text: String, key: String) -> void:
	make_label(grid, text, 28 if touch_enabled() else 20, WHITE)
	var toggle := CheckButton.new()
	toggle.custom_minimum_size = Vector2(180, 96 if touch_enabled() else 60)
	toggle.button_pressed = bool(options[key])
	toggle.toggled.connect(func(value: bool): set_option(key, value))
	grid.add_child(toggle)

func build_codex(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2 if touch_enabled() else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for a in range(5):
		for b in range(a, 5):
			var row := HBoxContainer.new()
			grid.add_child(row)
			var first := icon_button(row, GLYPHS[a], func(): start_practice_pair(a, b), FUSION_NAMES[pair_key(a, b)])
			first.accent = ELEMENT_COLORS[a]
			var second := icon_button(row, GLYPHS[b], func(): start_practice_pair(a, b), FUSION_NAMES[pair_key(a, b)])
			second.accent = ELEMENT_COLORS[b]

func finish_flag_match() -> void:
	if state != "offline": return
	winner_team = flag_owner if flag_phase == "owned" and flag_shield > 0 else -1
	state = "result"
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.set_physics_process(false)
	var box := create_menu_card(420)
	var result := make_label(box, "Ничья" if winner_team < 0 else ("Синие" if winner_team == 0 else "Оранжевые"), 36, WHITE if winner_team < 0 else (BLUE if winner_team == 0 else ORANGE))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not online_active or multiplayer.is_server(): make_button(box, "Ещё раз", func(): start_offline(match_mode))
	make_button(box, "В меню", show_main_menu)

func apply_options() -> void:
	if mobile_device():
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(options.volume))))
		AudioServer.set_bus_mute(0, float(options.volume) <= 0.0)
	else:
		super.apply_options()

func save_options() -> void:
	super.save_options()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		config.set_value("settings", "touch_mode", touch_override)
		config.save(SETTINGS_PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(touch_controls): touch_controls.reset_touches()
		if state == "offline" and not online_active and is_instance_valid(overlay_layer): open_overlay("pause")
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(overlay_panel): close_overlay()
		elif state == "offline": open_overlay("pause")
		else: show_main_menu()
