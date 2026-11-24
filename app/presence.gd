class_name Presence
extends Node3D
## Round 6 — Atlas's presence, extracted from the old data station (Jon's layout: the
## sphere floats on the LEFT of the room, by the entrance end of the table). The dense
## point sphere Jon approved in Round 3, unchanged in character: ~3,870 points across a
## churning core + two counter-rotating rings, a bright nucleus, a glow pool under it.
## celebrate() is the job-landed swell. No wall, no pedestal — the room is the frame.

var _orb: Node3D
var _orb_mats: Array[StandardMaterial3D] = []
var _orb_base: Array[Color] = []
var _orb_systems: Array[GPUParticles3D] = []
var _ring_pivots: Array[Node3D] = []
var _nucleus: Sprite3D
var _pool_mat: StandardMaterial3D
var _celebrate_t := 0.0
var _fade := 1.0

func _ready() -> void:
	_orb = Node3D.new()
	_orb.name = "Presence"
	_orb.position = Vector3(0, 1.35, 0)
	add_child(_orb)
	_orb.add_child(_make_core_points())
	var ring_a := _make_ring_points(0.56, 750, 0.30, 0.016, Color(0.4, 0.8, 1.0, 0.5))
	var pivot_a := Node3D.new()
	pivot_a.rotation = Vector3(deg_to_rad(18.0), 0, deg_to_rad(6.0))
	pivot_a.add_child(ring_a)
	_orb.add_child(pivot_a)
	_ring_pivots.append(pivot_a)
	var ring_b := _make_ring_points(0.66, 520, -0.20, 0.014, Color(0.35, 0.7, 1.0, 0.45))
	var pivot_b := Node3D.new()
	pivot_b.rotation = Vector3(deg_to_rad(-11.0), 0, deg_to_rad(-24.0))
	pivot_b.add_child(ring_b)
	_orb.add_child(pivot_b)
	_ring_pivots.append(pivot_b)
	_nucleus = Sprite3D.new()
	_nucleus.name = "OrbNucleus"
	_nucleus.texture = Fx.radial_texture(128, 1.6)
	_nucleus.pixel_size = 0.0028
	_nucleus.modulate = Color(0.55, 0.9, 1.0, 0.5)
	_nucleus.shaded = false
	_nucleus.double_sided = true
	_orb.add_child(_nucleus)
	var pool := MeshInstance3D.new()
	pool.name = "OrbGlowPool"
	var pq := PlaneMesh.new()
	pq.size = Vector2(1.5, 1.5)
	pool.mesh = pq
	_pool_mat = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.30), Fx.radial_texture(128, 1.7))
	pool.material_override = _pool_mat
	pool.position = Vector3(0, 0.012, 0)
	add_child(pool)

func _points_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Fx.radial_texture(64, 1.4)
	m.albedo_color = col
	_orb_mats.append(m)
	_orb_base.append(col)
	return m

func _fade_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.2, Color(1, 1, 1, 0.95))
	grad.add_point(0.8, Color(1, 1, 1, 0.95))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	return ramp

func _make_core_points() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "OrbCore"
	p.amount = 2600
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.randomness = 0.95
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-0.8, -0.8, -0.8), Vector3(1.6, 1.6, 1.6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.38
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.008
	pm.initial_velocity_max = 0.04
	pm.orbit_velocity_min = -0.085
	pm.orbit_velocity_max = 0.085
	pm.damping_min = 0.02
	pm.damping_max = 0.15
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	quad.material = _points_material(Color(0.45, 0.85, 1.0, 0.5))
	p.draw_pass_1 = quad
	_orb_systems.append(p)
	return p

func _make_ring_points(radius: float, amount: int, orbit: float, quad_size: float, col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "OrbRing"
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.randomness = 0.9
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-0.9, -0.9, -0.9), Vector3(1.8, 1.8, 1.8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius - 0.035
	pm.emission_ring_height = 0.012
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.012
	pm.orbit_velocity_min = orbit
	pm.orbit_velocity_max = orbit + 0.05 * signf(orbit)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	quad.material = _points_material(col)
	p.draw_pass_1 = quad
	_orb_systems.append(p)
	return p

## A job just landed on the table: the sphere swells and churns faster, then settles.
func celebrate() -> void:
	_celebrate_t = 1.6

func set_fade(v: float) -> void:
	_fade = v
	for i in _orb_mats.size():
		var b := _orb_base[i]
		_orb_mats[i].albedo_color = Color(b.r * v, b.g * v, b.b * v, b.a)
	if _nucleus:
		_nucleus.modulate = Color(0.55, 0.9, 1.0, 0.5 * v)
	if _pool_mat:
		_pool_mat.albedo_color = Tokens.a(Tokens.HOLO_PRIMARY, 0.30 * v)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_orb.position.y = 1.35 + sin(t * 0.7) * 0.02
	_orb.rotation.y += deg_to_rad(5.0) * delta
	_ring_pivots[0].rotation.y += deg_to_rad(11.0) * delta
	_ring_pivots[1].rotation.y -= deg_to_rad(8.0) * delta
	var breathe := 1.0 + 0.03 * sin(t * 1.35)
	if _celebrate_t > 0.0:
		_celebrate_t = maxf(_celebrate_t - delta, 0.0)
		var k := sin((_celebrate_t / 1.6) * PI)
		_orb.scale = Vector3.ONE * breathe * (1.0 + 0.16 * k)
		for s in _orb_systems:
			s.speed_scale = 1.0 + 1.8 * k
	else:
		_orb.scale = Vector3.ONE * breathe
		for s in _orb_systems:
			if s.speed_scale != 1.0:
				s.speed_scale = 1.0
