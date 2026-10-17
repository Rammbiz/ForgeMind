// A Meshy model whose crystals take a gameplay colour (e.g. a geode's reward): strongly
// saturated, bright texels are recoloured and glow; the rock or metal around them keeps the
// model's own texture.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 crystal_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float crystal_glow = 1.1;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float crystal = smoothstep(0.18, 0.34, hi - lo) * smoothstep(0.12, 0.3, hi);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 tinted = crystal_color.rgb * (0.35 + lum * 1.6);
	ALBEDO = mix(c, tinted, crystal);
	EMISSION = crystal_color.rgb * crystal * crystal_glow * (0.3 + lum * 1.2);
	ROUGHNESS = mix(0.8, 0.2, crystal);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
