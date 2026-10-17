shader_type canvas_item;
// Engraved gold lettering: glyphs drawn in pure white get a vertical polished-gold ramp
// between y0 and y1 (local px); any other colour (outline, shadow) passes through.
uniform sampler2D ramp : source_color, filter_linear, repeat_disable;
uniform float y0 = 0.0;
uniform float y1 = 64.0;
varying float ly;
varying vec4 vc;

void vertex() {
	ly = VERTEX.y;
	vc = COLOR;
}

void fragment() {
	float is_gold = step(0.98, vc.r) * step(0.98, vc.g) * step(0.98, vc.b);
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp((ly - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
	vec3 g = texture(ramp, vec2(t, 0.5)).rgb;
	vec4 plain = vc * tex;
	COLOR = mix(plain, vec4(g, vc.a * tex.a), is_gold);
}
