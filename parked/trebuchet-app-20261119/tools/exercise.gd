extends SceneTree
## Headless state-machine exercise (NOT part of the shipped app). Boots the real main scene,
## waits for the trebuchet to materialize, then drives the controller by hand with fixed
## timesteps (auto_tick off): cock -> fire -> reset, weight changes, guard checks, and landing
## distances for every block count.
## Run: godot --headless --path app --script res://../tools/exercise.gd   (abs path to this file)

var _main: Node
var _t: Node
var _fails := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_t = _main.get_node("HoloTable/Trebuchet")
	_run()

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1

func _sim(seconds: float, dt := 1.0 / 120.0) -> void:
	var n := int(seconds / dt)
	for i in n:
		_t.advance(dt)

func _until(state: int, limit := 6.0) -> float:
	var t := 0.0
	while _t.state != state and t < limit:
		_t.advance(1.0 / 120.0)
		t += 1.0 / 120.0
	return t

func _sname(s: int) -> String:
	return ["REST", "COCKING", "COCKED", "FIRING", "SETTLING", "RESETTING"][s]

func _run() -> void:
	await _t.materialized
	print("exercise: materialized (parts=%d, scale=%.3f, %s)" % [_t.part_names().size(), _t.scale.x, _t.scale_text(_t.true_dims())])
	_t.auto_tick = false
	if OS.get_environment("REL") != "":
		_t.release_angle_deg = float(OS.get_environment("REL"))
		print("release_angle_deg override = ", _t.release_angle_deg)
	var seen: Array[String] = []
	_t.state_changed.connect(func(s: int) -> void: seen.append(_sname(s)))
	_check(_t.state == 0, "starts in REST")
	_check(not _t.fire(), "FIRE refused in REST")
	_check(_t.weight_text().begins_with("WEIGHT — 4 BLOCKS · "), "weight readout: " + _t.weight_text())
	_check(_t.cock(), "COCK accepted in REST")
	_check(not _t.cock(), "COCK refused while cocking")
	var tc := _until(2)  # COCKED
	_check(_t.state == 2, "COCKING -> COCKED in %.2fs" % tc)
	_check(_t.weight_up() and _t.blocks == 5, "WT+ in COCKED -> 5 blocks")
	_check(_t.weight_down() and _t.blocks == 4, "WT- in COCKED -> 4 blocks")
	_sim(0.6)
	_check(_t.fire(), "FIRE accepted in COCKED")
	_check(not _t.weight_up(), "WT+ refused while FIRING")
	_check(_t.is_busy(), "explode/scale locked while firing")
	var tf := _until(4)  # SETTLING
	_check(_t.state == 4, "FIRING -> SETTLING at %.2fs (release)" % tf)
	var tr := _until(0, 4)
	_check(_t.state == 0, "SETTLING -> REST after %.2fs more" % tr)
	_check(not _t.is_busy(), "controls unlocked in REST")
	print("transitions: ", " > ".join(seen))
	_check(_t.cock(), "re-COCK straight after a shot (stone fades back in)")
	_until(2)
	_check(_t.reset(), "RESET accepted in COCKED")
	_until(0, 4)
	_check(_t.state == 0, "RESETTING -> REST")
	_t.explode_probe()
	print("")
	print("LANDINGS (distance release -> first touchdown, world metres; default tuning)")
	print("blocks  v0 m/s  elev(raw)  release_x  landing m   landing x on table")
	for n in range(1, 7):
		while _t.blocks != n:
			if _t.blocks < n: _t.weight_up()
			else: _t.weight_down()
		_t.cock(); _until(2); _sim(0.3)
		_t.fire(); _until(4); _sim(2.5)
		print("%d       %.2f     %.1f(%.1f)   %.3f      %.3f       %.3f" % [n, _t.last_launch_speed, _t.last_launch_elev_deg, _t.last_raw_elev_deg,
				_t.last_release_world.x - _main.get_node("HoloTable").global_position.x, _t.last_landing_m,
				_t.last_release_world.x - _main.get_node("HoloTable").global_position.x + _t.last_landing_m])
		_until(0, 4)
	print("EXERCISE %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(0 if _fails == 0 else 1)
