class_name CadBench
extends Node
## Voice-to-CAD on the table (brief #11 / SPEC §3 data flow). When the hub accepts a "make me a ..." request this
## follows the job (socket events AND a status poll, so a dropped socket can't lose a finished part), downloads the
## .glb + manifest, and materializes the result with the existing language. The previously active model is parked
## aside (multi-object bench); the new one takes centre stage, the panel/HUD/readouts retarget to it.
## A follow-up edit ("make it taller") arrives as a job whose status names its `parent`: the revised model REPLACES the
## parent's model in place (same bench slot, same transform) instead of being parked next to it (brief #16 R1-4).
## Voice alone never prints: send-to-print is the confirmation-gated, dry-run-only PrintFlow.

signal spawned(model: Node3D)
var _presence: Presence
var _overview_lines: Array = []   # R6: composed for the wall widgets (was the station wall)
var _lib_count := -1
var _lib_recent: Array = []
var _last_job_stamp := ""

## R3-11: the back-wall data station mirrors REAL bench state (library, table, last job).
func bind_presence(p: Presence) -> void:
	_presence = p
	_refresh_station()

## The current overview lines (title first) — the wall widgets render these (R6-2).
func overview_lines() -> Array:
	return _overview_lines

## Wall-widget feeds (R6-2): the active model and the library, as display lines.
func model_lines() -> Array:
	if _active:
		var nm: Variant = _active.get("model_name")
		var lines: Array = ["ON THE TABLE", String(nm) if nm != null else "DEMO BRACKET", "SIZE — %s" % _active.dims_text()]
		var pc: int = _active.part_names().size()
		if pc > 0:
			lines.append("PARTS — %d" % pc)
		return lines
	return ["ON THE TABLE", "— NOTHING YET —", "ASK ATLAS FOR A PART, OR LOAD ONE FROM THE LIBRARY"]

func library_lines() -> Array:
	var lines: Array = ["PARTS LIBRARY"]
	lines.append("%s" % ("%d PARTS" % _lib_count if _lib_count >= 0 else "—"))
	for e in _lib_recent:
		lines.append("· %s" % String(e))
	return lines

static func dims_line(d: Array) -> String:
	return Units.dims_line(d)

func _refresh_station() -> void:
	var lines: Array = ["WORKSHOP OVERVIEW"]
	lines.append("LIBRARY — %s" % ("%d PARTS" % _lib_count if _lib_count >= 0 else "—"))
	for e in _lib_recent:
		lines.append("· %s" % String(e))
	if _active:
		lines.append("ON TABLE — %d PARTS · %s" % [_active.part_names().size(), _active.dims_text()])
	else:
		lines.append("ON TABLE — —")
	if _last_job_stamp != "":
		lines.append("LAST JOB — %s" % _last_job_stamp)
	_overview_lines = lines

func _push_schematic_later(m: Node3D) -> void:
	# R6: the station's schematic disc is gone (the table inset carries the schematic);
	# kept as a no-op so the retarget call sites stay simple.
	await get_tree().create_timer(1.4).timeout
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
var _print: PrintFlow

func bind_print(pf: PrintFlow) -> void:
	_print = pf

func setup(table: Node3D, first_model: Node3D, panel: Node3D, hud: Node, voice: VoiceLink) -> void:
	_table = table
	_panel = panel
	_hud = hud
	_voice = voice
	add_to_group("cad_bench")
	_active = first_model
	_bench.append(first_model)
	_watch(first_model)
	restore_world()
	voice.cad_job.connect(_on_job)
	voice.cad_done.connect(_on_done)
	voice.cad_failed.connect(_on_failed)

func _log(msg: String) -> void:
	print("[CAD] t+%dms %s" % [Time.get_ticks_msec(), msg])

## Round 2 (R2-7): the hub job carries a real stage — narrate it instead
## of one blanket BUILDING for the whole wait.
const STAGE_LABELS := {
	"queued": "QUEUED", "writing": "WRITING", "repairing": "REPAIRING",
	"building": "BUILDING", "fetching": "FETCHING", "saving": "SAVING",
}

func _stage_status(stage: String) -> String:
	var label: String = STAGE_LABELS.get(stage, "BUILDING")
	return "%s %d s" % [label, int(Time.get_ticks_msec() / 1000.0 - _t_job)]

