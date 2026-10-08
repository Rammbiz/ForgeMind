// The step-out "crystallise" wipe of a summon walkout (part U §3.2 "Step-out"): the splash appears
// facet by facet from `origin` outward (a triangular facet grid, each facet with its own small
// delay), the leading facets flash in the gem colour, and a gem-coloured rim light hugs the art's
// alpha edge. `progress` 0..1 (>= 1 = fully shown), `rim` 0..1. No TIME: seekable.
shader_type canvas_item;

uniform float progress = 1.0;
uniform vec4 gem : source_color = vec4(1.0, 0.72, 0.18, 1.0);
uniform float rim = 0.0;
uniform vec2 origin = vec2(0.5, 0.45);
uniform float cells = 14.0;
uniform float aspect = 0.56;     // texture width / height (keeps facets equilateral-ish)

varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 g = vec2(UV.x * cells, UV.y * cells / max(aspect, 0.1));
	vec2 id = floor(g);
	vec2 f = fract(g);
	float tri = step(f.x, f.y);
	vec2 cid = id + vec2(tri * 0.33 + 0.33, 0.66 - tri * 0.33);
	vec2 cuv = vec2(cid.x / cells, cid.y * max(aspect, 0.1) / cells);
	float h = hash21(id * 1.7 + tri * 3.1);
	float dist = length((cuv - origin) * vec2(1.0, 1.0 / max(aspect, 0.1) * 0.56));
	float thr = dist * 1.05 + h * 0.22;
	float p = progress * 1.35;
	float shown = smoothstep(thr, thr + 0.06, p);
	float edge = smoothstep(thr - 0.02, thr + 0.03, p) * (1.0 - smoothstep(thr + 0.05, thr + 0.18, p));
	vec3 c = tex.rgb;
	c = mix(c, gem.rgb * 1.15 + vec3(0.25), edge * 0.7);
	// Rim light on the alpha edge (4 taps).
	if (rim > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * 6.0;
		float aa = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		float e = clamp(tex.a * 4.0 - aa, 0.0, 1.0);
		c += gem.rgb * e * rim * 0.9;
	}
	COLOR = vec4(c, tex.a * max(shown, edge * 0.85)) * v_mod;
}
