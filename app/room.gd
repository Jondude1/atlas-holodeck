class_name Room
extends Node3D
## The workshop (brief #8): a dark room the table stands ON. Floor, four wall planes with
## canvas-generated panel/shelving textures, a ceiling with beams and one cyan cove strip,
## recessed cyan accents, a contact shadow + glow pool under the table, and drifting dust.
## Procedural only: every texture is drawn here, every colour comes from Tokens.
## Brief #12 adds the Stark-lab dressing (lab.gd): workbenches, shelving + equipment, wall greebles, animated screens, a
## ceiling light rig with shafts, floor trim + gloss streaks. The beams, accent strips and cove are merged into the lab's
## meshes (they used to be 11 separate draw calls).
## Cost: ~15 draw calls at rest (floor, pool + 2 shadow decals, 4 walls, ceiling, cove halo, dust) + the lab's 5.

const HALF_X := 4.0
const Z_BACK := -5.0
const Z_FRONT := 3.0
const HEIGHT := 3.4
# Round 5 — the open wall (left, -X): a hangar opening onto the terrace and the vista.
const OPEN_Z0 := -4.2                  # opening span along the left wall
const OPEN_Z1 := 1.8
const OPEN_TOP := 2.9                  # opening head height (header above)
const TERRACE_X := -7.3                # terrace floor outer edge
const PPM := 128               # wall texture pixels per metre
const STRIP_ENERGY := 1.3
const COVE_ENERGY := 1.4
const POOL_ALPHA := 0.55
const SHADOW_ALPHA := 0.85
const HALO_ALPHA := 0.22

var _wall_mats: Array[StandardMaterial3D] = []
var _lit_mats: Array[StandardMaterial3D] = []   # floor + beams: albedo scaled by fade
var _lit_base: Array[Color] = []
var _strip_mats: Array[StandardMaterial3D] = []
var _strip_energy: Array[float] = []
var _glow_mats: Array[StandardMaterial3D] = []  # additive decals: alpha scaled by fade
var _glow_alpha: Array[float] = []
var _dust: GPUParticles3D
var _lab: Lab
var _fade := 1.0

## Table footprint centre on the floor (main.tscn places the table at z = -1.55).
func build(table_xz: Vector2) -> void:
	_lab = Lab.new()
	_lab.name = "Lab"
	add_child(_lab)                       # owns the merged lit / emissive builders the room adds its trim to
	_build_floor(table_xz)
	_build_walls()
	_build_ceiling()
	_lab.build(table_xz)                  # dressing + seals every merged mesh
	_build_dust()
	set_fade(1.0)

func station() -> DataStation:
	return _lab.station() if _lab else null

func set_fade(v: float) -> void:
	_fade = v
	if _lab:
		_lab.set_fade(v)
	for m in _wall_mats:
		m.albedo_color = Color(v, v, v)
	for i in _lit_mats.size():
		_lit_mats[i].albedo_color = _lit_base[i] * v
	for i in _strip_mats.size():
		var s := Tokens.HOLO_LINE * (_strip_energy[i] * v)
		_strip_mats[i].albedo_color = Color(s.r, s.g, s.b)
	for i in _glow_mats.size():
		_glow_mats[i].albedo_color = Tokens.a(_glow_mats[i].albedo_color, _glow_alpha[i] * v)

func start_dust() -> void:
	_dust.emitting = true

# ---------------------------------------------------------------- materials

