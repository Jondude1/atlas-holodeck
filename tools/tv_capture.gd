extends SceneTree
## Windowed captures for R7-1 TV panel (NOT shipped):
##   1) captures/shot-tv-room.png    — TV on the front wall in room context
##   2) captures/shot-tv-browser.png — Close-up of Stark library browser UI
##   3) captures/shot-tv-playback.png — Full-screen .ogv video playback (controls hidden)
## Run: xvfb-run -a godot --path app --script ../tools/tv_capture.gd --resolution 1280x720 -- /tmp/holodeck_jf_smoke.ogv

func _initialize() -> void:
	_run()

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clip_path := String(args[0]) if args.size() > 0 else "/tmp/holodeck_jf_smoke.ogv"

	var store_abs := OS.get_user_data_dir() + "/tv_layout.json"
	if FileAccess.file_exists("user://tv_layout.json"):
		DirAccess.remove_absolute(store_abs)

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait_ms(250)
	main.call("_skip_boot")
	await _wait_ms(500)

	var tv: TvPanel = main.get_node_or_null("TvPanel") as TvPanel
	if tv == null:
		push_error("TvPanel missing")
		quit(1)
		return

	tv.set_tv_visible(true)
	tv.set_spot("front", 0.0, 1.66)
	tv.set_width(1.90)

	# Populate browser with clean, non-Marvel entries using bundled repo imagery as poster art
	var pics := [
		"res://pictures/vista-coast.png",
		"res://pictures/vista-lake.png",
		"res://pictures/vista-valley.png",
		"res://pictures/suit-01-hero.png",
		"res://pictures/suit-04-heroine.png",
		"res://pictures/v2-vision-solid.png",
	]
	var texs: Array = []
	for p in pics:
		texs.append(load(p) if ResourceLoader.exists(p) else null)

	tv.inject_libraries([
		{"id": "lib-movies", "name": "Movies", "type": "movies"},
		{"id": "lib-tv", "name": "TV Shows", "type": "tvshows"},
		{"id": "lib-docs", "name": "Field Logs", "type": "movies"},
	])
	tv.inject_items("lib-movies", [
		{"id": "m1", "name": "Pacific Horizon", "year": 2024, "runtime": 7320, "has_poster": true, "poster_texture": texs[0]},
		{"id": "m2", "name": "Alpine Mirror", "year": 2023, "runtime": 6180, "has_poster": true, "poster_texture": texs[1]},
		{"id": "m3", "name": "Sierra Corridor", "year": 2022, "runtime": 5880, "has_poster": true, "poster_texture": texs[2]},
		{"id": "m4", "name": "Mark Zero Telemetry", "year": 2025, "runtime": 6900, "has_poster": true, "poster_texture": texs[3]},
		{"id": "m5", "name": "Valkyrie Chassis", "year": 2025, "runtime": 6420, "has_poster": true, "poster_texture": texs[4]},
		{"id": "m6", "name": "Solid Vision Lab", "year": 2024, "runtime": 5280, "has_poster": true, "poster_texture": texs[5]},
		{"id": "m7", "name": "Orbital Drift", "year": 2021, "runtime": 7560, "has_poster": false},
		{"id": "m8", "name": "Deep Current", "year": 2023, "runtime": 4980, "has_poster": false},
	])
	tv.request_redraw()

	var cam := Camera3D.new()
	cam.fov = 58.0
	root.add_child(cam)
	cam.current = true

	# Shot 1: Room view showing the TV on the front wall in context
	cam.global_position = Vector3(-1.35, 1.58, -1.10)
	cam.look_at(Vector3(0.0, 1.55, 2.94), Vector3.UP)
	await _wait_ms(400)
	await RenderingServer.frame_post_draw
	var p_room := "res://../captures/shot-tv-room.png"
	root.get_texture().get_image().save_png(p_room)
	print("CAPTURE ", p_room)

	# Shot 2: Browser UI close-up
	cam.fov = 48.0
	cam.global_position = Vector3(0.0, 1.66, 0.96)
	cam.look_at(tv.global_position, Vector3.UP)
	await _wait_ms(300)
	await RenderingServer.frame_post_draw
	var p_browser := "res://../captures/shot-tv-browser.png"
	root.get_texture().get_image().save_png(p_browser)
	print("CAPTURE ", p_browser)

	# Shot 3: Playback running the smoke clip (controls hidden, video edge-to-edge)
	if FileAccess.file_exists(clip_path):
		tv.play_local_file(clip_path, "Live Playback")
		tv.set_controls_visible(false)
		await _wait_ms(1600)
		await RenderingServer.frame_post_draw
		var p_play := "res://../captures/shot-tv-playback.png"
		root.get_texture().get_image().save_png(p_play)
		print("CAPTURE ", p_play)
		tv.stop_playback()
	else:
		print("WARN: playback clip missing at ", clip_path)

	quit(0)
