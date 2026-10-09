extends Node
## test_kind_parity (heroes design §10.4, §12.6 #9): the real Run and LevelSim play the same level on
## the same fixed input path, and the CHAMPIONS' contribution must come out the same in both, so the
## bot, level_check and the planner can trust the one rules implementation (HeroKinds / ChampionKinds
## over a KindView).
##
## 1. Verbs (always first; --verbs runs only this): the H2 KindView verbs (status + status_mult, hold,
##    ground, tether, grant_ward / absorb) on the same squads of one level through RunKindView (a real
##    Run, its Statuses stepped by hand) and SimKindView (LevelSim) must leave the same hp, strengths and
##    answers: MARK x1.25 on a hit, a tether's 50% both ways and one hop only, the stronger / longer
##    hold, a 3 s BURN = 3 units, a JOLT chain of 75% to a squad 1.5 u away (one stack spent), a
##    grounded Flying squad reads as ground, and contact wards spent by blade and barricade hits only;
##    then the Run's own hazard contacts spend them where LevelSim._hazards does (Run.hazard_kills: one
##    charge spares one soldier, the barricade keeps its wear).
## 2. Cases: seeds x heroes x team setups. A seed is a campaign level (LevelGen is deterministic per
##    level; seed k plays LEVELS[k], all >= 41 so the 4-member team is legal on every one). Heroes: the
##    three that run today (bolt, titan, seer). Setups: "none" (no champions), "expected" (the synthetic
##    EXPECTED account's pair, Meta.team_block_of through Meta.run_profile, as champ_survival builds it)
##    and "four" (borko, taya, ivo, mila: Warrior front, Mage, Guardian, Healer). Phase H2 is forced
##    (EconData.phase_override, restored at the end); the account is swapped into Meta for each case so the
##    Run reads its profile through the normal Meta.run_profile path, and LevelSim gets that very profile.
##
## Input: one path per (seed, hero), LevelSim.best_path planned once with the "expected" profile and
## replayed unchanged by every setup. (a) the Run, headless, stepped by this test at its own SUBSTEP
## (1 / 40 s, no frame-time noise; its Effects stepped with it, so the projectiles that carry machine,
## volley and turret hits land on game time; SceneTreeTimers, used only for the rocket launcher's
## staggered missiles and the mortar's bomblets, still run on the engine's clock), steered with
## Run.steer_to toward the path x a spring-lag ahead
## (RUN_SPEED x STEER_HALFLIFE / ln 2, so the critically damped follow lands on the path); the ult is
## fired by the shared auto policy (LevelSim.ult_worth on the bot's snapshot of the live run, the same
## rule LevelSim's auto_ult applies). (b) LevelSim.simulate on the same path and profile, with the crate
## contents the Run drew fixed in State.content (the Run and LevelSim draw crates from different RNG
## streams, so on their own they field different machines: an input difference, not a rules one); and
## once more with LevelSim's own draws for the drift diagnostic. No bot re-planning anywhere. All stop
## when the fortress falls or the run is lost.
##
## Asserted (the H2 gate): per (seed, hero) and team setup, the champions' contribution = (with the team
## - without it) in the Run against the same delta in LevelSim, for the army at the fortress, total kills
## and the champion counters (kills, heals, blocks, falls; "without" is 0 for those): |dRun - dSim| <=
## max(3% of the larger |delta|, the column's FLOOR): army 3 soldiers (one Mend pulse returns 3, a Block
## spares ~4, and the Run books whole soldiers through fractional accumulators), kills 3 and champion
## kills 3 (one Warrior leap), heals 3 (one pulse), blocks 1 (one Block), falls 0 (a fall must match).
## Printed per case (the DELTA lines); a case fails on any column.
## Printed, never asserted: total kills per case (squad hp removed by every source; equal whenever every
## squad dies), and the Meta-1 drift with the same inputs and no team, LevelSim on its own crate draws
## (META1_DRIFT: army at the fortress, the worst kills-curve gap at the CHECK_EVERY checkpoints, the kills
## when each side first clashes, the hazard and clash losses, how many crates the two drew differently, and
## the fortress army LevelSim gets with the Run's crates). That drift is Meta-1's, not the champions';
## fixing it would move shipped levels (LevelGen plans with LevelSim).
##
##   godot --headless --path . res://scenes/dev/test_kind_parity.tscn -- --autotest [--quick] [--verbs]
##        [--seeds=10] [--levels=41,45] [--heroes=bolt,titan,seer] [--setups=none,expected,four]
##        [--out=DIR] [--verbose] [--trace]
## --quick = 2 seeds. Exit code = failures. Last line: TEST_KIND_PARITY PASS|FAIL: <cases>, <failed>,
## time. --out writes kind_parity.csv (one row per case, the deltas on the team rows). About 5 s per
## (seed, hero) plan and 2-4 s per Run case on a desktop: the full 90 cases take ~6-8 min.

const CS := preload("res://scripts/dev/champ_survival.gd")
## Seed k -> campaign level (all >= 41: the 4-member team needs the third slot, UNLOCK_AT.slot3 = 40).
const LEVELS: Array[int] = [41, 42, 43, 44, 45, 46, 47, 50, 53, 55]
const HEROES: Array[String] = ["bolt", "titan", "seer"]
const SETUPS: Array[String] = ["none", "expected", "four"]
const FOUR: Array[String] = ["borko", "taya", "ivo", "mila"]
## The rule: |dRun - dSim| <= max(TOL x max(|dRun|, |dSim|), FLOOR[column]) (see the header).
const TOL := 0.03
const FLOOR := {"army": 3.0, "kills": 3.0, "ck": 3.0, "heals": 3.0, "blocks": 1.0, "falls": 0.0}
const COLUMNS: Array[String] = ["army", "kills", "ck", "heals", "blocks", "falls"]
const DT := Run.SUBSTEP
## Run steps per engine frame (the frame lets the run's fx nodes expire between batches).
const STEPS_PER_FRAME := 200
## Planner candidates (LevelSim.best_path default 13): the path is only an input here.
const PLAN_CANDIDATES := 9
## Hard stop for a Run that neither wins nor loses (run seconds).
const MAX_T := 600.0
## Kill / army checkpoints every this many u of run distance (the diagnostic columns).
const CHECK_EVERY := 5.0
## "Armies split" = the two armies differ by more than this share (of max(sim, 10)) at a checkpoint.
const ARMY_SPLIT := 0.1
## The verbs check plays on this level's first two squads, reset to RESET_HP before each sub-check.
const VERB_LEVEL := 45
const RESET_HP := 30.0

