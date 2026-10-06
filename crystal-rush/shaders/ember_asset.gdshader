// A Meshy model whose hot orange/amber details (windows, vents, lines) glow; everything else
// keeps the model's texture and lighting.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float glow = 2.2;
uniform float flicker = 0.0;   // 0..1, driven by damage

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	// Amber in linear space: strong red, clear green, little blue (the red plates have almost
	// no green, so they stay unlit).
	float amber = smoothstep(0.35, 0.6, c.r) * smoothstep(0.08, 0.2, c.g) * (1.0 - smoothstep(0.12, 0.3, c.b));
	ALBEDO = c;
	float f = 1.0 - flicker * 0.5 * (0.5 + 0.5 * sin(mod(TIME, 6.2831853) * 23.0));
	EMISSION = c * amber * glow * f;
	ROUGHNESS = mix(0.7, 0.35, amber);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
