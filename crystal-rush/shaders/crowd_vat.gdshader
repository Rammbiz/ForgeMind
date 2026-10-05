// Crowd units with baked skeletal animation (vertex animation textures, tools/bake_vat.gd).
// Drop-in alternative to crowd.gdshader for CrowdView / UnitFx: same INSTANCE_CUSTOM layout and
// the same look uniforms (tint, saturation, overlay, edge, flash, foot occlusion, hero lighting).
//
// INSTANCE_CUSTOM = (phase, hop, sway, flash):
//   phase  radians 0..2π (CrowdView's golden-angle phase): offsets each unit along the clip so a
//          crowd is never in step (phase_spread scales how far)
//   hop    extra bounce in world units, synced to the clip's own steps (hop_scale, default off:
//          the baked run already bobs)
//   sway   side-roll amplitude in radians, scaled by sway_scale for a little per-unit life
//   flash  0..1 white hit flash
//
// Every instance of one material plays the same clip: `clip` = (first frame, frame count, fps,
// loop 0/1) from the clip table. The vertex index comes from UV2.x (not VERTEX_ID); frames are
// read with texelFetch from half-float textures, two frames blended, plus an optional cross-fade
// from `prev_clip`. Time: `clip_time` (seconds since the clip started, driven by VatClip.tick())
// or, when it is negative, TIME wrapped to a whole number of loops.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform highp sampler2D vat_pos : filter_nearest, repeat_disable;
uniform highp sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vat_width = 1;              // texels per row (vertex count unless wrapped)
uniform int vat_rows_per_frame = 1;     // rows one frame takes (> 1 when vertices wrap)
uniform vec4 clip = vec4(0.0, 1.0, 30.0, 1.0);       // first frame, frames, fps, loop
uniform float clip_time = -1.0;         // seconds into the clip; < 0 = use TIME
uniform vec4 prev_clip = vec4(0.0, 1.0, 30.0, 1.0);  // clip being faded out
uniform float prev_time = 0.0;
uniform float clip_blend : hint_range(0.0, 1.0) = 1.0;  // 1 = only `clip`
uniform float speed = 1.0;              // playback rate (both clips)
uniform float phase_spread : hint_range(0.0, 1.0) = 1.0; // share of a loop the phases cover
uniform float oneshot_jitter = 0.25;    // seconds of per-unit delay on clips that do not loop

uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.18, 1.0, 0.55, 1.0);
uniform float overlay_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform float edge_amount : hint_range(0.0, 2.0) = 0.0;
uniform bool vertex_color_srgb = true;
// Kept from crowd.gdshader so CrowdView.set_gait() still works: integer rates keep TIME seamless.
uniform float hop_rate = 12.0;
uniform float sway_rate = 6.0;
uniform float hop_scale = 0.0;          // 0 = the baked bob only
uniform float sway_scale = 0.35;
uniform float ao_height = 0.3;
uniform float ao_strength = 0.45;
uniform float roughness_value = 0.8;
uniform float rim_value = 0.35;

varying float v_flash;
varying float v_height;

// Frame pair and blend weight for clip c at time t (seconds) for a unit at phase u (0..1).
void vat_frames(vec4 c, float t, float u, out int f0, out int f1, out float w) {
	float frames = max(c.y, 1.0);
	float fr;
	if (c.w > 0.5) {
		fr = mod(t * c.z * speed + u * phase_spread * frames, frames);
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
	float u = fract(cd.x * 0.15915494);
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
	v_height = p.y;
	// Per-unit life on top of the clip: a small side roll about the feet and an optional bounce.
	float tw = mod(TIME, 6.2831853);
	float roll = sin(tw * sway_rate + cd.x * 1.37) * cd.z * sway_scale;
	float cr = cos(roll);
	float sr = sin(roll);
	mat3 rz = mat3(vec3(cr, sr, 0.0), vec3(-sr, cr, 0.0), vec3(0.0, 0.0, 1.0));
	VERTEX = rz * p + vec3(0.0, b * cd.y * hop_scale, 0.0);
	NORMAL = normalize(rz * n);
}

void fragment() {
	vec3 vc = COLOR.rgb;
	if (vertex_color_srgb) {
		vc = mix(pow((vc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), vc * (1.0 / 12.92), lessThan(vc, vec3(0.04045)));
	}
	vec3 a = vc * texture(albedo_tex, UV).rgb * tint.rgb;
	float lum = dot(a, vec3(0.2126, 0.7152, 0.0722));
	a = mix(vec3(lum), a, saturation);
	// Soft occlusion towards the feet grounds the units in a dense blob.
	a *= mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, v_height));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	a = mix(a, a * overlay_color.rgb, overlay_amount * 0.55);
	a = mix(a, vec3(1.0), clamp(v_flash, 0.0, 1.0) * 0.75);
	ALBEDO = a;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	RIM = rim_value;
	RIM_TINT = 0.6;
	float pulse = 0.8 + 0.2 * sin(mod(TIME, 6.2831853) * 4.0);
	EMISSION = overlay_color.rgb * overlay_amount * (0.12 + 2.6 * fres) * pulse
		+ edge_color.rgb * edge_amount * fres
		+ vec3(1.0) * clamp(v_flash, 0.0, 1.0) * 1.5;
}
