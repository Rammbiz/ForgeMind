// Streaks (Effects): projectile trails, volley lines, laser darts and velocity-stretched
// sparks, all in one additive MultiMesh. Each instance is a unit quad along local Z whose
// transform carries the streak: the Z column is the length (head at local -Z), the length of
// the X column is the width. The quad is widened across the view so it always faces the
// camera. Instance COLOR = tint (rgb) and intensity (a). Hot white core near the head.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform float energy = 2.0;

void vertex() {
	float w = length(MODEL_MATRIX[0].xyz);
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 axis = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	vec3 side = cross(axis, c);
	float sl = length(side);
	side = sl > 1e-6 ? side / sl : vec3(1.0, 0.0, 0.0);
	VERTEX = c + side * VERTEX.x * w;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float along = UV.y;
	float glow = exp(-across * across * 2.6);
	float hot = exp(-across * across * 16.0);
	float tail = pow(clamp(1.0 - along, 0.0, 1.0), 1.3);
	float tip = smoothstep(0.0, 0.07, along);
	vec3 c = COLOR.rgb * glow + vec3(1.0) * hot * (0.35 + 0.65 * smoothstep(0.7, 0.0, along));
	ALBEDO = c * tail * tip * energy * COLOR.a;
}
