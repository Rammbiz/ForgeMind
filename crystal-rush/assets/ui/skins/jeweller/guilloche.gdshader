shader_type canvas_item;
// «Ювелірна майстерня»: navy guilloché enamel. Two mirrored families of wavy concentric
// rings (rose-engine barleycorn) plus faint radial rays, under a translucent enamel with a
// soft light pool. Coordinates are the CanvasItem's local pixels.
uniform vec4 base : source_color = vec4(0.063, 0.086, 0.204, 1.0);
uniform vec4 line_col : source_color = vec4(0.17, 0.22, 0.46, 1.0);
uniform vec4 deep : source_color = vec4(0.027, 0.04, 0.11, 1.0);
uniform vec4 glow_col : source_color = vec4(0.24, 0.3, 0.62, 1.0);
uniform vec2 center = vec2(360.0, 640.0);
uniform vec2 light_pos = vec2(200.0, 200.0);
uniform float light_r = 700.0;
uniform float spacing = 9.0;
uniform float waves = 18.0;
uniform float amp = 0.55;
uniform float rays = 96.0;
uniform float line_alpha = 0.6;
uniform float line_w = 1.9;
uniform vec4 rect = vec4(0.0, 0.0, 720.0, 1280.0);
uniform float vignette = 0.55;
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float lines(float v, float w) {
	float d = abs(fract(v + 0.5) - 0.5);
	float fw = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d / fw);
}

void fragment() {
	vec2 p = lp - center;
	float r = length(p);
	float a = atan(p.y, p.x);
	float wv = amp * sin(a * waves + r * 0.012);
	float l1 = lines(r / spacing + wv, line_w);
	float l2 = lines(r / spacing - wv, line_w);
	float l3 = lines(a * rays / 6.28318, line_w * 0.6) * smoothstep(40.0, 260.0, r) * 0.35;
	float pat = max(max(l1, l2) * 0.85, l3);
	vec3 c = base.rgb;
	// light pool and vignette on the plate
	float lpool = 1.0 - smoothstep(0.0, light_r, length(lp - light_pos));
	vec2 q = (lp - rect.xy) / rect.zw - 0.5;
	float vig = smoothstep(0.25, 0.75, length(q * vec2(1.1, 0.9)));
	c = mix(c, glow_col.rgb, lpool * 0.45);
	c = mix(c, line_col.rgb * (0.8 + 0.6 * lpool), pat * line_alpha);
	c = mix(c, deep.rgb, vig * vignette);
	COLOR = vec4(c, COLOR.a);
}
