extends "res://demo_arena.gd"

const VIEW_SCRIPT = preload("res://flag_view.gd")
const MINIMAP_SCRIPT = preload("res://flag_minimap.gd")
const WORLD_RECT := Rect2(0, 0, 1920, 1080)
const WORLD_LIMITS := Rect2(28, 48, 1864, 990)
const FLAG_POSITION := Vector2(890, 500)
const FLAG_RADIUS: float = 155.0
const BRUSH_MASK = preload("res://brush_mask.gd")
const SPELLS := {
	"0:0": {"radius": 155.0, "duration": 4.6, "damage": 7, "interval": 0.65, "pull": 0.0, "slow": false},
	"0:1": {"radius": 175.0, "duration": 4.5, "damage": 8, "interval": 0.8, "pull": 0.0, "slow": false},
	"0:2": {"radius": 165.0, "duration": 2.4, "damage": 42, "interval": 10.0, "pull": 0.0, "slow": true},
	"0:3": {"radius": 180.0, "duration": 4.2, "damage": 9, "interval": 0.7, "pull": -95.0, "slow": false},
	"0:4": {"radius": 175.0, "duration": 4.8, "damage": 7, "interval": 0.75, "pull": 100.0, "slow": false},
	"1:1": {"radius": 160.0, "duration": 3.0, "damage": 32, "interval": 0.1, "pull": -230.0, "slow": false},
	"1:2": {"radius": 180.0, "duration": 3.4, "damage": 34, "interval": 0.1, "pull": -190.0, "slow": true},
	"1:3": {"radius": 190.0, "duration": 4.7, "damage": 7, "interval": 0.75, "pull": 0.0, "slow": true},
	"1:4": {"radius": 180.0, "duration": 4.8, "damage": 6, "interval": 0.75, "pull": 140.0, "slow": false},
	"2:2": {"radius": 185.0, "duration": 5.0, "damage": 5, "interval": 0.7, "pull": 0.0, "slow": true},
	"2:3": {"radius": 175.0, "duration": 4.6, "damage": 7, "interval": 0.75, "pull": 0.0, "slow": true},
	"2:4": {"radius": 200.0, "duration": 5.0, "damage": 5, "interval": 0.75, "pull": 115.0, "slow": true},
	"3:3": {"radius": 175.0, "duration": 4.6, "damage": 10, "interval": 0.9, "pull": 0.0, "slow": false},
	"3:4": {"radius": 210.0, "duration": 5.4, "damage": 8, "interval": 0.8, "pull": 0.0, "slow": true},
	"4:4": {"radius": 150.0, "duration": 4.7, "damage": 5, "interval": 0.65, "pull": 175.0, "slow": false},
}

@export_range(30.0, 600.0) var match_duration: float = 180.0
@export_range(1.0, 10.0) var shield_build_seconds: float = 4.0
var time_left: float = 180.0
var flag_phase: String = "neutral"
var flag_owner: int = -1
var flag_shield: float = 200.0
var builder: int = -1
var build_progress: float = 0.0
var reveals: Dictionary = {}
var mobs: Array[Dictionary] = []
var views: Array = []
var flag_label: Label
var flag_banner: Label
var winner_team: int = -2
var brush_cells := PackedInt32Array()
var brush_blades := PackedVector2Array()
var zones: Array[Dictionary] = []

func _ready() -> void:
	var data: Dictionary = BRUSH_MASK.DATA
	brush_cells.resize(int(data.width) * int(data.height))
	brush_cells.fill(-1)
	for run in data.runs:
		for x in range(int(run[1]), int(run[2])):
			brush_cells[int(run[0]) * int(data.width) + x] = int(run[3])
	for p in data.blades:
		brush_blades.append(Vector2(p[0], p[1]))
	super._ready()

