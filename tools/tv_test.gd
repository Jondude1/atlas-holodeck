extends SceneTree
## R7-1 TV panel headless unit test (NOT shipped).
## Verifies: panel spawns on front wall, UIPanel TV toggle works, resize clamps
## strictly hold 16:9 (0.8-2.6 m) via API and 2-hand stretch, placement drag +
## snap + persistence work, browser UI populates from injected fake data, and
## state machine transitions cleanly (BROWSE -> PREPARING -> PLAYING -> BROWSE, ERROR).
## Run: godot --headless --path app --script ../tools/tv_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _run() -> void:
	var store_abs := OS.get_user_data_dir() + "/tv_layout.json"
	if FileAccess.file_exists("user://tv_layout.json"):
		DirAccess.remove_absolute(store_abs)

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await process_frame

	var tv: TvPanel = main.get_node_or_null("TvPanel") as TvPanel
	_check(tv != null, "TvPanel node built under Main")
	if tv == null:
		print("TV_TEST FAIL (%d)" % _fails)
		quit(1)
		return

	_check(tv.is_in_group("grabbable") and tv.is_in_group("tv_panel"), "TvPanel in grabbable + tv_panel groups")
	_check(tv.wall == "front" and absf(tv.global_position.z - 2.94) < 0.02,
			"default placement is FRONT wall (wall=%s, z=%.2f)" % [tv.wall, tv.global_position.z])
	_check(absf(tv.rotation_degrees.y - 180.0) < 0.5, "TV faces into room from front wall (yaw=%.1f)" % tv.rotation_degrees.y)

	# UIPanel TV toggle button
	var panel: Node = main.get_node("UIPanel")
	var tv_btn: Button = panel.get("_tv_button") as Button
	_check(tv_btn != null and tv_btn.text == "TV", "UIPanel has TV button in tools row")
	var was_vis: bool = tv.visible
	tv.toggle_tv()
	_check(tv.visible == (not was_vis), "toggle_tv hides TV")
	if not tv.visible:
		var probe_hand := Node3D.new()
		root.add_child(probe_hand)
		probe_hand.global_position = tv.global_position
		_check(not tv.can_grab(probe_hand), "hidden TV ignores grabs")
		_check(tv.pick(Vector3(0, 1.6, 1.0), Vector3(0, 0, 1)) == null, "hidden TV ignores pointer rays")
		probe_hand.queue_free()
	tv.set_tv_visible(true)
	_check(tv.visible, "TV shown again")

	# Resize clamps + strict 16:9 ratio
	var target_ratio := 16.0 / 9.0
	tv.set_width(0.2)
	var s_min: Vector2 = tv.panel_size()
	_check(absf(s_min.x - TvPanel.MIN_WIDTH) < 1e-4 and absf(s_min.x / s_min.y - target_ratio) < 1e-4,
			"min width clamp holds 16:9 (%.3f x %.3f)" % [s_min.x, s_min.y])
	tv.set_width(4.5)
	var s_max: Vector2 = tv.panel_size()
	_check(absf(s_max.x - TvPanel.MAX_WIDTH) < 1e-4 and absf(s_max.x / s_max.y - target_ratio) < 1e-4,
			"max width clamp holds 16:9 (%.3f x %.3f)" % [s_max.x, s_max.y])
	tv.set_width(1.6)
	var s_mid: Vector2 = tv.panel_size()
	_check(absf(s_mid.x - 1.6) < 1e-4 and absf(s_mid.x / s_mid.y - target_ratio) < 1e-4,
			"mid width holds 16:9 (%.3f x %.3f)" % [s_mid.x, s_mid.y])

	# Two-hand stretch resize
	var h1 := Node3D.new()
	var h2 := Node3D.new()
	root.add_child(h1)
	root.add_child(h2)
	h1.global_position = tv.global_position + Vector3(-0.4, 0.0, -0.1)
	h2.global_position = tv.global_position + Vector3(0.4, 0.0, -0.1)
	_check(tv.can_grab(h1) and tv.can_grab(h2), "both hands can grab TV")
	tv.begin_grab(h1)
	tv.begin_grab(h2)
	h1.global_position = tv.global_position + Vector3(-0.6, 0.0, -0.1)
	h2.global_position = tv.global_position + Vector3(0.6, 0.0, -0.1)
	tv.step(0.05)
	var s_stretched: Vector2 = tv.panel_size()
	_check(absf(s_stretched.x - 2.4) < 0.05 and absf(s_stretched.x / s_stretched.y - target_ratio) < 1e-4,
			"two-hand stretch resizes cleanly at 16:9 (%.2f x %.2f)" % [s_stretched.x, s_stretched.y])
	tv.end_grab(h2)
	tv.end_grab(h1)

	# Single-hand placement drag + snap on release
	tv.set_width(1.6)
	tv.set_spot("front", 0.0, 1.60)
	h1.global_position = tv.global_position + Vector3(0.0, 0.0, -0.1)
	tv.begin_grab(h1)
	h1.global_position = Vector3(0.73, 1.77, 2.84)
	for i in 25:
		tv.step(0.05)
	tv.end_grab(h1)
	var sp: Dictionary = tv.spot()
	var u_val := float(sp.get("u", 0.0))
	var v_val := float(sp.get("v", 0.0))
	_check(absf(u_val - 0.75) < 0.06 and absf(u_val - snappedf(u_val, 0.05)) < 1e-4,
			"placement drag snaps u to 0.05 m grid (u=%.2f)" % u_val)
	_check(absf(v_val - 1.75) < 0.06 and absf(v_val - snappedf(v_val, 0.05)) < 1e-4,
			"placement drag snaps v to 0.05 m grid (v=%.2f)" % v_val)
	_check(FileAccess.file_exists("user://tv_layout.json"), "layout persisted on release")
	h1.queue_free()
	h2.queue_free()

	# Browser UI populates from injected fake data (no Marvel names)
	var fake_libs: Array = [
		{"id": "lib-cinema", "name": "Cinema", "type": "movies"},
		{"id": "lib-docs", "name": "Documentaries", "type": "tvshows"},
	]
	var fake_cinema: Array = [
		{"id": "item-01", "name": "Orbital Horizon", "year": 2024, "runtime": 6480, "has_poster": false},
		{"id": "item-02", "name": "Coastal Telemetry", "year": 2022, "runtime": 5400, "has_poster": false},
		{"id": "item-03", "name": "Deep Ocean Survey", "year": 2023, "runtime": 4920, "has_poster": false},
		{"id": "item-04", "name": "Machined Light", "year": 2025, "runtime": 7140, "has_poster": false},
	]
	var fake_docs: Array = [
		{"id": "doc-01", "name": "Pacific Ridge · S01E01", "year": 2023, "runtime": 2700, "has_poster": false},
	]
	tv.inject_libraries(fake_libs)
	tv.inject_items("lib-cinema", fake_cinema)
	tv.inject_items("lib-docs", fake_docs)
	_check(tv.library_count() == 2, "2 libraries populated")
	_check(tv.item_count() == 4, "4 items populated in active library")
	var grid: GridContainer = tv.get("_items_grid") as GridContainer
	_check(grid != null and grid.get_child_count() == 4, "poster grid has 4 cards")
	tv.select_library("lib-docs")
	_check(tv.item_count() == 1 and grid.get_child_count() == 1, "switching library updates item grid")
	tv.select_library("lib-cinema")

	# State machine: BROWSE -> PREPARING -> PLAYING -> BROWSE -> ERROR -> BROWSE
	_check(tv.state == TvPanel.State.BROWSE, "starts in BROWSE state")
	tv.request_play(fake_cinema[0])
	_check(tv.state == TvPanel.State.PREPARING, "request_play transitions to PREPARING")
	tv.set_preparing_progress(0.42)
	var prep_lbl: Label = tv.get("_prep_status") as Label
	_check(prep_lbl != null and prep_lbl.text.contains("42%"), "preparing progress displays percentage (%s)" % (prep_lbl.text if prep_lbl else ""))

	# Verify PLAYING transition using a dummy local file path check + real file if present
	var tmp_ogv := OS.get_user_data_dir() + "/tv_test_stub.ogv"
	var f := FileAccess.open(tmp_ogv, FileAccess.WRITE)
	if f:
		f.store_string("OggS")
		f.close()
	var play_ok: bool = tv.play_local_file(tmp_ogv, "Orbital Horizon")
	var play_layer: Control = tv.get("_play_layer") as Control
	var browser_layer: Control = tv.get("_browser_layer") as Control
	var play_bar: Control = tv.get("_play_bar") as Control
	_check(play_ok and tv.state == TvPanel.State.PLAYING, "play_local_file transitions to PLAYING")
	_check(play_layer.visible and not browser_layer.visible and not play_bar.visible,
			"PLAYING hides browser and controls, shows video full-screen")
	tv.stop_playback()
	_check(tv.state == TvPanel.State.BROWSE and browser_layer.visible and not play_layer.visible,
			"stop_playback returns cleanly to BROWSE")
	tv.set_error("Bridge unreachable")
	_check(tv.state == TvPanel.State.ERROR, "set_error transitions cleanly to ERROR without crashing")

	# Clean up test files
	if FileAccess.file_exists(tmp_ogv):
		DirAccess.remove_absolute(tmp_ogv)
	if FileAccess.file_exists("user://tv_layout.json"):
		DirAccess.remove_absolute(store_abs)

	print("TV_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
