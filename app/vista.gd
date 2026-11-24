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
signal grade_changed(name: String)

const CENTRE := Vector3(0, 0, -1)      # room centre: cards are cylindrical around it
const FAR_R := 55.0
const ORDER: Array[String] = ["coast", "lake", "valley"]

const DEFS := {
	"coast": {
		"tex": "res://vistas/vista-coast.png", "card_top": 15.5,
		"sky_top": Color(0.24, 0.46, 0.72), "sky_horizon": Color(0.68, 0.80, 0.89), "sky_ground": Color(0.06, 0.16, 0.24),
		"fog": Color(0.14, 0.15, 0.17), "ambient_energy": 0.46, "fog_density": 0.006,
		"omni_tint": Color(0.96, 0.98, 1.0), "omni_energy": 1.05,
		"water_y": -4.2, "water_deep": Color(0.03, 0.20, 0.34), "water_spark": Color(0.65, 0.86, 0.95), "water_speed": 0.85,
		"mist": Color(0.84, 0.90, 0.96), "mist_alpha": 0.28, "cloud_tint": Color(0.95, 0.97, 0.99), "boat": true,
		"rock": Color(0.86, 0.89, 0.91), "drop": 9.5, "sea": [0.36, 0.82, 1.0],   # shader UV: v=0 at the TOP of the painting; the sea band is rows .36-.82
	},
	"lake": {
		"tex": "res://vistas/vista-lake.png", "card_top": 14.5,
		"sky_top": Color(0.05, 0.10, 0.22), "sky_horizon": Color(0.36, 0.48, 0.66), "sky_ground": Color(0.02, 0.05, 0.11),
		"fog": Color(0.10, 0.12, 0.15), "ambient_energy": 0.38, "fog_density": 0.007,
		"omni_tint": Color(0.86, 0.92, 1.0), "omni_energy": 0.95,
		"water_y": -3.0, "water_deep": Color(0.03, 0.1, 0.2), "water_spark": Color(0.5, 0.7, 0.95), "water_speed": 0.35,
		"mist": Color(0.75, 0.85, 1.0), "mist_alpha": 0.5, "cloud_tint": Color(0.6, 0.7, 0.9), "boat": true,
		"rock": Color(0.82, 0.86, 0.92), "drop": 7.0, "sea": [0.45, 0.75, 0.5],
	},
	"valley": {
		"tex": "res://vistas/vista-valley.png", "card_top": 15.2,
		"sky_top": Color(0.35, 0.54, 0.76), "sky_horizon": Color(0.90, 0.83, 0.68), "sky_ground": Color(0.08, 0.15, 0.10),
		"fog": Color(0.14, 0.15, 0.14), "ambient_energy": 0.48, "fog_density": 0.006,
		"omni_tint": Color(1.02, 0.98, 0.92), "omni_energy": 1.05,
		"water_y": 999.0, "water_deep": Color(0.02, 0.2, 0.3), "water_spark": Color(0.6, 0.9, 1.0), "water_speed": 1.0,
		"mist": Color(0.96, 0.94, 0.88), "mist_alpha": 0.38, "cloud_tint": Color(0.96, 0.95, 0.92), "boat": false,
		"rock": Color(0.52, 0.56, 0.42), "drop": 8.5, "sea": [0.0, 0.0, 0.0],
	},
}

const GRADE_ORDER: Array[String] = ["day", "golden", "dusk"]
const GRADES := {
	"day": {"card": Color(0.88, 0.90, 0.91), "sky": Color(0.90, 0.92, 0.94), "fog": Color(1, 1, 1), "amb_mul": 1.0, "omni_mul": 1.0, "vol": -26.0, "pitch": 1.0},
	"golden": {"card": Color(1.04, 0.84, 0.64), "sky": Color(1.06, 0.80, 0.55), "fog": Color(1.12, 0.94, 0.74), "amb_mul": 0.8, "omni_mul": 0.9, "vol": -28.0, "pitch": 0.97},
	"dusk": {"card": Color(0.50, 0.48, 0.64), "sky": Color(0.46, 0.44, 0.68), "fog": Color(0.6, 0.55, 0.78), "amb_mul": 0.45, "omni_mul": 0.68, "vol": -31.0, "pitch": 0.93},
}
const TEX_GULL: Texture2D = preload("res://textures/gull.png")
const TEX_BOAT: Texture2D = preload("res://textures/boat.png")
const TEX_ROCK: Texture2D = preload("res://textures/cliff-rock.png")
const TEX_OCEAN: Texture2D = preload("res://textures/ocean-surface.png")
const CARD_SHADER: Shader = preload("res://vista_card.gdshader")
const LIFE_SHADER: Shader = preload("res://vista_life.gdshader")

