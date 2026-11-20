extends Node3D
## One- and two-hand grab for a model, plus the table-plane work mode (SPEC §2 / §4, brief #15).
## Hands (XRController3D) call begin_grab/end_grab; while held this node follows them.
##  - Resting on the table, a one-hand grab is a PLANE drag: the model slides across the surface at table height and
##    turns with the hand's twist (yaw only). Lifting the hand clear of the surface (LIFT_OFF m) hands over to freehand.
##  - Freehand (and two-hand scale/rotate) follows the hand in 3D as before.
##  - Released over the table the model SETTLES back onto the surface (height eased down, tilt levelled, yaw kept);
##    released anywhere else it stays where it is. A plane drag released with speed carries: linear velocity (a flick)
##    and spin both decay smoothly (exponential friction); a flick that comes to rest away from the centre parks.
## All motion is driven by step(dt) so it can be exercised deterministically (tools/plane_test.gd).

signal flicked_aside(model: Node3D)

@export var grab_radius := 0.4  # metres from hand to model centre (scaled with the model)

const LIFT_OFF := 0.10          # m above the surface at which a plane drag becomes freehand
const FLICK_SPEED := 0.45       # m/s of release speed that counts as a flick (slides on)
const SLIDE_FRICTION := 3.2     # 1/s: linear velocity decays as exp(-k t)
const SPIN_FRICTION := 2.4      # 1/s: yaw rate decays as exp(-k t)
const STOP_SPEED := 0.02        # m/s: slide ends
const STOP_SPIN := 0.15         # rad/s: spin ends
const PARK_DISTANCE := 0.5      # m from table centre: a flick resting beyond this parks the model
const VEL_SMOOTH := 0.06        # s time constant of the release-velocity estimate
const SETTLE_TIME := 0.35

enum Mode { IDLE, PLANE, FREE, TWO_HAND, COAST, SETTLE }

var center_local := Vector3.ZERO  # model centre in local space; model.gd sets this
var mode: int = Mode.IDLE
var _hands: Array[Node3D] = []    # holding hands, in grab order
var _offset := Transform3D.IDENTITY  # one-hand: hand-space pose of the model (no scale)
var _mid_offset := Vector3.ZERO      # two-hand: model origin relative to hand midpoint
var _rot_offset := Basis.IDENTITY    # two-hand: model rotation in first hand's space
var _d0 := 1.0                       # hand distance at second-grab time
var _s0 := 1.0                       # model scale at second-grab time
# plane-drag state (table space)
var _yaw_off := 0.0                  # model yaw minus hand yaw at grab time
var _hand_off := Vector2.ZERO        # model xz minus hand xz at grab time
var _vel := Vector2.ZERO             # smoothed plane velocity, m/s (table space)
var _spin := 0.0                     # smoothed yaw rate, rad/s
var _prev_pos := Vector2.ZERO
var _prev_yaw := 0.0
var _have_prev := false
var _settle_t := 0.0
var _settle_from := Transform3D.IDENTITY
var _flicked := false

func _ready() -> void:
	add_to_group("grabbable")
	set_process(false)

func can_grab(hand: Node3D) -> bool:
	return hand.global_position.distance_to(global_transform * center_local) <= grab_radius * maxf(scale.x, 1.0)

## True when a table node is the parent (models live under the HoloTable).
func _table() -> Node3D:
	var p := get_parent()
	return p if p is HoloTable else null

func on_surface() -> bool:
	return _table() != null and absf(position.y - HoloTable.TOP_Y) < 0.02

func over_table() -> bool:
	return _table() != null and absf(position.x) <= HoloTable.SETTLE_HALF.x and absf(position.z) <= HoloTable.SETTLE_HALF.y \
			and position.y < HoloTable.TOP_Y + 0.6

func begin_grab(hand: Node3D) -> void:
	if hand in _hands or _hands.size() >= 2:
		return
	_hands.append(hand)
	_recapture()
	if hand.has_method("buzz"):
		hand.buzz(0.03, 0.5)  # R2-1: grab confirmed in the grabbing hand

func end_grab(hand: Node3D) -> void:
	_hands.erase(hand)
	_recapture()
	if hand.has_method("buzz"):
		hand.buzz(0.02, 0.3)  # R2-1: soft release tick (settle / coast / stay)

func _recapture() -> void:
	if _hands.size() == 1:
		var plain := Transform3D(global_basis.orthonormalized(), global_position)
		_offset = _hands[0].global_transform.affine_inverse() * plain
		var hl := _to_table(_hands[0].global_position)
		_hand_off = Vector2(position.x - hl.x, position.z - hl.z)
		_yaw_off = rotation.y - _hand_yaw(_hands[0])
		_have_prev = false
		_vel = Vector2.ZERO
		_spin = 0.0
		mode = Mode.PLANE if (on_surface() or mode == Mode.COAST and over_table()) else Mode.FREE
		_flicked = false
	elif _hands.size() == 2:
		var a := _hands[0].global_position
		var b := _hands[1].global_position
		_d0 = maxf(a.distance_to(b), 0.01)
		_s0 = scale.x
		_mid_offset = global_position - (a + b) * 0.5
		_rot_offset = _hands[0].global_basis.orthonormalized().inverse() * global_basis.orthonormalized()
		mode = Mode.TWO_HAND
	else:
		_release()
		return
	set_process(true)

