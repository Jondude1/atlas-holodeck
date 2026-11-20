class_name Hud
extends Node3D
## HUD frame (brief #8, from concept-target-04): top status strip, two large slow-rotating arc
## frames, the EXPLODE radial gauge and a status card beside the Atlas panel.
## Real data only: clock from the system, LINK/BRAIN from Hub, PARTS/DIMS/EXPLODE from the model.
## Cost: ~13 draw calls (strip, 2 arcs, gauge, card + their labels).

const STRIP_POS := Vector3(0.0, 1.88, -2.4)
const STRIP_SIZE := Vector2(1.3, 0.12)
const ARC_X := 1.55
const ARC_Y := 1.5
const ARC_Z := -2.3
const ARC_SIZE := 1.9
const ARC_DEG_PER_SEC := 2.5
const ARC_ALPHA := 0.55
const GAUGE_SIZE := 0.5
const GAUGE_ALPHA := 0.95
const CARD_SIZE := Vector2(0.4, 0.34)
const CARD_DROP := 0.5      # metres below the Atlas panel's centre (the panel is 0.6 m tall with the voice row)
const MIC_POS := Vector3(0.0, -0.19, 0.0)   # voice indicator sits just under the status strip
const SUBTITLE_POS := Vector3(0.0, -0.33, 0.0)
const TEXT_PX := 0.0009

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
uniform vec4 line_color : source_color;
uniform float alpha = 0.5;
uniform float seed = 0.0;
float band(float r, float c, float w) { return smoothstep(w, 0.0, abs(r - c)); }
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.x, -p.y) / TAU + 0.5;
	float i = 0.0;
	// outer broken arc, thick, with two gaps
	float gap = step(0.08, fract(a * 3.0 + seed)) * step(fract(a * 3.0 + seed), 0.93);
	i += band(r, 0.96, 0.012) * gap * 1.4;
	i += band(r, 0.92, 0.004) * step(0.35, fract(a * 2.0 + seed * 0.7)) * 0.9;
	// tick ring
	float t = step(0.7, fract(a * 90.0));
	float major = step(0.92, fract(a * 18.0));
	i += t * smoothstep(0.012, 0.0, abs(r - 0.86 - major * 0.01)) * 0.8;
	i += major * smoothstep(0.02, 0.0, abs(r - 0.85)) * 1.2;
	// inner hairline rings
	i += band(r, 0.74, 0.003) * step(0.2, fract(a * 5.0 + seed)) * 0.7;
	i += band(r, 0.66, 0.003) * 0.5;
	i *= smoothstep(1.0, 0.97, r);
	ALBEDO = line_color.rgb * i;
	ALPHA = clamp(i, 0.0, 1.0) * alpha;
}
"""

const GAUGE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled;
uniform vec4 line_color : source_color;
uniform vec4 core_color : source_color;
uniform float value = 0.0;
uniform float alpha = 1.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.x, -p.y) / TAU + 0.5;
	float seg = floor(a * 60.0) / 60.0;
	float cell = step(0.12, fract(a * 60.0));
	float on = step(seg + 0.0001, value);
	float band = step(0.66, r) * step(r, 0.86) * cell;
	vec3 col = mix(line_color.rgb * 0.18, mix(line_color.rgb, core_color.rgb, 0.35), on);
	float i = band * mix(0.25, 1.0, on);
	// thin outer + inner rings
	float ring = smoothstep(0.012, 0.0, abs(r - 0.95)) + smoothstep(0.01, 0.0, abs(r - 0.58)) * 0.7;
	i += ring * 0.7;
	col = mix(col, line_color.rgb, clamp(ring, 0.0, 1.0));
	// 12 major ticks
	i += step(0.9, fract(a * 12.0 + 0.04)) * step(0.88, r) * step(r, 0.93) * 0.9;
	i *= smoothstep(1.0, 0.97, r);
	ALBEDO = col * i;
	ALPHA = clamp(i, 0.0, 1.0) * alpha;
}
"""

var _model: Node
var _table: Node
var _fade := 1.0
var _clock: Label3D
var _link: Label3D
var _gauge_mat: ShaderMaterial
var _gauge_pct: Label3D
var _card_text: Label3D
var _arc_mats: Array[ShaderMaterial] = []
var _arcs: Array[MeshInstance3D] = []
var _frame_mats: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _voice: VoiceLink
var _mic_orb: MeshInstance3D
var _mic_orb_mat: StandardMaterial3D
var _mic_label: Label3D
var _subtitle: Label3D
var _subtitle_hold := 0.0
var _last_second := -1
var _last_link := "~unset"

func build(model: Node, table: Node) -> void:
	_model = model
	_table = table
	_build_strip()
	_build_arcs()
	_build_gauge()
	_build_card()
	_build_mic()
	_model.explode_changed.connect(_on_explode)
	_on_explode(0.0)
	_refresh_text()
	set_fade(1.0)

## The assembly on show changed (a voice-CAD model arrived): gauge, PARTS and DIMS follow it.
func set_model(m: Node) -> void:
	if _model and _model.explode_changed.is_connected(_on_explode):
		_model.explode_changed.disconnect(_on_explode)
	_model = m
	_model.explode_changed.connect(_on_explode)
	_on_explode(m.explode_value)
	_refresh_text()

