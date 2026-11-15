extends SceneTree

var clients: Array = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	for index in range(2):
		var arena = load("res://flag_demo.tscn").instantiate()
		root.add_child(arena)
		arena.show_online_menu()
		clients.append(arena)
	var until := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<until and not clients.all(func(client): return client.announcer.active_title == "DOUBLE KILL"):
		await create_timer(0.02,true).timeout
	if not clients.all(func(client): return client.announcer.active_title == "DOUBLE KILL"):
		push_error("Remote clients did not receive the combo")
		quit(1)
		return
	await create_timer(0.5,true).timeout
	if not clients.all(func(client): return client.announcer.age > 0.4):
		push_error("Repeated snapshots replayed the combo animation")
		quit(1)
		return
	for client in clients: client.show_main_menu()
	await process_frame
	print("REMOTE COMBO FEEDBACK: 0 failures")
	quit(0)
