extends Node
## demand_bake: re-bakes TEAM_DEMAND (heroes design §8.2, P4, §15 R5) in LevelSim with the real kits. Run it again
## whenever the kits, the EXPECTED profile or Meta-2 (Affinity) change; the lead adopts the numbers (see below).
##
## For every sampled level and hero the same planner (LevelSim.best_path, level_check's) plays twice:
##   p0  the Meta-1 EXPECTED account at phase 0 (Meta.synthetic_account "expected" led by the hero; Meta.run_profile:
##       the Meta-1 hero block, no team) on the level as built (m = 1): the target;
##   p2  the EXPECTED profile with the heroes system on, phase HEROES_RUN_PHASE (champ_survival.account_for: the same
##       synthetic account led by the hero, the two scripted champions; Meta.run_profile: the hero's v3 block and
##       the team block, as a dev run builds them) on the level with its enemy side x m (LevelGen.scale_enemies).
## m is the multiplier at which p2 does exactly as well as p0, by bisection on the outcome (`--measure`):
##   margin (default)  the win margin over the enemy budget: survivors / fortress hp on a win, -(fortress hp left) /
##                     fortress hp on a loss. The LevelSim reading of heroes_sim.calibrate_tf's power / demand ratio:
##                     with every soldier figure of a side x k it gives m = k, and it counts what the team does in the
##                     clashes and the siege.
##   fort              the fortress army ratio: army at the fortress / fortress hp (the siege itself left out).
## Per world (campaign W1-W7 = "1".."7", Invasion W1-W7 = "8".."14", TeamData.TEAM_DEMAND keys) the median of the
## per (level, hero) values is the measured multiplier. Then the check: p2 at the adopted TEAM_DEMAND and at the
## measured value, the planner (win, army at the fortress, survivors) and `--random` random paths (level_check's
## LevelSim.random_path, seed 1000 + level) as a rough human win rate, next to p0's.
##
##   godot --headless --path . res://scenes/dev/demand_bake.tscn -- --autotest [--worlds=1,2,..,14] [--pos=2,4,6,8]
##        [--levels=20,41] [--heroes=bolt,titan] [--measure=margin|fort] [--lo=0.8] [--hi=1.6] [--tol=0.01]
##        [--random=8] [--check=1] [--grid=0.9,1,1.1] [--use=1:1.04,2:1.05] [--rgrid=1,1.1,1.2] [--inv_fix=1]
##        [--out=DIR]
##   ... -- --autotest --merge=DIR
## --pos = the levels sampled in each world (level in world 1..8; 8 = the boss); --levels replaces the sampling.
## --grid prints the outcome at those m (no bisection, no check); --use runs only the check, against those m;
## --rgrid measures random-path win rates only (_rgrid: the sloppy-play reading of the same question);
## --inv_fix lifts the synthetic account's world caps on Invasion levels (invasion_fix); --merge pools the DB
## lines of split runs (_merge). `--autotest` keeps the save read-only; the phase is forced per run
## (EconData.phase_override) and restored. A (level, hero) costs 7-10 planner runs of ~8 s (about 70 s with the
## check); keep a run under ~10 min by splitting the worlds over parallel runs, then --merge their --out files.
## The H2 bake (2026-10-10): --pos=2,4,6,8 (every 2nd level), bolt + titan, --inv_fix, 112 (level, hero) pairs.
##
## Lines: DB (one per level and hero), DEMAND_BAKE_WORLD (per world: adopted, measured, delta, n), DEMAND_BAKE_CHECK
## (per world: p0 / p2 at adopted / p2 at measured), DEMAND_BAKE_MERGE, DEMAND_BAKE_JSON (the measured or, with
## --merge, the pooled values, rounded to 3 decimals). Exit 0.
##
## Adopting (the lead decides): the values go into tools/data/heroes_consts.json "team_demand" through
## heroes_sim.LEVELSIM_TEAM_DEMAND (export_consts writes it, so a later `heroes_sim.py --export` keeps the bake),
## then `gen_heroes_data.py --refresh` (TeamData.TEAM_DEMAND) and `gen_save_v3_data.py` (its consts stamp).

