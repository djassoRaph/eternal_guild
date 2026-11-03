// hall_portrait.gdshader: a past guildmaster's oil portrait (the hall look, pass 2; brainstorm #26): a dark varnished
// ground, a bust in a muted coat, a lit face, craquelure and an old yellow varnish. hall_dressing.gd sets each
// canvas's coat, hair and seed; the last frame in the row hangs empty, for the player.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 ground : source_color = vec3(0.12, 0.10, 0.08);
uniform vec3 coat : source_color = vec3(0.24, 0.18, 0.14);
uniform vec3 skin : source_color = vec3(0.70, 0.55, 0.42);
uniform vec3 hair : source_color = vec3(0.20, 0.15, 0.11);
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

void fragment() {
	vec2 uv = UV;
	float head_w = mix(0.17, 0.22, hash(vec2(seed, 1.0)));
	vec2 head = vec2(0.5 + (hash(vec2(seed, 2.0)) - 0.5) * 0.06, 0.38);
	vec3 c = ground * mix(0.8, 1.25, noise(uv * 4.0 + seed)) * mix(1.15, 0.7, uv.y);
	// shoulders: a broad curve from the neck down
	float shoulders = step(0.62 - 0.28 * (1.0 - pow(abs(uv.x - head.x) * 2.2, 2.0)), uv.y);
	c = mix(c, coat * mix(0.75, 1.1, noise(uv * 9.0 + seed)), shoulders);
	// the face: an oval, lit from the left, and hair on top
	vec2 f = (uv - head) / vec2(head_w, head_w * 1.35);
	float face = 1.0 - smoothstep(0.9, 1.0, length(f));
	vec3 lit = skin * mix(1.05, 0.55, smoothstep(-0.6, 0.8, f.x));
	c = mix(c, lit, face);
	float hair_mask = face * step(f.y, -0.35 + noise(vec2(uv.x * 20.0, seed)) * 0.25);
	c = mix(c, hair, hair_mask);
	// old varnish, a vignette and fine cracks
	c *= vec3(1.0, 0.93, 0.78) * mix(0.55, 1.0, 1.0 - smoothstep(0.25, 0.75, distance(uv, vec2(0.5, 0.45))));
	float crack = 1.0 - smoothstep(0.0, 0.03, abs(noise(uv * 30.0 + seed) - 0.5));
	c *= 1.0 - crack * 0.25;
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
