class_name HeroShowcase
extends Control
## «Вітрина героя / Hero Showcase» (heroes_design.md §9.2, §9.3, §11.3; owner round 3; fusion
## §6.8): the luxe screen. Route "hero/<id>[/3d|/manage]" (HeroesNav, host "screen": a full-screen
## CanvasLayer over the hub chrome).
##
##   backdrop  HeroShowcaseBackdrop: a bright painted sky in the hero's gem (+ element bloom),
##             sun rays, the gem cut engraved as a halo, light motes
##   art       Веста: the full-bleed splash (HeroArt), eye line placed by HeroArt.meta; starters:
##             the live 3D hero on the ivory dais (HeroShowcaseStage); everyone else: the class
##             sigil in metal relief painted straight into the sky (HeroArt.draw_relief, no frame,
##             breathing like a splash) with the honest caps line «Арт героя — скоро»
##   left      Living Gem emblem 200 px (doublet for a recut) · name 68 px · title · class /
##             element / faction badges (as they unlock, §11.3) · Рівень + «Міць 12 480» ·
##             «Грані 3 / 5 · 18 / 30 фрагм.» (once there are fragments) · rule #3 line + the
##             native-ceiling bar on a recut hero · «У команді»; unowned: where to find it
##   skills    cream glass band of skill plates, only the unlocked ones (Ult + Attack from L4,
##             Rally from L28 / L30, Awakening when open or born); Ult bezel = current form gem;
##             before L30 no rank hallmarks; native-ceiling notes on a recut hero
##   dock      ‹ · one contextual CTA (Покращити / Огранити / До Порталу) · «3D» · book (L30+)
##   «?»       Codex (88 px, top right)
## «3D» swaps the art for the interactive 3D view (starters) or an honest card (no model yet).
## Swipe left / right = next / previous hero of the Hall. Idle: splash breathing, motes, rays.
## Entrance per UI v2 (soft, no overshoot); Reduce Motion: static.

signal closed

const COL_W := 340.0
## Where a live 3D hero stands across the screen in the art view (right of the info column).
const STAGE_FOCUS := 0.72

var hub: Hub
var hero_id := "vesta"
var _h: Dictionary = {}
var _mode3d := false
var _start_3d := false
var _start_manage := false
var _start_codex := false
var _manage_tab := "level"
var _ins := Vector4.ZERO
var _t := 0.0

var _bg: HeroShowcaseBackdrop
var _art: Control
var _splash: TextureRect
var _stage: HeroShowcaseStage
var _relief: _ReliefArt
var _veil: TextureRect
var _ui: Control
var _info: VBoxContainer
var _skills: PanelContainer
var _dock: HBoxContainer
var _chip3d: HeroChip
var _codex: Control
var _hint3d: Control
var _none3d: Control
var _sheet: Control
var _press_x := -1.0
var _press_y := -1.0
var _dirty := false


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0 and HeroData.HEROES.has(str(args[0])):
		hero_id = str(args[0])
	_start_3d = "3d" in args
	_start_manage = "manage" in args
	_start_codex = "codex" in args
	for t: String in ["level", "facets", "skills", "gear"]:
		if t in args:
			_manage_tab = t


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ins = hub.insets() if hub else Vector4.ZERO
	_mode3d = _start_3d
	_build_hero(true)
	resized.connect(_layout)
	HeroesUIModel.bus().changed.connect(_on_model)
	if _start_manage:
		_open_manage(_manage_tab)
	elif _start_codex:
		_open_codex()


func _on_model(_what: String) -> void:
	if _dirty:
		return
	_dirty = true
	(func():
		_dirty = false
		if is_instance_valid(self) and is_inside_tree():
			refresh()).call_deferred()


## Rebuilds the info column, skills and dock from the model (the art stays).
func refresh() -> void:
	_h = HeroesUIModel.hero(hero_id)
	if _h.is_empty():
		return
	_build_ui(false)


func _process(delta: float) -> void:
	_t += delta
	if _splash and _splash.visible and not UITokens.reduce_motion():
		# Breathing: a 0.8 % scale swell and a 3 px rise over 5.2 s (pivot at the feet).
		var k := sin(_t * TAU / 5.2)
		_splash.scale = Vector2.ONE * (1.0 + 0.008 * k)
		_splash.position.y = float(_splash.get_meta("y0", 0.0)) - 3.0 * k


