class_name VoiceLink
extends Node
## Voice conversation (brief #11). Owns the microphone, the hub voice socket, the speech playback and the voice
## state machine. Atlas standing rule: explicit, indicated, logged.
##
##   MIC LIVE  <=> PCM frames are actually leaving the headset (state ARMED or LISTENING, socket open, not muted).
##   Every other state (MUTED, OFFLINE, NO MIC PERMISSION, THINKING, SPEAKING) sends nothing, and says so.
##   Every state change is logged ("[VOICE] t+ms ...") and mirrored by the hub in its own session log.
##
## Protocol with the hub (atlas_voice.py): binary frames = PCM16 16 kHz mono; JSON text frames both ways.
##   client -> hub:  {"event":"ptt_start"} / {"event":"ptt_end"}
##   hub -> client:  ready / wake / utterance_end / transcript / reply / cad_job / cad_done / cad_failed / idle / error
## Replies are spoken through POST /atlas/speak (Kokoro, the phone's voice) on a spatial player at the panel.
## If the hub is unreachable nothing hangs and nothing errors: state OFFLINE, the recorded greeting/lines stay.

enum S { OFFLINE, MUTED, NO_PERMISSION, ARMED, LISTENING, THINKING, SPEAKING }

signal state_changed(state: int)
signal heard(text: String)               # the user's transcribed words
signal said(text: String)                # Atlas's reply text (also shown as a subtitle)
signal cad_job(job_id: String, text: String)
signal cad_done(job_id: String)
signal cad_failed(job_id: String, detail: String)
signal print_request(ev: Dictionary)      # the hub heard "send it to the printer": opens the confirmation (never starts a print)
signal print_confirm(job_id: String)      # a spoken yes that the hub matched to a pending print request
signal print_cancel(job_id: String)

const MIC_BUS := "HoloMic"
const TARGET_RATE := 16000.0
const SEND_BYTES := 1920                 # 60 ms of PCM16 per websocket frame
const CONNECT_TIMEOUT := 8.0
const RETRY_STEPS := [3.0, 6.0, 12.0, 20.0]
const SPEAK_TIMEOUT := 25.0
const READ_SECONDS_PER_WORD := 0.35      # reading time when speech audio is unavailable

var state: int = S.OFFLINE
var muted := false
var wake_ok := true                      # false when the hub's keyword spotter is unavailable (PTT still works)
## Wake word ("Atlas") is EXPERIMENTAL and OFF: push-to-talk is the primary way to talk (Jon's 2026-11-19 addendum). With it off
## the mic is not captured and nothing is streamed except while a hold is down. Not proven end to end -> stays off.
var wake_enabled := false
var subtitle := ""
var mic_level := 0.0                     # 0..1 smoothed input level of what is being streamed (HUD orb)

var _ws: WebSocketPeer
var _ws_state := -1
var _ws_t0 := 0.0
var _ws_ready := false                   # the hub's "ready" event arrived on this socket
var _retry_i := 0
var _retry_at := 0.0
var _probing := false
var _capture: AudioEffectCapture
var _mic: AudioStreamPlayer
var _speaker: AudioStreamPlayer3D
var _carry := PackedFloat32Array()
var _pos := 0.0
var _out := PackedByteArray()
var _mix_rate := 48000.0
var _permission := false
var _started := false
var _tts_busy := false
var _speech_queue: Array[String] = []
var _speech_gen := 0                     # bumps to cancel an in-flight utterance (barge-in)
var _ptt := false
var _t0 := 0

func _log(msg: String) -> void:
	print("[VOICE] t+%dms %s" % [Time.get_ticks_msec() - _t0, msg])

func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("voice")
	_setup_audio()

## Places the spatial speaker at the panel (voices come from where the UI is).
func attach_speaker(at: Node3D) -> void:
	_speaker = AudioStreamPlayer3D.new()
	_speaker.name = "AtlasVoice"
	_speaker.unit_size = 2.5
	_speaker.max_distance = 12.0
	_speaker.volume_db = 2.0
	at.add_child(_speaker)

func _setup_audio() -> void:
	var idx := AudioServer.get_bus_index(MIC_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, MIC_BUS)
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture)
		var hush := AudioEffectAmplify.new()    # after the capture tap: the mic is never played back into the room
		hush.volume_db = -80.0
		AudioServer.add_bus_effect(idx, hush)
	else:
		_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_mix_rate = AudioServer.get_mix_rate()
	_mic = AudioStreamPlayer.new()
	_mic.name = "Mic"
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = MIC_BUS
	add_child(_mic)

# ---------------------------------------------------------------- lifecycle

## Called once the boot hub check has run. Requests the mic permission (Android) then opens the socket.
func start() -> void:
	if _started:
		return
	_started = true
	_permission = await _ensure_permission()
	if not _permission:
		_set_state(S.NO_PERMISSION)
		_log("RECORD_AUDIO not granted - voice off (the panel's MIC button asks again)")
		return
	_connect_or_wait()

