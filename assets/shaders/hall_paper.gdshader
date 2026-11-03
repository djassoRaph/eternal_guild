// hall_paper.gdshader: an old notice on the wall round the guild board (the hall look, pass 2; brainstorm #23,
// the layered notice board): yellowed, stained paper, faded lines of writing, a torn corner and a nail.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 paper : source_color = vec3(0.80, 0.72, 0.54);
uniform vec3 ink : source_color = vec3(0.22, 0.17, 0.13);
uniform float age = 0.6;
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
	// a torn corner (which one: the seed) and a ragged edge
	vec2 corner = vec2(step(0.5, fract(seed * 0.37)), step(0.5, fract(seed * 0.71)));
	float tear = 0.22 + (fbm(uv * 18.0 + seed) - 0.5) * 0.08;
	if (abs(uv.x - corner.x) + abs(uv.y - corner.y) < tear) {
		discard;
	}
	vec3 c = paper * mix(0.75, 1.05, fbm(uv * 5.0 + seed * 3.0));
	c = mix(c, c * vec3(0.78, 0.62, 0.42), age * smoothstep(0.3, 0.75, fbm(uv * 3.0 + seed)));
	// faded lines of writing: short dashes on ruled rows
	float row = fract(uv.y * 11.0);
	float in_text = step(0.18, uv.y) * step(uv.y, 0.86) * step(0.12, uv.x) * step(uv.x, 0.88);
	float word = step(0.35, noise(vec2(uv.x * 26.0, floor(uv.y * 11.0) * 7.0 + seed)));
	float line = (1.0 - smoothstep(0.08, 0.16, abs(row - 0.5))) * word * in_text;
	float title = (1.0 - smoothstep(0.1, 0.22, abs(uv.y - 0.1) * 11.0)) * step(0.3, uv.x) * step(uv.x, 0.7);
	c = mix(c, ink, clamp(line + title, 0.0, 1.0) * mix(0.55, 0.25, age));
	float nail = 1.0 - smoothstep(0.025, 0.04, distance(uv, vec2(0.5, 0.05)));
	c = mix(c, vec3(0.08), nail);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
