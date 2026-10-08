extends Node
## Headless unit tests of the Meta-1 core (WS1): Cache odds vs the sim (chi-square), pity caps,
## welcome Legendary, frozen counters, duplicate protection, Focus / Deck weights, Wild overflow,
## upgrade costs and curves, Arsenal Sync, final stats, run_profile shape, finish_run
## idempotence, loss payout + Reinforcements + loss charge, UnlockQueue sessions, Save io
## (atomic write, .bak fallback), the v1 -> v2 migration fixtures (levels 1, 9, 30) and Save v3
## (heroes_design.md §12.1 / §12.3): sections, sanitize + _orphans, the v2 -> v3 schema step on the
## v2 fixtures (levels 1, 9, 30, 56: every Meta-1 key kept, idempotent, round trip), the update-day
## conversion + lump grant, the v1 -> v2 -> v3 chain and a live load of a v2 file; the Heroes &
## Champions Meta API (WS-B, H1; live rules tested through EconData.phase_override): flag-off
## identity, §11.1 rows + §11.2 session placement, earned hero income, Portal / Seals / chests /
## facets / recut / skills / team through Meta, the atomic-write rollback, the two-track rule
## (earned-only randomness), machine Focus exactly 40% and the §12.5 telemetry schema.
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
	_test_save_v3()
	_test_migration_v2()
	_test_live_save_v2()
	_test_telemetry()
	_test_heroes_flag_off()
	_test_unlocks_heroes()
	_test_unlock_sessions()
	_test_hero_income()
	_test_meta_api_heroes()
	_test_grant_rollback()
	_test_two_track()
	_test_focus_exact()
	_test_hero_telemetry()
	_test_synthetic_heroes()
	EconData.phase_override = -1
	EconData.meta_phase_override = -1
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


## Binds the legacy Save mirrors to a test account. Meta.save() merges the account into Save.account
## (progress.level = max) and Meta.level() then raises Meta.account to Save.level, so while Save
## still held the real account a level left over by an earlier section silently moved the test
## account (review F2: an "L7" account read as L9 and its L7 win counted as a replay). Every test
## account installed in Meta is also Save's account (Meta.account = _bind(...)), and _unbind()
## restores the real one.
func _bind(acc: Dictionary) -> Dictionary:
	Save.account = acc
	Save.level = MetaAcc.level(acc)
	return acc


## Restores the account a section kept (Meta and the Save mirrors).
func _unbind(keep: Dictionary) -> void:
	Meta.account = keep
	_bind(keep)


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
	Meta.account = _bind(_acc_at(1))
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
	Meta.account = _bind(_acc_at(2))
	_ok(str(Meta.run_profile(2)["new_crate"]) == "ballista", "L2 profile: NEW crate ballista")
	Meta.account = _bind(_acc_at(30, "expected"))
	var p30 := Meta.run_profile(30)
	_ok((p30["deck"] as Array).size() == 3 and str(p30["lead"]) != "" and int(p30["inrun"]["rank_gates"]) == 1 and bool(p30["inrun"]["pairs"]), "expected L30: 3-deck with a Lead, rank gate, pairs: %s" % str(p30["deck"]))
	var r1 := int(p30["run_id"])
	_ok(int(Meta.run_profile(30)["run_id"]) == r1 + 1, "run ids increase")
	_unbind(keep)


func _test_finish_run() -> void:
	print("== finish_run idempotence")
	var keep := Meta.account
	Meta.account = _bind(_acc_at(6))
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
	_unbind(keep)


func _test_loss_flow() -> void:
	print("== loss payout, Reinforcements, loss charge")
	var keep := Meta.account
	Meta.account = _bind(_acc_at(7))
	_ok(Meta.level() == 7, "loss-flow account is at L7 (no leftover Save.level)")
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
	_unbind(keep)


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
	_ok(cfg != null and str(r["from"]) == "main" and int(cfg.get_value("meta", "version", 0)) == Save.VERSION, "read v%d" % Save.VERSION)
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
	_ok(after.load(path) == OK and int(after.get_value("meta", "version", 0)) == Save.VERSION, "migrated file rewritten as v%d" % Save.VERSION)
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


# ======================================================================== Save v3 (heroes_design.md §12)

const V2_FIXTURES: Array[int] = [1, 9, 30, 56]
## Keys of a v2 file that are written for the legacy menu, not kept in the account.
const V2_LEGACY := {"progress": ["coins"], "settings": ["music", "sfx", "language", "quality", "vibration"]}


func _v2_cfg(level: int) -> ConfigFile:
	var c := ConfigFile.new()
	_ok(c.load(FIX + "save_v2_L%d.cfg" % level) == OK, "fixture save_v2_L%d loads" % level)
	return c


## Every value of the v2 file is in `acc` unchanged (hero entries key by key; `superset` lists
## [section, key] arrays that may only have grown).
func _keeps_v2(cfg: ConfigFile, acc: Dictionary, what: String, superset: Array = []) -> void:
	var bad: Array[String] = []
	for sec in cfg.get_sections():
		if sec == "upgrades":
			continue
		for key in cfg.get_section_keys(sec):
			if (sec == "meta" and key == "version") or (V2_LEGACY.get(sec, []) as Array).has(key):
				continue
			var v: Variant = cfg.get_value(sec, key)
			if not (acc.get(sec, {}) as Dictionary).has(key):
				bad.append("%s.%s missing" % [sec, key])
				continue
			var now: Variant = acc[sec][key]
			if sec == "heroes" and v is Dictionary:
				for hk in (v as Dictionary):
					if var_to_str((v as Dictionary)[hk]) != var_to_str((now as Dictionary).get(hk)):
						bad.append("heroes.%s.%s" % [key, hk])
			elif [sec, key] in superset and v is Array and now is Array:
				for i in (v as Array).size():
					if i >= (now as Array).size() or var_to_str((v as Array)[i]) != var_to_str((now as Array)[i]):
						bad.append("%s.%s not a superset" % [sec, key])
						break
			elif var_to_str(v) != var_to_str(now):
				bad.append("%s.%s" % [sec, key])
	_ok(bad.is_empty(), "%s: every Meta-1 value kept %s" % [what, str(bad)])


