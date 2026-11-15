extends Node2D

const PROTOCOL_VERSION: int = 2
const DEFAULT_PORT: int = 24567
const SCORE_TO_WIN: int = 3
const ARENA_BOUNDS := Rect2(116.0, 170.0, 920.0, 462.0)
const MAP_RECT := Rect2(96.0, 128.0, 960.0, 540.0)
const MAP_TEXTURE: Texture2D = preload("res://assets/elemental_rivals_map.png")
const BLUE := Color("#88c9ff")
const ORANGE := Color("#ffc48a")
const WHITE := Color("#edf3fc")
const MUTED := Color("#94a6bd")

var state: String = "menu"
var match_mode: String = ""
var players: Array = []
var scores: Array[int] = [0, 0]
var match_id: int = 0
var remote_peer: int = 0
var remote_direction: Vector2 = Vector2.ZERO
var remote_attack: bool = false
var remote_sequence: int = -1
var input_sequence: int = 0
var last_remote_input: int = 0
var network_clock: float = 0.0
var join_deadline: int = 0
var countdown: float = 0.0
var bot_clock: float = 0.0
var bot_direction: Vector2 = Vector2.ZERO
var bot_attack: bool = false
var menu: Control
var match_ui: Control
var ui: Control
var status_label: Label
var score_label: Label
var countdown_label: Label
var address_field: LineEdit
var port_field: SpinBox
var host_button: Button
var join_button: Button
var world: Node2D


func _ready() -> void:
	process_physics_priority = -20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#0c111c"))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	canvas.add_child(ui)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	show_main_menu()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), Color("#0c111c"))
	draw_texture_rect(MAP_TEXTURE, MAP_RECT, false)
	draw_rect(MAP_RECT, Color("#35485e"), false, 2.0)
	for player in players:
		if is_instance_valid(player):
			var team_color := BLUE if player.player_slot == 0 else ORANGE
			var feet: Vector2 = player.position + Vector2(0, 35)
			draw_player_marker(feet, team_color)


