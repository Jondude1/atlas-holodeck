class_name HoloTable
extends Node3D
## The SHIELD holotable (SPEC §2 / §2.6, Stark restyle): a physical dark-titanium slab on splayed
## legs with light channels, a continuous edge light strip, and the display inset set into the top.
## Also holds the inset's life: slowly turning tick ring, rising motes, and the readouts
## (LINK on a physical bezel screen; PARTS / DIMS floating at the table edge).
## All geometry is boxes + materials; the table assembly is ~25 meshes.

const RING_DEG_PER_SEC := 6.0
const TOP_Y := 0.951       # display-inset surface height in this node's space (slab top 0.95 + 1 mm)
const SLAB_TOP := 0.95
const SLAB_T := 0.13     # heavier machined slab (brief #12; was 0.10)
const SLAB_BODY_HALF_X := 1.12   # rectangular body; the ends taper out to 1.22 with wedges (2.44 m = 8 ft overall)
const SLAB_HALF_Z := 0.61   # 1.22 m = 4 ft deep
const TAPER := 0.10
const INSET := Vector2(2.2, 1.0)
const LEG := Vector3(0.10, 0.85, 0.16)
const LEG_SPLAY_DEG := Vector2(8.0, 6.0)  # feet outward along X, along Z
## Table-plane work mode (R1-1/2): models slide inside PLANE_HALF (table space, metres) at TOP_Y; the slab's top is the
## region where a released model settles back down onto the surface.
const PLANE_HALF := Vector2(1.05, 0.45)
const SETTLE_HALF := Vector2(1.12, 0.61)
const READOUT_Z := 0.68    # floating readouts hover just past the player-facing edge
const READOUT_Y := 1.12

const EDGE_ENERGY := 2.1
const CHANNEL_ENERGY := 4.0
const BEVEL_ENERGY := 0.75
const ETCH_ALPHA := 0.5     # end-zone etchings brighter (brief #12; was 0.26)
const BEZEL_ENERGY := 1.4
const LIGHT_ENERGY := 2.6
const FILL_ENERGY := 0.7
const RIM_ENERGY := 1.2

var inset_mat: ShaderMaterial   # grid shader on the display inset (main.gd drives its fade)
var _ti_mat: StandardMaterial3D
var _apron_mat: StandardMaterial3D
var _strip_mat: ShaderMaterial
var _trim_mat: StandardMaterial3D
var _bezel_mat: StandardMaterial3D
var _channel_mat: ShaderMaterial
var _bevel_mat: StandardMaterial3D
var _etch_mat: StandardMaterial3D
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
	_build_model_glow()
	_build_link_screen()
	for entry in [["parts", 0.0], ["dims", 0.4]]:
		_labels[entry[0]] = _build_label(entry[1])
	set_fade(1.0)

## Boot fade: titanium and light strips come up with the room.
func set_fade(v: float) -> void:
	_ti_mat.albedo_color = Tokens.TITANIUM * v
	_apron_mat.albedo_color = Tokens.TITANIUM_DARK * v
	_trim_mat.albedo_color = Tokens.TITANIUM * v
	_strip_mat.set_shader_parameter("fade", v)
	_channel_mat.set_shader_parameter("fade", v)
	var bv := Tokens.TITANIUM.lerp(Tokens.HOLO_LINE, 0.55) * (BEVEL_ENERGY * v)
	_bevel_mat.albedo_color = Color(bv.r, bv.g, bv.b)
	_etch_mat.albedo_color = Tokens.a(Tokens.HOLO_LINE, ETCH_ALPHA * v)
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