func _to_table(world: Vector3) -> Vector3:
	var t := _table()
	return t.to_local(world) if t else world

func _hand_yaw(hand: Node3D) -> float:
	var f := -hand.global_basis.z
	var t := _table()
	if t:
		f = t.global_basis.inverse() * f
	return atan2(-f.x, -f.z)

func _process(delta: float) -> void:
	step(delta)

func step(dt: float) -> void:
	match mode:
		Mode.PLANE: _step_plane(dt)
		Mode.FREE: _step_free()
		Mode.TWO_HAND: _step_two_hand()
		Mode.COAST: _step_coast(dt)
		Mode.SETTLE: _step_settle(dt)
		_: set_process(false)

func _step_free() -> void:
	var t := _hands[0].global_transform * _offset
	global_transform = Transform3D(t.basis * Basis.from_scale(Vector3.ONE * scale.x), t.origin)

func _step_two_hand() -> void:
	var a := _hands[0].global_position
	var b := _hands[1].global_position
	var s := clampf(_s0 * a.distance_to(b) / _d0, 0.2, 6.0)
	var basis := _hands[0].global_basis.orthonormalized() * _rot_offset
	global_transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * s),
			(a + b) * 0.5 + _mid_offset * (s / _s0))

func _step_plane(dt: float) -> void:
	var free := _table().to_local((_hands[0].global_transform * _offset).origin)
	if free.y - HoloTable.TOP_Y > LIFT_OFF:        # hand left the surface: freehand takes over
		mode = Mode.FREE
		_step_free()
		return
	var hl := _to_table(_hands[0].global_position)
	var target := Vector2(hl.x, hl.z) + _hand_off
	target = Vector2(clampf(target.x, -HoloTable.PLANE_HALF.x, HoloTable.PLANE_HALF.x),
			clampf(target.y, -HoloTable.PLANE_HALF.y, HoloTable.PLANE_HALF.y))
	var yaw := _hand_yaw(_hands[0]) + _yaw_off
	position = Vector3(target.x, HoloTable.TOP_Y, target.y)
	rotation = Vector3(0.0, yaw, 0.0)
	if _have_prev and dt > 0.0:
		var k := 1.0 - exp(-dt / VEL_SMOOTH)
		_vel = _vel.lerp((target - _prev_pos) / dt, k)
		_spin = lerpf(_spin, wrapf(yaw - _prev_yaw, -PI, PI) / dt, k)
	_prev_pos = target
	_prev_yaw = yaw
	_have_prev = true

## All hands let go. Plane drag -> coast on the release velocity; anything over the table -> settle; else stay.
func _release() -> void:
	set_process(false)
	var was := mode
	if was == Mode.PLANE and (_vel.length() > FLICK_SPEED or absf(_spin) > STOP_SPIN * 2.0):
		_flicked = _vel.length() > FLICK_SPEED
		if not _flicked:
			_vel = Vector2.ZERO          # spin only: it turns in place
		mode = Mode.COAST
		set_process(true)
	elif over_table():
		_start_settle()
	else:
		mode = Mode.IDLE

func _step_coast(dt: float) -> void:
	var f := exp(-SLIDE_FRICTION * dt)
	_vel *= f
	_spin *= exp(-SPIN_FRICTION * dt)
	var p := Vector2(position.x, position.z) + _vel * dt
	var cl := Vector2(clampf(p.x, -HoloTable.PLANE_HALF.x, HoloTable.PLANE_HALF.x),
			clampf(p.y, -HoloTable.PLANE_HALF.y, HoloTable.PLANE_HALF.y))
	if cl != p:
		_vel = Vector2.ZERO              # met the edge of the inset: stops there
	position = Vector3(cl.x, HoloTable.TOP_Y, cl.y)
	rotation.y += _spin * dt
	if _vel.length() < STOP_SPEED and absf(_spin) < STOP_SPIN:
		mode = Mode.IDLE
		set_process(false)
		if _flicked and Vector2(position.x, position.z).length() > PARK_DISTANCE:
			_flicked = false
			flicked_aside.emit(self)

func _start_settle() -> void:
	mode = Mode.SETTLE
	_settle_t = 0.0
	_settle_from = Transform3D(basis, position)
	set_process(true)

## Ease the height down to the surface and level pitch/roll (yaw kept); scale untouched.
func _step_settle(dt: float) -> void:
	_settle_t = minf(_settle_t + dt, SETTLE_TIME)
	var k := _settle_t / SETTLE_TIME
	k = 1.0 - pow(1.0 - k, 3.0)
	var s := scale
	var from_pos := _settle_from.origin
	var yaw := _settle_from.basis.orthonormalized().get_euler().y
	var from_q := _settle_from.basis.orthonormalized().get_rotation_quaternion()
	var to_q := Quaternion(Vector3.UP, yaw)
	position = Vector3(from_pos.x, lerpf(from_pos.y, HoloTable.TOP_Y, k), from_pos.z)
	basis = Basis(from_q.slerp(to_q, k)) * Basis.from_scale(s)
	if _settle_t >= SETTLE_TIME:
		mode = Mode.IDLE
		set_process(false)