func draw_player_marker(center: Vector2, team_color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := float(index) / 24.0 * TAU
		points.append(center + Vector2(cos(angle) * 24, sin(angle) * 8))
	draw_colored_polygon(points, Color(team_color, 0.18))
	points.append(points[0])
	draw_polyline(points, Color(team_color, 0.65), 1.5, true)


func _process(_delta: float) -> void:
	queue_redraw()
	if state == "joining" and Time.get_ticks_msec() > join_deadline:
		close_and_show_online("Подключение не удалось. Проверь адрес и доступность UDP-порта.")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			show_main_menu()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if state != "offline" and state != "network":
		return
	if players.size() != 2:
		return
	if match_mode == "online" and not multiplayer.is_server():
		network_clock += delta
		if network_clock >= 1.0 / 30.0:
			network_clock = 0.0
			input_sequence += 1
			submit_input.rpc_id(1, match_id, input_sequence, keyboard_direction(0), Input.is_physical_key_pressed(KEY_SPACE))
		return

	countdown = maxf(0.0, countdown - delta)
	countdown_label.text = str(ceili(countdown)) if countdown > 0.0 else ""
	if countdown > 0.0:
		for player in players:
			player.move_intent = Vector2.ZERO
			player.attack_intent = false
	else:
		players[0].move_intent = keyboard_direction(0)
		players[0].attack_intent = Input.is_physical_key_pressed(KEY_SPACE)
		if match_mode == "bot":
			update_bot(delta)
			players[1].move_intent = bot_direction
			players[1].attack_intent = bot_attack
		elif match_mode == "local":
			players[1].move_intent = keyboard_direction(1)
			players[1].attack_intent = Input.is_physical_key_pressed(KEY_ENTER)
		else:
			var input_fresh := Time.get_ticks_msec() - last_remote_input < 400
			players[1].move_intent = remote_direction if input_fresh else Vector2.ZERO
			players[1].attack_intent = remote_attack and input_fresh
	for player in players:
		player.position = player.position.clamp(ARENA_BOUNDS.position, ARENA_BOUNDS.end)
	if match_mode == "online":
		network_clock += delta
		if network_clock >= 1.0 / 30.0:
			network_clock = 0.0
			receive_snapshot.rpc_id(remote_peer, match_id, snapshot(), scores, countdown)


func keyboard_direction(slot: int) -> Vector2:
	var keys: Array = [KEY_A, KEY_D, KEY_W, KEY_S]
	if slot == 1:
		keys = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
	return Vector2(
		float(Input.is_physical_key_pressed(keys[1])) - float(Input.is_physical_key_pressed(keys[0])),
		float(Input.is_physical_key_pressed(keys[3])) - float(Input.is_physical_key_pressed(keys[2]))
	).limit_length()


func update_bot(delta: float) -> void:
	bot_clock -= delta
	if bot_clock > 0.0:
		return
	bot_clock = 0.22
	var bot = players[1]
	var target = players[0]
	bot_direction = Vector2.ZERO
	bot_attack = false
	if bot.is_dead or target.is_dead:
		return
	var offset: Vector2 = target.position - bot.position
	var distance := offset.length()
	var toward := offset.normalized()
	if bot.energy < 20.0:
		bot_direction = -toward
	elif distance > 66.0:
		bot_direction = toward
	else:
		bot.facing_direction = toward
		bot.body_sprite.flip_h = toward.x < 0.0
		bot_attack = true
	if bot.position.x < ARENA_BOUNDS.position.x + 20 and bot_direction.x < 0:
		bot_direction.x = 0
		bot_direction.y = signf(412.0 - bot.position.y)
	if bot.position.x > ARENA_BOUNDS.end.x - 20 and bot_direction.x > 0:
		bot_direction.x = 0
		bot_direction.y = signf(412.0 - bot.position.y)


func begin_match(mode: String, epoch: int) -> void:
	clear_match()
	clear_menu()
	match_mode = mode
	match_id = epoch
	scores = [0, 0]
	state = "network" if mode == "online" else "offline"
	network_clock = 0.0
	remote_sequence = -1
	input_sequence = 0
	remote_direction = Vector2.ZERO
	remote_attack = false
	countdown = 1.5
	bot_clock = 0.0
	world = Node2D.new()
	world.name = "Fighters"
	add_child(world)
	match_ui = Control.new()
	match_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(match_ui)
	var scene := load("res://player.tscn") as PackedScene
	for slot in range(2):
		var player = scene.instantiate()
		player.name = "Player%d" % [slot + 1]
		player.player_slot = slot
		player.player_name = "BOT" if mode == "bot" and slot == 1 else "PLAYER %d" % [slot + 1]
		player.external_control = true
		player.simulation_authority = mode != "online" or multiplayer.is_server()
		player.auto_respawn = false
		player.debug_damage_enabled = false
		player.hud_world_space = false
		player.hud_width = 240.0
		player.position = Vector2(340 + slot * 472, 410)
		var collider := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collider != null:
			collider.position = Vector2(0, 12)
			var shape := CircleShape2D.new()
			shape.radius = 16.0
			collider.shape = shape
		world.add_child(player)
		player.facing_direction = Vector2.RIGHT if slot == 0 else Vector2.LEFT
		player.body_sprite.flip_h = slot == 1
		player.hud.reparent(match_ui, false)
		player.hud.position = Vector2(32 if slot == 0 else 880, 24)
		player.attack_impact.connect(resolve_attack)
		player.defeated.connect(on_defeated)
		players.append(player)
	create_match_ui()


func resolve_attack(attacker) -> void:
	if state != "offline" and state != "network":
		return
	if match_mode == "online" and not multiplayer.is_server():
		return
	if countdown > 0.0 or attacker.is_dead:
		return
	var target = players[1 - attacker.player_slot]
	if target.is_dead:
		return
	var offset: Vector2 = target.position - attacker.position
	var distance := offset.length()
	if distance <= 84.0 and (distance < 20.0 or attacker.facing_direction.dot(offset.normalized()) >= 0.2):
		target.take_damage(25)


func on_defeated(player) -> void:
	var winner: int = 1 - player.player_slot
	scores[winner] += 1
	update_score()
	if scores[winner] >= SCORE_TO_WIN:
		if match_mode == "online":
			finish_remote.rpc_id(remote_peer, match_id, scores, snapshot(), winner)
		show_result(winner)
		return
	var epoch := match_id
	await get_tree().create_timer(player.respawn_time).timeout
	if epoch == match_id and (state == "offline" or state == "network") and is_instance_valid(player):
		player.respawn()


func create_match_ui() -> void:
	var mode_name := "1 vs BOT"
	if match_mode == "local":
		mode_name = "LOCAL 1 vs 1"
	elif match_mode == "online":
		mode_name = "ONLINE 1 vs 1"
	var mode_label := make_label(match_ui, mode_name, 13, MUTED)
	mode_label.position = Vector2(400, 24)
	mode_label.size = Vector2(352, 22)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = make_label(match_ui, "", 36, WHITE)
	score_label.position = Vector2(400, 44)
	score_label.size = Vector2(352, 48)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var goal := make_label(match_ui, "ДО 3 ПОБЕД", 10, MUTED)
	goal.position = Vector2(400, 96)
	goal.size = Vector2(352, 20)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label = make_label(match_ui, "", 60, WHITE)
	countdown_label.position = Vector2(470, 310)
	countdown_label.size = Vector2(212, 80)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := "WASD — движение    SPACE — атака"
	if match_mode == "local":
		controls = "P1  WASD + SPACE      •      P2  СТРЕЛКИ + ENTER"
	elif match_mode == "online":
		var slot := 1 if multiplayer.is_server() else 2
		controls = "ТЫ — PLAYER %d    •    WASD — движение    SPACE — атака" % slot
	var hint := make_label(match_ui, controls, 14, MUTED)
	hint.position = Vector2(72, 674)
	var menu_button := make_button(match_ui, "МЕНЮ  /  ESC", show_main_menu)
	menu_button.position = Vector2(916, 668)
	menu_button.size = Vector2(164, 36)
	update_score()


func update_score() -> void:
	if is_instance_valid(score_label):
		score_label.text = "%d  —  %d" % [scores[0], scores[1]]


func snapshot() -> Array:
	return [players[0].network_state(), players[1].network_state()]


func clear_match() -> void:
	for player in players:
		if is_instance_valid(player):
			player.set_physics_process(false)
	players.clear()
	if is_instance_valid(world):
		world.queue_free()
	if is_instance_valid(match_ui):
		match_ui.hide()
		match_ui.queue_free()
	world = null
	match_ui = null
	score_label = null
	countdown_label = null


func clear_menu() -> void:
	if is_instance_valid(menu):
		menu.hide()
		menu.queue_free()
	menu = null


func stop_network() -> void:
	state = "menu"
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	remote_peer = 0
	join_deadline = 0


func show_main_menu() -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(600.0)
	make_label(box, "ELEMENT", 56, WHITE)
	make_label(box, "Выбери режим боя", 17, MUTED)
	var space := Control.new()
	space.custom_minimum_size.y = 10
	box.add_child(space)
	make_mode_button(box, "1 vs BOT", "Бой с ботом · подход, атака и восстановление энергии", BLUE, func(): start_offline("bot"))
	make_mode_button(box, "1 vs 1", "Два игрока на одной клавиатуре", ORANGE, func(): start_offline("local"))
	make_mode_button(box, "ONLINE", "Создай матч или подключись к другу по IP", Color("#a8a0ff"), show_online_menu)


func start_offline(mode: String) -> void:
	stop_network()
	begin_match(mode, match_id + 1)


func show_result(winner: int) -> void:
	state = "result"
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.set_physics_process(false)
	var box := create_menu_card(480.0)
	var winner_name := "BOT" if match_mode == "bot" and winner == 1 else "PLAYER %d" % [winner + 1]
	make_label(box, winner_name + " ПОБЕДИЛ", 30, BLUE if winner == 0 else ORANGE)
	make_label(box, "%d  —  %d" % [scores[0], scores[1]], 48, WHITE)
	if match_mode != "online" or multiplayer.is_server():
		make_button(box, "СЫГРАТЬ ЕЩЁ", rematch)
	else:
		make_label(box, "Хост может начать новый матч.", 15, MUTED)
	make_button(box, "В МЕНЮ", show_main_menu)


func rematch() -> void:
	if match_mode == "online":
		if not multiplayer.is_server() or remote_peer == 0:
			return
		var epoch := match_id + 1
		begin_match("online", epoch)
		begin_remote.rpc_id(remote_peer, epoch)
	else:
		start_offline(match_mode)


func show_online_menu(message: String = "") -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(620.0)
	make_label(box, "ONLINE", 42, WHITE)
	make_label(box, "Один игрок создаёт матч, второй вводит адрес хоста.", 16, MUTED)
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 12)
	box.add_child(inputs)
	address_field = LineEdit.new()
	address_field.placeholder_text = "IP или домен хоста"
	address_field.text = "127.0.0.1"
	address_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_field.custom_minimum_size.y = 46
	address_field.add_theme_font_size_override("font_size", 18)
	inputs.add_child(address_field)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = DEFAULT_PORT
	port_field.custom_minimum_size = Vector2(128, 46)
	port_field.tooltip_text = "UDP-порт"
	inputs.add_child(port_field)
	host_button = make_button(box, "СОЗДАТЬ МАТЧ", func(): start_host(int(port_field.value)))
	join_button = make_button(box, "ПОДКЛЮЧИТЬСЯ", func(): start_join(address_field.text, int(port_field.value)))
	status_label = make_label(box, message, 14, BLUE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(540, 46)
	var help := make_label(box, "В одной сети используй локальный IP хоста. Через интернет нужен внешний адрес и доступный UDP-порт. 127.0.0.1 — проверка на одном компьютере.", 13, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 540
	make_button(box, "НАЗАД / ОТМЕНИТЬ", show_main_menu)


func set_connection_busy(busy: bool) -> void:
	if is_instance_valid(host_button):
		host_button.disabled = busy
		join_button.disabled = busy
		address_field.editable = not busy
		port_field.editable = not busy


func start_host(port: int = DEFAULT_PORT) -> void:
	if port < 1024 or port > 65535:
		status_label.text = "Укажи порт от 1024 до 65535."
		return
	stop_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1, 2)
	if error != OK:
		status_label.text = "Не удалось открыть порт %d. Попробуй другой порт." % port
		return
	multiplayer.multiplayer_peer = peer
	state = "hosting"
	set_connection_busy(true)
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.is_valid_ip_address() and "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	status_label.text = "Ожидание второго игрока. UDP %d\nЛокальный IP: %s" % [port, ", ".join(addresses)]


func start_join(address: String, port: int = DEFAULT_PORT) -> void:
	address = address.strip_edges()
	if address.is_empty() or address.length() > 253 or port < 1024 or port > 65535:
		status_label.text = "Введи IP/домен хоста и порт от 1024 до 65535."
		return
	stop_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 2)
	if error != OK:
		status_label.text = "Не удалось начать подключение. Проверь адрес."
		return
	multiplayer.multiplayer_peer = peer
	state = "joining"
	join_deadline = Time.get_ticks_msec() + 12000
	set_connection_busy(true)
	status_label.text = "Подключение к %s, UDP %d…" % [address, port]


