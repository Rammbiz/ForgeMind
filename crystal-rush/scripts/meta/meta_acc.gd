class_name MetaAcc
## Small shared helpers over the account dictionary (Save v2 sections, EconData.fresh_account()
## shape) used by every scripts/meta/* rule class. Pure: no signals, no Save access. The Meta
## autoload compares wallet snapshots around each call and emits the signals.

const CURRENCIES: Array[String] = ["coins", "gems", "crowns", "cores"]
## Save v3 wallet currencies of the hero systems (heroes_design.md §12.1): Маяки / Beacons (the only
## Portal currency, earned only), Томи / Tomes, Зоряна руда / Star Ore. They never change while the
## heroes phase is off, so the 2.2.1 signals are unchanged.
const HERO_CURRENCIES: Array[String] = ["beacons", "tomes", "ore"]


## Next campaign level to play (1-based).
static func level(acc: Dictionary) -> int:
	return maxi(int((acc.get("progress", {}) as Dictionary).get("level", 1)), 1)


## Highest world the account has reached (by the stored value and the frontier).
static func world(acc: Dictionary) -> int:
	var p: Dictionary = acc.get("progress", {})
	return maxi(int(p.get("world_reached", 1)), ArsenalData.world_of(level(acc)))


static func machines(acc: Dictionary) -> Dictionary:
	return (acc["arsenal"] as Dictionary)["machines"]


static func owned(acc: Dictionary, id: String) -> bool:
	return machines(acc).has(id)


static func machine_level(acc: Dictionary, id: String) -> int:
	return int((machines(acc).get(id, {}) as Dictionary).get("lvl", 0))


# ------------------------------------------------------------------ wallet

## Balance of `cur`: coins | gems | crowns | cores | wild_<R>.
static func amount(acc: Dictionary, cur: String) -> int:
	var w: Dictionary = acc["wallet"]
	if cur.begins_with("wild_"):
		return int((w["wild"] as Dictionary).get(cur.trim_prefix("wild_"), 0))
	return int(w.get(cur, 0))


## Adds `n` (may be negative; never below 0) and returns the new balance.
static func add(acc: Dictionary, cur: String, n: int) -> int:
	var w: Dictionary = acc["wallet"]
	if cur.begins_with("wild_"):
		var wd: Dictionary = w["wild"]
		var r := cur.trim_prefix("wild_")
		wd[r] = maxi(0, int(wd.get(r, 0)) + n)
		return int(wd[r])
	w[cur] = maxi(0, int(w.get(cur, 0)) + n)
	return int(w[cur])


## Spends `n` of `cur` when affordable; false (nothing changed) otherwise.
static func spend(acc: Dictionary, cur: String, n: int) -> bool:
	if n < 0 or amount(acc, cur) < n:
		return false
	add(acc, cur, -n)
	return true


## Every wallet value as {cur: int} (coins, gems, crowns, cores, beacons, tomes, ore, wild_C..wild_M)
## for diffing.
static func wallet_snapshot(acc: Dictionary) -> Dictionary:
	var out := {}
	for c in CURRENCIES:
		out[c] = amount(acc, c)
	for c2 in HERO_CURRENCIES:
		out[c2] = amount(acc, c2)
	for r in ArsenalData.RARITY_ORDER:
		out["wild_" + r] = amount(acc, "wild_" + r)
	return out


# ------------------------------------------------------------------ counters

## Sums `v` (int, float or nested dictionary of numbers) into [counters] under `key`.
static func count(acc: Dictionary, key: String, v: Variant) -> void:
	if not acc.has("counters"):
		acc["counters"] = {}
	sum_into(acc["counters"], key, v)


static func sum_into(d: Dictionary, key: String, v: Variant) -> void:
	if v is Dictionary:
		if not d.get(key) is Dictionary:
			d[key] = {}
		for k in (v as Dictionary):
			sum_into(d[key], str(k), (v as Dictionary)[k])
	elif v is int or v is float or v is bool:
		var add_v: Variant = int(v) if v is bool else v
		d[key] = d.get(key, 0) + add_v
	elif v is Array:
		# id lists (evolutions_ids ...): count each id.
		if not d.get(key) is Dictionary:
			d[key] = {}
		for e in v:
			(d[key] as Dictionary)[str(e)] = int((d[key] as Dictionary).get(str(e), 0)) + 1


## Free first steps granted by UnlockQueue.ack ({"machine": id} / {"hero": true}); read and
## consumed by Arsenal.cost/upgrade and HeroesMeta.cost/level_up.
static func free_steps(acc: Dictionary) -> Dictionary:
	var un: Dictionary = acc["unlocks"]
	if not un.get("free") is Dictionary:
		un["free"] = {}
	return un["free"]
