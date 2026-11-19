extends "res://model.gd"
## The working trebuchet (SPEC §3): loads cad/trebuchet.glb + manifest, then drives it with a
## kinematic state machine -- no physics engine. Parts stay a flat list (the CAD export is flat);
## the animation groups come from the manifest "pivot" block and are applied as per-part pose
## deltas on top of the home (cocked) transform:
##   arm (ThrowingArm)  rotates about the axle
##   hanger (box, blocks, hinge pin)  hangs from the arm's short end, pendulum-swings
##   sling (rope, pouch, stone)  verlet point at the pouch rim, rope-length constrained to the tip
##   pin (ReleasePin)  slides up to release; cocking rope stretches tip -> pin ring
## States: REST -> COCKING -> COCKED -> FIRING -> SETTLING -> REST (+ RESETTING back to REST).
## Frame: model space = glTF Y-up metres, x forward (throw direction), y up, sim plane z = 0.

signal state_changed(state: int)
signal weight_changed
signal stone_landed(distance_m: float)

enum State { REST, COCKING, COCKED, FIRING, SETTLING, RESETTING }
enum StoneMode { HOME, ATTACHED, FLIGHT, GONE }

const MODEL_PATH := "res://models/trebuchet.glb"
const MANIFEST_PATH := "res://models/trebuchet.manifest.json"
const IN := 0.0254
const DISPLAY_FIT_M := 0.75        # longest horizontal true dimension is fitted to this on the inset

# -- tuning ------------------------------------------------------------------------------------
## THE RELEASE TUNING KNOB. Arm elevation (degrees above +X, long end) at which the sling lets go
## of the stone. The arm sweeps from 230 (cocked) down through 90 (vertical) to 65 (rest), so
## release EARLIER = a LARGER number (arm still leaning back, sling not yet whipped forward:
## lower, flatter throw); release LATER = a SMALLER number (arm past vertical: loftier throw). Like bending the pin on a real
## kit: nudge it a few degrees, fire, look at the arc. Same lever for all block counts.
const RELEASE_ANGLE_DEG := 115.0
const SLING_LEAD_DEG := 8.0         # the sling lets go slightly ahead of the bare tip direction
const GRAVITY := 18.0              # m/s^2 in table space (model-scale arcs, "across the table")
## Counterweight -> throw. Nominal touchdown distance (world metres, release point -> first
## contact) for n blocks: RANGE_MAX - (RANGE_MAX - RANGE_1_BLOCK) * RANGE_FALLOFF^(n-1). Diminishing
## returns (a real arm can't use all the extra mass), and it keeps even a 6-block throw on the
## 2.2 m inset (the stone is released ~0.9 m left of table centre, so 1.9 m still touches down
## inside the far edge at x = +1.1).
const RANGE_1_BLOCK := 0.70
const RANGE_MAX := 3.0
const RANGE_FALLOFF := 0.867       # 1 block 0.70 m, 4 blocks 1.50 m, 6 blocks 1.87 m
const LAUNCH_ELEV_MIN_DEG := 20.0  # launch direction = the arm tip's direction at release (arm angle
const LAUNCH_ELEV_MAX_DEG := 60.0  # minus 90) + SLING_LEAD_DEG, clamped so no tweak gives a skyward/flat shot
const COCK_TIME := 1.2
const COCK_TICK_DEG := 9.0         # ratchet tick every this many degrees of winch travel
const PIN_TIME := 0.25
const FIRE_ACCEL_TIME := 1.2       # pin pull -> release at 4 blocks (heavier = faster)
const FIRE_TIME_PER_BLOCK := 0.05  # fractional change of FIRE_ACCEL_TIME per block from 4
const SETTLE_MIN_TIME := 1.0
const RESET_ARM_TIME := 1.0
const SPARE_BLEND_TIME := 0.45
const SUBSTEP := 1.0 / 240.0
const HANGER_DAMP := 1.6           # 1/s, pendulum damping (x2.5 while SETTLING)
const SLING_DAMP := 0.6            # 1/s
const MAX_BLOCKS := 6
const STONE_HALF_H := 0.6          # inches: resting height of the stone's centre on the table
const STONE_REST_TIME := 2.0       # seconds after landing before the stone fades
const STONE_FADE_TIME := 0.5
const PIN_PICK_RADIUS := 0.09      # metres (world) around the pin ring for laser / hand selection

