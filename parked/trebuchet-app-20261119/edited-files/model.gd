extends "res://grabbable.gd"
## The assembly: remembers each part's home position + explode direction, and is grabbable.
## Also owns its look: per-part hologram materials, the flat table schematic, materialize().

signal labels_beat  # materialize beat 4: labels may fade in
signal materialized
signal scale_changed  # on-table size changed: readouts refresh

const EXPLODE_DISTANCE := 0.25
const MATERIALIZE_TIME := 2.0
const SCHEMATIC_LIFT := 0.002  # metres above the table surface (the model origin)
const SCAN_PLANE_ALPHA := 0.45
const SCAN_PLANE_MIN := 0.3    # metres: small parts still get a clear sweep
const DIM_LABEL_GAP := 0.06    # metres past the footprint edge: just outside the dimension line
const LABEL_OFFSET := 0.045    # metres (model space) a tethered label floats past its exploded part
const LABEL_FADE_FROM := 0.12  # explode amount where labels start to fade in ...
const LABEL_FADE_SPAN := 0.3   # ... and are fully in at FROM + SPAN
const TETHER_ALPHA := 0.7

var base_scale := 1.0  # display scale of the model at "1×"; the panel scale buttons multiply it
var _parts: Array[MeshInstance3D] = []
var _home_xf := {}  # part -> home transform (assembled, un-posed)
var _dir := {}   # part -> unit explode direction (part centre - centroid)
var _explode_t := 0.0
var _label_nodes := {}  # part -> Label3D (tethered label, fades in with explode)
var _tether: MeshInstance3D
var _tether_mat: StandardMaterial3D
var _mats: Array[ShaderMaterial] = []
var _bounds := AABB()  # model-local bounds of the assembled parts
var _schematic: MeshInstance3D  # child of the root, NOT a part: never explodes
var _schematic_mat: StandardMaterial3D
var _scan_plane: MeshInstance3D  # child of the root, NOT a part: not in _parts/_bounds/explode
var _scan_mat: StandardMaterial3D
var _dim_labels: Array[Label3D] = []
var _labels_enabled := false  # part labels only exist once the model has materialized

func _ready() -> void:
	super()
	for c in get_children():
		if c is MeshInstance3D:
			_parts.append(c)
	var centroid := Vector3.ZERO
	for p in _parts:
		_home_xf[p] = p.transform
		centroid += _home_box(p).get_center()
	centroid /= maxf(_parts.size(), 1)
	center_local = centroid
	for p in _parts:
		var d: Vector3 = _home_box(p).get_center() - centroid
		_dir[p] = d.normalized() if d.length() > 0.001 else Vector3.UP
	_apply_pose()
	for i in _parts.size():
		var p := _parts[i]
		var box := _part_box(p)
		_bounds = box if i == 0 else _bounds.merge(box)
		var mat := _make_material(p)
		_mats.append(mat)
		p.material_override = mat
	_build_schematic()
	_build_dim_labels()
	_build_scan_plane()
	_build_part_labels()
	hide_all()

## Hooks for models whose parts move (trebuchet.gd): the animated pose layered on the home
## transform, and per-part visibility. The bracket uses the defaults.
func _pose(_p: MeshInstance3D) -> Transform3D:
	return Transform3D.IDENTITY

func _part_visible(_p: MeshInstance3D) -> bool:
	return true

func _explode_offset(p: MeshInstance3D) -> Vector3:
	return _dir[p] * _explode_t * EXPLODE_DISTANCE

func _make_material(p: MeshInstance3D) -> ShaderMaterial:
	return Fx.part_material(p.mesh.get_aabb())

func _home_box(p: MeshInstance3D) -> AABB:
	return _home_xf[p] * p.mesh.get_aabb()

func _part_box(p: MeshInstance3D) -> AABB:
	return p.transform * p.mesh.get_aabb()

func _apply_pose() -> void:
	for p in _parts:
		p.transform = Transform3D(Basis.IDENTITY, _explode_offset(p)) * _pose(p) * _home_xf[p]
	_update_labels()

func part_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in _parts:
		names.append(p.name)
	return names

