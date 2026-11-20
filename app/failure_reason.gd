class_name FailureReason
## Turns the hub's raw CAD-job failure detail (<= 400 chars of runner output / an exception string; atlas_voice.py
## run_job) into ONE speakable sentence. Never speaks paths, ids, URLs, tracebacks or JSON; falls back to the generic line.

const GENERIC := "I couldn't get that one to build. Try describing it a little differently."
const MAX_REASON := 120
const TRY_AGAIN := " Try describing it a little differently."

## Whole line Atlas says.
static func spoken(detail: String) -> String:
	var r := reason(detail)
	if r == "":
		return GENERIC
	return "I couldn't build that: %s.%s" % [r, TRY_AGAIN]

## The cleaned reason fragment (no trailing full stop), or "" when nothing speakable survives.
static func reason(detail: String) -> String:
	var d := detail.strip_edges()
	if d == "":
		return ""
	var low := d.to_lower()
	# the hub's own infrastructure failures: say what they mean, not the plumbing
	if low.contains("no code writer answered"):
		return "my CAD writer isn't answering right now"
	if low.contains("upload to athena failed"):
		return "the build machine didn't answer"
	if low.begins_with("fetching ") or low.contains("fetching model.glb failed") or low.contains("fetching manifest"):
		return "the finished files didn't come back from the build machine"
	if low.begins_with("runner exited") and low.contains("no output"):
		return "the build machine returned nothing"
	var body := d
	var i := low.find("failed acceptance after")
	if i >= 0:                                       # "...after 3 attempts: <runner output tail>"
		var c := d.find(":", i)
		body = d.substr(c + 1) if c >= 0 else ""
	var line := _best_line(body)
	line = _clean(line)
	if line.length() < 6:
		return "it failed the geometry checks" if i >= 0 else ""
	return line

## Last line that reads like a message: skips traceback frames, bare JSON results, code echo.
static func _best_line(body: String) -> String:
	var lines := body.replace("\r", "").split("\n", false)
	for k in range(lines.size() - 1, -1, -1):
		var l := lines[k].strip_edges()
		if l == "" or l.begins_with("File \"") or l.begins_with("Traceback") or l.begins_with("^") or l.begins_with("at "):
			continue
		if l.begins_with("RESULT "):
			var j: Variant = JSON.parse_string(l.substr(7))
			if j is Dictionary:
				for key in ["error", "reason", "message", "checks"]:
					if j.has(key) and str(j[key]).strip_edges() != "":
						return str(j[key]).strip_edges()
			continue
		if l.begins_with("{") or l.begins_with("[") or l.begins_with("("):
			continue
		return l
	return ""

static func _clean(s: String) -> String:
	var t := s
	for pat in [
		"[A-Za-z]:[\\\\/][^\\s'\"]*",           # windows paths
		"(?:/[\\w.\\-]+){2,}",                  # unix paths
		"https?://\\S+",
		"\\b[0-9a-f]{8,}\\b",                   # job / hash ids
		"0x[0-9a-fA-F]+",
		"\\bline \\d+\\b",
	]:
		var re := RegEx.create_from_string(pat)
		t = re.sub(t, "", true)
	# "ValueError: x" / "build123d.exceptions.Foo: x" / "RuntimeError(x)" -> "x"
	var re_exc := RegEx.create_from_string("^[\\w.]*(?:Error|Exception|Failure|Warning)\\s*[:(]\\s*")
	t = re_exc.sub(t, "")
	if t.count(")") > t.count("("):
		t = t.rstrip(")").strip_edges()
	for ch in ["`", "\"", "'", "\t"]:
		t = t.replace(ch, "")
	t = RegEx.create_from_string("\\s+").sub(t, " ", true).strip_edges()
	t = t.trim_suffix(".").trim_suffix(":").strip_edges()
	if t.length() > MAX_REASON:
		var cut := t.substr(0, MAX_REASON)
		var sp := cut.rfind(" ")
		t = cut.substr(0, sp if sp > 40 else MAX_REASON).strip_edges().trim_suffix(",")
	if t.length() > 1 and t[1] == t[1].to_lower() and t[0] != "I":
		t = t.substr(0, 1).to_lower() + t.substr(1)
	return t
