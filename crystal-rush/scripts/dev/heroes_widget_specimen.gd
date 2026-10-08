class_name HeroesWidgetSpecimen
extends RefCounted
## The specimen pages of the Heroes widgets (gallery shots "widgets" and "widgets_cards"), 720 wide.
## Everything on them comes from scripts/ui/heroes/widgets + HeroesUIModel (state "late" / "mid").


static func build(which: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := _Paper.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = UITokens.GUTTER
	col.offset_right = -UITokens.GUTTER
	col.offset_top = 20
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)
	if which == "widgets_cards":
		_cards_page(col)
	else:
		_widgets_page(col)
	return root


static func _section(col: VBoxContainer, text: String) -> void:
	col.add_child(UIKit.gap(6))
	col.add_child(UIKit.section(text))


static func _row(col: VBoxContainer, sep := 14) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(r)
	return r


static func _widgets_page(col: VBoxContainer) -> void:
	var head := UIKit.gradient_heading("Герої · віджети", 40)
	col.add_child(head)
	_section(col, "Самоцвіти · огранка й оправа")
	var r1 := _row(col, 22)
	for g: String in ["C", "R", "E", "L", "M"]:
		var e := HeroGemEmblem.make(g, 112)
		e.show_name = true
		e.custom_minimum_size = Vector2(112, 140)
		r1.add_child(e)
	_section(col, "Живий самоцвіт · грані · дублет огранки")
	var r2 := _row(col, 8)
	for spec: Array in [["L", 3, "", "Топаз · 3 / 5"], ["M", 5, "", "Опал · Повні грані"], ["L", 2, "E", "Аметист → Топаз"], ["R", 1, "C", "Кварц → Сапфір"]]:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 162
		cell.add_theme_constant_override("separation", 2)
		var lg := HeroLivingGem.make_living(str(spec[0]), 138, int(spec[1]), str(spec[2]))
		lg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(lg)
		var l := UIKit.label(str(spec[3]), 20, UITokens.INK_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		r2.add_child(cell)
	_section(col, "Грані")
	var r3 := _row(col, 30)
	for spec: Array in [["C", 1], ["R", 2], ["E", 4], ["L", 3], ["M", 5]]:
		var p := HeroFacetPips.make(str(spec[0]), int(spec[1]), 20)
		p.bed = true
		r3.add_child(p)
	_section(col, "Шкали")
	var pity := HeroEngravedBar.make("L", 12, 30, 672)
	pity.label = HeroesText.t("PORTAL_PITY_L", [18])
	pity.value_text = "12 / 30"
	pity.ticks = [10.0, 20.0]
	pity.marker = 20.0
	col.add_child(pity)
	var bars := _row(col, 24)
	var fr := HeroEngravedBar.make("E", 18, 30, 324)
	fr.label = HeroesText.t("CUR_FRAGS")
	fr.value_text = "18 / 30"
	fr.tick_every = 5
	bars.add_child(fr)
	var cl := HeroEngravedBar.make("R", 4, 8, 324)
	cl.label = HeroesText.t("TEAM_CHAMPIONS")
	cl.value_text = HeroesText.t("SKL_RANK_SHORT", [4, 8])
	cl.tick_every = 1
	bars.add_child(cl)
	var bars2 := _row(col, 24)
	var se := HeroEngravedBar.make("M", 164, 200, 324)
	se.label = HeroesText.t("CUR_SEAL")
	se.value_text = "164 / 200"
	bars2.add_child(se)
	var ql := HeroEngravedBar.make("C", 31, 40, 324)
	ql.label = HeroesText.t("RECUT_TITLE")
	ql.value_text = "31 / 40"
	ql.tick_every = 10
	bars2.add_child(ql)
	_section(col, "Чіпи")
	var r5 := _row(col, 10)
	r5.add_child(HeroChip.make(HeroesText.t("PORTAL_ODDS"), "odds"))
	r5.add_child(HeroChip.make(HeroesText.t("PORTAL_HISTORY"), "calendar"))
	var foc := HeroChip.make(HeroesText.t("PORTAL_FOCUS"), "", "L")
	foc.active = true
	r5.add_child(foc)
	r5.add_child(HeroChip.make(HeroesText.class_label("ranger"), "cls_ranger"))
	_section(col, "Валюти · печатка «НОВИЙ» · навички")
	var r6 := _row(col, 10)
	r6.add_child(HeroCurrencyChip.make("beacons", "7", 150))
	r6.add_child(HeroCurrencyChip.make("seals", "37 / 40", 196))
	r6.add_child(HeroCurrencyChip.make("tomes", "38", 128))
	r6.add_child(HeroCurrencyChip.make("ore", "126", 140))
	var r7 := _row(col, 14)
	for px: float in [56.0, 72.0]:
		r7.add_child(HeroWaxSeal.make(px))
	for k: String in ["seal", "ore"]:
		r7.add_child(HeroIcons.make(k, 60))
	for k: String in ["sk_ult", "sk_attack", "sk_rally", "sk_awaken", "sk_relic"]:
		r7.add_child(HeroIcons.make(k, 48, UITokens.GOLD_TEXT))


static func _cards_page(col: VBoxContainer) -> void:
	HeroesUIModel.set_state("late")
	col.add_child(UIKit.gradient_heading("Герої · картки", 40))
	_section(col, "Герої · L 216 × 300")
	var r1 := _row(col, 12)
	for id: String in ["vesta", "bolt", "lumen"]:
		r1.add_child(HeroCard.make(HeroesUIModel.hero(id), "L"))
	_section(col, "Огранені, чемпіони, закриті · M 156 × 208")
	var r2 := _row(col, 12)
	r2.add_child(HeroCard.make(HeroesUIModel.hero("iskar"), "M"))
	r2.add_child(HeroCard.make(HeroesUIModel.champion("alba"), "M"))
	r2.add_child(HeroCard.make(HeroesUIModel.champion("dara"), "M"))
	r2.add_child(HeroCard.make(HeroesUIModel.champion("menhir"), "M"))
	_section(col, "Підсумок ×10 · S 124 × 186")
	var r3 := _row(col, 12)
	for id: String in ["titan", "seer", "vartan", "pava", "arin"]:
		r3.add_child(HeroCard.make(HeroesUIModel.hero(id), "S"))
	_section(col, "Навички · корінна Веста · огранений Іскар")
	var r4 := _row(col, 8)
	var v := HeroesUIModel.hero("vesta")
	for s: String in ["ult", "attack", "awakened"]:
		var p := HeroSkillPlate.from_model(v, s, 96)
		p.custom_minimum_size.x = 160
		r4.add_child(p)
	var isk := HeroSkillPlate.from_model(HeroesUIModel.hero("iskar"), "ult", 96)
	isk.custom_minimum_size.x = 160
	r4.add_child(isk)


class _Paper extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UITokens.PAPER_1)
		var top := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 260), Vector2(0, 260)])
		draw_polygon(top, PackedColorArray([UITokens.PAPER_0, UITokens.PAPER_0, Color(UITokens.PAPER_1, 0.0), Color(UITokens.PAPER_1, 0.0)]))
		GemDraw.draw_hairline(self, Vector2(UITokens.GUTTER, 88), Vector2(size.x - UITokens.GUTTER, 88), UITokens.HAIRLINE, 1.5, true, true)
