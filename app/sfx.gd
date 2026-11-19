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

static func play(from: Node, cue: String) -> void:
	var s := from.get_tree().get_first_node_in_group("sfx")
	if s and s._players.has(cue):
		s._players[cue].play()
