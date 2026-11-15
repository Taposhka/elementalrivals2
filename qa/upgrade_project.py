from pathlib import Path
p=Path(r"C:\Users\99899\OneDrive\Documents\element")
def edit(name, old, new, count=None):
    f=p/name
    text=f.read_text(encoding="utf-8")
    n=text.count(old)
    assert n > 0, (name, old[:100])
    if count is not None: assert n==count,(name,n,count)
    f.write_text(text.replace(old,new),encoding="utf-8")
names={"0:0":"Inferno","0:1":"Steam Apocalypse","0:2":"Crystal Volcano","0:3":"Thunderflame","0:4":"Flame Tornado","1:1":"Tsunami","1:2":"Frozen Tsunami","1:3":"Electric Storm","1:4":"Ocean Cyclone","2:2":"Blizzard","2:3":"Crystal Storm","2:4":"Arctic Vortex","3:3":"Thunderstrike","3:4":"Sky Tempest","4:4":"Hurricane"}
f=p/"demo_arena.gd"
s=f.read_text(encoding="utf-8")
lines=s.splitlines()
import json
lines=[("const FUSION_NAMES := "+json.dumps(names,ensure_ascii=False)) if x.startswith("const FUSION_NAMES :=") else x for x in lines]
f.write_text("\n".join(lines)+"\n",encoding="utf-8")
edit("flag_demo.tscn",'res://network_arena.gd','res://rivals_arena.gd',1)
edit("network_arena.gd","const NET_VERSION: int = 6","const NET_VERSION: int = 7",1)
edit("project.godot",'window/size/viewport_height=720','window/size/viewport_width=1152\nwindow/size/viewport_height=720\nwindow/size/window_width_override=1152\nwindow/size/window_height_override=720',1)
edit("flag_arena.gd",'"0:3": {"radius": 190.0, "duration": 2.2, "damage": 36, "interval": 10.0, "pull": -240.0, "slow": false}', '"0:3": {"radius": 180.0, "duration": 4.2, "damage": 9, "interval": 0.7, "pull": -95.0, "slow": false}',1)
edit("flag_arena.gd",'"1:2": {"radius": 180.0, "duration": 4.5, "damage": 6, "interval": 0.8, "pull": 0.0, "slow": true}', '"1:2": {"radius": 180.0, "duration": 3.4, "damage": 34, "interval": 0.1, "pull": -190.0, "slow": true}',1)
                                                                             
edit("flag_arena.gd",'pair_key(pair[0], pair[1]) == "1:1"','pair_key(pair[0], pair[1]) in ["1:1", "1:2"]')
edit("flag_arena.gd",'zone.key == "1:1"','zone.key in ["1:1", "1:2"]')
edit("flag_arena.gd",'zone.key != "1:1"','zone.key not in ["1:1", "1:2"]')
edit("flag_arena.gd",'elif zone.key == "4:4":','elif zone.key in ["4:4", "3:4"]:',1)
edit("flag_arena.gd",'target.slow_time = maxf(target.slow_time, 1.1)','target.slow_time = maxf(target.slow_time, 2.4 if zone.key == "1:2" else 1.1)',1)
                                         
edit("flag_view.gd",'camera.position = camera.position.lerp(viewer.position, 1.0 - exp(-10 * delta))','camera.position = camera.position.lerp(viewer.position, 1.0 - exp(-10 * delta)) if arena.get("options") == null or arena.options.camera_smoothing else viewer.position',1)
edit("flag_view.gd",'if not fx.text.is_empty():','if not fx.text.is_empty() and (arena.get("options") == null or arena.options.damage_numbers):',1)
edit("flag_view.gd",'var tint := sprite.modulate','var tint := sprite.modulate\n\t\tif arena.get("options") != null and arena.options.reduced_flashes:\n\t\t\ttint = Color(1, 1, 1, tint.a)',1)
                                                                                   
edit("flag_arena.gd",'partner.position.distance_to(player.position) < 100 and charge.armed and not charge.ready','partner.position.distance_to(player.position) < 360 and charge.armed and not charge.ready',1)
edit("flag_arena.gd",'\t\tif partner != null and partner.bot and charge.ready', '\t\tif partner != null and not partner.is_dead and not charge.ready and not charge.armed and partner.position.distance_to(player.position) < 125:\n\t\t\tplayer.move_intent = (player.position - partner.position).normalized()\n\t\tif partner != null and partner.bot and charge.ready',1)
                                                     