func bind_voice(v: VoiceLink) -> void:
	_voice = v
	v.state_changed.connect(func(_s: int) -> void: _refresh_text())
	v.heard.connect(func(_t: String) -> void: _subtitle_hold = 0.0)
	_refresh_text()

func set_fade(v: float) -> void:
	_fade = v
	for m in _arc_mats:
		m.set_shader_parameter("alpha", ARC_ALPHA * v)
	if _gauge_mat:
		_gauge_mat.set_shader_parameter("alpha", GAUGE_ALPHA * v)
	for m in _frame_mats:
		m.albedo_color = Color(1, 1, 1, v)
	for l in _labels:
		l.modulate.a = v
	if _mic_orb_mat:
		_mic_orb_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, 0.0)

func _process(delta: float) -> void:
	for a in _arcs:
		a.rotate_object_local(Vector3.FORWARD, deg_to_rad(ARC_DEG_PER_SEC) * delta * a.get_meta("dir"))
	_animate_mic(delta)
	var sec := int(Time.get_unix_time_from_system())
	if sec != _last_second or Hub.link != _last_link:
		_last_second = sec
		_last_link = Hub.link
		_refresh_text()

func _refresh_text() -> void:
	_clock.text = "HOLODECK • LIVE • %s" % Time.get_time_string_from_system()
	_link.text = "LINK — %s" % (Hub.link if Hub.link != "" else "CHECKING")
	var text := "LINK    %s\nBRAIN   %s\nPARTS   %d\nDIMS    %s" % [
		Hub.link if Hub.link != "" else "CHECKING",
		Hub.brain if Hub.brain != "" else "CHECKING",
		_model.part_names().size(), _model.dims_text()]
	if _voice:
		text += "\nVOICE   %s" % _voice.state_text()
	if CadBench.status != "":
		text += "\nCAD     %s" % CadBench.status
	_card_text.text = text

func _on_explode(t: float) -> void:
	_gauge_mat.set_shader_parameter("value", t)
	_gauge_pct.text = "%d%%" % roundi(t * 100.0)

# ---------------------------------------------------------------- voice indicator

## Persistent mic indicator (Atlas rule: no ambiguity about whether the mic is hot). An orb + words under the strip:
## MIC LIVE (steady cyan glow) / LISTENING (bright core, fast pulse driven by the real input level) / THINKING /
## SPEAKING / MIC OFF (dark). Plus a subtitle line with the last thing heard or said.
func _build_mic() -> void:
	_mic_orb_mat = Fx.glow_decal(Tokens.a(Tokens.HOLO_LINE, 0.0), Fx.radial_texture(64, 1.2))
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.2
	_mic_orb = MeshInstance3D.new()
	_mic_orb.name = "MicOrb"
	_mic_orb.mesh = q
	_mic_orb.material_override = _mic_orb_mat
	_mic_orb.position = STRIP_POS + MIC_POS + Vector3(-0.17, 0.0, 0.004)
	add_child(_mic_orb)
	_mic_label = _label("MIC OFF", 56, Tokens.GRID_MINOR, STRIP_POS + MIC_POS + Vector3(-0.07, 0.0, 0.004))
	_mic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle = _label("", 40, Tokens.HOLO_LINE, STRIP_POS + SUBTITLE_POS + Vector3(0, 0, 0.004))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.width = 1300.0

func _animate_mic(delta: float) -> void:
	if _voice == null or _mic_orb_mat == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var alpha := 0.1
	var scl := 0.7
	var col := Tokens.GRID_MINOR
	match _voice.state:
		VoiceLink.S.ARMED:
			col = Tokens.HOLO_LINE
			if _voice.wake_enabled:
				alpha = 0.55 + 0.1 * sin(t * 2.0)
				scl = 0.8 + 0.5 * _voice.mic_level
			else:
				alpha = 0.18                    # PTT-only: the mic is OFF, the orb is a dim "hold to talk" marker
				scl = 0.7
		VoiceLink.S.LISTENING:
			col = Tokens.HOLO_CORE
			alpha = 1.0
			scl = 1.15 + 0.2 * sin(t * 9.0) + 0.6 * _voice.mic_level
		VoiceLink.S.THINKING:
			col = Tokens.HOLO_PRIMARY
			alpha = 0.5 + 0.3 * sin(t * 5.0)
			scl = 0.9
		VoiceLink.S.SPEAKING:
			col = Tokens.HOLO_PRIMARY
			alpha = 0.75
			scl = 1.0 + 0.18 * sin(t * 7.0)
	_mic_orb_mat.albedo_color = Tokens.a(col, alpha * _fade)
	_mic_orb.scale = Vector3(scl, scl, 1.0)
	_mic_label.text = _voice.state_text()
	_mic_label.modulate = Tokens.a(col, _fade)
	var sub := _voice.subtitle
	_subtitle.text = sub
	_subtitle.modulate = Tokens.a(Tokens.HOLO_CORE if _voice.state == VoiceLink.S.LISTENING else Tokens.HOLO_LINE, _fade)

