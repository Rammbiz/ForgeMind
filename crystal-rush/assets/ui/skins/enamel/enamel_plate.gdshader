// «Емаль і золото» (UI direction C): one machined ENAMEL PLATE, drawn from a signed distance
// field so every size is crisp and anti-aliased. The owned shape: a rectangle whose top-left
// and bottom-right corners are cut at 45 degrees while the other two keep a small machined
// radius (per-corner `chamfers` / `radii`, so chips can flip it). Layers, back to front:
//   drop shadow -> SKIRT (the darker enamel side of a physical key, `depth` px tall)
//   -> FACE (glazed enamel ramp + pillow bevel + specular oval + orange-peel)
//   -> GOLD TRIM (a bevelled bead inset from the edge, following the chamfers)
//   -> RIVETS (gold domes at the chamfers and every `rivet_every` px along the long trims)
//   -> ink outline round the silhouette.
// `press` 0..1 sinks the face into its skirt (a key press leaves 3 px of skirt).
// `recess` 1 turns the plate into a sunk tray / window: inner shadow on the lit side, no skirt.
shader_type canvas_item;

uniform vec2 size = vec2(200.0, 100.0);      // node size in px
uniform float pad = 16.0;                    // margin round the shape (shadow / glow room)
uniform vec4 chamfers = vec4(16.0, 0.0, 16.0, 0.0);  // TL, TR, BR, BL (45 deg cut leg, px)
uniform vec4 radii = vec4(0.0, 6.0, 0.0, 6.0);       // TL, TR, BR, BL
uniform float depth = 0.0;                   // skirt height (0 = flat plate)
uniform float press = 0.0;
uniform float recess = 0.0;

uniform vec4 face_top : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 face_mid : source_color = vec4(0.957, 0.945, 0.918, 1.0);
uniform vec4 face_bot : source_color = vec4(0.89, 0.867, 0.816, 1.0);
uniform vec4 skirt_top : source_color = vec4(0.788, 0.753, 0.682, 1.0);
uniform vec4 skirt_bot : source_color = vec4(0.62, 0.58, 0.506, 1.0);
uniform vec4 outline : source_color = vec4(0.06, 0.07, 0.16, 0.75);
uniform float outline_w = 1.6;

uniform float trim_w = 4.0;                  // 0 = no trim
uniform float trim_inset = 3.0;
uniform vec4 trim_dark : source_color = vec4(0.478, 0.306, 0.071, 1.0);
uniform vec4 trim_mid : source_color = vec4(0.886, 0.69, 0.29, 1.0);
uniform vec4 trim_light : source_color = vec4(1.0, 0.906, 0.639, 1.0);

uniform float rivet_r = 0.0;                 // 0 = no rivets
uniform float rivet_every = 0.0;             // extra rivets along top / bottom trim (0 = none)
uniform float spec_k = 0.55;
uniform float bevel_w = 7.0;
uniform float bevel_k = 0.22;
uniform float noise_k = 0.025;
uniform float shadow_k = 0.45;
uniform vec2 shadow_off = vec2(0.0, 7.0);
uniform float shadow_blur = 10.0;
uniform vec4 glow : source_color = vec4(0.56, 0.92, 1.0, 0.0);
uniform float glow_r = 14.0;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Plate SDF: q relative to the centre, b half size.
float sd_plate(vec2 q, vec2 b) {
	// Per-quadrant radius (y grows downwards: q.y < 0 is the top).
	float r = q.x > 0.0 ? (q.y < 0.0 ? radii.y : radii.z) : (q.y < 0.0 ? radii.x : radii.w);
	vec2 qq = abs(q) - b + r;
	float d = min(max(qq.x, qq.y), 0.0) + length(max(qq, 0.0)) - r;
	float k = b.x + b.y;
	const float S = 0.70710678;
	if (chamfers.x > 0.0) d = max(d, (-q.x - q.y - (k - chamfers.x)) * S);
	if (chamfers.y > 0.0) d = max(d, (q.x - q.y - (k - chamfers.y)) * S);
	if (chamfers.z > 0.0) d = max(d, (q.x + q.y - (k - chamfers.z)) * S);
	if (chamfers.w > 0.0) d = max(d, (-q.x + q.y - (k - chamfers.w)) * S);
	return d;
}

