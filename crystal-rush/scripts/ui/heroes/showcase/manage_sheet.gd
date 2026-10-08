class_name HeroManageSheet
extends HeroesBottomSheet
## «Покращення / Manage sheet» (heroes_design.md §9.2, §9.3, §11.3): the cream bottom sheet behind
## the Showcase's «Покращити». Tabs appear as their system unlocks (a teaser tab two levels before,
## with its unlock line): Рівень (always) · Грані (from the first fragment) · Навички (L28 teaser,
## L30) · Спорядження (L30 teaser, L32). Facets are progress, not stats (§9.3): the Living Gem,
## the pips and «Грані 3 / 5 → Повні грані: +1 межа навичок»; the true values are printed once in
## small text, generated from Ladder (no hidden numbers, E12). H3a skeleton: Level and Facets act
## on the mock model (level_up / facet_up, micro beat 0.35 s); Skills and Gear show ranks, caps,
## costs and slots without buying.
## Hosts: inside the Showcase (own scrim), or the HeroesNav "manage/<id>[/tab]" modal route.
##   var m := HeroManageSheet.make(hub, "vesta", "facets", true); add_child(m)

var hero_id := "vesta"
var tab := "level"
var _h: Dictionary
var _tabs: KitTabs
var _page_host: MarginContainer
var _page: Control
var _sc: ScrollContainer
var _dirty := false


static func make(p_hub: Hub, id: String, p_tab := "level", p_own_scrim := true) -> HeroManageSheet:
	var m := HeroManageSheet.new()
	m.hub = p_hub
	m.hero_id = id
	m.tab = p_tab
	m.own_scrim = p_own_scrim
	return m


## HeroesNav route "manage/<id>[/<tab>]" (host "modal": the hub draws the scrim).
func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0:
		hero_id = str(args[0])
	if args.size() > 1:
		tab = str(args[1])


