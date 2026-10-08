class_name HeroIcons
extends Control
## Icons the Heroes UI adds on top of Icons / KitIcons (kept here so the kit files stay
## untouched). PAINTED (AFK style, like KitIcons.painted: soft gradient fills lit from the upper
## left, thin same-hue edge, one highlight, no black outline): `seal` (Печатка: a gold signet
## medallion with a portal-arch emboss) and `ore` (Зоряна руда: a slate-violet ore lump with
## pale-gold crystal shards). LINE (one colour, Genshin monoline): the four skill glyphs
## `sk_ult` `sk_attack` `sk_rally` `sk_awaken` and `sk_relic`.
## Every other kind is passed through to Icons.draw_icon (coin, beacon, tome, fragment, cls_*,
## el_*, fac_*, lock, ...). Bitmap override: res://assets/ui/kit/icon_<kind>.png wins.
##
##   HeroIcons.paint(self, "seal", Rect2(0, 0, 48, 48))          # in _draw()
##   add_child(HeroIcons.make("sk_ult", 40, UIKit.GOLD_TEXT))  # as a Control

const PAINTED: Array[String] = ["seal", "ore"]
const LINE: Array[String] = ["sk_ult", "sk_attack", "sk_rally", "sk_awaken", "sk_relic"]
## Skill id (HeroesUIModel skills keys) -> line icon.
const SKILL_ICON := {"ult": "sk_ult", "attack": "sk_attack", "rally": "sk_rally", "awakened": "sk_awaken", "relic": "sk_relic"}
## Currency id -> icon kind.
const CURRENCY_ICON := {"beacons": "beacon", "seals": "seal", "tomes": "tome", "ore": "ore", "coins": "coin", "frags": "fragment"}

var kind := "seal":
	set(v):
		kind = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


static func make(p_kind: String, px := 40.0, p_tint := Color.WHITE) -> HeroIcons:
	var i := HeroIcons.new()
	i.kind = p_kind
	i.tint = p_tint
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s := minf(size.x, size.y)
	paint(self, kind, Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s)), tint)


static func has(k: String) -> bool:
	return k in PAINTED or k in LINE


## Draws icon `k` in `r`. Line icons use `tint` (white -> ink); painted ones use its alpha only.
static func paint(ci: CanvasItem, k: String, r: Rect2, tint := Color.WHITE) -> void:
	var ov := UIKit.kit_texture("icon_" + k)
	if ov:
		ci.draw_texture_rect(ov, r, false, tint if k in LINE else Color(1, 1, 1, tint.a))
		return
	if k in PAINTED:
		_painted(ci, k, r, tint.a)
		return
	if k in LINE:
		var col := tint
		if tint.r > 0.97 and tint.g > 0.97 and tint.b > 0.97:
			col = Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, tint.a)
		line(ci, k, r, col)
		return
	Icons.draw_icon(ci, k, r, tint)


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size


static func _pp(r: Rect2, xy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i + 1 < xy.size():
		out.append(_p(r, xy[i], xy[i + 1]))
		i += 2
	return out


static func _grad(ci: CanvasItem, pts: PackedVector2Array, top: Color, bot: Color, r: Rect2, a: float) -> void:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		var c := top.lerp(bot, t)
		c.a *= a
		cols.append(c)
	ci.draw_polygon(pts, cols)


static func _ring_pts(c: Vector2, rad: float, n: int, bumps := 0, amp := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		var rr := rad * (1.0 + (amp * cos(t * bumps) if bumps > 0 else 0.0))
		pts.append(c + Vector2(cos(t), sin(t)) * rr)
	return pts


static func _painted(ci: CanvasItem, k: String, r: Rect2, a: float) -> void:
	var s := r.size.x
	var c := r.get_center()
	match k:
		"seal":
			# Scalloped gold signet with an indigo enamel field and an embossed portal arch.
			var drop := _ring_pts(c + Vector2(s * 0.02, s * 0.045), s * 0.44, 64, 14, 0.045)
			ci.draw_colored_polygon(drop, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.22 * a))
			var rim := _ring_pts(c, s * 0.44, 64, 14, 0.045)
			_grad(ci, rim, Color("#FFE7A0"), Color("#C98A2E"), r, a)
			GemDraw.outline(ci, rim, Color(0.6, 0.38, 0.1, 0.85 * a), maxf(1.0, s * 0.025))
			var field := _ring_pts(c, s * 0.31, 40)
			_grad(ci, field, Color("#6B6BC2"), Color("#2F2B6B"), r, a)
			GemDraw.outline(ci, field, Color(1.0, 0.86, 0.55, 0.9 * a), maxf(1.0, s * 0.03))
			# Portal arch (emboss: shadow line under a gold line).
			var lw := maxf(1.2, s * 0.05)
			var base_y := c.y + s * 0.16
			for pass_i in 2:
				var o := Vector2(0, s * 0.02) if pass_i == 0 else Vector2.ZERO
				var col := Color(0.1, 0.08, 0.25, 0.5 * a) if pass_i == 0 else Color(1.0, 0.89, 0.6, a)
				ci.draw_arc(c + Vector2(0, s * 0.02) + o, s * 0.14, PI, TAU, 18, col, lw, true)
				ci.draw_line(Vector2(c.x - s * 0.14, c.y + s * 0.02) + o, Vector2(c.x - s * 0.14, base_y) + o, col, lw, true)
				ci.draw_line(Vector2(c.x + s * 0.14, c.y + s * 0.02) + o, Vector2(c.x + s * 0.14, base_y) + o, col, lw, true)
			GemDraw.draw_keystone(ci, c + Vector2(0, -s * 0.13), s * 0.13, a, Color(0.85, 0.9, 1.0))
			ci.draw_arc(c, s * 0.4, PI * 1.08, PI * 1.6, 16, Color(1, 1, 1, 0.6 * a), maxf(1.0, s * 0.028), true)
		"ore":
			# A slate-violet ore lump with three pale-gold crystal shards.
			var lump := _pp(r, [0.14, 0.62, 0.22, 0.4, 0.42, 0.3, 0.66, 0.34, 0.86, 0.5, 0.84, 0.74, 0.6, 0.86, 0.3, 0.84])
			var sh := PackedVector2Array()
			for p in lump:
				sh.append(p + Vector2(s * 0.02, s * 0.045))
			ci.draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.22 * a))
			_grad(ci, lump, Color("#A39CC0"), Color("#4E4868"), r, a)
			# Lit plane (upper left) and shade plane (lower right).
			ci.draw_colored_polygon(_pp(r, [0.22, 0.4, 0.42, 0.3, 0.5, 0.5, 0.2, 0.6]), Color(1, 1, 1, 0.16 * a))
			ci.draw_colored_polygon(_pp(r, [0.5, 0.5, 0.86, 0.5, 0.84, 0.74, 0.6, 0.86]), Color(0.12, 0.08, 0.22, 0.22 * a))
			GemDraw.outline(ci, lump, Color(0.24, 0.2, 0.36, 0.85 * a), maxf(1.0, s * 0.025))
			var gold := Color("#FFE08A")
			GemDraw.draw_gem(ci, "diamond", _p(r, 0.5, 0.32), s * 0.36, gold, Color("#FFF8DC"), Color("#C98A2E"), false, a)
			GemDraw.draw_gem(ci, "diamond", _p(r, 0.32, 0.46), s * 0.22, gold, Color("#FFF8DC"), Color("#C98A2E"), false, a)
			GemDraw.draw_gem(ci, "diamond", _p(r, 0.7, 0.52), s * 0.2, gold, Color("#FFF8DC"), Color("#C98A2E"), false, a)
			if s >= 28.0:
				GemDraw.draw_glint(ci, _p(r, 0.44, 0.22), s * 0.34, Color(1, 1, 1, 0.9 * a))


