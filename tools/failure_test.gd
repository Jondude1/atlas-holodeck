extends SceneTree
## Headless proof (NOT shipped): hub failure details -> one sanitized spoken sentence.
func _initialize() -> void:
	var cases := [
		["failed acceptance after 3 attempts: Traceback (most recent call last):\n  File \"C:\\work\\scripts\\voicecad\\job_ab12cd34ef.py\", line 41, in <module>\nValueError: minimum wall thickness 0.4 mm is below the 0.8 mm printable limit", "minimum wall"],
		["no code writer answered", "CAD writer"],
		["upload to Athena failed: ssh: connect to host 192.168.1.50 port 22: Connection timed out", "didn't answer"],
		["fetching model.glb failed: scp: /work/out/voicecad/a8b6d50939/model.glb: No such file", "files"],
		["runner exited 1 with no output", "returned nothing"],
		["failed acceptance after 3 attempts: RESULT {\"ok\": false, \"error\": \"solid is not watertight (2 open edges)\"}", "watertight"],
		["", ""],
		["failed acceptance after 3 attempts: \n  ^\n", "geometry checks"],
	]
	var bad := 0
	for c in cases:
		var line := FailureReason.spoken(c[0])
		var ok: bool = line.contains(c[1]) and not line.contains("/") and not line.contains("\\") and not line.contains("Traceback") \
				and not line.contains("job_") and line.length() < 260 and line.count(". ") <= 1
		if c[0] == "":
			ok = line == FailureReason.GENERIC
		print("FAILSAY %s len=%d -> \"%s\"" % ["ok" if ok else "FAIL", line.length(), line])
		if not ok:
			bad += 1
	var long_r := FailureReason.reason("failed acceptance after 3 attempts: " + "wall ".repeat(150))
	var cap_ok := long_r.length() <= FailureReason.MAX_REASON and long_r.length() > 40
	print("FAILSAY %s length cap: reason is %d chars (max %d)" % ["ok" if cap_ok else "FAIL", long_r.length(), FailureReason.MAX_REASON])
	bad += 0 if cap_ok else 1
	print("FAILURE_TEST ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(bad)
