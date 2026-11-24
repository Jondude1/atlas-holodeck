extends SceneTree
## Round 6 captures (NOT shipped): the rebuilt room from the picture's framing + variants.
## Run windowed: xvfb-run godot --path app --resolution 1280x720 --script ../tools/round6_capture.gd
func _initialize() -> void:
	_run()

func _snap(cam: Camera3D, from: Vector3, to: Vector3, path: String) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var cam := Camera3D.new()
	cam.fov = 62.0
	root.add_child(cam)
	cam.current = true
	await process_frame
	# 1: THE picture — entrance end of the table, looking down it to the opening + coast
	await _snap(cam, Vector3(0, 1.6, 1.35), Vector3(0, 1.0, -2.2), "res://../captures/r6-picture.png")
	# 2: from the terrace, looking back into the room
	await _snap(cam, Vector3(-2.5, 1.65, -7.6), Vector3(0.5, 1.0, -1.0), "res://../captures/r6-terrace.png")
	# 3: the lake at blue hour, same framing as the picture
	main.get_node("VistaDeck").call("show_vista", "lake")
	await create_timer(1.1).timeout
	await _snap(cam, Vector3(0, 1.6, 1.35), Vector3(0, 1.0, -2.2), "res://../captures/r6-lake.png")
	# 4: wide from the entrance corner
	main.get_node("VistaDeck").call("show_vista", "coast")
	await create_timer(1.1).timeout
	await _snap(cam, Vector3(3.3, 1.75, 2.4), Vector3(-2.5, 0.8, -3.5), "res://../captures/r6-wide.png")
	quit(0)