## One merged mesh from a builder (every piece in it shares `mat`): a single draw call instead of one per box.
func _merged(parent: Node, nm: String, mb: MeshBuilder, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mb.build()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	_ti_mat = Fx.titanium(Tokens.TITANIUM)
	_apron_mat = Fx.titanium(Tokens.TITANIUM_DARK)
	_strip_mat = Fx.pulse_material(Tokens.HOLO_LINE, EDGE_ENERGY, Vector3.RIGHT, SLAB_BODY_HALF_X * 2.0)   # pulse travels the edge
	_trim_mat = Fx.titanium(Tokens.TITANIUM)
	_trim_mat.vertex_color_use_as_albedo = true
	_bezel_mat = Fx.emissive(Tokens.HOLO_PRIMARY, BEZEL_ENERGY)
	_channel_mat = Fx.pulse_material(Tokens.HOLO_LINE, CHANNEL_ENERGY, Vector3.UP, LEG.y * 0.92, 0.0)   # and runs up each leg (meshes are baked in table space)
	_bevel_mat = Fx.emissive(Tokens.TITANIUM, BEVEL_ENERGY)
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

	# heavier machined edge (brief #12): a protruding top lip and bottom skirt of brushed titanium frame a RECESSED
	# continuous light channel (the signature detail) with a pulse running along it; an under-slab glow strip washes
	# the floor. Lips + skirts are one merged mesh, the strips + under-glow another.
	var trim := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var hx := SLAB_BODY_HALF_X
	var lip_h := 0.034
	var skirt_h := 0.03
	for sz in [-1.0, 1.0]:
		trim.add_box(Vector3(0, SLAB_TOP - lip_h * 0.5, sz * SLAB_HALF_Z), Vector3(hx * 2.0 + 0.02, lip_h, 0.04), Color.WHITE)
		trim.add_box(Vector3(0, SLAB_TOP - SLAB_T + skirt_h * 0.5, sz * SLAB_HALF_Z), Vector3(hx * 2.0 + 0.02, skirt_h, 0.04), Tokens.TITANIUM_DARK.lerp(Color.WHITE, 0.45))
		glow.add_box(Vector3(0, slab_y + 0.002, sz * (SLAB_HALF_Z + 0.004)), Vector3(hx * 2.0, 0.03, 0.014), Color.WHITE)
		glow.add_box(Vector3(0, SLAB_TOP - SLAB_T - 0.004, sz * 0.47), Vector3(1.9, 0.008, 0.012), Color.WHITE)          # under-slab glow
	for sx in [-1.0, 1.0]:                                                                                            # end caps
		trim.add_box(Vector3(sx * (hx + TAPER * 0.5), slab_y, 0.0), Vector3(TAPER + 0.02, SLAB_T - 0.01, 0.03), Tokens.TITANIUM_DARK.lerp(Color.WHITE, 0.6))
	for pair in [["TitaniumTrim", trim, _trim_mat], ["EdgeGlow", glow, _strip_mat]]:
		var mi := MeshInstance3D.new()
		mi.name = pair[0]
		mi.mesh = pair[1].build()
		mi.material_override = pair[2]
		body.add_child(mi)

	# machined bevel: a thin pale-metal highlight along the slab's top edge, front and back (merged: one draw)
	var bevel := MeshBuilder.new()
	for sz in [-1.0, 1.0]:
		bevel.add_box(Vector3(0, SLAB_TOP + 0.0005, sz * (SLAB_HALF_Z - 0.006)), Vector3(SLAB_BODY_HALF_X * 2.0, 0.005, 0.012), Color.WHITE)
	_merged(body, "Bevels", bevel, _bevel_mat)

	# angled, splayed legs with a light channel down each outer face (legs one mesh, channels one mesh)
	var legs := MeshBuilder.new()
	var channels := MeshBuilder.new()
	var leg_top := SLAB_TOP - SLAB_T - 0.07
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var b := Basis.from_euler(Vector3(-sz * deg_to_rad(LEG_SPLAY_DEG.y), 0, sx * deg_to_rad(LEG_SPLAY_DEG.x)))
			var top := Vector3(sx * 0.95, leg_top, sz * 0.42)
			var centre := top + b * Vector3(0, -LEG.y * 0.5, 0)
			legs.add_box(centre, LEG, Color.WHITE, b)
			channels.add_box(centre + b * Vector3(0, 0, sz * (LEG.z * 0.5 + 0.001)), Vector3(0.024, LEG.y * 0.92, 0.006), Color.WHITE, b)
	_merged(body, "Legs", legs, _ti_mat)
	_merged(body, "LegChannels", channels, _channel_mat)

## Titanium needs light to catch: the display glow from just above the inset (+ a dim player-side fill).
func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "TableGlow"
	_light.light_color = Tokens.HOLO_PRIMARY.lerp(Color(1, 1, 1), 0.62)   # v2 look pass: ice-white rig light, not cyan wash
	_light.omni_range = 5.0
	_light.position = Vector3(0, 1.3, 0.3)
	add_child(_light)
	# one dim fill on the player side so the slab edge, apron and legs read against the room
	_fill = OmniLight3D.new()
	_fill.name = "PlayerFill"
	_fill.light_color = Tokens.HOLO_PRIMARY.lerp(Color(1, 1, 1), 0.62)
	_fill.omni_range = 4.0
	_fill.shadow_enabled = false
	_fill.position = Vector3(0, 0.75, 1.1)
	add_child(_fill)
	# rim: high behind the far edge, so slab top edges and legs catch a highlight from the player's view
	_rim = OmniLight3D.new()
	_rim.name = "RimLight"
	_rim.light_color = Tokens.HOLO_PRIMARY.lerp(Color(1, 1, 1), 0.62)
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
	inset_mat.set_shader_parameter("hot_center", 0.25)  # v2 look pass: a gentle pool, not a floodlight (was 0.6)
	inset_mat.set_shader_parameter("hot_radius", 0.85)
	mi.material_override = inset_mat
	mi.position.y = TOP_Y
	add_child(mi)
	# faint etched schematics away from centre: one low-alpha overlay quad, 1 mm above the grid
	var etch := MeshInstance3D.new()
	etch.name = "SurfaceEtch"
	var eq := PlaneMesh.new()
	eq.size = INSET
	etch.mesh = eq
	_etch_mat = StandardMaterial3D.new()
	_etch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_etch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_etch_mat.albedo_texture = Blueprint.surface_etch(INSET)
	_etch_mat.render_priority = 1
	etch.material_override = _etch_mat
	etch.position.y = TOP_Y + 0.001
	add_child(etch)
	# thin emissive bezel frame around the inset
	var t := 0.012
	var y := TOP_Y + 0.002
	var hx := INSET.x * 0.5
	var hz := INSET.y * 0.5
	var bezel := MeshBuilder.new()
	for sz in [-1.0, 1.0]:
		bezel.add_box(Vector3(0, y, sz * (hz + t * 0.5)), Vector3(INSET.x + t * 2.0, 0.004, t), Color.WHITE)
	for sx in [-1.0, 1.0]:
		bezel.add_box(Vector3(sx * (hx + t * 0.5), y, 0), Vector3(t, 0.004, INSET.y), Color.WHITE)
	_merged(self, "BezelLines", bezel, _bezel_mat)

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

# --- R3-1/R3-3: emitter glow that follows the ACTIVE model — a light pool on the display, a soft
# --- column rising off it, and motes drifting up through the beam. Three draws, no lights.
var _glow_group: Node3D
var _pool_mat: StandardMaterial3D
var _col_mat: ShaderMaterial
var _glow_motes: GPUParticles3D
var _glow_follow: Node3D
var _glow_alpha := 0.0

func _build_model_glow() -> void:
	_glow_group = Node3D.new()
	_glow_group.name = "ModelGlow"
	_glow_group.position.y = TOP_Y
	add_child(_glow_group)
	_pool_mat = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.0), Fx.radial_texture(128, 1.7))
	_pool_mat.render_priority = 2
	var pool := MeshInstance3D.new()
	pool.name = "GlowPool"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	pool.mesh = pm
	pool.material_override = _pool_mat
	pool.position.y = 0.003
	_glow_group.add_child(pool)
	_col_mat = ShaderMaterial.new()
	_col_mat.shader = load("res://column.gdshader")
	_col_mat.set_shader_parameter("tint", Tokens.HOLO_PRIMARY)
	_col_mat.set_shader_parameter("fade", 0.0)
	var mb := MeshBuilder.new()
	for rot in [0.0, 90.0]:
		mb.add_quad(Vector3(0, 0.28, 0), Vector2(1.0, 0.56), Basis(Vector3.UP, deg_to_rad(rot)), Color.WHITE)
	var col := MeshInstance3D.new()
	col.name = "GlowColumn"
	col.mesh = mb.build()
	col.material_override = _col_mat
	_glow_group.add_child(col)
	_glow_motes = GPUParticles3D.new()
	_glow_motes.name = "GlowMotes"
	_glow_motes.amount = 36
	_glow_motes.lifetime = 2.6
	_glow_motes.emitting = false
	var pm2 := ParticleProcessMaterial.new()
	pm2.direction = Vector3(0, 1, 0)
	pm2.spread = 6.0
	pm2.initial_velocity_min = 0.05
	pm2.initial_velocity_max = 0.11
	pm2.gravity = Vector3.ZERO
	pm2.scale_min = 0.004
	pm2.scale_max = 0.009
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm2.emission_ring_axis = Vector3(0, 1, 0)
	pm2.emission_ring_radius = 0.35
	pm2.emission_ring_inner_radius = 0.05
	pm2.emission_ring_height = 0.02
	pm2.color = Tokens.a(Tokens.HOLO_LINE, 0.55)
	_glow_motes.process_material = pm2
	var pq := QuadMesh.new()
	pq.size = Vector2(0.008, 0.008)
	pq.material = Fx.additive_unshaded(Tokens.a(Tokens.HOLO_LINE, 0.55))
	_glow_motes.draw_pass_1 = pq
	_glow_motes.position.y = 0.02
	_glow_group.add_child(_glow_motes)
	_glow_group.visible = false