func show_main_menu() -> void:
	super.show_main_menu()
	for label in menu.find_children("*", "Label", true, false):
		if label.text.begins_with("DEMO"):
			label.text = "FLAG CONTROL · Щиты · Кусты · Личные камеры"
		elif label.text.begins_with("Союзники касаются"):
			label.text = "3 минуты: разбей нейтральный щит, займи круг и построй свой. Удержи флаг со щитом к концу. Пустой круг теряет щит."
	var boxes := menu.find_children("*", "VBoxContainer", true, false)
	var box: VBoxContainer = boxes[0]
	var combo := make_label(box, "", 12, Color("#ffe7a2"))
	box.move_child(combo, 3)
	var refresh := func(_value: int = 0): combo.text = "СЛИЯНИЕ: " + FUSION_NAMES[pair_key(selected_elements[0], selected_elements[1])] + " · Q / R.SHIFT"
	for picker in menu.find_children("*", "OptionButton", true, false):
		picker.item_selected.connect(refresh)
	refresh.call()

func clear_match() -> void:
	super.clear_match()
	views.clear()
	mobs.clear()
	reveals.clear()
	zones.clear()
	flag_label = null
	flag_banner = null

func begin_match(mode: String, epoch: int) -> void:
	time_left = match_duration
	flag_phase = "neutral"
	flag_owner = -1
	flag_shield = 200
	builder = -1
	build_progress = 0
	winner_team = -2
	super.begin_match(mode, epoch)
	world.hide()
	for index in range(players.size()):
		var player = players[index]
		player.character_height = 40.0
		player.base_move_speed = 145.0

		for anim in player.animation_scales:
			player.animation_scales[anim] *= 40.0 / 64.0
		player.play_anim("idle")
		player.position = spawn_position(player.team, index % 2 if squad else 0)
		player.start_position = player.position
		player.aim_direction = (FLAG_POSITION - player.position).normalized()
		player.facing_direction = player.aim_direction
	for view in views:
		view.camera.position = view.viewer.position
		view.camera.reset_smoothing()
	for index in range(3):
		var home := FLAG_POSITION + Vector2.from_angle(index * TAU / 3 - 0.7) * 180
		mobs.append({"pos": home, "home": home, "hp": 55.0, "cooldown": 0.0, "respawn": 0.0})
	update_flag_ui()

func spawn_position(team: int, slot: int) -> Vector2:
	return Vector2(400 + slot * 95, 910) if team == 0 else Vector2(1460 + slot * 95, 180)

func create_match_ui() -> void:
	var mode_label := make_label(match_ui, "FLAG CONTROL · " + ("2V2" if squad else "1V1"), 12, MUTED)
	mode_label.position = Vector2(410, 14)
	mode_label.size.x = 332
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = make_label(match_ui, "03:00", 30, WHITE)
	score_label.position = Vector2(440, 32)
	score_label.size.x = 272
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_label = make_label(match_ui, "НЕЙТРАЛЬНЫЙ ЩИТ 200", 11, Color("#ffe7a2"))
	flag_label.position = Vector2(408, 76)
	flag_label.size.x = 336
	flag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for team in range(2):
		var status := make_label(match_ui, "", 11, BLUE if team == 0 else ORANGE)
		status.position = Vector2(24 if team == 0 else 704, 107)
		status.size.x = 424
		if team == 1:
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fusion_labels.append(status)
	var humans := players.filter(func(p): return p.human_index >= 0)
	for index in range(humans.size()):
		var container := SubViewportContainer.new()
		container.position = Vector2(index * 576 if humans.size() > 1 else 0, 128)
		container.size = Vector2(574 if humans.size() > 1 else 1152, 536)
		container.stretch = true
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match_ui.add_child(container)
		var viewport := SubViewport.new()
		viewport.world_2d = World2D.new()
		viewport.size = Vector2i(container.size)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally = false
		container.add_child(viewport)
		var view := Node2D.new()
		view.set_script(VIEW_SCRIPT)
		view.arena = self
		view.viewer = humans[index]
		view.container = container
		viewport.add_child(view)
		views.append(view)
		var overlay := CanvasLayer.new()
		viewport.add_child(overlay)
		var minimap := Node2D.new()
		minimap.set_script(MINIMAP_SCRIPT)
		minimap.arena = self
		minimap.viewer = humans[index]
		minimap.view = view
		overlay.add_child(minimap)
	countdown_label = make_label(match_ui, "", 44, WHITE)
	countdown_label.position = Vector2(510, 318)
	countdown_label.size.x = 132
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_banner = make_label(match_ui, "", 12, WHITE)
	flag_banner.position = Vector2(24, 670)
	var hint := make_label(match_ui, "P1: WASD · ЛКМ/SPACE · Q      P2: СТРЕЛКИ · ENTER · R.SHIFT", 11, MUTED)
	hint.position = Vector2(24, 697)
	var back := make_button(match_ui, "МЕНЮ / ESC", show_main_menu)
	back.position = Vector2(976, 677)
	back.size = Vector2(154, 34)
	update_fusion_ui()

