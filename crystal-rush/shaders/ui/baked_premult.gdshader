// A texture baked in a transparent SubViewport (premultiplied colour: rgb already times alpha),
// drawn with the item's modulate applied correctly: the modulate alpha scales rgb too, so a
// faded / dimmed baked card darkens into the page instead of washing out white.
// Used by MachineCard (the per-card bake).
shader_type canvas_item;
render_mode blend_premul_alpha;

varying float mod_a;

void vertex() {
	mod_a = COLOR.a;
}

void fragment() {
	// COLOR arrives as texture * vertex colour (modulate): alpha is already scaled, rgb not.
	COLOR.rgb *= mod_a;
}
