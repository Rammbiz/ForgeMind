class_name HeroesUIModel
extends RefCounted
## The ONE data adapter of the Heroes meta UI (phase H3a). Every heroes screen reads data only
## through these static calls; nothing under scripts/ui/heroes reads Meta, Save or the account.
## In H3a the source is a set of mock account states built from the generated data classes
## (HeroData, ChampionData, TeamData, PortalData, Ladder); phase H3b swaps the private `_acc`
## source for the real Meta API (heroes_design.md §12.2) and keeps every signature below.
##
## Switching the feature on
##   HeroesUIModel.enabled()            # HeroKinds.phase() >= 3  or  HeroesUIModel.force_on
##   HeroesUIModel.force_on = true      # dev override (the gallery sets it)
##   HeroesUIModel.set_state("mid")     # "fresh" (L4) | "mid" (L20) | "late" (L40) | "welcome" (L20, free x10)
##   HeroesUIModel.bus().changed.connect(func(what: String): ...)   # "state" | "heroes" | "portal" | "team" | ...
##
## Queries (all return fresh Dictionaries / Arrays; never mutate them to change the account)
##   heroes() -> Array[Dictionary]          every hero in collector order (owned or not), see hero()
##   hero(id) -> Dictionary                 {id, no, kind "hero", name, title, native, gem, facets, facets_max,
##       full, frags, frags_need, owned, is_new, listed, source {kind start|level|portal, level, seals},
##       level, level_cap, eff_level, synced, class, element, element2, faction, might, is_recut,
##       stat_ratio (≤ 1: stats ÷ a native of the current gem), skills {ult, attack, rally, awakened},
##       recut {can, next_gem, cost, have, max}, in_team, art (HeroArt state)}
##       skill = {rank, cap, cap_native (a native of the current gem at these facets), visible, locked,
##                locked_at, form, form_gem, form_max, form_max_gem (ult only),
##                open, born (awakened only)}
##   champions() / champion(id)            {id, no, kind "champion", name, title, role, native, gem, facets,
##       full, frags, frags_need, owned, is_new, listed, class, element, faction, slot, action_tier,
##       is_recut, in_team, art}
##   champion_level() -> {level, cap, max, next_world}
##   team() -> {hero, champions [id or ""], slots, slots_max, slot3_at, synergy {mode simple|full,
##       lines [{key, args, text}], factions {id: n}, classes {id: n}, elements {id: n}}}
##   portal_state() -> {open, welcome, beacons, seals, since_e, since_l, pity_e_left, pity_l_left,
##       pity_e_hard, pity_l_soft, pity_l_hard, topaz_chance_next, seal_target {gem, price},
##       focus {gem: id}, pool [ids], cost_x1, cost_x10}
##   seal_shop() -> Array {id, gem, price, owned, affordable, gives hero|frags|tomes, frags, tomes}
##   odds_rows(pool "portal"|"chest") -> {gems [{gem, base, total, one_in}], groups [{key, base, total,
##       one_in}], heroes [{id, gem, pct, owned}], lines [{key, args, text}]}  (all generated from data)
##   history() -> Array {n, id, kind, gem, is_new, fragments}, newest first
##   currencies() -> {coins, beacons, seals, tomes, ore}
##   unlocks() -> {level, world, champions, portal, portal_teaser, skills, skills_teaser, workshop,
##       workshop_teaser, slot3, seer, synergy_full}
##
## Mock mutations (ceremony screens drive these; each emits bus().changed)
##   summon(pool "portal", count 1|10, seed -1) -> Array {id, kind, gem, is_new, fragments, tomes,
##       forced}   PortalData odds + both pities + duplicate protection + Focus, seeded RNG
##       (same state + same seed = same results), welcome x10 rule, +Seals, -Beacons.
##   force_next = [{id, gem}]               the next summons return exactly these (gallery walkouts)
##   facet_up(id) -> bool · recut(id) -> bool · seal_pick(id) -> Dictionary · set_team(hero, champs)
##   set_focus(gem, id) · mark_seen(id) · level_up(id) -> bool

## Mock account states (set_state).
const STATES: Array[String] = ["fresh", "mid", "late", "welcome"]

## Dev override: the Hall shows even while HeroKinds.phase() < 3 (set by the gallery).
static var force_on := false
## Next summons return exactly these: [{"id": "vesta", "gem": "L"}, ...] (consumed in order).
static var force_next: Array = []

static var _acc: Dictionary = {}
static var _bus: Bus
static var _odds_cache: Dictionary = {}
static var _roll_count := 0


class Bus extends RefCounted:
	signal changed(what: String)


## True when the new Hall replaces the shipped Heroes tab.
static func enabled() -> bool:
	return force_on or HeroKinds.phase() >= 3


## Change notifications ("state", "heroes", "champions", "team", "portal", "wallet").
static func bus() -> Bus:
	if _bus == null:
		_bus = Bus.new()
	return _bus


static func _emit(what: String) -> void:
	bus().changed.emit(what)


static func state_name() -> String:
	_ensure()
	return str(_acc.get("state", ""))


## Loads mock account `name` (one of STATES).
static func set_state(name: String) -> void:
	_acc = _build_state(name if name in STATES else "mid")
	_roll_count = 0
	force_next.clear()
	_emit("state")


static func _ensure() -> void:
	if _acc.is_empty():
		_acc = _build_state("mid")


# ================================================================== queries

