class_name EnamelIcons
## «Емаль і золото» icons. Two kinds:
##  - kit OBJECTS (currencies): a gold coin with a riveted rim, an ice crystal shard, the gold
##    crown-crest from the knights' helmets - drawn as little die-cast parts, never emoji;
##  - chunky DEBOSSED pictograms (nav, settings, lock...): single navy ink stamped into the
##    enamel with a white lip below. `bg` fills holes (the enamel under the icon).

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")


static func draw(ci: CanvasItem, name: String, r: Rect2, ink := Color("1B2147"), bg := Color("F1EDE4"), style := "deboss") -> void:
	match name:
		"coin": _coin(ci, r)
		"crystal": _crystal(ci, r)
		"crest": _crest(ci, r)
		"geode_obj": _geode(ci, r)
		_:
			var shapes := _picto(name, r)
			if shapes.is_empty():
				return
			if style == "deboss":
				for s: Array in shapes:
					var off := PackedVector2Array()
					for p in (s[0] as PackedVector2Array):
						off.append(p + Vector2(0, 1.8))
					if not s[1]:
						K.poly(ci, off, Color(1, 1, 1, 0.9))
			elif style == "raised":
				for s: Array in shapes:
					var off := PackedVector2Array()
					for p in (s[0] as PackedVector2Array):
						off.append(p + Vector2(0, 2.4))
					if not s[1]:
						K.poly(ci, off, Color(0.02, 0.06, 0.2, 0.4))
			for s: Array in shapes:
				K.poly(ci, s[0], bg if s[1] else ink)


# ------------------------------------------------------------------ objects

