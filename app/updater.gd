extends Node
## Autoload: the headset updates itself. Every push to main makes GitHub Actions build a signed APK and publish
## it as a GitHub Release (see .github/workflows/release.yml). This node checks the public repo's latest release,
## downloads its APK into the app's private storage and hands it to Android's package installer, so Jon never has
## to sideload a new build by hand. Logs to logcat as "[UPDATE]".
##
## Quest notes: the first install asks once for "Install unknown apps" for Atlas Holodeck (Android settings
## panel); after that each update is one confirm in the system installer. Only builds signed with the committed
## release key (keystore/atlas-holodeck.jks) can update each other, so a local debug-key build can't update into
## a release build without one uninstall.

signal state_changed(state: int)
signal progress_changed(fraction: float)

enum S { IDLE, CHECKING, UP_TO_DATE, AVAILABLE, DOWNLOADING, READY, NEEDS_PERMISSION, FAILED }

const LATEST_URL := "https://api.github.com/repos/Jondude1/atlas-holodeck/releases/latest"
const UA := "User-Agent: AtlasHolodeck-updater"
const UPDATE_DIR := "user://updates"
const FIRST_CHECK_DELAY_S := 20.0      # let XR, the hub check and the boot sequence settle first
const AUTO_CHECK_EVERY_S := 1800.0     # quiet re-check at most every 30 minutes (GitHub allows 60/hour unauthenticated)
const INSTALL_PERMISSION := "android.permission.REQUEST_INSTALL_PACKAGES"

var state := S.IDLE
var latest_version := ""   # e.g. "2.14" (the release tag without the leading v)
var latest_code := 0
var reason := ""           # short, panel-sized text for FAILED / NEEDS_PERMISSION
var progress := 0.0

var _apk_url := ""
var _apk_size := 0
var _apk_path := ""
var _check: HTTPRequest
var _dl: HTTPRequest
var _since_check := 0.0
var _first_done := false
var _auto_after_check := false
var _last_progress_emit := -1.0

func _ready() -> void:
	_check = HTTPRequest.new()
	_check.use_threads = true
	_check.timeout = 20.0
	_check.request_completed.connect(_on_check_done)
	add_child(_check)
	_dl = HTTPRequest.new()
	_dl.use_threads = true            # an ~85 MB download must not hitch the headset's frame
	_dl.download_chunk_size = 262144
	_dl.max_redirects = 10            # GitHub redirects asset downloads to its CDN host
	_dl.request_completed.connect(_on_download_done)
	add_child(_dl)
	_log("installed v%s (code %d)%s" % [installed_version(), installed_code(), "" if auto_enabled() else " - auto-check off (local/dev build)"])

## The version CI stamped into project.godot ("2.<n>"); local builds say "2.1-dev".
func installed_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))

## Trailing number of the version = the release number n = the APK versionCode. 0 for local/dev builds.
func installed_code() -> int:
	return code_of(installed_version())

static func code_of(v: String) -> int:
	var m := RegEx.create_from_string("(\\d+)\\s*$").search(v)
	return int(m.get_string(1)) if m else 0

## Only CI release builds on the headset check by themselves; anyone can still press CHECK.
func auto_enabled() -> bool:
	return OS.has_feature("android") and installed_code() > 0

func _process(delta: float) -> void:
	if state == S.DOWNLOADING:
		var total := _dl.get_body_size()
		if total > 0:
			progress = clampf(float(_dl.get_downloaded_bytes()) / float(total), 0.0, 1.0)
			if progress - _last_progress_emit >= 0.01:
				_last_progress_emit = progress
				progress_changed.emit(progress)
	if not auto_enabled():
		return
	_since_check += delta
	var due := FIRST_CHECK_DELAY_S if not _first_done else AUTO_CHECK_EVERY_S
	if _since_check >= due and state in [S.IDLE, S.UP_TO_DATE, S.FAILED]:
		_first_done = true
		check()

func _notification(what: int) -> void:
	# Back from the Android settings panel or the installer: re-check soon (a finished install restarts the app anyway).
	if what == NOTIFICATION_APPLICATION_RESUMED and auto_enabled() and _first_done and state in [S.UP_TO_DATE, S.FAILED]:
		_since_check = maxf(_since_check, AUTO_CHECK_EVERY_S - 5.0)

## The panel's one button: does the next sensible thing for the current state.
func press() -> void:
	match state:
		S.AVAILABLE:
			download()
		S.READY, S.NEEDS_PERMISSION:
			install()
		S.CHECKING, S.DOWNLOADING:
			pass
		_:
			check()

