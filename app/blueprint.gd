class_name Blueprint
## Generated flat schematic for the table layer: top-down footprint outline, bolt-pattern
## suggestion, dimension lines with end ticks. Drawn 2x supersampled, shipped at 512x512.
## Image up = -Z (the quad lies on the table with its texture top pointing away from the player).

const SIZE := 512
const SS := 2
## Brief #16 R1-12: the real part outline replaces the bounding box + fake bolt pattern. `legacy` brings the old layer back
## (capture / comparison tooling only; nothing in the app sets it).
static var legacy := false
const MASK_PX := 768             # silhouette raster resolution: the schematic quad is shown at this many pixels square
const HOLE_MIN_PX := 12          # an enclosed empty region smaller than this many pixels is noise, not a hole

static func make(footprint: Rect2, quad_m: float) -> ImageTexture:
	var n := SIZE * SS
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA))
	var ppm := n / quad_m
	var c := Vector2(n, n) * 0.5
	var line := Tokens.a(Tokens.HOLO_LINE, 0.95)
	var dim := Tokens.a(Tokens.HOLO_LINE, 0.7)
	var faint := Tokens.a(Tokens.GRID_MINOR, 0.9)
	var w := 2 * SS

	_rect(img, Rect2(Vector2.ZERO, Vector2(n, n)).grow(-6 * SS), faint, SS)  # border frame
	var f := Rect2(c + footprint.position * ppm, footprint.size * ppm)
	_rect(img, f, line, w)
	# bolt pattern: four holes inset from the corners + a dashed pitch circle
	var inset := 0.025 * ppm
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var hc := f.get_center() + Vector2(sx * (f.size.x * 0.5 - inset), sy * (f.size.y * 0.5 - inset))
			_circle(img, hc, 0.008 * ppm, line, SS * 2, 0)
	_circle(img, f.get_center(), 0.05 * ppm, dim, SS * 2, 24)
	# dimension lines: width below the footprint, depth to its right, with end ticks
	var off := 0.035 * ppm
	var tick := 0.012 * ppm
	var yb := f.end.y + off
	_line(img, Vector2(f.position.x, f.end.y + 6 * SS), Vector2(f.position.x, yb + tick), dim, SS * 2)
	_line(img, Vector2(f.end.x, f.end.y + 6 * SS), Vector2(f.end.x, yb + tick), dim, SS * 2)
	_line(img, Vector2(f.position.x, yb), Vector2(f.end.x, yb), line, w)
	var xr := f.end.x + off
	_line(img, Vector2(f.end.x + 6 * SS, f.position.y), Vector2(xr + tick, f.position.y), dim, SS * 2)
	_line(img, Vector2(f.end.x + 6 * SS, f.end.y), Vector2(xr + tick, f.end.y), dim, SS * 2)
	_line(img, Vector2(xr, f.position.y), Vector2(xr, f.end.y), line, w)
	for e in [f.position.x, f.end.x]:
		_line(img, Vector2(e, yb - tick * 0.6), Vector2(e, yb + tick * 0.6), line, w)
	for e in [f.position.y, f.end.y]:
		_line(img, Vector2(xr - tick * 0.6, e), Vector2(xr + tick * 0.6, e), line, w)

	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## The REAL top-down silhouette of an assembly (union of every part's projected triangles in the model's XZ plane) with the
