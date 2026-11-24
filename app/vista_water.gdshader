shader_type spatial;
render_mode unshaded, depth_draw_opaque;

// The vista water plane (Round 5): fully procedural — two scrolling wave fields summed
// into moving sparkle over a deep base colour, plus a static sun-glitter streak. No
// texture (no tiling seams), no reflections, no per-frame CPU: TIME does all the work.
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.28, 1.0);
uniform vec4 spark_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float glitter_z = -1.0;        // world-z centre of the glitter lane (runs outward in -x)
uniform float glitter_width = 14.0;
uniform float speed = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave(vec2 p, vec2 dir, float freq, float spd) {
	return sin(dot(p, dir) * freq + TIME * spd) * 0.5 + 0.5;
}

void fragment() {
	vec2 p = wpos.xz;
	float w = 0.0;
	w += wave(p, vec2(0.8, 0.6), 1.4, 0.9 * speed) * 0.45;
	w += wave(p, vec2(-0.5, 1.0), 2.7, 1.3 * speed) * 0.30;
	w += wave(p, vec2(1.0, -0.2), 5.5, 2.1 * speed) * 0.25;
	float sparkle = smoothstep(0.78, 0.98, w);
	// sun glitter: a bright lane under the vista's light, fading with distance
	float lane = exp(-abs(wpos.z - glitter_z) / max(glitter_width, 0.1));
	float dist_fade = clamp(1.0 - length(p) / 90.0, 0.25, 1.0);
	vec3 col = deep_color.rgb;
	col += spark_color.rgb * sparkle * 0.35 * dist_fade;
	col += spark_color.rgb * lane * sparkle * 0.55 * dist_fade;
	col += spark_color.rgb * lane * 0.05;
	ALBEDO = col;
}
