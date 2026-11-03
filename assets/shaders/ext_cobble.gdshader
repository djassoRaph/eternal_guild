// ext_cobble.gdshader: the road and the village square as cobbles in world space (the exterior look; brainstorm #29,
// the Octopath shot's textured cobbles): rounded stones of mixed greys and browns, dark earth between them, the middle
// of the road worn paler, a little sheen on the stones. exterior_look.gd puts it on the terrain's path mesh.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 stone_a : source_color = vec3(0.46, 0.44, 0.41);
uniform vec3 stone_b : source_color = vec3(0.36, 0.33, 0.31);
uniform vec3 stone_c : source_color = vec3(0.42, 0.36, 0.30);
uniform vec3 joint : source_color = vec3(0.14, 0.12, 0.10);
uniform float stone_size = 0.32;
uniform float joint_width = 0.07;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / stone_size;
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + 0.15 + 0.7 * hash2(ip + o);
			float d = length(c - fp);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = ip + o;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	float h = hash(id);
	vec3 s = h < 0.4 ? stone_a : (h < 0.75 ? stone_b : stone_c);
	s *= mix(0.8, 1.12, hash(id + 5.0)) * mix(0.85, 1.05, noise(world_pos.xz * 6.0));
	float edge = f2 - f1;
	float j = 1.0 - smoothstep(joint_width * 0.5, joint_width, edge);
	s *= mix(0.7, 1.0, smoothstep(0.0, 0.35, edge));                  // rounded: darker toward each stone's rim
	vec3 c = mix(s, joint, j);
	ALBEDO = c;
	ROUGHNESS = mix(0.55, 0.95, j);
	SPECULAR = 0.4;
}