func update_score() -> void:

	pass

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), Color("#0c111c"))
	if state == "menu":
		draw_texture_rect(MAP_TEXTURE, Rect2(96, 128, 960, 540), false)

func _physics_process(delta: float) -> void:
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0)
	if state != "offline":
		return
	countdown = maxf(0, countdown - delta)
	countdown_label.text = str(ceili(countdown)) if countdown > 0 else ""
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.position = player.position.clamp(WORLD_LIMITS.position, WORLD_LIMITS.end)
	if countdown > 0:
		return
	elapsed += delta
	time_left = maxf(0, time_left - delta)
	for key in collision_cooldowns.keys():
		collision_cooldowns[key] -= delta
		if collision_cooldowns[key] <= 0:
			collision_cooldowns.erase(key)
	for player in players:
		if player.is_dead:
			continue
		if player.bot:
			if ai_enabled:
				control_bot(player)
		else:
			control_human(player)
	resolve_contacts()
	update_fusions(delta)
	update_projectiles(delta)
	update_zones(delta)
	update_mobs(delta)
	update_flag(delta)
	update_fusion_ui()
	update_flag_ui()
	if time_left <= 0:
		finish_flag_match()

func control_human(player) -> void:
	player.move_intent = keyboard_direction(player.human_index)
	player.attack_intent = Input.is_physical_key_pressed(KEY_SPACE if player.human_index == 0 else KEY_ENTER)
	if player.move_intent.length_squared() > 0.01:
		player.aim_direction = player.move_intent.normalized()
	if player.human_index == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		for view in views:
			if view.viewer == player and Rect2(view.container.position, view.container.size).has_point(get_viewport().get_mouse_position()):
				player.aim_direction = (view.mouse_world() - player.position).normalized()
				player.attack_intent = true

func brush_at(point: Vector2) -> int:

	point += Vector2(0, 16)
	if point.x < 0 or point.y < 0 or point.x >= 1920 or point.y >= 1080:
		return -1
	var x := int(point.x) / 4
	var y := int(point.y) / 4
	return brush_cells[y * 480 + x] if not brush_cells.is_empty() else -1

func reveal_to(target, team: int) -> void:
	reveals["%d:%d" % [team, target.get_instance_id()]] = elapsed + 2.0

func is_revealed(target, team: int) -> bool:
	return float(reveals.get("%d:%d" % [team, target.get_instance_id()], -1)) > elapsed

func is_visible_to(target, team: int) -> bool:
	if target.team == team or is_revealed(target, team):
		return true
	var brush := brush_at(target.position)
	for ally in players:
		if ally.team != team or ally.is_dead:
			continue
		var distance: float = ally.position.distance_to(target.position)
		if distance <= 65 or (brush < 0 and distance <= 470) or (brush >= 0 and distance <= 220 and brush_at(ally.position) == brush):
			return true
	return false

func nearest_enemy(player):
	var best = null
	var distance: float = INF
	for enemy in players:
		if enemy.team == player.team or enemy.is_dead or not is_visible_to(enemy, player.team):
			continue
		var d: float = enemy.position.distance_squared_to(player.position)
		if d < distance:
			distance = d
			best = enemy
	return best