var _fails := 0
var _verbose := false
var _trace := false
var _checked_sim := false
var _bot := Bot.new()
var _rows: Array = []
var _deltas: Array = []
var _csv: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_verbose = args.has("verbose")
	_trace = args.has("trace")
	var levels: Array[int] = []
	if args.has("levels"):
		for v in str(args["levels"]).split(",", false):
			levels.append(int(v))
	else:
		var n := 2 if args.has("quick") else clampi(int(args.get("seeds", "10")), 1, LEVELS.size())
		levels = LEVELS.slice(0, n)
	var heroes := _pick(args, "heroes", HEROES)
	var setups := _pick(args, "setups", SETUPS)
	if not setups.has("none"):
		# Every delta needs its no-team run.
		setups.push_front("none")
	Save.readonly = true
	var old_phase := EconData.phase_override
	var old_hitstop := Juice.hitstop_enabled
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	Juice.hitstop_enabled = false
	var t0 := Time.get_ticks_msec()
	await _verbs()
	if args.has("verbs"):
		EconData.phase_override = old_phase
		Juice.hitstop_enabled = old_hitstop
		print("TEST_KIND_PARITY %s: verbs only, %d failed, %.0f s" % ["PASS" if _fails == 0 else "FAIL", _fails,
				float(Time.get_ticks_msec() - t0) / 1000.0])
		get_tree().quit(_fails)
		return
	print("TEST_KIND_PARITY seeds (levels) %s x heroes %s x setups %s; rule: the champions' contribution (team -" % [
			str(levels), ",".join(heroes), ",".join(setups)])
	print("  none) matches, |dRun - dSim| <= max(%d%% of the larger, floor: army %.0f, kills %.0f, champion kills %.0f," % [
			int(TOL * 100.0), FLOOR["army"], FLOOR["kills"], FLOOR["ck"]])
	print("  heals %.0f, blocks %.0f, falls %.0f)" % [FLOOR["heals"], FLOOR["blocks"], FLOOR["falls"]])
	_csv.append("seed,level,hero,setup,team,run_kills,sim_kills,curve,run_ck,sim_ck,run_heals,sim_heals," +
			"run_blocks,sim_blocks,run_falls,sim_falls,run_won,sim_won,run_t,sim_t,run_army,sim_army,run_fort,sim_fort," +
			"run_haz,sim_haz,run_clash,sim_clash,army_split_d,ult_run,run_machine_kills,d_army_run,d_army_sim," +
			"d_kills_run,d_kills_sim,pass")
	print("  kills = squad hp removed by every source (run / sim; printed, not asserted); curve = worst kills gap at")
	print("  the %.0f u checkpoints; champion columns run/sim; fort = army at the fortress (-1 = never got there);" % CHECK_EVERY)
	print("  split = first checkpoint d where the armies differ by > %d%%." % int(ARMY_SPLIT * 100.0))
	print("  %-4s %-4s %-5s %-8s | %6s %7s | %6s | %9s | %9s | %5s | %3s | %3s | %11s | %11s | %s" % ["seed",
			"lvl", "hero", "setup", "run", "sim", "curve", "champ k", "heals", "blck", "fal", "won", "fort",
			"time", "split"])
	for k in levels.size():
		for hero in heroes:
			var path := _plan(levels[k], hero)
			var group := {}
			for setup in setups:
				var row: Dictionary = await _case(k, levels[k], hero, setup, path)
				_report(row)
				group[setup] = row
			_judge(group)
	EconData.phase_override = old_phase
	Juice.hitstop_enabled = old_hitstop
	_summary(float(Time.get_ticks_msec() - t0) / 1000.0)
	if args.has("out"):
		_write(str(args["out"]))
	get_tree().quit(_fails)


static func _pick(args: Dictionary, key: String, all: Array[String]) -> Array[String]:
	if not args.has(key):
		return all
	var out: Array[String] = []
	for v in str(args[key]).split(",", false):
		if v in all:
			out.append(v)
	return out


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
	if not cond or _verbose:
		print("  %s %s" % ["ok" if cond else "FAIL", what])


# ------------------------------------------------------------------ 1. the verbs in both views

