class_name WallPanel
extends Node3D
## Round 6-2 — one wall widget (Jon: "readouts and things on the wall be items I can move
## around and make into pictures or readouts that matter to me"). A framed panel that
## lives on one wall: GRAB it and slide it along the wall (it stays where you leave it);
## TAP its left/right edge (a quick grab-and-release without dragging) to step through
## what it shows — OVERVIEW / MODEL / LIBRARY / HUB / CLOCK, then every PICTURE in the
## ring, then back to OVERVIEW. Content is pushed in by WallWidgets (real data only);
## text panels render through a SubViewport on UPDATE_ONCE discipline, pictures are a
## plain textured quad (no viewport cost). Implements the hand system's grabbable
## contract (the Prop pattern) with wall-plane movement instead of free movement.

signal changed(panel: WallPanel)   # position or content state changed — owner persists

const TYPES := ["OVERVIEW", "MODEL", "LIBRARY", "HUB", "CLOCK"]
const WALLS := {
	"left": {"pos": -3.94, "yaw": 90.0, "umin": -4.5, "umax": 2.5},
	"right": {"pos": 3.94, "yaw": -90.0, "umin": -4.5, "umax": 2.5},
	"front": {"pos": 2.94, "yaw": 180.0, "umin": -3.5, "umax": 3.5},
}

var pid := ""
var wall := "left"
var size_kind := "small"           # "large" | "small"
var size := Vector2(0.95, 0.6)
var state := 0                     # ring index: 0..TYPES-1, then TYPES+i = picture i
var pictures: Array = []           # res:// paths, set by the owner before build()

var center_local := Vector3.ZERO
var grab_radius := 0.95

var _u := 0.0                      # along-wall coordinate (world z on side walls, x on front)
var _v := 1.6                      # height
var _hand: Node3D = null
var _grab_off := Vector2.ZERO      # hand (u,v) minus panel (u,v) at grab time
var _grab_frac := 0.0              # where across the panel the grab landed (-1..1)
var _grab_t := 0.0
var _grab_start := Vector2.ZERO
var _vp: SubViewport
var _title: Label
var _body: Label
var _clock: Label
var _wave: Line2D
var _gauge: Line2D
var _rule: ColorRect
var _display_mat: StandardMaterial3D
var _pic_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _lines: Array = []
var _built := false

func type_name() -> String:
	if state < TYPES.size():
		return TYPES[state]
	return "PICTURE"

func picture_index() -> int:
	return state - TYPES.size()

func ring_size() -> int:
	return TYPES.size() + pictures.size()

func step_state(dir: int) -> void:
	state = (state + dir) % ring_size()
	if state < 0:
		state += ring_size()
	_apply_content()
	changed.emit(self)

func build(pictures_in: Array) -> void:
	pictures = pictures_in
	size = Vector2(1.5, 0.85) if size_kind == "large" else Vector2(0.95, 0.6)
	grab_radius = size.x * 0.62
	add_to_group("grabbable")
	# frame: titanium border + dark backing, one merged mesh
	var mb := MeshBuilder.new()
	var ti := Tokens.TITANIUM_DARK.lerp(Tokens.TITANIUM, 0.45)
	var back := Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, 0.25)
	var bw := 0.035
	mb.add_box(Vector3(0, 0, -0.006), Vector3(size.x + 0.02, size.y + 0.02, 0.012), back)
	mb.add_box(Vector3(0, size.y * 0.5 + bw * 0.5, 0.004), Vector3(size.x + bw * 2.0, bw, 0.03), ti)
	mb.add_box(Vector3(0, -size.y * 0.5 - bw * 0.5, 0.004), Vector3(size.x + bw * 2.0, bw, 0.03), ti)
	mb.add_box(Vector3(-size.x * 0.5 - bw * 0.5, 0, 0.004), Vector3(bw, size.y, 0.03), ti)
	mb.add_box(Vector3(size.x * 0.5 + bw * 0.5, 0, 0.004), Vector3(bw, size.y, 0.03), ti)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.metallic = 0.5
	fm.roughness = 0.45
	frame.mesh = mb.build()
	frame.material_override = fm
	add_child(frame)
	# hover rim: an additive quad just behind the frame, lit when a hand hovers
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_rim_mat.albedo_color = Color(Tokens.HOLO_LINE, 0.0)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rq := QuadMesh.new()
	rq.size = size + Vector2(0.11, 0.11)
	rim.mesh = rq
	rim.material_override = _rim_mat
	rim.position = Vector3(0, 0, -0.004)
	add_child(rim)
	# the display quad (viewport texture, or a picture texture in PICTURE state)
	_display_mat = StandardMaterial3D.new()
	_display_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_display_mat.albedo_color = Color(0.75, 0.9, 1.0, 1.0)
	var disp := MeshInstance3D.new()
	disp.name = "Display"
	var dq := QuadMesh.new()
	dq.size = size
	disp.mesh = dq
	disp.material_override = _display_mat
	disp.position = Vector3(0, 0, 0.012)
	add_child(disp)
	_build_viewport()
	_place()
	_apply_content()
	_built = true
	set_process(true)

