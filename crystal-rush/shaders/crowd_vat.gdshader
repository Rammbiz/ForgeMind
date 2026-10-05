// Crowd units with baked skeletal animation (vertex animation textures, tools/bake_vat.gd).
// Drop-in alternative to crowd.gdshader for CrowdView / UnitFx: same INSTANCE_CUSTOM layout and
// the same look uniforms (tint, saturation, overlay, edge, flash, foot occlusion, hero lighting).
//
// INSTANCE_CUSTOM = (phase, hop, sway, flash):
//   phase  radians 0..2π (CrowdView's golden-angle phase): offsets each unit along the clip so a
//          crowd is never in step (the clip's spread x phase_spread scales how far)
//   hop    extra bounce in world units, synced to the clip's own steps (hop_scale, default off:
//          the baked run already bobs)
//   sway   side-roll amplitude in radians, scaled by sway_scale for a little per-unit life
//   flash  0..1 white hit flash
//
// Every instance of one material plays the same clip: `clip` = (first frame, frame count, fps,
// spread) from the clip table; spread 0 = a one-shot, > 0 = a loop whose units are spread over
// that share of a loop (1 = fully out of step, 0.3 = a ragged wave). The unit's place in the loop
// mixes its phase with an integer hash of INSTANCE_ID, so neighbours in a sunflower blob (whose
// golden-angle phases are nearly equal) never step in sync. The vertex index comes from UV2.x
// (not VERTEX_ID); frames are read with texelFetch from half-float textures, two frames blended,
// plus an optional cross-fade from `prev_clip`. Time: `clip_time` (seconds since the clip
// started, driven by VatClip.tick()) or, when it is negative, TIME wrapped to whole loops.
//
// Look: materials split from the painted albedo (pearl armour, glossy gold, crystal crest, matte
// cloth) and a custom light() that softens the shadows units cast on each other (see below).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform highp sampler2D vat_pos : filter_nearest, repeat_disable;
uniform highp sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vat_width = 1;              // texels per row (vertex count unless wrapped)
uniform int vat_rows_per_frame = 1;     // rows one frame takes (> 1 when vertices wrap)
uniform vec4 clip = vec4(0.0, 1.0, 30.0, 1.0);       // first frame, frames, fps, spread (0 = once)
uniform float clip_time = -1.0;         // seconds into the clip; < 0 = use TIME
uniform vec4 prev_clip = vec4(0.0, 1.0, 30.0, 1.0);  // clip being faded out
uniform float prev_time = 0.0;
uniform float clip_blend : hint_range(0.0, 1.0) = 1.0;  // 1 = only `clip`
uniform float speed = 1.0;              // playback rate (both clips)
uniform float phase_spread : hint_range(0.0, 1.0) = 1.0; // scales every clip's own spread
uniform float phase_scramble : hint_range(0.0, 1.0) = 1.0; // 0 = phase only, 1 = hashed per instance
uniform float oneshot_jitter = 0.25;    // seconds of per-unit delay on clips that do not loop

uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.18, 1.0, 0.55, 1.0);
uniform float overlay_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform float edge_amount : hint_range(0.0, 2.0) = 0.0;
// The knights' pale crest and pearl armour already glow against the road: CrowdView.set_edge()
// amounts made for the procedural soldiers (Army uses 0.35) are scaled down by this.
uniform float edge_scale = 0.35;
uniform bool vertex_color_srgb = true;
// Kept from crowd.gdshader so CrowdView.set_gait() still works: integer rates keep TIME seamless.
uniform float hop_rate = 12.0;
uniform float sway_rate = 6.0;
uniform float hop_scale = 0.0;          // 0 = the baked bob only
// Size of every unit (1 = the baked 0.75): a 220-knight blob reads better a little smaller
// (VatClip.set_unit_scale / VatClip.crowd_scale).
uniform float unit_scale = 1.0;
uniform float sway_scale = 0.35;
uniform float ao_height = 0.38;
uniform float ao_strength = 0.5;
uniform float roughness_value = 0.8;
uniform float rim_value = 0.35;
// Materials read from the painted albedo (the Meshy texture has no other maps): white armour
// becomes polished lacquered steel, gold trim glossy gold, the cyan crest a crystal with a cold
// inner glow, blue cloth stays matte. 0 = the flat matte look of crowd.gdshader.
uniform float material_split : hint_range(0.0, 1.0) = 1.0;
uniform float armour_gain = 0.96;         // white armour albedo (keeps its shading off the clip)
uniform float armour_roughness = 0.28;
// Pearl white instead of the painted lavender, so the army stays warm against the blue road.
uniform vec4 armour_tint : source_color = vec4(1.0, 0.975, 0.94, 1.0);
uniform float gold_gain = 1.25;
uniform float gold_roughness = 0.3;
uniform float gold_metallic = 0.3;
uniform float vibrance = 1.3;             // extra saturation of gold and cloth
uniform vec4 crystal_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float crystal_glow = 0.45;
uniform float crystal_tint = 0.3;         // how far the crest is pushed towards crystal_color
// Lighting (custom light(), close to the heroes' Burley + GGX): a dense blob would otherwise sit
// in its own shadow, the sun being behind the camera, and read as grey; units receive shadows at
// `self_shadow` strength (the road still gets the full shadow of the army). `light_wrap` softens
// the terminator like the painted Meshy shading.
uniform float self_shadow : hint_range(0.0, 1.0) = 0.35;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.1;
// Darkens surfaces seen edge-on, so overlapping white helmets in a dense blob stay apart.
uniform float edge_shade : hint_range(0.0, 1.0) = 0.5;
// Mip bias of the albedo: the Meshy atlas packs islands tightly, so far mips bleed neighbouring
// islands (gold specks, grey mush); a negative bias keeps the colours clean on small units.
uniform float albedo_bias = -0.8;
uniform float spec_strength = 1.0;

