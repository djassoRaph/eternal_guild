// hall_wall.gdshader: the hall's walls as one world-space surface (the hall look, pass 1; brainstorm 2026-11-03):
// ruin stone to about waist height with a broken top (#5: the hall stands on the ruins), then plaster in a dark
// timber frame, with soot darkening toward a ceiling lost in shadow (#16). hall_look.gd puts it on the b9 wall pieces.
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 stone_light : source_color = vec3(0.48, 0.46, 0.42);
uniform vec3 stone_dark : source_color = vec3(0.33, 0.32, 0.31);
uniform vec3 mortar_color : source_color = vec3(0.17, 0.16, 0.15);
uniform vec3 plaster_color : source_color = vec3(0.64, 0.57, 0.46);
uniform vec3 timber_color : source_color = vec3(0.18, 0.12, 0.085);
uniform vec3 soot_color : source_color = vec3(0.09, 0.075, 0.065);
uniform float floor_y = 0.1;
// the ruin line's mean height above the floor, and how broken it is
uniform float stone_top = 1.15;
uniform float stone_jag = 0.4;
uniform float course_height = 0.26;
// timber posts every post_spacing metres from post_offset, and one rail (the posts follow world metres, not the kit
// pieces' joints: only the north wall's 2 m pieces sit on even metres; the west, east and partition pieces don't)
uniform float post_spacing = 2.0;
uniform float post_offset = 1.0;
uniform float post_width = 0.2;
uniform float rail_y = 2.55;
uniform float rail_width = 0.18;
uniform float soot_from = 1.6;
uniform float soot_to = 4.0;
uniform float soot_amount = 0.8;

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
	world_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);   // right under non-uniform scale too
}

void fragment() {
	// the coordinate along the wall: z on walls facing x, x on walls facing z (and on top faces)
	vec3 n = normalize(world_nrm);
	float along = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
	float y = world_pos.y - floor_y;
	float ruin = stone_top + (fbm(vec2(along * 0.9, 3.0)) - 0.5) * stone_jag * 2.0;
	vec3 col;
	if (y < ruin) {
		float course = floor(y / course_height);
		float bw = mix(0.32, 0.62, hash(vec2(course, 9.1)));
		float sx = (along + hash(vec2(course, 1.7)) * 0.9) / bw;
		float hs = hash(vec2(floor(sx), course));
		float fu = fract(sx);
		float fv = fract(y / course_height);
		float edge_m = min(min(fu, 1.0 - fu) * bw, min(fv, 1.0 - fv) * course_height);
		float mortar = 1.0 - smoothstep(0.012, 0.03, edge_m);
		vec3 st = mix(stone_dark, stone_light, hs) * mix(0.78, 1.1, fbm(vec2(along, y) * 5.0 + hs * 7.0));
		st *= mix(0.62, 1.0, smoothstep(0.0, 0.6, y));            // damp at the foot
		st *= mix(0.72, 1.0, smoothstep(0.0, 0.08, ruin - y));     // the broken top's shadowed lip
		col = mix(st, mortar_color, mortar);
	} else {
		float pd = abs(fract((along - post_offset) / post_spacing + 0.5) - 0.5) * post_spacing;
		float post = 1.0 - smoothstep(post_width * 0.5 - 0.012, post_width * 0.5, pd);
		float rail = 1.0 - smoothstep(rail_width * 0.5 - 0.012, rail_width * 0.5, abs(y - rail_y));
		vec3 plaster = plaster_color * mix(0.8, 1.06, fbm(vec2(along, y) * 2.5));
		float crack = 1.0 - smoothstep(0.0, 0.014, abs(fbm(vec2(along, y) * 3.0 + 11.0) - 0.5));
		plaster = mix(plaster, plaster * 0.55, crack * 0.6);
		vec3 timber = timber_color * mix(0.8, 1.12, fbm(rail > post ? vec2(along * 2.0, y * 30.0) : vec2(along * 30.0, y * 2.0)));
		col = mix(plaster, timber, max(post, rail));
		col *= mix(0.55, 1.0, smoothstep(0.0, 0.12, y - ruin));   // the shadow where plaster meets the ruin
	}
	col = mix(col, soot_color, smoothstep(soot_from, soot_to, y) * soot_amount);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
