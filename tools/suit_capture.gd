extends SceneTree
## Iterate round 1 verification (NOT shipped): boot, put a virtual visitor in
## front of the LEFT suit only, wait for the wake ramp, print wake amounts,
## snap a close-up. Run windowed under xvfb like tools/shot.gd.
func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var hero: Node = main.get_node("Room/Lab/SuitHero")
	var heroine: Node = main.get_node("Room/Lab/SuitHeroine")
	hero.call("debug_set_visitor", Vector3(-1.6, 1.6, -3.4))
	heroine.call("debug_set_visitor", Vector3(-1.6, 1.6, -3.4))
	await create_timer(1.6).timeout
	print("WAKE hero=", hero.call("wake_amount"), " heroine=", heroine.call("wake_amount"))
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(-1.45, 1.5, -2.75)
	cam.look_at(Vector3(-2.5, 1.25, -4.3), Vector3.UP)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../captures/shot-suits-awake.png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	quit(0)