var state: int = State.REST
var blocks := 4
var auto_tick := true              # the headless exercise sets false and calls advance() itself
var release_angle_deg := RELEASE_ANGLE_DEG  # runtime copy (exercise sweeps it); the const is the shipped value
var last_landing_m := -1.0         # horizontal distance release -> first touchdown, world metres
var last_release_world := Vector3.ZERO
var last_launch_speed := 0.0
var last_launch_elev_deg := 0.0
var last_raw_elev_deg := 0.0       # sling direction before the clamp
var manifest := {}

var _piv := {}                     # manifest "pivot" block
var _kind := {}                    # part name -> group kind
var _part_by_name := {}
var _spare_blend := []             # per block: 0 = in the box, 1 = parked on the table
var _g_per_block := 0.0

# geometry (model space, metres)
var _A := Vector3.ZERO             # axle
var _H0 := Vector3.ZERO            # hinge, home (cocked) pose
var _E0 := Vector3.ZERO            # arm tip sling eye, home
var _Q0 := Vector3.ZERO            # pouch rim attach, home
var _S0 := Vector3.ZERO            # stone centre, home
var _R0 := Vector3.ZERO            # pin ring, home
var _RC0 := Vector3.ZERO           # cocking rope's pin end, home
var _e_cocked := 230.0
var _e_rest := 65.0
var _sling_len := 0.1778
var _hang_len := 0.0889
var _floor_q := 0.0

# sim state
var _e := 65.0                     # arm elevation, degrees
var _phi := 0.0                    # hanger swing angle from straight down (rad, CCW about +Z)
var _phi_v := 0.0
var _hinge_prev := Vector3.ZERO
var _hinge_v := Vector3.ZERO
var _hinge_a := Vector3.ZERO
var _Q := Vector3.ZERO
var _Qp := Vector3.ZERO
var _pin := 1.0                    # 0 = home (inserted) .. 1 = pulled
var _pin_from := 1.0
var _rope_attached := false
var _t := 0.0                      # time in the current state
var _e_from := 65.0
var _tick_acc := 0.0
var _released := false
var _omega_r := 0.0                # deg/s at release
var _t_b := 0.0                    # carry-through duration after release
var _t_a := FIRE_ACCEL_TIME
var _t_release := 0.0
var _stone_mode: int = StoneMode.HOME
var _sp := Vector3.ZERO
var _sv := Vector3.ZERO
var _spin := 0.0
var _bounces := 0
var _since_land := -1.0
var _stone_alpha := 1.0
var _release_x := 0.0
var _last_us := 0
var _xf := {}                      # per-frame group transforms

static func c2m(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1]) * IN

func _ready() -> void:
	_load_manifest()
	_load_glb()
	_init_sim()
	for i in MAX_BLOCKS:   # bounds / footprint / dimensions are measured with every block in the box
		_spare_blend[i] = 0.0
	super()
	_part_by_name.clear()
	for p in _parts:
		_part_by_name[String(p.name)] = p
	for i in MAX_BLOCKS:
		_spare_blend[i] = 0.0 if i < blocks else 1.0
	_apply_pose()
	_last_us = Time.get_ticks_usec()
	get_tree().process_frame.connect(_on_frame)

