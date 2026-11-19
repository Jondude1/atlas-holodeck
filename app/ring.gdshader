// HUD ring (SPEC §2.6) on one quad: outer ring with 60 minor / 12 major ticks, two inner
// rings at 0.82 / 0.64, and a brighter, thicker progress arc. Fully procedural, additive.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 base_color : source_color = vec3(0.1, 0.4, 0.8);  // un-lit ticks / rings
uniform vec3 line_color : source_color = vec3(0.5, 0.8, 1.0);  // lit ticks
uniform vec3 core_color : source_color = vec3(0.9, 0.95, 1.0); // progress arc / pulse
uniform float progress = 0.0; // 0..1 clockwise from the top
uniform float reveal = 1.0;   // 0..1 draw-in sweep
uniform float fade = 1.0;
uniform float pulse = 0.0;
uniform float arc_on = 1.0;
uniform float minor_ticks = 60.0;
uniform float major_ticks = 12.0;
uniform float inner_a = 0.82;
uniform float inner_b = 0.64;

const float RR = 0.94;       // outer ring radius in quad units
const float TICK = 0.035;    // minor tick length (major = 2x)
const float TAU_F = 6.2831853;

float band(float d, float w, float aa) {
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

float ticks(float t, float r, float count, float len, float aa) {
	float du = abs(fract(t * count + 0.5) - 0.5);
	float arcw = du * (TAU_F / count) * r;
	float radial = band(abs(r - (RR - len * 0.5)), len * 0.5, aa);
	return band(arcw, 0.004, aa) * radial;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float aa = max(fwidth(r), 1e-4);
	float t = fract(atan(p.x, -p.y) / TAU_F);

	float seen = step(t, reveal);
	float ring = band(abs(r - RR), 0.004, aa) * seen;
	float minor = ticks(t, r, minor_ticks, TICK, aa) * seen;
	float major = ticks(t, r, major_ticks, TICK * 2.0, aa) * seen;
	float inner = (band(abs(r - RR * inner_a), 0.003, aa) + band(abs(r - RR * inner_b), 0.003, aa)) * reveal;
	float lit = step(t, progress);
	float arc = band(abs(r - RR), 0.012, aa) * lit * arc_on * seen;

	vec3 col = base_color * (ring + inner * 0.7 + minor * 0.8);
	col += line_color * (minor * lit + major);
	col += core_color * (arc + major * lit * 0.5);
	col += core_color * pulse * (ring + minor + major + inner) * 0.8;
	if (max(col.r, max(col.g, col.b)) < 0.002) discard;
	ALBEDO = clamp(col, 0.0, 1.5);
	ALPHA = fade;
}
