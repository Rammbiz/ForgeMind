// The summon light pillar (heroes_design.md §9.4; part U §3.2 "Pillar"): a soft additive column of
// light in the gem colour with streaks rising through it, a hot core and feathered sides. Quartz =
// silver, Sapphire = blue, Amethyst = violet, Topaz = gold (+ `twin` side pillars), Opal = `opal`
// iridescent fire cycling through the spectrum over a dark core. Driven by the uniform `t`.
// Additive, so the peak is held below white by `intensity` (photosensitivity cap: the caller keeps
// intensity <= 1 and the core <= 60 % white).
shader_type canvas_item;
render_mode blend_add;

uniform float t = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform float intensity = 1.0;
uniform float width = 0.16;      // core half-width in UV x
uniform float twin = 0.0;        // 0..1 two extra side pillars (Topaz+)
uniform float opal = 0.0;
uniform float top_fade = 0.18;   // fade-in length at the top
uniform float base_y = 0.62;     // where the pillar meets the crystal (brightest pool)

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), u.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

vec3 spectrum(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

float column(float x, float c, float w) {
	float d = (x - c) / w;
	return exp(-d * d) * 0.85 + exp(-d * d * 0.12) * 0.25;
}

void fragment() {
	vec2 uv = UV;
	float v = smoothstep(0.0, top_fade, uv.y) * (1.0 - smoothstep(base_y + 0.12, 1.0, uv.y));
	float pool = exp(-pow((uv.y - base_y) / 0.09, 2.0)) * exp(-pow((uv.x - 0.5) / (width * 2.4), 2.0));
	float streak = vnoise(vec2(uv.x * 26.0, uv.y * 3.0 + t * 1.4)) * 0.6 + vnoise(vec2(uv.x * 60.0, uv.y * 6.0 + t * 2.3)) * 0.4;
	float main = column(uv.x, 0.5, width) * (0.65 + 0.55 * streak);
	float side = (column(uv.x, 0.5 - width * 2.6, width * 0.45) + column(uv.x, 0.5 + width * 2.6, width * 0.45)) * twin * (0.6 + 0.5 * streak);
	float k = (main + side) * v + pool * 0.9;
	vec3 c = color.rgb;
	if (opal > 0.0) {
		vec3 sp = mix(vec3(0.78, 0.72, 0.95), spectrum(fract(uv.y * 0.8 - t * 0.42 + (uv.x - 0.5) * 1.5)), 0.55);
		float core = exp(-pow((uv.x - 0.5) / (width * 0.55), 2.0));
		vec3 oc = mix(sp, vec3(0.42, 0.32, 0.62), core * 0.7);
		c = mix(c, oc, opal);
	}
	// Hot core towards white, capped (<= 60 % white at full intensity).
	float hot = exp(-pow((uv.x - 0.5) / (width * 0.35), 2.0)) * v;
	vec3 col = c * k + vec3(1.0) * hot * 0.32;
	COLOR = vec4(col * intensity * color.a, 1.0);
}
