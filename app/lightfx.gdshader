// Lab light FX (brief #12): fake volumetrics in ONE additive merged mesh - ceiling-rig light shafts down to the
// table, layered glow halos, and glossy floor streaks under the cyan strips. No real lights, no post: the vertex
// colour says what a piece is (COLOR.r = intensity, COLOR.g = kind: 0 shaft / 0.5 radial halo / 1 linear streak).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 line_color : source_color = vec3(0.5, 0.8, 1.0);
uniform float fade = 1.0;
uniform float gain = 1.0;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	float kind = vcol.g;
	float a = 0.0;
	if (kind < 0.25) {
		// shaft: brightest at the grazing edge of the cone's silhouette, thinning toward the table, shimmering slowly
		float rim = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float body = 0.4 + 0.6 * pow(1.0 - rim, 1.6);
		float shimmer = 0.82 + 0.18 * sin(TIME * 0.9 + UV.x * 25.13 + vcol.b * 40.0) * sin(TIME * 0.37 + UV.y * 6.0);
		a = body * (1.0 - UV.y * 0.9) * shimmer;
	} else if (kind < 0.75) {
		vec2 c = UV - 0.5;
		float d = length(c) * 2.0;
		a = pow(clamp(1.0 - d, 0.0, 1.0), 1.7) * (0.9 + 0.1 * sin(TIME * 0.8 + vcol.b * 30.0));
	} else {
		// floor streak: UV.v = 0 at the strip, fading outward; soft ends along u
		a = pow(1.0 - UV.y, 2.2) * smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0 - UV.x);
		a *= 0.85 + 0.15 * sin(TIME * 1.3 + UV.x * 9.0);
	}
	ALBEDO = line_color;                               // blend_add multiplies by ALPHA: intensity lives in ALPHA only
	ALPHA = clamp(a * vcol.r * gain, 0.0, 1.0) * fade;
}
