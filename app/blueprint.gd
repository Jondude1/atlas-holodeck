class_name Blueprint
## Generated flat schematic for the table layer: top-down footprint outline, bolt-pattern
## suggestion, dimension lines with end ticks. Drawn 2x supersampled, shipped at 512x512.
## Image up = -Z (the quad lies on the table with its texture top pointing away from the player).

const SIZE := 512
const SS := 2

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
