class_name JwHub
## «Ювелірна майстерня» hub pieces: the tiara top bar, the constellation level path, the
## astrolabe navigation dial and the machine card.


## Top bar as a tiara: one enamel band hanging from the top edge with a gold moulding along
## its curved lower edge; the profile is a cameo, the currencies are gems set into the band.
class Tiara extends Control:
	var crowns := "26"
	var gems := "40"
	var coins := "2 590"
	var level := "14"
	var _en: JwUi.Layer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_en = JwUi.Layer.new(_paint_band)
		_en.show_behind_parent = true
		add_child(_en)
		resized.connect(func() -> void:
			_en.size = size
			_en.material = JwUi.enamel_mat(Vector2(size.x * 0.5, -420), Rect2(Vector2.ZERO, Vector2(size.x, 130)),
				{"spacing": 7.0, "waves": 36.0, "amp": 0.4, "vignette": 0.25, "light": Vector2(size.x * 0.5, 0), "light_r": 520.0})
		)

	func edge_y(x: float) -> float:
		var u := (x - size.x * 0.5) / (size.x * 0.5)
		return 100.0 + 16.0 * (1.0 - u * u)

	func _edge(off: float, x0 := 0.0, x1 := -1.0) -> PackedVector2Array:
		if x1 < 0:
			x1 = size.x
		var p := PackedVector2Array()
		for k in 49:
			var x := lerpf(x0, x1, k / 48.0)
			p.append(Vector2(x, edge_y(x) + off))
		return p

	func _paint_band(ci: CanvasItem) -> void:
		var p := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
		var e := _edge(0)
		e.reverse()
		p.append_array(e)
		Jw.fill(ci, p, Color.WHITE)

	func _draw() -> void:
		# shadow cast by the band onto the world
		for k in 6:
			var sh := _edge(4.0 + k * 3.0)
			draw_polyline(sh, Color(0, 0, 0.03, 0.1), 6.0, true)
		Jw.milgrain(self, _edge(-13.0, 150, size.x - 90), 7.0, 1.2, false)
		Jw.gold_rule(self, _edge(-3.0), 9.0)
		# festoons: swags of tiny pearls hanging between the pendants
		var knots := [124.0, 262.0, 402.0, 590.0, 712.0]
		for k in knots.size() - 1:
			var xa: float = knots[k]
			var xb: float = knots[k + 1]
			var sw := PackedVector2Array()
			for q in 25:
				var t := q / 24.0
				var x := lerpf(xa, xb, t)
				sw.append(Vector2(x, edge_y(x) + 6.0 + 15.0 * 4.0 * t * (1.0 - t)))
			for v in Jw.resample(sw, 5.5, false):
				draw_circle(v + Vector2(0, 0.8), 1.7, Color(0, 0, 0.05, 0.5), true, -1.0, true)
				draw_circle(v, 1.6, Color("e8e2f0"), true, -1.0, true)
				draw_circle(v + Vector2(-0.4, -0.5), 0.6, Color(1, 1, 1), true, -1.0, true)
		# pendants: little marquise drops hanging off the band between settings
		for x in [262.0, 402.0, 590.0]:
			var y := edge_y(x) + 2.0
			Jw.prong(self, Vector2(x, y - 2), Vector2(x, y + 8), 5)
			Jw.marquise(self, Vector2(x, y + 18), 22, 10, PI * 0.5, "ice")
		# cameo + level lozenge
		JwArt.cameo(self, Vector2(66, 70), 44, 54)
		var lr := Rect2(30, 118, 72, 34)
		Jw.fill(self, Jw.lozenge(lr.grow_individual(0, -1, 0, 3), 14), Color(0, 0, 0, 0.5))
		Jw.gold_moulding(self, Jw.lozenge(lr, 14), Jw.lozenge(lr.grow(-3), 12.5), 0.45)
		Jw.fill_ramp(self, Jw.lozenge(lr.grow(-3), 12.5), Jw.ramp_tex("lvl", [[0.0, Color("2b1a6a")], [1.0, Color("120a33")]]), Vector2(0, 1))
		Jw.text_c(self, Jw.num(), level, lr.get_center() + Vector2(0, 1), 26, Jw.GOLD_LIGHT)
		# currencies set into the band
		var f := Jw.num()
		var cy := 58.0
		JwArt.tiara(self, Vector2(186, cy + 2), 21)
		_num(f, crowns, Vector2(214, cy))
		Jw.collet(self, Vector2(328, cy), 15, "ice")
		_num(f, gems, Vector2(356, cy))
		JwArt.coin(self, Vector2(462, cy), 21)
		_num(f, coins, Vector2(492, cy))
		JwArt.compass(self, Vector2(size.x - 46, cy), 24)

	func _num(f: Font, s: String, left: Vector2) -> void:
		var w := Jw.text_w(f, s, 34)
		Jw.text_engraved(self, f, s, left + Vector2(w * 0.5, 0), 34, Jw.IVORY, Color(0, 0, 0, 0.8), Color(0.6, 0.7, 1.0, 0.12))