varying float v_flash;
varying float v_height;
varying float v_spec;

// Frame pair and blend weight for clip c at time t (seconds) for a unit at phase u (0..1).
void vat_frames(vec4 c, float t, float u, out int f0, out int f1, out float w) {
	float frames = max(c.y, 1.0);
	float fr;
	if (c.w > 0.001) {
		fr = mod(t * c.z * speed + u * c.w * phase_spread * frames, frames);
		float a = floor(fr);
		f0 = int(a);
		f1 = int(mod(a + 1.0, frames));
		w = fr - a;
	} else {
		fr = clamp((t - u * oneshot_jitter) * c.z * speed, 0.0, frames - 1.0);
		float a = floor(fr);
		f0 = int(a);
		f1 = min(f0 + 1, int(frames) - 1);
		w = fr - a;
	}
	f0 += int(c.x + 0.5);
	f1 += int(c.x + 0.5);
}

ivec2 vat_texel(int frame, int vid) {
	return ivec2(vid % vat_width, frame * vat_rows_per_frame + vid / vat_width);
}

// Position (with the stored root yaw re-applied as a rotation) and normal of vertex `vid`.
void vat_sample(vec4 c, float t, float u, int vid, out vec3 p, out vec3 n, out float b) {
	int f0;
	int f1;
	float w;
	vat_frames(c, t, u, f0, f1, w);
	vec4 a0 = texelFetch(vat_pos, vat_texel(f0, vid), 0);
	vec4 a1 = texelFetch(vat_pos, vat_texel(f1, vid), 0);
	vec3 n0 = texelFetch(vat_nrm, vat_texel(f0, vid), 0).xyz;
	vec3 n1 = texelFetch(vat_nrm, vat_texel(f1, vid), 0).xyz;
	// Yaw: shortest way round, so a spin keeps its shape between frames.
	float dy = a1.w - a0.w;
	dy -= 6.2831853 * floor(dy / 6.2831853 + 0.5);
	float yaw = a0.w + dy * w;
	float cy = cos(yaw);
	float sy = sin(yaw);
	mat3 r = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	p = r * mix(a0.xyz, a1.xyz, w);
	n = r * mix(n0, n1, w);
	// Step bounce of a two-step loop: 0 at the frame the loop starts on, 1 between steps.
	float fr = float(f0 - int(c.x + 0.5)) + w;
	b = abs(sin(fr / max(c.y, 1.0) * 6.2831853));
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	v_flash = cd.w;
	int vid = int(UV2.x + 0.5);
	// Integer hash of the instance (lowbias32): exact on every GLES3 GPU, unlike sin-hashes.
	uint h = uint(INSTANCE_ID);
	h ^= h >> 16u;
	h *= 0x7feb352du;
	h ^= h >> 15u;
	h *= 0x846ca68bu;
	h ^= h >> 16u;
	float u = fract(cd.x * 0.15915494 + float(h & 0xffffu) * (1.0 / 65536.0) * phase_scramble);
	float t = clip_time;
	if (t < 0.0) {
		// Wrap TIME to whole loops (about 8 s) so float precision never drifts.
		float loop_len = clip.y / max(clip.z * speed, 0.001);
		t = mod(TIME, loop_len * ceil(8.0 / loop_len));
	}
	vec3 p;
	vec3 n;
	float b;
	vat_sample(clip, t, u, vid, p, n, b);
	if (clip_blend < 0.999) {
		vec3 p2;
		vec3 n2;
		float b2;
		vat_sample(prev_clip, prev_time, u, vid, p2, n2, b2);
		p = mix(p2, p, clip_blend);
		n = mix(n2, n, clip_blend);
		b = mix(b2, b, clip_blend);
	}
	v_height = p.y;  // unscaled: the foot occlusion keeps its share of the body
	// Per-unit life on top of the clip: a small side roll about the feet and an optional bounce.
	float tw = mod(TIME, 6.2831853);
	float roll = sin(tw * sway_rate + cd.x * 1.37) * cd.z * sway_scale;
	float cr = cos(roll);
	float sr = sin(roll);
	mat3 rz = mat3(vec3(cr, sr, 0.0), vec3(-sr, cr, 0.0), vec3(0.0, 0.0, 1.0));
	VERTEX = rz * (p * unit_scale) + vec3(0.0, b * cd.y * hop_scale, 0.0);
	NORMAL = normalize(rz * n);
}

