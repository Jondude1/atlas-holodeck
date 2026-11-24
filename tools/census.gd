extends SceneTree
## Round 4 audit census (NOT shipped): hard counts of what the scene actually costs — nodes by
## type, mesh instances, UNIQUE materials (batching killers), labels, particles, viewports.
func _initialize() -> void:
	_run()

func _abs(rel: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(rel).simplify_path()

func _walk(n: Node, counts: Dictionary, mats: Dictionary) -> void:
	counts["nodes"] = int(counts.get("nodes", 0)) + 1
	if n is MeshInstance3D:
		counts["mesh_instances"] = int(counts.get("mesh_instances", 0)) + 1
		var mi := n as MeshInstance3D
		if mi.mesh:
			counts["surfaces"] = int(counts.get("surfaces", 0)) + mi.mesh.get_surface_count()
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m:
					mats[m.get_instance_id()] = true
		if mi.material_override:
			mats[mi.material_override.get_instance_id()] = true
	elif n is Label3D:
		counts["label3d"] = int(counts.get("label3d", 0)) + 1
	elif n is GPUParticles3D:
		counts["particle_systems"] = int(counts.get("particle_systems", 0)) + 1
		counts["particles"] = int(counts.get("particles", 0)) + (n as GPUParticles3D).amount
	elif n is SubViewport:
		counts["subviewports"] = int(counts.get("subviewports", 0)) + 1
		counts["subviewport_px"] = int(counts.get("subviewport_px", 0)) + (n as SubViewport).size.x * (n as SubViewport).size.y
	elif n is OmniLight3D or n is SpotLight3D or n is DirectionalLight3D:
		counts["lights"] = int(counts.get("lights", 0)) + 1
	elif n is AudioStreamPlayer or n is AudioStreamPlayer3D:
		counts["audio_players"] = int(counts.get("audio_players", 0)) + 1
	for c in n.get_children():
		_walk(c, counts, mats)

func _report(tag: String, root_node: Node) -> void:
	var counts := {}
	var mats := {}
	_walk(root_node, counts, mats)
	print("CENSUS ", tag, ": ", counts, " unique_materials=", mats.size())

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await create_timer(2.0).timeout
	_report("boot (demo bracket on stage)", main)
	for c in main.get_children():
		_report("subtree " + c.name, c)
	var bench: Node = main.get_node("CadBench")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_abs("cad/trebuchet.manifest.json")))
	bench.spawn(FileAccess.get_file_as_bytes(_abs("cad/trebuchet.glb")), man)
	await create_timer(4.0).timeout
	_report("trebuchet on stage (27 parts)", main)
	var m: Node = bench.active_model()
	m.call("set_explode", 1.0)
	await create_timer(1.5).timeout
	_report("trebuchet EXPLODED (labels out)", main)
	quit(0)
