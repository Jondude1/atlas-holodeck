extends Node
## Autoload (runs before the main scene). Brings up OpenXR with per-frame retry for
## ~5 s, logs every init attempt and XRServer session transition with msec timestamps
## (grep logcat for "[XR]"), and arbitrates cameras deterministically. If no OpenXR
## interface exists (desktop / headless) it does nothing and main.gd keeps its fallback.

const RETRY_SECONDS := 5.0

var interface: XRInterface
var ready_ok := false          ## true once the interface initialized and use_xr is set
var gave_up := false           ## true if no interface exists or retries ran out
var _t0 := 0
var _attempts := 0
var _last_fail_log := -1000

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
	XRServer.connect("session_begun", func(): _log("XRServer session_begun"))
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
