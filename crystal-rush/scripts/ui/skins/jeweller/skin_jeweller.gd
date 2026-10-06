extends Control
## Dev-only mock-up of UI direction A «Ювелірна майстерня» (Celestial Jeweller).
## Renders one screen, saves a PNG and quits:
##   godot --path . --resolution 720x1280 res://scenes/dev/skin_jeweller.tscn -- --screen=home --out=<dir>
## Screens: home, arsenal, modal, specimen.
## The 2D UI is drawn into a 2x SubViewport and shown downsampled (the GL Compatibility
## renderer has no 2D MSAA), the 3D hub world renders behind it in the root viewport.

const W := 720.0
const H := 1280.0

var screen := "home"
var out_dir := "user://"
var ui: Control
var _sv: SubViewport
var _stage: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	_sv = SubViewport.new()
	_sv.size = Vector2i(int(W) * 2, int(H) * 2)
	_sv.size_2d_override = Vector2i(int(W), int(H))
	_sv.size_2d_override_stretch = true
	_sv.oversampling_override = 2.0
	_sv.transparent_bg = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sv)
	ui = Control.new()
	ui.size = Vector2(W, H)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv.add_child(ui)
	var tr := TextureRect.new()
	tr.texture = _sv.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	tr.material = pm
	tr.position = Vector2.ZERO
	tr.size = Vector2(W, H)
	add_child(tr)
	match screen:
		"home":
			await _home(false)
		"modal":
			await _home(true)
		"arsenal":
			await _arsenal()
		_:
			_specimen()
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("jeweller_%s.png" % screen)
	img.save_png(path)
	print("saved ", path)
	get_tree().quit(0)


# --- helpers -------------------------------------------------------------------------------
func _layer(p: Callable, mat: Material = null, parent: Control = null) -> JwUi.Layer:
	var l := JwUi.Layer.new(p, mat)
	l.position = Vector2.ZERO
	l.size = Vector2(W, H)
	(parent if parent else ui).add_child(l)
	return l


func _place(c: Control, pos: Vector2, sz: Vector2, parent: Control = null) -> Control:
	(parent if parent else ui).add_child(c)
	c.position = pos
	c.size = sz
	return c


func _enamel_bg(center: Vector2, opts := {}) -> void:
	var o := opts.duplicate()
	o["light"] = o.get("light", Vector2(W * 0.5, 160))
	o["light_r"] = o.get("light_r", 900.0)
	var m := JwUi.enamel_mat(center, Rect2(0, 0, W, H), o)
	_layer(func(ci: CanvasItem) -> void: Jw.fill(ci, PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), Color.WHITE), m)


func _thumbs(ids: Array) -> Dictionary:
	var out := {}
	var svc := MachineThumbs.service(get_tree())
	for id in ids:
		var t := MachineThumbs.get_thumb(self, id, false)
		if t:
			out[id] = t
	var guard := 0
	while out.size() < ids.size() and guard < 600:
		await get_tree().process_frame
		guard += 1
		for id in ids:
			if not out.has(id):
				var t := MachineThumbs.get_thumb(self, id, false)
				if t:
					out[id] = t
	if svc == null:
		push_warning("no thumbs service")
	return out