func _ensure_permission() -> bool:
	if OS.get_name() != "Android":
		return true
	if OS.request_permission("RECORD_AUDIO"):
		return true
	_log("requesting RECORD_AUDIO")
	var tree := get_tree()
	while true:
		var res: Array = await tree.on_request_permissions_result
		if String(res[0]).ends_with("RECORD_AUDIO"):
			return bool(res[1])
	return false

func set_muted(m: bool) -> void:
	if m == muted:
		return
	muted = m
	_log("voice %s by panel control" % ("MUTED" if m else "UNMUTED"))
	if m:
		_close_socket("muted")
		_mic.stop()
		_ptt = false
		_set_state(S.MUTED)
	else:
		if not _permission:
			_started = false
			start()
		else:
			_connect_or_wait()

## Panel MIC control: mutes, or re-asks for permission / reconnects.
func toggle_muted() -> void:
	set_muted(not muted)

func is_streaming() -> bool:
	if not _ws_ready or muted:
		return false
	if wake_enabled:
		return state == S.ARMED or state == S.LISTENING
	return state == S.LISTENING and _ptt        # PTT-only: the mic is live strictly while a hold is down

func set_wake_enabled(on: bool) -> void:
	wake_enabled = on
	_log("wake word %s (experimental)" % ("ENABLED" if on else "off - push-to-talk only"))
	state_changed.emit(state)

func state_text() -> String:
	match state:
		S.ARMED: return "MIC LIVE" if wake_enabled else "MIC OFF - HOLD TO TALK"
		S.LISTENING: return "LISTENING"
		S.THINKING: return "THINKING"
		S.SPEAKING: return "SPEAKING"
		S.MUTED: return "MIC OFF"
		S.NO_PERMISSION: return "MIC BLOCKED"
		_: return "VOICE OFFLINE"

func _set_state(s: int) -> void:
	if s == state:
		return
	_log("state %s -> %s (mic streaming: %s)" % [S.keys()[state], S.keys()[s], "YES" if _ws_ready and not muted and ((wake_enabled and (s == S.ARMED or s == S.LISTENING)) or (s == S.LISTENING and _ptt)) else "no"])
	state = s
	state_changed.emit(s)

func _set_subtitle(t: String) -> void:
	subtitle = t

# ---------------------------------------------------------------- socket

func _connect_or_wait() -> void:
	if muted or not _permission:
		return
	if Hub.base_url != "":
		_open_socket()
	else:
		_set_state(S.OFFLINE)
		_schedule_retry()

func _schedule_retry() -> void:
	_retry_at = Time.get_ticks_msec() / 1000.0 + RETRY_STEPS[mini(_retry_i, RETRY_STEPS.size() - 1)]
	_retry_i += 1

func _open_socket() -> void:
	_ws = WebSocketPeer.new()
	_ws.handshake_headers = Hub.auth_headers()
	_ws.outbound_buffer_size = 1 << 18
	var err := _ws.connect_to_url(Hub.ws_url())
	_ws_t0 = Time.get_ticks_msec() / 1000.0
	_ws_ready = false
	_ws_state = WebSocketPeer.STATE_CONNECTING
	_log("socket connecting %s (%s)" % [Hub.ws_url(), "ok" if err == OK else "error %d" % err])
	if err != OK:
		_ws = null
		_set_state(S.OFFLINE)
		_schedule_retry()

func _close_socket(why: String) -> void:
	if _ws:
		_ws.close(1000, why)
		_ws = null
	_ws_ready = false
	_ws_state = -1
	_out.clear()
	_carry.clear()
	_pos = 0.0

func _on_socket_lost(why: String) -> void:
	_log("socket lost: %s" % why)
	_ws = null
	_ws_ready = false
	_ws_state = -1
	_ptt = false
	if not muted:
		if not _tts_busy:
			_set_state(S.OFFLINE)
		_schedule_retry()

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _ws:
		_ws.poll()
		var st := _ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			if _ws_state != WebSocketPeer.STATE_OPEN:
				_ws_state = WebSocketPeer.STATE_OPEN
				_retry_i = 0
				_log("socket open - waiting for the hub's ready")
				if not _mic.playing:
					_mic.play()
			while _ws.get_available_packet_count() > 0:
				var pkt := _ws.get_packet()
				if _ws.was_string_packet():
					_on_event(JSON.parse_string(pkt.get_string_from_utf8()))
		elif st == WebSocketPeer.STATE_CLOSED:
			_on_socket_lost("closed code %d" % _ws.get_close_code())
		elif st == WebSocketPeer.STATE_CONNECTING and now - _ws_t0 > CONNECT_TIMEOUT:
			_ws.close()
			_on_socket_lost("connect timeout")
	elif not muted and _permission and _retry_at > 0.0 and now >= _retry_at and not _probing:
		_retry_at = 0.0
		_probe_then_open()
	_sync_mic()
	_pump_mic()
	mic_level = lerpf(mic_level, 0.0, clampf(delta * 6.0, 0.0, 1.0))

