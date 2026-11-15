extends "res://image_removebg_preview.gd"
signal dash_advanced(player, previous: Vector2, current: Vector2)
signal returned_to_play(player)

const DEATH_SHEET: Texture2D = preload("res://assets/deathanimation.png")
const BOUNCE_SHEET: Texture2D = preload("res://assets/bouncebacklinefinal.png")
var bounce_time: float = 0.0
var team: int = 0
var element: int = 0
var bot: bool = false
var human_index: int = -1
var aim_direction := Vector2.RIGHT
var push_velocity := Vector2.ZERO
var slow_time: float = 0.0
var element_time: float = 0.0
var applied_element: int = -1
var invincible_time: float = 0.0
var flash_time: float = 0.0
var base_move_speed: float = 160.0
var chill_time: float = 0.0
var attack_cooldown: float = 0.0
var attack_recovery: float = 0.0
var combo_stage: int = 0
var last_combo_stage: int = 0
var combo_time: float = 0.0
var dash_time: float = 0.0
var dash_velocity := Vector2.ZERO
const ELEMENT_PROFILE = preload("res://element_profiles.gd")

func apply_element_profile() -> void:
	var profile: Dictionary = ELEMENT_PROFILE.get_profile(element)
	base_move_speed = profile.speed
	attack_energy_cost = profile.cost
	energy_regen_per_second = 28.0
	energy_regen_delay = 0.35
	max_hp = 100
	var frames := body_sprite.sprite_frames
	frames.set_animation_speed("attack", float(frames.get_frame_count("attack")) / maxf(0.1, profile.cooldown * 0.85))
	frames.set_animation_speed("walk",7.0*float(profile.speed)/155.0)

func can_move_while_attacking() -> bool:
	return true

func _on_attack_frame() -> void:
	pass

func network_state() -> Dictionary:
	var data := super.network_state()
	data.merge({"combo_stage": combo_stage, "combo_time": combo_time, "chill": chill_time, "slow": slow_time, "applied": applied_element, "element_time": element_time})
	return data

func apply_network_state(data: Dictionary) -> void:
	super.apply_network_state(data)
	combo_stage = int(data.get("combo_stage", 0))
	combo_time = float(data.get("combo_time", 0.0))
	chill_time = float(data.get("chill", 0.0))
	slow_time = float(data.get("slow", 0.0))
	applied_element = int(data.get("applied", -1))
	element_time = float(data.get("element_time", 0.0))

