extends SceneTree
## Checks every level with LevelSim: the planner's best path vs a lazy path down the middle vs
## random wandering paths, for both heroes. Flags levels where the best path loses (a bug) or
## where the lazy path wins with a similar margin (an empty level).
##   godot --headless --path . --script res://scripts/dev/level_check.gd -- --from=1 --to=20
##        [--hero=bolt|titan|both] [--random=8] [--army=0] [--power=0] [--trace=LEVEL] [--map=LEVEL]
## Uses only static classes (no autoloads), so it runs as a bare SceneTree script.


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var from := int(args.get("from", "1"))
	var to := int(args.get("to", "20"))
	var heroes: Array[String] = ["bolt", "titan"]
	if str(args.get("hero", "both")) != "both":
		heroes = [str(args["hero"])]
	var randoms := int(args.get("random", "8"))
	var army := Balance.start_army(int(args.get("army", "0")))
	var power := int(args.get("power", "0"))
	var trace := int(args.get("trace", "0"))
	if args.has("map"):
		_print_map(int(args["map"]))
	var t0 := Time.get_ticks_msec()
	print("LEVELCHECK army=%d power=%d   best = planner, lazy = x 0, rnd = %d random paths" % [army, power, randoms])
	print("lvl hero  | len  e    fort | best: W army surv  x   coins haz wpn arm | lazy: W army surv | rnd: win% med army | flags")
	var problems := 0
	for level in range(from, to + 1):
		var def := LevelGen.build(level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, level)
		var fort := 0
		for it: Dictionary in def["items"]:
			if str(it["kind"]) == "fortress":
				fort = int(it["value"])
		for hero in heroes:
			var opts := {"power": power, "trace": trace == level}
			var best: Dictionary = LevelSim.best_path(lv, hero, army, opts)
			var b: Dictionary = best["result"]
			var lz := LevelSim.run_path(lv, hero, army, LevelSim.lazy_path(), {"power": power})
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + level
			var wins := 0
			var armies: Array[int] = []
			for k in randoms:
				var r := LevelSim.run_path(lv, hero, army, LevelSim.random_path(lv.length, rng), {"power": power})
				if r["won"]:
					wins += 1
				armies.append(int(r["army_at_fortress"]))
			armies.sort()
			var med := armies[armies.size() / 2] if not armies.is_empty() else 0
			var flags := ""
			if not b["won"]:
				flags += " BUG:best-loses"
				problems += 1
			elif lz["won"] and int(lz["survivors"]) * 10 >= int(b["survivors"]) * 6:
				flags += " EMPTY:lazy-close"
				problems += 1
			if b["won"] and int(b["survivors"]) < maxi(4, fort / 5):
				flags += " thin-margin"
			if level >= 5 and lz["won"]:
				flags += " lazy-wins"
			if level >= 7 and randoms > 0 and wins * 2 > randoms:
				flags += " random-wins"
			var wpn := ""
			for w: Dictionary in b["weapons"]:
				wpn += str(w["kind"]).substr(0, 2) + str(w["level"])
			print("%3d %-5s | %4d %4d %4d | %s %4d %4d x%-3s %5d %3d %-6s %d | %s %4d %4d | %3d%% %4d |%s" % [
				level, hero, int(lv.length), int(def["expected"]), fort,
				"W" if b["won"] else "L", b["army_at_fortress"], b["survivors"], str(b["stairs_mult"]), b["coins"],
				b["hazard_deaths"], wpn, b["arm_tier"],
				"W" if lz["won"] else "L", lz["army_at_fortress"], lz["survivors"],
				0 if randoms == 0 else wins * 100 / randoms, med, flags])
			if trace == level:
				for line in best["trace"]:
					print("    ", line)
	print("LEVELCHECK done: %d problem(s), %.1f s" % [problems, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


## Prints the item list of a level, one line per item.
func _print_map(level: int) -> void:
	var def := LevelGen.build(level, Balance.START_ARMY)
	print("MAP level %d length %d expected %d hints %s script %s" % [level, int(def["length"]), int(def["expected"]), str(def["hints"]), str(def["script"])])
	for it: Dictionary in def["items"]:
		var extra := ""
		for k in it:
			if not k in ["kind", "d", "x"]:
				extra += " %s=%s" % [k, str(it[k])]
		print("  %6.1f %-9s x=%5.2f%s" % [float(it["d"]), str(it["kind"]), float(it.get("x", 0.0)), extra])