## Hub not reachable yet (or dropped): re-run the LAN-then-tailnet probe, then reconnect. Never blocks anything.
func _probe_then_open() -> void:
	_probing = true
	var ok: bool = await Hub.probe(self)
	_probing = false
	if muted:
		return
	if ok:
		_open_socket()
	else:
		_set_state(S.OFFLINE)
		_schedule_retry()

# ---------------------------------------------------------------- hub events

func _on_event(ev: Variant) -> void:
	if not (ev is Dictionary):
		return
	match String(ev.get("event", "")):
		"ready":
			_ws_ready = true
			wake_ok = bool(ev.get("wake", true))
			_log("hub ready (wake spotter %s, ptt %s)" % ["on" if wake_ok else "OFF", ev.get("ptt", true)])
			if state != S.SPEAKING and state != S.THINKING:
				_set_state(S.ARMED)
		"wake":
			_ptt = ev.get("source", "") == "ptt"
			_log("wake (%s)%s" % [ev.get("source", "?"), " follow-up" if ev.get("followup", false) else ""])
			if not ev.get("followup", false):
				Sfx.play(self, "wake")
			_set_subtitle("LISTENING…")
			_set_state(S.LISTENING)
		"utterance_end":
			_log("utterance end (%s, %.2f s)" % [ev.get("why", "?"), float(ev.get("seconds", 0.0))])
			Sfx.play(self, "end")
			_ptt = false
			_set_state(S.THINKING)
			_set_subtitle("…")
		"transcript":
			var t := String(ev.get("text", ""))
			_log("transcript: %s" % t)
			if t != "":
				_set_subtitle("YOU — " + t)
				heard.emit(t)
		"reply":
			var r := String(ev.get("text", ""))
			_log("reply (%s): %s" % [ev.get("kind", "?"), r])
			say(r)
		"cad_job":
			_log("CAD job accepted: %s" % ev.get("job_id", "?"))
			cad_job.emit(String(ev.get("job_id", "")), String(ev.get("text", "")))
		"cad_done":
			_log("CAD job done: %s" % ev.get("job_id", "?"))
			cad_done.emit(String(ev.get("job_id", "")))
		"cad_failed":
			_log("CAD job failed: %s" % ev.get("detail", "?"))
			cad_failed.emit(String(ev.get("job_id", "")), String(ev.get("detail", "")))
		"print_request":
			_log("print request: %s (%s)" % [ev.get("job_id", "?"), ev.get("est_text", "?")])
			print_request.emit(ev)
		"print_confirm":
			_log("spoken confirm: %s" % ev.get("job_id", "?"))
			print_confirm.emit(String(ev.get("job_id", "")))
		"print_cancel":
			_log("spoken cancel: %s" % ev.get("job_id", "?"))
			print_cancel.emit(String(ev.get("job_id", "")))
		"idle":
			if not _tts_busy and (state == S.LISTENING or state == S.THINKING):
				_ptt = false
				if ev.get("reason", "") == "no_speech":
					_set_subtitle("")
				elif ev.get("reason", "") == "empty":
					_set_subtitle("(didn't catch that)")
				_set_state(S.ARMED if _ws_ready else S.OFFLINE)
		"error":
			_log("hub error: %s" % ev.get("detail", "?"))
			if not _tts_busy:
				_set_subtitle("(something went wrong on my side)")
				_set_state(S.ARMED if _ws_ready else S.OFFLINE)

# ---------------------------------------------------------------- microphone

## The OS microphone is captured only while audio is actually being streamed (so "mic off" is true at the device level too).
func _sync_mic() -> void:
	var want := is_streaming()
	if want and not _mic.playing:
		_mic.play()
		_log("microphone capture ON")
	elif not want and _mic.playing:
		_mic.stop()
		_log("microphone capture OFF")

