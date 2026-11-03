// ext_building.gdshader: the KayKit village buildings with their windows lit at dusk and night (the exterior look;
// brainstorm #29, the Octopath shot's warm windows). The buildings' own atlas texture, and emission on the atlas cell
// their window glass uses (found 2026-11-03: the one cell every house uses only on small vertical faces), scaled by
// window_glow (exterior_look.gd sets it per day phase).
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D atlas : source_color, filter_linear_mipmap;
// the window cell's UV rectangle (u0, v0, u1, v1)
uniform vec4 window_cell = vec4(0.625, 0.0, 0.75, 0.25);
uniform vec3 window_light : source_color = vec3(1.0, 0.64, 0.32);
uniform float window_glow = 0.0;

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float w = step(window_cell.x, UV.x) * step(UV.x, window_cell.z) * step(window_cell.y, UV.y) * step(UV.y, window_cell.w);
	float lit = w * clamp(window_glow, 0.0, 1.0);
	ALBEDO = mix(c, window_light * 0.7, lit * 0.6);
	EMISSION = window_light * w * window_glow * 1.6;
	ROUGHNESS = mix(0.85, 0.3, lit);
	SPECULAR = 0.3;
}
