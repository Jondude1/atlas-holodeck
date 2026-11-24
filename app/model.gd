extends "res://grabbable.gd"
## The assembly: remembers each part's home position + explode direction, and is grabbable.
## Also owns its look: per-part hologram materials, the flat table schematic, materialize().

signal labels_beat  # materialize beat 4: labels may fade in
signal materialized

const HOME_POS := Vector3(0.0, 0.951, 0.0)  # table centre, on the surface (HoloTable.TOP_Y)
const EXPLODE_DISTANCE := 0.25
const MATERIALIZE_TIME := 2.0
const SCHEMATIC_LIFT := 0.002  # metres above the table surface (the model origin)
const SCAN_PLANE_ALPHA := 0.18
const SCAN_PLANE_MIN := 0.3    # metres: small parts still get a clear sweep
const TETHER_RISE := 0.13      # metres: label sits this far above its part
const TETHER_SIDE := 0.1       # ...and this far out to the side, away from the assembly centre
const TETHER_FAN := 0.085      # R3-10: second callout column, this much further out — halves each column's stack
const TETHER_MIN_GAP := 0.046  # R3-10: minimum vertical separation between labels sharing a column
# R4-3: the merged leader-line mesh — unit-box corners (0.0018 x 0.0018 x 1) and outward-wound faces.
const _TETHER_CORNERS := [
	Vector3(-.0009, -.0009, -.5), Vector3(.0009, -.0009, -.5), Vector3(.0009, .0009, -.5), Vector3(-.0009, .0009, -.5),
	Vector3(-.0009, -.0009, .5), Vector3(.0009, -.0009, .5), Vector3(.0009, .0009, .5), Vector3(-.0009, .0009, .5)]
const _TETHER_IDX := [0, 3, 2, 0, 2, 1, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2, 0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5]
const DIM_LABEL_GAP := 0.06    # metres past the footprint edge: just outside the dimension line

signal explode_changed(t: float)
var explode_value := 0.0
## Parts of a voice-CAD model are scaled up to a table-readable size at load (a 3 in part is 7.6 cm); this is that
## factor, so every displayed size (dimension labels, DIMS) is divided back to true inches. 1.0 = shown at true scale.
var display_scale := 1.0
var job_id := ""                    # the hub job a runtime CAD model was built from ("" for the demo part); edits + send-to-print use it
var print_estimate := {}            # the hub's {est_minutes, est_text, ...} for the confirmation card
var _parked := false

var _parts: Array[MeshInstance3D] = []
var _home := {}  # part -> home position
var _centre := {} # part -> geometry (AABB) centre in model space, assembled
var _dir := {}   # part -> unit explode direction (geometry centre - assembly centroid)
## R4-2: no per-part materials — every part shares Fx's one material per shader kind; per-part
## values (aabb / wire / scan / y0 / y1 / flash) live in INSTANCE shader parameters on the part.
var _bounds := AABB()  # model-local bounds of the assembled parts
var _schematic: MeshInstance3D  # child of the root, NOT a part: never explodes
var _schematic_mat: StandardMaterial3D
var _scan_plane: MeshInstance3D  # child of the root, NOT a part: not in _parts/_bounds/explode
var _scan_mat: StandardMaterial3D
var _dim_labels: Array[Label3D] = []
var _dim_texts: Array[String] = []  # R4-4: parked models release their label textures (text=""); texts kept here for unpark
var _tethers: Array[Dictionary] = []  # {part, label, line}: leader line + caps label per part
var _tether_mat: StandardMaterial3D
var _tether_mesh: MeshInstance3D   # R4-3: ALL leader lines in ONE merged mesh (was one MeshInstance per part)
var _line_hidden := {}             # part index -> true: omit that leader from the merged mesh (pin styling)
var _tether_alpha := 0.0

