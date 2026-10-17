extends SummonSheet
## «Фокус / Focus» (heroes_design.md §7.1 Focus row; part U §2.8 Focus sheet): one row per gem. A
## row is live only when every pool hero of that gem is owned; then the player picks who gets
## exactly 60 % of that gem's results (PortalData.FOCUS_TOTAL, printed from data) or «Без фокуса».
## Otherwise the row says when Focus starts («… (1 / 2)»). Free, any time (HeroesUIModel.set_focus).


func _title() -> String:
	return HeroesText.t("PORTAL_FOCUS_TITLE")


func _fill(b: VBoxContainer) -> void:
	b.add_child(SummonSheet.para(HeroesText.t("PORTAL_FOCUS_60", [HeroesText.pct(PortalData.FOCUS_TOTAL)]), 24, UITokens.INK))
	b.add_child(SummonSheet.para(HeroesText.t("PORTAL_FOCUS_HELP"), 22))
	var ps := HeroesUIModel.portal_state()
	var focus: Dictionary = ps["focus"]
	for g: String in Ladder.GEMS:
		var ids: Array[String] = []
		var owned := 0
		for id in ps["pool"]:
			if HeroData.native(str(id)) == g:
				ids.append(str(id))
				if bool(HeroesUIModel.hero(str(id))["owned"]):
					owned += 1
		if ids.is_empty():
			continue
		b.add_child(UIKit.gap(4))
		var sec := HBoxContainer.new()
		sec.add_theme_constant_override("separation", 10)
		sec.add_child(SummonSheet.gem_mark(g, 30))
		sec.add_child(UIKit.section(HeroesText.gem_name(g)))
		b.add_child(sec)
		if ids.size() < 2:
			b.add_child(SummonSheet.para(HeroesText.t("PORTAL_FOCUS_SOLO"), 22))
			continue
		if owned < ids.size():
			b.add_child(SummonSheet.para(HeroesText.t("PORTAL_FOCUS_LOCKED", [owned, ids.size()]), 22))
			continue
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 4)
		b.add_child(flow)
		var cur := str(focus.get(g, ""))
		for id in ids:
			var c := HeroChip.make(HeroesText.hero_name(id), "", g)
			c.active = cur == id
			c.pressed.connect(func():
				HeroesUIModel.set_focus(g, id)
				refill())
			flow.add_child(c)
		var none := HeroChip.make(HeroesText.t("PORTAL_FOCUS_NONE"))
		none.active = cur == ""
		none.pressed.connect(func():
			HeroesUIModel.set_focus(g, "")
			refill())
		flow.add_child(none)
