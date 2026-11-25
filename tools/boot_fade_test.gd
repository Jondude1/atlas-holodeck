extends SceneTree
## Boot cascade test (NOT shipped) — P5 iterate round 5. Asserts boot_phases
## endpoints are exact, phases are monotonic and ordered room > table > hud
## mid-boot, and that _set_fade actually drives room/hud fades + the table
## key light from those phases; _skip_boot lands everything at exactly 1.
## Run: godot --headless --path app --script ../tools/boot_fade_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _run() -> void:
	var script: GDScript = load("res://main.gd")
	var p0: Vector3 = script.boot_phases(0.0)
	var p1: Vector3 = script.boot_phases(1.0)
	_check(p0 == Vector3.ZERO, "phases(0) all zero")
	_check(p1 == Vector3.ONE, "phases(1) all one (skip/rest state unchanged)")
	var mono := true
	var prev := Vector3.ZERO
	for i in range(1, 21):
		var p: Vector3 = script.boot_phases(float(i) / 20.0)
		if p.x < prev.x - 0.0001 or p.y < prev.y - 0.0001 or p.z < prev.z - 0.0001:
			mono = false
		prev = p
	_check(mono, "phases monotonic over v in [0,1]")
	var pm: Vector3 = script.boot_phases(0.4)
	_check(pm.x > pm.y and pm.y > 0.0 and pm.z == 0.0,
			"mid-boot ordering room(%.2f) > table(%.2f) > hud(%.2f)" % [pm.x, pm.y, pm.z])

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_set_fade", 0.5)
	var ph: Vector3 = script.boot_phases(0.5)
	var room: Node = main.get_node("Room")
	var hud: Node = main.get_node("Hud")
	var table: Node = main.get_node("HoloTable")
	_check(absf(float(room.get("_fade")) - ph.x) < 0.001, "room fade follows room phase")
	_check(absf(float(hud.get("_fade")) - ph.z) < 0.001, "hud fade follows hud phase")
	var key: Light3D = (table.call("mood_lights") as Array)[0]
	_check(absf(key.light_energy - 1.85 * ph.y) < 0.01, "table key light follows table phase (%.3f)" % key.light_energy)
	main.call("_skip_boot")
	_check(absf(float(room.get("_fade")) - 1.0) < 0.001 and absf(float(hud.get("_fade")) - 1.0) < 0.001,
			"skip lands room+hud at exactly 1")
	_check(absf(key.light_energy - 1.85) < 0.01, "skip lands key light at full energy")
	print("BOOT_FADE_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