## The H2 verbs on the same two squads A and B of VERB_LEVEL through both views (see the header), each
## sub-check from the same fresh state (RESET_HP, no statuses, holds or groundings). The Run is real (in
## the tree, never started: READY, its logic never stepped; its Statuses stepped by hand); run.t and
## State.t are moved together by hand for the timed verbs.
func _verbs() -> void:
	print("== verbs: RunKindView (a real Run) vs SimKindView (LevelSim) on the same squads of L%d" % VERB_LEVEL)
	var fails0 := _fails
	var acc := account_with(VERB_LEVEL, "bolt", [])
	var keep: Array = swap_in(acc, "bolt")
	var run := Run.new()
	run.setup(VERB_LEVEL, "bolt")
	swap_out(keep)
	add_child(run)
	run.set_process(false)
	await get_tree().process_frame
	var lv := level_of(VERB_LEVEL)
	var s := LevelSim.start_state(lv, "bolt", Balance.START_ARMY, {"profile": run.profile})
	var rv := run.kind_view
	var sv := SimKindView.new(lv, s)
	# The first two squads of both views: [run item, sim index].
	var sq: Array = []
	for it: Dictionary in run.hazards.squads:
		for i in lv.items.size():
			if lv.kind[i] == LevelSim.K.SQUAD and absf(lv.d[i] - float(it["d"])) < 0.001 and absf(lv.x[i] - float(it["x"])) < 0.001:
				sq.append([it, i])
				break
		if sq.size() == 2:
			break
	_ok(sq.size() == 2, "L%d: two squads matched by d and x in both views" % VERB_LEVEL)
	if sq.size() < 2:
		_drop(run)
		return
	var views: Array[KindView] = [rv, sv]
	var ids := [[int((sq[0][0] as Dictionary)["kid"]), int(sq[1][0]["kid"])], [int(sq[0][1]), int(sq[1][1])]]
	# MARK: x1.25 on the next hit; status_mult 1.25 on it, 1.0 elsewhere.
	_reset(run, s, sq)
	for k in 2:
		views[k].status(ids[k][0], &"mark", 3.0)
	var m := Vector2(rv.status_mult(ids[0][0]), sv.status_mult(ids[1][0]))
	var m1 := Vector2(rv.status_mult(ids[0][1]), sv.status_mult(ids[1][1]))
	for k in 2:
		views[k].hit(ids[k][0], 4.0)
	var lost := _lost(run, s, sq, 0)
	_ok(m == Vector2(1.25, 1.25) and m1 == Vector2.ONE and lost.is_equal_approx(Vector2(5.0, 5.0)),
			"MARK: status_mult %s (an unmarked squad %s), a hit of 4 removes %s (want 5 / 5)" % [m, m1, lost])
	# Tether A-B at 50%: 4 on A = A 4 + B 2; then 2 on B = B 2 + A 1 (one hop only).
	_reset(run, s, sq)
	for k in 2:
		views[k].tether(ids[k][0], ids[k][1], 0.5, 3.0)
		views[k].hit(ids[k][0], 4.0)
		views[k].hit(ids[k][1], 2.0)
	var la := _lost(run, s, sq, 0)
	var lb := _lost(run, s, sq, 1)
	_set_t(run, s, run.t + 3.5)
	for k in 2:
		views[k].hit(ids[k][0], 2.0)
	var la2 := _lost(run, s, sq, 0) - la
	var lb2 := _lost(run, s, sq, 1) - lb
	_ok(la.is_equal_approx(Vector2(5.0, 5.0)) and lb.is_equal_approx(Vector2(4.0, 4.0)) and la2.is_equal_approx(Vector2(2.0, 2.0))
			and lb2 == Vector2.ZERO, "tether 50%%: A lost %s (want 5), B %s (want 4); after it ends a hit of 2 on A: A %s, B %s" % [
			la, lb, la2, lb2])
	# Hold: 0.5 for 2 s, then 1.0 for 1 s -> 1.0 until +2 s; past it 0; an expired hold is replaced.
	_reset(run, s, sq)
	var t0 := run.t
	for k in 2:
		views[k].hold(ids[k][0], 2.0, 0.5)
		views[k].hold(ids[k][0], 1.0, 1.0)
	var k_now := _holds(run, s, sq[0])
	_set_t(run, s, t0 + 1.5)
	var k_mid := _holds(run, s, sq[0])
	_set_t(run, s, t0 + 2.5)
	var k_end := _holds(run, s, sq[0])
	for k in 2:
		views[k].hold(ids[k][0], 1.0, 0.3)
	var k_new := _holds(run, s, sq[0])
	_ok(k_now == Vector2(1.0, 1.0) and k_mid == Vector2(1.0, 1.0) and k_end == Vector2.ZERO and k_new.is_equal_approx(Vector2(0.3, 0.3)),
			"hold: stronger kept %s, at +1.5 s %s, at +2.5 s %s, an expired hold replaced %s" % [k_now, k_mid, k_end, k_new])
	# BURN 3 s: 1 unit / s (the Run in whole units, LevelSim as an expected value).
	_reset(run, s, sq)
	for k in 2:
		views[k].status(ids[k][0], &"burn", 3.0)
	for i in 160:
		run.arsenal.statuses.step(1.0 / 40.0)
	for i in 80:
		LevelSim._statuses(lv, s, 0.05)
	var le := _lost(run, s, sq, 0)
	_ok(absf(le.x - 3.0) <= 1.0 and absf(le.y - 3.0) < 0.01, "BURN 3 s: %s lost (want 3 / 3; the Run's whole-unit ticks within 1)" % le)
	# JOLT: B stands 1.5 u beside A; a hit of 4 on A chains 3 to B and spends the stack.
	_reset(run, s, sq)
	var ia: Dictionary = sq[0][0]
	var ib: Dictionary = sq[1][0]
	var keep_b := [float(ib["d"]), float(ib["x"]), lv.d[int(sq[1][1])], lv.x[int(sq[1][1])]]
	var nx := clampf(float(ia["x"]) + (1.5 if float(ia["x"]) < 0.0 else -1.5), -Balance.X_LIMIT, Balance.X_LIMIT)
	ib["d"] = float(ia["d"])
	ib["x"] = nx
	lv.d[int(sq[1][1])] = lv.d[int(sq[0][1])]
	lv.x[int(sq[1][1])] = nx
	for k in 2:
		views[k].status(ids[k][0], &"jolt", 2.0)
		views[k].hit(ids[k][0], 4.0)
	var lj := _lost(run, s, sq, 0)
	var lk := _lost(run, s, sq, 1)
	var spent := Vector2(0.0 if run.arsenal.statuses.has(ia, "jolt") else 1.0,
			0.0 if LevelSim.has_status(s, int(sq[0][1]), "jolt") else 1.0)
	_ok(lj.is_equal_approx(Vector2(4.0, 4.0)) and lk.is_equal_approx(Vector2(3.0, 3.0)) and spent == Vector2.ONE,
			"JOLT: the hit squad lost %s (want 4), its neighbour %s (want 3), stack spent %s" % [lj, lk, spent])
	ib["d"] = keep_b[0]
	ib["x"] = keep_b[1]
	lv.d[int(sq[1][1])] = keep_b[2]
	lv.x[int(sq[1][1])] = keep_b[3]
	# Ground: a Flying squad reads as ground while grounded, Flying again after.
	_reset(run, s, sq)
	ib["props"] = ["flying"]
	ib.erase("kv")
	lv.items[int(sq[1][1])] = (lv.items[int(sq[1][1])] as Dictionary).duplicate()
	lv.items[int(sq[1][1])]["props"] = ["flying"]
	var fl0 := _flying(rv, sv, sq[1])
	for k in 2:
		views[k].ground(ids[k][1], 2.0)
	var fl1 := _flying(rv, sv, sq[1])
	_set_t(run, s, run.t + 2.5)
	var fl2 := _flying(rv, sv, sq[1])
	_ok(fl0 == Vector2.ONE and fl1 == Vector2.ZERO and fl2 == Vector2.ONE,
			"ground: flying before %s, grounded %s, after %s (1 = flying)" % [fl0, fl1, fl2])
	# Wards: 2 contact charges for 5 s: a turret hit spends none, a blade and a barricade hit one each.
	var got: Array = []
	for v in views:
		v.grant_ward(&"contact", 2, 5.0)
		got.append([v.absorb(&"turret"), v.absorb(&"blade"), v.absorb(&"contact"), v.absorb(&"contact")])
	_ok(got[0] == [false, true, true, false] and got[1] == got[0],
			"wards: turret, blade, contact, contact -> Run %s, Sim %s (want false, true, true, false)" % [got[0], got[1]])
	_ward_contacts(run)
	_drop(run)
	print("TEST_KIND_PARITY_VERBS %s: %d failed" % ["PASS" if _fails == fails0 else "FAIL", _fails - fails0])


