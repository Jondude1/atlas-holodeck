class_name Lab
extends Node3D
## Stark-lab set dressing (brief #12). Everything is procedural (no external assets) and merged by material, so the
## whole lab is FIVE draw calls: one lit mesh (workbenches, shelving + equipment, wall greebles, ceiling rig, cables,
## the room's beams), one emissive mesh (cyan trim, LEDs, the ring light, the room's accent strips and cove), one
## additive light-FX mesh (rig shafts, glow halos, floor gloss streaks), one additive screens mesh (seven animated
## wall displays) and the rotating holographic ring over the table. Colours come from Tokens only; the dressing is
## dark titanium / deep blue with cyan rim accents, never orange.
## Room owns the instance: it adds its own beams / strips / cove to `lit` / `emi` before `build()` seals the meshes.

const E_BASE := 2.0                 # emissive material multiplier; vertex colours carry intensity (0..1) of this
const HEIGHT := 3.4

var lit := MeshBuilder.new()
var emi := MeshBuilder.new()
var fx := MeshBuilder.new()
var screens := MeshBuilder.new()

var _lit_mat: StandardMaterial3D
var _emi_mat: StandardMaterial3D
var _fx_mat: ShaderMaterial
var _screen_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _ring: MeshInstance3D
var _fade := 1.0
var _rng := RandomNumberGenerator.new()
var _table_xz := Vector2.ZERO
var _arm: RobotArm
var _station: DataStation

func station() -> DataStation:
	return _station

# ---------------------------------------------------------------- colour helpers (Tokens only)

func _ti(t := 0.0) -> Color:
	return Tokens.TITANIUM_DARK.lerp(Tokens.TITANIUM, t)

func _deep(t := 0.0) -> Color:
	return Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, t)

func _cyan(k: float) -> Color:
	return Tokens.HOLO_LINE * k

func _glow(k: float) -> Color:
	return Color(k, k, k)

## Emissive piece: intensity k (0..1 of E_BASE) of the cyan token.
func _e_box(c: Vector3, size: Vector3, k := 0.6, basis := Basis.IDENTITY) -> void:
	emi.add_box(c, size, Color(Tokens.HOLO_LINE.r * k, Tokens.HOLO_LINE.g * k, Tokens.HOLO_LINE.b * k), basis)

# ---------------------------------------------------------------- build

func build(table_xz: Vector2) -> void:
	_table_xz = table_xz
	_rng.seed = 1621
	_workbench(1.0)          # Round 5: the left bench run is gone — the open wall lives there
	_suit_platforms()
	for side in [-1.0, 1.0]:
		_shelf_unit(Vector3(side * 3.35, 0.0, -4.78), 0.0)
	_greebles()
	_rig(table_xz)
	_floor_trim(table_xz)
	_cables(table_xz)
	_screen_bank()
	_light_fx(table_xz)
	_seal()
	# R3-11 living lab: the workshop arm on the right bench + the data station on the back wall
	_arm = RobotArm.new()
	_arm.name = "RobotArm"
	_arm.position = Vector3(3.42, 0.9475, -1.05)
	add_child(_arm)
	_station = DataStation.new()
	_station.name = "DataStation"
	_station.position = Vector3(0, 0, -4.55)
	add_child(_station)
	# R3-9: the table's edge light spills onto the floor as a soft gloss strip (fake reflection)
	var gloss := MeshInstance3D.new()
	gloss.name = "FloorGloss"
	var gp := PlaneMesh.new()
	gp.size = Vector2(3.1, 1.35)
	gloss.mesh = gp
	gloss.material_override = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.15), Fx.radial_texture(128, 1.9))
	gloss.position = Vector3(table_xz.x, 0.006, table_xz.y + 1.05)
	add_child(gloss)

