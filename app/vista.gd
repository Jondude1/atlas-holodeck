class_name VistaDeck
extends Node3D
## Round 5 — the world outside the open wall, built the way the original Oculus Home did
## scenery (research: ~/workspace/research_notes/oculus-home-vista-spec-20261124): the
## backdrop is pre-filtered IMAGERY ON CURVED SURFACES at graded distances, not a simulated
## world. Per vista: a gradient sky dome, the photographic painting on a far cylindrical
## card, an animated water plane (coast/lake), two drifting mist banks and a cloud band.
## All motion is shader TIME — zero per-frame CPU. All materials unshaded, fog off, shadows
## off; every vista node sits on visual layer 2 so other systems never see it.
## All three vistas stay resident (~2 MB of texture each at shipping size); a swap is a
## visibility toggle plus a 0.6 s crossfade of the Environment and the table's light rig —
## geometry + lighting state travel together, the Rift custom-environment bundle model.
## Approximation vs the research spec, noted per SPEC §2.6: the spec's 4096×2048 equirect
## sky is replaced by the painting itself on the far card (1536×672 ≈ 13 px/deg across the
## opening — Carmack's own bar for UI imagery) with the gradient dome filling the rest of
## the sky; the spec's silhouette mid-card is deferred — the paintings carry their own
## depth, and terrace/water/mist already give four parallax depths. Revisit if the view
## reads flat on the headset.

signal vista_changed(name: String)

const CENTRE := Vector3(0, 0, -1)      # room centre: cards are cylindrical around it
const FAR_R := 55.0
const ORDER: Array[String] = ["coast", "lake", "valley"]

const DEFS := {
	"coast": {
		"tex": "res://vistas/vista-coast.png", "card_top": 12.9,
		"sky_top": Color(0.16, 0.42, 0.78), "sky_horizon": Color(0.62, 0.82, 0.95), "sky_ground": Color(0.05, 0.18, 0.28),
		"fog": Color(0.55, 0.72, 0.85), "ambient_energy": 0.27, "fog_density": 0.012,
		"omni_tint": Color(1.05, 1.0, 0.9), "omni_energy": 1.0,
		"water_y": -1.6, "water_deep": Color(0.02, 0.23, 0.38), "water_spark": Color(0.6, 0.9, 1.0), "water_speed": 1.0,
		"mist": Color(0.85, 0.93, 1.0), "mist_alpha": 0.35, "cloud_tint": Color(1, 1, 1),
	},
	"lake": {
		"tex": "res://vistas/vista-lake.png", "card_top": 12.2,
		"sky_top": Color(0.03, 0.08, 0.22), "sky_horizon": Color(0.35, 0.5, 0.72), "sky_ground": Color(0.02, 0.05, 0.12),
		"fog": Color(0.3, 0.42, 0.6), "ambient_energy": 0.3, "fog_density": 0.02,
		"omni_tint": Color(0.75, 0.85, 1.1), "omni_energy": 0.8,
		"water_y": -0.9, "water_deep": Color(0.03, 0.1, 0.2), "water_spark": Color(0.5, 0.7, 0.95), "water_speed": 0.35,
		"mist": Color(0.75, 0.85, 1.0), "mist_alpha": 0.6, "cloud_tint": Color(0.6, 0.7, 0.9),
	},
	"valley": {
		"tex": "res://vistas/vista-valley.png", "card_top": 15.2,
		"sky_top": Color(0.35, 0.55, 0.8), "sky_horizon": Color(0.95, 0.85, 0.65), "sky_ground": Color(0.08, 0.16, 0.1),
		"fog": Color(0.7, 0.72, 0.6), "ambient_energy": 0.36, "fog_density": 0.015,
		"omni_tint": Color(1.1, 1.0, 0.85), "omni_energy": 0.95,
		"water_y": 999.0, "water_deep": Color(0.02, 0.2, 0.3), "water_spark": Color(0.6, 0.9, 1.0), "water_speed": 1.0,
		"mist": Color(1.0, 0.97, 0.9), "mist_alpha": 0.45, "cloud_tint": Color(1, 0.98, 0.95),
	},
}

var _roots: Dictionary = {}            # name -> Node3D
var _current := "coast"
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _lights: Array = []                # the table's omni rig (re-tinted per vista)
var _light_base: Array = []            # [Color, energy] per light, captured at bind

func _ready() -> void:
	position = CENTRE
	for nm in ORDER:
		var root := _build_vista(nm, DEFS[nm])
		root.visible = nm == _current
		_roots[nm] = root
		add_child(root)