func _build_viewport() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 360) if size_kind == "large" else Vector2i(512, 320)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.transparent_bg = false
	add_child(_vp)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.028, 0.042, 1.0)   # R8: near-black teal, the target's display glass
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# R8 framed-display dressing (all inside the viewport texture — zero 3D cost):
	# a thin bright inner border, a waveform trace along the bottom, a ring gauge.
	var edge := Color(0.40, 0.95, 1.0, 0.38)
	for rect in [Rect2(9, 9, _vp.size.x - 18, 3), Rect2(9, _vp.size.y - 12, _vp.size.x - 18, 3),
			Rect2(9, 9, 3, _vp.size.y - 18), Rect2(_vp.size.x - 12, 9, 3, _vp.size.y - 18)]:
		var b := ColorRect.new()
		b.color = edge
		b.position = rect.position
		b.size = rect.size
		root.add_child(b)
	_wave = Line2D.new()
	_wave.width = 2.5
	_wave.default_color = Color(0.35, 0.95, 1.0, 0.45)
	_wave.antialiased = true
	root.add_child(_wave)
	_gauge = Line2D.new()
	_gauge.width = 3.5
	_gauge.default_color = Color(0.45, 0.97, 1.0, 0.6)
	_gauge.antialiased = true
	root.add_child(_gauge)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.add_child(vbox)
	root.add_child(margin)
	_title = _mk_label(vbox, 40, Tokens.HOLO_CORE, true)
	_rule = ColorRect.new()
	_rule.color = Color(0.40, 0.95, 1.0, 0.35)
	_rule.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(_rule)
	_body = _mk_label(vbox, 31, Color(0.75, 0.88, 1.0), false)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clock = _mk_label(vbox, 92, Tokens.HOLO_CORE, true)
	_clock.visible = false
	_vp.add_child(root)
	_display_mat.albedo_texture = _vp.get_texture()

func _mk_label(parent: Control, px: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(Tokens.FONT_BOLD if bold else Tokens.FONT_REGULAR))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

## Content push from the owner (text states). No-op cost when unchanged.
func set_lines(lines: Array) -> void:
	if lines == _lines or not _built:
		return
	_lines = lines.duplicate()
	if type_name() == "PICTURE":
		return
	_render_text()

func _render_text() -> void:
	if type_name() == "CLOCK":
		_title.visible = false
		_body.visible = false
		_clock.visible = true
		_clock.text = String(_lines[0]) if _lines.size() > 0 else ""
		_body.visible = _lines.size() > 1
		if _lines.size() > 1:
			_body.text = String(_lines[1])
		_decorate()
	else:
		_title.visible = true
		_body.visible = true
		_clock.visible = false
		_title.text = String(_lines[0]) if _lines.size() > 0 else ""
		var rest: Array = []
		for i in range(1, _lines.size()):
			rest.append(String(_lines[i]))
		_body.text = "\n".join(rest)
	_decorate()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## R8: redraw the framed-display dressing for the current state — a waveform
## trace (text states, seeded per state so each panel's trace differs), a ring
## gauge top-right (clock: live seconds sweep; text: a resting value hashed
## from the title), and the header rule (text states only).
func _decorate() -> void:
	if _wave == null:
		return
	var w := float(_vp.size.x)
	var h := float(_vp.size.y)
	var is_clock := type_name() == "CLOCK"
	_rule.visible = not is_clock
	_wave.visible = not is_clock
	if not is_clock:
		var seed := float(state) * 1.37 + 0.6
		var pts := PackedVector2Array()
		var x := 26.0
		while x <= w - 26.0:
			pts.append(Vector2(x, h - 58.0 + sin(x * 0.045 + seed) * 10.0 + sin(x * 0.013 + seed * 1.7) * 6.0))
			x += 8.0
		_wave.points = pts
	var val := 0.0
	if is_clock:
		val = float(Time.get_time_dict_from_system().second) / 60.0
	else:
		val = float(abs(_title.text.hash()) % 100) / 100.0
	var gp := PackedVector2Array()
	var cen := Vector2(w - 88.0, 96.0)
	var sweep := 270.0 * clampf(val, 0.02, 1.0)
	var a := 135.0
	while a <= 135.0 + sweep:
		var r := deg_to_rad(a)
		gp.append(cen + Vector2(cos(r), sin(r)) * 54.0)
		a += 6.0
	_gauge.points = gp