func _on_job(job_id: String, _ack: String) -> void:
	_t_job = Time.get_ticks_msec() / 1000.0
	status = "QUEUED 0 s"
	_log("job %s accepted - following it" % job_id)
	_poll(job_id)

func _on_failed(job_id: String, detail: String) -> void:
	if _handled.has(job_id):
		return
	_handled[job_id] = true
	Sfx.play(self, "error")
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
	var parent := String(info.get("parent", "")) if String(info.get("kind", "")) == "edit" else ""
	await spawn(glb, info["manifest"], job_id, parent, info.get("print_estimate", {}))
	var td := Time.get_time_dict_from_system()
	_last_job_stamp = "%02d:%02d" % [int(td["hour"]), int(td["minute"])]
	_refresh_station()
	if _presence:
		_presence.celebrate()

## Polls the job so completion is caught even if the socket dropped (or the hub is reached by LAN only for REST).
func _poll(job_id: String) -> void:
	var t_end := Time.get_ticks_msec() / 1000.0 + POLL_MAX_SECONDS
	while Time.get_ticks_msec() / 1000.0 < t_end and not _handled.has(job_id):
		await get_tree().create_timer(POLL_SECONDS).timeout
		if _handled.has(job_id):
			return
		var info := await _get_json("/atlas/cad-job/%s" % job_id)
		if not info.is_empty():
			status = _stage_status(String(info.get("stage", "")))
		match String(info.get("status", "")):
			"done":
				_on_done(job_id)
				return
			"failed":
				_on_failed(job_id, String(info.get("error", "")))
				return

# ---------------------------------------------------------------- Round 2.5: Parts Library (brief #18)
## The library lives on Athena, served by the hub (/atlas/library). Loading an entry first makes it a
## hub job, then the normal _on_done path downloads and spawns it — arrival speech, bench rules and the
## print/edit targeting all come along for free (the hub points follow-up edits at the loaded job).

func fetch_library() -> Array:
	var info := await _get_json("/atlas/library")
	var entries: Variant = info.get("entries", [])
	var arr: Array = entries if entries is Array else []
	_lib_count = arr.size()
	_lib_recent.clear()
	for e in arr.slice(0, 2):
		if e is Dictionary:
			var d: Array = e.get("dims_in", [])
			_lib_recent.append("%s — %s" % [String(e.get("name", "PART")).to_upper(), dims_line(d)])
	_refresh_station()
	return arr

func load_library(entry: Dictionary) -> void:
	var eid := String(entry.get("id", ""))
	if eid == "":
		return
	status = "FETCHING FROM LIBRARY"
	var res := await Hub.post_json(self, "/atlas/library/%s/load" % eid.uri_encode(), {})
	if not bool(res.get("ok", false)):
		status = ""
		_log("library load failed for %s: %s" % [eid, res.get("body", {})])
		_voice.say("I couldn't fetch that one from the library. The hub didn't answer cleanly.")
		return
	var job_id := String((res.get("body", {}) as Dictionary).get("job_id", ""))
	if job_id == "":
		status = ""
		return
	_handled.erase(job_id)   # re-fetching a part already spawned this session must spawn it again
	_on_done(job_id)

func delete_library(entry: Dictionary) -> bool:
	var eid := String(entry.get("id", ""))
	if eid == "":
		return false
	var res := await Hub.post_json(self, "/atlas/library/%s/delete" % eid.uri_encode(), {"confirmed": true})
	return bool(res.get("ok", false))

## Builds the model from downloaded bytes and runs the arrival: park the old one, speak, materialize, retarget.
func spawn(glb: PackedByteArray, manifest: Dictionary, job_id := "", parent_job := "", estimate := {}) -> Node3D:
	var old := find_by_job(parent_job)       # a revision replaces its parent's model; null = a fresh design
	var m: Node3D = Node3D.new()
	m.set_script(CadModelScript)
	m.name = "CadModel%d" % (_bench.size())
	m.call("setup", glb, manifest)
	m.set("job_id", job_id)
	m.set("print_estimate", estimate)
	m.position = old.position if old else (_active.position if _active else Vector3(0, 0.951, 0))
	_table.add_child(m)                      # _ready builds parts + schematic + tethers (hidden)
	if not m.get("load_ok"):
		m.queue_free()
		status = ""
		_voice.say("The part came back, but I couldn't read it. Let's try that again.")
		return null
	if job_id != "":
		_cache_job(job_id, glb, manifest)
	m.call("hide_all")
	if old:
		return await _replace_in_place(old, m, manifest)
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
	Sfx.play(self, "materialize")
	await m.materialize()
	_log("materialize complete")
	for h in get_tree().get_nodes_in_group("holodeck_hands"):
		if h.has_method("buzz"):
			h.buzz(0.06, 0.3)  # R2-1: materialize-complete pulse, both hands
	spawned.emit(m)
	await _voice.say("Take a look. You can grab it, or pull it apart from the panel. Nothing goes to the printer without your confirmation.")
	status = ""
	return m

