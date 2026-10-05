extends SceneTree
## QA overview of the generated levels: generation time, length, expected army, fortress hp,
## stairs costs, item counts, crates and special gates.
##   godot --headless --path . --script res://scripts/dev/qa_levels.gd -- [--from=1] [--to=15]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for level in range(int(args.get("from", "1")), int(args.get("to", "15")) + 1):
		var t0 := Time.get_ticks_usec()
		var def := LevelGen.build(level, Balance.START_ARMY)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var fort := 0
		var costs: Array[int] = []
		var counts := {}
		var notes := ""
		for it: Dictionary in def["items"]:
			var k := str(it["kind"])
			if k == "blade":
				k = str(it.get("type", "blade"))
			counts[k] = int(counts.get(k, 0)) + 1
			match k:
				"fortress":
					fort = int(it["value"])
				"stairs":
					for st: Dictionary in it["steps"]:
						costs.append(int(st["cost"]))
				"crate":
					notes += " crate@%d(x%.1f hp%d %s)" % [int(it["d"]), float(it["x"]), int(it["value"]), str(it["weapon"])]
				"gate":
					if it.has("reward"):
						notes += " charge@%d(%s)" % [int(it["d"]), str((it["reward"] as Dictionary).get("op", ""))]
					elif str(it["op"]) in ["arm", "rate", "dmg", "multi"]:
						notes += " %s@%d" % [str(it["op"]), int(it["d"])]
		print("L%-2d gen %4.0f ms | len %d e %d fort %d stairs %s" % [level, ms, int(def["length"]), int(def["expected"]), fort, str(costs)])
		print("     %s |%s" % [str(counts), notes])
	quit(0)