func _on_peer_connected(peer_id: int) -> void:
	if state == "hosting" and multiplayer.is_server():
		remote_peer = peer_id


func _on_connected() -> void:
	if state == "joining":
		client_ready.rpc_id(1, PROTOCOL_VERSION)


@rpc("any_peer", "call_remote", "reliable")
func client_ready(version: int) -> void:
	if not multiplayer.is_server() or state != "hosting":
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != remote_peer or sender == 1:
		return
	if version != PROTOCOL_VERSION:
		reject_connection.rpc_id(sender, "Версии игры различаются. Используйте одинаковую сборку.")
		return
	var epoch := match_id + 1
	begin_match("online", epoch)
	begin_remote.rpc_id(sender, epoch)


@rpc("authority", "call_remote", "reliable")
func begin_remote(epoch: int) -> void:
	if multiplayer.is_server() or (state != "joining" and state != "result"):
		return
	begin_match("online", epoch)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(epoch: int, sequence: int, direction: Vector2, attacking: bool) -> void:
	if not multiplayer.is_server() or state != "network":
		return
	if multiplayer.get_remote_sender_id() != remote_peer or epoch != match_id:
		return
	if sequence <= remote_sequence or not direction.is_finite():
		return
	remote_sequence = sequence
	remote_direction = direction.limit_length()
	remote_attack = attacking
	last_remote_input = Time.get_ticks_msec()


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_snapshot(epoch: int, fighter_states: Array, new_scores: Array, remaining: float) -> void:
	if multiplayer.is_server() or state != "network" or epoch != match_id:
		return
	if fighter_states.size() != 2 or new_scores.size() != 2:
		return
	for index in range(2):
		players[index].apply_network_state(fighter_states[index])
	scores.assign(new_scores)
	countdown = remaining
	countdown_label.text = str(ceili(countdown)) if countdown > 0.0 else ""
	update_score()