# ---------------------------------------------------------------------------------- loading
func _load_manifest() -> void:
	var txt := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	assert(parsed is Dictionary, "trebuchet manifest missing or invalid: " + MANIFEST_PATH)
	manifest = parsed
	_piv = manifest["pivot"]
	_A = c2m(_piv["axle"])
	_H0 = c2m(_piv["hinge"])
	_E0 = c2m(_piv["arm_tip_eye"])
	_Q0 = c2m(_piv["pouch_attach"])
	_S0 = c2m(_piv["stone_home"])
	_R0 = c2m(_piv["pin_ring"])
	_RC0 = _R0 + Vector3(-0.15, -0.1, 0.0) * IN
	_e_cocked = float(_piv["arm_cocked_angle_deg"])   # 230: long end down-back; firing sweeps 230 -> 65 clockwise, up and over the rear
	_e_rest = float(_piv["arm_rest_angle_deg"])
	_sling_len = float(_piv["sling_length_in"]) * IN
	_hang_len = float(_piv["cw_hang_in"]) * IN
	_floor_q = _Q0.y
	_g_per_block = float(_piv.get("counterweight_g_per_block", 0.0))
	for grp in _piv["groups"]:
		for n in _piv["groups"][grp]:
			_kind[n] = grp
	_kind["SlingRope"] = "Rope"
	_kind["SlingPouch"] = "Pouch"
	_kind["Stone"] = "Stone"
	var tdi: Array = manifest["true_dims_in"]
	base_scale = DISPLAY_FIT_M / (float(tdi[0]) * IN)
	scale = Vector3.ONE * base_scale
	for i in MAX_BLOCKS:
		_spare_blend.append(0.0 if i < blocks else 1.0)

func _load_glb() -> void:
	var inst: Node = null
	var res: Resource = load(MODEL_PATH)
	if res is PackedScene:
		inst = (res as PackedScene).instantiate()
	else:   # dev fallback: not yet imported by the editor
		var doc := GLTFDocument.new()
		var gst := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(MODEL_PATH), gst) == OK:
			inst = doc.generate_scene(gst)
	assert(inst != null, "trebuchet.glb failed to load")
	var found := {}
	_collect_meshes(inst, found)
	for part in manifest["parts"]:
		var n: String = part["name"]
		assert(found.has(n), "GLB is missing manifest part " + n)
		var mi: MeshInstance3D = found[n]
		var xf := _rel_xf(mi, inst)
		mi.get_parent().remove_child(mi)
		mi.owner = null
		add_child(mi)
		mi.name = n
		mi.transform = xf
	inst.free()

