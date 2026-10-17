class_name JwArt
## «Ювелірна майстерня» icons as jewellery: struck coin with the fox profile, a tiara,
## a cameo, a geode egg, an engraved compass star. Drawn with Jw primitives.

## Bolt the fox in profile (facing right), unit box centred at 0: [point, sharp].
const FOX := [
	[Vector2(-0.30, 0.58), true], [Vector2(-0.36, 0.28), false], [Vector2(-0.30, 0.0), false],
	[Vector2(-0.28, -0.22), false], [Vector2(-0.12, -0.70), true], [Vector2(0.02, -0.28), true],
	[Vector2(0.12, -0.22), false], [Vector2(0.22, -0.14), false], [Vector2(0.42, -0.04), false],
	[Vector2(0.58, 0.02), true], [Vector2(0.54, 0.08), false], [Vector2(0.34, 0.12), true],
	[Vector2(0.30, 0.17), false], [Vector2(0.14, 0.24), false], [Vector2(0.2, 0.34), true],
	[Vector2(0.04, 0.33), false], [Vector2(0.1, 0.47), true], [Vector2(-0.04, 0.45), false],
	[Vector2(-0.06, 0.60), true],
]
const FOX_EAR2 := [Vector2(-0.02, -0.26), Vector2(0.1, -0.64), Vector2(0.16, -0.24)]


## Closed Catmull-Rom through the fox points (sharp points are kept as corners).
static func fox_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	var sharp: Array[bool] = []
	for e in FOX:
		pts.append(c + (e[0] as Vector2) * s)
		sharp.append(e[1])
	var n := pts.size()
	var out := PackedVector2Array()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		if sharp[i]:
			p0 = p1
		if sharp[(i + 1) % n]:
			p3 = p2
		for k in 6:
			var t := k / 6.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## Fox profile in relief: dark offset shadow, body, a lit rim along the upper-left edges.
static func fox_relief(ci: CanvasItem, c: Vector2, s: float, body: Color, light: Color, shadow: Color) -> void:
	var ear2 := PackedVector2Array()
	for v in FOX_EAR2:
		ear2.append(c + (v as Vector2) * s)
	Jw.fill(ci, ear2, body.lerp(shadow, 0.35))
	Jw.fill(ci, fox_pts(c + Vector2(s * 0.03, s * 0.05), s), shadow)
	var p := fox_pts(c, s)
	Jw.fill_ramp(ci, p, Jw.ramp_tex("relief_%s" % body.to_html(), [[0.0, light], [0.45, body], [1.0, body.lerp(shadow, 0.35)]]), Vector2(0.5, 1).normalized())
	var n := Jw.normals(p)
	for k in p.size():
		var a := p[k]
		var b := p[(k + 1) % p.size()]
		var en := (n[k] + n[(k + 1) % p.size()]).normalized()
		var l := en.dot(Jw.TO_LIGHT)
		if l > 0.1:
			ci.draw_line(a - en * 1.0, b - en * 1.0, Color(light, clampf(l, 0.0, 1.0)), maxf(s * 0.035, 1.2), true)
	# inner ear and eye cut
	Jw.fill(ci, PackedVector2Array([c + Vector2(-0.19, -0.28) * s, c + Vector2(-0.12, -0.56) * s, c + Vector2(-0.04, -0.3) * s]), shadow.lerp(body, 0.45))
	var eye := PackedVector2Array([c + Vector2(0.1, -0.09) * s, c + Vector2(0.17, -0.13) * s, c + Vector2(0.24, -0.08) * s, c + Vector2(0.16, -0.06) * s])
	Jw.fill(ci, eye, shadow)


## Struck gold coin with the fox profile.
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, r * 0.1), r * 1.04, Color(0, 0, 0, 0.45), true, -1.0, true)
	var field := Jw.regular(c, r * 0.8, 40)
	Jw.fill_ramp(ci, field, Jw.ramp_tex("coin_field", [[0.0, Color("ffe29a")], [0.45, Color("e2b04a")], [1.0, Color("9a6418")]]), Vector2(0.4, 1).normalized())
	Jw.gold_moulding(ci, Jw.regular(c, r, 40), Jw.regular(c, r * 0.8, 40), 0.4)
	# reeded edge hint
	for k in 24:
		var a := TAU * k / 24.0
		var u := Vector2(cos(a), sin(a))
		ci.draw_line(c + u * r * 0.84, c + u * r * 0.9, Color(Jw.GOLD_INK, 0.35), 1.0, true)
	fox_relief(ci, c + Vector2(-r * 0.04, r * 0.02), r * 1.05, Color("f2c35a"), Color("fff3c8"), Color("8a5a17"))


