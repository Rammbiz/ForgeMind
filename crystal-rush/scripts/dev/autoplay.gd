extends Node
## Plays levels with the test bot at high speed and prints one JSON line per level.
##   godot --headless --path crystal-rush -- --autotest --level=3 [--levels=5] [--hero=bolt|titan]
##        [--bot=best|lazy|random] [--skill=0.8] [--army=0] [--power=0] [--speed=4] [--seed=1]
##        [--compare]  (also prints what LevelSim's planner predicts for the same level)
##        [--trace]    (one TRACE line per army change: time, d, state, hero x, what is near)
## For fast, deterministic runs add `--fixed-fps 60` before `--` and use --speed=1: the game
## then steps 1/60 s per frame as fast as the CPU allows (about 5x real time headless).
## JSON fields: level, hero, bot, skill, won, reason, army_at_fortress, survivors, stairs_mult,
## coins, weapons (id + Rank), arm_tier, hazard_deaths, time, length, expected, profile, crates,
## bonus, rank_gates, new_unlock, crowns, kills_by_machine, statuses (+ sim with --compare).
## The account is the dev profile: --profile=fresh|expected|max [--deck=a,b,c] (Meta, readonly).

const TIMEOUT := 600.0

var args := {}
var _bot := Bot.new()
var _run: Node3D
var _level := 1
var _last := 1
var _results: Array = []
var _elapsed := 0.0
var _army_at_fortress := -1
var _hazard := 0
var _last_army := 0
var _last_d := 0.0
var _gate_ds := PackedFloat32Array()
var _done := false


func _ready() -> void:
	_level = int(args.get("level", "1"))
	_last = _level + int(args.get("levels", "1")) - 1
	_bot.skill = float(args.get("skill", "1.0"))
	_bot.mode = str(args.get("bot", "best"))
	_bot.rng.seed = int(args.get("seed", "1"))
	_bot.power_level = int(args.get("power", "0"))
	seed(int(args.get("seed", "1")))
	var speed := float(args.get("speed", "4"))
	Engine.time_scale = speed
	Juice.base_time_scale = speed
	Juice.hitstop_enabled = false
	_start()


func _start() -> void:
	var main := get_parent()
	var holder: Node = main.call("make_play", _level, str(args.get("hero", "bolt")))
	main.call("set_scene_now", holder)
	_run = holder.get_meta("run")
	_run.connect("finished", _on_finished)
	_bot.reset()
	_elapsed = 0.0
	_army_at_fortress = -1
	_hazard = 0
	_last_army = int(_run.get("army"))
	_last_d = 0.0
	_done = false
	_gate_ds.clear()
	for it: Dictionary in _run.get("items"):
		if str(it["kind"]) == "gate":
			_gate_ds.append(float(it["d"]))


func _process(delta: float) -> void:
	if _run == null or not is_instance_valid(_run) or _done:
		return
	_elapsed += delta
	var st := int(_run.get("state"))
	if st != _state("WON") and st != _state("LOST"):
		_bot.think(_run)
	_track(st)
	if _elapsed > TIMEOUT:
		_on_finished(false, 0, "TIMEOUT")


## Army at the fortress and hazard deaths (the run's own counter when it has one).
func _track(st: int) -> void:
	var army := int(_run.get("army"))
	var d := float(_run.get("d"))
	if args.has("trace") and army != _last_army:
		_trace(st, army, d)
	if _army_at_fortress < 0 and (st == _state("SIEGE") or st == _state("STAIRS") or st == _state("WON")):
		_army_at_fortress = _last_army if st != _state("SIEGE") else army
	if st == _state("RUNNING") and army < _last_army:
		var at_gate := false
		for gd in _gate_ds:
			if gd > _last_d - 0.01 and gd <= d + 0.01:
				at_gate = true
		if not at_gate:
			_hazard += _last_army - army
	_last_army = army
	_last_d = d