const CS := preload("res://scripts/dev/champ_survival.gd")
## Bracket step of the bisection (from m = 1 / the adopted value).
const STEP := 0.05

static var inv_fix := false       ## --inv_fix=1 (invasion_fix)

var _args := {}
var _lines: PackedStringArray = PackedStringArray()
var _measure := "margin"
var _evals := 0
var _plays := {}                  ## "level:hero:m" -> p2's outcome (p2_at)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_measure = str(_args.get("measure", "margin"))
	var heroes: Array[String] = []
	for h in str(_args.get("heroes", "bolt,titan")).split(",", false):
		if Balance.HEROES.has(h):
			heroes.append(h)
	var levels := _levels()
	var lo := float(_args.get("lo", "0.8"))
	var hi := float(_args.get("hi", "1.6"))
	var tol := float(_args.get("tol", "0.01"))
	var randoms := int(_args.get("random", "8"))
	var old_phase := EconData.phase_override
	var t0 := Time.get_ticks_msec()
	if _args.has("merge"):
		_merge(str(_args["merge"]))
		_finish(t0)
		return
	_say("DEMAND_BAKE measure=%s heroes=%s levels=%s lo=%.2f hi=%.2f tol=%.3f" % [_measure, ",".join(heroes),
			str(levels), lo, hi, tol])
	inv_fix = int(_args.get("inv_fix", "0")) != 0
	if _args.has("grid"):
		_grid(levels, heroes)
		EconData.phase_override = old_phase
		_finish(t0)
		return
	if _args.has("use"):
		_check(_rows_p0(levels, heroes), _use(), randoms)
		EconData.phase_override = old_phase
		_finish(t0)
		return
	if _args.has("rgrid"):
		_rgrid(levels, heroes, randoms)
		EconData.phase_override = old_phase
		_finish(t0)
		return
	# Per (level, hero): {level, hero, world, p0 (outcome dict), m, flag}.
	var rows: Array[Dictionary] = []
	for level in levels:
		for hero in heroes:
			var row := _solve(level, hero, lo, hi, tol)
			rows.append(row)
			_say("DB L%3d %-6s %-5s %s | p0 %s | p2@1 %s | p2 hero alone@1 %s | m %.3f%s (%d runs)%s" % [level,
					_wname(int(row["world"])), hero, _team(row["prof2"]), _fmt(row["p0"]), _fmt(row["p2_1"]),
					_fmt(row["solo"]), float(row["m"]), str(row["flag"]), int(row["evals"]),
					" inv_fix" if inv_fix and level > ArsenalData.CAMPAIGN_LEVELS else ""])
	var measured := {}
	for w: int in _worlds_of(rows):
		var ms: Array[float] = []
		var per_hero := PackedStringArray()
		for hero in heroes:
			var mh: Array[float] = []
			for r: Dictionary in rows:
				if int(r["world"]) == w and str(r["hero"]) == hero and not bool(r["skip"]):
					mh.append(float(r["m"]))
					ms.append(float(r["m"]))
			per_hero.append("%s %s" % [hero, "%.3f" % _median(mh) if not mh.is_empty() else "n/a"])
		if ms.is_empty():
			continue
		measured[w] = _median(ms)
		var adopted := float(TeamData.TEAM_DEMAND.get(str(w), 1.0))
		_say("DEMAND_BAKE_WORLD %-6s adopted %.3f measured %.3f delta %+.3f n %d (%s; min %.3f max %.3f)" % [
				_wname(w), adopted, float(measured[w]), float(measured[w]) - adopted, ms.size(), ", ".join(per_hero),
				ms.min(), ms.max()])
	if int(_args.get("check", "1")) != 0:
		_check(rows, measured, randoms)
	var js := {}
	for w: int in measured:
		js[str(w)] = snappedf(float(measured[w]), 0.001)
	_say("DEMAND_BAKE_JSON " + JSON.stringify(js))
	EconData.phase_override = old_phase
	_finish(t0)


