extends SummonSheet
## «Історія призовів / Summon history» (part U §2.8 History sheet; §9.5): the last summons, newest
## first - number, the gem mark, the hero, and what it gave («НОВИЙ» wax seal or «+15 фрагм.»).
## Read from HeroesUIModel.history() (the model keeps the last 100).


func _title() -> String:
	return HeroesText.t("PORTAL_HISTORY_TITLE")


func _fill(b: VBoxContainer) -> void:
	var rows := HeroesUIModel.history()
	if rows.is_empty():
		b.add_child(SummonSheet.para(HeroesText.t("PORTAL_HISTORY_EMPTY"), 24))
		return
	b.add_child(SummonSheet.para(HeroesText.t("PORTAL_HISTORY_NOTE", [rows.size()]), 22))
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.custom_minimum_size.y = 56
		var n := UIKit.label(HeroesText.t("PORTAL_HISTORY_NO", [int(r["n"])]), 22, UITokens.INK_DIM_GLASS)
		n.custom_minimum_size.x = 92
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(n)
		var m := SummonSheet.gem_mark(str(r["gem"]), 32)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(m)
		var nm := UIKit.label(HeroesText.name_of(str(r["id"])), 24, UITokens.INK, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(nm)
		if bool(r["is_new"]):
			var s := HeroWaxSeal.make(52)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(s)
		else:
			var f := UIKit.label(HeroesText.t("SUMMON_FRAGS", [int(r["fragments"])]), 22, UITokens.INK)
			f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(f)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.add_child(h)
		v.add_child(UIKit.hairline())
		b.add_child(v)
