// Ground telegraphs (Effects.telegraph_*), arsenal_design.md §2.8 grammar - friendly and enemy
// never share a shape:
//   mode 0  friendly PLACE ring: hollow dashed ring in the family accent, 0.06 u line, four
//           inward chevrons that close in as `progress` runs 0 -> 1 (the landing countdown)
//   mode 1  friendly line (Railgun): two dashed rails with chevrons racing forward (-Z)
//   mode 2  enemy disc: filled red disc with a solid rim, the fill grows to the rim
//   mode 3  enemy line: a solid red band with solid edges
// The quad is a 1x1 PlaneMesh scaled to `size` (world units: x across, y along -Z). Fade with
// `alpha`. TIME is wrapped (8 s) and every scroll rate makes whole cycles per wrap.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform vec2 size = vec2(3.2, 3.2);
uniform float progress = 0.0;
uniform float alpha = 1.0;
uniform float line_w = 0.06;

float band(float d, float w) {
	float aa = max(fwidth(d), 0.004) * 1.2;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

void fragment() {
	float t = mod(TIME, 8.0);
	vec2 p = (UV - 0.5) * size;
	vec3 col = color.rgb;
	float a = 0.0;
	if (mode == 0) {
		float r = length(p);
		float R = size.x * 0.5 - line_w * 2.5;
		float ang = atan(p.y, p.x);
		float n = max(8.0, floor(6.2831853 * R / 0.36));
		float dsh = fract(ang / 6.2831853 * n + t * 0.25);
		float dash = smoothstep(0.0, 0.06, dsh) * (1.0 - smoothstep(0.56, 0.62, dsh));
		float ring = band(r - R, line_w * 0.5) * dash;
		float dr = (r - R) / 0.16;
		float halo = exp(-dr * dr) * 0.22;
		float chev = 0.0;
		float arm = 0.12 + 0.05 * R;
		float c0 = mix(R - 0.1, R * 0.35, clamp(progress, 0.0, 1.0));
		for (int i = 0; i < 4; i++) {
			float ai = float(i) * 1.5707963 + 0.7853982;
			vec2 dir = vec2(cos(ai), sin(ai));
			float rr = dot(p, dir);
			float vv = dot(p, vec2(-dir.y, dir.x));
			float d = (rr - c0 - abs(vv) * 0.9) * 0.743;
			float m = band(d, line_w * 0.55) * (1.0 - smoothstep(arm, arm + 0.02, abs(vv))) * step(c0 - 0.03, rr);
			chev = max(chev, m);
		}
		a = max(max(ring, chev), halo);
		col = mix(col, vec3(1.0), max(ring, chev) * 0.25) * 1.25;
	} else if (mode == 1) {
		float along = UV.y * size.y;
		float hw = size.x * 0.5 - line_w * 1.5;
		float dsh = fract(along / 0.5 + t * 2.0);
		float dash = smoothstep(0.0, 0.06, dsh) * (1.0 - smoothstep(0.55, 0.62, dsh));
		float rails = band(abs(p.x) - hw, line_w * 0.5) * dash;
		float cell = mod(along + t * 3.2, 1.6) - 0.5;
		float chev = band((cell - abs(p.x) * 0.8) * 0.78, line_w * 0.5) * (1.0 - smoothstep(hw * 0.45, hw * 0.45 + 0.02, abs(p.x)));
		float ends = smoothstep(0.0, 0.6, along) * smoothstep(size.y, size.y - 1.2, along);
		float hx = (abs(p.x) - hw) / 0.12;
		float halo = exp(-hx * hx) * 0.2;
		a = max(max(rails, chev * 0.8), halo) * ends * (0.6 + 0.4 * progress);
		col = mix(col, vec3(1.0), rails * 0.3) * 1.25;
	} else if (mode == 2) {
		float r = length(p);
		float R = size.x * 0.5 - 0.06;
		float inside = 1.0 - smoothstep(R - 0.01, R + 0.01, r);
		float rim = band(r - R, 0.05);
		float grow = 1.0 - smoothstep(R * progress - 0.02, R * progress + 0.02, r);
		float edge = band(r - R * progress, 0.03) * step(0.02, progress);
		a = max(rim * 0.95, inside * (0.2 + 0.3 * grow) + edge * 0.6);
		col = mix(col, vec3(1.0, 0.6, 0.5), edge * 0.5);
	} else {
		float along = UV.y * size.y;
		float hw = size.x * 0.5;
		float inside = 1.0 - smoothstep(hw - 0.02, hw, abs(p.x));
		float edges = band(abs(p.x) - (hw - 0.05), 0.045);
		a = max(edges * 0.95, inside * (0.22 + 0.25 * progress));
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * alpha;
}