# --- screen 1: home -------------------------------------------------------------------------
func _home(modal: bool) -> void:
	_stage = HubStage.new()
	add_child(_stage)
	move_child(_stage, 0)
	# a little lower and closer than the live hub: the hero stands between sky and dial
	_stage.look_y = 0.7
	_stage.cam_h = 1.35
	_stage.cam_d = 3.8
	# top darkening so the tiara and title sit on night sky
	_layer(func(ci: CanvasItem) -> void:
		var top := Color(0.02, 0.02, 0.08, 0.75)
		var clear := Color(0.02, 0.02, 0.08, 0.0)
		ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 420), Vector2(0, 420)]),
			PackedColorArray([top, top, clear, clear]))
		var bot := Color(0.01, 0.01, 0.05, 0.0)
		var bot2 := Color(0.01, 0.01, 0.05, 0.6)
		ci.draw_polygon(PackedVector2Array([Vector2(0, 780), Vector2(W, 780), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([bot, bot, bot2, bot2]))
	)
	var world := JwUi.label("СВІТ 1", 26, Color("b9c3ea"))
	_place(world, Vector2(0, 142), Vector2(W, 32))
	var title := JwUi.GoldLabel.new("Орбітальна траса", 54)
	_place(title, Vector2(0, 168), Vector2(W, 70))
	var con := JwHub.Constellation.new()
	con.stars = [[Vector2(66, 96), 1, "done"], [Vector2(160, 46), 2, "done"], [Vector2(258, 104), 3, "done"], [Vector2(372, 56), 4, "current"]]
	con.boss_star = Vector2(586, 98)
	con.boss_pts = [
		[Vector2(500, 14), Vector2(522, 50), Vector2(560, 72)],
		[Vector2(672, 12), Vector2(648, 48), Vector2(612, 72)],
		[Vector2(560, 72), Vector2(550, 106), Vector2(586, 138), Vector2(622, 106), Vector2(612, 72), Vector2(560, 72)],
	]
	_place(con, Vector2(0, 240), Vector2(W, 230))
	# vault medallion
	var vault := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		var c := Vector2(48, 48)
		ci.draw_circle(c + Vector2(0, 4), 46, Color(0, 0, 0, 0.45), true, -1.0, true)
		Jw.gold_moulding(ci, Jw.regular(c, 44, 40), Jw.regular(c, 37, 40), 0.45)
		Jw.fill_ramp(ci, Jw.regular(c, 37, 40), Jw.ramp_tex("vault", [[0.0, Color("2a1f63")], [1.0, Color("0c0a26")]]), Vector2(0, 1))
		Jw.milgrain(ci, Jw.regular(c, 33, 60), 6.0, 1.0)
		JwArt.geode(ci, c + Vector2(0, 2), 25)
		# count lozenge
		var lr := Rect2(62, 2, 40, 30)
		Jw.gold_moulding(ci, Jw.lozenge(lr, 12), Jw.lozenge(lr.grow(-3), 10.5), 0.45)
		Jw.fill(ci, Jw.lozenge(lr.grow(-3), 10.5), Color("8c0f2a"))
		Jw.text_c(ci, Jw.num(), "2", lr.get_center() + Vector2(0, 1), 24, Jw.IVORY)
		Jw.text_c(ci, Jw.label(), "Сховище", Vector2(48, 116), 26, Color(0, 0, 0, 0.8))
		Jw.text_c(ci, Jw.label(), "Сховище", Vector2(48, 114), 26, Jw.GOLD_LIGHT)
	)
	_place(vault, Vector2(580, 600), Vector2(130, 140))
	var tiara := JwHub.Tiara.new()
	_place(tiara, Vector2.ZERO, Vector2(W, 170))
	var dial := JwHub.Astrolabe.new()
	_place(dial, Vector2.ZERO, Vector2(W, H))
	var play := JwUi.GemButton.new("ГРАТИ")
	play.text_size = 66
	play.chamfer = 26
	play.glints = [[Vector2(0.12, 0.16), 22.0], [Vector2(0.86, 0.78), 12.0]]
	_place(play, Vector2(172, 1104), Vector2(376, 138))
	var sub := JwUi.label("Рівень 4 · Орбітальна траса", 26, Color("c9d6ff"), Jw.label())
	_place(sub, Vector2(0, 1238), Vector2(W, 36))
	if modal:
		_modal()
	await get_tree().process_frame


