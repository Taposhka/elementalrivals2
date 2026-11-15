extends "res://arena.gd"

const FIGHTER_SCRIPT = preload("res://demo_fighter.gd")
const ELEMENT_NAMES := ["ОГОНЬ", "ВОДА", "ЛЁД", "МОЛНИЯ", "ВЕТЕР"]
const ELEMENT_COLORS := [Color("#ff915e"), Color("#57c9ff"), Color("#b7f6ff"), Color("#d9a3ff"), Color("#a7decf")]
const SHOT_SPEED := [340.0, 400.0, 360.0, 490.0, 430.0]
const SHOT_DAMAGE := [16, 13, 12, 14, 11]
const FUSION_NAMES := {"0:0": "Inferno", "0:1": "Steam Apocalypse", "0:2": "Crystal Volcano", "0:3": "Thunderflame", "0:4": "Flame Tornado", "1:1": "Tsunami", "1:2": "Frozen Tsunami", "1:3": "Electric Storm", "1:4": "Ocean Cyclone", "2:2": "Blizzard", "2:3": "Crystal Storm", "2:4": "Arctic Vortex", "3:3": "Thunderstrike", "3:4": "Sky Tempest", "4:4": "Hurricane"}

var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var fusion: Array[Dictionary] = []
var fusion_labels: Array[Label] = []
var selected_elements: Array[int] = [0, 1]
var elapsed: float = 0.0
var goal_score: int = 3
var squad: bool = false
var collision_cooldowns: Dictionary = {}
var ai_enabled: bool = true
var fusion_count: int = 0
var ultimate_count: int = 0

func show_main_menu() -> void:
	stop_network()
	match_id += 1
	clear_match()
	var box := create_menu_card(680)
	make_label(box, "ELEMENT RIVALS", 38, WHITE)
	make_label(box, "DEMO  •  Снаряды · реакции · командное слияние", 15, MUTED)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	box.add_child(choices)
	for slot in range(2):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(column)
		make_label(column, "ТВОЙ ЭЛЕМЕНТ" if slot == 0 else "ЭЛЕМЕНТ СОЮЗНИКА / P2", 11, MUTED)
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(260, 34)
		for element_name in ELEMENT_NAMES:
			picker.add_item(element_name)
		picker.select(selected_elements[slot])
		picker.item_selected.connect(func(value: int): selected_elements[slot] = value)
		column.add_child(picker)
	make_button(box, "1v1  /  ПРОТИВ БОТА", func(): start_offline("duel_bot"))
	make_button(box, "1v1  /  ДВА ИГРОКА", func(): start_offline("duel_local"))
	make_button(box, "2v2  /  ТЫ + СОЮЗНИК-БОТ", func(): start_offline("squad_bot"))
	make_button(box, "2v2  /  ВДВОЁМ ПРОТИВ БОТОВ", func(): start_offline("squad_coop"))
	make_label(box, "P1: WASD + мышь / SPACE · ульта Q\nP2: стрелки + ENTER · ульта правый SHIFT", 14, MUTED)
	var help := make_label(box, "Союзники касаются → общий заряд ульты. После выстрела разойдитесь и соединитесь снова. В 1v1 слияния нет.", 13, BLUE)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 600
	make_button(box, "ПРЕЖНИЙ СЕТЕВОЙ 1v1", func(): get_tree().change_scene_to_file("res://main.tscn"))

func clear_match() -> void:
	super.clear_match()
	projectiles.clear()
	effects.clear()
	fusion.clear()
	fusion_labels.clear()
	collision_cooldowns.clear()

