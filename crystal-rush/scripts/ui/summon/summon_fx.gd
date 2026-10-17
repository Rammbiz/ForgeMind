class_name SummonFx
extends RefCounted
## Deterministic drawing and timing helpers for the Portal and the summon ceremonies
## (heroes_design.md §9.4, part U §3.2). Every visual here is a pure function of a time value,
## so a ceremony can be seeked to any t (dev shots) and still look exactly like the live frame.
## Gem colours follow §2.1 (UI hex); the opal is a black opal with play-of-colour.

## The gem UI hex (§2.1; opal = its fire accent, the body is black opal).
const HEX := {"C": Color("#D6DEE6"), "R": Color("#3FA9FF"), "E": Color("#B06CFF"), "L": Color("#FFB52E"), "M": Color("#B48CFF")}
## Light pillar colours: quartz silver, sapphire blue, amethyst violet, topaz gold, opal (spectral).
const PILLAR := {"C": Color("#DCE6F2"), "R": Color("#4FB0FF"), "E": Color("#A35CFF"), "L": Color("#FFB238"), "M": Color("#C9A8FF")}
## Crystal bodies (seed / walkout crystal): body, light facet, deep facet.
const BODY := {"C": [Color("#D6DEE6"), Color("#F7FAFD"), Color("#7C8A99")],
		"R": [Color("#3FA9FF"), Color("#BFE6FF"), Color("#1B4E7E")],
		"E": [Color("#7A35D6"), Color("#DCC2FF"), Color("#3E1A78")],
		"L": [Color("#FFB52E"), Color("#FFF0C2"), Color("#C2620E")],
		"M": [Color("#1A1530"), Color("#6E5AA8"), Color("#07050F")]}
const CLEAR := [Color(0.86, 0.9, 1.0, 0.62), Color(1, 1, 1, 0.9), Color(0.52, 0.58, 0.74, 0.7)]
const FLECKS: Array[Color] = [Color("#7FE3FF"), Color("#B48CFF"), Color("#FF9FD6"), Color("#FFE28A"), Color("#8DFFC4")]
## Photosensitivity cap (§9.7): a flash never exceeds this white alpha.
const FLASH_PEAK := 0.55


# ------------------------------------------------------------------ timing

## 0..1 progress of `t` through [a, a + len] (clamped).
static func seg(t: float, a: float, len: float) -> float:
	if len <= 0.0:
		return 1.0 if t >= a else 0.0
	return clampf((t - a) / len, 0.0, 1.0)


static func out3(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in2(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v


static func inout(x: float) -> float:
	var v := clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Ease-out-back (one soft overshoot; rewards only, never menus).
static func back(x: float, k := 1.4) -> float:
	var v := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + (k + 1.0) * v * v * v + k * v * v


## 1 inside [a, b], with `fade` seconds of ramp on both ends.
static func window(t: float, a: float, b: float, fade := 0.2) -> float:
	return seg(t, a, fade) * (1.0 - seg(t, b - fade, fade))


## The white-flash alpha of a flash that fires at `at` (80 ms, capped by FLASH_PEAK).
static func flash(t: float, at: float, peak := FLASH_PEAK, dur := 0.08) -> float:
	if t < at or t > at + dur * 2.0:
		return 0.0
	var u := (t - at) / dur
	return minf(peak, FLASH_PEAK) * (1.0 - smoothstep(0.4, 2.0, u)) * smoothstep(0.0, 0.2, u)


static func pillar_color(g: String) -> Color:
	return PILLAR.get(g, PILLAR["L"])


static func hex(g: String) -> Color:
	return HEX.get(g, HEX["L"])


static func cut(g: String) -> String:
	return str(UITokens.gem(g)["cut"])


## A spectral colour (opal play-of-colour) at hue 0..1.
static func spectral(h: float, s := 0.55, v := 1.0) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), s, v)


# ------------------------------------------------------------------ crystals

## A raw crystal / seed in its gem cut. `told` = 0 (clear crystal) .. 1 (its final gem colour);
## opal adds play-of-colour flecks that drift with `t`.
static func draw_crystal(ci: CanvasItem, g: String, c: Vector2, s: float, told := 1.0, alpha := 1.0, t := 0.0) -> void:
	var b: Array = BODY.get(g, BODY["L"])
	var base := (CLEAR[0] as Color).lerp(b[0], told)
	var light := (CLEAR[1] as Color).lerp(b[1], told)
	var deep := (CLEAR[2] as Color).lerp(b[2], told)
	base.a = 1.0
	light.a = 1.0
	deep.a = 1.0
	var ct := cut(g) if told > 0.5 else _clear_cut(g)
	GemDraw.draw_gem(ci, ct, c, s, base, light, deep, true, alpha * lerpf(0.82, 1.0, told))
	if g == "M" and told > 0.0:
		draw_opal_fire(ci, c, s, t, alpha * told)


