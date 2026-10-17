class_name Team
## «Команда / Team» (heroes_design.md §4.1, §5; WS-A rules): 1 hero + champion slots (2 from the
## L14 win, 3 from the L40 win), three presets, and the synergies — faction tiers (2 / 3 / 4 living
## members), class pairs (2 of a class), Affinity (members of an element boost fielded machines of
## that family, cap AFFINITY_CAP) and the per-machine TEAM_B2_CAP. Counts are native-blind and
## gem-blind and use LIVING members (a fallen champion stops counting). Two views of one rule:
## synergy() = the power-index terms (sim _synergy, «Міць» / Auto-team), run_effects() = the effects
## the run applies (TeamData.FACTION_RUN / CLASS_PAIR_RUN). Pure and static, account first.
##
## Account: team {hero, champions [ids], presets [{hero, champions}] x3, preset}.

## Account power weights of the sim (heroes_design.md §8.1: machines 0.50 · hero 0.25 · army 0.25)
## live in TeamData.POWER_W; the champion weight is ChampionData.W_C.


static func team(acc: Dictionary) -> Dictionary:
	return acc.get("team", {}) if acc.get("team") is Dictionary else {}


static func hero(acc: Dictionary) -> String:
	return str(team(acc).get("hero", "bolt"))


static func champions(acc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for c in (team(acc).get("champions", []) as Array):
		out.append(str(c))
	return out


## Champion slots open now (0 before the champions unlock; 2 from L14, 3 from L40).
static func slots(acc: Dictionary) -> int:
	if not Roster.system_open(acc, "champions"):
		return 0
	var n := ChampionData.slots_at(Roster.frontier(acc))
	if n >= 3 and not Roster.system_open(acc, "slot3"):
		n = 2
	return n


## True when hero `id` leads the active team or any preset (Rewrite is blocked for it).
static func uses_hero(acc: Dictionary, id: String) -> bool:
	if hero(acc) == id:
		return true
	for p in (team(acc).get("presets", []) as Array):
		if p is Dictionary and str((p as Dictionary).get("hero", "")) == id:
			return true
	return false


## "" when (hero, champs) is a valid team now, else hero | champion | duplicate | slots.
static func check(acc: Dictionary, hero_id: String, champs: Array) -> String:
	if Roster.kind_of(hero_id) != Roster.KIND_HERO or not Roster.owned(acc, hero_id):
		return "hero"
	if champs.size() > slots(acc):
		return "slots"
	var seen := {}
	for c in champs:
		var cid := str(c)
		if Roster.kind_of(cid) != Roster.KIND_CHAMPION or not Roster.owned(acc, cid):
			return "champion"
		if seen.has(cid):
			return "duplicate"
		seen[cid] = true
	return ""


## Sets the active team: {ok, reason, hero, champions, synergies [ids]}.
static func set_team(acc: Dictionary, hero_id: String, champs: Array, now_s := 0) -> Dictionary:
	var why := check(acc, hero_id, champs)
	if why != "":
		return {"ok": false, "reason": why}
	var list: Array = []
	for c in champs:
		list.append(str(c))
	var t := team(acc)
	t["hero"] = hero_id
	t["champions"] = list
	var ids: Array = synergy(members(hero_id, list))["ids"]
	MetaTelemetry.note(acc, "team_set", {"hero": hero_id, "champions": list.duplicate(), "synergies": ids.duplicate()},
			now_s)
	return {"ok": true, "reason": "", "hero": hero_id, "champions": list, "synergies": ids}


## Places an owned champion in the first free slot (scripted chests, §11.4). Returns true when placed.
static func place(acc: Dictionary, cid: String) -> bool:
	var cs := champions(acc)
	if cs.has(cid) or cs.size() >= slots(acc) or not Roster.owned(acc, cid):
		return false
	cs.append(cid)
	return bool(set_team(acc, hero(acc), cs)["ok"])


## Stores the active team in preset `i` (0..2).
static func save_preset(acc: Dictionary, i: int) -> bool:
	var ps: Array = team(acc).get("presets", [])
	if i < 0 or i >= ps.size():
		return false
	ps[i] = {"hero": hero(acc), "champions": champions(acc).duplicate()}
	return true


## Makes preset `i` the active team (when it is still valid). {ok, reason, ...set_team}.
static func use_preset(acc: Dictionary, i: int, now_s := 0) -> Dictionary:
	var ps: Array = team(acc).get("presets", [])
	if i < 0 or i >= ps.size() or not ps[i] is Dictionary or str((ps[i] as Dictionary).get("hero", "")) == "":
		return {"ok": false, "reason": "preset"}
	var p: Dictionary = ps[i]
	var r := set_team(acc, str(p["hero"]), p.get("champions", []) as Array, now_s)
	if bool(r["ok"]):
		team(acc)["preset"] = i
	return r


# ------------------------------------------------------------------ tags and synergy

## {class, element, faction} of a hero or champion ({} for an unknown id).
static func tags(id: String) -> Dictionary:
	var d: Dictionary = HeroData.HEROES.get(id, ChampionData.CHAMPIONS.get(id, {}))
	if d.is_empty():
		return {}
	return {"class": str(d["class"]), "element": str(d["element"]), "faction": str(d["faction"])}


## Member tag rows of a team; `alive` (optional) lists the champions still standing.
static func members(hero_id: String, champs: Array, alive: Variant = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if hero_id != "":
		out.append(tags(hero_id))
	for c in champs:
		if alive is Array and not (alive as Array).has(str(c)):
			continue
		var t := tags(str(c))
		if not t.is_empty():
			out.append(t)
	return out


## Faction tier 0..3 for `count` living members (FACTION_MEMBERS_FOR_TIER).
static func faction_tier(count: int) -> int:
	var tier := 0
	for i in TeamData.FACTION_MEMBERS_FOR_TIER.size():
		if count >= TeamData.FACTION_MEMBERS_FOR_TIER[i] and TeamData.FACTION_MEMBERS_FOR_TIER[i] > 0:
			tier = i
	return tier


static func _counts(m: Array[Dictionary], key: String) -> Dictionary:
	var out := {}
	for row in m:
		out[row[key]] = int(out.get(row[key], 0)) + 1
	return out


## Power-index synergy (sim _synergy): {rate, charge, ultp, army, cel, aff {element: v}, champ_all,
## champ_cls {class: x}, ids [fac_<f>_<tier> | cls_<class> | affinity]}. Fewer than 2 members: none.
static func synergy(m: Array[Dictionary]) -> Dictionary:
	var syn := {"rate": 1.0, "charge": 1.0, "ultp": 1.0, "army": 0.0, "cel": 0.0, "aff": {}, "champ_all": 1.0,
			"champ_cls": {}, "ids": []}
	if m.size() < 2:
		return syn
	var fc := _counts(m, "faction")
	for fac: String in fc:
		var tier := faction_tier(int(fc[fac]))
		if tier == 0:
			continue
		(syn["ids"] as Array).append("fac_%s_%d" % [fac, tier])
		var v := float((TeamData.FACTION_TIERS[fac] as Array)[tier])
		match fac:
			"dawn", "stoneheart":
				syn["army"] = float(syn["army"]) + v
			"wildfang":
				syn["charge"] = float(syn["charge"]) * v
			_:
				syn["cel"] = float(syn["cel"]) + v
	var cc := _counts(m, "class")
	for cls: String in cc:
		if int(cc[cls]) < 2:
			continue
		(syn["ids"] as Array).append("cls_" + cls)
		var kv: Array = TeamData.CLASS_PAIR[cls]
		var k := str(kv[0])
		var v2 := float(kv[1])
		if k == "army":
			syn["army"] = float(syn["army"]) + v2
		elif k == "champ_all":
			syn["champ_all"] = float(syn["champ_all"]) * v2
			(syn["champ_cls"] as Dictionary)["guardian"] = TeamData.CHAMP_CLS_PAIR["guardian"]
		else:
			syn[k] = float(syn[k]) * v2
			if cls == "ranger":
				(syn["champ_cls"] as Dictionary)["ranger"] = TeamData.CHAMP_CLS_PAIR["ranger"]
	var aff := affinity(m)
	syn["aff"] = aff
	if not aff.is_empty():
		(syn["ids"] as Array).append("affinity")
	return syn


## Affinity: element -> min(AFFINITY_CAP, AFFINITY_PER x living members of it) (2+ members only).
static func affinity(m: Array[Dictionary]) -> Dictionary:
	var out := {}
	if m.size() < 2:
		return out
	var ec := _counts(m, "element")
	for el: String in ec:
		out[el] = minf(TeamData.AFFINITY_CAP, TeamData.AFFINITY_PER * int(ec[el]))
	return out


## The run's synergy effects (§5.1, §5.3): {ids, factions {faction: tier}, effects {stat: value},
## affinity {element: v}}. Faction stats from FACTION_RUN (only the highest tier of each faction
## counts), class pairs from CLASS_PAIR_RUN (values add when two pairs touch one stat).
static func run_effects(m: Array[Dictionary]) -> Dictionary:
	var out := {"ids": synergy(m)["ids"], "factions": {}, "effects": {}, "affinity": affinity(m)}
	if m.size() < 2:
		return out
	var eff: Dictionary = out["effects"]
	var fc := _counts(m, "faction")
	for fac: String in fc:
		var tier := faction_tier(int(fc[fac]))
		if tier == 0:
			continue
		(out["factions"] as Dictionary)[fac] = tier
		var row: Dictionary = TeamData.FACTION_RUN[fac]
		var st := str(row["stat"])
		eff[st] = float(eff.get(st, 0.0)) + float((row["tiers"] as Array)[tier])
	var cc := _counts(m, "class")
	for cls: String in cc:
		if int(cc[cls]) < 2:
			continue
		var pair: Dictionary = TeamData.CLASS_PAIR_RUN[cls]
		for st2: String in pair:
			eff[st2] = float(eff.get(st2, 0.0)) + float(pair[st2])
	return out


## Bucket-2 bonus a team adds to one fielded machine of `family` (§5.2): Affinity (Rift: the best
## count present) + Celestials + the hero's Rally machine hook, capped at TEAM_B2_CAP.
static func machine_b2(m: Array[Dictionary], family: String, rally_add := 0.0) -> float:
	var aff := affinity(m)
	var a := 0.0
	if family == "rift":
		for el: String in aff:
			a = maxf(a, float(aff[el]))
	else:
		a = float(aff.get(family, 0.0))
	return minf(TeamData.TEAM_B2_CAP, a + float(synergy(m)["cel"]) + maxf(0.0, rally_add))


# ------------------------------------------------------------------ team power (Auto-team)

## The hero + champion part of the account power for (hero, champs) (sim team_power without the
## machine level term): W_HERO x hero / meta1 x Meta-1 level curve + W_ARMY x (rally + army
## synergy) + W_C x uptime x Σ champion index + W_MACH x B2_EFF x mean machine synergy over
## `families` (the deck's lead families). Used to rank candidate teams (Auto-team, delta badges).
static func score(acc: Dictionary, hero_id: String, champs: Array, families: Array = []) -> float:
	var m := members(hero_id, champs)
	var syn := synergy(m)
	var lvl := HeroesMeta.eff_level(acc, hero_id)
	var h := (1.0 + Ladder.LV_DMG * (lvl - 1)) * HeroesMeta.power(acc, hero_id, HeroesMeta.NO_GEAR, 0, false, syn) \
			/ HeroesMeta.meta1_index(lvl)
	var c := 0.0
	for cid in champs:
		var cls := str(ChampionData.CHAMPIONS[str(cid)]["class"])
		var mult := float(syn["champ_all"]) * float((syn["champ_cls"] as Dictionary).get(cls, 1.0))
		c += ChampionsMeta.power(acc, str(cid), -1, mult)
	c *= ChampionData.CHAMP_UPTIME
	var ral: Dictionary = HeroesMeta.rally(acc, hero_id)
	var army := float(syn["army"]) + Ladder.RALLY_W * float(ral["value"]) / float(HeroData.HEROES[hero_id]["rally"]["base"])
	var msyn := 0.0
	for fam in families:
		msyn += machine_b2(m, str(fam))
	if not families.is_empty():
		msyn /= families.size()
	var w: Dictionary = TeamData.POWER_W
	return (float(w["mach"]) * float(w["b2_eff"]) * msyn + float(w["hero"]) * h + float(w["army"]) * army
			+ ChampionData.W_C * c)


## Auto-team: the best (hero, champions) by score() among the owned characters (the two strongest
## heroes x every combination of the six strongest champions). {hero, champions}.
static func auto_pick(acc: Dictionary, families: Array = []) -> Dictionary:
	var hs := Roster.owned_ids(acc, Roster.KIND_HERO)
	if hs.is_empty():
		return {"hero": hero(acc), "champions": []}
	hs.sort_custom(func(a: String, b: String) -> bool: return HeroesMeta.power(acc, a) > HeroesMeta.power(acc, b))
	var cs := Roster.owned_ids(acc, Roster.KIND_CHAMPION)
	cs.sort_custom(func(a: String, b: String) -> bool: return ChampionsMeta.power(acc, a) > ChampionsMeta.power(acc, b))
	cs = cs.slice(0, 6)
	var k := mini(slots(acc), cs.size())
	var combos: Array = []
	_combos(cs, k, 0, [], combos)
	var best := {"hero": hs[0], "champions": []}
	var best_s := -1.0
	for hid in hs.slice(0, 2):
		for cmb: Array in combos:
			var s := score(acc, hid, cmb, families)
			if s > best_s:
				best_s = s
				best = {"hero": hid, "champions": cmb.duplicate()}
	return best


static func _combos(pool: Array, k: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i in range(start, pool.size()):
		cur.append(pool[i])
		_combos(pool, k, i + 1, cur, out)
		cur.pop_back()
