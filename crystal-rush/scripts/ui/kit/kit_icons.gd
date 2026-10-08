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
	# UI v2 final pass: the legacy clip-art kinds now draw as line icons too.
	"swipe", "spikes", "flag", "fortress", "egg", "cache_stone", "cache_world", "cache_royal", "cache_xray",
	"glint", "gate", "blade", "hand", "crate", "soldier", "star", "castle", "vault",
]
const PAINTED := ["coin", "gem", "crown", "blueprint", "beacon", "tome", "fragment",
		"tab_shop", "tab_arsenal", "tab_play", "tab_heroes", "tab_barracks"]
## Legacy kinds that are UI glyphs (sticker style before) and now draw as line icons.
const LINE_ALIASES := {"gear": "settings", "percent": "odds", "up": "arrow_up", "book": "quests",
		"hand": "swipe", "crate": "chest", "soldier": "helmet", "star": "glint", "castle": "fortress", "vault": "chest"}


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
	# Round caps at the two ends only (a dot per joint cost one draw call each: the Arsenal
	# grid's sockets drew ~50 calls per icon).
	if not closed and pts.size() >= 2 and w >= 2.6:
		ci.draw_circle(pts[0], w * 0.5, col, true, -1.0, true)
		ci.draw_circle(pts[pts.size() - 1], w * 0.5, col, true, -1.0, true)


static func _arc(ci: CanvasItem, c: Vector2, rad: float, a0: float, a1: float, col: Color, w: float, caps := true) -> void:
	ci.draw_arc(c, rad, a0, a1, maxi(8, int(absf(a1 - a0) * 10.0)), col, w, true)
	if caps and w >= 2.6:
		ci.draw_circle(c + Vector2(cos(a0), sin(a0)) * rad, w * 0.5, col, true, -1.0, true)
		ci.draw_circle(c + Vector2(cos(a1), sin(a1)) * rad, w * 0.5, col, true, -1.0, true)