## Bench hook: the glow tracks this model (null = fade out).
func follow_model(m: Node3D) -> void:
	_glow_follow = m

func _update_glow(delta: float) -> void:
	var target := 1.0 if _glow_follow and is_instance_valid(_glow_follow) else 0.0
	_glow_alpha = move_toward(_glow_alpha, target, delta * 1.6)
	_glow_group.visible = _glow_alpha > 0.01
	if not _glow_group.visible:
		_glow_motes.emitting = false
		return
	if target > 0.0:
		var lp := to_local(_glow_follow.global_position)
		_glow_group.position.x = lp.x
		_glow_group.position.z = lp.z
		var b: AABB = _glow_follow.get("_bounds")
		var sc: float = _glow_follow.global_transform.basis.get_scale().x
		var r := maxf(maxf(b.size.x, b.size.z) * 0.5 * sc, 0.09) + 0.05
		_glow_group.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	_pool_mat.albedo_color = Tokens.a(Tokens.HOLO_PRIMARY, 0.34 * _glow_alpha)
	_col_mat.set_shader_parameter("fade", _glow_alpha)
	_glow_motes.emitting = _glow_alpha > 0.4

func _process(delta: float) -> void:
	_ring_pivot.rotate_y(deg_to_rad(RING_DEG_PER_SEC) * delta)
	_update_glow(delta)

## The 3-light rig, for the vista system's per-vista mood tints (Round 5).
func mood_lights() -> Array:
	return [_light, _fill, _rim]

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
	_motes.amount = 90
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