func control_bot(player) -> void:
	var target = nearest_enemy(player)
	var objective := FLAG_POSITION + Vector2(-75 if player.team == 0 else 75, 55 * (player.get_index() % 2))
	var direction: Vector2 = objective - player.position
	player.move_intent = direction.normalized() if direction.length() > 18 else Vector2.ZERO
	player.aim_direction = (FLAG_POSITION - player.position).normalized()
	var attack_flag: bool = flag_shield > 0 and flag_owner != player.team
	if attack_flag and player.position.distance_to(FLAG_POSITION) < 380:
		player.attack_intent = true
		if player.position.distance_to(FLAG_POSITION) > 200:
			player.move_intent = Vector2.ZERO
	var mob_target: Dictionary = {}
	var mob_distance: float = 230
	for mob in mobs:
		var d: float = player.position.distance_to(mob.pos)
		if mob.hp > 0 and d < mob_distance:
			mob_distance = d
			mob_target = mob
	if not mob_target.is_empty():
		player.aim_direction = (mob_target.pos - player.position).normalized()
		player.attack_intent = true
	if target != null and player.position.distance_to(target.position) < 420:
		player.aim_direction = (target.position - player.position).normalized()
		player.attack_intent = true
		if player.position.distance_to(target.position) < 100:
			player.move_intent = -player.aim_direction
	if player.energy < 10:
		player.attack_intent = false
	if squad:
		var partner = teammate(player)
		var charge: Dictionary = fusion[player.team]
		if partner != null and not partner.is_dead and partner.position.distance_to(player.position) < 360 and charge.armed and not charge.ready:
			player.move_intent = (partner.position - player.position).normalized()
		if partner != null and not partner.is_dead and not charge.ready and not charge.armed and partner.position.distance_to(player.position) < 125:
			player.move_intent = (player.position - partner.position).normalized()
		if partner != null and partner.bot and charge.ready and charge.age > 1.5 and (target != null or attack_flag) and player.position.distance_to(FLAG_POSITION) < 380:
			cast_ultimate(player)

func update_flag(delta: float) -> void:
	var counts: Array[int] = [0, 0]
	for player in players:
		if not player.is_dead and player.position.distance_to(FLAG_POSITION) <= FLAG_RADIUS:
			counts[player.team] += 1
	if flag_phase == "owned" and counts[0] + counts[1] == 0:
		flag_shield = 0
		flag_owner = -1
		flag_phase = "open"
		builder = -1
		build_progress = 0
		add_effect(FLAG_POSITION, WHITE, FLAG_RADIUS, "ЗОНА ПУСТА · ЩИТ РАЗРУШЕН")
	if flag_shield > 0:
		return
	if counts[0] > 0 and counts[1] > 0:
		build_progress = maxf(0, build_progress - delta * 0.5)
		return
	var team: int = 0 if counts[0] > 0 else (1 if counts[1] > 0 else -1)
	if team < 0:
		builder = -1
		build_progress = 0
		return
	if builder != team:
		builder = team
		build_progress = 0
	build_progress += delta
	if build_progress >= shield_build_seconds:
		flag_owner = team
		flag_shield = 150
		flag_phase = "owned"
		builder = -1
		build_progress = 0
		add_effect(FLAG_POSITION, BLUE if team == 0 else ORANGE, FLAG_RADIUS, "ФЛАГ ЗАХВАЧЕН · ЩИТ ПОСТРОЕН")

func hit_flag(team: int, damage: int) -> void:
	if flag_shield <= 0 or flag_owner == team:
		return
	flag_shield = maxf(0, flag_shield - damage)
	add_effect(FLAG_POSITION, WHITE, 58, "ЩИТ −%d" % damage)
	if flag_shield <= 0:
		flag_owner = -1
		flag_phase = "open"
		builder = -1
		build_progress = 0

func update_flag_ui() -> void:
	if not is_instance_valid(flag_label):
		return
	var seconds := ceili(time_left)
	score_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	score_label.modulate = Color("#ff8b80") if time_left < 20 else WHITE
	if flag_phase == "neutral":
		flag_label.text = "НЕЙТРАЛЬНЫЙ ЩИТ · %d" % ceili(flag_shield)
		flag_banner.text = "ЦЕЛЬ: разрушьте нейтральный щит выстрелами, затем займите круг флага."
	elif flag_phase == "owned":
		flag_label.text = ("СИНИЕ" if flag_owner == 0 else "ОРАНЖЕВЫЕ") + " · ЩИТ %d" % ceili(flag_shield)
		flag_banner.text = "УДЕРЖАНИЕ: флаг со щитом в конце таймера приносит победу. Пустой круг теряет щит."
	else:
		flag_label.text = "СТРОИТЕЛЬСТВО %d%%" % int(build_progress / shield_build_seconds * 100) if builder >= 0 else "ФЛАГ БЕЗ ЩИТА"
		flag_banner.text = "СТРОЙТЕ: стойте в круге %d сек. Враг в круге мешает строительству." % int(shield_build_seconds)

