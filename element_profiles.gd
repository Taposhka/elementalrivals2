extends RefCounted

const DATA := [
	{"role": "ASSASSIN", "speed": 220.0, "cooldown": 0.24, "cost": 18.0, "range": 96.0, "damage": 34, "shot_speed": 0.0, "radius": 14.0, "description": "Dash through enemies to deal damage. Each target can be hit once per dash."},
	{"role": "CONTROLLER", "speed": 155.0, "cooldown": 0.65, "cost": 16.0, "range": 300.0, "damage": 9, "shot_speed": 330.0, "radius": 5.0, "description": "Fan out three water shots. Impacts leave spreading flood zones that deny ground."},
	{"role": "FROST SUPPORT", "speed": 170.0, "cooldown": 0.48, "cost": 12.0, "range": 380.0, "damage": 17, "shot_speed": 420.0, "radius": 4.0, "description": "Ice shards briefly slow enemies by 18%. Keep moving and control their approach."},
	{"role": "MARKSMAN", "speed": 165.0, "cooldown": 0.82, "cost": 20.0, "range": 660.0, "damage": 29, "shot_speed": 850.0, "radius": 3.0, "description": "Fast, narrow lightning shots reach across the arena. Aim carefully and keep your distance."},
	{"role": "COMBO SKIRMISHER", "speed": 195.0, "cooldown": 0.34, "cost": 13.0, "range": 330.0, "damage": 15, "shot_speed": 530.0, "radius": 4.0, "description": "Chain long/narrow, medium/wide, then short/wide gusts. Each attack dashes; the finisher knocks back."}
]

static func get_profile(element: int) -> Dictionary:
	return DATA[clampi(element, 0, DATA.size() - 1)]
