class_name Arsenal
## Machine rules of the account (arsenal_design.md §2.1, §3.1, §5.5, §9.3): levels with coins +
## blueprints (+ Wild Blueprints of the rarity), Arsenal Sync on unlock, Talents I/II, Focus,
## Deck / Lead / Auto-deck, machine cards, the "Best upgrade" (the sim's greedy value function),
## milestones, rating and final stats. Pure: every function takes the account dictionary first
## and mutates only it; the Meta autoload emits signals and saves.

## Sim power model (economy_sim.py: Player.mpow / parts / power), used by best_upgrade().
const SIM := {"w_mach": 0.50, "w_hero": 0.25, "w_army": 0.25, "talent": 0.05, "asc": 0.12, "apex": 0.06,
		"rarity_edge": 0.03, "machine_value": 1.3}
const BAR_POWER := {"recruits": 0.015, "reserves": 0.010, "scrape_guard": 0.010, "drill": 0.012, "volleys": 0.012}


# ======================================================================== stats

## Final numbers of `id` for UI and Run: ArsenalData.machine_stats with the account's level,
## talents and branch (unowned machines preview at their rarity start level), plus
## `final` {damage, dps, add}: one card number per §2.1 = bucket 1 x (1 + bucket 2 of the
## machine's own talents/Ascension), single target, before `vs`.
static func stats(acc: Dictionary, id: String, rank := 1) -> Dictionary:
	var st: Dictionary = MetaAcc.machines(acc).get(id, {})
	var lvl := int(st.get("lvl", EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
	var out := ArsenalData.machine_stats(id, lvl, rank, st.get("talents", []), str(st.get("branch", "")))
	out["final"] = final_numbers(out)
	return out


## Card numbers from a machine_stats() dictionary: {damage, dps, add}.
static func final_numbers(ms: Dictionary) -> Dictionary:
	var s: Dictionary = ms["stats"]
	var b2 := 1.0 + float(ms.get("add", 0.0))
	var dmg := float(s.get("damage", 0.0)) * b2
	var per := 1.0
	for k in ["bolts", "drones"]:
		if s.has(k):
			per *= float(s[k])
	var dps := 0.0
	if s.has("dps"):
		dps = float(s["dps"]) * b2
	elif s.has("rate"):
		dps = dmg * float(s["rate"]) * per
	elif s.has("period"):
		dps = dmg * float(s.get("volley", 1)) / maxf(float(s["period"]), 0.01)
	elif s.has("charge"):
		dps = dmg / maxf(float(s["charge"]), 0.01)
	return {"damage": snappedf(dmg, 0.01), "dps": snappedf(dps, 0.01), "add": float(ms.get("add", 0.0))}


# ======================================================================== levels

## Price of the next level of `id` (§6.3): {id, to_lvl, coins, bp_need, bp_have, wild_use, can,
## reason ("" | max | locked | not_owned | coins | blueprints), beat, free}.
static func cost(acc: Dictionary, id: String) -> Dictionary:
	var out := {"id": id, "to_lvl": 0, "coins": 0, "bp_need": 0, "bp_have": 0, "wild_use": 0, "can": false,
			"reason": "", "beat": "", "free": false}
	if not ArsenalData.MACHINES.has(id) or not MetaAcc.owned(acc, id):
		out["reason"] = "not_owned"
		return out
	var st: Dictionary = MetaAcc.machines(acc)[id]
	var nl := int(st["lvl"]) + 1
	if nl > ArsenalData.MAX_LEVEL:
		out["reason"] = "max"
		return out
	var r := ArsenalData.rarity_of(id)
	var need := EconData.bp_to(r, nl)
	var have := int(st.get("bp", 0))
	out["to_lvl"] = nl
	out["free"] = str(MetaAcc.free_steps(acc).get("machine", "")) == id
	out["coins"] = 0 if bool(out["free"]) else EconData.coin_to(nl)
	out["bp_need"] = need
	out["bp_have"] = have
	out["wild_use"] = maxi(0, need - have)
	out["beat"] = beat_at(nl)
	if not UnlockQueue.is_open(acc, "arsenal"):
		out["reason"] = "locked"
	elif have + MetaAcc.amount(acc, "wild_" + r) < need:
		out["reason"] = "blueprints"
	elif MetaAcc.amount(acc, "coins") < int(out["coins"]):
		out["reason"] = "coins"
	else:
		out["can"] = true
	return out


## Buys the next level: {ok, id, lvl, beat, coins, bp, wild} (ok false + reason: nothing changed).
## Blueprints of the machine are used first, then Wild Blueprints of its rarity.
static func upgrade(acc: Dictionary, id: String) -> Dictionary:
	var c := cost(acc, id)
	if not bool(c["can"]):
		return {"ok": false, "id": id, "reason": c["reason"]}
	var st: Dictionary = MetaAcc.machines(acc)[id]
	var r := ArsenalData.rarity_of(id)
	var from_bp := mini(int(st["bp"]), int(c["bp_need"]))
	st["bp"] = int(st["bp"]) - from_bp
	if int(c["wild_use"]) > 0:
		MetaAcc.add(acc, "wild_" + r, -int(c["wild_use"]))
	MetaAcc.spend(acc, "coins", int(c["coins"]))
	if bool(c["free"]):
		MetaAcc.free_steps(acc).erase("machine")
	st["lvl"] = int(c["to_lvl"])
	MetaAcc.count(acc, "upgrades_bought", 1)
	if int(st["lvl"]) == ArsenalData.ASCENSION_LEVEL:
		MetaAcc.count(acc, "ascensions", 1)
	if int(st["lvl"]) == ArsenalData.MAX_LEVEL:
		MetaAcc.count(acc, "mastered", 1)
	return {"ok": true, "id": id, "lvl": int(st["lvl"]), "beat": c["beat"], "coins": c["coins"], "bp": from_bp,
			"wild": c["wild_use"], "free": c["free"]}


## The beat reached at machine level `lvl`: talent1 3 | lead 5 | talent2 6 | ascension 8 |
## talent3 10 | apex 12 | prestige 13-14 | mastered 15 | "" (ceremony tier: beat = full).
static func beat_at(lvl: int) -> String:
	match lvl:
		3: return "talent1"
		5: return "lead"
		6: return "talent2"
		8: return "ascension"
		10: return "talent3"
		12: return "apex"
		13, 14: return "prestige"
		15: return "mastered"
	return ""


## Next beat after `lvl`: {lvl, beat} ({} at max).
static func next_beat(lvl: int) -> Dictionary:
	for l in range(lvl + 1, ArsenalData.MAX_LEVEL + 1):
		if beat_at(l) != "":
			return {"lvl": l, "beat": beat_at(l)}
	return {}


## Start level of a newly unlocked machine (Arsenal Sync §2.1):
## max(rarity start, min(SYNC_CAP, 3rd-best owned Lv - SYNC_BEHIND)).
static func sync_level(acc: Dictionary, id: String) -> int:
	var levels: Array[int] = []
	for k in MetaAcc.machines(acc):
		levels.append(int((MetaAcc.machines(acc)[k] as Dictionary)["lvl"]))
	levels.sort()
	levels.reverse()
	var start := int(EconData.START_LEVEL[ArsenalData.rarity_of(id)])
	if levels.size() >= 3:
		return maxi(start, mini(EconData.SYNC_CAP, levels[2] - EconData.SYNC_BEHIND))
	return start


## Unlocks `id` (NEW crate, Cache card, migration) at its Arsenal Sync level. True when new.
## Meta-2 machines never unlock in Meta-1.
static func unlock(acc: Dictionary, id: String, _source := "") -> bool:
	if not ArsenalData.is_live(id) or MetaAcc.owned(acc, id):
		return false
	MetaAcc.machines(acc)[id] = EconData.new_machine_state(id, sync_level(acc, id))
	(acc["counters"] as Dictionary)["machines_owned"] = MetaAcc.machines(acc).size()
	return true


# ======================================================================== talents, branch, finish, focus

## Picks Talent `talent_id` for tier 0/1/2 ("" clears; free respec). False if not allowed.
static func set_talent(acc: Dictionary, id: String, tier: int, talent_id: String) -> bool:
	if not MetaAcc.owned(acc, id) or tier < 0 or tier > 2:
		return false
	var st: Dictionary = MetaAcc.machines(acc)[id]
	if talent_id != "":
		if not UnlockQueue.is_open(acc, "talents"):
			return false
		if not bool(ArsenalData.FEATURES["talents12" if tier < 2 else "talent3"]):
			return false
		if int(st["lvl"]) < ArsenalData.TALENT_LEVELS[tier] or not _has_talent(id, tier, talent_id):
			return false
	var tal: Array = st["talents"]
	while tal.size() < 3:
		tal.append("")
	tal[tier] = talent_id
	return true


static func _has_talent(id: String, tier: int, talent_id: String) -> bool:
	for t: Dictionary in ArsenalData.talent_options(id, tier):
		if str(t["id"]) == talent_id:
			return true
	return false


## True when a reached talent tier of `id` has no pick yet (the "!" badge).
static func talent_pending(acc: Dictionary, id: String) -> bool:
	if not MetaAcc.owned(acc, id) or not UnlockQueue.is_open(acc, "talents"):
		return false
	var st: Dictionary = MetaAcc.machines(acc)[id]
	for tier in 3:
		if not bool(ArsenalData.FEATURES["talents12" if tier < 2 else "talent3"]):
			continue
		if int(st["lvl"]) >= ArsenalData.TALENT_LEVELS[tier] and str((st["talents"] as Array)[tier]) == "":
			return true
	return false


## Ascension branch "a"/"b" for Epic+ (false while FEATURES.branches is off).
static func set_branch(acc: Dictionary, id: String, b: String) -> bool:
	if not MetaAcc.owned(acc, id) or not bool(ArsenalData.FEATURES["branches"]) or not b in ["a", "b"]:
		return false
	(MetaAcc.machines(acc)[id] as Dictionary)["branch"] = b
	return true


## Mastery finish tier shown in the run (false while FEATURES.finishes is off).
static func set_finish(acc: Dictionary, id: String, tier: int) -> bool:
	if not MetaAcc.owned(acc, id) or not bool(ArsenalData.FEATURES["finishes"]):
		return false
	var st: Dictionary = MetaAcc.machines(acc)[id]
	if tier < 0 or (tier > 0 and not (int(st.get("finishes", 0)) & (1 << (tier - 1)))):
		return false
	st["finish"] = tier
	return true


## Focus machine (40% of Cache cards of its rarity). "" = default (the Lead).
static func set_focus(acc: Dictionary, id: String) -> void:
	(acc["arsenal"] as Dictionary)["focus"] = id if (id == "" or MetaAcc.owned(acc, id)) else ""


static func focus(acc: Dictionary) -> String:
	var f := str((acc["arsenal"] as Dictionary).get("focus", ""))
	if f != "" and MetaAcc.owned(acc, f):
		return f
	return lead(acc)


# ======================================================================== deck

## Deck slots open now (3 in Meta-1; the design adds +1 at World 3/4/5, max 6).
static func deck_slots(acc: Dictionary) -> int:
	var n := mini(6, 3 + maxi(0, MetaAcc.world(acc) - 2))
	return mini(n, int(ArsenalData.FEATURES.get("deck_slots_max", 3)))


## The active deck (ids, slot 0 = Lead slot). Before the Deck unlock: automatic, every owned
## machine by strength (max 5); after it: the saved preset (unowned ids dropped), or Auto-deck
## while the preset is empty.
static func deck(acc: Dictionary) -> Array[String]:
	if not UnlockQueue.is_open(acc, "deck"):
		return by_strength(acc, owned_ids(acc)).slice(0, 5)
	var ar: Dictionary = acc["arsenal"]
	var presets: Array = ar["decks"]
	var d: Array = presets[clampi(int(ar.get("deck_active", 0)), 0, presets.size() - 1)]
	var out: Array[String] = []
	for id in d:
		if MetaAcc.owned(acc, str(id)) and not out.has(str(id)) and out.size() < deck_slots(acc):
			out.append(str(id))
	return out if not out.is_empty() else auto_deck(acc)


## The Lead (deck slot 1 at Lv5+, after the Deck unlock), "" when none.
static func lead(acc: Dictionary) -> String:
	if not bool(ArsenalData.FEATURES["lead"]) or not UnlockQueue.is_open(acc, "deck"):
		return ""
	var d := deck(acc)
	if d.is_empty() or MetaAcc.machine_level(acc, d[0]) < ArsenalData.LEAD_LEVEL:
		return ""
	return d[0]


## Saves deck `ids` into the active preset. False if an id is unknown / unowned / repeated / too many.
static func set_deck(acc: Dictionary, ids: Array) -> bool:
	if ids.size() > deck_slots(acc):
		return false
	var clean: Array[String] = []
	for id in ids:
		if not MetaAcc.owned(acc, str(id)) or clean.has(str(id)) or not ArsenalData.is_live(str(id)):
			return false
		clean.append(str(id))
	var ar: Dictionary = acc["arsenal"]
	(ar["decks"] as Array)[int(ar.get("deck_active", 0))] = clean
	return true


## Suggested deck: answers to `threats` (property ids) first, then the strongest owned machines
## (level, then rarity, then roster order). Recipe pairs join with FEATURES.evolutions.
static func auto_deck(acc: Dictionary, threats: Array = []) -> Array[String]:
	var ids := by_strength(acc, owned_ids(acc))
	var first: Array[String] = []
	for p in threats:
		if not ArsenalData.PROPERTIES.has(p):
			continue
		var answers: Array = (ArsenalData.PROPERTIES[p] as Dictionary).get("answers", [])
		for id in ids:
			if answers.has(id) and not first.has(id):
				first.append(id)
				break
	for id2 in ids:
		if not first.has(id2):
			first.append(id2)
	return first.slice(0, deck_slots(acc))


## Owned live machine ids in roster order.
static func owned_ids(acc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in ArsenalData.ORDER:
		if MetaAcc.owned(acc, id):
			out.append(id)
	return out


## `ids` sorted strongest first (level, rarity, roster order).
static func by_strength(acc: Dictionary, ids: Array[String]) -> Array[String]:
	var out := ids.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var la := MetaAcc.machine_level(acc, a)
		var lb := MetaAcc.machine_level(acc, b)
		if la != lb:
			return la > lb
		var ra := ArsenalData.rarity_index(ArsenalData.rarity_of(a))
		var rb := ArsenalData.rarity_index(ArsenalData.rarity_of(b))
		if ra != rb:
			return ra > rb
		return ArsenalData.ORDER.find(a) < ArsenalData.ORDER.find(b))
	return out


# ======================================================================== cards

## Everything a machine card / detail screen needs (§6.2).
static func card(acc: Dictionary, id: String, best: Dictionary = {}, d: Array[String] = []) -> Dictionary:
	var m: Dictionary = ArsenalData.MACHINES[id]
	var r := str(m["rarity"])
	var own := MetaAcc.owned(acc, id)
	var st: Dictionary = MetaAcc.machines(acc).get(id, {})
	var lvl := int(st.get("lvl", 0))
	var c := cost(acc, id)
	if d.is_empty():
		d = deck(acc)
	var locked := ""
	if bool(m.get("meta2", false)):
		locked = "phase"
	elif not own:
		locked = "world"
	var badge := ""
	if own and bool(c["can"]) and (d.has(id) or str(best.get("id", "")) == id):
		badge = "arrow"
	elif own and talent_pending(acc, id):
		badge = "!"
	var tal_opts: Array = []
	for tier in 3:
		tal_opts.append(ArsenalData.talent_options(id, tier))
	var tal: Array = (st.get("talents", ["", "", ""]) as Array).duplicate()
	var ld := lead(acc)
	return {
		"id": id, "name": str(m["name"]), "desc": str(m["desc"]), "rarity": r, "family": str(m["family"]),
		"verb": str(m["verb"]), "shape": str(m.get("shape", "")), "home": int(m.get("home", 0)),
		"home_level": ArsenalData.new_crate_level(id), "owned": own, "locked": locked,
		"lvl": lvl, "max_lvl": ArsenalData.MAX_LEVEL, "bp": int(st.get("bp", 0)), "bp_need": int(c["bp_need"]),
		"wild": MetaAcc.amount(acc, "wild_" + r), "coins_need": int(c["coins"]), "can_upgrade": bool(c["can"]),
		"reason": str(c["reason"]), "next_beat": next_beat(lvl) if own else {}, "in_deck": d.has(id),
		"is_lead": ld == id and ld != "", "is_focus": own and focus(acc) == id, "badge": badge,
		"talents": tal, "talent_options": tal_opts, "branch": str(st.get("branch", "")),
		"finish": int(st.get("finish", 0)), "stats": stats(acc, id), "accent": ArsenalData.accent(id),
		"rarity_color": (ArsenalData.RARITIES[r] as Dictionary)["ui_color"],
		"pips": int((ArsenalData.RARITIES[r] as Dictionary)["pips"]), "flags": (m.get("flags", {}) as Dictionary).duplicate(),
		"frame": frame_tier(lvl), "free": bool(c["free"]),
	}


## Prestige frame: "" below Lv13, bronze 13, silver 14, gold 15 (Mastered).
static func frame_tier(lvl: int) -> String:
	if not bool(ArsenalData.FEATURES.get("prestige_frames", false)) or lvl < ArsenalData.PRESTIGE_FROM:
		return ""
	return ["bronze", "silver", "gold"][clampi(lvl - ArsenalData.PRESTIGE_FROM, 0, 2)]


## Cards for the grid. filter: all | owned | upgradable | <family id>.
static func cards(acc: Dictionary, filter := "all") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best := best_upgrade(acc)
	var d := deck(acc)
	for id in ArsenalData.ORDER:
		var keep := true
		match filter:
			"owned": keep = MetaAcc.owned(acc, id)
			"upgradable": keep = bool(cost(acc, id)["can"])
			"all": keep = true
			_: keep = ArsenalData.family_of(id) == filter
		if keep:
			out.append(card(acc, id, best, d))
	return out


# ======================================================================== best upgrade, milestones

## The pre-selected "Best upgrade": the sim's greedy choice (economy_sim.Player.spend, greedy):
## value = (1.3 for machines) x power gain / coins over every affordable option.
## Returns {kind: machine | hero | barracks, id, cost, label (Loc key), to_lvl} or {}.
static func best_upgrade(acc: Dictionary) -> Dictionary:
	var base := sim_power(acc)
	var best := {}
	var best_v := -1.0
	for id in owned_ids(acc):
		var c := cost(acc, id)
		if not bool(c["can"]):
			continue
		var st: Dictionary = MetaAcc.machines(acc)[id]
		st["lvl"] = int(st["lvl"]) + 1
		var gain := sim_power(acc) - base
		st["lvl"] = int(st["lvl"]) - 1
		var v := float(SIM["machine_value"]) * maxf(gain, 1e-6) / float(maxi(int(c["coins"]), 1))
		if v > best_v:
			best_v = v
			best = {"kind": "machine", "id": id, "cost": int(c["coins"]), "label": str((ArsenalData.MACHINES[id] as Dictionary)["name"]),
					"to_lvl": int(c["to_lvl"])}
	var h := str((acc["progress"] as Dictionary).get("hero", "bolt"))
	if HeroesMeta.can_level(acc, h):
		var hc := HeroesMeta.cost(acc, h)
		var v2 := maxf(float(SIM["w_hero"]) * float(EconData.HERO["dmg_per_lvl"]), 1e-6) / float(maxi(hc, 1))
		if v2 > best_v:
			best_v = v2
			var hname := "HERO_" + h.to_upper()
			best = {"kind": "hero", "id": h, "cost": hc, "label": hname, "to_lvl": HeroesMeta.level(acc, h) + 1}
	for t in EconData.BARRACKS_ORDER:
		if Barracks.can_buy(acc, t):
			var bc := Barracks.cost(acc, t)
			var v3 := maxf(float(SIM["w_army"]) * float(BAR_POWER[t]), 1e-6) / float(maxi(bc, 1))
			if v3 > best_v:
				best_v = v3
				best = {"kind": "barracks", "id": t, "cost": bc, "label": str((EconData.BARRACKS[t] as Dictionary)["name"]),
						"to_lvl": Barracks.level(acc, t) + 1}
	return best


## Sim power of one machine at `lvl` (economy_sim.Player.mpow, live beats only).
static func sim_mpow(id: String, lvl: int) -> float:
	var p := 1.0 + ArsenalData.PER_LEVEL * float(lvl - 1)
	var talents := 0
	for i in 3:
		if lvl >= ArsenalData.TALENT_LEVELS[i] and bool(ArsenalData.FEATURES["talents12" if i < 2 else "talent3"]):
			talents += 1
	p *= 1.0 + float(SIM["talent"]) * talents
	if lvl >= ArsenalData.ASCENSION_LEVEL and bool(ArsenalData.FEATURES["ascension"]):
		p *= 1.0 + float(SIM["asc"])
	if lvl >= ArsenalData.APEX_LEVEL and bool(ArsenalData.FEATURES["apex"]):
		p *= 1.0 + float(SIM["apex"])
	return p * (1.0 + float(SIM["rarity_edge"]) * ArsenalData.rarity_index(ArsenalData.rarity_of(id)))


## Sim account power (0.5 machines + 0.25 hero + 0.25 army): machines = mean of the top 3 deck
## machines blended 80/20 with the rest of the deck.
static func sim_power(acc: Dictionary) -> float:
	var vals: Array[float] = []
	for id in deck(acc):
		vals.append(sim_mpow(id, MetaAcc.machine_level(acc, id)))
	vals.sort()
	vals.reverse()
	var mach := 1.0
	if not vals.is_empty():
		var top := vals.slice(0, 3)
		mach = 0.0
		for v in top:
			mach += v
		mach /= float(top.size())
		if vals.size() > 3:
			var rest := 0.0
			for v2 in vals.slice(3):
				rest += v2
			mach = 0.8 * mach + 0.2 * rest / float(vals.size() - 3)
	var h := str((acc["progress"] as Dictionary).get("hero", "bolt"))
	var hero := 1.0 + float(EconData.HERO["dmg_per_lvl"]) * float(HeroesMeta.level(acc, h) - 1)
	var army := 1.0
	for t in EconData.BARRACKS_ORDER:
		army += float(BAR_POWER[t]) * Barracks.effective(acc, t)
	return float(SIM["w_mach"]) * mach + float(SIM["w_hero"]) * hero + float(SIM["w_army"]) * army


## Arsenal header milestone: the nearest beat among Deck machines {id, lvl, beat, levels_left}.
static func next_milestone(acc: Dictionary) -> Dictionary:
	var best := {}
	for id in deck(acc):
		var lv := MetaAcc.machine_level(acc, id)
		var nb := next_beat(lv)
		if nb.is_empty():
			continue
		var left := int(nb["lvl"]) - lv
		if best.is_empty() or left < int(best["levels_left"]):
			best = {"id": id, "lvl": int(nb["lvl"]), "beat": str(nb["beat"]), "levels_left": left}
	return best


## Coins (and blueprints per rarity) left to max every owned machine: {coins, share_done, bp}.
static func remaining_cost(acc: Dictionary) -> Dictionary:
	var left := 0
	var total := 0
	var bp := {}
	for id in owned_ids(acc):
		var r := ArsenalData.rarity_of(id)
		var lv := MetaAcc.machine_level(acc, id)
		for l in range(int(EconData.START_LEVEL[r]) + 1, ArsenalData.MAX_LEVEL + 1):
			total += EconData.coin_to(l)
			if l > lv:
				left += EconData.coin_to(l)
				bp[r] = int(bp.get(r, 0)) + EconData.bp_to(r, l)
	return {"coins": left, "share_done": 1.0 - float(left) / float(maxi(total, 1)), "bp": bp}


## Arsenal Rating (no damage): Σ levels + 5 per Ascension (+ finishes and Apex in Meta-2/3).
static func rating(acc: Dictionary) -> int:
	var n := 0
	for id in owned_ids(acc):
		var l := MetaAcc.machine_level(acc, id)
		n += l * int(EconData.RATING["per_level"])
		if l >= ArsenalData.ASCENSION_LEVEL:
			n += int(EconData.RATING["ascension"])
		if bool(ArsenalData.FEATURES["finishes"]):
			n += int(EconData.RATING["finish"]) * int((MetaAcc.machines(acc)[id] as Dictionary).get("finish", 0))
		if bool(ArsenalData.FEATURES["apex"]) and l >= ArsenalData.APEX_LEVEL:
			n += int(EconData.RATING["apex"])
	return n


## Coins from the rarity start to Lv15 for every machine of the roster (design: 578 270).
static func full_arsenal_coins() -> int:
	var n := 0
	for id in ArsenalData.ORDER:
		n += int(EconData.full_machine_cost(ArsenalData.rarity_of(id))["coins"])
	return n
