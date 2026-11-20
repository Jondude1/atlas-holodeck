class_name PrintFlow
extends Node
## Confirmation-gated send-to-print (brief #16 R1-8, SPEC §6). DRY-RUN ONLY in this build: the hub's /atlas/print-job
## returns the plan of what WOULD be sliced and sent; nothing is sliced and the printer is never contacted.
##
## State machine:  IDLE --request--> CONFIRMING --confirm--> SUBMITTING --> DONE (plan) | FAILED
##                                       \--cancel / timeout / model change--> IDLE (nothing sent, hub never called)
## A request (panel button OR a voice command) only ever reaches CONFIRMING. Only an explicit confirm moves on: the panel
## CONFIRM button, or a spoken yes that arrives while CONFIRMING. A spoken yes with nothing pending is ignored.

signal state_changed(state: int)
signal cancelled(why: String)
signal plan_ready(plan: Dictionary)
signal failed(reason: String)

enum S { IDLE, CONFIRMING, SUBMITTING, DONE, FAILED }

const CONFIRM_TIMEOUT_S := 45.0
const MATERIAL := "PLA"
const PRINTER := "S1"
## Same estimate as the hub (atlas_voice.estimate_print) so the card and the plan agree: ~40% of the solid volume is
## extruded at ~12 cm3/h average, plus 10 min of heat-up. A rough number, shown as an ESTIMATE.
const FILL := 0.4
const CM3_PER_HOUR := 12.0
const OVERHEAD_MIN := 10.0

var state := S.IDLE
var info := {}                    # what the card shows: job_id, name, material, printer, est_minutes, est_text
var plan := {}                    # the hub's dry-run plan once DONE
var reason := ""
var last_via := ""                # "panel" | "voice": how the confirm arrived
var submit_calls := 0             # how many times the hub route was called (tests: cancel must leave this at 0)
var _left := 0.0
## async (job_id: String) -> Dictionary {ok, code, body}. Default = the hub's dry-run route; tests inject their own.
var submit_fn := Callable()
var _voice: VoiceLink

func _ready() -> void:
	add_to_group("print_flow")
	set_process(false)
	if not submit_fn.is_valid():
		submit_fn = _hub_submit

func _hub_submit(job_id: String) -> Dictionary:
	return await Hub.post_json(self, "/atlas/print-job", {"job_id": job_id, "confirmed": true})

static func estimate_minutes(volume_cm3: float) -> int:
	return int(round(OVERHEAD_MIN + volume_cm3 * FILL / CM3_PER_HOUR * 60.0))

static func time_text(minutes: int) -> String:
	var h := floori(minutes / 60.0)
	var m := minutes % 60
	return ("%d min" % m) if h == 0 else ("%d h %02d min" % [h, m])

## Builds the card info from a model (its manifest + the hub's estimate when it came with the job).
static func info_for(model: Node) -> Dictionary:
	var jid := String(model.get("job_id")) if model.get("job_id") != null else ""
	var man: Dictionary = model.get("manifest") if model.get("manifest") != null else {}
	var est: Dictionary = model.get("print_estimate") if model.get("print_estimate") != null else {}
	var minutes := int(est.get("est_minutes", 0))
	if minutes <= 0:       # no hub estimate (older job): 25% of the bounding box, same rule the hub falls back to
		var d: Array = man.get("true_dims_in", [3.0, 3.0, 3.0])
		minutes = estimate_minutes(float(d[0]) * float(d[1]) * float(d[2]) * 16.387 * 0.25)
	return {"job_id": jid, "name": String(man.get("name", "part")), "material": MATERIAL, "printer": PRINTER,
			"est_minutes": minutes, "est_text": time_text(minutes)}

func _enter(s: int) -> void:
	var was := state
	state = s
	set_process(s == S.CONFIRMING)
	if _voice != null:      # keep the hub's "waiting for a yes/no" flag in step, so a spoken answer is classified, not chatted
		if s == S.CONFIRMING:
			_voice.hub_event({"event": "print_pending", "job_id": info.get("job_id", "")})
		elif was == S.CONFIRMING:
			_voice.hub_event({"event": "print_clear"})
	state_changed.emit(s)

func is_confirming() -> bool:
	return state == S.CONFIRMING

