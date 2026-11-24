extends SceneTree
## Round 5 captures (NOT shipped): the open wall + each vista from inside the room and
## from the terrace. Run: xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/round5_capture.gd
func _initialize() -> void:
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _snap(cam: Camera3D, pos: Vector3, look: Vector3, name: String) -> void:
	cam.global_position = pos
	cam.look_at(look)
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_abs("captures/" + name))
	print("CAPTURE ", name, " ", img.get_size())

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var cam: Camera3D = main.get_node("FallbackCamera")
	cam.fov = 62.0
	var deck: Node = main.get_node("VistaDeck")
	await create_timer(0.8).timeout
	# 1: from behind the table, looking across it through the opening — coast (default)
	await _snap(cam, Vector3(1.6, 1.6, -1.2), Vector3(-6.0, 0.9, -1.4), "r5-coast-room.png")
	# 2: out on the terrace, looking back at the room + down the coast
	await _snap(cam, Vector3(-6.6, 1.65, 1.6), Vector3(-2.0, 1.1, -1.6), "r5-coast-terrace.png")
	# 3: lake at blue hour, from the table
	deck.show_vista("lake")
	await create_timer(1.0).timeout
	await _snap(cam, Vector3(1.6, 1.6, -1.2), Vector3(-6.0, 0.9, -1.4), "r5-lake-room.png")
	# 4: valley morning, wide from the room's front corner
	deck.show_vista("valley")
	await create_timer(1.0).timeout
	await _snap(cam, Vector3(3.4, 1.7, 2.2), Vector3(-6.5, 0.7, -1.8), "r5-valley-wide.png")
	print("CAPTURE DONE")
	quit(0)
