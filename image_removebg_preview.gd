extends CharacterBody2D

signal attack_impact(player)
signal defeated(player)

const CUSTOM_ATTACK: Texture2D = preload("res://assets/attackline.png")


var external_control: bool = false
var simulation_authority: bool = true
var auto_respawn: bool = true
var debug_damage_enabled: bool = true
var hud_world_space: bool = true
var player_name: String = ""
var move_intent: Vector2 = Vector2.ZERO
var attack_intent: bool = false
var facing_direction: Vector2 = Vector2.RIGHT
var attack_has_hit: bool = false
var animation_revision: int = 0
var replica_revision: int = -1
var replica_position: Vector2 = Vector2.ZERO
var replica_initialized: bool = false

@export_group("Player")
@export_enum("Player 1", "Player 2") var player_slot: int = 0
@export_range(50.0, 500.0) var speed: float = 250.0
@export var respawn_point: Node2D
@export_range(0.1, 30.0) var respawn_time: float = 3.0

@export_group("Appearance")

@export_range(16.0, 256.0) var character_height: float = 72.0



@export var animation_size_multipliers: Dictionary = {
	"idle": 1.0,
	"walk": 1.0,
	"attack": 1.0,
	"hurt": 1.0,
	"death": 1.0
}


@export var body_includes_head: bool = false

@export_group("Health")
@export_range(1, 10000) var max_hp: int = 100
@export_range(0.0, 100.0) var hp_regen_per_second: float = 5.0
@export_range(0.0, 30.0) var hp_regen_delay: float = 4.0

@export_group("Energy")
@export_range(10.0, 1000.0) var max_energy: float = 100.0
@export_range(1.0, 100.0) var attack_energy_cost: float = 10.0
@export_range(0.0, 100.0) var energy_regen_per_second: float = 20.0
@export_range(0.0, 30.0) var energy_regen_delay: float = 1.0

@export_group("HUD")
@export_range(120.0, 240.0) var hud_width: float = 164.0
@export var hud_offset: Vector2 = Vector2.ZERO

var hp: float = 100.0
var energy: float = 100.0
var start_position: Vector2

var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false

var hp_regen_wait: float = 0.0
var energy_regen_wait: float = 0.0
var damage_key_was_pressed: bool = false

var left_key: Key = KEY_A
var right_key: Key = KEY_D
var up_key: Key = KEY_W
var down_key: Key = KEY_S
var attack_key: Key = KEY_SPACE
var damage_key: Key = KEY_H

var animation_scales: Dictionary = {}

var hud: PanelContainer
var health_bar: ProgressBar
var energy_bar: ProgressBar
var health_value: Label
var energy_value: Label
var health_fill: StyleBoxFlat

@onready var body_sprite: AnimatedSprite2D = $Body
@onready var head_sprite: AnimatedSprite2D = get_node_or_null("Head")


func _ready() -> void:
	hp = float(max_hp)
	energy = max_energy
	start_position = global_position

	configure_controls()
	configure_animations()
	configure_visual_size()
	create_hud()

	damage_key_was_pressed = Input.is_physical_key_pressed(damage_key)

	if not body_sprite.animation_finished.is_connected(_on_animation_finished):
		body_sprite.animation_finished.connect(_on_animation_finished)

	if head_sprite != null:
		head_sprite.visible = not body_includes_head

	body_sprite.frame_changed.connect(_on_attack_frame)
	play_anim("idle")
	update_hud()


func configure_controls() -> void:
	if player_slot == 1:
		left_key = KEY_LEFT
		right_key = KEY_RIGHT
		up_key = KEY_UP
		down_key = KEY_DOWN
		attack_key = KEY_ENTER
		damage_key = KEY_J


func configure_animations() -> void:
	for sprite in [body_sprite, head_sprite]:
		if sprite == null:
			continue


		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		if sprite.sprite_frames == null:
			continue

		sprite.sprite_frames = sprite.sprite_frames.duplicate()

		if sprite == body_sprite:
			install_attack_frames(sprite.sprite_frames)

		for anim_name in ["idle", "walk"]:
			if sprite.sprite_frames.has_animation(anim_name):
				sprite.sprite_frames.set_animation_loop(anim_name, true)

		for anim_name in ["attack", "hurt", "death"]:
			if sprite.sprite_frames.has_animation(anim_name):
				sprite.sprite_frames.set_animation_loop(anim_name, false)

	for anim_name in ["idle", "walk", "attack", "hurt", "death"]:
		if not has_anim(body_sprite, anim_name):
			push_warning("У Body отсутствует анимация с кадрами: " + anim_name)


