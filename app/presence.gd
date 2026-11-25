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
var _home := Vector3.ZERO          # R7-4: the orb's post (captured on first frame)
var _home_set := false
var _visit := Vector3.ZERO         # R7-4: where it has drifted off to look at
var _visit_until := -1.0
var _fade := 1.0

func _ready() -> void:
	_orb = Node3D.new()
	_orb.name = "Presence"
	_orb.position = Vector3(0, 1.42, 0)
	add_child(_orb)
	_orb.add_child(_make_core_points())
	# R8 polish: second system becomes a crisp spherical shell (EMISSION_SHAPE_SPHERE_SURFACE)
	# so the orb reads as a dense cohesive holographic globe at distance, not a loose spray.
	var shell := _make_shell_points(0.46, 750, 0.045, 0.015, Color(0.42, 0.94, 1.0, 0.78))
	var pivot_a := Node3D.new()
	pivot_a.rotation = Vector3(deg_to_rad(14.0), 0, deg_to_rad(6.0))
	pivot_a.add_child(shell)
	_orb.add_child(pivot_a)
	_ring_pivots.append(pivot_a)
	var ring_b := _make_ring_points(0.50, 520, -0.11, 0.013, Color(0.32, 0.84, 1.0, 0.62))
	var pivot_b := Node3D.new()
	pivot_b.rotation = Vector3(deg_to_rad(-14.0), 0, deg_to_rad(-22.0))
	pivot_b.add_child(ring_b)
	_orb.add_child(pivot_b)
	_ring_pivots.append(pivot_b)
	_nucleus = Sprite3D.new()
	_nucleus.name = "OrbNucleus"
	_nucleus.texture = Fx.radial_texture(128, 2.2)
	_nucleus.pixel_size = 0.0055
	_nucleus.modulate = Color(0.14, 0.68, 0.90, 0.28)   # soft cyan core depth — never clips white against sky
	_nucleus.shaded = false
	_nucleus.double_sided = true
	_orb.add_child(_nucleus)
	var pool := MeshInstance3D.new()
	pool.name = "OrbGlowPool"
	var pq := PlaneMesh.new()
	pq.size = Vector2(1.4, 1.4)
	pool.mesh = pq
	_pool_mat = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.22), Fx.radial_texture(128, 1.9))
	pool.material_override = _pool_mat
	pool.position = Vector3(0, 0.012, 0)
	add_child(pool)

func _points_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Fx.radial_texture(64, 2.4)   # sharper pinpoint dots instead of fuzzy clouds
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
	p.visibility_aabb = AABB(Vector3(-0.7, -0.7, -0.7), Vector3(1.4, 1.4, 1.4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.43
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.001
	pm.initial_velocity_max = 0.008
	pm.orbit_velocity_min = -0.045
	pm.orbit_velocity_max = 0.045
	pm.damping_min = 0.25
	pm.damping_max = 0.45
	pm.scale_min = 0.55
	pm.scale_max = 1.15
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.015, 0.015)
	quad.material = _points_material(Color(0.28, 0.88, 1.0, 0.72))
	p.draw_pass_1 = quad
	_orb_systems.append(p)
	return p

func _make_shell_points(radius: float, amount: int, orbit: float, quad_size: float, col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "OrbShell"
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.randomness = 0.9
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-0.7, -0.7, -0.7), Vector3(1.4, 1.4, 1.4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.004
	pm.orbit_velocity_min = orbit
	pm.orbit_velocity_max = orbit + 0.02
	pm.damping_min = 0.3
	pm.damping_max = 0.5
	pm.scale_min = 0.65
	pm.scale_max = 1.25
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	quad.material = _points_material(col)
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
	p.visibility_aabb = AABB(Vector3(-0.7, -0.7, -0.7), Vector3(1.4, 1.4, 1.4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius - 0.035
	pm.emission_ring_height = 0.018
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.004
	pm.orbit_velocity_min = orbit
	pm.orbit_velocity_max = orbit + 0.03 * signf(orbit)
	pm.damping_min = 0.3
	pm.damping_max = 0.5
	pm.scale_min = 0.65
	pm.scale_max = 1.2
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
		_nucleus.modulate = Color(0.14, 0.68, 0.90, 0.28 * v)
	if _pool_mat:
		_pool_mat.albedo_color = Tokens.a(Tokens.HOLO_PRIMARY, 0.22 * v)

## R7-4: drift over to look at something (a part landing on the table), linger,
## then ease back to the post. Moss-style attention: it comes to the work.
func drift_visit(point: Vector3, hold_s: float) -> void:
	if not _home_set:
		_home = position
		_home_set = true
	_visit = point
	_visit_until = Time.get_ticks_msec() / 1000.0 + hold_s

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if not _home_set:
		_home = position
		_home_set = true
	var dest := _visit if t < _visit_until else _home
	position = position.lerp(dest, 1.0 - exp(-delta / 0.85))
	_orb.position.y = 1.42 + sin(t * 0.7) * 0.02
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
