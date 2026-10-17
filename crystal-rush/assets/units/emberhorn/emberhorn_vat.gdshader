// The Emberhorn Sentinel crowd (enemy squads, baked by tools/bake_vat.gd profile "emberhorn").
// A sibling of shaders/crowd_vat.gdshader: same VAT decode, INSTANCE_CUSTOM layout
// (phase, hop, sway, flash) and look uniforms (tint, saturation, overlay, edge, flash, foot
// occlusion, custom light), so VatClip.attach() and CrowdView.set_*() work unchanged. VatClip picks
// it up because it sits next to the bake as <base>_vat.gdshader. Additions:
//
// Zone clip: units standing beyond world z = zone_z (the squad's front line, the army side) play
//   `zone_clip` at `zone_time` instead of `clip`, blended over zone_band, so in a clash the front
//   rank stabs while the ranks behind still run up (one crowd, one draw call). Off when
//   zone_on = false.
// Instance time: with instance_time = true, INSTANCE_CUSTOM.x is the unit's own clip time in
//   seconds (no phase): UnitFx plays the one-shot death per dying unit this way.
// Look: lacquered crimson plates, molten-bronze trim, gun-metal black armour and a steel spear,
//   split from the painted albedo; the eyes glow from the albedo's alpha (the bake's glow mask)
//   with a slow, menacing pulse.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform highp sampler2D vat_pos : filter_nearest, repeat_disable;
uniform highp sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vat_width = 1;
uniform int vat_rows_per_frame = 1;
uniform vec4 clip = vec4(0.0, 1.0, 30.0, 1.0);       // first frame, frames, fps, spread (0 = once)
uniform float clip_time = -1.0;
uniform vec4 prev_clip = vec4(0.0, 1.0, 30.0, 1.0);
uniform float prev_time = 0.0;
uniform float clip_blend : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 1.0;
uniform float phase_spread : hint_range(0.0, 1.0) = 1.0;
uniform float phase_scramble : hint_range(0.0, 1.0) = 1.0;
uniform float oneshot_jitter = 0.25;
uniform bool zone_on = false;
uniform vec4 zone_clip = vec4(0.0, 1.0, 30.0, 1.0);
uniform float zone_time = 0.0;
uniform float zone_z = 0.0;
uniform float zone_band = 0.3;
uniform bool instance_time = false;

uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.18, 1.0, 0.55, 1.0);
uniform float overlay_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.15, 1.0);
uniform float edge_amount : hint_range(0.0, 2.0) = 0.0;
uniform float edge_scale = 0.95;
uniform bool vertex_color_srgb = true;
uniform float hop_rate = 12.0;
uniform float sway_rate = 6.0;
uniform float hop_scale = 0.0;
uniform float unit_scale = 1.0;
uniform float sway_scale = 0.35;
uniform float ao_height = 0.38;
uniform float ao_strength = 0.35;
uniform float roughness_value = 0.75;
uniform float rim_value = 0.3;
uniform float material_split : hint_range(0.0, 1.0) = 1.0;
uniform vec4 crimson_tint : source_color = vec4(1.0, 0.93, 0.93, 1.0);
uniform float crimson_gain = 1.28;
uniform float crimson_roughness = 0.3;
uniform vec4 bronze_tint : source_color = vec4(1.0, 0.86, 0.66, 1.0);
uniform float bronze_gain = 1.15;
uniform float bronze_roughness = 0.32;
uniform float bronze_metallic = 0.45;
uniform float black_lift = 1.25;           // gun-metal plates: a touch lifted so they read
uniform float black_roughness = 0.34;
uniform float steel_roughness = 0.24;
uniform float vibrance = 1.2;
uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform float glow_strength = 4.0;
uniform float glow_pulse = 0.25;
uniform float self_shadow : hint_range(0.0, 1.0) = 0.35;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.12;
uniform float edge_shade : hint_range(0.0, 1.0) = 0.22;
uniform float albedo_bias = -0.6;
uniform float spec_strength = 1.0;

varying float v_flash;
varying float v_height;
varying float v_spec;
varying float v_phase;

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

void vat_sample(vec4 c, float t, float u, int vid, out vec3 p, out vec3 n) {
	int f0;
	int f1;
	float w;
	vat_frames(c, t, u, f0, f1, w);
	vec4 a0 = texelFetch(vat_pos, vat_texel(f0, vid), 0);
	vec4 a1 = texelFetch(vat_pos, vat_texel(f1, vid), 0);
	vec3 n0 = texelFetch(vat_nrm, vat_texel(f0, vid), 0).xyz;
	vec3 n1 = texelFetch(vat_nrm, vat_texel(f1, vid), 0).xyz;
	p = mix(a0.xyz, a1.xyz, w);
	n = mix(n0, n1, w);
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	v_flash = cd.w;
	int vid = int(UV2.x + 0.5);
	uint h = uint(INSTANCE_ID);
	h ^= h >> 16u;
	h *= 0x7feb352du;
	h ^= h >> 15u;
	h *= 0x846ca68bu;
	h ^= h >> 16u;
	float u = fract(cd.x * 0.15915494 + float(h & 0xffffu) * (1.0 / 65536.0) * phase_scramble);
	v_phase = float(h & 0xffu) * (1.0 / 255.0);
	float t = clip_time;
	if (instance_time) {
		t = cd.x;
		u = 0.0;
	} else if (t < 0.0) {
		float loop_len = clip.y / max(clip.z * speed, 0.001);
		t = mod(TIME, loop_len * ceil(8.0 / loop_len));
	}
	vec3 p;
	vec3 n;
	vat_sample(clip, t, u, vid, p, n);
	if (clip_blend < 0.999 && !instance_time) {
		vec3 p2;
		vec3 n2;
		vat_sample(prev_clip, prev_time, u, vid, p2, n2);
		p = mix(p2, p, clip_blend);
		n = mix(n2, n, clip_blend);
	}
	if (zone_on) {
		float wz = smoothstep(zone_z - zone_band, zone_z, MODEL_MATRIX[3].z);
		if (wz > 0.001) {
			vec3 p3;
			vec3 n3;
			vat_sample(zone_clip, zone_time, u, vid, p3, n3);
			p = mix(p, p3, wz);
			n = mix(n, n3, wz);
		}
	}
	v_height = p.y;
	float tw = mod(TIME, 6.2831853);
	float roll = instance_time ? 0.0 : sin(tw * sway_rate + cd.x * 1.37) * cd.z * sway_scale;
	float cr = cos(roll);
	float sr = sin(roll);
	mat3 rz = mat3(vec3(cr, sr, 0.0), vec3(-sr, cr, 0.0), vec3(0.0, 0.0, 1.0));
	VERTEX = rz * (p * unit_scale);
	NORMAL = normalize(rz * n);
}

