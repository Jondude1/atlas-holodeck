extends SceneTree
## Locomotion rig test (NOT shipped) — Round 6 layout: drives LocoRig.apply_move/apply_turn
## with a simulated head offset and asserts the clamping rules: the table blocks, the back
## wall holds outside the opening, the opening is the only way out, the terrace railing
## line holds, and a snap turn pivots on the head.
## Run: godot --headless --path app --script ../tools/rig_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var rig: Node = main.get_node("LocoRig")
	var origin: Node3D = main.get_node("XROrigin3D")
	var cam: Node3D = main.get_node("XROrigin3D/XRCamera3D")
	cam.position = Vector3(0.3, 1.6, 0.2)
	# 1: the table blocks a straight walk into it (head starts south of the table)
	origin.global_position = Vector3(0, 0, 0.2)   # head at (0.3, 0.4)
	for i in 40:
		rig.apply_move(Vector3(0, 0, -0.25))
	var h: Vector2 = rig.head_xz()
	_check(h.y < -0.35 and h.y > -0.75, "table blocks (head z=%.2f)" % h.y)
	# 2: a side wall holds (open floor lane along the entrance end)
	origin.global_position = Vector3(0, 0, 1.6)   # head at (0.3, 1.8)
	for i in 40:
		rig.apply_move(Vector3(0.25, 0, 0))
	h = rig.head_xz()
	_check(h.x >= 3.5 and h.x <= 3.72, "side wall holds (head x=%.2f)" % h.x)
	# 2b: the suit pad guards the opening's flank — walking its lane stops at the pad
	origin.global_position = Vector3(2.6, 0, 0.2)   # head at (2.9, 0.4), the pad's lane
	for i in 40:
		rig.apply_move(Vector3(0, 0, -0.25))
	h = rig.head_xz()
	_check(h.y > -3.25 and h.y < -2.95, "suit pad blocks its lane (head z=%.2f)" % h.y)
	# 3: through the opening (head x = 1.9 — between the table block and the pad's reach)
	#    onto the terrace; the railing line holds
	origin.global_position = Vector3(1.6, 0, 0.2)   # head at (1.9, 0.4)
	for i in 60:
		rig.apply_move(Vector3(0, 0, -0.25))
	h = rig.head_xz()
	_check(h.y < -7.7 and h.y > -8.2, "terrace reached, railing holds (head z=%.2f)" % h.y)
	# 4: snap turn pivots on the head — head world position must not move
	var before: Vector2 = rig.head_xz()
	rig.apply_turn(deg_to_rad(-30.0))
	var after: Vector2 = rig.head_xz()
	_check(before.distance_to(after) < 0.01, "turn pivots on the head (moved %.3f m)" % before.distance_to(after))
	_check(absf(rad_to_deg(origin.rotation.y) + 30.0) < 0.5 or absf(rad_to_deg(origin.rotation.y) - 330.0) < 0.5, "origin yaw = -30 (got %.1f)" % rad_to_deg(origin.rotation.y))
	print("RIG_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