edit("spell_art.gd",'if zone.key == "1:1":','if zone.key in ["1:1", "1:2"]:',1)
edit("spell_art.gd",'\t\tif t < zone.warning:\n', '\t\tvar label: String = arena.FUSION_NAMES[zone.key]\n\t\tvar font := ThemeDB.fallback_font\n\t\tvar label_pos := p + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2, -r - 12)\n\t\tcanvas.draw_string_outline(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#09121f"))\n\t\tcanvas.draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, faction)\n\t\tif t < zone.warning:\n',1)
                                                                  
edit("spell_art.gd",'\t\tvar fade := opacity(zone)','\t\tvar fade := opacity(zone)\n\t\tif arena.get("options") != null and arena.options.reduced_flashes:\n\t\t\tfade *= 0.55')
edit("spell_art.gd",'\t\tvar key: String = zone.key\n\t\tmatch key:', '\t\tvar key: String = zone.key\n\t\tvar detail: bool = arena.get("options") == null or arena.options.quality == 1\n\t\tmatch key:',1)
for n in [36,22,18]:
    edit("spell_art.gd",f"for i in range({n}):",f"for i in range({n} if detail else {n//2}):")
                                                                                   
edit("spell_art.gd",'\t\t\t"0:3":\n\t\t\t\tfor i in range(4):', '\t\t\t"0:3":\n\t\t\t\tfor i in range(12):\n\t\t\t\t\tvar ember := p + Vector2.from_angle(i * 2.399 + t * 0.3) * r * 0.62\n\t\t\t\t\tflame(canvas, ember, 24 + 12 * sin(t * 5 + i), fade)\n\t\t\t\tfor i in range(4):',1)
edit("spell_art.gd",'clampf(t * 2 - i * 0.23, 0.02, 1)','clampf(fmod(t * 0.8 + i * 0.24, 1.0), 0.02, 1)')
                                                                    
old='''\t\t\t"1:2":
\t\t\t\tfor i in range(12):
\t\t\t\t\tvar d := Vector2.from_angle(i * TAU / 12)
\t\t\t\t\tcrystal(canvas, p + d * r * 0.78, Vector2(0, -1), 28 + sin(i * 3.1) * 10, Color(0.5, 0.86, 0.96, 0.85 * fade))
\t\t\t\tfor i in range(4):
\t\t\t\t\tcanvas.draw_arc(p, r * (0.2 + i * 0.19), 0, TAU, 48, Color(0.83, 0.96, 1, 0.35 * fade), 2, true)'''
new='''\t\t\t"1:2":
\t\t\t\tvar side := Vector2(zone.dir).orthogonal()
\t\t\t\tvar crest := PackedVector2Array()
\t\t\t\tfor i in range(33):
\t\t\t\t\tvar offset := (i / 32.0 * 2 - 1) * r
\t\t\t\t\tcrest.append(p + side * offset + Vector2(zone.dir) * (28 + sin(offset * 0.06 + t * 4) * 9))
\t\t\t\tvar body := crest.duplicate()
\t\t\t\tbody.append(p + side * r - Vector2(zone.dir) * 48)
\t\t\t\tbody.append(p - side * r - Vector2(zone.dir) * 48)
\t\t\t\tcanvas.draw_colored_polygon(body, Color(0.3, 0.7, 0.92, 0.4 * fade))
\t\t\t\tcanvas.draw_polyline(crest, Color(0.75, 0.98, 1, 0.9 * fade), 6, true)
\t\t\t\tfor i in range(13):
\t\t\t\t\tvar base := p + side * (i / 12.0 * 2 - 1) * r * 0.94
\t\t\t\t\tcrystal(canvas, base, Vector2(0, -1), 30 + sin(i * 3.1 + t) * 10, Color(0.65, 0.92, 1, 0.9 * fade))'''
edit("spell_art.gd",old,new,1)
print("Upgraded recipes, combat, rendering, networking version and scene entry point.")
