extends SceneTree
## QA harness (NOT shipped): renders the finished room from several standing positions with a headset-wide FOV, so the
## set dressing that sits outside the single fallback-camera framing can be inspected. Output: captures/lab-views/*.png
## Run: xvfb-run godot --path app --resolution 1280x720 --script tools/room_views.gd

var _main: Node

func _initialize() -> void:
	Engine.time_scale = 1.0
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_run()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join("../captures/lab-views").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(name))
	print("VIEW ", name)

func _run() -> void:
	# wait for boot to finish (room + table faded up)
	var frames := 0
	while not (_main.get("_ring") == null or not is_instance_valid(_main.get("_ring"))) and frames < 3000:
		await process_frame
		frames += 1
	for i in 40:
		await process_frame
	var cam: Camera3D = _main.get_node("FallbackCamera")
	cam.fov = 95.0
	var views := {
		"v1-standing-table.png": [Vector3(0, 1.62, 0.7), Vector3(0, 1.2, -1.55)],
		"v2-left-bench.png": [Vector3(-1.0, 1.6, -1.6), Vector3(-3.5, 1.1, -2.6)],
		"v3-right-bench.png": [Vector3(1.0, 1.6, -1.6), Vector3(3.5, 1.1, -2.6)],
		"v4-back-wall.png": [Vector3(0, 1.6, -1.0), Vector3(0, 1.8, -5.0)],
		"v5-ceiling-rig.png": [Vector3(0, 1.6, 0.4), Vector3(0, 3.0, -1.6)],
		"v6-floor-table.png": [Vector3(0, 1.5, 1.2), Vector3(0, 0.3, -1.55)],
		"v7-table-edge-close.png": [Vector3(0.2, 1.25, -0.35), Vector3(0.5, 0.9, -0.95)],
	}
	for k in views:
		cam.global_position = views[k][0]
		cam.look_at(views[k][1])
		for i in 6:
			await process_frame
		await _snap(k)
		print("DRAWS ", k, " ", int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	print("VIEWS DONE")
	quit()
