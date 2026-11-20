extends "res://model.gd"
## A model made by the hub's voice-CAD job (brief #11), built at RUNTIME from the downloaded .glb bytes + manifest.
## Same assembly language as the demo bracket (it IS a model.gd): named parts, wireframe-scan materialize over the
## flat schematic, tethered labels, explode, grab/rotate/scale. The glTF is Y-up metres at TRUE size; parts are
## scaled up by display_scale so a 3 in part reads at table size, and every displayed dimension divides it back out.
## Loader promoted from parked/trebuchet-app-20261119/ (GLTFDocument path, flat parts re-parented by name).

const DISPLAY_FIT_M := 0.5          # longest horizontal true dimension is shown at this width on the inset
const SCALE_MIN := 0.25
const SCALE_MAX := 14.0

var manifest := {}
var model_name := "MODEL"
var load_ok := false
var _glb := PackedByteArray()

func setup(glb: PackedByteArray, man: Dictionary) -> void:
	_glb = glb
	manifest = man
	model_name = String(man.get("name", "MODEL"))

func _ready() -> void:
	load_ok = _load_parts()
	super()

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
	return "%s by %s by %s inches" % [_fmt_dec(float(td[0]), 2), _fmt_dec(float(td[1]), 2), _fmt_dec(float(td[2]), 2)]