func _rel_xf(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _collect_meshes(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D:
		out[String(n.name)] = n
	for c in n.get_children():
		_collect_meshes(c, out)

func _make_material(_p: MeshInstance3D) -> ShaderMaterial:
	return Fx.mesh_part_material()

# ---------------------------------------------------------------------------------- geometry
func _rz(a: float) -> Basis:
	return Basis(Vector3.BACK, a)

func _about(pivot: Vector3, ang: float) -> Transform3D:
	var b := _rz(ang)
	return Transform3D(b, pivot - b * pivot)

func _arm_pt(home_pt: Vector3, e_deg: float) -> Vector3:
	return _A + _rz(deg_to_rad(e_deg - _e_cocked)) * (home_pt - _A)

func _tip(e_deg: float) -> Vector3:
	return _arm_pt(_E0, e_deg)

func _hinge(e_deg: float) -> Vector3:
	return _arm_pt(_H0, e_deg)

func _g_local() -> float:
	return GRAVITY / maxf(scale.x, 0.01)

## Home rope chord (a -> b, in the cocked pose) mapped onto the current chord (c -> d): rotate +
## stretch along the chord only, so the rope thins nowhere and just lengthens / swings.
func _chord_xf(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Transform3D:
	var d0 := b - a
	var d1 := d - c
	if d0.length() < 1e-6:
		return Transform3D.IDENTITY
	var u := d0.normalized()
	var k := d1.length() / d0.length()
	var s := Basis(Vector3(1.0 + (k - 1.0) * u.x * u.x, (k - 1.0) * u.x * u.y, 0.0),
			Vector3((k - 1.0) * u.x * u.y, 1.0 + (k - 1.0) * u.y * u.y, 0.0), Vector3.BACK)
	var lin := _rz(atan2(d1.y, d1.x) - atan2(d0.y, d0.x)) * s
	return Transform3D(lin, c - lin * a)

## Spare blocks wait in a row on the table beside the machine (player side), one fixed slot per
## block so a block never shuffles when the count changes. Returns the delta from its home centre.
func _spare_target(i: int, home_center: Vector3) -> Vector3:
	return c2m([(i - (MAX_BLOCKS - 1) * 0.5) * 3.8, -5.6, 0.25]) - home_center

func _compute_xf() -> void:
	var arm := _about(_A, deg_to_rad(_e - _e_cocked))
	var hp := _hinge(_e)
	var hb := _rz(_phi)
	var hanger := Transform3D(hb, hp - hb * _H0)
	var tip := _tip(_e)
	var rope := _chord_xf(_E0, _Q0, tip, _Q)
	var psi := atan2(_Q.y - tip.y, _Q.x - tip.x) - atan2(_Q0.y - _E0.y, _Q0.x - _E0.x)
	var pb := _rz(psi)
	var pouch := Transform3D(pb, _Q - pb * _Q0)
	var pin_lift := Vector3.UP * (_pin * float(_piv["pin_travel_in"]) * IN)
	_xf = {"ArmPivot": arm, "Hanger": hanger, "Rope": rope, "Pouch": pouch, "Pin": Transform3D(Basis.IDENTITY, pin_lift),
			"CockingRope": _chord_xf(_E0, _RC0, tip, _RC0 + pin_lift)}

func _pose(p: MeshInstance3D) -> Transform3D:
	var n := String(p.name)
	var kind: String = _kind.get(n, "")
	if kind == "Stone":
		match _stone_mode:
			StoneMode.ATTACHED:
				return _xf["Pouch"]
			StoneMode.FLIGHT:
				var sb := _rz(_spin)
				return Transform3D(sb, _sp - sb * _S0)
		return Transform3D.IDENTITY
	if kind == "Hanger" and n.begins_with("WeightBlock"):
		var i := int(n.substr(11)) - 1
		var s: float = _spare_blend[i]
		if s <= 0.0:
			return _xf["Hanger"]
		var table := Transform3D(Basis.IDENTITY, _spare_target(i, _home_box(p).get_center()))
		var xf: Transform3D = (_xf["Hanger"] as Transform3D).interpolate_with(table, s)
		xf.origin += Vector3.UP * (0.16 * sin(PI * s))
		return xf
	return _xf.get(kind, Transform3D.IDENTITY)

func _apply_pose() -> void:
	_compute_xf()
	super()
	_update_dynamic_visibility()

func _update_dynamic_visibility() -> void:
	if _part_by_name.is_empty():
		return
	var shown := _schematic != null and _schematic.visible
	var stone: MeshInstance3D = _part_by_name["Stone"]
	stone.visible = shown and _stone_mode != StoneMode.GONE
	var cr: MeshInstance3D = _part_by_name["CockingRope"]
	var chord := (_RC0 - _E0).length()
	var cur := ((_RC0 + Vector3.UP * (_pin * float(_piv["pin_travel_in"]) * IN)) - _tip(_e)).length()
	cr.visible = shown and _rope_attached and cur < chord * 1.5

func _part_visible(p: MeshInstance3D) -> bool:
	if String(p.name) == "Stone":
		return _stone_mode != StoneMode.GONE
	if String(p.name) == "CockingRope":
		return _rope_attached
	return true

# ---------------------------------------------------------------------------------- sim init
func _init_sim() -> void:
	state = State.REST
	_e = _e_rest
	_e_from = _e
	_phi = 0.0
	_phi_v = 0.0
	_pin = 1.0
	_rope_attached = false
	_stone_mode = StoneMode.HOME
	_hinge_prev = _hinge(_e)
	_hinge_v = Vector3.ZERO
	_hinge_a = Vector3.ZERO
	_Q = _tip(_e) + Vector3(0.0, -_sling_len, 0.0)
	_Qp = _Q
	for i in MAX_BLOCKS:
		_spare_blend[i] = 0.0 if i < blocks else 1.0

# ---------------------------------------------------------------------------------- control API
func can_cock() -> bool:
	return state == State.REST

func can_fire() -> bool:
	return state == State.COCKED

func can_reset() -> bool:
	return state == State.REST or state == State.COCKED

func can_weight() -> bool:
	return state == State.REST or state == State.COCKED

func is_busy() -> bool:   # explode / scale controls lock while the machine is throwing
	return state == State.FIRING or state == State.SETTLING

func weight_text() -> String:
	return "WEIGHT — %d BLOCK%s · %d G" % [blocks, "" if blocks == 1 else "S", roundi(blocks * _g_per_block)]

func true_dims() -> Array:
	return manifest.get("true_dims_in", [])

func cock() -> bool:
	if not can_cock():
		return false
	if _stone_mode != StoneMode.HOME:
		_fresh_stone()
	_set_state_to(State.COCKING)
	_e_from = _e
	_rope_attached = true
	_tick_acc = 0.0
	return true

func fire() -> bool:
	if not can_fire():
		return false
	_released = false
	_t_a = FIRE_ACCEL_TIME * (1.0 - FIRE_TIME_PER_BLOCK * (blocks - 4))
	var span := release_angle_deg - _e_cocked
	_omega_r = 2.0 * span / _t_a
	_t_b = 2.0 * (_e_rest - release_angle_deg) / _omega_r
	_stone_mode = StoneMode.ATTACHED
	_set_state_to(State.FIRING)
	return true

func reset() -> bool:
	if not can_reset():
		return false
	if _stone_mode != StoneMode.HOME or _stone_alpha < 1.0:
		_fresh_stone()
	_e_from = _e
	_pin_from = _pin
	_set_state_to(State.RESETTING)
	return true

func weight_up() -> bool:
	return _set_blocks(blocks + 1)

func weight_down() -> bool:
	return _set_blocks(blocks - 1)

func _set_blocks(n: int) -> bool:
	if not can_weight() or n < 1 or n > MAX_BLOCKS or n == blocks:
		return false
	blocks = n
	weight_changed.emit()
	return true

## Pin selected by the laser trigger or a hand grab: pulling it fires a cocked machine.
func pin_select() -> void:
	Sfx.play(self, "grab")
	if can_fire():
		Sfx.play(self, "confirm")
		fire()

func pin_world() -> Vector3:
	return global_transform * (_R0 + Vector3.UP * (_pin * float(_piv["pin_travel_in"]) * IN))

## World ray vs the pin ring: generous radius so a laser can find a 1 cm part.
func pin_ray_hit(origin: Vector3, dir: Vector3) -> bool:
	if not visible or not _schematic.visible:
		return false
	var c := pin_world()
	var t := maxf((c - origin).dot(dir), 0.0)
	return (origin + dir * t).distance_to(c) <= PIN_PICK_RADIUS * maxf(scale.x / base_scale, 0.5)

func pin_near(point: Vector3) -> bool:
	return _schematic.visible and point.distance_to(pin_world()) <= PIN_PICK_RADIUS

func _set_state_to(s: int) -> void:
	state = s
	_t = 0.0
	state_changed.emit(s)

func _fresh_stone() -> void:
	_stone_mode = StoneMode.HOME
	_stone_alpha = 0.0
	_since_land = -1.0
	_bounces = 0

# ---------------------------------------------------------------------------------- stepping
func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) * 1e-6 * Engine.time_scale, 0.1)
	_last_us = now
	if auto_tick:
		advance(dt)

## Advance the machine by dt seconds of simulated time (fixed SUBSTEP internally).
func advance(dt: float) -> void:
	var left := dt
	while left > 1e-9:
		var h := minf(SUBSTEP, left)
		left -= h
		_step(h)
	_apply_pose()

func _step(h: float) -> void:
	_t += h
	_drive_arm(h)
	_step_hanger(h)
	_step_sling(h)
	_step_stone(h)
	_step_blocks(h)
	if _stone_alpha < 1.0 and _stone_mode == StoneMode.HOME:
		_stone_alpha = minf(_stone_alpha + h / 0.4, 1.0)
		_set_stone_alpha(_stone_alpha)

func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)

