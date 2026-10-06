// The owner's Meshy machines and weapon crate (WeaponModels): the model's own texture, with a
// premium surface read from the albedo (gold texels metallic and glossy, white enamel glossy,
// dark rubber matte) and the ice-crystal texels recoloured towards `crystal_color` (a family
// accent or a crate rarity, `crystal_mix` 0 keeps the owner's ice blue) and glowing.
// Crate only (`use_cracks`): `damage` spreads cracks over the crystals, `flash` whitens the
// whole crate on a hit. No TIME, no noise maths: two texture reads of noise_tex for cracks.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 crystal_color : source_color = vec4(0.36, 0.82, 1.0, 1.0);
uniform float crystal_mix : hint_range(0.0, 1.0) = 0.0;
uniform float crystal_glow = 0.9;
uniform float gold_metal : hint_range(0.0, 1.0) = 0.7;
uniform bool use_cracks = false;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = hi - lo;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// Ice crystal: blue and green clearly above red (linear colour). Gold and white stay out.
	float cry = smoothstep(0.08, 0.22, min(c.b - c.r, c.g - c.r + 0.1)) * smoothstep(0.12, 0.3, hi);
	// Gold trim: red over green over blue, saturated.
	float gold = smoothstep(0.12, 0.3, c.r - c.b) * smoothstep(-0.02, 0.04, c.g - c.b) * (1.0 - cry);
	// White enamel: bright, unsaturated.
	float white = smoothstep(0.4, 0.68, lum) * (1.0 - smoothstep(0.06, 0.18, sat)) * (1.0 - cry);
	vec3 tinted = crystal_color.rgb * (0.38 + lum * 1.25);
	vec3 crystal = mix(c, tinted, crystal_mix);
	vec3 alb = mix(c, crystal, cry);
	vec3 emit = crystal * cry * crystal_glow * (0.45 + lum * 0.8);
	if (use_cracks) {
		vec2 cuv = UV * 3.0;
		float n = texture(noise_tex, cuv).r;
		float n2 = texture(noise_tex, cuv * 2.3 + vec2(0.37)).r;
		float crack = (1.0 - smoothstep(0.0, 0.03, abs(n - 0.5))) * step(n2, damage * 1.1) * (0.35 + 0.65 * cry);
		alb = mix(alb, vec3(1.0), crack);
		emit += vec3(0.9, 0.97, 1.0) * crack * 1.6;
	}
	alb = mix(alb, vec3(1.0), flash * 0.45);
	emit += vec3(0.75, 0.9, 1.0) * flash * 0.7;
	ALBEDO = alb;
	METALLIC = gold * gold_metal;
	ROUGHNESS = mix(mix(mix(0.78, 0.36, white), 0.3, gold), 0.14, cry);
	SPECULAR = 0.5 + 0.25 * white;
	EMISSION = emit;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
