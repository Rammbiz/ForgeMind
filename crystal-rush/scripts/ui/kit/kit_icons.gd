class_name KitIcons
## UI v2 icon sets, drawn in code until the owner's painted bitmaps land (Icons.draw_icon checks
## res://assets/ui/kit/icon_<kind>.png first).
## LINE icons (Genshin monoline, 2-3 px strokes, rounded caps/joins) for menus, edge buttons,
## classes (cls_*), elements (el_*), factions (fac_*): drawn in ONE colour (ink on cream,
## gold_hi on slate, warm white on scenes).
## PAINTED icons (AFK: soft gradient fills lit from the upper left, a thin same-hue edge, a
## small highlight; no black outlines) for currencies and the five bottom-bar tabs.

const LINE := [
	"settings", "gear", "back", "close", "info", "lock", "unlock", "check", "plus", "minus", "home", "pause", "play",
	"restart", "sound", "music", "vibrate", "globe", "odds", "percent", "events", "mail", "quests", "book", "chest",
	"portal", "team", "gift", "calendar", "filter", "sort", "search", "chevron", "chevron_down", "arrow_up", "swap",
	"auto", "deck", "helmet", "target", "fast", "up", "edit", "help", "trophy", "map",
	"cls_warrior", "cls_ranger", "cls_mage", "cls_guardian", "cls_healer",
	"el_kinetic", "el_volt", "el_frost", "el_plasma", "el_tech", "el_rune", "el_rift",
	"fac_dawn", "fac_wildfang", "fac_stoneheart", "fac_celestial",
]
const PAINTED := ["coin", "gem", "crown", "blueprint", "beacon", "tome", "fragment",
		"tab_shop", "tab_arsenal", "tab_play", "tab_heroes", "tab_barracks"]
## Legacy kinds that are UI glyphs (sticker style before) and now draw as line icons.
const LINE_ALIASES := {"gear": "settings", "percent": "odds", "up": "arrow_up", "book": "quests"}


static func has_line(k: String) -> bool:
	return k in LINE


