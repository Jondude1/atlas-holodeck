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

var _prop_spots: Array = []   # [kind, world spot] for the grabbable bench props (R5B)
var lit := MeshBuilder.new()
var emi := MeshBuilder.new()
var fx := MeshBuilder.new()
var screens := MeshBuilder.new()

var _lit_mat: StandardMaterial3D
var _emi_mat: StandardMaterial3D
var _fx_mat: ShaderMaterial
var _screen_mat: ShaderMaterial
var _fade := 1.0
var _rng := RandomNumberGenerator.new()
var _table_xz := Vector2.ZERO
var _arm: RobotArm
var _presence: Presence

func presence() -> Presence:
	return _presence

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
func _e_box(c: Vector3, size: Vector3, k := 0.6, basis := Basis.IDENTITY, eb: MeshBuilder = null) -> void:
	(eb if eb != null else emi).add_box(c, size, Color(Tokens.HOLO_LINE.r * k, Tokens.HOLO_LINE.g * k, Tokens.HOLO_LINE.b * k), basis)

# ---------------------------------------------------------------- build

func build(table_xz: Vector2) -> void:
	_table_xz = table_xz
	_rng.seed = 1621
	# Round 6 — the room Jon asked for (the walk-in picture): bare slab benches, suit pads
	# flanking the far opening, white ceiling bars, and SPACE. The clutter of Rounds 3–5
	# (shelves, greebles, ceiling rig, screen bank, cables, data-station wall) is gone;
	# readouts return as movable wall widgets (R6-2), Atlas as the free-floating Presence.
	_bench_slabs()
	_suit_platforms()
	_ceiling_bars()
	_seal()
	_spawn_props()
	_arm = RobotArm.new()
	_arm.name = "RobotArm"
	_arm.position = Vector3(3.5, 0.9475, -4.0)
	add_child(_arm)
	_presence = Presence.new()
	_presence.name = "Presence"
	_presence.position = Vector3(-1.85, 0, -2.6)
	_presence.scale = Vector3.ONE * 1.3   # R6 pic-pass: the picture's sphere is a large presence, ~1.1 m across
	add_child(_presence)
	# R3-9: the table's edge light spills onto the floor as a soft gloss strip (fake reflection)
	var gloss := MeshInstance3D.new()
	gloss.name = "FloorGloss"
	var gp := PlaneMesh.new()
	gp.size = Vector2(3.1, 1.35)
	gloss.mesh = gp
	gloss.material_override = Fx.glow_decal(Tokens.a(Tokens.HOLO_PRIMARY, 0.09), Fx.radial_texture(128, 1.9))
	gloss.position = Vector3(table_xz.x, 0.006, table_xz.y + 1.05)
	add_child(gloss)

	# R7-0: baked contact shadows — with no realtime shadow maps (Quest budget), soft
	# dark blobs under the furniture are what ground it; flat CG floats, this sits.
	var sh_mat := StandardMaterial3D.new()
	sh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sh_mat.albedo_color = Color(0, 0, 0, 0.4)
	sh_mat.albedo_texture = Fx.radial_texture(128, 1.6)
	for spec in [[Vector3(table_xz.x, 0.003, table_xz.y), Vector2(3.6, 2.2)],
			[Vector3(3.55, 0.003, -2.5), Vector2(1.5, 4.6)],
			[Vector3(-3.55, 0.003, -2.5), Vector2(1.5, 4.6)]]:
		var sh := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = spec[1]
		sh.mesh = sp
		sh.material_override = sh_mat
		sh.position = spec[0]
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sh)

## Round 6: two ring-lit display platforms flanking the FAR opening, inside the room —
## the suit bay, as the picture has it. (Suits arrive via the image-to-3D pipeline.)
func _suit_platforms() -> void:
	for px in [-2.95, 2.95]:
		lit.add_cyl(Vector3(px, 0.035, -4.15), 0.58, 0.07, _ti(0.5), 28)
		lit.add_cyl(Vector3(px, 0.075, -4.15), 0.5, 0.012, _deep(0.3), 28)
		var ring := Color(Tokens.HOLO_LINE.r * 0.32, Tokens.HOLO_LINE.g * 0.32, Tokens.HOLO_LINE.b * 0.32)
		emi.add_torus(Vector3(px, 0.078, -4.15), 0.53, 0.012, ring, 48, 6)
		emi.add_cyl(Vector3(px, 0.004, -4.15), 0.64, 0.008, ring * 0.35, 28)