## Level path as a constellation: one constellation per world, its stars are the levels
## (cleared = lit brilliants, current = pulsing, next = hollow), the boss is a named figure.
class Constellation extends Control:
	var stars: Array = []      # [pos, number, state "done"|"current"|"next"]
	var boss_name := "Рогатий"
	var boss_pts: Array = []   # figure outline, local px
	var boss_star := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := Jw.num()
		# boss figure: engraved hairlines between faint stars
		for seg in boss_pts:
			var pl := PackedVector2Array(seg)
			draw_polyline(pl, Color(0.95, 0.55, 0.55, 0.16), 6.0, true)
			draw_polyline(pl, Color(1.0, 0.72, 0.62, 0.7), 1.6, true)
			for v in pl:
				draw_circle(v, 3.0, Color(1.0, 0.85, 0.8, 0.9), true, -1.0, true)
		# path
		for i in stars.size() - 1:
			var a: Vector2 = stars[i][0]
			var b: Vector2 = stars[i + 1][0]
			var done: bool = stars[i + 1][2] != "next"
			if done:
				draw_line(a, b, Color(0, 0, 0, 0.4), 4.0, true)
				draw_line(a, b, Jw.gold(0.75), 2.0, true)
			else:
				var n := int(a.distance_to(b) / 9.0)
				for k in n:
					draw_circle(a.lerp(b, (k + 0.5) / n), 1.6, Color(Jw.GOLD_LIGHT, 0.7), true, -1.0, true)
		var last: Vector2 = stars[stars.size() - 1][0]
		var n2 := int(last.distance_to(boss_star) / 9.0)
		for k in n2:
			draw_circle(last.lerp(boss_star, (k + 0.5) / n2), 1.6, Color(1.0, 0.75, 0.7, 0.7), true, -1.0, true)
		for s in stars:
			var p: Vector2 = s[0]
			var st: String = s[2]
			if st == "current":
				for k in 4:
					draw_circle(p, 44.0 - k * 8.0, Color(0.45, 0.8, 1.0, 0.05 + k * 0.03), true, -1.0, true)
				draw_arc(p, 30.0, 0, TAU, 64, Color(0.7, 0.95, 1.0, 0.45), 1.4, true)
				Jw.collet(self, p, 15, "ice", 4)
				Jw.glint(self, p + Vector2(-7, -8), 26, Color(0.85, 0.97, 1.0))
				var lc := p + Vector2(0, 46)
				Jw.text_c(self, f, str(s[1]), lc + Vector2(0, 2), 32, Color(0, 0, 0, 0.8))
				Jw.text_c(self, f, str(s[1]), lc, 32, Jw.GOLD_LIGHT)
			else:
				JwArt.star(self, p, 8.0 if st == "done" else 9.0, st == "done")
				var lc := p + Vector2(0, 32)
				Jw.text_c(self, f, str(s[1]), lc + Vector2(0, 2), 26, Color(0, 0, 0, 0.8))
				Jw.text_c(self, f, str(s[1]), lc, 26, Jw.IVORY if st == "done" else Jw.DIM)
		# boss star + name
		draw_circle(boss_star, 30, Color(0.9, 0.2, 0.25, 0.1), true, -1.0, true)
		Jw.glint(self, boss_star, 30, Color(1.0, 0.75, 0.75))
		Jw.collet(self, boss_star, 12, "ruby", 3)
		var bn := boss_star + Vector2(0, 52)
		var df := Jw.display()
		Jw.text_c(self, df, boss_name, bn + Vector2(0, 2), 30, Color(0, 0, 0, 0.85))
		Jw.text_c(self, df, boss_name, bn, 30, Color("ffb8a8"))


