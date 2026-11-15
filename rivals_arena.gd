extends "res://element_roles.gd"

const SETTINGS_PATH := "user://rivals_settings.cfg"
const DEFAULT_OPTIONS := {"fullscreen": false, "vsync": true, "volume": 0.65, "quality": 1, "reduced_flashes": false, "camera_smoothing": true, "damage_numbers": true}
const ELEMENT_EN := ["Fire", "Water", "Ice", "Thunder", "Wind"]
const DESCRIPTIONS := {
	"0:0": "A sustained field of fire. Denies ground with repeated burns.",
	"0:1": "Steam vents erupt across a scalding field. Sustained area damage.",
	"0:2": "Molten crystal erupts in a violent burst, slowing survivors.",
	"0:3": "A charged inferno repeatedly strikes and knocks enemies away.",
	"0:4": "A burning tornado drags enemies into its blazing core.",
	"1:1": "A sweeping wave knocks enemies back. Hits each target once.",
	"1:2": "A travelling wall of frozen water hits once and leaves enemies chilled.",
	"1:3": "An electrified rainstorm repeatedly shocks and slows enemies.",
	"1:4": "A churning ocean cyclone pulls enemies toward its centre.",
	"2:2": "A lingering blizzard chills enemies with repeated frost damage.",
	"2:3": "Electrified crystals rain down, damaging and chilling enemies.",
	"2:4": "An arctic vortex drags enemies inward and slows their escape.",
	"3:3": "Repeated lightning strikes punish enemies who remain inside.",
	"3:4": "A roaming thundercloud lashes the ground with wind and lightning.",
	"4:4": "A moving hurricane pulls enemies into its path."
}
var options: Dictionary = DEFAULT_OPTIONS.duplicate()
var overlay_layer: CanvasLayer
var overlay_panel: Control
var overlay_page: String = ""
var tone_cache: Dictionary = {}
var practice: bool = false

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for key in options:
			var value = config.get_value("settings", key, DEFAULT_OPTIONS[key])
			if typeof(value) == typeof(DEFAULT_OPTIONS[key]):
				options[key] = value
	options.volume = clampf(float(options.volume), 0.0, 1.0)
	options.quality = clampi(int(options.quality), 0, 1)
	super._ready()
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 30
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_layer.set_script(preload("res://rivals_overlay.gd"))
	overlay_layer.arena = self
	add_child(overlay_layer)
	apply_options()

func apply_options() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(options.volume))))
	AudioServer.set_bus_mute(0, float(options.volume) <= 0.0)

func save_options() -> void:
	var config := ConfigFile.new()
	for key in options:
		config.set_value("settings", key, options[key])
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))

func set_option(key: String, value: Variant) -> void:
	options[key] = value
	apply_options()
	save_options()

func make_button(parent: Node, text: String, action: Callable) -> Button:
	var button := super.make_button(parent, text, action)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", panel_style(Color(0.12, 0.24, 0.34, 0.2), Color("#ecd78d"), 12, 6))
	return button

func show_main_menu() -> void:
	close_overlay()
	practice = false
	super.show_main_menu()
	var boxes := menu.find_children("*", "VBoxContainer", true, false)
	if boxes.is_empty(): return
	var box: VBoxContainer = boxes[0]
	box.add_theme_constant_override("separation", 10)
	for child in box.get_children():
		if child is TextureButton:
			child.custom_minimum_size.y = 108
			child.focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var guide := make_button(row, "FUSION CODEX", func(): open_overlay("codex"))
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings := make_button(row, "SETTINGS", func(): open_overlay("settings"))
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_label(box, "5 ELEMENTS  /  10 MIXED FUSIONS  /  ONE SHARED ULTIMATE", 11, Color("#e6cb59"))

func add_element_choices(box: VBoxContainer, two: bool) -> void:
	super.add_element_choices(box, two)
	var preview := make_label(box, "", 13, Color("#b6c9dc"))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.custom_minimum_size.x = 520
	var refresh := func(_index: int = 0):
		preview.text = DESCRIPTIONS[pair_key(selected_elements[0], selected_elements[1])] if two else "Choose your element. Your teammate supplies the other half of your fusion."
	for picker in box.find_children("*", "OptionButton", true, false):
		picker.item_selected.connect(refresh)
	refresh.call()
	var roles := make_label(box, "", 12, Color("#acd5e7"))
	roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roles.custom_minimum_size.x = 520
	var refresh_roles := func(_value: int = 0):
		var profile: Dictionary = PROFILES.get_profile(selected_elements[0])
		roles.text = ELEMENT_EN[selected_elements[0]] + " / " + profile.role + "\n" + profile.description
		if two:
			var partner_profile: Dictionary = PROFILES.get_profile(selected_elements[1])
			roles.text += "\n" + ELEMENT_EN[selected_elements[1]] + " / " + partner_profile.role + "\n" + partner_profile.description
	for picker in box.find_children("*", "OptionButton", true, false):
		picker.item_selected.connect(refresh_roles)
	refresh_roles.call()

