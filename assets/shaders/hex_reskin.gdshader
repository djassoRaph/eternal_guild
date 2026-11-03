// hex_reskin.gdshader: the world map's KayKit hexes reskinned toward the exterior's Octopath look (Raphael
// 2026-11-03: "Octopath reskin", "Just make 3 for now: Grass. Water... Forest."). The pieces keep their shapes and
// their own atlas; each atlas cell they use is redrawn in world space: the grass tile's cell (0, 2) as muted patchy
// grass on top and layered earth on the sides, the water tile's (1, 1) as deep teal water with slow ripples, the
// trees' leaves (1, 2) as deep blue-green foliage with warm sunlit tops (KayKit's own gradient kept as the light),
// their trunks (6, 0) as dark bark. Any other cell keeps the atlas, slightly muted. hex_look.gd puts it on.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec3 grass_a : source_color = vec3(0.33, 0.43, 0.22);
uniform vec3 grass_b : source_color = vec3(0.23, 0.32, 0.18);
uniform vec3 grass_dry : source_color = vec3(0.48, 0.46, 0.27);
uniform vec3 soil : source_color = vec3(0.34, 0.27, 0.2);
uniform vec3 soil_dark : source_color = vec3(0.2, 0.16, 0.13);
uniform vec3 foliage_dark : source_color = vec3(0.07, 0.17, 0.15);
uniform vec3 foliage_light : source_color = vec3(0.24, 0.4, 0.27);
uniform vec3 foliage_warm : source_color = vec3(0.55, 0.55, 0.3);
uniform vec3 bark : source_color = vec3(0.2, 0.14, 0.1);
uniform vec3 water_deep : source_color = vec3(0.1, 0.22, 0.29);
uniform vec3 water_shallow : source_color = vec3(0.2, 0.37, 0.43);
uniform vec3 ripple_light : source_color = vec3(0.58, 0.72, 0.8);

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	vec2 cell = floor(UV * vec2(8.0, 4.0));
	vec3 n = normalize(world_nrm);
	vec2 p = world_pos.xz;
	vec3 col = mix(vec3(dot(base, vec3(0.333))), base, 0.78) * 0.92;
	float rough = 0.88;
	float spec = 0.25;
	if (cell == vec2(0.0, 2.0)) {
		// the grass tile: grass on top, layered earth on the sides
		if (n.y > 0.6) {
			col = mix(grass_b, grass_a, smoothstep(0.35, 0.65, fbm(p * 0.18)));
			col = mix(col, grass_dry, smoothstep(0.6, 0.8, fbm(p * 0.11 + 17.0)) * 0.6);
			col *= mix(0.84, 1.07, fbm(p * 2.2));
		} else {
			float strata = fbm(vec2((world_pos.x + world_pos.z) * 1.4, world_pos.y * 9.0));
			col = mix(soil_dark, soil, strata) * mix(0.7, 1.0, clamp(world_pos.y + 0.5, 0.0, 1.0));
		}
	} else if (cell == vec2(1.0, 1.0)) {
		// the water tile: deep teal water, slow ripples catching the light
		float n1 = noise(p * vec2(0.6, 0.25) + vec2(0.0, TIME * 0.12));
		float n2 = noise(p * vec2(1.6, 0.7) + vec2(TIME * 0.08, TIME * 0.2));
		col = mix(water_deep, water_shallow, n1 * 0.7);
		float ripple = smoothstep(0.72, 0.8, n2) * (1.0 - smoothstep(0.8, 0.9, n2));
		col = mix(col, ripple_light, ripple * 0.14);
		if (n.y <= 0.6) {
			col *= 0.6;
		}
		rough = 0.32;   // a soft sheen, not a sun glint at map scale
		spec = 0.5;
	} else if (cell == vec2(1.0, 2.0)) {
		// the trees' leaves: KayKit's gradient as the light, deep blue-green, warm on the sunlit tops
		float shade = dot(base, vec3(0.299, 0.587, 0.114));
		float leaf = fbm(world_pos.xz * 3.0 + vec2(world_pos.y * 2.0));
		col = mix(foliage_dark, foliage_light, clamp(shade * 1.7 - 0.25 + (leaf - 0.5) * 0.4, 0.0, 1.0));
		col = mix(col, foliage_warm, smoothstep(0.7, 1.0, n.y) * 0.22);
		rough = 0.9;
	} else if (cell == vec2(6.0, 0.0)) {
		col = bark * mix(0.8, 1.1, noise(vec2(world_pos.y * 12.0, world_pos.x + world_pos.z)));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
