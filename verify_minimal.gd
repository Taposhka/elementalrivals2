extends SceneTree

var arena
var failures: int = 0
var rendered: bool = false
var original_touch: int = 0

func _initialize() -> void:
	rendered = "--screenshots" in OS.get_cmdline_user_args()
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("CHECK FAILED: " + message)

func settle() -> void:
	for index in range(8): await process_frame

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/minimal_" + name + ".png")

func resize_case(size: Vector2i) -> void:
	root.size = size
	arena.configure_scale()
	await settle()
	arena.refresh_layout()
	await settle()

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	arena.touch_controls._input(event)

func drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	arena.touch_controls._input(event)

func run_checks() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await settle()
	original_touch = arena.touch_override
	await capture("menu")
	check(arena.menu.find_children("*", "TextureButton", true, false).is_empty(), "old image menu removed")
	check(arena.menu.find_children("*", "Label", true, false).size() == 1, "only title on main menu")
	var menu_scroll = arena.menu.find_children("*", "ScrollContainer", true, false)[0]
	check(menu_scroll.size.y > 300, "menu content is visible")
	arena.show_mode_menu(false)
	await settle()
	await capture("loadout")
	for button in arena.menu.find_children("*", "Button", true, false):
		check(button.size.y >= 60, "touch sized menu targets")
	arena.start_offline("squad_bot")
	await settle()
	arena.countdown = 0
	arena.countdown_label.text = ""
	arena.ai_enabled = false
	arena.set_physics_process(false)
	for player in arena.players:
		player.set_physics_process(false)
		player.position = arena.FLAG_POSITION + Vector2(-240 + player.get_index() * 120, 150)
		player.invincible_time = 0
	check(arena.players.all(func(player): return not player.hud.visible), "global HUD hidden")
	check(arena.fusion_labels.is_empty(), "fusion paragraphs removed")
	for window_size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(1600,720), Vector2i(720,1280), Vector2i(1024,768)]:
		await resize_case(window_size)
		var area: Vector2 = arena.get_viewport_rect().size
		check(arena.views[0].container.position == Vector2.ZERO, "arena begins at screen origin")
		check(arena.views[0].container.size.is_equal_approx(area), "arena fills screen")
		check(arena.views[0].camera.zoom.x >= 1, "camera avoids outside-map margins")
		check(Rect2(Vector2.ZERO, area).encloses(arena.pause_button.get_global_rect()), "pause button inside screen")
		arena.touch_override = 1
		await settle()
		await capture("match_%d_%d" % [window_size.x, window_size.y])
	await resize_case(Vector2i(1280,720))
	await create_timer(0.18, true).timeout
	arena.touch_override = 1
	var player = arena.players[0]
	var area: Vector2 = arena.get_viewport_rect().size
	var left := Vector2(150, area.y - 120)
	var right := Vector2(area.x - 150, area.y - 120)
	touch(10, left, true)
	drag(10, left + Vector2(50, 0))
	touch(11, right, true)
	drag(11, right + Vector2(0, -50))
	arena.control_human(player)
	check(player.move_intent.x > 0.5 and player.attack_intent, "simultaneous move and attack")
	check(player.aim_direction.y < -0.9, "independent touch aim")
	touch(10, left, false)
	arena.control_human(player)
	check(player.move_intent == Vector2.ZERO and player.attack_intent, "left release preserves right stick")
	arena.open_overlay("pause")
	check(paused and not arena.touch_controls.firing and arena.touch_controls.move_vector == Vector2.ZERO, "pause clears touch input")
	await settle()
	await capture("pause")
	arena.open_overlay("settings")
	await settle()
	await capture("settings")
	arena.close_overlay()
	check(not paused, "resume")
	arena.online_active = true
	player.set_meta("peer_id", arena.multiplayer.get_unique_id())
	var remote = arena.players[2]
	remote.set_meta("peer_id", 42)
	arena.net_inputs[42] = {"direction": Vector2.RIGHT, "aim": Vector2.LEFT, "attack": true, "time": Time.get_ticks_msec()}
	arena.open_overlay("settings")
	arena.control_human(remote)
	check(not paused and remote.move_intent.x == 1 and remote.attack_intent, "host overlay preserves remote input")
	arena.control_human(player)
	check(not player.attack_intent and player.move_intent == Vector2.ZERO, "host overlay blocks only local input")
	arena.close_overlay()
	arena.online_active = false
	arena.touch_override = 0
	arena.practice = false
	for fighter in arena.players:
		fighter.is_dead = false
		fighter.hp = 100
		fighter.invincible_time = 0
	arena.players[0].position = arena.FLAG_POSITION
	arena.players[1].position = arena.FLAG_POSITION + Vector2(-30, 0)
	arena.players[2].position = arena.FLAG_POSITION + Vector2(180, 0)
	arena.players[3].position = arena.FLAG_POSITION + Vector2(200, 30)
	arena.reveal_to(arena.players[0], 1)
	arena.reveal_to(arena.players[1], 1)
	var bot = arena.players[2]
	arena.fusion[1].ready = true
	arena.fusion[1].age = 5.0
	arena.fusion[1].pair = [2,3]
	arena.elapsed = 1
	check(not arena.cast_ultimate(bot), "no opening bot ultimate")
	arena.elapsed = 20
	check(arena.cast_ultimate(bot), "bot can cast with a valid enemy")
	arena.fusion[1].ready = true
	arena.fusion[1].age = 5.0
	arena.elapsed = 25
	check(not arena.cast_ultimate(bot), "bot cooldown prevents spam")
	arena.elapsed = 41
	check(not arena.cast_ultimate(bot), "no overlapping bot ultimate fields")
	arena.zones.clear()
	arena.players[0].is_dead = true
	arena.players[1].is_dead = true
	check(not arena.cast_ultimate(bot), "bot does not ultimate just the flag")
	arena.players[0].is_dead = false
	check(arena.cast_ultimate(bot), "bot cooldown recovers")
	check(not arena.cast_ultimate(arena.players[1]), "allied bot cannot spend human fusion")
	arena.zones.clear()
	for a in range(5):
		for b in range(a,5):
			var spell: Dictionary = arena.create_spell([a,b], 0, arena.FLAG_POSITION, Vector2.RIGHT)
			check(spell.key == arena.pair_key(a,b), "fusion preserved")
	arena.zones.clear()
	check(arena.PROFILES.DATA[0].range == 96 and arena.PROFILES.DATA[3].range > arena.PROFILES.DATA[2].range, "compact attacks preserve roles")
	check(arena.PROFILES.DATA[1].radius == 5, "smaller water shots")
	arena.touch_override = original_touch
	arena.show_main_menu()
	await settle()
	arena.start_offline("squad_coop")
	await settle()
	await resize_case(Vector2i(1280,720))
	check(arena.views.size() == 2 and arena.views[1].container.position.x > 0, "landscape split screen")
	await resize_case(Vector2i(720,1280))
	check(arena.views[1].container.position.y > 0 and arena.views[1].container.position.x == 0, "portrait split screen")
	arena.touch_override = 1
	arena.show_main_menu()
	await settle()
	var play_buttons = arena.menu.find_children("*", "Button", true, false).filter(func(button): return button.text == "Играть")
	check(play_buttons[0].size.y >= 96, "large touch menu targets")
	await capture("phone_menu")
	arena.show_mode_menu(false)
	await settle()
	await capture("phone_loadout")
	for button in arena.menu.find_children("*", "Button", true, false):
		check(button.size.y >= 96, "large touch loadout targets")
	arena.open_overlay("settings")
	await settle()
	await capture("phone_settings")
	arena.close_overlay()
	arena.touch_override = original_touch
	arena.show_main_menu()
	await settle()
	print("MINIMAL UI CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)

