extends RefCounted

const SOURCES := [
	preload("res://assets/ui/element_fire.png"),
	preload("res://assets/ui/element_water.png"),
	preload("res://assets/ui/element_ice.png")
]
static var frames: Dictionary = {}

static func texture_for(element: int) -> Texture2D:
	if element < 0 or element >= SOURCES.size(): return null
	if not frames.has(element):
		var texture: Texture2D = SOURCES[element]
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(texture.get_image().get_used_rect())
		frame.filter_clip = true
		frames[element] = frame
	return frames[element]
