from pathlib import Path
p=Path(r"C:\Users\99899\OneDrive\Documents\element")
f=p/"flag_arena.gd"
s=f.read_text(encoding="utf-8")
old='\t\t\t\tif toward.length_squared() < 0.01:\n\t\t\t\t\ttoward = -zone.dir'
new='\t\t\t\tif zone.key in ["1:1", "1:2"] or toward.length_squared() < 0.01:\n\t\t\t\t\ttoward = -zone.dir'
assert old in s
f.write_text(s.replace(old,new),encoding="utf-8")
f=p/"spell_art.gd"
s=f.read_text(encoding="utf-8")
s=s.replace('if key in ["1:2", "2:2", "2:3", "2:4"]:', 'if key in ["2:2", "2:3", "2:4"]:')
f.write_text(s,encoding="utf-8")
f=p/"verify_upgrade.gd"
s=f.read_text(encoding="utf-8")
s=s.replace('print("Fusion panels: ", arena.overlay_panel.find_children("*", "PanelContainer", true, false).size())\n\tcheck(arena.overlay_panel.find_children("*", "PanelContainer", true, false).size() >= 16, "all 15 fusion cards")','check(arena.overlay_panel.find_children("*", "GridContainer", true, false)[0].get_child_count() == 15, "all 15 fusion cards")')
s=s.replace('check(target.slow_time > 2, "frozen wave chill")','check(target.slow_time > 2, "frozen wave chill")\n\tcheck(target.push_velocity.x > 0, "wave pushes in travel direction")\n\tcheck(arena.players[0].hp == 100, "no friendly fire")')
s=s.replace('arena.start_practice()','arena.open_overlay("codex")\n\tawait settle()\n\tvar practice_buttons = arena.overlay_panel.find_children("*", "Button", true, false).filter(func(button): return button.text == "PRACTICE THIS FUSION")\n\tcheck(practice_buttons.size() == 15, "all recipes have practice actions")\n\tpractice_buttons[1].pressed.emit()')
s=s.replace('check(arena.practice and not arena.ai_enabled and arena.fusion[0].ready, "practice ready")','check(arena.practice and not arena.ai_enabled and arena.fusion[0].ready, "practice ready")\n\tcheck(arena.selected_elements == [0, 1], "practice button selects its exact recipe")')
f.write_text(s,encoding="utf-8")
print("Final combat and verification refinements saved.")
