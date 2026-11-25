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
uniform float strength = 1.0;
uniform float fine_strength = 0.0;  // faint sub-grid at 1/4 of minor_spacing (table inset: crisper, richer schematic)
uniform float dist_fade = 0.0;   // 1 = attenuate with camera distance (room); 0 = off (table inset)
uniform float near_dist = 2.5;   // full strength at or inside this distance (m)
uniform float far_dist = 9.0;    // far_floor strength at or beyond this distance (m)
uniform float far_floor = 0.15;
uniform float hot_center = 0.0;   // R3-2: extra emission toward the mesh centre (table inset: the work pools light)
uniform float hot_radius = 0.8;
uniform vec2 hot_point = vec2(0.0);  // R7-4: where a tap landed (inset-local XZ)
uniform float hot_pulse = 0.0;       // R7-4: tap flash strength, decays to 0   // metres from centre where the hot falloff reaches zero

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 wpos;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float minor = grid_line(lpos, minor_spacing);
	float major = grid_line(lpos, major_spacing);
	float fine = fine_strength > 0.0 ? grid_line(lpos, minor_spacing * 0.25) : 0.0;
	vec3 e = max(max(minor_color * minor * minor_strength, major_color * major * major_strength), minor_color * fine * fine_strength);
	ALBEDO = base_color * fade;
	float k = mix(1.0, mix(1.0, far_floor, smoothstep(near_dist, far_dist, distance(wpos, CAMERA_POSITION_WORLD))), dist_fade);
	float hot = 1.0 + hot_center * (1.0 - smoothstep(0.0, hot_radius, length(lpos.xz)));
	hot += hot_pulse * (1.0 - smoothstep(0.0, 0.45, length(lpos.xz - hot_point)));
	EMISSION = e * glow * fade * strength * k * hot;
}