static func unlocks() -> Dictionary:
	_ensure()
	var L := int(_acc["level"])
	var u := HeroData.UNLOCK_AT
	return {
		"level": L, "world": world_of(L),
		"champions": L >= int(u["champions"]),
		"portal": L >= int(u["portal"]), "portal_teaser": L >= int(u["portal"]) - 2,
		"skills": L >= int(u["skills"]), "skills_teaser": L >= int(u["skills"]) - 2,
		"workshop": L >= int(u["workshop"]), "workshop_teaser": L >= int(u["workshop"]) - 2,
		"slot3": L >= int(u["slot3"]), "seer": L >= int(u["seer"]),
		"synergy_full": L >= int(u["portal"]),
	}


## World reached at frontier level `level` (8 levels per world, the boss at 8k).
static func world_of(level: int) -> int:
	return mini(7, level / 8 + 1)


static func currencies() -> Dictionary:
	_ensure()
	return (_acc["wallet"] as Dictionary).duplicate()


static func heroes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in HeroData.HERO_ORDER:
		out.append(hero(id))
	return out


static func hero(id: String) -> Dictionary:
	_ensure()
	if not HeroData.HEROES.has(id):
		return {}
	var d: Dictionary = HeroData.HEROES[id]
	var st: Dictionary = (_acc["heroes"] as Dictionary).get(id, {})
	var un := unlocks()
	var native := str(d["native"])
	var owned := bool(st.get("owned", false))
	var gem := str(st.get("gem", native))
	var f := int(st.get("facets", 0))
	var lvl := int(st.get("lvl", 1))
	var cap := level_cap()
	var best := 1
	for hid: String in _acc["heroes"]:
		var o: Dictionary = _acc["heroes"][hid]
		if bool(o.get("owned", false)):
			best = maxi(best, int(o.get("lvl", 1)))
	var eff := maxi(lvl, mini(cap, best - HeroData.HERO_SYNC_BEHIND)) if owned else lvl
	var sk: Dictionary = st.get("skills", {})
	var g := Ladder.gem_index(gem)
	var source := {"kind": "portal", "level": PortalData.UNLOCK_PORTAL, "seals": PortalData.seal_price(native)}
	if id in HeroData.STARTERS:
		source = {"kind": "start" if int(HeroData.STARTER_AT[id]) == 0 else "level", "level": int(HeroData.STARTER_AT[id]), "seals": 0}
	var listed := owned or id in HeroData.STARTERS or bool(un["portal_teaser"])
	var skills := {}
	for s: String in ["ult", "attack", "rally"]:
		var rank := int(sk.get(s, 1))
		var row := {
			"rank": rank, "cap": Ladder.skill_cap(native, gem, f), "cap_native": Ladder.skill_cap(gem, gem, f),
			"visible": true, "locked": not bool(un["skills"]), "locked_at": int(HeroData.UNLOCK_AT["skills"]),
		}
		if s == "rally":
			row["visible"] = bool(un["skills_teaser"])
		if s == "ult":
			var form := Ladder.ult_form(native, rank)
			row["form"] = form
			row["form_gem"] = Ladder.GEMS[maxi(form - 1, 0)]
			row["form_max"] = Ladder.max_form(native)
			row["form_max_gem"] = Ladder.GEMS[Ladder.max_form(native) - 1]
		skills[s] = row
	var awk_rank := int(sk.get("awakened", 0))
	var can_awk := Ladder.can_awaken(native, gem, f)
	skills["awakened"] = {
		"rank": awk_rank, "cap": Ladder.awaken_cap(native, gem), "cap_native": Ladder.awaken_cap(gem, gem),
		"open": can_awk or awk_rank > 0, "born": Ladder.born_awakened(native),
		"visible": Ladder.born_awakened(native) or can_awk or awk_rank > 0,
		"locked": not (can_awk or awk_rank > 0), "locked_at": 0,
	}
	var max_gem := Ladder.gem_index(Ladder.HERO_MAX_GEM)
	var recut := {"can": false, "next_gem": "", "cost": 0, "have": int(st.get("frags", 0)), "max": g >= max_gem}
	if g < max_gem:
		recut["next_gem"] = Ladder.GEMS[g + 1]
		recut["cost"] = HeroData.RECUT_FRAGS[g]
		recut["can"] = owned and f == Ladder.FACETS_PER_GEM and int(st.get("frags", 0)) >= HeroData.RECUT_FRAGS[g]
	return {
		"id": id, "no": int(d["no"]), "kind": "hero",
		"name": HeroesText.hero_name(id), "title": HeroesText.hero_title(id),
		"native": native, "gem": gem, "facets": f, "facets_max": Ladder.FACETS_PER_GEM,
		"full": f == Ladder.FACETS_PER_GEM,
		"frags": int(st.get("frags", 0)), "frags_need": _frags_need(gem, f, max_gem),
		"owned": owned, "is_new": bool(st.get("is_new", false)), "listed": listed, "source": source,
		"level": lvl, "level_cap": cap, "eff_level": eff, "synced": owned and eff > lvl,
		"class": str(d["class"]), "element": str(d["element"]), "element2": str(d["element2"]),
		"faction": str(d["faction"]),
		"might": _might(native, gem, f, eff, sk) if owned else 0,
		"is_recut": gem != native,
		"stat_ratio": Ladder.mult(native, gem, f) / Ladder.mult(gem, gem, f),
		"skills": skills, "recut": recut,
		"in_team": str((_acc["team"] as Dictionary).get("hero", "")) == id,
		"art": HeroArt.state(id),
	}


static func champions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ChampionData.CHAMPION_ORDER:
		out.append(champion(id))
	return out