func begin_match(mode: String, epoch: int) -> void:
	clear_match()
	clear_menu()
	match_mode = mode
	match_id = epoch
	state = "offline"
	scores = [0, 0]
	squad = mode.begins_with("squad")
	goal_score = 5 if squad else 3
	countdown = 2.0
	elapsed = 0.0
	fusion_count = 0
	ultimate_count = 0
	ai_enabled = true
	for team in range(2):
		fusion.append({"ready": false, "armed": true, "pair": [0, 1], "age": 0.0})
	world = Node2D.new()
	world.name = "DemoFighters"
	add_child(world)
	match_ui = Control.new()
	match_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(match_ui)
	var scene := load("res://player.tscn") as PackedScene
	var total := 4 if squad else 2
	for index in range(total):
		var player = scene.instantiate()
		player.set_script(FIGHTER_SCRIPT)
		player.team = index / 2 if squad else index
		player.player_slot = player.team
		player.element = selected_elements[index] if index < 2 else (2 if index == 2 else 3)
		player.human_index = -1
		if index == 0:
			player.human_index = 0
		elif index == 1 and (mode == "duel_local" or mode == "squad_coop"):
			player.human_index = 1
		player.bot = player.human_index < 0
		player.name = "Fighter%d" % index
		player.player_name = ("БОТ" if player.bot else "P%d" % (player.human_index + 1)) + " · " + ELEMENT_NAMES[player.element]
		player.external_control = true
		player.auto_respawn = false
		player.debug_damage_enabled = false
		player.hud_world_space = false
		player.hud_width = 184
		player.character_height = 64.0

		player.collision_layer = 0
		player.collision_mask = 0
		player.position = Vector2(330 if player.team == 0 else 822, 350 + (index % 2) * 138 if squad else 410)
		configure_match_player(player, index, mode)
		world.add_child(player)
		player.facing_direction = Vector2.RIGHT if player.team == 0 else Vector2.LEFT
		player.aim_direction = player.facing_direction
		player.body_sprite.flip_h = player.team == 1
		player.hud.reparent(match_ui, false)
		var hud_x: int = [24, 220, 748, 944][index] if squad else (24 if index == 0 else 944)
		player.hud.position = Vector2(hud_x, 14)
		player.attack_impact.connect(resolve_attack)
		player.defeated.connect(on_defeated)
		players.append(player)
	create_match_ui()

func configure_match_player(_player, _index: int, _mode: String) -> void:
	pass

func create_match_ui() -> void:
	var label := make_label(match_ui, "2 vs 2" if squad else "1 vs 1", 13, MUTED)
	label.position = Vector2(456, 12)
	label.size.x = 240
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = make_label(match_ui, "", 32, WHITE)
	score_label.position = Vector2(456, 29)
	score_label.size.x = 240
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var goal := make_label(match_ui, "ДО %d KO" % goal_score, 10, MUTED)
	goal.position = Vector2(520, 72)
	goal.size.x = 112
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label = make_label(match_ui, "", 50, WHITE)
	countdown_label.position = Vector2(496, 310)
	countdown_label.size.x = 160
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for team in range(2):
		var status := make_label(match_ui, "", 12, BLUE if team == 0 else ORANGE)
		status.position = Vector2(24 if team == 0 else 704, 104)
		status.size.x = 424
		if team == 1:
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fusion_labels.append(status)
	var hint := make_label(match_ui, "WASD + ЛКМ / SPACE · Q — УЛЬТА     P2: СТРЕЛКИ + ENTER · ПРАВЫЙ SHIFT", 12, MUTED)
	hint.position = Vector2(60, 681)
	var back := make_button(match_ui, "МЕНЮ / ESC", show_main_menu)
	back.position = Vector2(954, 673)
	back.size = Vector2(166, 34)
	update_score()
	update_fusion_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if state != "offline" or countdown > 0 or not event is InputEventKey or not event.pressed or event.echo:
		return
	for player in players:
		if (player.human_index == 0 and event.physical_keycode == KEY_Q) or (player.human_index == 1 and event.physical_keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT):
			cast_ultimate(player)

func _physics_process(delta: float) -> void:
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0)
	if state != "offline":
		return
	elapsed += delta
	countdown = maxf(0, countdown - delta)
	countdown_label.text = str(ceili(countdown)) if countdown > 0 else ""
	for key in collision_cooldowns.keys():
		collision_cooldowns[key] -= delta
		if collision_cooldowns[key] <= 0:
			collision_cooldowns.erase(key)
	for player in players:
		player.position = player.position.clamp(ARENA_BOUNDS.position, ARENA_BOUNDS.end)
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		if player.is_dead or countdown > 0:
			continue
		if player.bot:
			if ai_enabled:
				control_bot(player)
		else:
			player.move_intent = keyboard_direction(player.human_index)
			player.attack_intent = Input.is_physical_key_pressed(KEY_SPACE if player.human_index == 0 else KEY_ENTER)
			if player.move_intent.length_squared() > 0.01:
				player.aim_direction = player.move_intent.normalized()
			if player.human_index == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				player.aim_direction = (get_global_mouse_position() - player.position).normalized()
				player.attack_intent = true
	if countdown <= 0:
		resolve_contacts()
		update_fusions(delta)
		update_projectiles(delta)
	update_fusion_ui()

