shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

// The vista sky dome (Round 5): a per-vista gradient — top colour, horizon glow band,
// ground haze — painted by direction only. One draw call, no texture, no fog, no light.
uniform vec4 top_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.45, 0.75, 0.95, 1.0);
uniform vec4 ground_color : source_color = vec4(0.02, 0.05, 0.10, 1.0);
uniform float horizon_height = 0.02;   // normalised direction-y of the horizon line
uniform float horizon_softness = 0.16;
// Vista-feel round (Oculus Home research): ONE sun — the dome carries a bright
// sector at the same azimuth the painting's light and the water's glitter use.
uniform vec2 sun_dir = vec2(-1.0, 0.0);          // deck-local xz, toward the sun
uniform vec4 sun_color : source_color = vec4(0.0);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float h = dir.y - horizon_height;
	vec3 col = h > 0.0
		? mix(horizon_color.rgb, top_color.rgb, pow(clamp(h / max(1.0 - horizon_height, 0.001), 0.0, 1.0), 0.48))
		: mix(horizon_color.rgb, ground_color.rgb, pow(clamp(-h / max(horizon_height + 1.0, 0.001), 0.0, 1.0), 0.5));
	// how aligned this fragment is with the sun's azimuth (fades with elevation)
	vec2 dxz = dir.xz / max(length(dir.xz), 0.05);
	float sa = max(dot(dxz, sun_dir), 0.0);
	// a soft luminous band hugging the horizon (sun haze / sea glare), stronger sunward
	col += horizon_color.rgb * exp(-abs(h) / max(horizon_softness, 0.001)) * 0.12 * (0.55 + 0.4 * pow(sa, 2.0));
	// the sun's own glow sector, low over the horizon — a brightening, not a blast
	col += sun_color.rgb * pow(sa, 4.0) * exp(-abs(h) / 0.13) * 0.20;
	ALBEDO = col;
}
