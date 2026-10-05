extends SceneTree
## Dev: trace one path through a level. --level=N --hero=bolt --x=0
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var level := int(args.get("level", "1"))
	var def := LevelGen.build(level, 3)
	var lv := LevelSim.make_level(def, level)
	var r := LevelSim.start_state(lv, str(args.get("hero", "bolt")), 3, {"trace": true})
	LevelSim.advance(lv, r, PackedFloat32Array([0.0, float(args.get("x", "0"))]), 400.0)
	for l in r.trace: print(l)
	print(LevelSim.result(lv, r))
	quit()
