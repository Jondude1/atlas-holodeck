class_name RefBoard
extends Prop
## R7-3 reference board: a picture pulled off the wall to stand by the work.
## A framed print on a foot — grab it, carry it, set it down anywhere a Prop can
## rest (table, benches, floor); it stays where it is put. Grab it twice in quick
## succession to flip to the next picture. Same pictures as the wall panels.

var _pics: Array = []               # Array[Texture2D]
var _pic_idx := 0
var _display: MeshInstance3D
var _last_grab_ms := -10000

func build(texs: Array) -> void:
	_pics = texs
	var mb := MeshBuilder.new()
	var frame := Color(0.16, 0.19, 0.24)
	var trim := Color(0.35, 0.75, 0.95)
	# frame: outer 0.66 x 0.46, built from four rails around a dark backing
	mb.add_box(Vector3(0, 0.27, -0.012), Vector3(0.66, 0.46, 0.018), Color(0.05, 0.06, 0.08))
	mb.add_box(Vector3(0, 0.485, 0.0), Vector3(0.66, 0.03, 0.026), frame)
	mb.add_box(Vector3(0, 0.055, 0.0), Vector3(0.66, 0.03, 0.026), frame)
	mb.add_box(Vector3(-0.315, 0.27, 0.0), Vector3(0.03, 0.46, 0.026), frame)
	mb.add_box(Vector3(0.315, 0.27, 0.0), Vector3(0.03, 0.46, 0.026), frame)
	mb.add_box(Vector3(0, 0.485, 0.014), Vector3(0.66, 0.006, 0.004), trim)
	# foot: a bar under the frame, kicked back so the board stands on a surface
	mb.add_box(Vector3(0, 0.012, -0.05), Vector3(0.44, 0.024, 0.22), frame)
	var mi := MeshInstance3D.new()
	mi.name = "Frame"
	mi.mesh = mb.build()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.55
	mat.roughness = 0.42
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_display = MeshInstance3D.new()
	_display.name = "Display"
	_display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_display)
	center_local = Vector3(0, 0.27, 0)
	grab_radius = 0.55
	_apply_pic()

func _apply_pic() -> void:
	if _pics.is_empty():
		return
	var tex := _pics[_pic_idx] as Texture2D
	var aspect := 1.33
	if tex and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var h := 0.40
	var w := clampf(h * aspect, 0.30, 0.58)
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	_display.mesh = q
	_display.position = Vector3(0, 0.27, 0.002)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	_display.material_override = m

func pic_index() -> int:
	return _pic_idx

func begin_grab(hand: Node3D) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_grab_ms < 400 and _pics.size() > 1:
		_pic_idx = (_pic_idx + 1) % _pics.size()
		_apply_pic()
	_last_grab_ms = now
	super(hand)
