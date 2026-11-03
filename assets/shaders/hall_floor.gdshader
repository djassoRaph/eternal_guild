// hall_floor.gdshader: the guild hall's floor as one world-space surface (the hall look, pass 1; brainstorm
// 2026-11-03): dark old planks with paler worn lanes where feet go (#4), pale repair planks (#8), iron nails (#9),
// grime along the walls, a tiled ring round the bar (#34) and a compass rose where the door's lane meets it (#32).
// hall_look.gd puts it on every b9_floor tile and sets the hall's numbers (lanes, the bar, the room).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wood_dark : source_color = vec3(0.19, 0.125, 0.085);
uniform vec3 wood_light : source_color = vec3(0.36, 0.24, 0.16);
uniform vec3 wood_worn : source_color = vec3(0.50, 0.38, 0.27);
uniform vec3 wood_repair : source_color = vec3(0.58, 0.44, 0.30);
uniform vec3 gap_color : source_color = vec3(0.06, 0.04, 0.03);
uniform vec3 nail_color : source_color = vec3(0.10, 0.09, 0.09);
uniform vec3 tile_a : source_color = vec3(0.44, 0.29, 0.20);
uniform vec3 tile_b : source_color = vec3(0.37, 0.24, 0.17);
uniform vec3 grout_color : source_color = vec3(0.17, 0.14, 0.12);
uniform vec3 border_color : source_color = vec3(0.34, 0.32, 0.30);
uniform vec3 brass : source_color = vec3(0.72, 0.56, 0.30);
uniform vec3 inlay_pale : source_color = vec3(0.68, 0.64, 0.56);
uniform vec3 inlay_dark : source_color = vec3(0.21, 0.18, 0.16);
uniform float plank_width = 0.24;
uniform float gap_width = 0.03;
uniform float repair_chance = 0.025;
uniform vec2 bar_center = vec2(7.74, -8.215);
uniform float ring_inner = 3.05;
uniform float ring_outer = 4.75;
uniform float border_width = 0.14;
uniform float tile_size = 0.5;
uniform vec2 rose_center = vec2(7.74, -4.25);
uniform float rose_radius = 0.62;
// worn lanes: segments (ax, az, bx, bz) in world metres
uniform vec4 lanes[8];
uniform int lane_count = 0;
uniform float lane_width = 1.2;
// the room's inside (min x, min z, max x, max z): grime gathers along these walls
uniform vec4 room = vec4(-5.0, -19.3, 15.2, 4.66);
uniform float wall_grime = 0.45;

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

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float lane = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= lane_count) {
			break;
		}
		lane = max(lane, 1.0 - smoothstep(lane_width * 0.3, lane_width, seg_dist(p, lanes[i].xy, lanes[i].zw)));
	}
	lane *= mix(0.55, 1.0, fbm(p * 1.3));

	// planks along x, staggered ends
	float row = floor(p.y / plank_width);
	float plen = mix(1.3, 2.7, hash(vec2(row, 3.1)));
	float along = (p.x + hash(vec2(row, 7.7)) * plen) / plen;
	vec2 id = vec2(floor(along), row);
	float h = hash(id);
	float u = fract(along);
	float v = fract(p.y / plank_width);
	float grain = fbm(vec2(p.x * 0.9 + h * 17.0, p.y * 22.0));
	float streak = fbm(vec2(p.x * 3.0 + h * 5.0, p.y * 60.0));
	vec3 col = mix(wood_dark, wood_light, clamp(h * 0.7 + grain * 0.6 - 0.2, 0.0, 1.0));
	col *= mix(0.82, 1.08, streak);
	if (hash(id + vec2(13.37, 2.9)) < repair_chance) {
		col = wood_repair * mix(0.85, 1.05, grain);
	}
	col = mix(col, wood_worn * mix(0.9, 1.05, grain), lane * 0.75);
	float to_wall = min(min(p.x - room.x, room.z - p.x), min(p.y - room.y, room.w - p.y));
	col *= mix(1.0 - wall_grime, 1.0, smoothstep(0.0, 1.8, to_wall));
	// the gaps (side and end) and two nails at each plank end, in metres
	float side_m = min(v, 1.0 - v) * plank_width;
	float end_m = min(u, 1.0 - u) * plen;
	float gap = 1.0 - smoothstep(gap_width * 0.35, gap_width * 0.5, min(side_m, end_m));
	col = mix(col, gap_color, gap * 0.9);
	float nail = 1.0 - smoothstep(0.016, 0.024, length(vec2(end_m, abs(v - 0.5) * plank_width) - vec2(0.06, 0.06)));
	col = mix(col, nail_color, nail);
	float rough = mix(0.84, 0.64, lane);

	// the tiled ring round the bar, with stone borders
	float r = distance(p, bar_center);
	if (r > ring_inner && r < ring_outer) {
		vec2 tp = p / tile_size;
		vec2 tf = fract(tp);
		float th = hash(floor(tp) + vec2(4.2, 1.3));
		vec3 tcol = mix(tile_b, tile_a, th) * mix(0.85, 1.07, fbm(p * 4.0 + th * 9.0));
		float grout = 1.0 - smoothstep(0.03, 0.055, min(min(tf.x, 1.0 - tf.x), min(tf.y, 1.0 - tf.y)));
		tcol = mix(tcol, grout_color, grout);
		tcol = mix(tcol, tcol * 1.15 + vec3(0.025), lane * 0.6);
		float border = 1.0 - smoothstep(border_width - 0.015, border_width, min(r - ring_inner, ring_outer - r));
		tcol = mix(tcol, border_color * mix(0.85, 1.05, fbm(p * 6.0)), border);
		col = tcol;
		rough = 0.72;
	}

	// the compass rose: N/E/S/W in brass, the diagonals in pale stone, each point split light/dark
	vec2 q = p - rose_center;
	float rr = length(q) / rose_radius;
	if (rr < 1.0) {
		float ang = atan(q.y, q.x);
		float main_pt = mix(0.16, 1.0, pow(abs(cos(2.0 * ang)), 8.0));
		float side_pt = mix(0.16, 0.62, pow(abs(sin(2.0 * ang)), 8.0));
		vec3 rose = inlay_dark;
		if (rr < side_pt) {
			rose = mix(inlay_pale, inlay_pale * 0.68, step(0.5, fract((ang - PI * 0.25) / (PI * 0.5))));
		}
		if (rr < main_pt) {
			rose = mix(brass, brass * 0.6, step(0.5, fract(ang / (PI * 0.5))));
		}
		float ring = smoothstep(0.85, 0.87, rr) * (1.0 - smoothstep(0.96, 0.98, rr));
		rose = mix(rose, brass * 0.9, ring);
		col = rose;
		rough = mix(0.62, 0.4, ring);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