## Round 5: two ring-lit display platforms flanking the open wall — the suit bay.
## (The suits themselves arrive via the image-to-3D pipeline; the pads are architecture.)
func _suit_platforms() -> void:
	for z in [-3.35, 0.85]:
		lit.add_cyl(Vector3(-3.15, 0.035, z), 0.58, 0.07, _ti(0.5), 28)
		lit.add_cyl(Vector3(-3.15, 0.075, z), 0.5, 0.012, _deep(0.3), 28)
		var ring := Color(Tokens.HOLO_LINE.r * 0.55, Tokens.HOLO_LINE.g * 0.55, Tokens.HOLO_LINE.b * 0.55)
		emi.add_torus(Vector3(-3.15, 0.078, z), 0.53, 0.012, ring, 48, 6)
		emi.add_cyl(Vector3(-3.15, 0.004, z), 0.64, 0.008, ring * 0.22, 28)

func _seal() -> void:
	_lit_mat = StandardMaterial3D.new()
	_lit_mat.vertex_color_use_as_albedo = true
	_lit_mat.vertex_color_is_srgb = true
	_lit_mat.metallic = 0.55
	_lit_mat.roughness = 0.42
	_add_mesh("LabSet", lit.build(), _lit_mat)

	_emi_mat = StandardMaterial3D.new()
	_emi_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_emi_mat.vertex_color_use_as_albedo = true
	_emi_mat.vertex_color_is_srgb = true
	_emi_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh("LabEmissive", emi.build(), _emi_mat)

	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://lightfx.gdshader")
	_fx_mat.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	_add_mesh("LabLightFx", fx.build(), _fx_mat)

	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = load("res://screens.gdshader")
	_screen_mat.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	_screen_mat.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	_screen_mat.set_shader_parameter("deep_color", Tokens.HOLO_DEEP)
	_add_mesh("LabScreens", screens.build(), _screen_mat)

	# the slow-turning holographic ring above the table (the ring HUD shader, laid flat and tilted)
	_ring_mat = Fx.ring_material()
	_ring_mat.set_shader_parameter("progress", 1.0)
	_ring_mat.set_shader_parameter("arc_on", 0.0)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.5
	_ring = MeshInstance3D.new()
	_ring.name = "HoloRing"
	_ring.mesh = q
	_ring.material_override = _ring_mat
	_ring.position = Vector3(_table_xz.x, 2.18, _table_xz.y)
	add_child(_ring)
	set_fade(_fade)

