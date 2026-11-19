extends Node3D
## The SHIELD holotable (SPEC §2 / §2.6, Stark restyle): a physical dark-titanium slab on splayed
## legs with light channels, a continuous edge light strip, and the display inset set into the top.
## Also holds the inset's life: slowly turning tick ring, rising motes, and the readouts
## (LINK on a physical bezel screen; PARTS / DIMS floating at the table edge).
## All geometry is boxes + materials; the table assembly is ~25 meshes.

const RING_DEG_PER_SEC := 6.0
const TOP_Y := 0.951       # display-inset surface height in this node's space (slab top 0.95 + 1 mm)
const SLAB_TOP := 0.95
const SLAB_T := 0.10
const SLAB_BODY_HALF_X := 1.12   # rectangular body; the ends taper out to 1.22 with wedges (2.44 m = 8 ft overall)
const SLAB_HALF_Z := 0.61   # 1.22 m = 4 ft deep
const TAPER := 0.10
const INSET := Vector2(2.2, 1.0)
const LEG := Vector3(0.10, 0.85, 0.16)
const LEG_SPLAY_DEG := Vector2(8.0, 6.0)  # feet outward along X, along Z
const READOUT_Z := 0.68    # floating readouts hover just past the player-facing edge
const READOUT_Y := 1.12

const EDGE_ENERGY := 2.0
const BEZEL_ENERGY := 1.4
const LIGHT_ENERGY := 2.6
const FILL_ENERGY := 0.7
const RIM_ENERGY := 1.2

var inset_mat: ShaderMaterial   # grid shader on the display inset (main.gd drives its fade)
var _ti_mat: StandardMaterial3D
var _apron_mat: StandardMaterial3D
var _strip_mat: StandardMaterial3D
var _bezel_mat: StandardMaterial3D
var _light: OmniLight3D
var _fill: OmniLight3D
var _rim: OmniLight3D
var _ring_pivot: Node3D
var _motes: GPUParticles3D
var _labels := {}

func _ready() -> void:
	_build_body()
	_build_inset()
	_build_light()
	_build_ring()
	_build_motes()
	_build_link_screen()
	for entry in [["parts", 0.0], ["dims", 0.4]]:
		_labels[entry[0]] = _build_label(entry[1])
	set_fade(1.0)

## Boot fade: titanium and light strips come up with the room.
func set_fade(v: float) -> void:
	_ti_mat.albedo_color = Tokens.TITANIUM * v
	_apron_mat.albedo_color = Tokens.TITANIUM_DARK * v
	var s := Tokens.HOLO_LINE * (EDGE_ENERGY * v)
	_strip_mat.albedo_color = Color(s.r, s.g, s.b)
	var b := Tokens.HOLO_PRIMARY * (BEZEL_ENERGY * v)
	_bezel_mat.albedo_color = Color(b.r, b.g, b.b)
	inset_mat.set_shader_parameter("fade", v)
	_light.light_energy = LIGHT_ENERGY * v
	_fill.light_energy = FILL_ENERGY * v
	_rim.light_energy = RIM_ENERGY * v

func _box(parent: Node, nm: String, size: Vector3, pos: Vector3, mat: Material, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	_ti_mat = Fx.titanium(Tokens.TITANIUM)
	_apron_mat = Fx.titanium(Tokens.TITANIUM_DARK)
	_strip_mat = Fx.emissive(Tokens.HOLO_LINE, EDGE_ENERGY)
	_bezel_mat = Fx.emissive(Tokens.HOLO_PRIMARY, BEZEL_ENERGY)
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var slab_y := SLAB_TOP - SLAB_T * 0.5

	# slab: rectangular body + two shallow wedges sweeping each end to a soft point (2.44 m overall)
	_box(body, "Slab", Vector3(SLAB_BODY_HALF_X * 2.0, SLAB_T, SLAB_HALF_Z * 2.0), Vector3(0, slab_y, 0), _ti_mat)
	for sx in [-1.0, 1.0]:
		var prism := PrismMesh.new()
		prism.size = Vector3(SLAB_HALF_Z * 2.0, TAPER, SLAB_T)  # triangle base along X, apex +Y, thickness Z
		var wedge := MeshInstance3D.new()
		wedge.name = "EndTaper%s" % ("R" if sx > 0 else "L")
		wedge.mesh = prism
		wedge.material_override = _ti_mat
		# map prism X -> plan Z, Y -> outward plan X, Z -> up (a proper rotation either way)
		wedge.basis = Basis(Vector3(0, 0, sx), Vector3(sx, 0, 0), Vector3(0, 1, 0))
		wedge.position = Vector3(sx * (SLAB_BODY_HALF_X + TAPER * 0.5), slab_y, 0)
		body.add_child(wedge)

	# under-slab apron: slightly inset and darker, so the slab reads as floating
	_box(body, "Apron", Vector3(1.94, 0.07, 0.92), Vector3(0, SLAB_TOP - SLAB_T - 0.035, 0), _apron_mat)

	# continuous edge light strip along both long side edges (the signature detail)
	for sz in [-1.0, 1.0]:
		_box(body, "EdgeStrip%s" % ("F" if sz > 0 else "B"), Vector3(SLAB_BODY_HALF_X * 2.0, 0.012, 0.008),
				Vector3(0, slab_y, sz * (SLAB_HALF_Z + 0.002)), _strip_mat)

	# angled, splayed legs with a light channel down each outer face
	var leg_top := SLAB_TOP - SLAB_T - 0.07
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var b := Basis.from_euler(Vector3(-sz * deg_to_rad(LEG_SPLAY_DEG.y), 0, sx * deg_to_rad(LEG_SPLAY_DEG.x)))
			var top := Vector3(sx * 0.95, leg_top, sz * 0.42)
			var leg := _box(body, "Leg%s%s" % ["R" if sx > 0 else "L", "F" if sz > 0 else "B"], LEG,
					top + b * Vector3(0, -LEG.y * 0.5, 0), _ti_mat, b)
			_box(leg, "Channel", Vector3(0.015, LEG.y * 0.92, 0.004), Vector3(0, 0, sz * (LEG.z * 0.5 + 0.001)), _strip_mat)

## Titanium needs light to catch: the display glow from just above the inset (+ a dim player-side fill).
func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "TableGlow"
	_light.light_color = Tokens.HOLO_PRIMARY
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.3, 0.3)
	add_child(_light)
	# one dim fill on the player side so the slab edge, apron and legs read against the room
	_fill = OmniLight3D.new()
	_fill.name = "PlayerFill"
	_fill.light_color = Tokens.HOLO_PRIMARY
	_fill.omni_range = 4.0
	_fill.shadow_enabled = false
	_fill.position = Vector3(0, 0.75, 1.1)
	add_child(_fill)
	# rim: high behind the far edge, so slab top edges and legs catch a highlight from the player's view
	_rim = OmniLight3D.new()
	_rim.name = "RimLight"
	_rim.light_color = Tokens.HOLO_PRIMARY
	_rim.omni_range = 6.0
	_rim.shadow_enabled = false
	_rim.position = Vector3(0, 1.9, -1.1)
	add_child(_rim)