var _roots: Dictionary = {}            # name -> Node3D
var _cards: Dictionary = {}            # name -> far-card material (grade tint target)
var _domes: Dictionary = {}            # name -> sky dome material (grade tint target)
var _rocks: Dictionary = {}            # name -> headland material (grade tint target)
var _grade := "day"
var _amb: AudioStreamPlayer
var _amb_streams: Dictionary = {}
var _mood_tw: Tween = null   # R4-7: one mood tween at a time — a vista/grade change kills the previous one
var _amb_tw: Tween = null    # R4-7: same discipline for the ambience volume
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
	# R7-2: the vista's own soundscape — synthesized loops (ocean / lake / wind),
	# swapped and re-graded with the view. Non-positional: it is the world's air.
	_amb = AudioStreamPlayer.new()
	_amb.name = "Ambience"
	add_child(_amb)
	for nm in ORDER:
		var st := load("res://sounds/amb-" + nm + ".wav") as AudioStreamWAV
		if st:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = st.data.size() / 2   # 16-bit mono frames
			_amb_streams[nm] = st
	_amb.stream = _amb_streams.get(_current)
	_amb.volume_db = -26.0
	if _amb.stream:
		_amb.play()

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
	_apply_grade_statics(nm)
	_apply_mood(DEFS[nm], 0.6)
	_apply_ambience(0.6)
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
	_apply_grade_statics(_current)
	_apply_mood(DEFS[_current], 0.0)
	_apply_ambience(0.0)

func grade() -> String:
	return _grade

func cycle_grade() -> String:
	var i := GRADE_ORDER.find(_grade)
	_grade = GRADE_ORDER[(i + 1) % GRADE_ORDER.size()]
	for nm in ORDER:
		_apply_grade_statics(nm)
	_apply_mood(DEFS[_current], 0.6)
	_apply_ambience(0.6)
	grade_changed.emit(_grade)
	return _grade

## The grade's static half: the painting's tint and the sky dome's colours.
## (The mood half — fog, ambient, rig lights — lives in _apply_mood.)
func _apply_grade_statics(nm: String) -> void:
	var g: Dictionary = GRADES[_grade]
	var d: Dictionary = DEFS[nm]
	if _cards.has(nm):
		(_cards[nm] as ShaderMaterial).set_shader_parameter("tint", g["card"])
	if _rocks.has(nm):
		(_rocks[nm] as StandardMaterial3D).albedo_color = (d["rock"] as Color) * (g["card"] as Color)
	if _domes.has(nm):
		var sm := _domes[nm] as ShaderMaterial
		sm.set_shader_parameter("top_color", (d["sky_top"] as Color) * (g["sky"] as Color))
		sm.set_shader_parameter("horizon_color", (d["sky_horizon"] as Color) * (g["sky"] as Color))
		sm.set_shader_parameter("ground_color", (d["sky_ground"] as Color) * (g["sky"] as Color))

func _apply_ambience(dur: float) -> void:
	if _amb == null:
		return
	var g: Dictionary = GRADES[_grade]
	var target: AudioStream = _amb_streams.get(_current)
	if target == null:
		return
	_amb.pitch_scale = float(g["pitch"])
	if _amb.stream == target and _amb.playing:
		if dur > 0.0:
			_amb_to(float(g["vol"]), dur)
		else:
			_amb.volume_db = float(g["vol"])
		return
	_amb.volume_db = -42.0
	_amb.stream = target
	_amb.play()
	_amb_to(float(g["vol"]), maxf(0.3, dur))

