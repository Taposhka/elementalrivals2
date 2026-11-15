extends SceneTree

var failures: int = 0
var clients: Array = []
var deadline: int = 0

func _initialize() -> void:
	deadline = Time.get_ticks_msec() + 35000
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func make_client(element: int):
	var arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	arena.selected_elements[0] = element
	arena.touch_override = 1
	arena.show_online_menu()
	clients.append(arena)
	return arena

func wait_until(condition: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < until:
		await create_timer(0.05, true).timeout
	return condition.call()

func run_checks() -> void:
	var first = make_client(4)
	var second = make_client(3)
	await wait_until(func(): return first.service_connected, 3)
	first.selected_elements[0] = 0
	check(first.menu.find_children("*", "LineEdit", true, false).is_empty(), "no IP fields")
	check(await wait_until(func(): return first.service_match and second.service_match, 10), "automatic two-player matchmaking")
	if not first.service_match or not second.service_match:
		quit(1)
		return
	check(first.match_id == second.match_id, "same room")
	check(first.local_slot != second.local_slot and first.local_slot / 2 != second.local_slot / 2, "opposing teams")
	check(first.players.count(null) == 0 and first.players.size() == 4, "complete match")
	check(first.players.filter(func(player): return player.bot).size() == 2, "empty slots filled with bots")
	check(first.players.all(func(player): return not player.simulation_authority), "server authoritative clients")
	check(first.players[second.local_slot].element == 3, "selected elements replicated")
	check(first.players[first.local_slot].element == 0, "element changes during search")
	await wait_until(func(): return first.countdown <= 0, 4)
	var x: float = first.players[first.local_slot].position.x
	first.touch_controls.move_vector = Vector2.RIGHT
	first.touch_controls.aim_vector = Vector2.RIGHT
	first.touch_controls.firing = true
	first.service_send({"type": "input", "sequence": 100000, "move": [1,0,1], "aim": [1,0], "attack": true})
	await create_timer(0.8, true).timeout
	check(first.players[first.local_slot].position.x > x + 35, "input reaches authoritative server")
	check(first.input_serial > 10, "input streaming")
	check(first.last_remote_event > 0,"combat SFX events replicated to clients")
	first.touch_controls.move_vector = Vector2.ZERO
	first.touch_controls.firing = false
	var departed_slot: int = second.local_slot
	second.show_main_menu()
	check(await wait_until(func(): return first.players[departed_slot].bot, 2), "disconnect replaced by bot")
	var cancelled = make_client(1)
	await create_timer(0.5, true).timeout
	cancelled.show_main_menu()
	check(not cancelled.service_active and cancelled.service_socket == null, "cancel closes socket")
	var third = make_client(2)
	var fourth = make_client(4)
	check(await wait_until(func(): return third.service_match and fourth.service_match, 10), "next room starts")
	check(third.match_id != first.match_id, "rooms remain independent")
	var group: Array = []
	for element in range(4): group.append(make_client(element))
	check(await wait_until(func(): return group.all(func(client): return client.service_match), 5), "full four-player room starts immediately")
	if group.all(func(client): return client.service_match):
		check(group.all(func(client): return client.match_id == group[0].match_id), "four players share a room")
		check(group[0].players.filter(func(player): return player.bot).is_empty(), "no bots in full room")
		var assigned: Array = group.map(func(client): return client.local_slot)
		assigned.sort()
		check(assigned == [0,1,2,3], "four unique assigned slots")
	for client in clients:
		client.show_main_menu()
		client.queue_free()
	await process_frame
	print("MATCHMAKING CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline:
		push_error("Matchmaking test timed out")
		quit(1)
	return false
