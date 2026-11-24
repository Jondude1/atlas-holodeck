class_name LocoRig
extends Node
## Round 5B — locomotion, built the way a VR engineer builds it: this rig owns the
## XROrigin. Left stick = smooth move (head-relative, smoothed accel, 1.7 m/s cap);
## right stick X = 30° snap turn PIVOTING ON THE HEAD (the origin is repositioned so the
## camera's world spot does not swing). Collision is analytic — no physics bodies: the
## body point (the head's XZ) is clamped into a union of walkable rectangles (room, the
## open-wall doorway, the terrace) with axis-separated sliding, then pushed out of
## obstacle rectangles/circles (table, bench, station, shelves, suit pads).
## Panel priority: while either hand's ray is on the UI panel, that hand's stick belongs
## to the panel (hand.gd's scroll) and the rig ignores it.
## The rig never touches the fallback camera, so simulator tools are unaffected; with no
## controllers connected the stick reads are zero and the rig is inert.

const SPEED := 1.7
const ACCEL := 10.0              # velocity smoothing (1/s)
const DEADZONE := 0.15
const TURN_DEG := 30.0
const TURN_TRIGGER := 0.7
const TURN_REARM := 0.35
const TURN_CD := 0.28

# walkable union (x0, z0, x1, z1), already inset by the body radius
const AREAS := [
	[-3.72, -4.72, 3.72, 2.72],        # the room
	[-2.65, -5.35, 2.65, -4.6],        # the doorway in the BACK wall — the only bridge out
	[-3.72, -8.05, 3.72, -4.95],       # the terrace beyond it
]
# obstacle rectangles (x0, z0, x1, z1), expanded by the body radius
const BLOCKS := [
	[-1.55, -2.5, 1.55, -0.6],         # the holo table
	[3.1, -4.55, 3.85, -0.45],         # the right bench slab
	[-3.85, -4.55, -3.1, -0.45],       # the left bench slab
]
# obstacle circles (x, z, r): the suit platforms flanking the opening
const PADS := [[-2.95, -4.15, 0.82], [2.95, -4.15, 0.82]]

var _origin: XROrigin3D
var _cam: XRCamera3D
var _left: XRController3D
var _right: XRController3D
var _vel := Vector2.ZERO
var _turn_armed := true
var _turn_cd := 0.0

func setup(origin: XROrigin3D, cam: XRCamera3D, left: XRController3D, right: XRController3D) -> void:
	_origin = origin
	_cam = cam
	_left = left
	_right = right
	set_process(true)

func _process(dt: float) -> void:
	if _origin == null or _cam == null:
		return
	_turn_cd = maxf(0.0, _turn_cd - dt)
	# --- move (left stick, unless the left hand's ray owns it for the panel)
	var stick := Vector2.ZERO
	if _left and not _claimed(_left):
		stick = _left.get_vector2("primary")
	if stick.length() < DEADZONE:
		stick = Vector2.ZERO
	var fwd3 := -_cam.global_transform.basis.z
	var right3 := _cam.global_transform.basis.x
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var right := Vector2(right3.x, right3.z).normalized()
	var want := (right * stick.x + fwd * -stick.y) * SPEED
	_vel = _vel.lerp(want, clampf(ACCEL * dt, 0.0, 1.0))
	if _vel.length() > 0.003:
		apply_move(Vector3(_vel.x, 0, _vel.y) * dt)
	# --- snap turn (right stick X, unless the right hand's ray owns it)
	if _right and not _claimed(_right):
		var tx: float = _right.get_vector2("primary").x
		if _turn_armed and _turn_cd <= 0.0 and absf(tx) > TURN_TRIGGER:
			apply_turn(deg_to_rad(-TURN_DEG) * signf(tx))
			_turn_armed = false
			_turn_cd = TURN_CD
		elif absf(tx) < TURN_REARM:
			_turn_armed = true

func _claimed(hand: XRController3D) -> bool:
	return hand.has_method("stick_claimed") and bool(hand.call("stick_claimed"))

func head_xz() -> Vector2:
	var p := _cam.global_position
	return Vector2(p.x, p.z)

## Move the origin by a world-space delta, clamped so the HEAD stays in the walkable
## union and out of the obstacles. Axis-separated: a blocked axis slides along the other.
func apply_move(delta: Vector3) -> void:
	var head := head_xz()
	var target := head + Vector2(delta.x, delta.z)
	if not _free(target):
		if _free(Vector2(target.x, head.y)):
			target = Vector2(target.x, head.y)
		elif _free(Vector2(head.x, target.y)):
			target = Vector2(head.x, target.y)
		else:
			return
	target = _push_out(target)
	var applied := target - head
	_origin.global_position += Vector3(applied.x, 0, applied.y)

## Rotate the world around the head: the camera's world position is invariant.
func apply_turn(angle: float) -> void:
	var pivot := _cam.global_position
	pivot.y = _origin.global_position.y
	var off := _origin.global_position - pivot
	off = off.rotated(Vector3.UP, angle)
	_origin.global_position = pivot + off
	_origin.rotate_y(angle)

func _free(p: Vector2) -> bool:
	var inside := false
	for a in AREAS:
		if p.x >= a[0] and p.x <= a[2] and p.y >= a[1] and p.y <= a[3]:
			inside = true
			break
	if not inside:
		return false
	for b in BLOCKS:
		if p.x > b[0] and p.x < b[2] and p.y > b[1] and p.y < b[3]:
			return false
	for c in PADS:
		if p.distance_to(Vector2(c[0], c[1])) < c[2]:
			return false
	return true

## When a slide lands the body inside an obstacle's skin (corner cases), push out along
## the smallest penetration so the rig can never tunnel into the furniture.
func _push_out(p: Vector2) -> Vector2:
	for b in BLOCKS:
		if p.x > b[0] and p.x < b[2] and p.y > b[1] and p.y < b[3]:
			var dxl: float = p.x - float(b[0])
			var dxr: float = float(b[2]) - p.x
			var dzl: float = p.y - float(b[1])
			var dzr: float = float(b[3]) - p.y
			var m: float = minf(minf(dxl, dxr), minf(dzl, dzr))
			if m == dxl:
				p.x = b[0]
			elif m == dxr:
				p.x = b[2]
			elif m == dzl:
				p.y = b[1]
			else:
				p.y = b[3]
	for c in PADS:
		var c0 := Vector2(c[0], c[1])
		var d := p.distance_to(c0)
		if d < c[2] and d > 0.0001:
			p = c0 + (p - c0) / d * c[2]
	return p
