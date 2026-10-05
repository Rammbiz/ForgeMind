// Floating crystals (MultiMesh, instance colour): a dim body with a bright facet rim and an
// inner glow that breathes slowly per instance. Bloom does the rest.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform float energy = 1.6;
uniform float body = 0.35;
varying float phase;

void vertex() {
	phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.11;
}

void fragment() {
	float t = mod(TIME, 62.831853);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float breathe = 0.75 + 0.25 * sin(t * 1.0 + phase);
	ALBEDO = COLOR.rgb * body;
	ROUGHNESS = 0.18;
	SPECULAR = 0.8;
	EMISSION = COLOR.rgb * energy * (0.35 + fres * fres * 1.4) * breathe;
}