## The sampled levels: --levels, else --pos of every world in --worlds (Invasion worlds 8-14 = levels 57-112).
func _levels() -> Array[int]:
	var out: Array[int] = []
	if _args.has("levels"):
		for p in str(_args["levels"]).split(",", false):
			out.append(int(p))
		return out
	var pos: Array[int] = []
	for p2 in str(_args.get("pos", "2,4,6,8")).split(",", false):
		pos.append(clampi(int(p2), 1, ArsenalData.LEVELS_PER_WORLD))
	for wv in str(_args.get("worlds", "1,2,3,4,5,6,7,8,9,10,11,12,13,14")).split(",", false):
		var w := int(wv)
		var base := (w - 1) * ArsenalData.LEVELS_PER_WORLD if w <= 7 else ArsenalData.CAMPAIGN_LEVELS + (w - 8) \
				* ArsenalData.LEVELS_PER_WORLD
		for p3 in pos:
			out.append(base + p3)
	return out


## TeamData.TEAM_DEMAND key of `level` (as LevelGen.team_demand reads it).
static func world_key(level: int) -> int:
	return ArsenalData.world_of(level) + (7 if level > ArsenalData.CAMPAIGN_LEVELS else 0)


# ------------------------------------------------------------------ profiles and plays

## Meta.run_profile(level) for `acc` led by `hero` (the account and Save.hero swapped in, restored), under the
## phase in effect: phase 0 gives the Meta-1 hero block, HEROES_RUN_PHASE the v3 block and the team block.
static func run_profile_of(acc: Dictionary, level: int, hero: String) -> Dictionary:
	var keep := [Meta.account, str(Save.hero)]
	Meta.account = acc
	Save.hero = hero
	var prof: Dictionary = Meta.run_profile(level)
	Meta.account = keep[0]
	Save.hero = str(keep[1])
	return prof


## The Meta-1 EXPECTED profile (phase 0) of `level` led by `hero`. Leaves the phase at 0.
static func profile_p0(level: int, hero: String) -> Dictionary:
	EconData.phase_override = 0
	var acc := Meta.synthetic_account(level, "expected")
	(acc["progress"] as Dictionary)["hero"] = hero
	invasion_fix(acc, level)
	return run_profile_of(acc, level, hero)


## The EXPECTED profile with the heroes system on (HEROES_RUN_PHASE) of `level` led by `hero`. Leaves the phase there.
static func profile_p2(level: int, hero: String) -> Dictionary:
	EconData.phase_override = EconData.HEROES_RUN_PHASE
	var acc := CS.account_for(level, "expected", hero)
	invasion_fix(acc, level)
	return run_profile_of(acc, level, hero)


## --inv_fix: Meta.synthetic_account caps the EXPECTED hero level and Barracks by world_of(level), which starts
## again at 1 past CAMPAIGN_LEVELS (the hero at L60 is Lv9, at L56 Lv15); a real account keeps world_reached 7
## and the Invasion hero cap. With the flag, an Invasion level's account gets world_reached 7, its leveled
## heroes the EXPECTED hero level under the Invasion cap and its Barracks the EXPECTED row under the W7 cap.
static func invasion_fix(acc: Dictionary, level: int) -> void:
	if not inv_fix or level <= ArsenalData.CAMPAIGN_LEVELS:
		return
	var row: Dictionary = Meta._expected_row(level)
	(acc["progress"] as Dictionary)["world_reached"] = 7
	var hs: Dictionary = acc["heroes"]
	for h: String in hs:
		if h in Meta.SYNTH_HERO_ENTRIES or EconData.heroes_run():
			(hs[h] as Dictionary)["lvl"] = clampi(int(row["hero_lvl"]), 1, EconData.hero_cap(7, true))
	var bar: Dictionary = row["barracks"]
	for t in EconData.BARRACKS_ORDER:
		(acc["barracks"] as Dictionary)[t] = mini(EconData.barracks_cap(7), int(bar.get(t, 0)))


## `level` with its enemy side x m.
static func level_at(level: int, m: float) -> LevelSim.Level:
	return LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY, m), level)