func nearest_enemy(player):
	var result = null
	var best: float = INF
	for other in players:
		if other.team == player.team or other.is_dead:
			continue
		var distance: float = player.position.distance_squared_to(other.position)
		if distance < best:
			best = distance
			result = other
	return result

func teammate(player):
	for other in players:
		if other != player and other.team == player.team:
			return other
	return null

func control_bot(player) -> void:
	var target = nearest_enemy(player)
	if target == null:
		return
	var offset: Vector2 = target.position - player.position
	var toward := offset.normalized()
	player.aim_direction = toward
	var distance := offset.length()
	if distance > 300:
		player.move_intent = toward
	elif distance < 150:
		player.move_intent = -toward
	else:
		player.move_intent = toward.orthogonal() * sin(elapsed * 0.7 + player.get_index()) * 0.45
	player.attack_intent = distance < 470 and player.energy >= 12
	if player.energy < 15:
		player.move_intent = -toward
	if squad:
		var partner = teammate(player)
		if partner != null and not partner.is_dead:
			var gap: Vector2 = partner.position - player.position
			var charge: Dictionary = fusion[player.team]
			if not charge.ready and charge.armed and (player.team == 0 or fmod(elapsed, 12) < 4.5):
				player.move_intent = gap.normalized() if gap.length() > 30 else Vector2.ZERO
			elif not charge.ready and not charge.armed and gap.length() < 120:
				player.move_intent = -gap.normalized()

			if player.team == 1 and charge.ready and charge.age > 1.2 and distance < 420:
				cast_ultimate(player)

func resolve_attack(attacker) -> void:
	if state != "offline" or countdown > 0 or attacker.is_dead:
		return
	spawn_projectile(attacker, false)

func spawn_projectile(attacker, ultimate: bool, pair: Array = []) -> void:
	if projectiles.size() >= 128:
		return
	var dir: Vector2 = attacker.facing_direction.normalized()
	if ultimate:
		dir = attacker.aim_direction.normalized()
	if dir.length_squared() < 0.1:
		dir = Vector2.RIGHT
	projectiles.append({"pos": attacker.position + dir * 32, "vel": dir * (310.0 if ultimate else SHOT_SPEED[attacker.element]), "team": attacker.team, "element": attacker.element, "life": 2.2 if ultimate else 1.5, "ultimate": ultimate, "pair": pair.duplicate(), "radius": 19.0 if ultimate else 7.0, "damage": 40 if ultimate else SHOT_DAMAGE[attacker.element]})

func update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var previous: Vector2 = shot.pos
		shot.pos += shot.vel * delta
		shot.life -= delta
		var hit = null
		var best: float = INF
		for target in players:
			if target.team == shot.team or target.is_dead or target.invincible_time > 0:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(target.position, previous, shot.pos)
			if closest.distance_to(target.position) < 23.0 + shot.radius:
				var distance: float = previous.distance_squared_to(target.position)
				if distance < best:
					best = distance
					hit = target
		var expired: bool = shot.life <= 0 or not MAP_RECT.has_point(shot.pos)
		if hit != null or expired:
			if shot.ultimate:
				explode_fusion(shot, hit.position if hit != null else shot.pos)
			elif hit != null:
				apply_element_hit(hit, int(shot.element), int(shot.damage), int(shot.team), shot.vel.normalized())
			projectiles.remove_at(index)
		if state != "offline":
			break

func pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

func receive_damage(target, amount: int, _team: int, _owner: int = -1) -> void:
	target.take_damage(amount)

func apply_element_hit(target, element: int, damage: int, attacking_team: int, direction: Vector2) -> void:
	if target.is_dead or target.invincible_time > 0 or target.team == attacking_team:
		return
	var reaction := ""
	var key := pair_key(element, target.applied_element)
	if target.applied_element >= 0 and target.applied_element != element and target.element_time > 0:
		match key:
			"0:1":
				damage += 12
				reaction = "ПАР +12"
			"0:2":
				damage += 16
				reaction = "ТАЯНИЕ +16"
			"0:3":
				damage += 10
				target.push_velocity += direction * 220
				reaction = "ПЕРЕГРУЗКА"
			"1:2":
				target.slow_time = 2.4
				reaction = "ЗАМОРОЗКА"
			"1:3":
				reaction = "ЦЕПНАЯ МОЛНИЯ"
				for other in players:
					if other != target and other.team == target.team and not other.is_dead and other.position.distance_to(target.position) < 180:
						receive_damage(other,10,attacking_team)
						add_effect(other.position, ELEMENT_COLORS[3], 42, "ЦЕПЬ −10")
			"2:3":
				damage += 8
				target.slow_time = 1.5
				reaction = "СВЕРХПРОВОДНИК"
		target.applied_element = -1
		target.element_time = 0
	else:
		target.applied_element = element
		target.element_time = 3.0
	if element == 2:
		target.chill_time = maxf(target.chill_time, 0.9)
	receive_damage(target,damage,attacking_team)
	add_effect(target.position, ELEMENT_COLORS[element], 34 if reaction.is_empty() else 62, "−%d" % damage if reaction.is_empty() else reaction)

