extends SceneTree

var arena
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)

func prepare(player, position: Vector2) -> void:
	player.respawn()
	player.invincible_time = 0
	player.position = position
	player.attack_intent = false
	player.move_intent = Vector2.ZERO
	player.set_physics_process(false)

func run_checks() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.selected_elements.assign([0,1])
	arena.start_offline("squad_bot")
	await process_frame
	arena.set_physics_process(false)
	arena.countdown = 0
	arena.countdown_label.text = ""
	arena.mobs.clear()
	var origin := Vector2(600,800)
	var fire = arena.players[0]
	var ally = arena.players[1]
	var enemy = arena.players[2]
	var second = arena.players[3]
	prepare(fire, origin)
	prepare(ally, origin + Vector2(45,0))
	prepare(enemy, origin + Vector2(45,0))
	prepare(second, origin + Vector2(85,0))
	fire.aim_direction = Vector2.RIGHT
	fire.start_attack()
	check(enemy.hp == 100 and second.hp == 100, "damage waits for dash movement")
	check(arena.projectiles.is_empty(), "fire does not shoot a projectile")
	check(fire.dash_time > 0 and fire.dash_velocity.x > 700, "attack starts a real dash")
	fire._physics_process(0.06)
	check(enemy.hp == 66, "dash damages a crossed enemy")
	check(second.hp == 100, "dash does not hit targets before reaching them")
	check(ally.hp == 100, "dash cannot damage teammates")
	if "--screenshots" in OS.get_cmdline_user_args():
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/fire_dash.png")
	fire._physics_process(0.06)
	check(enemy.hp == 66 and second.hp == 66, "one hit per enemy per dash")
	check(is_equal_approx(fire.position.x - origin.x, 96), "dash travel is 96")
	check(is_zero_approx(fire.position.y - origin.y), "dash follows aim")
	arena.update_fire_dashes()
	check(arena.fire_dashes.is_empty(), "completed dash cleaned up")
	prepare(fire, origin)
	prepare(enemy, origin + Vector2(50,55))
	prepare(second, origin + Vector2(250,0))
	fire.start_attack()
	fire._physics_process(0.12)
	check(enemy.hp == 100 and second.hp == 100, "narrow dash has no wide cone damage")
	prepare(fire, origin)
	prepare(enemy, origin + Vector2(48,0))
	enemy.invincible_time = 1
	fire.start_attack()
	fire._physics_process(0.12)
	check(enemy.hp == 100, "dash respects invulnerability")
	prepare(fire, origin)
	prepare(enemy, origin + Vector2(50,0))
	fire.start_attack()
	fire.trigger_bounce(Vector2.LEFT * 100)
	fire._physics_process(0.05)
	check(enemy.hp == 100, "interrupted dash has no ghost damage")
	arena.show_main_menu()
	await process_frame
	print("FIRE DASH CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