static func champion(id: String) -> Dictionary:
	_ensure()
	if not ChampionData.CHAMPIONS.has(id):
		return {}
	var d: Dictionary = ChampionData.CHAMPIONS[id]
	var st: Dictionary = (_acc["champions"] as Dictionary).get(id, {})
	var native := str(d["native"])
	var gem := str(st.get("gem", native))
	var f := int(st.get("facets", 0))
	var owned := bool(st.get("owned", false))
	return {
		"id": id, "no": int(d["no"]), "kind": "champion",
		"name": HeroesText.champ_name(id), "title": HeroesText.champ_title(id), "role": HeroesText.champ_role(id),
		"native": native, "gem": gem, "facets": f, "full": f == Ladder.FACETS_PER_GEM,
		"frags": int(st.get("frags", 0)),
		"frags_need": _frags_need(gem, f, Ladder.gem_index(Ladder.CHAMPION_MAX_GEM)),
		"owned": owned, "is_new": bool(st.get("is_new", false)), "listed": bool(unlocks()["champions"]),
		"class": str(d["class"]), "element": str(d["element"]), "faction": str(d["faction"]),
		"slot": str(d["slot"]), "action_tier": ChampionData.action_tier(id), "is_recut": gem != native,
		"in_team": id in ((_acc["team"] as Dictionary)["champions"] as Array),
		"art": HeroArt.state(id),
	}


static func champion_level() -> Dictionary:
	_ensure()
	var w := world_of(int(_acc["level"]))
	var cap := ChampionData.level_cap(w, false)
	return {"level": int(_acc["champion_level"]), "cap": cap, "max": ChampionData.CHAMP_LEVEL_MAX, "next_world": w + 1}


## Hero level cap at the current frontier: 6 + 3 x world reached (§3.1).
static func level_cap() -> int:
	_ensure()
	return mini(30, 6 + 3 * world_of(int(_acc["level"])))


static func team() -> Dictionary:
	_ensure()
	var t: Dictionary = _acc["team"]
	var L := int(_acc["level"])
	var slots := ChampionData.slots_at(L)
	var champs: Array = (t["champions"] as Array).duplicate()
	while champs.size() < slots:
		champs.append("")
	return {
		"hero": str(t["hero"]), "champions": champs, "slots": slots, "slots_max": 3,
		"slot3_at": int(HeroData.UNLOCK_AT["slot3"]), "synergy": _synergy(str(t["hero"]), champs),
	}


static func portal_state() -> Dictionary:
	_ensure()
	var p: Dictionary = _acc["portal"]
	var w: Dictionary = _acc["wallet"]
	var since_e := int(p["since_e"])
	var since_l := int(p["since_l"])
	var seals := int(w["seals"])
	var target := {"gem": "M", "price": PortalData.seal_price("M")}
	for g: String in ["E", "L", "M"]:
		if PortalData.seal_price(g) > seals:
			target = {"gem": g, "price": PortalData.seal_price(g)}
			break
	return {
		"open": bool(unlocks()["portal"]), "welcome": bool(p["welcome"]),
		"beacons": int(w["beacons"]), "seals": seals,
		"since_e": since_e, "since_l": since_l,
		"pity_e_hard": int(PortalData.PITY_E["hard"]),
		"pity_l_soft": int(PortalData.PITY_L["soft_from"]), "pity_l_hard": int(PortalData.PITY_L["hard"]),
		"pity_e_left": int(PortalData.PITY_E["hard"]) - since_e,
		"pity_l_left": int(PortalData.PITY_L["hard"]) - since_l,
		"topaz_chance_next": PortalData.topaz_plus_chance(since_l),
		"seal_target": target, "focus": (p["focus"] as Dictionary).duplicate(), "pool": _pool(),
		"cost_x1": PortalData.BEACONS_PER_SUMMON, "cost_x10": PortalData.BEACONS_PER_SUMMON * PortalData.X10_SUMMONS,
	}


static func seal_shop() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	var seals := int((_acc["wallet"] as Dictionary)["seals"])
	for id: String in _pool():
		var native := HeroData.native(id)
		var price := PortalData.seal_price(native)
		if price <= 0:
			continue
		var h := hero(id)
		var frags := PortalData.OWNED_SEAL_PICK_MULT * HeroData.dup_frags(native)
		var gives := "hero"
		var tomes := 0
		if bool(h["owned"]):
			gives = "frags"
			if str(h["gem"]) == Ladder.HERO_MAX_GEM and bool(h["full"]):
				gives = "tomes"
				tomes = frags / HeroData.OVERFLOW_FRAGS_PER_TOME
		out.append({"id": id, "gem": native, "price": price, "owned": bool(h["owned"]),
				"affordable": seals >= price, "gives": gives, "frags": frags if gives == "frags" else 0, "tomes": tomes})
	return out


static func history() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for e in (_acc["portal"] as Dictionary)["history"]:
		out.append((e as Dictionary).duplicate())
	return out


