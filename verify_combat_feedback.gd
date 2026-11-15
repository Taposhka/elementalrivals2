extends SceneTree

var arena
var failures: int = 0
var rendered: bool = false

func _initialize() -> void:
	rendered = "--screenshots" in OS.get_cmdline_user_args()
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func prepare(player, point: Vector2) -> void:
	player.respawn()
	player.position = point
	player.invincible_time = 0
	player.respawn_time = 99
	player.attack_intent = false
	player.move_intent = Vector2.ZERO
	player.set_physics_process(false)

func kill(actor: int, victim: int, clock: float) -> void:
	arena.elapsed = clock
	prepare(arena.players[victim],Vector2(750,800))
	arena.receive_damage(arena.players[victim],100,arena.players[actor].team,actor)

func last_kill() -> Dictionary:
	var kills = arena.combat_events.filter(func(event): return event.type == "kill")
	return kills[-1] if not kills.is_empty() else {}

func capture(name: String) -> void:
	if not rendered: return
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/combat_" + name + ".png")

func run_checks() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.selected_elements.assign([0,1])
	arena.start_offline("squad_bot")
	await process_frame
	arena.set_physics_process(false)
	arena.ai_enabled = false
	arena.countdown = 0
	arena.countdown_label.text = ""
	arena.mobs.clear()
	for player in arena.players: prepare(player,Vector2(600+player.get_index()*70,800))
	check(arena.sound_bank.streams.size() == 16,"all prepared SFX load")
	for stream in arena.sound_bank.streams.values():
		check(stream != null and stream.get_length() > 0 and stream.get_length() <= 2.0,"short valid audio clips")
	check(arena.players[0].base_move_speed == 220 and arena.players[0].energy_regen_per_second == 28,"faster movement and energy recovery")
	kill(0,2,1)
	check(last_kill().title == "FIRST BLOOD","first blood")
	kill(0,3,2)
	check(last_kill().title == "DOUBLE KILL" and arena.chains[0] == 2,"double kill")
	kill(0,2,3)
	check(last_kill().title == "TRIPLE KILL","triple kill after respawn")
	check(arena.announcer.active_title == "TRIPLE KILL","WOW announcer upgrades without stacking")
	await capture("triple")
	if rendered:
		root.size = Vector2i(720,1280)
		arena.touch_override = 1
		arena.configure_scale()
		for frame in range(8): await process_frame
		arena.refresh_layout()
		arena.announcer.reset()
		arena.announcer.present(last_kill())
		await capture("phone_combo")
		root.size = Vector2i(1280,720)
		arena.touch_override = 0
		arena.configure_scale()
		for frame in range(8): await process_frame
		arena.refresh_layout()
	kill(0,3,4)
	check(last_kill().title == "QUADRA KILL","quadra kill")
	kill(2,0,5)
	check(last_kill().title == "SHUTDOWN" and arena.streaks[0] == 0,"shutdown ends a streak")
	arena.announcer.reset()
	arena.announcer.present(last_kill())
	await capture("shutdown")
	kill(2,0,20)
	check(last_kill().chain == 1,"multi-kill window expires")
	kill(2,1,30)
	check(last_kill().title == "KILLING SPREE","persistent kill streak")
	var count: int = arena.kill_count
	prepare(arena.players[0],Vector2(600,800))
	arena.receive_damage(arena.players[0],100,-1)
	check(arena.kill_count == count,"environment death does not inherit previous-life credit")
	prepare(arena.players[1],Vector2(600,800))
	arena.receive_damage(arena.players[1],100,0,0)
	check(arena.players[1].hp == 100,"friendly damage blocked centrally")
	var attacker = arena.players[0]
	prepare(attacker,Vector2(600,800))
	attacker.element = 3
	attacker.apply_element_profile()
	attacker.aim_direction = Vector2.RIGHT
	prepare(arena.players[2],Vector2(720,800))
	arena.players[2].hp = 29
	arena.projectiles.clear()
	arena.spawn_projectile(attacker,false)
	check(arena.projectiles[0].owner == 0,"projectile owner attached")
	arena.update_projectiles(0.2)
	check(last_kill().actor == 0 and arena.players[2].is_dead,"projectile kill attribution")
	prepare(arena.players[2],Vector2(750,800))
	arena.players[2].hp = 6
	arena.active_actor = 0
	arena.zones.clear()
	var zone: Dictionary = arena.create_spell([0,2],0,Vector2(750,800),Vector2.RIGHT)
	arena.active_actor = -1
	zone.age = 0.6
	arena.update_zones(0.01)
	check(arena.players[2].is_dead and last_kill().actor == 0,"zone kill attribution")
	var crystal = load("res://crystal_volcano_art.gd")
	check(crystal.REGIONS.size() == 6 and crystal.frame_index(0.24) == 2,"six Crystal Volcano frames")
	if rendered:
		arena.announcer.reset()
		zone.age = zone.warning+0.24
		await capture("crystal_volcano")
	prepare(arena.players[2],Vector2(750,800))
	arena.players[2].hp = 4
	arena.floods.clear()
	arena.on_projectile_impact({"element":1,"ultimate":false,"team":0,"owner":0},Vector2(750,800),"player")
	arena.update_floods(0.7)
	check(arena.players[2].is_dead and last_kill().actor == 0,"flood kill attribution")
	prepare(arena.players[2],Vector2(750,800))
	prepare(arena.players[3],Vector2(780,800))
	arena.players[2].applied_element = 1
	arena.players[2].element_time = 3
	arena.players[3].hp = 10
	arena.projectile_element_hit(arena.players[2],{"element":3,"damage":29,"team":0,"owner":0,"vel":Vector2.RIGHT})
	check(arena.players[3].is_dead and last_kill().actor == 0,"reaction-chain kill attribution")
	prepare(attacker,Vector2(600,800))
	attacker.element = 0
	attacker.apply_element_profile()
	attacker.aim_direction = Vector2.RIGHT
	prepare(arena.players[3],Vector2(645,800))
	arena.players[3].hp = 34
	attacker.start_attack()
	attacker._physics_process(0.12)
	check(arena.players[3].is_dead and last_kill().actor == 0,"fire dash kill attribution")
	arena.roster = {99:{"slot":0,"element":3}}
	var data: Dictionary = arena.snapshot_for(99)
	check(data.has("combat_events") and data.combat_events.size() <= 96,"bounded replicated combat events")
	arena.last_remote_event = 0
	arena.apply_remote_snapshot(data)
	var pending: int = arena.announcer.pending.size()
	var seen: int = arena.last_remote_event
	arena.apply_remote_snapshot(data)
	check(arena.last_remote_event == seen and arena.announcer.pending.size() == pending,"snapshots do not replay announcers")
	var art = load("res://element_art.gd")
	check(art.texture_for(0).atlas.resource_path.ends_with("element_fire.png"),"fire icon mapping")
	check(art.texture_for(1).atlas.resource_path.ends_with("element_water.png"),"water icon mapping")
	check(art.texture_for(2).atlas.resource_path.ends_with("element_ice.png"),"ice icon mapping")
	check(art.texture_for(3) == null,"clean existing lightning retained")
	arena.show_main_menu()
	arena.show_mode_menu(false)
	await capture("icons")
	arena.show_main_menu()
	await process_frame
	print("COMBAT FEEDBACK CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