## Tiara icon (the «корони» currency): a band arc, five peaks, a centre ice brilliant.
static func tiara(ci: CanvasItem, c: Vector2, r: float, kind := "ice") -> void:
	# lower band: arc
	var base := Jw.arc(c + Vector2(0, r * 1.9), r * 1.6, -PI * 0.5 - 0.72, -PI * 0.5 + 0.72, 12)
	var top := PackedVector2Array()
	var peaks := [[-0.95, 0.15], [-0.55, -0.35], [0.0, -0.95], [0.55, -0.35], [0.95, 0.15]]
	for k in peaks.size():
		var pk: Array = peaks[k]
		top.append(c + Vector2(pk[0], pk[1]) * r)
		if k < peaks.size() - 1:
			var nx: Array = peaks[k + 1]
			top.append(c + Vector2((pk[0] + nx[0]) * 0.5, maxf(pk[1], nx[1]) * 0.4 + 0.32) * r)
	var shape := PackedVector2Array()
	shape.append_array(top)
	var rb := base.duplicate()
	rb.reverse()
	shape.append_array(rb)
	var sh := PackedVector2Array()
	for v in shape:
		sh.append(v + Vector2(r * 0.04, r * 0.1))
	Jw.fill(ci, sh, Color(0, 0, 0, 0.45))
	Jw.gold_fill(ci, shape, Vector2(0.3, 1))
	Jw.line(ci, shape, Color(Jw.GOLD_INK, 0.8), 1.2)
	# band rule
	var band := Jw.arc(c + Vector2(0, r * 1.9), r * 1.32, -PI * 0.5 - 0.62, -PI * 0.5 + 0.62, 12)
	ci.draw_polyline(band, Color(Jw.GOLD_INK, 0.6), 1.2, true)
	for k in [0, 1, 3, 4]:
		var pk: Array = peaks[k]
		ci.draw_circle(c + Vector2(pk[0], pk[1]) * r + Vector2(0, -r * 0.02), r * 0.1, Jw.gem(kind, 0.85), true, -1.0, true)
	Jw.brilliant(ci, c + Vector2(0, -r * 0.18), r * 0.36, kind)


