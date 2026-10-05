// Planet ring: a flat disc shaded into fine dusty bands; the inner hole and the outer edge
// are cut by radius. Unshaded, alpha-blended (far away, so the overdraw is small).
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.7, 0.9, 1.0);
uniform vec4 color_b : source_color = vec4(0.6, 0.5, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float inner = 0.62;
uniform float alpha = 0.7;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float k = clamp((r - inner) / (1.0 - inner), 0.0, 1.0);
	float bands = texture(noise_tex, vec2(k * 0.9, 0.37)).r;
	float fine = texture(noise_tex, vec2(k * 3.1, 0.71)).r;
	float a = smoothstep(0.0, 0.06, k) * smoothstep(1.0, 0.9, k);
	a *= smoothstep(0.25, 0.7, bands * 0.6 + fine * 0.4) * 0.85 + 0.15;
	if (r < inner || r > 1.0) {
		discard;
	}
	ALBEDO = mix(color_b.rgb, color.rgb, smoothstep(0.3, 0.75, fine));
	ALPHA = a * alpha;
}
