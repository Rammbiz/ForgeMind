// Space dust / distant glints: camera-facing additive sprites (MultiMesh, instance colour)
// that twinkle slowly. The sprite is a soft core with a faint cross flare.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 1.4;
varying float phase;

void vertex() {
	phase = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 0.53 + MODEL_MATRIX[3].y;
	// Billboard: keep the instance scale, face the camera.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float core = exp(-r * r * 18.0);
	float halo = exp(-r * 4.5) * 0.35;
	float flare = (exp(-abs(q.x) * 30.0) + exp(-abs(q.y) * 30.0)) * exp(-r * 3.0) * 0.5;
	float t = mod(TIME, 62.831853);
	float tw = 0.65 + 0.35 * sin(t * 2.0 + phase);
	ALBEDO = COLOR.rgb * (core + halo + flare) * energy * tw;
}
