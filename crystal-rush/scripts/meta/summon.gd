class_name Summon
## «Портал / Portal» (heroes_design.md §7.1 - §7.4; WS-A rules): the hero roller, its pity, the
## welcome ×10, Focus, Seals and the Seal shop, Beacon income — a line-by-line port of heroes_sim.py
## portal_gem / summon / pick_hero / seal_shop, with the (i) sheet's exact tables (stationary pity
## chain, best-of-×10 DP) computed from the same PortalData constants.
##
## One summon: Topaz+ test first (base L + M, +PITY_L.step per summon from PITY_L.soft_from, certain
## on PITY_L.hard; Opal OPAL_SHARE_IN_L inside it), else Amethyst certain on PITY_E.hard, else the
## base C / R / E weights. Then the hero of that gem: an unowned eligible hero first (duplicate
## protection), else the player's Focus gets exactly FOCUS_TOTAL and the others share the rest
## evenly (no Focus: even shares). +1 Seal per summon. Every random result is written to the account
## BEFORE this returns (the Meta API saves it, then the ceremony plays); `rng` is the account's
## stream (meta.rng_state), so a replay of the same state gives the same results.
##
## Account: summon {seals, since_e, since_l, total, focus {gem: id}, history [<= HISTORY_MAX], welcome_done}
##          wallet {beacons, beacon_charge}.
## `eligible` (optional everywhere): the ids allowed in the pool (HeroArt: only `complete`
## characters enter the Portal, WS-E); [] = every hero.

const HISTORY_MAX := 100
## Beacon income sources = beacon_sources() (the PortalData.BEACON nodes that pay; test_heroes checks
## the two agree). Kept as a const for the Meta API / tests.
const BEACON_SOURCES: Array[String] = ["first_clear", "boss", "mission", "weekly", "exp3", "exp5", "login7"]

static var _cons_cache: Dictionary = {}
static var _stat_cache: Dictionary = {}


static func is_open(acc: Dictionary) -> bool:
	return Roster.system_open(acc, "portal")


## Beacon income sources: the PortalData.BEACON nodes that pay a number of Beacons (§7.3; first
## clear, world boss, daily mission, weekly, Expedition 3/5 and 5/5, login day 7). Nothing else ever
## pays Beacons: not Feats, Track nodes (BEACON.track = 0) or Road nodes, replays, ads, SKUs, Gems or
## random chests (two-track rule).
static func beacon_sources() -> Array[String]:
	var out: Array[String] = []
	for k: String in PortalData.BEACON:
		var v: Variant = PortalData.BEACON[k]
		if (v is float or v is int) and float(v) > 0.0:
			out.append(k)
	return out


static func state(acc: Dictionary) -> Dictionary:
	return acc["summon"]


# ------------------------------------------------------------------ pool and odds