## Engraved 8-point compass star (settings).
static func compass(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 16:
		var a := -PI * 0.5 + TAU * k / 16.0
		var rr := r if k % 4 == 0 else (r * 0.62 if k % 2 == 0 else r * 0.28)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var sh := PackedVector2Array()
	for v in pts:
		sh.append(v + Vector2(0, 2))
	Jw.fill(ci, sh, Color(0, 0, 0, 0.5))
	# each ray split into a lit and a shaded half
	for k in 16:
		var a := pts[k]
		var b := pts[(k + 1) % 16]
		var mid := (a + b) * 0.5 - c
		Jw.fill(ci, PackedVector2Array([c, a, b]), Jw.gold(0.48 + 0.42 * mid.normalized().dot(Jw.TO_LIGHT) * (1.0 if k % 2 == 0 else -0.6)))
	Jw.line(ci, pts, Color(Jw.GOLD_INK, 0.8), 1.0)
	ci.draw_circle(c, r * 0.2, Jw.gold(0.3), true, -1.0, true)
	Jw.octagem(ci, c, r * 0.16, "ice")


## Cameo: an oval of sapphire-violet ground with Bolt's profile in ivory relief, in a gold
## frame with milgrain.
static func cameo(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	ci.draw_set_transform(Vector2.ZERO)
	Jw.fill(ci, Jw.ellipse(c + Vector2(0, 4), rx + 9, ry + 9), Color(0, 0, 0, 0.5))
	Jw.gold_moulding(ci, Jw.ellipse(c, rx + 8, ry + 8), Jw.ellipse(c, rx, ry), 0.42)
	var g := Jw.ellipse(c, rx, ry)
	# sardonyx shell: the fox's own orange-red under ivory relief
	Jw.fill_ramp(ci, g, Jw.ramp_tex("cameo", [[0.0, Color("d0703a")], [0.5, Color("9a3a1c")], [1.0, Color("4a160a")]]), Vector2(0.3, 1).normalized())
	Jw.milgrain(ci, Jw.ellipse(c, rx - 4, ry - 4, 64), 6.0, 1.1)
	fox_relief(ci, c + Vector2(-rx * 0.1, ry * 0.08), ry * 1.15, Color("f4e9d6"), Color("ffffff"), Color("5a1c0c"))


## Geode egg (cache): basalt shell, a cracked window of amethyst points, a gold band.
static func geode(ci: CanvasItem, c: Vector2, r: float) -> void:
	var egg := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		var y := sin(a)
		var x := cos(a) * (0.78 - 0.1 * y)
		egg.append(c + Vector2(x, y * 1.0) * r)
	var sh := PackedVector2Array()
	for v in egg:
		sh.append(v + Vector2(r * 0.05, r * 0.08))
	Jw.fill(ci, sh, Color(0, 0, 0, 0.5))
	Jw.fill_ramp(ci, egg, Jw.ramp_tex("basalt", [[0.0, Color("5a5f78")], [0.45, Color("2e3044")], [1.0, Color("121320")]]), Vector2(0.5, 1).normalized())
	# crack window
	var win := PackedVector2Array([c + Vector2(-0.34, -0.1) * r, c + Vector2(-0.12, -0.36) * r, c + Vector2(0.08, -0.22) * r,
		c + Vector2(0.3, -0.3) * r, c + Vector2(0.38, 0.02) * r, c + Vector2(0.16, 0.2) * r, c + Vector2(-0.1, 0.12) * r, c + Vector2(-0.3, 0.2) * r])
	Jw.fill(ci, win, Color("1a0838"))
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.32
		var base := c + Vector2((k - 3) * 0.09, 0.12) * r
		var tip := base + Vector2(cos(a), sin(a)) * r * (0.28 + 0.06 * (k % 3))
		var s := Vector2(-sin(a), cos(a)) * r * 0.06
		Jw.fill(ci, PackedVector2Array([base - s, tip, base + s]), Jw.gem("amethyst", 0.45 + 0.08 * (k % 4)))
		ci.draw_line(base - s * 0.2, tip, Jw.gem("amethyst", 0.95), 1.0, true)
	Jw.line(ci, win, Color(0.75, 0.55, 1.0, 0.8), 1.2)
	# gold band
	var band_o := PackedVector2Array()
	var band_i := PackedVector2Array()
	for k in 17:
		var x := lerpf(-0.74, 0.74, k / 16.0)
		var y := 0.42 + 0.12 * (1.0 - x * x / 0.55)
		band_o.append(c + Vector2(x, y - 0.06) * r)
		band_i.append(c + Vector2(x, y + 0.06) * r)
	var bp := band_o.duplicate()
	var bi := band_i.duplicate()
	bi.reverse()
	bp.append_array(bi)
	Jw.gold_fill(ci, bp, Vector2(0, 1))
	Jw.line(ci, bp, Color(Jw.GOLD_INK, 0.7), 1.0)
	Jw.glint(ci, c + Vector2(0.1, -0.2) * r, r * 0.32, Color(0.9, 0.8, 1.0))


## A constellation star: a little brilliant with a 4-point glint (lit) or a hollow ring.
static func star(ci: CanvasItem, c: Vector2, r: float, lit: bool, kind := "ice") -> void:
	if lit:
		ci.draw_circle(c, r * 2.6, Color(0.55, 0.85, 1.0, 0.08), true, -1.0, true)
		Jw.glint(ci, c, r * 2.2, Color(0.85, 0.95, 1.0))
		Jw.brilliant(ci, c, r, kind)
	else:
		ci.draw_circle(c, r * 0.95, Color(0.02, 0.03, 0.1, 0.8), true, -1.0, true)
		ci.draw_arc(c, r * 0.95, 0, TAU, 24, Color(Jw.GOLD, 0.75), 1.6, true)
		ci.draw_circle(c, r * 0.28, Color(Jw.GOLD, 0.7), true, -1.0, true)
