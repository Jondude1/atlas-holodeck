shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Drifting soft layers (Round 5): mist banks and the cloud band. The texture scrolls in
// UV and the whole layer breathes (alpha sine) — all in TIME, zero CPU. depth_draw_never
// keeps these pure overlays that never occlude the cards behind them.
uniform sampler2D tex : source = "white";
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float scroll_speed = 0.004;    // UV per second
uniform float alpha_base = 0.5;
uniform float pulse = 0.15;            // breathing depth (fraction of alpha_base)
uniform float pulse_speed = 0.05;

void fragment() {
	vec2 uv = UV;
	uv.x = fract(uv.x + TIME * scroll_speed);
	float a = alpha_base * (1.0 + pulse * sin(TIME * pulse_speed * 6.28318));
	vec4 t = texture(tex, uv);
	ALBEDO = tint.rgb;
	ALPHA = t.a * tint.a * a;
}
