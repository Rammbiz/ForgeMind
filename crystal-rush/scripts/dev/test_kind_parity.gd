extends Node
## test_kind_parity (heroes design §10.4, §12.6 #9): the real Run and LevelSim play the same level on
## the same fixed input path and must agree on the kills, so the bot, level_check and the planner can
## trust the one rules implementation (HeroKinds / ChampionKinds over a KindView).
##
## Cases: seeds x heroes x team setups. A seed is a campaign level (LevelGen is deterministic per
## level; seed k plays LEVELS[k], all >= 41 so the 4-member team is legal on every one). Heroes: the
## three that run today (bolt, titan, seer). Setups: "none" (no champions), "expected" (the synthetic
## EXPECTED account's pair, Meta.team_block_of through Meta.run_profile, as champ_survival builds it) and
## "four" (borko, taya, ivo, mila: Warrior front, Mage, Guardian, Healer). Phase H2 is forced
## (EconData.phase_override, restored at the end); the account is swapped into Meta for each case so
## the Run reads its profile through the normal Meta.run_profile path, and LevelSim gets that very
## profile dictionary.
##
## Input: one path per (seed, hero), LevelSim.best_path planned once with the "expected" profile and
## replayed unchanged by every setup. (a) the Run, headless, stepped by this test at its own SUBSTEP
## (1 / 40 s, no frame-time noise), steered with Run.steer_to toward the path x a spring-lag ahead
## (RUN_SPEED x STEER_HALFLIFE / ln 2, so the critically damped follow lands on the path); the ult is
## fired by the shared auto policy (LevelSim.ult_worth on the bot's snapshot of the live run, the same
## rule LevelSim's auto_ult applies). (b) LevelSim.simulate on the same path and profile. No bot
## re-planning anywhere. Both stop when the fortress falls or the run is lost.
##
## Compared per case: total kills (Run stats.kills_total vs State.kills: squad hp removed by every
## source), the kills curve (the worst kills gap at the CHECK_EVERY checkpoints, over the final sim
## kills), the army left at the end and the first checkpoint where the two armies split, champion
## kills, heals, blocks and falls (the members' counters), won and run time. Asserted: |Run - Sim| /
## max(Sim, 1) <= 3% for total kills, every case; everything else is a printed measurement (--trace
## prints every case's checkpoints: d, kills, the Run's war-machine kills, army, time).
##
##   godot --headless --path . res://scenes/dev/test_kind_parity.tscn -- --autotest [--quick]
##        [--seeds=10] [--levels=41,45] [--heroes=bolt,titan,seer] [--setups=none,expected,four]
##        [--out=DIR] [--verbose] [--trace]
## --quick = 2 seeds. Exit code = failures. Last line: TEST_KIND_PARITY PASS|FAIL: <cases>, <failed>,
## worst gap, time. --out writes kind_parity.csv (one row per case). About 5 s per (seed, hero) plan
## and 2-4 s per Run case on a desktop: the full 90 cases take ~6-8 min.

const CS := preload("res://scripts/dev/champ_survival.gd")
## Seed k -> campaign level (all >= 41: the 4-member team needs the third slot, UNLOCK_AT.slot3 = 40).
const LEVELS: Array[int] = [41, 42, 43, 44, 45, 46, 47, 50, 53, 55]
const HEROES: Array[String] = ["bolt", "titan", "seer"]
const SETUPS: Array[String] = ["none", "expected", "four"]
const FOUR: Array[String] = ["borko", "taya", "ivo", "mila"]
## The rule (§10.4): |Run - Sim| / max(Sim, 1) for total kills.
const TOL := 0.03
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

var _fails := 0
var _verbose := false
var _trace := false
var _checked_sim := false
var _bot := Bot.new()
var _rows: Array = []
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
	Save.readonly = true
	var old_phase := EconData.phase_override
	var old_hitstop := Juice.hitstop_enabled
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	Juice.hitstop_enabled = false
	var t0 := Time.get_ticks_msec()
	print("TEST_KIND_PARITY seeds (levels) %s x heroes %s x setups %s, rule |Run - Sim| / max(Sim, 1) <= %d%%" % [
			str(levels), ",".join(heroes), ",".join(setups), int(TOL * 100.0)])
	_csv.append("seed,level,hero,setup,team,run_kills,sim_kills,gap,curve,run_ck,sim_ck,run_heals,sim_heals," +
			"run_blocks,sim_blocks,run_falls,sim_falls,run_won,sim_won,run_t,sim_t,run_army,sim_army,army_split_d," +
			"ult_run,run_machine_kills,pass")
	print("  kills = squad hp removed by every source (run / sim, gap = |run - sim| / max(sim, 1), the asserted")
	print("  column); curve = worst kills gap at the %.0f u checkpoints; champion columns run/sim; army = left at" % CHECK_EVERY)
	print("  the end; split = first checkpoint d where the armies differ by > %d%%." % int(ARMY_SPLIT * 100.0))
	print("  %-4s %-4s %-5s %-8s | %6s %7s %6s | %6s | %9s | %9s | %5s | %3s | %3s | %11s | %11s | %s" % ["seed",
			"lvl", "hero", "setup", "run", "sim", "gap", "curve", "champ k", "heals", "blck", "fal", "won", "army",
			"time", "split"])
	for k in levels.size():
		for hero in heroes:
			var path := _plan(levels[k], hero)
			for setup in setups:
				var row: Dictionary = await _case(k, levels[k], hero, setup, path)
				_report(row)
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


