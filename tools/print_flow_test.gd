extends SceneTree
## Headless proof of the send-to-print confirmation state machine (brief #16 R1-8). NOT shipped.
## Run: godot --headless --path app --script ../tools/print_flow_test.gd
var fails := 0
var calls: Array = []

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func fake_hub(job_id: String) -> Dictionary:       # stands in for POST /atlas/print-job
	calls.append(job_id)
	await process_frame
	return {"ok": true, "code": 200, "body": {"dry_run": true, "contacted_printer": false, "sliced": false,
			"would": {"file": "x/model.step", "printer": "S1", "profile": "PLA - 0.20 mm standard"}}}

func _initialize() -> void:
	_run()

func _mk() -> PrintFlow:
	var pf := PrintFlow.new()
	pf.submit_fn = fake_hub
	root.add_child(pf)
	calls.clear()
	return pf

var _good := {"job_id": "a8b6d50939", "name": "Shelf Bracket", "material": "PLA", "printer": "S1", "est_minutes": 141, "est_text": "2 h 21 min"}

func _run() -> void:
	# 1. request -> confirm -> dry-run plan returned
	var pf := _mk()
	check(pf.state == PrintFlow.S.IDLE, "starts IDLE")
	check(pf.request(_good, "panel"), "panel request opens a confirmation")
	check(pf.state == PrintFlow.S.CONFIRMING and calls.is_empty(), "CONFIRMING, hub NOT called yet")
	check(pf.info["material"] == "PLA" and pf.info["name"] == "Shelf Bracket" and pf.info["est_text"] != "", "card names part, material, est. time")
	var plan := await pf.confirm("panel")
	check(pf.state == PrintFlow.S.DONE and plan.get("dry_run") == true and plan.get("contacted_printer") == false, "confirm -> DONE with a DRY-RUN plan")
	check(calls == ["a8b6d50939"], "hub called exactly once, after the confirm")
	# 2. request -> cancel -> nothing
	pf = _mk()
	pf.request(_good, "panel")
	pf.cancel("panel")
	check(pf.state == PrintFlow.S.IDLE and calls.is_empty() and pf.submit_calls == 0, "request -> cancel: IDLE, hub never called")
	var none := await pf.confirm("panel")
	check(none.is_empty() and calls.is_empty(), "confirm with nothing pending does nothing")
	# 3. a VOICE request alone never starts anything
	pf = _mk()
	check(pf.request(_good, "voice") and pf.state == PrintFlow.S.CONFIRMING, "voice request -> CONFIRMING only")
	await create_timer(0.2).timeout
	check(pf.state == PrintFlow.S.CONFIRMING and calls.is_empty(), "...and it stays there: the voice command did not start anything")
	# 4. a spoken yes counts only while confirming, and only for the named part
	pf = _mk()
	var v := VoiceLink.new()
	root.add_child(v)
	pf.bind_voice(v)
	v.print_confirm.emit("a8b6d50939")
	await create_timer(0.1).timeout
	check(calls.is_empty() and pf.state == PrintFlow.S.IDLE, "spoken yes with nothing pending is ignored")
	v.print_request.emit({"job_id": "a8b6d50939", "name": "Shelf Bracket", "est_minutes": 141, "est_text": "2 h 21 min", "text": ""})
	check(pf.state == PrintFlow.S.CONFIRMING, "hub print_request opens the card")
	v.print_confirm.emit("0000000000")
	await create_timer(0.1).timeout
	check(pf.state == PrintFlow.S.CONFIRMING and calls.is_empty(), "spoken yes for a DIFFERENT job is ignored")
	v.print_confirm.emit("a8b6d50939")
	await create_timer(0.2).timeout
	check(pf.state == PrintFlow.S.DONE and calls == ["a8b6d50939"] and pf.last_via == "voice", "spoken yes while CONFIRMING -> dry-run plan")
	# 5. spoken no
	pf = _mk()
	pf.bind_voice(v)
	pf.request(_good, "panel")
	v.print_cancel.emit("a8b6d50939")
	check(pf.state == PrintFlow.S.IDLE and calls.is_empty(), "spoken no -> cancelled, nothing sent")
	# 6. the part changes under an open card (edit replaced it) -> cancelled
	pf = _mk()
	pf.request(_good, "panel")
	pf.model_changed()
	check(pf.state == PrintFlow.S.IDLE and calls.is_empty(), "model replaced while confirming -> cancelled")
	# 7. timeout
	pf = _mk()
	pf.request(_good, "panel")
	pf._process(PrintFlow.CONFIRM_TIMEOUT_S + 1.0)
	check(pf.state == PrintFlow.S.IDLE and calls.is_empty(), "no answer within %d s -> lapses, nothing sent" % int(PrintFlow.CONFIRM_TIMEOUT_S))
	# 8. no job id (the demo part) cannot be sent
	pf = _mk()
	check(not pf.request({"job_id": "", "name": "Demo"}, "panel") and pf.state == PrintFlow.S.FAILED and calls.is_empty(), "part without a CAD job -> FAILED, hub not called")
	# 9. hub refuses / unreachable -> FAILED with a reason, never a fake plan
	pf = _mk()
	pf.submit_fn = func(_j: String) -> Dictionary: return {"ok": false, "code": 0, "body": {}}
	pf.request(_good, "panel")
	await pf.confirm("panel")
	check(pf.state == PrintFlow.S.FAILED and pf.plan.is_empty() and pf.reason != "", "hub unreachable -> FAILED, no plan")
	# 10. a hub reply that is NOT a dry run is rejected (defence against the seam going live by accident)
	pf = _mk()
	pf.submit_fn = func(_j: String) -> Dictionary: return {"ok": true, "code": 200, "body": {"dry_run": false, "contacted_printer": true}}
	pf.request(_good, "panel")
	await pf.confirm("panel")
	check(pf.state == PrintFlow.S.FAILED, "non-dry-run reply is refused by the client")
	# 11. estimate matches the hub formula (61.57 cm3 -> 133 min on the hub's volume rule)
	check(PrintFlow.estimate_minutes(61.57) == 133 and PrintFlow.time_text(133) == "2 h 13 min", "estimate formula = hub formula")
	print("PRINT_FLOW_TEST ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
