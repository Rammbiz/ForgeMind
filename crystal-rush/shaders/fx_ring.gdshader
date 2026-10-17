// Ground shockwave (Effects.shockwave): a bright ring racing outwards on a flat quad with a
// soft inner wash and a noisy rim, fading as it grows. Additive. `progress` 0..1.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float progress = 0.0;
uniform float energy = 2.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float p = clamp(progress, 0.0, 1.0);
	float e = 1.0 - pow(1.0 - p, 3.0);
	float rad = mix(0.08, 0.94, e);
	float w = mix(0.035, 0.11, p);
	float rd = (r - rad) / w;             // squared by hand: pow() of a negative base is undefined
	float ring = exp(-rd * rd);
	float n = texture(noise_tex, vec2(atan(q.y, q.x) * 0.48, r * 0.6 - p * 0.8)).r;
	float inner = (1.0 - smoothstep(0.0, rad, r)) * (r < rad ? 1.0 : 0.0) * 0.22;
	float fade = 1.0 - p;
	vec3 c = color.rgb * (ring * (0.6 + 0.8 * n) + inner * (0.5 + n)) + vec3(1.0) * ring * ring * 0.6 * fade;
	ALBEDO = c * fade * energy;
}
