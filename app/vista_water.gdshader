shader_type spatial;
render_mode unshaded, depth_draw_opaque, fog_disabled;

// The vista sea (Round 5; photographic since R7-6b). Jon called the old fully
// procedural version "that weird plane right after the balcony" — a flat colour
// field reads as a plane no matter how it sparkles. Now the base is a real
// ocean photograph, scrolled at two scales in different directions so it can
// never read as a still sheet or an obvious tile, with the swell, sun-glitter
// and shore wash kept as light overlays. All motion is TIME-driven.
uniform sampler2D tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.28, 1.0);
uniform vec4 spark_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float glitter_x = 0.0;         // world-x centre of the glitter lane (the lane runs outward, away from the room, at the sun's side of the view)
uniform float glitter_width = 14.0;
uniform float speed = 1.0;
uniform vec4 haze_color : source_color = vec4(0.74, 0.83, 0.90, 1.0);
uniform float haze_amt = 0.0;          // feel round: far water hazes into the painting's air so geometry sea and painted sea meet as one ramp

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

// Iterate round 2 (P2): large-scale value noise — the periodicity breaker.
// The two photo layers below repeat every ~22 m / ~7.7 m; from the terrace
// (high angle) that grid read as photo TILES. A smooth hash noise at ~30-55 m
// scales modulates the layer mix and the brightness, so no two tile repeats
// ever present the same pattern to the eye. No texture, no extra draw calls.
float vhash(vec2 g) {
	return fract(sin(dot(g, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(vhash(g), vhash(g + vec2(1.0, 0.0)), u.x),
		mix(vhash(g + vec2(0.0, 1.0)), vhash(g + vec2(1.0, 1.0)), u.x), u.y);
}

// Mirrored-repeat sampling: the ocean photo's edges do not match each other,
// so plain repeat stamped a rectangular seam at every tile border (the blocks
// in the baseline terrace capture). Mirroring makes every border continuous.
vec2 muv(vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return 1.0 - abs(m - 1.0);
}

void fragment() {
	vec2 p = wpos.xz;
	// two photographic layers, different scales, drifting against each other;
	// the fine layer is ROTATED off the coarse layer's grid so their repeats
	// never align into a visible tile lattice from above
	float ca = cos(0.62);
	float sa = sin(0.62);
	mat2 rot = mat2(vec2(ca, -sa), vec2(sa, ca));
	vec3 l1 = texture(tex, muv(p * 0.045 + vec2(TIME * 0.006, TIME * 0.0022) * speed)).rgb;
	vec3 l2 = texture(tex, muv(rot * p * 0.13 - vec2(TIME * 0.004, -TIME * 0.005) * speed)).rgb;
	// macro variation: the mix ratio and overall brightness wander at scales
	// far larger than either tile, breaking the repeat the eye locks onto
	float macro = vnoise(p * 0.018 + vec2(TIME * 0.0016, 0.0) * speed);
	float macro2 = vnoise(p * 0.034 + 7.3 - vec2(0.0, TIME * 0.0011) * speed);
	vec3 col = mix(l1, l2, clamp(0.42 + (macro - 0.5) * 0.55, 0.08, 0.76));
	col *= 0.90 + macro * 0.13 + macro2 * 0.07;
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
	float lane = exp(-abs(wpos.x - glitter_x) / max(glitter_width, 0.1));
	col += spark_color.rgb * sparkle * 0.16 * dist_fade;
	col += spark_color.rgb * lane * sparkle * 0.22 * dist_fade;
	// wash rolling ashore — bright bands travelling toward the cliffs (+z
	// world), strongest where the sea meets the headland, gone far out to sea.
	float shore = smoothstep(-24.0, -15.0, wpos.z) * (1.0 - smoothstep(-13.4, -12.2, wpos.z));
	float streak = sin(wpos.z * 2.1 - TIME * 1.15 * speed + sin(wpos.x * 0.3 + TIME * 0.23 * speed) * 1.6) * 0.5 + 0.5;
	float wash = shore * smoothstep(0.72, 0.97, streak);
	col = mix(col, vec3(0.88, 0.95, 0.99), wash * 0.45);
	// distance haze: by the time the geometry sea reaches the painting it has
	// taken on the same pale air the painting's own horizon wears
	col = mix(col, haze_color.rgb, smoothstep(18.0, 55.0, length(p)) * haze_amt);
	ALBEDO = col;
}
