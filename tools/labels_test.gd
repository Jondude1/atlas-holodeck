extends SceneTree
## R3-10 proof (NOT shipped): the 27-part trebuchet at 100% explode — no two tether labels may overlap
## in camera space (billboards are camera-aligned, so rect overlap is exact in that space). Also checks
## the pinned part's label carries its dims as a second line (R3-6 scoped).
## Run: xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/labels_test.gd
var _fails := 0

func _check(cond: bool, label: String) -> void:
	print("LBL ", "PASS " if cond else "FAIL ", label)
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
	var cam: Camera3D = main.get_node("FallbackCamera")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb")), man)
	await create_timer(1.0).timeout
	var m: Node = bench.active_model()
	m.set_explode(1.0)
	await create_timer(2.5).timeout   # explode tween settles; tethers follow
	cam.fov = 58.0
	cam.global_position = Vector3(0.0, 1.55, 2.3)
	cam.look_at(Vector3(0, 1.0, 0))
	await process_frame
	await process_frame
	var inv := cam.global_transform.affine_inverse()
	var rects: Array = []   # {centre: Vector2 (camera space), half: Vector2, name}
	for t in m.get("_tethers"):
		var l: Label3D = t["label"]
		if not l.visible:
			continue
		var cams := inv * l.global_position
		var lines := l.text.split("\n")
		var chars := 0
		for ln in lines:
			chars = maxi(chars, ln.length())
		var half := Vector2(chars * l.font_size * l.pixel_size * 0.27, lines.size() * l.font_size * l.pixel_size * 0.58)
		rects.append({"c": Vector2(cams.x, cams.y), "h": half, "n": l.text.split("\n")[0]})
	_check(rects.size() >= 20, "labels visible at full explode (%d)" % rects.size())
	var worst := 0.0
	var pair := ""
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Dictionary = rects[i]
			var b: Dictionary = rects[j]
			var ox: float = (a["h"].x + b["h"].x) - absf(a["c"].x - b["c"].x)
			var oy: float = (a["h"].y + b["h"].y) - absf(a["c"].y - b["c"].y)
			if ox > 0.0 and oy > 0.0:
				if ox * oy > worst:
					worst = ox * oy
					pair = "%s <-> %s" % [a["n"], b["n"]]
	_check(worst == 0.0, "no overlapping label rects at 100% explode" + (" (worst: %s)" % pair if worst > 0.0 else ""))
	if worst > 0.0:
		for t in m.get("_tethers"):
			var l2: Label3D = t["label"]
			if pair.contains(l2.text.split("\n")[0]):
				var cs := inv * l2.global_position
				print("LBL DBG ", l2.text.split("\n")[0], " world=", l2.global_position, " cam=", Vector2(cs.x, cs.y))
	# R3-6 scoped: pinning a part gives its label a dims second line
	var part: MeshInstance3D = m.part_node(3)
	m.highlight_part(part, true)
	var lt: Label3D = m.get("_tethers")[3]["label"]
	_check(lt.text.contains("\n") and lt.text.contains("IN"), "pinned label shows name + dims (%s)" % lt.text.replace("\n", " / "))
	m.clear_highlight()
	_check(not lt.text.contains("\n"), "unpin restores the one-line caption")
	print("LABELS_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