## One planner run: {won, army, surv, hp (fortress), left (fortress hp left), margin, fort, reason}.
func play(lv: LevelSim.Level, hero: String, prof: Dictionary) -> Dictionary:
	_evals += 1
	var bp: Dictionary = LevelSim.best_path(lv, hero, Balance.start_army(0), {"profile": prof})
	return outcome(lv, bp["result"], bp["state"])


static func outcome(lv: LevelSim.Level, r: Dictionary, s: LevelSim.State) -> Dictionary:
	var hp := maxf(float(lv.items[lv.fortress]["value"]), 1.0)
	var won := bool(r["won"])
	var left := 0.0 if won else maxf(s.hp[lv.fortress], 0.0)
	var surv := float(r["survivors"])
	var alive := 0
	for m: Dictionary in s.champs.members:
		alive += 1 if bool(m["alive"]) else 0
	return {"won": won, "army": int(r["army_at_fortress"]), "surv": int(surv), "hp": int(hp), "left": int(left),
			"margin": surv / hp if won else -left / hp, "fort": float(r["army_at_fortress"]) / hp,
			"reason": str(r["reason"]), "champs": "%d/%d" % [alive, s.champs.members.size()]}


func _q(o: Dictionary) -> float:
	return float(o[_measure])


## p2's planner run on `level` at m (phase HEROES_RUN_PHASE), cached per (level, hero, m, `tag` of the profile).
func p2_at(level: int, hero: String, prof2: Dictionary, m: float, tag := "") -> Dictionary:
	var key := "%d:%s:%s:%.4f" % [level, hero, tag, m]
	if not _plays.has(key):
		EconData.phase_override = EconData.HEROES_RUN_PHASE
		_plays[key] = play(level_at(level, m), hero, prof2)
	return _plays[key]


## Where the difference comes from: p2's hero (its v3 kit) alone at m = 1, the team block kept, no champions.
func solo_at(level: int, hero: String, prof2: Dictionary) -> Dictionary:
	var solo := prof2.duplicate(true)
	((solo["team"] as Dictionary)["champions"] as Array).clear()
	return p2_at(level, hero, solo, 1.0, "solo")


## Bisection on m for one (level, hero): where p2's outcome (it falls as m grows) crosses p0's. The bracket starts
## from m = 1 toward the adopted TEAM_DEMAND, then steps of STEP up to `hi` / down to `lo`; bisection to `tol`.
## {level, hero, world, p0, p2_1 (p2 at m = 1), m, flag ("" | "<" lo | ">" hi), skip, evals, prof2}.
func _solve(level: int, hero: String, lo: float, hi: float, tol: float) -> Dictionary:
	var e0 := _evals
	var p0 := play(level_at(level, 1.0), hero, profile_p0(level, hero))
	var prof2 := profile_p2(level, hero)
	var target := _q(p0)
	var p21 := p2_at(level, hero, prof2, 1.0)
	var row := {"level": level, "hero": hero, "world": world_key(level), "p0": p0, "p2_1": p21, "flag": "",
			"skip": false, "prof2": prof2}
	var adopted := float(TeamData.TEAM_DEMAND.get(str(world_key(level)), 1.0))
	var good := 1.0          # largest m known to keep p2 >= p0
	var bad := 1.0           # smallest m known to put p2 below p0
	if _q(p21) >= target:
		var up := maxf(adopted, 1.0 + STEP)
		bad = INF
		while up <= hi + 0.0001:
			if _q(p2_at(level, hero, prof2, up)) >= target:
				good = up
				up += STEP * 2.0
			else:
				bad = up
				break
		if bad == INF:
			row["m"] = good
			row["flag"] = ">"
	else:
		var down := minf(adopted, 1.0 - STEP) if adopted < 1.0 else 1.0 - STEP
		good = -INF
		while down >= lo - 0.0001:
			if _q(p2_at(level, hero, prof2, down)) >= target:
				good = down
				break
			bad = down
			down -= STEP
		if good == -INF:
			row["m"] = bad
			row["flag"] = "<"
	if not row.has("m"):
		while bad - good > tol:
			var mid := (good + bad) * 0.5
			if _q(p2_at(level, hero, prof2, mid)) >= target:
				good = mid
			else:
				bad = mid
		row["m"] = (good + bad) * 0.5
	# A level the Meta-1 planner loses has no margin to match: reported, left out of the world's median.
	row["skip"] = not bool(p0["won"])
	if bool(row["skip"]):
		row["flag"] = str(row["flag"]) + " (p0 loses: skipped)"
	row["solo"] = solo_at(level, hero, prof2)
	row["evals"] = _evals - e0
	EconData.phase_override = -1
	return row


