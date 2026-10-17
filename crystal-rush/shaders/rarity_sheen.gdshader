// Sheen overlay (GeometryInstance3D.material_overlay): a fresnel rim plus a bright band that
// sweeps diagonally over the object every `period` seconds. Used for the Ascension look of
// machines (family accent, WeaponModels.set_ascended) and for rarity glints on Caches and
// cards (rarity colour). Additive; fade with `strength`. TIME is wrapped to the period.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float strength = 1.0;
uniform float period = 2.6;
uniform float rim_power = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f = 1.0 - facing;
	float rim = f * f * rim_power;
	float t = mod(TIME, period) / period;
	float s = fract((world_pos.y * 0.9 + world_pos.x * 0.45 - world_pos.z * 0.25) * 0.55 - t);
	float sweep = smoothstep(0.0, 0.06, s) * (1.0 - smoothstep(0.06, 0.16, s));
	vec3 c = color.rgb * (rim * 1.1 + sweep * 0.8) + vec3(1.0) * sweep * 0.25;
	ALBEDO = c * strength;
}
