extends "res://minimal_arena.gd"

var service_socket: WebSocketPeer
var service_active: bool = false
var service_match: bool = false
var service_connected: bool = false
var service_started: int = 0
var service_ping_clock: float = 0.0
var service_input_clock: float = 0.0
var service_element: int = -1
var search_status: Label
var retry_button: Button
var search_spinner: Control

func server_url() -> String:
	if OS.has_environment("ELEMENT_SERVER_URL"): return OS.get_environment("ELEMENT_SERVER_URL").strip_edges()
	var config := ConfigFile.new()
	if config.load("res://online.cfg") == OK:
		return str(config.get_value("matchmaking", "server_url", "")).strip_edges()
	return ""

func stop_network() -> void:
	if service_socket != null: service_socket.close(1000, "cancelled")
	service_socket = null
	service_active = false
	service_match = false
	service_connected = false
	search_status = null
	retry_button = null
	super.stop_network()

func show_online_menu(message: String = "") -> void:
	close_overlay()
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(600 if touch_enabled() else 480)
	icon_button(box, "back", show_main_menu, "Назад").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_element_choices(box, false)
	var center := CenterContainer.new()
	box.add_child(center)
	search_spinner = Control.new()
	search_spinner.set_script(preload("res://search_spinner.gd"))
	center.add_child(search_spinner)
	search_status = make_label(box, "Поиск игроков…" if message.is_empty() else message, 24, WHITE)
	status_label = search_status
	search_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_button = make_button(box, "Повторить", func(): show_online_menu())
	retry_button.hide()
	if not message.is_empty():
		retry_button.show()
		return
	var url := server_url()
	if url.is_empty():
		search_failed("Сервер ещё не подключён")
		return
	if not url.begins_with("wss://") and not url.begins_with("ws://127.0.0.1:") and not url.begins_with("ws://localhost:"):
		search_failed("Недоступный сервер")
		return
	service_socket = WebSocketPeer.new()
	service_socket.inbound_buffer_size = 1048576
	service_socket.outbound_buffer_size = 65536
	service_socket.max_queued_packets = 64
	if service_socket.connect_to_url(url) != OK:
		search_failed("Не удалось подключиться")
		return
	service_active = true
	service_started = Time.get_ticks_msec()
	service_ping_clock = 0
	service_element = selected_elements[0]
	state = "searching"

func search_failed(message: String) -> void:
	if service_socket != null: service_socket.close()
	service_socket = null
	service_active = false
	service_connected = false
	if is_instance_valid(search_spinner): search_spinner.hide()
	if is_instance_valid(search_status): search_status.text = message
	if is_instance_valid(retry_button): retry_button.show()

func service_send(data: Dictionary) -> void:
	if service_socket != null and service_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		service_socket.send_text(JSON.stringify(data))

func _process(delta: float) -> void:
	super._process(delta)
	if not service_active or service_socket == null: return
	service_socket.poll()
	var ready := service_socket.get_ready_state()
	if ready == WebSocketPeer.STATE_CLOSED:
		if service_match and state == "result":
			service_active = false
			return
		if service_match:
			call_deferred("show_online_menu", "Связь потеряна")
		else:
			search_failed("Сервер недоступен")
		return
	if not service_connected and Time.get_ticks_msec() - service_started > 15000:
		search_failed("Сервер не отвечает")
		return
	if ready != WebSocketPeer.STATE_OPEN: return
	if not service_connected:
		service_connected = true
		service_send({"type": "queue", "version": NET_VERSION, "element": selected_elements[0]})
	service_ping_clock += delta
	if service_ping_clock >= 5.0:
		service_ping_clock = 0
		service_send({"type": "ping"})
	if not service_match and selected_elements[0] != service_element:
		service_element = selected_elements[0]
		service_send({"type": "element", "element": service_element})
	var packets: int = 0
	while service_socket != null and service_socket.get_available_packet_count() > 0 and packets < 32:
		packets += 1
		var packet := service_socket.get_packet()
		if service_socket.was_string_packet():
			if packet.size() > 16384: continue
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary: receive_service_message(data)
		elif service_match:
			var raw := packet.decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE)
			if raw.is_empty(): continue
			var data = bytes_to_var(raw)
			if data is Dictionary and int(data.get("epoch", -1)) == match_id:
				apply_remote_snapshot(data)

func receive_service_message(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"queue":
			if not is_instance_valid(search_status): return
			var count := int(data.get("players", 0))
			var countdown: int = int(data.get("starts_in", -1))
			search_status.text = "Поиск игроков…" if count < 2 or countdown < 0 else "%d / 4  ·  %d" % [count, maxi(0, countdown)]
		"error":
			search_failed(str(data.get("message", "Не удалось подключиться")))
		"match":
			if service_match: return
			var incoming = data.get("roster", {})
			var slot := int(data.get("slot", -1))
			if not incoming is Dictionary or slot < 0 or slot > 3: return
			roster.clear()
			for peer in incoming: roster[int(peer)] = incoming[peer]
			local_slot = slot
			service_match = true
			online_active = true
			input_serial = 0
			ultimate_serial = 0
			net_visible = [true, true, true, true]
			begin_match("squad_service", int(data.get("id", 1)))
			service_input_clock = 0

func configure_match_player(player, index: int, mode: String) -> void:
	if mode != "squad_service":
		super.configure_match_player(player, index, mode)
		return
	var human: bool = false
	for peer in roster:
		if int(roster[peer].slot) == index:
			player.element = int(roster[peer].element)
			human = true
	player.bot = not human
	player.human_index = 0 if index == local_slot else -1
	player.simulation_authority = false
	player.set_meta("peer_id", multiplayer.get_unique_id() if index == local_slot else 0)
	player.player_name = ""

func _physics_process(delta: float) -> void:
	if not service_match:
		super._physics_process(delta)
		return
	if state != "offline" or players.size() != 4: return
	elapsed += delta
	time_left = maxf(0, time_left - delta)
	countdown = maxf(0, countdown - delta)
	countdown_label.text = str(ceili(countdown)) if countdown > 0 else ""
	for shot in projectiles:
		var step := minf(delta, maxf(0, float(shot.life)))
		shot.pos += shot.vel * step
		shot.life = maxf(0, shot.life - delta)
	for zone in zones: zone.age += delta
	for flood in floods:
		flood.life = maxf(0, flood.life - delta)
		flood.age += delta
	for fx in effects: fx.life = maxf(0, fx.life - delta)
	for fx in combat_visuals: fx.life = maxf(0, fx.life - delta)
	var player = players[local_slot]
	control_human(player)
	if countdown > 0:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
	service_input_clock += delta
	if service_input_clock >= 1.0 / 30.0:
		service_input_clock = 0
		input_serial += 1
		service_send({"type": "input", "sequence": input_serial, "move": [player.move_intent.x, player.move_intent.y], "aim": [player.aim_direction.x, player.aim_direction.y], "attack": player.attack_intent, "ultimate": ultimate_serial})
	update_flag_ui()

func cast_ultimate(player) -> bool:
	if not service_match: return super.cast_ultimate(player)
	if state != "offline" or countdown > 0 or player != players[local_slot] or player.is_dead or not fusion[player.team].ready or elapsed < team_ult_next[player.team]: return false
	ultimate_serial += 1
	return true

func is_visible_to(target, team: int) -> bool:
	if service_match:
		var index := players.find(target)
		return index >= 0 and net_visible[index]
	return super.is_visible_to(target, team)

func start_offline(mode: String) -> void:
	if mode == "squad_service":
		show_online_menu()
		return
	super.start_offline(mode)
