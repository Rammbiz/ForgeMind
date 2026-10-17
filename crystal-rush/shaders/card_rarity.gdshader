// Rarity card art for the meta UI (arsenal_design.md §5.7; canvas_item, for TextureRect /
// ColorRect / Panel). `mode` 0 = card BACK (face-down card in the Cache fan-out: navy lattice,
// rarity glow, the gem cut in the middle), 1 = FRAME only (transparent centre, drawn over a
// machine card). The frame double-codes rarity: tier 0 Common plain steel, 1 Rare inner glow,
// 2 Epic animated energy lines, 3 Legendary gold filigree + glint sweep, 4 Mythic opal hue
// cycle. Gem cuts (colour-blind code): round, square, triangle, star, eye. `size` is the
// rect size in px so lines keep their width. TIME wrapped to 12 s; rates make whole cycles.
// No sin-hash noise; `alpha` fades it.
shader_type canvas_item;

uniform int mode = 0;
uniform int tier = 0;
uniform vec4 rarity_color : source_color = vec4(0.84, 0.87, 0.9, 1.0);
uniform vec2 size = vec2(220.0, 300.0);
uniform float radius_px = 22.0;
uniform float border_px = 7.0;
uniform float alpha = 1.0;
uniform float glow = 1.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sd_tri(vec2 p, float r) {
	const float k = 1.7320508;
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float sd_gem(vec2 p, int t, float r) {
	if (t == 0) {
		return length(p) - r;
	} else if (t == 1) {
		vec2 q = abs(p) - vec2(r * 0.82);
		return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	} else if (t == 2) {
		return sd_tri(vec2(p.x, -p.y + r * 0.15), r * 1.05);
	} else if (t == 3) {
		return sd_star5(vec2(p.x, -p.y), r * 1.15, 0.45);
	}
	// Eye: a vesica (two circles) with a round pupil cut out.
	float d1 = length(p - vec2(0.0, r * 0.9)) - r * 1.55;
	float d2 = length(p + vec2(0.0, r * 0.9)) - r * 1.55;
	float eye = max(d1, d2);
	return max(eye, -(length(p) - r * 0.32));
}

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	float t = mod(TIME, 12.0);
	vec2 px = (UV - 0.5) * size;
	vec2 half_size = size * 0.5;
	float d = sd_round_box(px, half_size - vec2(1.5), radius_px);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	float bw = border_px * (tier >= 3 ? 1.35 : 1.0);
	float border = inside * (1.0 - smoothstep(bw - 1.0, bw + 0.5, -d));
	vec3 rc = rarity_color.rgb;
	if (tier >= 4) {
		float ang = atan(px.y, px.x) / 6.2831853;
		rc = mix(vec3(1.0), hue(ang + t / 12.0), 0.45);
	}
	// Perimeter coordinate 0..1 for patterns running round the frame.
	float per = fract(atan(px.y / half_size.y, px.x / half_size.x) / 6.2831853 + 0.5);
	vec3 frame = mix(vec3(0.62, 0.67, 0.75), vec3(0.92, 0.95, 1.0), smoothstep(-bw, 0.0, d)) * 0.9;
	frame = mix(frame, rc, 0.35 + 0.15 * float(tier));
	float extra = 0.0;
	if (tier == 2) {
		float lines = fract(per * 6.0 - t * 0.5);
		extra = smoothstep(0.0, 0.05, lines) * (1.0 - smoothstep(0.05, 0.18, lines));
		frame += rc * extra * 1.2;
	} else if (tier == 3) {
		vec3 gold = vec3(1.0, 0.78, 0.32);
		float curl = 0.5 + 0.5 * cos(per * 6.2831853 * 28.0);
		frame = mix(gold * 0.85, gold * 1.15, curl);
		float glint = fract((UV.x + UV.y) * 0.5 - t / 3.0);
		extra = smoothstep(0.0, 0.03, glint) * (1.0 - smoothstep(0.03, 0.1, glint));
		frame += vec3(1.0) * extra * 0.9;
	} else if (tier == 4) {
		frame = mix(frame, rc, 0.5) + rc * 0.25;
	}
	// Inner glow just inside the border (Rare and up).
	float ig = exp(-max(-d - bw, 0.0) / (10.0 + 4.0 * float(tier))) * step(1.0, float(tier)) * inside * (1.0 - border);
	vec4 col = vec4(0.0);
	if (mode == 0) {
		// Card back: navy with a diamond lattice tinted by the rarity and a glowing gem cut.
		vec2 g = px / 26.0;
		float lat = abs(fract(g.x + g.y) - 0.5) + abs(fract(g.x - g.y) - 0.5);
		float lattice = (1.0 - smoothstep(0.04, 0.08, abs(lat - 0.5))) * 0.18;
		vec3 base = mix(vec3(0.05, 0.07, 0.16), vec3(0.11, 0.14, 0.3), UV.y) + rc * lattice;
		float gr = min(half_size.x, half_size.y) * 0.3;
		float gd = sd_gem(px, tier, gr);
		float gem_fill = 1.0 - smoothstep(-1.0, 0.5, gd);
		float gem_edge = (1.0 - smoothstep(1.0, 3.0, abs(gd))) ;
		float gem_halo = exp(-max(gd, 0.0) / 14.0) * (1.0 - gem_fill);
		float pulse = 0.85 + 0.15 * cos(t * 6.2831853 / 2.0);
		vec3 gem_col = mix(rc * 0.8, vec3(1.0), 0.25 + 0.35 * smoothstep(gr, -gr, px.y));
		base = mix(base, gem_col, gem_fill) + rc * gem_halo * 0.55 * glow * pulse + vec3(1.0) * gem_edge * 0.5;
		base += rc * ig * 0.6 * glow;
		col = vec4(mix(base, frame, border), inside);
	} else {
		vec3 c = mix(mix(rc, vec3(1.0), 0.2), frame, border);
		col = vec4(c, max(border, ig * 0.5 * glow));
	}
	col.a *= alpha * COLOR.a;
	COLOR = col;
}
