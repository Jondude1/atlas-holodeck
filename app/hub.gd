class_name Hub
## Atlas hub addresses (SPEC §3): LAN primary, tailnet fallback. base_url is the winning base,
## set by main.gd's hub check; voice.gd / cad_bench.gd build their requests from it.

const CANDIDATES := ["http://192.168.4.51:8765", "http://100.65.202.81:8765"]
const SECRET_PATH := "res://hub_secret.cfg"   # gitignored; baked into the APK at export time (see builds/README.md)

static var base_url := ""

## Link state for the HUD (brief #8): real values only. "" until the boot hub check has run.
static var link := ""    # "LAN" | "TAILNET" | "LOCAL ONLY"
static var brain := ""   # "HERMES" when a hub answered, else "OFFLINE" (the hub owns the tier; we only know reachability)

static var _token := ""
static var _token_loaded := false

## Dev/test override (headless harness points the app at a local mock hub): HOLODECK_HUB=http://127.0.0.1:PORT.
## Never set on the headset, so the shipped candidate list is the only path there.
static func candidates() -> Array:
	var o := OS.get_environment("HOLODECK_HUB")
	return [o] if o != "" else CANDIDATES

## Bearer token for the token-gated hub routes (the same token the phone app is given). Read once from the
## gitignored hub_secret.cfg; "" if the file isn't in the build (then gated routes answer 401 and voice stays off).
static func token() -> String:
	if not _token_loaded:
		_token_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SECRET_PATH) == OK:
			_token = String(cfg.get_value("hub", "token", "")).strip_edges()
	return _token

static func auth_headers(extra: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var h := extra.duplicate()
	if token() != "":
		h.append("Authorization: Bearer " + token())
	return h

static func ws_url() -> String:
	return base_url.replace("http://", "ws://").replace("https://", "wss://") + "/atlas/voice-stream"

## LAN first, then tailnet. Sets base_url / link / brain on success (real values only). Never errors; false = local only.
static func probe(host: Node) -> bool:
	var labels := ["LAN", "TAILNET"]
	var cands := candidates()
	for i in cands.size():
		if await _status_ok(host, cands[i]):
			base_url = cands[i]
			link = labels[mini(i, 1)]
			brain = "HERMES"
			return true
	link = "LOCAL ONLY"
	brain = "OFFLINE"
	return false

static func _status_ok(host: Node, base: String) -> bool:
	var http := HTTPRequest.new()
	http.timeout = 2.0
	host.add_child(http)
	if http.request(base + "/atlas/status") != OK:
		http.queue_free()
		return false
	var res: Array = await http.request_completed
	http.queue_free()
	return res[0] == HTTPRequest.RESULT_SUCCESS and res[1] >= 200 and res[1] < 300

## POST a JSON body to a token-gated hub route -> {ok, code, body}. `ok` is HTTP 2xx; body is the parsed JSON (or {}).
static func post_json(host: Node, path: String, payload: Dictionary) -> Dictionary:
	if base_url == "":
		return {"ok": false, "code": 0, "body": {}}
	var http := HTTPRequest.new()
	http.timeout = 20.0
	host.add_child(http)
	var err := http.request(base_url + path, auth_headers(PackedStringArray(["Content-Type: application/json"])),
			HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "body": {}}
	var res: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"ok": res[0] == HTTPRequest.RESULT_SUCCESS and res[1] >= 200 and res[1] < 300, "code": res[1],
			"body": parsed if parsed is Dictionary else {}}