# ------------------------------------------------------------------ build

func _build_hero(entrance: bool) -> void:
	for c in get_children():
		c.queue_free()
	_splash = null
	_stage = null
	_relief = null
	_h = HeroesUIModel.hero(hero_id)
	var gem := str(_h["gem"])
	_bg = HeroShowcaseBackdrop.make(gem, str(_h["element"]))
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	var st := HeroArt.state(hero_id)
	var owned := bool(_h["owned"])
	if st == "splash":
		_splash = TextureRect.new()
		_splash.texture = HeroArt.splash(hero_id)
		_splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_splash.stretch_mode = TextureRect.STRETCH_SCALE
		_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			_splash.modulate = Color(0.55, 0.56, 0.62, 0.55)
		_art.add_child(_splash)
	elif st == "live3d" and DisplayServer.get_name() != "headless":
		_stage = HeroShowcaseStage.make(hero_id, gem)
		_stage.left_clear = (UITokens.GUTTER + COL_W) / maxf(1.0, _vp().x)
		_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not owned:
			_stage.modulate = Color(0.6, 0.62, 0.7, 0.6)
		_art.add_child(_stage)
	else:
		_relief = _ReliefArt.new()
		_relief.gem = gem
		_relief.cls = str(_h["class"])
		_relief.dim = not owned
		_art.add_child(_relief)
	_veil = TextureRect.new()
	var gt := GradientTexture2D.new()
	var grad := Gradient.new()
	var cr := UITokens.PAPER_1
	# Art that reaches under the info column asks for a stronger veil (META "veil").
	var va := float(HeroArt.meta(hero_id).get("veil", 0.5))
	grad.set_color(0, Color(cr.r, cr.g, cr.b, va))
	grad.add_point(0.55, Color(cr.r, cr.g, cr.b, va * 0.44))
	grad.set_color(grad.get_point_count() - 1, Color(cr.r, cr.g, cr.b, 0.0))
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 4
	_veil.texture = gt
	_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_veil.stretch_mode = TextureRect.STRETCH_SCALE
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_build_ui(entrance)
	if _mode3d:
		_set_3d(true, false)
	if entrance:
		_entrance()


func _build_ui(entrance: bool) -> void:
	for c in _ui.get_children():
		c.queue_free()
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_info)
	_fill_info()
	_skills = _skill_band()
	_ui.add_child(_skills)
	_dock = _build_dock()
	_ui.add_child(_dock)
	var cx := UIKit.edge_button("help", 34.0)
	cx.pressed.connect(_open_codex)
	_ui.add_child(cx)
	_codex = cx
	_hint3d = _make_hint3d()
	_ui.add_child(_hint3d)
	_none3d = _make_none3d()
	_ui.add_child(_none3d)
	_hint3d.visible = _mode3d and _stage != null
	_none3d.visible = _mode3d and _stage == null
	_info.modulate.a = 0.0 if _mode3d else 1.0
	_skills.modulate.a = 0.0 if _mode3d else 1.0
	_skills.visible = not _mode3d
	_layout()
	if not entrance:
		return


