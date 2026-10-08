extends Node
## UI v2 specimen (design-system foundation): every primitive on a light warm ground, over a
## painted dawn scene, and over the real 3D hub stage. Saves one PNG per page, then quits.
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##     --resolution 720x1280 res://scenes/dev/ui_specimen.tscn -- --out=DIR --tag=720 [--pages=a,b] [--level=3] [--nokit]
## Pages: base (surfaces, type, buttons, tabs), widgets (plates, sockets, progress, rows, modal,
## bands), cards (the five gem cards), icons (line + painted sets), home (home layout over a
## painted dawn scene), hud (run HUD over the scene), stage (home layout over the real 3D stage).

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/uiv2/shots/foundation"
var tag := "720"
var pages: Array[String] = ["base", "widgets", "cards", "icons", "home", "hud", "stage"]
var level := 3
var ui: Control
var layer: CanvasLayer
var vp := Vector2(720, 1280)
var _stage: Node3D
var _hold := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out_dir = v
			"tag": tag = v
			"level": level = maxi(1, int(v))
			"nokit": UIKit.kit_enabled = false
			"hold": _hold = true
			"pages":
				pages.clear()
				for p in v.split(",", false):
					pages.append(p)
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.readonly = true
	Loc.set_language("uk", false)
	Meta.account = Meta.synthetic_account(level, "expected")
	layer = CanvasLayer.new()
	add_child(layer)
	await get_tree().process_frame
	vp = get_viewport().get_visible_rect().size
	for p in pages:
		await _page(p)
	if not _hold:
		get_tree().quit(0)


func _new_root(bg := "light") -> Control:
	if ui:
		ui.queue_free()
	if _stage and bg != "stage":
		_stage.queue_free()
		_stage = null
	ui = Control.new()
	ui.theme = UIKit.theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.size = vp
	layer.add_child(ui)
	if bg == "light":
		var g := _Backdrop.new()
		g.mode = "light"
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(g)
	elif bg == "scene":
		var g2 := _Backdrop.new()
		g2.mode = "scene"
		g2.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(g2)
	elif bg == "stage" and _stage == null:
		_stage = HubStage.new()
		add_child(_stage)
	return ui


func _shot(name: String, wait := 0.9) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/specimen_%s_%s.png" % [out_dir, name, tag]
	img.save_png(path)
	print("SPECIMEN saved ", path)


func _page(p: String) -> void:
	match p:
		"base": _page_base()
		"widgets": _page_widgets()
		"cards": _page_cards()
		"icons": _page_icons()
		"home": _page_home("scene")
		"hud": _page_hud()
		"stage": _page_home("stage")
	await _shot(p, 2.2 if p == "stage" else 0.9)


