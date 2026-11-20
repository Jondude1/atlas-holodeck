class_name DataStation
extends Node3D
## R3-11: the back-wall data station — a live readout wall fed with REAL workshop data (library
## count + recent parts, what's on the table, last job), Atlas himself present as a large floating
## sphere of randomly drifting points above his emitter (Jon's direction, 2026-11-20 — no figure,
## no bust), and a pedestal disc that slowly turns the active model's own schematic. No invented
## numbers: every line on the wall arrives from the bench's actual state.

var _vp: SubViewport
var _title: Label
var _lines: Array[Label] = []
var _wall_mat: StandardMaterial3D
var _static_mat: StandardMaterial3D
var _static_base: Color
var _orb: Node3D
var _orb_points: GPUParticles3D
var _orb_mats: Array[StandardMaterial3D] = []
var _orb_base: Array[Color] = []
var _orb_systems: Array[GPUParticles3D] = []
var _ring_pivots: Array[Node3D] = []
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _celebrate_t := 0.0
var _fade := 1.0

func _ready() -> void:
	_build()

func _build() -> void:
	# --- statics (ONE titanium mesh): wall frame, emitter base, pedestal stand
	var st := MeshBuilder.new()
	var frame_c := Vector3(0, 1.95, 0)
	st.add_box(frame_c + Vector3(0, 0.63, -0.03), Vector3(2.46, 0.06, 0.06), Color.WHITE)
	st.add_box(frame_c + Vector3(0, -0.63, -0.03), Vector3(2.46, 0.06, 0.06), Color.WHITE)
	st.add_box(frame_c + Vector3(-1.23, 0, -0.03), Vector3(0.06, 1.32, 0.06), Color.WHITE)
	st.add_box(frame_c + Vector3(1.23, 0, -0.03), Vector3(0.06, 1.32, 0.06), Color.WHITE)
	st.add_cyl(Vector3(1.7, 0.03, 0.3), 0.30, 0.06, Color.WHITE, 24)          # presence emitter
	st.add_cyl(Vector3(-1.7, 0.35, 0.3), 0.16, 0.70, Color.WHITE, 16)        # pedestal column
	st.add_cyl(Vector3(-1.7, 0.72, 0.3), 0.30, 0.04, Color.WHITE, 20)        # pedestal cap
	_static_mat = Fx.titanium(Tokens.TITANIUM)
	_static_base = _static_mat.albedo_color
	var sm := MeshInstance3D.new()
	sm.name = "StationStatics"
	sm.mesh = st.build()
	sm.material_override = _static_mat
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sm)
	# --- the data wall: a SubViewport quad, refreshed only when the data changes
	_vp = SubViewport.new()
	_vp.size = Vector2i(768, 384)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.transparent_bg = false
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 28
	vb.offset_top = 20
	vb.offset_right = -28
	vb.offset_bottom = -16
	vb.add_theme_constant_override("separation", 7)
	_vp.add_child(vb)
	_title = _mk_label(vb, 34, Tokens.HOLO_CORE, true)
	var rule := ColorRect.new()
	rule.color = Tokens.HOLO_PRIMARY
	rule.custom_minimum_size = Vector2(0, 3)
	vb.add_child(rule)
	for i in 6:
		_lines.append(_mk_label(vb, 25, Tokens.HOLO_LINE, false))
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_mat.albedo_texture = _vp.get_texture()
	var wall := MeshInstance3D.new()
	wall.name = "DataWall"
	var q := QuadMesh.new()
	q.size = Vector2(2.34, 1.17)
	wall.mesh = q
	wall.material_override = _wall_mat
	wall.position = Vector3(0, 1.95, 0.01)
	add_child(wall)
	# --- the presence: Atlas as a DENSE, living sphere of points (Jon, 2026-11-20 — modelled on the
	# JARVIS/Vision projection: thousands of points in a churning core, swept by orbital rings, with a
	# bright nucleus; house colours stay cyan/electric blue, never the film's orange)
	_orb = Node3D.new()
	_orb.name = "Presence"
	_orb.position = Vector3(1.7, 1.14, 0.3)
	add_child(_orb)
	_orb_points = _make_core_points()
	_orb.add_child(_orb_points)
	# two tilted orbital rings sweeping the sphere at different radii, speeds and directions
	var ring_a := _make_ring_points(0.56, 750, 0.30, 0.017, Color(0.5, 0.88, 1.0, 0.55))
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
	# the bright nucleus at the heart of the sphere
	var nucleus := Sprite3D.new()
	nucleus.name = "OrbNucleus"
	nucleus.texture = Fx.radial_texture(128, 1.6)
	nucleus.pixel_size = 0.0028
	nucleus.modulate = Color(0.55, 0.9, 1.0, 0.5)
	nucleus.shaded = false
	nucleus.double_sided = true
	_orb.add_child(nucleus)
	# a soft glow pool on the emitter under the sphere
	var pool := MeshInstance3D.new()
	pool.name = "OrbGlowPool"
	var pq2 := PlaneMesh.new()
	pq2.size = Vector2(0.85, 0.85)
	pool.mesh = pq2
	pool.material_override = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.30), Fx.radial_texture(128, 1.7))
	pool.position = Vector3(1.7, 0.065, 0.3)
	add_child(pool)
	# --- the pedestal disc: the active model's schematic, turning slowly
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.albedo_color = Color(1, 1, 1, 0)
	_disc = MeshInstance3D.new()
	_disc.name = "SchematicDisc"
	var pq := PlaneMesh.new()
	pq.size = Vector2(0.52, 0.52)
	_disc.mesh = pq
	_disc.material_override = _disc_mat
	_disc.position = Vector3(-1.7, 0.755, 0.3)
	_disc.visible = false
	add_child(_disc)
	set_overview(["WORKSHOP OVERVIEW", "LINK — STARTING", "LIBRARY — —", "ON TABLE — THE DEMO BRACKET"])

