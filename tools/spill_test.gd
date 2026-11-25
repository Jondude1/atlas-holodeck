extends SceneTree
## Round 3 / P3 proof (NOT shipped): VistaSpill follows vista + grade swaps.
## Boots the scene, reads the Lab's VistaSpill material after each swap
## (waiting out the 0.6 s mood tween), and asserts:
##   coast/day == the old static tint (0.82, 0.87, 0.93, 0.10) — unchanged
##   lake/day  == dimmer, deeper blue; valley/day == warm (r > b)
##   coast/dusk == alpha scaled by the grade (0.45x) and colour shifted
## Run: godot --headless --path app --script ../tools/spill_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print("SPILL ", "PASS " if cond else "FAIL ", label)
	if not cond:
		_fails += 1

func _close(a: Color, b: Color, tol := 0.02) -> bool:
	return absf(a.r - b.r) < tol and absf(a.g - b.g) < tol and absf(a.b - b.b) < tol and absf(a.a - b.a) < tol

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var deck: Node = main.get_node("VistaDeck")
	var spill_node: Node = main.get_node("Room/Lab/VistaSpill")
	_check(spill_node != null, "VistaSpill node exists")
	var mat := (spill_node as MeshInstance3D).material_override as StandardMaterial3D
	_check(mat != null, "VistaSpill material present")
	# boot bind snaps (dur 0): coast/day must equal the pre-P3 static tint
	_check(_close(mat.albedo_color, Color(0.82, 0.87, 0.93, 0.10)), "coast/day == old static tint %s" % mat.albedo_color)
	_check(_close(mat.albedo_color, deck.call("spill_target")), "coast/day == spill_target()")
	deck.call("show_vista", "lake")
	await create_timer(1.0).timeout
	_check(_close(mat.albedo_color, Color(0.50, 0.62, 0.82, 0.065)), "lake/day tint %s" % mat.albedo_color)
	_check(mat.albedo_color.b > mat.albedo_color.r + 0.2 and mat.albedo_color.a < 0.08, "lake is deep blue + dimmer than coast")
	deck.call("show_vista", "valley")
	await create_timer(1.0).timeout
	_check(_close(mat.albedo_color, Color(0.95, 0.85, 0.64, 0.11)), "valley/day tint %s" % mat.albedo_color)
	_check(mat.albedo_color.r > mat.albedo_color.b + 0.2, "valley is warm (r >> b)")
	deck.call("show_vista", "coast")
	await create_timer(1.0).timeout
	deck.call("cycle_grade")   # day -> golden
	deck.call("cycle_grade")   # golden -> dusk
	await create_timer(1.0).timeout
	_check(String(deck.call("grade")) == "dusk", "grade is dusk")
	_check(absf(mat.albedo_color.a - 0.045) < 0.01, "coast/dusk alpha ~0.045 (0.10 x 0.45) got %f" % mat.albedo_color.a)
	_check(mat.albedo_color.b > mat.albedo_color.r, "coast/dusk colour shifted blue-purple %s" % mat.albedo_color)
	print("SPILL_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(_fails)