## actual through-holes found in it (empty regions enclosed by the silhouette), a section hatch, and the dimension lines.
## `parts` are the model's MeshInstance3D children (assembled, so their node transforms place the geometry);
## `footprint` is the XZ bounds in model space; the quad is centred on the footprint centre. Image up = -Z.
## Multi-part models get the assembly footprint (the union); holes show where the stack of parts is open all the way
## through. Holes whose axis is not vertical (a screw hole through a wall) are not visible from above and not drawn.
static func make_silhouette(parts: Array, footprint: Rect2, quad_m: float) -> ImageTexture:
	var n := MASK_PX
	var ppm := n / quad_m
	var ctr := footprint.get_center()
	var mask := PackedByteArray()
	mask.resize(n * n)
	var tris := 0
	var x_lo := n
	var x_hi := -1
	var y_lo := n
	var y_hi := -1
	for p in parts:
		var mi := p as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := Transform3D(mi.basis, mi.position)
		var f := mi.mesh.get_faces()
		var pts := PackedVector2Array()
		pts.resize(f.size())
		for i in f.size():
			var w: Vector3 = xf * f[i]
			pts[i] = Vector2(n * 0.5 + (w.x - ctr.x) * ppm, n * 0.5 + (w.z - ctr.y) * ppm)
		for t in range(0, f.size() - 2, 3):
			var a := pts[t]
			var b := pts[t + 1]
			var c := pts[t + 2]
			if absf((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 1e-4:
				continue                                 # vertical wall: no area from above
			tris += 1
			var r := _fill_tri(mask, n, a, b, c)
			if r.size.x >= 0:
				x_lo = mini(x_lo, int(r.position.x))
				y_lo = mini(y_lo, int(r.position.y))
				x_hi = maxi(x_hi, int(r.end.x))
				y_hi = maxi(y_hi, int(r.end.y))
	if tris == 0 or x_hi < x_lo:
		return make(footprint, quad_m)                  # nothing to project: fall back to the plain footprint layer
	# work inside the silhouette's bbox (+ margin) only: a small part must not cost a full-image pass
	var bx0 := maxi(x_lo - 3, 0)
	var by0 := maxi(y_lo - 3, 0)
	var bx1 := mini(x_hi + 3, n - 1)
	var by1 := mini(y_hi + 3, n - 1)
	# 1. outside = empty pixels connected to the bbox border; enclosed empty regions are holes
	var outside := PackedByteArray()
	outside.resize(n * n)
	var stack := PackedInt32Array()
	for x in range(bx0, bx1 + 1):
		for y in [by0, by1]:
			if mask[y * n + x] == 0 and outside[y * n + x] == 0:
				outside[y * n + x] = 1
				stack.append(y * n + x)
	for y in range(by0, by1 + 1):
		for x in [bx0, bx1]:
			if mask[y * n + x] == 0 and outside[y * n + x] == 0:
				outside[y * n + x] = 1
				stack.append(y * n + x)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % n
		var y := i / n
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < bx0 or nx > bx1 or ny < by0 or ny > by1:
				continue
			var j: int = ny * n + nx
			if mask[j] == 0 and outside[j] == 0:
				outside[j] = 1
				stack.append(j)
	# 2. label the enclosed regions -> centre, size, roundness
	var seen := PackedByteArray()
	seen.resize(n * n)
	var holes: Array[Dictionary] = []
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			var i := y * n + x
			if mask[i] != 0 or outside[i] != 0 or seen[i] != 0:
				continue
			var area := 0
			var sx := 0.0
			var sy := 0.0
			var mnx := x
			var mxx := x
			var mny := y
			var mxy := y
			seen[i] = 1
			stack.append(i)
			while not stack.is_empty():
				var k: int = stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				var kx := k % n
				var ky := k / n
				area += 1
				sx += kx
				sy += ky
				mnx = mini(mnx, kx)
				mxx = maxi(mxx, kx)
				mny = mini(mny, ky)
				mxy = maxi(mxy, ky)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var j: int = (ky + d.y) * n + kx + d.x
					if mask[j] == 0 and outside[j] == 0 and seen[j] == 0:
						seen[j] = 1
						stack.append(j)
			if area >= HOLE_MIN_PX:
				var bw := mxx - mnx + 1
				var bh := mxy - mny + 1
				var round_ok := absf(float(bw) / bh - 1.0) < 0.3 and absf(area / (float(bw) * bh) - PI / 4.0) < 0.15
				holes.append({"c": Vector2(sx / area, sy / area), "r": sqrt(area / PI), "round": round_ok, "area": area})
	# 3. compose the RGBA image: panel fill, faint section hatch inside, outline (outer + holes), hole centre marks
	var base := Tokens.a(Tokens.HOLO_DEEP, Tokens.PANEL_ALPHA)
	var line := Tokens.a(Tokens.HOLO_LINE, 0.95)
	var hatch := Tokens.a(Tokens.HOLO_LINE, 0.22)
	var wash := Tokens.a(Tokens.HOLO_PRIMARY, 0.16)
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var bb := PackedByteArray([base.r8, base.g8, base.b8, base.a8])
	for i in n * n:
		data[i * 4] = bb[0]
		data[i * 4 + 1] = bb[1]
		data[i * 4 + 2] = bb[2]
		data[i * 4 + 3] = bb[3]
	var step_h := 14
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			var i := y * n + x
			if mask[i] == 0:
				continue
			var col := hatch if (x + y) % step_h < 2 else wash
			var o := i * 4
			data[o] = col.r8
			data[o + 1] = col.g8
			data[o + 2] = col.b8
			data[o + 3] = col.a8
	for y in range(by0, by1 + 1):                      # outline: a solid pixel with an empty 4-neighbour (outer edge + hole edges)
		for x in range(bx0, bx1 + 1):
			var i := y * n + x
			if mask[i] == 0:
				continue
			if mask[i - 1] == 0 or mask[i + 1] == 0 or mask[i - n] == 0 or mask[i + n] == 0:
				_put(data, n, x, y, line, 1)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var sc := n / 512.0
	var dim := Tokens.a(Tokens.HOLO_LINE, 0.7)
	for h in holes:
		if h["round"]:
			var c: Vector2 = h["c"]
			var rr: float = h["r"] + 5.0 * sc
			_line(img, c + Vector2(-rr, 0), c + Vector2(rr, 0), dim, 1)
			_line(img, c + Vector2(0, -rr), c + Vector2(0, rr), dim, 1)
	# dimension lines on the silhouette's own extent (same language as the legacy layer)
	var f := Rect2(Vector2(x_lo, y_lo), Vector2(x_hi - x_lo + 1, y_hi - y_lo + 1))
	var off := 0.035 * ppm
	var tick := 0.012 * ppm
	var w := 2
	var yb := f.end.y + off
	_line(img, Vector2(f.position.x, f.end.y + 6 * sc), Vector2(f.position.x, yb + tick), dim, w)
	_line(img, Vector2(f.end.x, f.end.y + 6 * sc), Vector2(f.end.x, yb + tick), dim, w)
	_line(img, Vector2(f.position.x, yb), Vector2(f.end.x, yb), line, w)
	var xr := f.end.x + off
	_line(img, Vector2(f.end.x + 6 * sc, f.position.y), Vector2(xr + tick, f.position.y), dim, w)
	_line(img, Vector2(f.end.x + 6 * sc, f.end.y), Vector2(xr + tick, f.end.y), dim, w)
	_line(img, Vector2(xr, f.position.y), Vector2(xr, f.end.y), line, w)
	for e in [f.position.x, f.end.x]:
		_line(img, Vector2(e, yb - tick * 0.6), Vector2(e, yb + tick * 0.6), line, w)
	for e in [f.position.y, f.end.y]:
		_line(img, Vector2(xr - tick * 0.6, e), Vector2(xr + tick * 0.6, e), line, w)
	var frame := Rect2(Vector2.ZERO, Vector2(n, n)).grow(-6 * sc)
	_rect(img, frame, Tokens.a(Tokens.GRID_MINOR, 0.9), 1)
	img.generate_mipmaps()
	last_holes = holes
	return ImageTexture.create_from_image(img)

## Hole list of the most recent make_silhouette (tests/tooling read it): [{c: px, r: px, round: bool, area: px}].
static var last_holes: Array[Dictionary] = []

static func _put(data: PackedByteArray, n: int, x: int, y: int, col: Color, grow: int) -> void:
	for dy in range(-grow, grow + 1):
		for dx in range(-grow, grow + 1):
			var xx := x + dx
			var yy := y + dy
			if xx < 0 or yy < 0 or xx >= n or yy >= n:
				continue
			var o := (yy * n + xx) * 4
			data[o] = col.r8
			data[o + 1] = col.g8
			data[o + 2] = col.b8
			data[o + 3] = col.a8

## Scanline-fills one triangle (pixel-centre sampling: shared edges leave no cracks) into `mask`; returns the touched rect
## (size.x < 0 when nothing was covered).
static func _fill_tri(mask: PackedByteArray, n: int, a: Vector2, b: Vector2, c: Vector2) -> Rect2i:
	var y0 := maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
	var y1 := mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), n - 1)
	var tx0 := n
	var tx1 := -1
	var ty0 := n
	var ty1 := -1
	for y in range(y0, y1 + 1):
		var yc := y + 0.5
		var xa := INF
		var xb := -INF
		for e in 3:
			var p := a if e == 0 else (b if e == 1 else c)
			var q := b if e == 0 else (c if e == 1 else a)
			if (p.y <= yc and q.y > yc) or (q.y <= yc and p.y > yc):
				var x := p.x + (yc - p.y) / (q.y - p.y) * (q.x - p.x)
				xa = minf(xa, x)
				xb = maxf(xb, x)
		if xb < xa:
			continue
		var xs := maxi(int(ceil(xa - 0.5)), 0)
		var xe := mini(int(floor(xb - 0.5)), n - 1)
		if xe < xs:
			continue
		var row := y * n
		for x in range(xs, xe + 1):
			mask[row + x] = 1
		tx0 = mini(tx0, xs)
		tx1 = maxi(tx1, xe)
		ty0 = mini(ty0, y)
		ty1 = maxi(ty1, y)
	if tx1 < 0:
		return Rect2i(0, 0, -1, -1)
	return Rect2i(tx0, ty0, tx1 - tx0, ty1 - ty0)