func _ready() -> void:
	super()
	for c in get_children():
		if c is MeshInstance3D:
			_parts.append(c)
	# Explode direction comes from each part's GEOMETRY centre (its AABB centre in model space), not its node origin:
	# exporters that bake vertices in world space leave every origin at 0, which used to lift all parts together.
	var centroid := Vector3.ZERO
	for p in _parts:
		_centre[p] = geom_centre(p)
		centroid += _centre[p]
	centroid /= maxf(_parts.size(), 1)
	center_local = centroid
	for i in _parts.size():
		var p := _parts[i]
		_home[p] = p.position
		var d: Vector3 = _centre[p] - centroid
		_dir[p] = d.normalized() if d.length() > 0.001 else Vector3.UP
		var box: AABB = Transform3D(p.basis, p.position) * p.mesh.get_aabb()
		_bounds = box if i == 0 else _bounds.merge(box)
		p.material_override = _make_material(p)
	_build_schematic()
	_build_dim_labels()
	_build_scan_plane()
	_build_tethers()
	hide_all()

## Material hook: the hand-built bracket uses the AABB-edge shader; runtime CAD meshes override this with the
## fresnel mesh hologram (cad_model.gd).
func _make_material(p: MeshInstance3D) -> ShaderMaterial:
	var aabb := p.mesh.get_aabb()
	p.set_instance_shader_parameter(&"aabb_center", aabb.get_center())
	p.set_instance_shader_parameter(&"aabb_half", aabb.size * 0.5)
	return Fx.part_material()

## First part's scan value — capture/perf tools wait on materialize completion through this.
func debug_scan() -> float:
	if _parts.is_empty():
		return -1.0
	var v = _parts[0].get_instance_shader_parameter(&"scan")
	return float(v) if v != null else 1.2

## A part's geometry centre in model space (AABB centre through its node transform).
static func geom_centre(p: MeshInstance3D) -> Vector3:
	return Transform3D(p.basis, p.position) * p.mesh.get_aabb().get_center()

func part_names() -> PackedStringArray:
	var names := PackedStringArray()
	for p in _parts:
		names.append(p.name)
	return names

## Real size from the part AABBs in decimal inches, as "9.45 × 6.3 × 7.87 IN" (X × Z × Y: length,
## depth, height). A dimension >= 24 in reads as feet + inches (F' R.R"); the IN suffix only
## appears when every dimension is plain inches. Metric never reaches the display.
func dims_text() -> String:
	var s := _bounds.size / display_scale
	return Units.dims_line([s.x / 0.0254, s.z / 0.0254, s.y / 0.0254])

## t in 0..1: 0 = assembled, 1 = fully exploded.
func set_explode(t: float) -> void:
	explode_value = t
	explode_changed.emit(t)
	for p in _parts:
		p.position = _home[p] + _dir[p] * t * EXPLODE_DISTANCE
	_update_tethers()

