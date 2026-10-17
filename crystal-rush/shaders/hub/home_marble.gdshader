// Home terrace floor (UI v2): warm ivory marble slabs laid in rings round the hero's dais,
// soft veins, gold inlay (a double ring round the dais, compass rays, a scalloped band near the
// rim) and a faint polish sheen. Pattern from the object-space position (centre = dais).
shader_type spatial;
render_mode cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// UI v2 final pass: warm ivory #E9DFCC with visible veining, a darker flagstone ring and an
// AO / contact gradient under the dais, toned so the floor lands at luma ~170-205 (no white
// haze under PLAY).
uniform vec4 marble_a : source_color = vec4(0.914, 0.875, 0.80, 1.0);
uniform vec4 marble_b : source_color = vec4(0.85, 0.80, 0.72, 1.0);
uniform vec4 vein : source_color = vec4(0.62, 0.56, 0.52, 1.0);
uniform float tone = 0.94;
uniform vec4 grout : source_color = vec4(0.72, 0.66, 0.58, 1.0);
uniform vec4 gold : source_color = vec4(0.95, 0.78, 0.45, 1.0);
uniform vec4 sheen : source_color = vec4(0.80, 0.90, 1.0, 1.0);
uniform float rim_r = 6.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float line(float v, float w) {
	return 1.0 - smoothstep(0.0, w, abs(v));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 q = lp.xz;
	float r = length(q);
	float a = atan(q.y, q.x);
	// Ring slabs: radii 1.35, 2.3, 3.35, 4.45, 5.4.
	float ring = r < 1.35 ? 0.0 : (r < 2.3 ? 1.0 : (r < 3.35 ? 2.0 : (r < 4.45 ? 3.0 : (r < 5.4 ? 4.0 : 5.0))));
	float segs = 8.0 + ring * 6.0;
	float off = mod(ring, 2.0) * 0.5;
	float sa = a / 6.2831853 * segs + off;
	float slab_id = floor(sa) + ring * 37.0;
	// Grout: ring borders and radial joints (in metres).
	float g = 0.0;
	g = max(g, line(r - 2.3, 0.012));
	g = max(g, line(r - 3.35, 0.012));
	g = max(g, line(r - 5.4, 0.012));
	float joint = abs(fract(sa) - 0.5) * 2.0;
	float jd = (1.0 - joint) * 3.14159 * r / segs;
	g = max(g, (r > 1.35 ? 1.0 : 0.0) * line(jd, 0.012));
	// Marble body + veins.
	float h = hash(vec2(slab_id, ring));
	vec3 base = mix(marble_a.rgb, marble_b.rgb, h * 0.55);
	vec2 vp = q * 0.18 + vec2(h * 3.0, h * 1.7);
	float w1 = texture(noise_tex, vp).r;
	float w2 = texture(noise_tex, vp * 2.7 + vec2(w1 * 0.4, 0.1)).r;
	float v = line(w1 * 0.7 + w2 * 0.3 - 0.52, 0.018) * 0.55 + line(w2 - 0.47, 0.01) * 0.3;
	vec3 col = mix(base, vein.rgb, v * 0.7);
	// The flagstone ring (2.3-3.35) a shade darker, so the terrace reads as laid stone.
	col *= (ring == 2.0 ? 0.9 : 1.0);
	col = mix(col, grout.rgb, g * 0.55);
	// Gold inlay.
	float inl = 0.0;
	inl = max(inl, line(r - 1.42, 0.022));
	inl = max(inl, line(r - 1.56, 0.012));
	// Compass rays between the dais and the 2nd ring (8 tapered rays).
	float ra = abs(fract(a / 6.2831853 * 8.0) - 0.5) * 2.0;
	float ray_w = mix(0.06, 0.004, smoothstep(1.56, 2.25, r));
	float ray = (r > 1.56 && r < 2.25) ? line((1.0 - ra) * 3.14159 * r / 8.0, ray_w) : 0.0;
	inl = max(inl, ray);
	// Scalloped band near the rim.
	float sc = 4.85 + 0.12 * abs(sin(a * 24.0));
	inl = max(inl, line(r - sc, 0.016));
	inl = max(inl, line(r - 4.62, 0.014));
	inl = max(inl, line(r - 5.12, 0.014));
	// Little diamonds in the band.
	float da = abs(fract(a / 6.2831853 * 24.0) - 0.5) * 2.0;
	float dd = abs(r - 4.87) / 0.1 + (1.0 - da) * 3.14159 * r / 24.0 / 0.1;
	inl = max(inl, step(dd, 1.0) * 0.9);
	col = mix(col, gold.rgb, inl);
	// Soft darkening at the rim and a polish sheen across the slabs.
	col *= mix(1.0, 0.86, smoothstep(rim_r - 0.9, rim_r, r));
	// Contact / AO gradient under the dais and along the balustrade foot.
	col *= mix(0.62, 1.0, smoothstep(0.5, 1.7, r));
	col *= mix(1.0, 0.88, smoothstep(rim_r - 0.45, rim_r - 0.05, r));
	col *= tone;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sheen.rgb * tone, fres * 0.12 * (1.0 - inl));
	ALBEDO = col;
	METALLIC = inl * 0.25;
	EMISSION = gold.rgb * inl * 0.12;
	ROUGHNESS = mix(0.42, 0.28, inl) + g * 0.3;
	SPECULAR = 0.25;
}