# ------------------------------------------------------------------ the case

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
	var res := await drive(run, path, _bot, MAX_T, CHECK_EVERY, run_samples, run_machines)
	var mk := machine_kills(run)
	var sim_samples: Array = []
	var s := simulate(level_of(level), hero, path, prof, CHECK_EVERY, sim_samples)
	if not _checked_sim:
		# Once: the sampled stepping here is LevelSim.simulate exactly.
		_checked_sim = true
		var ref := LevelSim.simulate(level_of(level), hero, Balance.START_ARMY, path, {"profile": prof})
		if ref.kills != s.kills or ref.t != s.t or ref.army != s.army:
			_fails += 1
			print("  FAIL the sampled sim differs from LevelSim.simulate (kills %.2f vs %.2f)" % [s.kills, ref.kills])
	var team: PackedStringArray = PackedStringArray()
	for m: Dictionary in run.champions.members:
		team.append("%s:%s" % [str(m["id"]), str(m["slot"])])
	var row := {"seed": seed_k, "level": level, "hero": hero, "setup": setup, "team": " ".join(team),
			"run_kills": float(run.stats["kills_total"]), "sim_kills": s.kills,
			"run": tally(run.champions.members), "sim": tally(s.champs.members),
			"run_won": run.state != Run.State.LOST and bool(res["ended"]), "sim_won": s.mode == LevelSim.Mode.WON,
			"run_t": run.t, "sim_t": s.t, "run_army": run.army, "sim_army": s.army, "ults": int(res["ults"]),
			"run_samples": run_samples, "sim_samples": sim_samples, "run_machines": run_machines, "run_mk": mk}
	remove_child(run)
	run.free()
	return row


## LevelSim.simulate (start_state, the path's first x, advance to length + 50 at DT for at most 600 s)
## stepped here so `samples` gets the same Vector4(d, kills, army, t) checkpoints as drive().
static func simulate(lv: LevelSim.Level, hero: String, path: PackedFloat32Array, prof: Dictionary, every: float,
		samples: Array) -> LevelSim.State:
	var s := LevelSim.start_state(lv, hero, Balance.START_ARMY, {"profile": prof})
	s.hx = LevelSim.path_x(path, 0.0)
	s.ax = s.hx
	var next := every
	var d_end := lv.length + 50.0
	while s.mode != LevelSim.Mode.WON and s.mode != LevelSim.Mode.LOST and s.d < d_end and s.t < MAX_T:
		if every > 0.0 and s.d >= next:
			samples.append(Vector4(next, s.kills, s.army, s.t))
			next += every
		LevelSim.step(lv, s, path, LevelSim.DT)
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
## multiple of `every`. Returns {ended, ults, steps}.
static func drive(run: Run, path: PackedFloat32Array, bot: Bot, max_t := MAX_T, every := 0.0,
		samples: Array = [], machines: Array = []) -> Dictionary:
	begin(run, path)
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
			steps += 1
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


# ------------------------------------------------------------------ report

