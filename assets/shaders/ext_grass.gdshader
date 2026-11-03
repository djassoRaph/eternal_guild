// ext_grass.gdshader: the exterior's ground in world space (the exterior look; brainstorm 2026-11-03 #29, Raphael's
// Octopath reference): muted, patchy grass with darker hollows, dry tufts and a few wild flowers, and bare earth and
// stone on the steep banks. exterior_look.gd puts it on the terrain mesh.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 grass_a : source_color = vec3(0.30, 0.40, 0.20);
uniform vec3 grass_b : source_color = vec3(0.21, 0.30, 0.17);
uniform vec3 grass_dry : source_color = vec3(0.45, 0.44, 0.26);
uniform vec3 bank : source_color = vec3(0.33, 0.29, 0.25);
uniform vec3 bank_dark : source_color = vec3(0.22, 0.2, 0.18);
uniform vec3 flower_a : source_color = vec3(0.85, 0.8, 0.55);
uniform vec3 flower_b : source_color = vec3(0.6, 0.5, 0.75);
uniform float flower_density = 0.05;

varying vec3 world_pos;
varying vec3 world_nrm;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float patch = fbm(p * 0.08);
	vec3 g = mix(grass_b, grass_a, smoothstep(0.35, 0.65, patch));
	g = mix(g, grass_dry, smoothstep(0.62, 0.8, fbm(p * 0.05 + 17.0)) * 0.7);
	g *= mix(0.82, 1.08, fbm(p * 1.6));                              // tufts
	g *= mix(0.85, 1.0, smoothstep(-3.5, -1.0, world_pos.y));        // darker down in the stream's valley
	// a few wild flowers, one per cell at most
	vec2 cell = floor(p * 2.5);
	vec2 fp = fract(p * 2.5) - vec2(hash(cell), hash(cell + 3.1));
	float flower = step(hash(cell + 7.7), flower_density) * (1.0 - smoothstep(0.03, 0.06, length(fp)));
	g = mix(g, mix(flower_a, flower_b, step(0.5, hash(cell + 1.3))), flower);
	// steep banks: bare earth and stone in layers
	float steep = 1.0 - smoothstep(0.55, 0.8, world_nrm.y);
	vec3 b = mix(bank_dark, bank, fbm(vec2((world_pos.x + world_pos.z) * 0.7, world_pos.y * 4.0)));
	ALBEDO = mix(g, b, steep);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