func update_mobs(delta: float) -> void:
	for mob in mobs:
		if mob.hp <= 0:
			mob.respawn -= delta
			if mob.respawn <= 0:
				mob.hp = 55
				mob.pos = mob.home
			continue
		mob.cooldown = maxf(0, mob.cooldown - delta)
		var target = null
		var nearest: float = 235
		for player in players:
			if player.is_dead:
				continue
			var d: float = player.position.distance_to(mob.pos)
			if d < nearest and (brush_at(player.position) < 0 or d < 65):
				nearest = d
				target = player
		if target != null and target.position.distance_to(mob.home) < 310:
			if nearest > 34:
				mob.pos += (target.position - mob.pos).normalized() * 75.0 * delta
			elif mob.cooldown <= 0:
				mob.cooldown = 1.25
				receive_damage(target,8,-1)
				add_effect(target.position, Color("#d8ca94"), 22, "−8")
		else:
			mob.pos = Vector2(mob.pos).move_toward(mob.home, 60 * delta)

func hit_mob(mob: Dictionary, damage: int) -> void:
	if mob.hp <= 0:
		return
	mob.hp = maxf(0, mob.hp - damage)
	add_effect(mob.pos, Color("#d8ca94"), 25, "−%d" % damage)
	if mob.hp <= 0:
		mob.respawn = 14.0

func apply_element_hit(target, element: int, damage: int, attacking_team: int, direction: Vector2) -> void:
	var before: Array = players.map(func(p): return p.hp)
	if (element == 4 or target.applied_element == 4) and target.applied_element >= 0 and target.applied_element != element and target.element_time > 0 and not target.is_dead and target.invincible_time <= 0 and target.team != attacking_team:
		var spread_element: int = target.applied_element if element == 4 else element
		receive_damage(target,damage+6,attacking_team)
		target.push_velocity += direction * 90
		target.applied_element = -1
		target.element_time = 0
		add_effect(target.position, ELEMENT_COLORS[spread_element], 80, "РАССЕИВАНИЕ")
		for other in players:
			if other != target and other.team != attacking_team and not other.is_dead and other.position.distance_to(target.position) < 120:
				receive_damage(other,6,attacking_team)
				other.applied_element = spread_element
				other.element_time = 3.0
	else:
		super.apply_element_hit(target, element, damage, attacking_team, direction)
	for index in range(players.size()):
		if players[index].team != attacking_team and players[index].hp < before[index]:
			reveal_to(players[index], attacking_team)

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var previous: Vector2 = shot.pos
		shot.pos += shot.vel * minf(delta, maxf(0.0, float(shot.life)))
		shot.life -= delta
		var hit_kind := ""
		var hit_player = null
		var hit_guard: Dictionary = {}
		var impact: Vector2 = shot.pos
		var best: float = INF
		for target in players:
			if target.team == shot.team or target.is_dead or target.invincible_time > 0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(target.position, previous, shot.pos)
			if closest.distance_to(target.position) < 16 + shot.radius and previous.distance_squared_to(closest) < best:
				best = previous.distance_squared_to(closest)
				hit_kind = "player"
				hit_player = target
				impact = closest
		for mob in mobs:
			if mob.hp <= 0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(mob.pos, previous, shot.pos)
			if closest.distance_to(mob.pos) < 20 + shot.radius and previous.distance_squared_to(closest) < best:
				best = previous.distance_squared_to(closest)
				hit_kind = "mob"
				hit_guard = mob
				impact = closest
		if flag_shield > 0 and flag_owner != shot.team:
			var closest := Geometry2D.get_closest_point_to_segment(FLAG_POSITION, previous, shot.pos)
			if closest.distance_to(FLAG_POSITION) < 44 + shot.radius and previous.distance_squared_to(closest) < best:
				hit_kind = "flag"
				impact = closest
		var expired: bool = shot.life <= 0 or not WORLD_RECT.has_point(shot.pos)
		if not hit_kind.is_empty() or expired:
			if shot.ultimate:
				explode_fusion(shot, impact)
			elif hit_kind == "player":
				projectile_element_hit(hit_player,shot)
			elif hit_kind == "mob":
				hit_mob(hit_guard, int(shot.damage))
			elif hit_kind == "flag":
				hit_flag(int(shot.team), int(shot.damage))
			on_projectile_impact(shot, impact, hit_kind)
			projectiles.remove_at(index)

