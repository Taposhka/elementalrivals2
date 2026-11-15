extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.start_practice()
	var target = arena.players[2]
	target.respawn_time = 0.1
	for cycle in range(3):
		arena.receive_damage(target,1000,0,0)
		assert(target.is_dead,"Practice target must die every time")
		await create_timer(0.15).timeout
		assert(not target.is_dead and target.hp == target.max_hp,"Practice target must respawn")
		assert(target.invincible_time == 0,"Practice targets must remain vulnerable")
	assert(arena.kill_count == 3,"Repeated training kills must count")
	print("PRACTICE RESPAWN: 3 repeated kills passed")
	quit()
