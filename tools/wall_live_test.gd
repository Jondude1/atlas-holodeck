extends SceneTree
## Wall live-data test (NOT shipped) — P4 iterate round 4. Asserts: a text panel's
## chrome phase advances on tick_live() by LIVE_STEP, its viewport is asked to
## repaint (UPDATE_ONCE), and a PICTURE panel's tick is a no-op.
## Run: godot --headless --path app --script ../tools/wall_live_test.gd
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
	if FileAccess.file_exists("user://wall_layout.json"):
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/wall_layout.json")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var widgets: Node = main.get_node("WallWidgets")
	var w1: Node = _panel(widgets, "w1")   # OVERVIEW (text)
	var w3: Node = _panel(widgets, "w3")   # PICTURE
	_check(w1 != null and w1.type_name() == "OVERVIEW", "w1 is a text panel")
	_check(w3 != null and w3.type_name() == "PICTURE", "w3 is a picture panel")
	var p0: float = w1.call("live_phase")
	_check(bool(w1.call("tick_live")), "text panel tick repaints")
	var p1: float = w1.call("live_phase")
	_check(absf(p1 - p0 - 0.45) < 0.001, "phase advanced by LIVE_STEP (%.2f -> %.2f)" % [p0, p1])
	_check(bool(w1.call("tick_live")) and absf(float(w1.call("live_phase")) - p1 - 0.45) < 0.001, "second tick advances again")
	var chrome: Object = w1.get("_chrome_draw")
	_check(chrome != null and absf(float(chrome.get("wave_phase")) - float(w1.call("live_phase"))) < 0.001, "chrome wave_phase matches panel phase")
	_check(not bool(w3.call("tick_live")) and absf(float(w3.call("live_phase"))) < 0.001, "picture panel tick is a no-op")
	print("WALL_LIVE_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
