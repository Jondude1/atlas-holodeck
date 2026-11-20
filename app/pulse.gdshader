// Light strip with a slow pulse travelling along it (brief #12: nothing static). Unshaded HDR so the existing glow
// picks it up. `axis` is the strip's long axis in mesh space; the pulse loops along `span` metres.
shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color = vec3(0.5, 0.8, 1.0);
uniform float energy = 3.4;
uniform float fade = 1.0;
uniform vec3 axis = vec3(1.0, 0.0, 0.0);
uniform float span = 2.24;
uniform float speed = 0.14;       // loops per second
uniform float gain = 1.1;         // extra brightness at the pulse head, as a fraction of the base energy
uniform float phase = 0.0;

varying float along;

void vertex() {
	along = dot(VERTEX, axis) / span + 0.5;
}

void fragment() {
	float h = fract(along - TIME * speed + phase);
	float band = exp(-pow((h - 0.5) * 7.0, 2.0));
	float e = energy * fade * (0.78 + gain * band);
	ALBEDO = base_color * e;
}
