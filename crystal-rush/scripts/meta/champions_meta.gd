class_name ChampionsMeta
## Champions (heroes_design.md §4.1, §4.3, §4.4; WS-A rules): the shared Champion Level coin track
## (Lv1-20, cl(L) = 1 + CL_STEP (L - 1), cost round(40 L^1.5 / 10) x 10, cap 2 + 2 x world reached,
## 20 in Invasion), the champion power index (sim champ_index) and the champion's numbers in the run
## (HP, Action power, Aura value capped at AURA_CAP; × ladder × Champion Level × relic). Facets,
## recut and duplicates are Roster's (shared with heroes). Pure and static, account first.
##
## Account: champions {level, roster {<id>: {...}}}.

## Shared Champion Level (1..CHAMP_LEVEL_MAX).
static func level(acc: Dictionary) -> int:
	return clampi(int((acc.get("champions", {}) as Dictionary).get("level", 1)), 1, ChampionData.CHAMP_LEVEL_MAX)


## Level cap: CL_CAP_BASE + CL_CAP_PER_WORLD x world reached; the max once the campaign is done.
static func cap(acc: Dictionary) -> int:
	return ChampionData.level_cap(MetaAcc.world(acc), MetaAcc.level(acc) > ArsenalData.CAMPAIGN_LEVELS)


## Coins for the next Champion Level (0 at the max).
static func cost(acc: Dictionary) -> int:
	return ChampionData.level_cost(level(acc))


## "" when the next Champion Level can be bought, else locked | none (no champion owned) | cap | coins.
static func level_block(acc: Dictionary) -> String:
	if not Roster.system_open(acc, "champions"):
		return "locked"
	if Roster.owned_ids(acc, Roster.KIND_CHAMPION).is_empty():
		return "none"
	if level(acc) >= cap(acc):
		return "cap"
	if MetaAcc.amount(acc, "coins") < cost(acc):
		return "coins"
	return ""


static func can_level(acc: Dictionary) -> bool:
	return level_block(acc) == ""


## One Champion Level for coins: {ok, reason, level, coins}.
static func level_up(acc: Dictionary, now_s := 0) -> Dictionary:
	var why := level_block(acc)
	if why != "":
		return {"ok": false, "reason": why, "level": level(acc)}
	var c := cost(acc)
	MetaAcc.spend(acc, "coins", c)
	var ch: Dictionary = acc["champions"]
	ch["level"] = level(acc) + 1
	MetaAcc.count(acc, "upgrades_bought", 1)
	MetaTelemetry.note(acc, "champion_level", {"lvl": int(ch["level"])}, now_s)
	return {"ok": true, "reason": "", "level": int(ch["level"]), "coins": c}


## Coins from Champion Level 1 to the max (design: 26 840).
static func total_cost() -> int:
	var t := 0
	for c: int in ChampionData.CHAMP_LEVEL_COST:
		t += c
	return t


## cl(L) = 1 + CL_STEP (L - 1).
static func cl_mult(cl: int) -> float:
	return 1.0 + ChampionData.CL_STEP * (cl - 1)


## Champion relic stat bonus at `rank` (-1 = no relic): C_RELIC[0] + C_RELIC[1] x rank.
static func relic_bonus(rank: int) -> float:
	return 0.0 if rank < 0 else ChampionData.C_RELIC[0] + ChampionData.C_RELIC[1] * rank


## The champion power index (sim champ_index): ladder x cl x relic x relic beats x Action tier.
## n / g gem indices, f facets, cl Champion Level, relic_rank -1 = none, mult = synergy.
static func index(n: int, g: int, f: int, cl: int, relic_rank := -1, mult := 1.0) -> float:
	var beats := 0
	if relic_rank >= 0:
		for b in [4, 8, 12]:
			if relic_rank >= b:
				beats += 1
	return (Ladder.mult(Ladder.GEMS[n], Ladder.GEMS[g], f) * cl_mult(cl) * (1.0 + relic_bonus(relic_rank))
			* (1.0 + Ladder.RELIC_BEAT * beats) * (1.0 + ChampionData.ACTION_TIER_STEP * n) * mult)


## The champion's power index now (relic from the Workshop when given).
static func power(acc: Dictionary, id: String, relic_rank := -1, mult := 1.0) -> float:
	return index(Ladder.gem_index(Roster.native(id)), Ladder.gem_index(Roster.gem(acc, id)), Roster.facets(acc, id),
			level(acc), relic_rank, mult)


## The champion's run numbers (§4.4): {id, native, gem, facets, tier, class, element, faction, slot,
## mult, hp, action, aura (capped at AURA_CAP), radius}. HP, Action and Aura = kit x ladder x cl x
## (1 + relic); rates, radii and counts never scale (kit identity).
static func stats_at(id: String, gem_now: String, f: int, cl: int, relic_rank := -1) -> Dictionary:
	var c: Dictionary = ChampionData.CHAMPIONS[id]
	var k: Dictionary = c["kit"]
	var m := Ladder.mult(str(c["native"]), gem_now, f) * cl_mult(cl) * (1.0 + relic_bonus(relic_rank))
	return {"id": id, "native": str(c["native"]), "gem": gem_now, "facets": f, "tier": ChampionData.action_tier(id),
			"class": str(c["class"]), "element": str(c["element"]), "faction": str(c["faction"]), "slot": str(c["slot"]),
			"mult": m, "hp": float(k["hp"]) * m, "action": float(k["action"]) * m,
			"aura": minf(ChampionData.AURA_CAP, float(k["aura"]) * m), "radius": float(k["radius"])}


## stats_at() for the account's champion now.
static func stats(acc: Dictionary, id: String, relic_rank := -1) -> Dictionary:
	return stats_at(id, Roster.gem(acc, id), Roster.facets(acc, id), level(acc), relic_rank)


## Aura effect in a slot: value x the slot's fixed share (AURA_SHARE, the same in Run and LevelSim).
static func aura_effect(aura_value: float, slot: String) -> float:
	return minf(ChampionData.AURA_CAP, aura_value) * float(ChampionData.AURA_SHARE.get(slot, 0.0))