## Navigation as a half-astrolabe: a gold limb with degree ticks, an enamel label band with
## the five destinations engraved on it, a rete of hairline gold inside, the alidade
## (pointer with a marquise) swung to the active destination, and the ГРАТИ gem at the hub.
class Astrolabe extends Control:
	var items: Array = ["Магазин", "Арсенал", "Гра", "Герої", "Казарми"]
	var active := 2
	var center := Vector2(360, 1390)
	var radius := 428.0
	var step_deg := 28.0
	var badges := {1: "emerald"}
	var _en: JwUi.Layer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_en = JwUi.Layer.new(_paint_enamel)
		_en.show_behind_parent = true
		add_child(_en)
		resized.connect(func() -> void:
			_en.size = size
			_en.material = JwUi.enamel_mat(center, Rect2(Vector2(0, center.y - radius), Vector2(size.x, radius)),
				{"spacing": 8.0, "waves": 24.0, "amp": 0.45, "rays": 72.0, "vignette": 0.0, "light": center + Vector2(-80, -radius * 0.8), "light_r": radius * 1.1})
		)

	func _paint_enamel(ci: CanvasItem) -> void:
		Jw.fill(ci, Jw.regular(center, radius - 2, 128), Color.WHITE)

	func _ang(i: int) -> float:
		return deg_to_rad((i - 2) * step_deg)

	func _draw() -> void:
		var c := center
		var R := radius
		# shadow ring onto the world
		for k in 6:
			draw_arc(c, R + 4 + k * 4, PI, TAU, 128, Color(0, 0, 0.03, 0.12), 6.0, true)
		# limb
		Jw.gold_moulding(self, Jw.regular(c, R, 160), Jw.regular(c, R - 12, 160), 0.4)
		# tick band
		var tb_o := R - 12.0
		var tb_i := R - 30.0
		Jw.fill(self, _ring(c, tb_o, tb_i), Color(0.02, 0.03, 0.09, 0.55))
		for d in range(-90, 91, 3):
			var a := deg_to_rad(d) - PI * 0.5
			var u := Vector2(cos(a), sin(a))
			var long := d % 15 == 0
			var l0 := tb_o - 1.0
			var l1 := tb_o - (13.0 if long else 6.0)
			draw_line(c + u * l0, c + u * l1, Jw.gold(0.75 if long else 0.6), 2.0 if long else 1.2, true)
		draw_arc(c, tb_i, PI, TAU, 160, Color(Jw.GOLD_INK, 0.8), 3.0, true)
		draw_arc(c, tb_i, PI, TAU, 160, Jw.gold(0.7), 1.4, true)
		# label band rim (inner)
		var lb_i := R - 82.0
		Jw.gold_moulding(self, Jw.regular(c, lb_i, 160), Jw.regular(c, lb_i - 9, 160), 0.45)
		Jw.milgrain(self, Jw.arc(c, lb_i + 6, PI * 1.02, PI * 1.98, 160), 7.0, 1.2, false)
		# rete: an off-centre ecliptic ring, star pointers and a hairline cross
		var rin := lb_i - 9
		draw_arc(c + Vector2(0, -rin * 0.28), rin * 0.66, PI * 1.03, TAU * 0.985, 96, Color(Jw.GOLD, 0.55), 1.6, true)
		draw_arc(c, rin * 0.5, PI, TAU, 96, Color(Jw.GOLD, 0.35), 1.2, true)
		for d in [-62.0, -24.0, 24.0, 62.0]:
			var a := deg_to_rad(d) - PI * 0.5
			var u := Vector2(cos(a), sin(a))
			var p0 := c + u * rin * 0.5
			var p1 := c + u * (rin - 18)
			draw_line(p0, p1, Color(Jw.GOLD, 0.45), 1.3, true)
			var s := Vector2(-u.y, u.x)
			Jw.fill(self, PackedVector2Array([p1 - s * 4, p1 + u * 14, p1 + s * 4]), Jw.gold(0.75))
			draw_circle(p1 + u * 3, 3.0, Jw.gem("ice", 0.85), true, -1.0, true)
		# labels engraved along the band, rotated with it
		var f := Jw.label()
		var lr := (tb_i + lb_i) * 0.5
		for i in items.size():
			var a := _ang(i)
			var p := c + Vector2(sin(a), -cos(a)) * lr
			var on := i == active
			var sz := 29 if on else 27
			draw_set_transform(p, a)
			var s: String = items[i]
			if on:
				Jw.text_engraved(self, f, s, Vector2.ZERO, sz, Jw.GOLD_LIGHT, Color(0, 0, 0, 0.9), Color(1, 0.9, 0.6, 0.2))
			else:
				Jw.text_engraved(self, f, s, Vector2.ZERO, sz, Color("c39a52"), Color(0, 0, 0, 0.9), Color(1, 0.9, 0.6, 0.08))
			if badges.has(i):
				var w := Jw.text_w(f, s, sz)
				Jw.octagem(self, Vector2(w * 0.5 + 12, -10), 7, badges[i])
			draw_set_transform(Vector2.ZERO)
			# separators between labels
			if i < items.size() - 1:
				var a2 := deg_to_rad((i - 2 + 0.5) * step_deg)
				var q := c + Vector2(sin(a2), -cos(a2)) * lr
				draw_set_transform(q, a2)
				Jw.fill(self, Jw.lozenge(Rect2(-4, -9, 8, 18), 0.1), Jw.gold(0.7))
				Jw.fill(self, Jw.regular(Vector2.ZERO, 4, 4), Jw.gold(0.7))
				draw_set_transform(Vector2.ZERO)
		# alidade: marquise pointer on the limb at the active destination
		var aa := _ang(active)
		var u2 := Vector2(sin(aa), -cos(aa))
		var tip := c + u2 * (R + 10)
		draw_set_transform(tip, aa)
		Jw.prong(self, Vector2(-16, 4), Vector2(-6, 14), 5)
		Jw.prong(self, Vector2(16, 4), Vector2(6, 14), 5)
		Jw.fill(self, PackedVector2Array([Vector2(-14, 8), Vector2(0, 34), Vector2(14, 8)]), Jw.gold(0.5))
		Jw.fill(self, PackedVector2Array([Vector2(-14, 8), Vector2(0, 34), Vector2(0, 8)]), Jw.gold(0.85))
		Jw.marquise(self, Vector2(0, 2), 40, 18, PI * 0.5, "ice")
		Jw.glint(self, Vector2(-4, -6), 14)
		draw_set_transform(Vector2.ZERO)

	func _ring(c: Vector2, ro: float, ri: float) -> PackedVector2Array:
		var p := Jw.arc(c, ro, PI, TAU, 96)
		var q := Jw.arc(c, ri, TAU, PI, 96)
		p.append_array(q)
		return p


