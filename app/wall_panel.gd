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
var _chrome_draw: Control
var _rule: ColorRect
var _display_mat: StandardMaterial3D
var _pic_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _lines: Array = []
var _built := false
# P4 live-feeling data: text panels advance their chrome phase on a slow staggered
# tick (one UPDATE_ONCE repaint per tick, never per-frame). Pictures never tick.
const LIVE_INTERVAL := 0.9
const LIVE_STEP := 0.45
var _live_t := 0.0
var _live_phase := 0.0

func live_phase() -> float:
	return _live_phase

## One live tick. Returns true when it actually repainted (text/clock states only).
func tick_live() -> bool:
	if not _built or _chrome_draw == null or type_name() == "PICTURE":
		return false
	_live_phase += LIVE_STEP
	var chrome := _chrome_draw as _PanelChrome
	chrome.wave_phase = _live_phase
	chrome.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return true

## Instrument chrome layer drawn inside the SubViewport on UPDATE_ONCE (zero 3D draw cost):
## subtle technical micro-grid, thin cyan inner border + corner L-brackets, concentric Stark
## ring gauge on the right (clear of text), and dual-trace oscilloscope strip along the bottom.
class _PanelChrome extends Control:
	var is_clock := false
	var wave_seed := 0.6
	var wave_phase := 0.0   # P4 live tick: advances ~0.45 rad per tick, shifts both traces + gauge breathing
	var gauge_val := 0.5
	var is_large := true

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		# 1. Faint technical micro-grid inside the dark glass
		var grid_col := Color(0.24, 0.76, 0.88, 0.065)
		var step := 32.0
		var gx := 12.0 + step
		while gx < w - 12.0:
			draw_line(Vector2(gx, 12.0), Vector2(gx, h - 12.0), grid_col, 1.0)
			gx += step
		var gy := 12.0 + step
		while gy < h - 12.0:
			draw_line(Vector2(12.0, gy), Vector2(w - 12.0, gy), grid_col, 1.0)
			gy += step
		# 2. Thin teal inner border + bright corner L-brackets
		var border_col := Color(0.35, 0.86, 0.96, 0.34)
		var r := Rect2(10.0, 10.0, w - 20.0, h - 20.0)
		draw_rect(r, border_col, false, 1.5)
		var brk := Color(0.55, 0.95, 1.0, 0.82)
		var bl := 16.0
		var bw := 2.5
		# top-left, top-right, bottom-left, bottom-right brackets
		draw_line(Vector2(10.0, 10.0), Vector2(10.0 + bl, 10.0), brk, bw)
		draw_line(Vector2(10.0, 10.0), Vector2(10.0, 10.0 + bl), brk, bw)
		draw_line(Vector2(w - 10.0, 10.0), Vector2(w - 10.0 - bl, 10.0), brk, bw)
		draw_line(Vector2(w - 10.0, 10.0), Vector2(w - 10.0, 10.0 + bl), brk, bw)
		draw_line(Vector2(10.0, h - 10.0), Vector2(10.0 + bl, h - 10.0), brk, bw)
		draw_line(Vector2(10.0, h - 10.0), Vector2(10.0, h - 10.0 - bl), brk, bw)
		draw_line(Vector2(w - 10.0, h - 10.0), Vector2(w - 10.0 - bl, h - 10.0), brk, bw)
		draw_line(Vector2(w - 10.0, h - 10.0), Vector2(w - 10.0, h - 10.0 - bl), brk, bw)

		# 3. Section hairlines (right gauge bay + bottom oscilloscope strip)
		var div_col := Color(0.32, 0.84, 0.96, 0.18)
		var split_x := w - (168.0 if is_large else 148.0)
		var wave_top := h - (108.0 if is_large else 96.0)
		if is_clock:
			draw_line(Vector2(split_x, 22.0), Vector2(split_x, h - 22.0), div_col, 1.0)
		else:
			draw_line(Vector2(split_x, 22.0), Vector2(split_x, wave_top - 10.0), div_col, 1.0)
			draw_line(Vector2(22.0, wave_top), Vector2(w - 22.0, wave_top), div_col, 1.0)

		# 4. Concentric Stark ring gauge in the right bay (never overlaps text)
		var cen := Vector2(split_x + (w - 10.0 - split_x) * 0.5, (h * 0.5) if is_clock else (wave_top * 0.52))
		var rad := 56.0 if is_large else 48.0
		var track_col := Color(0.28, 0.78, 0.92, 0.24)
		var tick_col := Color(0.42, 0.90, 1.0, 0.36)
		var arc_col := Color(0.52, 0.96, 1.0, 0.82)
		draw_arc(cen, rad, 0.0, TAU, 48, track_col, 2.0, true)
		draw_arc(cen, rad * 0.74, 0.0, TAU, 36, Color(0.28, 0.78, 0.92, 0.22), 1.2, true)
		draw_arc(cen, rad * 0.46, 0.0, TAU, 24, Color(0.32, 0.82, 0.94, 0.18), 1.0, true)
		# 24 radial ticks around outer ring
		for ti in 24:
			var ang := float(ti) / 24.0 * TAU
			var major := (ti % 6) == 0
			var r0 := rad - (8.0 if major else 4.5)
			var r1 := rad + (2.0 if major else 0.0)
			draw_line(cen + Vector2(cos(ang), sin(ang)) * r0, cen + Vector2(cos(ang), sin(ang)) * r1,
					arc_col if major else tick_col, 1.8 if major else 1.0, true)
		# Active progress sweep + subtle inner accent arc
		var a0 := deg_to_rad(135.0)
		var sweep := deg_to_rad(270.0 * clampf(gauge_val + sin(wave_phase * 0.7) * 0.03, 0.04, 1.0))
		draw_arc(cen, rad, a0, a0 + sweep, 40, arc_col, 3.2, true)
		draw_arc(cen, rad * 0.74, a0 + 0.3, a0 + sweep * 0.75 + 0.3, 28, Color(0.45, 0.92, 1.0, 0.45), 1.8, true)
		draw_circle(cen, 3.0, Color(0.62, 0.96, 1.0, 0.7))

		# 5. Dual-trace oscilloscope waveform in the bottom strip (text states)
		if not is_clock:
			var mid_y := wave_top + (h - 14.0 - wave_top) * 0.52
			var x0 := 24.0
			var x1 := w - 24.0
			draw_line(Vector2(x0, mid_y), Vector2(x1, mid_y), Color(0.26, 0.76, 0.90, 0.16), 1.0)
			# Small axis tick marks along baseline
			var tx := x0
			while tx <= x1:
				draw_line(Vector2(tx, mid_y - 3.5), Vector2(tx, mid_y + 3.5), Color(0.32, 0.82, 0.94, 0.22), 1.0)
				tx += 28.0
			var pts1 := PackedVector2Array()
			var pts2 := PackedVector2Array()
			var amp := 24.0 if is_large else 20.0
			var xx := x0
			while xx <= x1:
				var u := (xx - x0) / maxf(x1 - x0, 1.0)
				var env := sin(u * PI)
				var ph := wave_seed + wave_phase
				var y1 := mid_y + (sin(xx * 0.052 + ph) * 0.55 + sin(xx * 0.13 + ph * 2.1) * 0.28 + sin(xx * 0.019 + ph * 0.7) * 0.17) * amp * (0.35 + 0.65 * env)
				var y2 := mid_y + (sin(xx * 0.031 + ph * 1.4 + 1.2) * 0.6 + cos(xx * 0.085 - ph) * 0.4) * (amp * 0.55) * (0.3 + 0.7 * env)
				pts1.append(Vector2(xx, y1))
				pts2.append(Vector2(xx, y2))
				xx += 6.0
			if pts2.size() >= 2:
				draw_polyline(pts2, Color(0.25, 0.78, 0.92, 0.26), 1.6, true)
			if pts1.size() >= 2:
				draw_polyline(pts1, Color(0.45, 0.95, 1.0, 0.68), 2.2, true)

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
	# frame: slim dark recessed charcoal border + near-black backing, one merged mesh
	var mb := MeshBuilder.new()
	var ti := Tokens.TITANIUM_DARK.lerp(Tokens.TITANIUM, 0.16)
	var back := Color(0.008, 0.014, 0.020)
	var bw := 0.022
	mb.add_box(Vector3(0, 0, -0.006), Vector3(size.x + 0.016, size.y + 0.016, 0.012), back)
	mb.add_box(Vector3(0, size.y * 0.5 + bw * 0.5, 0.004), Vector3(size.x + bw * 2.0, bw, 0.026), ti)
	mb.add_box(Vector3(0, -size.y * 0.5 - bw * 0.5, 0.004), Vector3(size.x + bw * 2.0, bw, 0.026), ti)
	mb.add_box(Vector3(-size.x * 0.5 - bw * 0.5, 0, 0.004), Vector3(bw, size.y, 0.026), ti)
	mb.add_box(Vector3(size.x * 0.5 + bw * 0.5, 0, 0.004), Vector3(bw, size.y, 0.026), ti)
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.metallic = 0.45
	fm.roughness = 0.52
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
	_display_mat.albedo_color = Color(0.84, 0.95, 1.0, 1.0)
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
	_live_t = -float(abs(pid.hash()) % 70) / 100.0   # stagger panels so ticks don't repaint all at once
	set_process(true)

