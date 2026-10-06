class_name ForgeChrome
## «Кришталева кузня» shared chrome: the top strip (level gem, settings shard, currency shards)
## and the floating station shards that replace the tab bar.

const STATIONS := [
	["vault", "geode", "СХОВИЩЕ"],
	["arsenal", "anvil", "АРСЕНАЛ"],
	["gate", "gate", "БРАМА"],
	["heroes", "fox", "ГЕРОЇ"],
	["barracks", "helm", "КАЗАРМИ"],
]


## A small glass shard with an icon and a tabular number (currency / resource).
static func currency(parent: Node, r: Rect2, icon: String, value: String, seed: int, plus := false) -> void:
	var pts := ForgeKit.panel(parent, r, seed, {"n_cuts": 1, "min_cut": 16, "max_cut": 22, "skew": 0.0, "cleave": false,
		"cuts": {0: Vector2(18, 10)} if not plus else {0: Vector2(18, 10), 2: Vector2(6, 14)}, "tint_k": 0.9, "drop": true})
	ForgeKit.canvas(parent, func(ci: CanvasItem) -> void:
		var ic := r.size.y + 4.0
		ForgeIcons.draw(ci, icon, Rect2(r.position.x - 10.0, r.position.y - 2.0, ic, ic))
		ForgeKit.draw_text_l(ci, value, "num", 32, Vector2(r.position.x + ic - 2.0, r.get_center().y), ForgeKit.TEXT)
		if plus:
			var b := Rect2(r.end.x - r.size.y + 6.0, r.position.y + 7.0, r.size.y - 14.0, r.size.y - 18.0)
			var bp := ForgeKit.shard(b, seed + 3, {"cuts": {1: Vector2(9, 4)}, "skew": 0.0})
			ForgeKit.draw_prism(ci, bp, ForgeKit.PRISMS["primary"], 4.0, 0.0, 0.0, false)
			ForgeIcons.draw(ci, "plus", Rect2(b.get_center() - Vector2(11, 11), Vector2(22, 22))))


## Level gem, settings shard and the currencies.
static func top_bar(parent: Node, o := {}) -> void:
	var lvl := str(o.get("level", "14"))
	ForgeKit.canvas(parent, func(ci: CanvasItem) -> void:
		# XP sliver under the gem: a cut bar.
		var bar := ForgeKit.shard(Rect2(58, 74, 92, 14), 901, {"cuts": {2: Vector2(10, 14)}, "skew": 0.0})
		ci.draw_colored_polygon(bar, Color("0B1030"))
		var fill := ForgeKit.shard(Rect2(58, 74, 60, 14), 902, {"cuts": {2: Vector2(10, 14)}, "skew": 0.0})
		ci.draw_polygon(fill, ForgeKit.grad_cols(fill, Rect2(58, 74, 60, 14), Color("BFF3FF"), Color("3CB8FF"), 0.9))
		ForgeKit.draw_rim(ci, bar, Color(0.75, 0.93, 1.0, 0.7), Color("05061A"), 1.0, 0.0)
		ForgeKit.draw_level_gem(ci, Vector2(58, 56), 40.0, lvl))
	# Settings shard.
	var sr := Rect2(112, 22, 62, 46)
	ForgeKit.canvas(parent, func(ci: CanvasItem) -> void:
		var p := ForgeKit.shard(sr, 77, {"cuts": {1: Vector2(14, 8)}, "skew": 0.0})
		ForgeKit.draw_prism(ci, p, ForgeKit.PRISMS["glass"], 6.0, 0.0, 0.0, false)
		ForgeIcons.draw(ci, "gear", Rect2(sr.get_center() - Vector2(17, 17), Vector2(34, 34))))
	var coins := str(o.get("coins", "2 590"))
	var gems := str(o.get("gems", "40"))
	currency(parent, Rect2(272, 22, 170, 54), "gem", gems, 31, true)
	currency(parent, Rect2(474, 22, 228, 54), "coin", coins, 32)


