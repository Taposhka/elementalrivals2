extends RefCounted

const SHEET = preload("res://assets/spells/crystal_volcano.png")
const REGIONS := [
	Rect2(316,453,267,211),
	Rect2(1165,453,267,211),
	Rect2(2097,453,267,211),
	Rect2(3013,453,267,211),
	Rect2(3929,453,267,211),
	Rect2(4775,453,267,211)
]
static var frames: Array[Texture2D] = []

static func frame_index(age: float) -> int:
	return clampi(int(maxf(0,age)*10.0),0,5)

static func draw(canvas: Node2D, point: Vector2, radius: float, age: float, opacity: float) -> void:
	if frames.is_empty():
		for region in REGIONS:
			var frame := AtlasTexture.new()
			frame.atlas = SHEET
			frame.region = region
			frame.filter_clip = true
			frames.append(frame)
	var fade := opacity*clampf((1.25-age)/0.55,0,1)
	if fade <= 0: return
	var width := radius*1.65
	var size := Vector2(width,width*211.0/267.0)
	canvas.draw_texture_rect(frames[frame_index(age)],Rect2(point+Vector2(-size.x/2,12-size.y),size),false,Color(1,1,1,fade))
