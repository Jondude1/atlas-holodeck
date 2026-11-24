extends SceneTree
## Draw-call probe (NOT shipped): same counter as tools/capture.gd. Cases: demo bracket (3 parts) alone; + 1-part CAD
## model (shelf bracket job) with the bracket parked; each at rest / exploded / with a part pinned (hover label).
var main: Node
func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()
func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()
## Panel pinned to one state so the count is deterministic: idle = SubViewport not rendering (its normal resting state),
## active = re-rendering every frame (pointer on the panel). Both are reported; the budget is judged on the larger.
func _d1(active: bool) -> int:
	var panel: Node = main.get_node("UIPanel")
	panel.set_process(false)
	main.get_node("UIPanel/SubViewport").render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _d() -> String:
	return "%d idle / %d panel-active" % [await _d1(false), await _d1(true)]
func _case(label: String, m: Node3D) -> void:
	m.call("set_explode", 0.0)
	m.call("clear_highlight")
	var rest: String = await _d()
	m.call("highlight_part", m.call("part_node", 0), true)
	var pinned: String = await _d()
	m.call("clear_highlight")
	m.call("set_explode", 1.0)
	var ex: String = await _d()
	m.call("set_explode", 0.0)
	print("PERF %s: rest=%s | pinned=%s | exploded=%s" % [label, rest, pinned, ex])
func _run() -> void:
	await process_frame
	await process_frame
	var bracket: Node3D = main.get_node("HoloTable/TestBracket")
	var bench: CadBench = main.get_node("CadBench")
	while bracket.debug_scan() < 1.15:
		await process_frame
	await create_timer(1.5).timeout
	await _case("demo bracket (3 parts) alone", bracket)
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad-jobs/0f84d94de2/manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad-jobs/0f84d94de2/model.glb")), man)
	await create_timer(4.0).timeout
	await _case("shelf bracket (1 part) on stage, demo bracket parked", bench.active_model())
	bench.select(bracket)
	await create_timer(1.5).timeout
	await _case("demo bracket on stage, shelf bracket parked (after bench select)", bracket)
	print("PERF lights=%d" % _count(root, "Light3D"))
	quit()
func _count(n: Node, type: String) -> int:
	var c := 1 if n.is_class(type) else 0
	for k in n.get_children():
		c += _count(k, type)
	return c
