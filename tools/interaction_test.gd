extends SceneTree
## Headless proof for Round 1A (NOT shipped). Drives the real main scene with fake hands (plain Node3Ds) and steps the
## model's own motion code with a fixed dt, so every number is deterministic. Prints "T " lines + INTERACTION_TEST.
## Headset-only: how any of this FEELS (grip pressure, hand tracking jitter, tuning of friction/flick thresholds).
## Run: godot --headless --path app --script ../tools/interaction_test.gd
const DT := 1.0 / 72.0
const SLIDE_K := 3.2
var fails := 0
var main: Node
var table: Node3D
var bracket: Node3D
var treb: Node3D
var bench: CadBench
var panel: Node
var voice: VoiceLink
var hand: Node3D

func ck(label: String, ok: bool, detail := "") -> void:
	print("T %s %s %s" % ["ok  " if ok else "FAIL", label, detail])
	if not ok:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await process_frame

func secs(s: float) -> void:
	await create_timer(s).timeout

func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _tl(n: Node3D) -> Vector3:   # table-space position
	return table.to_local(n.global_position)

func _drag(m: Node3D, from: Vector3, delta: Vector3, secs_: float, yaw_rate := 0.0) -> void:
	hand.global_position = from
	hand.global_rotation = Vector3.ZERO
	m.set_process(false)
	m.call("begin_grab", hand)
	m.set_process(false)
	var n := int(secs_ / DT)
	for i in n:
		hand.global_position += delta / n
		hand.global_rotation.y += yaw_rate * DT
		m.call("step", DT)

func _release(m: Node3D) -> void:
	m.call("end_grab", hand)
	m.set_process(false)