func _drive_arm(h: float) -> void:
	match state:
		State.COCKING:
			var u := clampf(_t / COCK_TIME, 0.0, 1.0)
			var prev := _e
			_e = lerpf(_e_from, _e_cocked, _ease(u))
			_tick_acc += absf(_e - prev)
			while _tick_acc >= COCK_TICK_DEG:
				_tick_acc -= COCK_TICK_DEG
				Sfx.play(self, "tick")
			_pin = 1.0 - _ease(clampf((u - 0.78) / 0.22, 0.0, 1.0))
			if u >= 1.0:
				_e = _e_cocked
				_pin = 0.0
				_Q = _Q0
				_Qp = _Q0
				_set_state_to(State.COCKED)
		State.COCKED:
			_e = _e_cocked
		State.FIRING:
			_pin = clampf(_t / PIN_TIME, 0.0, 1.0)
			if _pin >= 0.5:
				_rope_attached = false
			var ta := _t - PIN_TIME
			if ta > 0.0:
				var u := clampf(ta / _t_a, 0.0, 1.0)
				_e = _e_cocked + (release_angle_deg - _e_cocked) * u * u
				if u >= 1.0:
					_e = release_angle_deg
					_release()
		State.SETTLING:
			var tb := minf(_t, _t_b)
			_e = release_angle_deg + _omega_r * tb - _omega_r * tb * tb / (2.0 * _t_b)
			if _t >= maxf(_t_b, SETTLE_MIN_TIME):
				_e = _e_rest
				_set_state_to(State.REST)
		State.RESETTING:
			_pin = lerpf(_pin_from, 1.0, clampf(_t / PIN_TIME, 0.0, 1.0))
			var u := clampf((_t - PIN_TIME) / RESET_ARM_TIME, 0.0, 1.0)
			_e = lerpf(_e_from, _e_rest, _ease(u))
			if u >= 1.0 and _t >= PIN_TIME + RESET_ARM_TIME:
				_e = _e_rest
				_set_state_to(State.REST)
		State.REST:
			_e = _e_rest

