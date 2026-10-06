class_name HeroesMeta
## Hero levels 1-30 (arsenal_design.md §4.1): coins per level round(30 x L^1.4, 10), +3.5% hero
## damage, +4% HP, +1% ult charge rate per level, cap 6 + 3 x world reached, Ult Rank II/III/IV
## at Lv5/15/25, Awakening looks at Lv10/20/30 (Meta-2). Pure rules over the account dictionary.

## Hero level of `id` (1 when the hero has no entry yet).
static func level(acc: Dictionary, id: String) -> int:
	return maxi(1, int(((acc["heroes"] as Dictionary).get(id, {}) as Dictionary).get("lvl", 1)))


## Level cap for the account's world (30 in Invasion).
static func cap(acc: Dictionary, _id := "") -> int:
	return EconData.hero_cap(MetaAcc.world(acc), MetaAcc.level(acc) > ArsenalData.CAMPAIGN_LEVELS)


## Campaign WIN that unlocks the hero has happened (or the hero is a starter). `dev` opens every
## hero that exists in this phase (dev runs).
static func unlocked(acc: Dictionary, id: String, dev := false) -> bool:
	var at := int(EconData.HERO_UNLOCK.get(id, -1))
	return at == 0 or (at > 0 and MetaAcc.level(acc) > at) or (dev and at >= 0)


## Coins for the next level of `id` (0 while the Heroes tab's free first level is unused).
static func cost(acc: Dictionary, id: String) -> int:
	if bool(MetaAcc.free_steps(acc).get("hero", false)):
		return 0
	return EconData.hero_cost(level(acc, id))


static func can_level(acc: Dictionary, id: String, dev := false) -> bool:
	return UnlockQueue.is_open(acc, "heroes") and unlocked(acc, id, dev) and level(acc, id) < cap(acc) \
			and MetaAcc.amount(acc, "coins") >= cost(acc, id)


## Buys one level: {ok, id, lvl, milestone ("" | ult_rank | awakening), coins, free}.
static func level_up(acc: Dictionary, id: String, dev := false) -> Dictionary:
	if not can_level(acc, id, dev):
		var why := "cap" if level(acc, id) >= cap(acc) else ("locked" if not unlocked(acc, id, dev) else "coins")
		return {"ok": false, "id": id, "reason": why}
	var c := cost(acc, id)
	var free := c == 0
	MetaAcc.spend(acc, "coins", c)
	if free:
		MetaAcc.free_steps(acc).erase("hero")
	var hs: Dictionary = acc["heroes"]
	if not hs.has(id):
		var aspects: Array = EconData.HERO_ASPECTS.get(id, [""])
		hs[id] = {"lvl": 1, "glory": 1, "boss_wins": 0, "aspect": str(aspects[0]), "skin": ""}
	var h: Dictionary = hs[id]
	h["lvl"] = int(h["lvl"]) + 1
	var lv := int(h["lvl"])
	var ms := ""
	if lv in (EconData.HERO["ult_rank_at"] as Array):
		ms = "ult_rank"
	elif lv in (EconData.HERO["awakening_at"] as Array):
		ms = "awakening"
	MetaAcc.count(acc, "upgrades_bought", 1)
	MetaAcc.count(acc, "hero_levels", 1)
	return {"ok": true, "id": id, "lvl": lv, "milestone": ms, "coins": c, "free": free}


## Run-ready hero block (§9.4 "hero"): {id, lvl, aspect, glory, ult_rank, dmg_mult, hp_mult,
## ult_rate_mult}.
static func profile(acc: Dictionary, id: String) -> Dictionary:
	var lvl := level(acc, id)
	var h: Dictionary = (acc["heroes"] as Dictionary).get(id, {})
	var mults := EconData.hero_mults(lvl)
	return {"id": id, "lvl": lvl, "aspect": str(h.get("aspect", "")), "glory": int(h.get("glory", 1)),
			"ult_rank": int(mults["ult_rank"]), "dmg_mult": float(mults["dmg_mult"]), "hp_mult": float(mults["hp_mult"]),
			"ult_rate_mult": float(mults["ult_rate_mult"])}


## Coins from Lv1 to Lv30 for one hero (design: 42 140).
static func total_cost() -> int:
	var n := 0
	for l in range(1, int(EconData.HERO["max"])):
		n += EconData.hero_cost(l)
	return n
