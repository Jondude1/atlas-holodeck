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

	var parts := Label.new()
	parts.text = "Parts: " + ", ".join(_model.part_names())
	parts.add_theme_font_size_override("font_size", 28)
	parts.add_theme_color_override("font_color", Tokens.HOLO_LINE)
	box.add_child(parts)

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
		b.pressed.connect(_model.set_model_scale.bind(s))
		b.pressed.connect(_on_button_pressed.bind(b))
		b.mouse_entered.connect(Sfx.play.bind(self, "tick"))
		row.add_child(b)

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