## Floating station shards (the bottom navigation). Only the active station carries its name.
static func nav(parent: Node, active: String, badges := {}) -> void:
	var slots := [84.0, 222.0, 360.0, 498.0, 636.0]
	ForgeKit.canvas(parent, func(ci: CanvasItem) -> void:
		# The horizon hairline the shards float over, broken under each shard, diamond ends.
		var y := 1251.0
		var c := Color(0.56, 0.9, 1.0, 0.32)
		ci.draw_line(Vector2(16, y), Vector2(704, y), c, 1.0, true)
		for x in [16.0, 704.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 5), Vector2(x + 4, y), Vector2(x, y + 5), Vector2(x - 4, y)]), Color(0.75, 0.95, 1.0, 0.8))
		for i in STATIONS.size():
			var st: Array = STATIONS[i]
			var x: float = slots[i]
			var is_on: bool = st[0] == active
			if is_on:
				var cp := ForgeKit.crystal_pts(Vector2(x, 1162), 112, 128, -0.03, 0.1)
				ForgeKit.draw_crystal(ci, cp, ForgeKit.PRISMS["primary"], 1.0, 14.0)
				ForgeIcons.draw(ci, st[1], Rect2(x - 32, 1130, 64, 64), false, ForgeIcons.DEEP if st[1] in ["gate", "anvil", "helm", "gear"] else [])
				var s := ForgeKit.fit_size(st[2], "label", 26, 170, 22)
				var bgw := ForgeKit.text_w(st[2], "label", s) + 40.0
				var lp := ForgeKit.shard(Rect2(x - bgw * 0.5, 1232, bgw, 38), 600 + i, {"cuts": {0: Vector2(14, 10), 2: Vector2(14, 10)}, "skew": 0.0})
				ci.draw_colored_polygon(lp, Color("0A0F2C"))
				ForgeKit.draw_chamfers(ci, lp, 5.0, 0.9)
				ForgeKit.draw_rim(ci, lp, Color(0.75, 0.95, 1.0, 0.9), Color("05061A"), 1.5, 0.0)
				ForgeKit.draw_text_c(ci, st[2], "label", s, Vector2(x, 1251), ForgeKit.RIM)
			else:
				var jit: float = [6.0, -5.0, 0.0, -7.0, 4.0][i]
				var tilt: float = [0.07, -0.05, 0.0, 0.06, -0.08][i]
				var cp2 := ForgeKit.crystal_pts(Vector2(x, 1176 + jit), 84, 96, tilt, 0.1)
				ForgeKit.draw_crystal(ci, cp2, ForgeKit.PRISMS["glass"], 0.0, 22.0 - jit)
				ForgeIcons.draw(ci, st[1], Rect2(x - 25, 1151 + jit, 50, 50))
			if badges.has(st[0]):
				var bx: float = x + (40.0 if is_on else 30.0)
				var by: float = 1112.0 if is_on else 1140.0 + [6.0, -5.0, 0.0, -7.0, 4.0][i]
				ForgeKit.draw_gem(ci, Vector2(bx, by), 17.0, 4, [Color("FFC7A8"), Color("FF6A3D"), Color("9C2410")], PI / 4.0, 0.62)
				ForgeKit.draw_text_c(ci, str(badges[st[0]]), "num", 22, Vector2(bx, by), Color.WHITE))


## A cut progress bar (parallelogram segments), filled `k` 0..1, `text` centred.
static func draw_bar(ci: CanvasItem, r: Rect2, k: float, text: String, full := false, col_a := Color("BFF3FF"), col_b := Color("3CB8FF")) -> void:
	var slant := r.size.y * 0.35
	var outer := PackedVector2Array([r.position + Vector2(slant, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x - slant, r.end.y), Vector2(r.position.x, r.end.y)])
	ci.draw_colored_polygon(outer, Color("070B22"))
	var segs := 8
	var gap := 4.0
	var inner := r.grow(-4.0)
	var sw := (inner.size.x - slant - gap * (segs - 1)) / segs
	var fill_n := k * segs
	for i in segs:
		var x0 := inner.position.x + i * (sw + gap)
		var seg := PackedVector2Array([Vector2(x0 + slant * 0.7, inner.position.y), Vector2(x0 + sw + slant * 0.7, inner.position.y), Vector2(x0 + sw, inner.end.y), Vector2(x0, inner.end.y)])
		var f := clampf(fill_n - i, 0.0, 1.0)
		if f >= 1.0:
			var a := col_a if not full else Color("FFFFFF")
			ci.draw_polygon(seg, PackedColorArray([a, a, col_b, col_b]))
		elif f > 0.0:
			ci.draw_colored_polygon(seg, Color(col_b.r, col_b.g, col_b.b, 0.35))
		else:
			ci.draw_colored_polygon(seg, Color(0.2, 0.26, 0.48, 0.45))
	ForgeKit.draw_rim(ci, outer, Color(0.75, 0.93, 1.0, 0.55), Color("05061A"), 1.0, 0.0)
	if text != "":
		ForgeKit.draw_text_oc(ci, text, "num", int(r.size.y * 0.74), r.get_center() + Vector2(slant * 0.1, 0), Color.WHITE, Color("05061A"), 7)
