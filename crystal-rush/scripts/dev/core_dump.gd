extends SceneTree
## Dev: prints the items of levels (kind, d, x, details) to pick screenshot moments.
## godot --headless --path . --script res://scripts/dev/core_dump.gd -- --from=1 --to=8 [--kind=blade]


func _init() -> void:
	var a := {}
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for lvl in range(int(a.get("from", "1")), int(a.get("to", "1")) + 1):
		var g := LevelGen.build(lvl, Balance.START_ARMY)
		print("LEVEL %d length %d" % [lvl, int(g["length"])])
		for it: Dictionary in g["items"]:
			var k := str(it["kind"])
			if k in ["tile", "coin"]:
				continue
			if a.has("kind") and k != str(a["kind"]):
				continue
			var extra := it.duplicate()
			for key in ["kind", "d", "x"]:
				extra.erase(key)
			print("  %-9s d=%6.1f x=%5.2f %s" % [k, float(it["d"]), float(it.get("x", 0.0)), str(extra)])
	quit(0)
