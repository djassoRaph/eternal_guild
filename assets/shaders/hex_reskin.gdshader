// hex_reskin.gdshader: the world map's KayKit hexes reskinned toward the exterior's Octopath look (Raphael
// 2026-11-03: "Octopath reskin", then "make all the other land masses ... with new water / beach shore lines"). The
// pieces keep their shapes and their own atlas; each atlas cell they use is redrawn in world space: grass (0, 2) as
// muted patchy grass on top and layered earth on the sides, water (1, 1) as deep teal water, leaves (1, 2) as deep
// blue-green foliage with warm tops, bark (6, 0), sand (4, 2), packed earth (3, 2), grey rock (2, 2) and pale stone
// (1, 0) for the mountains, red-brown earth (2, 1) and dry earth (5, 0) for the hills; any other cell keeps the
// atlas, slightly muted.
// The shoreline (hex_look.gd sets `hex_mask`, one texel per hex, land white, sea black): a land tile paints a beach
// along each edge that faces the sea, a water tile paints shallows and a foam line along each edge that faces land,
// both wiggled by noise, so the coast runs on across tiles instead of stopping at KayKit's five coast pieces.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform sampler2D hex_mask : filter_nearest;
uniform vec2 mask_origin = vec2(0.0);      // the mask's first texel: (min col, min row)
uniform vec2 mask_size = vec2(1.0);        // texels: (cols, rows)
uniform vec3 map_origin = vec3(0.0);       // the generator's world position (tiles are placed relative to it)
uniform float shore_on = 0.0;
uniform float col_step = 2.0;
uniform float row_step = 2.0;
uniform float row_offset = 1.0;
uniform float beach_width = 0.5;
uniform float shallows_width = 0.75;
// a mountain piece's own material (hex_look.gd): craggy striated rock, scree at the foot, snow on the high ledges
uniform float mountain = 0.0;
uniform float snow_line = 1.45;            // metres above the map (the mountains are stretched up by hex_look.gd)
uniform vec3 crag_dark : source_color = vec3(0.26, 0.27, 0.3);
uniform vec3 crag_light : source_color = vec3(0.64, 0.62, 0.58);
uniform vec3 snow : source_color = vec3(0.88, 0.9, 0.95);
uniform vec3 grass_a : source_color = vec3(0.33, 0.43, 0.22);
uniform vec3 grass_b : source_color = vec3(0.23, 0.32, 0.18);
uniform vec3 grass_dry : source_color = vec3(0.48, 0.46, 0.27);
uniform vec3 soil : source_color = vec3(0.34, 0.27, 0.2);
uniform vec3 soil_dark : source_color = vec3(0.2, 0.16, 0.13);
uniform vec3 sand_dry : source_color = vec3(0.72, 0.64, 0.48);
uniform vec3 sand_wet : source_color = vec3(0.47, 0.42, 0.34);
uniform vec3 foliage_dark : source_color = vec3(0.07, 0.17, 0.15);
uniform vec3 foliage_light : source_color = vec3(0.24, 0.4, 0.27);
uniform vec3 foliage_warm : source_color = vec3(0.55, 0.55, 0.3);
uniform vec3 bark : source_color = vec3(0.2, 0.14, 0.1);
uniform vec3 rock_dark : source_color = vec3(0.3, 0.31, 0.32);
uniform vec3 rock_light : source_color = vec3(0.52, 0.52, 0.5);
uniform vec3 earth_red : source_color = vec3(0.4, 0.26, 0.19);
uniform vec3 water_deep : source_color = vec3(0.1, 0.22, 0.29);
uniform vec3 water_shallow : source_color = vec3(0.2, 0.37, 0.43);
uniform vec3 water_coast : source_color = vec3(0.3, 0.5, 0.5);
uniform vec3 foam : source_color = vec3(0.78, 0.84, 0.82);
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

// a hex's centre (map-local x, z) from its offset coords (col, row); odd rows shift by row_offset
vec2 hex_center(vec2 cr) {
	return vec2(cr.x * col_step + (abs(mod(cr.y, 2.0)) > 0.5 ? row_offset : 0.0), cr.y * row_step);
}

