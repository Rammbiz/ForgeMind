// Space sky: the world's star panorama plus nebula layers from the baked noise texture.
// The run camera looks down at the road, so the nebula is laid on a dome around and below
// the camera (projected on d.xz / |d.y|, so the poles never pinch).
shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 neb_a : source_color = vec4(0.18, 0.36, 0.95, 1.0);
uniform vec4 neb_b : source_color = vec4(0.52, 0.22, 0.88, 1.0);
uniform vec4 neb_c : source_color = vec4(0.95, 0.42, 0.78, 1.0);
uniform vec4 deep : source_color = vec4(0.015, 0.012, 0.05, 1.0);
uniform float nebula = 1.25;
uniform float stars = 1.15;
uniform float energy = 1.0;

void sky() {
	vec3 d = EYEDIR;
	vec2 uv = vec2(atan(d.x, d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	// LOD 0 avoids a mip seam where atan() wraps.
	vec3 base = textureLod(panorama, uv, 0.0).rgb;
	float lum = dot(base, vec3(0.3, 0.5, 0.2));
	// Keep the panorama's stars crisp and push its own clouds down a little.
	vec3 sky_col = mix(base * 0.7, base * stars, smoothstep(0.35, 0.6, lum));
	vec2 p = d.xz / (abs(d.y) + 0.35);
	float n1 = texture(noise_tex, p * 0.3 + vec2(0.13, 0.41)).r;
	float n2 = texture(noise_tex, p * 0.62 - vec2(0.31, 0.12)).r;
	float n3 = texture(noise_tex, p * 1.3 + vec2(n1 * 0.35, n2 * 0.2)).r;
	float body = smoothstep(0.45, 0.88, n1 * 0.62 + n2 * 0.38);
	float wisp = smoothstep(0.56, 0.92, n2 * 0.45 + n3 * 0.55);
	float dark = smoothstep(0.55, 0.25, n1 * 0.5 + n3 * 0.5);
	vec3 neb = mix(neb_a.rgb, neb_b.rgb, smoothstep(0.3, 0.72, n2));
	neb = mix(neb, neb_c.rgb, smoothstep(0.62, 0.9, n3) * 0.55);
	vec3 col = mix(sky_col, deep.rgb + sky_col * 0.6, dark * 0.5);
	col += neb * (body * 0.42 + wisp * 0.26 + body * wisp * 0.35) * nebula;
	COLOR = col * energy;
}