static func has_painted(k: String) -> bool:
	return k in PAINTED


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func _pts(r: Rect2, xy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i + 1 < xy.size():
		out.append(_p(r, xy[i], xy[i + 1]))
		i += 2
	return out


## Polyline with round caps and joins.
static func _ln(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, closed := false) -> void:
	var p := pts
	if closed:
		p = pts.duplicate()
		p.append(pts[0])
	ci.draw_polyline(p, col, w, true)
	for q in pts:
		ci.draw_circle(q, w * 0.5, col, true, -1.0, true)


static func _arc(ci: CanvasItem, c: Vector2, rad: float, a0: float, a1: float, col: Color, w: float, caps := true) -> void:
	ci.draw_arc(c, rad, a0, a1, maxi(8, int(absf(a1 - a0) * 10.0)), col, w, true)
	if caps:
		ci.draw_circle(c + Vector2(cos(a0), sin(a0)) * rad, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(c + Vector2(cos(a1), sin(a1)) * rad, w * 0.5, col, true, -1.0, true)


static func _dot(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(c, rad, col, true, -1.0, true)


## Draws line icon `k` in `r` with colour `col`. Returns false for an unknown kind.
static func line(ci: CanvasItem, k: String, r: Rect2, col: Color, width := -1.0) -> bool:
	k = LINE_ALIASES.get(k, k)
	var s := r.size.x
	var w := width if width > 0.0 else clampf(s * 0.075, 1.6, 3.2)
	var c := r.get_center()
	match k:
		"settings":
			var pts := PackedVector2Array()
			var n := 8
			for i in n * 4:
				var a := TAU * float(i) / (n * 4) - PI / 2.0
				var on := (i % 4) in [0, 1]
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.4 if on else 0.31))
			_ln(ci, pts, col, w, true)
			_arc(ci, c, s * 0.13, 0, TAU, col, w, false)
		"back":
			_ln(ci, _pts(r, [0.78, 0.5, 0.24, 0.5]), col, w)
			_ln(ci, _pts(r, [0.46, 0.28, 0.24, 0.5, 0.46, 0.72]), col, w)
		"close":
			_ln(ci, _pts(r, [0.28, 0.28, 0.72, 0.72]), col, w)
			_ln(ci, _pts(r, [0.72, 0.28, 0.28, 0.72]), col, w)
		"info", "help":
			_arc(ci, c, s * 0.4, 0, TAU, col, w, false)
			if k == "info":
				_dot(ci, _p(r, 0.5, 0.31), w * 0.85, col)
				_ln(ci, _pts(r, [0.5, 0.45, 0.5, 0.71]), col, w)
			else:
				_arc(ci, _p(r, 0.5, 0.4), s * 0.11, PI * 1.05, PI * 2.35, col, w)
				_ln(ci, _pts(r, [0.53, 0.5, 0.5, 0.58]), col, w)
				_dot(ci, _p(r, 0.5, 0.72), w * 0.75, col)
		"lock", "unlock":
			_ln(ci, _chamfer(r, 0.24, 0.46, 0.76, 0.84, 0.05), col, w, true)
			var sc := _p(r, 0.5, 0.46)
			if k == "lock":
				_arc(ci, sc, s * 0.16, PI, TAU, col, w, false)
				_ln(ci, PackedVector2Array([sc + Vector2(-s * 0.16, 0), sc + Vector2(-s * 0.16, -s * 0.02)]), col, w)
				_ln(ci, PackedVector2Array([sc + Vector2(s * 0.16, 0), sc + Vector2(s * 0.16, -s * 0.02)]), col, w)
			else:
				_arc(ci, sc + Vector2(s * 0.2, -s * 0.06), s * 0.16, PI, TAU * 0.98, col, w)
				_ln(ci, PackedVector2Array([sc + Vector2(s * 0.04, 0), sc + Vector2(s * 0.04, -s * 0.06)]), col, w)
			_dot(ci, _p(r, 0.5, 0.62), w * 0.8, col)
			_ln(ci, _pts(r, [0.5, 0.63, 0.5, 0.72]), col, w * 0.8)
		"check":
			_ln(ci, _pts(r, [0.22, 0.53, 0.42, 0.72, 0.8, 0.3]), col, w * 1.15)
		"plus":
			_ln(ci, _pts(r, [0.24, 0.5, 0.76, 0.5]), col, w)
			_ln(ci, _pts(r, [0.5, 0.24, 0.5, 0.76]), col, w)
		"minus":
			_ln(ci, _pts(r, [0.24, 0.5, 0.76, 0.5]), col, w)
		"home":
			_ln(ci, _pts(r, [0.16, 0.5, 0.5, 0.2, 0.84, 0.5]), col, w)
			_ln(ci, _pts(r, [0.27, 0.42, 0.27, 0.8, 0.73, 0.8, 0.73, 0.42]), col, w)
			_ln(ci, _pts(r, [0.43, 0.8, 0.43, 0.6, 0.57, 0.6, 0.57, 0.8]), col, w)
		"pause":
			_ln(ci, _pts(r, [0.38, 0.27, 0.38, 0.73]), col, w * 1.2)
			_ln(ci, _pts(r, [0.62, 0.27, 0.62, 0.73]), col, w * 1.2)
		"play":
			_ln(ci, _pts(r, [0.36, 0.25, 0.75, 0.5, 0.36, 0.75]), col, w, true)
		"fast":
			_ln(ci, _pts(r, [0.2, 0.28, 0.48, 0.5, 0.2, 0.72]), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.28, 0.78, 0.5, 0.5, 0.72]), col, w, true)
		"restart":
			_arc(ci, c, s * 0.3, -PI * 0.35, PI * 1.45, col, w)
			var e := c + Vector2(cos(-PI * 0.35), sin(-PI * 0.35)) * s * 0.3
			_ln(ci, PackedVector2Array([e + Vector2(-s * 0.15, -s * 0.03), e, e + Vector2(-s * 0.02, s * 0.15)]), col, w)
		"sound":
			_ln(ci, _pts(r, [0.16, 0.4, 0.3, 0.4, 0.48, 0.25, 0.48, 0.75, 0.3, 0.6, 0.16, 0.6]), col, w, true)
			_arc(ci, _p(r, 0.5, 0.5), s * 0.14, -PI * 0.3, PI * 0.3, col, w)
			_arc(ci, _p(r, 0.5, 0.5), s * 0.27, -PI * 0.3, PI * 0.3, col, w)
		"music":
			_arc(ci, _p(r, 0.36, 0.72), s * 0.1, 0, TAU, col, w, false)
			_arc(ci, _p(r, 0.7, 0.64), s * 0.1, 0, TAU, col, w, false)
			_ln(ci, _pts(r, [0.46, 0.72, 0.46, 0.24, 0.8, 0.18, 0.8, 0.64]), col, w)
		"vibrate":
			_ln(ci, _chamfer(r, 0.36, 0.2, 0.64, 0.8, 0.05), col, w, true)
			_ln(ci, _pts(r, [0.22, 0.34, 0.16, 0.42, 0.22, 0.5, 0.16, 0.58, 0.22, 0.66]), col, w * 0.8)
			_ln(ci, _pts(r, [0.78, 0.34, 0.84, 0.42, 0.78, 0.5, 0.84, 0.58, 0.78, 0.66]), col, w * 0.8)
		"globe":
			_arc(ci, c, s * 0.38, 0, TAU, col, w, false)
			var mer := PackedVector2Array()
			for i in 25:
				var a := -PI / 2.0 + PI * i / 24.0
				mer.append(c + Vector2(cos(a) * s * 0.16, sin(a) * s * 0.38))
			_ln(ci, mer, col, w * 0.8)
			var mer2 := PackedVector2Array()
			for p in mer:
				mer2.append(Vector2(2.0 * c.x - p.x, p.y))
			_ln(ci, mer2, col, w * 0.8)
			_ln(ci, _pts(r, [0.12, 0.5, 0.88, 0.5]), col, w * 0.8)
		"odds":
			_arc(ci, _p(r, 0.32, 0.32), s * 0.1, 0, TAU, col, w, false)
			_arc(ci, _p(r, 0.68, 0.68), s * 0.1, 0, TAU, col, w, false)
			_ln(ci, _pts(r, [0.74, 0.24, 0.26, 0.76]), col, w)
		"events":
			_ln(ci, _pts(r, [0.28, 0.16, 0.28, 0.86]), col, w)
			_ln(ci, _pts(r, [0.28, 0.2, 0.8, 0.2, 0.66, 0.34, 0.8, 0.48, 0.28, 0.48]), col, w)
		"mail":
			_ln(ci, _chamfer(r, 0.14, 0.26, 0.86, 0.76, 0.04), col, w, true)
			_ln(ci, _pts(r, [0.16, 0.3, 0.5, 0.55, 0.84, 0.3]), col, w)
		"quests":
			_ln(ci, _pts(r, [0.5, 0.3, 0.32, 0.22, 0.13, 0.26, 0.13, 0.78, 0.32, 0.73, 0.5, 0.8, 0.68, 0.73, 0.87, 0.78, 0.87, 0.26, 0.68, 0.22]), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.3, 0.5, 0.8]), col, w)
		"chest":
			_ln(ci, _chamfer(r, 0.16, 0.46, 0.84, 0.82, 0.03), col, w, true)
			_ln(ci, _pts(r, [0.16, 0.46, 0.16, 0.36]), col, w)
			_ln(ci, _pts(r, [0.84, 0.46, 0.84, 0.36]), col, w)
			_arc(ci, _p(r, 0.5, 0.42), s * 0.34, PI * 1.12, PI * 1.88, col, w, false)
			_ln(ci, _chamfer(r, 0.43, 0.42, 0.57, 0.58, 0.02), col, w * 0.85, true)
		"portal":
			_arc(ci, c, s * 0.38, 0, TAU, col, w, false)
			_arc(ci, c, s * 0.22, -PI * 0.2, PI * 1.4, col, w * 0.8)
			_dot(ci, c, w * 0.9, col)
		"team":
			_arc(ci, _p(r, 0.38, 0.36), s * 0.12, 0, TAU, col, w, false)
			_arc(ci, _p(r, 0.38, 0.86), s * 0.24, PI * 1.12, PI * 1.88, col, w)
			_arc(ci, _p(r, 0.66, 0.32), s * 0.1, -PI * 0.65, PI * 0.95, col, w * 0.85)
			_arc(ci, _p(r, 0.7, 0.78), s * 0.2, PI * 1.35, PI * 1.9, col, w * 0.85)
		"gift":
			_ln(ci, _chamfer(r, 0.2, 0.44, 0.8, 0.82, 0.03), col, w, true)
			_ln(ci, _pts(r, [0.14, 0.34, 0.86, 0.34, 0.86, 0.44, 0.14, 0.44]), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.34, 0.5, 0.82]), col, w)
			_arc(ci, _p(r, 0.4, 0.26), s * 0.09, PI * 0.2, PI * 1.9, col, w * 0.8)
			_arc(ci, _p(r, 0.6, 0.26), s * 0.09, -PI * 0.9, PI * 0.8, col, w * 0.8)
		"calendar":
			_ln(ci, _chamfer(r, 0.16, 0.24, 0.84, 0.82, 0.04), col, w, true)
			_ln(ci, _pts(r, [0.16, 0.4, 0.84, 0.4]), col, w)
			_ln(ci, _pts(r, [0.34, 0.16, 0.34, 0.3]), col, w)
			_ln(ci, _pts(r, [0.66, 0.16, 0.66, 0.3]), col, w)
			_dot(ci, _p(r, 0.36, 0.58), w * 0.8, col)
			_dot(ci, _p(r, 0.5, 0.58), w * 0.8, col)
			_dot(ci, _p(r, 0.64, 0.58), w * 0.8, col)
		"filter":
			_ln(ci, _pts(r, [0.16, 0.24, 0.84, 0.24, 0.56, 0.54, 0.56, 0.8, 0.44, 0.72, 0.44, 0.54]), col, w, true)
		"sort":
			_ln(ci, _pts(r, [0.18, 0.3, 0.82, 0.3]), col, w)
			_ln(ci, _pts(r, [0.18, 0.5, 0.64, 0.5]), col, w)
			_ln(ci, _pts(r, [0.18, 0.7, 0.46, 0.7]), col, w)
		"search":
			_arc(ci, _p(r, 0.44, 0.44), s * 0.24, 0, TAU, col, w, false)
			_ln(ci, _pts(r, [0.62, 0.62, 0.82, 0.82]), col, w * 1.1)
		"chevron":
			_ln(ci, _pts(r, [0.4, 0.24, 0.66, 0.5, 0.4, 0.76]), col, w)
		"chevron_down":
			_ln(ci, _pts(r, [0.24, 0.4, 0.5, 0.66, 0.76, 0.4]), col, w)
		"arrow_up":
			_ln(ci, _pts(r, [0.5, 0.8, 0.5, 0.22]), col, w)
			_ln(ci, _pts(r, [0.28, 0.44, 0.5, 0.22, 0.72, 0.44]), col, w)
		"swap":
			_ln(ci, _pts(r, [0.2, 0.36, 0.78, 0.36]), col, w)
			_ln(ci, _pts(r, [0.62, 0.22, 0.78, 0.36, 0.62, 0.5]), col, w)
			_ln(ci, _pts(r, [0.8, 0.64, 0.22, 0.64]), col, w)
			_ln(ci, _pts(r, [0.38, 0.5, 0.22, 0.64, 0.38, 0.78]), col, w)
		"auto":
			_arc(ci, c, s * 0.32, -PI * 0.15, PI * 0.85, col, w)
			_arc(ci, c, s * 0.32, PI * 0.85 + 0.35, PI * 1.85, col, w)
			var e1 := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * s * 0.32
			_ln(ci, PackedVector2Array([e1 + Vector2(-s * 0.12, -s * 0.05), e1, e1 + Vector2(s * 0.02, s * 0.13)]), col, w)
			_ln(ci, _pts(r, [0.5, 0.4, 0.58, 0.5, 0.5, 0.6, 0.42, 0.5]), col, w * 0.8, true)
		"deck":
			_ln(ci, _chamfer(r, 0.3, 0.3, 0.7, 0.84, 0.04), col, w, true)
			_ln(ci, _pts(r, [0.24, 0.74, 0.18, 0.72, 0.24, 0.24, 0.6, 0.2]), col, w * 0.85)
			_ln(ci, _pts(r, [0.42, 0.52, 0.5, 0.42, 0.58, 0.52, 0.5, 0.62]), col, w * 0.8, true)
		"helmet":
			_ln(ci, _pts(r, [0.22, 0.78, 0.22, 0.46, 0.3, 0.28, 0.5, 0.18, 0.7, 0.28, 0.78, 0.46, 0.78, 0.78, 0.58, 0.78, 0.58, 0.5, 0.42, 0.5, 0.42, 0.78]), col, w, true)
		"target":
			_arc(ci, c, s * 0.3, 0, TAU, col, w, false)
			_dot(ci, c, w, col)
			_ln(ci, _pts(r, [0.5, 0.1, 0.5, 0.26]), col, w)
			_ln(ci, _pts(r, [0.5, 0.74, 0.5, 0.9]), col, w)
			_ln(ci, _pts(r, [0.1, 0.5, 0.26, 0.5]), col, w)
			_ln(ci, _pts(r, [0.74, 0.5, 0.9, 0.5]), col, w)
		"edit":
			_ln(ci, _pts(r, [0.24, 0.76, 0.28, 0.6, 0.66, 0.22, 0.78, 0.34, 0.4, 0.72]), col, w, true)
		"trophy":
			_ln(ci, _pts(r, [0.3, 0.2, 0.7, 0.2, 0.68, 0.44, 0.5, 0.56, 0.32, 0.44]), col, w, true)
			_arc(ci, _p(r, 0.3, 0.3), s * 0.1, PI * 0.5, PI * 1.5, col, w * 0.8)
			_arc(ci, _p(r, 0.7, 0.3), s * 0.1, -PI * 0.5, PI * 0.5, col, w * 0.8)
			_ln(ci, _pts(r, [0.5, 0.56, 0.5, 0.7]), col, w)
			_ln(ci, _pts(r, [0.34, 0.8, 0.66, 0.8]), col, w)
		"map":
			_ln(ci, _pts(r, [0.14, 0.26, 0.38, 0.18, 0.62, 0.26, 0.86, 0.18, 0.86, 0.74, 0.62, 0.82, 0.38, 0.74, 0.14, 0.82]), col, w, true)
			_ln(ci, _pts(r, [0.38, 0.18, 0.38, 0.74]), col, w * 0.8)
			_ln(ci, _pts(r, [0.62, 0.26, 0.62, 0.82]), col, w * 0.8)
		# ---- classes
		"cls_warrior":
			_ln(ci, _pts(r, [0.22, 0.78, 0.74, 0.26, 0.8, 0.2]), col, w)
			_ln(ci, _pts(r, [0.78, 0.78, 0.26, 0.26, 0.2, 0.2]), col, w)
			_ln(ci, _pts(r, [0.24, 0.62, 0.38, 0.76]), col, w)
			_ln(ci, _pts(r, [0.76, 0.62, 0.62, 0.76]), col, w)
		"cls_ranger":
			_arc(ci, _p(r, 0.26, 0.5), s * 0.42, -PI * 0.36, PI * 0.36, col, w)
			var t0 := _p(r, 0.26, 0.5) + Vector2(cos(-PI * 0.36), sin(-PI * 0.36)) * s * 0.42
			var t1 := _p(r, 0.26, 0.5) + Vector2(cos(PI * 0.36), sin(PI * 0.36)) * s * 0.42
			_ln(ci, PackedVector2Array([t0, _p(r, 0.42, 0.5), t1]), col, w * 0.7)
			_ln(ci, _pts(r, [0.42, 0.5, 0.86, 0.5]), col, w)
			_ln(ci, _pts(r, [0.74, 0.4, 0.86, 0.5, 0.74, 0.6]), col, w)
		"cls_mage":
			_arc(ci, c, s * 0.38, -PI * 0.4, PI * 1.4, col, w * 0.8)
			_arc(ci, c, s * 0.15, 0, TAU, col, w, false)
			_dot(ci, c + Vector2(-s * 0.05, -s * 0.05), w * 0.6, col)
			_ln(ci, _pts(r, [0.5, 0.06, 0.5, 0.18]), col, w * 0.8)
		"cls_guardian":
			_ln(ci, _pts(r, [0.26, 0.18, 0.74, 0.18, 0.74, 0.58, 0.5, 0.84, 0.26, 0.58]), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.26, 0.5, 0.72]), col, w * 0.8)
			_ln(ci, _pts(r, [0.34, 0.42, 0.66, 0.42]), col, w * 0.8)
		"cls_healer":
			_arc(ci, _p(r, 0.5, 0.14), s * 0.06, 0, TAU, col, w * 0.8, false)
			_ln(ci, _pts(r, [0.36, 0.3, 0.64, 0.3, 0.7, 0.36, 0.3, 0.36]), col, w, true)
			_ln(ci, _chamfer(r, 0.32, 0.36, 0.68, 0.8, 0.06), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.48, 0.58, 0.6, 0.5, 0.7, 0.42, 0.6]), col, w * 0.8, true)
		# ---- elements (= machine families)
		"el_kinetic":
			_ln(ci, _pts(r, [0.22, 0.52, 0.5, 0.3, 0.78, 0.52]), col, w * 1.1)
			_ln(ci, _pts(r, [0.22, 0.74, 0.5, 0.52, 0.78, 0.74]), col, w * 1.1)
		"el_volt":
			_ln(ci, _pts(r, [0.58, 0.12, 0.26, 0.56, 0.48, 0.56, 0.4, 0.88, 0.74, 0.42, 0.52, 0.42]), col, w, true)
		"el_frost":
			for i in 3:
				var a := PI / 2.0 + PI * i / 3.0
				var d := Vector2(cos(a), sin(a)) * s * 0.38
				_ln(ci, PackedVector2Array([c - d, c + d]), col, w)
				for sg: float in [-1.0, 1.0]:
					var m := c + d * 0.58 * sg
					var b1 := d.normalized().rotated(0.7) * s * 0.11 * sg
					var b2 := d.normalized().rotated(-0.7) * s * 0.11 * sg
					_ln(ci, PackedVector2Array([m - b1, m, m - b2]), col, w * 0.8)
		"el_plasma":
			var fl := PackedVector2Array()
			for i in 21:
				var t := float(i) / 20.0
				var a := lerpf(-PI * 0.15, PI * 1.15, t)
				fl.append(_p(r, 0.5, 0.6) + Vector2(cos(a), sin(a)) * s * 0.26)
			fl.append(_p(r, 0.4, 0.3))
			fl.append(_p(r, 0.5, 0.12))
			fl.append(_p(r, 0.66, 0.36))
			_ln(ci, fl, col, w, true)
			_arc(ci, _p(r, 0.5, 0.64), s * 0.1, PI * 0.9, PI * 2.1, col, w * 0.8)
		"el_tech":
			var g := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var on := (i % 4) in [0, 1]
				g.append(c + Vector2(cos(a), sin(a)) * s * (0.36 if on else 0.28))
			_ln(ci, g, col, w * 0.9, true)
			_ln(ci, _pts(r, [0.4, 0.5, 0.6, 0.5]), col, w * 0.9)
			_ln(ci, _pts(r, [0.5, 0.4, 0.5, 0.6]), col, w * 0.9)
		"el_rune":
			_ln(ci, _pts(r, [0.5, 0.12, 0.8, 0.5, 0.5, 0.88, 0.2, 0.5]), col, w, true)
			_ln(ci, _pts(r, [0.5, 0.28, 0.5, 0.72]), col, w * 0.85)
			_ln(ci, _pts(r, [0.38, 0.4, 0.5, 0.5, 0.62, 0.4]), col, w * 0.85)
		"el_rift":
			_arc(ci, _p(r, 0.44, 0.5), s * 0.32, PI * 0.35, PI * 1.65, col, w)
			_arc(ci, _p(r, 0.6, 0.5), s * 0.22, PI * 0.45, PI * 1.55, col, w * 0.85)
			_dot(ci, _p(r, 0.74, 0.32), w * 0.7, col)
			_dot(ci, _p(r, 0.8, 0.56), w * 0.55, col)
		# ---- factions
		"fac_dawn":
			_ln(ci, _pts(r, [0.12, 0.68, 0.88, 0.68]), col, w)
			_arc(ci, _p(r, 0.5, 0.68), s * 0.2, PI, TAU, col, w, false)
			for i in 5:
				var a := PI + PI * (i + 1) / 6.0
				var d := Vector2(cos(a), sin(a))
				_ln(ci, PackedVector2Array([_p(r, 0.5, 0.68) + d * s * 0.28, _p(r, 0.5, 0.68) + d * s * 0.4]), col, w * 0.85)
			_ln(ci, _pts(r, [0.3, 0.8, 0.7, 0.8]), col, w * 0.8)
		"fac_wildfang":
			for i in 3:
				var x0 := 0.3 + i * 0.17
				_arc(ci, _p(r, x0 - 0.3, 0.5), s * 0.34, -PI * 0.28, PI * 0.28, col, w)
		"fac_stoneheart":
			_ln(ci, _pts(r, [0.5, 0.84, 0.16, 0.46, 0.22, 0.26, 0.38, 0.2, 0.5, 0.32, 0.62, 0.2, 0.78, 0.26, 0.84, 0.46]), col, w, true)
			_ln(ci, _pts(r, [0.22, 0.26, 0.38, 0.46, 0.5, 0.32, 0.62, 0.46, 0.78, 0.26]), col, w * 0.7)
			_ln(ci, _pts(r, [0.38, 0.46, 0.5, 0.84, 0.62, 0.46]), col, w * 0.7)
		"fac_celestial":
			_arc(ci, _p(r, 0.46, 0.52), s * 0.32, PI * 0.25, PI * 1.75, col, w)
			_arc(ci, _p(r, 0.62, 0.44), s * 0.24, PI * 0.42, PI * 1.58, col, w * 0.8)
			_ln(ci, _pts(r, [0.74, 0.62, 0.79, 0.7, 0.74, 0.78, 0.69, 0.7]), col, w * 0.7, true)
		_:
			return false
	return true


