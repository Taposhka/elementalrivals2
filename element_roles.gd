extends "res://network_arena.gd"

const PROFILES = preload("res://element_profiles.gd")
var floods: Array[Dictionary] = []
var combat_visuals: Array[Dictionary] = []
var fire_dashes: Dictionary = {}

func clear_match() -> void:
	floods.clear()
	combat_visuals.clear()
	fire_dashes.clear()
	super.clear_match()

func begin_match(mode: String, epoch: int) -> void:
	super.begin_match(mode, epoch)
	for player in players:
		player.apply_element_profile()
		player.dash_advanced.connect(resolve_fire_dash_step)

func _physics_process(delta: float) -> void:
	if state == "offline" and countdown <= 0 and (not online_active or multiplayer.is_server()):
		update_fire_dashes()
	super._physics_process(delta)
	if state != "offline": return
	for fx in combat_visuals:
		fx.life -= delta
	combat_visuals = combat_visuals.filter(func(fx): return fx.life > 0)
	if online_active and not multiplayer.is_server(): return
	if countdown > 0: return
	update_floods(delta)

func resolve_attack(attacker) -> void:
	if state != "offline" or countdown > 0 or attacker.is_dead: return
	spawn_projectile(attacker, false)

func spawn_projectile(attacker, ultimate: bool, pair: Array = []) -> void:
	if ultimate:
		super.spawn_projectile(attacker, ultimate, pair)
		return
	var profile: Dictionary = PROFILES.get_profile(attacker.element)
	var direction: Vector2 = attacker.aim_direction.normalized()
	if direction.length_squared() < 0.01: direction = Vector2.RIGHT
	match attacker.element:
		0:
			fire_dashes[attacker.get_instance_id()] = {"player": attacker, "last": attacker.position, "dir": direction, "team": attacker.team, "damage": 34, "hits": {}}
		1:
			for angle in [-0.16, 0.0, 0.16]:
				add_role_projectile(attacker, direction.rotated(angle), profile.range, profile.shot_speed, profile.damage, profile.radius)
		4:
			var stage: int = attacker.last_combo_stage
			var ranges := [330.0, 205.0, 94.0]
			var damages := [15, 22, 32]
			var widths := [4.0, 9.0, 0.0]
			if stage < 2:
				add_role_projectile(attacker, direction, ranges[stage], 530.0, damages[stage], widths[stage])
			else:
				combat_visuals.append({"kind": "gust", "pos": attacker.position, "dir": direction, "radius": 94.0, "angle": 0.8, "team": attacker.team, "life": 0.3, "max_life": 0.3, "element": 4})
				hit_cone(attacker, direction, 94.0, 0.8, 32, 210.0)
		_:
			add_role_projectile(attacker, direction, profile.range, profile.shot_speed, profile.damage, profile.radius)

func update_fire_dashes() -> void:
	for id in fire_dashes.keys():
		var dash: Dictionary = fire_dashes[id]
		var attacker = dash.player
		if not is_instance_valid(attacker) or attacker.is_dead or attacker.dash_time <= 0 or attacker.bounce_time > 0:
			fire_dashes.erase(id)

func resolve_fire_dash_step(attacker, previous: Vector2, current: Vector2) -> void:
	var id: int = attacker.get_instance_id()
	if not fire_dashes.has(id) or attacker.is_dead: return
	var dash: Dictionary = fire_dashes[id]
	if previous.distance_squared_to(current) > 0.01:
		combat_visuals.append({"kind": "dash", "pos": previous + Vector2(0, 7), "end": current + Vector2(0, 7), "team": dash.team, "element": 0, "life": 0.16, "max_life": 0.16})
		if combat_visuals.size() > 96: combat_visuals.pop_front()
		for target in players:
			if target.team == dash.team or target.is_dead or target.invincible_time > 0: continue
			var token := "p%d" % target.get_instance_id()
			if dash.hits.has(token): continue
			var closest := Geometry2D.get_closest_point_to_segment(target.position, previous, current)
			if closest.distance_to(target.position) <= 28:
				dash.hits[token] = true
				apply_element_hit(target, 0, int(dash.damage), int(dash.team), dash.dir)
		for index in range(mobs.size()):
			var mob: Dictionary = mobs[index]
			var token := "m%d" % index
			if mob.hp <= 0 or dash.hits.has(token): continue
			if Geometry2D.get_closest_point_to_segment(mob.pos, previous, current).distance_to(mob.pos) <= 32:
				dash.hits[token] = true
				hit_mob(mob, int(dash.damage))
		if not dash.hits.has("flag") and Geometry2D.get_closest_point_to_segment(FLAG_POSITION, previous, current).distance_to(FLAG_POSITION) <= 56:
			dash.hits["flag"] = true
			hit_flag(int(dash.team), int(dash.damage))
	dash.last = current
	if attacker.dash_time <= 0 or attacker.bounce_time > 0:
		fire_dashes.erase(id)

func add_role_projectile(attacker, direction: Vector2, reach: float, travel_speed: float, damage: int, radius: float) -> void:
	if projectiles.size() >= 128: return
	projectiles.append({"pos": attacker.position + direction * 20, "vel": direction * travel_speed, "team": attacker.team, "element": attacker.element, "life": maxf(0.01, (reach - 20.0) / travel_speed), "ultimate": false, "pair": [], "radius": radius, "damage": damage})