## One-colour skill glyphs (stroke ~7.5 % of the size, round caps).
static func line(ci: CanvasItem, k: String, r: Rect2, col: Color, width := -1.0) -> void:
	var s := r.size.x
	var w := width if width > 0.0 else clampf(s * 0.075, 1.6, 3.6)
	var c := r.get_center()
	match k:
		"sk_ult":
			# A burst: a ring and eight rays (long / short), the ult's flare.
			ci.draw_arc(c, s * 0.15, 0, TAU, 32, col, w, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0 - PI / 2.0)
				var L := 0.42 if i % 2 == 0 else 0.32
				_seg(ci, c + d * s * 0.24, c + d * s * L, col, w)
		"sk_attack":
			# A glaive blade on the diagonal with a crossguard.
			var a := _p(r, 0.22, 0.8)
			var b := _p(r, 0.72, 0.3)
			_seg(ci, a, b, col, w)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var tip := b + d * s * 0.14
			var blade := PackedVector2Array([b + n * s * 0.07, tip, b - n * s * 0.07, b - d * s * 0.1])
			GemDraw.outline(ci, blade, col, w * 0.8)
			var g0 := a.lerp(b, 0.45)
			_seg(ci, g0 + n * s * 0.12, g0 - n * s * 0.12, col, w)
			ci.draw_circle(a, w * 0.9, col, true, -1.0, true)
		"sk_rally":
			# A banner on a pole with a swallowtail.
			_seg(ci, _p(r, 0.3, 0.16), _p(r, 0.3, 0.86), col, w)
			var flag := _pp(r, [0.3, 0.2, 0.8, 0.24, 0.68, 0.36, 0.8, 0.48, 0.3, 0.46])
			GemDraw.outline(ci, flag, col, w * 0.85)
			GemDraw.draw_marquise(ci, _p(r, 0.3, 0.14), Vector2.UP, s * 0.12, col)
		"sk_awaken":
			# An opening eye with a cut-gem pupil (the fourth skill).
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-0.4, 0.4, t), -sin(t * PI) * 0.22) * s)
			for i in range(1, 12):
				var t := 1.0 - float(i) / 12.0
				pts.append(c + Vector2(lerpf(-0.4, 0.4, t), sin(t * PI) * 0.22) * s)
			GemDraw.outline(ci, pts, col, w)
			var rh := PackedVector2Array([c + Vector2(0, -0.12) * s, c + Vector2(0.09, 0) * s, c + Vector2(0, 0.12) * s, c + Vector2(-0.09, 0) * s])
			ci.draw_colored_polygon(rh, col)
			for i in 3:
				var d := Vector2.from_angle(-PI / 2.0 + (i - 1) * 0.55)
				_seg(ci, c + d * s * 0.3, c + d * s * 0.42, col, w * 0.85)
		"sk_relic":
			# A pendant: a rhombus stone on a loop.
			ci.draw_arc(_p(r, 0.5, 0.24), s * 0.09, 0, TAU, 20, col, w, true)
			var gem := _pp(r, [0.5, 0.36, 0.72, 0.58, 0.5, 0.86, 0.28, 0.58])
			GemDraw.outline(ci, gem, col, w)
			_seg(ci, _p(r, 0.28, 0.58), _p(r, 0.72, 0.58), col, w * 0.7)


static func _seg(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)
	if w >= 2.4:
		ci.draw_circle(a, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(b, w * 0.5, col, true, -1.0, true)
