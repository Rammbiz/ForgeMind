// UI v2 light sweep: a soft diagonal band of warm light across a chamfered rect (CTA, cards).
// Additive. `progress` -1 hides it; 0..1 moves the band from left to right.
shader_type canvas_item;
render_mode blend_add;

uniform float progress = -1.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float chamfer = 12.0;
uniform float inset = 2.0;
uniform float width = 0.14;
uniform float strength = 0.45;
uniform vec4 tint : source_color = vec4(1.0, 0.97, 0.88, 1.0);

float sd_cham(vec2 p, vec2 b, float c) {
	vec2 q = abs(p) - b;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	return max(d, (q.x + q.y + c) * 0.70710678);
}

void fragment() {
	if (progress < 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 px = UV * rect_size;
		float d = sd_cham(px - rect_size * 0.5, rect_size * 0.5 - vec2(inset), max(chamfer - inset * 0.4, 0.0));
		float inside = 1.0 - smoothstep(-1.0, 0.5, d);
		float s = UV.x + UV.y * 0.5 * rect_size.y / max(rect_size.x, 1.0);
		float c = progress * 1.8 - 0.4;
		float band = 1.0 - smoothstep(0.0, width, abs(s - c));
		float core = 1.0 - smoothstep(0.0, width * 0.2, abs(s - c));
		// Brighter in the upper half (light comes from above).
		float up = mix(1.0, 0.55, UV.y);
		COLOR = vec4(tint.rgb * (band * 0.55 + core * 0.45) * strength * inside * up, 1.0);
	}
}
