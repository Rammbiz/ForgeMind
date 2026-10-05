// Gate energy field (Models.gate): a translucent crystal-energy curtain between the pylons.
// Layers: two scrolling noise octaves from the baked cloud texture (no sin-hash noise), rising
// light bands, a faint diamond lattice, a diagonal shimmer sweep, bright edges and a hot base
// where the emitter sits. Charge gates fill from the bottom (`fill`) with a glowing meniscus.
// TIME is wrapped to 40 s and every rate is a multiple of 1/40 s, so the loop is seamless.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 empty_color : source_color = vec4(0.3, 0.12, 0.4, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 size = vec2(1.8, 2.2);          // field size in metres
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float closed : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 2.0) = 1.0;
uniform float turbulence : hint_range(0.0, 2.0) = 1.0;
uniform float seed = 0.0;

float line_aa(float d, float w) {
	float aa = fwidth(d) * 1.5;
	return 1.0 - smoothstep(w, w + aa, d);
}

void fragment() {
	float t = mod(TIME, 40.0);
	vec2 p = vec2(UV.x * size.x, (1.0 - UV.y) * size.y);   // metres, y up from the base
	// Noise: a slow large octave and a faster detailed one, warped by the first.
	float n1 = texture(noise_tex, p * 0.28 + vec2(seed, -t * 0.05)).r;
	float n2 = texture(noise_tex, p * 0.75 + vec2(-t * 0.025 + seed * 0.37, -t * 0.125) + vec2(n1 * 0.35)).r;
	float n = mix(n1, n2, 0.45);
	n = mix(0.5, n, turbulence);
	// Rising light bands, bent by the noise so they look like energy, not stripes.
	float bands = 0.5 + 0.5 * sin(p.y * 5.0 - t * 3.14159265 + n * 3.0);
	bands = pow(bands, 6.0);
	// Diamond crystal lattice.
	vec2 q = p * 2.2;
	vec2 g = abs(fract(vec2(q.x + q.y, q.x - q.y) * 0.5) - 0.5);
	float lattice = line_aa(min(g.x, g.y), 0.018);
	// Diagonal shimmer sweep every 4 s.
	float sweep_pos = fract(t * 0.25) * 2.6 - 0.8;
	float sx = UV.x + (1.0 - UV.y) * 0.45;
	float shimmer = exp(-pow((sx - sweep_pos) * 7.0, 2.0));
	// Edges and the emitter at the base.
	float e = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	float edge = exp(-e * 9.0) + 0.35 * exp(-e * 2.5);
	float base = exp(-p.y * 2.2);
	float top = exp(-(size.y - p.y) * 5.0);
	// Charge fill level with a wobbling glowing surface.
	float level = fill * size.y + (n2 - 0.5) * 0.14 * step(0.001, fill) * step(fill, 0.999);
	float below = smoothstep(level + 0.03, level - 0.03, p.y);
	float meniscus = exp(-abs(p.y - level) * 22.0) * step(0.001, fill) * step(fill, 0.999);

	float glowk = clamp(edge * 0.5 + shimmer * 0.45 + base * 0.3 + bands * 0.22 + top * 0.3, 0.0, 0.8);
	vec3 deep = color.rgb * (0.38 + 0.62 * n);
	vec3 full = mix(deep, mix(color.rgb, core_color.rgb, 0.6), glowk);
	full += color.rgb * lattice * 0.3;
	float a_full = 0.5 + 0.22 * n + 0.18 * bands + 0.6 * edge + 0.3 * base + 0.22 * shimmer + 0.1 * lattice + 0.2 * top;

	vec3 empty = empty_color.rgb * (0.45 + 0.6 * n) + color.rgb * edge * 0.6;
	float a_empty = 0.3 + 0.16 * n + 0.55 * edge + 0.05 * lattice;

	vec3 rgb = mix(empty, full, below);
	float a = mix(a_empty, a_full, below);
	rgb = mix(rgb, core_color.rgb, clamp(meniscus * 1.2, 0.0, 1.0));
	a += meniscus * 0.6;

	float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(rgb, vec3(lum) * vec3(0.55, 0.58, 0.68), closed);
	a *= 1.0 - 0.55 * closed;
	rgb = mix(rgb, vec3(1.0), flash * 0.8);
	a += flash * 0.35;
	ALBEDO = rgb;
	ALPHA = clamp(a * opacity, 0.0, 0.95);
}