static func _line(img: Image, a: Vector2, b: Vector2, col: Color, w: int) -> void:
	var dist := a.distance_to(b)
	var steps := maxi(int(dist * 2.0), 1)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		img.fill_rect(Rect2i(int(p.x) - w / 2, int(p.y) - w / 2, w, w), col)

static func _rect(img: Image, r: Rect2, col: Color, w: int) -> void:
	var tl := r.position
	var br := r.end
	_line(img, tl, Vector2(br.x, tl.y), col, w)
	_line(img, Vector2(br.x, tl.y), br, col, w)
	_line(img, br, Vector2(tl.x, br.y), col, w)
	_line(img, Vector2(tl.x, br.y), tl, col, w)

## dashes > 0 draws that many dashes (half on, half off); 0 = solid.
static func _circle(img: Image, c: Vector2, r: float, col: Color, w: int, dashes: int) -> void:
	var steps := maxi(int(TAU * r * 2.0), 16)
	for i in steps:
		if dashes > 0 and int(float(i) / steps * dashes * 2.0) % 2 == 1:
			continue
		var a := TAU * float(i) / steps
		var p := c + Vector2(cos(a), sin(a)) * r
		img.fill_rect(Rect2i(int(p.x) - w / 2, int(p.y) - w / 2, w, w), col)

