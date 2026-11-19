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