static func _chamfer(r: Rect2, x0: float, y0: float, x1: float, y1: float, ch: float) -> PackedVector2Array:
	return GemDraw.chamfer_rect(Rect2(_p(r, x0, y0), Vector2((x1 - x0) * r.size.x, (y1 - y0) * r.size.y)), ch * r.size.x)


# ------------------------------------------------------------------ painted

## Polygon with a vertical gradient (top -> bottom) across `r`.
static func _gp(ci: CanvasItem, pts: PackedVector2Array, top: Color, bot: Color, r: Rect2, a := 1.0) -> void:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		var cc := top.lerp(bot, t)
		cc.a *= a
		cols.append(cc)
	ci.draw_polygon(pts, cols)


static func _edge(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.2) -> void:
	GemDraw.outline(ci, pts, col, w)


static func _circle_pts(c: Vector2, rad: float, n := 28, sy := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a) * sy) * rad)
	return pts


## Draws painted icon `k` in `r`. `mod` multiplies the colours (dim / alpha). Returns false
## for an unknown kind.
static func painted(ci: CanvasItem, k: String, r: Rect2, mod := Color.WHITE) -> bool:
	var s := r.size.x
	var c := r.get_center()
	var a := mod.a
	var shade := Color(mod.r, mod.g, mod.b, 1.0)
	match k:
		"coin":
			ci.draw_circle(c + Vector2(0, s * 0.04), s * 0.44, Color(0.45, 0.26, 0.06, 0.25 * a), true, -1.0, true)
			var disc := _circle_pts(c, s * 0.44, 36)
			_gp(ci, disc, Color("#FFE7A0") * shade, Color("#DE9A2E") * shade, r, a)
			_edge(ci, disc, Color(0.62, 0.38, 0.1, 0.9 * a), maxf(1.0, s * 0.03))
			var inner := _circle_pts(c, s * 0.33, 32)
			_gp(ci, inner, Color("#F4B848") * shade, Color("#FFE29A") * shade, r, a)
			_edge(ci, inner, Color(0.75, 0.48, 0.14, 0.7 * a), maxf(0.8, s * 0.02))
			# Embossed facet rhombus (our mark, not a currency sign).
			var h := s * 0.19
			var wd := s * 0.14
			# Four facets lit from the upper left (reads as a cut stone, not an arrow).
			var t := c + Vector2(0, -h)
			var rr := c + Vector2(wd, 0)
			var b := c + Vector2(0, h)
			var l := c + Vector2(-wd, 0)
			ci.draw_colored_polygon(PackedVector2Array([t, c, l]), Color("#FFF1C4") * Color(shade, a))
			ci.draw_colored_polygon(PackedVector2Array([t, rr, c]), Color("#F6C55A") * Color(shade, a))
			ci.draw_colored_polygon(PackedVector2Array([l, c, b]), Color("#EDB04A") * Color(shade, a))
			ci.draw_colored_polygon(PackedVector2Array([c, rr, b]), Color("#C98526") * Color(shade, a))
			GemDraw.outline(ci, PackedVector2Array([t, rr, b, l]), Color(0.7, 0.44, 0.12, 0.7 * a), 1.0)
			ci.draw_arc(c, s * 0.4, PI * 1.08, PI * 1.62, 16, Color(1, 1, 1, 0.65 * a), maxf(1.0, s * 0.03), true)
		"gem":
			GemDraw.draw_gem(ci, "round", c + Vector2(0, s * 0.02), s * 0.86, Color("#3FA9FF") * shade, Color("#D2EEFF") * shade, Color("#1B4E7E") * shade, s >= 28.0, a)
		"crown":
			var base := _pp(r, [0.16, 0.72, 0.84, 0.72, 0.84, 0.82, 0.16, 0.82])
			var body := _pp(r, [0.16, 0.72, 0.12, 0.3, 0.34, 0.5, 0.5, 0.2, 0.66, 0.5, 0.88, 0.3, 0.84, 0.72])
			ci.draw_colored_polygon(_shift(body, Vector2(0, s * 0.04)), Color(0.4, 0.24, 0.05, 0.22 * a))
			_gp(ci, body, Color("#FFE7A0") * shade, Color("#E3A23A") * shade, r, a)
			_edge(ci, body, Color(0.64, 0.4, 0.1, 0.9 * a), maxf(1.0, s * 0.028))
			_gp(ci, base, Color("#F0B54A") * shade, Color("#C9862A") * shade, r, a)
			_edge(ci, base, Color(0.6, 0.36, 0.08, 0.9 * a), maxf(1.0, s * 0.028))
			GemDraw.draw_gem(ci, "round", _p(r, 0.5, 0.58), s * 0.16, Color("#3FA9FF"), Color("#D2EEFF"), Color("#1B4E7E"), false, a)
			for q: Vector2 in [_p(r, 0.12, 0.3), _p(r, 0.5, 0.2), _p(r, 0.88, 0.3)]:
				ci.draw_circle(q, s * 0.05, Color("#FFF2C8") * Color(shade, a), true, -1.0, true)
		"blueprint":
			var sheet := _pp(r, [0.16, 0.2, 0.74, 0.2, 0.86, 0.32, 0.86, 0.82, 0.16, 0.82])
			ci.draw_colored_polygon(_shift(sheet, Vector2(0, s * 0.035)), Color(0.1, 0.2, 0.35, 0.2 * a))
			_gp(ci, sheet, Color("#7CC4F2") * shade, Color("#3E86C6") * shade, r, a)
			_edge(ci, sheet, Color(0.16, 0.36, 0.6, 0.9 * a), maxf(1.0, s * 0.025))
			ci.draw_colored_polygon(_pp(r, [0.74, 0.2, 0.86, 0.32, 0.74, 0.32]), Color("#B9E2FA") * Color(shade, a))
			var lc := Color(1, 1, 1, 0.8 * a)
			var lw := maxf(1.0, s * 0.03)
			ci.draw_line(_p(r, 0.26, 0.42), _p(r, 0.62, 0.42), lc, lw, true)
			ci.draw_line(_p(r, 0.26, 0.54), _p(r, 0.76, 0.54), lc, lw, true)
			ci.draw_arc(_p(r, 0.42, 0.68), s * 0.08, 0, TAU, 20, lc, lw, true)
			ci.draw_line(_p(r, 0.56, 0.68), _p(r, 0.76, 0.68), lc, lw, true)
		"beacon":
			var post := _pp(r, [0.4, 0.84, 0.6, 0.84, 0.56, 0.5, 0.44, 0.5])
			_gp(ci, post, Color("#F3E3C2") * shade, Color("#C9B08A") * shade, r, a)
			_edge(ci, post, Color(0.55, 0.42, 0.24, 0.8 * a), 1.0)
			ci.draw_texture_rect(UIKit.glow_texture(), Rect2(_p(r, 0.08, -0.04), Vector2(s, s) * 0.84), false, Color(1.0, 0.8, 0.4, 0.5 * a))
			GemDraw.draw_gem(ci, "cushion", _p(r, 0.5, 0.32), s * 0.36, UITokens.TOPAZ * shade, Color("#FFF0C2"), Color("#C2620E"), true, a)
		"tome":
			var cover := _pp(r, [0.2, 0.18, 0.78, 0.18, 0.78, 0.84, 0.2, 0.84])
			ci.draw_colored_polygon(_shift(cover, Vector2(0, s * 0.035)), Color(0.2, 0.08, 0.05, 0.2 * a))
			_gp(ci, cover, Color("#8E5BD0") * shade, Color("#5A3794") * shade, r, a)
			_edge(ci, cover, Color(0.3, 0.16, 0.5, 0.9 * a), 1.0)
			ci.draw_rect(Rect2(_p(r, 0.72, 0.2), Vector2(s * 0.08, s * 0.62)), Color("#F7F1E6") * Color(shade, a))
			GemDraw.draw_keystone(ci, _p(r, 0.47, 0.5), s * 0.3, a, Color(1.0, 0.9, 0.6))
		"fragment":
			GemDraw.draw_gem(ci, "triangle", c, s * 0.8, Color("#B06CFF") * shade, Color("#E7D2FF"), Color("#5E2BA8"), s >= 28.0, a)
		"tab_shop":
			_pouch(ci, r, shade, a)
		"tab_arsenal":
			_cannon_cog(ci, r, shade, a)
		"tab_play":
			_bridge(ci, r, shade, a)
		"tab_heroes":
			_sun_shield(ci, r, shade, a)
		"tab_barracks":
			_tent(ci, r, shade, a)
		_:
			return false
	return true