func _test_save_v3() -> void:
	print("== Save v3 sections, sanitize, _orphans")
	_ok(Save.VERSION == 3 and SaveMigrate.VERSION == 3, "Save.VERSION = 3")
	_ok(not EconData.heroes_live(), "heroes phase flag is off in this build (2.2.1 behaviour)")
	var f := EconData.fresh_account()
	var want := ["meta", "progress", "wallet", "arsenal", "heroes", "champions", "team", "summon", "chests", "workshop",
			"barracks", "vault", "unlocks", "telemetry", "settings", "_orphans"]
	var missing: Array = []
	for k in want:
		if not f.get(k) is Dictionary:
			missing.append(k)
	_ok(missing.is_empty() and int(f["meta"]["version"]) == 3 and f["meta"].has("max_day_seen"), "fresh_account has every v3 section %s" % str(missing))
	_ok((f["heroes"] as Dictionary).keys() == ["bolt", "titan", "seer"], "an entry per starter: %s" % str(f["heroes"].keys()))
	_ok(bool(f["heroes"]["bolt"]["owned"]) and not bool(f["heroes"]["titan"]["owned"]) and not bool(f["heroes"]["seer"]["owned"]), "Rudi owned at start, Goran and Meira not yet")
	_ok(str(f["heroes"]["titan"]["gem"]) == "C" and str(f["heroes"]["bolt"]["gem"]) == "R" and str(f["heroes"]["seer"]["gem"]) == "E", "starter gems = native (Quartz, Sapphire, Amethyst)")
	_ok(str(f["heroes"]["bolt"]["aspect"]) == "forked_fox" and int(f["heroes"]["titan"]["glory"]) == 1, "Meta-1 hero keys still there")
	for c in ["beacons", "tomes", "ore", "beacon_charge", "chest_charge", "ore_charge"]:
		_ok(f["wallet"].has(c), "wallet.%s" % c)
	_ok(not f["heroes"]["bolt"].has("native"), "native is never saved")
	var born := EconData.new_hero_state("lumen")
	_ok(int(born["skills"]["awakened"]) == 1 and str(born["gem"]) == "M" and int(EconData.new_hero_state("vesta")["skills"]["awakened"]) == 1
			and int(EconData.new_hero_state("seer")["skills"]["awakened"]) == 1 and int(EconData.new_hero_state("bolt")["skills"]["awakened"]) == 0,
			"native Amethyst / Topaz / Opal born awakened (F-AWK2, H1 gate F1); Sapphire not")
	# Generated consts in sync with heroes_consts.json (skipped when python3 is missing).
	var out: Array = []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/gen_save_v3_data.py"), "--check"], out, true)
	if code == -1:
		print("  (python3 not found: generator check skipped)")
	else:
		_ok(code == 0, "save_v3_data.gd in sync with heroes_consts.json: %s" % str(out).strip_edges())
	_ok(SaveV3Data.HERO_NATIVE.size() == 10 and SaveV3Data.CHAMPION_NATIVE.size() == 12 and SaveV3Data.EXPECTED_CHAMPION_LEVEL.size() == 113, "roster 10 + 12, Champion Level table 0..112")
	# Sanitize.
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 3)
	bad.set_value("progress", "level", 40)
	bad.set_value("wallet", "beacons", -3)
	bad.set_value("wallet", "tomes", "x")
	bad.set_value("heroes", "bolt", {"lvl": 99, "gem": "C", "facets": 9, "skills": {"ult": 99, "attack": 0}, "skills_peak": {"ult": 1}})
	bad.set_value("heroes", "zorro", {"lvl": 4, "gem": "M"})
	bad.set_value("heroes", "lumen", {"owned": true, "gem": "C", "skills": {"awakened": 0}})
	bad.set_value("champions", "level", 77)
	bad.set_value("champions", "roster", {"alba": {"owned": true, "gem": "M", "facets": -1}, "ghost": {"owned": true}, "otto": 5})
	bad.set_value("team", "champions", ["alba", "ghost", "alba", "otto", "mila", "teo"])
	bad.set_value("team", "presets", [{"hero": "zorro", "champions": ["alba"]}])
	bad.set_value("team", "preset", 9)
	bad.set_value("summon", "seals", -5)
	bad.set_value("chests", "scripted", 7)
	bad.set_value("vault", "hero_chests", [{"type": "hero_chest", "source": "win", "level": 3}, {"type": "pony"}, 4])
	bad.set_value("_orphans", "heroes", {"old_one": {"lvl": 3}})
	var s := Save.account_from_cfg(bad)
	var b: Dictionary = s["heroes"]["bolt"]
	_ok(int(b["lvl"]) == 30 and str(b["gem"]) == "R" and int(b["facets"]) == 5, "hero lvl / gem (>= native) / facets clamped")
	_ok(int(b["skills"]["ult"]) == SaveMigrate.skill_cap(1, 1, 5) and int(b["skills"]["ult"]) == 5 and int(b["skills"]["attack"]) == 1 and int(b["skills"]["rally"]) == 1, "ranks clamped to the F-CAP cap (Sapphire native f5 = 5), missing keys filled")
	_ok(int(b["skills_peak"]["ult"]) >= int(b["skills"]["ult"]) and b["loadout"].has("charm") and b["got"].has("via") and bool(b["owned"]), "skills_peak >= skills, nested keys filled, Rudi owned")
	_ok(not s["heroes"].has("zorro") and s["_orphans"]["heroes"].has("zorro") and s["_orphans"]["heroes"].has("old_one"), "unknown hero -> _orphans, earlier orphans kept")
	_ok(int(s["heroes"]["lumen"]["skills"]["awakened"]) == 1 and str(s["heroes"]["lumen"]["gem"]) == "M", "Opal native: gem clamped up to native, born awakened")
	_ok(s["heroes"].has("titan") and s["heroes"].has("seer"), "missing starters re-created")
	var ch: Dictionary = s["champions"]
	_ok(int(ch["level"]) == 20 and str(ch["roster"]["alba"]["gem"]) == "L" and int(ch["roster"]["alba"]["facets"]) == 0, "Champion Level <= 20, champion gem <= Topaz, facets >= 0")
	_ok(not ch["roster"].has("ghost") and not ch["roster"].has("otto") and s["_orphans"]["champions"].has("ghost") and s["_orphans"]["champions"].has("otto"), "unknown / broken champions -> _orphans")
	_ok(Array(s["team"]["champions"]) == ["alba", "otto", "mila"] and (s["team"]["presets"] as Array).size() == 3 and str(s["team"]["presets"][0]["hero"]) == "" and int(s["team"]["preset"]) == 2, "team: known unique champions <= 3, 3 presets, preset clamped")
	_ok(int(s["wallet"]["beacons"]) == 0 and int(s["wallet"]["tomes"]) == 0 and int(s["summon"]["seals"]) == 0 and int(s["chests"]["scripted"]) == 2, "counters non-negative, scripted 0..2")
	_ok((s["vault"]["hero_chests"] as Array).size() == 1, "vault.hero_chests keeps only valid chests")
	var once := var_to_str(s)
	Save.sanitize(s)
	_ok(var_to_str(s) == once, "sanitize is idempotent")
	# v3 round trip, orphans included.
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	(s["progress"] as Dictionary)["hero"] = "bolt"     # the legacy hero key is always written
	var path := TMP_DIR + "/v3.cfg"
	Save.write_file(path, {"level": 40, "coins": 0, "hero": "bolt", "upgrades": {"army": 0, "power": 0}}, s)
	var back := Save.account_from_cfg(Save.read_file(path)["cfg"])
	var diff: Array = []
	for sec: String in s:
		if var_to_str(s[sec]) != var_to_str(back.get(sec)):
			diff.append(sec)
	_ok(diff.is_empty(), "v3 write -> read keeps every section %s" % str(diff))
	# Monotonic day guard.
	var d := EconData.fresh_account()
	_ok(SaveMigrate.see_day(d, 20 * 86400 + 5) == 20 and SaveMigrate.see_day(d, 3 * 86400) == 20 and int(d["meta"]["max_day_seen"]) == 20, "max_day_seen never moves back")