# --- screen 3: modal (level reward) ---------------------------------------------------------
func _modal() -> void:
	var thumbs := await _thumbs(["mortar"])
	_layer(func(ci: CanvasItem) -> void:
		Jw.fill(ci, PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), Color(0.01, 0.015, 0.05, 0.78))
	)
	var r := Rect2(34, 214, W - 68, 820)
	JwUi.plate_shadow(ui, r, 30, 18)
	var plate := JwUi.Plate.new(30, "ice", {"center": Vector2(r.size.x * 0.5, 150), "light": Vector2(r.size.x * 0.5, 170), "light_r": 520.0, "vignette": 0.5})
	_place(plate, r.position, r.size)
	# crown of three star-gems over the top edge
	var crest := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		var c := Vector2(W * 0.5, 210)
		ci.draw_circle(c, 120, Color(0.5, 0.85, 1.0, 0.06), true, -1.0, true)
		ci.draw_circle(c, 70, Color(0.5, 0.85, 1.0, 0.08), true, -1.0, true)
		Jw.gold_rule(ci, Jw.arc(c + Vector2(0, 150), 210, -PI * 0.5 - 0.62, -PI * 0.5 + 0.62, 40), 8.0)
		for k in [-1, 1]:
			var p := c + Vector2(k * 104, 34)
			Jw.collet(ci, p, 22, "ice", 4)
			Jw.glint(ci, p + Vector2(-8, -8), 22)
		Jw.collet(ci, c + Vector2(0, -10), 34, "ice", 6)
		Jw.glint(ci, c + Vector2(-12, -24), 40)
		Jw.glint(ci, c + Vector2(20, 4), 16)
	)
	_place(crest, Vector2.ZERO, Vector2(W, H))
	var t := JwUi.GoldLabel.new("Перемога!", 76)
	_place(t, Vector2(0, 280), Vector2(W, 100))
	var st := JwUi.label("Рівень 4 · Орбітальна траса пройдена", 26, Color("c9d6ff"), Jw.body())
	_place(st, Vector2(0, 374), Vector2(W, 36))
	var h := JwUi.label("НАГОРОДА", 30, Jw.GOLD_LIGHT)
	_place(h, Vector2(0, 432), Vector2(W, 40))
	var rule := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		for sx in [-1.0, 1.0]:
			var a := Vector2(W * 0.5 + sx * 100, 452)
			var b := Vector2(W * 0.5 + sx * 250, 452)
			ci.draw_line(a, b, Color(Jw.GOLD_INK, 0.8), 3.0, true)
			ci.draw_line(a, b, Jw.gold(0.7), 1.4, true)
			Jw.fill(ci, Jw.regular(b + Vector2(sx * 6, 0), 5, 4), Jw.gold(0.8))
	)
	_place(rule, Vector2.ZERO, Vector2(W, H))
	# three reward medallions
	var items := [["coin", "+240", "Золото"], ["gem", "+5", "Кристали"], ["mortar", "×3", "Облогова мортира"]]
	for i in 3:
		var it: Array = items[i]
		var cx := 160.0 + i * 200.0
		var med := JwUi.Layer.new(func(ci: CanvasItem) -> void:
			var c := Vector2(cx, 560)
			var R := 74.0
			ci.draw_circle(c + Vector2(0, 6), R + 6, Color(0, 0, 0, 0.5), true, -1.0, true)
			Jw.gold_moulding(ci, Jw.regular(c, R, 48), Jw.regular(c, R - 9, 48), 0.45)
			var kind := "amethyst" if i == 2 else "sapphire"
			Jw.fill_ramp(ci, Jw.regular(c, R - 9, 48), Jw.ramp_tex("med_" + kind, [[0.0, Jw.gem(kind, 0.4)], [0.6, Jw.gem(kind, 0.15)], [1.0, Jw.gem(kind, 0.05)]]), Vector2(0, 1))
			Jw.milgrain(ci, Jw.regular(c, R - 15, 72), 6.5, 1.1)
			match it[0]:
				"coin":
					JwArt.coin(ci, c + Vector2(-12, -4), 26)
					JwArt.coin(ci, c + Vector2(12, 6), 30)
				"gem":
					Jw.brilliant(ci, c + Vector2(0, -2), 34, "ice")
					Jw.glint(ci, c + Vector2(-12, -16), 22)
				_:
					var tx: Texture2D = thumbs.get("mortar")
					if tx:
						ci.draw_texture_rect(tx, Rect2(c - Vector2(66, 70), Vector2(132, 132)), false)
			# amount plaque
			var pr := Rect2(c.x - 56, c.y + 52, 112, 40)
			Jw.fill(ci, Jw.lozenge(pr.grow_individual(0, -1, 0, 3), 14), Color(0, 0, 0, 0.5))
			Jw.gold_moulding(ci, Jw.lozenge(pr, 14), Jw.lozenge(pr.grow(-3), 12.5), 0.45)
			Jw.fill(ci, Jw.lozenge(pr.grow(-3), 12.5), Color("0b1030"))
			Jw.text_c(ci, Jw.num(), it[1], pr.get_center() + Vector2(0, 1), 30, Jw.ICE_WHITE)
		)
		_place(med, Vector2.ZERO, Vector2(W, H))
		var cap := JwUi.label(it[2], 26, Jw.IVORY, Jw.label())
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD
		_place(cap, Vector2(cx - 96, 668), Vector2(192, 70))
	var prim := JwUi.GemButton.new("ЗАБРАТИ")
	prim.text_size = 56
	prim.chamfer = 24
	prim.glints = [[Vector2(0.1, 0.2), 20.0]]
	_place(prim, Vector2(110, 790), Vector2(500, 130))
	var sec := JwUi.Cabochon.new("Подвоїти за рекламу")
	_place(sec, Vector2(130, 930), Vector2(460, 78))