func _build_viewport() -> void:
	_vp = SubViewport.new()
	var is_lg := size_kind == "large"
	_vp.size = Vector2i(640, 360) if is_lg else Vector2i(512, 320)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.transparent_bg = false
	add_child(_vp)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.007, 0.020, 0.032, 1.0)   # R8 polish: deep recessed teal-black instrument glass
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var chrome := _PanelChrome.new()
	chrome.is_large = is_lg
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(chrome)
	_chrome_draw = chrome
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 184 if is_lg else 164)
	margin.add_theme_constant_override("margin_bottom", 112 if is_lg else 100)
	margin.add_child(vbox)
	root.add_child(margin)
	_title = _mk_label(vbox, 30 if is_lg else 26, Color(0.68, 0.95, 1.0, 0.95), true)
	_rule = ColorRect.new()
	_rule.color = Color(0.38, 0.90, 1.0, 0.40)
	_rule.custom_minimum_size = Vector2(0, 1.5)
	vbox.add_child(_rule)
	_body = _mk_label(vbox, 22 if is_lg else 20, Color(0.56, 0.88, 0.97, 0.88), false)
	_body.add_theme_constant_override("line_spacing", 5)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clock = _mk_label(vbox, 78 if is_lg else 68, Color(0.76, 0.97, 1.0, 0.96), true)
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
		_clock.text = str(_lines[0]) if _lines.size() > 0 else ""
		_body.visible = _lines.size() > 1
		if _lines.size() > 1:
			_body.text = str(_lines[1])
	else:
		_title.visible = true
		_body.visible = true
		_clock.visible = false
		_title.text = str(_lines[0]) if _lines.size() > 0 else ""
		var rest: Array = []
		for i in range(1, _lines.size()):
			rest.append(str(_lines[i]))
		_body.text = "\n".join(rest)
	_decorate()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## R8 polish: update the instrument chrome parameters and queue one crisp redraw.
func _decorate() -> void:
	if _chrome_draw == null:
		return
	var is_clock := type_name() == "CLOCK"
	_rule.visible = not is_clock
	var val := 0.0
	if is_clock:
		val = float(Time.get_time_dict_from_system().second) / 60.0
	else:
		val = 0.25 + float(abs(_title.text.hash()) % 65) / 100.0
	var chrome := _chrome_draw as _PanelChrome
	chrome.is_clock = is_clock
	chrome.wave_seed = float(state) * 1.37 + 0.6
	chrome.gauge_val = val
	chrome.queue_redraw()

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
	# P4 live tick runs whether or not the panel is held (presentation only).
	if _built and type_name() != "PICTURE":
		_live_t += delta
		if _live_t >= LIVE_INTERVAL:
			_live_t = 0.0
			tick_live()
	if _hand == null:
		return
	_grab_t += delta
	var target := _clampedv(_hand_wall_coords(_hand) - _grab_off)
	_u = lerpf(_u, target.x, clampf(delta * 14.0, 0.0, 1.0))
	_v = lerpf(_v, target.y, clampf(delta * 14.0, 0.0, 1.0))
	_place()

func _clampedv(uv: Vector2) -> Vector2:
	return _clamped(uv.x, uv.y)
