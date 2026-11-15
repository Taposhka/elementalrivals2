extends "res://matchmaking_arena.gd"

const AUDIO = preload("res://combat_audio.gd")
const ANNOUNCER = preload("res://combat_announcer.gd")
const MULTI_NAMES := {2: "DOUBLE KILL", 3: "TRIPLE KILL", 4: "QUADRA KILL", 5: "PENTA KILL"}
const STREAK_NAMES := {3: "KILLING SPREE", 5: "RAMPAGE", 7: "UNSTOPPABLE", 10: "GODLIKE"}
var sound_bank: Node
var announcer: Control
var active_actor: int = -1
var creating_spell: bool = false
var last_damage: Dictionary = {}
var handled_deaths: Dictionary = {}
var streaks: Array[int] = [0,0,0,0]
var chains: Array[int] = [0,0,0,0]
var last_kills: Array[float] = [-100,-100,-100,-100]
var kill_count: int = 0
var combat_events: Array[Dictionary] = []
var combat_event_id: int = 0
var last_remote_event: int = 0

func _ready() -> void:
	super._ready()
	sound_bank = Node.new()
	sound_bank.set_script(AUDIO)
	add_child(sound_bank)
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	announcer = Control.new()
	announcer.set_script(ANNOUNCER)
	announcer.arena = self
	layer.add_child(announcer)

func clear_match() -> void:
	last_damage.clear()
	handled_deaths.clear()
	combat_events.clear()
	combat_event_id = 0
	last_remote_event = 0
	active_actor = -1
	kill_count = 0
	streaks = [0,0,0,0]
	chains = [0,0,0,0]
	last_kills = [-100,-100,-100,-100]
	if is_instance_valid(sound_bank): sound_bank.stop_all()
	if is_instance_valid(announcer): announcer.reset()
	super.clear_match()

func begin_match(mode: String, epoch: int) -> void:
	super.begin_match(mode, epoch)
	countdown = 1.0
	shield_build_seconds = 3.0
	for player in players:
		player.returned_to_play.connect(clear_life_credit)

func clear_life_credit(player) -> void:
	if practice and player.bot: player.invincible_time = 0
	last_damage.erase(player.get_instance_id())
	handled_deaths.erase(player.get_instance_id())

func spawn_projectile(attacker, ultimate: bool, pair: Array = []) -> void:
	var before := projectiles.size()
	var prior := active_actor
	active_actor = players.find(attacker)
	super.spawn_projectile(attacker, ultimate, pair)
	for index in range(before,projectiles.size()): projectiles[index]["owner"] = active_actor
	if not ultimate: record_combat_event({"type":"attack","actor":active_actor,"element":attacker.element,"pos":attacker.position})
	active_actor = prior

func hit_cone(attacker, direction: Vector2, reach: float, half_angle: float, damage: int, knockback: float) -> void:
	var prior := active_actor
	active_actor = players.find(attacker)
	super.hit_cone(attacker,direction,reach,half_angle,damage,knockback)
	active_actor = prior

func resolve_fire_dash_step(attacker, previous: Vector2, current: Vector2) -> void:
	var prior := active_actor
	active_actor = players.find(attacker)
	super.resolve_fire_dash_step(attacker,previous,current)
	active_actor = prior

func projectile_element_hit(target, shot: Dictionary) -> void:
	var prior := active_actor
	active_actor = int(shot.get("owner",-1))
	super.projectile_element_hit(target,shot)
	active_actor = prior

func on_projectile_impact(shot: Dictionary, impact: Vector2, kind: String) -> void:
	var prior := active_actor
	active_actor = int(shot.get("owner",-1))
	super.on_projectile_impact(shot,impact,kind)
	active_actor = prior

func add_flood(point: Vector2, team: int) -> void:
	super.add_flood(point,team)
	if active_actor < 0: return
	for flood in floods:
		if flood.team == team and Vector2(flood.pos).distance_to(point) < 65: flood["owner"] = active_actor

func explode_fusion(shot: Dictionary, center: Vector2) -> void:
	var prior := active_actor
	active_actor = int(shot.get("owner",-1))
	super.explode_fusion(shot,center)
	active_actor = prior

func cast_ultimate(player) -> bool:
	var prior := active_actor
	active_actor = players.find(player)
	var cast := super.cast_ultimate(player)
	active_actor = prior
	return cast

func create_spell(pair: Array, team: int, target: Vector2, direction: Vector2) -> Dictionary:
	creating_spell = true
	var zone := super.create_spell(pair,team,target,direction)
	creating_spell = false
	zone["owner"] = active_actor
	record_combat_event({"type":"spell","actor":active_actor,"key":zone.key,"pos":zone.pos})
	return zone

func receive_damage(target, amount: int, team: int, owner: int = -1) -> void:
	if target.is_dead or target.invincible_time > 0 or amount <= 0: return
	if team >= 0 and target.team == team: return
	var actor := owner if owner >= 0 else active_actor
	if actor >= 0 and actor < players.size() and players[actor].team == team and target.team != team:
		last_damage[target.get_instance_id()] = {"actor":actor,"at":elapsed}
	var before: float = target.hp
	super.receive_damage(target,amount,team,owner)
	var dealt := int(ceil(before-target.hp))
	if dealt > 0:
		record_combat_event({"type":"hit","actor":actor,"victim":players.find(target),"amount":dealt,"pos":target.position})

