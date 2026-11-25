extends SceneTree
## Iterate round 1 minimal budget probe (NOT shipped): boot the room, report
## resting draw calls + primitive count + light-node count. No CAD/hub cases
## (tools/perf_probe.gd covers those when the hub is up).
func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_skip_boot")
	await create_timer(2.0).timeout
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var calls := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var lights := 0
	var stack: Array[Node] = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Light3D:
			lights += 1
		for c in n.get_children():
			stack.append(c)
	print("SUITPERF draw_calls=", calls, " primitives=", prims, " light_nodes=", lights)
	quit(0)
