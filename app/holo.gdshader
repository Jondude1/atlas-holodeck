// Hologram part (SPEC §2.6): wireframe edges + translucent volume, resolved by a world-space
// scan plane that sweeps bottom-to-top. Edges are found from the part's own box bounds, so
// this is for box-shaped parts (the skeleton's bracket). scan >= ~1.1 = fully resolved.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 fill_color : source_color = vec3(0.1, 0.3, 0.6);
uniform vec3 line_color : source_color = vec3(0.5, 0.8, 1.0);
uniform vec3 core_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float fill_alpha = 0.28;
instance uniform vec3 aabb_center = vec3(0.0);
instance uniform vec3 aabb_half = vec3(0.1);
uniform float edge_w = 0.004;
instance uniform float wire = 1.0;   // overall visibility (beat 1: wireframe appears)
instance uniform float scan = 1.2;   // scan-plane height, 0..1 across y0..y1
instance uniform float y0 = 0.0;     // world-space y range of the whole model
instance uniform float y1 = 1.0;
instance uniform float flash = 0.0;
uniform float clip_y = 1000.0; // R7-3 section view: fragments above this world Y are cut (1000 = off)  // 1 = edges white-hot, 0 = settled to line colour
uniform float line_density = 360.0; // R3-8: fine horizontal scanlines per metre (world Y), matches holo_mesh

varying vec3 vpos;
varying float wy;

void vertex() {
	vpos = VERTEX - aabb_center;
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (wy > clip_y) discard; // R7-3 section plane
	vec3 q = aabb_half - abs(vpos);
	vec3 near = 1.0 - smoothstep(vec3(edge_w * 0.5), vec3(edge_w), q);
	float e = clamp(near.x * near.y + near.y * near.z + near.x * near.z, 0.0, 1.0);

	float h = (wy - y0) / max(y1 - y0, 1e-4);
	float res = 1.0 - smoothstep(scan - 0.03, scan, h);
	float band = (1.0 - clamp(abs(h - scan) / 0.05, 0.0, 1.0)) * step(0.0, scan) * step(scan, 1.05);

	float lines = 0.85 + 0.15 * sin(wy * line_density - TIME * 2.2);   // R3-8: scanlines drift slowly downward
	float wf = fill_alpha * res * lines;
	float we = e * mix(0.55, 1.0, res);
	float wb = band * 0.6;
	float sum = max(wf + we + wb, 1e-3);
	vec3 vol_col = vec3(fill_color.r * 0.45, mix(fill_color.g, line_color.g, 0.25), mix(fill_color.b, line_color.b, 0.18)) * 0.88;
	vec3 edge_col = mix(vec3(line_color.r * 0.5, line_color.g, line_color.b * 0.94), core_color, clamp(flash * 0.55, 0.0, 0.75)) * mix(0.9, 1.15, res);
	ALBEDO = (vol_col * wf + edge_col * we + core_color * 1.2 * wb) / sum;
	ALPHA = min(sum, 1.0) * wire;
}
