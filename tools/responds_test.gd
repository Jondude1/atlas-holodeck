extends SceneTree
## R7-4 everything-responds proof (NOT shipped): the orb drifts to a visit point
## and returns home; a downward tabletop tap fires the pulse, a hover does not.
## Run: godot --headless --path app --script ../tools/responds_test.gd
var _fails := 0

func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok: ", what)
	else:
		_fails += 1
		print("  FAIL: ", what)

func _initialize() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if main.has_method("_skip_boot"):
		main.call("_skip_boot")
	await process_frame
	var presence: Node = main.get_node("Room").presence()
	_check(presence != null, "presence present")
	var home: Vector3 = presence.position
	var target := home + Vector3(0.55, 0.02, 0.3)
	presence.drift_visit(target, 30.0)
	var d0: float = presence.position.distance_to(target)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2200:
		await process_frame
	var d1: float = presence.position.distance_to(target)
	_check(d1 < d0 * 0.45, "orb drifted most of the way to the visit point (%.2f -> %.2f)" % [d0, d1])
	presence.drift_visit(target, 0.01)   # hold already spent: it should head home
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 900:
		await process_frame
	_check(presence.position.distance_to(home) < d1 + 0.2, "orb eases back toward its post")

	var table: Node = main.get_node("HoloTable")
	var surf := 0.951
	_check(not table.tap_at(Vector3(0, surf + 0.03, -1.55), Vector3(0, surf + 0.02, -1.55)), "hover inside the band is not a tap")
	_check(table.tap_at(Vector3(0, surf + 0.09, -1.55), Vector3(0, surf + 0.03, -1.55)), "downward crossing knocks")
	_check(float(table.get("_pulse_t")) < 0.5, "tap pulse lit (t=%.2f)" % float(table.get("_pulse_t")))
	_check(not table.tap_at(Vector3(3.5, surf + 0.09, -1.55), Vector3(3.5, surf + 0.03, -1.55)), "off the table is not a tap")
	print("RESPONDS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
