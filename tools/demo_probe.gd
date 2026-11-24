extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await create_timer(1.1).timeout
	var m: Node = main.get("_model")
	if m == null:
		print("PROBE: no _model")
	else:
		print("PROBE: demo model node = ", m.name)
		if m.has_method("dims_text"):
			print("PROBE: dims = ", m.dims_text())
		if m.has_method("part_names"):
			print("PROBE: parts = ", m.part_names())
		print("PROBE: load_ok = ", m.get("load_ok"))
		for c in m.get_children():
			if c is MeshInstance3D and c.mesh != null:
				var ga: AABB = c.global_transform * c.get_aabb()
				print("PROBE: part ", c.name, " global AABB pos=", ga.position, " size=", ga.size, " visible=", c.visible)
	var cam := Camera3D.new()
	cam.fov = 62.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 1.6, 1.35)
	cam.look_at(Vector3(0, 1.0, -2.2), Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../captures/shot-pic16.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	quit(0)
