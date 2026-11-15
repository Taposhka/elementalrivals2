extends "res://server/matchmaker.gd"

var phase: int = 0
var phase_time: int = 0
var test_started: int = Time.get_ticks_msec()

func _process(delta: float) -> bool:
	super._process(delta)
	if phase == 2 and Time.get_ticks_msec()-phase_time > 1500:
		print("REMOTE FEEDBACK SERVER: passed")
		quit(0)
		return false
	if Time.get_ticks_msec()-test_started > 30000:
		push_error("Remote feedback server timed out")
		quit(1)
	if rooms.is_empty(): return false
	var arena = rooms.values()[0].arena
	if arena.countdown > 0: return false
	if phase == 0:
		arena.players[2].invincible_time = 0
		arena.receive_damage(arena.players[2],100,0,0)
		phase = 1
		phase_time = Time.get_ticks_msec()
	elif phase == 1 and Time.get_ticks_msec()-phase_time > 250:
		arena.players[2].respawn()
		arena.players[2].invincible_time = 0
		arena.receive_damage(arena.players[2],100,0,0)
		phase = 2
		phase_time = Time.get_ticks_msec()
	return false