func install_attack_frames(frames: SpriteFrames) -> void:


	var regions: Array[Rect2] = [
		Rect2(361, 351, 189, 189),
		Rect2(1253, 346, 188, 188),
		Rect2(2143, 352, 188, 188),
		Rect2(3078, 352, 188, 188),
		Rect2(4013, 346, 188, 188),
	]
	if not frames.has_animation("attack"):
		frames.add_animation("attack")
	frames.clear("attack")
	frames.set_animation_speed("attack", 10.0)
	frames.set_animation_loop("attack", false)
	for region in regions:
		var texture := AtlasTexture.new()
		texture.atlas = CUSTOM_ATTACK
		texture.region = region
		texture.filter_clip = true
		var padding := Vector2(189, 189) - region.size
		texture.margin = Rect2(Vector2(padding.x * 0.5, padding.y), padding)
		frames.add_frame("attack", texture)


func configure_visual_size() -> void:
	if body_sprite.sprite_frames == null:
		return



	for anim_name in body_sprite.sprite_frames.get_animation_names():
		var frame_height := get_animation_height(body_sprite, anim_name)

		if frame_height <= 0.0:
			continue

		var multiplier := maxf(
			0.01,
			float(animation_size_multipliers.get(anim_name, 1.0))
		)
		animation_scales[anim_name] = (
			character_height / frame_height * multiplier
		)

	var idle_height := get_animation_height(body_sprite, "idle")
	if idle_height <= 0.0:
		idle_height = get_animation_height(
			body_sprite,
			body_sprite.animation
		)

	var layout_scale := character_height / maxf(idle_height, 1.0)


	body_sprite.position *= layout_scale

	if head_sprite != null:
		head_sprite.position *= layout_scale
		head_sprite.scale *= layout_scale


func get_animation_height(
	sprite: AnimatedSprite2D,
	anim_name: StringName
) -> float:
	if not has_anim(sprite, anim_name):
		return 0.0

	var largest_height: float = 0.0

	for frame_index in range(sprite.sprite_frames.get_frame_count(anim_name)):
		var frame_texture := sprite.sprite_frames.get_frame_texture(
			anim_name,
			frame_index
		)

		if frame_texture == null:
			continue


		var frame_image := frame_texture.get_image()
		if frame_image == null:
			continue
		if frame_image.is_compressed():
			frame_image.decompress()

		largest_height = maxf(
			largest_height,
			float(frame_image.get_used_rect().size.y)
		)

	return largest_height


func _physics_process(delta: float) -> void:
	if not simulation_authority:
		return

	var damage_pressed := Input.is_physical_key_pressed(damage_key)
	var damage_just_pressed := damage_pressed and not damage_key_was_pressed
	damage_key_was_pressed = damage_pressed
	if is_dead:
		return
	if debug_damage_enabled and damage_just_pressed:
		take_damage(25)
		if is_dead:
			return

	regenerate_stats(delta)
	var direction := move_intent
	var wants_attack := attack_intent
	if not external_control:
		direction = Vector2(
			float(Input.is_physical_key_pressed(right_key)) - float(Input.is_physical_key_pressed(left_key)),
			float(Input.is_physical_key_pressed(down_key)) - float(Input.is_physical_key_pressed(up_key))
		)
		wants_attack = Input.is_physical_key_pressed(attack_key)
	direction = direction.limit_length()
	if not is_attacking and direction.length_squared() > 0.01:
		facing_direction = direction.normalized()
		if direction.x != 0.0:
			body_sprite.flip_h = direction.x < 0.0
			if head_sprite != null:
				head_sprite.flip_h = body_sprite.flip_h
	if wants_attack and not is_attacking:
		start_attack()
	update_hud()
	if (is_attacking and not can_move_while_attacking()) or is_hurt:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = direction * speed
	move_and_slide()
	var next_animation := "idle"
	if direction != Vector2.ZERO:
		next_animation = "walk"
	if not is_attacking and (body_sprite.animation != next_animation or not body_sprite.is_playing()):
		play_anim(next_animation)


func _process(delta: float) -> void:
	if not simulation_authority and replica_initialized:
		position = position.lerp(replica_position, 1.0 - exp(-22.0 * delta))