func _fill_info() -> void:
	var h := _h
	var un := HeroesUIModel.unlocks()
	var gem := str(h["gem"])
	var owned := bool(h["owned"])
	var recut := bool(h["is_recut"])
	var show_facets := owned and (int(h["facets"]) > 0 or int(h["frags"]) > 0)
	# 200 px Living Gem; 168 px beside a painted splash, so the face leads.
	var em_px := 168 if HeroArt.state(hero_id) == "splash" else 200
	var lg := HeroLivingGem.make_living(gem, em_px, int(h["facets"]) if show_facets else 0, str(h["native"]) if recut else "")
	lg.set_meta("base_px", float(em_px))
	if not owned:
		lg.modulate.a = 0.7
	lg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_info.add_child(lg)
	var nm := UIKit.gradient_heading(str(h["name"]), UIKit.fit_size(str(h["name"]), COL_W, 68, 44))
	_info.add_child(nm)
	var tl := UIKit.label(str(h["title"]), 28, UITokens.GOLD_TEXT, true)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(COL_W, 0)
	_info.add_child(tl)
	if recut:
		var rl := UIKit.label(HeroesText.t("RECUT_FROM", [HeroesText.gem_name(str(h["native"]), "GEN")]), 22, UITokens.INK_DIM)
		_info.add_child(rl)
	_info.add_child(UIKit.gap(6))
	# Badges: class from L4, faction from L14 (champions), element from L20 (Portal) (§11.3).
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 10)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tags: Array[String] = [HeroesText.class_label(str(h["class"]))]
	badges.add_child(_badge("cls_" + str(h["class"]), false))
	if bool(un["portal"]):
		badges.add_child(_badge("el_" + str(h["element"]), true))
		tags.append(HeroesText.element_label(str(h["element"])))
	if bool(un["champions"]):
		badges.add_child(_badge("fac_" + str(h["faction"]), false))
		tags.append(HeroesText.faction_label(str(h["faction"])))
	_info.add_child(badges)
	var tg := UIKit.label(" · ".join(tags), 22, UITokens.INK_DIM)
	tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tg.custom_minimum_size = Vector2(COL_W, 0)
	_info.add_child(tg)
	_info.add_child(UIKit.gap(10))
	if not owned:
		_fill_where()
		return
	# Level + Might.
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 34)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(stats)
	var lvc := VBoxContainer.new()
	lvc.add_theme_constant_override("separation", -4)
	lvc.add_child(UIKit.caps(HeroesText.t("MANAGE_TAB_LEVEL"), 20, UITokens.GOLD_TEXT))
	var lvr := HBoxContainer.new()
	lvr.add_theme_constant_override("separation", 6)
	lvr.add_child(UIKit.number(str(int(h["eff_level"])), 46))
	var capl := UIKit.label("/ %d" % int(h["level_cap"]), 26, UITokens.INK_DIM, true)
	capl.size_flags_vertical = Control.SIZE_SHRINK_END
	lvr.add_child(capl)
	lvc.add_child(lvr)
	stats.add_child(lvc)
	var mc := VBoxContainer.new()
	mc.add_theme_constant_override("separation", -4)
	mc.add_child(UIKit.caps(HeroesText.t("POWER"), 20, UITokens.GOLD_TEXT))
	mc.add_child(UIKit.number(HeroesText.num(int(h["might"])), 46))
	stats.add_child(mc)
	if bool(h["synced"]):
		var sy := UIKit.label(HeroesText.t("SYNC_LINE"), 22, UITokens.INK_DIM)
		sy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sy.custom_minimum_size = Vector2(COL_W, 0)
		_info.add_child(sy)
	if show_facets:
		# One combined facets + fragments line (§9.3), the rhombus pips under it.
		var need := int(h["frags_need"])
		var ft := HeroesText.t("FACET_MAX") if need <= 0 else HeroesText.t("FACET_ROW", [int(h["facets"]), int(h["facets_max"]), int(h["frags"]), need])
		var fl := UIKit.label(ft, 22, UITokens.INK, true)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(COL_W, 0)
		_info.add_child(fl)
		var pips := HeroFacetPips.make(gem, int(h["facets"]), 24)
		pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_info.add_child(pips)
	if recut:
		# Rule #3, visible: the stats vs a native of the current gem, with the ceiling tick.
		var ratio := float(h["stat_ratio"])
		var cl := UIKit.label(HeroesText.t("SHOW_CEILING", [HeroesText.pct(ratio, 0), HeroesText.gem_name(gem, "GEN")]), 22, UITokens.INK)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(COL_W, 0)
		_info.add_child(cl)
		var bar := HeroEngravedBar.make(gem, ratio, 1.0, COL_W - 20.0)
		bar.ticks = [1.0]
		bar.marker = 1.0
		_info.add_child(bar)
	if bool(h["in_team"]):
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 8)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.add_child(Icons.make("team", 26.0, UITokens.GOLD_TEXT))
		tr.add_child(UIKit.label(HeroesText.t("SHOW_IN_TEAM"), 22, UITokens.GOLD_TEXT, true))
		_info.add_child(tr)


