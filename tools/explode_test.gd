extends SceneTree
## Headless proof (NOT shipped): multi-part explode separates parts along their own geometry centres.
## Fixture: cad/trebuchet.glb (27 parts, vertices baked in world space => every node origin is 0, the audit's risk case),
## plus the 3-part demo bracket. Run: godot --headless --path app --script ../tools/explode_test.gd
const CadModelScript := preload("res://cad_model.gd")

func _initialize() -> void:
	var fail := 0
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	var glb := FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb"))
	var holder := Node3D.new()
	root.add_child(holder)
	var m: Node3D = Node3D.new()
	m.set_script(CadModelScript)
	m.call("setup", glb, man)
	holder.add_child(m)
	await process_frame
	fail += _check("trebuchet(27 parts, baked origins)", m)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	fail += _check("demo bracket(3 parts)", main.get_node("HoloTable/TestBracket"))
	print("EXPLODE_TEST ", "PASS" if fail == 0 else "FAIL (%d)" % fail)
	quit(fail)

func _check(label: String, m: Node3D) -> int:
	var parts: Array = m.get("_parts")
	var origins_zero := parts.all(func(p): return (m.get("_home")[p] as Vector3).length() < 1e-6)
	var centres0: Array = parts.map(func(p): return _gc(p))
	m.call("set_explode", 1.0)
	var moved_xz := 0
	var dirs := {}
	var max_disp := 0.0
	for i in parts.size():
		var d: Vector3 = (_gc(parts[i]) as Vector3) - centres0[i]
		max_disp = maxf(max_disp, d.length())
		if Vector2(d.x, d.z).length() > 0.01:
			moved_xz += 1
		dirs[snappedf(d.x, 0.01) * 1000 + snappedf(d.z, 0.01)] = true
	m.call("set_explode", 0.0)
	var restored := true
	for i in parts.size():
		if (_gc(parts[i]) as Vector3).distance_to(centres0[i]) > 1e-5:
			restored = false
	var ok := parts.size() > 1 and moved_xz >= parts.size() / 2 and dirs.size() > 1 and restored
	print("EXPLODE %s: parts=%d all_node_origins_zero=%s parts_moving_in_XZ=%d distinct_xz_vectors=%d max_disp=%.3f m restores=%s -> %s"
			% [label, parts.size(), origins_zero, moved_xz, dirs.size(), max_disp, restored, "ok" if ok else "FAIL"])
	return 0 if ok else 1

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _gc(p: MeshInstance3D) -> Vector3:
	return Transform3D(p.basis, p.position) * p.mesh.get_aabb().get_center()
