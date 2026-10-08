class_name KitNav
## UI v3 "porcelain glass" bottom-navigation drawing helpers (tab_bar.gd, KitSheet, page stages):
## - draw_arch_top(): the sheet's shallow arch: ONE device-px gold hairline, a 1 px inner light
##   line under it and a small cut-gem diamond at the apex (no thick line, no crystal keystone).
## - draw_bar(): the slim frosted strip (flat translucent fallback when there is no world snapshot).
## - draw_top_line(): the strip's only line: 1 device px gold, fading out toward both sides, with a
##   1 px light line under it; an optional gap (the Play ring sits in it, like a set stone).
## - Strip: the frosted body (KitGlass frost material, drawn behind the tab bar's glyphs).
## - draw_play_ring(): the slender Play key: a fine double gold ring around a faceted topaz crystal.
## - draw_medallion(): legacy name, now the same slender ring (no amber jelly coin).
## Bitmap overrides: nav_bar.png (nine-patch, kit.json margins), nav_medallion.png.


## Arch cap over `r`'s top edge: rises `sag` px (x0.6 in v3) at the centre between the chamfers.
static func draw_arch_top(ci: CanvasItem, r: Rect2, sag: float, cham: float, fill: Color, keystone := true, line := UITokens.HAIRLINE, _line_w := 1.0) -> void:
	sag *= 0.6
	var pts := _arch_points(r, sag, cham, 40)
	var cap := pts.duplicate()
	cap.append(Vector2(r.end.x - cham, r.position.y + 0.5))
	cap.append(Vector2(r.position.x + cham, r.position.y + 0.5))
	ci.draw_colored_polygon(cap, fill)
	var lw := UIKit.px(1.0)
	var c := Vector2(r.get_center().x, r.position.y - sag)
	var gold := Color(line.r, line.g, line.b, UITokens.LINE_GOLD.a)
	var gap := 12.0 if keystone else 0.0
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for p in pts:
		if p.x < c.x - gap:
			left.append(p)
		elif p.x > c.x + gap:
			right.append(p)
	if left.size() >= 2:
		ci.draw_polyline(left, gold, lw, true)
	if right.size() >= 2:
		ci.draw_polyline(right, gold, lw, true)
	# Inner light line 1 device px under the gold one, fading toward the ends.
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	var n := pts.size()
	for i in n:
		var k := 1.0 - absf(float(i) / (n - 1) * 2.0 - 1.0)
		inner.append(pts[i] + Vector2(0, UIKit.px(1.0)))
		cols.append(Color(1, 1, 1, UITokens.LINE_LIGHT.a * clampf(k * 2.0, 0.0, 1.0)))
	ci.draw_polyline_colors(inner, cols, lw, true)
	if keystone:
		GemDraw.draw_diamond(ci, c, 11.0, Color("#F2DFB0"), gold)


static func _arch_points(r: Rect2, sag: float, cham: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x + cham
	var x1 := r.end.x - cham
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, t), r.position.y - sin(t * PI) * sag))
	return pts


## The nav strip body in `r` (full width, flat top): flat translucent cream (used when there is
## no world snapshot; with one, tab_bar puts a frosted Strip behind instead) + the top line.
static func draw_bar(ci: CanvasItem, r: Rect2, _sag := 0.0) -> void:
	var tex := UIKit.kit_texture("nav_bar")
	if tex:
		ci.draw_style_box(UIKit.lux("nav_bar"), r)
		return
	var a0 := Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.84)
	var a1 := Color(UITokens.PAPER_1.r, UITokens.PAPER_1.g, UITokens.PAPER_1.b, 0.92)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([a0, a0, a1, a1]))
	draw_top_line(ci, r.position.y, r.position.x, r.end.x)


## The strip's top edge: 1 device px gold at UITokens.LINE_GOLD, fading out over the outer 22 %
## on each side, and a 1 px light line just under it. `gap` = [x0, x1] left open (Play ring).
static func draw_top_line(ci: CanvasItem, y: float, x0: float, x1: float, gap := Vector2.ZERO) -> void:
	var yy := GemDraw.pixel_y(ci, y)
	var lw := -1.0
	var w := x1 - x0
	var g := UITokens.LINE_GOLD
	var g0 := Color(g.r, g.g, g.b, 0.0)
	var l := UITokens.LINE_LIGHT
	var l0 := Color(1, 1, 1, 0.0)
	var xs := [x0, x0 + w * 0.22, x1 - w * 0.22, x1]
	var ga := [g0, g, g, g0]
	var la := [l0, l, l, l0]
	for pass_i in 2:
		var py := yy + (UIKit.px(1.0) if pass_i == 1 else 0.0)
		var cols: Array = la if pass_i == 1 else ga
		var pts := PackedVector2Array()
		var pc := PackedColorArray()
		for i in 4:
			var x: float = xs[i]
			if gap != Vector2.ZERO and x > gap.x and x < gap.y:
				continue
			pts.append(Vector2(x, py))
			pc.append(cols[i])
		if gap == Vector2.ZERO:
			ci.draw_polyline_colors(pts, pc, lw)
		else:
			# Two runs around the gap (the colour at the gap edges = full line colour).
			var c_full: Color = cols[1]
			ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, py), Vector2(minf(xs[1], gap.x), py), Vector2(gap.x, py)]),
					PackedColorArray([cols[0], c_full, c_full]), lw)
			ci.draw_polyline_colors(PackedVector2Array([Vector2(gap.y, py), Vector2(maxf(xs[2], gap.y), py), Vector2(x1, py)]),
					PackedColorArray([c_full, c_full, cols[3]]), lw)