func create_match_ui() -> void:
	super.create_match_ui()
	for button in match_ui.find_children("*", "Button", true, false):
		if button.position.y > 660:
			button.text = "PAUSE / ESC"
			button.custom_minimum_size.y = 34
			for connection in button.pressed.get_connections():
				button.pressed.disconnect(connection.callable)
			button.pressed.connect(func(): open_overlay("pause"))

func begin_match(mode: String, epoch: int) -> void:
	close_overlay()
	super.begin_match(mode, epoch)

func control_human(player) -> void:
	if is_instance_valid(overlay_panel):
		player.move_intent = Vector2.ZERO
		player.attack_intent = false
		return
	super.control_human(player)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(overlay_panel): return
	super._unhandled_key_input(event)

func close_overlay() -> void:
	if is_instance_valid(overlay_panel):
		overlay_panel.hide()
		overlay_panel.queue_free()
	overlay_panel = null
	overlay_page = ""
	if is_instance_valid(menu): menu.show()
	get_tree().paused = false

func open_overlay(page: String) -> void:
	if not is_instance_valid(overlay_layer): return
	if is_instance_valid(overlay_panel):
		overlay_panel.hide()
		overlay_panel.queue_free()
	overlay_page = page
	if is_instance_valid(menu): menu.hide()

	get_tree().paused = state == "offline" and not online_active
	overlay_panel = Control.new()
	overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(overlay_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_panel.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 630)
	panel.add_theme_stylebox_override("panel", panel_style(Color("#101c2b"), Color("#48606e"), 26, 14))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := make_label(header, {"pause": "MATCH PAUSED" if not online_active else "MATCH MENU", "settings": "SETTINGS", "codex": "FUSION CODEX"}[page], 30, Color("#ecd78d"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make_button(header, "CLOSE  /  ESC", close_overlay).custom_minimum_size = Vector2(158, 38)
	match page:
		"settings": build_settings(box)
		"codex": build_codex(box)
		"pause":
			make_label(box, "Online matches keep running." if online_active else "Take a breath. Your match will resume where you left it.", 16, MUTED)
			make_button(box, "RESUME MATCH", close_overlay)
			make_button(box, "SETTINGS", func(): open_overlay("settings"))
			make_button(box, "FUSION CODEX", func(): open_overlay("codex"))
			make_button(box, "LEAVE MATCH", show_main_menu)

func build_settings(box: VBoxContainer) -> void:
	make_label(box, "Changes apply immediately and are saved on this computer.", 14, MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 18)
	box.add_child(grid)
	add_toggle(grid, "Fullscreen", "fullscreen")
	add_toggle(grid, "Vertical sync", "vsync")
	add_toggle(grid, "Smooth camera", "camera_smoothing")
	add_toggle(grid, "Reduced flashes", "reduced_flashes")
	add_toggle(grid, "Combat text", "damage_numbers")
	make_label(grid, "Effect detail", 16, WHITE)
	var quality := OptionButton.new()
	quality.add_item("Performance")
	quality.add_item("High")
	quality.select(int(options.quality))
	quality.item_selected.connect(func(index: int): set_option("quality", index))
	grid.add_child(quality)
	var volume_title := make_label(grid, "Sound volume  %d%%" % roundi(float(options.volume) * 100), 16, WHITE)
	var volume := HSlider.new()
	volume.custom_minimum_size = Vector2(300, 34)
	volume.min_value = 0
	volume.max_value = 100
	volume.value = float(options.volume) * 100
	volume.value_changed.connect(func(value: float):
		set_option("volume", value / 100.0)
		volume_title.text = "Sound volume  %d%%" % roundi(value)
	)
	grid.add_child(volume)
	make_label(box, "P1  WASD · Mouse / Space · Q fusion\nP2  Arrow keys · Enter · Right Shift fusion\nEsc  Pause / close menu     F11  Toggle fullscreen", 14, MUTED)
	var row := HBoxContainer.new()
	box.add_child(row)
	make_button(row, "TEST SOUND", func(): play_spell_sound("1:3"))
	make_button(row, "RESTORE DEFAULTS", func():
		options = DEFAULT_OPTIONS.duplicate()
		apply_options()
		save_options()
		open_overlay("settings")
	)

func add_toggle(grid: GridContainer, text: String, key: String) -> void:
	make_label(grid, text, 16, WHITE)
	var toggle := CheckButton.new()
	toggle.text = "On" if options[key] else "Off"
	toggle.button_pressed = bool(options[key])
	toggle.toggled.connect(func(on: bool):
		toggle.text = "On" if on else "Off"
		set_option(key, on)
	)
	grid.add_child(toggle)

func build_codex(box: VBoxContainer) -> void:
	make_label(box, "2v2: touch your teammate to charge. Cast with Q / Right Shift. Separate, then reconnect to recharge.", 14, MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(900, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for a in range(5):
		for b in range(a, 5):
			var key := pair_key(a, b)
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(432, 142)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var accent: Color = ELEMENT_COLORS[a].lerp(ELEMENT_COLORS[b], 0.5)
			card.add_theme_stylebox_override("panel", panel_style(Color("#192a3a"), accent.darkened(0.45), 14, 8))
			grid.add_child(card)
			var content := VBoxContainer.new()
			content.add_theme_constant_override("separation", 5)
			card.add_child(content)
			make_label(content, ELEMENT_EN[a] + " + " + ELEMENT_EN[b], 12, accent)
			make_label(content, FUSION_NAMES[key], 18, WHITE)
			var detail := make_label(content, DESCRIPTIONS[key], 13, MUTED)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 398
			var spell: Dictionary = SPELLS[key]
			make_label(content, "%d DMG / hit   ·   %.1f s   ·   %s" % [spell.damage, spell.duration, "SLOW" if spell.slow else ("PULL" if spell.pull > 0 else ("KNOCKBACK" if spell.pull < 0 else "AREA DAMAGE"))], 11, accent)
			var try_spell := make_button(content, "PRACTICE THIS FUSION", func(): start_practice_pair(a, b))
			try_spell.custom_minimum_size.y = 30
			try_spell.disabled = state == "offline" or online_active
	make_button(box, "PRACTICE SELECTED FUSION", start_practice).disabled = state == "offline"
	make_label(box, "Select your two elements in the mode menu. Practice gives your team a continuously recharging fusion.", 12, MUTED)

func start_practice_pair(a: int, b: int) -> void:
	selected_elements.assign([a, b])
	start_practice()

func start_practice() -> void:
	practice = true
	start_offline("squad_bot")
	ai_enabled = false
	countdown = 0
	for player in players:
		if player.bot:
			player.set_physics_process(false)
			if player.team == 1:
				player.position = players[0].position + Vector2(250 + 90 * (player.get_index() % 2), -100 + 160 * (player.get_index() % 2))
				player.start_position = player.position
				player.invincible_time = 0
	mobs.clear()
	fusion[0].pair = [selected_elements[0], selected_elements[1]]
	fusion[0].ready = true
	flag_banner.text = "PRACTICE · Aim with the mouse · Q casts your fusion · Esc opens the menu"

func _physics_process(delta: float) -> void:
	if practice and state == "offline":
		time_left = match_duration
		fusion[0].ready = true
		fusion[0].pair = [selected_elements[0], selected_elements[1]]
	super._physics_process(delta)
	if practice and is_instance_valid(flag_banner):
		flag_banner.text = "PRACTICE · Aim + Q to cast · Choose another pair in the mode menu · Esc opens the menu"

func cast_ultimate(player) -> bool:
	if practice and not zones.is_empty(): return false
	var result := super.cast_ultimate(player)
	if not result and player.human_index >= 0 and not online_active and state == "offline":
		if not squad:
			add_effect(player.position, MUTED, 30, "Fusions require 2v2")
		elif not fusion[player.team].ready:
			add_effect(player.position, MUTED, 30, "Touch your teammate to charge")
	return result

func create_spell(pair: Array, team: int, target: Vector2, direction: Vector2) -> Dictionary:
	var zone := super.create_spell(pair, team, target, direction)
	play_spell_sound(zone.key)
	return zone

func play_spell_sound(key: String) -> void:
	if float(options.volume) <= 0 or DisplayServer.get_name() == "headless": return
	if not tone_cache.has(key):
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var samples := PackedByteArray()
		var seconds := 0.5
		var base := 100.0 + float(int(key[0])) * 43.0 + float(int(key[2])) * 31.0
		samples.resize(int(seconds * 22050) * 2)
		for i in range(samples.size() / 2):
			var t := float(i) / 22050.0
			var envelope := minf(1.0, t * 60.0) * pow(1.0 - t / seconds, 2.0)
			var wave := sin(TAU * (base * t + 90.0 * t * t)) * 0.6 + sin(TAU * base * 1.503 * t) * 0.22
			samples.encode_s16(i * 2, int(wave * envelope * 16000))
		stream.data = samples
		tone_cache[key] = stream
	var sound := AudioStreamPlayer.new()
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	sound.stream = tone_cache[key]
	sound.volume_db = -8
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