func _build_inset() -> void:
	var plane := PlaneMesh.new()
	plane.size = INSET
	var mi := MeshInstance3D.new()
	mi.name = "DisplayInset"
	mi.mesh = plane
	inset_mat = Fx.grid_material(Tokens.TABLE_SURFACE, Tokens.GRID_MINOR_STEP, Tokens.GRID_MAJOR_STEP)
	mi.material_override = inset_mat
	mi.position.y = TOP_Y
	add_child(mi)
	# thin emissive bezel frame around the inset
	var t := 0.012
	var y := TOP_Y + 0.002
	var hx := INSET.x * 0.5
	var hz := INSET.y * 0.5
	for sz in [-1.0, 1.0]:
		_box(self, "BezelLine%s" % ("F" if sz > 0 else "B"), Vector3(INSET.x + t * 2.0, 0.004, t), Vector3(0, y, sz * (hz + t * 0.5)), _bezel_mat)
	for sx in [-1.0, 1.0]:
		_box(self, "BezelLine%s" % ("R" if sx > 0 else "L"), Vector3(t, 0.004, INSET.y), Vector3(sx * (hx + t * 0.5), y, 0), _bezel_mat)

## LINK readout: a small slanted physical screen on the player-facing bezel, text just above it.
func _build_link_screen() -> void:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(28.0))  # face tips toward the player (+Z)
	var screen := _box(self, "LinkScreen", Vector3(0.34, 0.012, 0.07), Vector3(-0.4, TOP_Y + 0.008, 0.55), _apron_mat, tilt)
	var l := _make_label()
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.rotation_degrees.x = -90.0  # lie on the screen's top face
	l.position = Vector3(0, 0.009, 0)
	screen.add_child(l)
	_labels["link"] = l

func _process(delta: float) -> void:
	_ring_pivot.rotate_y(deg_to_rad(RING_DEG_PER_SEC) * delta)

func set_link(text: String) -> void:
	_labels["link"].text = text

func set_parts(n: int) -> void:
	_labels["parts"].text = "PARTS — %d" % n

func set_dims(text: String) -> void:
	_labels["dims"].text = text

func start_motes() -> void:
	_motes.emitting = true

func set_readout_alpha(a: float) -> void:
	for l in _labels.values():
		l.modulate.a = a

func _build_ring() -> void:
	_ring_pivot = Node3D.new()
	_ring_pivot.name = "RingPivot"
	_ring_pivot.position.y = TOP_Y + 0.002
	add_child(_ring_pivot)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.9  # outer ring fits inside the 1.0 m-deep inset
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.rotation_degrees.x = -90.0
	var mat := Fx.ring_material()
	mat.set_shader_parameter("progress", 1.0)
	mat.set_shader_parameter("arc_on", 0.0)
	mi.material_override = mat
	_ring_pivot.add_child(mi)

func _build_motes() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.4
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.0
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.colors = PackedColorArray([Tokens.a(Tokens.HOLO_LINE, 0.0), Tokens.HOLO_LINE, Tokens.a(Tokens.HOLO_LINE, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	pm.color_ramp = ramp

	# soft round sprite = the fake-bloom halo
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = sg
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var mat := Fx.additive_unshaded(Color.WHITE)
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.016
	quad.material = mat

	_motes = GPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 40
	_motes.lifetime = 6.0
	_motes.preprocess = 3.0
	_motes.emitting = false
	_motes.process_material = pm
	_motes.draw_pass_1 = quad
	_motes.visibility_aabb = AABB(Vector3(-1.05, 0.0, -0.7), Vector3(2.1, 1.2, 1.4))
	_motes.position.y = TOP_Y + 0.005
	add_child(_motes)

func _make_label() -> Label3D:
	var l := Label3D.new()
	l.font = load(Tokens.FONT_BOLD)
	l.font_size = 48
	l.pixel_size = 0.0007
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.modulate = Tokens.a(Tokens.HOLO_LINE, 0.0)
	l.outline_size = 0
	return l

func _build_label(x: float) -> Label3D:
	var l := _make_label()
	l.position = Vector3(x, READOUT_Y, READOUT_Z)
	add_child(l)
	return l
