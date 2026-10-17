class_name EnamelChrome
## «Емаль і золото» shared chrome: the riveted gold NAMEPLATE RAIL at the top (profile badge,
## stamped currency plates with odometer counters, settings key), the KIT TRAY at the bottom
## (a navy enamel tray holding five white plate-keys; the active one is pressed in and its ice
## inlay lights) and the TOGGLE-KEY tab row.

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")
const I := preload("res://scripts/ui/skins/enamel/enamel_icons.gd")

const NAV := [
	["shop", "chest", "Магазин"],
	["arsenal", "cannon", "Арсенал"],
	["play", "rush", "Гра"],
	["heroes", "fox", "Герої"],
	["barracks", "helm", "Казарми"],
]


## A stamped currency plate: kit object + odometer. Returns the plate rect.
static func currency(parent: Node, x: float, y: float, icon: String, value: String, plus := false, o := {}) -> Rect2:
	var size := int(o.get("size", 26))
	var cw: float = round(size * 0.86)
	var digits := value.replace(" ", "").length()
	var spaces := value.length() - digits
	var odo_w: float = digits * (cw + 2.0) - 2.0 + spaces * 5.0
	var ic := float(o.get("icon", 46.0))
	var h := float(o.get("h", 60.0))
	var w: float = 12.0 + ic + 10.0 + odo_w + 16.0 + (40.0 if plus else 0.0)
	var r := Rect2(x, y, w, h)
	K.plate(parent, r, {"ch": 14.0, "trim": 3.0, "inset": 3.0, "shadow": 0.5, "spec": 0.4})
	K.canvas(parent, func(ci: CanvasItem) -> void:
		var cy := r.get_center().y
		I.draw(ci, icon, Rect2(r.position.x + 11.0, cy - ic * 0.5, ic, ic))
		K.odometer(ci, value, size, Vector2(r.position.x + 12.0 + ic + 10.0, cy))
		)
	if plus:
		var pr := Rect2(r.end.x - 46.0, r.position.y + 9.0, 36.0, h - 17.0)
		K.plate(parent, pr, {"mat": "ice", "depth": 5.0, "ch": 6.0, "rad": 3.0, "trim": 0.0, "shadow": 0.3, "pad": 10.0, "bevel_w": 4.0})
		K.canvas(parent, func(ci: CanvasItem) -> void:
			var fr := K.face_of(pr, 5.0)
			I.draw(ci, "plus", Rect2(fr.get_center() - Vector2(10, 10), Vector2(20, 20)), K.WHITE, K.CTA, "raised"))
	return r


## Profile badge (enamel plate with the hero's stamped head) + navy rank ribbon.
static func profile(parent: Node, r: Rect2, level: String) -> void:
	K.plate(parent, r, {"ch": 14.0, "trim": 3.0, "rivet": 3.6, "shadow": 0.5})
	K.canvas(parent, func(ci: CanvasItem) -> void:
		I.draw(ci, "fox", Rect2(r.position.x + 18.0, r.position.y + 10.0, r.size.x - 36.0, r.size.x - 36.0), K.INK, Color("F6F3EC"))
		# Rank ribbon: navy enamel band with notched tails, gold edge, white tabular level.
		var y := r.end.y - 8.0
		var x0 := r.position.x - 8.0
		var x1 := r.end.x + 8.0
		var tail := PackedVector2Array([Vector2(x0 - 4, y - 2), Vector2(x0 + 18, y - 2), Vector2(x0 + 18, y + 26), Vector2(x0 - 4, y + 26), Vector2(x0 + 5, y + 12)])
		var tail2 := PackedVector2Array([Vector2(x1 + 4, y - 2), Vector2(x1 - 18, y - 2), Vector2(x1 - 18, y + 26), Vector2(x1 + 4, y + 26), Vector2(x1 - 5, y + 12)])
		K.poly(ci, tail, Color("0E1232"))
		K.poly(ci, tail2, Color("0E1232"))
		var band := Rect2(x0 + 8, y - 8, x1 - x0 - 16, 34)
		ci.draw_rect(Rect2(band.position + Vector2(0, 3), band.size), Color(0, 0, 0.05, 0.45))
		ci.draw_rect(band.grow(2.0), K.GOLD_DARK)
		ci.draw_rect(band.grow(1.0), K.GOLD)
		K.vgrad(ci, band, [Color("2C366E"), Color("1E2656"), Color("161C44")])
		K.text_c(ci, level, "num", 26, band.get_center() + Vector2(0, 1), K.ENAMEL, "raised"))