## Before the tell every seed is the same neutral clear crystal (a rhombus): the cut is part of
## the tell and never shows early.
static func _clear_cut(_g: String) -> String:
	return "diamond"


## Black-opal play of colour: soft spectral patches that drift inside the stone.
static func draw_opal_fire(ci: CanvasItem, c: Vector2, s: float, t: float, alpha := 1.0) -> void:
	var g := UIKit.glow_texture()
	for i in 7:
		var ph := float(i) * 1.7
		var p := c + Vector2(sin(t * 0.7 + ph) * s * 0.22, cos(t * 0.55 + ph * 1.3) * s * 0.13)
		var col: Color = FLECKS[i % FLECKS.size()]
		var r := s * (0.12 + 0.05 * sin(t * 1.3 + ph))
		ci.draw_texture_rect(g, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, 0.55 * alpha))
	for i in 6:
		var ph := float(i) * 2.3 + 0.4
		var p := c + Vector2(sin(t * 0.9 + ph) * s * 0.26, cos(t * 0.8 + ph) * s * 0.12)
		var col: Color = FLECKS[(i + 2) % FLECKS.size()]
		var r := s * 0.035
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0)]), Color(col.r, col.g, col.b, 0.85 * alpha))


## Crack lines that grow over a crystal (0..1), following the gem's fracture pattern (§2.1):
## Quartz 60/120 planes, Sapphire a grid tilted 12 degrees, Amethyst 30/90/150 triangles,
## Topaz 5 rays at 72 degrees, Opal conchoidal arcs.
static func draw_cracks(ci: CanvasItem, g: String, c: Vector2, s: float, k: float, col := Color(1, 1, 1, 0.9)) -> void:
	if k <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(g + "crack")
	var angles: Array[float] = []
	match g:
		"C": angles = [30.0, 90.0, 150.0, 210.0, 270.0, 330.0]
		"R": angles = [12.0, 102.0, 192.0, 282.0, 57.0, 237.0]
		"E": angles = [-90.0, 30.0, 150.0, 90.0, 210.0, 330.0]
		"L": angles = [-90.0, -18.0, 54.0, 126.0, 198.0]
		_: angles = [-150.0, -60.0, 20.0, 100.0, 170.0, 240.0, 300.0]
	var lines := PackedVector2Array()
	var glow := PackedVector2Array()
	for a0 in angles:
		var a := deg_to_rad(a0 + rng.randf_range(-6.0, 6.0))
		var p := c
		var len := s * rng.randf_range(0.36, 0.5) * k
		var steps := 4
		for i in steps:
			var bend := rng.randf_range(-0.35, 0.35) if g != "M" else 0.32
			a += bend * 0.5
			var q := p + Vector2(cos(a), sin(a)) * len / steps
			lines.append_array([p, q])
			if i == 1 and rng.randf() < 0.7:
				var ba := a + rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
				var bq := q + Vector2(cos(ba), sin(ba)) * len * 0.3
				glow.append_array([q, bq])
			p = q
	var w := maxf(1.2, s * 0.008)
	ci.draw_multiline(lines, Color(col.r, col.g, col.b, col.a * 0.35), w * 3.5, true)
	ci.draw_multiline(lines, col, w, true)
	if not glow.is_empty():
		ci.draw_multiline(glow, Color(col.r, col.g, col.b, col.a * 0.7), w * 0.8, true)


