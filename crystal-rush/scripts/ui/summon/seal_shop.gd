extends SummonSheet
## «Вибір за печатками / Pick with Seals» (heroes_design.md §7.4, §9.3 Seal shop row; part U §2.8):
## every eligible hero in three sections by price (Аметист · Топаз · Опал, prices from
## PortalData.SEAL_PRICES via HeroesUIModel.seal_shop()), each as a gem card with what the pick
## gives - «Новий герой», «+50 фрагм.» for an owned hero, or the honest overflow «+10 томів
## (надлишок)» at the absolute max - and a two-tap «Обрати · 40 печаток». Unaffordable picks are
## dim with «Ще 3 печатки». Footnote: Seal picks never change guarantees and give no Seals.
## Emits `picked(id)` (the Portal opens the known-contents walkout); on the HeroesNav route it opens
## "summon/seal/<id>" itself.

signal picked(id: String)

var _armed := ""


func _title() -> String:
	return HeroesText.t("SEAL_SHOP_TITLE")


func _fill(b: VBoxContainer) -> void:
	var seals := int(HeroesUIModel.currencies()["seals"])
	var have := HBoxContainer.new()
	have.add_theme_constant_override("separation", 10)
	var ic := HeroIcons.make("seal", 40.0)
	ic.custom_minimum_size = Vector2(40, 40)
	have.add_child(ic)
	var hl := UIKit.label(HeroesText.t("SEAL_HAVE", [HeroesText.count(seals, "seal")]), 26, UITokens.INK, true)
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	have.add_child(hl)
	b.add_child(have)
	var rows := HeroesUIModel.seal_shop()
	for g: String in PortalData.SEAL_PRICES:
		var items: Array[Dictionary] = []
		for r in rows:
			if str(r["gem"]) == g:
				items.append(r)
		if items.is_empty():
			continue
		b.add_child(UIKit.gap(4))
		var sec := HBoxContainer.new()
		sec.add_theme_constant_override("separation", 10)
		sec.add_child(SummonSheet.gem_mark(g, 30))
		sec.add_child(UIKit.section(HeroesText.t("SEAL_SECTION", [HeroesText.gem_name(g), HeroesText.count(PortalData.seal_price(g), "seal")])))
		b.add_child(sec)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 18)
		b.add_child(grid)
		for r in items:
			grid.add_child(_cell(r, seals))
	b.add_child(UIKit.gap(6))
	b.add_child(SummonSheet.para(HeroesText.t("SEAL_NOTE"), 22, UITokens.INK_DIM))


func _cell(r: Dictionary, seals: int) -> Control:
	var id := str(r["id"])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size.x = 196
	var cc := CenterContainer.new()
	v.add_child(cc)
	var h := HeroesUIModel.hero(id)
	var d := h.duplicate()
	d["is_new"] = false
	var card := HeroCard.make(d, "M")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(r["owned"]):
		# Unowned: show the hero bright (this is what the pick gives), not as a locked card.
		d["owned"] = true
		d["facets"] = 0
		d["frags"] = 0
		card.set_data(d)
	var foot := HeroesText.t("SHOW_LV", [int(h["level"])]) if bool(r["owned"]) else HeroesText.t("SEAL_GIVES_HERO")
	card.ready.connect(func(): card.card.footer = foot)
	cc.add_child(card)
	var gives := ""
	match str(r["gives"]):
		"hero": gives = HeroesText.t("SEAL_GIVES_HERO")
		"frags": gives = HeroesText.t("SEAL_OWNED", [int(r["frags"])])
		"tomes": gives = HeroesText.t("SEAL_OVERFLOW", [int(r["tomes"])])
	var gl := UIKit.label(gives, 22, UITokens.GOLD_TEXT if str(r["gives"]) == "hero" else UITokens.INK, true)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(gl)
	var price := int(r["price"])
	var can := bool(r["affordable"])
	var txt := HeroesText.t("SEAL_PICK_CTA", [HeroesText.count(price, "seal")]) if can else HeroesText.t("SEAL_NEED", [HeroesText.count(price - seals, "seal")])
	var btn := UIKit.button(txt, false, 196)
	btn.custom_minimum_size = Vector2(196, 88)
	btn.add_theme_font_size_override("font_size", 22)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.disabled = not can
	btn.pressed.connect(func(): _press(id, btn, price))
	v.add_child(btn)
	return v


## Two taps: the first arms («Так, обрати · …»), the second picks.
func _press(id: String, btn: Button, price: int) -> void:
	if _armed != id:
		_armed = id
		btn.text = HeroesText.t("SEAL_CONFIRM", [HeroesText.count(price, "seal")])
		UIJuice.punch(btn, 1.05, 0.14)
		return
	_armed = ""
	if embedded:
		picked.emit(id)
	else:
		var h := hub
		closed.emit()
		HeroesNav.open(h, "summon/seal/" + id)