## Settings: a small square enamel key with a stamped cog.
static func settings(parent: Node, r: Rect2) -> void:
	K.plate(parent, r, {"depth": 7.0, "ch": 8.0, "trim": 0.0, "shadow": 0.5, "pad": 14.0})
	K.canvas(parent, func(ci: CanvasItem) -> void:
		var fr := K.face_of(r, 7.0)
		I.draw(ci, "gear", Rect2(fr.get_center() - Vector2(17, 17), Vector2(34, 34)), K.INK, Color("F3EFE7")))


## The riveted gold rail with the profile, three currency plates and the settings key.
static func top_bar(parent: Node, o := {}) -> void:
	K.canvas(parent, func(ci: CanvasItem) -> void:
		K.rail(ci, Vector2(-4, 54), Vector2(724, 54), 12.0, false)
		for x in [128.0, 640.0]:
			K.rivet(ci, Vector2(x, 54), 4.2))
	profile(parent, Rect2(16, 12, 88, 84), str(o.get("level", "14")))
	var y := 24.0
	var coin_w := _cur_w("2 590", false)
	var gem_w := _cur_w("40", true)
	var crest_w := _cur_w("26", false)
	var x := 640.0 - coin_w
	currency(parent, x, y, "coin", str(o.get("coins", "2 590")))
	x -= gem_w + 10.0
	currency(parent, x, y, "crystal", str(o.get("gems", "40")), true)
	x -= crest_w + 10.0
	currency(parent, x, y, "crest", str(o.get("crowns", "26")))
	settings(parent, Rect2(652, 26, 54, 62))


static func _cur_w(value: String, plus: bool) -> float:
	var cw: float = round(26 * 0.86)
	var digits := value.replace(" ", "").length()
	var spaces := value.length() - digits
	return 12.0 + 46.0 + 10.0 + digits * (cw + 2.0) - 2.0 + spaces * 5.0 + 16.0 + (40.0 if plus else 0.0)


## The kit tray: navy enamel tray (gold trim, rivets) with five slotted white plate-keys.
static func nav(parent: Node, active: String, badges := {}) -> void:
	var tr := Rect2(6, 1124, 708, 150)
	K.plate(parent, tr, {"mat": "navy", "ch": 22.0, "rad": 8.0, "trim": 4.0, "inset": 4.0, "rivet": 4.5, "rivet_every": 140.0, "shadow": 0.6, "shadow_off": Vector2(0, -4), "spec": 0.25, "edge": 0.0})
	var n := NAV.size()
	var gap := 8.0
	var x0 := 24.0
	var kw := (720.0 - 2.0 * x0 - gap * (n - 1)) / n
	for i in n:
		var d: Array = NAV[i]
		var on: bool = d[0] == active
		var kr := Rect2(x0 + i * (kw + gap), 1140, kw, 116)
		var depth := 11.0
		K.plate(parent, kr, {"depth": depth, "press": 1.0 if on else 0.0, "ch": 12.0, "trim": 0.0, "shadow": 0.55, "pad": 16.0,
			"glow": Color(0.56, 0.92, 1.0, 0.55) if on else Color(0, 0, 0, 0), "glow_r": 10.0, "spec": 0.45})
		var fr := K.face_of(kr, depth, 1.0 if on else 0.0)
		var badge := str(badges.get(d[0], ""))
		K.canvas(parent, func(ci: CanvasItem) -> void:
			if on:
				# The lit ice inlay strip along the top of the pressed key.
				var s := Rect2(fr.position.x + 18.0, fr.position.y + 7.0, fr.size.x - 36.0, 7.0)
				ci.draw_rect(s.grow(1.5), K.GOLD_DARK)
				K.vgrad(ci, s, [K.ICE_WHITE, K.ICE, K.ICE_DEEP])
				ci.draw_rect(Rect2(s.position.x - 6, s.position.y - 5, s.size.x + 12, s.size.y + 10), Color(0.56, 0.92, 1.0, 0.18))
			var ic := 46.0
			I.draw(ci, d[1], Rect2(fr.get_center().x - ic * 0.5, fr.position.y + 18.0, ic, ic), K.INK if on else Color("2A3160"), Color("F1EDE4"))
			var lbl: String = d[2]
			K.text_c(ci, lbl, "bold", 26, Vector2(fr.get_center().x, fr.position.y + 83.0), K.INK if on else K.INK_DIM, "deboss", fr.size.x - 10.0)
			if badge != "":
				K.stud(ci, Vector2(fr.end.x - 10.0, fr.position.y + 4.0), badge, 15.0))


