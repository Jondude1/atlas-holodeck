// Emitter glow column (R3-1): two crossed quads fake a soft volumetric shaft rising from the display
// under the active model. Alpha peaks at each quad's horizontal centre and dies toward the top.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.35, 0.75, 1.0);
uniform float fade = 0.0;
uniform float gain = 0.09;

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;            // 1 at the quad's centre line, 0 at its edges
	float body = pow(across, 1.8) * pow(UV.y, 1.6);        // MeshBuilder quads: UV.y = 1 at the base, 0 at the top
	float shimmer = 0.9 + 0.1 * sin(TIME * 0.7 + UV.y * 9.0);
	ALBEDO = tint;
	ALPHA = clamp(body * shimmer * gain, 0.0, 1.0) * fade;
}
