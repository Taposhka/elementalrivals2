extends Control

const WOW = preload("res://assets/ui/combo_wow.png")
var arena
var badge: TextureRect
var title: Label
var content: Control
var current: Dictionary = {}
var pending: Array[Dictionary] = []
var age: float = 0.0
var active_title: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Vector2(320,220)
	add_child(content)
	badge = TextureRect.new()
	badge.texture = WOW
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(65,0)
	badge.size = Vector2(190,190)
	content.add_child(badge)
	title = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(0,170)
	title.size = Vector2(320,44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_outline_color", Color("#071018"))
	title.add_theme_constant_override("outline_size", 5)
	content.add_child(title)
	hide()

func reset() -> void:
	current.clear()
	pending.clear()
	active_title = ""
	hide()

func present(event: Dictionary) -> void:
	if str(event.get("title", "")).is_empty(): return
	if current.is_empty() or event.title == "SHUTDOWN" or (int(current.get("actor",-1)) == int(event.actor) and int(event.get("chain",0)) >= int(current.get("chain",0))):
		begin(event)
		return
	if pending.size() >= 3: pending.pop_front()
	pending.append(event)

func begin(event: Dictionary) -> void:
	current = event.duplicate()
	age = 0
	active_title = str(event.title)
	title.text = active_title
	title.modulate = arena.BLUE if int(event.team) == 0 else arena.ORANGE
	show()

func _process(delta: float) -> void:
	if current.is_empty(): return
	age += delta
	var bounds := get_viewport_rect().size
	content.position = Vector2(bounds.x / 2 - 160, arena.safe_bounds().position.y + (96 if arena.touch_enabled() else 65))
	content.pivot_offset = Vector2(160,105)
	var reduced: bool = arena.options.reduced_flashes
	var pop := 1.0 if reduced else (lerpf(0.74,1.06, minf(1.0, age/0.13)) if age < 0.13 else lerpf(1.06,1.0,minf(1.0,(age-0.13)/0.13)))
	content.scale = Vector2.ONE * pop
	content.modulate.a = minf(1.0,age/0.06) * clampf((1.35-age)/0.25,0,1)
	if age >= 1.35:
		current.clear()
		active_title = ""
		if pending.is_empty(): hide()
		else: begin(pending.pop_front())
