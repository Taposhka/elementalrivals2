extends "res://combat_arena.gd"

func _ready() -> void:
	process_physics_priority = -20
	var data: Dictionary = BRUSH_MASK.DATA
	brush_cells.resize(int(data.width) * int(data.height))
	brush_cells.fill(-1)
	for run in data.runs:
		for x in range(int(run[1]), int(run[2])):
			brush_cells[int(run[0]) * int(data.width) + x] = int(run[3])
	ui = Control.new()
	add_child(ui)

func configure_match_player(player, index: int, _mode: String) -> void:
	var peer_id: int = 0
	for peer in roster:
		if int(roster[peer].slot) == index:
			peer_id = int(peer)
			player.element = int(roster[peer].element)
	player.set_meta("peer_id", peer_id)
	player.bot = peer_id == 0
	player.human_index = -1
	player.simulation_authority = true
	player.player_name = ""

func create_match_ui() -> void:
	for player in players: player.hud.hide()
	score_label = Label.new()
	countdown_label = Label.new()
	flag_label = Label.new()
	flag_banner = Label.new()
	for label in [score_label, countdown_label, flag_label, flag_banner]:
		match_ui.add_child(label)
		label.hide()

func layout_match() -> void:
	pass

func control_human(player) -> void:
	player.move_intent = Vector2.ZERO
	player.attack_intent = false
	var data: Dictionary = net_inputs.get(int(player.get_meta("peer_id", 0)), {})
	if not data.is_empty() and Time.get_ticks_msec() - int(data.time) < 500:
		player.move_intent = data.direction
		player.aim_direction = data.aim
		player.attack_intent = data.attack

func finish_flag_match() -> void:
	if state != "offline": return
	winner_team = flag_owner if flag_phase == "owned" and flag_shield > 0 else -1
	state = "result"
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.set_physics_process(false)

func accept_player_input(peer_id: int, data: Dictionary) -> void:
	if state != "offline" or not roster.has(peer_id): return
	var old: Dictionary = net_inputs.get(peer_id, {"sequence": -1, "ultimate": 0})
	if not (data.get("sequence") is float or data.get("sequence") is int): return
	if not (data.get("ultimate", 0) is float or data.get("ultimate", 0) is int): return
	var sequence := int(data.get("sequence", -1))
	if sequence <= int(old.sequence) or sequence > 2147483647: return
	var move_data = data.get("move", [])
	var aim_data = data.get("aim", [])
	if not move_data is Array or not aim_data is Array or move_data.size() != 2 or aim_data.size() != 2: return
	for value in move_data + aim_data:
		if not (value is int or value is float) or not is_finite(float(value)): return
	var direction := Vector2(float(move_data[0]), float(move_data[1])).limit_length()
	var aim := Vector2(float(aim_data[0]), float(aim_data[1])).limit_length()
	var ultimate := clampi(int(data.get("ultimate", 0)), 0, 2147483647)
	net_inputs[peer_id] = {"sequence": sequence, "ultimate": maxi(ultimate, int(old.ultimate)), "direction": direction, "aim": aim, "attack": data.get("attack", false) == true, "time": Time.get_ticks_msec()}
	var player = players[int(roster[peer_id].slot)]
	if aim.length_squared() > 0.01: player.aim_direction = aim.normalized()
	if ultimate > int(old.ultimate): cast_ultimate(player)

func leave(peer_id: int) -> void:
	if not roster.has(peer_id): return
	var player = players[int(roster[peer_id].slot)]
	player.bot = true
	player.human_index = -1
	player.set_meta("peer_id", 0)
	roster.erase(peer_id)
	net_inputs.erase(peer_id)
