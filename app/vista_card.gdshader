shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// The vista painting, alive (Jon, 2026-11-24: "a gif that can be looped
// endlessly, the ocean rolling beneath the cliffside"). The painting itself
// stays still; its SEA BAND breathes — a slow UV swell across the water plus
// faint foam streaks forever crawling — so the backdrop loops without ever
// repeating a frame the eye can catch. Mesh UV: v = 1 at the card's bottom.
uniform sampler2D tex : filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sea_lo = 0.0;    // UV.y where the painted sea starts (bottom of the band)
uniform float sea_hi = 0.0;    // UV.y of the painted horizon
uniform float sway = 0.0;      // 0 = a still painting; 1 = full roll
uniform float sat = 0.86;      // R8 polish: calm photographic saturation so room holograms lead
// Vista-feel round (Oculus Home research): stepped aerial perspective + a graded
// top edge, so the painting hazes toward ITS horizon in two perceptible steps
// and melts into the sky dome where the card ends instead of cutting off.
uniform vec4 haze_color : source_color = vec4(0.74, 0.83, 0.90, 1.0);
uniform float haze_horizon = 0.36;   // UV.y of the painted horizon line
uniform float haze_near = 0.80;      // UV.y where the haze has fully cleared (near shore)
uniform float haze_strength = 0.0;   // 0 = off
uniform vec4 edge_color : source_color = vec4(0.50, 0.65, 0.82, 1.0);
uniform float edge_fade = 0.0;       // top rows blended toward edge_color over this UV span

void fragment() {
	float band = smoothstep(sea_lo - 0.03, sea_lo + 0.06, UV.y) * (1.0 - smoothstep(sea_hi - 0.06, sea_hi + 0.03, UV.y));
	band *= sway;
	vec2 uv = UV;
	// feel round: Jon's looping backdrop stays, subordinated — half the swell, so
	// the painting reads still at a glance and the geometry carries the life.
	uv.x += sin(TIME * 0.11 + UV.y * 22.0 + sin(TIME * 0.05) * 1.7) * 0.0007 * band;
	uv.y += sin(TIME * 0.07 + UV.x * 9.0) * 0.0003 * band;
	vec3 col = texture(tex, uv).rgb;
	// Broken organic glint instead of continuous horizontal sine lines across the ocean
	float streak = sin(UV.y * 95.0 - TIME * 0.32 + sin(UV.x * 48.0 + TIME * 0.1) * 1.8) * 0.5 + 0.5;
	float break_x = sin(UV.x * 62.0 + UV.y * 17.0 - TIME * 0.15) * 0.5 + 0.5;
	float foam = band * smoothstep(0.92, 1.0, streak) * smoothstep(0.35, 0.9, break_x) * 0.015;
	col += vec3(foam);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, sat);
	// stepped aerial perspective: full haze at the horizon, a clear step down
	// through the mid-distance, gone at the near shore — a contrast ramp, not a
	// single fog wash. Gated so the sky above the horizon stays clean.
	float hz = clamp((haze_near - UV.y) / max(haze_near - haze_horizon, 0.001), 0.0, 1.0);
	float hstep = smoothstep(0.30, 0.80, hz) * 0.62 + smoothstep(0.02, 0.38, hz) * 0.30;
	float hgate = smoothstep(haze_horizon - 0.045, haze_horizon + 0.01, UV.y);
	col = mix(col, haze_color.rgb, clamp(hstep, 0.0, 0.85) * haze_strength * hgate);
	// the card's top edge graded toward the dome's colour at that elevation;
	// the sky cap samples v < 0, where this blend reaches full strength
	float ef = clamp(1.0 - smoothstep(-0.02, max(edge_fade, 0.001), UV.y), 0.0, 1.0);
	col = mix(col, edge_color.rgb, ef * 0.8);
	// Iterate round 2 (P2): the same melt at the card's SIDE edges (u near 0/1,
	// the ends of the 132-degree arc) — the painting dissolved into the dome
	// there instead of cutting hard against a paler sky.
	float sf = 1.0 - smoothstep(0.0, 0.08, min(UV.x, 1.0 - UV.x));
	col = mix(col, edge_color.rgb, sf * 0.75);
	ALBEDO = col * tint.rgb;
}
