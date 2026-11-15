from pathlib import Path
import io
import tokenize

p = Path(r"C:\Users\99899\OneDrive\Documents\element")

def replace(name, old, new):
    f = p / name
    s = f.read_text(encoding="utf-8")
    assert old in s, (name, old[:70])
    f.write_text(s.replace(old, new), encoding="utf-8")

replace("rivals_arena.gd", 'extends "res://network_arena.gd"', 'extends "res://element_roles.gd"')
replace("network_arena.gd", "const NET_VERSION: int = 7", "const NET_VERSION: int = 8")
replace("flag_arena.gd", '\t\t\tprojectiles.remove_at(index)', '\t\t\ton_projectile_impact(shot, impact, hit_kind)\n\t\t\tprojectiles.remove_at(index)')
replace("flag_arena.gd", 'func explode_fusion(shot: Dictionary, center: Vector2) -> void:', 'func on_projectile_impact(_shot: Dictionary, _impact: Vector2, _hit_kind: String) -> void:\n\tpass\n\nfunc explode_fusion(shot: Dictionary, center: Vector2) -> void:')
replace("demo_arena.gd", '\tif element == 2:\n\t\ttarget.slow_time = maxf(target.slow_time, 0.65)', '\tif element == 2:\n\t\ttarget.chill_time = maxf(target.chill_time, 0.9)')
replace("image_removebg_preview.gd", '\tif is_attacking or is_hurt:\n', '\tif (is_attacking and not can_move_while_attacking()) or is_hurt:\n')
replace("image_removebg_preview.gd", '\tif body_sprite.animation != next_animation or not body_sprite.is_playing():', '\tif not is_attacking and (body_sprite.animation != next_animation or not body_sprite.is_playing()):')
replace("image_removebg_preview.gd", 'func start_attack() -> void:', 'func can_move_while_attacking() -> bool:\n\treturn false\n\nfunc start_attack() -> void:')
replace("demo_fighter.gd", 'var base_move_speed: float = 160.0', '''var base_move_speed: float = 160.0
var chill_time: float = 0.0
var attack_cooldown: float = 0.0
var attack_recovery: float = 0.0
var combo_stage: int = 0
var last_combo_stage: int = 0
var combo_time: float = 0.0
var dash_time: float = 0.0
var dash_velocity := Vector2.ZERO
const ELEMENT_PROFILE = preload("res://element_profiles.gd")

func apply_element_profile() -> void:
\tvar profile: Dictionary = ELEMENT_PROFILE.get_profile(element)
\tbase_move_speed = profile.speed
\tattack_energy_cost = profile.cost
\tenergy_regen_per_second = 24.0
\tenergy_regen_delay = 0.45
\tmax_hp = 100
\tvar frames := body_sprite.sprite_frames
\tframes.set_animation_speed("attack", float(frames.get_frame_count("attack")) / maxf(0.1, profile.cooldown * 0.85))

func can_move_while_attacking() -> bool:
\treturn true

func _on_attack_frame() -> void:
\tpass

func network_state() -> Dictionary:
\tvar data := super.network_state()
\tdata.merge({"combo_stage": combo_stage, "combo_time": combo_time, "chill": chill_time, "slow": slow_time, "applied": applied_element, "element_time": element_time})
\treturn data

func apply_network_state(data: Dictionary) -> void:
\tsuper.apply_network_state(data)
\tcombo_stage = int(data.get("combo_stage", 0))
\tcombo_time = float(data.get("combo_time", 0.0))
\tchill_time = float(data.get("chill", 0.0))
\tslow_time = float(data.get("slow", 0.0))
\tapplied_element = int(data.get("applied", -1))
\telement_time = float(data.get("element_time", 0.0))''')
replace("demo_fighter.gd", 'func _physics_process(delta: float) -> void:\n', '''func _physics_process(delta: float) -> void:
\tif not simulation_authority: return
\tattack_cooldown = maxf(0, attack_cooldown - delta)
\tattack_recovery = maxf(0, attack_recovery - delta)
\tchill_time = maxf(0, chill_time - delta)
\tcombo_time = maxf(0, combo_time - delta)
\tif combo_time <= 0: combo_stage = 0
\tif is_attacking and attack_recovery <= 0:
\t\tis_attacking = false
\t\tplay_anim("idle")
''')
replace("demo_fighter.gd", 'speed = base_move_speed * (0.55 if slow_time > 0 else 1.0)', 'speed = base_move_speed * (0.55 if slow_time > 0 else (0.82 if chill_time > 0 else 1.0))')
replace("demo_fighter.gd", '\t\tposition += push_velocity * delta', '\t\tposition += push_velocity * delta\n\t\tif dash_time > 0 and bounce_time <= 0 and not is_hurt:\n\t\t\tvar step := minf(delta, dash_time)\n\t\t\tposition += dash_velocity * step\n\t\t\tdash_time = maxf(0, dash_time - delta)')
replace("demo_fighter.gd", '''func start_attack() -> void:
\tif bounce_time > 0: return
\tif not is_dead and not is_attacking and aim_direction.length_squared() > 0.01:
\t\tfacing_direction = aim_direction.normalized()
\t\tbody_sprite.flip_h = facing_direction.x < 0
\tsuper.start_attack()''', '''func start_attack() -> void:
\tif bounce_time > 0 or attack_cooldown > 0 or is_dead or is_attacking or energy < attack_energy_cost: return
\tif aim_direction.length_squared() > 0.01:
\t\tfacing_direction = aim_direction.normalized()
\t\tbody_sprite.flip_h = facing_direction.x < 0
\tsuper.start_attack()
\tif not is_attacking: return
\tvar profile: Dictionary = ELEMENT_PROFILE.get_profile(element)
\tattack_cooldown = profile.cooldown
\tattack_recovery = minf(0.12, attack_cooldown * 0.7)
\tlast_combo_stage = combo_stage
\tif element == 4:
\t\tcombo_stage = (combo_stage + 1) % 3
\t\tcombo_time = 1.15
\t\tdash_time = 0.1
\t\tvar dash_dir := move_intent.normalized() if move_intent.length_squared() > 0.01 else aim_direction.normalized()
\t\tdash_velocity = dash_dir * 480.0
\telif element == 0:
\t\tdash_time = 0.045
\t\tdash_velocity = aim_direction.normalized() * 220.0
\tattack_has_hit = true
\tattack_impact.emit(self)''')
replace("demo_fighter.gd", 'func respawn() -> void:\n\tbounce_time = 0', 'func respawn() -> void:\n\tchill_time = 0\n\tattack_cooldown = 0\n\tattack_recovery = 0\n\tcombo_stage = 0\n\tcombo_time = 0\n\tdash_time = 0\n\tdash_velocity = Vector2.ZERO\n\tbounce_time = 0')
replace("demo_fighter.gd", '\tpush_velocity = impulse\n\tbounce_time', '\tdash_time = 0\n\tpush_velocity = impulse\n\tbounce_time')
replace("network_arena.gd", '\tzones.assign(data.zones)', '\tzones.assign(data.zones)\n\tif get("floods") != null: floods.assign(data.get("floods", []))\n\tif get("combat_visuals") != null: combat_visuals.assign(data.get("combat_visuals", []))')
replace("network_arena.gd", '\t\tfor zone in zones: zone.age += delta', '\t\tfor zone in zones: zone.age += delta\n\t\tif get("floods") != null:\n\t\t\tfor flood in floods:\n\t\t\t\tflood.life = maxf(0, flood.life - delta)\n\t\t\t\tflood.age += delta')
replace("rivals_arena.gd", '\trefresh.call()\n\nfunc create_match_ui()', '''\trefresh.call()
\tvar roles := make_label(box, "", 12, Color("#acd5e7"))
\troles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\troles.custom_minimum_size.x = 520
\tvar refresh_roles := func(_value: int = 0):
\t\tvar profile: Dictionary = PROFILES.get_profile(selected_elements[0])
\t\troles.text = ELEMENT_EN[selected_elements[0]] + " / " + profile.role + "\\n" + profile.description
\tfor picker in box.find_children("*", "OptionButton", true, false):
\t\tpicker.item_selected.connect(refresh_roles)
\trefresh_roles.call()

func create_match_ui()''')

def strip_gd_comments(text):
    result = []
    quote = ""
    escaped = False
    for line in text.splitlines(keepends=True):
        out = ""
        for char in line:
            if escaped:
                out += char
                escaped = False
            elif quote:
                out += char
                if char == "\\": escaped = True
                elif char == quote: quote = ""
            elif char in ('"', "'"):
                quote = char
                out += char
            elif char == "#":
                out = out.rstrip() + ("\n" if line.endswith("\n") else "")
                break
            else:
                out += char
        result.append(out)
    return "".join(result)

for f in p.rglob("*.gd"):
    if ".godot" not in f.parts:
        f.write_text(strip_gd_comments(f.read_text(encoding="utf-8")), encoding="utf-8")
for f in p.rglob("*.py"):
    tokens = list(tokenize.generate_tokens(io.StringIO(f.read_text(encoding="utf-8")).readline))
    f.write_text(tokenize.untokenize([t for t in tokens if t.type != tokenize.COMMENT]), encoding="utf-8")
print("Roles implemented; source comments removed.")