func _test_migration_v2() -> void:
	print("== v2 -> v3 migration (fixtures L1, L9, L30, L56)")
	var t := 1_800_000_000
	var grants := {}
	for lvl in V2_FIXTURES:
		var cfg := _v2_cfg(lvl)
		_ok(int(cfg.get_value("meta", "version", 0)) == 2, "L%d fixture is a v2 file" % lvl)
		var acc := Save.account_from_cfg(cfg)
		_ok(int(acc["meta"]["version"]) == 2, "L%d read keeps version 2 until migrate_v2" % lvl)
		var w0: Dictionary = (acc["wallet"] as Dictionary).duplicate(true)
		Save.migrate_v2(acc, t, 0)
		_ok(int(acc["meta"]["version"]) == 3 and int(acc["meta"]["v3_from"]["level"]) == lvl and int(acc["meta"]["v3_live"]) == 0, "L%d stamped v3, update day not yet (flag off)" % lvl)
		_keeps_v2(cfg, acc, "L%d schema step" % lvl)
		_ok(int(acc["wallet"]["beacons"]) == 0 and int(acc["wallet"]["tomes"]) == 0 and (acc["vault"]["hero_chests"] as Array).is_empty()
				and var_to_str(w0) == var_to_str(acc["wallet"]), "L%d schema step grants nothing" % lvl)
		var snap := var_to_str(acc)
		_ok(not SaveMigrate.migrate_v2(acc, t + 999, false) and var_to_str(acc) == snap, "L%d migrate_v2 twice = once" % lvl)
		var path := TMP_DIR + "/m%d.cfg" % lvl
		Save.write_file(path, {"level": lvl, "coins": int(acc["wallet"]["coins"]), "hero": str(acc["progress"]["hero"]), "upgrades": {"army": 0, "power": 0}}, acc)
		var back := Save.account_from_cfg(Save.read_file(path)["cfg"])
		Save.migrate_v2(back, t + 5, 0)
		_ok(var_to_str(back) == snap, "L%d v3 write -> read -> migrate_v2 is a no-op" % lvl)
		# Update day (the build that turns the hero systems on).
		var g := SaveMigrate.update_day(acc, t)
		grants[lvl] = g
		_ok(not g.is_empty() and int(acc["meta"]["v3_live"]) == t, "L%d update day ran" % lvl)
		_keeps_v2(cfg, acc, "L%d update day" % lvl, [["unlocks", "cards"], ["telemetry", "events"]])
		var after := var_to_str(acc)
		_ok(SaveMigrate.update_day(acc, t + 86400).is_empty() and var_to_str(acc) == after, "L%d update day runs once" % lvl)
		_ok(not SaveMigrate.migrate_v2(acc, t, true) and var_to_str(acc) == after, "L%d migrate_v2(live) after the update day changes nothing" % lvl)
		var hs: Dictionary = acc["heroes"]
		_ok(bool(hs["bolt"]["owned"]) and bool(hs["titan"]["owned"]) == (lvl > 4) and bool(hs["seer"]["owned"]) == (lvl > 5), "L%d owned: Rudi, Goran after L4, Meira after L5 (v2 rules)" % lvl)
		for id: String in hs:
			var h: Dictionary = hs[id]
			if not bool(h["owned"]):
				continue
			var n := SaveMigrate.native_index(id)
			var r2 := EconData.hero_ult_rank(int(h["lvl"]))
			_ok(str(h["gem"]) == SaveV3Data.GEMS[n] and int(h["facets"]) == 0 and int(h["frags"]) == 0, "L%d %s gem = native, facets 0" % [lvl, id])
			_ok(int(h["skills"]["ult"]) == mini(r2, SaveMigrate.skill_cap(n, n, 0)) and int(h["skills"]["attack"]) == 1 and int(h["skills"]["rally"]) == 1, "L%d %s Ult = min(Meta-1 rank %d, cap)" % [lvl, id, r2])
			var p2 := 1.0 + float(EconData.HERO["ult_rank_bonus"]) * float(r2 - 1)
			var p3 := (1.0 + SaveV3Data.ULT_RANK_STEP * float(int(h["skills"]["ult"]) - 1)) * (1.0 + SaveV3Data.LV_ULT * float(int(h["lvl"]) - 1))
			_ok(p3 >= p2 - 1e-9, "L%d %s ult power v3 %.3f >= v2 %.3f (no loss)" % [lvl, id, p3, p2])
			_ok(str(h["got"]["via"]) == ("start" if id == "bolt" else "migration"), "L%d %s via %s" % [lvl, id, h["got"]["via"]])
		_ok(str(acc["team"]["hero"]) == str(acc["progress"]["hero"]), "L%d team hero = the hero picked for runs" % lvl)
	# Fixture specifics.
	var a1: Dictionary = grants[1]
	_ok(int(a1["frontier"]) == 0 and int(a1["beacons"]) == 0 and int(a1["hero_chests"]) == 0 and int(a1["tomes_refund"]) == 0, "L1: nothing to grant")
	var g30: Dictionary = grants[30]
	_ok(int(g30["tomes_refund"]) == SaveV3Data.TOME_COST[2] and int(g30["ore_owed"]) == 10, "L30: Goran Lv15 Ult III > Quartz cap 2 -> %d Tomes; Glory 2 -> 10 Star Ore" % SaveV3Data.TOME_COST[2])
	_ok(int(g30["beacons"]) == 3 and int(g30["hero_chests"]) == 5 and int(g30["grand_hero_chests"]) == 2 and int(g30["tomes"]) == 0 and int(g30["champion_level"]) == 4, "L30 lump grant: 3 Beacons, 5 + 2 chests, Champion Lv 4: %s" % str(g30))
	var g56: Dictionary = grants[56]
	_ok(int(g56["tomes_refund"]) == SaveV3Data.TOME_COST[2] + SaveV3Data.TOME_COST[3] and int(g56["ore_owed"]) == 30, "L56: Goran Lv27 refund 2 ranks; Glory 3 + 2 -> 30 Star Ore")
	# Lump grant = heroes_sim.migrate_grant at the §8.7 rows (frontier L = next level - 1).
	var rows := {25: [2, 3, 2, 0, 3], 41: [10, 8, 4, 2, 5], 57: [17, 14, 6, 4, 6], 113: [42, 20, 13, 11, 13], 15: [0, 0, 0, 0, 1]}
	for nl: int in rows:
		var e: Array = rows[nl]
		var lg := SaveMigrate.lump_grant(nl, ArsenalData.world_of(mini(nl, ArsenalData.CAMPAIGN_LEVELS)))
		_ok([int(lg["beacons"]), int(lg["hero_chests"]), int(lg["grand_hero_chests"]), int(lg["tomes"]), int(lg["champion_level"])] == e,
				"lump grant at frontier %d = %s (got %s)" % [nl - 1, str(e), str([lg["beacons"], lg["hero_chests"], lg["grand_hero_chests"], lg["tomes"], lg["champion_level"]])])
	_ok(SaveMigrate.lump_grant(25, 1)["champion_level"] == 3 and SaveMigrate.lump_grant(41, 1)["champion_level"] == 4, "Champion Level capped at 2 + 2 x world")
	# Meira: a Seer an existing player owns is never taken away.
	var own := EconData.fresh_account()
	own["progress"]["level"] = 3
	own["heroes"]["seer"]["owned"] = true
	own["heroes"]["seer"]["got"] = {"t": 5, "via": "portal"}
	SaveMigrate.update_day(own, t)
	_ok(bool(own["heroes"]["seer"]["owned"]) and str(own["heroes"]["seer"]["got"]["via"]) == "portal", "an owned Seer stays owned (and keeps how she came)")
	var at5 := EconData.fresh_account()
	at5["progress"]["level"] = 5
	SaveMigrate.update_day(at5, t)
	_ok(bool(at5["heroes"]["titan"]["owned"]) and not bool(at5["heroes"]["seer"]["owned"]), "before the L5 win: Goran owned, Meira not (guest at L5, joins at L24)")
	var at6 := EconData.fresh_account()
	at6["progress"]["level"] = 6
	(at6["heroes"] as Dictionary).erase("seer")
	SaveMigrate.update_day(at6, t)
	_ok(bool(at6["heroes"]["seer"]["owned"]) and str(at6["heroes"]["seer"]["got"]["via"]) == "migration", "v2 player past the L5 win keeps Meira (no entry needed)")
	# Card + vault + telemetry.
	var a9 := Save.account_from_cfg(_v2_cfg(30))
	Save.migrate_v2(a9, t, 1)
	_ok((a9["unlocks"]["cards"] as Array).has(SaveMigrate.CARD) and int(a9["unlocks"]["heroes_migrated_level"]) == 30, "one-time heroes card queued, catch-up level recorded")
	_ok((a9["vault"]["hero_chests"] as Array).size() == 7 and (a9["vault"]["caches"] as Array).size() == 2, "7 Hero Chests in vault.hero_chests; Meta-1 Caches untouched")
	_ok(int(a9["wallet"]["beacons"]) == 3 and int(a9["wallet"]["tomes"]) == 3 and int(a9["champions"]["level"]) == 4 and int(a9["workshop"]["migration_ore"]) == 10, "wallet / Champion Level / owed ore credited")
	var ev: Array = a9["telemetry"]["events"]
	_ok(not ev.is_empty() and str(ev[-1]["e"]) == "migration" and int(ev[-1]["d"]["from_level"]) == 29, "telemetry migration {from_level, grant}")
	# v1 -> v2 -> v3 chain.
	print("== v1 -> v2 -> v3 chain")
	for lvl1 in [1, 9, 30]:
		var c1 := ConfigFile.new()
		c1.load(FIX + "save_v1_L%d.cfg" % lvl1)
		var v2 := Save.migrate_v1(c1)
		var v2_snap := var_to_str(v2["arsenal"]) + var_to_str(v2["barracks"]) + var_to_str(v2["progress"])
		Save.migrate_v2(v2, t, 1)
		_ok(int(v2["meta"]["version"]) == 3 and int(v2["meta"]["migrated_from"]) == 1 and var_to_str(v2["arsenal"]) + var_to_str(v2["barracks"]) + var_to_str(v2["progress"]) == v2_snap, "v1 L%d -> v3: machines, Barracks, progress kept" % lvl1)
		var hs1: Dictionary = v2["heroes"]
		_ok(bool(hs1["titan"]["owned"]) == (lvl1 > 4) and bool(hs1["seer"]["owned"]) == (lvl1 > 5), "v1 L%d -> v3: starters owned by the v2 rules" % lvl1)
		if lvl1 == 9:
			_ok(int(v2["workshop"]["migration_ore"]) == 10 and str(v2["progress"]["hero"]) == "titan" and str(v2["team"]["hero"]) == "titan", "v1 L9: Titan's Glory 2 -> 10 Star Ore owed, Titan leads")
		var p := TMP_DIR + "/chain%d.cfg" % lvl1
		Save.write_file(p, {"level": lvl1, "coins": int(v2["wallet"]["coins"]), "hero": str(v2["progress"]["hero"]), "upgrades": {"army": 0, "power": 0}}, v2)
		var rb := Save.account_from_cfg(Save.read_file(p)["cfg"])
		Save.migrate_v2(rb, t, 1)
		_ok(var_to_str(rb) == var_to_str(v2), "v1 L%d chain survives a v3 round trip unchanged" % lvl1)


## Save.load_from_disk() on a v2 file (temp path, readonly lifted for the test only): rewritten as
## v3 at once, v2 backup kept, every Meta-1 value and the legacy mirrors unchanged, nothing granted
## while the flag is off; a second load is a no-op.
func _test_live_save_v2() -> void:
	print("== live Save load of a v2 file (temp path)")
	var path := TMP_DIR + "/live_v2.cfg"
	var bk := TMP_DIR + "/save_v2_backup.cfg"
	for f in [path, path + ".bak", bk]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIX + "save_v2_L30.cfg"), ProjectSettings.globalize_path(path))
	var keep := {"path": Save.path, "account": Save.account, "level": Save.level, "coins": Save.coins, "hero": Save.hero,
			"upgrades": Save.upgrades.duplicate(), "lang": Save.language, "music": Save.music_volume, "vib": Save.vibration,
			"quality": Save.quality, "sfx": Save.sfx_volume, "meta": Meta.account, "dev": Meta.dev_profile}
	Save.readonly = false
	Save.path = path
	Save.account = {}
	Save.migrated_from = 0
	Save.load_from_disk(0)
	var after := ConfigFile.new()
	_ok(after.load(path) == OK and int(after.get_value("meta", "version", 0)) == 3 and Save.migrated_from == 2, "v2 file rewritten as v3 on load")
	_ok(FileAccess.file_exists(bk) and int(_cfg_at(bk).get_value("meta", "version", 0)) == 2, "save_v2_backup.cfg kept")
	_ok(Save.level == 30 and Save.coins == 2210 and Save.hero == "seer" and Save.language == "uk", "legacy mirrors unchanged")
	_keeps_v2(_v2_cfg(30), Save.account, "live load")
	_ok(int(Save.account["wallet"]["beacons"]) == 0 and int(Save.account["meta"]["v3_live"]) == 0, "flag off: no update day, no grant")
	Meta.load_account()
	_ok(Meta.level() == 30 and Meta.currency("coins") == 2210 and Meta.hero() == "seer" and Meta.owned("prism") and Meta.hero_level("titan") == 15 and Meta.hero_level("seer") == 12, "Meta sees the same account (coins, machines, heroes)")
	var once := FileAccess.get_file_as_string(bk)
	Save.account = {}
	Save.migrated_from = 0
	Save.load_from_disk(0)
	_ok(Save.migrated_from == 0 and FileAccess.get_file_as_string(bk) == once, "second load: plain v3 read, backup untouched")
	# The build that turns the heroes on: the update day runs once on load and is saved.
	Save.account = {}
	Save.load_from_disk(1)
	var live := Save.account_from_cfg(Save.read_file(path)["cfg"])
	_ok(int(live["meta"]["v3_live"]) > 0 and int(live["wallet"]["beacons"]) == 3 and bool(live["heroes"]["seer"]["owned"]), "live load: update day ran and was saved")
	var live_snap := var_to_str(live["wallet"]) + var_to_str(live["heroes"])
	Save.account = {}
	Save.load_from_disk(1)
	var again := Save.account_from_cfg(Save.read_file(path)["cfg"])
	_ok(var_to_str(again["wallet"]) + var_to_str(again["heroes"]) == live_snap, "live load twice grants once")
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


