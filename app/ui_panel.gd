extends Node3D
## Floating UI: a SubViewport rendered on a quad. The controller pointer calls pick()
## to turn a world ray into a panel pixel, then push() to feed mouse events in.

@export var model_path: NodePath
@onready var _quad: MeshInstance3D = $Quad
@onready var _vp: SubViewport = $SubViewport
@onready var _model: Node = get_node(model_path)
var _slider: HSlider
var _parts_label: Label
var _voice: VoiceLink
var _voice_label: Label
var _mic_button: Button
var _talk_button: Button

const SHOWN_SCALE_FROM := 0.9
const TICK_STEP := 0.05  # slider ticks every 5%

var _mat: StandardMaterial3D
var _shown := false  # the pointer can't hit the panel until it has started to appear
var _last_tick := -1

func _ready() -> void:
	add_to_group("ui_panel")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_texture = _vp.get_texture()
	_mat.albedo_color = Color(1, 1, 1, 0)
	_quad.material_override = _mat
	_build_ui()
	scale = Vector3.ONE * SHOWN_SCALE_FROM

## Boot finished: scale 0.9 -> 1 and fade in with easing.
func reveal() -> void:
	_shown = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mat, "albedo_color:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

func _flat(fill: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(8)
	return sb

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 2)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	_vp.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ATLAS HOLODECK"
	title.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Tokens.HOLO_CORE)
	box.add_child(title)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 44)
	slider.add_theme_stylebox_override("slider", _flat(Tokens.a(Tokens.GRID_MINOR, 0.6), Color(0, 0, 0, 0), 0))
	slider.add_theme_stylebox_override("grabber_area", _flat(Tokens.HOLO_PRIMARY, Color(0, 0, 0, 0), 0))
	slider.add_theme_stylebox_override("grabber_area_highlight", _flat(Tokens.HOLO_LINE, Color(0, 0, 0, 0), 0))
	slider.value_changed.connect(func(v: float) -> void: _model.set_explode(v))   # follows set_model()
	slider.value_changed.connect(_on_slider)
	box.add_child(slider)
	_slider = slider

	var parts := Label.new()
	parts.text = "Parts: " + ", ".join(_model.part_names())
	parts.add_theme_font_size_override("font_size", 28)
	parts.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	parts.clip_text = true
	parts.custom_minimum_size = Vector2(0, 34)
	box.add_child(parts)
	_parts_label = parts

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for s in [0.5, 1.0, 2.0]:
		var b := Button.new()
		b.text = "%s×" % s
		b.custom_minimum_size = Vector2(150, 60)
		b.add_theme_font_size_override("font_size", 32)
		b.add_theme_color_override("font_color", Tokens.HOLO_LINE)
		b.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
		b.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
		b.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 1))
		b.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_LINE, 2))
		b.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: _model.set_model_scale(s))
		b.pressed.connect(_on_button_pressed.bind(b))
		b.mouse_entered.connect(Sfx.play.bind(self, "tick"))
		row.add_child(b)

	box.add_child(_build_talk_button())
	box.add_child(_build_voice_row())

	var reset := Button.new()
	reset.text = "RESET FLOOR"
	reset.custom_minimum_size = Vector2(0, 60)
	reset.add_theme_font_size_override("font_size", 32)
	reset.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	reset.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
	reset.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
	reset.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 1))
	reset.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_LINE, 2))
	reset.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
	reset.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	reset.pressed.connect(XrBoot.reset_floor.bind("panel"))
	reset.pressed.connect(_on_button_pressed.bind(reset))
	reset.mouse_entered.connect(Sfx.play.bind(self, "tick"))
	box.add_child(reset)

## Big HOLD-TO-TALK control (primary way to talk): press = mic live + LISTENING + tone, release = the utterance is sent.
func _build_talk_button() -> Button:
	_talk_button = Button.new()
	_talk_button.text = "HOLD TO TALK"
	_talk_button.name = "TalkButton"
	_talk_button.custom_minimum_size = Vector2(0, 96)
	_talk_button.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_talk_button.add_theme_font_size_override("font_size", 52)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_talk_button.add_theme_color_override(c, Tokens.HOLO_CORE if c != "font_color" else Tokens.HOLO_LINE)
	_talk_button.add_theme_color_override("font_disabled_color", Tokens.GRID_MINOR)
	_talk_button.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 2))
	_talk_button.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_CORE, 3))
	_talk_button.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.5), Tokens.HOLO_CORE, 4))
	_talk_button.add_theme_stylebox_override("disabled", _flat(Tokens.a(Tokens.HOLO_DEEP, 0.4), Tokens.GRID_MINOR, 1))
	_talk_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_talk_button.button_down.connect(func() -> void:
		if _voice:
			_voice.ptt_begin())
	_talk_button.button_up.connect(func() -> void:
		if _voice:
			_voice.ptt_end())
	_talk_button.mouse_entered.connect(Sfx.play.bind(self, "tick"))
	return _talk_button