static func _dot(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(c, rad, col, true, -1.0, true)


## Draws line icon `k` in `r` with colour `col`. Returns false for an unknown kind.
static func line(ci: CanvasItem, k: String, r: Rect2, col: Color, width := -1.0) -> bool:
	k = LINE_ALIASES.get(k, k)
	var s := r.size.x
	# v3: finer monoline (was s * 0.075, 1.6..3.2): 1.3..2.4 canvas px.
	var w := width if width > 0.0 else clampf(s * 0.055, 1.3, 2.4)
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
		# ---- UI v2 final pass (legacy clip-art replacements)
		"swipe":
			# A finger-swipe arc with a gold-dot fingertip and a small arrow head.
			_arc(ci, _p(r, 0.5, 0.66), s * 0.34, PI * 1.16, PI * 1.84, col, w)
			var e := _p(r, 0.5, 0.66) + Vector2(cos(PI * 1.84), sin(PI * 1.84)) * s * 0.34
			_ln(ci, PackedVector2Array([e + Vector2(-s * 0.13, -s * 0.02), e, e + Vector2(-s * 0.02, s * 0.12)]), col, w)
			_arc(ci, _p(r, 0.5, 0.7), s * 0.1, 0, TAU, col, w * 0.85, false)
			_dot(ci, _p(r, 0.5, 0.7), s * 0.045, UITokens.HAIRLINE)
		"spikes":
			for i in 3:
				var x0 := 0.14 + i * 0.25
				_ln(ci, _pts(r, [x0, 0.74, x0 + 0.11, 0.3, x0 + 0.22, 0.74]), col, w * 0.9, true)
			_ln(ci, _pts(r, [0.1, 0.8, 0.9, 0.8]), col, w)
		"flag":
			_ln(ci, _pts(r, [0.28, 0.86, 0.28, 0.14]), col, w)
			_ln(ci, _pts(r, [0.28, 0.18, 0.78, 0.26, 0.64, 0.38, 0.78, 0.5, 0.28, 0.5]), col, w * 0.9, true)
			_dot(ci, _p(r, 0.28, 0.12), w * 0.9, col)
		"fortress":
			_ln(ci, _pts(r, [0.12, 0.84, 0.12, 0.3, 0.22, 0.3, 0.22, 0.38, 0.32, 0.38, 0.32, 0.3, 0.42, 0.3, 0.42, 0.38,
					0.58, 0.38, 0.58, 0.3, 0.68, 0.3, 0.68, 0.38, 0.78, 0.38, 0.78, 0.3, 0.88, 0.3, 0.88, 0.84]), col, w, true)
			_ln(ci, _pts(r, [0.38, 0.84, 0.38, 0.62]), col, w * 0.85)
			_ln(ci, _pts(r, [0.62, 0.84, 0.62, 0.62]), col, w * 0.85)
			_arc(ci, _p(r, 0.5, 0.62), s * 0.12, PI, TAU, col, w * 0.85, false)
		"egg", "cache_stone", "cache_world", "cache_royal", "cache_xray":
			# An egg outline with the cache's gem cut inside (stone square, world triangle, royal star).
			var eg := PackedVector2Array()
			for i in 36:
				var t := TAU * i / 36.0
				var yy := -cos(t)
				var rx := 0.3 * (1.0 - 0.18 * yy) * sin(t)
				eg.append(_p(r, 0.5 + rx, 0.54 + yy * 0.36))
			_ln(ci, eg, col, w, true)
			var cut: String = {"cache_stone": "square", "cache_world": "triangle", "cache_royal": "star", "cache_xray": "round"}.get(k, "square")
			GemDraw.outline(ci, GemDraw.cut_points(cut, _p(r, 0.5, 0.58), s * 0.3), col, w * 0.75)
		"glint":
			# Our signature glint: a 4-ray cross with one long ray (no 4-point star).
			_ln(ci, _pts(r, [0.5, 0.08, 0.5, 0.92]), col, w * 0.8)
			_ln(ci, _pts(r, [0.28, 0.42, 0.72, 0.42]), col, w * 0.8)
			_dot(ci, _p(r, 0.5, 0.42), w * 1.1, col)
		"gate":
			_ln(ci, _pts(r, [0.18, 0.84, 0.18, 0.2, 0.82, 0.2, 0.82, 0.84]), col, w)
			_ln(ci, _pts(r, [0.5, 0.36, 0.5, 0.64]), col, w * 0.9)
			_ln(ci, _pts(r, [0.36, 0.5, 0.64, 0.5]), col, w * 0.9)
		"blade":
			_arc(ci, c, s * 0.3, 0, TAU, col, w, false)
			for i in 6:
				var a0 := TAU * i / 6.0
				_ln(ci, PackedVector2Array([c + Vector2(cos(a0), sin(a0)) * s * 0.3, c + Vector2(cos(a0 + 0.5), sin(a0 + 0.5)) * s * 0.42]), col, w * 0.8)
			_dot(ci, c, w * 1.2, col)
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
			GemDraw.draw_gem(ci, "round", c + Vector2(0, s * 0.02), s * 0.86, Color("#3FA9FF") * shade, Color("#D2EEFF") * shade, Color("#1B4E7E") * shade, true, a)
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
			# A rolled parchment with a blue ink sketch and a small gold seal (no office sheet).
			var sheet := _pp(r, [0.2, 0.22, 0.8, 0.22, 0.8, 0.8, 0.2, 0.8])
			ci.draw_colored_polygon(_shift(sheet, Vector2(0, s * 0.035)), Color(0.35, 0.24, 0.1, 0.2 * a))
			_gp(ci, sheet, Color("#FBF3DF") * shade, Color("#E6D3AE") * shade, r, a)
			_edge(ci, sheet, Color(0.62, 0.48, 0.26, 0.85 * a), maxf(1.0, s * 0.025))
			for yy: float in [0.22, 0.8]:
				var roll := _pp(r, [0.14, yy - 0.06, 0.86, yy - 0.06, 0.86, yy + 0.06, 0.14, yy + 0.06])
				_gp(ci, roll, Color("#F3E4C2") * shade, Color("#CDB283") * shade, r, a)
				_edge(ci, roll, Color(0.55, 0.4, 0.2, 0.85 * a), maxf(1.0, s * 0.022))
			var ink := Color(0.16, 0.42, 0.74, 0.9 * a)
			var lw := maxf(1.0, s * 0.028)
			ci.draw_arc(_p(r, 0.42, 0.5), s * 0.1, 0, TAU, 20, ink, lw, true)
			ci.draw_line(_p(r, 0.52, 0.5), _p(r, 0.7, 0.42), ink, lw, true)
			ci.draw_line(_p(r, 0.28, 0.64), _p(r, 0.62, 0.64), Color(ink.r, ink.g, ink.b, 0.6 * a), lw, true)
			GemDraw.draw_gem(ci, "round", _p(r, 0.72, 0.66), s * 0.17, Color("#F2B84A") * shade, Color("#FFF0C2"), Color("#B9772A"), false, a)
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
			# v3: the tab family is the monoline gold nav glyph everywhere (unlock cards, chips).
			nav(ci, "shop", r, Color(UITokens.NAV_GOLD.r * shade.r, UITokens.NAV_GOLD.g * shade.g, UITokens.NAV_GOLD.b * shade.b, a))
		"tab_arsenal":
			# v3: the tab family is the monoline gold nav glyph everywhere (unlock cards, chips).
			nav(ci, "arsenal", r, Color(UITokens.NAV_GOLD.r * shade.r, UITokens.NAV_GOLD.g * shade.g, UITokens.NAV_GOLD.b * shade.b, a))
		"tab_play":
			# v3: the tab family is the monoline gold nav glyph everywhere (unlock cards, chips).
			nav(ci, "play", r, Color(UITokens.NAV_GOLD.r * shade.r, UITokens.NAV_GOLD.g * shade.g, UITokens.NAV_GOLD.b * shade.b, a))
		"tab_heroes":
			# v3: the tab family is the monoline gold nav glyph everywhere (unlock cards, chips).
			nav(ci, "heroes", r, Color(UITokens.NAV_GOLD.r * shade.r, UITokens.NAV_GOLD.g * shade.g, UITokens.NAV_GOLD.b * shade.b, a))
		"tab_barracks":
			# v3: the tab family is the monoline gold nav glyph everywhere (unlock cards, chips).
			nav(ci, "barracks", r, Color(UITokens.NAV_GOLD.r * shade.r, UITokens.NAV_GOLD.g * shade.g, UITokens.NAV_GOLD.b * shade.b, a))
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


# ------------------------------------------------------------------ nav family
## The five bottom-bar icons are ONE painted family: the same three materials (slate enamel,
## honey gold, ivory), the same light from the upper left (diagonal gradients, a rim light on
## the lit edges, a soft drop shadow to the lower right), the same edge weight (2.6 % of the
## size) and one small gem accent each. They read on the cream bar and on the amber medallion.

const NAV_MATS := {
	"enamel": [Color("#8D9BB4"), Color("#3E4960"), Color("#283041")],
	"gold": [Color("#FFE8AA"), Color("#C4862F"), Color("#7E5218")],
	"ivory": [Color("#FFFCF3"), Color("#DCC9A2"), Color("#957647")],
}
const NAV_L := Vector2(-0.6, -0.8)          ## towards the light


static func _nav_ew(s: float) -> float:
	return maxf(1.0, s * 0.026)


## Soft drop shadow (lower right), one polygon.
static func _nav_drop(ci: CanvasItem, pts: PackedVector2Array, s: float, a: float) -> void:
	ci.draw_colored_polygon(_shift(pts, Vector2(s * 0.022, s * 0.042)), Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.24 * a))