func _on_attack_frame() -> void:
	if not simulation_authority or not is_attacking or attack_has_hit:
		return
	if body_sprite.animation != &"attack":
		return
	var impact_frame := mini(2, body_sprite.sprite_frames.get_frame_count("attack") - 1)
	if body_sprite.frame >= impact_frame:
		attack_has_hit = true
		attack_impact.emit(self)


func network_state() -> Dictionary:
	return {
		"position": position, "hp": hp, "energy": energy,
		"dead": is_dead, "attacking": is_attacking, "hurt": is_hurt,
		"animation": body_sprite.animation, "revision": animation_revision,
		"frame": body_sprite.frame, "progress": body_sprite.frame_progress,
		"flip": body_sprite.flip_h
	}


func apply_network_state(state: Dictionary) -> void:
	if simulation_authority:
		return
	replica_position = state.position
	if not replica_initialized or position.distance_to(replica_position) > 150.0:
		position = replica_position
		replica_initialized = true
	hp = state.hp
	energy = state.energy
	is_dead = state.dead
	is_attacking = state.attacking
	is_hurt = state.hurt
	body_sprite.flip_h = state.flip
	if head_sprite != null:
		head_sprite.flip_h = state.flip
		head_sprite.visible = not is_dead and not body_includes_head
	if replica_revision != int(state.revision):
		replica_revision = int(state.revision)
		play_anim(StringName(state.animation))
		body_sprite.set_frame_and_progress(int(state.frame), float(state.progress))
	update_hud()


func regenerate_stats(delta: float) -> void:
	var hp_regen_delta := maxf(0.0, delta - hp_regen_wait)
	var energy_regen_delta := maxf(0.0, delta - energy_regen_wait)

	hp_regen_wait = maxf(0.0, hp_regen_wait - delta)
	energy_regen_wait = maxf(0.0, energy_regen_wait - delta)

	hp = minf(
		float(max_hp),
		hp + hp_regen_per_second * hp_regen_delta
	)
	energy = minf(
		max_energy,
		energy + energy_regen_per_second * energy_regen_delta
	)


func can_move_while_attacking() -> bool:
	return false

func start_attack() -> void:
	if is_dead or is_attacking:
		return

	if energy < attack_energy_cost:
		return

	if not has_anim(body_sprite, "attack"):
		return

	energy = maxf(0.0, energy - attack_energy_cost)
	energy_regen_wait = energy_regen_delay

	is_hurt = false
	is_attacking = true
	attack_has_hit = false
	velocity = Vector2.ZERO

	play_anim("attack")
	update_hud()


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	hp = maxf(0.0, hp - float(amount))
	hp_regen_wait = hp_regen_delay
	update_hud()

	if hp <= 0.0:
		die()
		return


	if is_attacking:
		return

	velocity = Vector2.ZERO
	is_hurt = has_anim(body_sprite, "hurt")

	if is_hurt:
		play_anim("hurt")
	else:
		play_anim("idle")


func die() -> void:
	if is_dead:
		return

	hp = 0.0
	is_dead = true
	is_attacking = false
	is_hurt = false
	velocity = Vector2.ZERO

	play_anim("death")

	if head_sprite != null:
		head_sprite.hide()

	update_hud()
	defeated.emit(self)
	if not auto_respawn:
		return

	await get_tree().create_timer(respawn_time).timeout

	if is_dead:
		respawn()


func respawn() -> void:
	if is_instance_valid(respawn_point):
		global_position = respawn_point.global_position
	else:
		global_position = start_position

	hp = float(max_hp)
	energy = max_energy
	hp_regen_wait = 0.0
	energy_regen_wait = 0.0

	is_dead = false
	is_attacking = false
	is_hurt = false
	velocity = Vector2.ZERO

	if head_sprite != null:
		head_sprite.visible = not body_includes_head

	play_anim("idle")
	update_hud()


func has_anim(
	sprite: AnimatedSprite2D,
	anim_name: StringName
) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false

	return (
		sprite.sprite_frames.has_animation(anim_name)
		and sprite.sprite_frames.get_frame_count(anim_name) > 0
	)


