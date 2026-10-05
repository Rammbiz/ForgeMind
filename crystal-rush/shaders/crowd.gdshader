// Crowd units (CrowdView, UnitFx): one MultiMesh draws a whole army, squad or recruit group.
// Lit like the heroes: matte (roughness 0.8), soft specular, a gentle rim and real shadows.
// The march (hop, squash and stretch, side roll, forward lean) runs here, per instance, so the
// CPU only uploads one buffer per crowd per frame.
//
// INSTANCE_CUSTOM = (phase, hop, sway, flash):
//   phase  radians, desynchronises the units
//   hop    bounce height in world units (≈0.08 marching, ≈0.015 idle, 0 = still)
//   sway   side-roll amplitude in radians (≈0.08)
//   flash  0..1 white hit flash
// Albedo = vertex COLOR × albedo_tex × tint, then saturation, foot occlusion and overlays.
// A Meshy GLB without vertex colours gets COLOR = white, so its texture shows unchanged.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.18, 1.0, 0.55, 1.0);
uniform float overlay_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.72, 0.86, 1.0, 1.0);
uniform float edge_amount : hint_range(0.0, 2.0) = 0.0;
uniform bool vertex_color_srgb = true;
// Integer rates keep the motion seamless when TIME is wrapped to one 2π period.
uniform float hop_rate = 12.0;
uniform float sway_rate = 6.0;
uniform float squash = 0.12;
uniform float lean = 0.12;
uniform float ao_height = 0.3;
uniform float ao_strength = 0.45;
uniform float roughness_value = 0.8;
uniform float rim_value = 0.35;

varying float v_flash;
varying float v_height;

void vertex() {
	float t = mod(TIME, 6.2831853);
	vec4 cd = INSTANCE_CUSTOM;
	float hop = cd.y;
	float sway = cd.z;
	v_flash = cd.w;
	v_height = VERTEX.y;
	float k = clamp(hop / 0.08, 0.0, 1.5);           // how hard this unit is marching
	float b = abs(sin(t * hop_rate + cd.x));          // 0 at foot contact, 1 at the apex
	// Squash at contact, stretch at the apex (volume roughly kept), plus idle breathing.
	float st = (b - 0.4) * squash * k + sin(t * 2.0 + cd.x) * 0.012;
	VERTEX.y *= 1.0 + st;
	VERTEX.xz *= 1.0 - st * 0.5;
	// Side roll about the feet and a forward lean that deepens on each push-off.
	float roll = sin(t * sway_rate + cd.x * 1.37) * sway;
	float pitch = k * lean * (0.7 + 0.3 * b);
	float cr = cos(roll);
	float sr = sin(roll);
	float cp = cos(pitch);
	float sp = sin(pitch);
	mat3 rz = mat3(vec3(cr, sr, 0.0), vec3(-sr, cr, 0.0), vec3(0.0, 0.0, 1.0));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cp, sp), vec3(0.0, -sp, cp));
	mat3 r = rz * rx;
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	VERTEX.y += b * hop;
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