func _cfg_at(p: String) -> ConfigFile:
	var c := ConfigFile.new()
	c.load(p)
	return c


# ======================================================================== Heroes & Champions: Meta API, unlocks, income (WS-B, H1)

## Turns the live hero systems on for a test (EconData.phase_override; -1 restores the shipped flag).
func _live(on: bool, phase := EconData.HEROES_LIVE_PHASE) -> void:
	EconData.phase_override = phase if on else -1


## A synthetic account at `level` with the hero sections of the live phase (every hero entry, all
## level-open rows acknowledged, Rudi as the team hero).
func _hacc(level: int, kind := "fresh") -> Dictionary:
	var acc := Meta.synthetic_account(level, kind)
	(acc["team"] as Dictionary)["hero"] = "bolt"
	(acc["meta"] as Dictionary)["rng_seed"] = 77
	return acc


## The result Meta.finish_run would book for a plain win / loss of `lvl`.
func _res(lvl: int, won := true, extra := {}) -> Dictionary:
	var r := {"won": won, "level": lvl, "victory": EconData.victory_coins(lvl, 20) if won else 0, "pickups": 10,
			"coins_run": 10, "mult": 1.5, "survivors": 20, "bridge_fraction": 0.5}
	r.merge(extra, true)
	return r


## Flag off (this build): every hero row, income, mutation and touch point behaves as 2.2.1.
func _test_heroes_flag_off() -> void:
	print("== heroes phase off: 2.2.1 behaviour")
	_live(false)
	var ids: Array = []
	for u in EconData.unlocks():
		ids.append(str(u["id"]))
	var base: Array = []
	for u2: Dictionary in EconData.UNLOCKS:
		base.append(str(u2["id"]))
	_ok(ids == base and EconData.unlock_entry("champions").is_empty() and int(EconData.unlock_entry("seer")["after_win"]) == 5,
			"unlock rows = the 2.2.1 table (Seer after L5, no hero rows)")
	_ok(EconData.hero_unlock_at("seer") == 5 and EconData.hero_unlock_at("titan") == 4 and EconData.seer_guest_level() == 0
			and EconData.hero_unlock_at("vesta") == -1, "hero unlock levels as 2.2.1, no guest level")
	_ok(EconData.stats_keys() == EconData.STATS_KEYS, "stats keys unchanged")
	_ok(EconData.road_node("premium", "gems", 20, 30) == {"cur": "gems", "n": 20}, "paid Road lane unchanged while off")
	var keep := Meta.account
	Meta.account = _bind(_hacc(25))
	(Meta.account["wallet"] as Dictionary)["beacons"] = 50
	var snap := var_to_str(Meta.account)
	var refusals := [Meta.summon(1), Meta.summon(10, true), Meta.seal_pick("vesta"), Meta.add_facet("hero", "bolt"),
			Meta.recut("hero", "bolt"), Meta.rank_skill("bolt", "ult"), Meta.level_champions(), Meta.open_hero_chest(0)]
	var all_phase := true
	for r in refusals:
		all_phase = all_phase and str((r as Dictionary).get("reason", "")) == "phase"
	_ok(all_phase and not Meta.set_team("bolt", []) and not Meta.set_portal_focus("C", "arin") and var_to_str(Meta.account) == snap,
			"every hero mutation refuses with reason phase and changes nothing")
	_ok(Meta.hero_mission_done().is_empty() and Meta.hero_weekly_done().is_empty() and var_to_str(Meta.account) == snap, "no hero income while off")
	var p := Meta.run_profile(25)
	_ok(not p.has("team") and not p.has("guest") and p["hero"] == HeroesMeta.profile(Meta.account, Meta.hero()), "run_profile: 2.2.1 hero block, no team / guest")
	var b := Meta.finish_run(_res(25, true, {"run_id": p["run_id"]}))
	_ok(not b.has("hero_chests") and not b.has("beacons") and not b.has("hero_joined") and int(Meta.account["wallet"]["beacons"]) == 50
			and float(Meta.account["wallet"]["chest_charge"]) == 0.0, "finish_run: no hero keys, no Beacons, no chest charge")
	_unbind(keep)
	# The heroes card / pending rows never appear while off.
	var acc := _natural(30)
	var pend: Array = []
	for u3 in UnlockQueue.pending(acc):
		pend.append(str(u3["id"]))
	_ok(not pend.has("champions") and not pend.has("portal") and not UnlockQueue.opened_between(13, 25).any(func(r: Dictionary) -> bool: return str(r["id"]) in ["champions", "portal", "seer_guest"]),
			"no hero unlock lines or result rows")


## §11.1 rows, Seer 5 -> 24 + guest level, free first steps, the update-day card and catch-up.
func _test_unlocks_heroes() -> void:
	print("== heroes unlock rows (live phase)")
	_live(true)
	var order: Array = []
	for u in EconData.unlocks():
		order.append(str(u["id"]))
	_ok(order.has("champions") and order.has("portal") and order.has("skills") and order.has("slot3") and order.has("seer_guest")
			and not order.has("workshop"), "§11.1 rows join; the Workshop row waits for its phase (H4)")
	_ok(order.find("talents") < order.find("champions") and order.find("champions") < order.find("haven")
			and order.find("dailies") < order.find("portal") and order.find("portal") < order.find("seer")
			and order.find("seer") < order.find("rift_anvil") and order.find("tactics") < order.find("skills"), "rows in level order: %s" % str(order))
	_ok(int(EconData.unlock_entry("seer")["after_win"]) == SaveV3Data.UNLOCK_AT["seer"] and EconData.hero_unlock_at("seer") == 24
			and EconData.seer_guest_level() == 5, "Seer joins after the World 3 boss (L24), guest at L5")
	_ok(EconData.stats_keys().size() == EconData.STATS_KEYS.size() + EconData.STATS_KEYS_HEROES.size(), "hero stats keys appended")
	var won14 := UnlockQueue.opened_between(14, 15)
	_ok(won14.any(func(r: Dictionary) -> bool: return str(r["id"]) == "champions" and str(r["free"]) == "first_champion"), "winning L14 opens the champions row")
	_ok(UnlockQueue.opened_between(24, 25).any(func(r: Dictionary) -> bool: return str(r["id"]) == "seer")
			and not UnlockQueue.opened_between(5, 6).any(func(r: Dictionary) -> bool: return str(r["id"]) == "seer"), "the Seer row opens at the L24 win, not L5")
	_live(true, EconData.HEROES_WORKSHOP_PHASE)
	_ok(not EconData.unlock_entry("workshop").is_empty() and int(EconData.unlock_entry("workshop")["after_win"]) == 32, "Workshop row from its phase")
	_live(true)
	# Free first steps.
	var a := _natural(31)
	UnlockQueue.ack(a, "skills")
	_ok(bool(MetaAcc.free_steps(a).get("skill_rank", false)), "skills: one free Ult rank on the team hero")
	var b := _natural(15)
	(b["chests"] as Dictionary)["unlock_gift"] = false      # a player whose unlock win granted no gift
	UnlockQueue.ack(b, "champions")
	var gift := Vault.hero_chests(b)
	_ok(gift.size() == 1 and str(gift[0]["source"]) == "unlock" and bool(b["chests"]["unlock_gift"]), "champions (no gift yet): the gift chest waits in the Vault")
	UnlockQueue.ack(b, "champions")
	_ok(Vault.hero_chests(b).size() == 1, "the gift is granted once")
	# Migrated v2 player: every passed row open on update day, lines still paced, heroes card first.
	var m := Save.account_from_cfg(_v2_cfg(30))
	Save.migrate_v2(m, 1_800_000_000, 1)
	(m["meta"] as Dictionary)["last_session"] = 0
	UnlockQueue.on_session_start(m, 1_800_000_100)
	_ok(UnlockQueue.is_open(m, "champions") and UnlockQueue.is_open(m, "portal") and not UnlockQueue.is_open(m, "skills"),
			"update day at L30: champions + Portal open at once, skills (after L30) not yet")
	var pend := UnlockQueue.pending(m)
	_ok(not pend.is_empty() and str(pend[0]["id"]) == UnlockQueue.MIGRATION_HEROES_ID and str(pend[0]["line"]) == SaveMigrate.CARD
			and int((pend[0]["grant"] as Dictionary).get("beacons", -1)) == 3, "the update-day card comes first with its grant")
	UnlockQueue.ack(m, UnlockQueue.MIGRATION_HEROES_ID)
	_ok(int(m["unlocks"]["session_count"]) == 0 and not UnlockQueue.pending(m).any(func(r: Dictionary) -> bool: return str(r["id"]) == UnlockQueue.MIGRATION_HEROES_ID),
			"the card takes no session slot and shows once")
	_live(false)