func resolve_contacts() -> void:
	for i in range(players.size()):
		var a = players[i]
		if a.is_dead:
			continue
		for j in range(i + 1, players.size()):
			var b = players[j]
			if b.is_dead or a.team == b.team:
				continue
			var offset: Vector2 = b.position - a.position
			var distance := offset.length()
			if distance >= 46:
				continue
			var normal := offset / distance if distance > 0.01 else Vector2.RIGHT
			var correction := normal * (46.0 - distance) * 0.5
			a.position -= correction
			b.position += correction
			var key := "%d:%d" % [i, j]
			if not collision_cooldowns.has(key):
				a.push_velocity = -normal * 180.0
				b.push_velocity = normal * 180.0
				collision_cooldowns[key] = 0.45
				add_effect((a.position + b.position) / 2, WHITE, 35, "")

func update_fusions(delta: float) -> void:
	if not squad:
		return
	for team in range(2):
		var allies := players.filter(func(p): return p.team == team)
		if allies.size() != 2 or allies[0].is_dead or allies[1].is_dead:
			continue
		var charge: Dictionary = fusion[team]
		charge.age += delta
		var gap: float = allies[0].position.distance_to(allies[1].position)
		if not charge.ready and gap >= 110:
			charge.armed = true
		if not charge.ready and charge.armed and gap <= 46:
			charge.ready = true
			charge.armed = false
			charge.age = 0.0
			charge.pair = [allies[0].element, allies[1].element]
			fusion_count += 1
			add_effect((allies[0].position + allies[1].position) / 2, Color("#ffe7a2"), 95, "СЛИЯНИЕ · УЛЬТА ГОТОВА")

func cast_ultimate(player) -> bool:
	if state != "offline" or countdown > 0 or not squad or player.is_dead:
		return false
	var charge: Dictionary = fusion[player.team]
	if not charge.ready:
		return false

	charge.ready = false
	charge.armed = false
	charge.age = 0.0
	ultimate_count += 1
	spawn_projectile(player, true, charge.pair)
	add_effect(player.position, Color("#ffe7a2"), 60, FUSION_NAMES[pair_key(charge.pair[0], charge.pair[1])])
	return true

func explode_fusion(shot: Dictionary, center: Vector2) -> void:
	var pair: Array = shot.pair
	var key := pair_key(pair[0], pair[1])
	var radius := 130.0
	add_effect(center, ELEMENT_COLORS[pair[0]].lerp(ELEMENT_COLORS[pair[1]], 0.5), radius, FUSION_NAMES[key])
	for target in players:
		if target.team == shot.team or target.is_dead or target.invincible_time > 0 or target.position.distance_to(center) > radius:
			continue
		var damage := 40
		if key == "0:1" or key == "0:2" or key == "0:0":
			damage = 52
		if 2 in pair:
			target.slow_time = 2.5
		if 3 in pair or key == "1:1":
			var outward: Vector2 = (target.position - center).normalized()
			if outward.length_squared() < 0.01:
				outward = shot.vel.normalized()
			target.push_velocity += outward * 260
		target.applied_element = pair[1]
		target.element_time = 3.0
		receive_damage(target,damage,int(shot.team),int(shot.get("owner",-1)))

func update_fusion_ui() -> void:
	for team in range(fusion_labels.size()):
		if not squad:
			fusion_labels[team].text = "РЕАКЦИИ ЭЛЕМЕНТОВ · БЕЗ СЛИЯНИЯ"
		elif fusion[team].ready:
			var pair: Array = fusion[team].pair
			fusion_labels[team].text = "УЛЬТА: " + FUSION_NAMES[pair_key(pair[0], pair[1])] + (" [Q / R.SHIFT]" if team == 0 else "")
		elif fusion[team].armed:
			fusion_labels[team].text = "СОЕДИНИТЕСЬ С СОЮЗНИКОМ → УЛЬТА"
		else:
			fusion_labels[team].text = "РАЗОЙДИТЕСЬ → СОЕДИНИТЕСЬ СНОВА"