## The Run spends wards where LevelSim._hazards does (Run.hazard_kills, after the Barracks Scrape Guard,
## before the champions): three soldiers on a barricade (its Scrape Guard used up) lose 2 fewer with 2
## contact charges than without, the charges are gone after, and the barricade wears the same 3 hp both
## times (a ward keeps the band's wear, as a Block does).
func _ward_contacts(run: Run) -> void:
	var bar: Dictionary = {}
	for it: Dictionary in run.hazards.spikes:
		if it["alive"]:
			bar = it
			break
	if bar.is_empty():
		_ok(false, "ward contacts: L%d has no barricade" % VERB_LEVEL)
		return
	var units := PackedInt32Array([0, 1, 2])
	bar["hp"] = maxf(float(bar["hp"]), 50.0)
	var res: Array = []
	var w := 1.0
	for warded in [false, true]:
		if warded:
			run.kind_view.grant_ward(&"contact", 2, 5.0)
		# A fresh army of 20 (one soldier per drawn unit), the barricade's Scrape Guard used up.
		run.set_army(20)
		w = float(run.army) / maxf(float(run.army_view.shown), 1.0)
		bar["guard_left"] = 0
		var a0 := run.army
		var hp0 := float(bar["hp"])
		run.hazard_kills(bar, units, Vector3.ZERO)
		res.append([a0 - run.army, hp0 - float(bar["hp"])])
	var left := run.kind_view.absorb(&"contact")
	var want := maxi(int(res[0][0]) - 2, 0)
	_ok(int(res[1][0]) == want and not left and is_equal_approx(float(res[0][1]), float(res[1][1])),
			"ward contacts (Run.hazard_kills): 3 soldiers (x%.1f) on a barricade lose %d without wards, %d with 2 contact charges (want %d); a charge left after: %s; wear %.1f / %.1f hp" % [
			w, int(res[0][0]), int(res[1][0]), want, left, float(res[0][1]), float(res[1][1])])


## Each verb check starts from the same state: both squads alive at RESET_HP, no statuses, holds or
## groundings (the item stamps / State.kv cleared).
static func _reset(run: Run, s: LevelSim.State, sq: Array) -> void:
	for pair: Array in sq:
		var it: Dictionary = pair[0]
		var i := int(pair[1])
		it["hp"] = RESET_HP
		it["alive"] = true
		for key in ["status", "hold_end", "hold_k", "ground_end"]:
			it.erase(key)
		s.hp[i] = RESET_HP
		s.alive[i] = 1
		for f in LevelSim.KV:
			if i * LevelSim.KV + f < s.kv.size():
				s.kv[i * LevelSim.KV + f] = 0.0


## What squad `k` of the pair lost since the reset, in the Run and in LevelSim.
static func _lost(run: Run, s: LevelSim.State, sq: Array, k: int) -> Vector2:
	return Vector2(RESET_HP - float((sq[k][0] as Dictionary)["hp"]), RESET_HP - s.hp[int(sq[k][1])])


func _drop(run: Run) -> void:
	remove_child(run)
	run.free()



static func _set_t(run: Run, s: LevelSim.State, t: float) -> void:
	run.t = t
	s.t = t


## The hold strength on the pair's squad in the Run and in LevelSim.
static func _holds(run: Run, s: LevelSim.State, pair: Array) -> Vector2:
	return Vector2(run.kind_view.hold_k(pair[0]), LevelSim.hold_k(s, int(pair[1])))


## 1 when the pair's squad reads as flying in squads_in, per view.
static func _flying(rv: KindView, sv: KindView, pair: Array) -> Vector2:
	var it: Dictionary = pair[0]
	var out := Vector2.ZERO
	for k in 2:
		var v: KindView = rv if k == 0 else sv
		var want := int(it["kid"]) if k == 0 else int(pair[1])
		var d := float(it["d"])
		for r: Dictionary in v.squads_in(d - 0.1, d + 0.1, -INF, INF):
			if int(r["id"]) == want and bool(r["flying"]):
				out[k] = 1.0
	return out


# ------------------------------------------------------------------ 2. the cases

## The synthetic EXPECTED account at `level` led by `hero` (champ_survival.account_for) with the
## setup's team.
static func account(level: int, hero: String, setup: String) -> Dictionary:
	match setup:
		"none":
			return account_with(level, hero, [])
		"four":
			return account_with(level, hero, FOUR)
	return CS.account_for(level, "expected", hero)


