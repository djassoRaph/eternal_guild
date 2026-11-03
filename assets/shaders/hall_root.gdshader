// hall_root.gdshader: the old roots wrapping the hourglass pillar (the hall look, pass 2; brainstorm #30 and #11, from
// Raphael's tavern drawing): dark bark with grooves along the root, and here and there a rune carved into it that
// glows the pillar's cyan, as if the ruin's magic runs through them. UV.x runs along the root, UV.y round it.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 bark : source_color = vec3(0.21, 0.14, 0.09);
uniform vec3 rune_color : source_color = vec3(0.35, 0.95, 1.0);
uniform float rune_energy = 2.4;
uniform float root_length = 4.0;
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
	float s = UV.x * root_length;      // metres along the root
	float grooves = noise(vec2(s * 3.0, UV.y * 9.0 + seed));
	vec3 c = bark * mix(0.6, 1.2, grooves) * mix(0.85, 1.05, noise(vec2(s * 0.8, seed)));
	// a rune every metre or so, on the root's outer side: a short glyph of strokes
	float cell = floor(s / 0.9);
	float local = fract(s / 0.9);
	float has = step(0.35, hash(vec2(cell, seed)));
	vec2 g = vec2((local - 0.5) * 6.0, (fract(UV.y) - 0.25) * 8.0);
	float strokes = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = hash(vec2(cell * 3.0 + float(i), seed + 7.0)) * PI;
		vec2 d = vec2(cos(a), sin(a));
		float along = clamp(dot(g, d), -0.8, 0.8);
		strokes = max(strokes, 1.0 - smoothstep(0.08, 0.16, length(g - d * along)));
	}
	float rune = strokes * has * step(abs(g.x), 1.0) * step(abs(g.y), 1.0);
	ALBEDO = mix(c, rune_color * 0.5, rune);
	EMISSION = rune_color * rune * rune_energy;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
