extends CanvasLayer
## «Кришталева кузня» Arsenal: machine cards are glass shards, each with its rarity crystal
## set into the cleaved top-right corner (the chamfer glows in the rarity's species colour)
## and a burst of rarity light behind the real machine render. One card is ready to upgrade:
## it glows ice and its bar becomes an upgrade prism.

## id, name, rarity, family, level, blueprints text, fill, state ("", "upgrade", "locked")
const CARDS := [
	["mortar", "Облогова мортира", "R", "Кінетика", "6", "8/8", 1.0, "upgrade"],
	["prism", "Призма", "L", "Плазма", "4", "2/12", 0.17, ""],
	["railgun", "Рейкова гармата", "E", "Вольт", "3", "5/10", 0.5, ""],
	["laser", "Лазер", "R", "Плазма", "5", "6/8", 0.75, ""],
	["ballista", "Балиста", "C", "Кінетика", "5", "3/8", 0.375, ""],
	["gatling", "Гатлінг", "C", "Кінетика", "1", "", 0.0, "locked"],
]

var _root: Control


func _ready() -> void:
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	ForgeKit.backdrop(_root, Vector2(0.62, 0.16))


func _build() -> void:
	ForgeChrome.top_bar(_root, {"level": "14", "coins": "2 590", "gems": "40"})
	ForgeKit.label(_root, "КУЗНЯ МАШИН · 8 / 9", "label", 22, Color("8FEAFF"), Rect2(24, 96, 420, 30), HORIZONTAL_ALIGNMENT_LEFT, false)
	ForgeKit.headline(_root, "АРСЕНАЛ", Vector2(20, 122), 58, {"max_w": 460})
	# Deck switch (secondary prism).
	var dr := Rect2(500, 112, 204, 60)
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		var p := ForgeKit.shard(dr, 3101, {"cuts": {0: Vector2(22, 10), 2: Vector2(10, 24)}, "skew": 0.0})
		ForgeKit.draw_button(ci, p, "secondary", "КОЛОДА 3/3", {"size": 22, "depth": 7.0}))
	ForgeChrome.tabs(_root, Rect2(16, 196, 688, 56), ["Усі · 9", "Мої · 8", "Можна покращити · 2"], 0)
	for i in CARDS.size():
		var col := i % 2
		var row := i / 2
		_card(Rect2(16 + col * 352, 270 + row * 278, 336, 262), CARDS[i], i)
	ForgeChrome.nav(_root, "arsenal", {"arsenal": 2, "vault": 2})


