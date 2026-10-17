// The owner's Cache eggs (CacheModels.cache), cut into shell chunks: the model's own texture;
// its gems (sapphire / amethyst) glow, and as the crack stages advance the best rarity inside
// leaks out: the gems and quartz veins take `tell_color`, glowing crack lines open along the
// chunk edges (UV2.x = distance to the chunk's edge in world units, `crack_w` the line width)
// and a rim light wraps the egg. Back faces (seen through the gaps and in the burst) are the
// lit inside of the shell. `tell` 0 intact, 1 tell, 1.4 heavy, 2 burst.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float gem_glow = 0.8;
uniform vec4 tell_color : source_color = vec4(1.0);
uniform float tell = 0.0;
uniform float crack_w = 0.0;
varying float edge;

void vertex() {
	edge = UV2.x;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = hi - lo;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float k = clamp(tell, 0.0, 2.0);
	// Gems: saturated, blue at least as strong as red (sapphire, amethyst). Gold stays out.
	float gem = smoothstep(0.1, 0.24, sat) * smoothstep(-0.04, 0.04, c.b - c.r * 0.85) * smoothstep(0.06, 0.18, hi);
	// Quartz veins: bright and unsaturated.
	float quartz = smoothstep(0.32, 0.6, lum) * (1.0 - smoothstep(0.08, 0.2, sat));
	// Gold bands: glossy metal.
	float gold = smoothstep(0.12, 0.3, c.r - c.b) * smoothstep(-0.02, 0.04, c.g - c.b);
	vec3 gemc = mix(c, tell_color.rgb * (0.45 + lum * 1.2), clamp(k * 0.5, 0.0, 0.7));
	vec3 alb = mix(c, gemc, gem);
	vec3 emit = gemc * gem * gem_glow * (0.35 + 0.5 * k);
	emit += tell_color.rgb * quartz * k * 0.4;
	float cl = (1.0 - smoothstep(crack_w * 0.35, crack_w, edge)) * step(0.0001, crack_w);
	alb = mix(alb, tell_color.rgb, cl * 0.75);
	emit += tell_color.rgb * cl * 3.2;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	emit += tell_color.rgb * fres * fres * fres * k * 0.32;
	float rough = mix(mix(0.62, 0.3, gem), 0.3, gold);
	if (!FRONT_FACING) {
		alb = mix(c * 0.25, tell_color.rgb, 0.35);
		emit = tell_color.rgb * (0.15 + 0.4 * k);
		rough = 0.8;
		gold = 0.0;
	}
	ALBEDO = alb;
	METALLIC = gold * 0.75;
	ROUGHNESS = rough;
	EMISSION = emit;
	if (has_normal && FRONT_FACING) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
