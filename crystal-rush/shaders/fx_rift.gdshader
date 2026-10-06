// Seer's ult "Star Rift" (Effects.rift_open): mode 0 = the tear on the road (a jagged white-violet
// crack with a soft glow and drifting star dust), mode 1 = the slow-time curtain standing over
// it (violet streaks rising, fading upwards and at the sides). Additive; `k` 0..1 opens / fades
// it; `t` is wrapped time from the script (no TIME, no sin-hash noise).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 1.0, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float k = 1.0;
uniform float t = 0.0;
uniform int mode = 0;
uniform float energy = 1.6;

void fragment() {
	vec2 uv = UV;
	float side = smoothstep(0.0, 0.14, uv.x) * smoothstep(1.0, 0.86, uv.x);
	if (mode == 0) {
		float n = texture(noise_tex, vec2(uv.x * 1.7 + t * 0.03, 0.31)).r;
		float n2 = texture(noise_tex, uv * vec2(3.0, 1.2) + vec2(-t * 0.07, t * 0.05)).r;
		float n3 = texture(noise_tex, uv * vec2(9.0, 3.5) + vec2(t * 0.11, -t * 0.04)).r;
		float y = (uv.y - 0.5) + (n - 0.5) * 0.42 * k;
		float open = mix(0.01, 0.05, k);
		float ay = abs(y);
		float line = exp(-ay * ay / (open * open * 0.3));
		float glow = exp(-ay * 6.0);
		float dust = smoothstep(0.78, 0.95, n3) * exp(-ay * 4.0);
		vec3 c = color.rgb * glow * (0.55 + 0.6 * n2) + core.rgb * line * 1.6 + gold.rgb * dust * 0.9;
		ALBEDO = c * side * k * energy;
	} else {
		float rise = texture(noise_tex, vec2(uv.x * 4.0, uv.y * 0.6 + t * 0.35)).r;
		float rise2 = texture(noise_tex, vec2(uv.x * 9.0 + 0.37, uv.y * 1.1 + t * 0.6)).r;
		float up = 1.0 - uv.y;          // 1 at the bottom
		float base = up * up * up;
		float streak = smoothstep(0.55, 0.85, rise) * up;
		float spark = smoothstep(0.86, 0.97, rise2) * up;
		vec3 c = color.rgb * (base * 0.55 + streak * 0.6) + core.rgb * spark * 0.8;
		ALBEDO = c * side * k * energy * 0.7;
	}
}