## Shards of a shattered crystal flying out (`u` = seconds since the shatter, `life` = fade time).
## Pre-fractured wedges of the cut, each with its own speed and spin (seeded, deterministic).
static func draw_shards(ci: CanvasItem, g: String, c: Vector2, s: float, u: float, life := 0.5, count := 18) -> void:
	if u < 0.0 or u > life:
		return
	var b: Array = BODY.get(g, BODY["L"])
	var outer := GemDraw.cut_points(cut(g), c, s)
	var n := outer.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(g + "shards")
	var fade := 1.0 - smoothstep(life * 0.45, life, u)
	for i in count:
		var j := i % n
		var p0 := outer[j]
		var p1 := outer[(j + 1) % n]
		var f0 := rng.randf_range(0.0, 0.35)
		var f1 := rng.randf_range(0.7, 1.0)
		var e0 := rng.randf_range(0.0, 0.3)
		var e1 := rng.randf_range(0.7, 1.0)
		var tri := PackedVector2Array([c.lerp(p0.lerp(p1, (e0 + e1) * 0.5), f0), p0.lerp(p1, e0).lerp(c, 1.0 - f1), p0.lerp(p1, e1).lerp(c, 1.0 - f1 * 0.95)])
		var cen := (tri[0] + tri[1] + tri[2]) / 3.0
		var dir := (cen - c).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var speed := rng.randf_range(300.0, 700.0) * (s / 360.0 * 0.6 + 0.4)
		var spin := rng.randf_range(-TAU, TAU)
		var off := dir * speed * (u - 0.5 * u * u) + Vector2(0, 260.0 * u * u)
		var rot := spin * u
		var sc := 1.0 - 0.35 * u / life
		var pts := PackedVector2Array()
		for q in tri:
			pts.append(cen + off + (q - cen).rotated(rot) * sc)
		var col: Color = (b[0] as Color).lerp(b[1], rng.randf_range(0.1, 0.7))
		if g == "M":
			col = FLECKS[i % FLECKS.size()].lerp(b[0], 0.35)
		col.a = fade
		ci.draw_colored_polygon(pts, col)
		var rim: Color = b[1]
		if g == "L":
			rim = Color("#FFE7A3")
		GemDraw.outline(ci, pts, Color(rim.r, rim.g, rim.b, 0.85 * fade), 1.2)


# ------------------------------------------------------------------ light

## Soft god rays from `c` (additive layer), `n` tapered shafts slowly turning by `rot`.
static func draw_rays(ci: CanvasItem, c: Vector2, R: float, col: Color, a: float, rot := 0.0, n := 9) -> void:
	if a <= 0.001:
		return
	for i in n:
		var ang := rot + TAU * float(i) / n + 0.21 * sin(float(i) * 2.3)
		var w := deg_to_rad(4.0 + 3.0 * absf(sin(float(i) * 1.7)))
		var len := R * (0.75 + 0.35 * absf(sin(float(i) * 3.1)))
		var d0 := Vector2(cos(ang - w), sin(ang - w))
		var d1 := Vector2(cos(ang + w), sin(ang + w))
		var pts := PackedVector2Array([c + d0 * R * 0.08, c + d0 * len, c + d1 * len, c + d1 * R * 0.08])
		var cc := Color(col.r, col.g, col.b, a * 0.22)
		var ce := Color(col.r, col.g, col.b, 0.0)
		ci.draw_polygon(pts, PackedColorArray([cc, ce, ce, cc]))


## A soft glow disc (additive layer).
static func draw_glow(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float) -> void:
	if a <= 0.001:
		return
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, a))


## Rising motes / glints across `rect` (seeded; `t` moves them up, wrapping).
static func draw_motes(ci: CanvasItem, rect: Rect2, col: Color, t: float, n := 24, a := 1.0, seed := 7) -> void:
	if a <= 0.001:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var x := rect.position.x + rng.randf() * rect.size.x
		var sp := rng.randf_range(40.0, 120.0)
		var y0 := rng.randf() * rect.size.y
		var y := rect.position.y + fposmod(y0 - t * sp, rect.size.y)
		var s := rng.randf_range(3.0, 9.0)
		var tw := 0.55 + 0.45 * sin(t * rng.randf_range(2.0, 5.0) + float(i))
		var edge := smoothstep(0.0, 0.15, (y - rect.position.y) / rect.size.y) * (1.0 - smoothstep(0.75, 1.0, (y - rect.position.y) / rect.size.y))
		var cc := Color(col.r, col.g, col.b, a * tw * edge)
		if s > 6.0:
			GemDraw.draw_glint(ci, Vector2(x + sin(t + i) * 8.0, y), s * 2.0, cc)
		else:
			ci.draw_circle(Vector2(x + sin(t + i) * 8.0, y), s * 0.45, cc)


## A thin expanding ring (shockwave / "the emblem rings").
static func draw_ring_pulse(ci: CanvasItem, c: Vector2, r0: float, r1: float, k: float, col: Color, w := 3.0) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var e := out3(k)
	ci.draw_arc(c, lerpf(r0, r1, e), 0.0, TAU, 64, Color(col.r, col.g, col.b, col.a * (1.0 - k)), w * (1.0 - k) + 1.0, true)


# ------------------------------------------------------------------ the large ceremony crystal

