// Loot light pillar over a weapon crate: a soft additive column in the weapon's colour with
// streaks rising through it (baked noise, no sin-hash), fading out towards the top and the rims.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float strength = 0.9;

void fragment() {
	// CylinderMesh sides: UV.y 0 at the top, 0.5 at the bottom (Godot keeps 0.5..1 for caps).
	float up = clamp(1.0 - UV.y * 2.0, 0.0, 1.0);
	float t = mod(TIME, 4.0) * 0.25;     // exactly one texture repeat per 4 s: seamless
	float n = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 0.7 + t)).r;
	float streak = smoothstep(0.35, 0.85, n);
	float fade = pow(1.0 - up, 1.6) * smoothstep(0.0, 0.06, up);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 1.5);
	float a = fade * core * (0.45 + 0.75 * streak) * strength;
	ALBEDO = color.rgb * a;
}
