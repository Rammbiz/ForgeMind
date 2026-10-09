class_name GemDraw
## UI v2 "precious" drawing helpers (v3.1: every line 1 device px, UIKit.px / line_px) (procedural placeholders until the owner's bitmaps land):
## faceted cut gems (round / square / triangle / star / eye / cushion), the crystal keystone,
## marquise hairline terminals, rhombus facet pips, the refraction glint (4 rays, one long)
## and chamfered-rect polygons. Everything is CanvasItem drawing, lit from the upper left.

const LIGHT_DIR := Vector2(-0.55, -0.83)


## Eight-point polygon of `rect` with 45-degree corner cuts of `ch` px (gem-girdle chamfer).
static func chamfer_rect(rect: Rect2, ch: float) -> PackedVector2Array:
	var c := minf(ch, minf(rect.size.x, rect.size.y) * 0.5)
	var p := rect.position
	var e := rect.end
	if c <= 0.01:
		return PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)])
	return PackedVector2Array([
		Vector2(p.x + c, p.y), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c), Vector2(e.x, e.y - c),
		Vector2(e.x - c, e.y), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), Vector2(p.x, p.y + c)])


## Closed hairline along a polygon.
static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.0) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, w, true)


## Silhouette of a gem cut centred on `c`, `s` = full size (px).
static func cut_points(cut: String, c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var R := s * 0.5
	match cut:
		"round":
			# Round brilliant read as a cut stone: a 10-sided girdle (broad facets + table), never
			# a smooth sphere.
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0 + PI / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * R)
		"square":
			pts = chamfer_rect(Rect2(c - Vector2(R, R) * 0.86, Vector2(R, R) * 1.72), R * 0.36)
		"triangle":
			# Trillion: a triangle with softly cut tips.
			var tri: Array[Vector2] = []
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				tri.append(c + Vector2(cos(a), sin(a) + 0.12) * R * 1.02)
			for i in 3:
				var a0: Vector2 = tri[i]
				var nxt: Vector2 = tri[(i + 1) % 3]
				var prv: Vector2 = tri[(i + 2) % 3]
				pts.append(a0.lerp(prv, 0.1))
				pts.append(a0.lerp(nxt, 0.1))
		"star":
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (R if i % 2 == 0 else R * 0.56))
		"eye":
			# Marquise: two arcs meeting in points left and right.
			for i in 13:
				var t := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-R, R, t), -sin(t * PI) * R * 0.56))
			for i in range(1, 12):
				var t := 1.0 - float(i) / 12.0
				pts.append(c + Vector2(lerpf(-R, R, t), sin(t * PI) * R * 0.56))
		"diamond":
			pts = PackedVector2Array([c + Vector2(0, -R), c + Vector2(R * 0.72, 0), c + Vector2(0, R), c + Vector2(-R * 0.72, 0)])
		_:
			# "cushion": the CTA topaz (an elongated octagon, tall).
			pts = chamfer_rect(Rect2(c - Vector2(R * 0.74, R), Vector2(R * 1.48, R * 2.0)), R * 0.42)
	return pts