func projectile_element_hit(target, shot: Dictionary) -> void:
	apply_element_hit(target,int(shot.element),int(shot.damage),int(shot.team),shot.vel.normalized())

func on_projectile_impact(_shot: Dictionary, _impact: Vector2, _hit_kind: String) -> void:
	pass

func explode_fusion(shot: Dictionary, center: Vector2) -> void:
	var before: Array = players.map(func(p): return p.hp)
	super.explode_fusion(shot, center)
	for index in range(players.size()):
		if players[index].team != shot.team and players[index].hp < before[index]:
			reveal_to(players[index], shot.team)
	if center.distance_to(FLAG_POSITION) < 170:
		hit_flag(int(shot.team), 45)
	for mob in mobs:
		if Vector2(mob.pos).distance_to(center) < 130:
			hit_mob(mob, 40)

func on_defeated(player) -> void:
	if state != "offline":
		return
	scores[1 - player.team] += 1
	var epoch := match_id
	await get_tree().create_timer(player.respawn_time).timeout
	if epoch == match_id and state == "offline" and is_instance_valid(player):
		player.respawn()

func finish_flag_match() -> void:
	if state != "offline":
		return
	winner_team = flag_owner if flag_phase == "owned" and flag_shield > 0 else -1
	state = "result"
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.set_physics_process(false)
	var box := create_menu_card(560)
	var title := "НИЧЬЯ · ФЛАГ НЕ ЗАЩИЩЁН"
	if winner_team >= 0:
		title = ("СИНЯЯ" if winner_team == 0 else "ОРАНЖЕВАЯ") + " КОМАНДА ПОБЕДИЛА"
	make_label(box, title, 24, WHITE)
	make_label(box, "Время вышло. Побеждает владелец флага с целым щитом.", 14, MUTED)
	make_label(box, "KO  %d — %d" % [scores[0], scores[1]], 20, MUTED)
	make_button(box, "ЕЩЁ МАТЧ", func(): start_offline(match_mode))
	make_button(box, "В МЕНЮ", show_main_menu)

func resolve_contacts() -> void:

	if flag_shield > 0:
		for player in players:
			if player.is_dead:
				continue
			var offset: Vector2 = player.position - FLAG_POSITION
			if offset.length() >= 62:
				continue
			var normal := offset.normalized() if offset.length() > 0.01 else (Vector2.LEFT if player.team == 0 else Vector2.RIGHT)
			player.position = FLAG_POSITION + normal * 62
			var key := "shield:%d" % player.get_instance_id()
			if not collision_cooldowns.has(key):
				player.trigger_bounce(normal * 230)
				collision_cooldowns[key] = 0.45
				add_effect(player.position, Color("#e5e7bd"), 42, "ОТСКОК")
	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var a = players[i]
			var b = players[j]
			if a.is_dead or b.is_dead or a.team == b.team:
				continue
			if (a.element == 0 and a.dash_time > 0) or (b.element == 0 and b.dash_time > 0):
				continue
			var offset: Vector2 = b.position - a.position
			var distance := offset.length()
			if distance >= 30:
				continue
			var normal := offset / distance if distance > 0.01 else Vector2.RIGHT
			a.position -= normal * (30 - distance) / 2
			b.position += normal * (30 - distance) / 2
			var key := "%d:%d" % [i, j]
			if not collision_cooldowns.has(key):
				a.trigger_bounce(-normal * 150)
				b.trigger_bounce(normal * 150)
				collision_cooldowns[key] = 0.45
				add_effect((a.position + b.position) / 2, WHITE, 25, "")

func uses_directional_aim(_player) -> bool:
	return false

