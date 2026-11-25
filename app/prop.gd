class_name Prop
extends Node3D
## Round 5B — a world prop (bench lamp, crates): the world-object sibling of Grabbable,
## same contract with hand.gd (group "grabbable", center_local, can_grab, begin/end_grab)
## but none of the table semantics: grab it, carry it anywhere, let go and it settles onto
## whatever support is under it (bench, table, suit pad, floor) and STAYS there.
## One hand follows with the captured offset; two hands also scale (0.4–2.2x).

var center_local := Vector3(0, 0.2, 0)
var grab_radius := 0.45

var _hands: Array[Node3D] = []
var _offset := Transform3D.IDENTITY
var _d0 := 0.0
var _s0 := 1.0
var _settle_to := -1.0        # target y while settling; -1 = not settling

func _ready() -> void:
	add_to_group("grabbable")
	set_process(false)

func can_grab(hand: Node3D) -> bool:
	return hand.global_position.distance_to(global_transform * center_local) <= grab_radius * maxf(scale.x, 1.0)

func begin_grab(hand: Node3D) -> void:
	if hand in _hands or _hands.size() >= 2:
		return
	_hands.append(hand)
	_settle_to = -1.0
	_recapture()
	if hand.has_method("buzz"):
		hand.buzz(0.03, 0.5)

func end_grab(hand: Node3D) -> void:
	_hands.erase(hand)
	if hand.has_method("buzz"):
		hand.buzz(0.02, 0.3)
	if _hands.size() == 1:
		_recapture()
	elif _hands.is_empty():
		_settle_to = support_height(global_position) 
		set_process(true)

func _recapture() -> void:
	if _hands.size() == 1:
		var plain := Transform3D(global_basis.orthonormalized(), global_position)
		_offset = _hands[0].global_transform.affine_inverse() * plain
	elif _hands.size() == 2:
		_d0 = maxf(_hands[0].global_position.distance_to(_hands[1].global_position), 0.01)
		_s0 = scale.x
		var mid := (_hands[0].global_position + _hands[1].global_position) * 0.5
		_offset = Transform3D(global_basis.orthonormalized(), global_position - mid)
	set_process(true)

func _process(dt: float) -> void:
	step(dt)

func step(dt: float) -> void:
	if _hands.size() == 1:
		var target := _hands[0].global_transform * _offset
		global_position = target.origin
		global_basis = target.basis
	elif _hands.size() == 2:
		var a := _hands[0].global_position
		var b := _hands[1].global_position
		var d: float = maxf(a.distance_to(b), 0.01)
		var s := clampf(_s0 * d / _d0, 0.4, 2.2)
		scale = Vector3.ONE * s
		global_position = (a + b) * 0.5 + _offset.origin
	elif _settle_to >= 0.0:
		# set down: ease the last few centimetres onto the support, then rest
		var y := global_position.y
		if y > _settle_to + 0.002:
			global_position.y = lerpf(y, _settle_to, clampf(dt * 7.0, 0.0, 1.0))
		else:
			global_position.y = _settle_to
			_settle_to = -1.0
			set_process(false)
			Sfx.play(self, "tap")   # R7-4: set down with a soft knock

## The resting height of a point in the room (world XZ in, support Y out). Mirrors the
## rig's furniture map: bench run, holo table, suit pads, else the floor.
static func support_height(p: Vector3) -> float:
	if absf(p.x) > 3.15 and absf(p.x) < 3.95 and p.z > -4.55 and p.z < -0.45:
		return 0.9475   # either bench slab
	if absf(p.x) <= 1.35 and p.z > -2.3 and p.z < -0.8:
		return 0.951   # HoloTable.TOP_Y
	for pad in [[-2.5, -4.3], [2.5, -4.3]]:
		if Vector2(p.x, p.z).distance_to(Vector2(pad[0], pad[1])) < 0.6:
			return 0.078
	return 0.0