## The (i) sheet rows, all generated from PortalData (§7.2, §9.5 row 3).
static func odds_rows(pool := "portal") -> Dictionary:
	_ensure()
	if pool == "chest":
		return _chest_odds()
	var total := consolidated_odds()
	var gems: Array[Dictionary] = []
	for g: String in Ladder.GEMS:
		var tv := float(total[g])
		gems.append({"gem": g, "base": float(PortalData.BASE_ODDS[g]), "total": tv, "one_in": 1.0 / maxf(tv, 1e-9)})
	var lp := float(total["L"]) + float(total["M"])
	var ep := lp + float(total["E"])
	var lb := float(PortalData.BASE_ODDS["L"]) + float(PortalData.BASE_ODDS["M"])
	var eb := lb + float(PortalData.BASE_ODDS["E"])
	var groups: Array[Dictionary] = [
		{"key": "PORTAL_TOPAZ_PLUS", "base": lb, "total": lp, "one_in": 1.0 / lp},
		{"key": "PORTAL_AMETHYST_PLUS", "base": eb, "total": ep, "one_in": 1.0 / ep},
	]
	var heroes_rows: Array[Dictionary] = []
	var per := _per_hero(total)
	for id: String in HeroData.HERO_ORDER:
		if per.has(id):
			heroes_rows.append({"id": id, "gem": HeroData.native(id), "pct": float(per[id]), "owned": bool(hero(id)["owned"])})
	var pl := PortalData.PITY_L
	var lines: Array[Dictionary] = [
		_line("PORTAL_PITY_E_LINE", [int(PortalData.PITY_E["hard"])]),
		_line("PORTAL_PITY_L_LINE", [int(pl["soft_from"]), HeroesText.pct(float(pl["step"])), int(pl["hard"])]),
		_line("PORTAL_OPAL_LINE", [HeroesText.pct(PortalData.OPAL_SHARE_IN_L), HeroesText.pct(1.0 - PortalData.OPAL_SHARE_IN_L)]),
		_line("PORTAL_DUP_LINE", []),
		_line("PORTAL_FOCUS_60", [HeroesText.pct(PortalData.FOCUS_TOTAL)]),
		_line("PORTAL_SEAL_EARN", [PortalData.SEALS_PER_SUMMON]),
		_line("PORTAL_PERMANENT", []),
	]
	return {"gems": gems, "groups": groups, "heroes": heroes_rows, "lines": lines}


## Per-summon gem shares including both pities (the stationary pity chain, §7.2 "Consolidated").
## Computed once from PortalData by power iteration over the (since_e, since_l) states.
static func consolidated_odds() -> Dictionary:
	if not _odds_cache.is_empty():
		return _odds_cache
	var he := int(PortalData.PITY_E["hard"])
	var hl := int(PortalData.PITY_L["hard"])
	var non_l := 1.0 - float(PortalData.BASE_ODDS["L"]) - float(PortalData.BASE_ODDS["M"])
	var dist := PackedFloat64Array()
	dist.resize(he * hl)
	dist[0] = 1.0
	var acc := {"C": 0.0, "R": 0.0, "E": 0.0, "L": 0.0, "M": 0.0}
	var iters := 240
	for it in iters:
		var nd := PackedFloat64Array()
		nd.resize(he * hl)
		var out := {"C": 0.0, "R": 0.0, "E": 0.0, "L": 0.0, "M": 0.0}
		for a in he:
			for b in hl:
				var p := dist[a * hl + b]
				if p <= 0.0:
					continue
				var lc := PortalData.topaz_plus_chance(b)
				out["M"] += p * lc * PortalData.OPAL_SHARE_IN_L
				out["L"] += p * lc * (1.0 - PortalData.OPAL_SHARE_IN_L)
				nd[0] += p * lc
				var rest := p * (1.0 - lc)
				var b2 := mini(b + 1, hl - 1)
				if a + 1 >= he:
					out["E"] += rest
					nd[b2] += rest
				else:
					for gk: String in ["C", "R", "E"]:
						var q := rest * float(PortalData.BASE_ODDS[gk]) / non_l
						out[gk] += q
						if gk == "E":
							nd[b2] += q
						else:
							nd[(a + 1) * hl + b2] += q
		dist = nd
		if it >= iters / 2:
			for gk: String in out:
				acc[gk] += float(out[gk])
	var s := 0.0
	for gk: String in acc:
		s += float(acc[gk])
	for gk: String in acc:
		_odds_cache[gk] = float(acc[gk]) / s
	return _odds_cache


# ================================================================== mutations

## Rolls `count` summons from `pool` ("portal"; "chest" = one Hero Chest per count, 2 cards each).
## Deterministic: the same state and the same `seed` give the same results (seed < 0 = an internal
## counter). force_next entries are consumed first. Returns [{id, kind, gem, is_new, fragments,
## tomes, forced}].
static func summon(pool := "portal", count := 1, seed := -1) -> Array[Dictionary]:
	_ensure()
	var rng := RandomNumberGenerator.new()
	_roll_count += 1
	rng.seed = hash([state_name(), seed if seed >= 0 else _roll_count, count, pool])
	var out: Array[Dictionary] = []
	if pool == "chest":
		for i in count:
			out.append_array(_roll_chest(rng))
		_emit("champions")
		return out
	var p: Dictionary = _acc["portal"]
	var w: Dictionary = _acc["wallet"]
	var welcome := bool(p["welcome"]) and count == PortalData.X10_SUMMONS
	if not welcome:
		w["beacons"] = maxi(0, int(w["beacons"]) - count * PortalData.BEACONS_PER_SUMMON)
	var got_l := false
	for i in count:
		var gem := ""
		var forced := false
		var fid := ""
		if not force_next.is_empty():
			var fx: Dictionary = force_next.pop_front()
			fid = str(fx.get("id", ""))
			gem = str(fx.get("gem", HeroData.native(fid) if fid != "" else "L"))
			forced = true
		elif welcome and i == count - 1 and not got_l:
			gem = "M" if rng.randf() < PortalData.OPAL_SHARE_IN_L else "L"
		else:
			gem = _roll_gem(rng, int(p["since_e"]), int(p["since_l"]))
		var gi := Ladder.gem_index(gem)
		if gi >= Ladder.gem_index("L"):
			got_l = true
			p["since_l"] = 0
			p["since_e"] = 0
		elif gi >= Ladder.gem_index("E"):
			p["since_l"] = int(p["since_l"]) + 1
			p["since_e"] = 0
		else:
			p["since_l"] = int(p["since_l"]) + 1
			p["since_e"] = int(p["since_e"]) + 1
		var id := fid if fid != "" else _pick_hero(rng, gem)
		var res := _grant_hero(id)
		res["forced"] = forced
		w["seals"] = int(w["seals"]) + PortalData.SEALS_PER_SUMMON
		out.append(res)
		var hist: Array = p["history"]
		hist.push_front({"n": int(p["total"]) + 1, "id": id, "kind": "hero", "gem": HeroData.native(id),
				"is_new": bool(res["is_new"]), "fragments": int(res["fragments"])})
		p["total"] = int(p["total"]) + 1
		if hist.size() > 100:
			hist.resize(100)
	if welcome:
		p["welcome"] = false
	_emit("portal")
	_emit("heroes")
	return out