## The synthetic EXPECTED account at `level` led by `hero` with exactly the champions `ids` in the
## team (added to the roster when missing, as main.gd's --team does).
static func account_with(level: int, hero: String, ids: Array) -> Dictionary:
	var acc := CS.account_for(level, "expected", hero)
	var roster: Dictionary = (acc["champions"] as Dictionary)["roster"]
	for id in ids:
		if not roster.has(str(id)):
			roster[str(id)] = EconData.new_champion_state(str(id), true, "dev")
	(acc["team"] as Dictionary)["champions"] = ids.duplicate()
	return acc


## Meta.run_profile(level) for `acc` led by `hero` (the account and Save.hero swapped in, restored).
static func profile_of(acc: Dictionary, level: int, hero: String) -> Dictionary:
	var keep: Array = swap_in(acc, hero)
	var prof: Dictionary = Meta.run_profile(level)
	swap_out(keep)
	return prof


## Puts `acc` and `hero` into Meta / Save (what Run.setup reads); returns what swap_out restores.
static func swap_in(acc: Dictionary, hero: String) -> Array:
	var keep := [Meta.account, str(Save.hero)]
	Meta.account = acc
	Save.hero = hero
	return keep


static func swap_out(keep: Array) -> void:
	Meta.account = keep[0]
	Save.hero = str(keep[1])


static func level_of(level: int) -> LevelSim.Level:
	return LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY), level)


## The fixed input of every setup of (level, hero): the planner's path with the EXPECTED team.
static func _plan(level: int, hero: String) -> PackedFloat32Array:
	var prof := profile_of(account(level, hero, "expected"), level, hero)
	var bp: Dictionary = LevelSim.best_path(level_of(level), hero, Balance.START_ARMY, {"profile": prof,
			"candidates": PLAN_CANDIDATES})
	return bp["path"]


func _case(seed_k: int, level: int, hero: String, setup: String, path: PackedFloat32Array) -> Dictionary:
	var acc := account(level, hero, setup)
	var keep: Array = swap_in(acc, hero)
	seed(1000 + seed_k)
	var run := Run.new()
	run.setup(level, hero)
	swap_out(keep)
	var prof: Dictionary = run.profile
	add_child(run)
	var run_samples: Array = []
	var run_machines: Array = []
	var run_marks := {}
	var res := await drive(run, path, _bot, MAX_T, CHECK_EVERY, run_samples, run_machines, run_marks)
	var mk := machine_kills(run)
	# LevelSim twice: with its own crate draws (the Meta-1 drift diagnostic) and with the crate contents the
	# Run drew (the compared run: the arsenal is an input here, as the path is; the two draw from different
	# RNG streams, Run._pick_rng vs LevelSim._pick's per-crate seed).
	var own_samples: Array = []
	var own_marks := {}
	var lv_own := level_of(level)
	var own := simulate(lv_own, hero, path, prof, CHECK_EVERY, own_samples, own_marks)
	if not _checked_sim:
		# Once: the sampled stepping here is LevelSim.simulate exactly.
		_checked_sim = true
		var ref := LevelSim.simulate(level_of(level), hero, Balance.START_ARMY, path, {"profile": prof})
		if ref.kills != own.kills or ref.t != own.t or ref.army != own.army:
			_fails += 1
			print("  FAIL the sampled sim differs from LevelSim.simulate (kills %.2f vs %.2f)" % [own.kills, ref.kills])
	var sim_samples: Array = []
	var sim_marks := {}
	var crates := run_crates(run)
	var s := simulate(level_of(level), hero, path, prof, CHECK_EVERY, sim_samples, sim_marks, crates)
	var team: PackedStringArray = PackedStringArray()
	for m: Dictionary in run.champions.members:
		team.append("%s:%s" % [str(m["id"]), str(m["slot"])])
	var row := {"seed": seed_k, "level": level, "hero": hero, "setup": setup, "team": " ".join(team),
			"run_kills": float(run.stats["kills_total"]), "sim_kills": s.kills,
			"run": tally(run.champions.members), "sim": tally(s.champs.members),
			"run_won": run.state != Run.State.LOST and bool(res["ended"]), "sim_won": s.mode == LevelSim.Mode.WON,
			"run_t": run.t, "sim_t": s.t, "run_army": run.army, "sim_army": s.army,
			"run_fort": float(run._army_at_fortress), "sim_fort": s.army_at_fortress,
			"run_haz": run.hazard_deaths, "sim_haz": s.hazard_deaths,
			"run_clash": float(run.stats["clash_losses"]), "sim_clash": s.clash_deaths,
			"run_first": run_marks, "sim_first": sim_marks, "ults": int(res["ults"]),
			"run_samples": run_samples, "sim_samples": sim_samples, "run_machines": run_machines, "run_mk": mk,
			"own_fort": own.army_at_fortress, "own_haz": own.hazard_deaths, "own_clash": own.clash_deaths,
			"own_first": own_marks, "own_samples": own_samples, "own_kills": own.kills, "crates": crates.size(),
			"crates_differ": _crates_differ(lv_own, own, crates)}
	remove_child(run)
	run.free()
	return row


## The crate contents the Run resolved: Vector2(d, x) -> content id (the crates it came near).
static func run_crates(run: Run) -> Dictionary:
	var out := {}
	for it: Dictionary in run.items:
		if str(it["kind"]) == "crate" and bool(it.get("resolved", false)) and str(it.get("content", "")) != "":
			out[Vector2(float(it["d"]), float(it["x"]))] = str(it["content"])
	return out


## How many of the Run's crate contents LevelSim (`s`, its own run on `lv`) drew differently.
static func _crates_differ(lv: LevelSim.Level, s: LevelSim.State, crates: Dictionary) -> int:
	var n := 0
	for key: Vector2 in crates:
		var i := _crate_index(lv, key)
		if i >= 0 and s.content.has(i) and str(s.content[i]) != str(crates[key]):
			n += 1
	return n


## The LevelSim index of the crate at (d, x) = `key` (-1 when none).
static func _crate_index(lv: LevelSim.Level, key: Vector2) -> int:
	for i in lv.crates:
		if absf(lv.d[i] - key.x) < 0.01 and absf(lv.x[i] - key.y) < 0.01:
			return i
	return -1


