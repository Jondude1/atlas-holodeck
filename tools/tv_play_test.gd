extends SceneTree
## R7-1 windowed playback proof (NOT shipped).
## Plays a real Theora/Vorbis (.ogv) clip on TvPanel's VideoStreamPlayer under xvfb,
## verifies the player is actively playing and stream_position advances over real wall time,
## and optionally saves captures/shot-tv-playback.png.
## Run: xvfb-run -a godot --path app --script ../tools/tv_play_test.gd --resolution 1280x720 -- /tmp/holodeck_jf_smoke.ogv [capture]
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _wait_ms(ms: int) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clip_path := String(args[0]) if args.size() > 0 else "/tmp/holodeck_jf_smoke.ogv"
	var do_capture := args.size() > 1 and String(args[1]) == "capture"

	var store_abs := OS.get_user_data_dir() + "/tv_layout.json"
	if FileAccess.file_exists("user://tv_layout.json"):
		DirAccess.remove_absolute(store_abs)

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait_ms(250)
	main.call("_skip_boot")
	await _wait_ms(400)

	var tv: TvPanel = main.get_node_or_null("TvPanel") as TvPanel
	_check(tv != null, "TvPanel present in scene")
	if tv == null:
		print("TV_PLAY_TEST FAIL (%d)" % _fails)
		quit(1)
		return

	tv.set_tv_visible(true)
	tv.set_spot("front", 0.0, 1.62)
	tv.set_width(1.90)

	# Aim camera straight at the front-wall TV so the SubViewport renders in the window
	var cam := Camera3D.new()
	cam.fov = 56.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.0, 1.62, 0.75)
	cam.look_at(tv.global_position, Vector3.UP)

	_check(FileAccess.file_exists(clip_path), "clip file exists (%s)" % clip_path)
	var started: bool = tv.play_local_file(clip_path, "Live Stream Test")
	_check(started and tv.state == TvPanel.State.PLAYING, "TvPanel entered PLAYING state")

	await _wait_ms(600)
	var playing_1: bool = tv.is_playing()
	var pos_1: float = tv.playback_position()
	var vp_player: VideoStreamPlayer = tv.video_player()
	var tex_1: Texture2D = vp_player.get_video_texture() if vp_player else null
	_check(playing_1, "VideoStreamPlayer reports is_playing() == true")
	_check(tex_1 != null and tex_1.get_width() > 0 and tex_1.get_height() > 0,
			"decoded video texture valid (%dx%d)" % [tex_1.get_width() if tex_1 else 0, tex_1.get_height() if tex_1 else 0])

	# Wait 1.4 s real wall clock and verify playback advances
	await _wait_ms(1400)
	var playing_2: bool = tv.is_playing()
	var pos_2: float = tv.playback_position()
	_check(playing_2 and pos_2 > pos_1 + 0.35,
			"video playback advanced (pos %.2fs -> %.2fs)" % [pos_1, pos_2])

	if do_capture:
		tv.set_controls_visible(false)
		await _wait_ms(200)
		await RenderingServer.frame_post_draw
		var out_path := "res://../captures/shot-tv-playback.png"
		root.get_texture().get_image().save_png(out_path)
		print("CAPTURE ", out_path)

	tv.stop_playback()
	_check(tv.state == TvPanel.State.BROWSE and not tv.is_playing(), "stop_playback returned to BROWSE")
	print("TV_PLAY_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