## Multi-object bench (SPEC §2): a design that is no longer the active one rests small at the table's edge,
## its labels and dimension lines off. `to` is in the table's space.
func park(to: Vector3, s := 0.55) -> void:
	_parked = true
	set_explode(0.0)
	set_tether_alpha(0.0)
	for l in _dim_labels:
		l.visible = false
		l.text = ""                    # R4-4: an empty Label3D holds no texture — parked models carry none
	for t in _tethers:                 # hidden outright: a transparent label still costs a draw call
		t["label"].visible = false
		t["label"].text = ""
	if _tether_mesh:
		_tether_mesh.visible = false
	_schematic.visible = false
	_kill_move()
	var tw := create_tween().set_parallel(true)
	_move_tw = tw
	tw.tween_property(self, "position", to, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE * s, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_parked() -> bool:
	return _parked

## Back to centre stage (bench select / reset): labels, schematic and dimension lines return.
func unpark() -> void:
	if not _parked:
		return
	_parked = false
	_schematic.visible = true
	for i in _dim_labels.size():
		_dim_labels[i].text = _dim_texts[i]   # R4-4: restore what park() released
		_dim_labels[i].visible = true
	for i in _tethers.size():
		var t: Dictionary = _tethers[i]
		t["label"].text = _part_caption(t["part"].name, i)
		t["label"].visible = true
	if _hot_part:
		_style_part(_hot_part, true)          # a pinned part keeps its two-line label
	_line_hidden.clear()
	if _tether_mesh:
		_tether_mesh.visible = true
		_update_tethers()
	_set_schematic_alpha(1.0)
	set_tether_alpha(1.0)

## Model reset (R1-3; distinct from the floor-height fix): centre of the table, upright, display scale, assembled.
## Returns the tween so callers can await it. Interrupts any coast/settle in progress.
func reset_pose(t := 0.6) -> Tween:
	_cancel_motion()
	unpark()
	set_explode(0.0)
	var tw := create_tween().set_parallel(true)
	_move_tw = tw
	tw.tween_property(self, "position", HOME_POS, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "quaternion", Quaternion.IDENTITY, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw

var _move_tw: Tween

func _kill_move() -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()

func _cancel_motion() -> void:
	_kill_move()
	mode = Mode.IDLE
	_hands.clear()
	set_process(false)

func set_model_scale(s: float) -> void:
	_scale_to(s)

## TRUE SIZE: the scale at which the model is its real size (display_scale is the table-readable enlargement).
func set_true_scale() -> void:
	_scale_to(1.0 / display_scale)

func _scale_to(s: float, t := 0.25) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * s, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Scale as the user reads it: 1.0 = table-readable display size; true size = 1 / display_scale.
func scale_label() -> String:
	var s := scale.x
	if absf(s * display_scale - 1.0) < 0.01 and absf(display_scale - 1.0) > 0.01:
		return "TRUE SIZE"
	return "%s×" % Units.dec(s, 2)

# ---------------------------------------------------------------- hover / select (R1-11, R1-6)

var _hot_part: MeshInstance3D = null
var _hot_pin := false  # a panel/list selection stays until cleared; plain hover follows the ray

## Emphasise one part (or none): rim white-hot via the part's own material and its label raised to the core colour,
## larger and forced visible. No extra nodes: costs no draw calls beyond the label that already exists.
func highlight_part(p: MeshInstance3D, pinned := false) -> void:
	if p == _hot_part and pinned == _hot_pin:
		return
	if _hot_part:
		_style_part(_hot_part, false)
	_hot_part = p
	_hot_pin = pinned and p != null
	if p:
		_style_part(p, true)

func hot_part() -> MeshInstance3D:
	return _hot_part

## Round 2 (R2-2): whole-model hover glow for PARKED models — the
## bench-select affordance. Every part rim-lights together so the parked
## model reads as one selectable object; labels stay as they are.
var _all_hot := false

func set_all_hot(on: bool) -> void:
	if on == _all_hot:
		return
	_all_hot = on
	for i in _parts.size():
		var rest := 0.85 if _parts[i] == _hot_part else 0.0
		_parts[i].set_instance_shader_parameter(&"flash", 0.6 if on else rest)

func clear_highlight(only_hover := false) -> void:
	if only_hover and _hot_pin:
		return
	highlight_part(null)

func _style_part(p: MeshInstance3D, on: bool) -> void:
	var i := _parts.find(p)
	if i < 0:
		return
	_parts[i].set_instance_shader_parameter(&"flash", 0.85 if on else 0.0)
	var t: Dictionary = _tethers[i]
	var l: Label3D = t["label"]
	if on:
		l.visible = true
		_line_hidden.erase(i)
		_update_tethers()
		l.modulate = Tokens.HOLO_CORE
		l.font_size = 56
		l.text = _part_caption(p.name, i) + "\n" + _part_dims_line(p)
	else:
		l.font_size = 40
		l.text = _part_caption(p.name, i)
		var parked_or_unseen := _parked or _tether_alpha <= 0.0
		l.modulate = Tokens.a(Tokens.HOLO_LINE, _tether_alpha)
		l.visible = not parked_or_unseen
		if parked_or_unseen:
			_line_hidden[i] = true
		else:
			_line_hidden.erase(i)
		_update_tethers()

## "UPRIGHT ARM · 02" caption of part i (the same string its tether label carries).
func part_caption(i: int) -> String:
	return _part_caption(_parts[i].name, i)

func part_node(i: int) -> MeshInstance3D:
	return _parts[i]

func part_by_name(n: String) -> MeshInstance3D:
	for p in _parts:
		if p.name == n:
			return p
	return null

## Ray (world space) vs part AABBs -> the nearest hit part, or null. Used for hover/select with the pointer.
func pick_part(origin: Vector3, dir: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_t := INF
	for p in _parts:
		var inv := p.global_transform.affine_inverse()
		var o := inv * origin
		var d := inv.basis * dir
		var hit: Variant = p.mesh.get_aabb().intersects_ray(o, d)
		if hit != null:
			var t := ((p.global_transform * (hit as Vector3)) - origin).length()
			if t < best_t:
				best_t = t
				best = p
	return best

func begin_grab(hand: Node3D) -> void:
	_kill_move()
	super(hand)
	Sfx.play(self, "grab")

func end_grab(hand: Node3D) -> void:
	super(hand)
	Sfx.play(self, "grab")

## Round 2 (R2-4/R2-5): the silhouette paint is the single most expensive
## step of building a model (~0.35-0.45 s of CPU rasterising) and it used
## to happen synchronously inside _ready — one frozen frame at spawn AND
## at boot (the demo bracket builds the same way). The mesh + material
## are still built immediately; only the texture paint is deferred to
## the next idle frame, and materialize's schematic fade waits for it.
var _schem_foot := Rect2()
var _schem_quad_m := 0.0
var _schematic_ready := false
var _schem_fade_pending := false

func _build_schematic() -> void:
	_schem_foot = Rect2(_bounds.position.x, _bounds.position.z, _bounds.size.x, _bounds.size.z)
	_schem_quad_m = maxf(_schem_foot.size.x, _schem_foot.size.y) * 1.7
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * _schem_quad_m
	_schematic_mat = StandardMaterial3D.new()
	_schematic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_schematic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_schematic_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_schematic = MeshInstance3D.new()
	_schematic.name = "Schematic"
	_schematic.mesh = quad
	_schematic.material_override = _schematic_mat
	_schematic.rotation_degrees.x = -90.0  # lie flat, texture top = -Z
	_schematic.position = Vector3(_bounds.get_center().x, SCHEMATIC_LIFT, _bounds.get_center().z)
	add_child(_schematic)
	call_deferred("_paint_schematic")

func _paint_schematic() -> void:
	# R1-12: the real part outline (top-down silhouette + actual through-holes); Blueprint.legacy = the old bbox + bolt layer
	_schematic_mat.albedo_texture = Blueprint.make(_schem_foot, _schem_quad_m) if Blueprint.legacy else Blueprint.make_silhouette(_parts, _schem_foot, _schem_quad_m)
	_schematic_ready = true
	if _schem_fade_pending:
		_schem_fade_pending = false
		var tw := create_tween()
		Ease.fd(tw.tween_method(_set_schematic_alpha, 0.0, 1.0, 0.5))

## Flat X / Z size labels just outside the blueprint's dimension lines.
func _build_dim_labels() -> void:
	var c := _bounds.get_center()
	var s := _bounds.size / display_scale
	var specs := [
		[s.x, Vector3(c.x, SCHEMATIC_LIFT, _bounds.end.z + DIM_LABEL_GAP), 0.0],
		[s.z, Vector3(_bounds.end.x + DIM_LABEL_GAP, SCHEMATIC_LIFT, c.z), 90.0],
	]
	var inches := [s.x / 0.0254, s.z / 0.0254]
	var long_form: bool = inches.any(func(v): return v >= 24.0) or s.y / 0.0254 >= 24.0
	for i in 2:
		var l := Label3D.new()
		l.name = "DimLabel%d" % i
		l.text = Units.len_in(inches[i], long_form) + ("" if long_form else " IN")
		_dim_texts.append(l.text)
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
	_tether_mesh = MeshInstance3D.new()
	_tether_mesh.name = "Tethers"
	_tether_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tether_mesh.material_override = _tether_mat
	add_child(_tether_mesh)
	for i in _parts.size():
		var p := _parts[i]
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
		_tethers.append({"part": p, "label": l})
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
	# Pass 1: each part's anchor (AABB centre) and its raw label tip.
	var n := _tethers.size()
	var anchors: Array[Vector3] = []
	var raw: Array[Vector3] = []
	var sides: Array[float] = []
	for t in _tethers:
		var p: MeshInstance3D = t["part"]
		var a: Vector3 = Transform3D(p.basis, p.position) * p.mesh.get_aabb().get_center()
		anchors.append(a)
		var side := 1.0 if a.x >= center_local.x else -1.0
		sides.append(side)
		raw.append(a + Vector3(side * TETHER_SIDE, TETHER_RISE, 0.0))
	# Pass 2 (R3-10): per side, fan the labels into two columns by height and enforce a minimum
	# vertical separation inside each column, recentred on the column's own span — at full explode
	# the clustered labels used to pile onto the same line and read as one smear.
	var adj: Array[Vector3] = []
	adj.resize(n)
	for side in [-1.0, 1.0]:
		var idx: Array[int] = []
		for i in n:
			if sides[i] == side:
				idx.append(i)
		idx.sort_custom(func(x: int, y: int) -> bool: return raw[x].y < raw[y].y)
		for col in 2:
			var members: Array[int] = []
			for k in idx.size():
				if k % 2 == col:
					members.append(idx[k])
			if members.is_empty():
				continue
			var ys: Array[float] = []
			for i in members:
				ys.append(raw[i].y)
			for j in range(1, ys.size()):
				ys[j] = maxf(ys[j], ys[j - 1] + TETHER_MIN_GAP)
			var shift := (raw[members[0]].y + raw[members[members.size() - 1]].y) * 0.5 - (ys[0] + ys[ys.size() - 1]) * 0.5
			for j in members.size():
				var i := members[j]
				adj[i] = Vector3(anchors[i].x + side * (TETHER_SIDE + col * TETHER_FAN), ys[j] + shift, raw[i].z)
	# Pass 2.5: pairwise relaxation — labels in NEIGHBOURING columns at the same height can still
	# collide when their captions are long; nudge overlapping pairs apart vertically until clear.
	# Overlap is judged in the READING plane: you look DOWN at the table, so a label farther away
	# projects HIGHER toward the horizon — depth leaks into screen height as y' = y - z * tan(tilt)
	# (measured -0.235 at the capture camera's 13 deg). A pair must be clear under BOTH a gentle
	# (0.24) and a steep (0.55) reading tilt; pairs too deep to clear by height alone also fan out in x.
	var halves: Array[Vector2] = []
	for i in n:
		var txt := _part_caption((_tethers[i]["part"] as MeshInstance3D).name, i)
		halves.append(Vector2(txt.length() * 40.0 * 0.0008 * 0.27, 0.030))
	for _pass in 40:
		var moved := false
		for i in n:
			for j in range(i + 1, n):
				var dxv := adj[j].x - adj[i].x
				if absf(dxv) >= halves[i].x + halves[j].x:
					continue
				var dyv := adj[j].y - adj[i].y
				var dzv := adj[j].z - adj[i].z
				var need := 0.0
				var dir := 1.0
				for k in [0.24, 0.55]:
					var dyp: float = dyv - float(k) * dzv
					if absf(dyp) < halves[i].y + halves[j].y:
						var req := halves[i].y + halves[j].y - absf(dyp) + 0.004
						if req > need:
							need = req
							dir = 1.0 if dyp >= 0.0 else -1.0
				if need <= 0.0:
					continue
				var dyv2 := dyv + need * dir
				var residual := 0.0
				for k in [0.24, 0.55]:
					residual = maxf(residual, halves[i].y + halves[j].y - absf(dyv2 - float(k) * dzv))
				if residual > 0.01:   # too deep to clear by height alone: fan apart in x as well
					var xneed := (halves[i].x + halves[j].x - absf(dxv)) + 0.01
					var sgn := 1.0 if dxv >= 0.0 else -1.0
					adj[j].x += xneed * 0.5 * sgn
					adj[i].x -= xneed * 0.5 * sgn
				adj[j].y += need * 0.5 * dir
				adj[i].y -= need * 0.5 * dir
				moved = true
		if not moved:
			break
	# Pass 3: park each label on its (possibly spread) tip, and rebuild the ONE
	# merged leader-line mesh (R4-3) — every tether is a thin oriented box in a
	# single ArrayMesh, so an exploded 27-part model costs 1 draw call for its
	# leaders instead of 27.
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n:
		var t: Dictionary = _tethers[i]
		var a := anchors[i]
		var tip := adj[i]
		var l: Label3D = t["label"]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if sides[i] > 0 else HORIZONTAL_ALIGNMENT_RIGHT
		l.position = tip + Vector3(sides[i] * 0.008, 0.012, 0.0)
		if _line_hidden.has(i):
			continue
		var d := tip - a
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		var xf := Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(1, 1, d.length())), a.lerp(tip, 0.5))
		var base := verts.size()
		for c in _TETHER_CORNERS:
			verts.append(xf * c)
		for k in _TETHER_IDX:
			idx.append(base + k)
	if _tether_mesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		if verts.size() > 0:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_tether_mesh.mesh = am

## A part's true size in the house format (X × Z × Y inches, feet+inches past 24 in) from its AABB.
func _part_dims_line(p: MeshInstance3D) -> String:
	var sz := p.mesh.get_aabb().size / display_scale
	return Units.dims_line([sz.x / 0.0254, sz.z / 0.0254, sz.y / 0.0254])

func set_tether_alpha(a: float) -> void:
	_tether_alpha = a
	_tether_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, a * 0.8)
	for t in _tethers:
		t["label"].modulate = Tokens.a(Tokens.HOLO_LINE, a)
	if _hot_part:
		_style_part(_hot_part, true)

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
	if _tether_mesh:
		_tether_mesh.visible = shown
	if _tether_mat:
		set_tether_alpha(0.0)
	for p in _parts:
		p.set_instance_shader_parameter(&"scan", scan)
		p.set_instance_shader_parameter(&"flash", flash_v)
		p.set_instance_shader_parameter(&"wire", wire)

