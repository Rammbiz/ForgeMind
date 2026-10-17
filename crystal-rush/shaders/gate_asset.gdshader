// The owner's gate frame (Meshy GLB): its texture as is, except the crystal texels (saturated
// cyan in the albedo), which take the gate's kind colour and glow. Models.gate_style drives it.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec4 crystal_color : source_color = vec4(0.1, 0.42, 1.0, 1.0);
uniform float crystal_glow = 1.25;
uniform float dim = 1.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	// Cyan crystal: blue and green clearly above red (linear space). Silver and gold stay out.
	float cyan = smoothstep(0.1, 0.28, min(c.b - c.r, c.g - c.r + 0.06));
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 tinted = crystal_color.rgb * (0.45 + lum * 1.1);
	ALBEDO = mix(c, tinted, cyan) * dim;
	EMISSION = crystal_color.rgb * cyan * crystal_glow * (0.35 + lum);
	ROUGHNESS = mix(0.5, 0.18, cyan);
	METALLIC = mix(0.3, 0.0, cyan);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