## Bare benches along both side walls — dark slabs on block legs, an emissive edge line,
## nothing on them but what Jon puts there (the props + the arm, on the right).
func _bench_slabs() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 3.55
		lit.add_box(Vector3(x, 0.92, -2.5), Vector3(0.7, 0.055, 3.9), _ti(0.5))
		for lz in [-4.15, -0.85]:
			lit.add_box(Vector3(x, 0.44, lz), Vector3(0.6, 0.85, 0.18), _deep(0.3))
		_e_box(Vector3(x - side * 0.36, 0.9, -2.5), Vector3(0.012, 0.012, 3.9), 0.35)
	# the grabbable props live on the right slab
	_prop_spots.append([5, Vector3(3.5, 0.9475, -2.25)])
	_prop_spots.append([6, Vector3(3.5, 0.9475, -1.55)])

## Slim WHITE light bars in the dark ceiling (the picture's lighting signature) — HDR
## vertex colour so they bloom softly; the room's actual light stays the table's rig.
func _ceiling_bars() -> void:
	emi.add_box(Vector3(0, 3.36, -1.0), Vector3(0.16, 0.03, 3.6), Color(1.9, 1.9, 1.85))
	for side in [-1.0, 1.0]:
		emi.add_box(Vector3(side * 2.3, 3.36, -1.0), Vector3(0.13, 0.03, 2.8), Color(1.5, 1.5, 1.45))

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
	if fx.vertex_count() > 0:
		_add_mesh("LabLightFx", fx.build(), _fx_mat)

	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = load("res://screens.gdshader")
	_screen_mat.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	_screen_mat.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	_screen_mat.set_shader_parameter("deep_color", Tokens.HOLO_DEEP)
	if screens.vertex_count() > 0:
		_add_mesh("LabScreens", screens.build(), _screen_mat)

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
	if _presence:
		_presence.set_fade(v)

# ---------------------------------------------------------------- workbenches

## A long bench against a side wall: cabinets with seams and cyan handles, a work top with a lit edge, and equipment.
func _bench_item(kind: int, at: Vector3, side: float, lb: MeshBuilder = null, eb: MeshBuilder = null) -> float:
	var inward := -side           # towards the room
	var L := lb if lb != null else lit   # props pass their own builders (kinds 5/6 only)
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
			L.add_cyl(at + Vector3(0, 0.015, 0), 0.07, 0.03, _ti(0.3), 12)
			L.add_rod(at + Vector3(0, 0.03, 0), at + Vector3(inward * 0.1, 0.42, 0.04), 0.01, _ti(0.5))
			L.add_rod(at + Vector3(inward * 0.1, 0.42, 0.04), at + Vector3(inward * 0.3, 0.38, 0.1), 0.01, _ti(0.5))
			_e_box(at + Vector3(inward * 0.31, 0.37, 0.1), Vector3(0.05, 0.012, 0.05), 0.9, Basis.IDENTITY, eb)
			L.add_torus(at + Vector3(side * 0.06, 0.08, -0.32), 0.1, 0.035, _deep(0.5), 18, 6, Basis(Vector3.RIGHT, 0.2))
			return 0.7
		_:  # crates
			L.add_box(at + Vector3(0, 0.1, 0), Vector3(0.4, 0.2, 0.34), _deep(0.3 + 0.2 * _rng.randf()))
			L.add_box(at + Vector3(0.02, 0.28, 0.02), Vector3(0.3, 0.16, 0.26), _deep(0.25 + 0.2 * _rng.randf()))
			_e_box(at + Vector3(inward * 0.201, 0.1, 0), Vector3(0.006, 0.02, 0.14), 0.4, Basis.IDENTITY, eb)
			return 0.55

# ---------------------------------------------------------------- shelving

## A shelving unit against the back wall (origin = floor point at the unit's centre): four uprights, boards with lit edges,
## crates, drums and tool silhouettes on every level.
# ---------------------------------------------------------------- walls

## Panel pilasters, pipe runs on brackets, vents, junction boxes with LEDs - along each wall so the planes read as
## built, not painted. (a = wall start, dir = along the wall, n = inward normal)
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

# ---------------------------------------------------------------- floor

# ---------------------------------------------------------------- screens

# ---------------------------------------------------------------- light FX (additive, one mesh)

func _spawn_props() -> void:
	for spot in _prop_spots:
		var kind := int(spot[0])
		var plit := MeshBuilder.new()
		var pemi := MeshBuilder.new()
		_bench_item(kind, Vector3.ZERO, 1.0, plit, pemi)
		var prop := Prop.new()
		prop.name = "PropLamp" if kind == 5 else "PropCrates"
		var lm := MeshInstance3D.new()
		lm.mesh = plit.build()
		lm.material_override = _lit_mat
		prop.add_child(lm)
		var em := MeshInstance3D.new()
		em.mesh = pemi.build()
		em.material_override = _emi_mat
		prop.add_child(em)
		prop.center_local = Vector3(0, 0.24, 0) if kind == 5 else Vector3(0, 0.18, 0)
		prop.grab_radius = 0.5
		prop.position = spot[1]
		add_child(prop)
