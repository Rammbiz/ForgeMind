// «Емаль і золото» backdrop for the 2D screens: the world's purple space (void + violet
// nebula + star dust) behind the white enamel kit, with a faint ice glow where the bridge is.
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 void_col : source_color = vec4(0.039, 0.043, 0.122, 1.0);
uniform vec4 nebula : source_color = vec4(0.165, 0.078, 0.314, 1.0);
uniform vec4 ice : source_color = vec4(0.235, 0.722, 1.0, 1.0);
uniform vec2 size = vec2(720.0, 1280.0);
uniform vec2 glow_at = vec2(0.7, 0.25);
uniform float dim = 0.0;

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
	float n1 = texture(noise_tex, uv * vec2(0.8, 1.2) + vec2(0.13, 0.4)).r;
	float n2 = texture(noise_tex, uv * vec2(2.3, 3.1) + vec2(0.5, 0.1)).g;
	float r = length((uv - glow_at) * asp);
	vec3 c = mix(void_col.rgb, void_col.rgb * 0.7, uv.y);
	float neb = smoothstep(1.0, 0.0, r) * (0.45 + 0.75 * n1) * (0.65 + 0.5 * n2);
	c = mix(c, nebula.rgb, clamp(neb, 0.0, 1.0));
	// Bridge glow along the bottom.
	c += ice.rgb * 0.10 * smoothstep(0.55, 1.0, uv.y) * (0.6 + 0.4 * n2);
	// Star dust.
	vec2 g = lp / 3.0;
	vec2 cell = floor(g);
	float h = hash(cell);
	if (h > 0.9965) {
		vec2 sp = cell + vec2(hash(cell + 1.7), hash(cell + 3.1));
		float d = length(g - sp);
		float b = (h - 0.9965) / 0.0035;
		c += vec3(0.85, 0.92, 1.0) * smoothstep(0.9, 0.0, d) * (0.35 + 0.65 * b);
	}
	c *= 1.0 - dim;
	COLOR = vec4(c, 1.0);
}
