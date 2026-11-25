class_name SuitDisplay
extends Node3D
## Iterate round 1 (P1) — the two suits on the pads flanking the opening, as in
## Jon's North Star (design/look-reference-jon-20261124.jpg): dark armour at rest,
## and when a visitor comes close the visor slit and chest core light up cyan and
## the visor tracks the visitor. Presentation only: no lights added (the room's
## 3-light law stands), the glow is emissive material energy, +3 draw calls/suit.
## Meshes: design/suits3d/*.glb (TRELLIS, ~295k tris + display disc) decimated by
## tools/decimate_suits.py to 25k tris, disc trimmed, feet at y=0, height 1.78 m.

const WAKE_DIST := 2.4        # approach distance that wakes a suit
const IDLE_GLOW := 0.04       # faint ember at rest — present, never bright
const TRACK_CLAMP := 0.65     # visor yaw limit (rad) either side of facing

var _visor_mat: StandardMaterial3D
var _chest_mat: StandardMaterial3D
var _visor_pivot: Node3D
var _glow := IDLE_GLOW
var _visitor_override := Vector3.ZERO
var _has_override := false

func setup(glb_path: String) -> void:
	var packed := load(glb_path) as PackedScene
	if packed:
		add_child(packed.instantiate())
	# chest core: a small emissive disc standing just off the chest plate
	_chest_mat = _glow_material()
	var chest := MeshInstance3D.new()
	chest.name = "ChestCore"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.042
	disc.bottom_radius = 0.042
	disc.height = 0.012
	disc.radial_segments = 20
	chest.mesh = disc
	chest.material_override = _chest_mat
	chest.rotation_degrees = Vector3(90, 0, 0)
	chest.position = Vector3(0, 1.40, 0.155)
	add_child(chest)
	# visor slit on a yaw pivot at head centre, so it can track the visitor
	_visor_mat = _glow_material()
	_visor_pivot = Node3D.new()
	_visor_pivot.name = "VisorPivot"
	_visor_pivot.position = Vector3(0, 1.615, 0)
	add_child(_visor_pivot)
	var visor := MeshInstance3D.new()
	visor.name = "VisorSlit"
	var slit := BoxMesh.new()
	slit.size = Vector3(0.105, 0.016, 0.010)
	visor.mesh = slit
	visor.material_override = _visor_mat
	visor.position = Vector3(0, 0.01, 0.098)
	_visor_pivot.add_child(visor)
	_apply_glow()

func _glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Tokens.HOLO_LINE
	return m

func _apply_glow() -> void:
	# unshaded albedo scaled by glow: HDR values (>1) feed the room's bloom
	var c: Color = Tokens.HOLO_LINE * (0.15 + _glow * 2.4)
	if _visor_mat:
		_visor_mat.albedo_color = c
	if _chest_mat:
		_chest_mat.albedo_color = c * 0.9

## Test hook / future rig hook: pretend the visitor stands here.
func debug_set_visitor(world_pos: Vector3) -> void:
	_visitor_override = world_pos
	_has_override = true

func wake_amount() -> float:
	return _glow

func _visitor_pos() -> Vector3:
	if _has_override:
		return _visitor_override
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(0, 1.6, 3.0)

func _process(delta: float) -> void:
	var v := _visitor_pos()
	var flat := Vector2(v.x - global_position.x, v.z - global_position.z)
	var awake := flat.length() < WAKE_DIST
	var target := 1.0 if awake else IDLE_GLOW
	_glow = move_toward(_glow, target, delta * (1.6 if awake else 0.5))
	_apply_glow()
	if _visor_pivot:
		var want := 0.0
		if awake:
			# visitor bearing relative to the suit's facing (+Z, into the room)
			want = clampf(atan2(flat.x, flat.y) - global_rotation.y, -TRACK_CLAMP, TRACK_CLAMP)
		_visor_pivot.rotation.y = lerpf(_visor_pivot.rotation.y, want, clampf(delta * 3.0, 0.0, 1.0))