func cone_contains(origin: Vector2, direction: Vector2, reach: float, half_angle: float, point: Vector2, padding: float = 16.0) -> bool:
	var offset := point - origin
	if offset.length() > reach + padding: return false
	if offset.length() <= padding: return true
	return direction.dot(offset.normalized()) >= cos(half_angle + atan2(padding, offset.length()))

func hit_cone(attacker, direction: Vector2, reach: float, half_angle: float, damage: int, knockback: float) -> void:
	for target in players:
		if target.team == attacker.team or target.is_dead or target.invincible_time > 0: continue
		if cone_contains(attacker.position, direction, reach, half_angle, target.position):
			apply_element_hit(target, attacker.element, damage, attacker.team, direction)
			target.push_velocity += direction * knockback
	for mob in mobs:
		if mob.hp > 0 and cone_contains(attacker.position, direction, reach, half_angle, mob.pos, 20):
			hit_mob(mob, damage)
	if cone_contains(attacker.position, direction, reach, half_angle, FLAG_POSITION, 44):
		hit_flag(attacker.team, damage)

func on_projectile_impact(shot: Dictionary, impact: Vector2, _hit_kind: String) -> void:
	if shot.element == 1 and not shot.ultimate:
		add_flood(impact, int(shot.team))

func add_flood(point: Vector2, team: int) -> void:
	for flood in floods:
		if flood.team == team and Vector2(flood.pos).distance_to(point) < 65:
			flood.life = 3.8
			return
	var owned: Array = floods.filter(func(flood): return flood.team == team)
	if owned.size() >= 6: floods.erase(owned[0])
	floods.append({"pos": point.clamp(WORLD_LIMITS.position, WORLD_LIMITS.end), "team": team, "life": 3.8, "age": 0.0, "radius": 24.0, "tick": 0.0})

func update_floods(delta: float) -> void:
	for index in range(floods.size() - 1, -1, -1):
		var flood: Dictionary = floods[index]
		flood.life -= delta
		flood.age += delta
		flood.radius = minf(56.0, 24.0 + flood.age * 40.0)
		if flood.life <= 0:
			floods.remove_at(index)
			continue
		flood.tick -= delta
		if flood.tick > 0: continue
		flood.tick = 0.6
		for target in players:
			if target.team == flood.team or target.is_dead or target.invincible_time > 0: continue
			if target.position.distance_to(flood.pos) <= flood.radius:
				receive_damage(target,4,int(flood.team),int(flood.get("owner",-1)))
				target.applied_element = 1
				target.element_time = 1.5
				reveal_to(target, int(flood.team))
		for mob in mobs:
			if mob.hp > 0 and Vector2(mob.pos).distance_to(flood.pos) <= flood.radius:
				hit_mob(mob, 4)
		if FLAG_POSITION.distance_to(flood.pos) <= flood.radius:
			hit_flag(int(flood.team), 4)

func apply_element_hit(target, element: int, damage: int, attacking_team: int, direction: Vector2) -> void:
	if target.is_dead or target.invincible_time > 0 or target.team == attacking_team: return
	super.apply_element_hit(target, element, damage, attacking_team, direction)
	if element == 2:
		target.chill_time = maxf(target.chill_time, 0.9)

func snapshot_for(peer: int) -> Dictionary:
	var data := super.snapshot_for(peer)
	data["floods"] = floods
	data["combat_visuals"] = combat_visuals
	return data

func is_visible_to(target, team: int) -> bool:
	if super.is_visible_to(target, team): return true
	if online_active and not multiplayer.is_server(): return false
	if brush_at(target.position) >= 0: return false
	for ally in players:
		if ally.team == team and ally.element == 3 and not ally.is_dead and ally.position.distance_to(target.position) <= 820:
			return true
	return false

func control_bot(player) -> void:
	super.control_bot(player)
	var target = nearest_enemy(player)
	var attack_point: Vector2 = FLAG_POSITION
	if target != null:
		attack_point = target.position
	else:
		for mob in mobs:
			if mob.hp > 0 and player.position.distance_to(mob.pos) < player.position.distance_to(attack_point):
				attack_point = mob.pos
	var offset: Vector2 = attack_point - player.position
	var profile: Dictionary = PROFILES.get_profile(player.element)
	var reach: float = profile.range
	var preferred: float = [45.0, 215.0, 270.0, 440.0, 180.0][player.element]
	if player.element == 4:
		preferred = [260.0, 150.0, 75.0][player.combo_stage]
	if target != null or (flag_shield > 0 and flag_owner != player.team):
		player.aim_direction = offset.normalized()
		player.attack_intent = offset.length() < reach + 12 and player.energy >= profile.cost
		if offset.length() > preferred + 30:
			player.move_intent = offset.normalized()
		elif target != null and offset.length() < preferred - 45 and player.element != 0:
			player.move_intent = -offset.normalized()
	if squad:
		var partner = teammate(player)
		if partner != null and not partner.is_dead and not fusion[player.team].ready:
			var gap: Vector2 = partner.position - player.position
			if fusion[player.team].armed and gap.length() < 360:
				player.move_intent = gap.normalized()
			elif not fusion[player.team].armed and gap.length() < 125:
				player.move_intent = -gap.normalized()
