extends Node3D
## Boots OpenXR; if no HMD/runtime is available, falls back to a plain camera so the
## scene still loads and renders (desktop / headless validation). Then runs the boot
## sequence (SPEC §2.6): black -> ring draws in -> arc fills -> pulse -> room/table fade up
## -> greeting, panel reveal, model materializes.

const RING_DISTANCE := 1.3

@onready var _fallback: Camera3D = $FallbackCamera
@onready var _table: Node3D = $HoloTable
@onready var _model: Node3D = $HoloTable/TestBracket
@onready var _panel: Node3D = $UIPanel
@onready var _room: Room = $Room
@onready var _hud: Hud = $Hud

var _voice: VoiceLink
var _bench: CadBench
var _vista: VistaDeck

var _xr_ok := false
var _ring_mat: ShaderMaterial
var _ring: MeshInstance3D

## Round 2 (R2-8): the boot ring sequence is skippable — any controller
## button press jumps to the normal completion path (materialize +
## greeting still happen). _boot_finished guards against double-running
## the completion when the killed tweens' coroutine is abandoned.
var _booting := false
var _boot_finished := false
var _boot_tweens: Array[Tween] = []

func _ready() -> void:
	add_child(Sfx.new())
	_apply_tokens()
	# XR startup lives in the XrBoot autoload (retries ~5 s, logs session signals, and
	# arbitrates cameras). If it hasn't come up yet we run on the fallback camera and
	# switch over if a retry succeeds.
	_xr_ok = XrBoot.ready_ok
	if not _xr_ok:
		push_warning("OpenXR unavailable - using fallback camera")
		_fallback.current = true
		_fallback.look_at($HoloTable.global_position + Vector3.UP * 1.0)
		if not XrBoot.gave_up:
			XrBoot.xr_started.connect(_on_xr_started, CONNECT_ONE_SHOT)
	_voice = VoiceLink.new()
	_voice.name = "Voice"
	add_child(_voice)
	_voice.attach_speaker(_panel)
	_panel.bind_voice(_voice)
	_hud.bind_voice(_voice)
	_bench = CadBench.new()
	_bench.name = "CadBench"
	add_child(_bench)
	_bench.setup(_table, _model, _panel, _hud, _voice)
	_bench.bind_station(_room.station())
	# Round 5: the world outside the open wall — resident vistas, mood bound to the
	# Environment + the table's light rig; the panel's VIEW button cycles them.
	_vista = VistaDeck.new()
	_vista.name = "VistaDeck"
	add_child(_vista)
	_vista.bind($WorldEnvironment.environment, _table.mood_lights())
	_panel.bind_vista(_vista)
	# Round 5B: the locomotion rig owns the XR origin (stick move + snap turn, clamped
	# to the room/doorway/terrace). Inert without controllers; never touches the fallback cam.
	var rig := LocoRig.new()
	rig.name = "LocoRig"
	add_child(rig)
	rig.setup($XROrigin3D, $XROrigin3D/XRCamera3D, $XROrigin3D/LeftHand, $XROrigin3D/RightHand)
	var print_flow := PrintFlow.new()          # confirmation-gated send-to-print (dry run only in this build)
	print_flow.name = "PrintFlow"
	add_child(print_flow)
	print_flow.bind_voice(_voice)
	_panel.bind_print(print_flow)
	_bench.bind_print(print_flow)
	_table.set_link("LINK — LOCAL (XR)" if _xr_ok else "LINK — FALLBACK")
	_table.set_parts(_model.part_names().size())
	_table.set_dims(_model.dims_text())
	_boot()

func _on_xr_started() -> void:
	_xr_ok = true
	_fallback.current = false
	_table.set_link("LINK — LOCAL (XR)")

## Colours come from Tokens only; the scene file carries geometry, not colour.
func _apply_tokens() -> void:
	var env: Environment = $WorldEnvironment.environment
	# Static procedural sky: never seen (the room hides it), exists so metals reflect a
	# blue horizon band instead of a flat colour. Cheap: no probes, no post.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, 0.55)   # upward-facing metal (floor, slab top) reflects this
	# horizon lifted a step (brief #12): this is what bare metal reflects, so the slab / benches / rig read as machined
	# metal with a blue gradient instead of flat black. Still never seen directly (the room encloses it).
	sky_mat.sky_horizon_color = Tokens.HOLO_PRIMARY.lerp(Tokens.HOLO_DEEP, 0.4)
	sky_mat.ground_horizon_color = Tokens.HOLO_PRIMARY.lerp(Tokens.HOLO_DEEP, 0.5)
	sky_mat.ground_bottom_color = Tokens.HOLO_DEEP
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Tokens.HOLO_DEEP.lerp(Tokens.ROOM_BG, 0.4)
	env.fog_light_energy = 0.8
	env.fog_density = 0.035
	env.fog_sky_affect = 0.0
	_room.build(Vector2($HoloTable.position.x, $HoloTable.position.z))
	_hud.build(_model, _table)
	var laser := StandardMaterial3D.new()
	laser.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser.albedo_color = Tokens.HOLO_LINE
	for path in ["XROrigin3D/LeftHand/Marker", "XROrigin3D/RightHand/Marker", "XROrigin3D/RightHand/Laser"]:
		get_node(path).material_override = laser