static func _pp(r: Rect2, xy: Array) -> PackedVector2Array:
	return _pts(r, xy)


static func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out


static func _pouch(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	# Sack body: a rounded bag (sampled curve), tied neck, flared top.
	var body := PackedVector2Array()
	var cb := _p(r, 0.5, 0.64)
	for i in 25:
		var t := float(i) / 24.0
		var ang := lerpf(-PI * 0.2, PI * 1.2, t)
		body.append(cb + Vector2(cos(ang) * s * 0.36, sin(ang) * s * 0.26 + (s * 0.04 if sin(ang) > 0.0 else 0.0)))
	body.append(_p(r, 0.36, 0.36))
	body.append(_p(r, 0.64, 0.36))
	ci.draw_colored_polygon(_shift(body, Vector2(0, s * 0.04)), Color(0.35, 0.18, 0.05, 0.2 * a))
	_gp(ci, body, Color("#F2C98A") * shade, Color("#B8773A") * shade, r, a)
	_edge(ci, body, Color(0.5, 0.28, 0.1, 0.85 * a), maxf(1.0, s * 0.022))
	var top := _pp(r, [0.36, 0.36, 0.26, 0.2, 0.42, 0.26, 0.5, 0.16, 0.58, 0.26, 0.74, 0.2, 0.64, 0.36])
	_gp(ci, top, Color("#F7D9A6") * shade, Color("#D49A55") * shade, r, a)
	_edge(ci, top, Color(0.5, 0.28, 0.1, 0.8 * a), maxf(1.0, s * 0.02))
	# Gold tie and a small facet clasp.
	ci.draw_line(_p(r, 0.34, 0.37), _p(r, 0.66, 0.37), Color("#E3B44E") * Color(shade, a), maxf(2.0, s * 0.06), true)
	GemDraw.draw_keystone(ci, _p(r, 0.5, 0.38), s * 0.16, a, Color(1.0, 0.86, 0.5))
	# Highlight.
	ci.draw_arc(cb + Vector2(-s * 0.04, -s * 0.02), s * 0.24, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.45 * a), maxf(1.0, s * 0.04), true)
	# A coin peeking at the right.
	painted(ci, "coin", Rect2(_p(r, 0.62, 0.6), Vector2(s, s) * 0.32), Color(shade.r, shade.g, shade.b, a))