func _report(r: Dictionary) -> void:
	var g := gap(float(r["run_kills"]), float(r["sim_kills"]))
	var ok := g <= TOL + 1e-6
	if not ok:
		_fails += 1
	r["gap"] = g
	r["pass"] = ok
	var cv := curves(r["run_samples"], r["sim_samples"], float(r["sim_kills"]))
	r["curve"] = cv[0]
	r["split"] = cv[1]
	_rows.append(r)
	var a: Dictionary = r["run"]
	var b: Dictionary = r["sim"]
	print("  %-4d %-4d %-5s %-8s | %6.0f %7.1f %5.1f%% | %5.1f%% | %4.0f/%-4.0f | %4.0f/%-4.0f | %2.0f/%-2.0f | %d/%d | %s/%s | %4.0f/%-6.1f | %5.1f/%-5.1f | %s%s" % [
			int(r["seed"]), int(r["level"]), str(r["hero"]), str(r["setup"]), float(r["run_kills"]),
			float(r["sim_kills"]), g * 100.0, float(r["curve"]) * 100.0, float(a["kills"]), float(b["kills"]),
			float(a["heals"]), float(b["heals"]), float(a["blocks"]), float(b["blocks"]), int(a["falls"]),
			int(b["falls"]), "W" if bool(r["run_won"]) else "L", "W" if bool(r["sim_won"]) else "L",
			float(r["run_army"]), float(r["sim_army"]), float(r["run_t"]), float(r["sim_t"]),
			("%.0f" % float(r["split"])) if float(r["split"]) >= 0.0 else "-", "" if ok else "  FAIL"])
	if _verbose and str(r["team"]) != "":
		print("       team %s, ults fired in the Run %d" % [str(r["team"]), int(r["ults"])])
	if _trace:
		var ra: Array = r["run_samples"]
		var sa: Array = r["sim_samples"]
		var rm: Array = r["run_machines"]
		for i in maxi(ra.size(), sa.size()):
			var p: Vector4 = ra[i] if i < ra.size() else Vector4(-1, -1, -1, -1)
			var q: Vector4 = sa[i] if i < sa.size() else Vector4(-1, -1, -1, -1)
			print("       d %5.0f  kills %6.1f / %-6.1f (run machines %5.1f)  army %5.0f / %-7.1f t %5.1f / %-5.1f" % [
					maxf(p.x, q.x), p.y, q.y, float(rm[i]) if i < rm.size() else -1.0, p.z, q.z, p.w, q.w])
	_csv.append("%d,%d,%s,%s,%s,%.1f,%.2f,%.4f,%.4f,%.1f,%.2f,%.1f,%.2f,%d,%d,%d,%d,%s,%s,%.2f,%.2f,%d,%.2f,%.0f,%d,%.1f,%s" % [
			int(r["seed"]), int(r["level"]), str(r["hero"]), str(r["setup"]), str(r["team"]), float(r["run_kills"]),
			float(r["sim_kills"]), g, float(r["curve"]), float(a["kills"]), float(b["kills"]), float(a["heals"]),
			float(b["heals"]), int(a["blocks"]), int(b["blocks"]), int(a["falls"]), int(b["falls"]), str(r["run_won"]),
			str(r["sim_won"]), float(r["run_t"]), float(r["sim_t"]), int(r["run_army"]), float(r["sim_army"]),
			float(r["split"]), int(r["ults"]), float(r["run_mk"]), str(ok)])


func _summary(secs: float) -> void:
	var worst := 0.0
	var worst_case := ""
	var by_setup := {}
	var ck := [0.0, 0.0]
	var heals := [0.0, 0.0]
	var blocks := [0.0, 0.0]
	var falls := [0.0, 0.0]
	var won_diff := 0
	for r: Dictionary in _rows:
		var g := float(r["gap"])
		if g > worst:
			worst = g
			worst_case = "L%d %s %s" % [int(r["level"]), str(r["hero"]), str(r["setup"])]
		var bs: Array = by_setup.get(str(r["setup"]), [0, 0, 0.0])
		bs[0] = int(bs[0]) + 1
		bs[1] = int(bs[1]) + (1 if bool(r["pass"]) else 0)
		bs[2] = maxf(float(bs[2]), g)
		by_setup[str(r["setup"])] = bs
		for pair: Array in [[ck, "kills"], [heals, "heals"], [blocks, "blocks"], [falls, "falls"]]:
			var acc: Array = pair[0]
			acc[0] = float(acc[0]) + float((r["run"] as Dictionary)[pair[1]])
			acc[1] = float(acc[1]) + float((r["sim"] as Dictionary)[pair[1]])
		if bool(r["run_won"]) != bool(r["sim_won"]):
			won_diff += 1
	for key: String in by_setup:
		var bs: Array = by_setup[key]
		print("TEST_KIND_PARITY_SETUP %-8s %d/%d within %d%%, worst %.1f%%" % [key, int(bs[1]), int(bs[0]),
				int(TOL * 100.0), float(bs[2]) * 100.0])
	print("TEST_KIND_PARITY_CHAMPS totals run / sim: kills %.0f / %.0f (%+.1f%%), heals %.0f / %.0f (%+.1f%%), blocks %.0f / %.0f, falls %.0f / %.0f; won differs in %d cases" % [
			ck[0], ck[1], _signed(ck), heals[0], heals[1], _signed(heals), blocks[0], blocks[1], falls[0], falls[1], won_diff])
	print("TEST_KIND_PARITY %s: %d cases, %d failed, worst gap %.1f%% (%s), %.0f s" % ["PASS" if _fails == 0 else "FAIL",
			_rows.size(), _fails, worst * 100.0, worst_case, secs])


static func _signed(p: Array) -> float:
	return 100.0 * (float(p[0]) - float(p[1])) / maxf(float(p[1]), 1.0)


func _write(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("kind_parity.csv")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("test_kind_parity: cannot write " + path)
		return
	f.store_string("\n".join(_csv) + "\n")
	f.close()
	print("TEST_KIND_PARITY written ", path)
