shader_type spatial;
// Vista life (R7-2): distant gulls + a horizon boat, animated entirely in the
// vertex shader — zero per-frame CPU, one draw call per system. The sprite is a
// dark silhouette on white; alpha comes from inverted luminance with an
// alpha-scissor cutout, so these stay in the OPAQUE pass (no transparent-layer
// cost against the vista's 4-layer sightline budget).
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D tex : source_color;
uniform vec4 tint : source_color = vec4(0.07, 0.09, 0.13, 1.0);
uniform float mode = 0.0; // 0 = gull (orbit + flap), 1 = boat (horizon drift)

varying float fade;

void vertex() {
	float phase = COLOR.r * 6.28318;
	if (mode < 0.5) {
		float a = TIME * (0.025 + COLOR.b * 0.02) + phase;
		float r = 6.0 + COLOR.g * 6.0;
		VERTEX += vec3(cos(a) * r, sin(TIME * 0.3 + phase * 3.0) * 0.8, sin(a) * r);
		VERTEX.y += sin(TIME * (2.0 + COLOR.b * 1.6) + phase * 7.0) * abs(UV.x - 0.5) * 1.1;
		fade = 1.0;
	} else {
		float t = fract(TIME * 0.0026 + COLOR.r);
		VERTEX.z += mix(-27.0, 27.0, t);
		VERTEX.y += sin(TIME * 0.9 + phase) * 0.07;
		fade = sin(3.14159 * t);
	}
}

void fragment() {
	vec4 t = texture(tex, UV);
	float lum = dot(t.rgb, vec3(0.3333));
	ALBEDO = tint.rgb;
	ALPHA = clamp(1.05 - lum, 0.0, 1.0) * fade;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
}