## LevelSim.simulate (start_state, the path's first x, advance to length + 50 at DT for at most 600 s)
## stepped here so `samples` gets the same Vector4(d, kills, army, t) checkpoints as drive(), and
## `marks` the first clash {d, kills, army, t}. `crates` (Vector2(d, x) -> content, run_crates) fixes
## those crates' contents in State.content (LevelSim._pick reads them first).
static func simulate(lv: LevelSim.Level, hero: String, path: PackedFloat32Array, prof: Dictionary, every: float,
		samples: Array, marks: Dictionary = {}, crates: Dictionary = {}) -> LevelSim.State:
	var s := LevelSim.start_state(lv, hero, Balance.START_ARMY, {"profile": prof})
	for key: Vector2 in crates:
		var ci := _crate_index(lv, key)
		if ci >= 0:
			s.content[ci] = str(crates[key])
	s.hx = LevelSim.path_x(path, 0.0)
	s.ax = s.hx
	var next := every
	var d_end := lv.length + 50.0
	while s.mode != LevelSim.Mode.WON and s.mode != LevelSim.Mode.LOST and s.d < d_end and s.t < MAX_T:
		if every > 0.0 and s.d >= next:
			samples.append(Vector4(next, s.kills, s.army, s.t))
			next += every
		LevelSim.step(lv, s, path, LevelSim.DT)
		if marks.is_empty() and s.mode == LevelSim.Mode.CLASH:
			marks.merge({"d": s.d, "kills": s.kills, "army": s.army, "t": s.t})
	return s


## Worst |kills_run(d) - kills_sim(d)| / max(final sim kills, 1) over the checkpoints both reached, and
## the first checkpoint where the armies differ by more than ARMY_SPLIT (-1 = never): [curve, split_d].
static func curves(a: Array, b: Array, final_sim: float) -> Array:
	var worst := 0.0
	var split := -1.0
	for i in mini(a.size(), b.size()):
		var p: Vector4 = a[i]
		var q: Vector4 = b[i]
		worst = maxf(worst, absf(p.y - q.y) / maxf(final_sim, 1.0))
		if split < 0.0 and absf(p.z - q.z) > ARMY_SPLIT * maxf(q.z, 10.0):
			split = p.x
	return [worst, split]


## Plays `run` (in the tree, READY) along `path` at the fixed SUBSTEP until the fortress falls, the run
## is lost or MAX_T passes: steer toward the path, fire the ult by the shared auto policy, step. The
## engine never steps the run itself (set_process(false)). With `every` > 0, `samples` gets a
## Vector4(d, kills, army, t) and `machines` the war machines' kills so far each time the hero passes a
## multiple of `every`; `marks` gets the first clash {d, kills, army, t}. Returns {ended, ults, steps}.
static func drive(run: Run, path: PackedFloat32Array, bot: Bot, max_t := MAX_T, every := 0.0,
		samples: Array = [], machines: Array = [], marks: Dictionary = {}) -> Dictionary:
	begin(run, path)
	# The run's Effects fly every projectile that carries a hit (machine shots, Prism orbs, mortar shells,
	# army volleys, turret shots: Effects.projectile's on_hit). Left to the engine they would fly in real
	# time while this loop runs STEPS_PER_FRAME game steps per frame, landing many game seconds late (or
	# never: the target is gone). They fly on game time here, one Effects step per run step.
	run.effects.set_process(false)
	var steps := 0
	var ults := 0
	var next := every
	var tree := run.get_tree()
	while true:
		for k in STEPS_PER_FRAME:
			if every > 0.0 and run.d >= next:
				samples.append(Vector4(next, float(run.stats["kills_total"]), float(run.army), run.t))
				machines.append(machine_kills(run))
				next += every
			if over(run) or run.t > max_t:
				return {"ended": over(run), "ults": ults, "steps": steps}
			# LevelSim checks its auto policy every DT (0.05 s) at the top of a step: every 2nd substep.
			if step(run, path, bot, DT, steps % 2 == 0):
				ults += 1
			run.effects._process(DT)
			steps += 1
			if marks.is_empty() and run.state == Run.State.CLASH:
				marks.merge({"d": run.d, "kills": float(run.stats["kills_total"]), "army": float(run.army), "t": run.t})
		await tree.process_frame
	return {}


## The engine stops stepping `run` (the caller does, at a fixed dt); the hero starts on the path.
static func begin(run: Run, path: PackedFloat32Array) -> void:
	run.set_process(false)
	run.hx = LevelSim.path_x(path, 0.0)
	run.target_x = run.hx
	run.start()


## One fixed step of `dt` (<= Run.MAX_FRAME): steer a spring-lag ahead on the path (RUN_SPEED x
## STEER_HALFLIFE / ln 2, so the critically damped follow lands on the path), fire the ult when
## `ult_check` and the shared auto policy (LevelSim.ult_worth on the bot's snapshot) says so, then
## Run._process(dt) (its substeps and visuals). `steer_x` < INF steers there instead of the path (dev
## stills). True when the ult fired.
static func step(run: Run, path: PackedFloat32Array, bot: Bot, dt: float, ult_check := true, steer_x := INF) -> bool:
	if steer_x < INF:
		run.steer_to(steer_x)
	else:
		run.steer_to(LevelSim.path_x(path, run.d + Balance.RUN_SPEED * Balance.STEER_HALFLIFE / log(2.0)))
	var fired := false
	if ult_check and run.ult_ready():
		var snap := bot.snapshot(run, false)
		fired = LevelSim.ult_worth(snap[0], snap[1]) and run.use_ult()
	run._process(dt)
	return fired


## The Run's war-machine kills so far (stats.kills_by_machine summed; LevelSim keeps no breakdown).
static func machine_kills(run: Run) -> float:
	var n := 0.0
	var km: Dictionary = run.stats["kills_by_machine"]
	for id: String in km:
		n += float(km[id])
	return n


## True once the fortress fell (the stairs follow) or the run is lost.
static func over(run: Run) -> bool:
	return run.state == Run.State.STAIRS or run.state == Run.State.WON or run.state == Run.State.LOST