// the offset coords of the hex nearest a map-local point (x, z)
vec2 hex_at(vec2 p) {
	float r0 = floor(p.y / row_step + 0.5);
	vec2 best = vec2(0.0);
	float bd = 1e9;
	for (int k = -1; k <= 1; k++) {
		float r = r0 + float(k);
		float off = abs(mod(r, 2.0)) > 0.5 ? row_offset : 0.0;
		vec2 cr = vec2(floor((p.x - off) / col_step + 0.5), r);
		float d = distance(p, hex_center(cr));
		if (d < bd) {
			bd = d;
			best = cr;
		}
	}
	return best;
}

// 1 when the hex at offset coords cr is land, 0 for sea (and off the map)
float land_at(vec2 cr) {
	vec2 t = cr - mask_origin;
	if (t.x < 0.0 || t.y < 0.0 || t.x >= mask_size.x || t.y >= mask_size.y) {
		return 0.0;
	}
	return texture(hex_mask, (t + 0.5) / mask_size).r > 0.5 ? 1.0 : 0.0;
}

// metres from a map-local point to the nearest edge its hex shares with a hex of the other kind (land vs sea)
// (99 when it has none); `own` is the point's hex's kind
float shore_distance(vec2 p, out float own) {
	vec2 cr = hex_at(p);
	vec2 c = hex_center(cr);
	own = land_at(cr);
	float d = 99.0;
	vec2 dirs[6] = vec2[](vec2(col_step, 0.0), vec2(-col_step, 0.0), vec2(row_offset, row_step), vec2(-row_offset, row_step),
		vec2(row_offset, -row_step), vec2(-row_offset, -row_step));
	for (int i = 0; i < 6; i++) {
		vec2 nc = c + dirs[i];
		vec2 ncr = hex_at(nc);
		if (land_at(ncr) != own) {
			vec2 dir = normalize(dirs[i]);
			d = min(d, length(dirs[i]) * 0.5 - dot(p - c, dir));
		}
	}
	return d;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	vec2 cell = floor(UV * vec2(8.0, 4.0));
	vec3 n = normalize(world_nrm);
	vec3 lp = world_pos - map_origin;
	vec2 p = world_pos.xz;
	vec3 col = mix(vec3(dot(base, vec3(0.333))), base, 0.78) * 0.92;
	float rough = 0.88;
	float spec = 0.25;
	// the shore: only near the tiles' tops (a mountain's grass cap stays grass)
	float own = 1.0;
	float sd = 99.0;
	if (shore_on > 0.5 && lp.y < 0.25) {
		// the coast wanders: a slow wide wiggle and a quick small one, so the beach doesn't trace the hex edges
		sd = shore_distance(lp.xz, own) + (fbm(lp.xz * 0.45) - 0.5) * 0.7 + (noise(lp.xz * 3.0) - 0.5) * 0.12;
	}
	if (cell == vec2(0.0, 2.0) && mountain > 0.5 && lp.y > snow_line - 0.25) {
		// a mountain's high ledges: snow, a little blue in its hollows, thinning to grass at the snow line
		float cover = smoothstep(snow_line - 0.25, snow_line + 0.05, lp.y + (fbm(p * 1.7) - 0.5) * 0.3);
		vec3 sn = snow * mix(0.82, 1.0, fbm(p * 4.0)) * (n.y > 0.6 ? 1.0 : 0.85);
		col = mix(grass_b * 0.9, sn, cover);
		rough = 0.7;
		spec = 0.35;
	} else if (cell == vec2(0.0, 2.0)) {
		// grass: grass on top, layered earth on the sides; a beach where the hex meets the sea
		if (n.y > 0.6) {
			col = mix(grass_b, grass_a, smoothstep(0.35, 0.65, fbm(p * 0.18)));
			col = mix(col, grass_dry, smoothstep(0.6, 0.8, fbm(p * 0.11 + 17.0)) * 0.6);
			col *= mix(0.84, 1.07, fbm(p * 2.2));
		} else if (lp.y > -0.12) {
			col = grass_b * 0.85;   // a grassy lip over the side, so the gaps between rows don't read as dark trenches
		} else {
			float strata = fbm(vec2((world_pos.x + world_pos.z) * 1.4, world_pos.y * 9.0));
			col = mix(mix(soil_dark, soil, strata), grass_b, 0.3) * mix(0.75, 1.0, clamp(lp.y + 0.5, 0.0, 1.0));
		}
		if (sd < beach_width) {
			float wet = 1.0 - smoothstep(0.04, 0.16, sd);
			vec3 sand = mix(sand_dry, sand_wet, wet) * mix(0.9, 1.05, noise(p * 9.0));
			col = mix(col, sand, 1.0 - smoothstep(beach_width - 0.12, beach_width, sd));
		}
	} else if (cell == vec2(1.0, 1.0)) {
		// water: deep teal, slow ripples; shallows and a foam line along the land's edges
		float n1 = noise(p * vec2(0.6, 0.25) + vec2(0.0, TIME * 0.12));
		float n2 = noise(p * vec2(1.6, 0.7) + vec2(TIME * 0.08, TIME * 0.2));
		col = mix(water_deep, water_shallow, n1 * 0.7);
		float ripple = smoothstep(0.72, 0.8, n2) * (1.0 - smoothstep(0.8, 0.9, n2));
		col = mix(col, ripple_light, ripple * 0.14);
		if (own < 0.5 && sd < shallows_width) {
			col = mix(col, water_coast, 1.0 - smoothstep(0.0, shallows_width, sd));
			float wave = 0.06 + 0.03 * sin(TIME * 1.3 + fbm(p * 0.8) * 6.0);
			col = mix(col, foam, (1.0 - smoothstep(wave * 0.5, wave, sd)) * 0.8);
		}
		if (n.y <= 0.6) {
			col *= 0.6;
		}
		rough = 0.45;   // a soft sheen, no sun glint at map scale
		spec = 0.3;
	} else if (cell == vec2(1.0, 2.0)) {
		float shade = dot(base, vec3(0.299, 0.587, 0.114));
		float leaf = fbm(world_pos.xz * 3.0 + vec2(world_pos.y * 2.0));
		col = mix(foliage_dark, foliage_light, clamp(shade * 1.7 - 0.25 + (leaf - 0.5) * 0.4, 0.0, 1.0));
		col = mix(col, foliage_warm, smoothstep(0.7, 1.0, n.y) * 0.22);
		rough = 0.9;
	} else if (cell == vec2(6.0, 0.0)) {
		col = bark * mix(0.8, 1.1, noise(vec2(world_pos.y * 12.0, world_pos.x + world_pos.z)));
	} else if (cell == vec2(4.0, 2.0)) {
		col = mix(sand_dry, sand_wet, 0.3) * mix(0.9, 1.05, noise(p * 9.0));
	} else if (cell == vec2(3.0, 2.0) || cell == vec2(5.0, 0.0)) {
		col = mix(soil, sand_wet, 0.35) * mix(0.82, 1.05, fbm(p * 3.0));
	} else if ((cell == vec2(2.0, 2.0) || cell == vec2(1.0, 0.0)) && mountain > 0.5) {
		// a mountain's crags: vertical striations and dark cracks, KayKit's gradient as the light, scree dark at the foot,
		// snow dusting the flat tops above the snow line
		float shade = dot(base, vec3(0.299, 0.587, 0.114));
		float stri = fbm(vec2((world_pos.x + world_pos.z) * 2.6, world_pos.y * 0.7));
		float crack = 1.0 - smoothstep(0.0, 0.05, abs(noise(vec2((world_pos.x - world_pos.z) * 3.5, world_pos.y * 0.9)) - 0.5));
		col = mix(crag_dark, crag_light, clamp(shade * 1.35 - 0.25 + (stri - 0.5) * 0.6, 0.0, 1.0));
		col *= 1.0 - crack * 0.5;
		col *= mix(0.72, 1.0, smoothstep(0.0, 0.7, lp.y));
		col = mix(col, snow, smoothstep(0.75, 0.95, n.y) * smoothstep(snow_line - 0.3, snow_line, lp.y));
		rough = 0.92;
	} else if (cell == vec2(2.0, 2.0) || cell == vec2(1.0, 0.0)) {
		// rock (single rocks): KayKit's gradient as the light, cool grey strata, a little moss on flat ledges
		float shade = dot(base, vec3(0.299, 0.587, 0.114));
		float strata = fbm(vec2((world_pos.x - world_pos.z) * 0.8, world_pos.y * 6.0));
		col = mix(rock_dark, rock_light, clamp(shade * 1.2 - 0.15 + (strata - 0.5) * 0.35, 0.0, 1.0));
		col = mix(col, grass_b, smoothstep(0.8, 0.95, n.y) * 0.35);
	} else if (cell == vec2(2.0, 1.0)) {
		col = mix(soil_dark, earth_red, fbm(vec2((world_pos.x + world_pos.z) * 1.2, world_pos.y * 8.0)));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