## The walkout crystal / revealed stone at ceremony scale (>= 200 px): a brilliant-cut crown
## (kite + star facets per girdle edge) with per-facet gradients from the deep girdle to the lit
## table, a fanned table with pavilion arrows, a moving caustic band clipped to the cut, a LIGHT
## rim (never a dark outline) and an inner glow `glow` 0..1. Lit from the upper left (GemDraw).
static func draw_crystal_lux(ci: CanvasItem, g: String, c: Vector2, s: float, alpha := 1.0, t := 0.0, glow := 0.0) -> void:
	if alpha <= 0.001:
		return
	var b: Array = BODY.get(g, BODY["L"])
	var base: Color = b[0]
	var light: Color = b[1]
	var deep: Color = b[2]
	var ct := cut(g)
	var outer := GemDraw.cut_points(ct, c, s)
	var n := outer.size()
	if n < 3:
		return
	var tk := 0.5
	match ct:
		"star": tk = 0.42
		"eye": tk = 0.46
		"triangle": tk = 0.46
	var tc := c + Vector2(0, -s * 0.03)
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(tc + (p - c) * tk)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var ld := GemDraw.LIGHT_DIR
	var add_tri := func(p0: Vector2, p1: Vector2, p2: Vector2, c0: Color, c1: Color, c2: Color) -> void:
		var k := pts.size()
		pts.append_array([p0, p1, p2])
		c0.a = alpha
		c1.a = alpha
		c2.a = alpha
		cols.append_array([c0, c1, c2])
		idx.append_array([k, k + 1, k + 2])
	# Crown: per girdle edge a kite facet split by the edge midpoint, and a star facet between.
	for i in n:
		var j := (i + 1) % n
		var m := (outer[i] + outer[j]) * 0.5
		var dir := ((outer[i] + outer[j]) * 0.5 - c).normalized()
		var lam := clampf(dir.dot(ld) * 0.5 + 0.5, 0.0, 1.0)
		var lo := deep.lerp(base, smoothstep(0.15, 0.8, lam))
		var hi := base.lerp(light, 0.12 + 0.7 * smoothstep(0.45, 1.0, lam))
		var alt := 0.08 if i % 2 == 0 else -0.04
		add_tri.call(outer[i], m, inner[i], lo, lo.lerp(hi, 0.35), hi.lightened(alt))
		add_tri.call(m, outer[j], inner[j], lo.lerp(hi, 0.35), lo.darkened(0.06), hi)
		var sl := base.lerp(light, 0.15 + 0.7 * lam)
		add_tri.call(inner[i], m, inner[j], sl.lightened(0.1), sl.darkened(0.12), sl)
	# Table: fanned from the centre, alternate wedges lighter (pavilion arrows seen through it).
	var tcen := base.lerp(light, 0.8)
	for i in n:
		var j := (i + 1) % n
		var dir := ((inner[i] + inner[j]) * 0.5 - tc).normalized()
		var lam := clampf(dir.dot(ld) * 0.5 + 0.5, 0.0, 1.0)
		var w := base.lerp(light, 0.3 + 0.45 * lam)
		if i % 2 == 1:
			w = w.lerp(deep, 0.18)
		add_tri.call(tc, inner[i], inner[j], tcen, w, w.lerp(base, 0.2))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
	if g == "M":
		draw_opal_fire(ci, tc, s, t, alpha)
	# Facet lines: thin light hairlines (crown edges and the table).
	var fl := Color(light.r, light.g, light.b, 0.38 * alpha)
	var lw := maxf(1.0, s * 0.004)
	var lines := PackedVector2Array()
	for i in n:
		if n > 10 and i % 2 == 1:
			continue
		lines.append_array([outer[i], inner[i]])
	ci.draw_multiline(lines, fl, lw, true)
	GemDraw.outline(ci, inner, Color(1, 1, 1, 0.42 * alpha), lw * 1.2)
	# Caustic band sweeping across the stone, clipped to the cut.
	var sw := fposmod(t * 0.32, 1.7) - 0.35
	if sw > -0.3 and sw < 1.3:
		var ax := Vector2(0.82, -0.57)
		var nx := Vector2(-ax.y, ax.x)
		var o := c + ax * lerpf(-0.75, 0.75, sw) * s
		var bw := s * 0.09
		var band := PackedVector2Array([o - nx * s - ax * bw, o + nx * s - ax * bw, o + nx * s + ax * bw, o - nx * s + ax * bw])
		for poly in Geometry2D.intersect_polygons(outer, band):
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.16 * alpha))
		var band2 := PackedVector2Array([o - nx * s + ax * bw * 1.6, o + nx * s + ax * bw * 1.6, o + nx * s + ax * bw * 2.1, o - nx * s + ax * bw * 2.1])
		for poly in Geometry2D.intersect_polygons(outer, band2):
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.1 * alpha))
	# Inner glow (charge) from the table.
	if glow > 0.0:
		var ig := light
		ci.draw_texture_rect(UIKit.glow_texture(), Rect2(tc - Vector2(s, s) * 0.36, Vector2(s, s) * 0.72), false, Color(ig.r, ig.g, ig.b, 0.32 * clampf(glow, 0.0, 1.0) * alpha))
	# Light rim: a bright girdle line plus a faint inner echo (no dark outline).
	var rim := light.lerp(Color(1, 1, 1), 0.35)
	GemDraw.outline(ci, outer, Color(rim.r, rim.g, rim.b, 0.9 * alpha), maxf(1.5, s * 0.007))
	var echo := PackedVector2Array()
	for p in outer:
		echo.append(c + (p - c) * 0.965)
	GemDraw.outline(ci, echo, Color(1, 1, 1, 0.22 * alpha), maxf(1.0, s * 0.004))
	GemDraw.draw_glint(ci, tc + Vector2(-s * 0.15, -s * 0.13), s * 0.3, Color(1, 1, 1, 0.85 * alpha))


