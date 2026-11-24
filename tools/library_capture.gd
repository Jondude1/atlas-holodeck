extends SceneTree
## Round 2.5 capture harness (NOT shipped): the panel's LIBRARY view against tools/mock_hub.py, plus the
## delete confirmation card. Run: HOLODECK_HUB=http://127.0.0.1:8793 xvfb-run -a godot --path app
## --resolution 1280x720 --script ../tools/library_capture.gd  (mock on 8793 with the usual assets)
var main: Node
var cam: Camera3D
var out_dir: String

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()

func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("CAPTURE ", n, " ", img.get_size(), " err=", img.save_png(out_dir.path_join(n)))

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	await process_frame
	await process_frame
	cam = main.get_node("FallbackCamera")
	var panel: Node = main.get_node("UIPanel")
	var bracket: Node3D = main.get_node("HoloTable/TestBracket")
	while bracket.debug_scan() >= 0.0 and bracket.debug_scan() < 1.15:
		await process_frame
	var t_end := Time.get_ticks_msec() / 1000.0 + 120.0
	while Hub.base_url == "" and Time.get_ticks_msec() / 1000.0 < t_end:
		await process_frame
	panel.set_list_mode("library")
	t_end = Time.get_ticks_msec() / 1000.0 + 90.0
	while panel.library_row_count() != 3 and Time.get_ticks_msec() / 1000.0 < t_end:
		await process_frame
	await _secs(0.8)
	var pp: Vector3 = (panel as Node3D).global_position
	var n: Vector3 = (panel as Node3D).global_basis.z
	cam.fov = 52.0
	cam.global_position = pp + n * 1.25 + Vector3(0, 0.02, 0)
	cam.look_at(pp)
	await _secs(0.6)
	await _snap("r25-library-panel.png")
	var entries: Array = panel.get("_lib_entries")
	if entries.size() > 1:
		panel.request_library_delete(entries[1])
		await _secs(0.6)
		await _snap("r25-library-delete.png")
		panel.cancel_library_delete()
	print("CAPTURE DONE")
	quit(0)
