// kit_roof.gdshader — Story 25.35: a kit building's roof tiles in their own colour. The Quaternius tile texture is
// terracotta; multiplying it can never make a blue or green roof, so this greys it first (keep_hue of its own colour
// left), then tints it by roof_color (the building's "roof_tint" metadata, picked by tools/exterior/gen_town.py).
// Toon-shaded like the rest of the kit town (exterior_look.gd apply_kit).
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform vec4 roof_color : source_color = vec4(0.62, 0.40, 0.46, 1.0);
uniform float keep_hue : hint_range(0.0, 1.0) = 0.12;
uniform float brightness = 1.7;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

void fragment() {
	vec2 uv = UV * uv1_scale.xy + uv1_offset.xy;
	vec3 t = texture(albedo_tex, uv).rgb;
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), t, keep_hue) * roof_color.rgb * brightness;
	ROUGHNESS = 1.0;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
	}
}
