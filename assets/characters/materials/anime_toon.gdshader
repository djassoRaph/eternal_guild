// anime_toon.gdshader — the anime cast's toon shading for the darker look presets (anime_look.gd; the "approved"
// preset keeps its StandardMaterial3D toon copies and never uses this shader).
//
// What the toon StandardMaterial3D draws, with the shadow side and the band made tunable:
// - the light band: smoothstep(band_threshold - band_softness, band_threshold + band_softness, N·L) × each
//   light, × lit_gain. band_threshold 0, band_softness 0.12 (TOON_BAND), lit_gain 1 = DIFFUSE_TOON's band;
// - the shadow side: the albedo, desaturated by shadow_desaturate and tinted by shadow_tint, lit by the scene's
//   ambient × shadow_level plus shadow_fill × each light (a toon shadow colour: 0 = the approved look, where an
//   unlit pixel gets the ambient only, which in the tavern is nearly black). A lit pixel still shows its own
//   albedo: the light band is divided by the same tint, so only the dark side changes colour;
// - no specular, no metal, opaque. ROUGHNESS is written (> 0) because the edge pass inks only what has a
//   roughness above 0 in the normal-roughness buffer. The ink hull is the material's next_pass (anime_look.gd).
// anime_look.gd fills every uniform from the source material (albedo, its texture and filter, UV1, vertex
// colour, emission) and from the preset's numbers (game_config.json › anime_look_presets).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
// One sampler per filter (a sampler's filter is fixed at compile time): the palette atlas is nearest, the face is
// linear (both mipmapped, like the imported materials).
uniform sampler2D albedo_nearest : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform sampler2D albedo_linear : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool albedo_use_linear = false;
uniform bool use_vertex_color = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
// Emission, as the source material has it (StandardMaterial3D's: (colour + texture) × energy, or colour × texture × energy
// with the multiply operator; energy 0 = none).
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool emission_add = true;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

// The look (preset numbers).
uniform float band_threshold = 0.0;
uniform float band_softness = 0.12;
uniform float lit_gain = 1.0;
uniform float shadow_level = 1.0;
uniform float shadow_fill = 0.0;
uniform vec3 shadow_tint = vec3(1.0);
uniform float shadow_desaturate = 0.0;
uniform float ink_roughness = 0.12;

varying vec3 v_lit_gain;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 tex = albedo_use_linear ? texture(albedo_linear, UV) : texture(albedo_nearest, UV);
	vec3 base = albedo_color.rgb * tex.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 shade = mix(base, vec3(luma), clamp(shadow_desaturate, 0.0, 1.0)) * shadow_tint;
	ALBEDO = shade;
	// The lit band shows the base colour: divide the shadow's tint back out (bounded: shade >= (1 - d) * tint * base).
	v_lit_gain = base / max(shade, vec3(1e-4));
	AO = clamp(shadow_level, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = max(ink_roughness, 0.01);
	vec3 etex = texture(emission_texture, UV).rgb;
	EMISSION = (emission_add ? emission_color.rgb + etex : emission_color.rgb * etex) * emission_energy;
}

void light() {
	float soft = max(band_softness, 0.005);
	float band = smoothstep(band_threshold - soft, band_threshold + soft, dot(NORMAL, LIGHT));
	vec3 k = band * v_lit_gain + (1.0 - band) * clamp(shadow_fill, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * lit_gain * k / PI;
}
