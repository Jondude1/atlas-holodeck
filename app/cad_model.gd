extends "res://model.gd"
## A model made by the hub's voice-CAD job (brief #11), built at RUNTIME from the downloaded .glb bytes + manifest.
## Same assembly language as the demo bracket (it IS a model.gd): named parts, wireframe-scan materialize over the
## flat schematic, tethered labels, explode, grab/rotate/scale. The glTF is Y-up metres at TRUE size; parts are
## scaled up by display_scale so a 3 in part reads at table size, and every displayed dimension divides it back out.
## Loader promoted from parked/trebuchet-app-20261119/ (GLTFDocument path, flat parts re-parented by name).

const DISPLAY_FIT_M := 0.96         # Round A: largest clean fit. 1.4 was tried — a model's long axis can lie
                                    # across the table's DEPTH (the destroyer's does), and at 1.4 its volume
                                    # overhangs the slab front/back (1.40 vs the 1.22 slab / 1.0 inset).
                                    # 0.96 keeps the volume, dim labels and silhouette inside the inset.
const SCALE_MIN := 0.25
const SCALE_MAX := 14.0
# Round A: hero hologram rings (the reference picture's thin rings around the hero).
const HeroRing := preload("res://hero_ring.gd")
const RING_UNDER_R := 0.62    # flat under-ring radius, × the footprint's bounding radius
const RING_ORBIT_R := 1.18    # tilted ring radius, × the same bounding radius
const RING_TILT_DEG := 18.0

var world_solid := false   # R5B: true while this model lives in the world as a solid object
var manifest := {}
var model_name := "MODEL"
var load_ok := false
var _glb := PackedByteArray()
var _ring_root: Node3D     # Round A: hero rings (children, so they follow grab/park/solidify)
var _rings_shown := false  # mirrors the model's materialize state; park() hides on top of it

func setup(glb: PackedByteArray, man: Dictionary) -> void:
	_glb = glb
	manifest = man
	model_name = String(man.get("name", "MODEL"))

func _ready() -> void:
	load_ok = _load_parts()
	super()
	_build_hero_rings()

## Round A (hero presence, per the North Star reference): two thin hologram rings
## around the active model — one flat just under the hull, one larger, tilted 18°,
## counter-rotating slowly (5.0 / -3.5 deg/s). Built AFTER super() so the rings
## never land in _parts/_bounds. They share the parts' mesh hologram material
## (instance params pin them to the resolved state) and cost 2 draw calls.
func _build_hero_rings() -> void:
	if _parts.is_empty():
		return
	var c := _bounds.get_center()
	var half_diag := 0.5 * Vector2(_bounds.size.x, _bounds.size.z).length()
	if half_diag < 0.02:
		return
	_ring_root = Node3D.new()
	_ring_root.name = "HeroRings"
	_ring_root.visible = false
	add_child(_ring_root)
	var flat := HeroRing.new()
	flat.name = "RingPivotFlat"
	flat.speed_deg = 5.0
	flat.position = Vector3(c.x, 0.0, c.z)
	_ring_root.add_child(flat)
	var under := _ring_mesh("RingUnder", half_diag * RING_UNDER_R, 0.60)
	under.position.y = _bounds.position.y + 0.005
	flat.add_child(under)
	var orbit := HeroRing.new()
	orbit.name = "RingPivotOrbit"
	orbit.speed_deg = -3.5
	# pivot high enough that the tilted ring's low arc never dips under the model's base plane
	orbit.position = Vector3(c.x, _bounds.position.y + half_diag * RING_ORBIT_R * sin(deg_to_rad(RING_TILT_DEG)) + 0.012, c.z)
	_ring_root.add_child(orbit)
	var orb := _ring_mesh("RingOrbit", half_diag * RING_ORBIT_R, 0.42)
	orb.rotation_degrees.x = RING_TILT_DEG
	orbit.add_child(orb)

func _ring_mesh(nm: String, radius: float, alpha_wire: float) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.0045
	tm.outer_radius = radius + 0.0045
	tm.rings = 72
	tm.ring_segments = 10
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = Fx.mesh_part_material()
	mi.set_instance_shader_parameter(&"wire", alpha_wire)
	mi.set_instance_shader_parameter(&"scan", 1.2)
	mi.set_instance_shader_parameter(&"y0", 0.0)
	mi.set_instance_shader_parameter(&"y1", 3.0)
	mi.set_instance_shader_parameter(&"flash", 0.0)
	return mi

## Ring visibility rides the model's own state: shown by materialize/_set_state,
## hidden while parked (the bench's resting state), back on unpark.
func _set_state(shown: bool, scan: float, flash_v: float, wire: float) -> void:
	super(shown, scan, flash_v, wire)
	_rings_shown = shown
	_apply_rings()

func park(to: Vector3, s := 0.55) -> void:
	super(to, s)
	_apply_rings()

func unpark() -> void:
	super()
	_apply_rings()

func _apply_rings() -> void:
	if _ring_root:
		_ring_root.visible = _rings_shown and not _parked

func _make_material(_p: MeshInstance3D) -> ShaderMaterial:
	return Fx.mesh_part_material()

func _load_parts() -> bool:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_buffer(_glb, "", st) != OK:
		push_warning("voice-CAD: glb did not parse")
		return false
	var inst := doc.generate_scene(st)
	if inst == null:
		return false
	var found := {}
	_collect_meshes(inst, found)
	var td: Array = manifest.get("true_dims_in", [4.0, 4.0, 4.0])
	var longest_m := maxf(float(td[0]), float(td[1])) * 0.0254
	display_scale = clampf(DISPLAY_FIT_M / maxf(longest_m, 0.001), SCALE_MIN, SCALE_MAX)
	var n_ok := 0
	var mparts: Array = manifest.get("parts", [])
	# Imported single-mesh files (STL conversions) may carry a generic node name inside the GLB:
	# a one-part manifest adopts the GLB's only mesh whatever it is called.
	var only_mesh: MeshInstance3D = null
	if mparts.size() == 1 and found.size() == 1:
		only_mesh = found.values()[0]
	for part in mparts:
		var nm: String = part["name"]
		if not found.has(nm) and only_mesh == null:
			push_warning("voice-CAD: glb is missing manifest part " + nm)
			continue
		var mi: MeshInstance3D = found[nm] if found.has(nm) else only_mesh
		var xf := _rel_xf(mi, inst)
		mi.get_parent().remove_child(mi)
		mi.owner = null
		add_child(mi)
		mi.name = nm
		mi.transform = Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * display_scale), xf.origin * display_scale)
		n_ok += 1
	inst.free()
	return n_ok > 0

func _rel_xf(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _collect_meshes(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D:
		out[String(n.name)] = n
	for c in n.get_children():
		_collect_meshes(c, out)

## "3 by 2.6 by 3.14 inches" for speech: decimal inches, X length by Y depth by Z height of the real part.
func spoken_dims() -> String:
	var td: Array = manifest.get("true_dims_in", [])
	if td.size() < 3:
		return ""
	return "%s by %s by %s inches" % [Units.dec(float(td[0]), 2), Units.dec(float(td[1]), 2), Units.dec(float(td[2]), 2)]
