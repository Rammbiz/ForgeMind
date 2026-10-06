extends Node
## Headless unit tests of the Meta-1 core (WS1): Cache odds vs the sim (chi-square), pity caps,
## welcome Legendary, frozen counters, duplicate protection, Focus / Deck weights, Wild overflow,
## upgrade costs and curves, Arsenal Sync, final stats, run_profile shape, finish_run
## idempotence, loss payout + Reinforcements + loss charge, UnlockQueue sessions, Save v2 io
## (atomic write, .bak fallback) and the v1 -> v2 migration fixtures (levels 1, 9, 30).
##
## godot --headless --path . res://scenes/dev/test_meta.tscn -- --autotest
## (--autotest keeps Save readonly: the player's save is never touched). Exit code = failures.
## --quick: 20 000-cache pity streams instead of 200 000.

const FIX := "res://scripts/dev/fixtures/"
const TMP_DIR := "user://test_meta"
## Chi-square critical values at p = 0.001 by degrees of freedom.
const CHI_CRIT := {1: 10.83, 2: 13.82, 3: 16.27, 4: 18.47}

const POOL_W1: Array[String] = ["drone", "ballista", "cannon", "rockets", "mortar"]
const POOL_W2: Array[String] = ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun"]
const POOL_W3: Array[String] = ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun", "prism"]

var _fails := 0
var _passes := 0
var _quick := false


func _ready() -> void:
	_quick = "--quick" in OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	_test_data_totals()
	_test_exact_odds()
	_test_chi_square()
	_test_pity_streams()
	_test_pity_rules()
	_test_grant_rules()
	_test_upgrades()
	_test_stats()
	_test_heroes_barracks()
	_test_unlock_queue()
	_test_run_profile()
	_test_finish_run()
	_test_loss_flow()
	_test_save_io()
	_test_migration()
	_test_live_save()
	_test_telemetry()
	print("TEST_META %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL ", what)


func _near(a: float, b: float, tol: float, what: String) -> void:
	_ok(absf(a - b) <= tol, "%s: %.5f vs %.5f (tol %.5f)" % [what, a, b, tol])


func _acc_at(level: int, kind := "fresh") -> Dictionary:
	return Meta.synthetic_account(level, kind)


## An account at `level` whose unlocks are NOT pre-acknowledged (natural player).
func _natural(level: int) -> Dictionary:
	var acc := Meta.synthetic_account(level, "fresh")
	(acc["unlocks"] as Dictionary)["done"] = []
	return acc


# ======================================================================== data and curves

func _test_data_totals() -> void:
	print("== curves and totals")
	_ok(int(EconData.full_machine_cost("C")["coins"]) == 24250, "machine coins 1->15 = 24 250")
	_ok(Arsenal.full_arsenal_coins() == 578270, "full arsenal = 578 270 (got %d)" % Arsenal.full_arsenal_coins())
	_ok(HeroesMeta.total_cost() == 42140, "hero 1->30 = 42 140 (got %d)" % HeroesMeta.total_cost())
	_ok(Barracks.total_cost() == 11015, "barracks track 0->10 = 11 015 (got %d)" % Barracks.total_cost())
	_ok(EconData.hero_cost(1) == 30 and EconData.hero_cost(10) == 750 and EconData.hero_cost(29) == 3350, "hero cost points")
	_ok(EconData.barracks_cost(1) == 70 and EconData.barracks_cost(5) == 850 and EconData.barracks_cost(10) == 2485, "barracks cost points")
	var bp_tot := {"C": 273, "R": 110, "E": 40, "L": 21, "M": 19}
	for r: String in bp_tot:
		_ok(int(EconData.full_machine_cost(r)["bp"]) == int(bp_tot[r]), "blueprints %s total %d" % [r, bp_tot[r]])
	var prev := 0
	var mono := true
	for l in range(2, 16):
		mono = mono and EconData.coin_to(l) > prev
		prev = EconData.coin_to(l)
	_ok(mono, "COIN_TO rises every level")
	_ok(EconData.victory_coins(10, 66) == 20 + 60 + 22, "victory coins 20 + 6L + min(s/3, 25)")
	_ok(EconData.loss_coins(7, 20, 0.5) == 15, "loss payout L7 pickups 20 half bridge = 15 (got %d)" % EconData.loss_coins(7, 20, 0.5))
	_ok(EconData.hero_cap(1) == 9 and EconData.hero_cap(7) == 27 and EconData.barracks_cap(1) == 4 and EconData.barracks_cap(4) == 10, "caps")


# ======================================================================== odds

func _test_exact_odds() -> void:
	print("== disclosed odds (exact)")
	var w2 := CacheRoller.present(POOL_W2, "stone")
	var w3 := CacheRoller.present(POOL_W3, "stone")
	var o1 := CacheRoller.odds("stone", w3)
	_near(float(o1["best"]["L"]), 0.0705, 0.00006, "World 3 Stone best L")
	_near(float(o1["best"]["E"]), 0.2914, 0.00006, "World 3 Stone best E")
	_near(float(o1["best"]["R"]), 0.6381, 0.00006, "World 3 Stone best R")
	_near(float(o1["guaranteed"]["L"]), 0.0439, 0.00006, "World 3 Stone guaranteed L")
	var o2 := CacheRoller.odds("world", w3)
	_near(float(o2["best"]["L"]), 0.2224, 0.00006, "World 3 World best L")
	_near(float(o2["guaranteed"]["E"]), 0.8228, 0.00006, "World 3 World guaranteed E")
	var o3 := CacheRoller.odds("stone", w2)
	_near(float(o3["best"]["E"]), 0.3135, 0.00006, "World 2 Stone best E")
	_near(float(o3["guaranteed"]["E"]), 0.2131, 0.00006, "World 2 Stone guaranteed E")
	_ok(CacheRoller.odds("world", w2)["best"].get("E", 0.0) > 0.9999, "World 2 World best E = 100%")
	var o4 := CacheRoller.odds("stone", CacheRoller.present(POOL_W1, "stone"))
	_ok(float(o4["best"].get("R", 0.0)) > 0.9999 and int(o4["pity_left"]) == -1, "World 1 Stone best R = 100%, pity hidden")
	var tot := 0.0
	for r in o1["best"]:
		tot += float(o1["best"][r])
	_near(tot, 1.0, 1e-9, "best-card table sums to 1")


