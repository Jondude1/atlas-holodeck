extends SceneTree
## Single-shot capture (NOT shipped): boot, one framed snap, quit. Args after --:
##   name (output captures/shot-<name>.png), camx camy camz lookx looky lookz, [vista]
func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name := String(args[0]) if args.size() > 0 else "x"
	var from := Vector3(float(args[1]), float(args[2]), float(args[3])) if args.size() > 6 else Vector3(0, 1.6, 1.35)
	var to := Vector3(float(args[4]), float(args[5]), float(args[6])) if args.size() > 6 else Vector3(0, 1.0, -2.2)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	if args.size() > 7:
		main.get_node("VistaDeck").call("show_vista", String(args[7]))
	if args.size() > 8:
		var deck: Node = main.get_node("VistaDeck")
		for i in 3:
			if String(deck.call("grade")) == String(args[8]):
				break
			deck.call("cycle_grade")
		await create_timer(1.1).timeout
	var cam := Camera3D.new()
	cam.fov = 62.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../captures/shot-%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	quit(0)
