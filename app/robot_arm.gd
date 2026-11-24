class_name RobotArm
extends Node3D
## R3-11: ONE original-design workshop arm on the right workbench, running a believable task loop —
## idle sway, reach to its parts tray, lift a part into the scanner beam, set it down, occasionally
## droop in a "sulk". Keyframed joint poses eased between states; no IK, no borrowed designs.
## Local frame: origin on the bench top, the arm works toward -X (into the room), +Y up.

const POSES := {
	"rest": Vector4(-30.0, 12.0, 30.0, -15.0),
	"tray": Vector4(5.0, 55.0, 12.0, 25.0),
	"lift": Vector4(5.0, 30.0, 30.0, 5.0),
	"scan": Vector4(46.0, 38.0, 22.0, 10.0),
	"sulk": Vector4(-5.0, 6.0, 58.0, -35.0),
}
# state: [pose, seconds in state]
const CYCLE: Array = [
	["rest", 5.0], ["tray", 1.7], ["tray", 0.5], ["lift", 1.2], ["scan", 2.6], ["lift", 1.1], ["tray", 1.4], ["tray", 0.5], ["rest", 2.0],
]

var _yaw: Node3D
var _shoulder: Node3D
var _elbow: Node3D
var _wrist: Node3D
var _held: MeshInstance3D
var _tray_part: MeshInstance3D
var _beam_mat: ShaderMaterial
var _beam: MeshInstance3D
var _ti_mats: Array[StandardMaterial3D] = []
var _pose := Vector4(-30.0, 12.0, 30.0, -15.0)
var _from := _pose
var _to := _pose
var _seg_t := 1.0
var _seg_dur := 1.0
var _state_i := 0
var _state_t := 0.0
var _cycles := 0
var _cur_name := "rest"
var _cur_dur := 5.0

func _ready() -> void:
	_build()
	_apply(_pose)

func _ti(k: float) -> StandardMaterial3D:
	var m := Fx.titanium(Tokens.TITANIUM.lerp(Tokens.HOLO_DEEP, 1.0 - k))
	# a whisper of cyan emission so the arm's silhouette never goes fully black in the dark room
	# (ACES tonemap crushes unlit titanium; the table carries edge strips, the arm carries this sheen)
	m.emission_enabled = true
	m.emission = Tokens.HOLO_DEEP.lerp(Tokens.HOLO_PRIMARY, 0.35)
	m.emission_energy_multiplier = 0.6
	_ti_mats.append(m)
	return m

