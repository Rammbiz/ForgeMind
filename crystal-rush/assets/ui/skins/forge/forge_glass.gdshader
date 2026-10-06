// «Кришталева кузня» glass shard fill: the screen behind, blurred (manual taps: the
// Compatibility renderer has no screen mipmaps), refracted a little by noise, then buried
// under a dark tinted core (>= 85% opaque so text stays legible) with slow caustic streaks.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.055, 0.07, 0.2, 1.0);
uniform vec4 tint_top : source_color = vec4(0.11, 0.13, 0.33, 1.0);
uniform float tint_k = 0.86;
uniform float blur_px = 9.0;
uniform float refract_px = 6.0;
uniform float streak_k = 1.0;
uniform vec2 box_pos = vec2(0.0);
uniform vec2 box_size = vec2(400.0, 300.0);
uniform vec4 streak_color : source_color = vec4(0.55, 0.85, 1.0, 1.0);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 n = texture(noise_tex, lp / 260.0).rg - 0.5;
	vec2 base = SCREEN_UV + n * refract_px * px;
	vec3 acc = vec3(0.0);
	float w = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec2 o = vec2(float(i), float(j)) * blur_px * 0.5;
			float k = exp(-dot(o, o) / (blur_px * blur_px));
			acc += texture(screen_tex, base + o * px).rgb * k;
			w += k;
		}
	}
	vec3 behind = acc / w;
	vec2 uv = clamp((lp - box_pos) / box_size, 0.0, 1.0);
	// Lit from the top-left: the core is lighter there, deeper bottom-right.
	float g = clamp(uv.y * 0.75 + uv.x * 0.25, 0.0, 1.0);
	vec3 core = mix(tint_top.rgb, tint.rgb, smoothstep(0.0, 0.85, g));
	vec3 c = mix(behind, core, tint_k);
	// Caustic streaks: thin diagonal bands drifting slowly.
	float d = (lp.x * 0.62 + lp.y);
	float s1 = 1.0 - smoothstep(0.0, 0.035, abs(fract(d / 520.0 + TIME * 0.012) - 0.5));
	float s2 = 1.0 - smoothstep(0.0, 0.012, abs(fract(d / 310.0 - TIME * 0.008 + 0.3) - 0.5));
	c += streak_color.rgb * (s1 * 0.055 + s2 * 0.035) * streak_k;
	COLOR = vec4(c, COLOR.a);
}