## Material fill: a diagonal gradient (lit upper left -> shaded lower right) across `r`, the
## family edge, and a rim light inset along the edges that face the light.
static func _nav_fill(ci: CanvasItem, pts: PackedVector2Array, mat: String, r: Rect2, shade: Color, a: float, rim := true) -> void:
	var m: Array = NAV_MATS[mat]
	var hi: Color = m[0]
	var lo: Color = m[1]
	var s := r.size.x
	var cols := PackedColorArray()
	for p in pts:
		var q := (p - r.position) / s
		var t := clampf((q.x * 0.55 + q.y * 0.85) / 1.25, 0.0, 1.0)
		var c: Color = hi.lerp(lo, smoothstep(0.08, 0.95, t)) * shade
		c.a = a
		cols.append(c)
	ci.draw_polygon(pts, cols)
	if rim:
		_nav_rim(ci, pts, s, a, 0.55 if mat != "ivory" else 0.8)
	GemDraw.outline(ci, pts, Color((m[2] as Color).r, (m[2] as Color).g, (m[2] as Color).b, 0.92 * a), _nav_ew(s))


## Rim light: the edges whose outward normal faces the light, inset a little, in warm white
## (one multiline call).
static func _nav_rim(ci: CanvasItem, pts: PackedVector2Array, s: float, a: float, k := 0.55) -> void:
	var n := pts.size()
	if n < 3:
		return
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= n
	# Winding: outward normal sign from the signed area.
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var sg := 1.0 if area > 0.0 else -1.0
	var segs := PackedVector2Array()
	var cols := PackedColorArray()
	var inset := s * 0.035
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var d := p1 - p0
		if d.length() < 0.01:
			continue
		var nrm := Vector2(d.y, -d.x).normalized() * sg
		var lit := nrm.dot(NAV_L.normalized())
		if lit <= 0.25:
			continue
		segs.append(p0 - nrm * inset)
		segs.append(p1 - nrm * inset)
		var c := Color(1.0, 0.98, 0.9, k * a * smoothstep(0.25, 0.9, lit))
		cols.append(c)
	if segs.size() >= 2:
		ci.draw_multiline_colors(segs, cols, maxf(1.0, s * 0.03), true)


