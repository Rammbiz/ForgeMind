extends Node
## Checks every level with LevelSim: the planner's best path vs a lazy path down the middle vs
## random wandering paths, for both heroes, with an account profile. Flags levels where the best
## path loses (a bug) or where the lazy path wins with a similar margin (an empty level), and
## prints the in-run arsenal the best path builds (machines and Ranks at the fortress) with the
## band shares of design §3.2 (P(Rank II+), P(Rank III)).
##   godot --headless --path . -- --levelcheck --from=1 --to=20 [--profile=fresh|expected|max|reference]
##        [--hero=bolt|titan|seer|both|all] [--random=8] [--army=0] [--power=0] [--trace=LEVEL] [--map=LEVEL]
## Runs through main.gd (the dev route), so the Meta autoload builds the synthetic accounts
## (Meta.synthetic_account, design §9.4). Levels never see the profile (LevelGen keeps
## START_ARMY and its own reference players); only the simulated player does.
## Exit code: the number of problems.

var args := {}


func _ready() -> void:
	var from := int(args.get("from", "1"))
	var to := int(args.get("to", "20"))
	var heroes: Array[String] = ["bolt", "titan"]
	if str(args.get("hero", "both")) == "all":
		heroes = Balance.HERO_ORDER.duplicate()
	elif str(args.get("hero", "both")) != "both":
		heroes = [str(args["hero"])]
	var randoms := int(args.get("random", "8"))
	var army := Balance.start_army(int(args.get("army", "0")))
	var power := int(args.get("power", "0"))
	var trace := int(args.get("trace", "0"))
	var kind := str(args.get("profile", "fresh"))
	if args.has("map"):
		_print_map(int(args["map"]))
	var t0 := Time.get_ticks_msec()
	print("LEVELCHECK profile=%s army=%d power=%d   best = planner, lazy = x 0, rnd = %d random paths" % [kind, army, power, randoms])
	print("lvl hero  | len  e    fort | best: W army surv  x   coins haz machines | lazy: W army surv | rnd: win% med army | flags")
	var problems := 0
	var bands := {}
	for level in range(from, to + 1):
		var def := LevelGen.build(level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, level)
		var prof := profile(level, kind)
		var fort := 0
		for it: Dictionary in def["items"]:
			if str(it["kind"]) == "fortress":
				fort = int(it["value"])
		for hero in heroes:
			var opts := {"power": power, "trace": trace == level, "sample": 1.0 if trace == level else 0.0, "profile": prof}
			var best: Dictionary = LevelSim.best_path(lv, hero, army, opts)
			var b: Dictionary = best["result"]
			var lz := LevelSim.run_path(lv, hero, army, LevelSim.lazy_path(), {"power": power, "profile": prof})
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + level
			var wins := 0
			var armies: Array[int] = []
			for k in randoms:
				var r := LevelSim.run_path(lv, hero, army, LevelSim.random_path(lv.length, rng), {"power": power, "profile": prof})
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
			var top := 0
			for w: Dictionary in b["weapons"]:
				wpn += str(w["kind"]).substr(0, 2) + str(w["level"])
				top = maxi(top, int(w["level"]))
			var band := "L1" if level <= 1 else ("L2-10" if level <= 10 else ("L11-30" if level <= 30 else "L31+"))
			var bd: Array = bands.get(band, [0, 0, 0])
			bd[0] = int(bd[0]) + 1
			bd[1] = int(bd[1]) + (1 if top >= 2 else 0)
			bd[2] = int(bd[2]) + (1 if top >= 3 else 0)
			bands[band] = bd
			print("%3d %-5s | %4d %4d %4d | %s %4d %4d x%-3s %5d %3d %-8s | %s %4d %4d | %3d%% %4d |%s" % [
				level, hero, int(lv.length), int(def["expected"]), fort,
				"W" if b["won"] else "L", b["army_at_fortress"], b["survivors"], str(b["stairs_mult"]), b["coins"],
				b["hazard_deaths"], wpn,
				"W" if lz["won"] else "L", lz["army_at_fortress"], lz["survivors"],
				0 if randoms == 0 else wins * 100 / randoms, med, flags])
			if trace == level:
				for line in best["trace"]:
					print("    ", line)
				var smp: PackedVector3Array = best.get("samples", PackedVector3Array())
				for et: Array in def.get("etrace", []):
					var sim_army := 0.0
					for sm in smp:
						if sm.x <= float(et[0]):
							sim_army = sm.z
					print("    E d=%6.1f e=%6.1f sim=%6.1f %s" % [float(et[0]), float(et[1]), sim_army, str(et[2])])
	for band: String in bands:
		var bd2: Array = bands[band]
		print("ARSENAL %s best paths: Rank II+ %d%%, Rank III %d%% (%d runs; design §3.2 targets L2-10 II+ >= 70%%, L11-30 III 60-85%%)" % [
			band, int(bd2[1]) * 100 / maxi(int(bd2[0]), 1), int(bd2[2]) * 100 / maxi(int(bd2[0]), 1), int(bd2[0])])
	print("LEVELCHECK done: %d problem(s), %.1f s" % [problems, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(problems)


## The simulated player's profile at `level`: fresh | expected | max (Meta.synthetic_account)
## or "reference" (LevelGen's own reference player, LevelSim.reference_profile).
static func profile(level: int, kind: String) -> Dictionary:
	if kind == "reference":
		return LevelSim.reference_profile(level)
	var meta := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Meta")
	if meta == null:
		return LevelSim.reference_profile(level)
	var acc: Dictionary = meta.call("synthetic_account", level, kind)
	return LevelSim.profile_from_account(acc, level, kind)


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
