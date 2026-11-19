extends "res://grabbable.gd"
## The assembly: remembers each part's home position + explode direction, and is grabbable.
## Also owns its look: per-part hologram materials, the flat table schematic, materialize().

signal labels_beat  # materialize beat 4: labels may fade in
signal materialized

const EXPLODE_DISTANCE := 0.25
const MATERIALIZE_TIME := 2.0
const SCHEMATIC_LIFT := 0.002  # metres above the table surface (the model origin)
const SCAN_PLANE_ALPHA := 0.45
const SCAN_PLANE_MIN := 0.3    # metres: small parts still get a clear sweep
const TETHER_RISE := 0.13      # metres: label sits this far above its part
const TETHER_SIDE := 0.1       # ...and this far out to the side, away from the assembly centre
const DIM_LABEL_GAP := 0.06    # metres past the footprint edge: just outside the dimension line

signal explode_changed(t: float)
var explode_value := 0.0

var _parts: Array[MeshInstance3D] = []
var _home := {}  # part -> home position
var _dir := {}   # part -> unit explode direction (part position - centroid)
var _mats: Array[ShaderMaterial] = []
var _bounds := AABB()  # model-local bounds of the assembled parts
var _schematic: MeshInstance3D  # child of the root, NOT a part: never explodes
var _schematic_mat: StandardMaterial3D
var _scan_plane: MeshInstance3D  # child of the root, NOT a part: not in _parts/_bounds/explode
var _scan_mat: StandardMaterial3D
var _dim_labels: Array[Label3D] = []
var _tethers: Array[Dictionary] = []  # {part, label, line}: leader line + caps label per part
var _tether_mat: StandardMaterial3D
var _tether_alpha := 0.0

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
	_build_dim_labels()
	_build_scan_plane()
	_build_tethers()
	hide_all()

func part_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in _parts:
		names.append(p.name)
	return names

## Real size from the part AABBs in decimal inches, as "9.45 × 6.3 × 7.87 IN" (X × Z × Y: length,
## depth, height). A dimension >= 24 in reads as feet + inches (F' R.R"); the IN suffix only
## appears when every dimension is plain inches. Metric never reaches the display.
func dims_text() -> String:
	var s := _bounds.size
	var inches := [s.x / 0.0254, s.z / 0.0254, s.y / 0.0254]
	var long_form := inches.any(func(v): return v >= 24.0)
	var parts := PackedStringArray()
	for v in inches:
		parts.append(_fmt_len(v, long_form))
	return " × ".join(parts) + ("" if long_form else " IN")

static func _fmt_dec(v: float, places: int) -> String:
	var t := String.num(v, places)
	if t.contains("."):
		t = t.rstrip("0").rstrip(".")
	return t

static func _fmt_len(inches: float, long_form: bool) -> String:
	if inches >= 24.0:
		var ft := int(inches / 12.0)
		var rem := inches - ft * 12.0
		if roundf(rem * 100.0) / 100.0 >= 12.0:  # rounding carried into a full foot
			ft += 1
			rem = 0.0
		return "%d' %s\"" % [ft, _fmt_dec(rem, 1)]
	return _fmt_dec(inches, 2)

## t in 0..1: 0 = assembled, 1 = fully exploded.
func set_explode(t: float) -> void:
	explode_value = t
	explode_changed.emit(t)
	for p in _parts:
		p.position = _home[p] + _dir[p] * t * EXPLODE_DISTANCE
	_update_tethers()

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

## Flat X / Z size labels just outside the blueprint's dimension lines.
func _build_dim_labels() -> void:
	var c := _bounds.get_center()
	var s := _bounds.size
	var specs := [
		[s.x, Vector3(c.x, SCHEMATIC_LIFT, _bounds.end.z + DIM_LABEL_GAP), 0.0],
		[s.z, Vector3(_bounds.end.x + DIM_LABEL_GAP, SCHEMATIC_LIFT, c.z), 90.0],
	]
	var inches := [s.x / 0.0254, s.z / 0.0254]
	var long_form: bool = inches.any(func(v): return v >= 24.0) or s.y / 0.0254 >= 24.0
	for i in 2:
		var l := Label3D.new()
		l.name = "DimLabel%d" % i
		l.text = _fmt_len(inches[i], long_form) + ("" if long_form else " IN")
		l.font = load(Tokens.FONT_BOLD)
		l.font_size = 48
		l.pixel_size = 0.0011
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.shaded = false
		l.double_sided = true
		l.modulate = Tokens.HOLO_LINE
		l.position = specs[i][1]
		l.rotation_degrees = Vector3(-90.0, specs[i][2], 0.0)
		add_child(l)
		_dim_labels.append(l)

