// Home stage sky (UI v2, "bright summer morning"): a warm gradient from the zenith blue to a
// peach horizon, a soft sun with a wide glow, a bank of painterly cumulus along the horizon
// and a sea of sunlit clouds below it (the bridge floats above the clouds). All procedural
// from the shared cloud noise; no TIME except a very slow drift.
shader_type sky;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 zenith : source_color = vec4(0.33, 0.6, 0.9, 1.0);
uniform vec4 mid_sky : source_color = vec4(0.52, 0.75, 0.93, 1.0);
uniform vec4 horizon : source_color = vec4(0.98, 0.89, 0.74, 1.0);
uniform vec4 haze : source_color = vec4(0.99, 0.93, 0.84, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.54, 1.0);
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.74, 0.76, 0.88, 1.0);
uniform vec4 cloud_warm : source_color = vec4(1.0, 0.86, 0.70, 1.0);
uniform vec3 sun_dir = vec3(0.35, 0.32, -0.88);
uniform float drift = 0.0;
uniform float cloud_amount = 1.0;

float n(vec2 p) {
	return texture(noise_tex, p).r;
}

float fbm(vec2 p) {
	return n(p) * 0.55 + n(p * 2.13 + vec2(0.31, 0.17)) * 0.3 + n(p * 4.7 + vec2(0.71, 0.43)) * 0.15;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	vec3 sd = normalize(sun_dir);
	float sun = max(dot(d, sd), 0.0);
	// Sky gradient (warmer towards the sun side of the horizon).
	float az = atan(d.x, -d.z);
	vec3 hor = mix(horizon.rgb, mix(horizon.rgb, sun_color.rgb, 0.35), pow(sun, 3.0));
	vec3 col = mix(hor, mid_sky.rgb, smoothstep(0.02, 0.17, y));
	col = mix(col, zenith.rgb, smoothstep(0.14, 0.5, y));
	// Sun disc and glow.
	col += sun_color.rgb * (pow(sun, 900.0) * 1.6 + pow(sun, 60.0) * 0.45 + pow(sun, 8.0) * 0.18);
	// High wisps (plane projection), very faint.
	if (y > 0.02) {
		vec2 p = d.xz / (y + 0.12) * 0.14 + vec2(drift * 0.004, 0.0);
		float w = smoothstep(0.55, 0.85, fbm(p * vec2(1.0, 2.6)));
		col = mix(col, cloud_lit.rgb, w * 0.35 * smoothstep(0.02, 0.2, y) * cloud_amount);
	}
	// Cumulus bank along the horizon: a bumpy silhouette in azimuth, lit tops, lilac bases.
	float u = az / 6.2831853;
	float top_h = 0.035 + 0.11 * fbm(vec2(u * 3.0 + drift * 0.0015, 0.37)) + 0.05 * n(vec2(u * 11.0, 0.71));
	float bank = smoothstep(top_h + 0.01, top_h - 0.025, y) * smoothstep(-0.12, -0.01, y);
	float puff = fbm(vec2(u * 9.0 + drift * 0.002, y * 6.0));
	float bank_lit = smoothstep(top_h - 0.09, top_h, y + puff * 0.04);
	vec3 bank_col = mix(cloud_shade.rgb, cloud_lit.rgb, bank_lit);
	bank_col = mix(bank_col, cloud_warm.rgb, pow(sun, 4.0) * 0.6 * bank_lit);
	col = mix(col, bank_col, bank * 0.92 * cloud_amount);
	// Below the horizon: the sea of clouds seen from above, melting into the haze far away.
	if (y < 0.0) {
		float fy = max(-y, 0.004);
		vec2 p = d.xz / fy * 0.035 + vec2(drift * 0.003, 0.0);
		float c1 = fbm(p);
		float c2 = fbm(p * 2.4 + vec2(c1 * 0.3, 0.2));
		float tops = smoothstep(0.38, 0.72, c1 * 0.65 + c2 * 0.35);
		vec3 sea = mix(mix(cloud_shade.rgb, haze.rgb, 0.45), cloud_lit.rgb, tops);
		sea = mix(sea, cloud_warm.rgb, 0.25 * pow(max(dot(normalize(vec3(d.x, 0.0, d.z)), normalize(vec3(sd.x, 0.0, sd.z))), 0.0), 3.0));
		float far = smoothstep(0.0, 0.16, fy);
		col = mix(mix(haze.rgb, bank_col, bank), sea, far);
	}
	COLOR = col;
}