func play_anim(anim_name: StringName) -> void:
	animation_revision += 1
	if has_anim(body_sprite, anim_name):
		var visual_scale := float(animation_scales.get(anim_name, 1.0))
		body_sprite.scale = Vector2.ONE * visual_scale
		body_sprite.play(anim_name)
		body_sprite.set_frame_and_progress(0, 0.0)

	if body_includes_head:
		return

	var head_animation := anim_name

	if not has_anim(head_sprite, head_animation):
		head_animation = &"idle"
	if not has_anim(head_sprite, head_animation):
		head_animation = &"default"

	if has_anim(head_sprite, head_animation):
		head_sprite.play(head_animation)
		head_sprite.set_frame_and_progress(0, 0.0)


func _on_animation_finished() -> void:
	if is_dead or not simulation_authority:
		return

	match body_sprite.animation:
		"attack":
			is_attacking = false
			play_anim("idle")
		"hurt":
			is_hurt = false
			play_anim("idle")


func create_hud() -> void:
	var player_color := Color("#8bbfff")
	if player_slot == 1:
		player_color = Color("#ffc78c")

	hud = PanelContainer.new()
	hud.name = "PlayerHUD"
	hud.custom_minimum_size.x = hud_width
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hud.z_index = 20

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#131d2b")
	panel_style.border_color = Color("#344458")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 10.0
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	panel_style.shadow_size = 3
	panel_style.shadow_offset = Vector2(0.0, 2.0)
	hud.add_theme_stylebox_override("panel", panel_style)
	add_child(hud)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	hud.add_child(content)

	var title := create_hud_label(
		content, player_name if not player_name.is_empty() else "PLAYER %d" % [player_slot + 1], player_color
	)
	title.add_theme_font_size_override("font_size", 10)

	var health_section := create_hud_meter(
		content, "HP", Color("#48d99a"), 7.0
	)
	health_bar = health_section.get_node("Bar") as ProgressBar
	health_value = health_section.get_node("Values/Amount") as Label
	health_fill = health_bar.get_theme_stylebox("fill") as StyleBoxFlat

	var energy_section := create_hud_meter(
		content, "EN", Color("#68baff"), 4.0
	)
	energy_bar = energy_section.get_node("Bar") as ProgressBar
	energy_value = energy_section.get_node("Values/Amount") as Label

	hud.resized.connect(position_hud)
	position_hud()


func position_hud() -> void:
	if not hud_world_space:
		return
	hud.position = Vector2(
		-hud.size.x * 0.5,
		-character_height * 0.5 - hud.size.y - 12.0
	) + hud_offset


func create_hud_label(
	parent: Control,
	label_text: String,
	label_color: Color
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", label_color)
	parent.add_child(label)
	return label


func create_hud_meter(
	parent: VBoxContainer,
	meter_name: String,
	fill_color: Color,
	bar_height: float
) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = meter_name
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_constant_override("separation", 3)
	parent.add_child(section)

	var values := HBoxContainer.new()
	values.name = "Values"
	values.mouse_filter = Control.MOUSE_FILTER_IGNORE
	values.add_theme_constant_override("separation", 8)
	section.add_child(values)

	var caption := create_hud_label(values, meter_name, Color("#9cacc0"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var amount := create_hud_label(values, "", Color("#eef4ff"))
	amount.name = "Amount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bar := ProgressBar.new()
	bar.name = "Bar"


	bar.show_percentage = false
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := StyleBoxFlat.new()
	background.bg_color = Color("#2a374a")
	background.set_corner_radius_all(2)
	background.set_content_margin_all(0.0)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	fill.set_content_margin_all(0.0)

	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.custom_minimum_size = Vector2(0.0, bar_height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	section.add_child(bar)
	bar.size.y = bar_height
	return section


func update_hud() -> void:
	if hud == null:
		return

	health_bar.max_value = float(max_hp)
	health_bar.value = hp

	energy_bar.max_value = max_energy
	energy_bar.value = energy

	health_value.text = "%d / %d" % [ceili(hp), max_hp]
	energy_value.text = "%d / %d" % [
		floori(energy),
		floori(max_energy)
	]

	var hp_ratio := hp / float(max_hp)

	health_fill.bg_color = Color("#48d99a")
	if hp_ratio <= 0.25:
		health_fill.bg_color = Color("#ff6275")
	elif hp_ratio <= 0.5:
		health_fill.bg_color = Color("#ffc66b")

	energy_value.modulate = Color.WHITE
	if energy < attack_energy_cost:
		energy_value.modulate = Color("#ffbc66")
