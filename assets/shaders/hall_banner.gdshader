// hall_banner.gdshader: a faded banner of a guild that ran the hall before yours (the hall look, pass 1; brainstorm
// #25): old cloth in a muted colour, a worn trim border, a ring-over-chevron emblem, a frayed swallowtail hem.
// hall_look.gd hangs it on a QuadMesh (UV v runs top to bottom).
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 cloth : source_color = vec3(0.24, 0.33, 0.34);
uniform vec3 trim : source_color = vec3(0.56, 0.47, 0.30);
uniform float fade = 0.3;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float hem = 0.8 + abs(uv.x - 0.5) * 0.4 + (fbm(vec2(uv.x * 24.0, seed)) - 0.5) * 0.04;
	if (uv.y > hem) {
		discard;
	}
	vec3 c = cloth * mix(0.8, 1.05, fbm(uv * vec2(6.0, 14.0) + seed));
	float border = step(min(min(uv.x, 1.0 - uv.x), uv.y), 0.07) + step(hem - uv.y, 0.05);
	float ring = 1.0 - smoothstep(0.025, 0.04, abs(distance(uv * vec2(1.0, 1.9), vec2(0.5, 0.62)) - 0.2));
	float chevron = 1.0 - smoothstep(0.03, 0.045, abs(uv.y - 0.6 - abs(uv.x - 0.5) * 0.55) - 0.0);
	chevron *= step(0.5, uv.y) * step(abs(uv.x - 0.5), 0.3);
	float mark = clamp(border + ring + chevron, 0.0, 1.0) * mix(0.6, 1.0, fbm(uv * 9.0 + seed * 3.0));
	c = mix(c, trim * mix(0.75, 1.0, fbm(uv * 20.0)), mark);
	c = mix(c, vec3(dot(c, vec3(0.333))), fade);
	c *= mix(0.72, 1.0, fbm(uv * 3.0 + seed * 2.0));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
