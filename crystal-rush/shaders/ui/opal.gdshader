// UI v2 black-opal ground: deep violet gradient with slow hue-cycling play-of-colour flecks.
// Used by KitGemCard for the Opal rarity (and any opal plate). Draw on a ColorRect.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.102, 0.082, 0.188, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.227, 0.176, 0.388, 1.0);
uniform float fleck_scale = 10.0;
uniform float fleck_alpha = 0.38;
uniform float speed = 0.25;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(top_color.rgb, bottom_color.rgb, uv.y);
	vec2 g = uv * vec2(fleck_scale, fleck_scale * 1.4);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float best = 1e9;
	vec2 bid = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash2(cell + o) - f;
			float d = dot(r, r);
			if (d < best) { best = d; bid = cell + o; }
		}
	}
	float h = fract(hash2(bid).x + TIME * speed * (0.5 + hash2(bid).y));
	float blob = (1.0 - smoothstep(0.0, 0.1, best)) * step(0.55, hash2(bid + 7.0).x);
	// A slow shimmer: each fleck fades in and out.
	blob *= 0.5 + 0.5 * sin(TIME * 0.8 + hash2(bid).y * 6.28);
	// Pastel spectrum: cyan, violet, pink, gold.
	vec3 fc = mix(hue(h), vec3(1.0), 0.35);
	COLOR = vec4(base + fc * blob * fleck_alpha, 1.0);
}
