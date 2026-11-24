extends SceneTree
## Round 1B captures (NOT shipped): the real silhouette schematic vs the legacy bbox + bolt layer, same camera, for the
## bracket revision (two plan-view holes) and the 27-part trebuchet. Layer-only top-down views (parts hidden) + model views.
## Run: xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/silhouette_capture.gd
var main: Node
var bench: CadBench
var cam: Camera3D
var out_dir: String

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	print("CAPTURE ", n, " ", img.get_size(), " err=", img.save_png(out_dir.path_join(n)))

func _secs(s: float) -> void:
	await create_timer(s).timeout

func _top(m: Node3D, h := 0.95, fov := 40.0) -> void:
	cam.fov = fov
	cam.global_position = m.global_position + Vector3(0.0, h, 0.001)
	cam.look_at(m.global_position, Vector3(0, 0, -1))

func _set_parts_visible(m: Node3D, on: bool) -> void:
	for i in m.call("part_names").size():
		m.call("part_node", i).visible = on
	for c in m.get_children():
		if c is Label3D and String(c.name).begins_with("PartLabel"):
			c.visible = on
		elif c is MeshInstance3D and String(c.name).begins_with("Tether"):
			c.visible = on

func _legacy_tex(m: Node3D) -> Texture2D:
	var b: AABB = m.get("_bounds")
	var quad_m := maxf(b.size.x, b.size.z) * 1.7
	return Blueprint.make(Rect2(b.position.x, b.position.z, b.size.x, b.size.z), quad_m)

func _one(tag: String, dir: String, glb: String, man: String, rot_deg: float) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs(dir + "/" + man)))
	await bench.spawn(FileAccess.get_file_as_bytes(_abs(dir + "/" + glb)), manifest, "cap" + tag)
	await _secs(0.8)
	var m: Node3D = bench.active_model()
	m.position = Vector3(0, 0.951, 0)
	m.rotation_degrees.y = rot_deg
	var mat: StandardMaterial3D = m.get("_schematic_mat")
	var new_tex := mat.albedo_texture
	_set_parts_visible(m, false)
	_top(m)
	await _secs(0.5)
	await _snap("r1b-silhouette-%s-new.png" % tag)
	mat.albedo_texture = _legacy_tex(m)
	await _secs(0.4)
	await _snap("r1b-silhouette-%s-old.png" % tag)
	mat.albedo_texture = new_tex
	_set_parts_visible(m, true)
	m.call("clear_highlight")
	m.call("set_tether_alpha", 1.0)
	cam.fov = 52.0
	cam.global_position = m.global_position + Vector3(0.0, 0.55, 0.62)
	cam.look_at(m.global_position + Vector3(0, 0.04, 0))
	await _secs(0.5)
	await _snap("r1b-silhouette-%s-model.png" % tag)

func _run() -> void:
	await process_frame
	await process_frame
	cam = main.get_node("FallbackCamera")
	bench = main.get_node("CadBench")
	var bracket: Node3D = bench.active_model()
	while bracket.debug_scan() >= 0.0 and bracket.debug_scan() < 1.15:
		await process_frame
	await _secs(1.0)
	await _one("bracket", "cad-jobs/edit-bracket-tall", "model.glb", "manifest.json", 0.0)
	await _one("treb", "cad", "trebuchet.glb", "trebuchet.manifest.json", 35.0)
	print("CAPTURE DONE")
	quit()
