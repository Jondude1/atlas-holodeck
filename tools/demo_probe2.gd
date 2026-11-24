extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("PROBE2: rl_exists = ", ResourceLoader.exists("res://demo/stardestroyer.glb"))
	print("PROBE2: fa_exists = ", FileAccess.file_exists("res://demo/stardestroyer.glb"))
	var bytes := FileAccess.get_file_as_bytes("res://demo/stardestroyer.glb")
	print("PROBE2: bytes = ", bytes.size())
	var f := FileAccess.open("res://demo/stardestroyer.json", FileAccess.READ)
	print("PROBE2: json_open = ", f != null)
	var manifest: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	print("PROBE2: manifest_is_dict = ", manifest is Dictionary)
	if manifest is Dictionary:
		print("PROBE2: manifest name = ", manifest.get("name"), " parts = ", (manifest.get("parts") as Array).size())
		var m := Node3D.new()
		m.set_script(preload("res://cad_model.gd"))
		root.add_child(m)
		m.setup(bytes, manifest)
		print("PROBE2: load_ok = ", m.get("load_ok"))
		if m.has_method("part_names"):
			print("PROBE2: parts = ", m.part_names())
	quit(0)
