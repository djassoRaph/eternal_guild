// fire_glow.gdshader (Story 25.5): opaque low-poly flames and sparks for particle draw passes.
// The particle colour (color ramp) becomes emission; roughness 0 keeps the ink outline off, so the
// fire reads as light, not ink (08 §1 build contract). Opaque on purpose: transparent meshes need
// render_priority >= 1 to survive the EdgeQuad, opaque ones just work.
shader_type spatial;

uniform float glow = 2.2;

void fragment() {
	ALBEDO = vec3(0.0);
	EMISSION = COLOR.rgb * glow;
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
}
