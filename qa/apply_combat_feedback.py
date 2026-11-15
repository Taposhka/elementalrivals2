from pathlib import Path

p = Path(__file__).resolve().parent.parent

def edit(name, old, new):
    f = p/name
    s = f.read_text(encoding="utf-8")
    assert old in s, (name,old[:70])
    f.write_text(s.replace(old,new),encoding="utf-8")

edit("demo_arena.gd", "func apply_element_hit(target, element: int, damage: int, attacking_team: int, direction: Vector2) -> void:", "func receive_damage(target, amount: int, _team: int, _owner: int = -1) -> void:\n\ttarget.take_damage(amount)\n\nfunc apply_element_hit(target, element: int, damage: int, attacking_team: int, direction: Vector2) -> void:")
edit("demo_arena.gd", "other.take_damage(10)", "receive_damage(other,10,attacking_team)")
f=p/"demo_arena.gd"
s=f.read_text(encoding="utf-8")
first=s.index("func apply_element_hit(")
last=s.index("func resolve_contacts(",first)
s=s[:first]+s[first:last].replace("target.take_damage(damage)","receive_damage(target,damage,attacking_team)")+s[last:]
first=s.index("func explode_fusion(")
last=s.index("func update_fusion_ui(",first)
s=s[:first]+s[first:last].replace("target.take_damage(damage)",'receive_damage(target,damage,int(shot.team),int(shot.get("owner",-1)))')+s[last:]
f.write_text(s,encoding="utf-8")
edit("flag_arena.gd", "target.take_damage(8)", "receive_damage(target,8,-1)")
edit("flag_arena.gd", "target.take_damage(damage + 6)", "receive_damage(target,damage+6,attacking_team)")
edit("flag_arena.gd", "other.take_damage(6)", "receive_damage(other,6,attacking_team)")
edit("flag_arena.gd", "target.take_damage(int(zone.damage))", 'receive_damage(target,int(zone.damage),int(zone.team),int(zone.get("owner",-1)))')
edit("flag_arena.gd", "apply_element_hit(hit_player, int(shot.element), int(shot.damage), int(shot.team), shot.vel.normalized())", "projectile_element_hit(hit_player,shot)")
edit("flag_arena.gd", "func on_projectile_impact(_shot: Dictionary, _impact: Vector2, _hit_kind: String) -> void:", "func projectile_element_hit(target, shot: Dictionary) -> void:\n\tapply_element_hit(target,int(shot.element),int(shot.damage),int(shot.team),shot.vel.normalized())\n\nfunc on_projectile_impact(_shot: Dictionary, _impact: Vector2, _hit_kind: String) -> void:")
edit("element_roles.gd", "target.take_damage(4)", 'receive_damage(target,4,int(flood.team),int(flood.get("owner",-1)))')
edit("demo_fighter.gd", "signal dash_advanced(player, previous: Vector2, current: Vector2)", "signal dash_advanced(player, previous: Vector2, current: Vector2)\nsignal returned_to_play(player)")
edit("demo_fighter.gd", "energy_regen_per_second = 24.0", "energy_regen_per_second = 28.0")
edit("demo_fighter.gd", "energy_regen_delay = 0.45", "energy_regen_delay = 0.35")
edit("demo_fighter.gd", 'frames.set_animation_speed("bounce", 14)', 'frames.set_animation_speed("bounce", 32)')
edit("demo_fighter.gd", "respawn_time = 3.5", "respawn_time = 2.25")
edit("demo_fighter.gd", "invincible_time = 1.2", "invincible_time = 0.75\n\treturned_to_play.emit(self)")
edit("demo_fighter.gd", "bounce_time = 0.5", "bounce_time = 0.22")
edit("element_profiles.gd", '"speed": 205.0', '"speed": 220.0')
edit("element_profiles.gd", '"speed": 145.0', '"speed": 155.0')
edit("element_profiles.gd", '"speed": 155.0, "cooldown": 0.48', '"speed": 170.0, "cooldown": 0.48')
edit("element_profiles.gd", '"speed": 150.0', '"speed": 165.0')
edit("element_profiles.gd", '"speed": 180.0', '"speed": 195.0')
edit("verify_roles.gd", "attacker.base_move_speed == 180", "attacker.base_move_speed == 195")
edit("flag_view.gd", "var frame_cache: Dictionary = {}", "var frame_cache: Dictionary = {}\nvar shake_strength: float = 0.0\n\nfunc impact(strength: float) -> void:\n\tif arena.get(\"options\") != null and arena.options.reduced_flashes: return\n\tshake_strength = minf(6,maxf(shake_strength,strength))")
edit("flag_view.gd", "\tcamera.zoom = Vector2.ONE", "\tshake_strength = move_toward(shake_strength,0,delta*24)\n\tcamera.offset = Vector2(sin(Time.get_ticks_msec()*0.071),cos(Time.get_ticks_msec()*0.089))*shake_strength\n\tcamera.zoom = Vector2.ONE")
edit("flag_demo.tscn", "res://matchmaking_arena.gd", "res://combat_arena.gd")
edit("server/room_arena.gd", 'extends "res://minimal_arena.gd"', 'extends "res://combat_arena.gd"')
edit("network_arena.gd", "const NET_VERSION: int = 10", "const NET_VERSION: int = 11")
edit("server/matchmaker.gd", "const VERSION: int = 10", "const VERSION: int = 11")
print("Combat attribution, tempo, UI and network feedback integrated.")
