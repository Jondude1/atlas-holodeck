extends Node3D
## Floating UI: a SubViewport rendered on a quad. The controller pointer calls pick()
## to turn a world ray into a panel pixel, then push() to feed mouse events in.

@export var model_path: NodePath
@onready var _quad: MeshInstance3D = $Quad
@onready var _vp: SubViewport = $SubViewport
@onready var _model: Node = get_node(model_path)

const SHOWN_SCALE_FROM := 0.9
const TICK_STEP := 0.05  # slider ticks every 5%

var _mat: StandardMaterial3D
var _slider: HSlider
var _scale_buttons: Array[Button] = []
var _cock: Button
var _fire: Button
var _reset: Button
var _wt_down: Button
var _wt_up: Button
var _weight: Label
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
	slider.value_changed.connect(_model.set_explode)
	slider.value_changed.connect(_on_slider)
	box.add_child(slider)
	_slider = slider

	var parts := Label.new()
	parts.text = "Parts (%d): %s" % [_model.part_names().size(), ", ".join(_model.part_names())]
	parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parts.custom_minimum_size = Vector2(590, 0)
	parts.add_theme_font_size_override("font_size", 19)
	parts.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	box.add_child(parts)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for s in [0.5, 1.0, 2.0]:
		var b := _button("%s×" % s, 150)
		b.pressed.connect(_model.set_model_scale.bind(s))
		row.add_child(b)
		_scale_buttons.append(b)

	if _model.has_method("cock"):
		_build_machine_row(box)

func _button(text: String, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 60)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	b.add_theme_color_override("font_hover_color", Tokens.HOLO_CORE)
	b.add_theme_color_override("font_pressed_color", Tokens.HOLO_CORE)
	b.add_theme_color_override("font_disabled_color", Tokens.a(Tokens.HOLO_LINE, 0.3))
	b.add_theme_stylebox_override("normal", _flat(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA), Tokens.HOLO_LINE, 1))
	b.add_theme_stylebox_override("hover", _flat(Tokens.a(Tokens.HOLO_PRIMARY, 0.45), Tokens.HOLO_LINE, 2))
	b.add_theme_stylebox_override("pressed", _flat(Tokens.a(Tokens.HOLO_CORE, 0.4), Tokens.HOLO_CORE, 2))
	b.add_theme_stylebox_override("disabled", _flat(Tokens.a(Tokens.HOLO_DEEP, 0.25), Tokens.a(Tokens.HOLO_LINE, 0.25), 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_on_button_pressed.bind(b))
	b.mouse_entered.connect(_on_hover.bind(b))
	return b

func _on_hover(b: Button) -> void:
	if not b.disabled:
		Sfx.play(self, "tick")

## Trebuchet controls: COCK / FIRE / RESET, WT- / WT+, and the weight readout. Buttons enable by
## the machine's state; explode + scale lock while it is throwing.
func _build_machine_row(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_cock = _button("COCK", 140)
	_fire = _button("FIRE", 140)
	_reset = _button("RESET", 140)
	_cock.pressed.connect(_model.cock)
	_fire.pressed.connect(_model.fire)
	_reset.pressed.connect(_model.reset)
	for b in [_cock, _fire, _reset]:
		row.add_child(b)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 12)
	box.add_child(wrow)
	_wt_down = _button("WT −", 110)
	_wt_up = _button("WT +", 110)
	_wt_down.pressed.connect(_model.weight_down)
	_wt_up.pressed.connect(_model.weight_up)
	wrow.add_child(_wt_down)
	wrow.add_child(_wt_up)
	_weight = Label.new()
	_weight.add_theme_font_override("font", load(Tokens.FONT_BOLD))
	_weight.add_theme_font_size_override("font_size", 30)
	_weight.add_theme_color_override("font_color", Tokens.HOLO_CORE)
	_weight.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrow.add_child(_weight)
	_model.state_changed.connect(_refresh_machine.unbind(1))
	_model.weight_changed.connect(_refresh_machine)
	_refresh_machine()

func _refresh_machine() -> void:
	_cock.disabled = not _model.can_cock()
	_fire.disabled = not _model.can_fire()
	_reset.disabled = not _model.can_reset()
	_wt_down.disabled = not _model.can_weight() or _model.blocks <= 1
	_wt_up.disabled = not _model.can_weight() or _model.blocks >= _model.MAX_BLOCKS
	_weight.text = _model.weight_text()
	var locked: bool = _model.is_busy()
	_slider.editable = not locked
	for b in _scale_buttons:
		b.disabled = locked

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
