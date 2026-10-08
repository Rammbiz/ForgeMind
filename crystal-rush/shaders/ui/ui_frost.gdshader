// UI v3 "porcelain glass" frost (Godot 4.7, gl_compatibility). Material of a Control that draws
// an opaque-painted porcelain body (a KitBox nine-patch or a polygon): every pixel it draws is
// mixed with the PRE-BLURRED world snapshot (KitGlass / WorldSnap, 1/8 res, blurred once per tab
// change) at SCREEN_UV, so the surface reads as frosted cream glass with the world glowing
// through. Cost: one bilinear tap per pixel from a ~90x160 texture. No screen copy, no render-pass
// break (tech.md B). Children of the Control keep their own material (text stays crisp).
shader_type canvas_item;

uniform sampler2D snap_tex : filter_linear, repeat_disable;
uniform float tint = 0.68;          // share of the painted colour over the frosted world (>= 0.68 under body text)
uniform float frost_lift = 0.12;    // brighten the world (bright, Genshin-like frost)
uniform float frost_desat = 0.25;   // and calm its colours a little
uniform vec4 warm : source_color = vec4(1.0, 0.976, 0.93, 1.0); // warm the light that comes through

void fragment() {
	vec4 p = COLOR;
	vec3 bg = texture(snap_tex, SCREEN_UV).rgb;
	float l = dot(bg, vec3(0.299, 0.587, 0.114));
	bg = mix(bg, vec3(l), frost_desat) * (1.0 - frost_lift) + frost_lift;
	bg *= warm.rgb;
	COLOR = vec4(mix(bg, p.rgb, tint), p.a);
}
