// Weapon crate glass (WeaponModels.crate): an ice-blue hologram shell with a fresnel edge, a
// scan line sweeping up and cracks that spread with `damage`. `flash` whitens it on a hit.
// TIME is wrapped to 10 s; the scan rate makes whole cycles per wrap.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(0.42, 0.85, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float height = 0.7;
varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float t = mod(TIME, 10.0);
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	fres = fres * fres;
	float y = lpos.y / height + 0.5;
	float s = fract(y * 1.0 - t * 0.4);
	float scan = smoothstep(0.86, 0.97, s) * (1.0 - smoothstep(0.97, 1.0, s));
	float grid = smoothstep(0.9, 1.0, fract(y * 9.0));
	// Cracks: thin contour lines of the noise, revealed as damage grows.
	vec2 cuv = vec2(atan(lpos.x, lpos.z) * 0.32, y * 0.7);
	float n = texture(noise_tex, cuv).r;
	float n2 = texture(noise_tex, cuv * 2.3 + 0.37).r;
	float crack = (1.0 - smoothstep(0.0, 0.025, abs(n - 0.5))) * step(n2, damage * 1.1);
	// Bright vertical lines on the hexagon's corners.
	float seg = atan(lpos.x, lpos.z) / 1.0471976;
	float edge = smoothstep(0.82, 0.97, abs(fract(seg) - 0.5) * 2.0);
	vec3 c = color.rgb * (0.45 + fres * 1.6) + vec3(0.85, 0.97, 1.0) * edge * 0.9 + vec3(0.8, 0.95, 1.0) * (scan * 0.7 + grid * 0.08);
	c += vec3(1.0) * crack * 1.2;
	c = mix(c, vec3(1.6), flash * 0.7);
	ALBEDO = c;
	ALPHA = clamp(0.24 + fres * 0.7 + edge * 0.5 + scan * 0.25 + grid * 0.04 + crack * 0.9 + flash * 0.5, 0.0, 1.0);
}
