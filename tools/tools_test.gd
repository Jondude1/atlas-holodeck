extends SceneTree
## R7-3 bench tools proof (NOT shipped): tape measure pins + readout, section
## plane on the shared materials, reference board spawn / picture flip / dismiss.
## Run: godot --headless --path app --script ../tools/tools_test.gd
var _fails := 0

func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok: ", what)
	else:
		_fails += 1
		print("  FAIL: ", what)

func _initialize() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_skip_boot"):
		main.call("_skip_boot")
	await process_frame
	await process_frame
	var bench: Node = main.get_node("CadBench")
	_check(bench != null, "bench present")

	# --- tape measure ---
	bench.set_measure(true)
	_check(bench.measure_armed(), "measure armed")
	var box := AABB()
	var first_box := true
	for p in bench.get("_active").get("_parts"):
		var mi := p as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		box = a if first_box else box.merge(a)
		first_box = false
	var centre: Vector3 = box.get_center()
	var o1 := centre + Vector3(0, 0.35, 0.9)
	var hit1: bool = bench.measure_pick(o1, (centre - o1).normalized())
	_check(hit1, "first pin lands on the model")
	var hit2: bool = bench.measure_pick(centre + Vector3(0.01, 0.8, 0.01), Vector3(0.02, -1, 0.02).normalized())
	_check(hit2, "second pin lands")
	var txt: String = bench.measure_text()
	_check(txt != "", "readout produced: '%s'" % txt)
	_check(txt.contains("IN"), "readout carries its unit")
	_check(bench.measure_pick(o1, (centre - o1).normalized()), "third click restarts the tape")
	_check(bench.measure_text() == "", "readout cleared on restart")
	bench.set_measure(false)
	_check(not bench.measure_armed(), "measure disarmed")

	# --- section view ---
	bench.set_section(0.5)
	var clip_mid: float = Fx.part_material().get_shader_parameter("clip_y")
	_check(clip_mid < 100.0, "section plane set on the shared part material (%.2f)" % clip_mid)
	var clip_mesh: float = Fx.mesh_part_material().get_shader_parameter("clip_y")
	_check(absf(clip_mesh - clip_mid) < 0.001, "section plane set on the shared mesh material too")
	bench.set_section(0.0)
	var clip_off: float = Fx.part_material().get_shader_parameter("clip_y")
	_check(clip_off >= 1000.0, "section off restores the open plane")

	# --- reference board ---
	var on: bool = bench.toggle_board()
	_check(on, "board toggled on")
	var board: Node = main.get_node_or_null("RefBoard")
	_check(board != null, "board exists in the world")
	if board:
		_check(absf(board.global_position.y - 0.951) < 0.01, "board stands on the table top")
		var hand := Node3D.new()
		root.add_child(hand)
		var before: int = board.pic_index()
		board.begin_grab(hand)
		board.end_grab(hand)
		board.begin_grab(hand)
		_check(board.pic_index() != before, "quick re-grab flips the picture")
		board.end_grab(hand)
		hand.queue_free()
	var off: bool = bench.toggle_board()
	_check(not off, "board toggled off")
	await process_frame
	_check(main.get_node_or_null("RefBoard") == null, "board freed")

	print("TOOLS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