## Sums of the champion counters: {n, kills, heals, blocks, falls}.
static func tally(members: Array) -> Dictionary:
	var o := {"n": members.size(), "kills": 0.0, "heals": 0.0, "blocks": 0.0, "falls": 0.0}
	for m: Dictionary in members:
		o["kills"] = float(o["kills"]) + float(m["kills"])
		o["heals"] = float(o["heals"]) + float(m["heals"])
		o["blocks"] = float(o["blocks"]) + float(m["blocks"])
		o["falls"] = float(o["falls"]) + (0.0 if bool(m["alive"]) else 1.0)
	return o


## |a - b| / max(b, 1).
static func gap(a: float, b: float) -> float:
	return absf(a - b) / maxf(b, 1.0)


## The army at the fortress (0 when the run never got there).
static func _fort(v: float) -> float:
	return maxf(v, 0.0)


# ------------------------------------------------------------------ report

func _report(r: Dictionary) -> void:
	var cv := curves(r["run_samples"], r["sim_samples"], float(r["sim_kills"]))
	r["curve"] = cv[0]
	r["split"] = cv[1]
	r["pass"] = true
	_rows.append(r)
	var a: Dictionary = r["run"]
	var b: Dictionary = r["sim"]
	print("  %-4d %-4d %-5s %-8s | %6.0f %7.1f | %5.1f%% | %4.0f/%-4.0f | %4.0f/%-4.0f | %2.0f/%-2.0f | %d/%d | %s/%s | %4.0f/%-6.1f | %5.1f/%-5.1f | %s" % [
			int(r["seed"]), int(r["level"]), str(r["hero"]), str(r["setup"]), float(r["run_kills"]),
			float(r["sim_kills"]), float(r["curve"]) * 100.0, float(a["kills"]), float(b["kills"]),
			float(a["heals"]), float(b["heals"]), float(a["blocks"]), float(b["blocks"]), int(a["falls"]),
			int(b["falls"]), "W" if bool(r["run_won"]) else "L", "W" if bool(r["sim_won"]) else "L",
			float(r["run_fort"]), float(r["sim_fort"]), float(r["run_t"]), float(r["sim_t"]),
			("%.0f" % float(r["split"])) if float(r["split"]) >= 0.0 else "-"])
	if _verbose and str(r["team"]) != "":
		print("       team %s, ults fired in the Run %d" % [str(r["team"]), int(r["ults"])])
	if str(r["setup"]) == "none":
		_drift(r)
	if _trace:
		var ra: Array = r["run_samples"]
		var sa: Array = r["sim_samples"]
		var rm: Array = r["run_machines"]
		for i in maxi(ra.size(), sa.size()):
			var p: Vector4 = ra[i] if i < ra.size() else Vector4(-1, -1, -1, -1)
			var q: Vector4 = sa[i] if i < sa.size() else Vector4(-1, -1, -1, -1)
			print("       d %5.0f  kills %6.1f / %-6.1f (run machines %5.1f)  army %5.0f / %-7.1f t %5.1f / %-5.1f" % [
					maxf(p.x, q.x), p.y, q.y, float(rm[i]) if i < rm.size() else -1.0, p.z, q.z, p.w, q.w])


## META1_DRIFT (no team; printed, never asserted): the Run vs LevelSim with its own crate draws (the
## same inputs a player and the bot / level_check have), then the fortress army with the Run's crates.
func _drift(r: Dictionary) -> void:
	var rf: Dictionary = r["run_first"]
	var sf: Dictionary = r["own_first"]
	var first := "no clash"
	if not rf.is_empty() and not sf.is_empty():
		first = "first clash at d %.1f / %.1f with kills %.0f / %.1f (ranged ratio %.2f), army %.0f / %.1f" % [
				float(rf["d"]), float(sf["d"]), float(rf["kills"]), float(sf["kills"]),
				float(rf["kills"]) / maxf(float(sf["kills"]), 1.0), float(rf["army"]), float(sf["army"])]
	var cv := curves(r["run_samples"], r["own_samples"], float(r["own_kills"]))
	print("       META1_DRIFT L%d %s: fort %.0f / %.1f (%+.0f); curve %.1f%%; %s; hazard losses %.0f / %.1f; clash losses %.0f / %.1f; crates drawn differently %d of %d (with the Run's crates: fort sim %.1f, %+.0f)" % [
			int(r["level"]), str(r["hero"]), _fort(float(r["run_fort"])), _fort(float(r["own_fort"])),
			_fort(float(r["run_fort"])) - _fort(float(r["own_fort"])), float(cv[0]) * 100.0, first,
			float(r["run_haz"]), float(r["own_haz"]), float(r["run_clash"]), float(r["own_clash"]), int(r["crates_differ"]),
			int(r["crates"]), _fort(float(r["sim_fort"])), _fort(float(r["run_fort"])) - _fort(float(r["sim_fort"]))])


## The H2 assertion for one (seed, hero): every team setup's deltas against "none" (see the header).
func _judge(group: Dictionary) -> void:
	if not group.has("none"):
		return
	var base: Dictionary = group["none"]
	for setup: String in group:
		if setup == "none":
			continue
		var r: Dictionary = group[setup]
		var ra: Dictionary = r["run"]
		var sa: Dictionary = r["sim"]
		var d := {
			"army": [_fort(float(r["run_fort"])) - _fort(float(base["run_fort"])),
					_fort(float(r["sim_fort"])) - _fort(float(base["sim_fort"]))],
			"kills": [float(r["run_kills"]) - float(base["run_kills"]), float(r["sim_kills"]) - float(base["sim_kills"])],
			"ck": [float(ra["kills"]), float(sa["kills"])],
			"heals": [float(ra["heals"]), float(sa["heals"])],
			"blocks": [float(ra["blocks"]), float(sa["blocks"])],
			"falls": [float(ra["falls"]), float(sa["falls"])],
		}
		var ok := true
		var parts: PackedStringArray = PackedStringArray()
		var row := {"level": r["level"], "hero": r["hero"], "setup": setup, "cols": {}}
		for col in COLUMNS:
			var p: Array = d[col]
			var dr := float(p[0])
			var ds := float(p[1])
			var tol := maxf(TOL * maxf(absf(dr), absf(ds)), float(FLOOR[col]))
			var g := absf(dr - ds)
			var fine := g <= tol + 1e-6
			ok = ok and fine
			(row["cols"] as Dictionary)[col] = [dr, ds, g, tol, fine]
			parts.append("%s %+.0f/%+.1f%s" % [col, dr, ds, "" if fine else " (gap %.1f > %.1f)" % [g, tol]])
		row["ok"] = ok
		r["pass"] = ok
		r["d_army"] = d["army"]
		r["d_kills"] = d["kills"]
		_deltas.append(row)
		if not ok:
			_fails += 1
		print("       DELTA %s L%d %s %s: %s" % ["ok" if ok else "FAIL", int(r["level"]), str(r["hero"]), setup,
				" · ".join(parts)])


