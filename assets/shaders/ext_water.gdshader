// ext_water.gdshader: the stream (the exterior look; brainstorm #29): deep teal water with slow moving ripples and a
// low roughness, so the braziers, the windows and the moon catch on it. exterior_look.gd puts it on the terrain's
// water mesh.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.09, 0.2, 0.26);
uniform vec3 shallow : source_color = vec3(0.2, 0.36, 0.42);
uniform vec3 ripple_light : source_color = vec3(0.55, 0.7, 0.78);
uniform vec2 flow = vec2(0.0, 0.35);

varying vec3 world_pos;

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
	vec2 p = world_pos.xz;
	float n1 = noise(p * vec2(0.9, 0.35) - flow * TIME);
	float n2 = noise(p * vec2(2.3, 0.8) - flow * TIME * 1.7 + 4.0);
	vec3 c = mix(deep, shallow, n1 * 0.7);
	float ripple = smoothstep(0.72, 0.8, n2) * (1.0 - smoothstep(0.8, 0.9, n2));
	c = mix(c, ripple_light, ripple * 0.28);
	ALBEDO = c;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	// an encoded normal map (Godot decodes .xy * 2 - 1 and rebuilds z): 0.5 is flat, so no normalize here
	NORMAL_MAP = vec3(0.5 + (n1 - 0.5) * 0.3, 0.5 + (n2 - 0.5) * 0.3, 1.0);
}