## Machine card: a prong-set plate in the machine's rarity gem, the render on a light pool,
## the name, a shield level badge and baguette progress (or an upgrade gem button).
class Card extends Control:
	var title := ""
	var rarity := "C"
	var lvl := 1
	var progress := Vector2i(3, 5)
	var thumb: Texture2D
	var upgrade_price := ""      # non-empty: show the upgrade gem button
	var ready_dot := false
	var selected := false
	var _en: JwUi.Layer
	var _btn: JwUi.GemButton

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_en = JwUi.Layer.new(func(ci: CanvasItem) -> void:
			Jw.fill(ci, Jw.notched(Rect2(Vector2(2, 2), size - Vector2(4, 4)), 16), Color.WHITE))
		_en.show_behind_parent = true
		add_child(_en)
		resized.connect(_layout)

	func setup() -> void:
		var k: String = Jw.RARITY_GEM[rarity]
		var glow := Jw.gem(k, 0.42)
		_en.size = size
		_en.material = JwUi.enamel_mat(Vector2(size.x * 0.5, size.y * 0.32), Rect2(Vector2.ZERO, size),
			{"spacing": 6.0, "waves": 12.0, "amp": 0.5, "rays": 48.0, "vignette": 0.7,
			 "glow_col": glow, "light": Vector2(size.x * 0.5, size.y * 0.32), "light_r": size.x * 0.75,
			 "line_col": Jw.gem(k, 0.3), "base": Color("0d1230")})
		if upgrade_price != "":
			_btn = JwUi.GemButton.new(upgrade_price)
			_btn.icon = "coin"
			_btn.font = Jw.num()
			_btn.text_size = 34
			_btn.chamfer = 13
			_btn.glints = [[Vector2(0.15, 0.25), 12.0]]
			add_child(_btn)
		_layout()

	func _layout() -> void:
		if _en:
			_en.size = size
		if _btn:
			_btn.position = Vector2(6, size.y - 80)
			_btn.size = Vector2(size.x - 12, 74)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var k: String = Jw.RARITY_GEM[rarity]
		if selected:
			for i in 5:
				Jw.fill(self, Jw.notched(r.grow(12 - i * 2.4), 14 + 12 - i * 2.4), Color(0.55, 0.9, 1.0, 0.06))
		# machine render on its light pool (cropped: the thumbs carry generous padding)
		var div_y := 172.0
		if thumb:
			var ts := size.x - 16
			draw_texture_rect_region(thumb, Rect2(Vector2(8, div_y - ts + 2), Vector2(ts, ts)), Rect2(34, 18, 188, 188))
		Jw.plate_frame(self, r, 14, 5.0, k, false)
		# divider with a set gem
		var dl := PackedVector2Array([Vector2(16, div_y), Vector2(size.x - 16, div_y)])
		draw_polyline(dl, Color(Jw.GOLD_INK, 0.8), 3.0, true)
		draw_polyline(dl, Jw.gold(0.7), 1.3, true)
		Jw.fill(self, Jw.regular(Vector2(size.x * 0.5, div_y), 7, 4), Jw.gold(0.85))
		Jw.octagem(self, Vector2(size.x * 0.5, div_y), 4.2, k)
		# name: fixed two-line block
		var f := Jw.label()
		var words := title.split(" ")
		var lines: Array[String] = [title]
		if Jw.text_w(f, title, 27) > size.x - 24 and words.size() > 1:
			lines = [words[0], " ".join(words.slice(1))]
		var ly := div_y + 36.0 if lines.size() == 1 else div_y + 22.0
		for s in lines:
			Jw.text_c(self, f, s, Vector2(size.x * 0.5, ly + 2), 27, Color(0, 0, 0, 0.8))
			Jw.text_c(self, f, s, Vector2(size.x * 0.5, ly), 27, Jw.IVORY)
			ly += 29
		# level shield badge (top-left)
		var sr := Rect2(12, 12, 42, 52)
		Jw.fill(self, Jw.shield(sr.grow(2).grow_individual(0, -1, 0, 3)), Color(0, 0, 0, 0.5))
		Jw.gold_moulding(self, Jw.shield(sr), Jw.shield(sr.grow(-4)), 0.45)
		Jw.fill_ramp(self, Jw.shield(sr.grow(-4)), Jw.ramp_tex("shield_" + k, [[0.0, Jw.gem(k, 0.4)], [1.0, Jw.gem(k, 0.12)]]), Vector2(0, 1))
		Jw.text_c(self, Jw.num(), str(lvl), sr.get_center() + Vector2(0, -3), 28, Jw.IVORY)
		if ready_dot:
			Jw.collet(self, Vector2(size.x - 30, 32), 10, "emerald", 4)
			Jw.glint(self, Vector2(size.x - 36, 26), 14, Color(0.8, 1.0, 0.9))
		# footer: count + baguette channel
		if upgrade_price == "":
			var full := progress.x >= progress.y
			var lab := "%d/%d" % [progress.x, progress.y]
			var nf := Jw.num()
			var lw := Jw.text_w(nf, lab, 26)
			Jw.text_c(self, nf, lab, Vector2(16 + lw * 0.5, size.y - 37), 26, Jw.IVORY if full else Jw.DIM)
			var bars := Rect2(24 + lw, size.y - 54, size.x - 38 - lw, 34)
			_baguettes(bars, progress.x, progress.y, "emerald" if full else "ice")

	func _baguettes(r: Rect2, filled: int, total: int, kind: String) -> void:
		Jw.fill(self, Jw.chamfer(r.grow_individual(0, -1, 0, 3), 4), Color(0, 0, 0, 0.5))
		Jw.gold_moulding(self, Jw.chamfer(r, 5), Jw.chamfer(r.grow(-3), 3.8), 0.45)
		var inner := r.grow(-4)
		Jw.fill(self, Jw.chamfer(inner, 3), Color("070a1c"))
		var gap := 3.0
		var n := total
		var bw := (inner.size.x - gap * (n + 1)) / n
		for i in n:
			var br := Rect2(inner.position + Vector2(gap + i * (bw + gap), 3), Vector2(bw, inner.size.y - 6))
			if i < filled:
				Jw.emerald_cut(self, br, 2.0, kind, false, PackedFloat32Array([0.0, 0.22]))
			else:
				Jw.fill(self, Jw.chamfer(br, 2.0), Color("151a36"))
				Jw.line(self, Jw.chamfer(br, 2.0), Color("2a3160"), 1.0)
