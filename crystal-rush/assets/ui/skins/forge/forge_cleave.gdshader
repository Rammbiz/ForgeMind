// «Кришталева кузня» cleaved crystal type: the glyphs are cut into steep facets (bands at
// ~64 degrees, alternating light), split once by a slanted cleave - upper facet ice-white,
// lower facet deep crystal cyan - with a bright hairline at the cut. Reads as cut crystal,
// not as chrome: no horizon line, no smooth gradient.
shader_type canvas_item;

uniform vec2 box_pos = vec2(0.0);
uniform vec2 box_size = vec2(400.0, 100.0);
uniform vec4 hi_a : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 hi_b : source_color = vec4(0.8, 0.95, 1.0, 1.0);
uniform vec4 lo_a : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform vec4 lo_b : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform float cleave_y = 0.56;
uniform float cleave_tilt = 0.22;
uniform float line_px = 0.0;
uniform float facet_px = 0.0;
uniform float facet_k = 0.07;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 uv = (lp - box_pos) / box_size;
	float cut = cleave_y + (uv.x - 0.5) * -cleave_tilt;
	float dy = (uv.y - cut) * box_size.y;
	vec3 hi = mix(hi_a.rgb, hi_b.rgb, clamp(uv.y / max(cut, 0.01), 0.0, 1.0));
	vec3 lo = mix(lo_a.rgb, lo_b.rgb, clamp((uv.y - cut) / max(1.0 - cut, 0.01), 0.0, 1.0));
	vec3 c = dy < 0.0 ? hi : lo;
	// Steep facet bands.
	float fp = facet_px > 0.0 ? facet_px : box_size.y * 0.9;
	float band = (lp.x + (lp.y - box_pos.y) * 0.48) / fp;
	float id = floor(band);
	float f = fract(sin(id * 12.9898) * 43758.5453);
	c *= 1.0 - facet_k + facet_k * 2.0 * step(0.5, f) * (dy < 0.0 ? 0.6 : 1.0);
	float edge = 1.0 - smoothstep(0.0, 0.05, min(fract(band), 1.0 - fract(band)));
	c = mix(c, vec3(1.0), edge * 0.18 * step(0.0, dy));
	if (line_px > 0.0) {
		c = mix(c, vec3(1.0), (1.0 - smoothstep(0.0, line_px, abs(dy))) * 0.9);
	}
	COLOR = vec4(c * COLOR.rgb, t.a * COLOR.a);
}
