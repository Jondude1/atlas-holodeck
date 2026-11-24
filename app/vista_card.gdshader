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

void fragment() {
	float band = smoothstep(sea_lo - 0.03, sea_lo + 0.06, UV.y) * (1.0 - smoothstep(sea_hi - 0.06, sea_hi + 0.03, UV.y));
	band *= sway;
	vec2 uv = UV;
	uv.x += sin(TIME * 0.11 + UV.y * 22.0 + sin(TIME * 0.05) * 1.7) * 0.0016 * band;
	uv.y += sin(TIME * 0.07 + UV.x * 9.0) * 0.0007 * band;
	vec3 col = texture(tex, uv).rgb;
	float streak = sin(UV.y * 90.0 - TIME * 0.35 + sin(UV.x * 40.0 + TIME * 0.1) * 1.5) * 0.5 + 0.5;
	float foam = band * smoothstep(0.93, 1.0, streak) * 0.07;
	col += vec3(foam);
	ALBEDO = col * tint.rgb;
}