func check() -> void:
	if state == S.CHECKING or state == S.DOWNLOADING:
		return
	_since_check = 0.0
	_set_state(S.CHECKING)
	var err := _check.request(LATEST_URL, PackedStringArray([UA, "Accept: application/vnd.github+json"]))
	if err != OK:
		_fail("NO NETWORK", "check request failed to start (%d)" % err)

func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("CAN'T REACH GITHUB", "check failed, result %d" % result)
		return
	if code == 404:
		_fail("NO RELEASES YET", "releases/latest answered 404 (no release, or the repo is private)")
		return
	if code != 200:
		_fail("GITHUB HTTP %d" % code, "check answered HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_fail("BAD RELEASE DATA", "release JSON didn't parse")
		return
	var tag := String(data.get("tag_name", ""))
	latest_version = tag.trim_prefix("v")
	latest_code = code_of(tag)
	_apk_url = ""
	var apk_name := ""
	for a in data.get("assets", []):
		var nm := String(a.get("name", ""))
		if nm.to_lower().ends_with(".apk"):
			_apk_url = String(a.get("browser_download_url", ""))
			_apk_size = int(a.get("size", 0))
			apk_name = nm.validate_filename()
			break
	if latest_code <= installed_code():
		_clear_downloads()
		_log("up to date (installed %d, latest %s)" % [installed_code(), tag])
		_set_state(S.UP_TO_DATE)
		return
	if _apk_url == "":
		_fail("NO APK IN RELEASE", "release %s has no .apk asset" % tag)
		return
	_apk_path = UPDATE_DIR.path_join(apk_name)
	_log("update available: %s (installed %d)" % [tag, installed_code()])
	if FileAccess.file_exists(_apk_path) and FileAccess.get_size(_apk_path) == _apk_size:
		_set_state(S.READY)          # already downloaded earlier; one press installs it
	else:
		_set_state(S.AVAILABLE)

func download() -> void:
	if _apk_url == "" or state == S.DOWNLOADING:
		return
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_clear_downloads()
	progress = 0.0
	_last_progress_emit = -1.0
	_dl.download_file = _apk_path + ".part"   # renamed only once complete, so a killed download is never "ready"
	_set_state(S.DOWNLOADING)
	var err := _dl.request(_apk_url, PackedStringArray([UA]))
	if err != OK:
		_fail("DOWNLOAD FAILED", "download request failed to start (%d)" % err)

func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var part := _apk_path + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(part) \
			or (_apk_size > 0 and FileAccess.get_size(part) != _apk_size):
		_clear_downloads()
		_fail("DOWNLOAD FAILED", "download failed, result %d HTTP %d" % [result, code])
		return
	DirAccess.rename_absolute(part, _apk_path)
	progress = 1.0
	progress_changed.emit(progress)
	_log("downloaded %s (%d bytes)" % [_apk_path, FileAccess.get_size(_apk_path)])
	_set_state(S.READY)
	install()

## Hands the APK to Android's installer (Godot opens absolute paths through its own FileProvider with read access
## granted). The first time, Android needs "Install unknown apps" allowed for this app: request_permission opens that
## settings page and returns false; Jon flips it and presses INSTALL again.
func install() -> void:
	if not FileAccess.file_exists(_apk_path):
		_set_state(S.AVAILABLE if _apk_url != "" else S.IDLE)
		return
	if not OS.has_feature("android"):
		_fail("INSTALL ON HEADSET", "install only works on Android")
		return
	if not OS.request_permission(INSTALL_PERMISSION):
		reason = "ALLOW, THEN INSTALL"
		_log("asked Android for install-unknown-apps permission")
		_set_state(S.NEEDS_PERMISSION)
		return
	var err := OS.shell_open(ProjectSettings.globalize_path(_apk_path))
	if err != OK:
		_fail("INSTALLER DIDN'T OPEN", "shell_open on the APK returned %d" % err)
		return
	_log("installer opened for %s" % _apk_path)
	_set_state(S.READY)

func _clear_downloads() -> void:
	var d := DirAccess.open(UPDATE_DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.to_lower().ends_with(".apk") or f.ends_with(".part"):
			d.remove(f)

func _fail(short: String, detail: String) -> void:
	reason = short
	_log("FAILED: " + detail)
	_set_state(S.FAILED)

func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)

func _log(msg: String) -> void:
	print("[UPDATE] " + msg)
