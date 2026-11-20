extends SceneTree
func _initialize() -> void:
	_run()
func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()
func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await create_timer(2.5).timeout
	var station: Node = main.get_node("Room/Lab/DataStation")
	var orb: Node3D = station.get_node("Presence")
	var cam: Camera3D = main.get_node("FallbackCamera")
	cam.fov = 55.0
	cam.global_position = orb.global_position + Vector3(-0.85, 0.28, 1.55)
	cam.look_at(orb.global_position + Vector3(0, -0.05, 0))
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(_abs("captures/r3-orb.png"))
	print("CAPTURE r3-orb.png")
	station.celebrate()
	await create_timer(0.8).timeout
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(_abs("captures/r3-orb-celebrate.png"))
	print("CAPTURE r3-orb-celebrate.png")
	quit(0)