## Buys a facet with banked fragments (micro ceremony). False when it cannot.
static func facet_up(id: String) -> bool:
	var st := _state_of(id)
	if st.is_empty() or not bool(st.get("owned", false)):
		return false
	var g := Ladder.gem_index(str(st["gem"]))
	var f := int(st.get("facets", 0))
	if f >= Ladder.FACETS_PER_GEM:
		return false
	var need: int = HeroData.FACET_FRAGS[g][f]
	if int(st["frags"]) < need:
		return false
	st["frags"] = int(st["frags"]) - need
	st["facets"] = f + 1
	if bool(st["facets"] == Ladder.FACETS_PER_GEM) and Ladder.can_awaken(_native_of(id), str(st["gem"]), Ladder.FACETS_PER_GEM):
		var sk: Dictionary = st.get("skills", {})
		sk["awakened"] = maxi(1, int(sk.get("awakened", 0)))
		st["skills"] = sk
	_emit("heroes" if HeroData.HEROES.has(id) else "champions")
	return true


## Recuts `id` to the next gem (facets restart at 0, no number drops). False when it cannot.
static func recut(id: String) -> bool:
	var st := _state_of(id)
	if st.is_empty() or int(st.get("facets", 0)) < Ladder.FACETS_PER_GEM:
		return false
	var g := Ladder.gem_index(str(st["gem"]))
	var max_g := Ladder.gem_index(Ladder.HERO_MAX_GEM if HeroData.HEROES.has(id) else Ladder.CHAMPION_MAX_GEM)
	if g >= max_g or int(st["frags"]) < HeroData.RECUT_FRAGS[g]:
		return false
	st["frags"] = int(st["frags"]) - HeroData.RECUT_FRAGS[g]
	st["gem"] = Ladder.GEMS[g + 1]
	st["facets"] = 0
	_emit("heroes" if HeroData.HEROES.has(id) else "champions")
	return true


## Seal shop pick: a new hero, or 2 x DUP fragments for an owned one (overflow -> Tomes).
static func seal_pick(id: String) -> Dictionary:
	_ensure()
	var w: Dictionary = _acc["wallet"]
	var price := PortalData.seal_price(HeroData.native(id))
	if price <= 0 or int(w["seals"]) < price:
		return {}
	w["seals"] = int(w["seals"]) - price
	var st := _state_of(id)
	var res := {"id": id, "kind": "hero", "gem": HeroData.native(id), "is_new": false, "fragments": 0, "tomes": 0, "forced": false}
	if not bool(st.get("owned", false)):
		st["owned"] = true
		st["is_new"] = true
		res["is_new"] = true
	else:
		var fr := PortalData.OWNED_SEAL_PICK_MULT * HeroData.dup_frags(HeroData.native(id))
		res["fragments"] = fr
		st["frags"] = int(st.get("frags", 0)) + fr
	_emit("portal")
	_emit("heroes")
	return res


## Sets the team (hero id + champion ids; extra champions beyond the open slots are dropped).
static func set_team(hero_id: String, champs: Array) -> void:
	_ensure()
	var slots := ChampionData.slots_at(int(_acc["level"]))
	var c: Array = []
	for x in champs:
		if c.size() < slots and str(x) != "" and not str(x) in c:
			c.append(str(x))
	_acc["team"] = {"hero": hero_id, "champions": c}
	_emit("team")


static func set_focus(gem: String, id: String) -> void:
	_ensure()
	var f: Dictionary = (_acc["portal"] as Dictionary)["focus"]
	if id == "":
		f.erase(gem)
	else:
		f[gem] = id
	_emit("portal")


## Clears the NEW seal of `id` (hero or champion).
static func mark_seen(id: String) -> void:
	var st := _state_of(id)
	if not st.is_empty() and bool(st.get("is_new", false)):
		st["is_new"] = false
		_emit("heroes" if HeroData.HEROES.has(id) else "champions")


## Mock hero level-up within the world cap (coins are not modelled in H3a).
static func level_up(id: String) -> bool:
	var st := _state_of(id)
	if st.is_empty() or not bool(st.get("owned", false)) or int(st["lvl"]) >= level_cap():
		return false
	st["lvl"] = int(st["lvl"]) + 1
	_emit("heroes")
	return true


# ================================================================== internals

static func _state_of(id: String) -> Dictionary:
	_ensure()
	if HeroData.HEROES.has(id):
		return (_acc["heroes"] as Dictionary).get(id, {})
	return (_acc["champions"] as Dictionary).get(id, {})


static func _native_of(id: String) -> String:
	if HeroData.HEROES.has(id):
		return HeroData.native(id)
	return str((ChampionData.CHAMPIONS.get(id, {}) as Dictionary).get("native", "C"))


static func _frags_need(gem: String, f: int, max_g: int) -> int:
	var g := Ladder.gem_index(gem)
	if f < Ladder.FACETS_PER_GEM:
		return HeroData.FACET_FRAGS[g][f]
	return HeroData.RECUT_FRAGS[g] if g < max_g else 0


