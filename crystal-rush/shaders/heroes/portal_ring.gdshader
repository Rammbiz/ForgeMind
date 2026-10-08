// The Portal ring (heroes_design.md §9.3 Portal; fusion §6.8 #4): a gold torus that reads as 3D
// (tube normals lit from the upper left, a specular line, engraved filigree grooves and two thin
// rim rings), a swirling starlit interior that falls away like a tunnel, and a soft halo. The five
// gem sockets are drawn on top by PortalRing (GDScript). Ceremony controls: `tint` (the pool /
// best gem), `charge` (interior brightness), `pulse` (a gleam running round the tube), `opal`
// (spectral interior for the Opal tell), `open` (the interior blooms white-gold before a reveal).
// Driven by the uniform `t`, never TIME (seekable dev shots). One quad, no textures.
shader_type canvas_item;

uniform float t = 0.0;
uniform vec4 tint : source_color = vec4(0.66, 0.55, 1.0, 1.0);
uniform vec4 tint_hi : source_color = vec4(1.0, 0.9, 0.62, 1.0);
uniform float charge = 0.0;
uniform float pulse = -1.0;      // gleam angle 0..1 round the ring (< 0 = off)
uniform float opal = 0.0;
uniform float open = 0.0;
uniform float ring_r = 0.78;     // tube centre radius (UV half-size units)
uniform float tube_w = 0.07;



float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), u.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

vec3 spectrum(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

vec3 gold(float k) {
	vec3 lo = vec3(0.30, 0.18, 0.06);
	vec3 mid = vec3(0.79, 0.60, 0.27);
	vec3 hi = vec3(1.0, 0.92, 0.66);
	return k < 0.6 ? mix(lo, mid, k / 0.6) : mix(mid, hi, (k - 0.6) / 0.4);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	vec2 dir = q / max(r, 1e-4);
	vec4 outc = vec4(0.0);

	// ---- interior: a starlit swirl that falls away like a tunnel
	float ri = ring_r - tube_w;
	if (r < ri + 0.01) {
		float d = r / ri;
		float lr = log(r + 0.06);
		float sw = a + 2.4 * lr - t * 0.32;
		// Noise on the circle (cos, sin) of the swirl angle: no seam where atan wraps.
		vec2 cs = vec2(cos(sw), sin(sw));
		float n1 = vnoise(cs * 1.6 + vec2(lr * 3.0 - t * 0.45, 2.0));
		float n2 = vnoise(cs * 3.4 + vec2(5.0, lr * 6.0 - t * 0.7));
		float swirl = n1 * 0.65 + n2 * 0.35;
		float arms = 0.5 + 0.5 * sin(sw * 3.0 + swirl * 2.5);
		vec3 deep = vec3(0.07, 0.05, 0.19);
		vec3 base = mix(deep, tint.rgb * 0.75, smoothstep(0.15, 1.0, arms * swirl + 0.25 * (1.0 - d)));
		vec3 sp = spectrum(fract(a / (2.0 * PI) + t * 0.06 + swirl * 0.4));
		base = mix(base, mix(deep, sp * 0.9, smoothstep(0.2, 0.95, swirl)), opal);
		// Bright core (the light at the end of the tunnel) and a charge bloom.
		float core = exp(-d * d / (0.10 + 0.28 * charge + 0.6 * open));
		base += mix(tint_hi.rgb, vec3(1.0), 0.35 * open) * core * (0.55 + 0.9 * charge + 1.2 * open);
		// Stars drifting inward along the swirl.
		vec2 sg = vec2(fract(sw / (2.0 * PI)) * 24.0, lr * 9.0 - t * 0.9);
		vec2 sid = floor(sg);
		vec2 sf = fract(sg) - 0.5;
		float sh = hash21(sid);
		float st = sh > 0.86 ? smoothstep(0.16, 0.0, length(sf)) * (0.5 + 0.5 * sin(t * 3.0 + sh * 30.0)) : 0.0;
		base += vec3(1.0, 0.96, 0.88) * st * (0.4 + 0.6 * d);
		// Inner shadow under the gold tube (depth).
		base *= mix(0.55, 1.0, smoothstep(1.0, 0.82, d));
		float cov = smoothstep(ri + 0.01, ri - 0.004, r);
		outc = vec4(base, cov);
	}

	// ---- halo outside the tube
	float halo = exp(-pow((r - ring_r) / (0.16 + 0.1 * charge), 2.0)) * (0.32 + 0.45 * charge + 0.4 * open);
	halo *= 1.0 - smoothstep(0.84, 0.99, r);
	vec3 hc = mix(tint.rgb, tint_hi.rgb, 0.4);
	if (r > ring_r) {
		outc = vec4(hc, max(outc.a, halo * 0.8));
	}

	// ---- thin rim rings (outer and inner)
	float rim_o = smoothstep(0.009, 0.0, abs(r - (ring_r + tube_w + 0.03)));
	float rim_i = smoothstep(0.006, 0.0, abs(r - (ri - 0.025)));
	vec3 rimc = gold(0.75);
	if (rim_o > 0.0) {
		outc = vec4(mix(outc.rgb, rimc, rim_o), max(outc.a, rim_o));
	}
	if (rim_i > 0.0) {
		outc = vec4(mix(outc.rgb, rimc * 1.05, rim_i * 0.8), max(outc.a, rim_i * 0.8));
	}
	// Rhombus beads on the outer rim (filigree).
	float beads = 48.0;
	float ba = fract(a / (2.0 * PI) * beads) - 0.5;
	vec2 bp = vec2(ba * 2.0 * PI * (ring_r + tube_w + 0.03) / beads, r - (ring_r + tube_w + 0.03));
	float bead = smoothstep(0.012, 0.0, abs(bp.x) * 0.9 + abs(bp.y) * 1.6 - 0.006);
	if (bead > 0.0) {
		outc = vec4(mix(outc.rgb, gold(0.9), bead), max(outc.a, bead));
	}

	// ---- the gold tube
	float n = (r - ring_r) / tube_w;
	if (abs(n) < 1.0) {
		float z = sqrt(1.0 - n * n);
		vec3 N = normalize(vec3(dir * n, z));
		vec3 L = normalize(vec3(-0.45, -0.7, 0.75));
		float diff = max(dot(N, L), 0.0);
		vec3 R = reflect(-L, N);
		float spec = pow(max(R.z, 0.0), 28.0);
		float k = 0.18 + 0.72 * diff;
		// Engraved grooves: a twisted rope pattern and fine cross-hatching.
		float rope = abs(sin(a * 30.0 + n * 2.2));
		float groove = smoothstep(0.12, 0.0, rope) * 0.35 * z;
		k -= groove;
		vec3 c = gold(clamp(k, 0.0, 1.0)) + vec3(1.0, 0.95, 0.8) * spec * 0.85;
		// The pulse gleam running round the tube.
		if (pulse >= 0.0) {
			float pa = fract(a / (2.0 * PI) + 0.25 - pulse);
			float g = exp(-pow(min(pa, 1.0 - pa) / 0.035, 2.0));
			c += vec3(1.0, 0.97, 0.88) * g * 0.75 * z;
		}
		// Charge warms the metal a little (light from the interior on the inner face).
		c += tint_hi.rgb * max(-n, 0.0) * (0.12 + 0.3 * charge + 0.4 * open);
		float cov = smoothstep(1.0, 0.92, abs(n));
		outc = vec4(mix(outc.rgb, c, cov), max(outc.a, cov));
	}
	COLOR = outc;
}