func _add_mesh(nm: String, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func set_fade(v: float) -> void:
	_fade = v
	if _lit_mat == null:
		return
	_lit_mat.albedo_color = Color(v, v, v)
	_emi_mat.albedo_color = Color(E_BASE * v, E_BASE * v, E_BASE * v)
	_fx_mat.set_shader_parameter("fade", v)
	_screen_mat.set_shader_parameter("fade", v)
	_ring_mat.set_shader_parameter("fade", v * 0.8)
	if _station:
		_station.set_fade(v)

func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_y(deg_to_rad(7.0) * delta)
		_ring.rotation.x = deg_to_rad(90.0) + deg_to_rad(5.0) * sin(Time.get_ticks_msec() / 1000.0 * 0.35)

# ---------------------------------------------------------------- workbenches

## A long bench against a side wall: cabinets with seams and cyan handles, a work top with a lit edge, and equipment.
func _workbench(side: float) -> void:
	var x := side * 3.42
	var z0 := -4.5
	var z1 := -0.7
	var face_x := x - side * 0.38                         # the cabinet face looking into the room
	var top_y := 0.92
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	lit.add_box(Vector3(x, top_y, zc), Vector3(0.84, 0.055, length + 0.06), _ti(0.55))              # work top
	lit.add_box(Vector3(x, 0.07, zc), Vector3(0.78, 0.14, length), _ti(0.0))                         # plinth
	var n := 4
	for k in n:
		var zk := z0 + (float(k) + 0.5) * length / n
		var w := length / n - 0.03
		lit.add_box(Vector3(x, 0.52, zk), Vector3(0.76, 0.74, w), _deep(0.25).lerp(_ti(0.3), 0.5))   # cabinet body
		lit.add_box(Vector3(face_x - side * 0.01, 0.52, zk), Vector3(0.025, 0.68, w - 0.05), _ti(0.18))   # door
		_e_box(Vector3(face_x - side * 0.03, 0.66, zk + w * 0.34), Vector3(0.018, 0.16, 0.012), 0.5)      # handle
	_e_box(Vector3(face_x - side * 0.01, top_y - 0.04, zc), Vector3(0.012, 0.012, length), 0.55)         # lit worktop edge
	_e_box(Vector3(face_x - side * 0.01, 0.145, zc), Vector3(0.01, 0.01, length), 0.35)                  # toe-kick glow
	# equipment on the top
	var z := z0 + 0.25
	var item := 0
	while z < z1 - 0.25:
		var kind := (item + (0 if side < 0 else 2)) % 7
		z += _bench_item(kind, Vector3(x, top_y + 0.0275, z), side)
		item += 1

## Returns the z advance used.
func _bench_item(kind: int, at: Vector3, side: float) -> float:
	var inward := -side           # towards the room
	match kind:
		0:  # monitor on an arm
			lit.add_box(at + Vector3(side * 0.2, 0.03, 0), Vector3(0.22, 0.02, 0.24), _ti(0.2))
			lit.add_rod(at + Vector3(side * 0.2, 0.03, 0), at + Vector3(side * 0.2, 0.34, 0), 0.015, _ti(0.4))
			lit.add_box(at + Vector3(side * 0.16, 0.5, 0), Vector3(0.035, 0.34, 0.56), _ti(0.1))
			var scr := at + Vector3(side * 0.16 + inward * 0.02, 0.5, 0)
			screens.add_quad(scr, Vector2(0.52, 0.3), Basis(Vector3.UP, deg_to_rad(90.0 * inward)), Color(_rng.randf(), 0.125 * _rng.randi_range(0, 3), 0.217, 1.0))
			return 0.8
		1:  # parts bins
			for r in 2:
				for c in 2:
					lit.add_box(at + Vector3(0, 0.07 + r * 0.14, -0.14 + c * 0.28), Vector3(0.4, 0.12, 0.25), _deep(0.4 + 0.2 * _rng.randf()))
					_e_box(at + Vector3(inward * 0.201, 0.1 + r * 0.14, -0.14 + c * 0.28), Vector3(0.006, 0.014, 0.1), 0.45)
			return 0.75
		2:  # canisters
			for k in 3:
				var rr := 0.07 + 0.03 * _rng.randf()
				var hh := 0.22 + 0.2 * _rng.randf()
				lit.add_cyl(at + Vector3(side * 0.05 * k, hh * 0.5, -0.12 + 0.12 * k), rr, hh, _ti(0.15 + 0.3 * _rng.randf()), 10)
				_e_box(at + Vector3(side * 0.05 * k, hh * 0.7, -0.12 + 0.12 * k) + Vector3(inward * rr, 0, 0), Vector3(0.006, 0.05, 0.018), 0.6)
			return 0.6
		3:  # printer frame
			lit.add_box(at + Vector3(0, 0.19, 0), Vector3(0.46, 0.38, 0.46), _deep(0.35))
			lit.add_box(at + Vector3(inward * 0.2, 0.19, 0), Vector3(0.04, 0.3, 0.4), _deep(0.15))
			_e_box(at + Vector3(inward * 0.224, 0.36, 0), Vector3(0.008, 0.012, 0.36), 0.7)
			_e_box(at + Vector3(inward * 0.224, 0.05, 0), Vector3(0.008, 0.01, 0.36), 0.35)
			lit.add_rod(at + Vector3(0, 0.38, -0.2), at + Vector3(0, 0.38, 0.2), 0.012, _ti(0.5))
			return 0.75
		4:  # tool chest, stacked
			lit.add_box(at + Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.42), _ti(0.12))
			lit.add_box(at + Vector3(0, 0.3, 0.02), Vector3(0.42, 0.12, 0.34), _ti(0.25))
			for r in 3:
				_e_box(at + Vector3(inward * 0.251, 0.05 + r * 0.07, 0), Vector3(0.006, 0.01, 0.2), 0.4)
			return 0.65
		5:  # lamp arm + cable reel
			lit.add_cyl(at + Vector3(0, 0.015, 0), 0.07, 0.03, _ti(0.3), 12)
			lit.add_rod(at + Vector3(0, 0.03, 0), at + Vector3(inward * 0.1, 0.42, 0.04), 0.01, _ti(0.5))
			lit.add_rod(at + Vector3(inward * 0.1, 0.42, 0.04), at + Vector3(inward * 0.3, 0.38, 0.1), 0.01, _ti(0.5))
			_e_box(at + Vector3(inward * 0.31, 0.37, 0.1), Vector3(0.05, 0.012, 0.05), 0.9)
			lit.add_torus(at + Vector3(side * 0.06, 0.08, -0.32), 0.1, 0.035, _deep(0.5), 18, 6, Basis(Vector3.RIGHT, 0.2))
			return 0.7
		_:  # crates
			lit.add_box(at + Vector3(0, 0.1, 0), Vector3(0.4, 0.2, 0.34), _deep(0.3 + 0.2 * _rng.randf()))
			lit.add_box(at + Vector3(0.02, 0.28, 0.02), Vector3(0.3, 0.16, 0.26), _deep(0.25 + 0.2 * _rng.randf()))
			_e_box(at + Vector3(inward * 0.201, 0.1, 0), Vector3(0.006, 0.02, 0.14), 0.4)
			return 0.55

