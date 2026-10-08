// UI v3.1 porcelain frost (Godot 4.7, gl_compatibility). Material of a Control that paints an
// opaque porcelain body (KitBox nine-patch or a polygon). Each painted pixel is mixed with the
// PRE-BLURRED world still at SCREEN_UV. 1 bilinear tap per pixel, no screen copy, no pass break.
// Children keep their own material, so text and icons stay crisp.
shader_type canvas_item;

uniform sampler2D snap_tex : filter_linear, repeat_disable;
uniform float tint = 0.62;            // share of painted cream over the world (rim / margins)
uniform float frost_lift = 0.14;      // brighten the world (bright Genshin frost)
uniform float frost_desat = 0.45;     // calm its colours (was 0.25: blue/purple blobs)
uniform float frost_contrast = 0.55;  // compress luma variance toward frost_mid ("milk glass")
uniform float frost_mid = 0.80;       // the luma band centre the world is pulled toward
uniform vec4 warm : source_color = vec4(1.0, 0.976, 0.93, 1.0);
uniform vec4 page_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0); // optional: tint toward the page behind (§4.6)
uniform bool alpha_is_tint = false;   // nav strip: vertex alpha carries the tint ramp

void fragment() {
	vec4 p = COLOR;
	vec3 bg = texture(snap_tex, SCREEN_UV).rgb;
	float l = dot(bg, vec3(0.299, 0.587, 0.114));
	bg = mix(bg, vec3(l), frost_desat);
	bg = vec3(frost_mid) + (bg - vec3(frost_mid)) * frost_contrast;
	bg = bg * (1.0 - frost_lift) + frost_lift;
	bg *= warm.rgb * page_tint.rgb;
	float t = alpha_is_tint ? p.a : tint;
	// Where the strip is most transparent (low t) a little of the sharp scene also shows.
	float a = alpha_is_tint ? clamp(0.55 + t * 0.5, 0.0, 1.0) : p.a;
	COLOR = vec4(mix(bg, p.rgb, t), a);
}
