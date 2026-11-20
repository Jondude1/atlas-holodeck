// Wall-mounted Stark-style screens (brief #12). Every screen in the lab is a quad of ONE merged mesh, so the whole
// bank is a single draw call; the vertex colour tells each quad what to show:
//   COLOR.r = seed (0..1), COLOR.g = kind (k/8), COLOR.b = aspect/8 (width / height).
// Fully procedural and animated by TIME: rings turning, graphs scrolling, readout rows crawling. Cyan only - the
// two cyan tokens come in as uniforms, nothing here carries a colour literal.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 line_color : source_color = vec3(0.5, 0.8, 1.0);
uniform vec3 core_color : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 deep_color : source_color = vec3(0.04, 0.2, 0.34);
uniform float fade = 1.0;
uniform float brightness = 1.0;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float box(vec2 p, vec2 c, vec2 h, float w) {
	vec2 d = abs(p - c) - h;
	return smoothstep(w, 0.0, abs(max(d.x, d.y)));
}

float ring(float r, float c, float w) {
	return smoothstep(w, 0.0, abs(r - c));
}

// arc segments around a ring: n gaps, rotating
float arcs(vec2 p, float r, float w, float n, float rot, float dutycycle) {
	float a = atan(p.y, p.x) / TAU + 0.5;
	return ring(length(p), r, w) * step(fract(a * n + rot), dutycycle);
}