# --- screen 2: arsenal ----------------------------------------------------------------------
func _arsenal() -> void:
	var ids := ["drone", "ballista", "mortar", "laser", "railgun", "prism"]
	var thumbs := await _thumbs(ids)
	_enamel_bg(Vector2(W * 0.5, 230), {"vignette": 0.6, "light": Vector2(W * 0.5, 240), "light_r": 700.0, "spacing": 10.0, "waves": 20.0})
	var tiara := JwHub.Tiara.new()
	tiara.crowns = "9"
	_place(tiara, Vector2.ZERO, Vector2(W, 170))
	var title := JwUi.GoldLabel.new("Арсенал", 58)
	_place(title, Vector2(0, 140), Vector2(W, 76))
	var cnt := JwUi.Lozenge.new("8/9", "sapphire")
	_place(cnt, Vector2(560, 156), Vector2(118, 46))
	var tabs := JwUi.Tabs.new()
	tabs.items = ["Машини", "Колода"]
	tabs.selected = 0
	tabs.badges = {1: "emerald"}
	_place(tabs, Vector2(80, 212), Vector2(W - 160, 74))
	var data := [
		["Дрон", "C", 6, Vector2i(8, 8), "", true],
		["Балиста", "C", 6, Vector2i(3, 8), "", false],
		["Облогова мортира", "R", 6, Vector2i(3, 3), "540", true],
		["Лазер", "R", 4, Vector2i(2, 5), "", false],
		["Рейкова гармата", "E", 3, Vector2i(1, 4), "", false],
		["Призма", "L", 2, Vector2i(0, 3), "", false],
	]
	var cw := (W - 24.0 - 24.0) / 3.0
	var ch := 316.0
	for i in data.size():
		var d: Array = data[i]
		var card := JwHub.Card.new()
		card.title = d[0]
		card.rarity = d[1]
		card.lvl = d[2]
		card.progress = d[3]
		card.upgrade_price = d[4]
		card.ready_dot = d[5]
		card.selected = d[4] != ""
		card.thumb = thumbs.get(ids[i])
		var col := i % 3
		var row := i / 3
		_place(card, Vector2(12 + col * (cw + 12), 300 + row * (ch + 14)), Vector2(cw, ch))
		card.setup()
	var dial := JwHub.Astrolabe.new()
	dial.active = 1
	dial.badges = {}
	_place(dial, Vector2.ZERO, Vector2(W, H))
	var play := JwUi.GemButton.new("ГРАТИ")
	play.text_size = 66
	play.chamfer = 26
	play.glints = [[Vector2(0.12, 0.16), 22.0]]
	_place(play, Vector2(172, 1104), Vector2(376, 138))
	var sub := JwUi.label("Рівень 4 · Орбітальна траса", 26, Color("c9d6ff"), Jw.label())
	_place(sub, Vector2(0, 1238), Vector2(W, 36))


