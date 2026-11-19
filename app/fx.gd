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
	return m

static func part_material(aabb: AABB) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://holo.gdshader")
	m.set_shader_parameter("fill_color", Tokens.HOLO_PRIMARY)
	m.set_shader_parameter("line_color", Tokens.HOLO_LINE)
	m.set_shader_parameter("core_color", Tokens.HOLO_CORE)
	m.set_shader_parameter("fill_alpha", Tokens.VOLUME_ALPHA)
	m.set_shader_parameter("aabb_center", aabb.get_center())
	m.set_shader_parameter("aabb_half", aabb.size * 0.5)
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

## Brushed-metal grain: fine streaks along the face's U axis, mean ~0.85 so albedo_color keeps its tone.
static func brushed_texture() -> ImageTexture:
	if _brushed:
		return _brushed
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1621
	for y in n:
		var v := 0.82 + rng.randf_range(-0.12, 0.1)
		for x in n:
			var w := clampf(v + rng.randf_range(-0.035, 0.035), 0.0, 1.0)
			img.set_pixel(x, y, Color(w, w, w))
	img.generate_mipmaps()
	_brushed = ImageTexture.create_from_image(img)
	return _brushed

static func titanium(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = brushed_texture()
	m.metallic = 0.9
	m.roughness = 0.3
	return m

## Soft radial sprite (white centre -> transparent edge): glow pools, halos.
static func radial_texture(size: int, power := 1.0) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var h := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - h, y + 0.5 - h).length() / h
			var a := pow(clampf(1.0 - d, 0.0, 1.0), power)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

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