## §11.2 session placement (≤ 2 new systems per session; the queue holds overflow), every phase on.
func _test_unlock_sessions() -> void:
	print("== session placement §11.2 (all content phases on)")
	_live(true, EconData.HEROES_WORKSHOP_PHASE)
	EconData.meta_phase_override = 3
	var reg := _sessions(4, 32)
	var cas := _sessions(2, 32)
	var want_reg := {4: ["talents", "champions"], 5: ["haven", "dailies"], 6: ["portal", "rift_anvil"], 7: ["tactics", "shop"],
			8: ["skills", "workshop"]}
	for s: int in want_reg:
		_ok(reg[s - 1] == want_reg[s], "regular S%d = %s (got %s)" % [s, str(want_reg[s]), str(reg[s - 1])])
	var want_cas := {7: ["talents", "champions"], 8: ["haven"], 9: ["dailies"], 10: ["portal"], 12: ["rift_anvil"], 13: ["tactics"],
			14: ["shop"], 15: ["skills"], 16: ["workshop"]}
	for s2: int in want_cas:
		_ok(cas[s2 - 1] == want_cas[s2], "casual S%d = %s (got %s)" % [s2, str(want_cas[s2]), str(cas[s2 - 1])])
	var most := 0
	for row: Array in reg + cas:
		most = maxi(most, row.size())
	_ok(most <= int(EconData.UNLOCK_RULES["per_session"]), "never more than %d new systems in a session" % int(EconData.UNLOCK_RULES["per_session"]))
	EconData.meta_phase_override = -1
	_live(false)


## Lines shown per session for a player who wins `per` levels a session up to `to` (the hub shows
## pending lines at the session start and after every win).
func _sessions(per: int, to: int) -> Array:
	var acc := EconData.fresh_account()
	var out: Array = []
	var t := 1000
	var lvl := 1
	while lvl <= to:
		t += 10000
		UnlockQueue.on_session_start(acc, t)
		var shown: Array = []
		_show_pending(acc, shown)
		for i in per:
			if lvl > to:
				break
			(acc["progress"] as Dictionary)["level"] = lvl + 1
			(acc["progress"] as Dictionary)["world_reached"] = ArsenalData.world_of(lvl + 1)
			_show_pending(acc, shown)
			lvl += 1
		out.append(shown)
	return out


func _show_pending(acc: Dictionary, shown: Array) -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var p := UnlockQueue.pending(acc)
		if p.is_empty():
			return
		var id := str(p[0]["id"])
		UnlockQueue.ack(acc, id)
		if str(p[0].get("kind", "")) != "card":
			shown.append(id)


## Earned hero income through Rewards.level_end (live phase): starters by progress, Beacons, Tomes,
## Hero Chests, the gift + scripted chests, one inline reveal, replays, the guest level.
func _test_hero_income() -> void:
	print("== hero income in Rewards (live phase)")
	_live(true)
	var keep := Meta.account
	Meta.account = _bind(_hacc(1))
	Meta._last_bundle = {}
	(Meta.account["unlocks"] as Dictionary)["done"] = []
	var joined := {}
	var inline_max := 0
	var gift_rev := {}
	var second := {}
	var tomes_boss := 0
	var chests_seen := 0
	var grand_seen := 0
	for lvl in range(1, 41):
		UnlockQueue.on_session_start(Meta.account, 100000 + lvl * 1000)      # one session per level
		var p := Meta.run_profile(lvl)
		if lvl == 5:
			_ok(str(p["hero"]["id"]) == "seer" and bool(p["hero"]["guest"]) and int(p["hero"]["lvl"]) == 5 and str(p["guest"]) == "seer"
					and (p["team"]["champions"] as Array).is_empty() and Meta.run_hero(5) == "seer", "L5: Meira leads as a guest at Lv5, no team")
		var b := Meta.finish_run(_res(lvl, true, {"run_id": p["run_id"]}))
		if lvl == 5:
			var gl: Dictionary = b.get("guest", {})
			_ok(str(gl.get("line", "")) == "GUEST_SEER_RETURN" and gl.get("args", []) == [3]
					and Loc.f("GUEST_SEER_RETURN", gl["args"]).contains("3"), "L5 result: the guest line carries its world number (review F10)")
		for pu in Meta.pending_unlocks():
			Meta.ack_unlock(str(pu["id"]))
		for j in b.get("hero_joined", []):
			joined[str(j["id"])] = lvl
		var inl := 0
		for c in b["caches"]:
			inl += 1 if bool(c["inline"]) else 0
		for hc in b.get("hero_chests", []):
			var hd: Dictionary = hc
			inl += 1 if bool(hd["inline"]) else 0
			chests_seen += 1
			grand_seen += 1 if str(hd["type"]) == Vault.GRAND else 0
			if str(hd["source"]) == "unlock":
				gift_rev = hd
			elif int(hd.get("scripted", 0)) == 2:
				second = hd
		inline_max = maxi(inline_max, inl)
		tomes_boss += int((b.get("tomes", {}) as Dictionary).get("add", 0))
		if lvl == 5:
			_ok(str((b.get("guest", {}) as Dictionary).get("line", "")) == "GUEST_SEER_RETURN" and not Roster.owned(Meta.account, "seer"),
					"after the guest level: her line, and she is not owned")
		if lvl == 14:
			_ok(not gift_rev.is_empty() and bool(gift_rev["inline"]) and int(gift_rev["scripted"]) == 1
					and str(gift_rev["reveal"]["cards"][0]["id"]) == "alba" and Team.champions(Meta.account) == ["alba"],
					"L14 win: the gift chest opens inline as scripted chest #1 (Alba with Rudi) and takes slot 1: %s" % str(gift_rev.get("reveal", {}).get("cards", [])))
	_ok(joined.get("titan", 0) == 4 and joined.get("seer", 0) == 24, "Goran joins after L4, Meira after L24 (via progress): %s" % str(joined))
	_ok(str(Meta.account["heroes"]["seer"]["got"]["via"]) == "progress", "Meira's copy is a progress copy")
	_ok(inline_max <= 1, "at most one inline reveal per result screen")
	_ok(not second.is_empty() and str((second["reveal"]["cards"] as Array).filter(func(c: Dictionary) -> bool: return bool(c["scripted"]))[0]["id"]) == "mila"
			and Team.champions(Meta.account).has("mila"), "the next chest is scripted #2 (Mila) and takes slot 2")
	# Income = what the content would have paid (the update-day lump grant is the same rule).
	var lg := SaveMigrate.lump_grant(41, 5)
	var w: Dictionary = Meta.account["wallet"]
	_ok(MetaAcc.amount(Meta.account, "beacons") == int(lg["beacons"]) and float(w["beacon_charge"]) < 1e-6,
			"Beacons after L40 = 0.2 x first clears past L20 + 2 x bosses past L20 = %d (got %d + %.2f)" % [int(lg["beacons"]), MetaAcc.amount(Meta.account, "beacons"), float(w["beacon_charge"])])
	_ok(grand_seen == int(lg["grand_hero_chests"]) and chests_seen == 1 + int(lg["hero_chests"]) + int(lg["grand_hero_chests"]),
			"chests: gift + every 3rd win past L14 (%d) + a Grand per boss past L14 (%d); got %d (%d Grand)" % [int(lg["hero_chests"]), int(lg["grand_hero_chests"]), chests_seen, grand_seen])
	_ok(tomes_boss == int(lg["tomes"]) and tomes_boss == 2, "boss Tomes after the skills unlock (L32, L40) = %d" % tomes_boss)
	# Replays: chest charge only on the first CHEST_REPLAYS_PER_DAY replay wins a day; no Beacons.
	var b0 := MetaAcc.amount(Meta.account, "beacons")
	var c0 := float(w["chest_charge"])
	var day := 1_900_000_000
	var charged := 0
	for i in 5:
		var rb := Rewards.level_end(Meta.account, _res(20, true, {"run_id": 900 + i}), Meta._rng, day)
		var cc := float(Meta.account["wallet"]["chest_charge"])
		charged += 1 if (cc != c0 or not (rb["hero_chests"] as Array).is_empty()) else 0
		c0 = cc
	_ok(charged == PortalData.CHEST_REPLAYS_PER_DAY and MetaAcc.amount(Meta.account, "beacons") == b0, "replays: chest charge on the first 3 a day, never Beacons (%d charged)" % charged)
	# A loss pays no hero income.
	var before := var_to_str(Meta.account["wallet"])
	var lb := Rewards.level_end(Meta.account, _res(41, false, {"run_id": 990}), Meta._rng, day)
	var wl: Dictionary = Meta.account["wallet"]
	_ok((lb["hero_chests"] as Array).is_empty() and int(lb["beacons"]["add"]) == 0 and int(wl["beacons"]) == int(str_to_var(before)["beacons"]), "a loss: no chests, no Beacons")
	# Daily / weekly / Expedition / login income.
	var bw := MetaAcc.amount(Meta.account, "beacons")
	var tw := MetaAcc.amount(Meta.account, "tomes")
	var vw := Vault.hero_chests(Meta.account).size()
	for i2 in 3:
		Meta.hero_mission_done()
	_ok(MetaAcc.amount(Meta.account, "beacons") == bw + 1, "3 daily missions = 1 Beacon")
	Meta.hero_weekly_done()
	_ok(MetaAcc.amount(Meta.account, "beacons") == bw + 1 + int(PortalData.BEACON["weekly"]) and MetaAcc.amount(Meta.account, "tomes") == tw + PortalData.TOMES_WEEKLY
			and Vault.hero_chests(Meta.account).size() == vw + 1, "weekly 5/5: +4 Beacons, +2 Tomes, a Grand Hero Chest")
	var e5 := Meta.hero_expedition(5)
	var e3 := Meta.hero_expedition(3)
	var e2 := Meta.hero_expedition(2)
	_ok(int(e5["beacons"]) == 3 and int(e5["tomes"]) == 2 and int(e5["vault_index"]) >= 0 and int(e3["beacons"]) == 1 and int(e3["vault_index"]) == -1
			and int(e2["beacons"]) == 0, "Expedition 5/5: 1 + 2 Beacons, Tomes, Grand; 3/5: 1 Beacon; 2/5: nothing")
	_ok(int(Meta.hero_login(7)["beacons"]) == 1 and int(Meta.hero_login(6)["beacons"]) == 0, "login day-7 card: +1 Beacon")
	var early := _hacc(10)
	_ok(Rewards.hero_weekly_done(early)["beacons"] == 0 and Rewards.hero_weekly_done(early)["vault_index"] == -1 and Rewards.hero_mission_done(early)["beacons"] == 0,
			"before the Portal / champions unlock: no Beacons, no Grand chest")
	# Open a Vault chest through the Meta API.
	var n0 := Vault.hero_chests(Meta.account).size()
	var rev := Meta.open_hero_chest(0)
	_ok(bool(rev.get("ok", false)) and Vault.hero_chests(Meta.account).size() == n0 - 1 and (rev["cards"] as Array).size() >= 2, "Meta.open_hero_chest opens and removes the chest")
	_ok(Meta.open_hero_chest(99).is_empty(), "bad index -> {}")
	_unbind(keep)
	_live(false)