## Unowned: where the hero comes from, every line generated from data (§9.5 row 3).
func _fill_where() -> void:
	var h := _h
	var un := HeroesUIModel.unlocks()
	_info.add_child(UIKit.label(HeroesText.t("SHOW_NOT_OWNED"), 26, UITokens.INK, true))
	var src: Dictionary = h["source"]
	var lines: Array = []
	match str(src["kind"]):
		"level", "start":
			lines.append(["lock", HeroesText.t("SHOW_FROM_LEVEL", [int(src["level"])])])
		_:
			if bool(un["portal"]):
				var pct := 0.0
				for r: Dictionary in HeroesUIModel.odds_rows("portal")["heroes"]:
					if str(r["id"]) == hero_id:
						pct = float(r["pct"])
				lines.append(["portal", HeroesText.t("SHOW_FROM_PORTAL", [HeroesText.pct(pct)])])
			else:
				lines.append(["portal", HeroesText.t("SHOW_FROM_PORTAL_SOON", [int(HeroData.UNLOCK_AT["portal"])])])
			if int(src.get("seals", 0)) > 0:
				lines.append(["seal", HeroesText.t("SHOW_FROM_SEALS", [HeroesText.count(int(src["seals"]), "seal")])])
	for l: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := HeroIcons.make(str(l[0]), 30.0, UITokens.INK)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		if str(l[0]) == "portal":
			# The gem-cut mark before the per-summon %: the rarity reads at a glance.
			var gm := _GemMark.new()
			gm.gem = str(h["gem"])
			gm.custom_minimum_size = Vector2(28, 30)
			gm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(gm)
		var lb := UIKit.label(str(l[1]), 22, UITokens.INK)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(COL_W - (82.0 if str(l[0]) == "portal" else 44.0), 0)
		row.add_child(lb)
		_info.add_child(row)