func _col(x := 24.0, y := 24.0, sep := 14.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(x, y)
	v.size = Vector2(vp.x - x * 2.0, 0)
	v.add_theme_constant_override("separation", int(sep))
	ui.add_child(v)
	return v


func _row(parent: Control, sep := 12.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(sep))
	parent.add_child(h)
	return h


# ------------------------------------------------------------------ pages

func _page_base() -> void:
	_new_root("light")
	var v := _col(24, 28, 16)
	v.add_child(UIKit.caps("Crystal Rush · UI v2 · специмен"))
	v.add_child(UIKit.gradient_heading("Кришталевий Ривок", 46))
	var body := UIKit.label("Кремові панелі, одна золота лінія, м’які тіні, гранований зріз кутів. Шрифт M PLUS Rounded 1c: і ї є ґ ’ « » — №.", 22, UIKit.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = vp.x - 48
	v.add_child(body)
	# Palette swatches
	var sw := _row(v, 8)
	for c: Array in [["paper_0", UITokens.PAPER_0], ["paper_1", UITokens.PAPER_1], ["paper_2", UITokens.PAPER_2], ["paper_3", UITokens.PAPER_3],
			["hairline", UITokens.HAIRLINE], ["ink", UITokens.INK], ["taupe", UITokens.INK_DIM], ["amber", UITokens.CTA]]:
		var s := _Swatch.new()
		s.col = c[1]
		s.label = c[0]
		s.custom_minimum_size = Vector2(76, 70)
		sw.add_child(s)
	v.add_child(UIKit.divider(vp.x - 48))
	# Panel with typography
	var p := UIKit.panel("panel")
	v.add_child(p)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	p.add_child(pv)
	pv.add_child(UIKit.section("Атрибути"))
	var hr := _row(pv, 18)
	var lvl := VBoxContainer.new()
	lvl.add_theme_constant_override("separation", -6)
	lvl.add_child(UIKit.caps("Рів."))
	var num := _row(lvl, 6)
	num.add_child(UIKit.number("23", 64))
	var of := UIKit.label("/ 30", 26, UIKit.INK_DIM, true)
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	num.add_child(of)
	hr.add_child(lvl)
	var pw := VBoxContainer.new()
	pw.add_theme_constant_override("separation", -2)
	pw.add_child(UIKit.caps("Сила"))
	pw.add_child(UIKit.number("12 480", 44))
	hr.add_child(pw)
	pv.add_child(UIKit.list_row("Здоров’я", "1 288", "cls_guardian"))
	pv.add_child(UIKit.list_row("Атака", "66  +4", "cls_warrior"))
	# Buttons
	v.add_child(UIKit.cta_button("ГРАТИ", "Рівень 14", Vector2(448, 104), 42))
	var br := _row(v, 14)
	br.add_child(UIKit.cta_button("Покращити", "", Vector2(290, 84), 30))
	var c2 := UIKit.styled_button("1 260", "green", Vector2(170, 72), 28)
	br.add_child(c2)
	var dis := UIKit.cta_button("Забрати", "", Vector2(180, 72), 26)
	dis.topaz = false
	dis.disabled = true
	br.add_child(dis)
	var br2 := _row(v, 14)
	br2.add_child(UIKit.secondary_button("Деталі", "info", Vector2(230, 68)))
	br2.add_child(UIKit.button("Авто-колода", false, 230))
	br2.add_child(UIKit.text_button("Скасувати"))
	# Tabs
	v.add_child(UIKit.tabs([["a", "Атрибути"], ["n", "Навички"], ["s", "Спорядження"], ["z", "Грані"]], "n", Callable(), 24))
	v.add_child(UIKit.segmented([["h", "Герої"], ["c", "Чемпіони"], ["f", "Подвиги"]], "h", func(_id: String): pass, 60.0, 24))


func _page_widgets() -> void:
	_new_root("light")
	var v := _col(24, 28, 16)
	v.add_child(UIKit.caps("Плашки, гнізда, прогрес, рядки"))
	var tr := _row(v, 14)
	tr.add_child(UIKit.currency_plate("coin", "12 480", true, 200))
	tr.add_child(UIKit.currency_plate("gem", "320", false, 160))
	tr.add_child(UIKit.currency_plate("crown", "26", false, 140))
	var tp := UIKit.title_plate("Світ 2 · Луки · Рівень 14", 420, false)
	tp.accent = "Луки"
	var tph := CenterContainer.new()
	tph.add_child(tp)
	v.add_child(tph)
	var er := _row(v, 18)
	for ic: String in ["events", "mail", "quests", "chest", "settings", "close"]:
		var b := UIKit.edge_button(ic, 34.0, "!" if ic == "chest" else ("3" if ic == "mail" else ""))
		er.add_child(b)
	var sr := _row(v, 12)
	for k: String in ["cls_warrior", "cls_ranger", "cls_mage", "cls_guardian", "cls_healer"]:
		sr.add_child(UIKit.socket(k, 56))
	sr.add_child(UIKit.gap(8))
	for k: String in ["el_volt", "el_frost", "el_plasma"]:
		sr.add_child(UIKit.socket(k, 56, true))
	var bd := _row(v, 12)
	bd.add_child(UIKit.notify_badge("!"))
	bd.add_child(UIKit.notify_badge("12"))
	bd.add_child(UIKit.new_tag("Новий"))
	var pr1 := UIKit.progress(26, 40, 420, 12)
	pr1.text = "26 / 40"
	v.add_child(pr1)
	v.add_child(UIKit.progress(5, 8, 420, 14, 8))
	var pr3 := UIKit.progress(1, 1, 300, 10)
	pr3.text = "МАКС"
	v.add_child(pr3)
	# Glass panel over a "3D" strip + toast
	var strip := _Backdrop.new()
	strip.mode = "scene"
	strip.custom_minimum_size = Vector2(vp.x - 48, 190)
	v.add_child(strip)
	var gp := UIKit.glass_panel()
	gp.position = Vector2(20, 20)
	strip.add_child(gp)
	var gv := VBoxContainer.new()
	gp.add_child(gv)
	gv.add_child(UIKit.label("Напівпрозорий крем над 3D", 22, UIKit.INK, true))
	gv.add_child(UIKit.label("porcelain · hairline · soft shadow", 18, UIKit.INK_DIM))
	var sl := UIKit.scene_label("Веста", 52)
	sl.position = Vector2(380, 40)
	strip.add_child(sl)
	var sub := UIKit.scene_label("Сонцекута", 22)
	sub.add_theme_color_override("font_color", UIKit.GOLD_HI)
	sub.position = Vector2(384, 112)
	strip.add_child(sub)
	# Modal + bands
	var m := UIKit.modal("Шанси випадіння", func(): pass, vp.x - 48)
	v.add_child(m)
	var mb: VBoxContainer = m.get_meta("body")
	mb.add_child(UIKit.list_row("Кварц", "62 %", ""))
	mb.add_child(UIKit.list_row("Сапфір", "28 %", ""))
	v.add_child(UIKit.band("ПЕРЕМОГА", "amber", 110))
	v.add_child(UIKit.band("Поразка", "cool", 90))
	await get_tree().process_frame
	UIKit.toast(ui, "Колоду збережено", "check", 30.0, vp.y - 120.0)


func _page_cards() -> void:
	_new_root("light")
	var v := _col(24, 28, 18)
	v.add_child(UIKit.caps("Картки рідкості · грунт кольору самоцвіту + огранка"))
	var names := [["quartz", "Борко", "Рів. 7", 1], ["sapphire", "Альба", "Рів. 12", 2], ["amethyst", "Іскар", "Рів. 18", 3],
			["topaz", "Веста", "Рів. 23", 4], ["opal", "Мейра", "Рів. 30", 5]]
	var r1 := _row(v, 12)
	var r2 := _row(v, 12)
	var i := 0
	for n: Array in names:
		var c := UIKit.gem_card(str(n[0]), Vector2(216, 300))
		c.title = str(n[1])
		c.footer = str(n[2])
		c.pips = int(n[3])
		c.new_tag = i == 3
		var bust := _Bust.new()
		bust.gem = str(n[0])
		bust.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.content.add_child(bust)
		(r1 if i < 3 else r2).add_child(c)
		i += 1
	var locked := UIKit.gem_card("quartz", Vector2(216, 300))
	locked.title = "Як отримати"
	locked.footer = "12 / 40"
	locked.dim = true
	locked.pips = 0
	r2.add_child(locked)
	var r3 := _row(v, 10)
	for g: String in UITokens.GEM_ORDER:
		var c3 := UIKit.gem_card(g, Vector2(124, 160))
		c3.title = Loc.t(str((UITokens.GEMS[g] as Dictionary)["name"])) if Loc.has_method("t") else g
		if c3.title.begins_with("GEM_"):
			c3.title = {"quartz": "Кварц", "sapphire": "Сапфір", "amethyst": "Аметист", "topaz": "Топаз", "opal": "Опал"}[g]
		c3.footer_ratio = 0.24
		r3.add_child(c3)


func _page_icons() -> void:
	_new_root("light")
	var v := _col(24, 24, 10)
	v.add_child(UIKit.caps("Лінійні іконки · ink на кремі"))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for k: String in KitIcons.LINE:
		if k in ["gear", "percent", "up", "book"]:
			continue
		var ic := Icons.make(k, 52.0, UIKit.INK)
		grid.add_child(ic)
	v.add_child(UIKit.divider(vp.x - 48))
	v.add_child(UIKit.caps("Гнізда: класи, стихії (сланець), фракції"))
	var sr := _row(v, 10)
	for k: String in ["el_kinetic", "el_volt", "el_frost", "el_plasma", "el_tech", "el_rune", "el_rift"]:
		sr.add_child(UIKit.socket(k, 64, true))
	var fr := _row(v, 10)
	for k: String in ["fac_dawn", "fac_wildfang", "fac_stoneheart", "fac_celestial", "portal", "team", "trophy"]:
		fr.add_child(UIKit.socket(k, 64))
	v.add_child(UIKit.divider(vp.x - 48))
	v.add_child(UIKit.caps("Мальовані іконки · валюти та нижня панель"))
	var pr := _row(v, 18)
	for k: String in ["coin", "gem", "crown", "blueprint", "beacon", "tome", "fragment"]:
		pr.add_child(Icons.make(k, 72.0))
	var nav := _row(v, 22)
	for k: String in ["tab_shop", "tab_arsenal", "tab_play", "tab_heroes", "tab_barracks"]:
		nav.add_child(Icons.make(k, 96.0))
	var small := _row(v, 18)
	for k: String in ["tab_shop", "tab_arsenal", "tab_play", "tab_heroes", "tab_barracks", "coin", "gem"]:
		small.add_child(Icons.make(k, 44.0))
	v.add_child(UIKit.divider(vp.x - 48))
	v.add_child(UIKit.caps("Самоцвіти-огранки (колір + форма)"))
	var gr := _row(v, 16)
	for g: String in UITokens.GEM_ORDER:
		var m := _Mark.new()
		m.gem = g
		m.custom_minimum_size = Vector2(72, 72)
		gr.add_child(m)
	var tz := _Mark.new()
	tz.gem = "cta"
	tz.custom_minimum_size = Vector2(72, 72)
	gr.add_child(tz)


## Home layout (home_v1 component set) over a painted dawn scene or the real 3D stage.
func _page_home(bg: String) -> void:
	_new_root(bg)
	var W := vp.x
	var H := vp.y
	# Top bar: portrait ring + level, two currency plates.
	var port := RoundButton.new(40.0)
	port.ult_style = true
	port.highlight = false
	port.progress = 0.65
	port.position = Vector2(18, 14)
	ui.add_child(port)
	var lv := UIKit.notify_badge("14", 30)
	lv.position = Vector2(70, 70)
	ui.add_child(lv)
	var coins := UIKit.currency_plate("coin", "12 480", true, 210)
	coins.position = Vector2(W - 210 - 170 - 24, 26)
	coins.size = Vector2(210, 52)
	ui.add_child(coins)
	var gems := UIKit.currency_plate("gem", "320", false, 156)
	gems.position = Vector2(W - 156 - 14, 26)
	gems.size = Vector2(156, 52)
	ui.add_child(gems)
	var rib := UIKit.title_plate("Світ 2 · Луки · Рівень 14", 400)
	rib.position = Vector2((W - 400) * 0.5, 112)
	rib.size = Vector2(400, 44)
	ui.add_child(rib)
	# Edge buttons: two per side.
	var lefts := ["events", "mail"]
	var rights := ["quests", "chest"]
	for i in 2:
		var b := UIKit.edge_button(lefts[i], 36.0, "3" if i == 1 else "")
		b.position = Vector2(20, 200 + i * 104)
		ui.add_child(b)
		var b2 := UIKit.edge_button(rights[i], 36.0, "!" if i == 1 else "")
		b2.position = Vector2(W - 96, 200 + i * 104)
		b2.highlight = i == 1
		ui.add_child(b2)
	# Dais hint (scene page only) is in the backdrop. PLAY gem button.
	var play := UIKit.cta_button("ГРАТИ", "Рівень 14", Vector2(448, 112), 46)
	play.position = Vector2((W - 448) * 0.5, H - 120 - 28 - 140)
	play.size = Vector2(448, 112)
	ui.add_child(play)
	# Bottom nav: arched bar, painted icons + labels, raised medallion for the active tab.
	var nav := _NavMock.new()
	nav.position = Vector2(0, H - 120)
	nav.size = Vector2(W, 120)
	ui.add_child(nav)


func _page_hud() -> void:
	_new_root("scene")
	var W := vp.x
	var H := vp.y
	# Porcelain plates at the top.
	var lp := UIKit.pill()
	lp.position = Vector2(18, 22)
	ui.add_child(lp)
	var lr := _row(lp, 8)
	lr.add_child(Icons.make("map", 30.0, UIKit.INK))
	lr.add_child(UIKit.label("Рівень 14", 24, UIKit.INK, true))
	var cp := UIKit.pill()
	cp.position = Vector2(W - 190, 22)
	ui.add_child(cp)
	var cr := _row(cp, 8)
	cr.add_child(Icons.make("coin", 34.0))
	cr.add_child(UIKit.number("1 260", 26))
	var pause := UIKit.edge_button("pause", 30.0)
	pause.position = Vector2(W * 0.5 - 34, 14)
	ui.add_child(pause)
	var hint := UIKit.pill()
	hint.position = Vector2(W * 0.5 - 170, 150)
	ui.add_child(hint)
	var hl := UIKit.label("Тягни, щоб вести армію", 24, UIKit.INK, true)
	hint.add_child(hl)
	# Big on-scene numerals (army count) with the soft shadow.
	var army := UIKit.number("38", 72, true)
	army.position = Vector2(W * 0.5 - 40, H * 0.52)
	ui.add_child(army)
	var mult := UIKit.gradient_heading("×2.5", 88, Color(1, 1, 0.94), Color("#FFE6A3"), Color("#F5AE45"))
	mult.position = Vector2(W * 0.5 - 100, H * 0.3)
	ui.add_child(mult)
	# Ult buttons: charging and ready.
	for i in 2:
		var u := RoundButton.new(58.0)
		u.ult_style = true
		u.icon_kind = "helmet"
		u.badge_icon = "el_volt"
		u.progress = 0.55 if i == 0 else 1.0
		u.highlight = i == 1
		u.caption = "55%" if i == 0 else "УЛЬТА"
		u.position = Vector2(40 + i * 170, H - 230)
		ui.add_child(u)
	var toastp := UIKit.panel("toast", Vector2(22, 10))
	toastp.position = Vector2(W * 0.5 - 150, H * 0.42)
	ui.add_child(toastp)
	toastp.add_child(UIKit.label("+12 солдатів", 24, UIKit.INK, true))


# ------------------------------------------------------------------ drawn helpers

class _Backdrop extends Control:
	var mode := "light"

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if mode == "light":
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
					PackedColorArray([Color("#F3EBDD"), Color("#F3EBDD"), Color("#E8DCC6"), Color("#E8DCC6")]))
			# Faint facet filigree in a corner (4 %).
			var c := Vector2(w * 0.92, h * 0.06)
			for i in 6:
				draw_arc(c, 60.0 + i * 34.0, 0, TAU, 64, Color(0.79, 0.66, 0.42, 0.06), 1.0, true)
			return
		# Painted dawn: sky -> warm horizon, sun bloom, clouds, a crystal bridge in perspective,
		# and a warm marble plaza.
		var hz := h * 0.46
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, hz), Vector2(0, hz)]),
				PackedColorArray([Color("#5AA6EC"), Color("#5AA6EC"), Color("#FBE3BC"), Color("#FBE3BC")]))
		var glow := UIKit.glow_texture()
		draw_texture_rect(glow, Rect2(Vector2(w * 0.5 - 300, hz - 300), Vector2(600, 600)), false, Color(1.0, 0.86, 0.55, 0.6))
		for i in 9:
			var cx := fmod(i * 173.0, w + 200.0) - 100.0
			var cy := hz - 40.0 + sin(i * 1.7) * 40.0
			draw_texture_rect(glow, Rect2(Vector2(cx - 140, cy - 60), Vector2(280, 120)), false, Color(1, 0.98, 0.95, 0.75))
		draw_polygon(PackedVector2Array([Vector2(0, hz), Vector2(w, hz), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([Color("#E9DCC8"), Color("#E9DCC8"), Color("#CDBB9E"), Color("#CDBB9E")]))
		# Bridge (perspective trapezoid) with gold trims and tiles.
		var vx := w * 0.5
		var top_y := hz - 4.0
		var bot_y := h * 0.66
		var tw := 26.0
		var bw := w * 0.44
		var bridge := PackedVector2Array([Vector2(vx - tw, top_y), Vector2(vx + tw, top_y), Vector2(vx + bw, bot_y), Vector2(vx - bw, bot_y)])
		draw_polygon(bridge, PackedColorArray([Color("#F2FCFF"), Color("#F2FCFF"), Color("#BFE9F7"), Color("#BFE9F7")]))
		for i in 14:
			var t := pow(float(i) / 14.0, 1.8)
			var y := lerpf(top_y, bot_y, t)
			var hw := lerpf(tw, bw, t)
			draw_line(Vector2(vx - hw, y), Vector2(vx + hw, y), Color(0.55, 0.8, 0.9, 0.5), 1.0, true)
		draw_line(Vector2(vx - tw, top_y), Vector2(vx - bw, bot_y), Color("#C9A86A"), 3.0, true)
		draw_line(Vector2(vx + tw, top_y), Vector2(vx + bw, bot_y), Color("#C9A86A"), 3.0, true)
		# Plaza + dais
		var pc := Vector2(vx, h * 0.72)
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(pc + Vector2(cos(a) * w * 0.62, sin(a) * h * 0.11))
		draw_colored_polygon(pts, Color("#EFE6D6"))
		draw_arc(pc, 10.0, 0, TAU, 4, Color(0, 0, 0, 0), 1.0)
		var dais := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			dais.append(pc + Vector2(cos(a) * 130.0, sin(a) * 34.0 - 30.0))
		draw_colored_polygon(dais, Color("#F7F1E6"))
		var rim := dais.duplicate()
		rim.append(dais[0])
		draw_polyline(rim, Color("#FFB52E"), 3.0, true)
		draw_texture_rect(glow, Rect2(pc + Vector2(-150, -90), Vector2(300, 120)), false, Color(1.0, 0.75, 0.3, 0.35))
		# Hero silhouette placeholder (a soft column of light) so the layout reads.
		draw_texture_rect(glow, Rect2(pc + Vector2(-70, -430), Vector2(140, 420)), false, Color(1, 0.95, 0.85, 0.45))


class _Swatch extends Control:
	var col := Color.WHITE
	var label := ""

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 20))
		draw_style_box(UIKit.cbox(col, 6, UITokens.HAIRLINE, 1, Vector2.ZERO), r)
		var f := UIKit.font_w("medium")
		draw_string(f, Vector2(0, size.y - 3), label, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, UITokens.INK_DIM)