## A row of toggle keys in a sunk navy channel. labels: Array[String]; active index.
static func tabs(parent: Node, r: Rect2, labels: Array, active: int) -> void:
	K.plate(parent, r, {"mat": "navy", "ch": 12.0, "trim": 3.0, "inset": 3.0, "shadow": 0.45, "spec": 0.2})
	var ws: Array[float] = []
	var total := 0.0
	for l: String in labels:
		var w := K.text_w(l, "bold", 26) + 40.0
		ws.append(w)
		total += w
	var inner := r.size.x - 20.0 - 6.0 * (labels.size() - 1)
	var x := r.position.x + 10.0
	for i in labels.size():
		var w := ws[i] / total * inner
		var on := i == active
		var kr := Rect2(x, r.position.y + 9.0, w, r.size.y - 18.0)
		var depth := 8.0
		K.plate(parent, kr, {"depth": depth, "press": 1.0 if on else 0.0, "ch": 8.0, "rad": 4.0, "trim": 0.0, "shadow": 0.5, "pad": 12.0, "bevel_w": 5.0})
		var fr := K.face_of(kr, depth, 1.0 if on else 0.0)
		var lbl: String = labels[i]
		K.canvas(parent, func(ci: CanvasItem) -> void:
			var lx := fr.get_center().x
			if on:
				K.draw_inlay(ci, Vector2(fr.position.x + 18.0, fr.get_center().y), Vector2(14, 22), [K.ICE_WHITE, K.ICE, K.ICE_DEEP], false)
				lx += 9.0
			K.text_c(ci, lbl, "bold", 26, Vector2(lx, fr.get_center().y + 1.0), K.INK if on else K.INK_DIM, "deboss", fr.size.x - (34.0 if on else 12.0)))
		x += w + 6.0


## A hanging nameplate (title plate): white enamel, gold trim, two rivets, debossed title
## and an optional caps kicker above it in ice-ink on a navy tab.
static func nameplate(parent: Node, pos: Vector2, title: String, kicker := "", o := {}) -> Rect2:
	var size := int(o.get("size", 46))
	var max_w := float(o.get("max_w", 560.0))
	var s := K.fit_size(title, "display", size, max_w - 56.0, 30)
	var tw := K.text_w(title, "display", s)
	var h := float(o.get("h", 84.0))
	var r := Rect2(pos.x, pos.y, maxf(tw + 64.0, float(o.get("min_w", 0.0))), h)
	if kicker != "":
		var kw := K.text_w(kicker, "caps", 26) + 40.0
		var kr := Rect2(pos.x + 18.0, pos.y - 36.0, kw, 46.0)
		K.plate(parent, kr, {"mat": "navy", "ch": 8.0, "rad": 4.0, "trim": 0.0, "shadow": 0.4, "pad": 12.0, "corners": "tl"})
		K.canvas(parent, func(ci: CanvasItem) -> void:
			K.text_l(ci, kicker, "caps", 26, Vector2(kr.position.x + 20.0, kr.position.y + 19.0), K.ICE, "plain"))
	K.plate(parent, r, {"ch": 16.0, "trim": 4.0, "rivet": 4.0, "shadow": 0.55})
	K.canvas(parent, func(ci: CanvasItem) -> void:
		K.text_c(ci, title, "display", s, r.get_center() + Vector2(0, 1), K.INK, "deboss"))
	return r
