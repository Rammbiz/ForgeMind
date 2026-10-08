class_name HeroesRecutPreview
extends RefCounted
## What a recut would change, for the Recut screen's honesty table (heroes_design.md §2.2-§2.4,
## §9.3; part U §2.5). Pure: it reads a HeroesUIModel hero() / champion() dictionary and the rule
## class Ladder (the four brakes B1-B4) plus HeroData.RECUT_FRAGS / FACETS_PER_GEM for the cost.
## Nothing is hand-typed. H3b: HeroesUIModel.recut_preview(id) can return this same dictionary
## from the Meta API and this file goes away (requested in the H3a report).
##
##   var p := HeroesRecutPreview.of(HeroesUIModel.hero("arin"))
##   p.rows      -> [{key, now, after, after_full, native, native_full, better}]  (display strings)
##   p.unlocks   -> ["+1 межа навичок", "+3,65% до показників", ...]  (the «Відкриває» block)
##   p.ceiling   -> 0.96  (recut's Full-facet stats / a native's Full-facet stats of the next gem)
##   p.bar       -> {now, after, full, native}  shares of the native Full-facet value (bar marks)
##   p.state     -> "ready" | "facets" | "frags" | "max" | "locked"


static func of(d: Dictionary) -> Dictionary:
	var is_hero := str(d.get("kind", "hero")) == "hero"
	var n := str(d["native"])
	var g := str(d["gem"])
	var f := int(d.get("facets", 0))
	var gi := Ladder.gem_index(g)
	var max_gem := Ladder.HERO_MAX_GEM if is_hero else Ladder.CHAMPION_MAX_GEM
	var max_i := Ladder.gem_index(max_gem)
	var out := {
		"id": str(d["id"]), "kind": "hero" if is_hero else "champion", "native": n, "gem": g,
		"facets": f, "facets_max": Ladder.FACETS_PER_GEM, "next": "", "at_max": gi >= max_i,
		"cost": 0, "have": int(d.get("frags", 0)), "short": 0, "need_facets": Ladder.FACETS_PER_GEM - f,
		"rows": [], "unlocks": [], "ceiling": 1.0, "equal_gap": 0.0,
		"bar": {"now": 1.0, "after": 1.0, "full": 1.0, "native": 1.0}, "state": "max",
		"first_recut": not bool(d.get("is_recut", false)),
	}
	if not bool(d.get("owned", false)):
		out["state"] = "locked"
	if gi >= max_i:
		return out
	var g1 := Ladder.GEMS[gi + 1]
	var F := Ladder.FACETS_PER_GEM
	out["next"] = g1
	out["cost"] = HeroData.RECUT_FRAGS[gi]
	out["short"] = maxi(0, int(out["cost"]) - int(out["have"]))
	if bool(d.get("owned", false)):
		if f < F:
			out["state"] = "facets"
		elif int(out["short"]) > 0:
			out["state"] = "frags"
		else:
			out["state"] = "ready"
	# B1 stats on one scale: a native of the NEXT gem at Full facets = 100 %.
	var top := Ladder.mult(g1, g1, F)
	var s_now := Ladder.mult(n, g, f) / top
	var s_after := Ladder.mult(n, g1, 0) / top
	var s_full := Ladder.mult(n, g1, F) / top
	var s_nat := Ladder.mult(g1, g1, 0) / top
	out["ceiling"] = s_full
	out["bar"] = {"now": s_now, "after": s_after, "full": s_full, "native": s_nat}
	out["equal_gap"] = Ladder.mult(g1, g1, 0) / Ladder.mult(n, g1, 0) - 1.0
	var rows: Array[Dictionary] = []
	if is_hero and int(d.get("might", 0)) > 0:
		# Might moves with the B1 ladder (same level, same ranks); a bare recut changes no number.
		var m := float(d["might"])
		var base := Ladder.mult(n, g, f)
		rows.append(_row("RECUT_ROW_POWER", HeroesText.num(int(m)),
				HeroesText.num(_round10(m * Ladder.mult(n, g1, 0) / base)),
				HeroesText.num(_round10(m * Ladder.mult(n, g1, F) / base)),
				HeroesText.num(_round10(m * Ladder.mult(g1, g1, 0) / base)),
				HeroesText.num(_round10(m * Ladder.mult(g1, g1, F) / base))))
	rows.append(_row("RECUT_ROW_STATS", HeroesText.pct(s_now, 1), HeroesText.pct(s_after, 1),
			HeroesText.pct(s_full, 1), HeroesText.pct(s_nat, 1), HeroesText.pct(1.0, 0)))
	var unlocks: Array[String] = []
	if is_hero:
		var cap_now := Ladder.skill_cap(n, g, f)
		var cap_full := Ladder.skill_cap(n, g1, F)
		rows.append(_row("RECUT_ROW_CAP", str(cap_now), str(Ladder.skill_cap(n, g1, 0)), str(cap_full),
				str(Ladder.skill_cap(g1, g1, 0)), str(Ladder.skill_cap(g1, g1, F))))
		var fn := Ladder.max_form(n)
		var fx := Ladder.max_form(g1)
		var form_cell := HeroesText.roman(fn) + " · " + HeroesText.gem_name(Ladder.GEMS[fn - 1])
		rows.append(_row("RECUT_ROW_FORM", form_cell, form_cell, "",
				HeroesText.roman(fx) + " · " + HeroesText.gem_name(Ladder.GEMS[fx - 1]), ""))
		var a_now := Ladder.awaken_cap(n, g)
		var a_after := Ladder.awaken_cap(n, g1)
		var a_nat := Ladder.awaken_cap(g1, g1)
		var nat_cell := _rank_cell(a_nat)
		if Ladder.born_awakened(g1):
			nat_cell += " · " + HeroesText.t("RECUT_CELL_BORN")
		rows.append(_row("RECUT_ROW_AWAKEN", _rank_cell(a_now), _rank_cell(a_now),
				_rank_cell(a_after) if a_after > 0 else "", nat_cell, ""))
		# Gains are counted from the moment a recut can happen: Full facets of the current gem.
		var dc := cap_full - Ladder.skill_cap(n, g, F)
		if dc > 0:
			unlocks.append(HeroesText.t("RECUT_UNLOCK_CAP_1" if dc == 1 else "RECUT_UNLOCK_CAP_N", [dc]))
		if a_after > a_now:
			unlocks.append(HeroesText.t("RECUT_UNLOCK_AWAKEN") if a_now == 0 else HeroesText.t("RECUT_UNLOCK_AWAKEN_RANK", [a_after]))
	else:
		var tier := HeroesText.roman(Ladder.gem_index(n) + 1)
		rows.append(_row("RECUT_ROW_TIER", HeroesText.t("RECUT_CELL_TIER", [tier]), HeroesText.t("RECUT_CELL_TIER", [tier]), "",
				HeroesText.t("RECUT_CELL_TIER", [HeroesText.roman(gi + 2)]), ""))
	unlocks.append(HeroesText.t("RECUT_UNLOCK_STATS", [HeroesText.pct(Ladder.mult(n, g1, F) / Ladder.mult(n, g, F) - 1.0)]))
	unlocks.append(HeroesText.t("RECUT_UNLOCK_FACETS", [F]))
	out["rows"] = rows
	out["unlocks"] = unlocks
	return out


static func _row(key: String, now: String, after: String, after_full: String, native: String, native_full: String) -> Dictionary:
	return {"key": key, "now": now, "after": after, "after_full": after_full, "native": native, "native_full": native_full}


static func _rank_cell(r: int) -> String:
	return HeroesText.t("RECUT_CELL_RANK", [r]) if r > 0 else HeroesText.t("RECUT_CELL_NONE")


static func _round10(v: float) -> int:
	return int(roundf(v / 10.0)) * 10