## Real size from the part AABBs in decimal inches, as "9.45 × 6.3 × 7.87 IN" (X × Z × Y: length,
## depth, height). A dimension >= 24 in reads as feet + inches (F' R.R"); the IN suffix only
## appears when every dimension is plain inches. Metric never reaches the display.
func dims_text() -> String:
	var s := _bounds.size * scale.x
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
	_explode_t = t
	_apply_pose()

func set_model_scale(s: float) -> void:
	scale = Vector3.ONE * base_scale * s
	scale_changed.emit()

## Readout for the table: enlargement "SCALE 2.1× · TRUE 14 × 7 × 10 IN", reduction "SCALE 1:X.X".
## true_in is the model's real size (manifest); empty for models without one.
func scale_text(true_in: Array) -> String:
	var f := scale.x
	var head := "SCALE %s×" % _fmt_dec(f, 1) if f >= 1.0 else "SCALE 1:%s" % _fmt_dec(1.0 / f, 1)
	if true_in.is_empty():
		return head
	var t := PackedStringArray()
	for v in true_in:
		t.append(_fmt_dec(float(v), 2))
	return "%s · TRUE %s IN" % [head, " × ".join(t)]

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
	_labels_enabled = false
	_set_state(false, 0.0, 0.0, 0.0)

func _set_state(shown: bool, scan: float, flash_v: float, wire: float) -> void:
	for p in _parts:
		p.visible = shown and _part_visible(p)
	_schematic.visible = shown
	_scan_plane.visible = false
	for l in _dim_labels:
		l.visible = shown
	for m in _mats:
		m.set_shader_parameter("scan", scan)
		m.set_shader_parameter("flash", flash_v)
		m.set_shader_parameter("wire", wire)
	_update_labels()

## Parked / already-resolved display (the bracket at the table's right end): fades the whole
## model up with no scan sweep.
func show_all() -> void:
	_set_state(true, 1.2, 0.0, 0.0)
	_set_schematic_alpha(1.0)
	create_tween().tween_method(_set_param.bind(&"wire"), 0.0, 1.0, 0.6)
	_labels_enabled = true

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
	tw.tween_callback(func() -> void: _labels_enabled = true).set_delay(1.75)
	tw.tween_callback(labels_beat.emit).set_delay(1.75)
	tw.tween_callback(materialized.emit).set_delay(MATERIALIZE_TIME)
	await materialized

## One tethered label per part: fades in with the explode amount, floats just past the part
## along its explode direction, joined by a thin tether line (all tethers = one mesh).
func _build_part_labels() -> void:
	for p in _parts:
		var l := Label3D.new()
		l.name = "Label_" + String(p.name)
		l.text = String(p.name).to_upper()
		l.font = load(Tokens.FONT_BOLD)
		l.font_size = 40
		l.pixel_size = 0.0004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.shaded = false
		l.no_depth_test = true
		l.render_priority = 2
		l.outline_size = 0
		l.modulate = Tokens.a(Tokens.HOLO_LINE, 0.0)
		l.visible = false
		add_child(l)
		_label_nodes[p] = l
	_tether_mat = Fx.additive_unshaded(Tokens.a(Tokens.HOLO_LINE, 0.0))
	_tether = MeshInstance3D.new()
	_tether.name = "Tethers"
	_tether.material_override = _tether_mat
	_tether.visible = false
	add_child(_tether)

func _label_alpha() -> float:
	return clampf((_explode_t - LABEL_FADE_FROM) / LABEL_FADE_SPAN, 0.0, 1.0) if _labels_enabled else 0.0

func _update_labels() -> void:
	if _label_nodes.is_empty():
		return
	var a := _label_alpha()
	var on := a > 0.0
	_tether.visible = on
	if not on:
		for l in _label_nodes.values():
			l.visible = false
		return
	var pts := PackedVector3Array()
	for p in _parts:
		var l: Label3D = _label_nodes[p]
		var show_it := p.visible
		l.visible = show_it
		if not show_it:
			continue
		var c := _part_box(p).get_center()
		var at: Vector3 = c + _dir[p] * LABEL_OFFSET
		l.position = at
		l.modulate = Tokens.a(Tokens.HOLO_LINE, a)
		pts.append(c)
		pts.append(at)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var m := ArrayMesh.new()
	if not pts.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	_tether.mesh = m
	_tether_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, a * TETHER_ALPHA)
