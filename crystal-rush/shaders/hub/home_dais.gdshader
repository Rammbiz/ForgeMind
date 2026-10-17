// The owner's hero dais on the bright Home terrace (UI v2): the same texture classes as
// asset_altar (gold trim, ice/rune crystals, violet gems) but the navy stone is re-glazed as
// warm ivory marble (keeping the texture's carving as shading), the gold is lifted, and the
// crystal ring glows in the hero's gem colour (`rune_color`, breathing with `pulse`).
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 rune_color : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform vec4 ivory : source_color = vec4(0.95, 0.92, 0.86, 1.0);
uniform vec4 gold_tint : source_color = vec4(0.98, 0.8, 0.48, 1.0);
uniform float stone_k : hint_range(0.0, 1.0) = 0.9;
uniform float rune_k = 0.6;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float rune = smoothstep(0.1, 0.24, c.b - c.r) * smoothstep(-0.06, 0.06, c.g - c.r) * smoothstep(0.16, 0.34, hi);
	float gem = smoothstep(0.06, 0.16, min(c.r, c.b) - c.g) * smoothstep(0.08, 0.2, hi) * (1.0 - rune);
	float gold = smoothstep(0.12, 0.3, c.r - c.b) * smoothstep(-0.02, 0.04, c.g - c.b) * (1.0 - rune);
	float stone = clamp(1.0 - rune - gem - gold, 0.0, 1.0);
	// Ivory re-glaze: the stone's own value (carving, cracks) becomes the marble's shading.
	float shade = clamp(0.62 + lum * 1.6, 0.55, 1.08);
	vec3 marble = ivory.rgb * shade;
	vec3 goldc = mix(c, gold_tint.rgb * (0.55 + lum * 0.9), 0.55);
	float k = rune_k * (0.85 + 0.3 * pulse);
	vec3 runec = rune_color.rgb * (0.55 + lum * 0.6);
	vec3 alb = c;
	alb = mix(alb, marble, stone * stone_k);
	alb = mix(alb, goldc, gold);
	alb = mix(alb, mix(runec, vec3(1.0), 0.25), rune);
	alb = mix(alb, rune_color.rgb * (0.4 + lum), gem);
	ALBEDO = alb;
	METALLIC = gold * 0.3;
	ROUGHNESS = mix(mix(0.42, 0.3, gold), 0.15, max(rune, gem));
	SPECULAR = 0.4;
	EMISSION = runec * rune * (0.35 + 1.6 * k) + gold_tint.rgb * gold * 0.08 + rune_color.rgb * gem * 0.6;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