func _badge(icon: String, slate: bool) -> Control:
	var s := UIKit.socket(icon, 56, slate)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _skill_band() -> PanelContainer:
	var h := _h
	var un := HeroesUIModel.unlocks()
	var ranks_open := bool(un["skills"])
	var p := UIKit.panel("cream_glass", Vector2(18, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UIKit.section(HeroesText.t("SHOW_SKILLS")))
	head.add_child(UIKit.spacer())
	if not ranks_open:
		head.add_child(UIKit.label(HeroesText.t("SHOW_SKILLS_SOON", [int(HeroData.UNLOCK_AT["skills"])]), 22, UITokens.INK_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var sk: Dictionary = h["skills"]
	var shown: Array[String] = []
	for s: String in ["ult", "attack", "rally", "awakened"]:
		var r: Dictionary = sk[s]
		if not bool(r.get("visible", true)):
			continue
		if s == "awakened" and not bool(r.get("open", false)) and not bool(r.get("born", false)):
			continue
		shown.append(s)
	var inner := _vp().x - 32.0 - 36.0
	var bw := minf(190.0, (inner - 10.0 * (shown.size() - 1)) / maxf(1.0, shown.size()))
	for s in shown:
		row.add_child(_skill_block(s, ranks_open, bw))
	# Rule #3 on a recut hero, once for the band (the per-skill caps are in Manage > Навички).
	if ranks_open and bool(h["is_recut"]):
		var ult: Dictionary = sk["ult"]
		var txt := HeroesText.t("SHOW_RECUT_CAPS", [HeroesText.gem_name(str(h["gem"]), "PL")])
		txt += "\n" + HeroesText.t("SHOW_RECUT_FORM", [HeroesText.roman(int(ult["form_max"])), HeroesText.gem_name(str(ult["form_max_gem"]))])
		var foot := UIKit.label(txt, 22, UITokens.GOLD_TEXT)
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.custom_minimum_size = Vector2(inner, 0)
		v.add_child(foot)
	return p


func _skill_block(s: String, ranks_open: bool, bw := 152.0) -> Control:
	var h := _h
	var r: Dictionary = (h["skills"] as Dictionary)[s]
	# Three tiers, never colliding: the kind as 20 px gold caps ABOVE the plate, the plate (the
	# rank hallmark only once ranks open, L30), the name under it on ONE line at 22 px (fitted).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(bw, 0)
	var kind := UIKit.caps(HeroesText.skill_kind(s), 20, UITokens.GOLD_TEXT)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kind)
	var plate := HeroShowcasePlate.make_from(h, s, 104, ranks_open)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.pressed.connect(func(): _on_skill(s))
	col.add_child(plate)
	var sn := HeroesText.skill_name(hero_id, s)
	var fs := UIKit.fit_size(sn, bw - 2.0, 22, 20)
	var nm := UIKit.label(sn, fs, UITokens.INK, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size = Vector2(bw, 0)
	if not " " in sn.strip_edges():
		# One long word (e.g. «Сонцесходження») never breaks mid-word: it fits on one line instead.
		nm.add_theme_font_size_override("font_size", UIKit.fit_size(sn, bw + 8.0, 22, 18))
	elif UIKit.font(true).get_string_size(sn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > bw - 2.0:
		# A long name takes two 22 px lines rather than shrinking below the type floor.
		nm.add_theme_font_size_override("font_size", 22)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.max_lines_visible = 2
	col.add_child(nm)
	return col


func _build_dock() -> HBoxContainer:
	var h := _h
	var d := HBoxContainer.new()
	d.add_theme_constant_override("separation", 12)
	var back := UIKit.secondary_button("", "back", Vector2(96, 88))
	back.pressed.connect(_back)
	d.add_child(back)
	var cta: Control
	if not bool(h["owned"]):
		if bool(HeroesUIModel.unlocks()["portal"]) and str((h["source"] as Dictionary)["kind"]) == "portal":
			var b := UIKit.secondary_button(HeroesText.t("SHOW_TO_PORTAL"), "portal", Vector2(0, 88))
			b.pressed.connect(func(): HeroesNav.open(hub, "portal"))
			cta = b
		else:
			cta = UIKit.spacer()
	elif bool((h["recut"] as Dictionary)["can"]):
		var rc := UIKit.cta_button(HeroesText.t("RECUT_CTA"), HeroesText.t("RECUT_TO", [HeroesText.gem_name(str(h["recut"]["next_gem"]))]), Vector2(0, 88), 30)
		rc.pressed.connect(func(): HeroesNav.open(hub, "recut/" + hero_id))
		cta = rc
	else:
		var sub := ""
		var price := 0
		if int(h["eff_level"]) < int(h["level_cap"]):
			sub = HeroesText.t("MANAGE_LEVEL_TO", [int(h["eff_level"]), int(h["eff_level"]) + 1])
			price = HeroesUIModel.level_cost(hero_id)
		else:
			# At the world cap the CTA still opens Manage (facets, skills); say why there is no price.
			sub = HeroesText.t("MANAGE_LEVEL_AT_CAP", [int(HeroesUIModel.unlocks()["world"]) + 1])
		var up := HeroPriceCTA.make(HeroesText.t("SHOW_CTA_UPGRADE"), sub, price, Vector2(0, 88), 30)
		up.pressed.connect(func(): _open_manage("level"))
		cta = up
	cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_child(cta)
	_chip3d = HeroChip.make(HeroesText.t("SHOW_3D"))
	_chip3d.visual_h = 64.0
	_chip3d.label_size = 26
	_chip3d.custom_minimum_size = Vector2(104, 88)
	_chip3d.active = _mode3d
	_chip3d.pressed.connect(func(): _set_3d(not _mode3d, true))
	d.add_child(_chip3d)
	if bool(HeroesUIModel.unlocks()["skills"]) and bool(h["owned"]):
		var book := UIKit.edge_button("book", 38.0)
		book.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		book.pressed.connect(func(): HeroesNav.open(hub, "chronicle/" + hero_id))
		d.add_child(book)
	return d


func _make_hint3d() -> Control:
	var p := UIKit.pill()
	var l := UIKit.label(HeroesText.t("SHOW_3D_HINT"), 22, UITokens.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _make_none3d() -> Control:
	var p := UIKit.panel("card", Vector2(28, 24))
	p.custom_minimum_size = Vector2(480, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var em := HeroGemEmblem.make(str(_h["gem"]), 120, str(_h["native"]) if bool(_h["is_recut"]) else "")
	em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(em)
	var t := UIKit.label(HeroesText.t("SHOW_3D_NONE"), 26, UITokens.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(420, 0)
	v.add_child(t)
	var s := UIKit.label(HeroesText.t("SHOW_3D_NONE_SUB"), 22, UITokens.INK_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	return p


# ------------------------------------------------------------------ layout

func _vp() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _layout() -> void:
	if _info == null:
		return
	var vp := _vp()
	var W := vp.x
	var H := vp.y
	var y0 := _ins.y + 26.0
	var dock_y := H - _ins.w - 22.0 - 88.0
	_dock.position = Vector2(UITokens.GUTTER, dock_y)
	_dock.size = Vector2(W - UITokens.GUTTER * 2.0, 88)
	var sk_h := _skills.get_combined_minimum_size().y
	var sk_y := dock_y - 16.0 - sk_h
	_skills.position = Vector2(16, sk_y)
	_skills.size = Vector2(W - 32.0, sk_h)
	_info.position = Vector2(UITokens.GUTTER, y0)
	_info.size = Vector2(COL_W, 0)
	# Short screens: the emblem gives way (200 -> 140 px) before the column meets the skills.
	var em := _info.get_child(0) as Control if _info.get_child_count() > 0 else null
	if em and not _mode3d:
		var over := y0 + _info.get_combined_minimum_size().y - (sk_y - 14.0)
		var cur := em.custom_minimum_size.x
		var want := clampf(cur - over, 140.0, float(em.get_meta("base_px", 200.0)))
		if absf(want - cur) > 0.5:
			em.custom_minimum_size = Vector2(want, want)
			_info.size = Vector2(COL_W, 0)
	_codex.position = Vector2(W - UITokens.GUTTER - 76.0, y0)
	_veil.position = Vector2.ZERO
	_veil.size = Vector2(W * 0.72, H)
	_bg.focus = Vector2(0.64, 0.34)
	# Art.
	if _splash:
		var tex := _splash.texture
		var aspect := float(tex.get_width()) / float(tex.get_height())
		# Tall phones: the art band grows, but the splash stops at 1380 px tall (its feet stay on
		# the floor), so the face never slides under the info column.
		var full := minf(H, 1380.0)
		var meta := HeroArt.meta(hero_id)
		# Wide art (a golem's fist and shoulders) is drawn smaller: the eye line stays where a
		# full-height splash puts it and the cut bottom edge stays under the skills band.
		var sc := float(meta.get("scale", 1.0))
		var sh := full * sc
		var sw := sh * aspect
		var eye: Vector2 = meta.get("eye", Vector2(0.6, 0.3))
		var ex := W * 0.64 - eye.x * sw
		ex = clampf(ex, W - sw - 40.0, 40.0)
		var sy := H - full + eye.y * (full - sh)
		_splash.size = Vector2(sw, sh)
		_splash.position = Vector2(ex, sy)
		_splash.set_meta("y0", sy)
		_splash.pivot_offset = Vector2(sw * 0.6, sh)
		_bg.focus = Vector2((ex + eye.x * sw) / W, eye.y * 0.9)
	if _stage:
		var sr := _stage_rect(_mode3d)
		_stage.position = sr.position
		_stage.size = sr.size
		_stage.focus_x = 0.5 if _mode3d else STAGE_FOCUS
	if _relief:
		# The sigil fills the art column right of the info column, centred between the header
		# and the skill band; the backdrop's sun and gem halo sit right behind it.
		var ax := UITokens.GUTTER + COL_W + 8.0
		var top := y0 + 40.0
		var bot := sk_y - 16.0
		_relief.position = Vector2(ax, top)
		_relief.size = Vector2(W - ax - 12.0, maxf(200.0, bot - top))
		_relief.halo_px = W * 0.52
		_bg.focus = (_relief.position + _relief.centre()) / Vector2(W, H)
	_hint3d.size = _hint3d.get_combined_minimum_size()
	_hint3d.position = Vector2((W - _hint3d.size.x) * 0.5, dock_y - 30.0 - _hint3d.size.y)
	_none3d.size = Vector2(minf(520.0, W - 64.0), _none3d.get_combined_minimum_size().y)
	_none3d.position = Vector2((W - _none3d.size.x) * 0.5, H * 0.42 - _none3d.size.y * 0.5)


func _stage_rect(three_d: bool) -> Rect2:
	var vp := _vp()
	var W := vp.x
	var H := vp.y
	var y0 := _ins.y + 26.0
	var dock_y := H - _ins.w - 22.0 - 88.0
	if three_d:
		return Rect2(Vector2(0, y0 + 60.0), Vector2(W, dock_y - y0 - 120.0))
	var sk_y := dock_y - 16.0 - (_skills.get_combined_minimum_size().y if _skills else 260.0)
	var top := maxf(y0 + 40.0, sk_y - 880.0)
	return Rect2(Vector2(0, top), Vector2(W, sk_y - top + 40.0))


# ------------------------------------------------------------------ motion

func _entrance() -> void:
	if UITokens.reduce_motion():
		return
	_bg.modulate.a = 0.0
	create_tween().tween_property(_bg, "modulate:a", 1.0, UITokens.MENU_IN)
	var art_item: Control = _splash if _splash else (_stage if _stage else _relief)
	if art_item:
		var a := art_item.modulate.a
		art_item.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(art_item, "modulate:a", a, 0.36).set_delay(0.06)
		if not _mode3d:
			var ox := art_item.position.x
			art_item.position.x = ox + 40.0
			tw.tween_property(art_item, "position:x", ox, 0.42).set_delay(0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var i := 0
	for c in _info.get_children():
		if c is CanvasItem:
			UIJuice.soft_in(c, Vector2(-18, 0), 0.08 + 0.035 * i)
			i += 1
	UIJuice.soft_in(_skills, Vector2(0, 28), 0.16)
	UIJuice.soft_in(_dock, Vector2(0, 20), 0.2)


func _set_3d(on: bool, animate: bool) -> void:
	_mode3d = on
	if _chip3d:
		_chip3d.active = on
	var dur := 0.0 if (not animate or UITokens.reduce_motion()) else 0.28
	var tw: Tween = null
	if dur > 0.0:
		tw = create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var a := 0.0 if on else 1.0
	_skills.visible = true
	for c: CanvasItem in [_info, _skills, _veil]:
		if dur > 0.0:
			tw.tween_property(c, "modulate:a", a, dur)
		else:
			c.modulate.a = a
	if on and tw:
		tw.chain().tween_callback(func(): _skills.visible = not _mode3d)
	elif on:
		_skills.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _stage:
		_stage.interactive = on
		_stage.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		var r := _stage_rect(on)
		var fx := 0.5 if on else STAGE_FOCUS
		if dur > 0.0:
			tw.tween_property(_stage, "position", r.position, dur)
			tw.tween_property(_stage, "size", r.size, dur)
			tw.tween_property(_stage, "focus_x", fx, dur)
		else:
			_stage.position = r.position
			_stage.size = r.size
			_stage.focus_x = fx
		_hint3d.visible = on
	else:
		_none3d.visible = on
		var art_item: CanvasItem = _splash if _splash else _relief
		if art_item:
			var target := (0.35 if on else (1.0 if bool(_h["owned"]) else 0.55))
			if dur > 0.0:
				tw.tween_property(art_item, "modulate:a", target, dur)
			else:
				art_item.modulate.a = target
		if on and dur > 0.0:
			UIJuice.soft_in(_none3d, Vector2(0, 18))


# ------------------------------------------------------------------ actions

func _back() -> void:
	if bool(_h.get("is_new", false)):
		HeroesUIModel.mark_seen(hero_id)
	Audio.play("click", -8.0)
	if UITokens.reduce_motion():
		closed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_callback(func(): closed.emit())


func _on_skill(_s: String) -> void:
	if not bool(_h["owned"]):
		return
	if bool(HeroesUIModel.unlocks()["skills_teaser"]):
		_open_manage("skills")
	else:
		UIKit.toast(self, HeroesText.t("SHOW_SKILLS_SOON", [int(HeroData.UNLOCK_AT["skills"])]), "lock")


func _open_manage(tab: String) -> void:
	if _sheet and is_instance_valid(_sheet):
		return
	if not bool(_h["owned"]):
		return
	# Through HeroesNav: over this screen the sheet lands on the router's modal layer (above the
	# screen layer) with the sheet's own warm scrim; the 3D stage keeps rendering above it.
	_sheet = HeroesNav.open(hub, "manage/%s/%s" % [hero_id, tab], self)
	if _sheet:
		_sheet.tree_exited.connect(func(): _sheet = null)


func _open_codex() -> void:
	if _sheet and is_instance_valid(_sheet):
		return
	_sheet = HeroesNav.open(hub, "codex", self)
	if _sheet:
		_sheet.tree_exited.connect(func(): _sheet = null)


func _exit_tree() -> void:
	# The screen closes under an open sheet (Android back, close_all): take the sheet along.
	if _sheet and is_instance_valid(_sheet):
		HeroesNav.back(_sheet, false)


## Swipe on the art = the next / previous hero of the Hall (the Hall's order).
func _gui_input(e: InputEvent) -> void:
	if _mode3d:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press_x = mb.position.x
			_press_y = mb.position.y
		elif _press_x >= 0.0:
			var dx := mb.position.x - _press_x
			var dy := absf(mb.position.y - _press_y)
			_press_x = -1.0
			if absf(dx) > 110.0 and dy < 160.0:
				_step(-1 if dx > 0.0 else 1)


func _step(d: int) -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in HeroesUIModel.heroes():
		if bool(r["listed"]):
			rows.append(r)
	rows = HeroesHall.sort_rows(rows)
	var ids: Array[String] = []
	for r in rows:
		ids.append(str(r["id"]))
	var i := ids.find(hero_id)
	if i < 0 or ids.size() < 2:
		return
	hero_id = ids[(i + d + ids.size()) % ids.size()]
	_mode3d = false
	Audio.play("click", -10.0)
	_build_hero(true)


## The art of a hero whose painted splash is not in yet (Genshin's "unknown" look, never an
## empty framed card): the class sigil in metal relief (HeroArt.draw_relief) painted straight
## into the gem sky, a faint filled silhouette of the gem cut matching the backdrop's halo, a
## slow 0.8 % breathing and a light sweep every ~7 s; the honest 20 px caps line
## «Арт героя — скоро» under it. Static under Reduce Motion.
class _ReliefArt extends Control:
	var gem := "M"
	var cls := "mage"
	var dim := false
	var halo_px := 360.0
	var _t := 0.0
	var _note: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note = UIKit.caps(HeroesText.t("SHOW_ART_SOON"), 20, UITokens.GOLD_TEXT)
		_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_note)
		resized.connect(_place_note)
		_place_note()
		set_process(not UITokens.reduce_motion())

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func glyph_px() -> float:
		return clampf(minf(size.x * 0.9, size.y * 0.62), 200.0, 440.0)

	func centre() -> Vector2:
		return Vector2(size.x * 0.5, size.y * 0.46)

	func _place_note() -> void:
		if _note == null:
			return
		var ns := _note.get_combined_minimum_size()
		_note.size = Vector2(size.x, ns.y)
		_note.position = Vector2(0, centre().y + glyph_px() * 0.62 + 18.0)

	func _draw() -> void:
		var g: Dictionary = UITokens.gem(gem)
		var light: Color = g["light"]
		var a := 0.5 if dim else 1.0
		var c := centre()
		# The cut silhouette (the backdrop draws its engraved outline at the same size).
		var pts := GemDraw.cut_points(str(g["cut"]), c, halo_px)
		draw_colored_polygon(pts, Color(light.r, light.g, light.b, 0.16 * a))
		var reduce := UITokens.reduce_motion()
		var k := 0.0 if reduce else sin(_t * TAU / 5.2)
		draw_set_transform(c + Vector2(0, -3.0 * k), 0.0, Vector2.ONE * (1.0 + 0.008 * k))
		HeroArt.draw_relief(self, Vector2.ZERO, glyph_px(), cls, gem, a, -1.0 if reduce else _t, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A small gem-cut rarity mark (GemDraw.draw_mark) as a row glyph.
class _GemMark extends Control:
	var gem := "L"

	func _draw() -> void:
		GemDraw.draw_mark(self, UITokens.gem_of(gem), size * 0.5, minf(size.x, size.y) * 0.78)
