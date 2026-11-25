extends SceneTree
## Wall widgets test (NOT shipped) — Round 6-2. Asserts: five panels at their default
## spots/types; a picture panel shows a picture; a grab-drag slides a panel along its
## wall and persists; an edge tap steps the content ring and persists; a rebuild
## restores the saved layout.
## Run: godot --headless --path app --script ../tools/wall_widgets_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _panel(widgets: Node, pid: String) -> Node:
	for p in widgets.get("_panels"):
		if String(p.get("pid")) == pid:
			return p
	return null

func _run() -> void:
	# clean slate FIRST: the layout store persists between runs by design, and the
	# widgets build during the scene's _ready — the delete must precede the instance
	if FileAccess.file_exists("user://wall_layout.json"):
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/wall_layout.json")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var widgets: Node = main.get_node("WallWidgets")
	var panels: Array = widgets.get("_panels")
	_check(panels.size() == 5, "five wall panels built")
	var w1: Node = _panel(widgets, "w1")
	var w2: Node = _panel(widgets, "w2")
	var w3: Node = _panel(widgets, "w3")
	var w5: Node = _panel(widgets, "w5")
	_check(w1.type_name() == "OVERVIEW" and absf(w1.global_position.x + 3.94) < 0.02, "w1 OVERVIEW on the left wall")
	_check(w3.type_name() == "PICTURE", "w3 starts as a PICTURE")
	var disp: MeshInstance3D = w3.get_node("Display")
	_check(disp.material_override != null and disp.material_override.albedo_texture != null and not (disp.material_override.albedo_texture is ViewportTexture), "w3 display wears a picture texture")
	# drag w2 along the left wall (z from -2.6 toward -1.2), then release
	var hand := Node3D.new()
	root.add_child(hand)
	hand.global_position = w2.global_position
	w2.begin_grab(hand)
	for i in 12:
		hand.global_position = w2.global_position.lerp(Vector3(-3.94, 1.02, -1.2), float(i + 1) / 12.0)
		await process_frame
	for i in 30:
		await process_frame
	w2.end_grab(hand)
	await process_frame
	_check(absf(w2.global_position.z + 1.2) < 0.12, "w2 slid along the wall (z=%.2f)" % w2.global_position.z)
	_check(FileAccess.file_exists("user://wall_layout.json"), "layout saved on release")
	# edge tap on w5 (HUB) steps the ring to CLOCK
	var before: int = w5.get("state")
	hand.global_position = w5.global_position + w5.global_transform.basis.x * 0.42
	w5.begin_grab(hand)
	await process_frame
	w5.end_grab(hand)
	_check(int(w5.get("state")) == before + 1 and w5.type_name() == "CLOCK", "edge tap stepped w5 HUB -> CLOCK")
	# persistence: a fresh widgets build restores the saved spots
	var saved_u: float = w2.global_position.z
	var widgets2 := WallWidgets.new()
	root.add_child(widgets2)
	widgets2.build(main.get_node("CadBench"))
	var w2b: Node = _panel(widgets2, "w2")
	var w5b: Node = _panel(widgets2, "w5")
	_check(w2b != null and absf(w2b.global_position.z - saved_u) < 0.06, "rebuild restores w2's spot")
	_check(w5b != null and w5b.type_name() == "CLOCK", "rebuild restores w5's content")
	print("WALL_WIDGETS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