## The slender Play key centred on `c`: a frosted disc (drawn by the Strip), a fine double gold
## ring (1 device px + an inner 1 px at 45 %), the faceted topaz crystal. `on` warms the ring
## and lights the crystal (the Play tab is active).
static func draw_play_ring(ci: CanvasItem, c: Vector2, rad: float, on := false, alpha := 1.0) -> void:
	var lw := UIKit.px(1.0)
	var gold := UITokens.HAIRLINE
	var ring := Color("#D29A45") if on else gold
	ci.draw_arc(c, rad - lw * 0.5, 0, TAU, 72, Color(ring.r, ring.g, ring.b, (0.95 if on else 0.8) * alpha), UIKit.px(1.5) if on else lw, true)
	ci.draw_arc(c, rad - 4.0, 0, TAU, 64, Color(gold.r, gold.g, gold.b, 0.42 * alpha), lw, true)
	ci.draw_arc(c, rad - 1.5, PI * 1.08, PI * 1.62, 24, Color(1, 1, 1, 0.75 * alpha), lw, true)
	KitIcons.topaz_crystal(ci, c + Vector2(0, 0.5), rad * 1.06, alpha, 1.0 if on else 0.0)


## Legacy: the v2 raised amber medallion (the caller draws the tab icon on top). v3 draws a
## slender porcelain ring instead: a translucent cream disc, a fine double gold ring.
static func draw_medallion(ci: CanvasItem, c: Vector2, rad: float, glow := 0.0) -> void:
	var tex := UIKit.kit_texture("nav_medallion")
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)
		return
	var r := minf(rad, UITokens.NAV_PLAY_R)
	var lw := UIKit.px(1.0)
	if glow > 0.0:
		ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(1.0, 0.86, 0.55, 0.3 * minf(glow, 1.0)))
	ci.draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.86))
	ci.draw_arc(c, r - lw * 0.5, 0, TAU, 72, Color("#D29A45"), UIKit.px(1.5), true)
	ci.draw_arc(c, r - 4.0, 0, TAU, 64, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.42), lw, true)


## The frosted body of the nav strip (and the Play ring's disc): an opaque-painted cream body
## under the KitGlass frost material, so the blurred world glows through; flat translucent cream
## when there is no snapshot. Put it behind the tab bar's own drawing (show_behind_parent).
class Strip extends Control:
	var top := 14.0               ## y of the strip's top edge
	var ring_c := Vector2(-1, -1) ## centre of the Play disc (rises above the strip), or < 0
	var ring_r := 0.0
	var _frost := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _ready() -> void:
		var m := KitGlass.frost(0.5)
		if m:
			material = m
			_frost = true
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Frosted: half cream over the blurred world, and the top lets ~10 % of the sharp scene
		# through (real depth); flat fallback: translucent cream.
		var a0 := 0.9 if _frost else 0.84
		var a1 := 1.0 if _frost else 0.92
		var c0 := Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, a0)
		var c1 := Color(UITokens.PAPER_1.r, UITokens.PAPER_1.g, UITokens.PAPER_1.b, a1)
		var r := Rect2(Vector2(0, top), Vector2(size.x, size.y - top))
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
				PackedColorArray([c0, c0, c1, c1]))
		if ring_c.x >= 0.0 and ring_r > 0.0:
			# The Play disc: only its cap above the strip needs drawing (no double alpha below).
			var pts := PackedVector2Array()
			for i in 49:
				var ang := PI + PI * float(i) / 48.0
				pts.append(ring_c + Vector2(cos(ang), sin(ang)) * ring_r)
			var cap := PackedVector2Array()
			for p in pts:
				if p.y <= top + 0.5:
					cap.append(p)
			if cap.size() >= 3:
				draw_colored_polygon(cap, c0)
