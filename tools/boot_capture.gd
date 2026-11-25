extends SceneTree
## Mid-boot cascade capture (NOT shipped) — P5 iterate round 5. Skips the ring
## (which lands the boot at fade 1), then re-applies a mid-boot fade value
## through the same _set_fade the boot tween drives, and snaps the room.
## Args after --: name, fade (0..1)
func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name := String(args[0]) if args.size() > 0 else "boot"
	var fade := float(args[1]) if args.size() > 1 else 0.45
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	main.call("_set_fade", fade)
	var cam := Camera3D.new()
	cam.fov = 62.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 1.6, 1.35)
	cam.look_at(Vector3(0, 1.0, -2.2), Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../captures/shot-%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	quit(0)