func _summary(secs: float) -> void:
	var by_setup := {}
	var by_col := {}
	for col in COLUMNS:
		by_col[col] = [0, 0, 0.0, ""]
	for row: Dictionary in _deltas:
		var bs: Array = by_setup.get(str(row["setup"]), [0, 0])
		bs[0] = int(bs[0]) + 1
		bs[1] = int(bs[1]) + (1 if bool(row["ok"]) else 0)
		by_setup[str(row["setup"])] = bs
		for col in COLUMNS:
			var c: Array = (row["cols"] as Dictionary)[col]
			var bc: Array = by_col[col]
			bc[0] = int(bc[0]) + 1
			bc[1] = int(bc[1]) + (1 if bool(c[4]) else 0)
			if float(c[2]) - float(c[3]) > float(bc[2]):
				bc[2] = float(c[2]) - float(c[3])
				bc[3] = "L%d %s %s %+.0f/%+.1f" % [int(row["level"]), str(row["hero"]), str(row["setup"]), float(c[0]),
						float(c[1])]
	for key: String in by_setup:
		var bs: Array = by_setup[key]
		print("TEST_KIND_PARITY_SETUP %-8s %d/%d team cases match on every column" % [key, int(bs[1]), int(bs[0])])
	for col in COLUMNS:
		var bc: Array = by_col[col]
		print("TEST_KIND_PARITY_COLUMN %-6s %d/%d within, worst excess %.1f%s" % [col, int(bc[1]), int(bc[0]),
				float(bc[2]), (" (" + str(bc[3]) + ")") if str(bc[3]) != "" else ""])
	var drift := [0.0, 0.0, 0, 0.0, 0.0, 0.0, 0, 0]
	for r: Dictionary in _rows:
		if str(r["setup"]) != "none":
			continue
		drift[0] = float(drift[0]) + _fort(float(r["run_fort"]))
		drift[1] = float(drift[1]) + _fort(float(r["own_fort"]))
		drift[2] = int(drift[2]) + 1
		drift[3] = float(drift[3]) + float(r["run_haz"])
		drift[4] = float(drift[4]) + float(r["own_haz"])
		drift[5] = float(drift[5]) + _fort(float(r["sim_fort"]))
		drift[6] = int(drift[6]) + int(r["crates_differ"])
		drift[7] = int(drift[7]) + int(r["crates"])
	print("TEST_KIND_PARITY_META1_DRIFT %d no-team cases: army at the fortress run / sim %.0f / %.0f (%+.1f%%; with the Run's crates %.0f, %+.1f%%), hazard losses %.0f / %.0f, crates drawn differently %d of %d (not asserted)" % [
			int(drift[2]), float(drift[0]), float(drift[1]), 100.0 * (float(drift[0]) - float(drift[1])) / maxf(float(drift[1]), 1.0),
			float(drift[5]), 100.0 * (float(drift[0]) - float(drift[5])) / maxf(float(drift[5]), 1.0), float(drift[3]),
			float(drift[4]), int(drift[6]), int(drift[7])])
	print("TEST_KIND_PARITY %s: %d cases (%d team deltas), %d failed, %.0f s" % ["PASS" if _fails == 0 else "FAIL",
			_rows.size(), _deltas.size(), _fails, secs])


func _write(dir: String) -> void:
	for r: Dictionary in _rows:
		var a: Dictionary = r["run"]
		var b: Dictionary = r["sim"]
		var da: Array = r.get("d_army", [0.0, 0.0])
		var dk: Array = r.get("d_kills", [0.0, 0.0])
		_csv.append("%d,%d,%s,%s,%s,%.1f,%.2f,%.4f,%.1f,%.2f,%.1f,%.2f,%d,%d,%d,%d,%s,%s,%.2f,%.2f,%d,%.2f,%.0f,%.2f,%.1f,%.2f,%.0f,%.2f,%.0f,%d,%.1f,%.1f,%.2f,%.1f,%.2f,%s" % [
				int(r["seed"]), int(r["level"]), str(r["hero"]), str(r["setup"]), str(r["team"]), float(r["run_kills"]),
				float(r["sim_kills"]), float(r["curve"]), float(a["kills"]), float(b["kills"]), float(a["heals"]),
				float(b["heals"]), int(a["blocks"]), int(b["blocks"]), int(a["falls"]), int(b["falls"]), str(r["run_won"]),
				str(r["sim_won"]), float(r["run_t"]), float(r["sim_t"]), int(r["run_army"]), float(r["sim_army"]),
				float(r["run_fort"]), float(r["sim_fort"]), float(r["run_haz"]), float(r["sim_haz"]), float(r["run_clash"]),
				float(r["sim_clash"]), float(r["split"]), int(r["ults"]), float(r["run_mk"]), float(da[0]), float(da[1]),
				float(dk[0]), float(dk[1]), str(r["pass"])])
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("kind_parity.csv")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("test_kind_parity: cannot write " + path)
		return
	f.store_string("\n".join(_csv) + "\n")
	f.close()
	print("TEST_KIND_PARITY written ", path)
