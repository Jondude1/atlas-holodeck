extends Node3D
## Floating UI: a SubViewport rendered on a quad. The controller pointer calls pick()
## to turn a world ray into a panel pixel, then push() to feed mouse events in.

@export var model_path: NodePath
@onready var _quad: MeshInstance3D = $Quad
@onready var _vp: SubViewport = $SubViewport
@onready var _model: Node = get_node(model_path)
var _slider: HSlider
var _parts_header: Label
var _parts_scroll: ScrollContainer
var _parts_list: VBoxContainer
var _part_buttons: Array[Button] = []
var _scale_t := 0.0
var _voice: VoiceLink
var _voice_label: Label
var _mic_button: Button
var _talk_button: Button
var _print: PrintFlow
var _card: PanelContainer               # the send-to-print confirmation card (R1-8), over the whole panel while a request is open
var _card_title: Label
var _card_body: Label
var _card_hint: Label
var _card_confirm: Button
var _card_cancel: Button
# Round 2.5: the parts/library list toggle + delete confirmation card
var _list_mode := "parts"                # "parts" | "library" — the scroll area below the slider shows one or the other
var _lib_toggle: Button
var _lib_entries: Array = []
var _lib_card: PanelContainer
var _lib_title: Label
var _lib_body: Label
var _lib_confirm: Button
var _lib_cancel: Button
var _lib_pending: Dictionary = {}
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

const SHOWN_SCALE_FROM := 0.9
const PART_ROWS := 4
const PART_ROW_H := 44
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
	poke(2.0)
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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ATLAS HOLODECK"
	title.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	title.add_theme_font_size_override("font_size", 40)
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
	slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(self, "explode"))
	slider.value_changed.connect(_on_slider)
	box.add_child(slider)
	_slider = slider

	box.add_child(_build_parts_block())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for s in [0.5, 1.0, 2.0]:
		var b := Button.new()
		b.text = "%s×" % s
		b.custom_minimum_size = Vector2(110, 60)
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
	var true_b := _action_button("TRUE SIZE", Vector2(0, 60), 28)
	true_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	true_b.pressed.connect(func() -> void: _model.set_true_scale())
	row.add_child(true_b)

	box.add_child(_build_talk_button())
	box.add_child(_build_voice_row())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	var reset_model := _action_button("RESET MODEL", Vector2(0, 60), 30)   # model back to table centre (cad_bench)
	reset_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_model.pressed.connect(func() -> void:
		var bench := get_tree().get_first_node_in_group("cad_bench")
		if bench:
			bench.reset_active()
		else:
			_model.reset_pose())
	bottom.add_child(reset_model)
	var fix_floor := _action_button("FIX FLOOR HEIGHT", Vector2(0, 60), 30)  # was RESET FLOOR: moves YOUR height, not the model
	fix_floor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fix_floor.pressed.connect(XrBoot.reset_floor.bind("panel"))
	bottom.add_child(fix_floor)
	_vista_button = _action_button("VIEW: COAST", Vector2(0, 60), 24)   # Round 5: cycle the world outside the open wall
	_vista_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vista_button.pressed.connect(func() -> void:
		if _vista:
			_vista.cycle())
	bottom.add_child(_vista_button)
	box.add_child(bottom)

	var send := _action_button("SEND TO PRINTER", Vector2(0, 60), 30)   # opens the confirmation card; never prints by itself
	send.pressed.connect(func() -> void:
		if _print and _model:
			_print.request_for(_model))
	box.add_child(send)
	_build_print_card()
	_build_lib_card()

## Shared styling for the plain action buttons (tick on hover, light pulse + confirm on press).
func _action_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	b.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
	b.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
	b.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 1))
	b.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_LINE, 2))
	b.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_button_pressed.bind(b))
	b.mouse_entered.connect(Sfx.play.bind(self, "tick"))
	return b