void fragment() {
	float seed = vcol.r * 9.0;
	int kind = int(floor(vcol.g * 8.0 + 0.5));
	float aspect = max(vcol.b * 8.0, 0.2);
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);          // height spans -0.5 .. 0.5
	float t = TIME * (0.4 + 0.15 * fract(seed));
	float i = 0.0;

	// frame: thin border + corner brackets + title tick row
	float bw = 0.006;
	i += box(p, vec2(0.0), vec2(aspect * 0.5 - 0.012, 0.488), bw) * 0.9;
	for (int k = 0; k < 4; k++) {
		vec2 s = vec2(k < 2 ? -1.0 : 1.0, (k % 2) == 0 ? -1.0 : 1.0);
		vec2 c = s * vec2(aspect * 0.5 - 0.03, 0.46);
		i += box(p, c, vec2(0.05, 0.004), 0.004) * 1.2 + box(p, c, vec2(0.004, 0.05), 0.004) * 1.2;
	}
	float title = step(0.43, p.y) * step(p.y, 0.47) * step(fract(p.x * 30.0 + seed), 0.5) * 0.35;
	i += title;

	if (kind == 0) {
		// concentric turning rings (left) + bar levels (right)
		vec2 q = p - vec2(-aspect * 0.22, -0.02);
		float r = length(q);
		i += arcs(q, 0.30, 0.012, 3.0, t * 0.25 + seed, 0.62) * 1.3;
		i += arcs(q, 0.24, 0.006, 5.0, -t * 0.4, 0.5) * 0.9;
		i += arcs(q, 0.17, 0.016, 2.0, t * 0.6, 0.7) * 1.1;
		i += ring(r, 0.09, 0.004) * 0.8;
		float a = atan(q.y, q.x) / TAU + 0.5;
		i += step(0.8, fract(a * 72.0)) * ring(r, 0.335, 0.012) * 0.7;
		i += smoothstep(0.02, 0.0, r - 0.025 * (1.0 + 0.2 * sin(t * 3.0))) * 0.8;
		for (int k = 0; k < 9; k++) {
			float fx = aspect * 0.08 + float(k) * 0.045;
			float h = 0.05 + 0.34 * (0.5 + 0.5 * sin(t * (1.0 + 0.3 * float(k)) + float(k) * 1.7 + seed));
			i += step(abs(p.x - fx), 0.014) * step(-0.28, p.y) * step(p.y, -0.28 + h) * 0.75;
		}
	} else if (kind == 1) {
		// scrolling line graphs over a faint grid
		vec2 g = p * vec2(1.0, 1.0);
		i += (step(fract(g.x * 14.0), 0.04) + step(fract(g.y * 10.0), 0.05)) * 0.13;
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float x = p.x * (5.0 - fk) + t * (0.8 + 0.4 * fk) + seed * (1.0 + fk);
			float y = (-0.18 + 0.2 * fk) + 0.07 * sin(x * 2.1 + fk) + 0.045 * sin(x * 5.3 + seed) + 0.02 * sin(x * 11.0);
			i += smoothstep(0.012, 0.0, abs(p.y - y)) * (0.95 - 0.18 * fk);
			i += smoothstep(0.1, 0.0, p.y - y) * step(p.y, y) * 0.05;
		}
		float sweep = fract(t * 0.18 + seed);
		i += smoothstep(0.02, 0.0, abs((uv.x) - sweep)) * 0.5;
	} else if (kind == 2) {
		// schematic: hex lattice with a scanning bar, crosshair and a slow-turning gear
		vec2 h = p * 9.0;
		vec2 a2 = mod(h, vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
		vec2 b2 = mod(h + vec2(0.5, 0.8660254), vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
		vec2 gv = dot(a2, a2) < dot(b2, b2) ? a2 : b2;
		float hex = max(abs(gv.x) * 0.866 + abs(gv.y) * 0.5, abs(gv.y));
		i += smoothstep(0.035, 0.0, abs(hex - 0.46)) * 0.16;
		vec2 q = p - vec2(aspect * 0.12, 0.0);
		i += ring(length(q), 0.26, 0.007) * 0.9;
		float ga = atan(q.y, q.x) + t * 0.5;
		i += smoothstep(0.012, 0.0, abs(length(q) - (0.19 + 0.025 * step(0.5, fract(ga * 14.0 / TAU))))) * 1.1;
		i += box(p, vec2(0.0), vec2(aspect * 0.5 - 0.05, 0.0035), 0.003) * 0.4 + box(p, vec2(aspect * 0.12, 0.0), vec2(0.0035, 0.4), 0.003) * 0.4;
		float scan = fract(t * 0.22 + seed);
		i += smoothstep(0.014, 0.0, abs(uv.y - scan)) * 0.7 + step(uv.y, scan) * step(scan - 0.12, uv.y) * 0.06;
		i += arcs(p - vec2(-aspect * 0.3, -0.15), 0.11, 0.008, 4.0, -t * 0.7, 0.6) * 1.1;
	} else {
		// readout rows: dashed "text" crawling upward, a header bar and a progress bar
		float rows = 16.0;
		float y = uv.y * rows + t * 0.8;
		float row = floor(y);
		float inrow = step(0.18, fract(y)) * step(fract(y), 0.62);
		float w = 0.2 + 0.7 * hash(vec2(row, seed));
		float start = 0.06 + 0.12 * hash(vec2(row + 7.0, seed));
		float seg = step(start, uv.x) * step(uv.x, start + w * 0.8);
		float gap = step(0.3, fract(uv.x * (14.0 + 6.0 * hash(vec2(row, 3.0)))));
		i += inrow * seg * gap * (0.35 + 0.45 * hash(vec2(row, 9.0)));
		float bar = 0.5 + 0.5 * sin(t * 0.7 + seed);
		i += box(p, vec2(0.0, -0.4), vec2(aspect * 0.4, 0.012), 0.004) * 0.8;
		i += step(abs(p.y + 0.4), 0.008) * step(p.x, -aspect * 0.4 + aspect * 0.8 * bar) * step(-aspect * 0.4, p.x) * 1.0;
	}

	float edge = smoothstep(0.0, 0.05, min(uv.x, 1.0 - uv.x)) * smoothstep(0.0, 0.05, min(uv.y, 1.0 - uv.y));
	float flicker = 0.93 + 0.07 * sin(TIME * 13.0 + seed * 5.0);
	float panel = 0.07;     // faint wash so a screen reads as a lit pane, not floating lines
	vec3 col = mix(deep_color * 2.0 + line_color * 0.25, mix(line_color, core_color, clamp(i * 0.25, 0.0, 1.0)), clamp(i * 2.0, 0.0, 1.0));
	ALBEDO = col * brightness;                         // blend_add multiplies by ALPHA: intensity lives in ALPHA
	ALPHA = clamp(panel + i, 0.0, 1.0) * flicker * edge * fade;
}
