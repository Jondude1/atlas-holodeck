// Holographic grid (SPEC §2.6): dark base, minor lines every minor_spacing, majors every
// major_spacing at ~2x brightness. Grid comes from mesh-local position, so use it on
// boxes/discs sized in metres. Room: 0.5/2.0 m. Table: 0.10/0.50 m.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.0);
uniform vec3 minor_color : source_color = vec3(0.1);
uniform vec3 major_color : source_color = vec3(0.2);
uniform float minor_spacing = 0.1;
uniform float major_spacing = 0.5;
uniform float minor_strength = 0.35;
uniform float major_strength = 0.7; // ~2x minor
uniform float line_px = 1.2;
uniform float glow = 2.0;
uniform float fade = 1.0;

varying vec3 lpos;
varying vec3 lnrm;

float grid_line(vec3 pos, float spacing) {
	vec3 p = pos / spacing;
	vec3 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec3(1e-5));
	g += abs(lnrm) * 1000.0; // ignore the axis along the face normal
	float d = min(min(g.x, g.y), g.z);
	return 1.0 - clamp(d / line_px, 0.0, 1.0);
}

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	float minor = grid_line(lpos, minor_spacing);
	float major = grid_line(lpos, major_spacing);
	vec3 e = max(minor_color * minor * minor_strength, major_color * major * major_strength);
	ALBEDO = base_color * fade;
	EMISSION = e * glow * fade;
}