func current() -> String:
	return _current

func cycle() -> String:
	var i := ORDER.find(_current)
	show_vista(ORDER[(i + 1) % ORDER.size()])
	return _current

## The swap: backdrop visibility now, mood (sky/ambient/fog/lights) crossfaded over 0.6 s.
func show_vista(nm: String) -> void:
	if not DEFS.has(nm) or nm == _current:
		return
	_current = nm
	for k in _roots:
		(_roots[k] as Node3D).visible = k == nm
	_apply_mood(DEFS[nm], 0.6)
	vista_changed.emit(nm)

## main hands over the pieces of mood it owns; the first call snaps (no fade at boot).
func bind(env: Environment, lights: Array) -> void:
	_env = env
	if env and env.sky:
		_sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	_lights = lights
	_light_base.clear()
	for l in _lights:
		var o := l as OmniLight3D
		_light_base.append([o.light_color, o.light_energy])
	_apply_mood(DEFS[_current], 0.0)

func _slate(c: Color) -> Color:
	var g := Color(c.get_luminance(), c.get_luminance(), c.get_luminance() * 1.06)
	return c.lerp(g, 0.38)

func _apply_mood(d: Dictionary, dur: float) -> void:
	if _env == null:
		return
	var fog_c: Color = d["fog"]
	var amb_e: float = d["ambient_energy"]
	if dur <= 0.0:
		_env.fog_light_color = fog_c
		_env.fog_density = float(d["fog_density"])
		_env.ambient_light_energy = amb_e
		if _sky_mat:
			# the env sky is never seen directly — it only feeds ambient + reflections, so it
			# carries a desaturated version of the vista (soft sheen, not a blue mirror)
			_sky_mat.sky_top_color = _slate(d["sky_top"])
			_sky_mat.sky_horizon_color = _slate(d["sky_horizon"])
			_sky_mat.ground_horizon_color = _slate(d["sky_horizon"])
			_sky_mat.ground_bottom_color = _slate(d["sky_ground"])
		for i in _lights.size():
			var o := _lights[i] as OmniLight3D
			var base: Array = _light_base[i]
			o.light_color = (base[0] as Color) * (d["omni_tint"] as Color)
			o.light_energy = float(base[1]) * float(d["omni_energy"])
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(_env, "fog_light_color", fog_c, dur)
	tw.tween_property(_env, "fog_density", float(d["fog_density"]), dur)
	tw.tween_property(_env, "ambient_light_energy", amb_e, dur)
	if _sky_mat:
		tw.tween_property(_sky_mat, "sky_top_color", _slate(d["sky_top"]), dur)
		tw.tween_property(_sky_mat, "sky_horizon_color", _slate(d["sky_horizon"]), dur)
		tw.tween_property(_sky_mat, "ground_bottom_color", _slate(d["sky_ground"]), dur)
	for i in _lights.size():
		var o := _lights[i] as OmniLight3D
		var base: Array = _light_base[i]
		tw.tween_property(o, "light_color", (base[0] as Color) * (d["omni_tint"] as Color), dur)
		tw.tween_property(o, "light_energy", float(base[1]) * float(d["omni_energy"]), dur)

# ---------------------------------------------------------------- construction

