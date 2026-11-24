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
uniform float rim_power = 1.75;     // R8 tone-lift: strong teal fresnel silhouette at both wireframe and resolved states
uniform float rim_strength = 0.96;
uniform float crease_strength = 0.85; // R8 tone-lift: crisp electric-teal structural wireframe ridges
uniform float line_density = 360.0; // fine horizontal scanlines per metre (world Y)
instance uniform float wire = 1.0;   // overall visibility (also used as the per-part fade)
instance uniform float scan = 1.2;   // scan-plane height, 0..1 across y0..y1
instance uniform float y0 = 0.0;     // world-space y range of the whole model
instance uniform float y1 = 1.0;
instance uniform float flash = 0.0;
uniform float clip_y = 1000.0; // R7-3 section view: fragments above this world Y are cut (1000 = off)  // 1 = rim white-hot, 0 = settled to line colour

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (wy > clip_y) discard; // R7-3 section plane
	vec3 n = normalize(NORMAL);
	float ndv = abs(dot(n, normalize(VIEW)));
	float fres = pow(1.0 - clamp(ndv, 0.0, 1.0), rim_power);
	float ndelta = length(dFdx(n)) + length(dFdy(n));
	float crease = smoothstep(0.12, 0.50, ndelta);

	float h = (wy - y0) / max(y1 - y0, 1e-4);
	float res = 1.0 - smoothstep(scan - 0.03, scan, h);
	float band = (1.0 - clamp(abs(h - scan) / 0.05, 0.0, 1.0)) * step(0.0, scan) * step(scan, 1.05);

	float lines = 0.84 + 0.16 * sin(wy * line_density - TIME * 2.2);   // R3-8: scanlines drift slowly downward
	float wf = clamp(fill_alpha * mix(0.32, 0.92, res), 0.0, 0.28) * lines;
	float we = fres * rim_strength * mix(0.82, 1.0, res);
	float wc = crease * crease_strength * mix(0.88, 1.0, res);
	float wb = band * 0.45;
	float sum = max(wf + we + wc + wb, 1e-3);
	vec3 teal_vol = vec3(fill_color.r * 0.55, mix(fill_color.g, line_color.g, 0.48), mix(fill_color.b, line_color.b, 0.24));
	vec3 teal_rim = vec3(line_color.r * 0.34, line_color.g * 1.15, line_color.b * 0.92);
	vec3 teal_wire = vec3(line_color.r * 0.46, line_color.g * 1.32, line_color.b * 1.02);
	vec3 hi_teal = mix(teal_wire, core_color, 0.22);
	vec3 rim_col = mix(teal_rim, hi_teal, flash) * mix(0.95, 1.10, res);
	vec3 crease_col = mix(teal_wire, hi_teal, flash) * mix(1.00, 1.18, res);
	ALBEDO = (teal_vol * wf + rim_col * we + crease_col * wc + hi_teal * 1.15 * wb) / sum;
	ALPHA = min(sum, 0.84) * wire;
}