## A faceted gem: crown facets between the girdle and a table, shaded by facet direction,
## table highlight, thin facet lines, a rim, and an optional refraction glint.
## `base` = body colour, `light` = lit facets, `deep` = shadow facets.
static func draw_gem(ci: CanvasItem, cut: String, c: Vector2, s: float, base: Color, light: Color, deep: Color,
		glint := true, alpha := 1.0) -> void:
	var outer := cut_points(cut, c, s)
	var n := outer.size()
	if n < 3:
		return
	var tc := c + Vector2(0, -s * 0.03)
	var tk := 0.5 if cut != "star" else 0.38
	if cut == "eye":
		tk = 0.42
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(tc + (p - c) * tk)
	var a := alpha
	# One triangle array for the shadow, the crown facets and the table (a single canvas draw
	# command per gem instead of ~25; the Arsenal grid draws dozens of these).
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var sh := Color(0.12, 0.08, 0.04, 0.22 * a)
	var so := Vector2(0, s * 0.05)
	var sc := c + so
	for i in n:
		var j := (i + 1) % n
		var k0 := pts.size()
		pts.append_array([sc, outer[i] + so, outer[j] + so])
		cols.append_array([sh, sh, sh])
		idx.append_array([k0, k0 + 1, k0 + 2])
	for i in n:
		var j := (i + 1) % n
		var mid := (outer[i] + outer[j]) * 0.5 - c
		var lam := clampf(mid.normalized().dot(LIGHT_DIR) * 0.5 + 0.5, 0.0, 1.0)
		var col := deep.lerp(base, smoothstep(0.0, 0.55, lam)).lerp(light, smoothstep(0.55, 1.0, lam) * 0.85)
		# Alternate facets a touch for sparkle.
		if i % 2 == 1:
			col = col.lightened(0.06)
		col.a = a
		var k1 := pts.size()
		pts.append_array([outer[i], outer[j], inner[j], inner[i]])
		cols.append_array([col, col, col, col])
		idx.append_array([k1, k1 + 1, k1 + 2, k1, k1 + 2, k1 + 3])
	# Table: a soft vertical gradient (lighter at the top), fanned from its centre.
	var ty0 := INF
	var ty1 := -INF
	for p in inner:
		ty0 = minf(ty0, p.y)
		ty1 = maxf(ty1, p.y)
	var kc := pts.size()
	var cc := base.lerp(light, 0.55).lerp(base, 0.4)
	cc.a = a
	pts.append(tc)
	cols.append(cc)
	for p in inner:
		var t := (p.y - ty0) / maxf(ty1 - ty0, 1.0)
		var tcol := base.lerp(light, 0.55).lerp(base, t * 0.8)
		tcol.a = a
		pts.append(p)
		cols.append(tcol)
	for i in n:
		idx.append_array([kc, kc + 1 + i, kc + 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	# Facet lines (light, thin).
	var fl := Color(light.r, light.g, light.b, 0.45 * a)
	var lw := maxf(0.8, s * 0.018)
	# Small marks (cards, chips) skip the hairline facet lines: the facet colours already read.
	if s >= 26.0:
		var lines := PackedVector2Array()
		for i in n:
			if n > 10 and i % 2 == 1:
				continue
			lines.append_array([outer[i], inner[i]])
		ci.draw_multiline(lines, fl, lw, true)
		outline(ci, inner, Color(light.r, light.g, light.b, 0.55 * a), lw)
	# Girdle rim.
	outline(ci, outer, Color(deep.r * 0.7, deep.g * 0.7, deep.b * 0.7, 0.85 * a), maxf(1.0, s * 0.025))
	if glint:
		draw_glint(ci, tc + Vector2(-s * 0.14, -s * 0.14), s * 0.36, Color(1, 1, 1, 0.9 * a))


## Gem-cut rarity mark: the gem in its cut, in its own colours, set in a thin gold bezel.
static func draw_mark(ci: CanvasItem, gem_key: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var g: Dictionary = UITokens.gem(gem_key)
	var cut: String = g["cut"]
	var bez := cut_points(cut, c, s * 1.16)
	ci.draw_colored_polygon(bez, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, alpha))
	outline(ci, bez, Color(0.45, 0.32, 0.12, 0.6 * alpha), UIKit.px(1.0))
	var body: Color = g["rim"]
	if gem_key == "opal":
		body = Color("#3A2D63")
	elif gem_key == "quartz":
		# Rock crystal reads as a cut, cool stone (never a white pearl).
		body = Color("#A9B6C4")
	draw_gem(ci, cut, c, s, body, g["light"], g["deep"], s >= 22.0, alpha)
	if gem_key == "opal":
		var fl: Array = g["flecks"]
		for i in 5:
			var ang := float(i) * 2.4 + 0.6
			var p := c + Vector2(cos(ang), sin(ang)) * s * (0.1 + 0.05 * (i % 3))
			var fc: Color = fl[i % fl.size()]
			ci.draw_circle(p, s * 0.07, Color(fc.r, fc.g, fc.b, 0.85 * alpha))


## Rhombus facet pip (rarity / facet track). Lit = gem light tone with a white table line;
## unlit = an engraved gold outline.
static func draw_pip(ci: CanvasItem, c: Vector2, s: float, lit: bool, col := UITokens.TOPAZ, alpha := 1.0) -> void:
	var h := s * 0.5
	var w := s * 0.36
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, 0), c + Vector2(0, h), c + Vector2(-w, 0)])
	if lit:
		ci.draw_colored_polygon(_offset(pts, Vector2(0, 1.2)), Color(0.2, 0.12, 0.04, 0.25 * alpha))
		ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, alpha))
		ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c, pts[3]]), Color(1, 1, 1, 0.32 * alpha))
		ci.draw_line(c + Vector2(-w * 0.45, -h * 0.1), c + Vector2(w * 0.45, -h * 0.1), Color(1, 1, 1, 0.75 * alpha), 1.0, true)
		outline(ci, pts, Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.8 * alpha), UIKit.px(1.0))
	else:
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.12 * alpha))
		outline(ci, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9 * alpha), UIKit.line_px(1.0))