func _link(nm: String, mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build() -> void:
	# --- statics: base, tray with spare parts, scanner arch (lit titanium + emissive in two meshes)
	var lit := MeshBuilder.new()
	lit.add_cyl(Vector3(0, 0.03, 0), 0.16, 0.06, Color.WHITE, 20)
	lit.add_cyl(Vector3(0, 0.09, 0), 0.10, 0.06, Color.WHITE, 16)
	lit.add_box(Vector3(-0.36, 0.015, 0.03), Vector3(0.30, 0.03, 0.24), Color.WHITE)            # tray
	lit.add_box(Vector3(-0.44, 0.055, -0.04), Vector3(0.10, 0.05, 0.07), Color.WHITE)           # spare block
	lit.add_cyl(Vector3(-0.28, 0.05, 0.10), 0.028, 0.04, Color.WHITE, 12)                      # spare puck
	lit.add_box(Vector3(-0.30, 0.10, 0.31), Vector3(0.03, 0.20, 0.03), Color.WHITE)             # scanner post
	lit.add_box(Vector3(-0.30, 0.21, 0.24), Vector3(0.03, 0.03, 0.17), Color.WHITE)             # scanner arm over the pad
	lit.add_box(Vector3(-0.30, 0.012, 0.17), Vector3(0.16, 0.024, 0.16), Color.WHITE)          # scan pad
	add_child(_link("ArmStatics", lit.build(), _ti(0.5)))
	var emi := MeshBuilder.new()
	var ec := Tokens.HOLO_LINE
	emi.add_cyl(Vector3(0, 0.062, 0), 0.145, 0.006, ec, 20)                                    # base light ring
	emi.add_box(Vector3(-0.30, 0.196, 0.17), Vector3(0.05, 0.008, 0.05), ec)                   # scanner emitter
	emi.add_box(Vector3(-0.365, 0.033, 0.03), Vector3(0.29, 0.004, 0.004), ec)                 # tray edge light
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Tokens.HOLO_LINE * 1.6
	em.vertex_color_use_as_albedo = false
	add_child(_link("ArmGlow", emi.build(), em))
	# the part the arm "works on": one on the tray, one in the gripper (the swap is invisible at room distance)
	_tray_part = _link("TrayPart", _part_mesh(), _ti(0.75))
	_tray_part.position = Vector3(-0.36, 0.055, 0.03)
	add_child(_tray_part)
	# scanner beam: a soft additive quad under the emitter, shown only while scanning
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load("res://column.gdshader")
	_beam_mat.set_shader_parameter("tint", Tokens.HOLO_PRIMARY)
	_beam_mat.set_shader_parameter("gain", 0.30)
	_beam_mat.set_shader_parameter("fade", 0.0)
	var beam := MeshInstance3D.new()
	beam.name = "ScanBeam"
	var bq := QuadMesh.new()
	bq.size = Vector2(0.13, 0.17)
	beam.mesh = bq
	beam.material_override = _beam_mat
	beam.position = Vector3(-0.30, 0.105, 0.17)
	beam.rotation_degrees.y = 90.0
	beam.visible = false
	_beam = beam
	add_child(beam)
	# --- articulated chain
	_yaw = Node3D.new()
	_yaw.name = "ArmYaw"
	_yaw.position.y = 0.12
	add_child(_yaw)
	var ymb := MeshBuilder.new()
	ymb.add_cyl(Vector3(0, 0.02, 0), 0.085, 0.05, Color.WHITE, 16)
	ymb.add_box(Vector3(0, 0.075, 0), Vector3(0.11, 0.06, 0.09), Color.WHITE)
	_yaw.add_child(_link("YawLink", ymb.build(), _ti(0.6)))
	_shoulder = Node3D.new()
	_shoulder.name = "ArmShoulder"
	_shoulder.position.y = 0.10
	_yaw.add_child(_shoulder)
	var smb := MeshBuilder.new()
	smb.add_box(Vector3(0, 0.17, 0), Vector3(0.075, 0.36, 0.06), Color.WHITE)
	smb.add_cyl(Vector3(0, 0.02, 0), 0.055, 0.075, Color.WHITE, 14, Basis(Vector3.RIGHT, deg_to_rad(90.0)))
	_shoulder.add_child(_link("UpperArm", smb.build(), _ti(0.65)))
	_elbow = Node3D.new()
	_elbow.name = "ArmElbow"
	_elbow.position.y = 0.34
	_shoulder.add_child(_elbow)
	var emb := MeshBuilder.new()
	emb.add_box(Vector3(0, 0.14, 0), Vector3(0.055, 0.30, 0.045), Color.WHITE)
	emb.add_cyl(Vector3(0, 0.01, 0), 0.042, 0.06, Color.WHITE, 12, Basis(Vector3.RIGHT, deg_to_rad(90.0)))
	_elbow.add_child(_link("Forearm", emb.build(), _ti(0.6)))
	_wrist = Node3D.new()
	_wrist.name = "ArmWrist"
	_wrist.position.y = 0.28
	_elbow.add_child(_wrist)
	var wmb := MeshBuilder.new()
	wmb.add_box(Vector3(0, 0.035, 0), Vector3(0.07, 0.07, 0.06), Color.WHITE)                  # palm
	wmb.add_box(Vector3(-0.022, -0.025, 0), Vector3(0.014, 0.05, 0.05), Color.WHITE)           # finger L
	wmb.add_box(Vector3(0.022, -0.025, 0), Vector3(0.014, 0.05, 0.05), Color.WHITE)            # finger R
	_wrist.add_child(_link("Gripper", wmb.build(), _ti(0.7)))
	_held = _link("HeldPart", _part_mesh(), _ti(0.8))
	_held.position = Vector3(0, -0.045, 0)
	_held.visible = false
	_wrist.add_child(_held)

func _part_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_box(Vector3.ZERO, Vector3(0.075, 0.045, 0.055), Color.WHITE)
	mb.add_cyl(Vector3(0, 0.032, 0), 0.016, 0.02, Color.WHITE, 10)
	return mb.build()

func _apply(p: Vector4) -> void:
	_pose = p
	_yaw.rotation.y = deg_to_rad(p.x)
	_shoulder.rotation.z = deg_to_rad(p.y)
	_elbow.rotation.z = deg_to_rad(p.z)
	_wrist.rotation.z = deg_to_rad(p.w)

var _poke_cd := 0.0

## Round 5B: a hand coming close pokes the arm — it sulks for a beat, then resumes work.
func poke(hand: Node3D = null) -> void:
	if _poke_cd > 0.0 or _cur_name == "sulk":
		return
	_poke_cd = 6.0
	_from = _pose
	_to = POSES["sulk"]
	_cur_name = "sulk"
	_cur_dur = 2.2
	_state_t = 0.0
	_seg_t = 0.0
	_seg_dur = 0.45
	_beam.visible = false
	_beam_mat.set_shader_parameter("fade", 0.0)
	if hand and hand.has_method("buzz"):
		hand.buzz(0.03, 0.4)

func _process(delta: float) -> void:
	_poke_cd = maxf(0.0, _poke_cd - delta)
	if _poke_cd <= 0.0 and _wrist:
		for h in get_tree().get_nodes_in_group("hand"):
			if (h as Node3D).global_position.distance_to(_wrist.global_position) < 0.3:
				poke(h as Node3D)
				break
	_state_t += delta
	if _seg_t < 1.0:
		_seg_t = minf(_seg_t + delta / _seg_dur, 1.0)
		_apply(_from.lerp(_to, Ease.out_cubic(_seg_t)))
	elif _state_t >= _cur_dur:
		_advance()
	# idle life: a slow breathing sway on the wrist while resting; the held part turns in the beam
	if _cur_name == "rest":
		_wrist.rotation.z += deg_to_rad(sin(Time.get_ticks_msec() / 1000.0 * 0.6) * 2.0) * delta
	if _cur_name == "scan" and _held.visible:
		_held.rotation.y += deg_to_rad(35.0) * delta

func _advance() -> void:
	_state_i = (_state_i + 1) % CYCLE.size()
	_state_t = 0.0
	var def: Array = CYCLE[_state_i]
	_cur_name = String(def[0])
	_cur_dur = float(def[1])
	if _state_i == 0:
		_cycles += 1
		if _cycles % 4 == 3:   # every fourth cycle the arm sulks instead of resting
			_cur_name = "sulk"
			_cur_dur = 2.8
	_from = _pose
	_to = POSES[_cur_name]
	_seg_dur = maxf(_cur_dur * 0.55, 0.5)
	_seg_t = 0.0
	# the gripper swap happens in the tray dwells (indices 2 = picked up, 7 = set back down)
	if _state_i == 2:
		_held.visible = true
		_tray_part.visible = false
	if _state_i == 7:
		_held.visible = false
		_tray_part.visible = true
	var scanning := _cur_name == "scan"
	_beam.visible = scanning
	_beam_mat.set_shader_parameter("fade", 0.85 if scanning else 0.0)
