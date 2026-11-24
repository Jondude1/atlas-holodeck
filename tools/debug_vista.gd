extends SceneTree
## Debug (NOT shipped): bisect the coast vista layers to find the horizon slab.
func _initialize() -> void:
	_run()

func _shot(cam: Camera3D, path: String) -> void:
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
	cam.global_position = Vector3(0, 1.62, 2.5)
	cam.look_at(Vector3(0, 1.0, -2.4), Vector3.UP)
	await process_frame
	var deck: Node = main.get_node("VistaDeck")
	var coast: Node = deck.get_child(0)
	print("coast children: ", coast.get_children().map(func(c): return c.name))
	await _shot(cam, "res://../captures/dbg-all.png")
	for c in coast.get_children():
		if String(c.name).begins_with("Water"):
			c.visible = false
	await _shot(cam, "res://../captures/dbg-nowater.png")
	for c in coast.get_children():
		c.visible = false
		if String(c.name).begins_with("FarCard"):
			c.visible = true
	await _shot(cam, "res://../captures/dbg-cardonly.png")
	for c in coast.get_children():
		c.visible = true
	deck.visible = false
	await _shot(cam, "res://../captures/dbg-novista.png")
	deck.visible = true
	main.get_node("Hud").visible = false
	await _shot(cam, "res://../captures/dbg-nohud.png")
	quit(0)
