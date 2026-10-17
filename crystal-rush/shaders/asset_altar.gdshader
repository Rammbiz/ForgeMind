// The owner's Crystal Altar (CacheModels.altar) and hub hero dais (HubShowcase / HubStage):
// the model's own texture, with gold trim glossy metal, marble / enamel glossy, and two glow
// classes read from the albedo:
//   runes - blue / ice-cyan texels (the altar's rune band, the dais's crystal ring): they take
//           `rune_color` and glow with `rune_k` (CacheModels.altar_light drives it: ~0.4 idle,
//           1.0 in the tell colour);
//   gems  - violet texels (the altar's amethyst pillars): they glow, leaning towards
//           `rune_color` by `gem_tint`.
// `pulse` 0..1 adds a soft breathing (the caller animates it; no TIME here).
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 rune_color : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float rune_k = 0.4;
uniform float rune_mix : hint_range(0.0, 1.0) = 0.6;
uniform float gem_tint : hint_range(0.0, 1.0) = 0.3;
uniform float gem_k = 0.5;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = hi - lo;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// Runes / ice: blue clearly above red, green near or above red (cyan to azure).
	float rune = smoothstep(0.1, 0.24, c.b - c.r) * smoothstep(-0.06, 0.06, c.g - c.r) * smoothstep(0.16, 0.34, hi);
	// Gems: violet (red and blue both above green).
	float gem = smoothstep(0.06, 0.16, min(c.r, c.b) - c.g) * smoothstep(0.08, 0.2, hi) * (1.0 - rune);
	float gold = smoothstep(0.12, 0.3, c.r - c.b) * smoothstep(-0.02, 0.04, c.g - c.b) * (1.0 - rune);
	float white = smoothstep(0.4, 0.68, lum) * (1.0 - smoothstep(0.06, 0.18, sat));
	float k = rune_k * (1.0 + 0.18 * pulse);
	vec3 runec = mix(c, rune_color.rgb * (0.5 + lum), rune_mix);
	vec3 gemc = mix(c, rune_color.rgb * (0.35 + lum), gem_tint);
	vec3 alb = mix(mix(c, runec, rune), gemc, gem);
	vec3 emit = runec * rune * (0.25 + 2.2 * k) + gemc * gem * (0.3 + 1.4 * gem_k) * (1.0 + 0.2 * pulse);
	ALBEDO = alb;
	METALLIC = gold * 0.7;
	ROUGHNESS = mix(mix(mix(0.7, 0.32, white), 0.3, gold), 0.2, max(rune, gem));
	SPECULAR = 0.5 + 0.2 * white;
	EMISSION = emit;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
