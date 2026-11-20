extends SceneTree
## Round 2.5 library proof (NOT shipped): against tools/mock_hub.py, the panel's LIBRARY view lists the
## mock's 3 entries (STL row has no EDIT), a fetch spawns the entry's job on stage, and the delete flow is
## confirmation-gated (cancel deletes nothing; confirm deletes exactly that entry and the list refreshes).
## Run: HOLODECK_HUB=http://127.0.0.1:8792 xvfb-run -a godot --path app --resolution 1280x720 --script ../tools/library_test.gd
## (mock started with --assets cad-jobs/0f84d94de2 --edit-assets cad-jobs/edit-bracket-tall)

var _fails := 0

func _check(cond: bool, label: String) -> void:
	print("LIB ", "PASS " if cond else "FAIL ", label)
	if not cond:
		_fails += 1

func _until(desc: String, fn: Callable, timeout_s: float) -> bool:
	var t_end := Time.get_ticks_msec() / 1000.0 + timeout_s
	while Time.get_ticks_msec() / 1000.0 < t_end:
		if fn.call():
			return true
		await process_frame
	print("LIB FAIL TIMEOUT: ", desc)
	_fails += 1
	return false

func _initialize() -> void:
	_run()

func _run() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var panel: Node = main.get_node("UIPanel")
	var bench: Node = main.get_node("CadBench")
	await _until("hub probe", func() -> bool: return Hub.base_url != "", 180.0)
	_check(Hub.base_url != "", "hub reachable (%s)" % Hub.base_url)

	panel.set_list_mode("library")
	await _until("library rows", func() -> bool: return panel.library_row_count() == 3, 90.0)
	_check(panel.library_row_count() == 3, "library lists 3 entries")
	_check(panel.library_row_has_edit(0), "holodeck row 0 has an EDIT button")
	_check(not panel.library_row_has_edit(2), "imported STL row has NO edit button")

	var entries: Array = panel.get("_lib_entries")
	bench.load_library(entries[0])
	await _until("fetched model on stage", func() -> bool:
		var m: Node = bench.active_model()
		return m != null and String(m.get("job_id")) == "a8b6d50939", 120.0)
	_check(String(bench.active_model().get("job_id")) == "a8b6d50939", "fetch spawned the bracket job on stage")

	# delete: cancel first — nothing may be deleted
	panel.set_list_mode("library")
	await _until("library rows again", func() -> bool: return panel.library_row_count() == 3, 90.0)
	entries = panel.get("_lib_entries")
	panel.request_library_delete(entries[1])
	_check((panel.get("_lib_card") as Control).visible, "delete opens the confirmation card")
	panel.cancel_library_delete()
	_check(not (panel.get("_lib_card") as Control).visible, "cancel closes the card")
	panel.set_list_mode("parts")
	panel.set_list_mode("library")
	await _until("rows after cancel", func() -> bool: return panel.library_row_count() == 3, 90.0)
	_check(panel.library_row_count() == 3, "cancel deleted nothing (still 3 entries)")

	# delete: confirm — exactly that entry goes, the list refreshes to 2
	entries = panel.get("_lib_entries")
	panel.request_library_delete(entries[1])
	panel.confirm_library_delete()
	await _until("rows after confirm", func() -> bool: return panel.library_row_count() == 2, 90.0)
	_check(panel.library_row_count() == 2, "confirm deleted the entry (2 remain)")
	var names := []
	for e in panel.get("_lib_entries"):
		names.append(String(e.get("id", "")))
	_check(not names.has("test-block-b7c1e44f02") and names.has("shelf-bracket-a8b6d50939"), "the right entry was deleted")

	print("LIBRARY_TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
