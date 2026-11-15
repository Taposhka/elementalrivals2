extends SceneTree

var arena
var hosting: bool = false
var started: bool = false
var done: bool = false
var clock: float = 0.0
var saw_touch_input: bool = false

func _initialize() -> void:
	hosting = "--host" in OS.get_cmdline_user_args()
	call_deferred("start")

func start() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	arena.selected_elements[0] = 1 if hosting else 4
	arena.show_online_menu()
	if hosting: arena.start_host(25489)
	else: arena.start_join("127.0.0.1", 25489)

func _process(delta: float) -> bool:
	clock += delta
	if clock > 12.0:
		push_error("Network role verification timed out")
		quit(1)
	if arena == null or done: return false
	if hosting:
		if not started and arena.roster.size() == 2:
			started = true
			arena.start_online_round()
		if started and arena.state == "offline" and arena.countdown <= 0:
			arena.add_flood(arena.FLAG_POSITION, 0)
			arena.players[2].combo_stage = 2
			arena.players[2].combo_time = 0.9
			arena.team_ult_next[1] = arena.elapsed + 4.0
			for data in arena.net_inputs.values():
				if Vector2(data.direction).x > 0.5 and data.attack: saw_touch_input = true
			if clock > 7:
				if not saw_touch_input:
					push_error("Remote touch controls did not reach host")
					quit(1)
					return false
				print("HOST ROLE NETWORK CHECK: passed")
				arena.stop_network()
				quit(0)
	elif arena.state == "offline":
		arena.touch_override = 1
		arena.touch_controls.move_vector = Vector2(0.75, 0)
		arena.touch_controls.aim_vector = Vector2.RIGHT
		arena.touch_controls.firing = true
		if clock > 4.5 and not arena.floods.is_empty() and arena.players[2].combo_stage == 2 and arena.players[2].combo_time > 0 and arena.team_ult_next[1] - arena.elapsed > 3:
			done = true
			print("CLIENT ROLE NETWORK CHECK: floods and wind combo replicated")
			arena.stop_network()
			quit(0)
	return false
