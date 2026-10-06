// Cache egg shell chunks (CacheModels). Stone colour from two baked-noise layers sampled at the
// chunk's REST position (UV.y = rest y, UV2 = rest x/z), so the texture stays glued to a chunk
// while it flies. UV.x = distance to the chunk's edge (world units): `seam` lights permanent
// seams (World Cache amethyst), `tell` + `crack_w` light the cracks in the colour of the best
// rarity inside (§5.6 honest tell). Vertex COLOR.rgb = tint, COLOR.a = 1 on the broken walls
// and the inner face (they glow with the tell). No sin-hash, no pow of negatives.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 base : source_color = vec4(0.42, 0.47, 0.58, 1.0);
uniform vec4 base2 : source_color = vec4(0.28, 0.32, 0.42, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 seam_color : source_color = vec4(0.7, 0.4, 1.0, 1.0);
uniform float seam = 0.0;
uniform vec4 tell_color : source_color = vec4(0.25, 0.65, 1.0, 1.0);
uniform float tell = 0.0;
uniform float crack_w = 0.0;
uniform float roughness = 0.55;
uniform float metallic = 0.1;
uniform float fleck = 0.35;

void fragment() {
	vec3 rp = vec3(UV2.x, UV.y, UV2.y);
	float n1 = texture(noise_tex, vec2(rp.x + rp.z * 0.6, rp.y) * 1.4).r;
	float n2 = texture(noise_tex, vec2(rp.z - rp.x * 0.7, rp.y * 1.3) * 3.3).r;
	float n = n1 * 0.65 + n2 * 0.35;
	vec3 albedo = mix(base2.rgb, base.rgb, smoothstep(0.25, 0.75, n)) * COLOR.rgb;
	// Mineral flecks catch the light.
	float f = smoothstep(0.72, 0.8, n2) * fleck;
	ALBEDO = albedo + vec3(f * 0.35);
	ROUGHNESS = clamp(roughness - f * 0.4, 0.05, 1.0);
	METALLIC = metallic + f * 0.4;
	float edge = UV.x;
	float wall = COLOR.a;
	float seam_line = (1.0 - smoothstep(0.0, 0.022, edge)) * (1.0 - wall);
	float crack = (1.0 - smoothstep(crack_w * 0.35, crack_w + 0.001, edge)) * step(0.0005, crack_w) * (1.0 - wall);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = (1.0 - facing) * (1.0 - facing);
	vec3 em = seam_color.rgb * seam * seam_line * 2.0;
	em += tell_color.rgb * tell * (crack * 1.5 + wall * 1.4 + rim * 0.3);
	EMISSION = em;
}
