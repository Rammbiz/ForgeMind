// «Кришталева кузня» backdrop for the 2D screens: deep void, a violet nebula from the noise
// texture, faint giant crystal facets (the inside of the forge's geode) and star dust.
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 void_col : source_color = vec4(0.039, 0.031, 0.125, 1.0);
uniform vec4 nebula : source_color = vec4(0.17, 0.07, 0.34, 1.0);
uniform vec4 ice : source_color = vec4(0.24, 0.72, 1.0, 1.0);
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 glow_at = vec2(0.5, 0.18);

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = lp / size;
	vec2 asp = vec2(1.0, size.y / size.x);
	float n1 = texture(noise_tex, uv * vec2(0.9, 1.4) + vec2(TIME * 0.004, 0.0)).r;
	float n2 = texture(noise_tex, uv * vec2(2.1, 3.0) - vec2(0.0, TIME * 0.003)).g;
	float r = length((uv - glow_at) * asp);
	vec3 c = void_col.rgb;
	float neb = smoothstep(0.85, 0.0, r) * (0.55 + 0.6 * n1) * (0.7 + 0.5 * n2);
	c = mix(c, nebula.rgb, clamp(neb, 0.0, 1.0));
	c += ice.rgb * 0.05 * smoothstep(0.45, 0.0, r);
	// Giant facets: a Voronoi-like split into flat cells, each a slightly different tone.
	vec2 g = uv * asp * 2.6;
	vec2 cell = floor(g);
	float best = 9.0;
	float second = 9.0;
	vec2 bid = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 cc = cell + vec2(float(i), float(j));
			vec2 p = cc + vec2(hash(cc), hash(cc + 7.3));
			float d = length(g - p);
			if (d < best) { second = best; best = d; bid = cc; }
			else if (d < second) { second = d; }
		}
	}
	float tone = hash(bid + 3.1);
	c *= 0.86 + 0.28 * tone;
	float edge = 1.0 - smoothstep(0.0, 0.02, second - best);
	c += ice.rgb * edge * 0.05 * (1.0 - uv.y * 0.6);
	// Star dust.
	vec2 sp = floor(lp / 3.0);
	float s = step(0.9965, hash(sp));
	float tw = 0.5 + 0.5 * sin(TIME * 2.0 + hash(sp + 1.7) * 30.0);
	c += vec3(0.8, 0.9, 1.0) * s * (0.35 + 0.5 * tw) * (1.0 - uv.y * 0.5);
	// Vignette.
	c *= 1.0 - 0.45 * smoothstep(0.35, 1.0, length((uv - vec2(0.5, 0.45)) * vec2(1.25, 1.0)));
	COLOR = vec4(c, 1.0);
}
