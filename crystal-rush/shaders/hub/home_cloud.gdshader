// Home stage cloud puff (UI v2): a soft painterly cumulus on a camera-facing quad; lit warm
// white on top, lilac-grey underneath, a feathered edge from the cloud noise. Unshaded and
// fog-aware so far puffs melt into the haze.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 lit : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 shade : source_color = vec4(0.80, 0.80, 0.90, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.88, 0.74, 1.0);
uniform float seed = 0.0;
uniform float alpha = 0.95;

void vertex() {
	// Billboard (keep the quad upright: spherical facing is enough for distant puffs).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 s = UV * vec2(1.6, 1.0) + vec2(seed * 0.37, seed * 0.11);
	float n1 = texture(noise_tex, s * 0.55).r;
	float n2 = texture(noise_tex, s * 1.4 + vec2(n1 * 0.2, 0.0)).r;
	// Flat-bottomed, billowy-topped blob.
	float bottom = smoothstep(0.55, 0.2, p.y + n2 * 0.15);
	float body = 1.0 - length(p * vec2(0.85, 1.25 + 0.4 * step(0.0, p.y)));
	float d = body + (n1 * 0.5 + n2 * 0.5 - 0.5) * 0.75;
	float a = smoothstep(0.0, 0.28, d) * bottom;
	float top_k = smoothstep(0.35, -0.6, p.y) * (0.6 + 0.4 * n2);
	vec3 col = mix(shade.rgb, lit.rgb, clamp(top_k + d * 0.4, 0.0, 1.0));
	col = mix(col, warm.rgb, 0.25 * smoothstep(0.2, -0.6, p.y));
	ALBEDO = col;
	ALPHA = a * alpha;
}