static func _cannon_cog(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var cc := _p(r, 0.42, 0.62)
	var cog := PackedVector2Array()
	for i in 40:
		var ang := TAU * i / 40.0
		var on := (i % 5) in [0, 1]
		cog.append(cc + Vector2(cos(ang), sin(ang)) * s * (0.3 if on else 0.25))
	ci.draw_colored_polygon(_shift(cog, Vector2(0, s * 0.035)), Color(0.2, 0.15, 0.08, 0.2 * a))
	_gp(ci, cog, Color("#F1D58C") * shade, Color("#B98A3A") * shade, r, a)
	_edge(ci, cog, Color(0.5, 0.36, 0.12, 0.9 * a), maxf(1.0, s * 0.022))
	ci.draw_circle(cc, s * 0.13, Color("#FFF4D8") * Color(shade, a), true, -1.0, true)
	ci.draw_arc(cc, s * 0.13, 0, TAU, 24, Color(0.55, 0.4, 0.15, 0.8 * a), 1.0, true)
	# Barrel: a tapered bronze tube aimed up-right, with bands.
	var d := Vector2(0.8, -0.6).normalized()
	var n := Vector2(-d.y, d.x)
	var b0 := cc + d * s * 0.02
	var b1 := cc + d * s * 0.48
	var barrel := PackedVector2Array([b0 + n * s * 0.12, b1 + n * s * 0.085, b1 - n * s * 0.085, b0 - n * s * 0.12])
	ci.draw_colored_polygon(_shift(barrel, Vector2(0, s * 0.03)), Color(0.2, 0.12, 0.05, 0.25 * a))
	_gp(ci, barrel, Color("#9AA6B6") * shade, Color("#4E5B6E") * shade, Rect2(_p(r, 0, 0.1), Vector2(s, s * 0.6)), a)
	_edge(ci, barrel, Color(0.22, 0.26, 0.34, 0.9 * a), maxf(1.0, s * 0.022))
	ci.draw_line(b0 + n * s * 0.06 + d * s * 0.05, b1 + n * s * 0.045, Color(1, 1, 1, 0.45 * a), maxf(1.0, s * 0.03), true)
	for t: float in [0.35, 0.82]:
		var m := b0.lerp(b1, t)
		var wdt := lerpf(0.13, 0.095, t) * s
		ci.draw_line(m + n * wdt, m - n * wdt, Color("#E3B44E") * Color(shade, a), maxf(2.0, s * 0.05), true)
	ci.draw_circle(b1, s * 0.07, Color("#2B3245") * Color(shade, a), true, -1.0, true)
	ci.draw_arc(b1, s * 0.085, 0, TAU, 20, Color("#E3B44E") * Color(shade, a), maxf(1.2, s * 0.03), true)


static func _bridge(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	# Arch span: an outer arc band over two piers, crystal-blue with a gold trim.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var c := _p(r, 0.5, 0.78)
	for i in 25:
		var t := float(i) / 24.0
		var ang := PI + PI * t
		outer.append(c + Vector2(cos(ang) * s * 0.42, sin(ang) * s * 0.5))
	for i in 25:
		var t := 1.0 - float(i) / 24.0
		var ang := PI + PI * t
		inner.append(c + Vector2(cos(ang) * s * 0.26, sin(ang) * s * 0.32))
	var band := outer.duplicate()
	band.append_array(inner)
	ci.draw_colored_polygon(_shift(band, Vector2(0, s * 0.035)), Color(0.1, 0.25, 0.35, 0.2 * a))
	_gp(ci, band, Color("#F2FCFF") * shade, Color("#7FCDE8") * shade, r, a)
	_edge(ci, band, Color(0.25, 0.55, 0.7, 0.85 * a), maxf(1.0, s * 0.022))
	# Voussoir joints.
	for i in range(1, 8):
		var ang := PI + PI * i / 8.0
		var p0 := c + Vector2(cos(ang) * s * 0.26, sin(ang) * s * 0.32)
		var p1 := c + Vector2(cos(ang) * s * 0.42, sin(ang) * s * 0.5)
		ci.draw_line(p0, p1, Color(0.35, 0.65, 0.8, 0.55 * a), 1.0, true)
	# Gold trim along the top and a crystal keystone.
	ci.draw_polyline(outer, Color("#D8B266") * Color(shade, a), maxf(1.5, s * 0.035), true)
	GemDraw.draw_keystone(ci, c + Vector2(0, -s * 0.44), s * 0.24, a, Color(1.0, 0.88, 0.55))
	# Deck line.
	ci.draw_line(_p(r, 0.04, 0.8), _p(r, 0.96, 0.8), Color("#D8B266") * Color(shade, a), maxf(1.5, s * 0.04), true)


static func _sun_shield(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var sh := _pp(r, [0.2, 0.16, 0.8, 0.16, 0.82, 0.5, 0.5, 0.9, 0.18, 0.5])
	ci.draw_colored_polygon(_shift(sh, Vector2(0, s * 0.04)), Color(0.3, 0.2, 0.08, 0.22 * a))
	_gp(ci, sh, Color("#FFFFFF") * shade, Color("#DCCFB6") * shade, r, a)
	_edge(ci, sh, Color("#C9A86A") * Color(shade, a), maxf(1.5, s * 0.04))
	var inner := _pp(r, [0.27, 0.23, 0.73, 0.23, 0.74, 0.49, 0.5, 0.8, 0.26, 0.49])
	_edge(ci, inner, Color(0.79, 0.66, 0.42, 0.55 * a), 1.0)
	# Sunburst: amber disc + 8 rays.
	var c := _p(r, 0.5, 0.45)
	for i in 8:
		var ang := TAU * i / 8.0 - PI / 2.0
		var dd := Vector2(cos(ang), sin(ang))
		var nn := Vector2(-dd.y, dd.x) * s * 0.035
		ci.draw_colored_polygon(PackedVector2Array([c + dd * s * 0.1 + nn, c + dd * s * 0.22, c + dd * s * 0.1 - nn]), Color("#F0A23A") * Color(shade, a))
	var disc := _circle_pts(c, s * 0.1, 20)
	_gp(ci, disc, Color("#FFE7A0") * shade, Color("#E8922E") * shade, Rect2(c - Vector2(s, s) * 0.1, Vector2(s, s) * 0.2), a)
	ci.draw_arc(c + Vector2(-s * 0.02, -s * 0.02), s * 0.06, PI, PI * 1.5, 8, Color(1, 1, 1, 0.7 * a), 1.0, true)


static func _tent(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var body := _pp(r, [0.5, 0.2, 0.88, 0.82, 0.12, 0.82])
	ci.draw_colored_polygon(_shift(body, Vector2(0, s * 0.035)), Color(0.3, 0.1, 0.05, 0.22 * a))
	_gp(ci, body, Color("#F49A6E") * shade, Color("#C24E33") * shade, r, a)
	_edge(ci, body, Color(0.5, 0.18, 0.1, 0.85 * a), maxf(1.0, s * 0.022))
	# Cream stripe panels and the door flap.
	ci.draw_colored_polygon(_pp(r, [0.5, 0.2, 0.62, 0.82, 0.38, 0.82]), Color("#F7EBD8") * Color(shade, 0.9 * a))
	ci.draw_colored_polygon(_pp(r, [0.5, 0.48, 0.58, 0.82, 0.42, 0.82]), Color("#7A2E1E") * Color(shade, a))
	ci.draw_line(_p(r, 0.5, 0.2), _p(r, 0.12, 0.82), Color(1, 0.9, 0.8, 0.45 * a), maxf(1.0, s * 0.03), true)
	# Gold pole + pennant.
	ci.draw_line(_p(r, 0.5, 0.2), _p(r, 0.5, 0.06), Color("#C9A86A") * Color(shade, a), maxf(1.5, s * 0.035), true)
	ci.draw_colored_polygon(_pp(r, [0.5, 0.06, 0.68, 0.1, 0.5, 0.14]), Color("#F5AE45") * Color(shade, a))
	ci.draw_line(_p(r, 0.06, 0.83), _p(r, 0.94, 0.83), Color("#C9A86A") * Color(shade, a), maxf(1.5, s * 0.035), true)