## The tips of a cut where a gold claw holds the stone (ceremony stone setting).
static func prong_points(g: String, c: Vector2, s: float) -> PackedVector2Array:
	var outer := GemDraw.cut_points(cut(g), c, s)
	var out := PackedVector2Array()
	match cut(g):
		"star":
			for i in range(0, outer.size(), 2):
				out.append(outer[i])
		"triangle":
			for i in 3:
				out.append((outer[i * 2] + outer[i * 2 + 1]) * 0.5)
		"square":
			for i in 4:
				out.append((outer[i * 2 + 1] + outer[(i * 2 + 2) % 8]) * 0.5)
		"eye":
			out.append(outer[0])
			out.append(outer[12])
		_:
			for i in range(0, outer.size(), 2):
				out.append(outer[i])
	return out


## A gold claw prong at `p` pointing out of the stone centre `c`.
static func draw_prong(ci: CanvasItem, c: Vector2, p: Vector2, s: float, alpha := 1.0) -> void:
	var d := (p - c).normalized()
	var nrm := Vector2(-d.y, d.x)
	var L := s * 0.055
	var W := s * 0.028
	var tip := p + d * L * 0.55
	var poly := PackedVector2Array([p - d * L * 0.7 + nrm * W, tip + nrm * W * 0.35, tip + d * L * 0.35, tip - nrm * W * 0.35, p - d * L * 0.7 - nrm * W])
	var metal := Color("#E3C67E")
	ci.draw_polygon(poly, PackedColorArray([Color(metal.lightened(0.35), alpha), Color(metal.lightened(0.2), alpha), Color(metal, alpha), Color(metal.darkened(0.25), alpha), Color(metal.darkened(0.35), alpha)]))
	GemDraw.outline(ci, poly, Color(1.0, 0.95, 0.8, 0.6 * alpha), 1.0)


## A line glyph in raised gold relief (shadow below, gold body, a light top edge).
static func draw_relief_glyph(ci: CanvasItem, icon: String, r: Rect2, alpha := 1.0, shadow := Color(0.1, 0.06, 0.02)) -> void:
	var s := r.size.x
	var w := maxf(3.0, s * 0.055)
	KitIcons.line(ci, icon, Rect2(r.position + Vector2(0, s * 0.03), r.size), Color(shadow.r, shadow.g, shadow.b, 0.5 * alpha), w * 1.25)
	KitIcons.line(ci, icon, r, Color(0.62, 0.45, 0.18, alpha), w * 1.1)
	KitIcons.line(ci, icon, Rect2(r.position + Vector2(-s * 0.006, -s * 0.01), r.size), Color(0.93, 0.79, 0.47, alpha), w * 0.72)
	KitIcons.line(ci, icon, Rect2(r.position + Vector2(-s * 0.012, -s * 0.02), r.size), Color(1.0, 0.96, 0.84, 0.75 * alpha), w * 0.26)


## A card footer for the Portal screens. When HeroCard draws its own footer (footer_mode: the
## name at >= 22 px) the card shows just the name and the screen prints `text` outside the card;
## otherwise the kit's footer line carries `text` ("" = no sub-line).
static func card_footer(card: HeroCard, text: String) -> void:
	if "footer_mode" in card:
		card.set("footer_mode", "name")
		return
	if card.is_node_ready():
		card.card.footer = text
	else:
		card.ready.connect(func(): card.card.footer = text)