## Opens the confirmation. `source` is "panel" or "voice" and changes nothing about the gate: neither can start a print.
func request(i: Dictionary, source := "panel") -> bool:
	if state == S.SUBMITTING:
		return false
	if String(i.get("job_id", "")) == "":
		reason = "This part didn't come from a CAD job, so there's nothing to send yet."
		_enter(S.FAILED)
		failed.emit(reason)
		return false
	info = i.duplicate()
	plan = {}
	reason = ""
	last_via = source
	_left = CONFIRM_TIMEOUT_S
	_enter(S.CONFIRMING)
	return true

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and state == S.CONFIRMING:
		cancel("timeout")

func seconds_left() -> float:
	return maxf(_left, 0.0)

## Only valid while CONFIRMING. via = "panel" (button) or "voice" (spoken yes). Returns the dry-run plan ({} on failure).
func confirm(via: String) -> Dictionary:
	if state != S.CONFIRMING:
		return {}
	last_via = via
	_enter(S.SUBMITTING)
	submit_calls += 1
	var fn: Callable = submit_fn if submit_fn.is_valid() else _hub_submit
	var res: Dictionary = await fn.call(String(info["job_id"]))
	var body: Dictionary = res.get("body", {})
	if res.get("ok", false) and bool(body.get("dry_run", false)) and not bool(body.get("contacted_printer", true)):
		plan = body
		_enter(S.DONE)
		plan_ready.emit(plan)
		return plan
	reason = _fail_text(int(res.get("code", 0)), body)
	_enter(S.FAILED)
	failed.emit(reason)
	return {}

static func _fail_text(code: int, body: Dictionary) -> String:
	var d := String(body.get("detail", ""))
	if code == 0:
		return "I couldn't reach the hub, so nothing was planned."
	if code == 409 or code == 404:
		return "The hub wouldn't plan that one: %s." % d.rstrip(".") if d != "" else "The hub wouldn't plan that one."
	return "The hub had a problem planning that print."

## A spoken yes counts ONLY while a confirmation is open.
func voice_confirm() -> void:
	if state == S.CONFIRMING:
		confirm("voice")

func voice_cancel() -> void:
	if state == S.CONFIRMING:
		cancel("voice")

func cancel(why := "panel") -> void:
	if state != S.CONFIRMING:
		return
	_enter(S.IDLE)
	cancelled.emit(why)

## Back to IDLE after the DONE / FAILED card has been seen.
func dismiss() -> void:
	if state == S.DONE or state == S.FAILED:
		_enter(S.IDLE)

## The part on stage changed (edit swapped it, bench select, new job): an open confirmation named the OLD part.
func model_changed() -> void:
	if state == S.CONFIRMING:
		cancel("model-changed")

## Voice entry. The hub reports what it heard; this class decides what it means. print_request opens the confirmation
## and speaks the hub's line; a spoken yes/no counts only while CONFIRMING and only for the part the card names.
func bind_voice(v: VoiceLink) -> void:
	_voice = v
	v.print_request.connect(_on_voice_request)
	v.print_confirm.connect(_on_voice_confirm)
	v.print_cancel.connect(_on_voice_cancel)
	plan_ready.connect(func(p: Dictionary) -> void:
		v.say("Dry run complete. Nothing was sent: that's the plan only, the printer was not contacted."))
	failed.connect(func(r: String) -> void: v.say(r))
	cancelled.connect(func(why: String) -> void:
		if why != "model-changed":
			v.say("Cancelled. Nothing was sent."))

func _on_voice_request(ev: Dictionary) -> void:
	var i := {"job_id": String(ev.get("job_id", "")), "name": String(ev.get("name", "part")), "material": MATERIAL,
			"printer": String(ev.get("printer", PRINTER)), "est_minutes": int(ev.get("est_minutes", 0)),
			"est_text": String(ev.get("est_text", "?"))}
	if request(i, "voice") and _voice:
		_voice.say(String(ev.get("text", "")))

func _on_voice_confirm(job_id: String) -> void:
	if state == S.CONFIRMING and job_id == String(info.get("job_id", "")):
		voice_confirm()

func _on_voice_cancel(job_id: String) -> void:
	if state == S.CONFIRMING and job_id == String(info.get("job_id", "")):
		voice_cancel()

## Panel entry: SEND TO PRINTER on the active model. Opens the same confirmation and says what it names.
func request_for(model: Node) -> bool:
	var i := info_for(model)
	var ok := request(i, "panel")
	if ok and _voice:
		_voice.say("Send the %s to printer %s? %s, about %s. Press confirm on the panel, or say yes." % [
				i["name"], PRINTER, MATERIAL, i["est_text"]])
	return ok