func _step_hanger(h: float) -> void:
	var hp := _hinge(_e)
	var v := (hp - _hinge_prev) / h
	var a := (v - _hinge_v) / h
	_hinge_prev = hp
	_hinge_v = v
	_hinge_a = _hinge_a.lerp(a, 0.25)
	var g := _g_local()
	var damp := HANGER_DAMP * (2.5 if state == State.SETTLING else 1.0)
	var acc := (-(g + _hinge_a.y) * sin(_phi) - _hinge_a.x * cos(_phi)) / _hang_len - damp * _phi_v
	_phi_v += acc * h
	_phi += _phi_v * h
	if absf(_phi) > 1.3:
		_phi = signf(_phi) * 1.3
		_phi_v = 0.0

func _step_sling(h: float) -> void:
	if state == State.COCKED:
		_Q = _Q0
		_Qp = _Q0
		return
	var tip := _tip(_e)
	var vel := (_Q - _Qp) * (1.0 - SLING_DAMP * h)
	_Qp = _Q
	_Q += vel + Vector3(0.0, -_g_local(), 0.0) * h * h
	var d := _Q - tip
	if d.length() > _sling_len:
		_Q = tip + d.normalized() * _sling_len
	if _Q.y < _floor_q:
		_Q.y = _floor_q
		_Qp.x = _Q.x - (_Q.x - _Qp.x) * 0.8   # dragging along the table: friction
	if state == State.COCKING:   # last stretch of the winch: the pouch is led onto its mark
		var u := clampf(_t / COCK_TIME, 0.0, 1.0)
		var w := _ease(clampf((u - 0.85) / 0.15, 0.0, 1.0))
		_Q = _Q.lerp(_Q0, w)
		_Qp = _Qp.lerp(_Q0, w)

