class_name CadBench
extends Node
## Voice-to-CAD on the table (brief #11 / SPEC §3 data flow). When the hub accepts a "make me a ..." request this
## follows the job (socket events AND a status poll, so a dropped socket can't lose a finished part), downloads the
## .glb + manifest, and materializes the result with the existing language. The previously active model is parked
## aside (multi-object bench); the new one takes centre stage, the panel/HUD/readouts retarget to it.
## Voice alone never prints: this build has no print path at all (a future one is panel-confirmation only).

signal spawned(model: Node3D)
signal selected(model: Node3D)

const CadModelScript := preload("res://cad_model.gd")
const POLL_SECONDS := 3.0
const POLL_MAX_SECONDS := 420.0
const MAX_ON_BENCH := 5
const PARK_SLOTS := [Vector3(-0.8, 0.0, 0.3), Vector3(0.8, 0.0, 0.3), Vector3(-0.8, 0.0, -0.3), Vector3(0.8, 0.0, -0.3)]

## Real status for the HUD card: "" | "BUILDING 42 s" | "READY"
static var status := ""

var _table: Node3D
var _panel: Node3D
var _hud: Node
var _voice: VoiceLink
var _active: Node3D
var _bench: Array[Node3D] = []
var _handled := {}
var _t_job := 0.0

func setup(table: Node3D, first_model: Node3D, panel: Node3D, hud: Node, voice: VoiceLink) -> void:
	_table = table
	_panel = panel
	_hud = hud
	_voice = voice
	add_to_group("cad_bench")
	_active = first_model
	_bench.append(first_model)
	_watch(first_model)
	voice.cad_job.connect(_on_job)
	voice.cad_done.connect(_on_done)
	voice.cad_failed.connect(_on_failed)

func _log(msg: String) -> void:
	print("[CAD] t+%dms %s" % [Time.get_ticks_msec(), msg])

func _on_job(job_id: String, _ack: String) -> void:
	_t_job = Time.get_ticks_msec() / 1000.0
	status = "BUILDING 0 s"
	_log("job %s accepted - following it" % job_id)
	_poll(job_id)

func _on_failed(job_id: String, detail: String) -> void:
	if _handled.has(job_id):
		return
	_handled[job_id] = true
	status = ""
	_log("job %s failed: %s" % [job_id, detail])
	_voice.say(FailureReason.spoken(detail))     # the hub's real reason, sanitized to one sentence (R1-5)

func _on_done(job_id: String) -> void:
	if _handled.has(job_id):
		return
	_handled[job_id] = true
	var info := await _get_json("/atlas/cad-job/%s" % job_id)
	var glb := await _get_bytes("/atlas/cad-job/%s/model" % job_id)
	if info.is_empty() or glb.is_empty() or not info.has("manifest"):
		status = ""
		_log("job %s: download failed (status %s, glb %d bytes)" % [job_id, not info.is_empty(), glb.size()])
		_voice.say("The part finished, but I couldn't bring it over. Ask me again in a moment.")
		return
	_log("job %s: downloaded %d bytes + manifest" % [job_id, glb.size()])
	await spawn(glb, info["manifest"])

## Polls the job so completion is caught even if the socket dropped (or the hub is reached by LAN only for REST).
func _poll(job_id: String) -> void:
	var t_end := Time.get_ticks_msec() / 1000.0 + POLL_MAX_SECONDS
	while Time.get_ticks_msec() / 1000.0 < t_end and not _handled.has(job_id):
		await get_tree().create_timer(POLL_SECONDS).timeout
		status = "BUILDING %d s" % int(Time.get_ticks_msec() / 1000.0 - _t_job)
		if _handled.has(job_id):
			return
		var info := await _get_json("/atlas/cad-job/%s" % job_id)
		match String(info.get("status", "")):
			"done":
				_on_done(job_id)
				return
			"failed":
				_on_failed(job_id, String(info.get("error", "")))
				return