func _pump_mic() -> void:
	if _capture == null:
		return
	var n := _capture.get_frames_available()
	if n <= 0:
		return
	var frames := _capture.get_buffer(n)
	if not is_streaming():
		return                              # drained and dropped: nothing leaves the headset
	var mono := PackedFloat32Array()
	mono.resize(frames.size())
	var peak := 0.0
	for i in frames.size():
		var v := (frames[i].x + frames[i].y) * 0.5
		mono[i] = v
		peak = maxf(peak, absf(v))
	mic_level = maxf(mic_level, minf(peak * 3.0, 1.0))
	_carry.append_array(mono)
	var ratio := _mix_rate / TARGET_RATE
	var produced := PackedFloat32Array()
	while _pos + ratio <= _carry.size():
		var a := int(_pos)
		var b := maxi(int(_pos + ratio), a + 1)
		var acc := 0.0
		for j in range(a, b):
			acc += _carry[j]
		produced.append(acc / float(b - a))
		_pos += ratio
	var used := int(_pos)
	if used > 0:
		_carry = _carry.slice(used)
		_pos -= used
	var off := _out.size()
	_out.resize(off + produced.size() * 2)
	for k in produced.size():
		_out.encode_s16(off + k * 2, clampi(int(produced[k] * 32767.0), -32768, 32767))
	while _out.size() >= SEND_BYTES and _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send(_out.slice(0, SEND_BYTES))
		_out = _out.slice(SEND_BYTES)

# ---------------------------------------------------------------- push to talk

## Hold begins (panel TALK button or controller trigger): open an utterance directly (same pipeline, same tones). Needs the mic live.
func ptt_begin() -> void:
	if muted or not _ws_ready:
		return
	if state == S.SPEAKING:
		interrupt_speech()                      # barge-in: talking over Atlas cuts the reply off
		_set_state(S.ARMED)
	if state != S.ARMED and state != S.LISTENING:
		return
	_ptt = true
	_out.clear()
	_log("PTT down")
	_ws.send_text(JSON.stringify({"event": "ptt_start"}))
	Sfx.play(self, "wake")
	_set_subtitle("LISTENING…")
	_set_state(S.LISTENING)

## Small control messages to the hub on the open socket (print_pending / print_clear). False when the socket is down.
func hub_event(ev: Dictionary) -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	_ws.send_text(JSON.stringify(ev))
	return true

func ptt_end() -> void:
	if not _ptt or not _ws_ready:
		return
	_ptt = false
	_log("PTT up")
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not _out.is_empty():
		_ws.send(_out)                       # the tail of what was said before release
		_out.clear()
	if _ws:
		_ws.send_text(JSON.stringify({"event": "ptt_end"}))
	_set_state(S.THINKING)                   # stop streaming right now; the hub's utterance_end confirms

# ---------------------------------------------------------------- speech out

## Speaks text through the hub's Kokoro voice. Returns when it has finished (or its reading time is up).
## Speech that arrives while speaking is queued; the mic is NOT streaming while Atlas talks.
func say(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	_set_subtitle("ATLAS — " + text)
	said.emit(text)
	_speech_queue.append(text)
	if _tts_busy:
		return
	_tts_busy = true
	var gen := _speech_gen
	while not _speech_queue.is_empty() and gen == _speech_gen:
		var t: String = _speech_queue.pop_front()
		_set_state(S.SPEAKING)
		await _speak_one(t, gen)
	if gen == _speech_gen:
		_tts_busy = false
		_after_speech()

func interrupt_speech() -> void:
	_speech_gen += 1
	_speech_queue.clear()
	_tts_busy = false
	if _speaker:
		_speaker.stop()

func _after_speech() -> void:
	if muted:
		_set_state(S.MUTED)
	elif _ws_ready:
		_set_state(S.ARMED)
	else:
		_set_state(S.OFFLINE)

func _speak_one(text: String, gen: int) -> void:
	var audio := await _fetch_speech(text)
	if gen != _speech_gen:
		return
	if audio.is_empty() or _speaker == null:
		# hub/TTS unreachable: degrade to the build's recorded behaviour - a chime and the text on screen
		_log("TTS unavailable - showing text with a chime")
		Sfx.play(self, "confirm")
		await get_tree().create_timer(clampf(text.split(" ").size() * READ_SECONDS_PER_WORD, 1.5, 7.0)).timeout
		return
	var mp3 := AudioStreamMP3.new()
	mp3.data = audio
	_speaker.stream = mp3
	_speaker.play()
	var t_end := Time.get_ticks_msec() + int((mp3.get_length() + 1.0) * 1000.0)
	while _speaker.playing and gen == _speech_gen and Time.get_ticks_msec() < t_end + int(SPEAK_TIMEOUT * 1000.0):
		await get_tree().process_frame

func _fetch_speech(text: String) -> PackedByteArray:
	if Hub.base_url == "":
		return PackedByteArray()
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(Hub.base_url + "/atlas/speak", Hub.auth_headers(PackedStringArray(["Content-Type: application/json"])),
			HTTPClient.METHOD_POST, JSON.stringify({"text": text}))
	if err != OK:
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_log("speak -> HTTP %s / result %s" % [res[1], res[0]])
		return PackedByteArray()
	return res[3]

# ---------------------------------------------------------------- test hooks (capture / headless harness)

## Forces a state for the capture harness (shows what LISTENING looks like without a hub).
func debug_force(s: int, text := "") -> void:
	if text != "":
		_set_subtitle(text)
	_set_state(s)