func _step_blocks(h: float) -> void:
	for i in MAX_BLOCKS:
		var target := 0.0 if i < blocks else 1.0
		_spare_blend[i] = move_toward(_spare_blend[i], target, h / SPARE_BLEND_TIME)

func _release() -> void:
	# Stone leaves the pouch: position from the pouch pose, direction from the arm tip at the
	# release angle, speed from the counterweight's block count (nominal_range). SPEC §3 approximation.
	var pose: Transform3D = _stone_pose_attached()
	_sp = pose * _S0
	var vq := (_Q - _Qp) / SUBSTEP
	last_raw_elev_deg = rad_to_deg(atan2(vq.y, absf(vq.x)))   # the sling's own direction (reported only)
	var elev := clampf(release_angle_deg - 90.0 + SLING_LEAD_DEG, LAUNCH_ELEV_MIN_DEG, LAUNCH_ELEV_MAX_DEG)
	var v0 := _launch_speed(elev, (_sp.y - STONE_HALF_H * IN) * scale.x)
	var v0_local := v0 / maxf(scale.x, 0.01)
	_sv = Vector3(cos(deg_to_rad(elev)), sin(deg_to_rad(elev)), 0.0) * v0_local
	_spin = 0.0
	_bounces = 0
	_since_land = -1.0
	_stone_alpha = 1.0
	_release_x = _sp.x
	last_release_world = global_transform * _sp
	last_launch_speed = v0
	last_launch_elev_deg = elev
	last_landing_m = -1.0
	_stone_mode = StoneMode.FLIGHT
	_released = true
	_set_stone_alpha(1.0)
	_set_state_to(State.SETTLING)

func nominal_range(n: int) -> float:
	return RANGE_MAX - (RANGE_MAX - RANGE_1_BLOCK) * pow(RANGE_FALLOFF, n - 1)

## Speed that lands the stone nominal_range(blocks) away, given the launch elevation and the
## release height above the table (world units): the ballistic range equation solved for v.
func _launch_speed(elev_deg: float, h0: float) -> float:
	var a := deg_to_rad(elev_deg)
	var r := nominal_range(blocks)
	return sqrt(GRAVITY * r * r / (2.0 * cos(a) * cos(a) * maxf(h0 + r * tan(a), 0.05)))

func _stone_pose_attached() -> Transform3D:
	_compute_xf()
	return _xf["Pouch"]

func _step_stone(h: float) -> void:
	if _stone_mode != StoneMode.FLIGHT:
		return
	var g := _g_local()
	var floor_y := STONE_HALF_H * IN
	_sv.y -= g * h
	_sp += _sv * h
	var r := 0.75 * IN
	if _since_land < 0.0:
		_spin -= _sv.x / r * h * 0.5   # tumbling in the air
	else:
		_spin -= _sv.x / r * h
	if _sp.y <= floor_y and _sv.y < 0.0:
		_sp.y = floor_y
		if _since_land < 0.0:
			_since_land = 0.0
			last_landing_m = (_sp.x - _release_x) * scale.x
			stone_landed.emit(last_landing_m)
		if _bounces < 1:
			_bounces += 1
			_sv.y = -_sv.y * 0.30
			_sv.x *= 0.55
		else:
			_sv.y = 0.0
			_sv.x = move_toward(_sv.x, 0.0, 1.2 * h * _sv.length() + 0.4 * h)
	if _since_land >= 0.0:
		_since_land += h
		if _since_land > STONE_REST_TIME:
			_stone_alpha = maxf(_stone_alpha - h / STONE_FADE_TIME, 0.0)
			_set_stone_alpha(_stone_alpha)
			if _stone_alpha <= 0.0:
				_stone_mode = StoneMode.GONE

func _set_stone_alpha(a: float) -> void:
	var i := _parts.find(_part_by_name["Stone"])
	if i >= 0:
		_mats[i].set_shader_parameter("wire", a)

## Exercise hook: explode + labels with the machine in any state must not error.
func explode_probe() -> void:
	set_explode(1.0)
	_apply_pose()
	set_explode(0.0)
	_apply_pose()
