extends SceneTree
## Headless proof of the real silhouette schematic (brief #16 R1-12). NOT shipped.
## Builds real CadModels from glbs, then checks the silhouette raster against the known geometry: hole count / position /
## radius for a bracket with two base holes, no phantom holes for plain parts, a multi-part assembly footprint, and cost.
## Run: godot --headless --path app --script ../tools/silhouette_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _model(dir: String, glb: String, man: String) -> Node3D:
	var m := Node3D.new()
	m.set_script(load("res://cad_model.gd"))
	m.call("setup", FileAccess.get_file_as_bytes(_abs(dir + "/" + glb)), JSON.parse_string(FileAccess.get_file_as_string(_abs(dir + "/" + man))))
	return m

func _initialize() -> void:
	_run()

func _run() -> void:
	# 1. bracket revision: 4 x 1.25 in base with two 5.5 mm holes along Z at x = +0.2 in and +1.52 in from centre
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	var t0 := Time.get_ticks_usec()
	var m := _model("cad-jobs/edit-bracket-tall", "model.glb", "manifest.json")
	holder.add_child(m)
	await process_frame
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var holes: Array[Dictionary] = Blueprint.last_holes.duplicate()
	var s: float = m.get("display_scale")
	var b: AABB = m.get("_bounds")
	var quad_m := maxf(b.size.x, b.size.z) * 1.7
	var ppm := Blueprint.MASK_PX / quad_m
	print("bracket: %d holes, display_scale=%.2f, build %.0f ms (model + silhouette)" % [holes.size(), s, ms])
	check(holes.size() == 2, "two base holes found (got %d)" % holes.size())
	var got: Array[float] = []
	for h in holes:
		var c: Vector2 = h["c"]
		got.append((c.x - Blueprint.MASK_PX * 0.5) / ppm / s / 0.0254)       # inches from the bbox centre (centred on x = 0: bbox is the part)
		check(h["round"], "hole is recognised as round")
		var r_in := float(h["r"]) / ppm / s / 0.0254
		check(absf(r_in - 2.75 / 25.4) < 0.02, "hole radius %.3f in ~ 2.75 mm (%.3f)" % [r_in, 2.75 / 25.4])
	got.sort()
	check(absf(got[0] - 0.2) < 0.04 and absf(got[1] - 1.52) < 0.04, "hole centres at %.2f / %.2f in (CAD: 0.20 / 1.52)" % [got[0], got[1]])
	# 2. the original bracket (holes are in the vertical arm, axis X): nothing visible from above -> no phantom holes
	var m0 := _model("cad-jobs/0f84d94de2", "model.glb", "manifest.json")
	holder.add_child(m0)
	await process_frame
	check(Blueprint.last_holes.is_empty(), "plain bracket: no through-holes from above, none invented")
	# 3. 27-part trebuchet: footprint union, timing
	t0 = Time.get_ticks_usec()
	var mt := _model("cad", "trebuchet.glb", "trebuchet.manifest.json")
	holder.add_child(mt)
	await process_frame
	var mt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("trebuchet: %d parts, %d holes, build %.0f ms" % [mt.call("part_names").size(), Blueprint.last_holes.size(), mt_ms])
	check(mt.call("part_names").size() > 3, "multi-part model built")
	# 4. the schematic texture is a real, non-legacy image of the expected size, and the legacy layer is still reachable
	var tex: Texture2D = (mt.get("_schematic_mat") as StandardMaterial3D).albedo_texture
	check(tex.get_width() == Blueprint.MASK_PX, "silhouette texture %d px" % tex.get_width())
	Blueprint.legacy = true
	var ml := _model("cad-jobs/0f84d94de2", "model.glb", "manifest.json")
	holder.add_child(ml)
	await process_frame
	check((ml.get("_schematic_mat") as StandardMaterial3D).albedo_texture.get_width() == Blueprint.SIZE, "legacy layer still available for comparison")
	Blueprint.legacy = false
	print("SILHOUETTE_TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
