// Smoke puffs (Effects): rocket trails and explosion smoke. One alpha-blended MultiMesh of
// camera-facing quads with a soft noisy edge, lit from above in a cheap way.
// Instance COLOR = colour and opacity; INSTANCE_CUSTOM.x = noise offset, .y = rotation.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec2 custom;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	custom = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float cs = cos(custom.y);
	float sn = sin(custom.y);
	vec2 rq = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	float n = texture(noise_tex, rq * 0.35 + vec2(custom.x, custom.x * 0.7)).r;
	float r = length(q) + (n - 0.5) * 0.55;
	float a = 1.0 - smoothstep(0.35, 0.95, r);
	float light = 0.75 + 0.45 * clamp(-q.y * 0.8 + n * 0.4, 0.0, 1.0);
	ALBEDO = COLOR.rgb * light;
	ALPHA = a * COLOR.a;
}