## The Meta API over the rule classes (live phase): Portal, Seals, facets, recut, skills, team,
## champions, cards; results saved before they return.
func _test_meta_api_heroes() -> void:
	print("== Meta API: heroes, champions, team, Portal (live phase)")
	_live(true)
	var keep := Meta.account
	Meta.account = _bind(_hacc(25))
	var acc := Meta.account
	Roster.grant(acc, "titan", "progress")
	var po := Meta.portal()
	_ok(bool(po["open"]) and bool(po["welcome_ready"]) and int(po["e_left"]) == 10 and int(po["l_left"]) == 30, "portal(): open, welcome ready, pity 10 / 30")
	(acc["wallet"] as Dictionary)["beacons"] = 5
	_ok(str(Meta.summon(1).get("reason", "")) == "welcome_first" and MetaAcc.amount(acc, "beacons") == 5,
			"Beacon summons wait for the welcome x10 (review F4)")
	(acc["wallet"] as Dictionary)["beacons"] = 0
	(acc["wallet"] as Dictionary)["gems"] = 99999
	(acc["wallet"] as Dictionary)["coins"] = 999999
	var wb := Meta.welcome_summon()
	var lplus := (wb["items"] as Array).any(func(it: Dictionary) -> bool: return Ladder.gem_index(str(it["gem"])) >= 3)
	_ok(bool(wb["ok"]) and (wb["items"] as Array).size() == 10 and lplus and int(wb["seals"]["after"]) == 10 and int(wb["beacons"]) == 0,
			"welcome x10: free, 10 heroes, at least one Topaz+, +10 Seals")
	_ok(str(Meta.welcome_summon().get("reason", "")) == "welcome" and not bool(Meta.portal()["welcome_ready"]), "the welcome x10 is used once")
	_ok(str(Meta.summon(1).get("reason", "")) == "beacons", "no Beacons: summon refused")
	_ok(str(Meta.summon(1).get("reason", "")) == "beacons", "Gems and coins never pay a summon")
	(acc["wallet"] as Dictionary)["beacons"] = 11
	var s1 := Meta.summon(1)
	_ok(bool(s1["ok"]) and int(s1["beacons_after"]) == 10 and int(s1["seals"]["after"]) == 11 and s1.has("pity") and s1.has("history_id"), "x1: 1 Beacon, +1 Seal, bundle shape")
	var s10 := Meta.summon(10)
	_ok(bool(s10["ok"]) and MetaAcc.amount(acc, "beacons") == 0 and Meta.summon_history().size() == 21, "x10: 10 Beacons, history 21 rows")
	_ok(str(Meta.summon(3).get("reason", "")) in ["count", "beacons"], "only x1 / x10")
	# Seal shop.
	var shop := Meta.seal_shop()
	_ok(not shop.is_empty() and shop.all(func(o: Dictionary) -> bool: return int(o["price"]) in [40, 100, 200]), "Seal shop: Amethyst 40 / Topaz 100 / Opal 200")
	(acc["summon"] as Dictionary)["seals"] = 100
	var vesta_owned := Roster.owned(acc, "vesta")
	var sp := Meta.seal_pick("vesta")
	_ok(bool(sp["ok"]) and int(sp["seals"]["after"]) == 0 and Roster.owned(acc, "vesta") and bool(sp["new"]) == not vesta_owned, "Seal pick: Vesta for 100 Seals")
	_ok(str(Meta.seal_pick("arin").get("reason", "")) == "hero", "Quartz heroes are not for Seals")
	# Cards.
	var hc := Meta.hero_card("bolt")
	for k in ["id", "kind", "owned", "native", "gem", "recut", "facets", "frags", "frags_need", "can_facet", "can_recut", "recut_to",
			"lvl", "own_lvl", "cap", "synced", "class", "element", "faction", "skills", "power", "badge", "in_team", "name", "title"]:
		_ok(hc.has(k), "hero_card.%s" % k)
	_ok((hc["skills"] as Dictionary).has_all(["ult", "attack", "rally", "awakened"]) and int(hc["skills"]["ult"]["native_max"]) >= int(hc["skills"]["ult"]["cap"]),
			"hero_card skills with caps and the native ceiling")
	var vc := Meta.hero_card("vesta")
	_ok(bool(vc["skills"]["awakened"]["open"]) and bool(vc["skills"]["awakened"]["born"]), "a native Topaz is born awakened")
	_ok(Roster.owned(acc, "pava") or not (Meta.hero_card("pava")["sources"] as Array).is_empty(), "unowned hero card lists its sources")
	var cc := Meta.champion_card("alba")
	_ok(cc.has_all(["action", "aura", "hp", "level", "slot", "class", "role"]) and int(cc["action"]["tier"]) == 2, "champion_card: Action tier II for a native Sapphire")
	_ok(Meta.hero_ids("owned").has("bolt") and Array(Meta.hero_ids("native:M")) == ["lumen", "pava"] and Array(Meta.champion_ids("class:guardian")) == ["ivo", "otto", "nimb"],
			"hero_ids / champion_ids filters")
	# Facets and recut through the API (fragments only, never coins).
	var coins0 := MetaAcc.amount(acc, "coins")
	Roster.ensure(acc, "bolt")["frags"] = 200
	var ff := Meta.fill_facets("hero", "bolt")
	_ok(bool(ff["ok"]) and int(ff["facets"]) == 5 and bool(ff["full"]), "fill_facets: 5 facets from banked fragments")
	var rc := Meta.recut_cost("hero", "bolt")
	_ok(bool(rc["can"]) and str(rc["to_gem"]) == "E" and int(rc["coins"]) == 0, "recut cost: to Amethyst, no coins")
	var ru := Meta.recut("hero", "bolt")
	_ok(bool(ru["ok"]) and str(Roster.gem(acc, "bolt")) == "E" and Roster.facets(acc, "bolt") == 0 and MetaAcc.amount(acc, "coins") == coins0,
			"recut Rudi to Amethyst; facets restart; coins untouched")
	_ok(str(Meta.add_facet("champion", "bolt").get("reason", "")) == "kind", "kind is checked")
	# Skills: Tomes only, the free first Ult rank on the team hero.
	MetaAcc.free_steps(acc)["skill_rank"] = true
	(acc["progress"] as Dictionary)["level"] = 31
	UnlockQueue.mark_all_done(acc)
	var sc := Meta.skill_cost("bolt", "ult")
	_ok(bool(sc["free"]) and int(sc["tomes"]) == 0 and int(sc["coins"]) == 0, "first Ult rank on the team hero is free")
	var rk := Meta.rank_skill("bolt", "ult")
	_ok(bool(rk["ok"]) and int(rk["rank"]) == 2 and not bool(MetaAcc.free_steps(acc).get("skill_rank", false)), "free rank used")
	_ok(str(Meta.rank_skill("bolt", "attack").get("reason", "")) == "tomes", "next rank needs Tomes")
	(acc["wallet"] as Dictionary)["tomes"] = 50
	_ok(bool(Meta.rank_skill("bolt", "attack")["ok"]) and MetaAcc.amount(acc, "tomes") == 50 - HeroData.TOME_COST[1], "Attack rank for Tomes")
	# Team.
	_ok(Meta.team_slots() == 2, "2 champion slots before L40")
	Roster.grant(acc, "otto", "chest")
	Roster.grant(acc, "borko", "chest")
	var hero0 := Save.hero
	_ok(Meta.set_team("titan", ["otto", "borko"]), "set_team with owned members")
	_ok(Meta.hero() == "titan" and str(acc["progress"]["hero"]) == "titan" and Save.hero == "titan", "the team hero is the run hero")
	var syn := Meta.team_synergy("titan", ["otto", "borko"])
	_ok((syn["ids"] as Array).size() >= 1 and syn.has("run"), "team synergy: %s" % str(syn["ids"]))
	_ok(not Meta.set_team("bolt", ["otto", "borko", "alba"]), "more champions than slots refused")
	var at := Meta.auto_team()
	_ok(at.has("hero") and at.has("champions") and at.has("gains"), "auto_team shape")
	_ok(Meta.save_team_preset(1) and Meta.load_team_preset(1), "presets save / load")
	# Champion Level.
	var cl0 := Meta.champion_level()
	var lv := Meta.level_champions()
	_ok(bool(lv["ok"]) and Meta.champion_level() == cl0 + 1, "Champion Level for coins")
	_ok(Meta.set_chest_focus("otto") and Meta.chest_focus("R") == "otto", "chest Focus per gem")
	_ok(Meta.set_portal_focus("C", "arin") == Summon.pool(acc, "C").has("arin"), "Portal Focus set for a pool hero")
	var od := Meta.portal_odds()
	_near(float((od["consolidated"] as Dictionary).values().reduce(func(a: float, b: float) -> float: return a + b, 0.0)), 1.0, 1e-6, "consolidated odds sum to 1")
	_ok(not Meta.chest_odds("grand_hero_chest").is_empty() and Meta.chest_odds("pony").is_empty(), "chest_odds per type")
	# Run profile (live).
	var rp := Meta.run_profile(31)
	_ok(rp.has("team") and str(rp["hero"]["id"]) == Meta.hero() and rp["hero"].has("ult_power") and rp["hero"].has("skills")
			and not bool(rp["hero"]["guest"]), "run_profile: v3 hero block and team")
	_ok((rp["team"]["champions"] as Array).size() == 2 and str(rp["team"]["champions"][0]["slot"]) != str(rp["team"]["champions"][1]["slot"]),
			"team block: two champions in distinct slots")
	Save.hero = hero0
	_unbind(keep)
	_live(false)