## The real part list (R1-6): header with count + scale readout, a scrollable column of one button per named part
## (press = pin the part's highlight + name on the model, press again to clear), and up/down scroll buttons for the
## pointer (a controller can't drag-scroll).
func _build_parts_block() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	v.add_child(hrow)
	_parts_header = Label.new()
	_parts_header.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_parts_header.add_theme_font_size_override("font_size", 28)
	_parts_header.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	_parts_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(_parts_header)
	_lib_toggle = _action_button("LIBRARY ▸", Vector2(190, 44), 24)
	_lib_toggle.pressed.connect(_toggle_list_mode)
	hrow.add_child(_lib_toggle)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	_parts_scroll = ScrollContainer.new()
	_parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_parts_scroll.custom_minimum_size = Vector2(0, PART_ROWS * (PART_ROW_H + 4) - 4)
	_parts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_parts_scroll)
	_parts_list = VBoxContainer.new()
	_parts_list.add_theme_constant_override("separation", 4)
	_parts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_scroll.add_child(_parts_list)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	for dir in [-1, 1]:
		var sb := _action_button("▲" if dir < 0 else "▼", Vector2(64, (PART_ROWS * (PART_ROW_H + 4) - 12) / 2), 28)
		sb.add_theme_stylebox_override("normal", StyleBoxEmpty.new())   # text-only at rest: one 2D draw instead of two
		sb.pressed.connect(scroll_parts.bind(dir))
		col.add_child(sb)
	h.add_child(col)
	_rebuild_part_list()
	return v

func scroll_parts(dir: int) -> void:
	poke()
	_parts_scroll.scroll_vertical = maxi(0, _parts_scroll.scroll_vertical + dir * (PART_ROW_H + 4) * 3)

func _rebuild_part_list() -> void:
	poke()
	for c in _parts_list.get_children():
		c.queue_free()
		_parts_list.remove_child(c)
	_part_buttons.clear()
	var names: PackedStringArray = _model.part_names()
	_parts_header.text = "PARTS · %d    SCALE %s" % [names.size(), _model.scale_label()]
	for i in names.size():
		var b := _action_button(_model.part_caption(i), Vector2(0, PART_ROW_H), 26)
		b.name = "Part%d" % i
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())    # rows are text at rest (hover/pressed draw the box)
		b.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
		b.toggled.connect(_on_part_toggled.bind(i))
		_parts_list.add_child(b)
		_part_buttons.append(b)
	_parts_scroll.scroll_vertical = 0

func _on_part_toggled(on: bool, i: int) -> void:
	if on:
		for k in _part_buttons.size():           # one pinned part at a time
			if k != i and _part_buttons[k].button_pressed:
				_part_buttons[k].set_pressed_no_signal(false)
		_model.highlight_part(_model.part_node(i), true)
	else:
		_model.clear_highlight()

## The panel is static most of the time, so its SubViewport renders only while something is happening (pointer input,
## voice state, list/model change = poke). Round 2 (R2-6): at idle the viewport is now fully DISABLED (Godot 4 has
## no when-dirty mode for SubViewport) — every content change funnels through poke() (the text setters compare
## before setting), expiry draws one final ONCE frame, and a slow 5 s safety pulse covers anything un-poked.
## Before R2-6, idle forced a full re-render every 0.5 s (~34 draw calls each, forever).
const PANEL_SAFETY_REFRESH := 5.0
const PANEL_POKE_S := 1.2
var _poke_t := PANEL_POKE_S
var _idle_t := 0.0
var _safety_flip := false

func poke(seconds := PANEL_POKE_S) -> void:
	_poke_t = maxf(_poke_t, seconds)

func _process(delta: float) -> void:
	if _card and _card.visible and _print and _print.is_confirming():
		var t := "or say YES or NO  ·  closes in %d s" % ceili(_print.seconds_left())
		if t != _card_hint.text:
			_card_hint.text = t
			poke()
	if _safety_flip:
		_safety_flip = false
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _poke_t > 0.0:
		_poke_t -= delta
		_idle_t = 0.0
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_idle_t += delta
		if _vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE  # one final clean frame, then off
			_safety_flip = true
		elif _idle_t >= PANEL_SAFETY_REFRESH:
			_idle_t = 0.0
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			_safety_flip = true
	_scale_t += delta
	if _scale_t > 0.25 and _parts_header and _model and _list_mode == "parts":
		_scale_t = 0.0
		var t := "PARTS · %d    SCALE %s" % [_part_buttons.size(), _model.scale_label()]
		if t != _parts_header.text:
			_parts_header.text = t
			poke()

