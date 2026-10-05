extends SceneTree
## QA: per level, the count of each item kind and the crates / weapon gates.
func _initialize() -> void:
	for level in range(1, 16):
		var def := LevelGen.build(level, Balance.START_ARMY)
		var counts := {}
		var notes := ""
		for it: Dictionary in def["items"]:
			var k := str(it["kind"])
			if k == "blade":
				k = str(it.get("type", "blade"))
			counts[k] = int(counts.get(k, 0)) + 1
			if k == "crate":
				notes += " crate@%d(x%.1f,hp%d,%s)" % [int(it["d"]), float(it["x"]), int(it["value"]), str(it["weapon"])]
			if k == "gate" and it.has("reward"):
				notes += " charge@%d(%s)" % [int(it["d"]), str(it["reward"])]
			if k == "gate" and str(it["op"]) in ["arm", "rate", "dmg", "multi"]:
				notes += " %s@%d" % [str(it["op"]), int(it["d"])]
		print("L%d %s |%s" % [level, str(counts), notes])
	quit(0)
