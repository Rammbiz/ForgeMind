// Persistent laser beam (Effects.beam): a camera-facing ribbon from the emitter (local +Z
// end) to the target (local -Z end) with a white-hot core, a coloured sheath and energy
// knots racing along it. `intensity` fades it in and out; `beam_length` keeps the knots at a
// fixed world spacing. TIME is wrapped to 10 s; rates make whole cycles per wrap.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float beam_length = 5.0;
uniform float energy = 2.2;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

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
	float t = mod(TIME, 10.0);
	float across = abs(UV.x - 0.5) * 2.0;
	float along = UV.y * beam_length;
	float wob = 0.85 + 0.15 * sin(t * 37.699112 + along * 3.0);
	float sheath = exp(-across * across * 3.2 / wob);
	float core = exp(-across * across * 26.0);
	float n = texture(noise_tex, vec2(along * 0.18 + t * 1.2, UV.x * 0.5)).r;
	float knots = smoothstep(0.55, 0.85, n);
	float ends = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.97, UV.y);
	vec3 c = color.rgb * sheath * (0.55 + knots * 0.9) + vec3(1.0) * core * (0.9 + knots * 0.5);
	ALBEDO = c * ends * intensity * energy;
}