func configure_animations() -> void:
	super.configure_animations()
	body_includes_head = true
	var frames := body_sprite.sprite_frames

	for anim in ["idle", "hurt"]:
		frames.clear(anim)
		frames.add_frame(anim, frames.get_frame_texture("attack", 0))
		frames.set_animation_speed(anim, 4.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("hurt", false)
	frames.set_animation_speed("attack", 7.0)
	frames.set_animation_speed("walk", 6.0)
	frames.clear("death")
	frames.set_animation_speed("death", 2.4)
	frames.set_animation_loop("death", false)
	for region in [Rect2(442, 373, 198, 198), Rect2(1233, 320, 198, 214), Rect2(2110, 372, 230, 166)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = DEATH_SHEET
		atlas.region = region
		atlas.filter_clip = true
		var padding: Vector2 = Vector2(230, 214) - region.size
		atlas.margin = Rect2(Vector2(padding.x / 2, padding.y), padding)
		frames.add_frame("death", atlas)
	animation_size_multipliers["death"] = 214.0 / 198.0
	if not frames.has_animation("bounce"): frames.add_animation("bounce")
	frames.clear("bounce")
	frames.set_animation_speed("bounce", 32)
	frames.set_animation_loop("bounce", false)
	for region in [Rect2(426,379,141,141), Rect2(1309,373,141,141), Rect2(2223,368,140,140), Rect2(3160,377,140,138), Rect2(3967,379,140,141), Rect2(4858,391,140,141), Rect2(5793,391,138,141)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = BOUNCE_SHEET
		atlas.region = region
		atlas.filter_clip = true
		var padding: Vector2 = Vector2(141,141) - region.size
		atlas.margin = Rect2(Vector2(padding.x / 2, padding.y), padding)
		frames.add_frame("bounce", atlas)
	speed = base_move_speed
	respawn_time = 2.25
	hp_regen_delay = 4.0
	hp_regen_per_second = 4.0
	energy_regen_per_second = 14.0
	energy_regen_delay = 0.8

func _physics_process(delta: float) -> void:
	if not simulation_authority: return
	attack_cooldown = maxf(0, attack_cooldown - delta)
	attack_recovery = maxf(0, attack_recovery - delta)
	chill_time = maxf(0, chill_time - delta)
	combo_time = maxf(0, combo_time - delta)
	if combo_time <= 0: combo_stage = 0
	if is_attacking and attack_recovery <= 0:
		is_attacking = false
		play_anim("idle")
	bounce_time = maxf(0, bounce_time - delta)
	slow_time = maxf(0, slow_time - delta)
	element_time = maxf(0, element_time - delta)
	invincible_time = maxf(0, invincible_time - delta)
	flash_time = maxf(0, flash_time - delta)
	if element_time <= 0:
		applied_element = -1
	speed = base_move_speed * (0.55 if slow_time > 0 else (0.82 if chill_time > 0 else 1.0))
	if element == 0 and dash_time > 0: speed = 0
	super._physics_process(delta)
	if not is_dead:
		position += push_velocity * delta
		if dash_time > 0 and bounce_time <= 0 and not is_hurt:
			var step := minf(delta, dash_time)
			var previous := position
			position += dash_velocity * step
			if element == 0: dash_advanced.emit(self, previous, position)
			dash_time = maxf(0, dash_time - delta)
	push_velocity = push_velocity.move_toward(Vector2.ZERO, 750.0 * delta)
	body_sprite.modulate = Color(1.8, 1.0, 1.0) if flash_time > 0 else Color.WHITE
	if invincible_time > 0:
		body_sprite.modulate.a = 0.55 + 0.35 * absf(sin(invincible_time * 14))

func start_attack() -> void:
	if bounce_time > 0 or attack_cooldown > 0 or is_dead or is_attacking or energy < attack_energy_cost: return
	if aim_direction.length_squared() > 0.01:
		facing_direction = aim_direction.normalized()
		body_sprite.flip_h = facing_direction.x < 0
	super.start_attack()
	if not is_attacking: return
	var profile: Dictionary = ELEMENT_PROFILE.get_profile(element)
	attack_cooldown = profile.cooldown
	attack_recovery = minf(0.12, attack_cooldown * 0.7)
	last_combo_stage = combo_stage
	if element == 4:
		combo_stage = (combo_stage + 1) % 3
		combo_time = 1.15
		dash_time = 0.1
		var dash_dir := move_intent.normalized() if move_intent.length_squared() > 0.01 else aim_direction.normalized()
		dash_velocity = dash_dir * 480.0
	elif element == 0:
		dash_time = 0.12
		dash_velocity = facing_direction.normalized() * 800.0
	attack_has_hit = true
	attack_impact.emit(self)

func take_damage(amount: int) -> void:
	if is_dead or invincible_time > 0:
		return
	flash_time = 0.14
	if bounce_time > 0:
		hp = maxf(0, hp - maxi(0, amount))
		hp_regen_wait = hp_regen_delay
		update_hud()
		if hp <= 0: die()
		return
	super.take_damage(amount)
	if not is_dead: is_hurt = false

func respawn() -> void:
	chill_time = 0
	attack_cooldown = 0
	attack_recovery = 0
	combo_stage = 0
	combo_time = 0
	dash_time = 0
	dash_velocity = Vector2.ZERO
	bounce_time = 0
	super.respawn()
	push_velocity = Vector2.ZERO
	slow_time = 0
	applied_element = -1
	element_time = 0
	invincible_time = 0.75
	returned_to_play.emit(self)

func play_anim(anim_name: StringName) -> void:
	super.play_anim(anim_name)

	if anim_name == &"death":
		body_sprite.position.y = 36.0 - 107.0 * body_sprite.scale.y
	else:
		body_sprite.position.y = 0

func trigger_bounce(impulse: Vector2) -> void:
	if is_dead: return
	dash_time = 0
	push_velocity = impulse
	bounce_time = 0.22
	is_attacking = false
	is_hurt = true
	velocity = Vector2.ZERO
	play_anim("bounce")

func _on_animation_finished() -> void:
	if not simulation_authority or is_dead: return
	if body_sprite.animation == &"bounce":
		bounce_time = 0
		is_hurt = false
		play_anim("idle")
	else:
		super._on_animation_finished()