func _set_param(v: float, param: StringName) -> void:
	for p in _parts:
		p.set_instance_shader_parameter(param, v)

## The painted flat-schematic texture (null until the deferred paint lands) — the data station's
## pedestal disc shows the same drawing across the room (R3-11).
func schematic_texture() -> Texture2D:
	return _schematic_mat.albedo_texture if _schematic_mat else null

func _set_schematic_alpha(a: float) -> void:
	_schematic_mat.albedo_color = Color(0.70, 0.85, 0.94, a * 0.68)
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
	for p in _parts:
		p.set_instance_shader_parameter(&"y0", y_lo)
		p.set_instance_shader_parameter(&"y1", y_hi)
	var tw := create_tween().set_parallel(true)
	if _schematic_ready:
		Ease.fd(tw.tween_method(_set_schematic_alpha, 0.0, 1.0, 0.5))
	else:
		_schem_fade_pending = true  # R2-4: _paint_schematic runs this fade when the texture lands
	Ease.fd(tw.tween_method(_set_param.bind(&"wire"), 0.0, 1.0, 0.35))
	tw.tween_method(_set_param.bind(&"scan"), 0.0, 1.15, 1.1).set_delay(0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_scan_plane_begin).set_delay(0.35)
	tw.tween_method(_set_scan_plane, 0.0, 1.0, 1.1).set_delay(0.35) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Ease.fd(tw.tween_method(_set_scan_plane_alpha, SCAN_PLANE_ALPHA, 0.0, 0.25).set_delay(1.2))
	tw.tween_callback(func() -> void: _scan_plane.visible = false).set_delay(1.45)
	Ease.fd(tw.tween_method(_set_param.bind(&"flash"), 1.0, 0.0, 0.5).set_delay(1.35))
	tw.tween_callback(labels_beat.emit).set_delay(1.75)
	tw.tween_callback(materialized.emit).set_delay(MATERIALIZE_TIME)
	await materialized
