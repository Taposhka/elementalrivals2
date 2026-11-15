extends SceneTree

var arena
var failures: int = 0
var screenshots: bool = false

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _initialize() -> void:
	screenshots = "--screenshots" in OS.get_cmdline_user_args()
	call_deferred("run_checks")

func settle() -> void:
	for i in range(5): await process_frame

func capture(file: String) -> void:
	if screenshots:
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("res://qa/qa_" + file + ".png")

func run_checks() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await settle()
	check(arena.options.size() == 7, "settings loaded")
	await capture("menu")
	arena.open_overlay("settings")
	await settle()
	check(is_instance_valid(arena.overlay_panel), "settings panel")
	await capture("settings")
	arena.open_overlay("codex")
	await settle()
	check(arena.overlay_panel.find_children("*", "GridContainer", true, false)[0].get_child_count() == 15, "all 15 fusion cards")
	await capture("codex")
	arena.close_overlay()
	arena.selected_elements.assign([0, 3])
	arena.start_offline("squad_bot")
	await settle()
	arena.ai_enabled = false
	arena.countdown = 0
	check(arena.players.size() == 4, "four fighters spawned")
	for player in arena.players: player.set_physics_process(false)
	arena.set_physics_process(false)
	var cast_pos: Vector2 = arena.players[0].position + Vector2(180, -100)
	for a in range(5):
		for b in range(a, 5):
			arena.zones.clear()
			var zone: Dictionary = arena.create_spell([a, b], 0, cast_pos, Vector2.RIGHT)
			check(zone.key == arena.pair_key(a, b), "recipe lookup")
			check(arena.spell_contains(zone, cast_pos), "spell centre covered")
			zone.age = 1.1
			zone.pulse = 0.2
			await settle()
			if a != b: await capture("fusion_%d_%d" % [a,b])
			arena.update_zones(0.1)

	arena.zones.clear()
	var target = arena.players[2]
	target.position = Vector2(900, 500)
	target.invincible_time = 0
	target.hp = 100
	var zone: Dictionary = arena.create_spell([1,2], 0, Vector2(900, 500), Vector2.RIGHT)
	zone.age = 0.6
	arena.update_zones(0.01)
	var hp: float = target.hp
	check(hp == 66, "frozen wave damage")
	check(target.slow_time > 2, "frozen wave chill")
	check(target.push_velocity.x > 0, "wave pushes in travel direction")
	check(arena.players[0].hp == 100, "no friendly fire")
	arena.update_zones(0.11)
	check(target.hp == hp, "wave hits each fighter once")
	check(Vector2(zone.pos).x > 900, "wave travels")

	arena.zones.clear()
	arena.fusion[0].ready = true
	arena.fusion[0].pair = [0,3]
	check(arena.cast_ultimate(arena.players[0]), "charged cast")
	check(not arena.fusion[0].ready, "shared charge consumed")
	check(not arena.cast_ultimate(arena.players[1]), "second ally cannot spend consumed charge")
	arena.open_overlay("pause")
	var before: float = arena.time_left
	await create_timer(0.12, true).timeout
	check(paused and arena.time_left == before, "offline pause")
	arena.close_overlay()
	check(not paused, "resume")

	arena.online_active = true
	arena.open_overlay("settings")
	check(not paused, "online menu keeps network alive")
	arena.close_overlay()
	arena.online_active = false

	var original: Dictionary = arena.options.duplicate()
	arena.options.camera_smoothing = false
	arena.save_options()
	var config := ConfigFile.new()
	check(config.load(arena.SETTINGS_PATH) == OK, "settings file saved")
	check(config.get_value("settings", "camera_smoothing") == false, "setting persists")
	arena.options = original
	arena.save_options()
	arena.show_main_menu()
	await settle()
	arena.open_overlay("codex")
	await settle()
	var recipes = arena.overlay_panel.find_children("*", "GridContainer", true, false)[0]
	check(recipes.get_child_count() == 15, "all recipes have practice actions")
	recipes.get_child(1).get_child(0).pressed.emit()
	await settle()
	check(arena.practice and not arena.ai_enabled and arena.fusion[0].ready, "practice ready")
	check(arena.selected_elements == [0, 1], "practice button selects its exact recipe")
	arena.show_main_menu()
	await settle()
	print("UPGRADE CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
