extends SceneTree
## R4-4 proof (NOT shipped): a parked model releases its label textures (every label text == ""),
## and unpark restores them — tether captions, dim labels, and a pinned part's two-line label.
## Run: godot --headless --path app --script ../tools/park_labels_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print("PARKLBL ", "PASS " if cond else "FAIL ", label)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var bench: Node = main.get_node("CadBench")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb")), man)
	await create_timer(1.0).timeout
	var m: Node = bench.active_model()
	var tethers: Array = m.get("_tethers")
	var dims: Array = m.get("_dim_labels")
	_check(tethers.size() == 27, "27 tether labels built")
	_check((tethers[0]["label"] as Label3D).text != "", "labels carry text at rest")
	# pin part 3 so its label is the two-line rich form, then park
	var part: MeshInstance3D = tethers[3]["part"]
	m.highlight_part(part, true)
	_check("\n" in (tethers[3]["label"] as Label3D).text, "pinned label is two-line before park")
	m.park(Vector3(1.2, 0.951, -0.4))
	await create_timer(0.2).timeout
	var all_blank := true
	for t in tethers:
		if (t["label"] as Label3D).text != "":
			all_blank = false
	for l in dims:
		if (l as Label3D).text != "":
			all_blank = false
	_check(all_blank, "parked: every label texture released (all texts empty)")
	m.unpark()
	await create_timer(0.2).timeout
	var restored := true
	for t in tethers:
		if (t["label"] as Label3D).text == "":
			restored = false
	for l in dims:
		if (l as Label3D).text == "":
			restored = false
	_check(restored, "unparked: all label texts restored")
	_check("\n" in (tethers[3]["label"] as Label3D).text, "pinned part keeps its two-line label after unpark")
	print("PARK_LABELS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(_fails)