## Roller vs the exact tables: chi-square over 20 000 rolls per pool state (no pity active).
func _test_chi_square() -> void:
	print("== roller vs sim tables (chi-square, 20 000 rolls each)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for case in [["stone", POOL_W1], ["stone", POOL_W2], ["stone", POOL_W3], ["world", POOL_W2], ["world", POOL_W3]]:
		var type: String = case[0]
		var pool: Array[String] = []
		pool.assign(case[1])
		var pres := CacheRoller.present(pool, type)
		var o := CacheRoller.odds(type, pres)
		var n := 20000
		var best_cnt := {}
		var free_cnt := {}
		var free_n := 0
		var wild_n := 0
		for i in n:
			var pity := {"since_epic": 0, "since_leg": 0, "leg_welcome_done": true}
			var res := CacheRoller.roll(type, pool, pity, rng)
			var rars: Array[String] = res["rarities"]
			best_cnt[res["best"]] = int(best_cnt.get(res["best"], 0)) + 1
			for s in rars.size() - 1:
				free_cnt[rars[s]] = int(free_cnt.get(rars[s], 0)) + 1
				free_n += 1
			for wv in res["wild"]:
				wild_n += 1 if wv else 0
		_chi(best_cnt, o["best"], n, "%s %s best card" % [type, "".join(pres)])
		_chi(free_cnt, o["per_card"], free_n, "%s %s free-slot card" % [type, "".join(pres)])
		var slots := int((EconData.CACHES[type] as Dictionary)["slots"])
		var wild_p := float(wild_n) / float(n * slots)
		var se := sqrt(EconData.WILD_CARD_CHANCE * (1.0 - EconData.WILD_CARD_CHANCE) / float(n * slots))
		_ok(absf(wild_p - EconData.WILD_CARD_CHANCE) <= 4.0 * se, "%s %s wild rate %.4f" % [type, "".join(pres), wild_p])


func _chi(counts: Dictionary, probs: Dictionary, n: int, what: String) -> void:
	var chi := 0.0
	var k := 0
	for r in probs:
		var e := float(probs[r]) * float(n)
		if e <= 0.0:
			_ok(int(counts.get(r, 0)) == 0, what + ": impossible rarity %s drawn" % r)
			continue
		k += 1
		var o := float(counts.get(r, 0))
		chi += (o - e) * (o - e) / e
	for r2 in counts:
		if not probs.has(r2) or float(probs[r2]) <= 0.0:
			_ok(false, what + ": rarity %s outside the table" % r2)
	if k <= 1:
		_ok(true, what)
		return
	var crit := float(CHI_CRIT.get(k - 1, 20.0))
	_ok(chi <= crit, "%s chi2 %.2f <= %.2f (df %d)" % [what, chi, crit, k - 1])


func _stream(n: int, pool: Array[String], type := "stone", seed := 5) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pity := {"since_epic": 0, "since_leg": 0, "leg_welcome_done": true}
	var legs := 0
	var epics := 0
	var last_l := -1
	var last_e := -1
	var max_l := 0
	var max_e := 0
	for i in n:
		var b := str(CacheRoller.roll(type, pool, pity, rng)["best"])
		var bi := ArsenalData.rarity_index(b)
		if bi >= 3:
			legs += 1
			max_l = maxi(max_l, i - last_l)
			last_l = i
		if bi >= 2:
			epics += 1
			max_e = maxi(max_e, i - last_e)
			last_e = i
	return {"per_leg": float(n) / float(maxi(legs, 1)), "per_epic": float(n) / float(maxi(epics, 1)),
			"max_l": max_l, "max_e": max_e}


func _test_pity_streams() -> void:
	var n := 20000 if _quick else 200000
	print("== pity streams (%d Stone Caches)" % n)
	var s3 := _stream(n, POOL_W3)
	print("  World 3: 1 Legendary per %.2f, Epic+ per %.2f, longest gaps L %d / E %d" % [s3["per_leg"], s3["per_epic"], s3["max_l"], s3["max_e"]])
	# Exact stationary rates of the pity Markov chain (since_epic x since_leg): 11.96 / 2.638 / 3.032.
	# The design's printed 11.8 / 2.63 / 3.01 are one 200 000-cache seed of the sim; a 1 000 000-cache
	# sim stream gives 11.95 / 2.642, the same as this port.
	_near(float(s3["per_leg"]), 11.96, 0.25 if not _quick else 0.6, "World 3: Caches per Legendary (exact 11.96, design 11.8)")
	_near(float(s3["per_epic"]), 2.638, 0.03 if not _quick else 0.08, "World 3: Caches per Epic+ (exact 2.638)")
	_ok(int(s3["max_l"]) <= int(EconData.PITY["leg_hard"]), "Legendary gap <= hard pity 30 (got %d)" % s3["max_l"])
	_ok(int(s3["max_e"]) <= int(EconData.PITY["epic"]), "Epic gap <= 8 (got %d)" % s3["max_e"])
	if not _quick:
		_ok(int(s3["max_l"]) == int(EconData.PITY["leg_hard"]), "longest Legendary gap is exactly 30 (design)")
	var s2 := _stream(n, POOL_W2)
	print("  World 2: Epic+ per %.2f, longest gap %d" % [s2["per_epic"], s2["max_e"]])
	_near(float(s2["per_epic"]), 3.032, 0.03 if not _quick else 0.08, "World 2: Caches per Epic+ (exact 3.032, design 3.01)")
	_ok(int(s2["max_e"]) <= 8, "World 2 Epic gap <= 8")


func _test_pity_rules() -> void:
	print("== pity rules")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Welcome Legendary: the first Cache after L enters the pool.
	var welcome_ok := true
	for i in 200:
		var pity := {"since_epic": 0, "since_leg": 0, "leg_welcome_done": false}
		var res := CacheRoller.roll("stone", POOL_W3, pity, rng)
		welcome_ok = welcome_ok and str(res["best"]) == "L" and bool(pity["leg_welcome_done"]) and int(pity["since_leg"]) == 0
	_ok(welcome_ok, "welcome Legendary on the first World-3 Cache")
	# Frozen counters.
	var p1 := {"since_epic": 0, "since_leg": 0, "leg_welcome_done": false}
	for i2 in 100:
		CacheRoller.roll("stone", POOL_W1, p1, rng)
	_ok(int(p1["since_epic"]) == 0 and int(p1["since_leg"]) == 0 and not bool(p1["leg_welcome_done"]), "World 1: both counters frozen")
	var p2 := {"since_epic": 0, "since_leg": 0, "leg_welcome_done": false}
	for i3 in 100:
		CacheRoller.roll("stone", POOL_W2, p2, rng)
	_ok(int(p2["since_leg"]) == 0 and not bool(p2["leg_welcome_done"]), "World 2: Legendary counter frozen")
	# Hard / epic pity triggers.
	var hard_ok := true
	var epic_ok := true
	for i4 in 300:
		var ph := {"since_epic": 0, "since_leg": 29, "leg_welcome_done": true}
		hard_ok = hard_ok and str(CacheRoller.roll("stone", POOL_W3, ph, rng)["best"]) == "L"
		var pe := {"since_epic": 7, "since_leg": 0, "leg_welcome_done": true}
		epic_ok = epic_ok and ArsenalData.rarity_index(str(CacheRoller.roll("stone", POOL_W2, pe, rng)["best"])) >= 2
	_ok(hard_ok, "since_leg 29 -> Legendary guaranteed")
	_ok(epic_ok, "since_epic 7 -> Epic+ guaranteed")
	# Soft pity raises the Legendary share (n = 25 -> >= 18% on the last slot).
	var soft := 0
	for i5 in 4000:
		var ps := {"since_epic": 0, "since_leg": 24, "leg_welcome_done": true}
		if str(CacheRoller.roll("stone", POOL_W3, ps, rng)["best"]) == "L":
			soft += 1
	_ok(float(soft) / 4000.0 >= 0.18, "soft pity at n=25: P(L) %.3f >= 0.18" % (float(soft) / 4000.0))
	_ok(CacheRoller.pity_left(["C", "R", "E", "L"], {"since_leg": 5, "leg_welcome_done": true}) == 25, "pity_left 30 - since_leg")
	_ok(CacheRoller.pity_left(["C", "R", "E", "L"], {"since_leg": 0, "leg_welcome_done": false}) == 1, "pity_left welcome = 1")
	_ok(CacheRoller.pity_left(["C", "R", "E"], {"since_leg": 3, "leg_welcome_done": true}) == -1, "pity_left hidden without L")


# ======================================================================== card grant

func _test_grant_rules() -> void:
	print("== grant: duplicates, Focus, Deck, Wild")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Duplicate protection: a Legendary goes to the unowned Prism first.
	var acc := _acc_at(22)
	(MetaAcc.machines(acc) as Dictionary).erase("prism")
	var pool := CacheRoller.pool(acc)
	_ok(pool.has("prism"), "World 3 pool holds Prism")
	var c1 := CacheRoller.grant_card(acc, "L", pool, rng, false)
	_ok(str(c1["id"]) == "prism" and bool(c1["new"]) and MetaAcc.owned(acc, "prism"), "Legendary card unlocks the unowned Prism (NEW)")
	_ok(int(MetaAcc.machines(acc)["prism"]["lvl"]) >= 4, "Prism starts at >= its rarity start level")
	var c2 := CacheRoller.grant_card(acc, "L", pool, rng, false)
	_ok(str(c2["id"]) == "prism" and not bool(c2["new"]) and int(c2["bp_after"]) == int(c2["bp_before"]) + 1, "owned Legendary: +1 blueprint, not NEW")
	# Focus 40% (+ even Deck weights before the Deck unlock: all 4 Commons are in the auto deck).
	var a2 := _acc_at(6)
	Arsenal.set_focus(a2, "ballista")
	var p2 := CacheRoller.pool(a2)
	var hits := 0
	var n := 20000
	for i in n:
		if str(CacheRoller.grant_card(a2, "C", p2, rng, false)["id"]) == "ballista":
			hits += 1
	_near(float(hits) / n, 0.40 + 0.60 / 4.0, 0.015, "Focus share of its rarity (0.4 + 0.6 x 1/4)")
	# Deck x1.5 (no Focus: no Lead below Lv5).
	var a3 := _acc_at(14)
	_ok(Arsenal.set_deck(a3, ["drone", "cannon", "mortar"]), "set_deck 3 machines")
	Arsenal.set_focus(a3, "")
	_ok(Arsenal.focus(a3) == "", "no Focus without a Lead")
	var p3 := CacheRoller.pool(a3)
	var dh := 0
	for i2 in n:
		if str(CacheRoller.grant_card(a3, "C", p3, rng, false)["id"]) == "drone":
			dh += 1
	_near(float(dh) / n, 1.5 / 6.0, 0.012, "Deck machine share 1.5 / (1.5 + 1.5 + 1 + 1 + 1)")
	# Lv15 machine: blueprints become Wild Blueprints 1:1.
	var a4 := _acc_at(3)
	(MetaAcc.machines(a4)["ballista"] as Dictionary)["lvl"] = 15
	var w_before := MetaAcc.amount(a4, "wild_C")
	var c4 := CacheRoller.grant_card(a4, "C", ["ballista"], rng, false, "ballista", 3)
	_ok(MetaAcc.amount(a4, "wild_C") == w_before + 3 and int(c4["to_wild"]) == 3, "Lv15 overflow -> 3 Wild Commons")
	var c5 := CacheRoller.grant_card(a4, "R", ["mortar"], rng, true)
	_ok(bool(c5["wild"]) and MetaAcc.amount(a4, "wild_R") == 1, "Wild card adds a Wild Blueprint")
	# A full open: saved pity, coins slot, ascending cards, scripted first Stone Cache.
	var a5 := _natural(7)
	var rev := CacheRoller.open(a5, "stone", "win", rng)
	_ok(bool(rev["scripted"]) and int(rev["coins"]) == 30 + 3 * 7, "first Stone Cache is scripted, coins 30 + 3 x frontier")
	var ids: Array = []
	for c in rev["cards"]:
		ids.append(str(c["id"]))
	_ok(ids.has("ballista") and ids.has("drone"), "scripted cache: Ballista + Drone (%s)" % str(ids))
	var asc := true
	for i3 in range(1, (rev["cards"] as Array).size()):
		asc = asc and ArsenalData.rarity_index(str(rev["cards"][i3]["rarity"])) >= ArsenalData.rarity_index(str(rev["cards"][i3 - 1]["rarity"]))
	_ok(asc, "cards sorted ascending by rarity")
	var rev2 := CacheRoller.open(a5, "stone", "win", rng)
	_ok(not bool(rev2["scripted"]) and int((a5["vault"] as Dictionary)["stone_total"]) == 2, "second Stone Cache is random")


# ======================================================================== upgrades

func _test_upgrades() -> void:
	print("== upgrades")
	var acc := _acc_at(12)
	var st: Dictionary = MetaAcc.machines(acc)["ballista"]
	st["lvl"] = 2
	st["bp"] = 1
	(acc["wallet"] as Dictionary)["coins"] = 1000
	(acc["wallet"]["wild"] as Dictionary)["C"] = 2
	var c := Arsenal.cost(acc, "ballista")
	_ok(bool(c["can"]) and int(c["coins"]) == 80 and int(c["bp_need"]) == 3 and int(c["wild_use"]) == 2 and str(c["beat"]) == "talent1", "cost to Lv3: 80 coins, 3 bp (2 wild)")
	var u := Arsenal.upgrade(acc, "ballista")
	_ok(bool(u["ok"]) and int(st["lvl"]) == 3 and int(st["bp"]) == 0 and MetaAcc.amount(acc, "wild_C") == 0 and MetaAcc.amount(acc, "coins") == 920, "upgrade spends bp, then wild, then coins")
	_ok(str(Arsenal.cost(acc, "ballista")["reason"]) == "blueprints", "reason blueprints")
	st["bp"] = 10
	(acc["wallet"] as Dictionary)["coins"] = 10
	_ok(str(Arsenal.cost(acc, "ballista")["reason"]) == "coins", "reason coins")
	(MetaAcc.machines(acc).erase("prism"))
	_ok(str(Arsenal.cost(acc, "prism")["reason"]) == "not_owned", "reason not_owned")
	st["lvl"] = 15
	_ok(str(Arsenal.cost(acc, "ballista")["reason"]) == "max", "reason max")
	var fresh := _natural(2)
	(fresh["wallet"] as Dictionary)["coins"] = 500
	_ok(str(Arsenal.cost(fresh, "drone")["reason"]) == "locked", "Arsenal locked before L3 is won")
	# Free first step (Arsenal unlock: Ballista Lv2).
	var a2 := _natural(4)
	UnlockQueue.ack(a2, "arsenal")
	var c2 := Arsenal.cost(a2, "ballista")
	_ok(bool(c2["free"]) and int(c2["coins"]) == 0 and bool(c2["can"]), "free first step: Ballista Lv2 costs 0")
	Arsenal.upgrade(a2, "ballista")
	_ok(int(Arsenal.cost(a2, "ballista")["coins"]) == 80 and not MetaAcc.free_steps(a2).has("machine"), "free step consumed")
	# Arsenal Sync.
	var a3 := _acc_at(30)
	for id in ["drone", "ballista", "cannon"]:
		(MetaAcc.machines(a3)[id] as Dictionary)["lvl"] = 10
	(MetaAcc.machines(a3) as Dictionary).erase("prism")
	_ok(Arsenal.sync_level(a3, "prism") == 7, "Arsenal Sync caps at 7 (3rd best 10)")
	for id2 in MetaAcc.machines(a3):
		(MetaAcc.machines(a3)[id2] as Dictionary)["lvl"] = 4
	_ok(Arsenal.sync_level(a3, "prism") == 4 and Arsenal.sync_level(a3, "gatling") == 2, "Arsenal Sync: max(rarity start, 3rd best - 2)")
	_ok(Arsenal.unlock(a3, "prism", "test") and not Arsenal.unlock(a3, "prism", "test") and not Arsenal.unlock(a3, "tesla", "test"), "unlock once; Meta-2 machines never unlock")
	_ok(Arsenal.beat_at(5) == "lead" and Arsenal.beat_at(8) == "ascension" and Arsenal.beat_at(13) == "prestige" and Arsenal.beat_at(4) == "", "beats")
	# Talents need the Talents unlock and the level.
	var a4 := _natural(13)
	(MetaAcc.machines(a4)["ballista"] as Dictionary)["lvl"] = 6
	_ok(not Arsenal.set_talent(a4, "ballista", 0, "tempered"), "talents closed before L13 is won")
	var a5 := _acc_at(14)
	(MetaAcc.machines(a5)["ballista"] as Dictionary)["lvl"] = 6
	_ok(Arsenal.set_talent(a5, "ballista", 0, "tempered") and Arsenal.set_talent(a5, "ballista", 1, "piercing"), "talent I/II picks")
	_ok(not Arsenal.set_talent(a5, "ballista", 0, "capacitor") and not Arsenal.set_talent(a5, "ballista", 2, "ricochet"), "foreign talent / Talent III refused")
	_ok(Arsenal.set_talent(a5, "ballista", 0, "long_barrel"), "free respec")
	_ok(not Arsenal.set_branch(a5, "railgun", "b"), "branches off in Meta-1")
	# Best upgrade picks something affordable and prefers the free step.
	var a6 := _acc_at(20, "expected")
	(a6["wallet"] as Dictionary)["coins"] = 2000
	var bu := Arsenal.best_upgrade(a6)
	_ok(not bu.is_empty() and str(bu["kind"]) in ["machine", "hero", "barracks"] and int(bu["cost"]) <= 2000, "best upgrade %s" % str(bu))
	(a6["wallet"] as Dictionary)["coins"] = 0
	_ok(Arsenal.best_upgrade(a6).is_empty(), "best upgrade {} when broke")
	var rc := Arsenal.remaining_cost(_acc_at(1))
	_ok(int(rc["coins"]) == 24250 and float(rc["share_done"]) == 0.0, "remaining cost of a fresh Drone")


func _test_stats() -> void:
	print("== stats")
	var s := ArsenalData.machine_stats("ballista", 15, 3, ["tempered", "piercing"])
	_near(float(s["stats"]["damage"]), 16.03, 0.01, "ballista Lv15 R3 damage 3 x 1.2 x 2.12 x 2.1")
	_ok(int(s["stats"]["pierce"]) == 4 and int(s["stats"]["bolts"]) == 2 and absf(float(s["add"]) - 0.15) < 1e-6, "pierce 4, bolts 2, add 0.15")
	var acc := _acc_at(14)
	var st: Dictionary = MetaAcc.machines(acc)["ballista"]
	st["lvl"] = 15
	Arsenal.set_talent(acc, "ballista", 0, "tempered")
	Arsenal.set_talent(acc, "ballista", 1, "piercing")
	var a := Arsenal.stats(acc, "ballista", 3)
	_near(float(a["final"]["damage"]), 16.03 * 1.15, 0.02, "final card damage = bucket 1 x (1 + 0.15)")
	_near(float(a["final"]["dps"]), 16.03 * 1.15 * 0.9 * 2.0, 0.05, "final dps = damage x rate x bolts")
	var fresh := Arsenal.stats(_acc_at(1), "drone")
	_ok(int(fresh["lvl"]) == 1 and float(fresh["stats"]["damage"]) == 1.0, "drone Lv1 = Balance anchor")
	_ok(int(Arsenal.stats(_acc_at(1), "prism")["lvl"]) == 4, "unowned machine previews at its start level")


func _test_heroes_barracks() -> void:
	print("== heroes and barracks")
	var acc := _acc_at(9)
	(acc["wallet"] as Dictionary)["coins"] = 100000
	var n := 0
	while HeroesMeta.can_level(acc, "bolt"):
		HeroesMeta.level_up(acc, "bolt")
		n += 1
	_ok(HeroesMeta.level(acc, "bolt") == EconData.hero_cap(2), "hero levels up to the world cap %d (got %d)" % [EconData.hero_cap(2), HeroesMeta.level(acc, "bolt")])
	var hp := HeroesMeta.profile(acc, "bolt")
	_near(float(hp["dmg_mult"]), 1.0 + 0.035 * 11, 1e-6, "hero dmg_mult at Lv12")
	_ok(int(hp["ult_rank"]) == 2, "ult rank II from Lv5")
	_ok(not HeroesMeta.can_level(_natural(4), "titan"), "Titan locked until L4 is won")
	var nat := _natural(5)
	UnlockQueue.ack(nat, "heroes")
	(nat["wallet"] as Dictionary)["coins"] = 0
	_ok(HeroesMeta.cost(nat, "bolt") == 0 and bool(HeroesMeta.level_up(nat, "bolt")["ok"]), "free first hero level")
	_ok(HeroesMeta.cost(nat, "bolt") == EconData.hero_cost(2), "free hero step consumed")
	var b := _acc_at(13)
	(b["wallet"] as Dictionary)["coins"] = 100000
	var cap := Barracks.cap(b)
	for i in 20:
		Barracks.buy(b, "recruits")
	_ok(Barracks.level(b, "recruits") == cap, "barracks capped at 2 + 2 x world (%d)" % cap)
	(b["barracks"] as Dictionary)["reserves"] = 3
	(b["barracks"] as Dictionary)["volleys"] = 5
	(b["barracks"] as Dictionary)["drill"] = 2
	var ap := Barracks.profile(b)
	_ok(int(ap["recruit_bonus"]) == cap / 2 and int(ap["reserves"]) == 6 and absf(float(ap["volley_mult"]) - 1.3) < 1e-6 \
			and absf(float(ap["drill"]) - 0.06) < 1e-6 and int(ap["max_tier"]) == 2, "army profile values %s" % str(ap))
	_ok(not Barracks.can_buy(_natural(12), "recruits"), "Barracks locked until L12 is won")


# ======================================================================== unlocks

func _test_unlock_queue() -> void:
	print("== UnlockQueue")
	var acc := _natural(14)
	var ids := func(a: Dictionary) -> Array:
		var out: Array = []
		for u in UnlockQueue.pending(a):
			out.append(str(u["id"]))
		return out
	_ok(ids.call(acc) == ["arsenal", "heroes"], "session 1 shows 2 unlocks: %s" % str(ids.call(acc)))
	_ok(UnlockQueue.is_open(acc, "arsenal") and not UnlockQueue.is_open(acc, "barracks"), "3rd system waits for the next session")
	_ok(UnlockQueue.is_open(acc, "pairs") and UnlockQueue.is_open(acc, "titan"), "in-run / hero unlocks open by level")
	UnlockQueue.ack(acc, "arsenal")
	UnlockQueue.ack(acc, "heroes")
	_ok(ids.call(acc).is_empty(), "no more this session")
	UnlockQueue.on_session_start(acc, 1000)
	_ok(not UnlockQueue.on_session_start(acc, 1100), "< 5 min away is the same session")
	UnlockQueue.on_session_start(acc, 2000)
	_ok(ids.call(acc) == ["altar", "deck"], "next session: altar, deck (tab/currency gap holds stone_cache, barracks): %s" % str(ids.call(acc)))
	(acc["progress"] as Dictionary)["level"] = 16
	UnlockQueue.on_session_start(acc, 4000)
	_ok(ids.call(acc) == ["stone_cache", "altar"], "2 levels later the currency unlock returns: %s" % str(ids.call(acc)))
	_ok(not UnlockQueue.is_open(acc, "haven"), "phase-2 unlock closed")
	var opened := UnlockQueue.opened_between(3, 4)
	_ok(opened.size() == 1 and str(opened[0]["id"]) == "arsenal", "winning L3 opens the Arsenal row")
	_ok(UnlockQueue.opened_between(4, 5).size() == 3, "winning L4: heroes + titan + pairs (L5)")


# ======================================================================== run profile, finish_run

func _test_run_profile() -> void:
	print("== run_profile")
	var keep := Meta.account
	Meta.account = _acc_at(1)
	var p := Meta.run_profile(1)
	for k in ["level", "world", "boss", "profile", "deck", "lead", "owned", "new_crate", "machines", "inrun", "hero", "army",
			"tactics", "assist", "haven_info", "codex", "auto_apex", "features", "run_id"]:
		_ok(p.has(k), "run_profile has %s" % k)
	_ok(p["deck"] == ["drone"] and str(p["lead"]) == "" and str(p["new_crate"]) == "", "fresh L1: deck [drone], no lead, no NEW crate")
	var dm: Dictionary = p["machines"]["drone"]
	_ok((dm["by_rank"] as Array).size() == 3 and dm.has("finish") and dm.has("lead") and bool(dm["live"]) and dm.has("stats") and dm.has("mods"), "machine entry: by_rank x3, finish, lead, live")
	_ok(float(p["hero"]["dmg_mult"]) == 1.0 and int(p["army"]["recruit_bonus"]) == 0 and float(p["army"]["volley_mult"]) == 1.0 and int(p["army"]["max_tier"]) == 2, "fresh hero / army neutral")
	_ok(int(p["assist"]["stacks"]) == 0 and int(p["inrun"]["crates"]) == 0, "no assist, no crates on L1")
	for k2 in ["dmg_mult", "hp_mult", "ult_rate_mult", "ult_rank", "id", "lvl", "aspect", "glory"]:
		_ok((p["hero"] as Dictionary).has(k2), "hero.%s" % k2)
	Meta.account = _acc_at(2)
	_ok(str(Meta.run_profile(2)["new_crate"]) == "ballista", "L2 profile: NEW crate ballista")
	Meta.account = _acc_at(30, "expected")
	var p30 := Meta.run_profile(30)
	_ok((p30["deck"] as Array).size() == 3 and str(p30["lead"]) != "" and int(p30["inrun"]["rank_gates"]) == 1 and bool(p30["inrun"]["pairs"]), "expected L30: 3-deck with a Lead, rank gate, pairs: %s" % str(p30["deck"]))
	var r1 := int(p30["run_id"])
	_ok(int(Meta.run_profile(30)["run_id"]) == r1 + 1, "run ids increase")
	Meta.account = keep


func _test_finish_run() -> void:
	print("== finish_run idempotence")
	var keep := Meta.account
	Meta.account = _acc_at(6)
	var prof := Meta.run_profile(6)
	var c0 := Meta.currency("coins")
	var result := {"won": true, "level": 6, "victory": 56, "coins_run": 10, "pickups": 10, "mult": 2.0, "total": 132,
			"survivors": 30, "fielded": [{"id": "drone", "rank": 3}], "run_id": prof["run_id"], "new_unlock": "mortar"}
	var b1 := Meta.finish_run(result)
	var c1 := Meta.currency("coins")
	var cache_coins := 0
	for c in b1["caches"]:
		if bool(c["inline"]):
			cache_coins += int(c["reveal"]["coins"])
	_ok(not bool(b1["duplicate"]) and c1 == c0 + 132 + cache_coins, "win credited once: +132 + cache coins %d" % cache_coins)
	_ok(Meta.level() == 7 and str(b1["new_unlock"]) == "mortar" and bool(b1["walkout"]) and Meta.owned("mortar"), "level 7, Mortar NEW with walkout")
	_ok((b1["caches"] as Array).size() == 1 and str(b1["caches"][0]["type"]) == "stone" and bool(b1["caches"][0]["inline"]), "L6 win: inline Stone Cache")
	_ok((b1["drip"] as Array).size() == 1 and absf(float(b1["drip"][0]["add"]) - 1.5) < 1e-6, "drip Common at Rank III = 1.5")
	var ids: Array = []
	for u in b1["unlocks"]:
		ids.append(str(u["id"]))
	_ok(ids.has("stone_cache"), "L6 win opens stone_cache row")
	var b2 := Meta.finish_run(result)
	_ok(bool(b2["duplicate"]) and Meta.currency("coins") == c1 and Meta.level() == 7, "same run again: duplicate, nothing credited")
	Meta._last_bundle = {}                      # app restarted: the booked id still blocks it
	var b3 := Meta.finish_run(result)
	_ok(bool(b3["duplicate"]) and Meta.currency("coins") == c1, "after a restart: still duplicate (booked ids saved)")
	var legacy := {"won": true, "level": 7, "victory": 62, "coins_run": 5, "mult": 1.5, "total": 101, "survivors": 20}
	var b4 := Meta.finish_run(legacy)
	var c4 := Meta.currency("coins")
	_ok(not bool(b4["duplicate"]) and Meta.level() == 8, "legacy result without run id books once")
	var b5 := Meta.finish_run(legacy.duplicate())
	_ok(bool(b5["duplicate"]) and Meta.currency("coins") == c4, "legacy result sent twice: duplicate")
	var prof2 := Meta.run_profile(8)
	var b6 := Meta.finish_run({"won": true, "level": 8, "victory": 68, "coins_run": 5, "mult": 1.5, "total": 110, "survivors": 20, "run_id": prof2["run_id"]})
	_ok(not bool(b6["duplicate"]) and Meta.level() == 9 and str(b6["caches"][0]["type"]) == "world" and not bool(b6["caches"][0]["inline"]), "boss L8: World Cache to the Vault")
	_ok(Meta.vault().size() == 1 and int(b6["caches"][0]["vault_index"]) == 0, "vault index reported")
	var rev := Meta.open_cache(0)
	_ok(not rev.is_empty() and bool(rev["altar"]) and (rev["cards"] as Array).size() == 5 and Meta.vault().is_empty(), "open_cache: 5 cards, vault emptied")
	_ok(Meta.open_cache(0).is_empty(), "open_cache bad index -> {}")
	Meta.account = keep


func _test_loss_flow() -> void:
	print("== loss payout, Reinforcements, loss charge")
	var keep := Meta.account
	Meta.account = _acc_at(7)
	var c0 := Meta.currency("coins")
	var b := {}
	for i in 3:
		var prof := Meta.run_profile(7)
		b = Meta.finish_run({"won": false, "level": 7, "coins_run": 20, "pickups": 20, "bridge_fraction": 0.5, "victory": 0,
				"run_id": prof["run_id"], "fielded": [{"id": "ballista", "rank": 1}]})
		if i == 0:
			_ok(int(b["coins"]["total"]) == 15 and Meta.currency("coins") == c0 + 15, "loss payout 15")
			_ok(int(b["cache_charge"]["value"]) == 1 and int(b["assist"]["stacks"]) == 1 and int(b["assist"]["soldiers"]) == 2, "charge 1/3, Reinforcements +2 soldiers")
			_ok(absf(float(b["drip"][0]["add"]) - 0.5) < 1e-6, "loss drip = 50%")
	_ok(int(b["cache_charge"]["value"]) == 3 and (b["caches"] as Array).size() == 1 and str(b["caches"][0]["type"]) == "stone", "3rd loss: a Stone Cache")
	_ok(float(Meta.account["wallet"]["cache_charge"]) == 0.0 and Meta.assist_stacks(7) == 3, "charge reset; 3 stacks")
	_ok(int(Meta.run_profile(7)["assist"]["stacks"]) == 3, "profile carries the assist")
	Meta.set_setting("reinforcements", false)
	_ok(Meta.assist_stacks(7) == 0, "Reinforcements off")
	Meta.set_setting("reinforcements", true)
	var prof2 := Meta.run_profile(7)
	Meta.finish_run({"won": true, "level": 7, "victory": 62, "coins_run": 5, "mult": 1.0, "total": 67, "survivors": 3, "run_id": prof2["run_id"]})
	_ok(Meta.assist_stacks(8) == 0 and Meta.assist_stacks(7) == 0, "a win clears Reinforcements")
	# Replay: 60%, Stone Cache only on the first 3 replays a day.
	var caches := 0
	for i2 in 4:
		var pr := Meta.run_profile(6)
		var rb := Meta.finish_run({"won": true, "level": 6, "victory": 56, "coins_run": 10, "mult": 2.0, "total": 132, "survivors": 30, "run_id": pr["run_id"]})
		if i2 == 0:
			_ok(bool(rb["replay"]) and int(rb["coins"]["total"]) == int(round(132 * 0.6)), "replay pays 60%")
		caches += (rb["caches"] as Array).size()
	_ok(caches == 3 and Meta.level() == 8, "replay Stone Caches: 3 per day; frontier unchanged")
	Meta.account = keep


# ======================================================================== save io and migration

func _test_save_io() -> void:
	print("== Save v2 io")
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var path := TMP_DIR + "/save.cfg"
	for f in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var acc := _acc_at(20, "expected")
	(acc["wallet"] as Dictionary)["coins"] = 777
	(acc["progress"]["crowns_best"] as Dictionary)[3] = 2
	Arsenal.set_deck(acc, ["laser", "drone"])
	(acc["meta"] as Dictionary)["booked"] = [5, 6]
	var legacy := {"level": 20, "coins": 777, "hero": "titan", "upgrades": {"army": 2, "power": 0}, "music": 0.4, "sfx": 0.5,
			"language": "en", "quality": "low", "vibration": false}
	_ok(Save.write_file(path, legacy, acc) == OK and FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".tmp"), "atomic write")
	(acc["wallet"] as Dictionary)["coins"] = 800
	_ok(Save.write_file(path, legacy, acc) == OK and FileAccess.file_exists(path + ".bak"), ".bak kept after the 2nd write")
	var r := Save.read_file(path)
	var cfg: ConfigFile = r["cfg"]
	_ok(cfg != null and str(r["from"]) == "main" and int(cfg.get_value("meta", "version", 0)) == 2, "read v2")
	var back := Save.account_from_cfg(cfg)
	_ok(int(back["wallet"]["coins"]) == 800 and int(back["progress"]["level"]) == 20, "round trip wallet / level")
	_ok(var_to_str(back["arsenal"]["machines"]) == var_to_str(acc["arsenal"]["machines"]), "round trip machines")
	_ok(int(back["progress"]["crowns_best"].get(3, 0)) == 2 and (back["meta"]["booked"] as Array) == [5, 6], "round trip nested dicts + extra keys")
	_ok(Array(back["arsenal"]["decks"][0]) == ["laser", "drone"], "round trip deck preset")
	_ok(str(cfg.get_value("settings", "language", "")) == "en" and int(cfg.get_value("upgrades", "army", 0)) == 2 and not back["settings"].has("language"), "legacy keys written, kept out of the account")
	# Corrupt the main file: the .bak takes over (the engine prints one expected parse error).
	print("  (expected: one ConfigFile parse error below)")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[progress\nthis is not a config = = =\n")
	f.close()
	var r2 := Save.read_file(path)
	_ok(r2["cfg"] != null and str(r2["from"]) == "bak" and int(Save.account_from_cfg(r2["cfg"])["wallet"]["coins"]) == 777, "corrupt main -> .bak")
	# Sanitize: bad types and unknown machines.
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 2)
	bad.set_value("progress", "level", "oops")
	bad.set_value("wallet", "coins", -50)
	bad.set_value("arsenal", "machines", {"ballista": {"lvl": 99, "bp": -3}, "nonsense": {"lvl": 2}})
	var s := Save.account_from_cfg(bad)
	_ok(int(s["progress"]["level"]) == 1 and int(s["wallet"]["coins"]) == 0, "bad types fall back to defaults")
	var ms: Dictionary = s["arsenal"]["machines"]
	_ok(not ms.has("nonsense") and int(ms["ballista"]["lvl"]) == 15 and int(ms["ballista"]["bp"]) == 0 and ms.has("drone") and (ms["ballista"]["talents"] as Array).size() == 3, "machines sanitised")


