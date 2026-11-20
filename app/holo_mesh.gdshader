// Hologram for real meshes (SPEC §2.6 / §3): translucent volume fill + fresnel rim, resolved by the
// same world-Y scan plane as holo.gdshader (same uniforms: wire / scan / y0 / y1 / flash), so a
// model made of either kind of part materializes identically. No AABB box edges: the silhouette
// comes from the fresnel term, which follows the actual surface.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec3 fill_color : source_color = vec3(0.1, 0.3, 0.6);
uniform vec3 line_color : source_color = vec3(0.5, 0.8, 1.0);
uniform vec3 core_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float fill_alpha = 0.28;
uniform float rim_power = 2.2;      // higher = thinner rim
uniform float rim_strength = 0.85;
uniform float line_density = 360.0; // fine horizontal scanlines per metre (world Y)
uniform float wire = 1.0;   // overall visibility (also used as the per-part fade)
uniform float scan = 1.2;   // scan-plane height, 0..1 across y0..y1
uniform float y0 = 0.0;     // world-space y range of the whole model
uniform float y1 = 1.0;
uniform float flash = 0.0;  // 1 = rim white-hot, 0 = settled to line colour

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fres = pow(1.0 - clamp(ndv, 0.0, 1.0), rim_power);

	float h = (wy - y0) / max(y1 - y0, 1e-4);
	float res = 1.0 - smoothstep(scan - 0.03, scan, h);
	float band = (1.0 - clamp(abs(h - scan) / 0.05, 0.0, 1.0)) * step(0.0, scan) * step(scan, 1.05);

	float lines = 0.85 + 0.15 * sin(wy * line_density - TIME * 2.2);   // R3-8: scanlines drift slowly downward
	float wf = fill_alpha * res * lines;
	float we = fres * rim_strength * mix(0.55, 1.0, res);
	float wb = band * 0.6;
	float sum = max(wf + we + wb, 1e-3);
	vec3 rim_col = mix(line_color, core_color, flash) * mix(1.0, 1.4, res);
	ALBEDO = (fill_color * wf + rim_col * we + core_color * wb) / sum;
	ALPHA = min(sum, 1.0) * wire;
}