## Placeholder bust (head + shoulders silhouette lit in the gem's light) for card previews.
class _Bust extends Control:
	var gem := "topaz"

	func _draw() -> void:
		var g: Dictionary = UITokens.gem(gem)
		var lc: Color = g["light"]
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var s := size.x
		var shoulders := PackedVector2Array()
		for i in 25:
			var a := PI + PI * i / 24.0
			shoulders.append(Vector2(c.x + cos(a) * s * 0.42, size.y * 0.86 + sin(a) * s * 0.32))
		draw_colored_polygon(shoulders, Color(lc.r, lc.g, lc.b, 0.35))
		draw_circle(c, s * 0.17, Color(lc.r, lc.g, lc.b, 0.42), true, -1.0, true)


class _Mark extends Control:
	var gem := "topaz"

	func _draw() -> void:
		var c := size * 0.5
		if gem == "cta":
			GemDraw.draw_gem(self, "cushion", c, size.y * 0.8, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"))
			return
		GemDraw.draw_mark(self, gem, c, size.x * 0.66)


## The bottom nav mock: KitNav bar + medallion + painted icons + labels.
class _NavMock extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		KitNav.draw_bar(self, r, 8.0)
		var tabs := [["tab_shop", "Магазин"], ["tab_arsenal", "Арсенал"], ["tab_play", "Грати"], ["tab_heroes", "Герої"], ["tab_barracks", "Казарми"]]
		var w := size.x / 5.0
		var f := UIKit.font_w("bold")
		for i in 5:
			var cx := w * (i + 0.5)
			var on := i == 2
			var lab: String = tabs[i][1]
			if on:
				var mc := Vector2(cx, 18.0)
				KitNav.draw_medallion(self, mc, 50.0, 1.0)
				Icons.draw_icon(self, tabs[i][0], Rect2(mc - Vector2(34, 36), Vector2(68, 68)))
				var tw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
				draw_string(f, Vector2(cx - tw * 0.5, size.y - 18.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UITokens.CTA_LO.darkened(0.15))
			else:
				Icons.draw_icon(self, tabs[i][0], Rect2(Vector2(cx - 30, 20), Vector2(60, 60)))
				var tw2 := UIKit.font_w("medium").get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
				draw_string(UIKit.font_w("medium"), Vector2(cx - tw2 * 0.5, size.y - 18.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UITokens.INK_DIM)
