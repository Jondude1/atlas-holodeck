extends SceneTree
## Jon's live-library verification (NOT shipped): fetch the Victory-class Star Destroyer STL entry from
## the REAL hub (tailnet), materialize it, then prove manipulation — a hand drag (slide + yaw) and the
## scale buttons' path — with captures. Run with HOLODECK_HUB=http://100.65.202.81:8765.
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print("SD ", "PASS " if cond else "FAIL ", label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _snap(cam: Camera3D, pos: Vector3, look: Vector3, name: String) -> void:
	cam.global_position = pos
	cam.look_at(look)
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_abs("captures/" + name))
	print("CAPTURE ", name, " ", img.get_size())

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await create_timer(1.0).timeout
	var bench: Node = main.get_node("CadBench")
	var glb := FileAccess.get_file_as_bytes("/tmp/sd/model.glb")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/sd/manifest.json"))
	_check(glb.size() == 3176056, "real converted GLB in hand (%d bytes)" % glb.size())
	var t0 := Time.get_ticks_msec()
	var m: Node = await bench.spawn(glb, man, "edce928564")
	print("SD spawn took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_check(m != null and bench.active_model() == m, "materialized as the active model")
	if m == null:
		quit(1)
		return
	await create_timer(3.0).timeout   # materialize beat finishes
	_check(m.part_names().size() == 1, "single part (imported STL), parts=%d" % m.part_names().size())
	print("SD dims_text: ", m.dims_text(), " scale_label: ", m.scale_label())
	var cam: Camera3D = main.get_node("FallbackCamera")
	cam.fov = 55.0
	var c: Vector3 = m.global_position + Vector3(0, 0.12, 0)
	await _snap(cam, c + Vector3(-0.55, 0.38, 0.75), c, "r25-stardestroyer-front.png")
	# --- manipulation 1: hand drag — slide + yaw, driven exactly like the interaction suite drives it
	var hand := Node3D.new()
	main.add_child(hand)
	var before: Vector3 = m.global_position
	hand.global_position = before + Vector3(0, 0.1, 0)
	hand.global_rotation = Vector3.ZERO
	m.set_process(false)
	m.call("begin_grab", hand)
	m.set_process(false)
	var steps := 30
	for i in steps:
		hand.global_position += Vector3(0.20, 0.0, 0.10) / steps
		hand.global_rotation.y += deg_to_rad(35.0) / steps
		m.call("step", 1.0 / 30.0)
	m.call("end_grab", hand)
	m.set_process(true)
	await create_timer(1.2).timeout   # settle/coast finishes
	var moved: Vector3 = m.global_position - before
	_check(moved.length() > 0.08, "drag moved the ship %.2f m (dx %.2f dz %.2f)" % [moved.length(), moved.x, moved.z])
	_check(absf(m.rotation.y) > 0.2, "drag yawed the ship to %.0f deg" % rad_to_deg(m.rotation.y))
	# --- manipulation 2: the scale path the panel buttons use
	m.call("set_model_scale", 2.0)
	await create_timer(0.6).timeout
	_check(absf(m.scale.x - 2.0) < 0.05, "2x scale applied (scale %.2f)" % m.scale.x)
	m.call("set_model_scale", 1.0)
	await create_timer(0.6).timeout
	c = m.global_position + Vector3(0, 0.12, 0)
	await _snap(cam, c + Vector3(0.62, 0.34, 0.68), c, "r25-stardestroyer-yawed.png")
	print("SD_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