## Voice row: the persistent mic state (what the headset is doing with the microphone, in words) and the MUTE control.
func _build_voice_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_voice_label = Label.new()
	_voice_label.text = "● VOICE OFFLINE"
	_voice_label.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_voice_label.add_theme_font_size_override("font_size", 34)
	_voice_label.add_theme_color_override("font_color", Tokens.GRID_MINOR)
	_voice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_voice_label)
	_mic_button = Button.new()
	_mic_button.text = "MUTE VOICE"
	_mic_button.custom_minimum_size = Vector2(250, 60)
	_mic_button.add_theme_font_size_override("font_size", 32)
	_mic_button.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	_mic_button.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
	_mic_button.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
	_mic_button.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 1))
	_mic_button.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_LINE, 2))
	_mic_button.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
	_mic_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_mic_button.pressed.connect(func() -> void:
		if _voice:
			_voice.toggle_muted())
	_mic_button.pressed.connect(_on_button_pressed.bind(_mic_button))
	_mic_button.mouse_entered.connect(Sfx.play.bind(self, "tick"))
	row.add_child(_mic_button)
	return row

## Wires the voice state to the row: the label says exactly what the mic is doing, the button mutes/unmutes.
func bind_voice(v: VoiceLink) -> void:
	_voice = v
	v.state_changed.connect(_on_voice_state)
	_on_voice_state(v.state)

func _on_voice_state(s: int) -> void:
	var live := _voice.is_streaming()
	var col := Tokens.GRID_MINOR
	match s:
		VoiceLink.S.ARMED: col = Tokens.HOLO_LINE
		VoiceLink.S.LISTENING: col = Tokens.HOLO_CORE
		VoiceLink.S.THINKING, VoiceLink.S.SPEAKING: col = Tokens.HOLO_PRIMARY
	_voice_label.text = "● " + _voice.state_text()
	_voice_label.add_theme_color_override("font_color", col)
	_mic_button.text = "UNMUTE VOICE" if s == VoiceLink.S.MUTED else ("ENABLE MIC" if s == VoiceLink.S.NO_PERMISSION else "MUTE VOICE")
	_mic_button.add_theme_color_override("font_color", Tokens.HOLO_CORE if live else Tokens.HOLO_LINE)
	_talk_button.disabled = not (s == VoiceLink.S.ARMED or s == VoiceLink.S.LISTENING or s == VoiceLink.S.SPEAKING)
	match s:
		VoiceLink.S.LISTENING: _talk_button.text = "LISTENING..."
		VoiceLink.S.THINKING: _talk_button.text = "THINKING..."
		VoiceLink.S.MUTED: _talk_button.text = "VOICE MUTED"
		VoiceLink.S.OFFLINE, VoiceLink.S.NO_PERMISSION: _talk_button.text = "VOICE UNAVAILABLE"
		_: _talk_button.text = "HOLD TO TALK"

## Retarget the explode slider / parts line / scale buttons to a newly spawned model.
func set_model(m: Node) -> void:
	_model = m
	_slider.set_value_no_signal(0.0)
	_last_tick = 0
	_parts_label.text = "Parts: " + ", ".join(m.part_names())

func _on_slider(v: float) -> void:
	var step := int(v / TICK_STEP)
	if step != _last_tick:
		_last_tick = step
		Sfx.play(self, "tick")

## Confirm sound + a brief light pulse: modulate flashes from holo_core back to white.
func _on_button_pressed(b: Button) -> void:
	Sfx.play(self, "confirm")
	b.pivot_offset = b.size * 0.5
	b.modulate = Tokens.HOLO_CORE
	b.scale = Vector2.ONE * 0.94
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "modulate", Color.WHITE, 0.25)
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## World ray -> Vector3(pixel_x, pixel_y, distance), or null if it misses the panel.
func pick(origin: Vector3, dir: Vector3) -> Variant:
	if not _shown:
		return null
	var inv := _quad.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	if absf(d.z) < 1e-5:
		return null
	var t := -o.z / d.z
	if t < 0.0:
		return null
	var p := o + d * t
	var size: Vector2 = _quad.mesh.size
	if absf(p.x) > size.x * 0.5 or absf(p.y) > size.y * 0.5:
		return null
	var uv := Vector2(p.x / size.x + 0.5, 0.5 - p.y / size.y)
	return Vector3(uv.x * _vp.size.x, uv.y * _vp.size.y, t * dir.length())

func push(ev: InputEvent) -> void:
	_vp.push_input(ev)