func _apply_content() -> void:
	if not _built:
		return
	if type_name() == "PICTURE":
		var idx := picture_index()
		if idx >= 0 and idx < pictures.size():
			if _pic_mat == null:
				_pic_mat = StandardMaterial3D.new()
				_pic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_pic_mat.albedo_texture = load(pictures[idx])
			# swap the display quad to the picture material
			(get_node("Display") as MeshInstance3D).material_override = _pic_mat
	else:
		(get_node("Display") as MeshInstance3D).material_override = _display_mat
		_render_text()

# ---------------------------------------------------------------- placement

func set_spot(wall_in: String, u: float, v: float) -> void:
	wall = wall_in
	_u = u
	_v = v
	_place()

func spot() -> Dictionary:
	return {"wall": wall, "u": _u, "v": _v, "state": state}

func _place() -> void:
	var w: Dictionary = WALLS[wall]
	var clamped := _clamped(_u, _v)
	_u = clamped.x
	_v = clamped.y
	if wall == "front":
		position = Vector3(_u, _v, float(w["pos"]))
	else:
		position = Vector3(float(w["pos"]), _v, _u)
	rotation_degrees = Vector3(0, float(w["yaw"]), 0)

func _clamped(u: float, v: float) -> Vector2:
	var w: Dictionary = WALLS[wall]
	var hw := size.x * 0.5 + 0.06
	var hh := size.y * 0.5 + 0.06
	return Vector2(
		clampf(u, float(w["umin"]) + hw, float(w["umax"]) - hw),
		clampf(v, 0.45 + hh, 3.05 - hh))

# ---------------------------------------------------------------- the hand contract

func can_grab(hand: Node3D) -> bool:
	if _hand != null:
		return false
	return global_position.distance_to(hand.global_position) <= grab_radius + 0.25

func is_held() -> bool:
	return _hand != null

func begin_grab(hand: Node3D) -> void:
	_hand = hand
	var hv := _hand_wall_coords(hand)
	_grab_off = hv - Vector2(_u, _v)
	var local := to_local(hand.global_position)
	_grab_frac = clampf(local.x / (size.x * 0.5), -1.0, 1.0)
	_grab_start = Vector2(_u, _v)
	_grab_t = 0.0
	if hand.has_method("buzz"):
		hand.buzz(0.03, 0.5)

func end_grab(hand: Node3D) -> void:
	if hand != _hand:
		return
	_hand = null
	if hand.has_method("buzz"):
		hand.buzz(0.02, 0.3)
	var moved := Vector2(_u, _v).distance_to(_grab_start)
	if _grab_t < 0.3 and moved < 0.04:
		# a tap: step the content ring by which edge was grabbed
		if _grab_frac > 0.32:
			step_state(1)
			return
		if _grab_frac < -0.32:
			step_state(-1)
			return
	# a drag (or a centre tap): settle on the snap grid and persist
	_u = snappedf(_u, 0.05)
	_v = snappedf(_v, 0.05)
	_place()
	changed.emit(self)

func set_all_hot(v: bool) -> void:
	if _rim_mat:
		_rim_mat.albedo_color = Color(Tokens.HOLO_LINE, 0.30 if v else 0.0)

## The hand's position in this panel's wall coordinates.
func _hand_wall_coords(hand: Node3D) -> Vector2:
	var p := hand.global_position
	if wall == "front":
		return Vector2(p.x, p.y)
	return Vector2(p.z, p.y)

func _process(delta: float) -> void:
	if _hand == null:
		return
	_grab_t += delta
	var target := _clampedv(_hand_wall_coords(_hand) - _grab_off)
	_u = lerpf(_u, target.x, clampf(delta * 14.0, 0.0, 1.0))
	_v = lerpf(_v, target.y, clampf(delta * 14.0, 0.0, 1.0))
	_place()

func _clampedv(uv: Vector2) -> Vector2:
	return _clamped(uv.x, uv.y)