# --- screen 4: specimen ------------------------------------------------------------------
func _specimen() -> void:
	_enamel_bg(Vector2(W * 0.5, -200), {"vignette": 0.5})
	var y := 22.0
	var t := JwUi.GoldLabel.new("Ювелірна майстерня", 58)
	_place(t, Vector2(0, y), Vector2(W, 80))
	y += 78
	var st := JwUi.label("ШРИФТИ · КНОПКИ · ВКЛАДКИ", 26, Jw.DIM)
	_place(st, Vector2(0, y), Vector2(W, 34))
	y += 44
	var pr := Rect2(24, y, W - 48, 250)
	JwUi.plate_shadow(ui, pr, 22)
	var plate := JwUi.Plate.new(22, "ice")
	_place(plate, pr.position, pr.size)
	var h1 := JwUi.GoldLabel.new("Кришталевий Ривок", 52, null, HORIZONTAL_ALIGNMENT_LEFT)
	_place(h1, Vector2(40, 20), Vector2(560, 70), plate)
	var h2 := JwUi.label("ЗАГОЛОВОК РОЗДІЛУ · МІТКА", 30, Jw.GOLD_LIGHT, Jw.label(), HORIZONTAL_ALIGNMENT_LEFT)
	_place(h2, Vector2(42, 92), Vector2(600, 40), plate)
	var body := JwUi.label("Їжак ґанок є’ — текст пластини.", 26, Jw.IVORY, Jw.body(), HORIZONTAL_ALIGNMENT_LEFT)
	_place(body, Vector2(42, 134), Vector2(600, 36), plate)
	var nums := JwUi.label("2 590 · 14 · ×2,5 · 08:41", 34, Jw.ICE_WHITE, Jw.num(), HORIZONTAL_ALIGNMENT_LEFT)
	_place(nums, Vector2(42, 178), Vector2(600, 44), plate)
	y += 270
	var cap := JwUi.label("ОСНОВНА · ЗВИЧ. / НАТИСН. / ВИМК.", 26, Jw.DIM)
	_place(cap, Vector2(0, y), Vector2(W, 30))
	y += 36
	var b1 := JwUi.GemButton.new("ГРАТИ")
	b1.text_size = 48
	b1.glints = [[Vector2(0.18, 0.2), 16.0]]
	_place(b1, Vector2(16, y), Vector2(236, 104))
	var b2 := JwUi.GemButton.new("ГРАТИ")
	b2.text_size = 48
	b2.state = "pressed"
	_place(b2, Vector2(250, y), Vector2(236, 104))
	var b3 := JwUi.GemButton.new("ГРАТИ")
	b3.text_size = 48
	b3.state = "disabled"
	_place(b3, Vector2(484, y), Vector2(220, 104))
	y += 116
	var bu := JwUi.GemButton.new("540")
	bu.icon = "coin"
	bu.font = Jw.num()
	bu.text_size = 40
	bu.chamfer = 16
	_place(bu, Vector2(16, y), Vector2(230, 86))
	var bc := JwUi.GemButton.new("ПОКРАЩИТИ ВСЕ", "citrine")
	bc.font = Jw.label()
	bc.text_size = 32
	bc.chamfer = 16
	_place(bc, Vector2(252, y), Vector2(452, 86))
	y += 100
	var cap2 := JwUi.label("ДРУГОРЯДНА · КАБОШОН У ДЖГУТІ", 26, Jw.DIM)
	_place(cap2, Vector2(0, y), Vector2(W, 30))
	y += 36
	var s1 := JwUi.Cabochon.new("Подвоїти нагороду")
	_place(s1, Vector2(16, y), Vector2(400, 76))
	var s2 := JwUi.Cabochon.new("Пізніше")
	s2.state = "pressed"
	_place(s2, Vector2(424, y), Vector2(280, 76))
	y += 82
	var s3 := JwUi.Cabochon.new("Недоступно")
	s3.state = "disabled"
	_place(s3, Vector2(16, y), Vector2(300, 76))
	var link := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		var f := Jw.label()
		Jw.text_engraved(ci, f, "Усі деталі", Vector2(150, 34), 28, Jw.GOLD_LIGHT)
		var w := Jw.text_w(f, "Усі деталі", 28)
		ci.draw_line(Vector2(150 - w * 0.5, 54), Vector2(150 + w * 0.5, 54), Jw.gold(0.7), 1.5, true)
		Jw.fill(ci, Jw.regular(Vector2(150 + w * 0.5 + 12, 54), 4, 4), Jw.gold(0.8))
	)
	_place(link, Vector2(400, y), Vector2(300, 76))
	y += 92
	var chips := [["Звичайна", "quartz"], ["Рідкісна", "sapphire"], ["Епічна", "amethyst"]]
	var x := 16.0
	for c in chips:
		var lz := JwUi.Lozenge.new(c[0], c[1])
		var w := Jw.text_w(Jw.label(), c[0], 26) + 70
		_place(lz, Vector2(x, y), Vector2(w, 48))
		x += w + 8
	y += 58
	var lz2 := JwUi.Lozenge.new("Легендарна", "citrine")
	_place(lz2, Vector2(16, y), Vector2(Jw.text_w(Jw.label(), "Легендарна", 26) + 70, 48))
	var cur := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		JwArt.tiara(ci, Vector2(30, 26), 22)
		Jw.text_c(ci, Jw.num(), "26", Vector2(84, 28), 32, Jw.IVORY)
		Jw.collet(ci, Vector2(150, 26), 15, "ice")
		Jw.text_c(ci, Jw.num(), "40", Vector2(202, 28), 32, Jw.IVORY)
		JwArt.coin(ci, Vector2(268, 26), 20)
		Jw.text_c(ci, Jw.num(), "2 590", Vector2(340, 28), 32, Jw.IVORY)
	)
	_place(cur, Vector2(290, y - 2), Vector2(420, 56))
	y += 64
	var bg := JwUi.Baguettes.new()
	bg.filled = 3
	bg.total = 5
	_place(bg, Vector2(16, y), Vector2(230, 40))
	var bl := JwUi.label("3/5", 28, Jw.IVORY, Jw.num())
	_place(bl, Vector2(250, y), Vector2(60, 40))
	var bg2 := JwUi.Baguettes.new()
	bg2.filled = 8
	bg2.total = 8
	bg2.kind = "emerald"
	_place(bg2, Vector2(318, y), Vector2(230, 40))
	var cp := JwUi.Layer.new(func(ci: CanvasItem) -> void:
		JwArt.compass(ci, Vector2(30, 22), 22)
		JwArt.geode(ci, Vector2(100, 22), 24)
	)
	_place(cp, Vector2(560, y - 2), Vector2(160, 50))
	y += 56
	var tabs := JwUi.Tabs.new()
	tabs.items = ["Машини", "Колода", "Реліквії"]
	tabs.selected = 0
	tabs.badges = {1: "emerald"}
	_place(tabs, Vector2(10, y), Vector2(W - 20, 76))