func _test_migration() -> void:
	print("== v1 -> v2 migration fixtures")
	var cfg1 := ConfigFile.new()
	_ok(cfg1.load(FIX + "save_v1_L1.cfg") == OK, "fixture L1 loads")
	var a1 := Save.migrate_v1(cfg1)
	_ok(int(a1["progress"]["level"]) == 1 and Arsenal.owned_ids(a1) == ["drone"] and int(a1["wallet"]["coins"]) == 0, "L1: fresh, Drone only")
	_ok(UnlockQueue.pending(a1).is_empty(), "L1: no catch-up, no card")
	var cfg9 := ConfigFile.new()
	_ok(cfg9.load(FIX + "save_v1_L9.cfg") == OK, "fixture L9 loads")
	var a9 := Save.migrate_v1(cfg9)
	_ok(int(a9["progress"]["level"]) == 9 and int(a9["progress"]["world_reached"]) == 2, "L9: level kept, world 2")
	_ok(Arsenal.owned_ids(a9) == ["drone", "ballista", "cannon", "rockets", "mortar"], "L9: crates behind the player granted: %s" % str(Arsenal.owned_ids(a9)))
	_ok(int(a9["arsenal"]["machines"]["mortar"]["lvl"]) == 2, "mortar at its Rare start level")
	_ok(int(a9["barracks"]["recruits"]) == 6 and int(a9["barracks"]["grandfathered"].get("recruits", 0)) == 2, "army 8 -> Recruits 6 (W2 cap) + 2 grandfathered")
	_ok(Barracks.effective(a9, "recruits") == 8 and int(Barracks.profile(a9)["recruit_bonus"]) == 4, "grandfathered levels count")
	var refund := Balance.upgrade_cost("power", 0) + Balance.upgrade_cost("power", 1) + Balance.upgrade_cost("power", 2)
	_ok(int(a9["wallet"]["coins"]) == 340 + refund and refund == 182, "power 3 refunded (%d)" % refund)
	_ok(int(a9["progress"]["boss_wins"]) == 1 and int(a9["wallet"]["cores"]) == 1 and int(a9["heroes"]["titan"]["boss_wins"]) == 1 and int(a9["heroes"]["titan"]["glory"]) == 2, "one boss passed: core, boss win, Glory on Titan")
	_ok(int(a9["progress"]["crowns_best"].get(8, 0)) == 1 and not a9["progress"]["crowns_best"].has(9) and int(a9["wallet"]["crowns"]) == 8, "Crown 1 on L1-8")
	var pend: Array = []
	for u in UnlockQueue.pending(a9):
		pend.append(str(u["id"]))
	_ok(pend == ["migration", "arsenal", "heroes"], "catch-up tour: card + 2 per session: %s" % str(pend))
	_ok(UnlockQueue.is_open(a9, "altar") and UnlockQueue.is_open(a9, "stone_cache"), "catch-up: systems below the level open at once")
	_ok(str(a9["progress"]["hero"]) == "titan", "hero kept")
	var cfg30 := ConfigFile.new()
	_ok(cfg30.load(FIX + "save_v1_L30.cfg") == OK, "fixture L30 loads")
	var a30 := Save.migrate_v1(cfg30)
	_ok(Arsenal.owned_ids(a30).size() == 9 and Arsenal.owned_ids(a30).has("prism"), "L30: all 9 live machines")
	_ok(int(a30["barracks"]["recruits"]) == 10 and not a30["barracks"]["grandfathered"].has("recruits"), "army 10 -> Recruits 10 (W4 cap 10)")
	_ok(int(a30["wallet"]["cores"]) == 3 and int(a30["progress"]["boss_wins"]) == 3, "3 bosses passed")
	_ok(UnlockQueue.is_open(a30, "barracks") and UnlockQueue.is_open(a30, "talents") and not UnlockQueue.is_open(a30, "haven"), "L30 catch-up: Barracks, Talents open; Haven (phase 2) closed")
	# Migrated file -> v2 write -> v2 read keeps everything.
	var path := TMP_DIR + "/migrated.cfg"
	Save.write_file(path, {"level": 30, "coins": int(a30["wallet"]["coins"]), "hero": "bolt", "upgrades": {"army": 10, "power": 0}}, a30)
	var back := Save.account_from_cfg(Save.read_file(path)["cfg"])
	_ok(Arsenal.owned_ids(back).size() == 9 and int(back["unlocks"]["migrated_level"]) == 30 and int(back["barracks"]["recruits"]) == 10, "migrated account survives a v2 round trip")
	_ok(not bool(back["meta"].get("migrated_from", 0) == 0), "migration marker saved")