vec3 gold_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	if (t < 0.5) return mix(trim_dark.rgb, trim_mid.rgb, t * 2.0);
	return mix(trim_mid.rgb, trim_light.rgb, (t - 0.5) * 2.0);
}

vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	if (a < 1e-4) return vec4(0.0);
	return vec4((src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / a, a);
}

// Gold dome at c (radius r): returns premultiplied-free rgba.
vec4 rivet(vec2 p, vec2 c, float r) {
	vec2 v = (p - c) / r;
	float l = length(v);
	vec4 o = vec4(0.0);
	// contact shadow
	float sh = 1.0 - smoothstep(0.7, 1.35, length((p - c - vec2(0.8, 1.4)) / r));
	o = over(o, vec4(0.0, 0.0, 0.05, 0.45 * sh));
	float a = clamp((1.0 - l) * r + 0.5, 0.0, 1.0);
	if (a > 0.0) {
		float z = sqrt(max(1.0 - l * l, 0.0));
		vec3 n = normalize(vec3(v, z * 1.2));
		vec3 L = normalize(vec3(-0.45, -0.75, 0.6));
		float lam = dot(n, L);
		float spec = pow(max(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0), 18.0);
		vec3 col = gold_ramp(0.38 + 0.55 * lam) + vec3(spec * 0.9);
		col *= mix(0.55, 1.0, smoothstep(1.0, 0.72, l));
		o = over(o, vec4(col, a));
	}
	return o;
}