static func _coin(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.5
	# thickness (edge) below
	ci.draw_circle(c + Vector2(0, rad * 0.14), rad, K.GOLD_DARK.darkened(0.25), true, -1.0, true)
	ci.draw_circle(c, rad, K.GOLD_DARK, true, -1.0, true)
	ci.draw_circle(c + Vector2(-rad * 0.03, -rad * 0.04), rad * 0.93, K.GOLD, true, -1.0, true)
	ci.draw_circle(c + Vector2(-rad * 0.1, -rad * 0.14), rad * 0.62, K.GOLD_LIGHT.lerp(K.GOLD, 0.35), true, -1.0, true)
	ci.draw_circle(c, rad * 0.66, K.GOLD_MID, false, maxf(1.5, rad * 0.06), true)
	# riveted rim
	var n := 10
	for i in n:
		var a := TAU * i / n - PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * rad * 0.8
		ci.draw_circle(p + Vector2(0.4, 0.6), rad * 0.085, Color(0.3, 0.18, 0.02, 0.6), true, -1.0, true)
		ci.draw_circle(p, rad * 0.075, K.GOLD_LIGHT, true, -1.0, true)
	# stamped ice lozenge
	var hw := rad * 0.26
	var hh := rad * 0.38
	var d := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
	var d2 := PackedVector2Array()
	for p in d:
		d2.append(p + Vector2(0, 1.2))
	K.poly(ci, d2, Color(1, 0.95, 0.8, 0.8))
	K.poly(ci, d, K.GOLD_DARK)
	ci.draw_arc(c, rad * 0.97, PI * 1.05, PI * 1.55, 12, Color(1, 1, 0.9, 0.7), maxf(1.2, rad * 0.06), true)


static func _crystal(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var h := r.size.y * 0.5
	var w := r.size.x * 0.3
	var top := c + Vector2(w * 0.1, -h)
	var bot := c + Vector2(0, h)
	var l1 := c + Vector2(-w, -h * 0.35)
	var l2 := c + Vector2(-w, h * 0.45)
	var r1 := c + Vector2(w, -h * 0.4)
	var r2 := c + Vector2(w, h * 0.4)
	var m1 := c + Vector2(-w * 0.1, -h * 0.25)
	var m2 := c + Vector2(-w * 0.05, h * 0.55)
	var outline := PackedVector2Array([top, r1, r2, bot, l2, l1])
	var grow := PackedVector2Array()
	for p in outline:
		grow.append(c + (p - c) * 1.0 + (p - c).normalized() * 2.2)
	K.poly(ci, grow, Color("0B2A55"))
	K.poly(ci, PackedVector2Array([top, m1, l1]), K.ICE_WHITE)
	K.poly(ci, PackedVector2Array([top, r1, m1]), K.ICE)
	K.poly(ci, PackedVector2Array([l1, m1, m2, l2]), Color("BDF3FF"))
	K.poly(ci, PackedVector2Array([m1, r1, r2, m2]), K.ICE_DEEP)
	K.poly(ci, PackedVector2Array([l2, m2, bot]), K.ICE)
	K.poly(ci, PackedVector2Array([m2, r2, bot]), Color("1A6FC0"))
	K.star(ci, top.lerp(l1, 0.5) + Vector2(2, 3), h * 0.28, Color(1, 1, 1, 0.95))


static func _crest(ci: CanvasItem, r: Rect2) -> void:
	# The knights' gold crown-crest: three blades on a band, an ice gem in the middle.
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	var P := func(u: float, v: float) -> Vector2: return Vector2(x0 + u * w, y0 + v * h)
	var body := PackedVector2Array([P.call(0.08, 0.86), P.call(0.04, 0.32), P.call(0.3, 0.52), P.call(0.5, 0.06),
		P.call(0.7, 0.52), P.call(0.96, 0.32), P.call(0.92, 0.86)])
	var sh := PackedVector2Array()
	for p in body:
		sh.append(p + Vector2(0, h * 0.06))
	K.poly(ci, sh, K.GOLD_DARK.darkened(0.3))
	K.poly(ci, body, K.GOLD_DARK)
	var inner := PackedVector2Array([P.call(0.13, 0.8), P.call(0.11, 0.44), P.call(0.31, 0.6), P.call(0.5, 0.2),
		P.call(0.69, 0.6), P.call(0.89, 0.44), P.call(0.87, 0.8)])
	K.poly(ci, inner, K.GOLD)
	K.poly(ci, PackedVector2Array([P.call(0.5, 0.2), P.call(0.31, 0.6), P.call(0.13, 0.8), P.call(0.13, 0.66), P.call(0.3, 0.5)]), K.GOLD_LIGHT)
	K.vgrad(ci, Rect2(P.call(0.1, 0.72), Vector2(w * 0.8, h * 0.16)), [K.GOLD_LIGHT, K.GOLD_MID])
	K.draw_inlay(ci, P.call(0.5, 0.56), Vector2(w * 0.2, h * 0.32), [K.ICE_WHITE, K.ICE, K.ICE_DEEP], false)
	for u in [0.04, 0.5, 0.96]:
		ci.draw_circle(P.call(u, 0.32 if u != 0.5 else 0.06), w * 0.06, K.GOLD_LIGHT, true, -1.0, true)


static func _geode(ci: CanvasItem, r: Rect2) -> void:
	# The world cache: a basalt egg cracked open at the top, amethyst inside, a gold band.
	var c := r.get_center() + Vector2(0, r.size.y * 0.06)
	var rx := r.size.x * 0.4
	var ry := r.size.y * 0.44
	var egg := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var k := 1.0 if sin(a) > 0.0 else 1.12
		egg.append(c + Vector2(cos(a) * rx, sin(a) * ry * k))
	var sh := PackedVector2Array()
	for p in egg:
		sh.append(p + Vector2(1.5, 3.0))
	K.poly(ci, sh, Color(0, 0, 0.05, 0.45))
	K.poly(ci, egg, Color("23253A"))
	var lit := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var k := 1.0 if sin(a) > 0.0 else 1.12
		lit.append(c + Vector2(-rx * 0.12, -ry * 0.1) + Vector2(cos(a) * rx * 0.72, sin(a) * ry * 0.72 * k))
	K.poly(ci, lit, Color("3A3E5C"))
	# gold band
	var band := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		band.append(c + Vector2(-cos(a) * rx * 0.99, ry * 0.28 + sin(a) * ry * 0.12))
	for i in 17:
		var a := PI - PI * i / 16.0
		band.append(c + Vector2(-cos(a) * rx * 0.99, ry * 0.12 + sin(a) * ry * 0.12))
	K.poly(ci, band, K.GOLD)
	# the crack and the crystals
	var top := c + Vector2(0, -ry * 0.98)
	var crys := [[Vector2(-0.3, -0.55), 0.5, -0.35], [Vector2(0.02, -0.72), 0.7, 0.05], [Vector2(0.3, -0.5), 0.45, 0.4]]
	K.poly(ci, PackedVector2Array([c + Vector2(-rx * 0.62, -ry * 0.42), c + Vector2(-rx * 0.3, -ry * 0.62), c + Vector2(0, -ry * 0.5),
		c + Vector2(rx * 0.3, -ry * 0.64), c + Vector2(rx * 0.62, -ry * 0.4), c + Vector2(0, -ry * 0.18)]), Color("150A2E"))
	for cr: Array in crys:
		var base: Vector2 = c + Vector2(rx, ry) * (cr[0] as Vector2) + Vector2(0, ry * 0.25)
		var h: float = ry * float(cr[1])
		var tilt: float = cr[2]
		var dir := Vector2(sin(tilt), -cos(tilt))
		var side := Vector2(-dir.y, dir.x) * rx * 0.16
		var tip := base + dir * h
		K.poly(ci, PackedVector2Array([base - side, tip - dir * h * 0.25 - side, tip, base]), Color("C9A8FF"))
		K.poly(ci, PackedVector2Array([base, tip, tip - dir * h * 0.25 + side, base + side]), Color("7A3FD0"))
	K.star(ci, top + Vector2(rx * 0.1, ry * 0.15), ry * 0.22, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ pictograms

## Returns [[points, is_hole], ...] in draw order.
static func _picto(name: String, r: Rect2) -> Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var s := minf(r.size.x, r.size.y)
	var ox := x0 + (r.size.x - s) * 0.5
	var oy := y0 + (r.size.y - s) * 0.5
	var P := func(u: float, v: float) -> Vector2: return Vector2(ox + u * s, oy + v * s)
	var out: Array = []
	match name:
		"gear":
			var c: Vector2 = P.call(0.5, 0.5)
			var pts := PackedVector2Array()
			var n := 8
			var st := TAU / n
			for i in n:
				var a := st * i
				for k: Array in [[-0.34, 0.33], [-0.17, 0.48], [0.17, 0.48], [0.34, 0.33]]:
					var aa: float = a + float(k[0]) * st
					pts.append(c + Vector2(cos(aa), sin(aa)) * s * float(k[1]))
			out.append([pts, false])
			out.append([_circle(c, s * 0.14, 20), true])
		"plus":
			var t := 0.14
			out.append([PackedVector2Array([P.call(0.5 - t, 0.12), P.call(0.5 + t, 0.12), P.call(0.5 + t, 0.5 - t), P.call(0.88, 0.5 - t),
				P.call(0.88, 0.5 + t), P.call(0.5 + t, 0.5 + t), P.call(0.5 + t, 0.88), P.call(0.5 - t, 0.88), P.call(0.5 - t, 0.5 + t),
				P.call(0.12, 0.5 + t), P.call(0.12, 0.5 - t), P.call(0.5 - t, 0.5 - t)]), false])
		"check":
			out.append([PackedVector2Array([P.call(0.08, 0.52), P.call(0.24, 0.36), P.call(0.42, 0.54), P.call(0.78, 0.16), P.call(0.94, 0.32), P.call(0.42, 0.86)]), false])
		"lock":
			out.append([PackedVector2Array([P.call(0.16, 0.44), P.call(0.84, 0.44), P.call(0.84, 0.92), P.call(0.16, 0.92)]), false])
			var arc := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				arc.append(P.call(0.5, 0.42) + Vector2(cos(a), sin(a)) * s * 0.28)
			for i in 13:
				var a := TAU - PI * i / 12.0
				arc.append(P.call(0.5, 0.42) + Vector2(cos(a), sin(a)) * s * 0.16)
			out.append([arc, false])
			out.append([_circle(P.call(0.5, 0.64), s * 0.07, 12), true])
			out.append([PackedVector2Array([P.call(0.47, 0.66), P.call(0.53, 0.66), P.call(0.55, 0.8), P.call(0.45, 0.8)]), true])
		"fox":
			# Fox head: two tall ears, wide cheeks, a pointed muzzle; eyes as holes.
			out.append([PackedVector2Array([P.call(0.08, 0.06), P.call(0.36, 0.3), P.call(0.64, 0.3), P.call(0.92, 0.06), P.call(0.9, 0.46),
				P.call(0.98, 0.56), P.call(0.66, 0.74), P.call(0.5, 0.96), P.call(0.34, 0.74), P.call(0.02, 0.56), P.call(0.1, 0.46)]), false])
			out.append([PackedVector2Array([P.call(0.27, 0.5), P.call(0.42, 0.55), P.call(0.36, 0.62)]), true])
			out.append([PackedVector2Array([P.call(0.73, 0.5), P.call(0.58, 0.55), P.call(0.64, 0.62)]), true])
			out.append([PackedVector2Array([P.call(0.18, 0.18), P.call(0.32, 0.32), P.call(0.2, 0.38)]), true])
			out.append([PackedVector2Array([P.call(0.82, 0.18), P.call(0.68, 0.32), P.call(0.8, 0.38)]), true])
		"helm":
			# Knight helm with a crest blade and a visor slit.
			out.append([PackedVector2Array([P.call(0.44, 0.0), P.call(0.56, 0.0), P.call(0.6, 0.2), P.call(0.4, 0.2)]), false])
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(P.call(0.5, 0.52) + Vector2(cos(a) * 0.36, sin(a) * 0.34) * s)
			dome.append(P.call(0.86, 0.96))
			dome.append(P.call(0.14, 0.96))
			out.append([dome, false])
			out.append([PackedVector2Array([P.call(0.22, 0.48), P.call(0.78, 0.48), P.call(0.78, 0.58), P.call(0.22, 0.58)]), true])
			out.append([PackedVector2Array([P.call(0.46, 0.58), P.call(0.54, 0.58), P.call(0.54, 0.86), P.call(0.46, 0.86)]), true])
		"cannon":
			# A war machine on wheels: barrel up-right, body, two wheels (holes for hubs).
			out.append([PackedVector2Array([P.call(0.42, 0.42), P.call(0.86, 0.12), P.call(0.96, 0.26), P.call(0.56, 0.58)]), false])
			out.append([PackedVector2Array([P.call(0.08, 0.5), P.call(0.66, 0.5), P.call(0.74, 0.7), P.call(0.04, 0.7)]), false])
			out.append([_circle(P.call(0.24, 0.78), s * 0.17, 18), false])
			out.append([_circle(P.call(0.62, 0.78), s * 0.17, 18), false])
			out.append([_circle(P.call(0.24, 0.78), s * 0.06, 10), true])
			out.append([_circle(P.call(0.62, 0.78), s * 0.06, 10), true])
		"chest":
			# Shop: a kit box with a hinged lid and a gem clasp.
			out.append([PackedVector2Array([P.call(0.06, 0.36), P.call(0.18, 0.14), P.call(0.82, 0.14), P.call(0.94, 0.36)]), false])
			out.append([PackedVector2Array([P.call(0.06, 0.42), P.call(0.94, 0.42), P.call(0.94, 0.9), P.call(0.06, 0.9)]), false])
			out.append([PackedVector2Array([P.call(0.5, 0.32), P.call(0.62, 0.48), P.call(0.5, 0.64), P.call(0.38, 0.48)]), true])
		"geode":
			# Vault: the egg cache cracked open, crystals inside.
			var egg := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var ry := 0.46 if sin(a) < 0 else 0.4
				egg.append(P.call(0.5, 0.54) + Vector2(cos(a) * 0.38, sin(a) * ry) * s)
			out.append([egg, false])
			out.append([PackedVector2Array([P.call(0.28, 0.5), P.call(0.36, 0.22), P.call(0.44, 0.42), P.call(0.5, 0.12), P.call(0.58, 0.4),
				P.call(0.66, 0.24), P.call(0.72, 0.5), P.call(0.5, 0.62)]), true])
		"gate":
			# The ×2 crystal gate: two posts, an arch, a chevron.
			out.append([PackedVector2Array([P.call(0.06, 0.96), P.call(0.06, 0.3), P.call(0.5, 0.04), P.call(0.94, 0.3), P.call(0.94, 0.96),
				P.call(0.76, 0.96), P.call(0.76, 0.38), P.call(0.5, 0.24), P.call(0.24, 0.38), P.call(0.24, 0.96)]), false])
			out.append([PackedVector2Array([P.call(0.34, 0.52), P.call(0.5, 0.66), P.call(0.66, 0.52), P.call(0.66, 0.68), P.call(0.5, 0.82), P.call(0.34, 0.68)]), false])
		"castle":
			out.append([PackedVector2Array([P.call(0.06, 0.96), P.call(0.06, 0.2), P.call(0.22, 0.2), P.call(0.22, 0.32), P.call(0.36, 0.32),
				P.call(0.36, 0.2), P.call(0.64, 0.2), P.call(0.64, 0.32), P.call(0.78, 0.32), P.call(0.78, 0.2), P.call(0.94, 0.2), P.call(0.94, 0.96)]), false])
			var door := PackedVector2Array([P.call(0.36, 0.96), P.call(0.36, 0.66)])
			for i in 7:
				var a := PI + PI * i / 6.0
				door.append(P.call(0.5, 0.66) + Vector2(cos(a), sin(a)) * s * 0.14)
			door.append(P.call(0.64, 0.96))
			out.append([door, true])
		"horns":
			# Enemy boss: a horned helm.
			out.append([PackedVector2Array([P.call(0.02, 0.06), P.call(0.3, 0.4), P.call(0.7, 0.4), P.call(0.98, 0.06), P.call(0.84, 0.5),
				P.call(0.8, 0.94), P.call(0.2, 0.94), P.call(0.16, 0.5)]), false])
			out.append([PackedVector2Array([P.call(0.26, 0.56), P.call(0.46, 0.62), P.call(0.3, 0.68)]), true])
			out.append([PackedVector2Array([P.call(0.74, 0.56), P.call(0.54, 0.62), P.call(0.7, 0.68)]), true])
		"bolt":
			out.append([PackedVector2Array([P.call(0.58, 0.02), P.call(0.18, 0.56), P.call(0.46, 0.56), P.call(0.36, 0.98), P.call(0.82, 0.4),
				P.call(0.54, 0.4)]), false])
		"blueprint":
			out.append([PackedVector2Array([P.call(0.12, 0.06), P.call(0.7, 0.06), P.call(0.88, 0.24), P.call(0.88, 0.94), P.call(0.12, 0.94)]), false])
			out.append([PackedVector2Array([P.call(0.24, 0.42), P.call(0.76, 0.42), P.call(0.76, 0.5), P.call(0.24, 0.5)]), true])
			out.append([PackedVector2Array([P.call(0.24, 0.62), P.call(0.66, 0.62), P.call(0.66, 0.7), P.call(0.24, 0.7)]), true])
		"rush":
			# The run: a double chevron charging forward over a bridge plank.
			for k in 2:
				var dx := 0.3 * k
				out.append([PackedVector2Array([P.call(0.06 + dx, 0.1), P.call(0.28 + dx, 0.1), P.call(0.6 + dx, 0.44), P.call(0.28 + dx, 0.78),
					P.call(0.06 + dx, 0.78), P.call(0.38 + dx, 0.44)]), false])
			out.append([PackedVector2Array([P.call(0.04, 0.86), P.call(0.96, 0.86), P.call(0.96, 0.96), P.call(0.04, 0.96)]), false])
		"play":
			out.append([PackedVector2Array([P.call(0.22, 0.08), P.call(0.9, 0.5), P.call(0.22, 0.92)]), false])
		"ad":
			out.append([PackedVector2Array([P.call(0.04, 0.18), P.call(0.96, 0.18), P.call(0.96, 0.82), P.call(0.04, 0.82)]), false])
			out.append([PackedVector2Array([P.call(0.38, 0.32), P.call(0.68, 0.5), P.call(0.38, 0.68)]), true])
	return out


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p