# ---------------------------------------------------------------- pieces

func _label(text: String, size_px: int, col: Color, pos: Vector3, parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load(Tokens.FONT_BOLD)
	l.font_size = size_px
	l.pixel_size = TEXT_PX
	l.shaded = false
	l.outline_size = 0
	l.modulate = col
	l.position = pos
	parent.add_child(l)
	_labels.append(l)
	return l

## Dark translucent panel with a 1 px cyan border and a chamfered corner (per the renderings).
func _frame_texture(px: Vector2i) -> ImageTexture:
	var img := Image.create(px.x, px.y, false, Image.FORMAT_RGBA8)
	img.fill(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA))
	var c := 18
	for k in c:  # clip the top-left and bottom-right corners
		img.fill_rect(Rect2i(0, k, c - k, 1), Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(px.x - (c - k), px.y - 1 - k, c - k, 1), Color(0, 0, 0, 0))
	var line := Tokens.HOLO_LINE
	var t := 2
	Blueprint._line(img, Vector2(c, 0), Vector2(px.x, 0), line, t)
	Blueprint._line(img, Vector2(0, c), Vector2(c, 0), line, t)
	Blueprint._line(img, Vector2(0, c), Vector2(0, px.y), line, t)
	Blueprint._line(img, Vector2(0, px.y - 1), Vector2(px.x - c, px.y - 1), line, t)
	Blueprint._line(img, Vector2(px.x - c, px.y - 1), Vector2(px.x - 1, px.y - c), line, t)
	Blueprint._line(img, Vector2(px.x - 1, 0), Vector2(px.x - 1, px.y - c), line, t)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _frame_quad(nm: String, size: Vector2, px: Vector2i, xf: Transform3D) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _frame_texture(px)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame_mats.append(m)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = q
	mi.material_override = m
	mi.transform = xf
	add_child(mi)
	return mi

func _build_strip() -> void:
	var strip := _frame_quad("StatusStrip", STRIP_SIZE, Vector2i(520, 48), Transform3D(Basis.IDENTITY, STRIP_POS))
	_clock = _label("", 48, Tokens.HOLO_LINE, Vector3(-STRIP_SIZE.x * 0.5 + 0.05, 0, 0.002), strip)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_link = _label("", 48, Tokens.HOLO_LINE, Vector3(STRIP_SIZE.x * 0.5 - 0.05, 0, 0.002), strip)
	_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_arcs() -> void:
	var shader := Shader.new()
	shader.code = ARC_SHADER
	for side in [-1.0, 1.0]:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("line_color", Tokens.HOLO_LINE)
		m.set_shader_parameter("seed", 0.0 if side < 0 else 0.37)
		_arc_mats.append(m)
		var q := QuadMesh.new()
		q.size = Vector2.ONE * ARC_SIZE
		var mi := MeshInstance3D.new()
		mi.name = "HudArc%s" % ("L" if side < 0 else "R")
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(side * ARC_X, ARC_Y, ARC_Z)
		mi.rotation_degrees.y = -side * 24.0  # turn toward the workspace
		mi.set_meta("dir", -side)             # the two frames counter-rotate
		add_child(mi)
		_arcs.append(mi)

func _build_gauge() -> void:
	var shader := Shader.new()
	shader.code = GAUGE_SHADER
	_gauge_mat = ShaderMaterial.new()
	_gauge_mat.shader = shader
	_gauge_mat.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	_gauge_mat.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * GAUGE_SIZE
	var mi := MeshInstance3D.new()
	mi.name = "ExplodeGauge"
	mi.mesh = q
	mi.material_override = _gauge_mat
	# sits inside the left arc frame, same yaw
	mi.position = Vector3(-ARC_X, ARC_Y, ARC_Z + 0.02)
	mi.rotation_degrees.y = 24.0
	add_child(mi)
	_gauge_pct = _label("0%", 80, Tokens.HOLO_CORE, Vector3(0, 0.02, 0.003), mi)
	_label("EXPLODE", 36, Tokens.HOLO_LINE, Vector3(0, -0.05, 0.003), mi)

func _build_card() -> void:
	var panel := get_node_or_null("../UIPanel") as Node3D
	var xf := Transform3D(Basis.IDENTITY, Vector3(1.55, 1.35, -1.15))
	if panel:
		xf = Transform3D(panel.transform.basis.orthonormalized(), panel.transform.origin)
	xf.origin += xf.basis * Vector3(0, -CARD_DROP, 0)
	var card := _frame_quad("StatusCard", CARD_SIZE, Vector2i(320, 272), xf)
	_label("STATUS", 40, Tokens.HOLO_CORE, Vector3(-CARD_SIZE.x * 0.5 + 0.03, CARD_SIZE.y * 0.5 - 0.04, 0.002), card).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card_text = _label("", 36, Tokens.HOLO_LINE, Vector3(-CARD_SIZE.x * 0.5 + 0.03, CARD_SIZE.y * 0.5 - 0.075, 0.002), card)
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_card_text.line_spacing = 6.0
