class_name KitNav
## UI v2 bottom-navigation drawing helpers (used by tab_bar.gd and KitSheet):
## - draw_arch_top(): cream arch cap above a rect's top edge, gold hairline, crystal keystone.
## - draw_bar(): the whole light nav bar (porcelain, shadow, arched top edge, keystone).
## - draw_medallion(): the raised round amber medallion of the active tab.
## Bitmap overrides: nav_bar.png (nine-patch, kit.json margins), nav_medallion.png.


## Arch cap over `r`'s top edge: rises `sag` px at the centre between the two chamfers.
static func draw_arch_top(ci: CanvasItem, r: Rect2, sag: float, cham: float, fill: Color, keystone := true, line := UITokens.HAIRLINE, line_w := 2.0) -> void:
	var pts := _arch_points(r, sag, cham, 32)
	# Fill the cap (from the arch down to 3 px under the top edge to cover the straight line).
	var cap := pts.duplicate()
	cap.append(Vector2(r.end.x - cham, r.position.y + 3.0))
	cap.append(Vector2(r.position.x + cham, r.position.y + 3.0))
	ci.draw_colored_polygon(cap, fill)
	ci.draw_polyline(pts, line, line_w, true)
	if keystone:
		var c := Vector2(r.get_center().x, r.position.y - sag)
		ci.draw_line(c - Vector2(14, 0), c + Vector2(14, 0), fill, line_w + 2.0)
		GemDraw.draw_keystone(ci, c, 18.0)


static func _arch_points(r: Rect2, sag: float, cham: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x + cham
	var x1 := r.end.x - cham
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, t), r.position.y - sin(t * PI) * sag))
	return pts


## The nav bar body in `r` (full width): porcelain fill, a soft upward shadow, an arched top
## edge with a gold hairline and a keystone at the centre (behind the medallion).
static func draw_bar(ci: CanvasItem, r: Rect2, sag := 8.0) -> void:
	var tex := UIKit.kit_texture("nav_bar")
	if tex:
		ci.draw_style_box(UIKit.lux("nav_bar"), Rect2(r.position - Vector2(0, sag), r.size + Vector2(0, sag)))
		return
	var top := _arch_points(r, sag, 0.0, 48)
	# Soft upward shadow: a gradient band following the arch (no stripes).
	var sh := PackedVector2Array()
	var shc := PackedColorArray()
	var sc := UITokens.SCRIM
	for p in top:
		sh.append(p + Vector2(0, 2))
		shc.append(Color(sc.r, sc.g, sc.b, 0.1))
	for i in range(top.size() - 1, -1, -1):
		sh.append(top[i] + Vector2(0, -16))
		shc.append(Color(sc.r, sc.g, sc.b, 0.0))
	ci.draw_polygon(sh, shc)
	var body := top.duplicate()
	body.append(r.end)
	body.append(Vector2(r.position.x, r.end.y))
	var cols := PackedColorArray()
	for p in body:
		var t := clampf((p.y - (r.position.y - sag)) / maxf(r.size.y, 1.0), 0.0, 1.0)
		cols.append(UITokens.PAPER_0.lerp(UITokens.PAPER_1, t))
	ci.draw_polygon(body, cols)
	ci.draw_polyline(top, UITokens.HAIRLINE, 1.5, true)
	# Inner hairline 5 px below (the Genshin double line), fading to the sides.
	var inner := PackedVector2Array()
	for p in top:
		inner.append(p + Vector2(0, 5))
	var n := inner.size()
	for i in n - 1:
		var k := 1.0 - absf(float(i) / (n - 1) * 2.0 - 1.0)
		ci.draw_line(inner[i], inner[i + 1], Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.45 * k), 1.0, true)


## The raised active-tab medallion centred on `c`, radius `rad`: soft shadow, gold rim, amber
## jewel face, cream inner ring. The tab's painted icon is drawn on top by the caller.
static func draw_medallion(ci: CanvasItem, c: Vector2, rad: float, glow := 0.0) -> void:
	var tex := UIKit.kit_texture("nav_medallion")
	if glow > 0.0:
		ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(rad, rad) * 1.9, Vector2(rad, rad) * 3.8), false, Color(1.0, 0.8, 0.45, 0.35 * glow))
	for i in 4:
		ci.draw_circle(c + Vector2(0, 3.0 + i * 1.5), rad + 1.0 + i, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)
		return
	ci.draw_circle(c, rad, UITokens.PAPER_0)
	ci.draw_arc(c, rad - 0.75, 0, TAU, 64, UITokens.HAIRLINE, 1.5, true)
	var face := rad - 6.0
	# Amber face: radial-ish gradient from stacked discs, lit from the top-left.
	var n := 10
	for i in n:
		var k := float(i) / (n - 1)
		var col := UITokens.CTA_LO.lerp(UITokens.CTA, smoothstep(0.0, 0.6, k)).lerp(UITokens.CTA_HI, smoothstep(0.55, 1.0, k))
		ci.draw_circle(c + Vector2(-face * 0.12, -face * 0.16) * k, face * (1.0 - k * 0.55), col)
	ci.draw_arc(c, face, 0, TAU, 64, Color("#B9772A"), 1.5, true)
	ci.draw_arc(c, face - 3.0, PI * 1.05, PI * 1.85, 24, Color(1, 0.97, 0.85, 0.7), 1.5, true)
