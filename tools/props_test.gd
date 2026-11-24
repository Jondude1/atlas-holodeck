extends SceneTree
## Round 5B props test (NOT shipped): the bench lamp + crates exist as Prop nodes in the
## grabbable group; a fake hand grabs the lamp, carries it to the room centre, releases —
## it must follow while held and settle onto the FLOOR (support height 0) when let go.
## The robot arm must sulk when poked. Run: godot --headless --path app --script ../tools/props_test.gd
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
	var lamp: Node = main.find_child("PropLamp", true, false)
	var crates: Node = main.find_child("PropCrates", true, false)
	_check(lamp != null and crates != null, "lamp + crates props exist")
	_check(lamp.is_in_group("grabbable") and crates.is_in_group("grabbable"), "props are grabbable")
	_check(absf(lamp.global_position.y - 0.9475) < 0.01, "lamp starts on the bench (y=%.3f)" % lamp.global_position.y)
	# fake hand grabs the lamp
	var hand := Node3D.new()
	root.add_child(hand)
	hand.global_position = lamp.global_position + Vector3(0, 0.24, 0)
	_check(lamp.can_grab(hand), "lamp can be grabbed at its centre")
	lamp.begin_grab(hand)
	hand.global_position = Vector3(0.0, 1.3, -1.0)   # carry to mid-room, mid-air
	lamp.step(0.016)
	_check(lamp.global_position.distance_to(Vector3(0.0, 1.06, -1.0)) < 0.05, "lamp follows the hand (at %s)" % lamp.global_position)
	lamp.end_grab(hand)
	# settle: step until rest — must land on the floor (support 0 at room centre... the
	# table is at centre! (0,-1) is over the table display -> support is the table top)
	for i in 90:
		lamp.step(0.05)
	_check(absf(lamp.global_position.y - 0.97) < 0.02, "lamp settles onto the table top (y=%.3f)" % lamp.global_position.y)
	# carry it OFF the table to open floor and drop again -> floor height
	lamp.begin_grab(hand)
	hand.global_position = Vector3(-2.2, 1.2, 1.8)
	lamp.step(0.016)
	lamp.end_grab(hand)
	for i in 90:
		lamp.step(0.05)
	_check(absf(lamp.global_position.y) < 0.02, "lamp settles onto the floor (y=%.3f)" % lamp.global_position.y)
	# the arm sulks when poked
	var arm: Node = main.find_child("RobotArm", true, false)
	_check(arm != null, "robot arm present")
	arm.poke()
	_check(String(arm.get("_cur_name")) == "sulk", "arm sulks when poked (state=%s)" % String(arm.get("_cur_name")))
	print("PROPS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