## Heroes of `gem` in the Portal pool: every hero of that native gem, a starter only once owned
## (the starters join by progress), filtered by `eligible`.
static func pool(acc: Dictionary, gem: String, eligible: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in HeroData.HERO_ORDER:
		if str(HeroData.HEROES[id]["native"]) != gem:
			continue
		if HeroData.STARTERS.has(id) and not Roster.owned(acc, id):
			continue
		if not eligible.is_empty() and not eligible.has(id):
			continue
		out.append(id)
	return out


## Chance of each gem on the next summon from pity state (since_e, since_l) (sim portal_step_dist).
static func step_odds(since_e: int, since_l: int) -> Dictionary:
	var pl := PortalData.topaz_plus_chance(since_l)
	var out := {"C": 0.0, "R": 0.0, "E": 0.0, "L": pl * (1.0 - PortalData.OPAL_SHARE_IN_L), "M": pl * PortalData.OPAL_SHARE_IN_L}
	var rest := 1.0 - pl
	if since_e + 1 >= int(PortalData.PITY_E["hard"]):
		out["E"] = rest
	else:
		var t := float(PortalData.BASE_ODDS["C"]) + float(PortalData.BASE_ODDS["R"]) + float(PortalData.BASE_ODDS["E"])
		for g in ["C", "R", "E"]:
			out[g] = rest * float(PortalData.BASE_ODDS[g]) / t
	return out


## One gem roll (sim portal_gem); updates st {since_e, since_l} in place.
static func roll_gem(st: Dictionary, rng: RandomNumberGenerator) -> String:
	var gem := ""
	if rng.randf() < PortalData.topaz_plus_chance(int(st["since_l"])):
		gem = "M" if rng.randf() < PortalData.OPAL_SHARE_IN_L else "L"
	elif int(st["since_e"]) + 1 >= int(PortalData.PITY_E["hard"]):
		gem = "E"
	else:
		var c := float(PortalData.BASE_ODDS["C"])
		var r := float(PortalData.BASE_ODDS["R"])
		var x := rng.randf() * (c + r + float(PortalData.BASE_ODDS["E"]))
		gem = "C" if x < c else ("R" if x < c + r else "E")
	_advance(st, gem)
	return gem


static func _advance(st: Dictionary, gem: String) -> void:
	var gi := Ladder.gem_index(gem)
	st["since_e"] = 0 if gi >= Ladder.gem_index("E") else int(st["since_e"]) + 1
	st["since_l"] = 0 if gi >= Ladder.gem_index("L") else int(st["since_l"]) + 1


## The player's Focus hero for `gem` ("" none or not in the pool).
static func focus(acc: Dictionary, gem: String, eligible: Array = []) -> String:
	var f := str((state(acc).get("focus", {}) as Dictionary).get(gem, ""))
	return f if pool(acc, gem, eligible).has(f) else ""


## Sets (or clears with "") the Focus hero of `gem`; free, any time. False for a hero not in the pool.
static func set_focus(acc: Dictionary, gem: String, id: String, eligible: Array = []) -> bool:
	var fd: Dictionary = state(acc)["focus"]
	if id == "":
		fd.erase(gem)
		return true
	if not pool(acc, gem, eligible).has(id):
		return false
	fd[gem] = id
	return true


## Share of each hero inside a `gem` result now: unowned heroes first (even), else Focus exactly
## FOCUS_TOTAL and the rest even, else even. {id: p} ({} for an empty pool).
static func hero_weights(acc: Dictionary, gem: String, eligible: Array = []) -> Dictionary:
	var p := pool(acc, gem, eligible)
	var out := {}
	if p.is_empty():
		return out
	var un: Array[String] = []
	for id in p:
		if not Roster.owned(acc, id):
			un.append(id)
	if not un.is_empty():
		for id2 in p:
			out[id2] = 1.0 / un.size() if un.has(id2) else 0.0
		return out
	var f := focus(acc, gem, eligible)
	if f == "" or p.size() == 1:
		for id3 in p:
			out[id3] = 1.0 / p.size()
		return out
	for id4 in p:
		out[id4] = PortalData.FOCUS_TOTAL if id4 == f else (1.0 - PortalData.FOCUS_TOTAL) / (p.size() - 1)
	return out


## The hero of a `gem` result (sim pick_hero with the player's Focus).
static func pick_hero(acc: Dictionary, gem: String, rng: RandomNumberGenerator, eligible: Array = []) -> String:
	var p := pool(acc, gem, eligible)
	if p.is_empty():
		return ""
	var un: Array[String] = []
	for id in p:
		if not Roster.owned(acc, id):
			un.append(id)
	if not un.is_empty():
		return un[rng.randi_range(0, un.size() - 1)]
	var f := focus(acc, gem, eligible)
	if f == "" or p.size() == 1:
		return p[rng.randi_range(0, p.size() - 1)]
	if rng.randf() < PortalData.FOCUS_TOTAL:
		return f
	var rest: Array[String] = []
	for id2 in p:
		if id2 != f:
			rest.append(id2)
	return rest[rng.randi_range(0, rest.size() - 1)]


# ------------------------------------------------------------------ summoning

## Beacons a summon of `count` costs (0 for the welcome ×10).
static func cost(count: int, src := "beacons") -> int:
	return 0 if src == "welcome" else count * PortalData.BEACONS_PER_SUMMON


## "" when the summon can run, else locked | count | welcome (already used) | welcome_first (a
## Beacon summon before the free welcome ×10) | beacons | pool.
## Beacon summons wait for the welcome ×10 (§11.4 order; review F4): the welcome then always starts
## from fresh pity, so its disclosed best-of-10 row (PortalData.ODDS_X10_WELCOME, 78.46 / 21.54) is
## exact. A migrated player's lump Beacons therefore stay in the wallet until the welcome is used.
static func block(acc: Dictionary, count: int, src := "beacons", eligible: Array = []) -> String:
	if not is_open(acc):
		return "locked"
	if src == "welcome":
		if count != PortalData.X10_SUMMONS:
			return "count"
		if welcome_done(acc):
			return "welcome"
	elif count != 1 and count != PortalData.X10_SUMMONS:
		return "count"
	elif not welcome_done(acc):
		return "welcome_first"
	elif MetaAcc.amount(acc, "beacons") < cost(count, src):
		return "beacons"
	for g in Ladder.GEMS:
		if pool(acc, g, eligible).is_empty():
			return "pool"
	return ""


## ×1 / ×10 summon (src "beacons"), or the free welcome ×10 (src "welcome") with the disclosed rule
## «Серед десяти — щонайменше Топаз»: if summons 1-9 hold no Topaz+, the 10th is Topaz+ (Opal
## OPAL_SHARE_IN_L inside it); it gives Seals and moves pity like any ×10.
## Returns {ok, reason, src, count, results [{gem, id, new, frags, tomes, awakened}], best, seals,
## beacons (spent), welcome_rule (the 10th was forced)}.
static func summon(acc: Dictionary, count: int, rng: RandomNumberGenerator, src := "beacons", now_s := 0,
		eligible: Array = []) -> Dictionary:
	var why := block(acc, count, src, eligible)
	if why != "":
		return {"ok": false, "reason": why, "src": src, "count": count, "results": []}
	var st := state(acc)
	var paid := cost(count, src)
	MetaAcc.spend(acc, "beacons", paid)
	if src == "welcome":
		st["welcome_done"] = true
	var results: Array[Dictionary] = []
	var any_lplus := false
	var forced := false
	var best := "C"
	for i in count:
		var gem := ""
		if src == "welcome" and i == count - 1 and not any_lplus:
			gem = "M" if rng.randf() < PortalData.OPAL_SHARE_IN_L else "L"
			_advance(st, gem)
			forced = true
		else:
			gem = roll_gem(st, rng)
		any_lplus = any_lplus or Ladder.gem_index(gem) >= Ladder.gem_index("L")
		if Ladder.gem_index(gem) > Ladder.gem_index(best):
			best = gem
		st["total"] = int(st["total"]) + 1
		st["seals"] = int(st["seals"]) + PortalData.SEALS_PER_SUMMON
		var id := pick_hero(acc, gem, rng, eligible)
		var g := Roster.grant(acc, id, "portal", now_s)
		results.append({"gem": gem, "id": id, "new": bool(g["new"]), "frags": int(g["frags"]), "tomes": int(g["tomes"]),
				"awakened": bool(g["awakened"])})
		var hist: Array = st["history"]
		hist.append({"g": gem, "id": id, "t": maxi(0, now_s)})
		while hist.size() > HISTORY_MAX:
			hist.remove_at(0)
	MetaAcc.count(acc, "summons", count)
	MetaTelemetry.note(acc, "summon", {"n": count, "best": best,
			"e_left": int(PortalData.PITY_E["hard"]) - int(st["since_e"]),
			"l_left": int(PortalData.PITY_L["hard"]) - int(st["since_l"]),
			"seals": int(st["seals"]), "welcome": src == "welcome"}, now_s)
	return {"ok": true, "reason": "", "src": src, "count": count, "results": results, "best": best,
			"seals": count * PortalData.SEALS_PER_SUMMON, "beacons": paid, "welcome_rule": forced}


## True once the free welcome ×10 was used.
static func welcome_done(acc: Dictionary) -> bool:
	return bool(state(acc).get("welcome_done", false))


## The free welcome ×10 at the Portal unlock.
static func welcome(acc: Dictionary, rng: RandomNumberGenerator, now_s := 0, eligible: Array = []) -> Dictionary:
	return summon(acc, PortalData.X10_SUMMONS, rng, "welcome", now_s, eligible)


## Summons left until the guarantees: {e (Amethyst+ certain on this many more), l (Topaz+ certain)}.
static func pity_left(acc: Dictionary) -> Dictionary:
	var st := state(acc)
	return {"e": int(PortalData.PITY_E["hard"]) - int(st["since_e"]), "l": int(PortalData.PITY_L["hard"]) - int(st["since_l"])}


# ------------------------------------------------------------------ Seals (§7.4)

## The Seal shop: every eligible Amethyst / Topaz / Opal hero with {id, gem, price, owned, frags
## (an owned pick = OWNED_SEAL_PICK_MULT x DUP_FRAGS), tomes (overflow it would give)}.
static func seal_offer(acc: Dictionary, eligible: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: String in PortalData.SEAL_PRICES:
		for id in pool(acc, g, eligible):
			var own := Roster.owned(acc, id)
			var fr := PortalData.OWNED_SEAL_PICK_MULT * HeroData.dup_frags(g) if own else 0
			out.append({"id": id, "gem": g, "price": PortalData.seal_price(g), "owned": own, "frags": fr,
					"tomes": Roster.overflow_preview(acc, id, fr) if own else 0})
	return out


## "" when `id` can be bought with Seals now, else locked | hero | seals.
static func seal_block(acc: Dictionary, id: String, eligible: Array = []) -> String:
	if not is_open(acc):
		return "locked"
	var g := Roster.native(id)
	if Roster.kind_of(id) != Roster.KIND_HERO or PortalData.seal_price(g) <= 0 or not pool(acc, g, eligible).has(id):
		return "hero"
	if int(state(acc)["seals"]) < PortalData.seal_price(g):
		return "seals"
	return ""


## Buys hero `id` with Seals: a new hero joins (via "seal"); an owned one gets OWNED_SEAL_PICK_MULT x
## its DUP_FRAGS fragments. Gives no Seals and moves no pity. {ok, reason, id, gem, price, new, frags, tomes}.
static func seal_pick(acc: Dictionary, id: String, now_s := 0, eligible: Array = []) -> Dictionary:
	var why := seal_block(acc, id, eligible)
	if why != "":
		return {"ok": false, "reason": why, "id": id}
	var g := Roster.native(id)
	var price := PortalData.seal_price(g)
	var st := state(acc)
	st["seals"] = int(st["seals"]) - price
	var own := Roster.owned(acc, id)
	var res := {"ok": true, "reason": "", "id": id, "gem": g, "price": price, "new": false, "frags": 0, "tomes": 0}
	if own:
		var add := Roster.add_frags(acc, id, PortalData.OWNED_SEAL_PICK_MULT * HeroData.dup_frags(g), "seal")
		res["frags"] = int(add["frags"])
		res["tomes"] = int(add["tomes"])
	else:
		var gr := Roster.grant(acc, id, "seal", now_s)
		res["new"] = bool(gr["new"])
	MetaTelemetry.note(acc, "seal_pick", {"id": id, "gem": g, "cost": price, "owned": own}, now_s)
	return res


# ------------------------------------------------------------------ Beacons (§7.3)

## Credits Beacon income from `source` (BEACON_SOURCES) `times` over: fractions bank in
## wallet.beacon_charge and whole Beacons move to the wallet. Returns the whole Beacons added.
## 0 for any other source (Track, Road, shop, ads, ...) and before the Portal's unlock level (the
## income rule Roster.income_open, the same as Rewards; review F8).
static func credit(acc: Dictionary, source: String, times := 1.0) -> int:
	if not BEACON_SOURCES.has(source) or not Roster.income_open(acc, "portal") or times <= 0.0:
		return 0
	var w: Dictionary = acc["wallet"]
	var ch := float(w.get("beacon_charge", 0.0)) + float(PortalData.BEACON[source]) * times
	var whole := int(ch + 1e-9)
	w["beacon_charge"] = maxf(0.0, ch - whole)
	MetaAcc.add(acc, "beacons", whole)
	return whole


# ------------------------------------------------------------------ disclosure ((i) sheet, §7.2)

## Exact consolidated gem odds over the stationary pity chain (sim portal_exact), as generated into
## PortalData.ODDS_CONSOLIDATED: the (i) sheet reads the constant (review F3: solving the chain took
## ~0.8 s on desktop). {gem: p}.
static func consolidated() -> Dictionary:
	return PortalData.ODDS_CONSOLIDATED.duplicate()


## The same table solved at runtime from the PortalData rules (tests and tools/odds_table.gd check
## it equals the generated constant). {gem: p}.
static func solve_consolidated() -> Dictionary:
	if _cons_cache.is_empty():
		_solve_chain()
	return _cons_cache.duplicate()


## Stationary distribution of pity states {Vector2i(since_e, since_l): p}.
static func stationary() -> Dictionary:
	if _stat_cache.is_empty():
		_solve_chain()
	return _stat_cache


static func _solve_chain() -> void:
	var dist := {Vector2i(0, 0): 1.0}
	for _it in 4000:
		var nd := {}
		for s: Vector2i in dist:
			var p := float(dist[s])
			var step := step_odds(s.x, s.y)
			for g: String in step:
				var q := float(step[g])
				if q <= 0.0:
					continue
				var gi := Ladder.gem_index(g)
				var ns := Vector2i(0 if gi >= 2 else s.x + 1, 0 if gi >= 3 else s.y + 1)
				nd[ns] = float(nd.get(ns, 0.0)) + p * q
		var diff := 0.0
		for k: Vector2i in nd:
			diff += absf(float(nd[k]) - float(dist.get(k, 0.0)))
		for k2: Vector2i in dist:
			if not nd.has(k2):
				diff += float(dist[k2])
		dist = nd
		if diff < 1e-15:
			break
	var cons := {"C": 0.0, "R": 0.0, "E": 0.0, "L": 0.0, "M": 0.0}
	for s2: Vector2i in dist:
		var step2 := step_odds(s2.x, s2.y)
		for g2: String in step2:
			cons[g2] = float(cons[g2]) + float(dist[s2]) * float(step2[g2])
	_cons_cache = cons
	_stat_cache = dist


## Exact distribution of the best gem of a ×10 from pity state (since_e, since_l) (sim
## portal_x10_best); `welcome` applies the welcome rule. {gem: p} over the gems that can be best.
static func x10_best(since_e := 0, since_l := 0, welcome_rule := false) -> Dictionary:
	var dist := {Vector3i(since_e, since_l, -1): 1.0}
	for k in PortalData.X10_SUMMONS:
		var nd := {}
		for s: Vector3i in dist:
			var p := float(dist[s])
			var step := step_odds(s.x, s.y)
			if welcome_rule and k == PortalData.X10_SUMMONS - 1 and s.z < Ladder.gem_index("L"):
				step = {"L": 1.0 - PortalData.OPAL_SHARE_IN_L, "M": PortalData.OPAL_SHARE_IN_L}
			for g: String in step:
				var q := float(step[g])
				if q <= 0.0:
					continue
				var gi := Ladder.gem_index(g)
				var ns := Vector3i(0 if gi >= 2 else s.x + 1, 0 if gi >= 3 else s.y + 1, maxi(s.z, gi))
				nd[ns] = float(nd.get(ns, 0.0)) + p * q
		dist = nd
	var out := {}
	for s2: Vector3i in dist:
		var g2: String = Ladder.GEMS[s2.z]
		out[g2] = float(out.get(g2, 0.0)) + float(dist[s2])
	return out


## Best gem of a typical ×10 (starting from the stationary pity state): the generated
## PortalData.ODDS_X10_TYPICAL (review F3). {gem: p}.
static func x10_best_stationary() -> Dictionary:
	return PortalData.ODDS_X10_TYPICAL.duplicate()


## Best gem of the welcome ×10 from the account's pity now: the generated ODDS_X10_WELCOME from fresh
## pity (always, while Beacon summons wait for the welcome), else solved from the current state. {gem: p}.
static func welcome_odds(acc: Dictionary) -> Dictionary:
	var st := state(acc)
	if int(st.get("since_e", 0)) == 0 and int(st.get("since_l", 0)) == 0:
		return PortalData.ODDS_X10_WELCOME.duplicate()
	return x10_best(int(st["since_e"]), int(st["since_l"]), true)


## x10_best_stationary solved at runtime (~0.5 s; tests / tools only). {gem: p}.
static func solve_x10_best_stationary() -> Dictionary:
	var out := {}
	var st := stationary()
	for s: Vector2i in st:
		var b := x10_best(s.x, s.y)
		for g: String in b:
			out[g] = float(out.get(g, 0.0)) + float(st[s]) * float(b[g])
	return out


## Per-hero odds the (i) sheet lists now (consolidated gem odds x the in-gem shares). {id: p}.
static func hero_odds(acc: Dictionary, eligible: Array = []) -> Dictionary:
	var cons := consolidated()
	var out := {}
	for id in HeroData.HERO_ORDER:
		out[id] = 0.0
	for g in Ladder.GEMS:
		var w := hero_weights(acc, g, eligible)
		for id2: String in w:
			out[id2] = float(cons[g]) * float(w[id2])
	return out