func on_defeated(player) -> void:
	if state != "offline":
		return
	var winner: int = 1 - player.team
	scores[winner] += 1
	update_score()
	if scores[winner] >= goal_score:
		show_result(winner)
		return
	var epoch := match_id
	await get_tree().create_timer(player.respawn_time).timeout
	if epoch == match_id and state == "offline" and is_instance_valid(player):
		player.respawn()

func show_result(winner: int) -> void:
	state = "result"
	for player in players:
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		player.set_physics_process(false)
	var box := create_menu_card(520)
	make_label(box, ("СИНЯЯ" if winner == 0 else "ОРАНЖЕВАЯ") + " КОМАНДА ПОБЕДИЛА", 23, BLUE if winner == 0 else ORANGE)
	make_label(box, "%d — %d" % [scores[0], scores[1]], 48, WHITE)
	make_button(box, "ЕЩЁ МАТЧ", func(): start_offline(match_mode))
	make_button(box, "ЭЛЕМЕНТЫ И РЕЖИМЫ", show_main_menu)

func add_effect(pos: Vector2, color: Color, radius: float, caption: String) -> void:
	if effects.size() >= 80:
		effects.pop_front()
	effects.append({"pos": pos, "color": color, "radius": radius, "life": 0.85, "text": caption})

func _draw() -> void:
	super._draw()
	var font := ThemeDB.fallback_font
	for player in players:
		if not is_instance_valid(player):
			continue
		var color: Color = ELEMENT_COLORS[player.element]
		draw_arc(player.position + Vector2(0, 35), 26, 0, TAU, 32, color, 2, true)
		if not player.is_dead:
			draw_circle(player.position + Vector2(0, -40), 4, color)
			if player.applied_element >= 0:
				draw_arc(player.position, 37, -PI / 2, -PI / 2 + TAU * player.element_time / 3, 28, ELEMENT_COLORS[player.applied_element], 2, true)
			if player.human_index >= 0:
				var aim: Vector2 = player.aim_direction.normalized()
				draw_line(player.position + aim * 35, player.position + aim * 58, Color(color, 0.8), 2, true)
			if squad and fusion[player.team].ready:
				draw_arc(player.position, 43, elapsed * 2, elapsed * 2 + PI * 1.4, 28, Color("#ffe7a2"), 2, true)
	for shot in projectiles:
		var pos: Vector2 = shot.pos
		var dir: Vector2 = shot.vel.normalized()
		var side := dir.orthogonal()
		var color: Color = ELEMENT_COLORS[shot.element]
		if shot.ultimate:
			color = ELEMENT_COLORS[shot.pair[0]].lerp(ELEMENT_COLORS[shot.pair[1]], 0.5)
			draw_circle(pos, 24, Color(color, 0.15))
			draw_circle(pos, 16, color)
			draw_arc(pos, 23, elapsed * 8, elapsed * 8 + PI * 1.6, 24, Color("#fff3c4"), 3, true)
		elif shot.element == 0:
			draw_colored_polygon(PackedVector2Array([pos + dir * 10, pos + side * 7 - dir * 5, pos - dir * 24, pos - side * 7 - dir * 5]), color)
			draw_circle(pos, 4, Color("#fff0a5"))
		elif shot.element == 1:
			draw_line(pos - dir * 22, pos, Color(color, 0.4), 9, true)
			draw_circle(pos, 8, color)
			draw_circle(pos - side * 2 + dir * 2, 3, WHITE)
		elif shot.element == 2:
			draw_colored_polygon(PackedVector2Array([pos + dir * 13, pos + side * 6, pos - dir * 13, pos - side * 6]), color)
			draw_line(pos - dir * 8, pos + dir * 8, WHITE, 2, true)
		else:
			draw_polyline(PackedVector2Array([pos - dir * 22, pos - dir * 8 + side * 6, pos - side * 6, pos + dir * 12]), color, 4, true)
	for fx in effects:
		var progress: float = 1.0 - fx.life / 0.85
		var color: Color = fx.color
		color.a = 1.0 - progress
		draw_arc(fx.pos, maxf(2, fx.radius * progress), 0, TAU, 40, color, 2, true)
		if not fx.text.is_empty():
			var text_pos: Vector2 = fx.pos + Vector2(-font.get_string_size(fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / 2, -38 - progress * 25)
			draw_string_outline(font, text_pos, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.03, 0.04, 0.07, color.a))
			draw_string(font, text_pos, fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