## Mock Might (illustrative power index; H3b reads the real one from Meta).
static func _might(native: String, gem: String, f: int, lvl: int, sk: Dictionary) -> int:
	var skill := 1.0 + Ladder.ULT_RANK_STEP * U_SHARE_K * (int(sk.get("ult", 1)) - 1) \
			+ Ladder.ATK_RANK_STEP * (int(sk.get("attack", 1)) - 1) + Ladder.AWK_STEP * int(sk.get("awakened", 0))
	var v := 1150.0 * Ladder.mult(native, gem, f) * (1.0 + Ladder.LV_DMG * (lvl - 1)) * skill
	return int(roundf(v / 10.0)) * 10

const U_SHARE_K := 0.3


## Heroes that can come out of the Portal now (Мейра only once she has joined).
static func _pool() -> Array[String]:
	var out: Array[String] = []
	for id: String in HeroData.HERO_ORDER:
		if id == "seer" and not bool(unlocks()["seer"]) and not bool(hero(id)["owned"]):
			continue
		out.append(id)
	return out


static func _roll_gem(rng: RandomNumberGenerator, since_e: int, since_l: int) -> String:
	var lc := PortalData.topaz_plus_chance(since_l)
	var r := rng.randf()
	if r < lc:
		return "M" if rng.randf() < PortalData.OPAL_SHARE_IN_L else "L"
	if since_e + 1 >= int(PortalData.PITY_E["hard"]):
		return "E"
	var non_l := float(PortalData.BASE_ODDS["C"]) + float(PortalData.BASE_ODDS["R"]) + float(PortalData.BASE_ODDS["E"])
	var x := rng.randf() * non_l
	if x < float(PortalData.BASE_ODDS["C"]):
		return "C"
	if x < float(PortalData.BASE_ODDS["C"]) + float(PortalData.BASE_ODDS["R"]):
		return "R"
	return "E"


## Who comes out for a rolled `gem`: an unowned hero first; else the Focus gets FOCUS_TOTAL; else even.
static func _pick_hero(rng: RandomNumberGenerator, gem: String) -> String:
	var weights := _gem_split(gem)
	var x := rng.randf()
	var acc := 0.0
	var last := ""
	for id: String in weights:
		acc += float(weights[id])
		last = id
		if x < acc:
			return id
	return last


## id -> share of `gem`'s results (sums to 1 over the eligible heroes of that gem).
static func _gem_split(gem: String) -> Dictionary:
	var elig: Array[String] = []
	for id in _pool():
		if HeroData.native(id) == gem:
			elig.append(id)
	var unowned: Array[String] = []
	for id in elig:
		if not bool(hero(id)["owned"]):
			unowned.append(id)
	var out := {}
	if not unowned.is_empty():
		for id in unowned:
			out[id] = 1.0 / unowned.size()
		return out
	var focus := str(((_acc["portal"] as Dictionary)["focus"] as Dictionary).get(gem, ""))
	if focus != "" and focus in elig and elig.size() > 1:
		for id in elig:
			out[id] = PortalData.FOCUS_TOTAL if id == focus else (1.0 - PortalData.FOCUS_TOTAL) / (elig.size() - 1)
		return out
	for id in elig:
		out[id] = 1.0 / maxf(1.0, elig.size())
	return out


static func _per_hero(total: Dictionary) -> Dictionary:
	var out := {}
	for g: String in Ladder.GEMS:
		var split := _gem_split(g)
		for id: String in split:
			out[id] = float(total[g]) * float(split[id])
	return out


static func _grant_hero(id: String) -> Dictionary:
	var st := _state_of(id)
	var native := HeroData.native(id)
	var res := {"id": id, "kind": "hero", "gem": native, "is_new": false, "fragments": 0, "tomes": 0}
	if not bool(st.get("owned", false)):
		st["owned"] = true
		st["is_new"] = true
		st["gem"] = native
		st["facets"] = 0
		st["frags"] = 0
		st["lvl"] = maxi(1, level_cap() - 6)
		st["skills"] = {"ult": 1, "attack": 1, "rally": 1, "awakened": 1 if Ladder.born_awakened(native) else 0}
		res["is_new"] = true
	else:
		var fr := HeroData.dup_frags(native)
		if str(st["gem"]) == Ladder.HERO_MAX_GEM and int(st["facets"]) >= Ladder.FACETS_PER_GEM:
			res["tomes"] = fr / HeroData.OVERFLOW_FRAGS_PER_TOME
			(_acc["wallet"] as Dictionary)["tomes"] = int((_acc["wallet"] as Dictionary)["tomes"]) + int(res["tomes"])
		else:
			st["frags"] = int(st.get("frags", 0)) + fr
			res["fragments"] = fr
	return res


