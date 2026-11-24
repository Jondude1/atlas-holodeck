class_name Units
## The ONE home for user-facing measurements (R4-6 consolidation; SPEC: imperial only, decimal
## inches, feet+inches at 24 in and up, metric never reaches a display). Before this file the
## trimmer existed twice and cad_bench's dims line skipped the feet conversion entirely, so a
## 30 in library part read "30.5 IN" there but "2' 6.5"" on the model — same house, two formats.

## Decimal with trailing zeros trimmed: dec(6.30, 2) = "6.3", dec(4.0, 2) = "4".
static func dec(v: float, places: int) -> String:
	var t := String.num(v, places)
	if t.contains("."):
		t = t.rstrip("0").rstrip(".")
	return t

## One length: plain decimal inches, or feet + inches when long_form (any sibling >= 24 in).
static func len_in(inches: float, long_form: bool) -> String:
	if inches >= 24.0:
		var ft := int(inches / 12.0)
		var rem := inches - ft * 12.0
		if roundf(rem * 100.0) / 100.0 >= 12.0:  # rounding carried into a full foot
			ft += 1
			rem = 0.0
		return "%d' %s\"" % [ft, dec(rem, 1)]
	return dec(inches, 2)

## "9.45 × 6.3 × 7.87 IN" from an [x, z, y] inch triple (house order: length, depth, height);
## the IN suffix appears only when every dimension is plain inches.
static func dims_line(d: Array) -> String:
	if d.size() < 3:
		return ""
	var vals := [float(d[0]), float(d[1]), float(d[2])]
	var long_form := vals.any(func(v: float) -> bool: return v >= 24.0)
	var parts := PackedStringArray()
	for v in vals:
		parts.append(len_in(v, long_form))
	return " × ".join(parts) + ("" if long_form else " IN")
