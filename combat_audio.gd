extends Node

const KEYS := ["fire_dash", "fire_burst", "water_attack", "water_burst", "ice_attack", "ice_burst", "electric_attack", "electric_burst", "wind_attack", "wind_burst", "thunder_burst", "steam_burst", "explosion", "combo", "swipe", "hit"]
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_started: Dictionary = {}
var last_priorities: Dictionary = {}
var enabled: bool = true

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	for key in KEYS:
		streams[key] = load("res://assets/audio/%s.wav" % key)
	if not enabled: return
	for index in range(16):
		var voice := AudioStreamPlayer.new()
		voice.set_meta("priority", 0)
		add_child(voice)
		voices.append(voice)

func play(key: String, volume_db: float = -6.0, pitch: float = 1.0, priority: int = 0) -> void:
	if not enabled or not streams.has(key) or get_tree().paused: return
	var now := Time.get_ticks_msec()
	if now - int(last_started.get(key, -1000)) < (90 if key == "hit" else 55) and priority <= int(last_priorities.get(key,0)): return
	var selected: AudioStreamPlayer
	for voice in voices:
		if not voice.playing:
			selected = voice
			break
	if selected == null:
		for voice in voices:
			if int(voice.get_meta("priority", 0)) <= priority:
				selected = voice
				break
	if selected == null: return
	last_started[key] = now
	last_priorities[key] = priority
	selected.stop()
	selected.stream = streams[key]
	selected.volume_db = volume_db
	selected.pitch_scale = pitch
	selected.set_meta("priority", priority)
	selected.play()

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	last_started.clear()
	last_priorities.clear()
