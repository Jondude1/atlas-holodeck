extends SceneTree
## Headless panel layout proof (NOT shipped): measures the panel's content minimum size against its SubViewport,
## and that every control's rect lies inside the viewport (nothing clipped). Run: godot --headless --path app --script ../tools/panel_test.gd
func _initialize() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	var panel: Node = main.get_node("UIPanel")
	var vp: SubViewport = panel.get_node("SubViewport")
	var content: Control = vp.get_child(0)
	var need := content.get_combined_minimum_size()
	print("PANEL viewport=%s content_min=%s content_size=%s" % [vp.size, need, content.size])
	var bad := 0
	bad += _walk(content, Rect2(Vector2.ZERO, Vector2(vp.size)))
	var ok := need.y <= vp.size.y and need.x <= vp.size.x and bad == 0
	print("PANEL_TEST ", "PASS" if ok else "FAIL (min fits=%s, controls outside=%d)" % [need.y <= vp.size.y, bad])
	quit(0 if ok else 1)

func _walk(n: Node, bounds: Rect2) -> int:
	var bad := 0
	if n is Control and (n as Control).is_visible_in_tree():
		var r := Rect2((n as Control).global_position, (n as Control).size)
		if not (n is ScrollContainer) and r.end.y > bounds.end.y + 0.5 or r.end.x > bounds.end.x + 0.5:
			print("  CLIPPED: %s %s (viewport %s)" % [n.name, r, bounds])
			bad += 1
	for c in n.get_children():
		bad += _walk(c, bounds)
	return bad