func _test_telemetry() -> void:
	print("== telemetry")
	var acc := _acc_at(5)
	MetaTelemetry.attempt(acc, 5, false, 100)
	MetaTelemetry.attempt(acc, 5, true, 200)
	MetaTelemetry.attempt(acc, 6, false, 300)
	MetaTelemetry.session(acc, 420)
	MetaTelemetry.skip(acc, "inline_reveal")
	var row: Dictionary = acc["telemetry"]["levels"]["5"]
	_ok(int(row["attempts"]) == 2 and int(row["wins"]) == 1 and int(acc["telemetry"]["levels"]["6"]["quits_after_loss"]) == 1, "per-level rows + quit after a loss")
	for i in 450:
		MetaTelemetry.note(acc, "x", {}, i + 1)
	_ok((acc["telemetry"]["events"] as Array).size() == MetaTelemetry.MAX_EVENTS, "event log capped at 400")
	var js: Variant = JSON.parse_string(MetaTelemetry.export_json(acc))
	_ok(js is Dictionary and (js as Dictionary).has("telemetry") and (js as Dictionary).has("counters"), "JSON export parses")


## Save.load_data() on a v1 file (temp path, readonly lifted for the test only): migrates, writes
## v2 at once, keeps the v1 backup next to it; Meta works on Save.account by reference.
func _test_live_save() -> void:
	print("== live Save / Meta load (temp path)")
	var path := TMP_DIR + "/live.cfg"
	for f in [path, path + ".bak", TMP_DIR + "/save_v1_backup.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIX + "save_v1_L9.cfg"), ProjectSettings.globalize_path(path))
	var keep := {"path": Save.path, "account": Save.account, "level": Save.level, "coins": Save.coins, "hero": Save.hero,
			"upgrades": Save.upgrades.duplicate(), "lang": Save.language, "music": Save.music_volume, "vib": Save.vibration,
			"quality": Save.quality, "sfx": Save.sfx_volume, "meta": Meta.account, "dev": Meta.dev_profile}
	Save.readonly = false
	Save.path = path
	Save.account = {}
	Save.migrated_from = 0
	# load_data() re-reads the command line: emulate a normal launch.
	var cfg_res := Save.read_file(path)
	Save._read_legacy(cfg_res["cfg"])
	Save.account = Save.migrate_v1(cfg_res["cfg"])
	Save.migrated_from = 1
	Save.upgrades["power"] = 0
	Save._from_account()
	Save.save_data()
	var after := ConfigFile.new()
	_ok(after.load(path) == OK and int(after.get_value("meta", "version", 0)) == 2, "migrated file rewritten as v2")
	_ok(int(after.get_value("upgrades", "power", -1)) == 0 and int(after.get_value("upgrades", "army", -1)) == 8, "legacy power zeroed (refunded), army kept for the old run")
	_ok(Save.level == 9 and Save.coins == 340 + 182 and Save.hero == "titan" and Save.language == "uk", "legacy mirrors after migration")
	Meta.load_account()
	_ok(is_same(Meta.account, Save.account), "Meta works on Save.account by reference")
	_ok(Meta.level() == 9 and Meta.currency("coins") == 522 and Meta.owned("mortar") and Meta.hero() == "titan", "Meta sees the migrated account")
	var pend := Meta.pending_unlocks()
	_ok(not pend.is_empty() and str(pend[0]["id"]) == "migration", "migration card first")
	Meta.ack_unlock("migration")
	Meta.add_currency("gems", 5, "test")
	var again := Save.account_from_cfg(Save.read_file(path)["cfg"])
	_ok(int(again["wallet"]["gems"]) == 5 and (again["unlocks"]["done"] as Array).has("migration"), "Meta.save() persisted through Save")
	_ok(int(again["meta"]["rng_seed"]) != 0 and int(again["meta"]["sessions"]) >= 1, "rng seed and session saved")
	# Legacy router path: Save.level_won() + Save.add_coins() reach the account.
	Save.add_coins(10)
	Save.level_won()
	var again2 := Save.account_from_cfg(Save.read_file(path)["cfg"])
	_ok(int(again2["progress"]["level"]) == 10 and int(again2["wallet"]["coins"]) == 532 and Meta.level() == 10 and Meta.currency("coins") == 532, "legacy add_coins / level_won mirrored into the account")
	# Restore the readonly test state.
	Save.readonly = true
	Save.path = str(keep["path"])
	Save.account = keep["account"]
	Save.level = int(keep["level"])
	Save.coins = int(keep["coins"])
	Save.hero = str(keep["hero"])
	Save.upgrades = keep["upgrades"]
	Save.language = str(keep["lang"])
	Save.music_volume = float(keep["music"])
	Save.sfx_volume = float(keep["sfx"])
	Save.vibration = bool(keep["vib"])
	Save.quality = str(keep["quality"])
	Save.migrated_from = 0
	Meta.account = keep["meta"]
	Meta.dev_profile = str(keep["dev"])
