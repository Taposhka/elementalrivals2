extends "res://flag_arena.gd"

const NET_VERSION: int = 11
const MENU_IMAGES := [preload("res://assets/menu_1player.png"), preload("res://assets/menu_2player.png"), preload("res://assets/menu_online.png")]
var online_active: bool = false
var roster: Dictionary = {}
var net_inputs: Dictionary = {}
var net_visible: Array[bool] = [true, true, true, true]
var local_slot: int = 0
var send_clock: float = 0.0
var input_serial: int = 0
var ultimate_serial: int = 0
var start_online_button: Button
var lobby_port: int = DEFAULT_PORT

func stop_network() -> void:
	online_active = false
	roster.clear()
	net_inputs.clear()
	start_online_button = null
	super.stop_network()

func show_main_menu() -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(690)
	make_label(box, "ELEMENT RIVALS", 40, Color("#e6cb59"))
	make_label(box, "ФЛАГ · ЭЛЕМЕНТЫ · КОМАНДНЫЕ УЛЬТЫ", 13, MUTED)
	var actions: Array[Callable] = [func(): show_mode_menu(false), func(): show_mode_menu(true), show_online_menu]
	var tips := ["Один игрок: дуэль с ботом или 2v2 с союзником-ботом", "Два игрока на одном компьютере: дуэль или совместный 2v2", "Сетевой 2v2: создать матч или подключиться по IP"]
	for index in range(3):
		var crop := AtlasTexture.new()
		crop.atlas = MENU_IMAGES[index]
		crop.region = Rect2(77, 192, 1805, 384)
		var button := TextureButton.new()
		button.texture_normal = crop
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(620, 132)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.tooltip_text = tips[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.mouse_entered.connect(func(): button.modulate = Color(1.18, 1.18, 1.1))
		button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
		button.pressed.connect(actions[index])
		box.add_child(button)
	make_label(box, "WASD + ЛКМ / SPACE · УЛЬТА Q", 13, MUTED)

func add_element_choices(box: VBoxContainer, two: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var combo := make_label(box, "", 13, Color("#ffe7a2"))
	for slot in range(2 if two else 1):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		make_label(column, "ТВОЙ ЭЛЕМЕНТ" if slot == 0 else "P2 / СОЮЗНИК", 12, MUTED)
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(230, 40)
		for name in ELEMENT_NAMES: picker.add_item(name)
		picker.select(selected_elements[slot])
		picker.item_selected.connect(func(value: int):
			selected_elements[slot] = value
			combo.text = "СЛИЯНИЕ: " + FUSION_NAMES[pair_key(selected_elements[0], selected_elements[1])] if two else "В онлайне союзник выбирает свой элемент."
		)
		column.add_child(picker)
	combo.text = "СЛИЯНИЕ: " + FUSION_NAMES[pair_key(selected_elements[0], selected_elements[1])] if two else "В онлайне союзник выбирает свой элемент."

func show_mode_menu(two_players: bool) -> void:
	var box := create_menu_card(620)
	make_label(box, "2 PLAYER" if two_players else "1 PLAYER", 38, Color("#e6cb59"))
	add_element_choices(box, true)
	if two_players:
		make_button(box, "1v1 · ДРУГ ПРОТИВ ДРУГА", func(): start_offline("duel_local"))
		make_button(box, "2v2 · ВДВОЁМ ПРОТИВ БОТОВ", func(): start_offline("squad_coop"))
		make_label(box, "P1: WASD / ЛКМ / Q\nP2: стрелки / Enter / правый Shift", 15, MUTED)
	else:
		make_button(box, "1v1 · ПРОТИВ БОТА", func(): start_offline("duel_bot"))
		make_button(box, "2v2 · С СОЮЗНИКОМ-БОТОМ", func(): start_offline("squad_bot"))
		make_label(box, "Коснись союзника → общий заряд ульты.\nПосле применения разойдитесь и соединитесь снова.", 14, MUTED)
	make_button(box, "НАЗАД", show_main_menu)

func show_online_menu(message: String = "") -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(680)
	make_label(box, "ONLINE · 2V2", 35, Color("#e6cb59"))
	make_label(box, "До четырёх игроков. Свободные места займут боты.", 15, MUTED)
	add_element_choices(box, false)
	var row := HBoxContainer.new()
	box.add_child(row)
	address_field = LineEdit.new()
	address_field.text = "127.0.0.1"
	address_field.placeholder_text = "IP хоста"
	address_field.custom_minimum_size = Vector2(440, 40)
	row.add_child(address_field)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = DEFAULT_PORT
	row.add_child(port_field)
	host_button = make_button(box, "СОЗДАТЬ ЛОББИ", func(): start_host(int(port_field.value)))
	join_button = make_button(box, "ПОДКЛЮЧИТЬСЯ", func(): start_join(address_field.text, int(port_field.value)))
	start_online_button = make_button(box, "НАЧАТЬ 2V2", start_online_round)
	start_online_button.disabled = true
	status_label = make_label(box, message, 13, BLUE)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(600, 58)
	var help := make_label(box, "Один Wi-Fi: локальный IP хоста. Через интернет: доступный внешний IP и UDP-порт 24567. 127.0.0.1 работает только на одном компьютере.", 12, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 600
	make_button(box, "НАЗАД / ОТМЕНИТЬ", show_main_menu)

func set_connection_busy(busy: bool) -> void:
	super.set_connection_busy(busy)
	for picker in menu.find_children("*", "OptionButton", true, false):
		picker.disabled = busy

func start_host(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 3, 2)
	if err != OK:
		status_label.text = "Порт занят или недоступен. Выбери другой UDP-порт."
		return
	multiplayer.multiplayer_peer = peer
	state = "hosting"
	lobby_port = port
	roster = {1: {"slot": 0, "element": selected_elements[0]}}
	set_connection_busy(true)
	update_lobby()

func start_join(address: String, port: int = DEFAULT_PORT) -> void:
	address = address.strip_edges()
	if address.is_empty() or port < 1024 or port > 65535:
		status_label.text = "Введи IP хоста и корректный порт."
		return
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port, 2) != OK:
		status_label.text = "Не удалось начать подключение."
		return
	multiplayer.multiplayer_peer = peer
	state = "joining"
	join_deadline = Time.get_ticks_msec() + 12000
	set_connection_busy(true)
	status_label.text = "Подключение к " + address + "…"

func _on_peer_connected(_peer_id: int) -> void:
	pass

func _on_connected() -> void:
	if state == "joining": net_hello.rpc_id(1, NET_VERSION, selected_elements[0])

@rpc("any_peer", "call_remote", "reliable")
func net_hello(version: int, element: int) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if version != NET_VERSION or state != "hosting" or element < 0 or element >= ELEMENT_NAMES.size():
		net_reject.rpc_id(sender, "Версия не совпадает или матч уже начался. Используйте одинаковую сборку.")
		return
	if roster.has(sender): return
	var occupied: Array = roster.values().map(func(p): return int(p.slot))
	for slot in [2, 1, 3]:
		if slot not in occupied:
			roster[sender] = {"slot": slot, "element": element}
			update_lobby()
			return
	net_reject.rpc_id(sender, "Лобби заполнено.")

func update_lobby() -> void:
	var addresses := PackedStringArray()
	for ip in IP.get_local_addresses():
		if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			addresses.append(ip)
	var message := "Игроков: %d/4 · UDP %d\nIP хоста: %s\nХост может начать матч после подключения друга." % [roster.size(), lobby_port, ", ".join(addresses)]
	if is_instance_valid(status_label): status_label.text = message
	if is_instance_valid(start_online_button): start_online_button.disabled = roster.size() < 2
	for peer in roster:
		if int(peer) != 1: net_lobby.rpc_id(int(peer), roster, message)

@rpc("authority", "call_remote", "reliable")
func net_lobby(new_roster: Dictionary, message: String) -> void:
	if multiplayer.is_server(): return
	roster = new_roster
	state = "lobby"
	join_deadline = 0
	local_slot = int(roster[multiplayer.get_unique_id()].slot)
	status_label.text = message

func start_online_round() -> void:
	if not multiplayer.is_server() or roster.size() < 2: return
	online_active = true
	local_slot = 0
	net_inputs.clear()
	var epoch := match_id + 1
	begin_match("squad_net", epoch)
	for peer in roster:
		if int(peer) != 1: net_begin.rpc_id(int(peer), epoch, roster)

@rpc("authority", "call_remote", "reliable")
func net_begin(epoch: int, new_roster: Dictionary) -> void:
	if multiplayer.is_server(): return
	roster = new_roster
	online_active = true
	local_slot = int(roster[multiplayer.get_unique_id()].slot)
	input_serial = 0
	ultimate_serial = 0
	net_visible = [true, true, true, true]
	begin_match("squad_net", epoch)

func configure_match_player(player, index: int, mode: String) -> void:
	if mode != "squad_net": return
	var peer_id: int = 0
	for peer in roster:
		if int(roster[peer].slot) == index:
			peer_id = int(peer)
			player.element = int(roster[peer].element)
	player.set_meta("peer_id", peer_id)
	player.bot = peer_id == 0
	player.human_index = 0 if peer_id == multiplayer.get_unique_id() else -1
	player.simulation_authority = multiplayer.is_server()
	player.player_name = ("БОТ" if player.bot else "P%d" % (index + 1)) + " · " + ELEMENT_NAMES[player.element]

func begin_match(mode: String, epoch: int) -> void:
	super.begin_match(mode, epoch)
	send_clock = 0
	if mode == "squad_net":
		for label in match_ui.find_children("*", "Label", true, false):
			if label.text.begins_with("P1:"):
				label.text = "ONLINE 2V2 · ТЫ P%d · WASD / ЛКМ / SPACE / Q" % (local_slot + 1)

func control_human(player) -> void:
	if not online_active or int(player.get_meta("peer_id", 0)) == multiplayer.get_unique_id():
		super.control_human(player)
		return
	var data: Dictionary = net_inputs.get(int(player.get_meta("peer_id", 0)), {})
	if not data.is_empty() and Time.get_ticks_msec() - int(data.time) < 400:
		player.move_intent = data.direction
		player.attack_intent = data.attack
		player.aim_direction = data.aim

func _physics_process(delta: float) -> void:
	if state == "joining" and join_deadline > 0 and Time.get_ticks_msec() > join_deadline:
		close_and_show_online("Хост не отвечает. Проверь IP и UDP-порт.")
		return
	if not online_active:
		super._physics_process(delta)
		return
	if multiplayer.is_server():
		super._physics_process(delta)
		send_clock += delta
		if send_clock >= 0.05 and (state == "offline" or state == "result"):
			send_clock = 0
			for peer in roster:
				if int(peer) != 1: net_state.rpc_id(int(peer), match_id, var_to_bytes(snapshot_for(int(peer))).compress(FileAccess.COMPRESSION_DEFLATE))
	else:
		if state != "offline" or players.size() != 4: return
		elapsed += delta
		time_left = maxf(0, time_left - delta)
		countdown = maxf(0, countdown - delta)
		countdown_label.text = str(ceili(countdown)) if countdown > 0 else ""
		for shot in projectiles: shot.pos += shot.vel * delta
		for zone in zones: zone.age += delta
		if get("floods") != null:
			for flood in get("floods"):
				flood.life = maxf(0, flood.life - delta)
				flood.age += delta
		for fx in effects: fx.life = maxf(0, fx.life - delta)
		var player = players[local_slot]
		control_human(player)
		send_clock += delta
		if send_clock >= 1.0 / 30:
			send_clock = 0
			input_serial += 1
			net_input.rpc_id(1, match_id, input_serial, player.move_intent, player.aim_direction, player.attack_intent, ultimate_serial)
		update_flag_ui()
		update_fusion_ui()

func cast_ultimate(player) -> bool:
	if online_active and not multiplayer.is_server():
		if player != players[local_slot] or player.is_dead: return false
		ultimate_serial += 1
		return true
	return super.cast_ultimate(player)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func net_input(epoch: int, sequence: int, direction: Vector2, aim: Vector2, attack: bool, ultimate: int) -> void:
	if not online_active or not multiplayer.is_server() or state != "offline" or epoch != match_id: return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 1 or not roster.has(sender) or not direction.is_finite() or not aim.is_finite(): return
	var old: Dictionary = net_inputs.get(sender, {"sequence": -1, "ultimate": 0})
	if sequence <= int(old.sequence): return
	var slot: int = roster[sender].slot
	players[slot].aim_direction = aim.limit_length()
	net_inputs[sender] = {"sequence": sequence, "ultimate": maxi(ultimate, int(old.ultimate)), "direction": direction.limit_length(), "aim": aim.limit_length(), "attack": attack, "time": Time.get_ticks_msec()}
	if ultimate > int(old.ultimate): cast_ultimate(players[slot])

func snapshot_for(peer: int) -> Dictionary:
	var team := int(roster[peer].slot) / 2
	var fighters: Array = []
	for player in players:
		var visible := super.is_visible_to(player, team)
		var data: Dictionary = player.network_state() if visible else {"hidden": true}
		data["hidden"] = not visible
		data["bot"] = player.bot
		data["aim"] = player.aim_direction if visible else Vector2.ZERO
		data["revealed"] = maxf(0, float(reveals.get("%d:%d" % [team, player.get_instance_id()], 0)) - elapsed)
		fighters.append(data)
	var zone_data: Array = []
	for zone in zones:
		var copy: Dictionary = zone.duplicate()
		copy.erase("hits")
		zone_data.append(copy)
	return {"fighters": fighters, "elapsed": elapsed, "time": time_left, "countdown": countdown, "phase": flag_phase, "owner": flag_owner, "shield": flag_shield, "builder": builder, "progress": build_progress, "mobs": mobs, "shots": projectiles, "zones": zone_data, "effects": effects, "fusion": fusion, "scores": scores, "finished": state == "result"}

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func net_state(epoch: int, packed: PackedByteArray) -> void:
	if not online_active or multiplayer.is_server() or epoch != match_id or players.size() != 4: return
	var raw := packed.decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var decoded = bytes_to_var(raw)
	if not decoded is Dictionary: return
	var data: Dictionary = decoded
	apply_remote_snapshot(data)

func apply_remote_snapshot(data: Dictionary) -> void:
	if not data.has("fighters") or not data.fighters is Array or data.fighters.size() != 4 or players.size() != 4: return
	elapsed = data.elapsed
	time_left = data.time
	countdown = data.countdown
	flag_phase = data.phase
	flag_owner = data.owner
	flag_shield = data.shield
	builder = data.builder
	build_progress = data.progress
	mobs.assign(data.mobs)
	projectiles.assign(data.shots)
	zones.assign(data.zones)
	if get("floods") != null: get("floods").assign(data.get("floods", []))
	if get("combat_visuals") != null: get("combat_visuals").assign(data.get("combat_visuals", []))
	effects.assign(data.effects)
	fusion.assign(data.fusion)
	if get("team_ult_next") != null:
		var wait: Array = data.get("ult_wait", [0.0, 0.0])
		for team in range(2): get("team_ult_next")[team] = elapsed + float(wait[team])
	scores.assign(data.scores)
	for index in range(4):
		var player = players[index]
		var actor: Dictionary = data.fighters[index]
		net_visible[index] = not actor.hidden
		player.bot = actor.bot
		if not actor.hidden:
			player.apply_network_state(actor)
			player.aim_direction = actor.aim
		var team: int = players[local_slot].team
		reveals["%d:%d" % [team, player.get_instance_id()]] = elapsed + float(actor.revealed)
	update_flag_ui()
	update_fusion_ui()
	if data.finished and state == "offline":
		finish_flag_match()
		for button in menu.find_children("*", "Button", true, false):
			if button.text == "ЕЩЁ МАТЧ":
				button.text = "РЕВАНШ ЗАПУСКАЕТ ХОСТ"
				button.disabled = true

func is_visible_to(target, team: int) -> bool:
	if online_active and not multiplayer.is_server():
		var index := players.find(target)
		return index >= 0 and net_visible[index]
	return super.is_visible_to(target, team)

func start_offline(mode: String) -> void:
	if mode == "squad_net":
		if multiplayer.is_server(): start_online_round()
		return
	super.start_offline(mode)

func _on_peer_disconnected(peer: int) -> void:
	if not multiplayer.is_server() or not roster.has(peer): return
	var slot: int = roster[peer].slot
	roster.erase(peer)
	net_inputs.erase(peer)
	if online_active and players.size() == 4:
		players[slot].bot = true
		players[slot].human_index = -1
		players[slot].set_meta("peer_id", 0)
		add_effect(players[slot].position, WHITE, 35, "ИГРОКА ЗАМЕНИЛ БОТ")
	elif state == "hosting":
		update_lobby()

func _on_server_disconnected() -> void:
	if online_active or state in ["joining", "lobby"]:
		call_deferred("close_and_show_online", "Связь с хостом потеряна. Можно подключиться снова.")

@rpc("authority", "call_remote", "reliable")
func net_reject(message: String) -> void:
	call_deferred("close_and_show_online", message)
