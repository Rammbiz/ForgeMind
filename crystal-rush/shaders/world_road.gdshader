// The sculpted road module (Meshy albedo + normal map) toned down so the army, the gates and
// the threats read first: lower saturation and brightness. The bright cyan veins of the
// painted ice keep a soft glow with an energy pulse flowing down the road.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 1.5) = 0.8;
uniform float brightness : hint_range(0.0, 2.0) = 0.9;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform float normal_depth = 1.0;
uniform vec4 vein_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float vein_glow = 0.55;
uniform float pulse_speed = 3.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb;
	float l = dot(a, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(vec3(l), a, saturation);
	c = (c - 0.5) * contrast + 0.5;
	ALBEDO = clamp(c, 0.0, 1.0) * brightness * tint.rgb;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = 0.62;
	SPECULAR = 0.4;
	// Veins: the near-white cyan strokes of the painted ice.
	float vein = smoothstep(0.82, 0.97, min(a.g, a.b)) * smoothstep(0.02, 0.15, a.b - a.r);
	float t = mod(TIME, 62.831853);
	float wave = 0.5 + 0.5 * sin(wpos.z * 0.3 + t * pulse_speed);
	wave = wave * wave * wave;
	float shimmer = texture(noise_tex, wpos.xz * 0.045 + vec2(0.0, t * 0.0318)).r;
	EMISSION = vein_color.rgb * vein * vein_glow * (0.25 + 0.5 * shimmer + 1.2 * wave * shimmer);
}
