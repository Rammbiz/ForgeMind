// Squad status rings on the road (Effects.status), arsenal_design.md §2.1 statuses. One
// alpha-blended quad (true status colours on any road) per (squad, status), scaled to 2.6 x the squad radius (the ring sits at
// q-radius 0.77 = the squad edge). `kind`:
//   0 STAGGER  copper chevrons pushed outwards
//   1 JOLT     crackling orchid ring, 3 stack arcs
//   2 CHILL    frost rim with ice teeth, 3 stack arcs; at 3 stacks a frozen disc
//   3 BURN     ember tongues licking outwards
//   4 MARK     lime reticle: corner brackets and ticks (vs 1.25)
//   5 SEAL     indigo double rune ring
// Fade with `alpha`. TIME is wrapped (10 s); every rate makes whole cycles per wrap. Noise is
// a baked texture (no sin-hash).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int kind = 0;
uniform vec4 color : source_color = vec4(1.0);
uniform float alpha = 1.0;
uniform float stacks = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float band(float d, float w) {
	float aa = max(fwidth(d), 0.003) * 1.2;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	float t = mod(TIME, 10.0);
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float u = ang / 6.2831853 + 0.5;
	float R = 0.77;
	float a = 0.0;
	vec3 col = color.rgb;
	if (kind == 0) {
		float push = fract(t * 2.5);
		float rr = R + push * 0.18;
		float cell = fract(u * 8.0) - 0.5;
		float chev = band((r - rr) - abs(cell) * 0.25, 0.035) * (1.0 - smoothstep(0.32, 0.36, abs(cell)));
		a = chev * (1.0 - push) + band(r - R, 0.012) * 0.4;
	} else if (kind == 1) {
		float n = texture(noise_tex, vec2(u * 3.0, t * 1.2)).r;
		float jag = R + (n - 0.5) * 0.09;
		float seg = floor(u * 3.0);
		float lit = step(seg, stacks - 0.5);
		float gap = smoothstep(0.02, 0.05, fract(u * 3.0)) * (1.0 - smoothstep(0.95, 0.98, fract(u * 3.0)));
		float flick = 0.6 + 0.4 * texture(noise_tex, vec2(t * 2.0, u)).r;
		float ring = band(r - jag, 0.032) * gap;
		a = ring * (0.25 + 0.75 * lit) * flick;
		float dr = (r - R) / 0.08;
		a += exp(-dr * dr) * 0.25 * lit;
		col = mix(col, vec3(1.0), band(r - jag, 0.008) * 0.6);
	} else if (kind == 2) {
		float tooth = abs(fract(u * 24.0) - 0.5) * 2.0;
		float inner = R - 0.04 - tooth * 0.08 * (0.5 + 0.5 * min(stacks, 3.0) / 3.0);
		float rim = smoothstep(inner - 0.01, inner + 0.01, r) * (1.0 - smoothstep(R, R + 0.02, r));
		float seg = floor(u * 3.0);
		float lit = step(seg, stacks - 0.5);
		a = rim * (0.45 + 0.55 * lit) + band(r - R, 0.02) * 0.9;
		if (stacks >= 3.0) {
			float n2 = texture(noise_tex, q * 0.6 + vec2(0.3, 0.7)).r;
			float crack = band(n2 - 0.5, 0.02);
			a += (1.0 - smoothstep(R - 0.02, R, r)) * (0.16 + crack * 0.4);
		}
		col = mix(col, vec3(1.0), 0.3);
	} else if (kind == 3) {
		float n = texture(noise_tex, vec2(u * 4.0, r * 1.2 - t * 0.8)).r;
		float flame = (1.0 - smoothstep(R - 0.05, R + 0.06 + n * 0.16, r)) * smoothstep(R - 0.16, R - 0.04, r);
		a = flame * (0.5 + n) + band(r - R + 0.05, 0.015) * 0.5;
		col = mix(col, vec3(1.0, 0.78, 0.4), smoothstep(R, R + 0.16, r) * 0.8 + n * 0.2);
	} else if (kind == 4) {
		float rot = t * 0.6283185;
		float c = cos(rot);
		float s = sin(rot);
		vec2 p = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
		vec2 ap = abs(p);
		float box = R * 0.76;
		float bx = band(max(ap.x, ap.y) - box, 0.035);
		float corner = step(box * 0.55, min(ap.x, ap.y));
		float brackets = bx * corner;
		float tick = band(ap.x, 0.03) * step(R * 0.86, ap.y) * step(ap.y, R * 1.08) + band(ap.y, 0.03) * step(R * 0.86, ap.x) * step(ap.x, R * 1.08);
		float circle = band(r - R * 0.98, 0.014) * 0.55;
		a = max(max(brackets, tick), circle);
	} else {
		float rot = u + t * 0.05;
		float outer = band(r - R, 0.026);
		float inner = band(r - R * 0.86, 0.018);
		float cell = fract(rot * 8.0);
		float glyph = band(r - R * 0.93, 0.04) * band(cell - 0.5, 0.1) * 0.95;
		float bar = band(cell - 0.5, 0.02) * step(R * 0.84, r) * step(r, R * 1.02);
		a = max(max(outer, inner * 0.8), max(glyph, bar));
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * alpha;
}
