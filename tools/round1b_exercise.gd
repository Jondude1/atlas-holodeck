extends SceneTree
## Round 1B exercise (NOT shipped): the real main scene against tools/mock_hub.py --edit-assets ... (HOLODECK_HUB=...).
## Proves, with "EX " lines: create -> edit (the app swaps the model IN PLACE: same bench slot/transform, old node freed),
## panel SEND TO PRINTER -> confirmation card -> cancel (hub never called) -> voice request -> spoken yes -> dry-run plan.
## Run: HOLODECK_HUB=http://127.0.0.1:8792 xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/round1b_exercise.gd
var main: Node
var voice: VoiceLink
var bench: CadBench
var pf: PrintFlow
var cam: Camera3D
var out_dir: String
var fails := 0

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()

func ex(msg: String) -> void:
	print("EX %s" % msg)

func check(ok: bool, what: String) -> void:
	print(("EX PASS " if ok else "EX FAIL ") + what)
	if not ok:
		fails += 1

func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("EX CAPTURE ", n, " ", img.get_size(), " err=", img.save_png(out_dir.path_join(n)))

func _until(cond: Callable, label: String, limit := 60.0) -> bool:
	var t_end := Time.get_ticks_msec() / 1000.0 + limit
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() / 1000.0 > t_end:
			check(false, "TIMEOUT: " + label)
			return false
	return true

func _ptt(hold := 0.6) -> void:
	voice.ptt_begin()
	await create_timer(hold).timeout
	voice.ptt_end()

func _draws() -> int:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _run() -> void:
	await process_frame
	await process_frame
	cam = main.get_node("FallbackCamera")
	voice = main.get_node("Voice")
	bench = main.get_node("CadBench")
	pf = main.get_node("PrintFlow")
	var panel: Node3D = main.get_node("UIPanel")
	var table: Node3D = main.get_node("HoloTable")
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "voice armed", 120.0)
	# turn 1: chat; turn 2: "make me ..." -> job A materializes (parks the demo bracket)
	await _ptt()
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "turn 1 done", 60.0)
	await _ptt()
	await _until(func() -> bool: return bench.active_model() != null and String(bench.active_model().get("job_id")) != "", "job A on stage", 90.0)
	await create_timer(4.5).timeout
	var a: Node3D = bench.active_model()
	var a_job := String(a.get("job_id"))
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "idle after job A speech", 90.0)
	# the user moves/rotates/scales the model before asking for the edit
	a.position = Vector3(0.12, 0.951, -0.08)
	a.rotate_y(0.7)
	a.scale = Vector3.ONE * 1.4
	var a_pos := a.position
	var a_quat := a.quaternion
	var a_scale := a.scale
	var bench_n := bench.bench().size()
	var slot := bench.bench().find(a)
	var a_id := a.get_instance_id()
	ex("job A=%s on stage, bench=%d slot=%d dims=%s" % [a_job, bench_n, slot, a.dims_text()])
	# turn 3: the edit
	await _ptt()
	await _until(func() -> bool: return String(bench.active_model().get("job_id")) != a_job, "edit job B replaces A on stage", 90.0)
	await create_timer(0.3).timeout
	var b: Node3D = bench.active_model()
	check(String(b.get("job_id")) == "b7c1e44f02", "active model is the revision (job b7c1e44f02)")
	check(bench.bench().size() == bench_n, "bench size unchanged (%d): replaced, not parked beside" % bench_n)
	check(bench.bench().find(b) == slot, "revision holds the same bench slot (%d)" % slot)
	check(b.position.is_equal_approx(a_pos) and b.quaternion.is_equal_approx(a_quat) and b.scale.is_equal_approx(a_scale),
			"same position / orientation / scale as the model it replaced")
	check(not is_instance_valid(instance_from_id(a_id)) or (instance_from_id(a_id) as Node).is_queued_for_deletion(), "old model freed")
	check(not b.is_parked(), "revision is on stage (not parked)")
	ex("revised dims=%s (was taller-by-2in) parts=%s" % [b.dims_text(), b.part_names()])
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "idle after edit speech", 90.0)
	var treb_like := bench.bench().size()
	# ---- print flow, panel path: button -> card -> CANCEL -> hub never called
	var send: Button = null
	for n in panel.find_children("*", "Button", true, false):
		if (n as Button).text == "SEND TO PRINTER":
			send = n
	check(send != null, "panel has a SEND TO PRINTER button")
	send.pressed.emit()
	check(pf.state == PrintFlow.S.CONFIRMING and pf.info["job_id"] == "b7c1e44f02", "panel press opens CONFIRMING for the on-stage part")
	await create_timer(0.8).timeout
	var pp := panel.global_position
	cam.fov = 50.0
	cam.global_position = pp + panel.global_basis.z * 1.25 + Vector3(0, 0.0, 0)
	cam.look_at(pp)
	await create_timer(0.5).timeout
	await _snap("r1b-print-confirmation.png")
	var card: Control = panel.find_child("PrintCard", true, false)
	check(card != null and card.visible, "confirmation card is visible")
	pf.cancel("panel")
	check(pf.state == PrintFlow.S.IDLE and pf.submit_calls == 0, "CANCEL -> IDLE, hub print-job never called")
	# ---- voice path: PTT turn 4 "send it to the printer" -> card; turn 5 "yes" -> plan
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "armed before turn 4", 60.0)
	await _ptt()
	await _until(func() -> bool: return pf.state == PrintFlow.S.CONFIRMING, "hub print_request opens the card", 30.0)
	check(pf.last_via == "voice" and pf.submit_calls == 0, "voice request only opened the card (nothing started)")
	await _until(func() -> bool: return voice.state == VoiceLink.S.ARMED, "armed after confirmation prompt", 60.0)
	await _ptt()
	await _until(func() -> bool: return pf.state == PrintFlow.S.DONE, "spoken yes -> dry-run plan returned", 30.0)
	check(pf.last_via == "voice" and pf.submit_calls == 1 and pf.plan.get("dry_run") == true and pf.plan.get("contacted_printer") == false,
			"one hub call, DRY-RUN plan, printer not contacted")
	await create_timer(0.8).timeout
	await _snap("r1b-print-dry-run-plan.png")
	pf.dismiss()
	# draw calls (panel idle, bracket revision on stage)
	cam.fov = 58.0
	cam.global_position = Vector3(0.0, 1.9, -0.55)
	cam.look_at(table.global_position + Vector3(0, 1.1, 0))
	await create_timer(0.6).timeout
	await _snap("r1b-edit-in-place.png")
	var perf_draws: int = await _draws()
	var perf_lights: int = _count(root, "Light3D")
	print("EX PERF draw_calls=%d lights=%d" % [perf_draws, perf_lights])
	check(perf_draws <= 95, "R4-7 ceiling: draw calls %d <= 95 (Quest 2 mono budget)" % perf_draws)
	check(perf_lights <= 3, "R4-7 ceiling: lights %d <= 3" % perf_lights)
	print("ROUND1B_EXERCISE ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)

func _count(n: Node, type: String) -> int:
	var c := 1 if n.is_class(type) else 0
	for k in n.get_children():
		c += _count(k, type)
	return c