## --trace: one line per army change with the state, the hero x and what is around.
func _trace(st: int, army: int, d: float) -> void:
	var near := ""
	for it: Dictionary in _run.get("items"):
		var di := float(it["d"])
		if di < d - 4.0 or di > d + 3.0:
			continue
		var k := str(it["kind"])
		if k in ["tile", "coin"]:
			continue
		near += " %s@%.0f(x%.1f%s)" % [k, di, float(it.get("x", 0.0)), "" if it.get("alive", true) else "-"]
	var hz: Variant = _run.get("hazard_deaths")
	print("TRACE t=%5.1f d=%6.1f st=%d hx=%5.2f army %d -> %d (%+d) haz=%.0f |%s" % [
		float(_run.get("t")), d, st, float(_run.get("hx")), _last_army, army, army - _last_army,
		float(hz) if hz != null else 0.0, near])


func _state(name: String) -> int:
	return int(Run.State.get(name, -99))


func _on_finished(won: bool, coins: int, reason: String) -> void:
	if _done:
		return
	_done = true
	var res: Dictionary = _run.get("result") if _run.get("result") != null else {}
	var ws: Array = []
	var run_ws: Variant = _run.get("weapons")
	if run_ws is Array:
		for w: Dictionary in run_ws:
			ws.append("%s%d" % [str(w["kind"]), int(w["level"])])
	var hz: Variant = _run.get("hazard_deaths")
	var length: Variant = _run.get("length")
	var r := {
		"level": _level, "hero": str(_run.get("hero_type")), "bot": _bot.mode, "skill": _bot.skill,
		"won": won, "reason": reason,
		"army_at_fortress": maxi(_army_at_fortress, 0),
		"survivors": int(res.get("survivors", _run.get("army") if won else 0)),
		"stairs_mult": float(res.get("mult", _run.get("stairs_mult") if _run.get("stairs_mult") != null else 1.0)),
		"coins": coins, "weapons": ws, "arm_tier": int(_run.get("arm_tier") if _run.get("arm_tier") != null else 0),
		"hazard_deaths": int(hz) if hz != null else _hazard,
		"time": snappedf(_elapsed, 0.1),
		"length": int(length) if length != null else 0,
		"expected": int(_run.get("expected")) if _run.get("expected") != null else 0,
	}
	# Arsenal (Meta-1): what the run reports to Meta.finish_run.
	var st: Dictionary = res.get("stats", {})
	r["profile"] = str((_run.get("profile") as Dictionary).get("profile", "")) if _run.get("profile") is Dictionary else ""
	r["crates"] = int(st.get("crates_opened", 0))
	r["bonus"] = int(st.get("crate_bonus", 0))
	r["rank_gates"] = int(st.get("rank_gates", 0))
	r["new_unlock"] = str(res.get("new_unlock", ""))
	r["crowns"] = int(res.get("crowns", 0))
	r["kills_by_machine"] = st.get("kills_by_machine", {})
	r["statuses"] = st.get("statuses", {})
	if args.has("compare"):
		var def := LevelGen.build(_level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, _level)
		var army := Balance.start_army(int(args.get("army", "0")))
		var sim: Dictionary = LevelSim.best_path(lv, str(_run.get("hero_type")), army, {"power": int(args.get("power", "0"))})["result"]
		r["sim"] = {"won": sim["won"], "army_at_fortress": sim["army_at_fortress"], "survivors": sim["survivors"],
			"stairs_mult": sim["stairs_mult"], "hazard_deaths": sim["hazard_deaths"]}
	print("AUTOTEST ", JSON.stringify(r))
	_results.append(r)
	_run = null
	if _level < _last:
		_level += 1
		_start.call_deferred()
	else:
		var wins := 0
		for x: Dictionary in _results:
			if x["won"]:
				wins += 1
		print("AUTOTEST_SUMMARY ", JSON.stringify({"levels": _results.size(), "won": wins, "bot": _bot.mode, "skill": _bot.skill}))
		get_tree().quit(0)