## A grant that fails to save rolls the in-memory account (and the RNG) back (§12.1, test 15).
func _test_grant_rollback() -> void:
	print("== atomic write rollback (live phase)")
	_live(true)
	var keep := {"path": Save.path, "account": Save.account, "meta": Meta.account, "ro": Save.readonly, "level": Save.level,
			"coins": Save.coins, "hero": Save.hero}
	var acc := _hacc(25)
	(acc["wallet"] as Dictionary)["beacons"] = 10
	Save.account = acc
	Meta.account = acc
	Save.readonly = false
	Save.path = TMP_DIR + "/no_such_dir/deeper/save.cfg"
	Save.level = MetaAcc.level(acc)             # the legacy mirrors match the account (Meta.level() reads them)
	Save.hero = str(acc["progress"]["hero"])
	var snap := var_to_str(acc)
	var rs: int = Meta._rng.state
	var r2 := Meta.welcome_summon()
	_ok(not bool(r2["ok"]) and str(r2["reason"]) == "save" and var_to_str(Meta.account) == snap and Meta._rng.state == rs,
			"welcome x10 whose save fails: rolled back (still unused)")
	(acc["summon"] as Dictionary)["welcome_done"] = true     # Beacon summons wait for the welcome (review F4)
	snap = var_to_str(acc)
	var r := Meta.summon(10)
	if str(r.get("reason", "")) != "save" or var_to_str(Meta.account) != snap:
		var was: Dictionary = str_to_var(snap)
		for sec in was:
			if var_to_str(was[sec]) != var_to_str(Meta.account.get(sec)):
				print("    rollback differs in %s: %s -> %s" % [sec, var_to_str(was[sec]).left(200), var_to_str(Meta.account.get(sec)).left(200)])
		print("    rollback: summon -> %s rng %s/%s" % [str(r).left(200), str(rs), str(Meta._rng.state)])
	_ok(not bool(r["ok"]) and str(r["reason"]) == "save" and var_to_str(Meta.account) == snap and Meta._rng.state == rs and is_same(Meta.account, Save.account),
			"summon whose save fails: account, RNG and the shared dictionary restored")
	Save.path = TMP_DIR + "/rollback_ok.cfg"
	var r3 := Meta.summon(1)
	_ok(bool(r3["ok"]) and MetaAcc.amount(Meta.account, "beacons") == 9 and FileAccess.file_exists(Save.path), "a good path saves the grant")
	Save.readonly = bool(keep["ro"])
	Save.level = int(keep["level"])
	Save.coins = int(keep["coins"])
	Save.hero = str(keep["hero"])
	Save.path = str(keep["path"])
	Save.account = keep["account"]
	Meta.account = keep["meta"]
	_live(false)


## Earned-only randomness (P2, §7.3, §7.7, test 7): no path from money, Gems, SKUs, rating, Track or
## Road into Beacons, Seals, Hero Chests, Tomes, fragments or pity.
func _test_two_track() -> void:
	print("== earned-only randomness (two-track rule)")
	_live(true)
	# 1. Data: no SKU carries hero currencies or random items; no Track / Road / Feat pays Beacons.
	var forbidden := ["beacon", "seal", "chest", "tome", "ore", "frag", "summon", "hero", "champion", "pity", "portal"]
	var leak: Array = []
	for sku: String in EconData.SKUS:
		var txt := var_to_str(EconData.SKUS[sku]).to_lower()
		for f in forbidden:
			if f in txt and not (f == "hero" and sku.begins_with("skin_")):
				leak.append("%s:%s" % [sku, f])
	_ok(leak.is_empty(), "no SKU holds hero currencies or random items: %s" % str(leak))
	_ok(float(PortalData.BEACON["track"]) == 0.0 and not "track" in Summon.BEACON_SOURCES and not "road" in Summon.BEACON_SOURCES
			and not "shop" in Summon.BEACON_SOURCES and not "ads" in Summon.BEACON_SOURCES, "Track / Road / shop / ads are no Beacon source")
	var feat_pay := true
	for fid: String in HeroData.FEATS:
		feat_pay = feat_pay and str((HeroData.FEATS[fid] as Dictionary)["reward"][0]) in ["tomes", "ore"]
	_ok(feat_pay, "hero Feats pay Tomes / Star Ore only, never Beacons")
	var track_cur: Array = []
	for step: Array in EconData.TRACK["cycle"]:
		track_cur.append(str(step[0]))
	_ok(not track_cur.has("beacons"), "Arsenal Track pays no Beacons")
	_ok(EconData.road_node("premium", "gems", 20, 30)["cur"] == "coins" and int(EconData.road_node("premium", "gems", 20, 30)["n"]) == EconData.track_coin_node(30)
			and EconData.road_node("free", "gems", 20, 30)["cur"] == "gems", "paid Road lane: Gem nodes pay coins (Track rate), free lane unchanged")
	for lane in ["free", "premium"]:
		for cur in ["gems", "coins", "beacons"]:
			_ok(str(EconData.road_node(lane, cur, 5, 30)["cur"]) != "beacons" or cur == "beacons", "Road %s %s never becomes Beacons" % [lane, cur])
	var a0 := _hacc(25)
	_ok(Summon.credit(a0, "track") == 0 and Summon.credit(a0, "shop") == 0 and Summon.credit(a0, "gems") == 0, "Summon.credit refuses money / Track sources")
	# 2. Same seeds, same play: a paying account earns exactly the same random-side resources.
	var free := _hacc(1)
	var paid := _hacc(1)
	(paid["shop"] as Dictionary)["entitlements"] = {"starter_arsenal": true, "supporter": true, "road_premium": true}
	MetaAcc.add(paid, "gems", 50000)
	MetaAcc.add(paid, "coins", 500000)
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 4242
	r2.seed = 4242
	for lvl in range(1, 61):
		var won := lvl % 7 != 3
		Rewards.level_end(free, _res(lvl, won, {"run_id": lvl}), r1, 1_800_000_000 + lvl * 3600)
		Rewards.level_end(paid, _res(lvl, won, {"run_id": lvl}), r2, 1_800_000_000 + lvl * 3600)
		if not won:
			Rewards.level_end(free, _res(lvl, true, {"run_id": 1000 + lvl}), r1, 1_800_000_000 + lvl * 3600 + 60)
			Rewards.level_end(paid, _res(lvl, true, {"run_id": 1000 + lvl}), r2, 1_800_000_000 + lvl * 3600 + 60)
	var keys := func(a: Dictionary) -> String:
		var w: Dictionary = a["wallet"]
		return var_to_str([w["beacons"], w["beacon_charge"], w["chest_charge"], w["tomes"], a["summon"], a["chests"], a["vault"]["hero_chests"],
				a["champions"], a["pity"], a["vault"]["caches"]])
	_ok(keys.call(free) == keys.call(paid) and int(free["wallet"]["beacons"]) > 0, "60 levels, same seed: Beacons, chest charge, chests, Tomes, Seals, pity, Caches identical with and without SKUs / Gems / coins")
	# 3. Source scan: only the earned-income rules credit Beacons or Seals.
	var allowed := ["res://scripts/meta/rewards.gd", "res://scripts/meta/summon.gd", "res://scripts/meta/save_migrate.gd"]
	var bad: Array = []
	for f2 in _gd_files("res://scripts"):
		if f2.begins_with("res://scripts/dev/"):
			continue
		var src := FileAccess.get_file_as_string(f2)
		var credits := src.contains("add(acc, \"beacons\"") or src.contains("add(account, \"beacons\"") or src.contains("[\"seals\"] = int(") \
				or src.contains("add_currency(\"beacons\"")
		if credits and not allowed.has(f2):
			bad.append(f2)
		var fn := f2.get_file()
		if (fn.contains("shop") or fn.contains("billing") or fn.begins_with("ads")) and (src.contains("beacon") or src.contains("seals") or src.contains("hero_chest")):
			bad.append(f2 + " (shop)")
	_ok(bad.is_empty(), "Beacons / Seals are credited only by Rewards, Summon and the migration: %s" % str(bad))
	# Review F9: the generic currency helper refuses the earned-only currencies.
	var w0 := var_to_str(Meta.account["wallet"])
	for cur in ["beacons", "tomes", "ore", "seals"]:
		Meta.add_currency(cur, 50, "test_shop")
	_ok(var_to_str(Meta.account["wallet"]) == w0, "Meta.add_currency refuses Beacons, Tomes, Star Ore and Seals")
	_live(false)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out


