// Distant planet: banded clouds from the noise texture that drift slowly, a soft terminator
// and an atmospheric rim. Unshaded (the scene light would wash it out at this distance).
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform vec4 rim_col : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 light_dir = vec3(-0.55, 0.55, 0.65);
uniform float band_scale = 7.0;
varying vec3 wnormal;

void vertex() {
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Wrap where every drift (0.002, 0.003, 0.004 per s) is a whole number of texture repeats.
	float t = mod(TIME, 1000.0);
	float warp = texture(noise_tex, UV * vec2(3.0, 2.0) + vec2(t * 0.002, 0.0)).r;
	float bands = texture(noise_tex, vec2(UV.x * 2.0 + warp * 0.18 + t * 0.003, UV.y * band_scale + warp * 0.5)).r;
	float storms = texture(noise_tex, UV * vec2(5.0, 3.0) - vec2(t * 0.004, 0.0)).r;
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.25, 0.82, bands * 0.7 + UV.y * 0.35));
	c = mix(c, col_b.rgb * 1.15, smoothstep(0.72, 0.9, storms) * 0.35);
	float ndl = dot(wnormal, normalize(light_dir));
	float lit = smoothstep(-0.3, 0.65, ndl);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(fres, 2.6);
	ALBEDO = c * (0.06 + lit * 1.05) + rim_col.rgb * rim * (0.15 + lit * 1.1);
}
