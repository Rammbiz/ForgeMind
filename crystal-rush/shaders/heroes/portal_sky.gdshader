// Portal night sky (heroes_design.md §9.1: the one place a dark ground is allowed). Deep blue-violet
// night with two star layers (twinkle), a soft aurora curtain tinted by the pool's gems, a warm
// horizon glow at the bottom, and ceremony controls: `dim` (walkout scrim) and `desat` (the Opal
// tell). Driven by the uniform `t` (seconds), never TIME, so a ceremony can be seeked for dev shots.
// Budget: one full-screen pass, 2 value-noise octaves for the aurora, hashed star cells.
shader_type canvas_item;

uniform float t = 0.0;
uniform vec2 px_size = vec2(720.0, 1280.0);
uniform vec4 sky_top : source_color = vec4(0.055, 0.047, 0.15, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.165, 0.145, 0.314, 1.0);
uniform vec4 sky_low : source_color = vec4(0.29, 0.227, 0.478, 1.0);
uniform vec4 horizon : source_color = vec4(0.96, 0.68, 0.27, 1.0);
uniform vec4 aurora_a : source_color = vec4(0.49, 0.42, 1.0, 1.0);
uniform vec4 aurora_b : source_color = vec4(1.0, 0.71, 0.18, 1.0);
uniform float aurora = 0.5;      // aurora strength 0..1
uniform float horizon_glow = 0.55;
uniform float dim = 0.0;         // 0..1 walkout scrim (keeps stars faintly)
uniform float desat = 0.0;       // 0..1 grey world (Opal tell)
uniform vec4 burst : source_color = vec4(1.0, 0.8, 0.4, 0.0);  // gem-coloured radial light (a = strength)
uniform vec2 burst_at = vec2(0.5, 0.45);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float stars(vec2 p, float cell, float density, float seed) {
	vec2 g = p / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash21(id + seed);
	if (h > density) {
		return 0.0;
	}
	vec2 o = vec2(hash21(id + seed + 7.1), hash21(id + seed + 3.7)) - 0.5;
	float d = length(f - o * 0.7);
	float tw = 0.55 + 0.45 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	float core = smoothstep(0.09, 0.0, d);
	float halo = smoothstep(0.32, 0.0, d) * 0.25;
	return (core + halo) * tw * (0.4 + 0.6 * hash21(id + seed + 1.3));
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * px_size;
	// Night gradient: top -> mid -> low, then the warm horizon at the very bottom.
	vec3 col = mix(sky_top.rgb, sky_mid.rgb, smoothstep(0.0, 0.45, uv.y));
	col = mix(col, sky_low.rgb, smoothstep(0.45, 0.88, uv.y));
	float hz = smoothstep(0.7, 1.0, uv.y);
	col = mix(col, horizon.rgb * 0.9, hz * hz * horizon_glow);
	// Stars (fewer near the horizon glow).
	float s = stars(p, 34.0, 0.16, 0.0) + stars(p + 13.0, 71.0, 0.22, 5.0) * 1.4;
	s *= (1.0 - smoothstep(0.6, 0.95, uv.y));
	col += vec3(1.0, 0.97, 0.92) * s * 0.85;
	// Aurora: a soft curtain band in the upper half that drifts slowly.
	float y0 = 0.26 + 0.05 * sin(uv.x * 3.1 + t * 0.11);
	float n = vnoise(vec2(uv.x * 3.0 + t * 0.05, uv.y * 1.5)) * 0.65 + vnoise(vec2(uv.x * 7.0 - t * 0.08, uv.y * 4.0)) * 0.35;
	float band = exp(-pow((uv.y - y0 - (n - 0.5) * 0.12) / 0.09, 2.0));
	float rays = 0.6 + 0.4 * vnoise(vec2(uv.x * 22.0 + t * 0.2, 0.5));
	float ak = band * rays * aurora;
	vec3 ac = mix(aurora_a.rgb, aurora_b.rgb, smoothstep(0.15, 0.85, uv.x + (n - 0.5) * 0.4));
	col += ac * ak * 0.42;
	// Gem-coloured burst (ceremony light behind the crystal).
	vec2 bd = (uv - burst_at) * vec2(px_size.x / px_size.y, 1.0);
	float bl = exp(-dot(bd, bd) / 0.06);
	col += burst.rgb * bl * burst.a;
	// Desaturate (Opal tell) and dim (walkout scrim).
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.92, 0.94, 1.0), desat * 0.85);
	col *= 1.0 - dim * 0.62;
	COLOR = vec4(col, 1.0);
}