func _ready() -> void:
	# Sized to the page (about half the screen on Рівень / Грані, never above 72 %), with the
	# warm bottom-weighted scrim: the hero stays bright above the sheet.
	height_frac = 0.0
	max_frac = 0.72
	scrim_style = "warm"
	_h = HeroesUIModel.hero(hero_id)
	title = HeroesText.t("MANAGE_TITLE")
	var em := HeroGemEmblem.make(str(_h["gem"]), 64, str(_h["native"]) if bool(_h["is_recut"]) else "")
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(em)
	head.move_child(em, 0)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var nm := UIKit.label("· " + str(_h["name"]), 30, UITokens.GOLD_TEXT, true)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.move_child(nm, 2)
	var opts := _tab_options()
	var ids: Array[String] = []
	for o: Array in opts:
		ids.append(str(o[0]))
	if not tab in ids:
		tab = "level"
	_tabs = UIKit.tabs(opts, tab, _on_tab, 26)
	body.add_child(_tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_sc = sc
	_page_host = MarginContainer.new()
	_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_host.add_theme_constant_override("margin_top", 6)
	_page_host.add_theme_constant_override("margin_bottom", 18)
	sc.add_child(_page_host)
	UIKit.scroll_fade(sc)
	_show_page(false)
	HeroesUIModel.bus().changed.connect(_on_model)
	super._ready()


func _tab_options() -> Array:
	var un := HeroesUIModel.unlocks()
	var o: Array = [["level", HeroesText.t("MANAGE_TAB_LEVEL")]]
	if int(_h["facets"]) > 0 or int(_h["frags"]) > 0 or bool(_h["is_recut"]):
		o.append(["facets", HeroesText.t("MANAGE_TAB_FACETS")])
	if bool(un["skills_teaser"]):
		o.append(["skills", HeroesText.t("MANAGE_TAB_SKILLS")])
	if bool(un["workshop_teaser"]):
		o.append(["gear", HeroesText.t("MANAGE_TAB_GEAR")])
	return o


func _on_tab(id: String) -> void:
	tab = id
	_show_page(true)


func _on_model(_w: String) -> void:
	if _dirty:
		return
	_dirty = true
	(func():
		_dirty = false
		if is_instance_valid(self) and is_inside_tree():
			_h = HeroesUIModel.hero(hero_id)
			_show_page(false)).call_deferred()


func _show_page(fade: bool) -> void:
	var old := _page
	_page = VBoxContainer.new()
	(_page as VBoxContainer).add_theme_constant_override("separation", 14)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match tab:
		"facets": _facets_page(_page)
		"skills": _skills_page(_page)
		"gear": _gear_page(_page)
		_: _level_page(_page)
	_page_host.add_child(_page)
	if old:
		_page_host.remove_child(old)
		old.queue_free()
	if fade and not UITokens.reduce_motion():
		UIJuice.soft_in(_page, Vector2(0, 12))
	_fit_to_page(fade)


## The sheet height follows the page (the scroll only takes over past 60 % of the screen). On
## the first build this runs before the sheet's slide-in, so the slide ends at the right height.
func _fit_to_page(relayout := true) -> void:
	if not is_instance_valid(_page) or _sc == null:
		return
	var want := _page_host.get_combined_minimum_size().y
	_sc.custom_minimum_size.y = minf(want, _vp_h() * 0.6)
	if relayout and is_inside_tree():
		_layout()


func _small(text: String, col := UITokens.INK_SOFT) -> Label:
	var l := UIKit.label(text, 22, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	return l


## Shows the unlock line for a teaser tab; true when the tab is still locked.
func _teaser(page: Control, key: String, at: int) -> bool:
	if int(HeroesUIModel.unlocks()["level"]) >= at:
		return false
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(0, 260)
	box.add_theme_constant_override("separation", 12)
	var ic := Icons.make("lock", 48.0, UITokens.INK_DIM)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := UIKit.label(HeroesText.t("MANAGE_TEASER", [HeroesText.t(key), at]), 26, UITokens.INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	page.add_child(box)
	return true


# ------------------------------------------------------------------ Рівень

func _level_page(page: Control) -> void:
	var h := _h
	var lv := int(h["eff_level"])
	var cap := int(h["level_cap"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	page.add_child(top)
	var lvc := VBoxContainer.new()
	lvc.add_theme_constant_override("separation", -6)
	lvc.add_child(UIKit.caps(HeroesText.t("MANAGE_TAB_LEVEL"), 20, UITokens.GOLD_TEXT))
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 6)
	var num := UIKit.number(str(lv), 72)
	lr.add_child(num)
	var cl := UIKit.label("/ %d" % cap, 30, UITokens.INK_DIM, true)
	cl.size_flags_vertical = Control.SIZE_SHRINK_END
	lr.add_child(cl)
	lvc.add_child(lr)
	top.add_child(lvc)
	var mc := VBoxContainer.new()
	mc.add_theme_constant_override("separation", -6)
	mc.add_child(UIKit.caps(HeroesText.t("POWER"), 20, UITokens.GOLD_TEXT))
	mc.add_child(UIKit.number(HeroesText.num(int(h["might"])), 56))
	top.add_child(mc)
	var bar := HeroEngravedBar.make(str(h["gem"]), lv, cap, 600)
	bar.tick_every = 1
	bar.label = HeroesText.t("MANAGE_LEVEL_CAP", [cap])
	bar.value_text = HeroesText.t("SKL_RANK_SHORT", [lv, cap])
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(bar)
	if bool(h["synced"]):
		page.add_child(_small(HeroesText.t("SYNC_LINE"), UITokens.INK))
	# The CTA right under the bar (the key verb, with its coin price), then the exact values in
	# small text: the page ends where the content ends, never on empty cream.
	var cta: KitCTA
	if lv < cap:
		var price := HeroesUIModel.level_cost(hero_id)
		var coins := int(HeroesUIModel.currencies()["coins"])
		var p := HeroPriceCTA.make(HeroesText.t("SHOW_CTA_UPGRADE"), HeroesText.t("MANAGE_LEVEL_TO", [lv, lv + 1]), price, Vector2(0, 92), 32)
		if coins < price:
			p.disabled = true
			p.price = 0
			p.sub = HeroesText.t("MANAGE_LEVEL_NO_COINS", [HeroesText.num(coins), HeroesText.num(price)])
		cta = p
		cta.pressed.connect(func():
			if HeroesUIModel.level_up(hero_id):
				Audio.play("upgrade", -6.0)
				UIJuice.punch(num))
	else:
		cta = UIKit.cta_button(HeroesText.t("SHOW_CTA_UPGRADE"), HeroesText.t("MANAGE_LEVEL_AT_CAP", [int(HeroesUIModel.unlocks()["world"]) + 1]), Vector2(0, 92), 32)
		cta.disabled = true
	page.add_child(cta)
	page.add_child(UIKit.hairline())
	page.add_child(UIKit.caps(HeroesText.t("MANAGE_TRUE_VALUE"), 20, UITokens.GOLD_TEXT))
	page.add_child(_small(HeroesText.t("MANAGE_LEVEL_GIVES", [HeroesText.pct(Ladder.LV_DMG, 1), HeroesText.pct(Ladder.LV_HP, 0), HeroesText.pct(Ladder.LV_RATE, 0)])))
	var ult := 1.0 + Ladder.LV_ULT * (lv - 1)
	var us := ("%.2f" % ult)
	if HeroesText.lang() == "uk":
		us = us.replace(".", ",")
	page.add_child(_small(HeroesText.t("MANAGE_LEVEL_ULT", [us])))


# ------------------------------------------------------------------ Грані

func _facets_page(page: Control) -> void:
	var h := _h
	var gem := str(h["gem"])
	var f := int(h["facets"])
	var fmax := int(h["facets_max"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	page.add_child(top)
	var lg := HeroLivingGem.make_living(gem, 150, f, str(h["native"]) if bool(h["is_recut"]) else "")
	top.add_child(lg)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	top.add_child(col)
	col.add_child(UIKit.label(HeroesText.t("FACET_FULL") if f >= fmax else HeroesText.t("FACET_COUNT", [f, fmax]), 32, UITokens.INK, true))
	var pips := HeroFacetPips.make(gem, f, 30, fmax)
	col.add_child(pips)
	var card := UIKit.label(HeroesText.t("FACET_CARD", [f, fmax]), 22, UITokens.INK)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(card)
	var need := int(h["frags_need"])
	var frags := int(h["frags"])
	if need > 0:
		var bar := HeroEngravedBar.make(gem, mini(frags, need), need, 600)
		bar.label = HeroesText.t("CUR_FRAGS")
		bar.value_text = HeroesText.t("FACET_FRAGS", [frags, need])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_child(bar)
	else:
		page.add_child(_small(HeroesText.t("FACET_MAX"), UITokens.INK))
	var rc: Dictionary = h["recut"]
	if f < fmax:
		if frags >= need:
			var add := UIKit.secondary_button(HeroesText.t("MANAGE_FACET_ADD"), "plus", Vector2(0, 88))
			add.pressed.connect(func():
				if HeroesUIModel.facet_up(hero_id):
					Audio.play("upgrade", -8.0)
					lg.engrave(f + 1))
			page.add_child(add)
		else:
			page.add_child(_small(HeroesText.t("MANAGE_FACET_NEED", [HeroesText.count(need - frags, "frag")]), UITokens.INK))
	elif not bool(rc["max"]):
		var ng := HeroesText.gem_name(str(rc["next_gem"]), "GEN")
		if bool(rc["can"]):
			page.add_child(_small(HeroesText.t("MANAGE_RECUT_READY", [ng]), UITokens.INK))
			var cta := UIKit.cta_button(HeroesText.t("RECUT_CTA"), HeroesText.t("RECUT_TO", [HeroesText.gem_name(str(rc["next_gem"]))]), Vector2(0, 92), 32)
			cta.pressed.connect(func(): HeroesNav.open(hub, "recut/" + hero_id))
			page.add_child(cta)
		else:
			page.add_child(_small(HeroesText.t("MANAGE_RECUT_NEED", [ng, HeroesText.t("FACET_FRAGS", [int(rc["have"]), int(rc["cost"])])]), UITokens.INK))
	page.add_child(UIKit.hairline())
	page.add_child(UIKit.caps(HeroesText.t("MANAGE_TRUE_VALUE"), 20, UITokens.GOLD_TEXT))
	page.add_child(_small(HeroesText.t("FACET_GIVES", [HeroesText.pct(Ladder.FACET_STEP)])))
	page.add_child(_small(HeroesText.t("FACET_GIVES_FULL")))
	if bool(h["is_recut"]):
		page.add_child(_small(HeroesText.t("RECUT_EQUAL", [HeroesText.gem_name(gem), HeroesText.pct(1.0 / float(h["stat_ratio"]) - 1.0, 1)])))
	page.add_child(_small(HeroesText.t("MANAGE_FACET_SOURCES")))


# ------------------------------------------------------------------ Навички

func _skills_page(page: Control) -> void:
	if _teaser(page, "MANAGE_TAB_SKILLS", int(HeroData.UNLOCK_AT["skills"])):
		return
	var h := _h
	var cur := HeroesUIModel.currencies()
	var top := HBoxContainer.new()
	top.add_child(UIKit.label(HeroesText.t("MANAGE_SKILL_CAP_NOTE"), 22, UITokens.INK_DIM))
	top.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(top.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(HeroCurrencyChip.make("tomes", HeroesText.num(int(cur["tomes"])), 150))
	page.add_child(top)
	if bool(h["is_recut"]):
		# Rule #3 once for the tab (not on every row): the recut ceiling line with its tick.
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 10)
		var em := HeroGemEmblem.make(str(h["gem"]), 44, str(h["native"]))
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cr.add_child(em)
		var cl := _small(HeroesText.t("MANAGE_SKILL_CEILING", [HeroesText.gem_name(str(h["gem"]), "PL")]), UITokens.GOLD_TEXT)
		cl.custom_minimum_size = Vector2(0, 0)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(cl)
		page.add_child(cr)
	var sk: Dictionary = h["skills"]
	for s: String in ["ult", "attack", "rally", "awakened"]:
		var r: Dictionary = sk[s]
		if not bool(r.get("visible", true)):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var p := HeroShowcasePlate.make_from(h, s, 76, true)
		row.add_child(p)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var nl := HBoxContainer.new()
		nl.add_theme_constant_override("separation", 10)
		nl.add_child(UIKit.label(HeroesText.skill_name(hero_id, s), 24, UITokens.INK, true))
		nl.add_child(UIKit.caps(HeroesText.skill_kind(s), 20, UITokens.GOLD_TEXT))
		col.add_child(nl)
		var locked := s == "awakened" and not bool(r.get("open", false))
		if locked:
			col.add_child(_small(HeroesText.t("SHOW_AWAKEN_LOCKED"), UITokens.INK))
		else:
			var rk := HeroesText.t("SKL_RANK", [int(r["rank"]), int(r["cap"])])
			if int(r["cap"]) < int(r["cap_native"]) and int(r["rank"]) >= int(r["cap"]):
				rk = HeroesText.t("MANAGE_SKILL_CAP_ROW", [rk])
			col.add_child(UIKit.label(rk, 22, UITokens.INK))
			if s == "ult":
				col.add_child(UIKit.label(HeroesText.t("SKL_FORM", [HeroesText.roman(int(r["form"]))]) + " · " + HeroesText.t("FORM_" + str(r["form_gem"])), 22, UITokens.INK_DIM))
			var gives := ""
			match s:
				"ult": gives = HeroesText.t("MANAGE_SKILL_ULT", [HeroesText.pct(Ladder.ULT_RANK_STEP)])
				"attack": gives = HeroesText.t("MANAGE_SKILL_ATTACK", [HeroesText.pct(Ladder.ATK_RANK_STEP)])
				"rally": gives = HeroesText.t("MANAGE_SKILL_RALLY", [HeroesText.pct(Ladder.RALLY_RANK_STEP)])
				_: gives = HeroesText.t("MANAGE_SKILL_AWAKEN")
			col.add_child(_small(gives))
			if int(r["rank"]) < int(r["cap"]) and int(r["rank"]) < HeroData.TOME_COST.size():
				col.add_child(_small(HeroesText.t("MANAGE_SKILL_NEXT", [HeroesText.count(HeroData.TOME_COST[int(r["rank"])], "tome")])))
		page.add_child(row)
		page.add_child(UIKit.hairline())


# ------------------------------------------------------------------ Спорядження

func _gear_page(page: Control) -> void:
	if _teaser(page, "MANAGE_TAB_GEAR", int(HeroData.UNLOCK_AT["workshop"])):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(row)
	var lv := int(_h["eff_level"])
	for slot: String in ["weapon", "armour", "charm", "relic"]:
		var at := int(HeroData.GEAR_SLOT_AT[slot])
		var well := _GearWell.new()
		well.slot = slot
		well.open = lv >= at
		well.title = HeroesText.t("MANAGE_GEAR_" + slot.to_upper())
		well.sub = HeroesText.t("MANAGE_GEAR_EMPTY") if lv >= at else HeroesText.t("MANAGE_GEAR_AT", [at])
		well.custom_minimum_size = Vector2(150, 196)
		row.add_child(well)
	page.add_child(_small(HeroesText.t("MANAGE_GEAR_NOTE"), UITokens.INK))
	page.add_child(_small(HeroesText.t("WORKSHOP_NO_RANDOM")))
	var go := UIKit.secondary_button(HeroesText.t("WORKSHOP_TITLE"), "chevron", Vector2(0, 88))
	go.pressed.connect(func(): HeroesNav.open(hub, "workshop"))
	page.add_child(go)


## An empty gear slot: a cream well with an open gold setting, the slot name and its state.
class _GearWell extends Control:
	var slot := "weapon"
	var open := true
	var title := ""
	var sub := ""

	func _draw() -> void:
		var r := Rect2(Vector2(0, 0), Vector2(size.x, size.x))
		draw_style_box(UIKit.lux("well"), r)
		var c := r.get_center()
		var R := size.x * 0.3
		for k: float in [1.0, 0.82]:
			var pts := GemDraw.cut_points("square", c, R * 2.0 * k)
			GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8 if k == 1.0 else 0.4), 1.4)
		var icon: String = {"weapon": "cls_warrior", "armour": "cls_guardian", "charm": "gem", "relic": "crown"}[slot]
		var s := R * 1.0
		var ir := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		if open:
			Icons.draw_icon(self, icon, ir, Color(UITokens.INK_DIM.r, UITokens.INK_DIM.g, UITokens.INK_DIM.b, 0.55))
		else:
			Icons.draw_icon(self, "lock", ir, UITokens.INK_DIM)
		var f := UIKit.font_w("bold")
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2((size.x - tw) * 0.5, r.end.y + 26.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK)
		var fm := UIKit.font_w("medium")
		var fs := 20
		while fs > 16 and fm.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x:
			fs -= 1
		var sw := fm.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(fm, Vector2((size.x - sw) * 0.5, r.end.y + 26.0 + fs + 4.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK_DIM)
