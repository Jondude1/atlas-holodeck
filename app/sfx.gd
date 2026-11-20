class_name Sfx
extends Node
## Tiny sound helper: one AudioStreamPlayer per cue, found through the "sfx" group so any
## node can call Sfx.play(self, "tick"). Cues are generated WAVs (tools/gen_sounds.py) plus
## the two pre-rendered voice lines.

const CUES := {
	"tick": ["res://sounds/tick.wav", -16.0],
	"confirm": ["res://sounds/confirm.wav", -12.0],
	"grab": ["res://sounds/grab.wav", -14.0],
	"boot": ["res://sounds/boot.wav", -14.0],
	"wake": ["res://sounds/wake.wav", -11.0],      # voice: listening opened (wake word or PTT)
	"end": ["res://sounds/end.wav", -12.0],        # voice: utterance closed
	"greeting": ["res://sounds/greeting.mp3", -6.0],
	"confirm_render": ["res://sounds/confirm_render.mp3", -6.0],
}

var _players := {}

func _ready() -> void:
	add_to_group("sfx")
	for cue in CUES:
		var p := AudioStreamPlayer.new()
		p.stream = load(CUES[cue][0])
		p.volume_db = CUES[cue][1]
		add_child(p)
		_players[cue] = p

## Plays a cue and waits until it finishes (no-op if the cue is unknown).
## The wait is DEADLINE-CAPPED (clip length + 1.5 s): awaiting the raw
## `finished` signal hung forever under a windowed dummy-audio run
## (round1b exercise, 2026-11-20) — a missed signal must never stall boot.
static func play_and_wait(from: Node, cue: String) -> void:
	var s := from.get_tree().get_first_node_in_group("sfx")
	if s and s._players.has(cue):
		var p: AudioStreamPlayer = s._players[cue]
		p.play()
		var len := 2.0
		if p.stream:
			len = p.stream.get_length()
		var t_end := Time.get_ticks_msec() + int((len + 1.5) * 1000.0)
		while p.playing and Time.get_ticks_msec() < t_end:
			await from.get_tree().process_frame

static func play(from: Node, cue: String) -> void:
	var s := from.get_tree().get_first_node_in_group("sfx")
	if s and s._players.has(cue):
		s._players[cue].play()