## Thin leader line + small-caps label per part, following the part as it explodes.
func _build_tethers() -> void:
	_tether_mat = StandardMaterial3D.new()
	_tether_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tether_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tether_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, 0.0)
	for i in _parts.size():
		var p := _parts[i]
		var line := MeshInstance3D.new()
		line.name = "Tether%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.0018, 0.0018, 1.0)
		line.mesh = box
		line.material_override = _tether_mat
		add_child(line)
		var l := Label3D.new()
		l.name = "PartLabel%d" % i
		l.text = _part_caption(p.name, i)
		l.font = load(Tokens.FONT_BOLD)
		l.font_size = 40
		l.pixel_size = 0.0008
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.shaded = false
		l.no_depth_test = true
		l.modulate = Tokens.a(Tokens.HOLO_LINE, 0.0)
		l.outline_size = 0
		add_child(l)
		_tethers.append({"part": p, "label": l, "line": line})
	_update_tethers()

## "UprightArm" -> "UPRIGHT ARM · 02"
static func _part_caption(part_name: String, index: int) -> String:
	var words := PackedStringArray()
	var cur := ""
	for ch in part_name:
		if ch == ch.to_upper() and ch != ch.to_lower() and cur != "":
			words.append(cur)
			cur = ""
		cur += ch
	words.append(cur)
	return "%s · %02d" % [" ".join(words).to_upper(), index + 1]

func _update_tethers() -> void:
	for t in _tethers:
		var p: MeshInstance3D = t["part"]
		var a: Vector3 = Transform3D(p.basis, p.position) * p.mesh.get_aabb().get_center()
		var side := 1.0 if a.x >= center_local.x else -1.0
		var tip := a + Vector3(side * TETHER_SIDE, TETHER_RISE, 0.0)
		var line: MeshInstance3D = t["line"]
		var d := tip - a
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		line.transform = Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(1, 1, d.length())), a.lerp(tip, 0.5))
		var l: Label3D = t["label"]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side > 0 else HORIZONTAL_ALIGNMENT_RIGHT
		l.position = tip + Vector3(side * 0.008, 0.012, 0.0)

func set_tether_alpha(a: float) -> void:
	_tether_alpha = a
	_tether_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, a * 0.8)
	for t in _tethers:
		t["label"].modulate = Tokens.a(Tokens.HOLO_LINE, a)

func _build_scan_plane() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(maxf(_bounds.size.x * 1.15, SCAN_PLANE_MIN), maxf(_bounds.size.z * 1.15, SCAN_PLANE_MIN))
	_scan_mat = Fx.additive_unshaded(Tokens.a(Tokens.HOLO_LINE, 0.0))
	_scan_plane = MeshInstance3D.new()
	_scan_plane.name = "ScanPlane"
	_scan_plane.mesh = quad
	_scan_plane.material_override = _scan_mat
	_scan_plane.rotation_degrees.x = -90.0
	_scan_plane.position = Vector3(_bounds.get_center().x, _bounds.position.y, _bounds.get_center().z)
	_scan_plane.visible = false
	add_child(_scan_plane)

## t 0..1 sweeps the plane base -> top; alpha is the plane's own strength.
func _set_scan_plane(t: float) -> void:
	_scan_plane.position.y = lerpf(_bounds.position.y, _bounds.end.y, t)

func _set_scan_plane_alpha(a: float) -> void:
	_scan_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, a)

func hide_all() -> void:
	_set_state(false, 0.0, 0.0, 0.0)

func _set_state(shown: bool, scan: float, flash_v: float, wire: float) -> void:
	for p in _parts:
		p.visible = shown
	_schematic.visible = shown
	_scan_plane.visible = false
	for l in _dim_labels:
		l.visible = shown
	for t in _tethers:
		t["label"].visible = shown
		t["line"].visible = shown
	if _tether_mat:
		set_tether_alpha(0.0)
	for m in _mats:
		m.set_shader_parameter("scan", scan)
		m.set_shader_parameter("flash", flash_v)
		m.set_shader_parameter("wire", wire)

func _set_param(v: float, param: StringName) -> void:
	for m in _mats:
		m.set_shader_parameter(param, v)

func _set_schematic_alpha(a: float) -> void:
	_schematic_mat.albedo_color = Color(1, 1, 1, a)
	for l in _dim_labels:
		l.modulate = Tokens.a(Tokens.HOLO_LINE, a)

func _scan_plane_begin() -> void:
	_set_scan_plane(0.0)
	_set_scan_plane_alpha(SCAN_PLANE_ALPHA)
	_scan_plane.visible = true

## SPEC §2.6 beats, ~2 s: (1) flat schematic + wireframe appear -> (2) scan plane sweeps
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
	tw.tween_method(_set_schematic_alpha, 0.0, 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_param.bind(&"wire"), 0.0, 1.0, 0.35)
	tw.tween_method(_set_param.bind(&"scan"), 0.0, 1.15, 1.1).set_delay(0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_scan_plane_begin).set_delay(0.35)
	tw.tween_method(_set_scan_plane, 0.0, 1.0, 1.1).set_delay(0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_scan_plane_alpha, SCAN_PLANE_ALPHA, 0.0, 0.25).set_delay(1.2)
	tw.tween_callback(func() -> void: _scan_plane.visible = false).set_delay(1.45)
	tw.tween_method(_set_param.bind(&"flash"), 1.0, 0.0, 0.5).set_delay(1.35)
	tw.tween_callback(labels_beat.emit).set_delay(1.75)
	tw.tween_callback(materialized.emit).set_delay(MATERIALIZE_TIME)
	await materialized
