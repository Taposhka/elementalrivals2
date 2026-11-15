extends RefCounted

const SHEET = preload("res://assets/spells/flame_tornado.png")
const REGIONS := [Rect2(555,381,108,90),Rect2(1367,381,108,90),Rect2(2179,381,108,90)]
static var frames: Array[Texture2D] = []

static func frame_index(age: float) -> int:
	return int(maxf(0,age)*10.0)%3

static func draw(canvas: Node2D, point: Vector2, radius: float, age: float, opacity: float) -> void:
	if frames.is_empty():
		for region in REGIONS:
			var frame := AtlasTexture.new()
			frame.atlas = SHEET
			frame.region = region
			frame.filter_clip = true
			frames.append(frame)
	var width := radius*1.2
	var size := Vector2(width,width*90.0/108.0)
	canvas.draw_texture_rect(frames[frame_index(age)],Rect2(point-size*0.5,size),false,Color(1,1,1,opacity))
