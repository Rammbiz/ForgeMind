class_name HeroesChampionNumbers
extends RefCounted
## The live numbers of a champion's Action and Aura for the Champion Showcase (heroes_design.md
## §4.1-§4.4): kit (ChampionData) × the B1 ladder (Ladder.mult) × Champion Level cl(L), the aura
## value capped at ChampionData.AURA_CAP and printed as its effect at the champion's slot share
## (ChampionData.AURA_SHARE). No relic (the Workshop tempers it; H3a has no gear state).
## Pure; reads a HeroesUIModel champion() dict + champion_level(). H3b: replace with
## HeroesUIModel.champion_numbers(id) from the Meta API (requested in the H3a report).
##   var n := HeroesChampionNumbers.of(HeroesUIModel.champion("mila"))
##   n.action -> 3.0   n.action_text -> "Повертає до 3,00 солдатів за імпульс"
##   n.aura_effect -> 0.036   n.aura_text -> "−3,6% у колі"   n.tier -> 1   n.slot -> "left"


static func of(c: Dictionary, slot := "") -> Dictionary:
	var id := str(c["id"])
	var d: Dictionary = ChampionData.CHAMPIONS[id]
	var kit: Dictionary = d["kit"]
	var lvl := int(HeroesUIModel.champion_level()["level"])
	var cl := 1.0 + ChampionData.CL_STEP * (lvl - 1)
	var m := Ladder.mult(str(c["native"]), str(c["gem"]), int(c.get("facets", 0)))
	var sl := slot if slot != "" else str(d["slot"])
	var action := float(kit["action"]) * m * cl
	var aura := minf(ChampionData.AURA_CAP, float(kit["aura"]) * m * cl)
	var effect := aura * float(ChampionData.AURA_SHARE.get(sl, 0.3))
	var cls := str(d["class"])
	var sign := "−" if cls in ["guardian", "healer"] else "+"
	return {
		"id": id, "class": cls, "slot": sl, "level": lvl, "cl": cl, "mult": m,
		"action": action, "action_text": HeroesText.t("CHAMP_" + id.to_upper() + "_ACTVAL", [dec(action, 2)]),
		"aura": aura, "aura_effect": effect, "aura_capped": aura >= ChampionData.AURA_CAP - 1e-6,
		"aura_text": HeroesText.t("CHAMP_UI_AURA_VALUE", [sign + HeroesText.pct(effect, 1)]),
		"radius": float(kit["radius"]), "tier": ChampionData.action_tier(id),
		"hp": float(kit["hp"]) * m * cl,
	}


## 3.0 -> "3,00" (uk decimal comma).
static func dec(v: float, places := 2) -> String:
	var s := ("%." + str(places) + "f") % v
	return s.replace(".", ",") if HeroesText.lang() == "uk" else s