func cast_ultimate(player) -> bool:
	if state != "offline" or countdown > 0 or not squad or player.is_dead or zones.size() >= 12:
		return false
	var charge: Dictionary = fusion[player.team]
	if not charge.ready:
		return false
	var direction: Vector2 = player.aim_direction.normalized()
	var target: Vector2 = player.position + direction * 240
	if player.human_index == 0 and not uses_directional_aim(player):
		for view in views:
			if view.viewer == player and Rect2(view.container.position, view.container.size).has_point(get_viewport().get_mouse_position()):
				target = player.position + (view.mouse_world() - player.position).limit_length(360)
				direction = (target - player.position).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var pair: Array = charge.pair.duplicate()
	if pair_key(pair[0], pair[1]) in ["1:1", "1:2"]:
		target = player.position + direction * 65
	charge.ready = false
	charge.armed = false
	charge.age = 0
	ultimate_count += 1
	create_spell(pair, player.team, target, direction)
	return true

func create_spell(pair: Array, team: int, target: Vector2, direction: Vector2) -> Dictionary:
	var key := pair_key(pair[0], pair[1])
	var zone: Dictionary = SPELLS[key].duplicate(true)
	zone.merge({"key": key, "team": team, "pair": pair.duplicate(), "pos": target.clamp(WORLD_LIMITS.position, WORLD_LIMITS.end), "dir": direction.normalized(), "age": 0.0, "warning": 0.55, "tick": 0.0, "hits": {}, "pulse": 0.0})
	if Vector2(zone.dir).length_squared() < 0.01:
		zone.dir = Vector2.RIGHT
	zones.append(zone)
	add_effect(zone.pos, ELEMENT_COLORS[pair[0]].lerp(ELEMENT_COLORS[pair[1]], 0.5), 90, FUSION_NAMES[key])
	return zone

func spell_contains(zone: Dictionary, point: Vector2) -> bool:
	var offset: Vector2 = point - zone.pos
	if zone.key == "0:3":
		return absf(offset.dot(zone.dir)) <= zone.radius and absf(offset.dot(Vector2(zone.dir).orthogonal())) <= 36
	if zone.key in ["1:1", "1:2"]:
		return absf(offset.dot(zone.dir)) <= 52 and absf(offset.dot(Vector2(zone.dir).orthogonal())) <= zone.radius
	return offset.length_squared() <= zone.radius * zone.radius

func update_zones(delta: float) -> void:
	for index in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		zone.age += delta
		zone.pulse = maxf(0, zone.pulse - delta)
		if zone.age > zone.duration + zone.warning:
			zones.remove_at(index)
			continue
		if zone.age < zone.warning:
			continue
		if zone.key in ["1:1", "1:2"]:
			zone.pos += zone.dir * 180 * delta
		elif zone.key in ["4:4", "3:4"]:
			zone.pos = Vector2(zone.pos + zone.dir * 32 * delta).clamp(WORLD_LIMITS.position, WORLD_LIMITS.end)
		zone.tick -= delta
		if zone.tick > 0:
			continue
		zone.tick = zone.interval
		zone.pulse = 0.25
		for target in players:
			if target.team == zone.team or target.is_dead or target.invincible_time > 0 or not spell_contains(zone, target.position):
				continue
			var token := "p%d" % target.get_instance_id()
			if zone.key in ["1:1", "1:2"] and zone.hits.has(token):
				continue
			zone.hits[token] = true
			receive_damage(target,int(zone.damage),int(zone.team),int(zone.get("owner",-1)))
			reveal_to(target, int(zone.team))
			if zone.slow:
				target.slow_time = maxf(target.slow_time, 2.4 if zone.key == "1:2" else 1.1)
			if zone.pull != 0:
				var toward: Vector2 = (zone.pos - target.position).normalized()
				if zone.key in ["1:1", "1:2"] or toward.length_squared() < 0.01:
					toward = -zone.dir
				target.push_velocity += toward * zone.pull
			target.applied_element = zone.pair[1]
			target.element_time = 3.0
		for mob_index in range(mobs.size()):
			var mob: Dictionary = mobs[mob_index]
			var token := "m%d" % mob_index
			if mob.hp > 0 and spell_contains(zone, mob.pos) and (zone.key not in ["1:1", "1:2"] or not zone.hits.has(token)):
				zone.hits[token] = true
				hit_mob(mob, int(zone.damage))
		if spell_contains(zone, FLAG_POSITION) and (zone.key not in ["1:1", "1:2"] or not zone.hits.has("flag")):
			zone.hits["flag"] = true
			hit_flag(int(zone.team), int(zone.damage))
