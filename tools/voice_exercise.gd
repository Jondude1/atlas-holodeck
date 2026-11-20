extends SceneTree
## Voice + voice-CAD exercise (NOT part of the shipped app): runs the real main scene against tools/mock_hub.py
## (HOLODECK_HUB=http://127.0.0.1:PORT) and drives the client through the whole loop, printing "EX " lines:
##   boot -> hub probe -> mic permission/socket -> ready (MIC LIVE) -> spotter wake (LISTENING, captured as
##   shot-05-listening.png) -> thinking -> reply spoken -> PTT (right-trigger path via ptt_begin/ptt_end) ->
##   CAD job accepted -> job done -> glb+manifest downloaded -> bench parks the demo bracket -> materialize
##   (shot-06-voice-cad.png) -> mute control -> unmute.
## Run: HOLODECK_HUB=http://127.0.0.1:8791 xvfb-run godot --path app --resolution 1280x720 --script tools/voice_exercise.gd

const MAX_SECONDS := 150.0

var _main: Node
var _voice: VoiceLink
var _out_dir: String
var _t0 := 0.0
var _states: Array[String] = []

func _initialize() -> void:
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path()
	_t0 = Time.get_ticks_msec() / 1000.0
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_run()

func _ex(msg: String) -> void:
	print("EX t+%5.1fs %s" % [Time.get_ticks_msec() / 1000.0 - _t0, msg])

func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_out_dir.path_join(file_name))
	_ex("CAPTURE %s %s" % [file_name, img.get_size()])

func _until(cond: Callable, label: String, limit := 60.0) -> bool:
	var t_end := Time.get_ticks_msec() / 1000.0 + limit
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() / 1000.0 > t_end:
			_ex("TIMEOUT waiting for: " + label)
			return false
	_ex("ok: " + label)
	return true

func _on_state(s: int) -> void:
	_states.append(VoiceLink.S.keys()[s])
	_ex("voice state -> %s (streaming=%s)" % [VoiceLink.S.keys()[s], _voice.is_streaming()])

func _run() -> void:
	await _until(func() -> bool: return _main.get_node_or_null("Voice") != null, "voice node present", 10.0)
	_voice = _main.get_node("Voice")
	_voice.state_changed.connect(_on_state)
	var bench: CadBench = _main.get_node("CadBench")
	var ok := true
	# the mic starts only after the recorded greeting lines; then the socket opens
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.ARMED, "MIC LIVE after greeting + socket ready", 90.0)
	_ex("hub base_url=%s link=%s streaming=%s" % [Hub.base_url, Hub.link, _voice.is_streaming()])
	# 1. PTT is the primary path. ARMED must NOT be streaming: the mic is off until a hold starts.
	ok = ok and not _voice.is_streaming()
	_ex("idle (PTT-only): state=ARMED streaming=%s label='%s' (must be false / MIC OFF)" % [_voice.is_streaming(), _voice.state_text()])
	var talk: Button = _main.get_node("UIPanel").find_child("TalkButton", true, false)
	ok = ok and talk != null and not talk.disabled
	# 1a. the panel's big TALK button: press and hold = mic live + LISTENING, release = THINKING -> reply spoken
	talk.button_down.emit()
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.LISTENING and _voice.is_streaming(), "TALK held -> LISTENING, mic streaming", 5.0)
	await create_timer(1.2).timeout
	await _snap("shot-05-listening.png")
	talk.button_up.emit()
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.THINKING and not _voice.is_streaming(), "TALK released -> THINKING, mic stopped", 5.0)
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.SPEAKING, "SPEAKING the reply", 20.0)
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.ARMED and not _voice.is_streaming(), "back to idle, mic OFF after speech", 40.0)
	# 2. the controller hold: the REAL hand.gd handler on the LEFT hand (trigger_click), not a direct call
	var lh: XRController3D = _main.get_node("XROrigin3D/LeftHand")
	lh._on_pressed("trigger_click")
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.LISTENING and _voice.is_streaming(), "left trigger held -> LISTENING", 5.0)
	await create_timer(1.2).timeout
	lh._on_released("trigger_click")
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.THINKING, "left trigger released -> THINKING", 5.0)
	# 3. CAD: accepted -> ack spoken -> done -> downloaded -> materialized
	var spawned_model: Array = []
	bench.spawned.connect(func(m: Node3D) -> void: spawned_model.append(m))
	ok = ok and await _until(func() -> bool: return CadBench.status.begins_with("BUILDING"), "HUD CAD status BUILDING", 30.0)
	ok = ok and await _until(func() -> bool: return CadBench.status == "READY", "job done, glb + manifest downloaded, model spawned", 60.0)
	var m: Node3D = _main.get_node_or_null("HoloTable/CadModel1")
	if m:
		_ex("CadModel1: parts=%s dims=%s display_scale=%.2f load_ok=%s" % [m.part_names(), m.dims_text(), m.display_scale, m.load_ok])
		var bracket: Node3D = _main.get_node("HoloTable/TestBracket")
		_ex("bracket parked=%s at %s scale %s" % [bracket.is_parked(), bracket.position, bracket.scale])
		await create_timer(1.1).timeout
		await _snap("shot-06-voice-cad-scan.png")
	ok = ok and await _until(func() -> bool: return spawned_model.size() > 0, "materialize complete", 30.0)
	await create_timer(1.0).timeout
	await _snap("shot-06-voice-cad.png")
	# explode retarget: panel slider drives the new model
	if m:
		m.set_explode(1.0)
		await process_frame
		await process_frame
		await _snap("shot-07-voice-cad-exploded.png")
		_ex("draw calls with CAD model, exploded, capture framing: %d" % await _draws())
		m.set_explode(0.0)
		# worst case: the wide standing pose (95 deg FOV, whole lab in view) with a CAD model + the parked bracket
		var cam: Camera3D = _main.get_node("FallbackCamera")
		cam.fov = 95.0
		cam.global_position = Vector3(0, 1.5, 1.2)
		cam.look_at(Vector3(0, 0.3, -1.55))
		for i in 4:
			await process_frame
		_ex("draw calls with CAD model, wide standing pose (worst case): %d" % await _draws())
		cam.global_position = Vector3(0, 1.62, 0.7)
		cam.look_at(Vector3(0, 1.2, -1.55))
		for i in 4:
			await process_frame
		_ex("draw calls with CAD model, standing at the table: %d" % await _draws())
	# 4. mute control: mic stops, indicator off
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.ARMED, "settled to idle after confirmation speech", 60.0)
	_voice.set_muted(true)
	_ex("muted: state=%s streaming=%s" % [VoiceLink.S.keys()[_voice.state], _voice.is_streaming()])
	ok = ok and _voice.state == VoiceLink.S.MUTED and not _voice.is_streaming()
	await create_timer(0.5).timeout
	_voice.set_muted(false)
	ok = ok and await _until(func() -> bool: return _voice.state == VoiceLink.S.ARMED, "unmuted -> idle again", 20.0)
	_ex("state sequence: %s" % " > ".join(_states))
	_ex("RESULT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _draws() -> int:
	await RenderingServer.frame_post_draw
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
