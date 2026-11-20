extends Node
## Autoload (runs before the main scene). Brings up OpenXR with per-frame retry for
## ~5 s, logs every init attempt and XRServer session transition with msec timestamps
## (grep logcat for "[XR]"), and arbitrates cameras deterministically. If no OpenXR
## interface exists (desktop / headless) it does nothing and main.gd keeps its fallback.

const RETRY_SECONDS := 5.0
const HEIGHT_RECHECK_SECONDS := 2.0

## Reference-space priority (floor-anchored first): STAGE, then LOCAL_FLOOR, then LOCAL.
## Godot exposes these to script as XRInterface play-area modes (STAGE / ROOMSCALE=LOCAL_FLOOR /
## SITTING=LOCAL) and as the `xr/openxr/reference_space` project setting (0 Local, 1 Stage, 2 Local Floor).
const SPACE_PRIORITY := [
	{"name": "STAGE", "mode": XRInterface.XR_PLAY_AREA_STAGE, "setting": 1},
	{"name": "LOCAL_FLOOR", "mode": XRInterface.XR_PLAY_AREA_ROOMSCALE, "setting": 2},
	{"name": "LOCAL", "mode": XRInterface.XR_PLAY_AREA_SITTING, "setting": 0},
]

var interface: XRInterface
var ready_ok := false          ## true once the interface initialized and use_xr is set
var gave_up := false           ## true if no interface exists or retries ran out
var _t0 := 0
var _attempts := 0
var _last_fail_log := -1000
var _requested_space := "none"

signal xr_started

func _log(msg: String) -> void:
	print("[XR] t+%dms %s" % [Time.get_ticks_msec(), msg])

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	interface = XRServer.find_interface("OpenXR")
	_log("autoload start; interface %s" % ("found" if interface else "NOT found"))
	if interface == null:
		gave_up = true
		set_process(false)
		return
	XRServer.connect("session_begun", _on_session_begun)
	XRServer.connect("session_visible", func(): _log("XRServer session_visible"))
	XRServer.connect("session_focussed", func(): _log("XRServer session_focussed"))
	XRServer.connect("session_stopping", func(): _log("XRServer session_stopping"))
	_try_init()

func _process(_delta: float) -> void:
	if ready_ok or gave_up:
		set_process(false)
		return
	if Time.get_ticks_msec() - _t0 > int(RETRY_SECONDS * 1000.0):
		gave_up = true
		_log("initialize() still failing after %d attempts / %.1fs - giving up, desktop fallback" % [_attempts, RETRY_SECONDS])
		set_process(false)
		return
	_try_init()

func _try_init() -> void:
	_attempts += 1
	if not interface.is_initialized():
		# BEFORE initialize(): ask for the top-priority space (STAGE). Godot reads this setting
		# when it builds the play space, so the intent is in place before the session exists.
		_requested_space = SPACE_PRIORITY[0].name
		ProjectSettings.set_setting("xr/openxr/reference_space", SPACE_PRIORITY[0].setting)
	var ok: bool = interface.is_initialized() or interface.initialize()
	if not ok:
		# retry runs every frame; log the first failure and then ~1/s to keep logcat readable
		var now := Time.get_ticks_msec()
		if _attempts == 1 or now - _last_fail_log >= 1000:
			_last_fail_log = now
			_log("initialize attempt #%d -> FAILED (retrying each frame)" % _attempts)
		return
	_log("initialize attempt #%d -> OK" % _attempts)
	ready_ok = true
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # headset sets the pace
	_log("use_xr = true; OpenXR initialized")
	_select_space()
	set_process(false)
	_arbitrate_cameras.call_deferred()
	xr_started.emit()

## XR active: FallbackCamera off, XRCamera3D on. Deferred so the main scene exists.
func _arbitrate_cameras() -> void:
	var main := get_tree().current_scene
	if main == null:
		await get_tree().process_frame
		main = get_tree().current_scene
	if main == null:
		return
	var fb := main.get_node_or_null("FallbackCamera") as Camera3D
	if fb:
		fb.current = false
	var xc := main.get_node_or_null("XROrigin3D/XRCamera3D") as Camera3D
	if xc:
		xc.current = true
	_log("cameras: FallbackCamera.current=%s XRCamera3D.current=%s" % [fb.current if fb else "n/a", xc.current if xc else "n/a"])

## Walks SPACE_PRIORITY and requests the first mode the runtime reports as supported. Needs an
## initialized interface (supports_play_area_mode asks the runtime), so this runs right after
## initialize() and before the session begins, and corrects the pre-initialize setting if the
## runtime can't do STAGE.
func _select_space() -> void:
	for entry in SPACE_PRIORITY:
		var supported: bool = interface.supports_play_area_mode(entry.mode)
		_log("reference space %s supported=%s" % [entry.name, supported])
		if not supported:
			continue
		_requested_space = entry.name
		ProjectSettings.set_setting("xr/openxr/reference_space", entry.setting)
		var set_ok: bool = interface.set_play_area_mode(entry.mode)
		_log("reference space REQUESTED=%s set_play_area_mode -> %s" % [entry.name, set_ok])
		return
	_requested_space = "LOCAL"
	_log("reference space REQUESTED=LOCAL (no priority entry reported supported; last resort)")

func _granted_space() -> String:
	match interface.get_play_area_mode():
		XRInterface.XR_PLAY_AREA_STAGE: return "STAGE"
		XRInterface.XR_PLAY_AREA_ROOMSCALE: return "LOCAL_FLOOR"
		XRInterface.XR_PLAY_AREA_SITTING: return "LOCAL"
		XRInterface.XR_PLAY_AREA_3DOF: return "3DOF"
		_: return "UNKNOWN"

## Camera height above the XROrigin3D (the floor when the space is floor-anchored).
func camera_height() -> float:
	var main := get_tree().current_scene
	var xc := main.get_node_or_null("XROrigin3D/XRCamera3D") as Node3D if main else null
	return xc.position.y if xc else NAN

func _log_space_and_height(tag: String) -> void:
	_log("%s: reference space REQUESTED=%s GRANTED=%s camera_height=%.3fm" % [tag, _requested_space, _granted_space(), camera_height()])

func _on_session_begun() -> void:
	_log("XRServer session_begun")
	_log_space_and_height("session_begun")
	await get_tree().create_timer(HEIGHT_RECHECK_SECONDS).timeout
	_log_space_and_height("session_begun+%.0fs" % HEIGHT_RECHECK_SECONDS)

## RESET FLOOR: full recenter including height (keep_height = false), logging before/after.
func reset_floor(source := "panel") -> void:
	var before := camera_height()
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, false)
	_log("RESET FLOOR (%s): center_on_hmd(keep_height=false) camera_height before=%.3fm after=%.3fm space=%s" % [source, before, camera_height(), _granted_space() if interface else "n/a"])
	# the pose updates on the next tracking frame, so log the settled value too
	await get_tree().create_timer(0.5).timeout
	_log("RESET FLOOR settled: camera_height=%.3fm" % camera_height())
