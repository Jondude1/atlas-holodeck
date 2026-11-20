class_name MeshBuilder
extends RefCounted
## Collects boxes / cylinders / cones / tori / quads (each with a vertex colour) into ONE ArrayMesh, so any amount
## of static set dressing costs a single draw call per material. Positions are in the owner's local space.
## Vertex colours are 8-bit: HDR glow energy lives in the material's albedo multiplier, hue/intensity in the colour.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _i := PackedInt32Array()

func vertex_count() -> int:
	return _v.size()

func _tri_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv_a := Vector2(0, 0), uv_c := Vector2(1, 1)) -> void:
	var o := _v.size()
	_v.append_array([a, b, c, d])
	_n.append_array([n, n, n, n])
	_c.append_array([col, col, col, col])
	_uv.append_array([Vector2(uv_a.x, uv_c.y), Vector2(uv_c.x, uv_c.y), Vector2(uv_c.x, uv_a.y), Vector2(uv_a.x, uv_a.y)])
	_i.append_array([o, o + 1, o + 2, o, o + 2, o + 3])

## Axis-aligned box rotated by `basis` about its own centre. UVs span each face 0..1.
func add_box(center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), h.x],     # +X: u along -Z .. handled by the corner order below
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), h.x],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), h.y],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), h.y],
		[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0), h.z],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0), h.z],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var up: Vector3 = f[1]
		var right: Vector3 = f[2]
		var d: float = f[3]
		var ext_u := absf(right.x) * h.x + absf(right.y) * h.y + absf(right.z) * h.z
		var ext_v := absf(up.x) * h.x + absf(up.y) * h.y + absf(up.z) * h.z
		var p := n * d
		var a := p - right * ext_u - up * ext_v
		var b := p + right * ext_u - up * ext_v
		var c := p + right * ext_u + up * ext_v
		var e := p - right * ext_u + up * ext_v
		_tri_quad(center + basis * a, center + basis * b, center + basis * c, center + basis * e, (basis * n).normalized(), col)

## Flat rectangle facing `basis` +Z (normal = basis.z), `size` in its local X/Y. UVs: full 0..1, v running down local -Y.
## Corners are emitted clockwise as seen from +Z (Godot's front face).
func add_quad(center: Vector3, size: Vector2, basis: Basis, col: Color) -> void:
	var hx := basis.x * size.x * 0.5
	var hy := basis.y * size.y * 0.5
	var n := basis.z.normalized()
	var o := _v.size()
	_v.append_array([center - hx - hy, center - hx + hy, center + hx + hy, center + hx - hy])
	_n.append_array([n, n, n, n])
	_c.append_array([col, col, col, col])
	_uv.append_array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	_i.append_array([o, o + 1, o + 2, o, o + 2, o + 3])

## Closed cylinder along basis Y, smooth sides.
func add_cyl(center: Vector3, radius: float, height: float, col: Color, seg := 10, basis := Basis.IDENTITY, caps := true) -> void:
	var o := _v.size()
	var hh := height * 0.5
	for k in seg + 1:
		var a := TAU * float(k) / seg
		var dir := Vector3(cos(a), 0, sin(a))
		var n := (basis * dir).normalized()
		_v.append(center + basis * (dir * radius + Vector3(0, hh, 0)))
		_v.append(center + basis * (dir * radius - Vector3(0, hh, 0)))
		_n.append_array([n, n])
		_c.append_array([col, col])
		_uv.append_array([Vector2(float(k) / seg, 0), Vector2(float(k) / seg, 1)])
	for k in seg:
		var i0 := o + k * 2
		_i.append_array([i0, i0 + 1, i0 + 3, i0, i0 + 3, i0 + 2])
	if caps:
		for sgn in [1.0, -1.0]:
			var oc := _v.size()
			var nn := (basis * Vector3(0, sgn, 0)).normalized()
			_v.append(center + basis * Vector3(0, sgn * hh, 0))
			_n.append(nn)
			_c.append(col)
			_uv.append(Vector2(0.5, 0.5))
			for k in seg + 1:
				var a2 := TAU * float(k) / seg
				_v.append(center + basis * Vector3(cos(a2) * radius, sgn * hh, sin(a2) * radius))
				_n.append(nn)
				_c.append(col)
				_uv.append(Vector2(0.5 + cos(a2) * 0.5, 0.5 + sin(a2) * 0.5))
			for k in seg:
				if sgn > 0:
					_i.append_array([oc, oc + 2 + k, oc + 1 + k])
				else:
					_i.append_array([oc, oc + 1 + k, oc + 2 + k])

## Open tapered shaft (light beam): top ring -> bottom ring, UV u around, v 0 at the top .. 1 at the bottom. No caps.
func add_shaft(top: Vector3, r_top: float, bottom: Vector3, r_bottom: float, col: Color, seg := 14) -> void:
	var o := _v.size()
	for k in seg + 1:
		var a := TAU * float(k) / seg
		var dir := Vector3(cos(a), 0, sin(a))
		_v.append(top + dir * r_top)
		_v.append(bottom + dir * r_bottom)
		_n.append_array([dir, dir])
		_c.append_array([col, col])
		_uv.append_array([Vector2(float(k) / seg, 0), Vector2(float(k) / seg, 1)])
	for k in seg:
		var i0 := o + k * 2
		_i.append_array([i0, i0 + 1, i0 + 3, i0, i0 + 3, i0 + 2])

func add_torus(center: Vector3, big_r: float, small_r: float, col: Color, seg := 48, tube_seg := 8, basis := Basis.IDENTITY) -> void:
	var o := _v.size()
	for i in seg + 1:
		var a := TAU * float(i) / seg
		var ring_dir := Vector3(cos(a), 0, sin(a))
		for j in tube_seg + 1:
			var b := TAU * float(j) / tube_seg
			var n := ring_dir * cos(b) + Vector3(0, sin(b), 0)
			_v.append(center + basis * (ring_dir * big_r + n * small_r))
			_n.append((basis * n).normalized())
			_c.append(col)
			_uv.append(Vector2(float(i) / seg, float(j) / tube_seg))
	var stride := tube_seg + 1
	for i in seg:
		for j in tube_seg:
			var a0 := o + i * stride + j
			var a1 := a0 + stride
			_i.append_array([a0, a1, a1 + 1, a0, a1 + 1, a0 + 1])

## A cylinder from point a to point b (cables, pipes, struts).
func add_rod(a: Vector3, b: Vector3, radius: float, col: Color, seg := 8, caps := false) -> void:
	var d := b - a
	var len := d.length()
	if len < 1e-5:
		return
	var y := d / len
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	add_cyl((a + b) * 0.5, radius, len, col, seg, Basis(x, y, z), caps)

func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