# ---------------------------------------------------------------- shelving

## A shelving unit against the back wall (origin = floor point at the unit's centre): four uprights, boards with lit edges,
## crates, drums and tool silhouettes on every level.
func _shelf_unit(o: Vector3, _yaw: float) -> void:
	var w := 1.1
	var d := 0.42
	var h := 2.35
	for ux in [-w * 0.5, w * 0.5]:
		for uz in [-(d * 0.5 - 0.04), d * 0.5 - 0.04]:
			lit.add_box(o + Vector3(ux, h * 0.5, uz), Vector3(0.045, h, 0.045), _ti(0.3))
	var levels := [0.18, 0.78, 1.38, 1.98]
	for ly in levels:
		lit.add_box(o + Vector3(0, ly, 0), Vector3(w, 0.035, d), _ti(0.4))
		_e_box(o + Vector3(0, ly + 0.002, d * 0.5 + 0.003), Vector3(w - 0.04, 0.008, 0.008), 0.5)        # lit front edge
		var x := -w * 0.5 + 0.1
		while x < w * 0.5 - 0.12:
			var kind := _rng.randi() % 5
			var iw := 0.1 + 0.16 * _rng.randf()
			var ih := 0.12 + 0.34 * _rng.randf()
			var base := o + Vector3(x + iw * 0.5, ly + 0.0175, 0.0)
			if kind == 0:     # drum
				lit.add_cyl(base + Vector3(0, ih * 0.5, 0), iw * 0.5, ih, _ti(0.1 + 0.3 * _rng.randf()), 10)
				_e_box(base + Vector3(0, ih * 0.75, d * 0.0) + Vector3(0, 0, iw * 0.5), Vector3(iw * 0.4, 0.008, 0.006), 0.55)
			elif kind == 1:   # tool: handle + head
				lit.add_rod(base + Vector3(0, 0, 0), base + Vector3(0, ih + 0.1, 0), 0.012, _ti(0.5), 6)
				lit.add_box(base + Vector3(0, ih + 0.1, 0), Vector3(iw * 0.9, 0.04, 0.05), _ti(0.35))
			else:             # crate
				lit.add_box(base + Vector3(0, ih * 0.5, 0), Vector3(iw, ih, d * 0.7), _deep(0.25 + 0.4 * _rng.randf()))
				_e_box(base + Vector3(0, ih * 0.7, d * 0.35 + 0.003), Vector3(iw * 0.5, 0.008, 0.006), 0.5)
				if _rng.randf() < 0.4:
					_e_box(base + Vector3(iw * 0.3, ih * 0.35, d * 0.35 + 0.003), Vector3(0.012, 0.012, 0.006), 1.0)   # status LED
			x += iw + 0.03 + 0.08 * _rng.randf()
	for ux in [-w * 0.5, w * 0.5]:                                                                         # lit uprights
		_e_box(o + Vector3(ux, h * 0.5, d * 0.5 + 0.026), Vector3(0.008, h - 0.1, 0.006), 0.4)

# ---------------------------------------------------------------- walls