void fragment() {
	vec3 vc = COLOR.rgb;
	// On gl_compatibility (OUTPUT_IS_SRGB) the output is not re-encoded, so this decode darkens
	// the vertex colours (vs a StandardMaterial); the masks and shades below are tuned to that.
	if (vertex_color_srgb) {
		vc = mix(pow((vc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), vc * (1.0 / 12.92), lessThan(vc, vec3(0.04045)));
	}
	vec3 a = vc * texture(albedo_tex, UV, albedo_bias).rgb;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// Material masks from the colour (linear): steel = bright and grey, gold = warm and
	// saturated, crystal = bright cyan, cloth = deep blue.
	float mx = max(a.r, max(a.g, a.b));
	float sat = (mx - min(a.r, min(a.g, a.b))) / max(mx, 0.001);
	float steel = (1.0 - smoothstep(0.12, 0.35, sat)) * smoothstep(0.2, 0.5, mx);
	float gold = smoothstep(0.45, 0.75, sat) * smoothstep(0.08, 0.25, a.r - a.b) * step(a.b, a.g);
	float crystal = smoothstep(0.08, 0.25, a.g - a.r) * smoothstep(0.35, 0.65, a.g) * smoothstep(0.4, 0.7, a.b);
	float cloth = smoothstep(0.06, 0.2, a.b - a.g) * (1.0 - crystal);
	steel *= material_split;
	gold *= material_split;
	crystal *= material_split;
	cloth *= material_split;
	float l0 = dot(a, vec3(0.2126, 0.7152, 0.0722));
	a = mix(a, mix(vec3(l0), a, vibrance), max(gold, cloth));
	a *= mix(vec3(1.0), armour_tint.rgb * armour_gain, steel);
	a *= mix(1.0, gold_gain, gold);
	a = mix(a, a * crystal_color.rgb * 1.1, crystal * crystal_tint);
	a *= tint.rgb;
	float lum = dot(a, vec3(0.2126, 0.7152, 0.0722));
	a = mix(vec3(lum), a, saturation);
	// Soft occlusion towards the feet grounds the units in a dense blob.
	float ao = mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, v_height));
	a *= ao;
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	a *= 1.0 - edge_shade * (1.0 - nv) * (1.0 - nv);
	a = mix(a, a * overlay_color.rgb, overlay_amount * 0.55);
	a = mix(a, vec3(1.0), clamp(v_flash, 0.0, 1.0) * 0.75);
	ALBEDO = a;
	ROUGHNESS = mix(mix(mix(roughness_value, armour_roughness, steel), gold_roughness, gold), 0.18, crystal);
	METALLIC = gold * gold_metallic;
	SPECULAR = 0.4 + 0.25 * max(steel, max(gold, crystal));
	v_spec = 0.4 + 0.6 * max(steel, max(gold, crystal));
	RIM = rim_value;
	RIM_TINT = 0.6;
	float pulse = 0.8 + 0.2 * sin(mod(TIME, 6.2831853) * 4.0);
	vec3 crystal_light = crystal_color.rgb * crystal * crystal_glow * (0.12 + 0.9 * fres) * ao
		* clamp(saturation, 0.0, 1.0);
	EMISSION = overlay_color.rgb * overlay_amount * (0.12 + 2.6 * fres) * pulse
		+ edge_color.rgb * edge_amount * edge_scale * fres
		+ crystal_light
		+ vec3(1.0) * clamp(v_flash, 0.0, 1.0) * 1.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + light_wrap) / ((1.0 + light_wrap) * (1.0 + light_wrap)), 0.0, 1.0);
	float sh = mix(1.0, ATTENUATION, self_shadow);
	DIFFUSE_LIGHT += LIGHT_COLOR * wrap * sh * (1.0 / 3.14159265);
	// Normalised Blinn-Phong with roughness mapped like GGX's look; gold tints its highlight.
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float r = clamp(ROUGHNESS, 0.04, 1.0);
	float shin = 2.0 / (r * r * r * r) - 2.0;
	shin = min(shin, 2048.0);
	float spec = pow(ndh, shin) * (shin + 8.0) * (1.0 / 25.1327412) * clamp(ndl, 0.0, 1.0);
	vec3 f0 = mix(vec3(0.04 * v_spec * 2.0), ALBEDO, METALLIC);
	float vh = clamp(dot(VIEW, h), 0.0, 1.0);
	vec3 fr = f0 + (vec3(1.0) - f0) * pow(1.0 - vh, 5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * fr * spec * sh * spec_strength * (1.0 / 3.14159265);
	// Rim (the fragment's RIM is not applied by a custom light()).
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - nv, 4.0) * clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * rim_value;
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * sh * (1.0 / 3.14159265) * 1.5;
}