## Big HOLD-TO-TALK control (primary way to talk): press = mic live + LISTENING + tone, release = the utterance is sent.
func _build_talk_button() -> Button:
	_talk_button = Button.new()
	_talk_button.text = "HOLD TO TALK"
	_talk_button.name = "TalkButton"
	_talk_button.custom_minimum_size = Vector2(0, 84)
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
	poke()
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
	if _model and _model != m and is_instance_valid(_model):
		_model.clear_highlight()
	_model = m
	_list_mode = "parts"
	_lib_toggle.text = "LIBRARY ▸"
	_slider.set_value_no_signal(0.0)
	_last_tick = 0
	_rebuild_part_list()

func _on_slider(v: float) -> void:
	poke()
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
	Ease.fd(tw.tween_property(b, "modulate", Color.WHITE, 0.25))
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
	poke()
	_vp.push_input(ev)

# ---------------------------------------------------------------- send-to-print confirmation card (R1-8, dry run)

func _build_print_card() -> void:
	_card = PanelContainer.new()
	_card.name = "PrintCard"
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := _flat(Color(Tokens.HOLO_DEEP.r * 0.8, Tokens.HOLO_DEEP.g * 0.8, Tokens.HOLO_DEEP.b * 0.8, 1.0), Tokens.HOLO_CORE, 3)
	sb.set_content_margin_all(28)
	_card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_card.add_child(box)
	_card_title = Label.new()
	_card_title.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_card_title.add_theme_font_size_override("font_size", 44)
	_card_title.add_theme_color_override("font_color", Tokens.HOLO_CORE)
	box.add_child(_card_title)
	_card_body = Label.new()
	_card_body.add_theme_font_size_override("font_size", 32)
	_card_body.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_card_body)
	_card_hint = Label.new()
	_card_hint.add_theme_font_size_override("font_size", 26)
	_card_hint.add_theme_color_override("font_color", Tokens.GRID_MINOR.lightened(0.5))
	box.add_child(_card_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_card_confirm = _action_button("CONFIRM", Vector2(0, 90), 40)
	_card_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_confirm.pressed.connect(func() -> void: if _print: _print.confirm("panel"))
	row.add_child(_card_confirm)
	_card_cancel = _action_button("CANCEL", Vector2(0, 90), 40)
	_card_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_cancel.pressed.connect(func() -> void:
		if _print:
			if _print.state == PrintFlow.S.CONFIRMING:
				_print.cancel("panel")
			else:
				_print.dismiss())
	row.add_child(_card_cancel)
	_card.visible = false
	_vp.add_child(_card)

var _vista: VistaDeck
var _vista_button: Button

func bind_vista(v: VistaDeck) -> void:
	_vista = v
	_vista_button.text = "VIEW: %s" % v.current().to_upper()
	v.vista_changed.connect(func(nm: String) -> void:
		_vista_button.text = "VIEW: %s" % nm.to_upper()
		poke())

func bind_print(pf: PrintFlow) -> void:
	_print = pf
	pf.state_changed.connect(_on_print_state)

func _on_print_state(s: int) -> void:
	poke(3.0)
	_card.visible = s != PrintFlow.S.IDLE
	if _card.visible:
		get_tree().call_group("holodeck_main", "show_chrome")
	_card_confirm.visible = s == PrintFlow.S.CONFIRMING or s == PrintFlow.S.SUBMITTING
	_card_confirm.disabled = s == PrintFlow.S.SUBMITTING
	_card_cancel.text = "CANCEL" if s == PrintFlow.S.CONFIRMING else "DISMISS"
	_card_cancel.disabled = s == PrintFlow.S.SUBMITTING
	var i := _print.info
	match s:
		PrintFlow.S.CONFIRMING:
			_card_title.text = "SEND TO PRINTER?"
			_card_body.text = "PART       %s\nMATERIAL   %s\nPRINTER    %s\nEST. TIME  ~ %s\n\nDRY RUN: this build only plans the print. The printer is not contacted." % [
					String(i.get("name", "?")).to_upper(), i.get("material", "PLA"), i.get("printer", "S1"), i.get("est_text", "?")]
			_card_hint.text = "or say YES or NO"
		PrintFlow.S.SUBMITTING:
			_card_title.text = "PLANNING..."
			_card_hint.text = ""
		PrintFlow.S.DONE:
			var would: Dictionary = _print.plan.get("would", {})
			_card_title.text = "DRY RUN COMPLETE"
			_card_body.text = "WOULD SLICE  %s\nPRINTER      %s\nPROFILE      %s\n\nNOT SLICED. PRINTER NOT CONTACTED." % [
					String(would.get("file", "?")).get_file(), would.get("printer", "?"), would.get("profile", "?")]
			_card_hint.text = "live printing needs Jon's separate sign-off"
		PrintFlow.S.FAILED:
			_card_title.text = "COULDN'T PLAN"
			_card_body.text = _print.reason.to_upper()
			_card_hint.text = ""

# ---------------------------------------------------------------- Round 2.5: Parts Library view (brief #18)
## The same scroll area as the part list, toggled: LIBRARY lists every part saved on Athena (Holodeck
## save-backs + imported STLs). Tap a row to fetch it onto the table; EDIT (Holodeck parts only) fetches
## and primes a voice revision; DEL asks on a confirmation card first — nothing is deleted from one tap.

func _toggle_list_mode() -> void:
	poke()
	if _list_mode == "parts":
		_list_mode = "library"
		_lib_toggle.text = "◂ PARTS"
		_show_library()
	else:
		_list_mode = "parts"
		_lib_toggle.text = "LIBRARY ▸"
		_rebuild_part_list()

func set_list_mode(mode: String) -> void:   # test + programmatic entry point
	if mode == "library" and _list_mode != "library":
		_toggle_list_mode()
	elif mode == "parts" and _list_mode != "parts":
		_toggle_list_mode()

func _bench() -> Node:
	return get_tree().get_first_node_in_group("cad_bench")

func _fmt_dims(dims: Variant) -> String:
	if not (dims is Array) or (dims as Array).size() != 3:
		return ""
	var parts: Array[String] = []
	for v in dims:
		parts.append(("%0.2f" % float(v)).trim_suffix("0").trim_suffix("."))
	return " × ".join(parts) + " IN"

func _fmt_date(epoch: Variant) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(int(epoch))
	return "%s %d" % [MONTHS[clampi(int(dt.get("month", 1)) - 1, 0, 11)], int(dt.get("day", 1))]

func _show_library() -> void:
	poke()
	_parts_header.text = "LIBRARY — LOADING..."
	for c in _parts_list.get_children():
		c.queue_free()
		_parts_list.remove_child(c)
	_part_buttons.clear()
	if Hub.base_url == "":
		_parts_header.text = "LIBRARY — HUB OFFLINE"
		_lib_placeholder("THE HUB ISN'T REACHABLE — THE LIBRARY LIVES ON ATHENA")
		return
	var bench := _bench()
	if bench == null:
		_lib_placeholder("NO BENCH — CAN'T FETCH")
		return
	_lib_entries = await bench.fetch_library()
	if _list_mode != "library":
		return   # the user flipped back while the list was in flight
	_rebuild_library_list()

func _lib_placeholder(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Tokens.GRID_MINOR.lightened(0.4))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parts_list.add_child(l)

func _rebuild_library_list() -> void:
	poke()
	for c in _parts_list.get_children():
		c.queue_free()
		_parts_list.remove_child(c)
	_parts_header.text = "LIBRARY · %d" % _lib_entries.size()
	if _lib_entries.is_empty():
		_lib_placeholder("NOTHING SAVED YET — PARTS YOU MAKE LAND HERE")
		return
	for e in _lib_entries:
		_parts_list.add_child(_lib_row(e))
	_parts_scroll.scroll_vertical = 0

func _lib_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var main_b := _action_button("", Vector2(0, PART_ROW_H), 23)
	main_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_b.text = "%s · %s · %s" % [String(entry.get("name", "?")).to_upper(), _fmt_dims(entry.get("dims_in", [])), _fmt_date(entry.get("created", 0))]
	main_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	main_b.pressed.connect(_on_lib_fetch.bind(entry))
	row.add_child(main_b)
	if bool(entry.get("editable", false)):
		var edit_b := _action_button("EDIT", Vector2(88, PART_ROW_H), 22)
		edit_b.name = "LibEdit"
		edit_b.pressed.connect(_on_lib_edit.bind(entry))
		row.add_child(edit_b)
	var del_b := _action_button("DEL", Vector2(80, PART_ROW_H), 22)
	del_b.name = "LibDel"
	del_b.pressed.connect(request_library_delete.bind(entry))
	row.add_child(del_b)
	return row

func library_row_count() -> int:
	return _lib_entries.size() if _list_mode == "library" else 0

func library_row_has_edit(i: int) -> bool:
	if i < 0 or i >= _parts_list.get_child_count():
		return false
	return _parts_list.get_child(i).get_node_or_null("LibEdit") != null

func _on_lib_fetch(entry: Dictionary) -> void:
	var bench := _bench()
	if bench:
		bench.load_library(entry)

func _on_lib_edit(entry: Dictionary) -> void:
	var bench := _bench()
	if bench == null:
		return
	bench.spawned.connect(func(_m: Node) -> void:
		if _voice:
			_voice.say("That's the %s from your library. Say the change, and I'll revise it in place." % String(entry.get("name", "part"))), CONNECT_ONE_SHOT)
	bench.load_library(entry)

# ---------------------------------------------------------- delete confirmation (never one tap)

func _build_lib_card() -> void:
	_lib_card = PanelContainer.new()
	_lib_card.name = "LibraryCard"
	_lib_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := _flat(Color(Tokens.HOLO_DEEP.r * 0.8, Tokens.HOLO_DEEP.g * 0.8, Tokens.HOLO_DEEP.b * 0.8, 1.0), Tokens.HOLO_CORE, 3)
	sb.set_content_margin_all(28)
	_lib_card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_lib_card.add_child(box)
	_lib_title = Label.new()
	_lib_title.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_lib_title.add_theme_font_size_override("font_size", 44)
	_lib_title.add_theme_color_override("font_color", Tokens.HOLO_CORE)
	box.add_child(_lib_title)
	_lib_body = Label.new()
	_lib_body.add_theme_font_size_override("font_size", 32)
	_lib_body.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	_lib_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lib_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_lib_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_lib_confirm = _action_button("DELETE IT", Vector2(0, 90), 40)
	_lib_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lib_confirm.pressed.connect(confirm_library_delete)
	row.add_child(_lib_confirm)
	_lib_cancel = _action_button("CANCEL", Vector2(0, 90), 40)
	_lib_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lib_cancel.pressed.connect(cancel_library_delete)
	row.add_child(_lib_cancel)
	_lib_card.visible = false
	_vp.add_child(_lib_card)

func request_library_delete(entry: Dictionary) -> void:
	poke(3.0)
	_lib_pending = entry
	_lib_title.text = "DELETE FROM LIBRARY?"
	_lib_body.text = "PART   %s\n\nThis deletes the saved files on Athena. It can't be undone." % String(entry.get("name", "?")).to_upper()
	_lib_confirm.visible = true
	_lib_cancel.text = "CANCEL"
	_lib_card.visible = true
	get_tree().call_group("holodeck_main", "show_chrome")

func cancel_library_delete() -> void:
	poke()
	_lib_pending = {}
	_lib_card.visible = false

func confirm_library_delete() -> void:
	if _lib_pending.is_empty():
		return
	var entry := _lib_pending
	_lib_pending = {}
	var bench := _bench()
	var ok := false
	if bench:
		ok = await bench.delete_library(entry)
	if ok:
		_lib_card.visible = false
		if _voice:
			_voice.say("Deleted the %s from the library." % String(entry.get("name", "part")))
		if _list_mode == "library":
			_show_library()
	else:
		_lib_title.text = "COULDN'T DELETE"
		_lib_body.text = "THE HUB DIDN'T CONFIRM THE DELETE. THE PART IS STILL IN THE LIBRARY."
		_lib_confirm.visible = false
		_lib_cancel.text = "DISMISS"
		poke(3.0)