func on_defeated(player) -> void:
	if state != "offline" or handled_deaths.get(player.get_instance_id(),false): return
	handled_deaths[player.get_instance_id()] = true
	var victim: int = players.find(player)
	var defeated_streak: int = streaks[victim] if victim >= 0 else 0
	if victim >= 0:
		streaks[victim] = 0
		chains[victim] = 0
		last_kills[victim] = -100
	var credit: Dictionary = last_damage.get(player.get_instance_id(),{})
	var actor: int = int(credit.get("actor",-1))
	if actor >= 0 and actor < players.size() and players[actor].team != player.team and elapsed-float(credit.at) <= 8:
		kill_count += 1
		streaks[actor] += 1
		chains[actor] = chains[actor]+1 if elapsed-last_kills[actor] <= 6 else 1
		last_kills[actor] = elapsed
		var title := ""
		if defeated_streak >= 3: title = "SHUTDOWN"
		elif chains[actor] >= 2: title = MULTI_NAMES.get(chains[actor],"MULTI KILL")
		elif STREAK_NAMES.has(streaks[actor]): title = STREAK_NAMES[streaks[actor]]
		elif kill_count == 1: title = "FIRST BLOOD"
		record_combat_event({"type":"kill","actor":actor,"victim":victim,"team":players[actor].team,"element":players[actor].element,"title":title,"chain":chains[actor],"streak":streaks[actor],"pos":player.position})
	last_damage.erase(player.get_instance_id())
	super.on_defeated(player)

func record_combat_event(event: Dictionary) -> void:
	combat_event_id += 1
	event["id"] = combat_event_id
	combat_events.append(event)
	if combat_events.size() > 96: combat_events.pop_front()
	if not service_match and (not online_active or multiplayer.is_server()): present_combat_event(event)

func present_combat_event(event: Dictionary) -> void:
	var kind: String = event.type
	if kind == "kill":
		if is_instance_valid(announcer): announcer.present(event)
		if is_instance_valid(sound_bank): sound_bank.play("combo" if not str(event.title).is_empty() else "explosion",-3,1.0,3)
		if event.title == "SHUTDOWN" and is_instance_valid(sound_bank): sound_bank.play("explosion",-9,1.0,3)
		impact_views(int(event.actor),int(event.victim),5)
	elif kind == "hit":
		var actor: int = int(event.actor)
		var victim: int = int(event.victim)
		if event.amount >= 8:
			impact_views(actor,victim,1.7)
			if is_instance_valid(sound_bank) and actor >= 0 and players[actor].human_index >= 0:
				sound_bank.play("hit",-13,1.08,1)
	elif kind == "attack":
		if not is_instance_valid(sound_bank): return
		var keys := ["fire_dash","water_attack","ice_attack","electric_attack","wind_attack"]
		var distance := sound_distance(event.pos)
		if distance < 850:
			var actor: int = int(event.actor)
			var priority: int = 1 if actor >= 0 and players[actor].human_index >= 0 else 0
			sound_bank.play(keys[int(event.element)],-3-distance/90.0,randf_range(0.97,1.03),priority)
	elif kind == "spell":
		play_spell_sound(str(event.key))

func sound_distance(point: Vector2) -> float:
	var distance: float = 10000
	for player in players:
		if player.human_index >= 0: distance = minf(distance,player.position.distance_to(point))
	return distance

func impact_views(actor: int, victim: int, strength: float) -> void:
	for view in views:
		var index: int = players.find(view.viewer)
		if index == actor or index == victim: view.impact(strength)

func play_spell_sound(key: String) -> void:
	if creating_spell or not is_instance_valid(sound_bank): return
	match key:
		"0:1": sound_bank.play("steam_burst",-3,1,2)
		"0:0","0:2":
			sound_bank.play("explosion",-5,1,2)
			if key == "0:2": sound_bank.play("ice_burst",-10,1,2)
		"0:3":
			sound_bank.play("fire_burst",-6,1,2)
			sound_bank.play("thunder_burst",-8,1,2)
		"0:4":
			sound_bank.play("fire_burst",-5,1,2)
			sound_bank.play("wind_burst",-8,1,2)
		"1:1","1:2","1:4":
			sound_bank.play("water_burst",-4,1,2)
			if key == "1:2": sound_bank.play("ice_burst",-8,1,2)
			elif key == "1:4": sound_bank.play("wind_burst",-8,1,2)
		"1:3":
			sound_bank.play("electric_burst",-3,1,2)
			sound_bank.play("water_burst",-8,1,2)
		"2:2","2:3","2:4":
			sound_bank.play("ice_burst",-4,1,2)
			if key == "2:3": sound_bank.play("electric_burst",-8,1,2)
			elif key == "2:4": sound_bank.play("wind_burst",-8,1,2)
		"3:3","3:4":
			sound_bank.play("thunder_burst",-4,1,2)
			if key == "3:4": sound_bank.play("wind_burst",-9,1,2)
		"4:4": sound_bank.play("wind_burst",-4,1,2)

func snapshot_for(peer: int) -> Dictionary:
	var data := super.snapshot_for(peer)
	data["combat_events"] = combat_events
	return data

func apply_remote_snapshot(data: Dictionary) -> void:
	super.apply_remote_snapshot(data)
	for event in data.get("combat_events",[]):
		if not event is Dictionary or int(event.get("id",0)) <= last_remote_event: continue
		last_remote_event = int(event.id)
		present_combat_event(event)

func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button := super.make_button(parent,text,action)
	button.pressed.connect(func():
		if is_instance_valid(sound_bank): sound_bank.play("swipe",-15,1.15,0)
	)
	return button
