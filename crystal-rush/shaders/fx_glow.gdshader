// Glow sprites (Effects): flashes, muzzle flares, projectile heads, beam ends. One additive
// MultiMesh of camera-facing quads. Instance COLOR = tint × intensity (a);
// INSTANCE_CUSTOM.x = flare amount (4-point star rays), .y = flare rotation (radians),
// .z = core whiteness.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 1.8;
varying vec3 custom;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float halo = (exp(-r * 4.0) * 0.8 + exp(-r * r * 9.0) * 0.6) * (1.0 - smoothstep(0.7, 1.0, r));
	float core = exp(-r * r * 16.0);
	float cs = cos(custom.y);
	float sn = sin(custom.y);
	vec2 rq = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	float rays = (exp(-abs(rq.x) * 26.0) + exp(-abs(rq.y) * 26.0)) * (1.0 - smoothstep(0.2, 1.0, r));
	vec3 c = COLOR.rgb * (halo + rays * custom.x) + vec3(1.0) * core * custom.z;
	ALBEDO = c * energy * COLOR.a;
}
