class_name Barracks
## Barracks (arsenal_design.md §4.2): five army tracks Lv0-10, coins round(70 x L^1.55, 5) to
## reach level L, track cap 2 + 2 x world reached. None touches the starting army (LevelGen keeps
## START_ARMY); the run reads army profile values. Migrated v1 "army" levels above the world cap
## are kept as `barracks.grandfathered[track]` and count toward the effect (shown, never removed).

## Bought level of `track` (0..10).
static func level(acc: Dictionary, track: String) -> int:
	return int((acc["barracks"] as Dictionary).get(track, 0))


## Level used for the effect: bought + grandfathered, at most BARRACKS_MAX.
static func effective(acc: Dictionary, track: String) -> int:
	var g: Dictionary = (acc["barracks"] as Dictionary).get("grandfathered", {})
	return mini(EconData.BARRACKS_MAX, level(acc, track) + int(g.get(track, 0)))


static func cap(acc: Dictionary, _track := "") -> int:
	return EconData.barracks_cap(MetaAcc.world(acc))


## Coins for the next level of `track`.
static func cost(acc: Dictionary, track: String) -> int:
	return EconData.barracks_cost(level(acc, track) + 1)


static func can_buy(acc: Dictionary, track: String) -> bool:
	return UnlockQueue.is_open(acc, "barracks") and EconData.BARRACKS.has(track) \
			and level(acc, track) < cap(acc) and effective(acc, track) < EconData.BARRACKS_MAX \
			and MetaAcc.amount(acc, "coins") >= cost(acc, track)


## Buys one level: {ok, track, lvl, value, coins} (ok false + reason: locked | cap | coins).
static func buy(acc: Dictionary, track: String) -> Dictionary:
	if not can_buy(acc, track):
		var why := "coins"
		if not UnlockQueue.is_open(acc, "barracks") or not EconData.BARRACKS.has(track):
			why = "locked"
		elif level(acc, track) >= cap(acc) or effective(acc, track) >= EconData.BARRACKS_MAX:
			why = "cap"
		return {"ok": false, "track": track, "reason": why}
	var c := cost(acc, track)
	MetaAcc.spend(acc, "coins", c)
	var b: Dictionary = acc["barracks"]
	b[track] = level(acc, track) + 1
	MetaAcc.count(acc, "upgrades_bought", 1)
	MetaAcc.count(acc, "barracks_levels", 1)
	return {"ok": true, "track": track, "lvl": int(b[track]), "value": value(acc, track), "coins": c}


## Effect of `track` now (soldiers, or a fraction for drill / volleys).
static func value(acc: Dictionary, track: String) -> float:
	return EconData.barracks_value(track, effective(acc, track))


## Run-ready army block (§9.4 "army").
static func profile(acc: Dictionary) -> Dictionary:
	return {
		"recruit_bonus": int(value(acc, "recruits")),
		"reserves": int(value(acc, "reserves")),
		"scrape_guard": int(value(acc, "scrape_guard")),
		"drill": value(acc, "drill"),
		"volley_mult": 1.0 + value(acc, "volleys"),
		"max_tier": max_army_tier(acc),
		"glory_reserves": 0,
	}


## Highest live soldier tier (2 = blaster in Meta-1; T3+ are Meta-2).
static func max_army_tier(acc: Dictionary) -> int:
	var t := 0
	for i in ArsenalData.ARMY_TIERS.size():
		var tier: Dictionary = ArsenalData.ARMY_TIERS[i]
		if bool(tier.get("meta2", false)) and not bool(ArsenalData.FEATURES["army_tiers_t3"]):
			continue
		if MetaAcc.world(acc) >= int(tier["unlock_world"]):
			t = i
	return t


## Coins for one track from Lv0 to Lv10 (design: 11 015).
static func total_cost() -> int:
	var n := 0
	for l in range(1, EconData.BARRACKS_MAX + 1):
		n += EconData.barracks_cost(l)
	return n