void fragment() {
	vec3 vc = COLOR.rgb;
	if (vertex_color_srgb) {
		vc = mix(pow((vc + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), vc * (1.0 / 12.92), lessThan(vc, vec3(0.04045)));
	}
	vec4 tex = texture(albedo_tex, UV, albedo_bias);
	vec3 a = vc * tex.rgb;
	float glow = tex.a;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// Masks from the painted colour (linear): crimson = saturated red, bronze = saturated orange,
	// black = very dark, steel = bright grey (the spear's blade).
	float mx = max(a.r, max(a.g, a.b));
	float sat = (mx - min(a.r, min(a.g, a.b))) / max(mx, 0.001);
	float hue_o = clamp(a.g / max(a.r, 0.001), 0.0, 1.0);   // 0 red .. ~0.45 orange
	float warm = smoothstep(0.45, 0.7, sat) * step(a.b, a.r);
	float bronze = warm * smoothstep(0.12, 0.22, hue_o);
	float crimson = warm * (1.0 - smoothstep(0.1, 0.18, hue_o));
	float black = (1.0 - smoothstep(0.02, 0.06, mx)) * (1.0 - warm);
	float steel = (1.0 - smoothstep(0.12, 0.3, sat)) * smoothstep(0.12, 0.35, mx);
	bronze *= material_split;
	crimson *= material_split;
	black *= material_split;
	steel *= material_split;
	float l0 = dot(a, vec3(0.2126, 0.7152, 0.0722));
	a = mix(a, mix(vec3(l0), a, vibrance), max(crimson, bronze));
	a *= mix(vec3(1.0), crimson_tint.rgb * crimson_gain, crimson);
	a *= mix(vec3(1.0), bronze_tint.rgb * bronze_gain, bronze);
	a *= mix(1.0, black_lift, black);
	a *= tint.rgb;
	float lum = dot(a, vec3(0.2126, 0.7152, 0.0722));
	a = mix(vec3(lum), a, saturation);
	float ao = mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, v_height));
	a *= ao;
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	a *= 1.0 - edge_shade * (1.0 - nv) * (1.0 - nv);
	a = mix(a, a * overlay_color.rgb, overlay_amount * 0.55);
	a = mix(a, vec3(1.0), clamp(v_flash, 0.0, 1.0) * 0.75);
	ALBEDO = a * (1.0 - glow * 0.6);
	ROUGHNESS = mix(mix(mix(mix(roughness_value, crimson_roughness, crimson), bronze_roughness, bronze), black_roughness, black), steel_roughness, steel);
	METALLIC = bronze * bronze_metallic + steel * 0.5;
	SPECULAR = 0.45 + 0.3 * max(max(crimson, bronze), max(black, steel));
	v_spec = 0.45 + 0.55 * max(max(crimson, bronze), max(black, steel));
	RIM = rim_value;
	RIM_TINT = 0.6;
	// Eyes: a slow breath of light, each unit at its own phase (no two glare in sync).
	float pulse = 1.0 - glow_pulse + glow_pulse * sin(mod(TIME, 6.2831853) * 2.2 + v_phase * 6.2831853);
	EMISSION = glow_color.rgb * glow * glow_strength * pulse * clamp(saturation, 0.0, 1.0)
		+ overlay_color.rgb * overlay_amount * (0.12 + 2.6 * fres)
		+ edge_color.rgb * edge_amount * edge_scale * fres
		+ vec3(1.0) * clamp(v_flash, 0.0, 1.0) * 1.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + light_wrap) / ((1.0 + light_wrap) * (1.0 + light_wrap)), 0.0, 1.0);
	float sh = mix(1.0, ATTENUATION, self_shadow);
	DIFFUSE_LIGHT += LIGHT_COLOR * wrap * sh * (1.0 / 3.14159265);
	vec3 hv = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, hv), 0.0, 1.0);
	float r = clamp(ROUGHNESS, 0.04, 1.0);
	float shin = min(2.0 / (r * r * r * r) - 2.0, 2048.0);
	float spec = pow(ndh, shin) * (shin + 8.0) * (1.0 / 25.1327412) * clamp(ndl, 0.0, 1.0);
	vec3 f0 = mix(vec3(0.04 * v_spec * 2.0), ALBEDO, METALLIC);
	float vh = clamp(dot(VIEW, hv), 0.0, 1.0);
	vec3 fr = f0 + (vec3(1.0) - f0) * pow(1.0 - vh, 5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * fr * spec * sh * spec_strength * (1.0 / 3.14159265);
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - nv, 4.0) * clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * rim_value;
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * sh * (1.0 / 3.14159265) * 1.5;
}
