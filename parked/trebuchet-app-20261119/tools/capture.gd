extends SceneTree
## Capture harness (NOT part of the shipped app): loads the real main scene under the
## desktop fallback camera and photographs the viewport at the boot/materialize beats.
## Beats are found by polling the app's own shader parameters frame by frame, so the
## shots land on-state regardless of frame rate:
##   shot-01-boot.png         boot ring mid-check (ring "progress" ~0.5)
##   shot-03-materialize.png  trebuchet mid-materialize (part "scan" ~0.55, scan plane up)
##   shot-04-materialized.png trebuchet fully materialized + schematic + readouts (+ parked bracket)
##   shot-02-table-idle.png   table idle afterwards (models hidden via their own hide_all(),
##                            ring still rotating, motes on, readouts live)
##   shot-05-trebuchet-cocked.png   after COCK: arm down-back, counterweight raised, stone in pouch
##   shot-06-trebuchet-firing.png   after FIRE: stone caught in flight (the sim is driven with
##                            fixed timesteps from here, so the frame is exact, not a timing gamble)
## Run: xvfb-run godot --path app --resolution 1280x720 --script <abs path to this file>

const MAX_FRAMES := 4000

var _main: Node
var _out_dir: String

func _initialize() -> void:
	Engine.time_scale = 0.35  # slow the app's tweens so software rendering keeps up
	var app_dir := ProjectSettings.globalize_path("res://")
	_out_dir = app_dir.path_join("../captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var packed: PackedScene = load("res://main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_run()

func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out_dir.path_join(file_name)
	var err := img.save_png(path)
	print("CAPTURE ", file_name, " ", img.get_size(), " err=", err)

func _wait_until(cond: Callable, label: String) -> bool:
	var frames := 0
	while not cond.call():
		await process_frame
		frames += 1
		if frames > MAX_FRAMES:
			push_warning("CAPTURE timeout waiting for: " + label)
			return false
	return true

func _ring_progress() -> float:
	var mat = _main.get("_ring_mat")
	if mat == null:
		return -1.0
	return float(mat.get_shader_parameter("progress"))

func _scan() -> float:
	var model = _main.get_node("HoloTable/Trebuchet")
	var mats: Array = model.get("_mats")
	if mats.is_empty():
		return -1.0
	return float(mats[0].get_shader_parameter("scan"))

func _step(t: Node, seconds: float) -> void:
	for i in int(seconds * 120.0):
		t.advance(1.0 / 120.0)

func _machine_shots(cam: Camera3D) -> void:
	var t: Node = _main.get_node("HoloTable/Trebuchet")
	await _wait_until(func() -> bool: return float(t.get("_t")) >= 0.0 and t.get("state") == 0 and _scan() >= 1.15, "rest")
	await create_timer(0.8).timeout
	t.set("auto_tick", false)
	t.call("cock")
	_step(t, 1.5)
	await process_frame
	await _snap("shot-05-trebuchet-cocked.png")
	t.call("fire")
	var guard := 0
	while t.get("state") == 3 and guard < 2000:   # FIRING until the release
		_step(t, 1.0 / 120.0)
		guard += 1
	_step(t, 0.4)   # stone clear of the pouch, high in the arc
	await process_frame
	await _snap("shot-06-trebuchet-firing.png")
	_step(t, 4.0)
	t.call("explode_probe")

func _draws() -> int:
	await RenderingServer.frame_post_draw
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _count(n: Node, type: String) -> int:
	var c := 1 if n.is_class(type) else 0
	for k in n.get_children():
		c += _count(k, type)
	return c

## Draw calls (main viewport, this frame) at rest and fully exploded with labels; light count.
func _perf_report() -> void:
	var t: Node = _main.get_node("HoloTable/Trebuchet")
	t.call("set_explode", 0.0)
	await process_frame
	await process_frame
	var rest := await _draws()
	t.call("set_explode", 1.0)
	await process_frame
	await process_frame
	var ex := await _draws()
	await _snap("shot-07-trebuchet-exploded.png")
	t.call("set_explode", 0.0)
	print("PERF draw_calls rest=%d exploded=%d  lights=%d  objects_in_frame=%d" % [rest, ex, _count(root, "Light3D"),
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))])

func _run() -> void:
	# (a) boot ring mid-check, from the app's own fallback framing
	if await _wait_until(func() -> bool: return _ring_progress() >= 0.35, "ring progress"):
		await _snap("shot-01-boot.png")
	# Move the fallback camera in close for the materialize beats (runtime only;
	# the scene file is untouched). In the headset you'd be standing at the table.
	var cam: Camera3D = _main.get_node("FallbackCamera")
	var home_tf := cam.global_transform
	cam.fov = 58.0
	cam.global_position = Vector3(0.3, 1.55, -0.05)
	cam.look_at(Vector3(-0.4, 1.3, -1.55))
	# (c) bracket mid-materialize: scan plane part-way up the part
	if await _wait_until(func() -> bool: return _scan() >= 0.35, "materialize scan"):
		await _snap("shot-03-materialize.png")
	# (d) fully materialized: scan done, white-hot flash settled
	if await _wait_until(func() -> bool: return _scan() >= 1.15, "scan complete"):
		await create_timer(0.4).timeout
		await _snap("shot-04-materialized.png")
	await _machine_shots(cam)
	await _perf_report()
	# (b) table idle: restore framing, hide the models through their own API;
	# ring/motes/readouts keep living
	cam.global_transform = home_tf
	_main.get_node("HoloTable/Trebuchet").call("hide_all")
	_main.get_node("HoloTable/TestBracket").call("hide_all")
	await process_frame
	await process_frame
	await _snap("shot-02-table-idle.png")
	print("CAPTURE DONE")
	quit()
