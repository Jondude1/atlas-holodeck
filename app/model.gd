extends "res://grabbable.gd"
## The assembly: remembers each part's home position + explode direction, and is grabbable.
## Also owns its look: per-part hologram materials, the flat table schematic, materialize().

signal labels_beat  # materialize beat 4: labels may fade in
signal materialized

const EXPLODE_DISTANCE := 0.25
const MATERIALIZE_TIME := 1.2
const SCHEMATIC_LIFT := 0.002  # metres above the table surface (the model origin)

var _parts: Array[MeshInstance3D] = []
var _home := {}  # part -> home position
var _dir := {}   # part -> unit explode direction (part position - centroid)
var _mats: Array[ShaderMaterial] = []
var _bounds := AABB()  # model-local bounds of the assembled parts
var _schematic: MeshInstance3D  # child of the root, NOT a part: never explodes
var _schematic_mat: StandardMaterial3D

func _ready() -> void:
	super()
	var centroid := Vector3.ZERO
	for c in get_children():
		if c is MeshInstance3D:
			_parts.append(c)
			centroid += c.position
	centroid /= maxf(_parts.size(), 1)
	center_local = centroid
	for i in _parts.size():
		var p := _parts[i]
		_home[p] = p.position
		var d: Vector3 = p.position - centroid
		_dir[p] = d.normalized() if d.length() > 0.001 else Vector3.UP
		var box: AABB = Transform3D(p.basis, p.position) * p.mesh.get_aabb()
		_bounds = box if i == 0 else _bounds.merge(box)
		var mat := Fx.part_material(p.mesh.get_aabb())
		_mats.append(mat)
		p.material_override = mat
	_build_schematic()
	hide_all()

func part_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in _parts:
		names.append(p.name)
	return names

## Real size from the part AABBs, as "240 × 160 × 200 MM" (X × Z × Y: length, depth, height).
func dims_text() -> String:
	var s := _bounds.size
	return "%d × %d × %d MM" % [roundi(s.x * 1000.0), roundi(s.z * 1000.0), roundi(s.y * 1000.0)]

## t in 0..1: 0 = assembled, 1 = fully exploded.
func set_explode(t: float) -> void:
	for p in _parts:
		p.position = _home[p] + _dir[p] * t * EXPLODE_DISTANCE

func set_model_scale(s: float) -> void:
	scale = Vector3.ONE * s

func begin_grab(hand: Node3D) -> void:
	super(hand)
	Sfx.play(self, "grab")

func end_grab(hand: Node3D) -> void:
	super(hand)
	Sfx.play(self, "grab")

func _build_schematic() -> void:
	var foot := Rect2(_bounds.position.x, _bounds.position.z, _bounds.size.x, _bounds.size.z)
	var quad_m := maxf(foot.size.x, foot.size.y) * 1.7
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * quad_m
	_schematic_mat = StandardMaterial3D.new()
	_schematic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_schematic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_schematic_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_schematic_mat.albedo_texture = Blueprint.make(foot, quad_m)
	_schematic = MeshInstance3D.new()
	_schematic.name = "Schematic"
	_schematic.mesh = quad
	_schematic.material_override = _schematic_mat
	_schematic.rotation_degrees.x = -90.0  # lie flat, texture top = -Z
	_schematic.position = Vector3(_bounds.get_center().x, SCHEMATIC_LIFT, _bounds.get_center().z)
	add_child(_schematic)

func hide_all() -> void:
	_set_state(false, 0.0, 0.0, 0.0)

func _set_state(shown: bool, scan: float, flash_v: float, wire: float) -> void:
	for p in _parts:
		p.visible = shown
	_schematic.visible = shown
	for m in _mats:
		m.set_shader_parameter("scan", scan)
		m.set_shader_parameter("flash", flash_v)
		m.set_shader_parameter("wire", wire)

func _set_param(v: float, param: StringName) -> void:
	for m in _mats:
		m.set_shader_parameter(param, v)

func _set_schematic_alpha(a: float) -> void:
	_schematic_mat.albedo_color = Color(1, 1, 1, a)

## SPEC §2.6 beats, ~1.2 s: (1) flat schematic + wireframe appear -> (2) scan plane sweeps
## bottom-to-top, resolving the wireframe -> (3) volume fills, edges settle from white-hot
## to holo_line -> (4) labels. Safe to call on any future spawned model.
func materialize() -> void:
	var y_lo := global_transform.origin.y + _bounds.position.y * scale.y
	var y_hi := global_transform.origin.y + _bounds.end.y * scale.y
	_set_state(true, -0.5, 1.0, 0.0)
	_set_schematic_alpha(0.0)
	for m in _mats:
		m.set_shader_parameter("y0", y_lo)
		m.set_shader_parameter("y1", y_hi)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_schematic_alpha, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_param.bind(&"wire"), 0.0, 1.0, 0.25)
	tw.tween_method(_set_param.bind(&"scan"), 0.0, 1.15, 0.6).set_delay(0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_param.bind(&"flash"), 1.0, 0.0, 0.35).set_delay(0.7)
	tw.tween_callback(labels_beat.emit).set_delay(1.0)
	tw.tween_callback(materialized.emit).set_delay(MATERIALIZE_TIME)
	await materialized
