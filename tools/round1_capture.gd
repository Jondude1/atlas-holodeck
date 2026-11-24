extends SceneTree
## Round 1A capture harness (NOT shipped): real main scene, desktop fallback camera, 27-part trebuchet through the real
## CadBench.spawn path. Writes captures/r1-*.png and prints PERF draw-call numbers.
## Run: xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/round1_capture.gd
var main: Node
var bench: CadBench
var cam: Camera3D
var out_dir: String

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("CAPTURE ", n, " ", img.get_size(), " err=", img.save_png(out_dir.path_join(n)))

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _draws() -> int:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _look(pos: Vector3, at: Vector3, fov := 58.0) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(at)

func _run() -> void:
	await process_frame
	await process_frame
	cam = main.get_node("FallbackCamera")
	bench = main.get_node("CadBench")
	var bracket: Node3D = main.get_node("HoloTable/TestBracket")
	var table: Node3D = main.get_node("HoloTable")
	var panel: Node3D = main.get_node("UIPanel")
	while bracket.debug_scan() >= 0.0 and bracket.debug_scan() < 1.15:
		await process_frame        # boot + demo bracket materialize
	await _secs(1.0)
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb")), man)
	await _secs(4.5)
	var treb: Node3D = bench.active_model()
	# 1. part list on the panel, one part pinned (its name raised on the model)
	panel.get("_part_buttons")[7].button_pressed = true
	panel.call("scroll_parts", 1)
	await _secs(0.6)
	var pp := panel.global_position
	var n := panel.global_basis.z
	_look(pp + n * 1.25 + Vector3(0, 0.02, 0), pp, 52.0)
	await _secs(0.5)
	await _snap("r1-panel-part-list.png")
	# 2. the model with a part pinned + exploded (parts separate along their own centroids)
	panel.get("_part_buttons")[7].button_pressed = false
	treb.call("highlight_part", treb.call("part_node", 12), true)
	treb.call("set_explode", 1.0)
	_look(Vector3(0.0, 1.9, -0.55), table.global_position + Vector3(0, 1.1, 0), 62.0)
	await _secs(0.6)
	await _snap("r1-trebuchet-exploded-pinned.png")
	var ex := await _draws()
	treb.call("clear_highlight")
	treb.call("set_explode", 0.0)
	await _secs(0.3)
	var rest := await _draws()
	print("PERF draw_calls rest=%d exploded+pinned=%d lights=%d" % [rest, ex, _count(root, "Light3D")])
	# 3. bench select: trebuchet on stage, bracket parked aside -> pull the bracket back (mid-pull + settled)
	_look(Vector3(0.0, 1.55, -0.55), table.global_position + Vector3(0, 1.0, 0), 66.0)
	await _secs(0.4)
	await _snap("r1-bench-before-select.png")
	bench.select(bracket)
	await _secs(0.35)
	await _snap("r1-bench-select-midpull.png")
	await _secs(1.2)
	await _snap("r1-bench-after-select.png")
	var sel := await _draws()
	print("PERF draw_calls after_select=%d (bracket on stage, trebuchet parked)" % sel)
	bracket.call("set_explode", 1.0)
	await _secs(0.3)
	print("PERF draw_calls worst_case_bracket_exploded_trebuchet_parked=%d" % await _draws())
	print("CAPTURE DONE")
	quit()

func _count(n: Node, type: String) -> int:
	var c := 1 if n.is_class(type) else 0
	for k in n.get_children():
		c += _count(k, type)
	return c