## Meta-1 touch point: the Focus machine gets EXACTLY 40% of its rarity's cards (live phase);
## the 2.2.1 rule (flag off) gives it 40% + its share of the rest.
func _test_focus_exact() -> void:
	print("== machine Focus exactly 40% (live phase)")
	var acc := _acc_at(20, "expected")
	var pl: Array[String] = []
	for id in ArsenalData.live_ids():
		if ArsenalData.rarity_of(id) == "C" and MetaAcc.owned(acc, id):
			pl.append(id)
	if pl.size() < 3:
		_ok(false, "need 3 owned Commons for the Focus test (got %s)" % str(pl))
		return
	(acc["arsenal"] as Dictionary)["focus"] = pl[0]
	var n := 40000
	for live in [false, true]:
		_live(live)
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var hit := 0
		var a := acc.duplicate(true)
		for i in n:
			if str(CacheRoller.grant_card(a, "C", pl, rng, false)["id"]) == pl[0]:
				hit += 1
		var p := float(hit) / n
		var d := Arsenal.deck(a)
		var tot := 0.0
		for id2 in pl:
			tot += EconData.DECK_WEIGHT if d.has(id2) else 1.0
		var own := (EconData.DECK_WEIGHT if d.has(pl[0]) else 1.0) / tot
		var want := EconData.FOCUS_SHARE if live else EconData.FOCUS_SHARE + (1.0 - EconData.FOCUS_SHARE) * own
		var z := (p - want) / sqrt(want * (1.0 - want) / n)
		_ok(absf(z) <= 4.0, "%s: Focus share %.4f vs %.4f (z %.2f)" % ["live exactly 40%" if live else "2.2.1 rule", p, want, z])
	_live(false)
	_ok(CacheRoller.odds("stone", ["C", "R"], {})["focus_exact"] == false, "odds sheet says the 2.2.1 rule while off")


## §12.5: every hero event the flows above logged carries its keys.
func _test_hero_telemetry() -> void:
	print("== hero telemetry schema (§12.5)")
	_live(true)
	var keep := Meta.account
	Meta.account = _bind(_hacc(25))
	var acc := Meta.account
	(acc["wallet"] as Dictionary)["beacons"] = 20
	(acc["wallet"] as Dictionary)["tomes"] = 20
	(acc["wallet"] as Dictionary)["coins"] = 50000
	Meta.welcome_summon()
	Meta.summon(10)
	(acc["summon"] as Dictionary)["seals"] = 40
	Meta.seal_pick("iskar")
	Roster.ensure(acc, "bolt")["frags"] = 200
	Meta.fill_facets("hero", "bolt")
	Meta.recut("hero", "bolt")
	Meta.level_hero("bolt")
	Meta.level_champions()
	Rewards.level_end(acc, _res(25, true, {"run_id": 5, "team_report": [{"id": "alba", "alive": false, "t": 41.5, "cause": "clash"}]}), Meta._rng, 0)
	Meta.note_ceremony("walkout_L", 3.6, false)
	(acc["progress"] as Dictionary)["level"] = 31
	UnlockQueue.mark_all_done(acc)
	(acc["wallet"] as Dictionary)["tomes"] = 30
	var cb := Meta.buy_chronicle("bolt")
	_ok(bool(cb["ok"]) and int(cb["page"]) == 1 and int(cb["tomes"]) == HeroData.CHRONICLE_PRICES[0] and MetaAcc.amount(acc, "tomes") == 30 - HeroData.CHRONICLE_PRICES[0],
			"Chronicle page 1 for %d Tomes" % HeroData.CHRONICLE_PRICES[0])
	_ok(str(Meta.chronicle_cost("vesta")["reason"]) in ["owned", "tomes", ""], "Chronicle cost of another hero")
	var missing: Array = []
	var seen := {}
	for ev in (acc["telemetry"]["events"] as Array):
		var e := str((ev as Dictionary)["e"])
		if MetaTelemetry.HERO_EVENTS.has(e):
			seen[e] = true
			var m := MetaTelemetry.missing_keys(e, (ev as Dictionary)["d"])
			if not m.is_empty():
				missing.append("%s %s" % [e, str(m)])
	_ok(missing.is_empty(), "hero events carry every §12.5 key: %s" % str(missing))
	_ok(seen.has_all(["summon", "seal_pick", "facet", "recut", "team_run", "champion_lost", "ceremony", "chronicle", "champion_level"]),
			"events logged: %s" % str(seen.keys()))
	var tr := MetaTelemetry.events_of(acc, "team_run")
	_ok(not tr.is_empty() and (tr[-1]["d"]["lost_ids"] as Array) == ["alba"], "team_run lists the fallen champions")
	_unbind(keep)
	_live(false)


## Dev profiles from the champions-in-the-run phase (H2): synthetic accounts carry the starters met
## by progress and the two scripted champions; dev run profiles get the v3 hero / team blocks while a
## real account still plays 2.2.1 until the live phase.
func _test_synthetic_heroes() -> void:
	print("== synthetic accounts / dev run profiles (phase H2)")
	_live(true, EconData.HEROES_RUN_PHASE)
	var a := Meta.synthetic_account(30, "expected")
	_ok(bool(a["heroes"]["titan"]["owned"]) and bool(a["heroes"]["seer"]["owned"]) and Array(a["team"]["champions"]) == ["alba", "mila"]
			and int(a["champions"]["level"]) == SaveV3Data.EXPECTED_CHAMPION_LEVEL[29], "expected L30: Goran and Meira met, Alba + Mila, Champion Lv %d" % SaveV3Data.EXPECTED_CHAMPION_LEVEL[29])
	_ok(not bool(Meta.synthetic_account(20, "expected")["heroes"]["seer"]["owned"]), "expected L20: Meira joins only after the L24 win")
	var b := Meta.synthetic_account(10, "fresh")
	_ok((b["team"]["champions"] as Array).is_empty() and (b["champions"]["roster"] as Dictionary).is_empty(), "before L14: no champions")
	var keep := Meta.account
	Meta.account = a
	var p := Meta.run_profile(30)
	_ok(Save.readonly and p.has("team") and (p["team"]["champions"] as Array).size() == 2 and p["hero"].has("ult_power") and not Meta.heroes_on(),
			"dev run profile at phase 2: v3 hero + team blocks, hero systems still off")
	_ok(str(Meta.summon(1).get("reason", "")) == "phase", "phase 2: no meta mutations")
	_unbind(keep)
	_live(false)
	var c := Meta.synthetic_account(30, "expected")
	_ok((c["team"]["champions"] as Array).is_empty() and not bool(c["heroes"]["titan"]["owned"]), "phase 0: synthetic accounts as 2.2.1")