func _build_vista(nm: String, d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Vista_" + nm
	# sky dome
	var dome := MeshInstance3D.new()
	dome.name = "SkyDome"
	var sm := SphereMesh.new()
	sm.radius = 130.0
	sm.height = 260.0
	sm.radial_segments = 48
	sm.rings = 24
	dome.mesh = sm
	var sky_sh := ShaderMaterial.new()
	sky_sh.shader = preload("res://vista_sky.gdshader")
	sky_sh.set_shader_parameter("top_color", d["sky_top"])
	sky_sh.set_shader_parameter("horizon_color", d["sky_horizon"])
	sky_sh.set_shader_parameter("ground_color", d["sky_ground"])
	dome.material_override = sky_sh
	_seal_vista_node(dome)
	root.add_child(dome)
	# far card: the painting itself
	var top: float = d["card_top"]
	var card := MeshInstance3D.new()
	card.name = "FarCard"
	card.mesh = _card_mesh(FAR_R, 132.0, top - 22.0, top, 32)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.disable_fog = true
	cm.albedo_texture = load(d["tex"]) as Texture2D
	card.material_override = cm
	_seal_vista_node(card)
	root.add_child(card)
	# water (valley has none — its river lives in the painting)
	var wy: float = d["water_y"]
	if wy < 100.0:
		var water := MeshInstance3D.new()
		water.name = "Water"
		var pm := PlaneMesh.new()
		pm.size = Vector2(58.0, 76.0)
		water.mesh = pm
		water.position = Vector3(-36.0, wy, 0.0)
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://vista_water.gdshader")
		wm.set_shader_parameter("deep_color", d["water_deep"])
		wm.set_shader_parameter("spark_color", d["water_spark"])
		wm.set_shader_parameter("speed", d["water_speed"])
		wm.set_shader_parameter("glitter_z", 0.0)
		water.material_override = wm
		_seal_vista_node(water)
		root.add_child(water)
	# mist banks: two thin drifting layers hugging the horizon
	var mist_tex := _mist_texture()
	for i in 2:
		var mist := MeshInstance3D.new()
		mist.name = "Mist%d" % i
		var r := 24.0 + 13.0 * i
		mist.mesh = _card_mesh(r, 104.0, 0.1 + 0.5 * i, 2.3 + 0.5 * i, 24)
		var mm := ShaderMaterial.new()
		mm.shader = preload("res://vista_drift.gdshader")
		mm.set_shader_parameter("tex", mist_tex)
		mm.set_shader_parameter("tint", d["mist"])
		mm.set_shader_parameter("alpha_base", float(d["mist_alpha"]) * (0.8 - 0.25 * i))
		mm.set_shader_parameter("scroll_speed", 0.004 + 0.002 * i)
		mm.set_shader_parameter("pulse_speed", 0.05 + 0.02 * i)
		mist.material_override = mm
		_seal_vista_node(mist)
		root.add_child(mist)
	# cloud band: high, wide, slow — the drift you actually see
	var band := MeshInstance3D.new()
	band.name = "CloudBand"
	band.mesh = _card_mesh(72.0, 116.0, 15.0, 23.0, 24)
	var bm := ShaderMaterial.new()
	bm.shader = preload("res://vista_drift.gdshader")
	bm.set_shader_parameter("tex", _cloud_texture())
	bm.set_shader_parameter("tint", d["cloud_tint"])
	bm.set_shader_parameter("alpha_base", 0.85)
	bm.set_shader_parameter("scroll_speed", 0.0016)
	bm.set_shader_parameter("pulse", 0.0)
	band.material_override = bm
	_seal_vista_node(band)
	root.add_child(band)
	return root

func _seal_vista_node(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2        # visual layer 2 only: other systems never render/collect it

## A cylindrical card centred on the VistaDeck origin, opening toward -X: an arc of
## `arc_deg` around the -X direction, from y0 to y1, UV-mapped so a painting sits upright.
func _card_mesh(radius: float, arc_deg: float, y0: float, y1: float, seg: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var half := deg_to_rad(arc_deg) * 0.5
	for i in seg + 1:
		var a := -half + (2.0 * half) * float(i) / float(seg)
		var p := Vector3(-cos(a), 0, sin(a)) * radius
		verts.append(Vector3(p.x, y0, p.z))
		verts.append(Vector3(p.x, y1, p.z))
		var u := float(i) / float(seg)
		uvs.append(Vector2(u, 1.0))
		uvs.append(Vector2(u, 0.0))
	for i in seg:
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

var _mist_tex: Texture2D
func _mist_texture() -> Texture2D:
	if _mist_tex:
		return _mist_tex
	var w := 512
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var blob := 0.55 + 0.45 * sin(float(x) * 0.021) * sin(float(x) * 0.0073 + 1.7)
		for y in h:
			var v := float(y) / float(h)
			var a := sin(v * PI) ** 2.0 * blob
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_mist_tex = ImageTexture.create_from_image(img)
	return _mist_tex

var _cloud_tex: Texture2D
func _cloud_texture() -> Texture2D:
	if _cloud_tex:
		return _cloud_tex
	var w := 1024
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 90:
		var cx := rng.randi_range(0, w - 1)
		var cy := h / 2 + rng.randi_range(-h / 5, h / 5)
		var r := rng.randi_range(18, 52)
		for x in range(maxi(0, cx - r), mini(w, cx + r)):
			for y in range(maxi(0, cy - r), mini(h, cy + r)):
				var d2 := Vector2(x - cx, (y - cy) * 2.2).length()
				if d2 < r:
					var a := (1.0 - d2 / r) ** 2.0 * 0.16
					var p := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(1, 1, 1, minf(1.0, p.a + a)))
	_cloud_tex = ImageTexture.create_from_image(img)
	return _cloud_tex