## Panel pilasters, pipe runs on brackets, vents, junction boxes with LEDs - along each wall so the planes read as
## built, not painted. (a = wall start, dir = along the wall, n = inward normal)
func _greebles() -> void:
	_wall_run(Vector3(-4.0, 0, -5.0), Vector3(1, 0, 0), Vector3(0, 0, 1), 8.0, false)  # back wall (the ticker screen owns the high band)
	_wall_run(Vector3(-4.0, 0, 3.0), Vector3(0, 0, -1), Vector3(1, 0, 0), 8.0)       # left wall
	_wall_run(Vector3(4.0, 0, -5.0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 8.0)       # right wall
	_wall_run(Vector3(4.0, 0, 3.0), Vector3(-1, 0, 0), Vector3(0, 0, -1), 8.0)       # front wall (behind the player)

func _wall_run(a: Vector3, dir: Vector3, n: Vector3, length: float, vents := true) -> void:
	var basis := Basis(dir, Vector3.UP, n)                         # local X along the wall, Z = inward normal
	var step_m := 2.0
	var count := int(length / step_m)
	for k in count + 1:
		var p := a + dir * (float(k) * step_m)
		lit.add_box(p + n * 0.06 + Vector3(0, HEIGHT * 0.5, 0), Vector3(0.12, HEIGHT, 0.1), _ti(0.05), basis)   # pilaster
		_e_box(p + n * 0.115 + Vector3(0, 0.95, 0), Vector3(0.008, 0.5, 0.004), 0.45, basis)                    # lit pilaster slit
	for ry in [2.5, 0.34]:                                                                                        # pipe runs
		lit.add_rod(a + n * 0.12 + Vector3(0, ry, 0), a + dir * length + n * 0.12 + Vector3(0, ry, 0), 0.045, _ti(0.2), 8)
		if ry < 1.0:
			lit.add_rod(a + n * 0.12 + Vector3(0, ry + 0.12, 0), a + dir * length + n * 0.12 + Vector3(0, ry + 0.12, 0), 0.022, _deep(0.6), 6)
		for k in int(length / 0.9):
			var p2 := a + dir * (0.45 + k * 0.9) + n * 0.09 + Vector3(0, ry, 0)
			lit.add_box(p2, Vector3(0.05, 0.12, 0.05), _ti(0.4), basis)                                           # clamp
	for k in count:
		var p3 := a + dir * (k * step_m + 1.0)
		if k % 2 == 0 and not vents:
			continue
		if k % 2 == 0:       # vent grille: frame + slats
			lit.add_box(p3 + n * 0.05 + Vector3(0, 2.95, 0), Vector3(0.8, 0.3, 0.06), _ti(0.1), basis)
			for s in 5:
				_e_box(p3 + n * 0.085 + Vector3(0, 2.84 + s * 0.05, 0), Vector3(0.7, 0.008, 0.004), 0.22, basis)
		else:                # junction box with LEDs
			lit.add_box(p3 + n * 0.08 + Vector3(0, 1.1, 0), Vector3(0.36, 0.5, 0.12), _ti(0.18), basis)
			for s in 3:
				_e_box(p3 + n * 0.145 + dir * (-0.1 + s * 0.1) + Vector3(0, 1.28, 0), Vector3(0.025, 0.025, 0.006), 0.9 if s == _rng.randi() % 3 else 0.35, basis)

# ---------------------------------------------------------------- ceiling rig

func _rig(t: Vector2) -> void:
	var y := 3.02
	var hx := 1.55
	var hz := 1.15
	for sx in [-1.0, 1.0]:
		lit.add_box(Vector3(t.x + sx * hx, y, t.y), Vector3(0.09, 0.11, hz * 2.0), _ti(0.25))               # long rails
		for sz in [-1.0, 1.0]:
			lit.add_rod(Vector3(t.x + sx * hx, y + 0.05, t.y + sz * hz * 0.85), Vector3(t.x + sx * hx, HEIGHT - 0.2, t.y + sz * hz * 0.85), 0.012, _ti(0.5), 6)   # hangers
	for sz in [-1.0, 1.0]:
		lit.add_box(Vector3(t.x, y, t.y + sz * hz), Vector3(hx * 2.0, 0.11, 0.09), _ti(0.25))               # cross rails
	# ring light: a lit torus slung under the rig on four spokes
	var ring_y := 2.92
	emi.add_torus(Vector3(t.x, ring_y, t.y), 1.02, 0.028, Color(Tokens.HOLO_LINE.r * 0.95, Tokens.HOLO_LINE.g * 0.95, Tokens.HOLO_LINE.b * 0.95), 64, 8)
	lit.add_torus(Vector3(t.x, ring_y + 0.04, t.y), 1.02, 0.034, _ti(0.3), 64, 8)
	for a in 4:
		var dir := Vector3(cos(a * PI * 0.5 + PI * 0.25), 0, sin(a * PI * 0.5 + PI * 0.25))
		lit.add_rod(Vector3(t.x, y, t.y) + dir * 0.1, Vector3(t.x, ring_y + 0.04, t.y) + dir * 1.02, 0.012, _ti(0.4), 6)
	# four spot housings on the rails, lens glowing down
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(t.x + sx * hx * 0.56, y - 0.08, t.y + sz * hz * 0.45)
			lit.add_cyl(p + Vector3(0, -0.05, 0), 0.085, 0.16, _ti(0.15), 12)
			lit.add_rod(p + Vector3(0, 0.0, 0), Vector3(p.x + sx * hx * 0.44, y, p.z), 0.008, _ti(0.5), 5)
			emi.add_cyl(p + Vector3(0, -0.135, 0), 0.07, 0.012, Tokens.HOLO_CORE * 0.85, 12)

# ---------------------------------------------------------------- floor

func _floor_trim(t: Vector2) -> void:
	var y := 0.006
	var hx := 1.62
	var hz := 0.98
	for sx in [-1.0, 1.0]:
		_e_box(Vector3(t.x + sx * hx, y, t.y), Vector3(0.022, 0.006, hz * 2.0), 0.55)
	for sz in [-1.0, 1.0]:
		_e_box(Vector3(t.x, y, t.y + sz * hz), Vector3(hx * 2.0, 0.006, 0.022), 0.55)
	# dashed lead-ins running out to the side benches, and toward the player
	for sx in [-1.0, 1.0]:
		var x := hx + 0.3
		while x < 2.75:
			_e_box(Vector3(t.x + sx * x, y, t.y), Vector3(0.28, 0.006, 0.014), 0.4)
			x += 0.42
	var zz := hz + 0.3
	while zz < 2.3:
		_e_box(Vector3(t.x, y, t.y + zz), Vector3(0.014, 0.006, 0.28), 0.32)
		zz += 0.42
	# corner marks
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_e_box(Vector3(t.x + sx * (hx + 0.15), y, t.y + sz * (hz + 0.15)), Vector3(0.3, 0.006, 0.014), 0.7)
			_e_box(Vector3(t.x + sx * (hx + 0.15), y, t.y + sz * (hz + 0.15)), Vector3(0.014, 0.006, 0.3), 0.7)

## Heavy dark cables from the table's rear legs out to the benches, with clips.
func _cables(t: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var pts := [Vector3(t.x + side * 0.98, 0.03, t.y - 0.42), Vector3(t.x + side * 1.5, 0.03, t.y - 0.62),
				Vector3(t.x + side * 2.0, 0.03, t.y - 1.1), Vector3(t.x + side * 2.45, 0.03, t.y - 1.5), Vector3(side * 3.0, 0.03, -3.25)]
		for k in pts.size() - 1:
			lit.add_rod(pts[k], pts[k + 1], 0.024, _ti(0.05), 8, true)
			lit.add_box((pts[k] + pts[k + 1]) * 0.5 + Vector3(0, 0.0, 0.0), Vector3(0.05, 0.012, 0.05), _ti(0.4))
		_e_box(pts[pts.size() - 1] + Vector3(0, 0.02, 0), Vector3(0.05, 0.02, 0.05), 0.8)

# ---------------------------------------------------------------- screens

func _screen_bank() -> void:
	# [centre, size, yaw_deg (0 faces +Z, 90 faces +X, -90 faces -X), kind, seed]
	var defs := [
		[Vector3(-2.0, 1.95, -4.96), Vector2(1.5, 0.85), 0.0, 0, 0.12],
		[Vector3(2.0, 1.95, -4.96), Vector2(1.5, 0.85), 0.0, 1, 0.47],
		[Vector3(0.0, 2.8, -4.96), Vector2(2.6, 0.36), 0.0, 3, 0.81],
		[Vector3(-3.96, 1.95, -2.1), Vector2(1.6, 0.9), 90.0, 2, 0.33],
		[Vector3(-3.96, 1.95, -4.05), Vector2(1.5, 0.85), 90.0, 1, 0.64],
		[Vector3(3.96, 1.95, -2.1), Vector2(1.6, 0.9), -90.0, 3, 0.9],
		[Vector3(3.96, 1.95, -4.05), Vector2(1.5, 0.85), -90.0, 0, 0.27],
	]
	for d in defs:
		var c: Vector3 = d[0]
		var sz: Vector2 = d[1]
		var b := Basis(Vector3.UP, deg_to_rad(d[2]))
		var n := b.z
		var aspect := sz.x / sz.y
		screens.add_quad(c + n * 0.045, sz, b, Color(d[4], float(d[3]) / 8.0, aspect / 8.0, 1.0))
		# bezel: dark frame box behind the glass and a thin lit outline
		lit.add_box(c + n * 0.02, Vector3(sz.x + 0.1, sz.y + 0.1, 0.04), _ti(0.08), b)
		var ol := 0.012
		_e_box(c + n * 0.048 + b.y * (sz.y * 0.5 + 0.045), Vector3(sz.x + 0.1, ol, 0.004), 0.5, b)
		_e_box(c + n * 0.048 - b.y * (sz.y * 0.5 + 0.045), Vector3(sz.x + 0.1, ol, 0.004), 0.5, b)

# ---------------------------------------------------------------- light FX (additive, one mesh)

func _light_fx(t: Vector2) -> void:
	var table_top := 0.97
	# shafts from the four spots (soft) and a broad one from the ring, all ending on the table
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var top := Vector3(t.x + sx * 1.55 * 0.56, 2.86, t.y + sz * 1.15 * 0.45)
			var bot := Vector3(t.x + sx * 0.5, table_top, t.y + sz * 0.3)
			fx.add_shaft(top, 0.07, bot, 0.42, Color(0.16, 0.0, (sx + sz + 2.0) * 0.13, 1.0), 14)
	fx.add_shaft(Vector3(t.x, 2.9, t.y), 1.0, Vector3(t.x, table_top, t.y), 0.8, Color(0.05, 0.0, 0.5, 1.0), 28)
	# layered glow halos around the ring and a pool of light on the slab
	var down := Basis(Vector3.RIGHT, deg_to_rad(90.0))                    # quad normal -> +Y ... facing up
	var flat_up := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	fx.add_quad(Vector3(t.x, 2.93, t.y), Vector2(3.0, 3.0), down, Color(0.16, 0.5, 0.1, 1.0))
	fx.add_quad(Vector3(t.x, 2.94, t.y), Vector2(1.7, 1.7), down, Color(0.28, 0.5, 0.4, 1.0))
	fx.add_quad(Vector3(t.x, table_top, t.y), Vector2(2.1, 1.1), flat_up, Color(0.22, 0.5, 0.7, 1.0))
	# floor: under-glow spill + gloss streaks under the strips and each leg (the "reflection" of the cyan lines)
	fx.add_quad(Vector3(t.x, 0.009, t.y), Vector2(3.6, 2.2), flat_up, Color(0.38, 0.5, 0.2, 1.0))
	for sz in [-1.0, 1.0]:
		var yaw := Basis(Vector3.UP, deg_to_rad(0.0 if sz > 0 else 180.0))
		var streak := yaw * flat_up
		fx.add_quad(Vector3(t.x, 0.008, t.y + sz * (0.62 + 0.3)), Vector2(2.3, 0.6), streak, Color(0.55, 1.0, 0.3, 1.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var yaw2 := Basis(Vector3.UP, deg_to_rad(0.0 if sz > 0 else 180.0))
			fx.add_quad(Vector3(t.x + sx * 1.0, 0.0085, t.y + sz * (0.45 + 0.4)), Vector2(0.12, 0.8), yaw2 * flat_up, Color(0.5, 1.0, 0.6, 1.0))
