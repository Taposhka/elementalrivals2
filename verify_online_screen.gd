extends SceneTree

var arena

func _initialize() -> void:
	call_deferred("capture_search")

func capture_search() -> void:
	arena = load("res://flag_demo.tscn").instantiate()
	root.add_child(arena)
	arena.show_online_menu()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/online_search.png")
	if not arena.service_connected or arena.menu.find_children("*", "LineEdit", true, false).size() > 0:
		push_error("Online search interface did not connect cleanly")
		quit(1)
		return
	arena.show_main_menu()
	await process_frame
	print("ONLINE SEARCH SCREEN: passed")
	quit(0)
