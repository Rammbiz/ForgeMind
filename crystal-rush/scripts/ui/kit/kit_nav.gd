class_name KitNav
## UI v3.1 "porcelain glass" bottom-navigation drawing helpers (spec §6; tab_bar.gd, KitSheet):
## - Strip: the frosted strip body (KitGlass.frost_nav(): vertex alpha carries the tint ramp
##   0.40 at the hairline -> 0.80 at the label cap height -> 0.88 at the bottom, so the world
##   ghosts through the upper third on Play), its top following the hairline's gentle arch, and
##   the Play disc (frosted cream, only while Play is active). Flat cream 0.84 -> 0.92 fallback.
## - draw_top_line(): the strip's ONLY line: an engraved pair (1 dpx LINE_GOLD_DEEP @ 0.85 + 1 dpx
##   white @ 0.62 under it) arching very gently (centre high, sides NAV_SAG lower), fading out
##   over the outer 22 % and open around the Play ring (the stone is set into the line).
## - draw_play_ring(on): the slender Play key (§6.6): an outline-only double ring + a lit faceted
##   topaz; `on` 0..1 warms the ring to 1.5 dpx amber and lights the crystal.
## - draw_indicator(): the active state (§6.4): a 1.5 dpx amber underline with facet ends, the
##   topaz diamond riding the hairline with a 52 px glint, the soft gold-leaf wash.
## - draw_arch_top(): v2 name kept: the SHEET top is a straight fading rule with a 9 px diamond
##   (only the nav arches). draw_bar() / draw_medallion(): legacy names (specimen, old callers).
## Bitmap overrides: nav_bar.png (nine-patch, kit.json margins), nav_medallion.png.


## y of the nav hairline at x (control local): the apex `top` at the centre, NAV_SAG lower at
## the sides (a parabola, so it reads as one calm arch).
static func arch_y(x: float, width: float, top: float, sag := UITokens.NAV_SAG) -> float:
	if width <= 0.0:
		return top
	var t := (x - width * 0.5) / (width * 0.5)
	return top + sag * t * t


## v2 name kept for the sheets and page stages: a STRAIGHT top rule on `r`'s top edge (1 dpx gold
## fading over its outer 30 % + a 1 dpx light line under it) with a 9 px cut-gem diamond at the
## centre. `sag`, `fill` and `_line_w` are accepted for old callers and ignored (no arch cap, no
## fill: the sheet body itself is glass).
static func draw_arch_top(ci: CanvasItem, r: Rect2, _sag: float, cham: float, _fill: Color, keystone := true, line := UITokens.HAIRLINE, _line_w := 1.0) -> void:
	var y := GemDraw.pixel_y(ci, r.position.y + 1.0)
	var x0 := r.position.x + maxf(cham, 0.0) + 6.0
	var x1 := r.end.x - maxf(cham, 0.0) - 6.0
	var w := x1 - x0
	var gold := Color(line.r, line.g, line.b, UITokens.LINE_GOLD.a)
	var g0 := Color(gold.r, gold.g, gold.b, 0.0)
	var lw := -1.0 if UIKit.ui_scale() >= 0.9 else UIKit.line_px(1.0)
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + w * 0.3, y), Vector2(x1 - w * 0.3, y), Vector2(x1, y)]),
			PackedColorArray([g0, gold, gold, g0]), lw)
	var ly := y + UIKit.px(1.0)
	var l := Color(1, 1, 1, UITokens.LINE_LIGHT.a)
	var l0 := Color(1, 1, 1, 0.0)
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, ly), Vector2(x0 + w * 0.3, ly), Vector2(x1 - w * 0.3, ly), Vector2(x1, ly)]),
			PackedColorArray([l0, l, l, l0]), -1.0)
	if keystone:
		GemDraw.draw_diamond(ci, Vector2(r.get_center().x, y), 9.0, Color("#F2DFB0"), UITokens.LINE_GOLD_DEEP)


## v2 helper kept for callers (the Arsenal sheet shadow): the top-edge points (flat in v3.1).
static func _arch_points(r: Rect2, _sag: float, cham: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x + cham
	var x1 := r.end.x - cham
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector2(lerpf(x0, x1, t), r.position.y))
	return pts


## Legacy: the nav strip body in `r` (flat translucent cream 0.84 -> 0.92) + the top line.
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


