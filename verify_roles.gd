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

func settle() -> void:
	for frame in range(5): await process_frame

func reset_fighter(player, position: Vector2) -> void:
	player.respawn()
	player.position = position
	player.invincible_time = 0
	player.applied_element = -1
	player.element_time = 0
	player.set_physics_process(false)

func attack(player) -> void:
	player.attack_cooldown = 0
	player.attack_recovery = 0
	player.is_attacking = false
	player.is_hurt = false
	player.energy = 100
	player.start_attack()

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/roles_" + name + ".png")

func run_checks() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	await settle()
	arena.selected_elements.assign([0, 1])
	arena.start_offline("squad_bot")
	await settle()
	arena.set_physics_process(false)
	arena.ai_enabled = false
	arena.countdown = 0
	arena.mobs.clear()
	var attacker = arena.players[0]
	var ally = arena.players[1]
	var target = arena.players[2]
	var origin := Vector2(500, 600)
	for player in arena.players: reset_fighter(player, origin + Vector2(0, player.get_index() * 150))
	attacker.aim_direction = Vector2.RIGHT
	for element in range(5):
		attacker.element = element
		attacker.apply_element_profile()
		check(attacker.max_hp == 100, "standard HP for every element")
	check(attacker.base_move_speed == 195, "wind profile")
	attacker.element = 0
	attacker.apply_element_profile()
	reset_fighter(attacker, origin)
	reset_fighter(target, origin + Vector2(64, 0))
	reset_fighter(ally, origin + Vector2(64, 0))
	attack(attacker)
	check(target.hp == 100, "fire has no instant cone hit")
	attacker._physics_process(0.12)
	check(target.hp == 66, "fire close-range hit")
	check(ally.hp == 100, "fire friendly-fire protection")
	var hp: float = target.hp
	attacker.is_attacking = false
	attacker.start_attack()
	check(target.hp == hp, "attack cooldown enforced")
	attacker.position = origin
	attack(attacker)
	attacker._physics_process(0.12)
	attacker.position = origin
	attack(attacker)
	attacker._physics_process(0.12)
	check(target.is_dead, "three fire hits lethal")
	reset_fighter(target, origin + Vector2(220, 0))
	attacker.position = origin
	attack(attacker)
	attacker._physics_process(0.12)
	check(target.hp == 100, "fire cannot damage distant enemies")
	check(attacker.base_move_speed > 190, "fire mobility")
	attacker.element = 1
	reset_fighter(attacker, origin)
	attacker.apply_element_profile()
	arena.projectiles.clear()
	attack(attacker)
	check(arena.projectiles.size() == 3, "water spreads three shots")
	for i in range(15): arena.update_projectiles(0.1)
	check(not arena.floods.is_empty(), "water shots flood on impact and expiry")
	reset_fighter(target, origin + Vector2(220, 0))
	arena.floods.clear()
	arena.add_flood(origin + Vector2(220, 0), 0)
	arena.update_floods(1.0)
	check(arena.floods[0].radius == 56, "flood expands")
	check(target.hp == 96, "flood damages opponents")
	for i in range(15): arena.add_flood(Vector2(150 + i * 110, 500), 0)
	check(arena.floods.size() <= 8, "flood cap")
	arena.update_floods(5.0)
	check(arena.floods.is_empty(), "flood expiry")
	reset_fighter(target, origin + Vector2(220, 0))
	arena.apply_element_hit(target, 2, 17, 0, Vector2.RIGHT)
	check(target.chill_time > 0 and target.slow_time == 0, "ice basic attack applies mild chill")
	target.attack_intent = false
	target.move_intent = Vector2.ZERO
	target._physics_process(0.01)
	check(is_equal_approx(target.speed, target.base_move_speed * 0.82), "ice slow is 18 percent")
	attacker.element = 3
	attacker.apply_element_profile()
	arena.projectiles.clear()
	attack(attacker)
	check(arena.projectiles.size() == 1, "thunder single precision shot")
	var shot: Dictionary = arena.projectiles[0]
	check(is_equal_approx(float(shot.life) * Vector2(shot.vel).length() + 20, 660), "thunder range 660")
	reset_fighter(target, origin + Vector2(600, 0))
	for i in range(9): arena.update_projectiles(0.1)
	check(target.hp == 71, "thunder hits at long range")
	attacker.element = 4
	attacker.apply_element_profile()
	arena.projectiles.clear()
	attacker.combo_stage = 0
	attack(attacker)
	check(attacker.combo_stage == 1 and arena.projectiles[0].radius == 4, "wind first narrow attack")
	check(attacker.dash_time > 0 and attacker.dash_velocity.length() > 0, "wind attack dashes")
	attack(attacker)
	check(attacker.combo_stage == 2 and arena.projectiles[1].radius == 9, "wind second wider attack")
	reset_fighter(target, origin + Vector2(75, 35))
	attack(attacker)
	check(attacker.combo_stage == 0 and target.hp == 68 and target.push_velocity.x > 0, "wind wide finisher with knockback")
	attacker.combo_stage = 2
	attacker.combo_time = 0.01
	attacker.attack_intent = false
	attacker._physics_process(0.02)
	check(attacker.combo_stage == 0, "wind combo times out")
	var polygon: PackedVector2Array = load("res://player_marker.gd").points(Vector2(0,18), Vector2(21,8))
	check(polygon.size() == 49 and polygon[0].is_equal_approx(polygon[-1]), "foot ring closed")
	for element in range(5):
		attacker.element = element
		attacker.apply_element_profile()
		reset_fighter(attacker, origin)
		reset_fighter(target, origin + Vector2(220, 0))
		reset_fighter(ally, origin + Vector2(90, 80))
		attacker.body_sprite.flip_h = element % 2 == 1
		target.body_sprite.flip_h = true
		ally.body_sprite.flip_h = false
		attacker.aim_direction = Vector2.RIGHT
		arena.effects.clear()
		arena.projectiles.clear()
		arena.floods.clear()
		arena.combat_visuals.clear()
		arena.fusion[0].ready = true
		arena.countdown_label.text = ""
		if element == 1:
			for point in [Vector2(170, -50), Vector2(250, 0), Vector2(170, 70)]:
				arena.add_flood(origin + point, 0)
			arena.update_floods(0.9)
		elif element == 4:
			attacker.combo_stage = 2
		attack(attacker)
		await settle()
		await capture(str(element))
	var profile: Dictionary = arena.PROFILES.get_profile(attacker.element)
	check(profile.role == "COMBO SKIRMISHER", "role data")
	arena.show_main_menu()
	await settle()
	arena.show_mode_menu(false)
	await settle()
	await capture("mode_menu")
	print("ELEMENT ROLE CHECKS: %d failures" % failures)
	quit(0 if failures == 0 else 1)