## --use=1:1.04,2:1.05,..: the multipliers to check against the adopted ones (no bisection), {world: m}.
func _use() -> Dictionary:
	var out := {}
	for p in str(_args["use"]).split(",", false):
		var kv := p.split(":")
		if kv.size() == 2:
			out[int(kv[0])] = float(kv[1])
	return out


## Rows for _check without a bisection: p0 played, p2's profile built.
func _rows_p0(levels: Array[int], heroes: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for level in levels:
		for hero in heroes:
			var p0 := play(level_at(level, 1.0), hero, profile_p0(level, hero))
			rows.append({"level": level, "hero": hero, "world": world_key(level), "p0": p0,
					"prof2": profile_p2(level, hero)})
	EconData.phase_override = -1
	return rows


## --merge=DIR: the DB lines of every .txt / .log file in DIR (name order; a later file wins a repeated level and
## hero) -> per world the median m, the 3-world pooled median (the world and its neighbours of the same mode:
## campaign W1-W7, Invasion W1-W7) and DEMAND_BAKE_JSON of the pooled values, the ones to adopt: one world's
## 4-8 samples swing by about +-0.04 (90% interval of the median), the pooled 16-24 by about +-0.025.
func _merge(dir: String) -> void:
	var re := RegEx.new()
	re.compile("^DB L\\s*(\\d+) +(?:Inv )?W\\d+\\s+(\\w+) .*?\\| p0 ([WL]) .*?\\| m ([0-9.]+)")
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	var by := {}                  # "level:hero" -> [world, m]; a level the Meta-1 planner loses is left out
	for f: String in files:
		if not (f.ends_with(".txt") or f.ends_with(".log")):
			continue
		for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
			var mt := re.search(line)
			if mt == null:
				continue
			var level := int(mt.get_string(1))
			var key := "%d:%s" % [level, mt.get_string(2)]
			by.erase(key)
			if mt.get_string(3) == "W":
				by[key] = [world_key(level), float(mt.get_string(4))]
	var per := {}                 # world -> Array[float] of m
	for key: String in by:
		var w := int(by[key][0])
		if not per.has(w):
			var fresh: Array[float] = []
			per[w] = fresh
		var ms: Array[float] = per[w]
		ms.append(float(by[key][1]))
	var js := {}
	var worlds: Array = per.keys()
	worlds.sort()
	for w: int in worlds:
		var pool: Array[float] = []
		for x in [w - 1, w, w + 1]:
			if per.has(x) and (x <= 7) == (w <= 7):
				pool.append_array(per[x])
		var own: Array[float] = per[w]
		var adopted := float(TeamData.TEAM_DEMAND.get(str(w), 1.0))
		js[str(w)] = snappedf(_median(pool), 0.001)
		_say("DEMAND_BAKE_MERGE %-6s adopted %.3f median %.3f (n %d) pooled %.3f (n %d) delta %+.3f" % [_wname(w),
				adopted, _median(own), own.size(), _median(pool), pool.size(), _median(pool) - adopted])
	_say("DEMAND_BAKE_JSON " + JSON.stringify(js))


## --rgrid=1,1.1,1.2: the sloppy-play reading. Per world, the win rate of `--random` random paths (the same paths
## for every run of a level) for p0 at m = 1 and for p2 at every listed m, and the m where p2's rate crosses p0's
## (linear between the grid points). No planner runs.
func _rgrid(levels: Array[int], heroes: Array[String], randoms: int) -> void:
	var ms: Array[float] = []
	for p in str(_args["rgrid"]).split(",", false):
		ms.append(float(p))
	var tally := {}               # world -> [p0 wins, [p2 wins per m], runs]
	for level in levels:
		var w := world_key(level)
		if not tally.has(w):
			var zeros: Array[int] = []
			zeros.resize(ms.size())
			tally[w] = [0, zeros, 0]
		var t: Array = tally[w]
		for hero in heroes:
			var prof0 := profile_p0(level, hero)
			t[0] = int(t[0]) + _random_wins(level_at(level, 1.0), hero, prof0, randoms, level)
			var prof2 := profile_p2(level, hero)
			var wins2: Array[int] = t[1]
			for k in ms.size():
				wins2[k] += _random_wins(level_at(level, ms[k]), hero, prof2, randoms, level)
			t[2] = int(t[2]) + randoms
			EconData.phase_override = -1
	for w: int in tally:
		var t2: Array = tally[w]
		var n := maxf(float(t2[2]), 1.0)
		var r0 := 100.0 * float(t2[0]) / n
		var parts := PackedStringArray()
		var cross := "> %.2f" % ms[ms.size() - 1]
		var prev := INF
		var w2: Array[int] = t2[1]
		for k in ms.size():
			var r := 100.0 * float(w2[k]) / n
			parts.append("m %.2f %.0f%%" % [ms[k], r])
			if cross.begins_with(">") and r <= r0:
				cross = "%.3f" % (ms[k] if k == 0 or prev == r else lerpf(ms[k - 1], ms[k], (prev - r0) / (prev - r)))
				if k == 0:
					cross = "<= %.2f" % ms[0]
			prev = r
		_say("DEMAND_BAKE_RGRID %-6s | p0 %.0f%% | %s | crossing m %s (%d paths)" % [_wname(w), r0, " | ".join(parts),
				cross, int(t2[2])])


## --grid: the outcome of p0 (m = 1), of p2's hero alone (solo_at) and of p2 at every listed m.
func _grid(levels: Array[int], heroes: Array[String]) -> void:
	var ms: Array[float] = []
	for p in str(_args["grid"]).split(",", false):
		ms.append(float(p))
	for level in levels:
		for hero in heroes:
			var p0 := play(level_at(level, 1.0), hero, profile_p0(level, hero))
			var prof2 := profile_p2(level, hero)
			var parts := PackedStringArray()
			for m in ms:
				parts.append("m %.2f: %s" % [m, _fmt(p2_at(level, hero, prof2, m))])
			var solo := solo_at(level, hero, prof2)
			EconData.phase_override = -1
			_say("GRID L%3d %-6s %-5s %s | p0 %s | p2 hero alone@1 %s | %s" % [level, _wname(world_key(level)), hero,
					_team(prof2), _fmt(p0), _fmt(solo), " | ".join(parts)])


# ------------------------------------------------------------------ check

## Per world: p0 (m = 1), p2 at the adopted TEAM_DEMAND and p2 at the measured value: planner wins, mean army at
## the fortress, mean survivors and the random-path win rate.
func _check(rows: Array[Dictionary], measured: Dictionary, randoms: int) -> void:
	_say("DEMAND_BAKE_CHECK world | p0 m=1: plan win, army, surv, rnd win | p2 adopted: same | p2 measured: same")
	for w: int in measured:
		var adopted := float(TeamData.TEAM_DEMAND.get(str(w), 1.0))
		var acc := {"p0": _acc(), "ad": _acc(), "me": _acc()}
		for r: Dictionary in rows:
			if int(r["world"]) != w:
				continue
			var level := int(r["level"])
			var hero := str(r["hero"])
			var prof0 := profile_p0(level, hero)
			_tally(acc["p0"], r["p0"], _random_wins(level_at(level, 1.0), hero, prof0, randoms, level), randoms)
			var prof2: Dictionary = r["prof2"]
			EconData.phase_override = EconData.HEROES_RUN_PHASE
			for key: String in ["ad", "me"]:
				var m := adopted if key == "ad" else float(measured[w])
				var o := p2_at(level, hero, prof2, m)
				_tally(acc[key], o, _random_wins(level_at(level, m), hero, prof2, randoms, level), randoms)
			EconData.phase_override = -1
		if int((acc["p0"] as Dictionary)["n"]) == 0:
			continue
		_say("DEMAND_BAKE_CHECK %-6s | %s | m %.3f: %s | m %.3f: %s" % [_wname(w), _sum(acc["p0"]), adopted,
				_sum(acc["ad"]), float(measured[w]), _sum(acc["me"])])


static func _acc() -> Dictionary:
	return {"n": 0, "wins": 0, "army": 0.0, "surv": 0.0, "rnd": 0, "rnd_n": 0}


static func _tally(a: Dictionary, o: Dictionary, rnd_wins: int, randoms: int) -> void:
	a["n"] = int(a["n"]) + 1
	a["wins"] = int(a["wins"]) + (1 if bool(o["won"]) else 0)
	a["army"] = float(a["army"]) + float(o["army"])
	a["surv"] = float(a["surv"]) + float(o["surv"])
	a["rnd"] = int(a["rnd"]) + rnd_wins
	a["rnd_n"] = int(a["rnd_n"]) + randoms


static func _sum(a: Dictionary) -> String:
	var n := maxf(float(a["n"]), 1.0)
	return "plan %d/%d, army %.0f, surv %.0f, rnd %.0f%%" % [int(a["wins"]), int(a["n"]), float(a["army"]) / n,
			float(a["surv"]) / n, 100.0 * float(a["rnd"]) / maxf(float(a["rnd_n"]), 1.0)]


## Wins of `n` random wandering paths (level_check's, seeded by the level) under the phase in effect.
static func _random_wins(lv: LevelSim.Level, hero: String, prof: Dictionary, n: int, level: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + level
	var wins := 0
	for k in n:
		var path := LevelSim.random_path(lv.length, rng)
		var r := LevelSim.run_path(lv, hero, Balance.start_army(0), path, {"profile": prof})
		wins += 1 if bool(r["won"]) else 0
	return wins


# ------------------------------------------------------------------ output

static func _worlds_of(rows: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for r: Dictionary in rows:
		if not out.has(int(r["world"])):
			out.append(int(r["world"]))
	out.sort()
	return out


static func _median(v: Array[float]) -> float:
	var s := v.duplicate()
	s.sort()
	var n := s.size()
	return s[n / 2] if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) * 0.5


## "[hero Lv n v3, champions id+id x their stat multiplier]" of a p2 profile (its v3 hero block and team block).
static func _team(prof: Dictionary) -> String:
	var ids := PackedStringArray()
	var team: Dictionary = prof.get("team", {}) if prof.get("team") is Dictionary else {}
	var mult := 0.0
	for c: Dictionary in team.get("champions", []):
		ids.append(str(c.get("id", "?")))
		mult = float(c.get("mult", mult))
	var hb: Dictionary = prof.get("hero", {}) if prof.get("hero") is Dictionary else {}
	return "[Lv%d%s %s x%.2f]" % [int(hb.get("lvl", 0)), " v3" if HeroKinds.is_v3(hb) else "",
			"+".join(ids) if not ids.is_empty() else "no champions", mult]


static func _wname(w: int) -> String:
	return "W%d" % w if w <= 7 else "Inv W%d" % (w - 7)


static func _fmt(o: Dictionary) -> String:
	return "%s army %d surv %d fort %d margin %+.3f fort_ratio %.2f champs %s" % ["W" if bool(o["won"]) else "L",
			int(o["army"]), int(o["surv"]), int(o["hp"]), float(o["margin"]), float(o["fort"]), str(o["champs"])]


func _say(line: String) -> void:
	print(line)
	_lines.append(line)


func _finish(t0: int) -> void:
	_say("DEMAND_BAKE done: %d planner runs, %.1f s" % [_evals, float(Time.get_ticks_msec() - t0) / 1000.0])
	if _args.has("out"):
		var dir := str(_args["out"])
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir.path_join("demand_bake_%s_%d.txt" % [_measure, int(Time.get_unix_time_from_system())])
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_lines) + "\n")
			f.close()
			print("DEMAND_BAKE written ", path)
	get_tree().quit(0)