## The strip's hairline from x0 to x1 with its apex at `y`: the engraved pair, fading out over the
## outer 22 % on each side; `gap` = [x0, x1] left open (the Play ring); `sag` = how much lower
## the ends sit (0 = straight; then primitive 1 dpx lines on a pixel row).
static func draw_top_line(ci: CanvasItem, y: float, x0: float, x1: float, gap := Vector2.ZERO, sag := 0.0) -> void:
	var w := x1 - x0
	var g := UITokens.LINE_GOLD_DEEP
	var gold := Color(g.r, g.g, g.b, 0.85)
	var light := Color(1, 1, 1, UITokens.LINE_LIGHT.a)
	var straight := sag <= 0.0
	var yy := GemDraw.pixel_y(ci, y) if straight else y
	var lw := -1.0 if straight and UIKit.ui_scale() >= 0.9 else UIKit.line_px(1.0)
	var n := 2 if straight else 24
	for pass_i in 2:
		var off := UIKit.px(1.0) * pass_i
		var col := light if pass_i == 1 else gold
		var runs: Array = [[x0, x1]]
		if gap != Vector2.ZERO:
			runs = [[x0, gap.x], [gap.y, x1]]
		for run: Array in runs:
			var a: float = run[0]
			var b: float = run[1]
			if b - a < 1.0:
				continue
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var xs: Array[float] = []
			for i in n + 1:
				xs.append(lerpf(a, b, float(i) / n))
			# Exact fade knots (22 % in from each end of the whole line).
			for kx: float in [x0 + w * 0.22, x1 - w * 0.22]:
				if kx > a and kx < b:
					xs.append(kx)
			xs.sort()
			for x: float in xs:
				var e := minf(x - x0, x1 - x) / maxf(w * 0.22, 1.0)
				var k := clampf(e, 0.0, 1.0)
				k = k * k * (3.0 - 2.0 * k)
				var py := (yy if straight else arch_y(x - x0, w, y, sag)) + off
				pts.append(Vector2(x, py))
				cols.append(Color(col.r, col.g, col.b, col.a * k))
			ci.draw_polyline_colors(pts, cols, lw, not straight)


## The slender Play key centred on `c` (§6.6). `on` 0..1 (bool accepted): inactive = an
## outline-only double ring (1 dpx LINE_GOLD_DEEP @ 0.85 + an inner 1 dpx @ 0.40 at r - 3), a
## 1 dpx white arc upper left, the faceted topaz at 85 % value (lit but quiet, never grey);
## active = the ring warms to #D29A45 at 1.5 dpx and the crystal lights fully with a soft glow.
## (The frosted disc fill of the active state is drawn by the Strip, under the glass material.)
static func draw_play_ring(ci: CanvasItem, c: Vector2, rad: float, on = 0.0, alpha := 1.0) -> void:
	var k := clampf(float(on), 0.0, 1.0)
	var deep := UITokens.LINE_GOLD_DEEP
	var warm := Color("#D29A45")
	var ring := Color(deep.r, deep.g, deep.b, 0.85).lerp(Color(warm.r, warm.g, warm.b, 1.0), k)
	ring.a *= alpha
	var w := lerpf(UIKit.line_px(1.0), UIKit.line_px(UITokens.SELECT_PX), k)
	ci.draw_arc(c, rad - w * 0.5, 0, TAU, 96, ring, w, true)
	ci.draw_arc(c, rad - 3.0, 0, TAU, 80, Color(deep.r, deep.g, deep.b, 0.40 * alpha), UIKit.line_px(1.0), true)
	ci.draw_arc(c, rad - 1.5 - w, PI * 1.08, PI * 1.6, 24, Color(1, 1, 1, 0.75 * alpha), UIKit.px(1.0), true)
	KitIcons.topaz_crystal(ci, c + Vector2(0, 0.5), 32.0, alpha, k, lerpf(0.85, 1.0, k))


## Legacy: the v2 raised amber medallion. v3.1 draws the slender Play ring instead (active look,
## with a translucent cream disc since there is no Strip under it).
static func draw_medallion(ci: CanvasItem, c: Vector2, rad: float, glow := 0.0) -> void:
	var tex := UIKit.kit_texture("nav_medallion")
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)
		return
	var r := minf(rad, UITokens.NAV_PLAY_R)
	if glow > 0.0:
		draw_wash(ci, c, 0.6 * minf(glow, 1.0))
	ci.draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.86))
	draw_play_ring(ci, c, r, 1.0)


## The soft gold-leaf wash behind an active glyph centred on `c` (a feathered glow, never a tile):
## 120 x 80 NAV_WASH @ 0.32 + a white core 56 x 40 @ 0.30, both x `k`.
static func draw_wash(ci: CanvasItem, c: Vector2, k := 1.0) -> void:
	if k <= 0.01:
		return
	var g := UIKit.glow_texture()
	var wc := UITokens.NAV_WASH
	ci.draw_texture_rect(g, Rect2(c - Vector2(60, 40), Vector2(120, 80)), false, Color(wc.r, wc.g, wc.b, 0.32 * k))
	ci.draw_texture_rect(g, Rect2(c - Vector2(28, 20), Vector2(56, 40)), false, Color(1, 1, 1, 0.30 * k))


## The topaz cut-gem diamond riding the hairline at `c`, with a 52 px 1.5 dpx amber glint along
## the line (fading out at both ends). `slope` = dy/dx of the line there (the gentle arch).
static func draw_line_gem(ci: CanvasItem, c: Vector2, k := 1.0, slope := 0.0) -> void:
	if k <= 0.01:
		return
	var a := UITokens.CTA_LO
	var g1 := Color(a.r, a.g, a.b, 0.95 * k)
	var g0 := Color(a.r, a.g, a.b, 0.0)
	var d := Vector2(1.0, slope).normalized() * 26.0
	ci.draw_polyline_colors(PackedVector2Array([c - d, c - d * 0.35, c, c + d * 0.35, c + d]),
			PackedColorArray([g0, g1, g1, g1, g0]), UIKit.line_px(UITokens.SELECT_PX), true)
	GemDraw.draw_diamond(ci, c, 12.0, UITokens.TOPAZ, Color("#A8662A"), k)