func _run() -> void:
	await frames(3)
	table = main.get_node("HoloTable")
	bracket = main.get_node("HoloTable/TestBracket")
	panel = main.get_node("UIPanel")
	voice = main.get_node("Voice")
	bench = main.get_node("CadBench")
	hand = Node3D.new()
	root.add_child(hand)
	bracket.call("hide_all")   # nothing here needs the boot / materialize beats
	bracket.call("_set_state", true, 1.2, 0.0, 1.0)
	bracket.call("unpark")
	table.scale = Vector3.ONE    # the boot fade scales the table 0.94 -> 1; measure at rest scale
	var top := HoloTable.TOP_Y
	var m := bracket

	# ---- R1-1 table-plane drag + settle ---------------------------------------------------------------
	m.position = Vector3(0, top, 0)
	_drag(m, table.to_global(Vector3(0, top + 0.05, 0)), Vector3(0.5, 0.04, 0.2), 0.5)
	var p := _tl(m)
	ck("R1-1 plane drag follows the hand across the surface", absf(p.x - 0.5) < 0.01 and absf(p.z - 0.2) < 0.01, "x=%.3f z=%.3f" % [p.x, p.z])
	ck("R1-1 ...and stays at table height while the hand wanders up 4 cm", absf(p.y - top) < 1e-4, "y=%.4f (top %.4f)" % [p.y, top])
	ck("R1-1 mode is PLANE", m.get("mode") == m.Mode.PLANE)
	# lift the hand clear of the surface -> freehand
	hand.global_position += Vector3(0, 0.25, 0)
	hand.global_rotation.x = deg_to_rad(30)
	m.call("step", DT)
	ck("R1-1 lifting the hand 25 cm hands over to freehand (model leaves the surface)", m.get("mode") == m.Mode.FREE and _tl(m).y > top + 0.1, "mode=%d y=%.3f" % [m.get("mode"), _tl(m).y])
	# release over the table, up in the air and tilted -> settles
	_release(m)
	ck("R1-1 release over the table starts SETTLE", m.get("mode") == m.Mode.SETTLE)
	for i in 40:
		m.call("step", DT)
	var tilt: float = absf((m.basis.orthonormalized() * Vector3.UP).angle_to(Vector3.UP))
	ck("R1-1 settles back to table height", absf(_tl(m).y - top) < 1e-3, "y=%.4f" % _tl(m).y)
	ck("R1-1 ...and levels out (tilt %.2f deg)" % rad_to_deg(tilt), tilt < 0.01)
	ck("R1-1 ...keeping its xz where it was released", absf(_tl(m).x - p.x) < 0.01, "x=%.3f" % _tl(m).x)
	# release OFF the table stays freehand
	m.position = Vector3(0, top, 0)
	_drag(m, table.to_global(Vector3(0, top + 0.05, 0)), Vector3(0, 0.3, 0), 0.3)   # lift
	hand.global_position += table.global_basis * Vector3(1.9, 0, 0)               # carry well past the table end
	m.call("step", DT)
	var off := _tl(m)
	_release(m)
	for i in 30:
		m.call("step", DT)
	ck("R1-1 released off-table it stays freehand (no settle)", absf(_tl(m).y - off.y) < 1e-4 and m.get("mode") == m.Mode.IDLE, "y=%.3f x=%.2f" % [_tl(m).y, _tl(m).x])

	# ---- R1-2 inertia: flick + spin -------------------------------------------------------------------
	var flicked: Array = []
	m.connect("flicked_aside", func(mm): flicked.append(mm))
	m.position = Vector3(0, top, 0)
	m.rotation = Vector3.ZERO
	m.call("unpark")
	m.scale = Vector3.ONE
	_drag(m, table.to_global(Vector3(0, top + 0.05, 0)), Vector3(0.3, 0, 0), 0.3)   # 1.0 m/s
	var x_at_release := _tl(m).x
	_release(m)
	ck("R1-2 release at speed enters COAST (flick)", m.get("mode") == m.Mode.COAST, "mode=%d" % m.get("mode"))
	var speeds: Array[float] = []
	var last := Vector2(_tl(m).x, _tl(m).z)
	var steps := 0
	while m.get("mode") == m.Mode.COAST and steps < 2000:
		m.call("step", DT)
		var cur := Vector2(_tl(m).x, _tl(m).z)
		speeds.append((cur - last).length() / DT)
		last = cur
		steps += 1
	var slid := _tl(m).x - x_at_release
	var mono := true
	var max_jump := 0.0
	for i in range(1, speeds.size()):
		if speeds[i] > speeds[i - 1] + 1e-4:
			mono = false
		if speeds[i - 1] > 0.05:
			max_jump = maxf(max_jump, absf(speeds[i] / speeds[i - 1] - exp(-SLIDE_K * DT)))
	ck("R1-2 flick carries on after release (slid %.2f m in %.2f s)" % [slid, steps * DT], slid > 0.15 and steps * DT > 0.5)
	ck("R1-2 speed decays monotonically and smoothly (max frame-to-frame deviation from exp %.4f)" % max_jump, mono and max_jump < 0.02)
	ck("R1-2 stays inside the inset", absf(_tl(m).x) <= HoloTable.PLANE_HALF.x + 1e-4)
	ck("R1-2 flick that rests away from the centre emitted flicked_aside", flicked.size() == 1, "x=%.2f" % _tl(m).x)
	bench.call("_on_flicked", m)
	ck("R1-2 ...and the bench parks it (small, aside)", m.call("is_parked"))
	await secs(1.0)
	ck("R1-2 parked scale arrives (0.55)", absf(m.scale.x - 0.55) < 0.02, "scale=%.2f" % m.scale.x)
	# spin
	m.call("unpark")
	m.scale = Vector3.ONE
	m.position = Vector3(0, top, 0)
	m.rotation = Vector3.ZERO
	_drag(m, table.to_global(Vector3(0, top + 0.05, 0)), Vector3(0.0, 0, 0), 0.4, 4.0)   # twist 4 rad/s
	var yaw0: float = m.rotation.y
	_release(m)
	ck("R1-2 twist release enters COAST as spin only (no slide)", m.get("mode") == m.Mode.COAST and flicked.size() == 1)
	var pos0 := _tl(m)
	var w_prev := 99.0
	var spin_smooth := true
	var prev_y: float = m.rotation.y
	var n := 0
	while m.get("mode") == m.Mode.COAST and n < 2000:
		m.call("step", DT)
		var w := absf(wrapf(m.rotation.y - prev_y, -PI, PI)) / DT
		prev_y = m.rotation.y
		if w > w_prev + 1e-3:
			spin_smooth = false
		w_prev = w
		n += 1
	ck("R1-2 spin keeps turning after release then decays smoothly to a stop (%.2f s, +%.0f deg)" % [n * DT, rad_to_deg(wrapf(m.rotation.y - yaw0, -TAU, TAU))],
			n * DT > 0.4 and spin_smooth and (_tl(m) - pos0).length() < 1e-4)

	# ---- R1-3 reset + true scale + scale buttons --------------------------------------------------------
	m.position = Vector3(0.6, top, 0.3)
	m.scale = Vector3.ONE * 2.0
	m.rotation = Vector3(0.0, 1.2, 0.0)
	m.call("set_explode", 0.7)
	bench.call("reset_active")
	await secs(1.0)
	ck("R1-3 RESET MODEL returns the active model to centre", _tl(m).distance_to(Vector3(0, top, 0)) < 0.01, "pos=%s" % _tl(m))
	ck("R1-3 ...upright, display scale, assembled", absf(m.scale.x - 1.0) < 0.01 and absf(m.rotation.y) < 0.01 and m.get("explode_value") == 0.0)
	# panel buttons: names + presence
	var names: Array[String] = []
	_collect_buttons(panel.get_node("SubViewport"), names)
	ck("R1-3 panel has RESET MODEL, FIX FLOOR HEIGHT, TRUE SIZE and 0.5×/1×/2×; no bare RESET FLOOR", \
			"RESET MODEL" in names and "FIX FLOOR HEIGHT" in names and "TRUE SIZE" in names and "0.5×" in names and "2.0×" in names and not ("RESET FLOOR" in names), str(names))

	# ---- CAD model (27 parts) through the real spawn path -----------------------------------------------
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	var glb := FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb"))
	var said: Array[String] = []
	voice.said.connect(func(t): said.append(t))
	bench.spawn(glb, man)          # not awaited: materialize + speech run on their own
	await secs(0.5)
	treb = bench.active_model()
	ck("spawned the 27-part trebuchet; bracket parked", treb != null and treb != bracket and bracket.call("is_parked"), "parts=%d" % treb.call("part_names").size())
	await secs(2.6)
	# true scale
	treb.call("set_model_scale", 1.0)
	await secs(0.4)
	treb.call("set_true_scale")
	await secs(0.5)
	var ds: float = treb.get("display_scale")
	var true_x: float = (treb.get("_bounds") as AABB).size.x * treb.scale.x / ds / 0.0254
	var want_x: float = man["true_dims_in"][0]
	ck("R1-3 TRUE SIZE shows the part at its real size (%.2f in vs manifest %.2f in, display_scale %.2f)" % [true_x * ds, want_x, ds],
			absf(treb.scale.x - 1.0 / ds) < 0.01 and absf(true_x * ds - want_x) / want_x < 0.05 or absf(treb.scale.x * (treb.get("_bounds") as AABB).size.x / ds / 0.0254 - want_x) / want_x < 0.05,
			"scale=%.3f label=%s" % [treb.scale.x, treb.call("scale_label")])
	treb.call("set_model_scale", 1.0)
	await secs(0.4)

	# ---- R1-6 part list + overflow with 27 parts ------------------------------------------------------
	var vp: SubViewport = panel.get_node("SubViewport")
	var content: Control = vp.get_child(0)
	await frames(3)
	var rows := _count_named(vp, "Part")
	ck("R1-6 part list has one row per part (27)", rows == 27, "rows=%d" % rows)
	var need := content.get_combined_minimum_size()
	ck("R1-6 panel content fits the viewport with 27 parts (%d of %d px)" % [need.y, vp.size.y], need.y <= vp.size.y)
	var sc: ScrollContainer = panel.get("_parts_scroll")
	var sv0 := sc.scroll_vertical
	panel.call("scroll_parts", 1)
	await frames(2)
	ck("R1-6 list scrolls (scroll_vertical %d -> %d, list height %d in a %d px window)" % [sv0, sc.scroll_vertical, (panel.get("_parts_list") as Control).size.y, sc.size.y], sc.scroll_vertical > sv0)
	var rb: Button = panel.get("_part_buttons")[2]
	rb.button_pressed = true
	await frames(2)
	var hp: MeshInstance3D = treb.call("hot_part")
	ck("R1-6/R1-11 pressing a list row pins that part's highlight + name on the model", hp != null and hp == treb.call("part_node", 2), "hot=%s" % (hp.name if hp else "none"))
	var lab: Label3D = (treb.get("_tethers") as Array)[2]["label"]
	ck("R1-11 ...its name label is raised (core colour, large, visible)", lab.visible and lab.font_size == 56 and lab.modulate.a > 0.99)
	rb.button_pressed = false
	await frames(2)
	ck("R1-6 pressing again clears it", treb.call("hot_part") == null and lab.font_size == 40)

	# ---- R1-11 hover by ray ---------------------------------------------------------------------------
	var target: MeshInstance3D = treb.call("part_node", 5)
	var tc: Vector3 = target.global_transform * target.mesh.get_aabb().get_center()
	var origin := tc + Vector3(0.0, 0.3, 0.9)
	var got: MeshInstance3D = treb.call("pick_part", origin, (tc - origin).normalized())
	ck("R1-11 pointer ray picks the part under it", got != null, "picked=%s want=%s" % [got.name if got else "none", target.name])
	var miss: MeshInstance3D = treb.call("pick_part", origin, Vector3.UP)
	ck("R1-11 a ray into empty space picks nothing", miss == null)
	treb.call("highlight_part", got)
	ck("R1-11 hover highlights then clears (hover only)", treb.call("hot_part") == got)
	treb.call("clear_highlight", true)
	ck("R1-11 hover end clears the highlight", treb.call("hot_part") == null)

	# ---- R1-7 bench select ----------------------------------------------------------------------------
	var tpos: Vector3 = treb.position
	var bpos: Vector3 = bracket.position
	bench.select(bracket)
	await secs(1.0)
	ck("R1-7 select pulls the parked bracket to centre and makes it active", bench.active_model() == bracket and not bracket.call("is_parked")
			and _tl(bracket).distance_to(Vector3(0, top, 0)) < 0.01 and absf(bracket.scale.x - 1.0) < 0.01, "pos=%s" % _tl(bracket))
	ck("R1-7 the model that was on stage parks into the vacated slot", treb.call("is_parked") and _tl(treb).distance_to(bpos) < 0.05, "treb=%s slot=%s" % [_tl(treb), bpos])
	ck("R1-7 panel retargets (3 part rows) and readouts follow", _count_named(vp, "Part") == 3, "rows=%d" % _count_named(vp, "Part"))
	var tw: Node = panel.get("_model")
	ck("R1-7 panel model is the bracket", tw == bracket)
	bench.select(treb)
	await secs(1.0)
	ck("R1-7 round trip: trebuchet back on stage, bracket parked", bench.active_model() == treb and bracket.call("is_parked") and not treb.call("is_parked"))

	# ---- R1-5 spoken failure reason through the bench -------------------------------------------------
	said.clear()
	voice.cad_failed.emit("zzzz1", "failed acceptance after 3 attempts: ValueError: minimum wall thickness 0.4 mm is below the 0.8 mm printable limit")
	await frames(3)
	ck("R1-5 a failed job speaks the hub's actual reason, sanitized", said.size() == 1 and said[0].contains("minimum wall thickness") and not said[0].contains("ValueError"), said[0] if said.size() else "(nothing said)")

	# ---- R1-11 A/X PTT ------------------------------------------------------------------------------
	var lh: XRController3D = main.get_node("XROrigin3D/LeftHand")
	var rh: XRController3D = main.get_node("XROrigin3D/RightHand")
	lh.call("_on_pressed", "ax_button")
	ck("R1-11 X (left) starts push-to-talk", lh.get("_ptt_held") == true and lh.get("_ptt_by_ax") == true)
	lh.call("_on_released", "trigger_click")
	ck("R1-11 ...a stray trigger release does not end an A/X hold", lh.get("_ptt_held") == true)
	lh.call("_on_released", "ax_button")
	ck("R1-11 releasing X ends it", lh.get("_ptt_held") == false)
	rh.call("_on_pressed", "ax_button")
	ck("R1-11 A (right) is also a PTT binding", rh.get("_ptt_held") == true)
	rh.call("_on_released", "ax_button")
	lh.call("_on_pressed", "trigger_click")
	ck("R1-11 left trigger PTT still works", lh.get("_ptt_held") == true and lh.get("_ptt_by_ax") == false)
	lh.call("_on_released", "trigger_click")
	ck("R1-11 ...and releases", lh.get("_ptt_held") == false)

	print("INTERACTION_TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(fails)

func _collect_buttons(n: Node, out: Array[String]) -> void:
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_collect_buttons(c, out)

func _count_named(n: Node, prefix: String) -> int:
	var c := 1 if n is Button and String(n.name).begins_with(prefix) and not n.is_queued_for_deletion() else 0
	for k in n.get_children():
		c += _count_named(k, prefix)
	return c
