extends Node3D
## Boots OpenXR; if no HMD/runtime is available, falls back to a plain camera so the
## scene still loads and renders (desktop / headless validation). Then runs the boot
## sequence (SPEC §2.6): black -> ring draws in -> arc fills -> pulse -> room/table fade up
## -> greeting, panel reveal, model materializes.

const HUB_STATUS_URL := "http://100.65.202.81:8765/atlas/status"
const HUB_TIMEOUT := 2.0
const RING_DISTANCE := 1.3

@onready var _fallback: Camera3D = $FallbackCamera
@onready var _table: Node3D = $HoloTable
@onready var _model: Node3D = $HoloTable/TestBracket
@onready var _panel: Node3D = $UIPanel
@onready var _room: MeshInstance3D = $Room

var _xr_ok := false
var _room_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _ring: MeshInstance3D

func _ready() -> void:
	add_child(Sfx.new())
	_apply_tokens()
	var xr := XRServer.find_interface("OpenXR")
	if xr and (xr.is_initialized() or xr.initialize()):
		print("OpenXR initialized")
		_xr_ok = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # headset sets the pace
		_fallback.current = false
	else:
		push_warning("OpenXR unavailable - using fallback camera")
		_fallback.current = true
		_fallback.look_at($HoloTable.global_position + Vector3.UP * 1.0)
	_table.set_link("LINK — LOCAL (XR)" if _xr_ok else "LINK — FALLBACK")
	_table.set_parts(_model.part_names().size())
	_table.set_dims(_model.dims_text())
	_boot()

## Colours come from Tokens only; the scene file carries geometry, not colour.
func _apply_tokens() -> void:
	var env: Environment = $WorldEnvironment.environment
	env.background_color = Tokens.ROOM_BG
	env.ambient_light_color = Tokens.HOLO_DEEP
	_room_mat = Fx.grid_material(Tokens.ROOM_BG, 0.5, 2.0)
	_room.material_override = _room_mat
	var laser := StandardMaterial3D.new()
	laser.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser.albedo_color = Tokens.HOLO_LINE
	for path in ["XROrigin3D/LeftHand/Marker", "XROrigin3D/RightHand/Marker", "XROrigin3D/RightHand/Laser"]:
		get_node(path).material_override = laser

func _tween(setter: Callable, from: float, to: float, dur: float,
		trans := Tween.TRANS_CUBIC, ease_type := Tween.EASE_OUT) -> Signal:
	var tw := create_tween()
	tw.tween_method(setter, from, to, dur).set_trans(trans).set_ease(ease_type)
	return tw.finished

func _set_ring(v: float, param: StringName) -> void:
	_ring_mat.set_shader_parameter(param, v)

func _set_fade(v: float) -> void:
	_room_mat.set_shader_parameter("fade", v)
	_table.set_fade(v)
	_table.scale = Vector3.ONE * lerpf(0.94, 1.0, v)

func _boot() -> void:
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

	await _tween(_set_ring.bind(&"reveal"), 0.0, 1.0, 0.4)          # draw in
	await _tween(_set_ring.bind(&"progress"), 0.0, 1.0, 1.4,
			Tween.TRANS_SINE, Tween.EASE_IN_OUT)                                          # fill
	await _tween(_set_ring.bind(&"pulse"), 0.0, 1.0, 0.1)           # pulse at 100%
	_tween(_set_ring.bind(&"pulse"), 1.0, 0.0, 0.2)
	_tween(_set_ring.bind(&"fade"), 1.0, 0.0, 0.5)
	await _tween(_set_fade, 0.0, 1.0, 0.6)                                              # room + table up
	_ring.queue_free()
	_on_boot_complete()

func _on_boot_complete() -> void:
	print("boot complete")
	Sfx.play(self, "greeting")  # the greeting is the graceful fallback: always plays
	_check_hub()
	_table.start_motes()
	_panel.reveal()
	_model.labels_beat.connect(_on_labels_beat, CONNECT_ONE_SHOT)
	await _model.materialize()
	print("materialize complete")
	Sfx.play(self, "confirm_render")

func _on_labels_beat() -> void:
	_tween(_table.set_readout_alpha, 0.0, 1.0, 0.2)

## Result only changes the LINK readout; failure is never an error screen.
func _check_hub() -> void:
	var http := HTTPRequest.new()
	http.timeout = HUB_TIMEOUT
	add_child(http)
	if http.request(HUB_STATUS_URL) != OK:
		_table.set_link("LINK — LOCAL ONLY")
		http.queue_free()
		return
	var res: Array = await http.request_completed
	var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and res[1] >= 200 and res[1] < 300
	_table.set_link("LINK — HUB OK" if ok else "LINK — LOCAL ONLY")
	http.queue_free()
