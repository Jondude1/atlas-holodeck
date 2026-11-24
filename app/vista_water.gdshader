shader_type spatial;
render_mode unshaded, depth_draw_opaque;

// The vista sea (Round 5; photographic since R7-6b). Jon called the old fully
// procedural version "that weird plane right after the balcony" — a flat colour
// field reads as a plane no matter how it sparkles. Now the base is a real
// ocean photograph, scrolled at two scales in different directions so it can
// never read as a still sheet or an obvious tile, with the swell, sun-glitter
// and shore wash kept as light overlays. All motion is TIME-driven.
uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.28, 1.0);
uniform vec4 spark_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float glitter_z = -1.0;        // world-z centre of the glitter lane (runs outward in -x)
uniform float glitter_width = 14.0;
uniform float speed = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// a real swell — the surface itself rises and falls (the plane carries
	// subdivisions), so looking down from the balcony the sea is never still.
	VERTEX.y += (sin(wpos.x * 0.32 + TIME * 0.8 * speed) + sin(wpos.z * 0.21 - TIME * 0.62 * speed)) * 0.035;
}

float wave(vec2 p, vec2 dir, float freq, float spd) {
	return sin(dot(p, dir) * freq + TIME * spd) * 0.5 + 0.5;
}

void fragment() {
	vec2 p = wpos.xz;
	// two photographic layers, different scales, drifting against each other
	vec3 l1 = texture(tex, p * 0.045 + vec2(TIME * 0.006, TIME * 0.0022) * speed).rgb;
	vec3 l2 = texture(tex, p * 0.13 - vec2(TIME * 0.004, -TIME * 0.005) * speed).rgb;
	vec3 col = mix(l1, l2, 0.42);
	// depth grade: darker + deeper near, easing to the photo's own colour out far
	float dist_fade = clamp(1.0 - length(p) / 90.0, 0.25, 1.0);
	col = mix(col, col * deep_color.rgb * 2.4, 0.35 * dist_fade);
	// a whisper of the old procedural life: moving glints + the sun lane
	float w = 0.0;
	w += wave(p, vec2(0.8, 0.6), 1.4, 0.9 * speed) * 0.45;
	w += wave(p, vec2(-0.5, 1.0), 2.7, 1.3 * speed) * 0.30;
	w += wave(p, vec2(1.0, -0.2), 5.5, 2.1 * speed) * 0.25;
	float near_calm = smoothstep(8.0, 26.0, length(wpos.xz - vec2(0.0, -6.0)));
	float sparkle = smoothstep(0.80, 0.99, w) * mix(0.10, 0.7, near_calm);
	float lane = exp(-abs(wpos.z - glitter_z) / max(glitter_width, 0.1));
	col += spark_color.rgb * sparkle * 0.16 * dist_fade;
	col += spark_color.rgb * lane * sparkle * 0.22 * dist_fade;
	// wash rolling ashore — bright bands travelling toward the cliffs (+z
	// world), strongest where the sea meets the headland, gone far out to sea.
	float shore = smoothstep(-24.0, -15.0, wpos.z) * (1.0 - smoothstep(-13.4, -12.2, wpos.z));
	float streak = sin(wpos.z * 2.1 - TIME * 1.15 * speed + sin(wpos.x * 0.3 + TIME * 0.23 * speed) * 1.6) * 0.5 + 0.5;
	float wash = shore * smoothstep(0.72, 0.97, streak);
	col = mix(col, vec3(0.88, 0.95, 0.99), wash * 0.45);
	ALBEDO = col;
}