## Soft volume: a warm-white sheen on the lit side of a mass (the glow texture, one call).
static func _nav_sheen(ci: CanvasItem, c: Vector2, rx: float, ry: float, a: float, k := 0.32) -> void:
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), false, Color(1.0, 0.98, 0.92, k * a))


static func _nav_gem(ci: CanvasItem, cut: String, c: Vector2, sz: float, gem: String, a: float) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var base: Color = g.get("rim", UITokens.TOPAZ)
	var light: Color = g.get("light", Color.WHITE)
	GemDraw.draw_gem(ci, cut, c, sz, base, light, base.darkened(0.5), sz >= 14.0, a)


static func _arc_pts(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return out


## Магазин: a slate-velvet coin pouch with a gold tie and topaz clasp, a gold coin at its side.
static func _pouch(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var cb := _p(r, 0.47, 0.63)
	var body := PackedVector2Array()
	for i in 29:
		var t := float(i) / 28.0
		var ang := lerpf(-PI * 0.22, PI * 1.22, t)
		body.append(cb + Vector2(cos(ang) * s * 0.34, sin(ang) * s * 0.25 + (s * 0.035 if sin(ang) > 0.0 else 0.0)))
	body.append(_p(r, 0.35, 0.37))
	body.append(_p(r, 0.59, 0.37))
	var top := _pp(r, [0.35, 0.37, 0.24, 0.22, 0.38, 0.26, 0.47, 0.15, 0.56, 0.26, 0.7, 0.22, 0.59, 0.37])
	_nav_drop(ci, body, s, a)
	_nav_fill(ci, body, "enamel", r, shade, a)
	_nav_fill(ci, top, "enamel", r, shade, a)
	# Gathered folds under the tie, and the soft sheen on the lit side.
	var fold := Color(0.16, 0.19, 0.27, 0.45 * a)
	ci.draw_polyline(_pp(r, [0.4, 0.42, 0.36, 0.56, 0.37, 0.7]), fold, maxf(1.0, s * 0.022), true)
	ci.draw_polyline(_pp(r, [0.55, 0.42, 0.6, 0.55, 0.6, 0.66]), fold, maxf(1.0, s * 0.022), true)
	_nav_sheen(ci, _p(r, 0.36, 0.56), s * 0.2, s * 0.15, a)
	# Gold tie band + clasp gem.
	var band := _pp(r, [0.31, 0.345, 0.63, 0.345, 0.64, 0.41, 0.3, 0.41])
	_nav_fill(ci, band, "gold", r, shade, a, false)
	_nav_gem(ci, "cushion", _p(r, 0.47, 0.38), s * 0.15, "topaz", a)
	# A gold coin at the lower right (same light and edge).
	var cc := _p(r, 0.76, 0.74)
	var disc := _circle_pts(cc, s * 0.15, 24)
	_nav_drop(ci, disc, s, a)
	_nav_fill(ci, disc, "gold", r, shade, a)
	ci.draw_arc(cc, s * 0.095, 0, TAU, 20, Color(0.6, 0.38, 0.1, 0.7 * a), maxf(1.0, s * 0.018), true)
	GemDraw.draw_keystone(ci, cc, s * 0.1, a, Color(1.0, 0.86, 0.5))


## Арсенал: a gold cog with a slate enamel cannon barrel aimed up-right, gold bands, a sapphire
## on the hub.
static func _cannon_cog(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var cc := _p(r, 0.4, 0.64)
	var cog := PackedVector2Array()
	for i in 40:
		var ang := TAU * i / 40.0 + 0.08
		var on := (i % 5) in [0, 1]
		cog.append(cc + Vector2(cos(ang), sin(ang)) * s * (0.3 if on else 0.245))
	_nav_drop(ci, cog, s, a)
	_nav_fill(ci, cog, "gold", r, shade, a)
	var d := Vector2(0.8, -0.6).normalized()
	var n := Vector2(-d.y, d.x)
	var b0 := cc - d * s * 0.04
	var b1 := cc + d * s * 0.47
	var barrel := PackedVector2Array([b0 + n * s * 0.125, b1 + n * s * 0.088, b1 - n * s * 0.088, b0 - n * s * 0.125])
	_nav_drop(ci, barrel, s, a)
	_nav_fill(ci, barrel, "enamel", r, shade, a)
	for t: float in [0.3, 0.86]:
		var m := b0.lerp(b1, t)
		var wd := lerpf(0.135, 0.1, t) * s
		var bw := s * 0.035
		var bandp := PackedVector2Array([m + n * wd - d * bw, m + n * wd + d * bw, m - n * wd + d * bw, m - n * wd - d * bw])
		_nav_fill(ci, bandp, "gold", r, shade, a, false)
	ci.draw_circle(b1 + d * s * 0.01, s * 0.06, Color("#1E2433") * Color(shade, a), true, -1.0, true)
	_nav_gem(ci, "round", cc, s * 0.17, "sapphire", a)


## Грати: the bridge arch in slate enamel with a gold trim, a crystal keystone and a soft
## aqua light under the span.
static func _bridge(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var c := _p(r, 0.5, 0.8)
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(_p(r, 0.22, 0.5), Vector2(s * 0.56, s * 0.42)), false, Color(0.6, 0.92, 1.0, 0.55 * a))
	var outer := _arc_pts(c, s * 0.42, s * 0.52, PI, TAU, 28)
	var inner := _arc_pts(c, s * 0.25, s * 0.33, TAU, PI, 28)
	var band := outer.duplicate()
	band.append_array(inner)
	_nav_drop(ci, band, s, a)
	_nav_fill(ci, band, "enamel", r, shade, a)
	# Voussoir joints (ivory hairlines).
	var segs := PackedVector2Array()
	for i in range(1, 8):
		var ang := PI + PI * i / 8.0
		segs.append(c + Vector2(cos(ang) * s * 0.26, sin(ang) * s * 0.34))
		segs.append(c + Vector2(cos(ang) * s * 0.41, sin(ang) * s * 0.51))
	ci.draw_multiline(segs, Color(1.0, 0.97, 0.88, 0.35 * a), 1.0, true)
	# Gold trim along the extrados.
	ci.draw_polyline(_arc_pts(c, s * 0.44, s * 0.545, PI, TAU, 28), Color("#E3B95E") * Color(shade, a), maxf(1.5, s * 0.04), true)
	# The deck: a gold plank across.
	var deck := _pp(r, [0.04, 0.78, 0.96, 0.78, 0.96, 0.84, 0.04, 0.84])
	_nav_drop(ci, deck, s, a)
	_nav_fill(ci, deck, "gold", r, shade, a, false)
	GemDraw.draw_keystone(ci, c + Vector2(0, -s * 0.47), s * 0.25, a, Color(0.75, 0.95, 1.0))


## Герої: a slate enamel heater shield with a gold rim, a gold sunburst and an amethyst heart.
static func _sun_shield(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var sh := _pp(r, [0.18, 0.14, 0.82, 0.14, 0.83, 0.48, 0.5, 0.9, 0.17, 0.48])
	_nav_drop(ci, sh, s, a)
	_nav_fill(ci, sh, "gold", r, shade, a)
	var inner := _pp(r, [0.25, 0.21, 0.75, 0.21, 0.755, 0.47, 0.5, 0.8, 0.245, 0.47])
	_nav_fill(ci, inner, "enamel", r, shade, a)
	_nav_sheen(ci, _p(r, 0.38, 0.32), s * 0.16, s * 0.12, a, 0.26)
	var c := _p(r, 0.5, 0.44)
	for i in 8:
		var ang := TAU * i / 8.0 - PI / 2.0
		var dd := Vector2(cos(ang), sin(ang))
		var nn := Vector2(-dd.y, dd.x) * s * 0.032
		var L := 0.22 if i % 2 == 0 else 0.17
		var ray := PackedVector2Array([c + dd * s * 0.09 + nn, c + dd * s * L, c + dd * s * 0.09 - nn])
		_nav_fill(ci, ray, "gold", r, shade, a, false)
	_nav_gem(ci, "round", c, s * 0.17, "amethyst", a)


## Казарми: a slate enamel tent with an ivory centre panel, gold roof trim, a gold pole and an
## amber pennant.
static func _tent(ci: CanvasItem, r: Rect2, shade: Color, a: float) -> void:
	var s := r.size.x
	var body := _pp(r, [0.5, 0.2, 0.9, 0.8, 0.1, 0.8])
	_nav_drop(ci, body, s, a)
	_nav_fill(ci, body, "enamel", r, shade, a)
	_nav_sheen(ci, _p(r, 0.33, 0.62), s * 0.14, s * 0.12, a, 0.26)
	var panel := _pp(r, [0.5, 0.2, 0.63, 0.8, 0.37, 0.8])
	_nav_fill(ci, panel, "ivory", r, shade, a, false)
	var door := _pp(r, [0.5, 0.5, 0.585, 0.8, 0.415, 0.8])
	ci.draw_colored_polygon(door, Color("#2B3245") * Color(shade, a))
	# Gold trim on both roof lines + the ground line.
	var gold := Color("#E3B95E") * Color(shade, a)
	ci.draw_polyline(_pp(r, [0.08, 0.81, 0.5, 0.19, 0.92, 0.81]), gold, maxf(1.5, s * 0.04), true)
	var ground := _pp(r, [0.04, 0.8, 0.96, 0.8, 0.96, 0.86, 0.04, 0.86])
	_nav_fill(ci, ground, "gold", r, shade, a, false)
	ci.draw_line(_p(r, 0.5, 0.2), _p(r, 0.5, 0.05), gold, maxf(1.5, s * 0.035), true)
	var flag := _pp(r, [0.5, 0.05, 0.72, 0.095, 0.5, 0.14])
	_nav_fill(ci, flag, "gold", r, Color(1.0, 0.82, 0.6) * shade, a, false)


# ------------------------------------------------------------------ v3 nav glyphs (monoline gold)
## UI v3 bottom-nav family ("porcelain glass"): ONE monoline family, gold ink, 1.6 canvas px
## strokes with round joins on a 40 px box, one silhouette per tab, and one small cut-gem accent
## each (the gem DNA). `fill_a` > 0 lays a thin duotone wash of `fill` under the strokes (the
## active tab). No gradients, no rims, no drop shadows, no multi-colour.
##   shop = a brilliant-cut gem · arsenal = a crossed blade and cannon barrel · play = an arch
##   gate (the Play slot itself shows the topaz crystal) · heroes = a crested helm ·
##   barracks = a swallow-tail banner.
const NAV := ["shop", "arsenal", "play", "heroes", "barracks"]


static func nav(ci: CanvasItem, k: String, r: Rect2, col: Color, fill_a := 0.0, fill := UITokens.CTA, width := -1.0) -> bool:
	var s := r.size.x
	var w := width if width > 0.0 else clampf(s * 0.04, 1.2, 2.0)
	var fc := Color(fill.r, fill.g, fill.b, fill_a * col.a)
	match k:
		"shop":
			var body := _pts(r, [0.3, 0.24, 0.7, 0.24, 0.88, 0.42, 0.5, 0.86, 0.12, 0.42])
			if fill_a > 0.0:
				ci.draw_colored_polygon(body, fc)
			_ln(ci, body, col, w, true)
			_ln(ci, _pts(r, [0.12, 0.42, 0.88, 0.42]), col, w * 0.8)
			_ln(ci, _pts(r, [0.3, 0.24, 0.4, 0.42, 0.5, 0.24, 0.6, 0.42, 0.7, 0.24]), col, w * 0.8)
			_ln(ci, _pts(r, [0.4, 0.42, 0.5, 0.86, 0.6, 0.42]), col, w * 0.8)
			# Glint: a tiny 4-ray star off the crown (the gem accent).
			var g := _p(r, 0.86, 0.16)
			ci.draw_line(g - Vector2(s * 0.07, 0), g + Vector2(s * 0.07, 0), col, w * 0.7, true)
			ci.draw_line(g - Vector2(0, s * 0.07), g + Vector2(0, s * 0.07), col, w * 0.7, true)
		"arsenal":
			# Blade: lower left -> upper right.
			var bd := Vector2(1, -1).normalized()
			var bn := Vector2(-bd.y, bd.x)
			var base := _p(r, 0.34, 0.66)
			var tip := _p(r, 0.84, 0.16)
			var hw := s * 0.05
			var blade := PackedVector2Array([base + bn * hw, tip - bd * s * 0.08 + bn * hw * 0.8, tip, tip - bd * s * 0.08 - bn * hw * 0.8, base - bn * hw])
			if fill_a > 0.0:
				ci.draw_colored_polygon(blade, fc)
			_ln(ci, blade, col, w)
			_ln(ci, PackedVector2Array([base - bn * s * 0.13, base + bn * s * 0.13]), col, w)
			_ln(ci, PackedVector2Array([base, base - bd * s * 0.15]), col, w)
			_diamond_line(ci, base - bd * s * 0.2, s * 0.09, col, w * 0.8)
			# Cannon barrel: upper left (muzzle) -> lower right (breech), behind the blade.
			var cd := Vector2(1, 1).normalized()
			var cn := Vector2(-cd.y, cd.x)
			var m0 := _p(r, 0.17, 0.2)
			var b0 := _p(r, 0.66, 0.69)
			var tube := PackedVector2Array([m0 + cn * s * 0.065, b0 + cn * s * 0.085, b0 - cn * s * 0.085, m0 - cn * s * 0.065])
			if fill_a > 0.0:
				ci.draw_colored_polygon(tube, fc)
			_ln(ci, tube, col, w, true)
			_ln(ci, PackedVector2Array([m0 + cd * s * 0.06 + cn * s * 0.085, m0 + cd * s * 0.06 - cn * s * 0.085]), col, w * 0.8)
			_arc(ci, b0 + cd * s * 0.1, s * 0.055, 0, TAU, col, w * 0.8, false)
		"play":
			var gate := PackedVector2Array()
			gate.append(_p(r, 0.24, 0.84))
			for i in 17:
				var a := PI + PI * float(i) / 16.0
				gate.append(_p(r, 0.5, 0.48) + Vector2(cos(a), sin(a)) * s * 0.26)
			gate.append(_p(r, 0.76, 0.84))
			if fill_a > 0.0:
				var poly := gate.duplicate()
				ci.draw_colored_polygon(poly, fc)
			_ln(ci, gate, col, w)
			_arc(ci, _p(r, 0.5, 0.52), s * 0.14, PI, TAU, col, w * 0.8, false)
			_ln(ci, _pts(r, [0.36, 0.52, 0.36, 0.84]), col, w * 0.8)
			_ln(ci, _pts(r, [0.64, 0.52, 0.64, 0.84]), col, w * 0.8)
			_ln(ci, _pts(r, [0.12, 0.86, 0.88, 0.86]), col, w)
			_diamond_line(ci, _p(r, 0.5, 0.12), s * 0.11, col, w * 0.8)
		"heroes":
			var helm := PackedVector2Array()
			helm.append(_p(r, 0.38, 0.86))
			helm.append(_p(r, 0.22, 0.78))
			helm.append(_p(r, 0.2, 0.52))
			for i in 17:
				var a := PI + PI * float(i) / 16.0
				helm.append(_p(r, 0.5, 0.52) + Vector2(cos(a), sin(a)) * s * 0.3)
			helm.append(_p(r, 0.78, 0.78))
			helm.append(_p(r, 0.62, 0.86))
			if fill_a > 0.0:
				ci.draw_colored_polygon(helm, fc)
			_ln(ci, helm, col, w)
			# T-visor.
			_ln(ci, _pts(r, [0.3, 0.6, 0.45, 0.6, 0.47, 0.82]), col, w * 0.85)
			_ln(ci, _pts(r, [0.7, 0.6, 0.55, 0.6, 0.53, 0.82]), col, w * 0.85)
			# Crest ridge and the brow gem.
			_arc(ci, _p(r, 0.5, 0.52), s * 0.38, PI * 1.28, PI * 1.72, col, w * 0.8, false)
			_diamond_line(ci, _p(r, 0.5, 0.42), s * 0.1, col, w * 0.8)
		"barracks":
			_ln(ci, _pts(r, [0.26, 0.16, 0.26, 0.9]), col, w)
			_ln(ci, _pts(r, [0.26, 0.2, 0.78, 0.2]), col, w * 0.85)
			_diamond_line(ci, _p(r, 0.26, 0.1), s * 0.1, col, w * 0.8)
			var cloth := _pts(r, [0.34, 0.2, 0.34, 0.74, 0.53, 0.62, 0.72, 0.74, 0.72, 0.2])
			if fill_a > 0.0:
				ci.draw_colored_polygon(cloth, fc)
			_ln(ci, cloth, col, w)
			_diamond_line(ci, _p(r, 0.53, 0.4), s * 0.15, col, w * 0.8)
		_:
			return false
	return true


## A small rhombus outline (the family's gem accent).
static func _diamond_line(ci: CanvasItem, c: Vector2, sz: float, col: Color, w: float) -> void:
	var h := sz * 0.5
	var hw := sz * 0.36
	_ln(ci, PackedVector2Array([c + Vector2(0, -h), c + Vector2(hw, 0), c + Vector2(0, h), c + Vector2(-hw, 0)]), col, w, true)


## The Play key's jewel: a slender faceted topaz crystal (a hexagonal point), lit from the upper
## left, edged by one fine deep-amber line. `glow` adds a soft inner light (the active Play tab).
static func topaz_crystal(ci: CanvasItem, c: Vector2, h: float, alpha := 1.0, glow := 0.0) -> void:
	var w := h * 0.62
	var t := c + Vector2(0, -h * 0.5)
	var b := c + Vector2(0, h * 0.5)
	var ul := c + Vector2(-w * 0.5, -h * 0.2)
	var ur := c + Vector2(w * 0.5, -h * 0.2)
	var ll := c + Vector2(-w * 0.5, h * 0.24)
	var lr := c + Vector2(w * 0.5, h * 0.24)
	var tm := c + Vector2(0, -h * 0.12)
	var bm := c + Vector2(0, h * 0.16)
	if glow > 0.0:
		ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(h, h) * 0.9, Vector2(h, h) * 1.8), false, Color(1.0, 0.82, 0.45, 0.45 * glow * alpha))
	ci.draw_colored_polygon(PackedVector2Array([t, tm, ul]), _ca(Color("#FFF1C9"), alpha))
	ci.draw_colored_polygon(PackedVector2Array([t, ur, tm]), _ca(Color("#FFD27A"), alpha))
	ci.draw_colored_polygon(PackedVector2Array([ul, tm, bm, ll]), _ca(Color("#FFC560"), alpha))
	ci.draw_colored_polygon(PackedVector2Array([tm, ur, lr, bm]), _ca(Color("#F0A23C"), alpha))
	ci.draw_colored_polygon(PackedVector2Array([ll, bm, b]), _ca(Color("#E89434"), alpha))
	ci.draw_colored_polygon(PackedVector2Array([bm, lr, b]), _ca(Color("#C9772A"), alpha))
	var edge := _ca(Color(0.62, 0.36, 0.1, 0.9), alpha)
	var lw := UIKit.px(1.0)
	ci.draw_polyline(PackedVector2Array([t, ur, lr, b, ll, ul, t]), edge, lw, true)
	var facet := _ca(Color(1, 0.97, 0.88, 0.75), alpha)
	ci.draw_polyline(PackedVector2Array([ul, tm, ur]), facet, lw, true)
	ci.draw_polyline(PackedVector2Array([tm, bm]), facet, lw, true)
	ci.draw_polyline(PackedVector2Array([ll, bm, lr]), Color(edge.r, edge.g, edge.b, edge.a * 0.5), lw, true)


static func _ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)
