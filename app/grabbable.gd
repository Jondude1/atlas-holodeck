extends Node3D
## One- and two-hand grab for a model. Hands (XRController3D) call begin_grab/end_grab;
## while held, this node follows them every frame. Release = stay where it is.

@export var grab_radius := 0.4  # metres from hand to model centre (scaled with the model)

var center_local := Vector3.ZERO  # model centre in local space; model.gd sets this
var _hands: Array[Node3D] = []    # holding hands, in grab order
var _offset := Transform3D.IDENTITY  # one-hand: hand-space pose of the model (no scale)
var _mid_offset := Vector3.ZERO      # two-hand: model origin relative to hand midpoint
var _rot_offset := Basis.IDENTITY    # two-hand: model rotation in first hand's space
var _d0 := 1.0                       # hand distance at second-grab time
var _s0 := 1.0                       # model scale at second-grab time

func _ready() -> void:
	add_to_group("grabbable")

func can_grab(hand: Node3D) -> bool:
	return hand.global_position.distance_to(global_transform * center_local) <= grab_radius * maxf(scale.x, 1.0)

func begin_grab(hand: Node3D) -> void:
	if hand in _hands or _hands.size() >= 2:
		return
	_hands.append(hand)
	_recapture()

func end_grab(hand: Node3D) -> void:
	_hands.erase(hand)
	_recapture()

func _recapture() -> void:
	if _hands.size() == 1:
		var plain := Transform3D(global_basis.orthonormalized(), global_position)
		_offset = _hands[0].global_transform.affine_inverse() * plain
	elif _hands.size() == 2:
		var a := _hands[0].global_position
		var b := _hands[1].global_position
		_d0 = maxf(a.distance_to(b), 0.01)
		_s0 = scale.x
		_mid_offset = global_position - (a + b) * 0.5
		_rot_offset = _hands[0].global_basis.orthonormalized().inverse() * global_basis.orthonormalized()
	set_process(not _hands.is_empty())

func _process(_delta: float) -> void:
	if _hands.size() == 1:
		var t := _hands[0].global_transform * _offset
		global_transform = Transform3D(t.basis * Basis.from_scale(Vector3.ONE * scale.x), t.origin)
	elif _hands.size() == 2:
		var a := _hands[0].global_position
		var b := _hands[1].global_position
		var s := clampf(_s0 * a.distance_to(b) / _d0, 0.2, 6.0)
		var basis := _hands[0].global_basis.orthonormalized() * _rot_offset
		global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * s),
				(a + b) * 0.5 + _mid_offset * (s / _s0))