@rpc("authority", "call_remote", "reliable")
func finish_remote(epoch: int, final_scores: Array, fighter_states: Array, winner: int) -> void:
	if multiplayer.is_server() or state != "network" or epoch != match_id:
		return
	if fighter_states.size() != 2 or final_scores.size() != 2:
		return
	for index in range(2):
		players[index].apply_network_state(fighter_states[index])
	scores.assign(final_scores)
	update_score()
	show_result(winner)


@rpc("authority", "call_remote", "reliable")
func reject_connection(message: String) -> void:
	call_deferred("close_and_show_online", message)


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id != remote_peer:
		return
	if state == "network" or state == "result":
		call_deferred("close_and_show_online", "Второй игрок отключился. Можно создать новый матч.")
	elif state == "hosting":
		remote_peer = 0


func _on_connection_failed() -> void:
	if state == "joining":
		call_deferred("close_and_show_online", "Подключение не удалось. Проверь адрес и UDP-порт.")


func _on_server_disconnected() -> void:
	if state == "network" or state == "joining" or state == "result":
		call_deferred("close_and_show_online", "Соединение с хостом потеряно.")


func close_and_show_online(message: String) -> void:
	show_online_menu(message)


func create_menu_card(width: float) -> VBoxContainer:
	clear_menu()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.07, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", panel_style(Color("#121d2c"), Color("#304157"), 30, 12))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


func panel_style(background: Color, border: Color, margin: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(float(margin))
	return style


func make_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", panel_style(Color("#1c2b3e"), Color("#3c536d"), 12, 6))
	button.add_theme_stylebox_override("hover", panel_style(Color("#2a4059"), BLUE.darkened(0.35), 12, 6))
	button.add_theme_stylebox_override("pressed", panel_style(Color("#162334"), BLUE, 12, 6))
	button.add_theme_stylebox_override("disabled", panel_style(Color("#17212e"), Color("#263445"), 12, 6))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func make_mode_button(parent: Node, title: String, description: String, accent: Color, action: Callable) -> void:
	var button := make_button(parent, "", action)
	button.custom_minimum_size.y = 88
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	make_label(box, title, 24, accent)
	make_label(box, description, 13, MUTED)
