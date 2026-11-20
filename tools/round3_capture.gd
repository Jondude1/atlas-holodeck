extends SceneTree
## Round 3 captures (NOT shipped): exploded-label spread, the glow column on the table, the robot arm
## mid-scan, and the data station. Run: xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/round3_capture.gd
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
	cam.fov = 58.0
	var bench: Node = main.get_node("CadBench")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb")), man)
	await create_timer(1.2).timeout
	var m: Node = bench.active_model()
	m.set_explode(1.0)
	await create_timer(1.0).timeout
	# 1: the label spread at full explode (R3-10)
	await _snap(cam, Vector3(0.0, 1.55, 0.75), Vector3(0, 1.02, -1.55), "r3-exploded-labels.png")
	# 2: wide room — table glow column + lab behind (R3-1/R3-2)
	m.set_explode(0.0)
	await _snap(cam, Vector3(1.9, 1.8, 1.15), Vector3(0, 0.95, -1.6), "r3-room-wide.png")
	# 3: the data station on the back wall (R3-11)
	await _snap(cam, Vector3(0.0, 1.5, -2.2), Vector3(0, 1.35, -4.55), "r3-data-station.png")
	# 4: the arm, whenever it is in its scan state (R3-11)
	var arm: Node = main.get_node("Room/Lab/RobotArm")
	var waited := 0.0
	while String(arm.get("_cur_name")) != "scan" and waited < 40.0:
		await create_timer(0.5).timeout
		waited += 0.5
	await _snap(cam, Vector3(2.15, 1.45, -0.15), Vector3(3.35, 1.05, -1.15), "r3-arm-scan.png")
	print("CAPTURE DONE")
	quit(0)
