extends SceneTree
## Locomotion rig test (NOT shipped): drives LocoRig.apply_move/apply_turn directly with a
## simulated head offset and asserts the clamping rules — walls hold, the doorway is the
## only way out, the terrace railing line holds, the table blocks, and a snap turn pivots
## on the head. Run: godot --headless --path app --script ../tools/rig_test.gd
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
	# simulate a roomscale head offset: the head stands 0.3 right, 0.2 toward the table
	origin.global_position = Vector3.ZERO
	cam.position = Vector3(0.3, 1.6, 0.2)
	await process_frame
	var head0: Vector2 = rig.head_xz()
	_check(head0.distance_to(Vector2(0.3, 0.2)) < 0.01, "head offset tracked (got %s)" % head0)
	# 1: walking -x from the middle of the room must stop at the wall (x >= -3.72 area edge
	#    is only crossable inside the doorway z band; head z = 0.2 IS in the band, so use a
	#    z outside the band for the wall test first: teleport the origin so head z = 2.4)
	origin.global_position = Vector3(0, 0, 2.2)   # head z = 2.4, outside the doorway band
	for i in 40:
		rig.apply_move(Vector3(-0.25, 0, 0))
	var h: Vector2 = rig.head_xz()
	_check(h.x > -3.85 and h.x < -3.5, "wall holds outside the doorway (head x=%.2f)" % h.x)
	# 2: through the doorway (head z in band) onto the terrace, railing line holds
	origin.global_position = Vector3(-0.3, 0, -0.2)  # head back at (0, 0)
	cam.position = Vector3(0.3, 1.6, 0.2)
	for i in 60:
		rig.apply_move(Vector3(-0.25, 0, 0))
	h = rig.head_xz()
	_check(h.x < -6.6 and h.x > -7.05, "terrace reached, railing holds (head x=%.2f)" % h.x)
	# 3: the table blocks a straight walk into it
	origin.global_position = Vector3(-0.3, 0, -3.4)  # head at (0, -3.2), south of the table
	for i in 40:
		rig.apply_move(Vector3(0, 0, 0.25))
	h = rig.head_xz()
	_check(h.y < -2.35 and h.y > -2.75, "table blocks (head z=%.2f)" % h.y)
	# 4: snap turn pivots on the head — head world position must not move
	var before: Vector2 = rig.head_xz()
	rig.apply_turn(deg_to_rad(-30.0))
	var after: Vector2 = rig.head_xz()
	_check(before.distance_to(after) < 0.01, "turn pivots on the head (moved %.3f m)" % before.distance_to(after))
	_check(absf(rad_to_deg(origin.rotation.y) + 30.0) < 0.5 or absf(rad_to_deg(origin.rotation.y) - 330.0) < 0.5, "origin yaw = -30 (got %.1f)" % rad_to_deg(origin.rotation.y))
	print("RIG_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