void fragment() {
	vec2 p = lp;
	vec2 inner = size - 2.0 * pad;
	float sink = recess > 0.5 ? 0.0 : press * max(depth - 3.0, 0.0);
	float rd = recess > 0.5 ? 0.0 : depth - sink;
	vec2 fb = vec2(inner.x, inner.y - depth) * 0.5;           // face half size
	vec2 fc = vec2(pad + fb.x, pad + sink + fb.y);            // face centre
	vec2 q = p - fc;
	float d_face = sd_plate(q, fb);
	// Skirt: the face swept straight down by rd.
	float t = clamp(q.y, 0.0, rd);
	float d_all = sd_plate(q - vec2(0.0, t), fb);

	vec4 col = vec4(0.0);
	// Glow (selection / ready), then the drop shadow.
	if (glow.a > 0.0) {
		float g = exp(-max(d_all, 0.0) / glow_r) * smoothstep(-2.0, 2.0, d_all);
		col = over(col, vec4(glow.rgb, glow.a * g));
	}
	if (shadow_k > 0.0 && recess < 0.5) {
		vec2 qs = q - shadow_off;
		float ts = clamp(qs.y, 0.0, rd);
		float ds = sd_plate(qs - vec2(0.0, ts), fb);
		float sa = shadow_k * (1.0 - smoothstep(-shadow_blur * 0.5, shadow_blur, ds));
		col = over(col, vec4(0.0, 0.0, 0.04, sa));
	}
	// Ink outline round the whole silhouette.
	float a_out = clamp(0.5 - (d_all - outline_w), 0.0, 1.0);
	col = over(col, vec4(outline.rgb, outline.a * a_out));
	// Skirt.
	float a_all = clamp(0.5 - d_all, 0.0, 1.0);
	if (a_all > 0.0 && rd > 0.0) {
		float sy = clamp((q.y - fb.y + 4.0) / (rd + 4.0), 0.0, 1.0);
		vec3 sc = mix(skirt_top.rgb, skirt_bot.rgb, sy);
		// Rounded skirt edge: lighter towards the light at the left.
		sc *= 0.92 + 0.12 * smoothstep(fb.x, -fb.x, q.x);
		sc *= 1.0 - 0.25 * smoothstep(-3.0, 0.0, d_all);
		col = over(col, vec4(sc, a_all));
	}
	// Face.
	float a_face = clamp(0.5 - d_face, 0.0, 1.0);
	if (a_face > 0.0) {
		float v = clamp((q.y + fb.y) / (2.0 * fb.y), 0.0, 1.0);
		vec3 fcol = v < 0.45 ? mix(face_top.rgb, face_mid.rgb, v / 0.45) : mix(face_mid.rgb, face_bot.rgb, (v - 0.45) / 0.55);
		// Outward normal from the SDF gradient.
		vec2 e = vec2(0.75, 0.0);
		vec2 n = normalize(vec2(sd_plate(q + e.xy, fb) - sd_plate(q - e.xy, fb), sd_plate(q + e.yx, fb) - sd_plate(q - e.yx, fb)) + 1e-5);
		vec2 L = normalize(vec2(-0.45, -1.0));
		float edge = 1.0 - smoothstep(0.0, bevel_w, -d_face);
		float lam = dot(n, L);
		if (recess > 0.5) {
			// Sunk: the rim shades the lit side, the far side catches light.
			fcol *= 1.0 - bevel_k * edge * lam * 1.6;
			vec2 so = vec2(3.0, 6.0);
			float ds = sd_plate(q - so, fb);
			fcol *= 1.0 - 0.45 * smoothstep(-8.0, 1.0, ds);
		} else {
			// Pillow: glazed enamel rolls over the edge.
			fcol += vec3(bevel_k * edge * lam);
			// Specular oval in the top third (not a band).
			vec2 so = (q - vec2(-fb.x * 0.18, -fb.y * 0.42)) / vec2(fb.x * 0.78, max(fb.y * 0.42, 8.0));
			float spec = 1.0 - smoothstep(0.35, 1.0, length(so));
			fcol = mix(fcol, vec3(1.0), spec * spec_k * 0.55);
		}
		fcol += (hash(floor(p * 0.75)) - 0.5) * noise_k;
		// Hairline light lip just inside the top-left edge.
		float lip = smoothstep(-2.6, -1.2, d_face) * (1.0 - smoothstep(-1.2, 0.0, d_face));
		fcol = mix(fcol, recess > 0.5 ? fcol * 0.7 : vec3(1.0), lip * clamp(lam, 0.0, 1.0) * 0.8);
		col = over(col, vec4(fcol, a_face));
		// Gold trim bead.
		if (trim_w > 0.0) {
			float s = -d_face - trim_inset;
			float a_t = clamp(s + 0.5, 0.0, 1.0) * clamp(trim_w - s + 0.5, 0.0, 1.0);
			if (a_t > 0.0) {
				float u = clamp(s / trim_w, 0.0, 1.0);
				float facing = cos(u * 3.14159);          // outer half faces out, inner half in
				float lt = dot(n * facing, L);
				float g = 0.5 + 0.5 * lt;
				vec3 gc = gold_ramp(g * 0.9 + 0.08 * sin(u * 3.14159));
				gc += vec3(pow(max(lt, 0.0), 6.0) * 0.35);
				// crisp dark seat lines at both edges of the bead
				float seat = max(1.0 - smoothstep(0.0, 1.0, s), 1.0 - smoothstep(0.0, 1.0, trim_w - s));
				gc = mix(gc, trim_dark.rgb * 0.7, seat * 0.55);
				col = over(col, vec4(gc, a_t * a_face));
			}
		}
		// Rivets.
		if (rivet_r > 0.0) {
			float on = trim_w > 0.0 ? trim_inset + trim_w * 0.5 : rivet_r + 3.0;
			const float S = 0.70710678;
			vec2 cs[4] = vec2[4](vec2(-fb.x, -fb.y), vec2(fb.x, -fb.y), vec2(fb.x, fb.y), vec2(-fb.x, fb.y));
			vec2 ins[4] = vec2[4](vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0));
			float chs[4] = float[4](chamfers.x, chamfers.y, chamfers.z, chamfers.w);
			for (int i = 0; i < 4; i++) {
				if (chs[i] > 0.0) {
					vec2 m = cs[i] + ins[i] * chs[i] * 0.5 + ins[i] * S * on;
					col = over(col, rivet(q, m, rivet_r));
				}
			}
			if (rivet_every > 0.0) {
				float span = 2.0 * fb.x - 2.0 * max(max(chamfers.x, chamfers.y), 24.0);
				int nr = int(floor(span / rivet_every));
				for (int i = 1; i < 12; i++) {
					if (i > nr) break;
					float x = -span * 0.5 + span * float(i) / float(nr + 1);
					col = over(col, rivet(q, vec2(x, -fb.y + on), rivet_r * 0.85));
					col = over(col, rivet(q, vec2(x, fb.y - on), rivet_r * 0.85));
				}
			}
		}
	}
	COLOR = col;
}
