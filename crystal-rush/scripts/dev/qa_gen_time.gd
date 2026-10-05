extends SceneTree
func _initialize() -> void:
	for level in range(1, 16):
		var t0 := Time.get_ticks_usec()
		var def := LevelGen.build(level, Balance.START_ARMY)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var fort := 0
		var steps := []
		for it: Dictionary in def["items"]:
			if str(it["kind"]) == "fortress":
				fort = int(it["value"])
			if str(it["kind"]) == "stairs":
				for st in it["steps"]:
					steps.append(int(st["cost"]))
		print("L%d gen %.0f ms len %d e %d fort %d stairs %s" % [level, ms, int(def["length"]), int(def["expected"]), fort, str(steps)])
	quit(0)
