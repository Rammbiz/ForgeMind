// Seer's ult "Star Rift" (Effects.rift_open). mode 0: a tear in the road that opens onto a
// starry void - a lens of deep violet night with star specks, a white-hot jagged rim, a violet
// and gold glow spilling onto the road. mode 1: the slow-time curtain over it (violet streaks
// rising, fading upwards and at the sides). `k` 0..1 opens / fades it; `t` is wrapped time
// from the script (no TIME, no sin-hash noise, no pow of negatives).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 color : source_color = vec4(0.62, 0.28, 1.0, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 1.0, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.78, 0.38, 1.0);
uniform vec4 void_col : source_color = vec4(0.05, 0.02, 0.13, 1.0);
uniform float k = 1.0;
uniform float t = 0.0;
uniform int mode = 0;

void fragment() {
	vec2 uv = UV;
	if (mode == 0) {
		float x = uv.x * 2.0 - 1.0;                  // -1..1 across the road
		float lens = max(1.0 - x * x, 0.0);           // fattest in the middle
		float jag = texture(noise_tex, vec2(uv.x * 2.3 + t * 0.02, 0.37)).r - 0.5;
		float y = (uv.y - 0.5) + jag * 0.16;
		float half_w = (0.04 + 0.2 * lens) * k;
		float ay = abs(y);
		float inside = 1.0 - smoothstep(half_w - 0.015, half_w, ay);
		float rim_d = (ay - half_w) / 0.022;
		float rim = exp(-rim_d * rim_d) * smoothstep(0.0, 0.25, lens);
		float spill = exp(-max(ay - half_w, 0.0) * 6.0) * (0.35 + 0.65 * lens);
		// The void: drifting star specks and a slow nebula swirl.
		float st = texture(noise_tex, uv * vec2(7.0, 5.0) + vec2(t * 0.05, -t * 0.03)).r;
		float st2 = texture(noise_tex, uv * vec2(13.0, 9.0) - vec2(t * 0.07, 0.0)).r;
		float neb = texture(noise_tex, uv * vec2(2.0, 1.6) + vec2(-t * 0.04, t * 0.06)).r;
		vec3 v = void_col.rgb + color.rgb * neb * 0.35 + vec3(1.0) * smoothstep(0.86, 0.95, st) + gold.rgb * smoothstep(0.9, 0.97, st2);
		vec3 glow = mix(color.rgb, gold.rgb, smoothstep(0.55, 0.85, neb) * 0.35);
		vec3 c = mix(glow * 1.4, v, inside);
		c = mix(c, core.rgb * 1.5, rim * (1.0 - inside * 0.5));
		float a = max(inside, max(rim, spill * 0.75));
		float side = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
		ALBEDO = c;
		ALPHA = clamp(a * side * k, 0.0, 1.0);
	} else {
		float rise = texture(noise_tex, vec2(uv.x * 4.0, uv.y * 0.6 + t * 0.35)).r;
		float rise2 = texture(noise_tex, vec2(uv.x * 9.0 + 0.37, uv.y * 1.1 + t * 0.6)).r;
		float up = 1.0 - uv.y;                        // 1 at the bottom
		float base = up * up * up;
		float streak = smoothstep(0.5, 0.85, rise) * up;
		float spark = smoothstep(0.86, 0.97, rise2) * up;
		float side2 = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
		ALBEDO = mix(color.rgb * 1.3, core.rgb * 1.4, spark);
		ALPHA = clamp((base * 0.6 + streak * 0.65 + spark * 0.9) * side2 * k, 0.0, 1.0);
	}
}