## The bench model that was built from `job_id` (null when none, e.g. the demo bracket or a trimmed model).
func find_by_job(job_id: String) -> Node3D:
	if job_id == "":
		return null
	for b in _bench:
		if is_instance_valid(b) and String(b.get("job_id")) == job_id:
			return b
	return null

## R1-4: the revised model takes the old one's bench slot, transform (position, orientation, scale; TRUE SIZE stays true
## size) and parked/active role. The old model is freed (no second copy on the table); the arrival is the usual scan.
func _replace_in_place(old: Node3D, m: Node3D, manifest: Dictionary) -> Node3D:
	var was_parked: bool = old.call("is_parked")
	var keep_true := absf(old.scale.x * float(old.get("display_scale")) - 1.0) < 0.01 and absf(float(old.get("display_scale")) - 1.0) > 0.01
	m.position = old.position
	m.quaternion = old.quaternion
	m.scale = (Vector3.ONE / float(m.get("display_scale"))) if keep_true else old.scale
	var slot := _bench.find(old)
	var was_active := old == _active
	old.call("_cancel_motion")
	old.call("clear_highlight")
	_bench[slot] = m
	_watch(m)
	if was_active:
		_active = m
	old.queue_free()
	if was_active:
		_retarget(m)
	status = "READY"
	var name_text := String(manifest.get("name", "part"))
	var line := "Updated. %s is now %s." % [name_text, m.call("spoken_dims")]
	_log("replaced %s in place with '%s' (%s, parked=%s)" % [old.name, name_text, m.call("spoken_dims"), was_parked])
	_voice.say(line)
	m.labels_beat.connect(_on_labels_beat.bind(m), CONNECT_ONE_SHOT)
	await m.materialize()
	if was_parked:
		m.call("park", m.position, m.scale.x)
	spawned.emit(m)
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
	Ease.fd(tw.tween_method(_table.set_readout_alpha, 0.0, 1.0, 0.2))
	Ease.fd(tw.tween_method(m.set_tether_alpha, 0.0, 1.0, 0.3))

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
	if _print:
		_print.model_changed()               # an open send-to-print confirmation named the part that was just replaced
	_panel.call("set_model", m)
	_hud.call("set_model", m)
	_table.call("set_parts", m.part_names().size())
	_table.call("set_dims", m.dims_text())
	_table.call("follow_model", m)
	_refresh_station()
	_push_schematic_later(m)

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

# ---------------------------------------------------------------- Round 5B: solidify + persistence
## Carry the active model beyond the table's edge and it SOLIDIFIES: same geometry, a
## machined-titanium material, living in the world as a grabbable object that settles onto
## whatever support is under it and PERSISTS (user://world.json + the job's GLB cached at
## spawn, so restore works with the hub offline). Carry it back over a free table and it
## returns to hologram + bench duty. One world solid at a time (v1 scope).

const WORLD_PATH := "user://world.json"
const CACHE_DIR := "user://world_cache"
var _solid: Node3D = null
static var _solid_mat: StandardMaterial3D = null

static func solid_material() -> StandardMaterial3D:
	if _solid_mat == null:
		_solid_mat = StandardMaterial3D.new()
		_solid_mat.albedo_color = Color(0.6, 0.63, 0.67)
		_solid_mat.metallic = 0.85
		_solid_mat.roughness = 0.38
	return _solid_mat

func _process(dt: float) -> void:
	if _solid == null and _active != null and is_instance_valid(_active) \
			and _active.get_script() == CadModelScript and bool(_active.call("is_held")):
		if _beyond_table(_active, 0.18):
			_solidify(_active)
	if _solid != null and is_instance_valid(_solid):
		if bool(_solid.call("is_held")):
			if _active == null and _within_table(_solid, -0.04) and _solid.global_position.y < 1.85:
				_unsolidify(_solid)
		else:
			var sup := Prop.support_height(_solid.global_position)
			if _solid.global_position.y > sup + 0.004:
				_solid.global_position.y = lerpf(_solid.global_position.y, sup, clampf(dt * 7.0, 0.0, 1.0))
				if _solid.global_position.y <= sup + 0.02:
					_solid.global_position.y = sup
					_save_world()