## The active-tab underline centred on `c` (its y is the line), `w` wide, `k` 0..1 strength
## (§6.4.1, graft from B): a 1.5 dpx CTA_LO rule fading in from both ends with a 7 px amber facet
## at each end. With `glyph_c` it also lays the gold-leaf wash there, and with `line_c` the
## topaz diamond + glint on the hairline (the full §6.4 state in one call).
static func draw_indicator(ci: CanvasItem, c: Vector2, w: float, k := 1.0, glyph_c := Vector2.INF, line_c := Vector2.INF, slope := 0.0) -> void:
	if k <= 0.01:
		return
	if glyph_c != Vector2.INF:
		draw_wash(ci, glyph_c, k)
	var amber := Color(UITokens.CTA_LO.r, UITokens.CTA_LO.g, UITokens.CTA_LO.b, k)
	var y := GemDraw.pixel_y(ci, c.y)
	var x0 := c.x - w * 0.5 + 6.0
	var x1 := c.x + w * 0.5 - 6.0
	var f := (x1 - x0) * 0.24
	ci.draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + f, y), Vector2(x1 - f, y), Vector2(x1, y)]),
			PackedColorArray([Color(amber.r, amber.g, amber.b, 0.35 * k), amber, amber, Color(amber.r, amber.g, amber.b, 0.35 * k)]), UIKit.line_px(UITokens.SELECT_PX))
	_facet(ci, Vector2(c.x - w * 0.5 + 3.0, y), 7.0, amber)
	_facet(ci, Vector2(c.x + w * 0.5 - 3.0, y), 7.0, amber)
	if line_c != Vector2.INF:
		draw_line_gem(ci, line_c, k, slope)


## A 7 px amber facet (rhombus, lit upper half).
static func _facet(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var h := s * 0.5
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c, pts[3]]), Color(1, 0.95, 0.8, 0.45 * col.a))


## The frosted body of the nav strip (and the active Play disc): cream under KitGlass.frost_nav()
## with the vertex alpha as the tint ramp (§6.3), the top following the hairline arch. Flat
## translucent cream (0.84 -> 0.92) when there is no world snapshot. Put it behind the tab bar's
## own drawing (show_behind_parent). One triangle array (+ one for the disc while Play is on).
class Strip extends Control:
	var top := UITokens.NAV_RISE  ## hairline apex y
	var sag := UITokens.NAV_SAG
	var label_y := 70.0           ## y of the label cap height (the ramp's middle knot)
	var ring_c := Vector2(-1, -1) ## centre of the Play disc, or < 0
	var ring_r := 0.0
	var ring_on := 0.0:           ## 0..1: the active Play disc fill
		set(v):
			if not is_equal_approx(v, ring_on):
				ring_on = v
				queue_redraw()
	var _frost := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _ready() -> void:
		var m := KitGlass.frost_nav()
		if m:
			material = m
			_frost = true
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0:
			return
		var p0 := UITokens.PAPER_0
		var p1 := UITokens.PAPER_1
		# Tint ramp (frosted: alpha = tint) or the flat fallback alphas.
		var t_top := UITokens.NAV_TINT_TOP if _frost else 0.84
		var t_mid := UITokens.NAV_TINT_MID if _frost else 0.88
		var t_bot := UITokens.NAV_TINT_BOT if _frost else 0.92
		var ym := maxf(label_y, top + 8.0)
		var n := 24
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for i in n + 1:
			var x := w * float(i) / n
			var yt := KitNav.arch_y(x, w, top, sag)
			pts.append_array([Vector2(x, yt), Vector2(x, ym), Vector2(x, h)])
			cols.append_array([Color(p0.r, p0.g, p0.b, t_top), Color(p0.r, p0.g, p0.b, t_mid), Color(p1.r, p1.g, p1.b, t_bot)])
			if i > 0:
				var a := (i - 1) * 3
				var b := i * 3
				idx.append_array([a, b, a + 1, b, b + 1, a + 1, a + 1, b + 1, a + 2, b + 1, b + 2, a + 2])
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
		if ring_c.x >= 0.0 and ring_r > 0.0 and ring_on > 0.01:
			# The active Play disc: frosted cream @ 0.85 (flat 0.88 without a snapshot).
			var da := (0.85 if _frost else 0.88) * ring_on
			var dp := PackedVector2Array()
			for i in 48:
				var ang := TAU * float(i) / 48.0
				dp.append(ring_c + Vector2(cos(ang), sin(ang)) * (ring_r - 1.0))
			draw_colored_polygon(dp, Color(p0.r, p0.g, p0.b, da))