static func _roll_chest(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in int(PortalData.CHEST_CARDS["hero"]):
		var pity := int(_acc.get("chest_pity", 0)) + 1 >= PortalData.CHEST_PITY_L and i == 0
		var gem := PortalData.CHEST_PITY_GEM
		if not pity:
			var x := rng.randf()
			var acc := 0.0
			for g: String in PortalData.CHEST_ODDS:
				acc += float(PortalData.CHEST_ODDS[g])
				gem = g
				if x < acc:
					break
		var elig: Array[String] = []
		var unowned: Array[String] = []
		for id: String in ChampionData.CHAMPION_ORDER:
			if str(ChampionData.CHAMPIONS[id]["native"]) == gem:
				elig.append(id)
				if not bool(_state_of(id).get("owned", false)):
					unowned.append(id)
		var pick_from := unowned if not unowned.is_empty() else elig
		var id: String = pick_from[rng.randi_range(0, pick_from.size() - 1)]
		var st := _state_of(id)
		var res := {"id": id, "kind": "champion", "gem": gem, "is_new": false, "fragments": 0, "tomes": 0, "forced": false}
		if not bool(st.get("owned", false)):
			st["owned"] = true
			st["is_new"] = true
			res["is_new"] = true
		else:
			var fr := HeroData.dup_frags(gem)
			st["frags"] = int(st.get("frags", 0)) + fr
			res["fragments"] = fr
		out.append(res)
	var got_l := false
	for r in out:
		if str(r["gem"]) == PortalData.CHEST_PITY_GEM:
			got_l = true
	_acc["chest_pity"] = 0 if got_l else int(_acc.get("chest_pity", 0)) + 1
	return out


static func _chest_odds() -> Dictionary:
	var gems: Array[Dictionary] = []
	for g: String in PortalData.CHEST_ODDS:
		var v := float(PortalData.CHEST_ODDS[g])
		gems.append({"gem": g, "base": v, "total": v, "one_in": 1.0 / v})
	var lines: Array[Dictionary] = [
		_line("CHEST_PITY", [PortalData.CHEST_PITY_L]),
		_line("CHEST_TEAM_WEIGHT", [PortalData.CHEST_TEAM_HERO_WEIGHT]),
		_line("PORTAL_FOCUS_60", [HeroesText.pct(PortalData.CHEST_FOCUS_TOTAL)]),
	]
	return {"gems": gems, "groups": [], "heroes": [], "lines": lines}


static func _line(key: String, args: Array) -> Dictionary:
	return {"key": key, "args": args, "text": HeroesText.t(key, args)}


## Synergy of a team (§5.3, §5.5): one line per ACTIVE bonus; counts for the full panel.
static func _synergy(hero_id: String, champs: Array) -> Dictionary:
	var members: Array[Dictionary] = []
	if hero_id != "" and HeroData.HEROES.has(hero_id):
		members.append(HeroData.HEROES[hero_id])
	for c in champs:
		if str(c) != "" and ChampionData.CHAMPIONS.has(str(c)):
			members.append(ChampionData.CHAMPIONS[str(c)])
	var fac := {}
	var cls := {}
	var el := {}
	for m in members:
		fac[m["faction"]] = int(fac.get(m["faction"], 0)) + 1
		cls[m["class"]] = int(cls.get(m["class"], 0)) + 1
		el[m["element"]] = int(el.get(m["element"], 0)) + 1
	var lines: Array[Dictionary] = []
	for f: String in TeamData.FACTIONS:
		var n := int(fac.get(f, 0))
		var tier := 0
		for t in TeamData.FACTION_MEMBERS_FOR_TIER.size():
			if n >= TeamData.FACTION_MEMBERS_FOR_TIER[t] and t > 0:
				tier = t
		if tier <= 0:
			continue
		var v: Variant = (TeamData.FACTION_RUN[f]["tiers"] as Array)[tier]
		var shown: Variant = v if f == "dawn" else HeroesText.pct(absf(float(v)))
		lines.append(_line("SYN_" + f.to_upper(), [HeroesText.faction_label(f), HeroesText.roman(tier), shown]))
	for c: String in TeamData.CLASSES:
		if int(cls.get(c, 0)) >= 2:
			var eff: Dictionary = TeamData.CLASS_PAIR_RUN[c]
			var first: float = absf(float(eff.values()[0]))
			lines.append(_line("SYN_PAIR_" + c.to_upper(), [HeroesText.pct(first)]))
	var mode := "full" if bool(unlocks()["synergy_full"]) else "simple"
	if mode == "full":
		for e: String in TeamData.ELEMENTS:
			if int(el.get(e, 0)) > 0:
				var a := minf(TeamData.AFFINITY_CAP, TeamData.AFFINITY_PER * int(el[e]))
				lines.append(_line("SYN_AFFINITY", [HeroesText.element_label(e), HeroesText.pct(a)]))
	return {"mode": mode, "lines": lines, "factions": fac, "classes": cls, "elements": el}


# ================================================================== mock states

static func _hero_st(owned: bool, gem: String, facets: int, frags: int, lvl: int, ult := 1, atk := 1, rally := 1, awk := -1, is_new := false) -> Dictionary:
	return {"owned": owned, "gem": gem, "facets": facets, "frags": frags, "lvl": lvl, "is_new": is_new,
			"skills": {"ult": ult, "attack": atk, "rally": rally, "awakened": maxi(awk, 0)}}


static func _champ_st(owned: bool, gem: String, facets := 0, frags := 0, is_new := false) -> Dictionary:
	return {"owned": owned, "gem": gem, "facets": facets, "frags": frags, "is_new": is_new}


static func _build_state(name: String) -> Dictionary:
	var acc := {
		"state": name, "level": 20, "heroes": {}, "champions": {}, "champion_level": 1,
		"team": {"hero": "bolt", "champions": []}, "chest_pity": 0,
		"portal": {"welcome": false, "since_e": 0, "since_l": 0, "focus": {}, "history": [], "total": 0},
		"wallet": {"coins": 0, "beacons": 0, "seals": 0, "tomes": 0, "ore": 0},
	}
	for id: String in HeroData.HERO_ORDER:
		acc["heroes"][id] = _hero_st(false, HeroData.native(id), 0, 0, 1, 1, 1, 1, 1 if Ladder.born_awakened(HeroData.native(id)) else 0)
	for id: String in ChampionData.CHAMPION_ORDER:
		acc["champions"][id] = _champ_st(false, str(ChampionData.CHAMPIONS[id]["native"]))
	var H: Dictionary = acc["heroes"]
	var C: Dictionary = acc["champions"]
	match name:
		"fresh":
			# L4: Руді from the start, Горан just joined (NEW); Мейра waits for the World 3 boss.
			acc["level"] = 4
			H["bolt"] = _hero_st(true, "R", 0, 0, 5)
			H["titan"] = _hero_st(true, "C", 0, 0, 3, 1, 1, 1, 0, true)
			acc["wallet"] = {"coins": 640, "beacons": 0, "seals": 0, "tomes": 0, "ore": 0}
			acc["team"] = {"hero": "bolt", "champions": []}
		"welcome":
			# L20, the first Portal visit: the free x10 is waiting, pity fresh, no Seals yet.
			acc["level"] = 20
			H["bolt"] = _hero_st(true, "R", 1, 6, 14)
			H["titan"] = _hero_st(true, "C", 2, 4, 12)
			for c: String in ["alba", "otto", "mila", "ivo"]:
				C[c] = _champ_st(true, str(ChampionData.CHAMPIONS[c]["native"]))
			acc["champion_level"] = 3
			acc["team"] = {"hero": "bolt", "champions": ["alba", "mila"]}
			acc["portal"]["welcome"] = true
			acc["wallet"] = {"coins": 3900, "beacons": 2, "seals": 0, "tomes": 0, "ore": 0}
		"late":
			# L40: most of the roster, Full facets, Люмен awakened, Іскар recut Аметист -> Топаз,
			# all three team slots, the Workshop open.
			acc["level"] = 40
			H["titan"] = _hero_st(true, "R", 4, 9, 22, 3, 3, 2, 0)
			H["arin"] = _hero_st(true, "C", 5, 44, 21, 3, 3, 3, 0)
			H["bolt"] = _hero_st(true, "R", 5, 44, 24, 5, 4, 4, 0)
			H["eira"] = _hero_st(true, "R", 3, 12, 20, 4, 3, 2, 0)
			H["seer"] = _hero_st(true, "E", 5, 20, 22, 6, 5, 4, 1)
			H["iskar"] = _hero_st(true, "L", 2, 14, 22, 7, 5, 4, 2)
			H["vesta"] = _hero_st(true, "L", 5, 40, 24, 8, 6, 5, 2)
			H["vartan"] = _hero_st(true, "L", 1, 26, 19, 5, 4, 3, 1)
			H["lumen"] = _hero_st(true, "M", 2, 22, 21, 9, 7, 6, 2, true)
			for c: String in ChampionData.CHAMPION_ORDER:
				if c != "menhir" and c != "nimb":
					C[c] = _champ_st(true, str(ChampionData.CHAMPIONS[c]["native"]), 2, 6)
			C["mila"] = _champ_st(true, "R", 3, 8)
			C["alba"] = _champ_st(true, "R", 5, 30)
			C["dara"] = _champ_st(true, "L", 1, 4, true)
			acc["champion_level"] = 9
			acc["team"] = {"hero": "vesta", "champions": ["mila", "ivo", "dara"]}
			acc["portal"] = {"welcome": false, "since_e": 2, "since_l": 23, "focus": {"C": "arin"}, "history": [], "total": 164}
			acc["wallet"] = {"coins": 18240, "beacons": 23, "seals": 164, "tomes": 38, "ore": 126}
			acc["chest_pity"] = 6
		_:
			# "mid", L20 after the welcome x10: six heroes (Веста native Топаз 3/5, Горан recut
			# Кварц -> Сапфір), six champions, team 1 + 2, Seals 37 / 40.
			acc["state"] = "mid"
			acc["level"] = 20
			H["bolt"] = _hero_st(true, "R", 2, 7, 14)
			H["titan"] = _hero_st(true, "R", 1, 4, 13)
			H["arin"] = _hero_st(true, "C", 4, 12, 11)
			H["eira"] = _hero_st(true, "R", 0, 5, 9)
			H["vesta"] = _hero_st(true, "L", 3, 18, 12, 1, 1, 1, 1)
			H["iskar"] = _hero_st(true, "E", 0, 0, 9, 1, 1, 1, 0, true)
			for c: String in ["mila", "ivo", "borko", "alba", "otto", "brant"]:
				C[c] = _champ_st(true, str(ChampionData.CHAMPIONS[c]["native"]))
			C["alba"] = _champ_st(true, "R", 1, 6)
			C["brant"] = _champ_st(true, "E", 0, 0, true)
			acc["champion_level"] = 4
			acc["team"] = {"hero": "bolt", "champions": ["alba", "borko"]}
			acc["portal"] = {"welcome": false, "since_e": 3, "since_l": 12, "focus": {}, "history": [], "total": 37}
			acc["wallet"] = {"coins": 4260, "beacons": 7, "seals": 37, "tomes": 0, "ore": 0}
			acc["chest_pity"] = 4
	if name == "mid" or name not in STATES:
		acc["portal"]["history"] = _mock_history([
			["iskar", true, 0], ["eira", false, 15], ["arin", false, 10], ["bolt", false, 15], ["arin", false, 10],
			["titan", false, 10], ["eira", true, 0], ["arin", true, 0], ["vesta", true, 0], ["titan", false, 10]], 37)
	elif name == "late":
		acc["portal"]["history"] = _mock_history([
			["lumen", true, 0], ["arin", false, 10], ["eira", false, 15], ["seer", false, 25], ["titan", false, 10],
			["vartan", true, 0], ["bolt", false, 15], ["arin", false, 10]], 164)
	return acc


static func _mock_history(rows: Array, total: int) -> Array:
	var out: Array = []
	var n := total
	for r: Array in rows:
		out.append({"n": n, "id": r[0], "kind": "hero", "gem": HeroData.native(str(r[0])), "is_new": r[1], "fragments": r[2]})
		n -= 1
	return out
