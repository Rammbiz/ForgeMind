// One-time gaussian for the world snapshot (runs on a 1/10-res SubViewport, UPDATE_ONCE):
// 7x7 taps, sigma ~2 texels. At 135x240 that is ~1.6 M texel fetches once per refresh.
shader_type canvas_item;
uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.0074, 0.0042);
uniform float spread = 1.6;
void fragment() {
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float w = exp(-float(x * x + y * y) / 8.0);
			acc += texture(src, UV + vec2(float(x), float(y)) * texel * spread).rgb * w;
			wsum += w;
		}
	}
	COLOR = vec4(acc / wsum, 1.0);
}