func _tween(setter: Callable, from: float, to: float, dur: float,
		trans := Tween.TRANS_CUBIC, ease_type := Tween.EASE_OUT) -> Signal:
	var tw := create_tween()
	tw.tween_method(setter, from, to, dur).set_trans(trans).set_ease(ease_type)
	if _booting:
		_boot_tweens.append(tw)
	return tw.finished

func _skip_boot() -> void:
	if not _booting or _boot_finished:
		return
	for tw in _boot_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_boot_tweens.clear()
	# Final visual state of the ring sequence, then the normal path.
	_set_ring(1.0, &"reveal")
	_set_ring(1.0, &"progress")
	_set_ring(0.0, &"pulse")
	_set_ring(0.0, &"fade")
	_set_fade(1.0)
	if _ring:
		_ring.queue_free()
		_ring = null
	print("boot skipped by input")
	_finish_boot()

func _finish_boot() -> void:
	if _boot_finished:
		return
	_boot_finished = true
	Sfx.start_hum(self)
	_booting = false
	_on_boot_complete()

func _on_any_controller_button(_name: String) -> void:
	if _booting:
		_skip_boot()

func _input(event: InputEvent) -> void:
	# Desktop/headless convenience: a physical key also skips.
	if _booting and event is InputEventKey and (event as InputEventKey).pressed:
		_skip_boot()

func _set_ring(v: float, param: StringName) -> void:
	_ring_mat.set_shader_parameter(param, v)

func _set_fade(v: float) -> void:
	_room.set_fade(v)
	_hud.set_fade(v)
	_table.set_fade(v)
	_table.scale = Vector3.ONE * lerpf(0.94, 1.0, v)

func _boot() -> void:
	_booting = true
	for hand_path in ["XROrigin3D/LeftHand", "XROrigin3D/RightHand"]:
		var c := get_node_or_null(hand_path) as XRController3D
		if c and not c.button_pressed.is_connected(_on_any_controller_button):
			c.button_pressed.connect(_on_any_controller_button)
	_set_fade(0.0)
	_model.hide_all()
	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.9
	_ring.mesh = quad
	_ring_mat = Fx.ring_material()
	_ring_mat.set_shader_parameter("reveal", 0.0)
	_ring_mat.set_shader_parameter("progress", 0.0)
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 1.6, -RING_DISTANCE)
	add_child(_ring)
	Sfx.play(self, "boot")

	await _tween(_set_ring.bind(&"reveal"), 0.0, 1.0, 0.6)          # draw in
	await _tween(_set_ring.bind(&"progress"), 0.0, 1.0, 1.7,
			Tween.TRANS_SINE, Tween.EASE_IN_OUT)                                          # fill
	await _tween(_set_ring.bind(&"pulse"), 0.0, 1.0, 0.2)           # pulse at 100%
	_tween(_set_ring.bind(&"pulse"), 1.0, 0.0, 0.2)
	_tween(_set_ring.bind(&"fade"), 1.0, 0.0, 0.5)
	await _tween(_set_fade, 0.0, 1.0, 1.5)                                              # room + table up
	if _boot_finished:
		return  # a skip already ran the completion path; the ring is freed there
	_ring.queue_free()
	_finish_boot()

func _on_boot_complete() -> void:
	print("boot complete")
	_check_hub()
	_table.start_motes()
	_room.start_dust()
	_panel.reveal()
	_model.labels_beat.connect(_on_labels_beat, CONNECT_ONE_SHOT)
	await _model.materialize()
	print("materialize complete")
	await _greet()
	_voice.start()  # brief #11: the mic opens only after the recorded lines, so the greeting is never "heard"

## Round 2 (R2-9): hub-driven greeting. If the hub answered the boot
## probe, Atlas greets through the hub's own voice with real context
## (time of day); the recorded clips remain the offline fallback —
## never an error screen, never silence.
func _greet() -> void:
	# The boot probe runs un-awaited; give it a short grace window so a
	# slow-but-alive hub still gets to speak the greeting.
	var waited := 0.0
	while Hub.link == "" and waited < 4.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if Hub.base_url != "":
		var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
		var part := "morning" if hour < 12 else ("afternoon" if hour < 18 else "evening")
		await _voice.say("Good %s, Jon. The holodeck is ready. Hold the left trigger and ask me to make something." % part)
	else:
		await Sfx.play_and_wait(self, "greeting")
	await Sfx.play_and_wait(self, "confirm_render")  # never overlaps the greeting

func _on_labels_beat() -> void:
	_tween(_table.set_readout_alpha, 0.0, 1.0, 0.2)
	_tween(_model.set_tether_alpha, 0.0, 1.0, 0.3)

## Tries the LAN hub first, then the tailnet (Hub.probe). Result only changes the LINK readout and
## Hub.base_url; failure is never an error screen.
func _check_hub() -> void:
	var ok: bool = await Hub.probe(self)
	_table.set_link("LINK — HUB OK · %s" % Hub.link if ok else "LINK — LOCAL ONLY")
