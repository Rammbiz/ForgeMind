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