## Table-surface dressing (brief #8): faint etched drawings in the two end zones of the inset
## (|x| > 0.55 m, clear of the ring and the model): plan outline with bolt holes + dimension line,
## gear, section hatch, title block, centre-lines. Transparent background, HOLO_LINE strokes.
const ETCH_PPM := 440

static func surface_etch(inset: Vector2) -> ImageTexture:
	var w := int(inset.x * ETCH_PPM)
	var h := int(inset.y * ETCH_PPM)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line := Tokens.a(Tokens.HOLO_LINE, 1.0)
	var dim := Tokens.a(Tokens.HOLO_LINE, 0.6)
	var c := Vector2(w, h) * 0.5
	var m := float(ETCH_PPM)
	for side in [-1.0, 1.0]:
		var o := c + Vector2(side * 0.82 * m, 0.0)  # zone centre
		# plan view: stepped bracket outline with bolt holes
		var plan := Rect2(o + Vector2(-0.22, -0.34) * m, Vector2(0.44, 0.2) * m)
		_rect(img, plan, line, 2)
		_rect(img, Rect2(plan.position + Vector2(0.0, 0.2) * m, Vector2(0.16, 0.12) * m), line, 2)
		for k in 3:
			_circle(img, plan.position + Vector2(0.07 + k * 0.15, 0.1) * m, 0.022 * m, line, 2, 0)
		_line(img, plan.position + Vector2(-0.04, 0.1) * m, plan.end + Vector2(0.04, -0.1) * m, dim, 1)  # centre-line
		var yd := plan.position.y - 0.04 * m  # dimension line above the plan
		_line(img, Vector2(plan.position.x, yd), Vector2(plan.end.x, yd), dim, 1)
		for e in [plan.position.x, plan.end.x]:
			_line(img, Vector2(e, yd - 6), Vector2(e, yd + 6), dim, 1)
		# gear / cam: ring + toothed outline + spokes
		var g := o + Vector2(-side * 0.1, 0.18) * m
		_circle(img, g, 0.1 * m, line, 2, 0)
		_circle(img, g, 0.075 * m, dim, 1, 0)
		_circle(img, g, 0.03 * m, line, 2, 0)
		_circle(img, g, 0.115 * m, line, 2, 36)  # tooth ring
		for k in 6:
			var d := Vector2.from_angle(k * TAU / 6.0)
			_line(img, g + d * 0.03 * m, g + d * 0.075 * m, dim, 1)
		_line(img, g + Vector2(-0.14, 0) * m, g + Vector2(0.14, 0) * m, dim, 1)
		_line(img, g + Vector2(0, -0.14) * m, g + Vector2(0, 0.14) * m, dim, 1)
		# section hatch block
		var hb := Rect2(o + Vector2(0.1 * side - 0.1, 0.3) * m, Vector2(0.2, 0.12) * m)
		_rect(img, hb, line, 2)
		var x := hb.position.x
		while x < hb.end.x + hb.size.y:
			var a := Vector2(x, hb.end.y)
			var b := Vector2(x + hb.size.y, hb.position.y)
			a.x = clampf(a.x, hb.position.x, hb.end.x)
			if b.x > hb.end.x:
				b = Vector2(hb.end.x, hb.position.y + (b.x - hb.end.x))
			_line(img, a, b, dim, 1)
			x += 0.024 * m
		# title block, outer-bottom corner
		var tb := Rect2(c + Vector2(side * 1.02 * m - (0.26 * m if side > 0 else 0.0), 0.36 * m), Vector2(0.26, 0.1) * m)
		tb.position.x = clampf(tb.position.x, 6, w - tb.size.x - 6)
		_rect(img, tb, dim, 1)
		_line(img, tb.position + Vector2(0, tb.size.y * 0.5), tb.position + Vector2(tb.size.x, tb.size.y * 0.5), dim, 1)
		_line(img, tb.position + Vector2(tb.size.x * 0.4, 0), tb.position + Vector2(tb.size.x * 0.4, tb.size.y), dim, 1)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