## One point system for the presence. Points are born through the volume, drift, and orbit the
## centre at individual rates in BOTH directions — the cloud churns instead of rotating as a lump.
func _points_material(col: Color, quad_size: float) -> StandardMaterial3D:
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
	quad.material = _points_material(Color(0.45, 0.85, 1.0, 0.5), 0.02)
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
	quad.material = _points_material(col, quad_size)
	p.draw_pass_1 = quad
	_orb_systems.append(p)
	return p

func _mk_label(parent: Control, size: int, col: Color, bold: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load(Tokens.FONT_BOLD if bold else Tokens.FONT_REGULAR))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.text = ""
	parent.add_child(l)
	return l

## Real data only — the bench composes these lines from its own state.
func set_overview(lines: Array) -> void:
	if lines.is_empty():
		return
	_title.text = String(lines[0])
	for i in _lines.size():
		_lines[i].text = String(lines[i + 1]) if i + 1 < lines.size() else ""
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func set_schematic(tex: Texture2D) -> void:
	if tex == null:
		return
	_disc_mat.albedo_texture = tex
	_disc_mat.albedo_color = Color(1, 1, 1, 0.9)
	_disc.visible = true

## A job just landed on the table: the sphere swells and its points churn faster, then settle.
func celebrate() -> void:
	_celebrate_t = 1.6

func set_fade(v: float) -> void:
	_fade = v
	_static_mat.albedo_color = _static_base * v
	_wall_mat.albedo_color = Color(v, v, v, 1.0)
	for i in _orb_mats.size():
		var b := _orb_base[i]
		_orb_mats[i].albedo_color = Color(b.r * v, b.g * v, b.b * v, b.a)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_orb.position.y = 1.14 + sin(t * 0.7) * 0.02
	_orb.rotation.y += deg_to_rad(5.0) * delta
	_ring_pivots[0].rotation.y += deg_to_rad(11.0) * delta
	_ring_pivots[1].rotation.y -= deg_to_rad(8.0) * delta
	_disc.rotate_y(deg_to_rad(9.0) * delta)
	# breathing: the sphere is never quite still, even at rest
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
