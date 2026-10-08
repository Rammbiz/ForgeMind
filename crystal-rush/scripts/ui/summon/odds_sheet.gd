extends SummonSheet
## «Шанси Порталу / Portal odds» (heroes_design.md §7.2, §9.3 Odds row, §9.5 row 3): the per-gem
## table (per summon · with guarantees · 1 in N), the Topaz-or-better and Amethyst-or-better rows,
## the chance of the next summon right now, every eligible hero's current %, the pity sentences,
## duplicate protection, Focus «60%», Seal prices and the permanent-Portal line, then the Hero
## Chest odds. EVERYTHING is generated: HeroesUIModel.odds_rows() / consolidated_odds() /
## portal_state() read PortalData; the sentences are Loc templates filled from it.
## Route "odds" (HeroesNav modal) or embedded over the Portal.

const COL := [124.0, 178.0, 112.0]


func _title() -> String:
	return HeroesText.t("PORTAL_ODDS_TITLE")


func _fill(b: VBoxContainer) -> void:
	var od := HeroesUIModel.odds_rows("portal")
	var ps := HeroesUIModel.portal_state()
	# ---- per gem
	b.add_child(_head())
	for r: Dictionary in od["gems"]:
		b.add_child(_gem_row(str(r["gem"]), HeroesText.gem_name(str(r["gem"])), float(r["base"]), float(r["total"]), float(r["one_in"])))
	for r: Dictionary in od["groups"]:
		var g := "L" if str(r["key"]) == "PORTAL_TOPAZ_PLUS" else "E"
		# The table uses the short group names («Топаз+»), the sentences below keep the long ones.
		var short := "PORTAL_ODDS_TOPAZ_PLUS" if g == "L" else "PORTAL_ODDS_AMETHYST_PLUS"
		b.add_child(_gem_row(g, HeroesText.t(short), float(r["base"]), float(r["total"]), float(r["one_in"]), true))
	var now := SummonSheet.para(HeroesText.t("PORTAL_ODDS_NOW", [HeroesText.pct(float(ps["topaz_chance_next"]))]), 22, UITokens.INK)
	b.add_child(now)
	b.add_child(UIKit.gap(6))
	# ---- rules (pity, opal share, duplicates, Focus, Seals, permanent)
	b.add_child(UIKit.section(HeroesText.t("PORTAL_ODDS_RULES")))
	for l: Dictionary in od["lines"]:
		b.add_child(_rule(str(l["text"])))
	var prices: Array[String] = []
	for g: String in PortalData.SEAL_PRICES:
		prices.append(HeroesText.t("PORTAL_ODDS_SEAL_ROW", [HeroesText.gem_name(g), PortalData.seal_price(g)]))
	b.add_child(_rule(HeroesText.t("PORTAL_ODDS_SEAL_PRICES", [" · ".join(prices)])))
	b.add_child(UIKit.gap(6))
	# ---- every eligible hero's current chance
	b.add_child(UIKit.section(HeroesText.t("PORTAL_ODDS_HEROES")))
	var heroes: Array = (od["heroes"] as Array).duplicate()
	heroes.sort_custom(func(x, y): return float(x["pct"]) > float(y["pct"]) if Ladder.gem_index(str(x["gem"])) == Ladder.gem_index(str(y["gem"])) else Ladder.gem_index(str(x["gem"])) > Ladder.gem_index(str(y["gem"])))
	for r: Dictionary in heroes:
		var id := str(r["id"])
		var name := HeroesText.hero_name(id)
		var v := HeroesText.pct(float(r["pct"]))
		var line := SummonSheet.row(SummonSheet.gem_mark(str(r["gem"]), 32), name + ("  ·  " + HeroesText.t("PORTAL_ODDS_OWNED") if bool(r["owned"]) else ""), v)
		b.add_child(line)
	b.add_child(UIKit.gap(6))
	# ---- Hero Chest (champions)
	var ch := HeroesUIModel.odds_rows("chest")
	b.add_child(UIKit.section(HeroesText.t("PORTAL_ODDS_CHEST")))
	for r: Dictionary in ch["gems"]:
		b.add_child(SummonSheet.row(SummonSheet.gem_mark(str(r["gem"]), 32), HeroesText.gem_name(str(r["gem"])), HeroesText.pct(float(r["total"]))))
	for l: Dictionary in ch["lines"]:
		b.add_child(_rule(str(l["text"])))


func _head() -> Control:
	# One line of 20 px caps per column (no wrapping): РІДКІСТЬ · ЗА ПРИЗОВ · З ГАРАНТІЯМИ · ЧАСТОТА.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var n := UIKit.caps(HeroesText.t("RARITY"), 20)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	for i in 3:
		var k: String = ["PORTAL_ODDS_BASE", "PORTAL_ODDS_TOTAL", "PORTAL_ODDS_FREQ"][i]
		var txt := HeroesText.t(k)
		var l := UIKit.caps(txt, 20)
		var f := UIKit.font_caps(20)
		var fs := 20
		while fs > 16 and f.get_string_size(txt.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > COL[i] + 6.0:
			fs -= 1
		l.add_theme_font_size_override("font_size", fs)
		l.custom_minimum_size.x = COL[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return h


func _gem_row(g: String, name: String, base: float, total: float, one_in: float, group := false) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.custom_minimum_size.y = 50
	var m := SummonSheet.gem_mark(g, 32)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(m)
	var l := UIKit.label(name, 24, UITokens.INK, group)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var vals := [HeroesText.pct(base), HeroesText.pct(total), HeroesText.t("PORTAL_ODDS_ONE_IN", [_one_in(one_in)])]
	for i in 3:
		var c := UIKit.label(str(vals[i]), 24 if i < 2 else 22, UITokens.INK if i == 1 else UITokens.INK_DIM, i == 1)
		c.custom_minimum_size.x = COL[i]
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(c)
	v.add_child(h)
	v.add_child(UIKit.hairline())
	return v


func _one_in(x: float) -> String:
	var s := "%.1f" % x if x < 10.0 else "%.1f" % x
	return s.replace(".", ",") if HeroesText.lang() == "uk" else s


## A rule sentence with a small crystal keystone bullet.
func _rule(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var k := _Key.new()
	k.custom_minimum_size = Vector2(16, 30)
	k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(k)
	var l := SummonSheet.para(text, 22, UITokens.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


class _Key extends Control:
	func _draw() -> void:
		GemDraw.draw_keystone(self, Vector2(size.x * 0.5, 16), 12.0)