## R4-7: the only ambience-volume tween — a new fade kills the one before it.
func _amb_to(vol: float, dur: float) -> void:
	if _amb_tw and _amb_tw.is_valid():
		_amb_tw.kill()
	_amb_tw = create_tween()
	_amb_tw.tween_property(_amb, "volume_db", vol, dur)

## R8 polish: neutral-charcoal reflection/ambient slate — keeps the polished floor
## and dark titanium reflecting readable charcoal daylight instead of blue or black.
func _slate(c: Color) -> Color:
	var lum := c.get_luminance()
	var g := Color(lum, lum, lum * 1.02)
	return c.lerp(g, 0.86) * 0.88

func _apply_mood(d: Dictionary, dur: float) -> void:
	if _env == null:
		return
	var g: Dictionary = GRADES[_grade]
	var fog_c: Color = (d["fog"] as Color) * (g["fog"] as Color)
	var amb_e: float = float(d["ambient_energy"]) * float(g["amb_mul"])
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
			o.light_color = (base[0] as Color) * (d["omni_tint"] as Color) * (g["fog"] as Color)
			o.light_energy = float(base[1]) * float(d["omni_energy"]) * float(g["omni_mul"])
		return
	if _mood_tw and _mood_tw.is_valid():
		_mood_tw.kill()
	var tw := create_tween().set_parallel()
	_mood_tw = tw
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
		tw.tween_property(o, "light_color", (base[0] as Color) * (d["omni_tint"] as Color) * (g["fog"] as Color), dur)
		tw.tween_property(o, "light_energy", float(base[1]) * float(d["omni_energy"]) * float(g["omni_mul"]), dur)

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
	_domes[nm] = sky_sh
	_seal_vista_node(dome)
	root.add_child(dome)
	# far card: the painting itself
	var top: float = d["card_top"]
	var card := MeshInstance3D.new()
	card.name = "FarCard"
	card.mesh = _card_mesh(FAR_R, 132.0, top - 22.0, top, 32)
	var cm := ShaderMaterial.new()
	cm.shader = CARD_SHADER
	cm.set_shader_parameter("tex", load(d["tex"]) as Texture2D)
	var sea: Array = d["sea"]
	cm.set_shader_parameter("sea_lo", sea[0])
	cm.set_shader_parameter("sea_hi", sea[1])
	cm.set_shader_parameter("sway", sea[2])
	card.material_override = cm
	_cards[nm] = cm
	_seal_vista_node(card)
	root.add_child(card)
	# water (valley has none — its river lives in the painting)
	var wy: float = d["water_y"]
	if wy < 100.0:
		var water := MeshInstance3D.new()
		water.name = "Water"
		var pm := PlaneMesh.new()
		pm.size = Vector2(58.0, 76.0)
		pm.subdivide_width = 48   # R7-6: the swell needs vertices to move
		pm.subdivide_depth = 48
		water.mesh = pm
		water.position = Vector3(-36.0, wy, 0.0)
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://vista_water.gdshader")
		wm.set_shader_parameter("deep_color", d["water_deep"])
		wm.set_shader_parameter("spark_color", d["water_spark"])
		wm.set_shader_parameter("speed", d["water_speed"])
		wm.set_shader_parameter("tex", TEX_OCEAN)
		wm.set_shader_parameter("glitter_z", 0.0)
		water.material_override = wm
		_seal_vista_node(water)
		root.add_child(water)
	# R7-6 headland (Jon): the terrace stands on a real point of rock — a noise-
	# displaced cliff skirt dropping from under the terrace into the sea, so the
	# balcony has somewhere to look DOWN at, and the point wraps both ways.
	var head := MeshInstance3D.new()
	head.name = "Headland"
	head.mesh = _headland_mesh(d)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.disable_fog = true
	hm.vertex_color_use_as_albedo = true
	hm.albedo_texture = TEX_ROCK
	hm.texture_repeat = true
	hm.albedo_color = d["rock"]
	head.material_override = hm
	_rocks[nm] = hm
	_seal_vista_node(head)
	root.add_child(head)
	if wy < 100.0:
		# foam collar: a wash band hugging the cliff base, forever scrolling ashore
		var foam := MeshInstance3D.new()
		foam.name = "Foam"
		foam.mesh = _foam_mesh()
		foam.position = Vector3(0, wy + 0.06, 0)
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://vista_drift.gdshader")
		fm.set_shader_parameter("tex", _foam_texture())
		fm.set_shader_parameter("tint", Color(0.95, 0.99, 1.0))
		fm.set_shader_parameter("alpha_base", 0.55)
		fm.set_shader_parameter("scroll_speed", 0.045)
		fm.set_shader_parameter("pulse", 0.25)
		fm.set_shader_parameter("pulse_speed", 0.11)
		foam.material_override = fm
		_seal_vista_node(foam)
		root.add_child(foam)
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
	# R7-2 life: a small flock working the wind + (on the water vistas) one boat
	# crossing the horizon — both pure vertex-shader motion, one draw call each.
	var gulls := MeshInstance3D.new()
	gulls.name = "Gulls"
	gulls.mesh = _gulls_mesh()
	var gm := ShaderMaterial.new()
	gm.shader = LIFE_SHADER
	gm.set_shader_parameter("tex", TEX_GULL)
	gm.set_shader_parameter("mode", 0.0)
	gulls.material_override = gm
	_seal_vista_node(gulls)
	root.add_child(gulls)
	if bool(d.get("boat", false)):
		var boat := MeshInstance3D.new()
		boat.name = "Boat"
		boat.mesh = _boat_mesh()
		boat.position = Vector3(-52.5, wy + 1.32, 0.0)
		var bom := ShaderMaterial.new()
		bom.shader = LIFE_SHADER
		bom.set_shader_parameter("tex", TEX_BOAT)
		bom.set_shader_parameter("mode", 1.0)
		bom.set_shader_parameter("tint", Color(0.1, 0.12, 0.16, 1.0))
		boat.material_override = bom
		_seal_vista_node(boat)
		root.add_child(boat)
	return root

