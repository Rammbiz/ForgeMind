// Rarity light pillar (Legendary+ tell on a Cache, §5.6/§5.7): a tall additive column in the
// rarity colour with a white core, streaks rising through it (baked noise) and a soft top
// fade. CylinderMesh sides (UV.y 0 at the top, 0.5 at the bottom). Fade with `strength`; TIME
// is wrapped so one noise repeat = one wrap.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.71, 0.18, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float strength = 1.0;

void fragment() {
	float up = clamp(1.0 - UV.y * 2.0, 0.0, 1.0);
	float t = mod(TIME, 2.0) * 0.5;
	float n = texture(noise_tex, vec2(UV.x * 3.0, UV.y * 0.5 + t)).r;
	float streak = smoothstep(0.4, 0.9, n);
	float top = 1.0 - up;
	float fade = top * top * smoothstep(0.0, 0.04, up);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = facing * facing * facing;
	vec3 c = color.rgb * (0.35 + 0.9 * streak) * facing + vec3(1.0) * core * core * 0.6;
	ALBEDO = c * fade * strength;
}
