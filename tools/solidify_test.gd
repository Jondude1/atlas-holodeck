extends SceneTree
## Round 5B solidify + persistence test (NOT shipped). Spawns the exercise bracket through
## CadBench.spawn (local assets, no hub), drags it off the table with a fake hand: it must
## solidify (world parent, solid material, world_solid). Released over open floor it must
## settle to the floor and write user://world.json. A simulated restart (model freed,
## restore_world) must bring it back from the on-device cache at the same transform.
## Carrying it back over the free table must return it to hologram bench duty.
## Run: godot --headless --path app --script ../tools/solidify_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print(("  ok  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _drag(m: Node3D, hand: Node3D, to: Vector3, steps := 14) -> void:
	var from := hand.global_position
	for i in steps:
		hand.global_position = from.lerp(to, float(i + 1) / steps)
		await process_frame
		await process_frame

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	var bench: Node = main.get_node("CadBench")
	var table: Node = main.get_node("HoloTable")
	# clean slate for the world store
	if FileAccess.file_exists("user://world.json"):
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/world.json")
	var glb := FileAccess.get_file_as_bytes("res://../cad-jobs/0f84d94de2/model.glb")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../cad-jobs/0f84d94de2/manifest.json"))
	var m: Node3D = await bench.spawn(glb, man, "testjob001")
	_check(m != null, "model spawned through the bench")
	_check(FileAccess.file_exists("user://world_cache/testjob001.glb"), "GLB cached on the headset at spawn")
	var hand := Node3D.new()
	root.add_child(hand)
	hand.global_position = (m.global_transform * (m.get("center_local") as Vector3)) + Vector3(0, 0.05, 0)
	m.call("begin_grab", hand)
	await _drag(m, hand, Vector3(-0.2, 1.8, -1.2), 8)      # lift clear of the surface first (well inside the table rect)
	await _drag(m, hand, Vector3(-2.6, 1.8, 1.6), 12)      # then carry out over the floor
	_check(bool(m.get("world_solid")), "model solidified after crossing the table edge")
	_check(m.get_parent() == main, "solid model is parented to the world, not the table")
	_check(bench.get("_solid") == m, "bench tracks the solid")
	var part0: MeshInstance3D = (m.get("_parts") as Array)[0]
	_check(part0.material_override is StandardMaterial3D, "parts wear the solid material")
	m.call("end_grab", hand)
	# wait for the settle ease to actually land (headless frames compress real time)
	var last_y := m.global_position.y
	var still := 0
	for i in 400:
		await process_frame
		if m.global_position.y <= 0.011:
			break
		if absf(m.global_position.y - last_y) < 0.0005:
			still += 1
			if still > 12:
				break
		else:
			still = 0
		last_y = m.global_position.y
	_check(absf(m.global_position.y) < 0.02, "solid settles onto the floor (y=%.3f)" % m.global_position.y)
	# the persistence contract: wait until the LANDING save reaches the file
	for i in 240:
		var wj: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://world.json"))
		if typeof(wj) == TYPE_DICTIONARY and (wj.get("objects", []) as Array).size() == 1:
			var op: Array = (wj["objects"][0] as Dictionary).get("pos", [0, 9, 0])
			if float(op[1]) <= 0.02:
				break
		await process_frame
	var saved_pos := m.global_position
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://world.json"))
	_check((world.get("objects", []) as Array).size() == 1, "world.json holds the placed object")
	# simulated restart: free the model, restore from the cache
	m.queue_free()
	bench.set("_solid", null)
	await process_frame
	await process_frame
	bench.restore_world()
	var restored: Node = bench.get("_solid")
	_check(restored != null and restored != m, "restore brings the object back")
	if restored != null:
		_check(restored.global_position.distance_to(saved_pos) < 0.02, "restored at the saved spot (%s)" % restored.global_position)
		_check(bool(restored.get("world_solid")), "restored object is solid")
		# carry it back over the free table -> hologram again
		hand.global_position = (restored.global_transform * (restored.get("center_local") as Vector3)) + Vector3(0, 0.05, 0)
		restored.call("begin_grab", hand)
		await _drag(restored, hand, Vector3(0.0, 1.45, -1.55), 14)
		for i in 600:
			if not bool(restored.get("world_solid")):
				break
			await process_frame
		_check(not bool(restored.get("world_solid")), "carried back over the table: hologram again")
		_check(restored.get_parent() == table, "model is a table child again")
		_check(bench.get("_active") == restored, "bench active model restored")
		restored.call("end_grab", hand)
	var world2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://world.json"))
	_check((world2.get("objects", []) as Array).is_empty(), "world.json emptied on return")
	print("SOLIDIFY_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