## Builds the model from downloaded bytes and runs the arrival: park the old one, speak, materialize, retarget.
func spawn(glb: PackedByteArray, manifest: Dictionary) -> Node3D:
	var m: Node3D = Node3D.new()
	m.set_script(CadModelScript)
	m.name = "CadModel%d" % (_bench.size())
	m.call("setup", glb, manifest)
	m.position = _active.position if _active else Vector3(0, 0.951, 0)
	_table.add_child(m)                      # _ready builds parts + schematic + tethers (hidden)
	if not m.get("load_ok"):
		m.queue_free()
		status = ""
		_voice.say("The part came back, but I couldn't read it. Let's try that again.")
		return null
	m.call("hide_all")
	_park_active()
	_bench.append(m)
	_watch(m)
	_active = m
	_trim_bench()
	_retarget(m)
	status = "READY"
	var name_text: String = String(manifest.get("name", "part"))
	var parts: int = (manifest.get("parts", []) as Array).size()
	var line := "Here is your %s. %s, %s." % [name_text, ("%d parts" % parts) if parts != 1 else "One part", m.call("spoken_dims")]
	_log("materializing '%s' (%d parts, %s)" % [name_text, parts, m.call("spoken_dims")])
	_voice.say(line)                         # before: what it is and its true size
	m.labels_beat.connect(_on_labels_beat.bind(m), CONNECT_ONE_SHOT)
	await m.materialize()
	_log("materialize complete")
	spawned.emit(m)
	await _voice.say("Take a look. You can grab it, or pull it apart from the panel. Nothing goes to the printer without your confirmation.")
	status = ""
	return m

func _watch(m: Node3D) -> void:
	m.connect("flicked_aside", _on_flicked)

## A flick that comes to rest away from the centre parks the model where it stopped (small, labels off).
func _on_flicked(m: Node3D) -> void:
	if m.call("is_parked"):
		return
	_log("flicked aside: parking %s" % m.name)
	m.call("park", Vector3(m.position.x, m.position.y, m.position.z))

## Bench select (R1-7): pull a parked model back to centre stage. It becomes the active model (panel / HUD / readouts
## retarget); the one that was on stage parks into the slot the selected one just vacated.
func select(m: Node3D) -> void:
	if m == null or not (m in _bench):
		return
	if m == _active and not m.call("is_parked"):
		return
	var vacated: Vector3 = m.position
	if _active != null and _active != m and not _active.call("is_parked"):
		_active.call("park", Vector3(vacated.x, _active.position.y, vacated.z))
	_active = m
	m.call("reset_pose", 0.7)
	_retarget(m)
	_log("bench select: %s now active" % m.name)
	selected.emit(m)

## Model reset (R1-3): the active model back to centre, upright, display scale, assembled. If it had been parked
## aside, it is brought back like a bench select.
func reset_active() -> void:
	if _active == null:
		return
	if _active.call("is_parked"):
		select(_active)
	else:
		_active.call("reset_pose", 0.6)
		_retarget(_active)

func active_model() -> Node3D:
	return _active

func bench() -> Array[Node3D]:
	return _bench

func _on_labels_beat(m: Node3D) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_table.set_readout_alpha, 0.0, 1.0, 0.2)
	tw.tween_method(m.set_tether_alpha, 0.0, 1.0, 0.3)

func _park_active() -> void:
	if _active == null or _active.call("is_parked"):
		return
	var used := 0
	for b in _bench:
		if b != _active and b.call("is_parked"):
			used += 1
	var slot: Vector3 = PARK_SLOTS[used % PARK_SLOTS.size()]
	_active.call("park", Vector3(slot.x, _active.position.y, slot.z))

## Keep the bench honest: the oldest parked runtime model is freed once there are too many (never the demo bracket).
func _trim_bench() -> void:
	while _bench.size() > MAX_ON_BENCH:
		var victim: Node3D = null
		for b in _bench:
			if b != _active and b.call("is_parked") and b.get_script() == CadModelScript:
				victim = b
				break
		if victim == null:
			return
		_bench.erase(victim)
		victim.queue_free()

func _retarget(m: Node3D) -> void:
	_panel.call("set_model", m)
	_hud.call("set_model", m)
	_table.call("set_parts", m.part_names().size())
	_table.call("set_dims", m.dims_text())

# ---------------------------------------------------------------- REST

func _get_json(path: String) -> Dictionary:
	var body := await _get_bytes(path)
	if body.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}

func _get_bytes(path: String) -> PackedByteArray:
	if Hub.base_url == "":
		return PackedByteArray()
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	if http.request(Hub.base_url + path, Hub.auth_headers()) != OK:
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return PackedByteArray()
	return res[3]