## Crystal keystone (v2 name kept, signature unchanged). v3.1 (spec §3.3): every crystal keystone
## is the small cut-gem diamond (9-12 px: lit left facet, shaded right facet, a 1 dpx edge); `s`
## maps onto that range, `tint` lightly colours the stone (default: pale gold).
static func draw_keystone(ci: CanvasItem, c: Vector2, s: float, alpha := 1.0, tint := Color(0.86, 0.96, 1.0)) -> void:
	var fill := Color("#F3E2B8")
	if tint != Color(0.86, 0.96, 1.0):
		fill = fill.lerp(Color(tint.r, tint.g, tint.b, 1.0), 0.5)
	draw_diamond(ci, c, clampf(s * 0.7, 9.0, 12.0), fill, UITokens.LINE_GOLD_DEEP, alpha)


## v3 small cut-gem diamond (nav active marker, divider centre, sheet top): a slim rhombus with a
## lit left facet and a shaded right facet, a 1 px edge. `fill` = the stone colour.
static func draw_diamond(ci: CanvasItem, c: Vector2, s: float, fill := UITokens.TOPAZ, edge := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	var h := s * 0.5
	var w := s * 0.34
	var t := c + Vector2(0, -h)
	var r := c + Vector2(w, 0)
	var b := c + Vector2(0, h)
	var l := c + Vector2(-w, 0)
	var lit := fill.lightened(0.45)
	var sh := fill.darkened(0.12)
	ci.draw_colored_polygon(PackedVector2Array([t, b, l]), Color(lit.r, lit.g, lit.b, alpha))
	ci.draw_colored_polygon(PackedVector2Array([t, r, b]), Color(sh.r, sh.g, sh.b, alpha))
	var e := edge if edge.a > 0.0 else fill.darkened(0.35)
	outline(ci, PackedVector2Array([t, r, b, l]), Color(e.r, e.g, e.b, e.a * alpha), UIKit.line_px(1.0))


## Tiny cut-gem marquise terminal for hairlines (pointing along `dir`): slim, flat gold.
static func draw_marquise(ci: CanvasItem, c: Vector2, dir: Vector2, len := 10.0, col := UITokens.HAIRLINE) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var hl := len * 0.5
	var hw := len * 0.2
	var pts := PackedVector2Array([c - d * hl, c + n * hw, c + d * hl, c - n * hw])
	ci.draw_colored_polygon(pts, col)


## `y` (local) moved to the centre of a device pixel row, so a 1-device-px rule is crisp.
static func pixel_y(ci: CanvasItem, y: float) -> float:
	var sc := UIKit.ui_scale()
	var gy := ci.get_global_transform_with_canvas().origin.y
	return (floorf((gy + y) * sc) + 0.5) / sc - gy


## Gold hairline (ONE device px, v3) with slim marquise terminals and an optional small cut-gem
## diamond at the centre (in a gap of the line). `fade`: the line fades out toward both ends.
## `w` is kept for old callers: > 1.0 draws a 1.5-device-px line (primary frames only).
static func draw_hairline(ci: CanvasItem, a: Vector2, b: Vector2, col := UITokens.HAIRLINE, w := 1.0, keystone := true, fade := false) -> void:
	var d := (b - a).normalized()
	var a2 := a + d * 12.0
	var b2 := b - d * 12.0
	var lw := -1.0 if w <= 1.0 else UIKit.px(1.5)
	var m := (a + b) * 0.5
	var gap := 11.0 if keystone else 0.0
	var c0 := Color(col.r, col.g, col.b, col.a * (0.0 if fade else 1.0))
	var c1 := Color(col.r, col.g, col.b, col.a)
	# Two halves (one polyline each, per-vertex alpha for the fade).
	ci.draw_polyline_colors(PackedVector2Array([a2, a2.lerp(m, 0.5), m - d * gap]), PackedColorArray([c0, c1, c1]), lw)
	ci.draw_polyline_colors(PackedVector2Array([m + d * gap, b2.lerp(m, 0.5), b2]), PackedColorArray([c1, c1, c0]), lw)
	# The engraved pair (Genshin): a 1 px light line right under the gold one, so the rule reads
	# on cream glass and on darker grounds alike.
	var nrm := Vector2(-d.y, d.x) * UIKit.px(1.0)
	var l1 := Color(1, 1, 1, 0.55 * col.a)
	var l0 := Color(1, 1, 1, 0.0)
	ci.draw_polyline_colors(PackedVector2Array([a2 + nrm, a2.lerp(m, 0.5) + nrm, m - d * gap + nrm]), PackedColorArray([l0 if fade else l1, l1, l1]), lw)
	ci.draw_polyline_colors(PackedVector2Array([m + d * gap + nrm, b2.lerp(m, 0.5) + nrm, b2 + nrm]), PackedColorArray([l1, l1, l0 if fade else l1]), lw)
	draw_marquise(ci, a + d * 5.0, d, 8.0, Color(col.r, col.g, col.b, col.a * 0.9))
	draw_marquise(ci, b - d * 5.0, d, 8.0, Color(col.r, col.g, col.b, col.a * 0.9))
	if keystone:
		draw_diamond(ci, m, 10.0, Color("#F3E2B8"), Color(col.r, col.g, col.b, 1.0), col.a)


## Our glint (anti-sparkle): a 4-ray cross with one long ray (a refraction streak).
static func draw_glint(ci: CanvasItem, c: Vector2, s: float, col := Color(1, 1, 1, 0.9)) -> void:
	var tex := UIKit.glow_texture()
	ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.22, Vector2(s, s) * 0.44), false, Color(col.r, col.g, col.b, col.a * 0.8))
	var rays := [[Vector2(1, 0), 0.5], [Vector2(-1, 0), 0.32], [Vector2(0, -1), 0.3], [Vector2(0, 1), 0.62]]
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for ray: Array in rays:
		var d: Vector2 = (ray[0] as Vector2).rotated(-0.35)
		var L: float = s * float(ray[1])
		var n := Vector2(-d.y, d.x)
		var wdt := s * 0.045
		var k := pts.size()
		pts.append_array([c + n * wdt, c + d * L, c - n * wdt])
		cols.append_array([col, col, col])
		idx.append_array([k, k + 1, k + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func _offset(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out