func _unshaded_tex(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	_wall_mats.append(m)
	return m

func _lit(c: Color, metallic: float, rough: float, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex
	m.metallic = metallic
	m.roughness = rough
	_lit_mats.append(m)
	_lit_base.append(c)
	return m

func _strip(energy: float) -> StandardMaterial3D:
	var m := Fx.emissive(Tokens.HOLO_LINE, energy)
	_strip_mats.append(m)
	_strip_energy.append(energy)
	return m

func _glow(c: Color, tex: Texture2D, alpha: float) -> StandardMaterial3D:
	var m := Fx.glow_decal(Tokens.a(c, alpha), tex)
	_glow_mats.append(m)
	_glow_alpha.append(alpha)
	return m

func _mesh(nm: String, mesh: Mesh, mat: Material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi

func _quad(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

# ---------------------------------------------------------------- floor

func _build_floor(table_xz: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_X * 2.0, Z_FRONT - Z_BACK)
	# the texture carries the tone (dark blue-rich plate, seams + scuffs); the tint stays near white so the two don't
	# multiply into black (brief #12: darker and richer than #8, never black)
	var mat := _lit(Color(0.85, 0.92, 1.0), 0.6, 0.22, _floor_texture())           # glossy: the rig and table light streak across it
	mat.uv1_scale = Vector3(HALF_X * 2.0, Z_FRONT - Z_BACK, 1.0)
	_mesh("Floor", plane, mat, Vector3(0, 0, (Z_FRONT + Z_BACK) * 0.5))

	# soft glow pool spilling past the slab, then the contact shadow under it
	var pool_tex := Fx.radial_texture(128, 1.6)
	var pool := _mesh("GlowPool", _quad(Vector2(4.4, 2.8)), _glow(Tokens.HOLO_PRIMARY, pool_tex, POOL_ALPHA),
			Vector3(table_xz.x, 0.004, table_xz.y), Vector3(-90, 0, 0))
	pool.get_active_material(0).render_priority = 0
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_texture = Fx.radial_texture(128, 0.7)
	shadow_mat.albedo_color = Tokens.a(Tokens.ROOM_BG, SHADOW_ALPHA)
	shadow_mat.render_priority = 1
	_mesh("ContactShadow", _quad(Vector2(2.7, 1.5)), shadow_mat,
			Vector3(table_xz.x, 0.006, table_xz.y), Vector3(-90, 0, 0))
	# tight dark core right under the slab (contact shading): the table reads as standing ON the floor, not hovering
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_texture = Fx.radial_texture(96, 0.45)
	core_mat.albedo_color = Tokens.a(Tokens.ROOM_BG, 0.9)
	core_mat.render_priority = 2
	_mesh("ContactCore", _quad(Vector2(2.35, 1.0)), core_mat, Vector3(table_xz.x, 0.0075, table_xz.y), Vector3(-90, 0, 0))

## 1 m tile: dark plate, directional scuffs, bevelled seams.
func _floor_texture() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var base := Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, 0.5)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in 90:
		var a := Vector2(rng.randf() * n, rng.randf() * n)
		var dir := Vector2.from_angle(rng.randf_range(-0.5, 0.5) + (0.0 if rng.randf() < 0.7 else 1.57))
		var b := a + dir * rng.randf_range(10.0, 70.0)
		Blueprint._line(img, a, b, base.lerp(Tokens.HOLO_LINE, rng.randf_range(0.04, 0.2)), 1)
	for i in 500:  # fine grit
		img.set_pixel(rng.randi() % n, rng.randi() % n, base.lerp(Tokens.HOLO_LINE, rng.randf_range(0.05, 0.25)))
	var seam := Tokens.ROOM_BG * 0.5
	var edge := base.lerp(Tokens.HOLO_PRIMARY, 0.3)
	img.fill_rect(Rect2i(0, 0, n, 3), seam)
	img.fill_rect(Rect2i(0, 0, 3, n), seam)
	img.fill_rect(Rect2i(0, 3, n, 1), edge)
	img.fill_rect(Rect2i(3, 0, 1, n), edge)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- walls

func _build_walls() -> void:
	var width := HALF_X * 2.0
	var size := Vector2(width, HEIGHT)
	var y := HEIGHT * 0.5
	# accent strip positions in wall-texture pixels (x), matching the strip boxes placed below
	var back_px: Array[int] = []
	for wx in [-1.0, 1.0]:                # the shelving units own the outer bays now
		back_px.append(int((wx + HALF_X) * PPM))
	var right_z := -3.2
	var right_px: Array[int] = [int((right_z - Z_BACK) * PPM)]  # right wall: texture u runs -Z -> +Z
	_mesh("WallBack", _quad(size), _unshaded_tex(_wall_texture(false, 11, back_px)), Vector3(0, y, Z_BACK))
	_mesh("WallFront", _quad(size), _unshaded_tex(_wall_texture(false, 23, [])), Vector3(0, y, Z_FRONT), Vector3(0, 180, 0))
	var side := Vector2(Z_FRONT - Z_BACK, HEIGHT)
	_mesh("WallRight", _quad(side), _unshaded_tex(_wall_texture(true, 41, right_px)), Vector3(HALF_X, y, (Z_FRONT + Z_BACK) * 0.5), Vector3(0, -90, 0))
	_build_open_wall()

	for wx in [-1.0, 1.0]:                # accent strips: merged into the lab's emissive mesh (STRIP_ENERGY of E_BASE)
		_lab_strip(Vector3(wx, 1.5, Z_BACK + 0.016), Vector3(0.03, 1.2, 0.03))
	_lab_strip(Vector3(HALF_X - 0.016, 1.5, right_z), Vector3(0.03, 1.2, 0.03))

## Round 5: the left wall is no longer a wall — two pillars + a header leave a hangar
## opening (OPEN_Z0..OPEN_Z1, floor to OPEN_TOP) framed in titanium with a cyan light
## line, opening onto a railed terrace. The segments share the one wall texture/material
## so the panelling reads continuous; frame, railing and trim merge into the lab's
## builders (no extra draw calls beyond the segments + the terrace floor).
func _build_open_wall() -> void:
	var mat := _unshaded_tex(_wall_texture(true, 37, []))
	_mesh("WallLeftBack", _wall_segment(Z_BACK, OPEN_Z0, 0.0, HEIGHT), mat, Vector3.ZERO)
	_mesh("WallLeftFront", _wall_segment(OPEN_Z1, Z_FRONT, 0.0, HEIGHT), mat, Vector3.ZERO)
	_mesh("WallLeftHeader", _wall_segment(OPEN_Z0, OPEN_Z1, OPEN_TOP, HEIGHT), mat, Vector3.ZERO)
	var ti := Color(0.32, 0.38, 0.46)
	var k := STRIP_ENERGY / Lab.E_BASE
	var line := Color(Tokens.HOLO_LINE.r * k, Tokens.HOLO_LINE.g * k, Tokens.HOLO_LINE.b * k)
	# machined frame: jambs + head beam + a threshold plate at the floor line
	_lab.lit.add_box(Vector3(-HALF_X, OPEN_TOP * 0.5, OPEN_Z0), Vector3(0.2, OPEN_TOP, 0.2), ti)
	_lab.lit.add_box(Vector3(-HALF_X, OPEN_TOP * 0.5, OPEN_Z1), Vector3(0.2, OPEN_TOP, 0.2), ti)
	_lab.lit.add_box(Vector3(-HALF_X, (OPEN_TOP + HEIGHT) * 0.5, (OPEN_Z0 + OPEN_Z1) * 0.5), Vector3(0.2, HEIGHT - OPEN_TOP, OPEN_Z1 - OPEN_Z0 + 0.2), ti)
	_lab.lit.add_box(Vector3(-HALF_X, 0.012, (OPEN_Z0 + OPEN_Z1) * 0.5), Vector3(0.34, 0.024, OPEN_Z1 - OPEN_Z0), ti * 0.8)
	# the cyan light line tracing the opening's inner edge
	_lab.emi.add_box(Vector3(-HALF_X + 0.11, OPEN_TOP * 0.5, OPEN_Z0 + 0.11), Vector3(0.025, OPEN_TOP, 0.025), line)
	_lab.emi.add_box(Vector3(-HALF_X + 0.11, OPEN_TOP * 0.5, OPEN_Z1 - 0.11), Vector3(0.025, OPEN_TOP, 0.025), line)
	_lab.emi.add_box(Vector3(-HALF_X + 0.11, OPEN_TOP - 0.02, (OPEN_Z0 + OPEN_Z1) * 0.5), Vector3(0.025, 0.025, OPEN_Z1 - OPEN_Z0 - 0.2), line)
	# terrace floor: the room's plate, extended past the wall line to the railing
	var tmat := _lit(Color(0.45, 0.52, 0.62), 0.55, 0.45, _floor_texture())
	tmat.uv1_scale = Vector3(-TERRACE_X - HALF_X, Z_FRONT - Z_BACK, 1.0)
	var terrace := PlaneMesh.new()
	terrace.size = Vector2(-TERRACE_X - HALF_X, Z_FRONT - Z_BACK)
	_mesh("Terrace", terrace, tmat, Vector3((TERRACE_X - HALF_X) * 0.5, -0.005, (Z_FRONT + Z_BACK) * 0.5))
	# railing: posts + two rails on the outer edge, top rails closing both ends, a lit lip
	var rail_x := TERRACE_X + 0.15
	for i in 7:
		_lab.lit.add_box(Vector3(rail_x, 0.48, -4.9 + i * 1.3), Vector3(0.05, 0.96, 0.05), ti)
	_lab.lit.add_box(Vector3(rail_x, 0.97, -1.0), Vector3(0.06, 0.05, 8.0), ti)
	_lab.lit.add_box(Vector3(rail_x, 0.55, -1.0), Vector3(0.04, 0.03, 8.0), ti)
	for e in [-4.97, 2.97]:
		_lab.lit.add_box(Vector3((rail_x - HALF_X) * 0.5, 0.97, e), Vector3(-rail_x - HALF_X, 0.05, 0.06), ti)
		_lab.lit.add_box(Vector3(rail_x, 0.48, e), Vector3(0.05, 0.96, 0.05), ti)
	_lab.emi.add_box(Vector3(TERRACE_X + 0.02, 0.02, -1.0), Vector3(0.03, 0.015, 8.0), line * 0.7)

## One piece of the left wall in world space at x = -HALF_X, facing +X, with UVs that
## continue the full-wall texture (u runs +Z -> -Z, v = 1 at the floor).
func _wall_segment(za: float, zb: float, y0: float, y1: float) -> ArrayMesh:
	var ua := (Z_FRONT - za) / (Z_FRONT - Z_BACK)
	var ub := (Z_FRONT - zb) / (Z_FRONT - Z_BACK)
	var va := 1.0 - y0 / HEIGHT
	var vb := 1.0 - y1 / HEIGHT
	var a := Vector3(-HALF_X, y1, zb)
	var b := Vector3(-HALF_X, y1, za)
	var c := Vector3(-HALF_X, y0, za)
	var d := Vector3(-HALF_X, y0, zb)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, c, b, a, d, c])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(ub, vb), Vector2(ua, va), Vector2(ua, vb),
		Vector2(ub, vb), Vector2(ub, va), Vector2(ua, va)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _lab_strip(c: Vector3, size: Vector3, energy := STRIP_ENERGY) -> void:
	var k := energy / Lab.E_BASE
	_lab.emi.add_box(c, size, Color(Tokens.HOLO_LINE.r * k, Tokens.HOLO_LINE.g * k, Tokens.HOLO_LINE.b * k))

## Wall plane texture: panel seams, recessed bays, optionally shelving silhouettes, accent halos.
func _wall_texture(shelves: bool, seed_v: int, strip_px: Array[int]) -> ImageTexture:
	var w := int((HALF_X * 2.0) * PPM)
	var h := int(HEIGHT * PPM)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, 0.28)
	for y in h:  # vertical falloff: lit mid-height, dark toward floor and ceiling
		var t := absf(float(y) / h - 0.55) * 2.0
		img.fill_rect(Rect2i(0, y, w, 1), base.lerp(Tokens.ROOM_BG, clampf(t * 0.85, 0.0, 0.9)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var seam := Tokens.ROOM_BG * 0.6
	var edge := base.lerp(Tokens.HOLO_PRIMARY, 0.22)
	var bay := PPM  # 1 m panels
	for x in range(0, w, bay):  # panel seams with a bevel highlight beside each
		img.fill_rect(Rect2i(x, 0, 3, h), seam)
		img.fill_rect(Rect2i(x + 3, 0, 1, h), edge)
	for ym in [0.45, 2.6]:  # horizontal rails
		var yy := int((HEIGHT - ym) * PPM)
		img.fill_rect(Rect2i(0, yy, w, 3), seam)
		img.fill_rect(Rect2i(0, yy + 3, w, 1), edge)
	var recess := base.lerp(Tokens.ROOM_BG, 0.35)
	if not shelves:  # recessed panel bays on the plain walls
		for x in range(bay, w - bay, bay * 2):
			var r := Rect2(x + 14, int((HEIGHT - 2.4) * PPM), bay * 2 - 28, int(1.7 * PPM))
			img.fill_rect(Rect2i(r.position, r.size), recess)
			Blueprint._rect(img, r, edge, 1)
			Blueprint._rect(img, r.grow(-8), seam, 1)
	else:
		_shelves(img, rng, base, w, h)
	for px in strip_px:  # soft halo around each accent strip
		_halo(img, Rect2i(px - 2, int((HEIGHT - 2.1) * PPM), 4, int(1.2 * PPM)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _halo(img: Image, core: Rect2i) -> void:
	for k in range(14, 0, -1):
		var r := core.grow(k * 4)
		var a := 0.05 * (1.0 - float(k) / 15.0)
		_blend(img, r, Tokens.a(Tokens.HOLO_LINE, a))
	img.fill_rect(core.grow(-1), Tokens.HOLO_LINE.lerp(Tokens.HOLO_CORE, 0.5))

func _blend(img: Image, r: Rect2i, col: Color) -> void:
	var x0 := maxi(r.position.x, 0)
	var y0 := maxi(r.position.y, 0)
	var x1 := mini(r.end.x, img.get_width())
	var y1 := mini(r.end.y, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r + col.r * col.a, c.g + col.g * col.a, c.b + col.b * col.a, 1.0))

## Dim shelving bays: boards, uprights, crates, drums and tool silhouettes, the odd status LED.
func _shelves(img: Image, rng: RandomNumberGenerator, base: Color, w: int, h: int) -> void:
	var board := base.lerp(Tokens.HOLO_PRIMARY, 0.2)
	var upright := base.lerp(Tokens.ROOM_BG, 0.45)
	var rim := base.lerp(Tokens.HOLO_LINE, 0.28)
	var levels := [0.5, 1.05, 1.6, 2.15]
	var x_start := int(0.35 * PPM)
	var x_end := w - int(0.35 * PPM)
	for lm in levels:
		var by := int((HEIGHT - lm) * PPM)
		var x := x_start
		while x < x_end - 20:
			var iw := rng.randi_range(14, 60)
			var ih := rng.randi_range(14, 56)
			var col := base.lerp(Tokens.HOLO_DEEP, rng.randf_range(0.25, 0.75))
			var kind := rng.randi() % 4
			if kind == 0:  # drum / cylinder with a lit rim
				var r := iw / 2
				for dx in range(-r, r + 1):
					var dh := int(ih * (0.82 + 0.18 * cos(float(dx) / r * 1.2)))
					img.fill_rect(Rect2i(x + r + dx, by - dh, 1, dh), col)
				img.fill_rect(Rect2i(x, by - ih, iw, 1), rim)
			elif kind == 1:  # tool: tall thin handle + head
				img.fill_rect(Rect2i(x + iw / 2, by - ih - 14, 3, ih + 14), col)
				img.fill_rect(Rect2i(x + iw / 2 - 8, by - ih - 14, 19, 6), col)
			else:  # crate
				img.fill_rect(Rect2i(x, by - ih, iw, ih), col)
				img.fill_rect(Rect2i(x, by - ih, iw, 1), rim)
				Blueprint._rect(img, Rect2(x + 3, by - ih + 3, iw - 6, ih - 6), col.lerp(upright, 0.5), 1)
			if rng.randf() < 0.07:  # status LED
				img.fill_rect(Rect2i(x + iw / 2, by - ih / 2, 2, 2), Tokens.HOLO_LINE)
			x += iw + rng.randi_range(4, 26)
		img.fill_rect(Rect2i(x_start - 6, by, x_end - x_start + 12, 5), board)
		img.fill_rect(Rect2i(x_start - 6, by, x_end - x_start + 12, 1), rim)
	for x in range(x_start - 6, x_end + 8, PPM):  # uprights
		img.fill_rect(Rect2i(x, int((HEIGHT - 2.25) * PPM), 5, int(1.85 * PPM)), upright)

# ---------------------------------------------------------------- ceiling

func _build_ceiling() -> void:
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_mats.append(ceil_mat)
	var tex_img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	tex_img.fill(Tokens.ROOM_BG.lerp(Tokens.HOLO_DEEP, 0.1))
	ceil_mat.albedo_texture = ImageTexture.create_from_image(tex_img)
	_mesh("Ceiling", _quad(Vector2(HALF_X * 2.0, Z_FRONT - Z_BACK)), ceil_mat,
			Vector3(0, HEIGHT, (Z_FRONT + Z_BACK) * 0.5), Vector3(90, 0, 0))
	for z in [-4.0, -2.4, -0.8, 0.8, 2.4]:
		_lab.lit.add_box(Vector3(0, HEIGHT - 0.1, z), Vector3(HALF_X * 2.0, 0.2, 0.24), Tokens.TITANIUM_DARK)
	# cove: one soft cyan strip where the back wall meets the ceiling, with a halo wash on the wall
	_lab_strip(Vector3(0, HEIGHT - 0.28, Z_BACK + 0.04), Vector3(HALF_X * 1.85, 0.04, 0.05), COVE_ENERGY)
	var wash_tex := Fx.radial_texture(128, 1.4)
	_mesh("CoveHalo", _quad(Vector2(HALF_X * 2.0, 1.1)), _glow(Tokens.HOLO_LINE, wash_tex, HALO_ALPHA),
			Vector3(0, HEIGHT - 0.55, Z_BACK + 0.01))

# ---------------------------------------------------------------- atmosphere

func _build_dust() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.6, 1.4, 3.6)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.04
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var g := Gradient.new()
	g.colors = PackedColorArray([Tokens.a(Tokens.HOLO_LINE, 0.0), Tokens.a(Tokens.HOLO_LINE, 0.55), Tokens.a(Tokens.HOLO_LINE, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	pm.color_ramp = ramp
	var mat := Fx.additive_unshaded(Color.WHITE)
	mat.albedo_texture = Fx.radial_texture(32, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.014
	quad.material = mat
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 240
	_dust.lifetime = 14.0
	_dust.preprocess = 8.0
	_dust.emitting = false
	_dust.process_material = pm
	_dust.draw_pass_1 = quad
	_dust.visibility_aabb = AABB(Vector3(-4.5, -0.2, -5.5), Vector3(9.0, 4.0, 9.0))
	_dust.position = Vector3(0, 1.7, -1.5)
	add_child(_dust)