func _table_rect(ext: float) -> Rect2:
	var c := _table.global_position
	return Rect2(c.x - 1.35 - ext, c.z - 0.72 - ext, 2.7 + ext * 2.0, 1.44 + ext * 2.0)

func _centre_xz(m: Node3D) -> Vector2:
	var c: Vector3 = m.global_transform * (m.get("center_local") as Vector3)
	return Vector2(c.x, c.z)

func _beyond_table(m: Node3D, ext: float) -> bool:
	return not _table_rect(ext).has_point(_centre_xz(m))

func _within_table(m: Node3D, ext: float) -> bool:
	return _table_rect(ext).has_point(_centre_xz(m))

func _solidify(m: Node3D) -> void:
	m.call("set_explode", 0.0)
	_bench.erase(m)
	if _active == m:
		_active = null
	m.reparent(get_parent(), true)
	for p in (m.get("_parts") as Array):
		(p as MeshInstance3D).material_override = solid_material()
	m.set("world_solid", true)
	_solid = m
	Sfx.play(self, "materialize")
	_log("solidified '%s' — it lives in the world now" % String(m.get("model_name")))
	_save_world()
	_refresh_station()

func _unsolidify(m: Node3D) -> void:
	m.reparent(_table, true)
	for p in (m.get("_parts") as Array):
		(p as MeshInstance3D).material_override = m.call("_make_material", p)
	m.set("world_solid", false)
	_solid = null
	_bench.append(m)
	if not m.is_connected("flicked_aside", _on_flicked):
		_watch(m)
	_active = m
	_retarget(m)
	Sfx.play(self, "materialize")
	_log("'%s' is back on the table as a hologram" % String(m.get("model_name")))
	_save_world()
	_refresh_station()

func _cache_job(job_id: String, glb: PackedByteArray, manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(CACHE_DIR + "/" + job_id + ".glb", FileAccess.WRITE)
	if f:
		f.store_buffer(glb)
	var g := FileAccess.open(CACHE_DIR + "/" + job_id + ".json", FileAccess.WRITE)
	if g:
		g.store_string(JSON.stringify(manifest))

func _save_world() -> void:
	var objs: Array = []
	if _solid != null and is_instance_valid(_solid):
		var p := _solid.global_position
		var r := _solid.global_rotation
		objs.append({"job_id": String(_solid.get("job_id")), "name": String(_solid.get("model_name")),
			"pos": [p.x, p.y, p.z], "rot": [r.x, r.y, r.z], "scale": _solid.scale.x})
	var f := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "objects": objs}))

func restore_world() -> void:
	if not FileAccess.file_exists(WORLD_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry in (parsed as Dictionary).get("objects", []):
		var jid := String((entry as Dictionary).get("job_id", ""))
		var glb_path := CACHE_DIR + "/" + jid + ".glb"
		var man_path := CACHE_DIR + "/" + jid + ".json"
		if jid == "" or not FileAccess.file_exists(glb_path) or not FileAccess.file_exists(man_path):
			continue
		var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(man_path))
		if typeof(man) != TYPE_DICTIONARY:
			continue
		var m: Node3D = Node3D.new()
		m.set_script(CadModelScript)
		m.name = "WorldModel"
		m.call("setup", FileAccess.get_file_as_bytes(glb_path), man)
		m.set("job_id", jid)
		get_parent().add_child(m)
		if not bool(m.get("load_ok")):
			m.queue_free()
			continue
		var pos: Array = (entry as Dictionary).get("pos", [0, 0, 0])
		var rot: Array = (entry as Dictionary).get("rot", [0, 0, 0])
		m.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		m.global_rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
		m.scale = Vector3.ONE * float((entry as Dictionary).get("scale", 1.0))
		for p in (m.get("_parts") as Array):
			(p as MeshInstance3D).material_override = solid_material()
		m.set("world_solid", true)
		_solid = m
		_log("restored world object '%s' from the headset cache" % String(m.get("model_name")))