## Five gull sprites on individual orbits, encoded per-vertex (COLOR = phase /
## radius / flap jitter). Quads stand in the YZ plane facing the room (+X local).
func _gulls_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var bases := [Vector3(-52, 9.5, -6), Vector3(-49, 10.5, 4), Vector3(-56, 8.8, 8), Vector3(-47, 11.0, -12), Vector3(-54, 10.0, -16)]   # far back (Jon): specks on the horizon, not visitors
	var w := 0.85
	var h := 0.82
	for gi in bases.size():
		var b: Vector3 = bases[gi]
		var enc := Color(float(gi) / float(bases.size()), float(gi % 3) / 2.0, float((gi * 7) % 5) / 4.0, 1.0)
		var base := verts.size()
		verts.append_array([b + Vector3(0, -h, -w), b + Vector3(0, -h, w), b + Vector3(0, h, w), b + Vector3(0, h, -w)])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		for k in 4:
			cols.append(enc)
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _boat_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var w := 1.9
	var h := 1.55
	verts.append_array([Vector3(0, -h, -w), Vector3(0, -h, w), Vector3(0, h, w), Vector3(0, h, -w)])
	uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	for k in 4:
		cols.append(Color(0.35, 0, 0, 1))
	idx.append_array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The headland heightfield (deck-local: the terrace occupies x -7.3..-4, so the
## skirt starts tucked under it at -6.9 and runs out to -21; z spans past the
## room both ways and the point falls off into the sea beyond |z| 9.
func _headland_mesh(d: Dictionary) -> ArrayMesh:
	var drop: float = d["drop"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := [0.0, 0.02, 0.05, 0.09, 0.14, 0.2, 0.27, 0.35, 0.44, 0.54, 0.65, 0.77, 0.9, 1.0]
	var cols := 30
	var pts: Array = []
	for ri in rows.size():
		var sf: float = rows[ri]
		var lx := -6.9 - sf * 14.1
		var row: Array = []
		for ci in cols + 1:
			var lz := -15.0 + 30.0 * float(ci) / float(cols)
			var fall := 1.0 - smoothstep(9.0, 15.0, absf(lz)) * 0.85
			var y := -0.12 - drop * pow(sf, 1.15) * fall   # apron profile: a rocky slope you can READ from above, not a plumb drop that hides under the railing
			var amp := 0.55 * pow(sin(PI * clampf(sf, 0.0, 1.0)), 0.7) * smoothstep(0.03, 0.25, sf)   # smooth lip where it tucks under the balcony
			var n := sin(lx * 1.7 + lz * 2.3) * 0.5 + sin(lx * 0.6 - lz * 1.1) * 0.35 + sin((lx + lz) * 3.1) * 0.15
			y += n * amp
			y = lerpf(y, roundf(y / 0.55) * 0.55, 0.30 * clampf(amp * 2.0, 0.0, 1.0))
			if ri == 0:
				y = -0.12
			row.append(Vector3(lx, y, lz))
		pts.append(row)
	for ri in rows.size() - 1:
		for ci in cols:
			_head_quad(st, pts[ri][ci], pts[ri][ci + 1], pts[ri + 1][ci + 1], pts[ri + 1][ci])
	st.generate_normals()
	return st.commit()

func _head_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, e: Vector3) -> void:
	for v in [a, b, c, a, c, e]:
		var wet := smoothstep(-3.5, -0.2, v.y)
		st.set_color(Color(0.45, 0.5, 0.52).lerp(Color(1, 1, 1), wet))
		st.set_uv(Vector2(v.z * 0.13, -v.y * 0.22))
		st.add_vertex(v)

## A flat wash band at the waterline (positioned at wy + 0.06 by the caller).
## u runs 0 at the cliff foot -> 1 out at sea, so the drift shader's scroll
## walks the foam ASHORE; v tiles the streaks along the coast.
func _foam_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-11.2, -12.6, -14.0, -15.6]   # centred where the apron meets the water
	var cols := 20
	for ri in xs.size() - 1:
		for ci in cols:
			var z0 := -13.0 + 26.0 * float(ci) / float(cols)
			var z1 := -13.0 + 26.0 * float(ci + 1) / float(cols)
			var u0: float = (-11.2 - xs[ri]) / 4.4
			var u1: float = (-11.2 - xs[ri + 1]) / 4.4
			var v0 := float(ci) / float(cols) * 5.0
			var v1 := float(ci + 1) / float(cols) * 5.0
			var a := Vector3(xs[ri], 0, z0)
			var b := Vector3(xs[ri], 0, z1)
			var c := Vector3(xs[ri + 1], 0, z1)
			var e := Vector3(xs[ri + 1], 0, z0)
			var uvs := {a: Vector2(u0, v0), b: Vector2(u0, v1), c: Vector2(u1, v1), e: Vector2(u1, v0)}
			for vtx in [a, b, c, a, c, e]:
				st.set_uv(uvs[vtx])
				st.add_vertex(vtx)
	return st.commit()

var _foam_tex: Texture2D = null

## Streaky foam alpha: stretched soft blobs, edges faded in the texture itself so
## the wash band melts into the water at both borders.
func _foam_texture() -> Texture2D:
	if _foam_tex:
		return _foam_tex
	var w := 512
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 130:
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, h - 1)
		var rx := rng.randi_range(16, 54)
		var ry := maxi(3, rx / rng.randi_range(4, 7))
		for x in range(maxi(0, cx - rx), mini(w, cx + rx)):
			for y in range(maxi(0, cy - ry), mini(h, cy + ry)):
				var dd := Vector2(float(x - cx) / float(rx), float(y - cy) / float(ry)).length()
				if dd < 1.0:
					var p := img.get_pixel(x, y)
					p.a = minf(1.0, p.a + (1.0 - dd) * 0.5)
					img.set_pixel(x, y, p)
	for x in w:
		for y in h:
			var p := img.get_pixel(x, y)
			var fx := sin(PI * float(x) / float(w))
			var fy := sin(PI * float(y) / float(h))
			p.a *= pow(fx, 0.7) * pow(fy, 0.5)
			img.set_pixel(x, y, p)
	_foam_tex = ImageTexture.create_from_image(img)
	return _foam_tex

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
