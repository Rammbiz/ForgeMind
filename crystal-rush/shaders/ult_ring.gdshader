// Ult charge ring on the ground under the hero (Models.ult_ring): a segmented arc that fills
// clockwise from the front with a hot head, on a dark backing ring so it reads on the bright
// crystal road. When ready it turns gold, breathes and spins a dashed outer halo.
// TIME is wrapped to 4 s; every rate is a whole number of cycles per wrap.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 charge_color : source_color = vec4(0.45, 0.88, 1.0, 1.0);
uniform vec4 ready_color : source_color = vec4(1.0, 0.8, 0.28, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 0.74;        // ring centre, fraction of the half size
uniform float thickness = 0.075;    // half thickness, same units
uniform float segments = 28.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float band(float x, float c, float w) {
	float aa = fwidth(x) * 1.2;
	return 1.0 - smoothstep(w - aa, w + aa, abs(x - c));
}

void fragment() {
	float t = mod(TIME, 4.0);
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float f = fract(atan(c.x, -c.y) / 6.2831853 + 1.0);   // 0..1 clockwise from the front
	float pulse = 0.5 + 0.5 * sin(t * 6.2831853);          // 1 Hz
	float R = radius + ready * pulse * 0.025;
	float ring = band(r, R, thickness);
	float backing = band(r, R, thickness + 0.04);
	float seg = fract(f * segments);
	float sw = fwidth(f * segments) * 1.5;
	float gaps = smoothstep(0.0, 0.07 + sw, seg) * smoothstep(1.0, 0.93 - sw, seg);
	float faa = fwidth(f) * 1.5;
	float filled = 1.0 - smoothstep(progress - faa, progress, f);
	filled = max(filled * step(0.001, progress), ready);
	filled = max(filled, step(0.999, progress));
	vec3 col = mix(charge_color.rgb, ready_color.rgb, ready);
	float core = band(r, R, thickness * 0.4);

	vec3 rgb = vec3(0.03, 0.05, 0.13);
	float a = backing * 0.6;
	float lit = ring * gaps;
	rgb = mix(rgb, col * 0.35, ring * (1.0 - filled) * gaps * 0.8);
	rgb = mix(rgb, col, lit * filled);
	rgb = mix(rgb, vec3(1.0), core * lit * filled * (0.45 + 0.3 * ready * pulse));
	a = max(a, lit * (0.35 + 0.65 * filled));
	// Hot head at the fill front while charging.
	float hd = (f - progress) * 40.0;     // squared by hand: pow() of a negative base is undefined
	float head = exp(-hd * hd) * ring * (1.0 - ready) * step(0.001, progress);
	rgb = mix(rgb, vec3(1.0), head);
	a = max(a, head);
	// Ready: soft breathing halo and spinning dashes outside the ring.
	float hr = (r - R) / 0.16;
	float halo = exp(-hr * hr) * ready * (0.25 + 0.35 * pulse);
	float dr = R + thickness + 0.075;
	float dash = band(r, dr, 0.018) * step(0.5, fract(f * 12.0 - t * 0.5)) * ready;
	float inner = smoothstep(R - thickness, R - thickness - 0.35, r) * smoothstep(0.0, 0.4, r) * ready * (0.08 + 0.1 * pulse);
	rgb = mix(rgb, col, clamp(halo * (1.0 - ring) + dash + inner, 0.0, 1.0));
	a = max(a, max(halo, max(dash * 0.9, inner)));
	ALBEDO = rgb;
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}
