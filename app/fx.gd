class_name Fx
## Material factories: every colour comes from Tokens.

static func ring_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://ring.gdshader")
	m.set_shader_parameter("base_color", Tokens.HOLO_PRIMARY)
	m.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	m.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	m.set_shader_parameter("minor_ticks", float(Tokens.RING_MINOR_TICKS))
	m.set_shader_parameter("major_ticks", float(Tokens.RING_MAJOR_TICKS))
	m.set_shader_parameter("inner_a", Tokens.RING_INNER[0])
	m.set_shader_parameter("inner_b", Tokens.RING_INNER[1])
	return m

static func grid_material(base: Color, minor_step: float, major_step: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://grid.gdshader")
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("minor_color", Tokens.GRID_MINOR)
	m.set_shader_parameter("major_color", Tokens.HOLO_PRIMARY)
	m.set_shader_parameter("minor_strength", Tokens.GRID_MINOR_ALPHA)
	m.set_shader_parameter("major_strength", Tokens.GRID_MINOR_ALPHA * 2.0)
	m.set_shader_parameter("minor_spacing", minor_step)
	m.set_shader_parameter("major_spacing", major_step)
	m.set_shader_parameter("minor_strength", 0.13)   # v2 look pass (Jon: "obnoxious blue lines") — the grid whispers; the hologram is the hero
	m.set_shader_parameter("major_strength", 0.25)
	m.set_shader_parameter("fine_strength", 0.05)
	return m

## Light strip with a pulse travelling along `axis` (see pulse.gdshader). HDR energy as Fx.emissive.
static func pulse_material(c: Color, energy: float, axis := Vector3.RIGHT, span := 2.24, phase := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://pulse.gdshader")
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("axis", axis)
	m.set_shader_parameter("span", span)
	m.set_shader_parameter("phase", phase)
	return m

## R4-2: ONE shared material for every hologram part of each shader kind. Everything that varies
## per part (aabb, wire, scan, y0, y1, flash) is an INSTANCE uniform in the shaders, set per
## MeshInstance3D — so a 27-part model costs 1 material instead of 27, and parts batch together.
## Contract: NEVER set a regular uniform on these at runtime; per-part values go through
## set_instance_shader_parameter on the part itself.
static var _part_mat: ShaderMaterial
static var _mesh_part_mat: ShaderMaterial

static func part_material() -> ShaderMaterial:
	if _part_mat:
		return _part_mat
	var m := ShaderMaterial.new()
	m.shader = load("res://holo.gdshader")
	m.set_shader_parameter("fill_color", Tokens.HOLO_PRIMARY)
	m.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	m.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	m.set_shader_parameter("fill_alpha", Tokens.VOLUME_ALPHA)
	_part_mat = m
	return m

## Real-mesh hologram (fresnel rim + volume fill, promoted from the parked trebuchet work): same
## instance uniforms as part_material, so a runtime CAD model materializes identically.
static func mesh_part_material() -> ShaderMaterial:
	if _mesh_part_mat:
		return _mesh_part_mat
	var m := ShaderMaterial.new()
	m.shader = load("res://holo_mesh.gdshader")
	m.set_shader_parameter("fill_color", Tokens.HOLO_PRIMARY)
	m.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	m.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	m.set_shader_parameter("fill_alpha", Tokens.VOLUME_ALPHA)
	_mesh_part_mat = m
	return m

static func additive_unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m

static var _brushed: ImageTexture
static var _brushed_n: ImageTexture

## Brushed-metal grain (brief #12: clearer at working distance). Streaks run along the face's U axis: per-row
## brightness bands (some bright machining lines), fine noise, and a few long light scratches. Mean ~0.84 so
## albedo_color keeps its tone. The same height field feeds brushed_normal().
static var _grain_h := PackedFloat32Array()
const GRAIN_N := 256

static func _grain() -> void:
	if not _grain_h.is_empty():
		return
	var n := GRAIN_N
	var rng := RandomNumberGenerator.new()
	rng.seed = 1621
	_grain_h.resize(n * n)
	for y in n:
		var v := 0.8 + rng.randf_range(-0.16, 0.14)
		if rng.randf() < 0.07:
			v += 0.12                                  # a bright machining line
		for x in n:
			_grain_h[y * n + x] = clampf(v + rng.randf_range(-0.045, 0.045), 0.0, 1.0)
	for k in 14:                                       # long fine scratches, slightly off-axis
		var y0 := rng.randf() * n
		var slope := rng.randf_range(-0.03, 0.03)
		var x_start := rng.randi() % n
		var len := rng.randi_range(n / 3, n)
		for dx in len:
			var x := (x_start + dx) % n
			var y := int(y0 + slope * dx) % n
			_grain_h[y * n + x] = clampf(_grain_h[y * n + x] + 0.16, 0.0, 1.0)

static func brushed_texture() -> ImageTexture:
	if _brushed:
		return _brushed
	_grain()
	var n := GRAIN_N
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	for y in n:
		for x in n:
			var w := _grain_h[y * n + x]
			img.set_pixel(x, y, Color(w, w, w))
	img.generate_mipmaps()
	_brushed = ImageTexture.create_from_image(img)
	return _brushed

## Normal map from the grain height field: the streaks tilt the surface across the brushing direction, which is what
## makes the light catch in lines on the slab edge and top (anisotropic look without an anisotropic shader).
static func brushed_normal() -> ImageTexture:
	if _brushed_n:
		return _brushed_n
	_grain()
	var n := GRAIN_N
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		var yp := (y + 1) % n
		var ym := (y + n - 1) % n
		for x in n:
			var dx := _grain_h[y * n + (x + 1) % n] - _grain_h[y * n + (x + n - 1) % n]
			var dy := _grain_h[yp * n + x] - _grain_h[ym * n + x]
			var nv := Vector3(-dx * 0.6, -dy * 2.4, 1.0).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	img.generate_mipmaps()
	_brushed_n = ImageTexture.create_from_image(img)
	return _brushed_n

static func titanium(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = brushed_texture()
	m.normal_enabled = true
	m.normal_texture = brushed_normal()
	m.normal_scale = 0.8
	m.metallic = 0.92
	m.roughness = 0.27
	return m

## Soft radial sprite (white centre -> transparent edge): glow pools, halos.
## R4-1: cached by (size, power) — call sites repeat the same pairs, and each generation is a
## per-pixel GDScript loop plus a texture upload. Textures are immutable, so sharing is safe.
static var _radial_cache: Dictionary = {}

static func radial_texture(size: int, power := 1.0) -> ImageTexture:
	var key := "%d|%s" % [size, str(power)]
	if _radial_cache.has(key):
		return _radial_cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - h, y + 0.5 - h).length() / h
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_radial_cache[key] = tex
	return tex

## Additive soft-glow material from a radial_texture; alpha scales it.
static func glow_decal(c: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := additive_unshaded(c)
	m.albedo_texture = tex
	return m

## Light strips / bezel trim: unshaded, HDR albedo so the existing glow picks it up.
static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy)
	return m