func _card(r: Rect2, d: Array, i: int) -> void:
	var id: String = d[0]
	var rar: Array = ForgeKit.RARITY[d[2]]
	var state: String = d[7]
	var cut := Vector2(58, 34)
	var pts := ForgeKit.shard(r, 4000 + i * 13, {"cuts": {1: cut, 3: Vector2(14, 22 + (i % 3) * 6)}, "skew": 2.0 + (i % 2), "skew_edge": "bottom" if i % 2 == 0 else "top"})
	var ready := state == "upgrade"
	var locked := state == "locked"
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		if ready:
			ForgeKit.draw_glow(ci, ForgeKit.moved(pts, Vector2(0, 4)), Color("8FEAFF"), 1.5, 5, 4.0)
		ForgeKit.draw_drop(ci, ForgeKit.moved(pts, Vector2(0, 8)), 10.0, 0.4)
		ForgeKit.draw_slab_sides(ci, pts, 8.0, Color("3A64C0") if ready else Color("2A4C9C")))
	var species: Color = Color("1A2050").lerp(rar[2], 0.28) if not locked else Color("12152E")
	ForgeKit.add_glass(_root, pts, {"tint_k": 0.9 if not locked else 0.94, "tint_top": species})
	var thumb_c := Vector2(r.get_center().x + 8, r.position.y + 74)
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		# Rarity light: a burst of flat facets behind the machine, clipped to the card.
		if not locked:
			var n := 14
			for k in n:
				var a0 := TAU * float(k) / n + 0.13 * i
				var a1 := TAU * float(k + 1) / n + 0.13 * i
				var rr := 230.0 if k % 2 == 0 else 170.0
				var tri := PackedVector2Array([thumb_c, thumb_c + Vector2(cos(a0), sin(a0)) * rr, thumb_c + Vector2(cos(a1), sin(a1)) * rr * 0.92])
				var clip := Geometry2D.intersect_polygons(tri, pts)
				var c: Color = rar[1]
				c.a = 0.16 if k % 2 == 0 else 0.07
				for poly: PackedVector2Array in clip:
					ci.draw_colored_polygon(poly, c)
			# A pool of light under the machine.
			var pool := PackedVector2Array()
			for k in 16:
				var a := TAU * float(k) / 16.0
				pool.append(thumb_c + Vector2(0, 50) + Vector2(cos(a) * 96.0, sin(a) * 13.0))
			var pc: Color = rar[1]
			pc.a = 0.2
			ci.draw_colored_polygon(pool, pc)
		# Divider facet above the name plate.
		var y0 := r.position.y + 140.0
		var plate := Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2(r.position.x - 10, y0 + 6), Vector2(r.end.x + 10, y0 - 6), Vector2(r.end.x + 10, r.end.y + 40), Vector2(r.position.x - 10, r.end.y + 40)]))
		for poly: PackedVector2Array in plate:
			ci.draw_colored_polygon(poly, Color(0.02, 0.03, 0.1, 0.72))
		ci.draw_line(Vector2(r.position.x + 2, y0 + 6), Vector2(r.end.x - 2, y0 - 6), Color(0.7, 0.92, 1.0, 0.22), 1.0, true)
		# The machine render (silhouette when locked).
		var tex := MachineThumbs.get_thumb(_root, id, false)
		if tex:
			var tr := Rect2(thumb_c - Vector2(98, 100), Vector2(196, 196))
			if locked:
				ci.draw_texture_rect(tex, tr, false, Color(0.05, 0.06, 0.16, 0.95))
			else:
				ci.draw_texture_rect(tex, tr, false)
		# Chamfers and rims; the rarity corner glows in its species colour.
		ForgeKit.draw_chamfers(ci, pts, 8.0, 0.55)
		ForgeKit.draw_rim(ci, pts, ForgeKit.RIM if not ready else Color("FFFFFF"), Color("05061A"), 2.0 if not ready else 3.0)
		var c0 := Vector2(r.end.x - cut.x, r.position.y)
		var c1 := Vector2(r.end.x, r.position.y + cut.y)
		for p in pts:
			if absf(p.y - r.position.y) < 12.0 and absf(p.x - c0.x) < 2.0:
				c0 = p
			if absf(p.x - r.end.x) < 2.0 and absf(p.y - c1.y) < 12.0:
				c1 = p
		var nrm := -ForgeKit.edge_normal(c0, c1)
		var rc: Color = rar[1]
		ci.draw_polygon(PackedVector2Array([c0, c1, c1 + nrm * 26.0 + Vector2(0, 10), c0 + nrm * 26.0 + Vector2(-10, 0)]),
			PackedColorArray([rar[0], rar[0], Color(rc.r, rc.g, rc.b, 0.0), Color(rc.r, rc.g, rc.b, 0.0)]))
		ci.draw_line(c0, c1, rar[0], 3.0, true)
		var gc := c0.lerp(c1, 0.5) + nrm * 20.0
		var sides := int(rar[4])
		ForgeKit.draw_gem(ci, gc, 21.0, sides, [rar[0], rar[1], rar[2]], 0.0, 0.56)
		# Level gem.
		if not locked:
			ForgeKit.draw_level_gem(ci, r.position + Vector2(36, 38), 24.0, d[4])
		else:
			ForgeIcons.draw(ci, "lock", Rect2(thumb_c - Vector2(24, 34), Vector2(48, 48)))
		# Name and rarity line.
		var nx := r.position.x + 20.0
		var ny := r.position.y + 166.0
		var ns := ForgeKit.fit_size(d[1], "bold", 30, r.size.x - 40.0, 26)
		ForgeKit.draw_text_l(ci, d[1], "bold", ns, Vector2(nx, ny), ForgeKit.TEXT if not locked else ForgeKit.DIM)
		if locked:
			ForgeKit.draw_text_l(ci, "Відкриється на рівні 18", "body", 26, Vector2(nx, ny + 40), ForgeKit.DIM)
			return
		var rw := ForgeKit.draw_text_l(ci, str(rar[3]), "bold", 24, Vector2(nx, ny + 30), rar[1] if d[2] != "C" else Color("C4CCDA"))
		ForgeKit.draw_text_l(ci, " · " + str(d[3]), "body", 24, Vector2(nx + rw, ny + 30), ForgeKit.DIM)
		# Bar or upgrade prism.
		if ready:
			var br := Rect2(r.position.x + 16, r.end.y - 52, r.size.x - 32, 42)
			var bp := ForgeKit.shard(br, 4200 + i, {"cuts": {0: Vector2(18, 8), 2: Vector2(10, 20)}, "skew": 0.0})
			var top := ForgeKit.draw_prism(ci, bp, ForgeKit.PRISMS["primary"], 6.0, 0.0, 0.0)
			var tb := ForgeKit.bounds(top)
			var cy := tb.get_center().y
			var px := tb.end.x - 16.0
			var pw := ForgeKit.draw_text_r(ci, "540", "num", 28, Vector2(px, cy), ForgeKit.INK)
			ForgeIcons.draw(ci, "coin", Rect2(px - pw - 36, cy - 15, 30, 30))
			var avail := tb.size.x - 20.0 - (pw + 36.0 + 16.0) - 12.0
			var ls := ForgeKit.fit_size("ПОКРАЩИТИ", "bold", 26, avail, 20)
			ForgeKit.draw_text_l(ci, "ПОКРАЩИТИ", "bold", ls, Vector2(tb.position.x + 18, cy), ForgeKit.INK)
		else:
			ForgeChrome.draw_bar(ci, Rect2(r.position.x + 18, r.end.y - 42, r.size.x - 36, 28), float(d[6]), d[5]))


func prepared() -> void:
	for c: Array in CARDS:
		MachineThumbs.get_thumb(_root, c[0], false)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	_build()
	for i in 4:
		await get_tree().process_frame
