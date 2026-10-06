extends SceneTree
## Exports the shipped meta-economy numbers (EconData + the ArsenalData tables the sim needs) to
## JSON, so tools/economy_sim.py always simulates the numbers the game ships (arsenal_design.md
## §9.1). Also prints the disclosed odds tables (§5.4) for every pool state.
##
##   godot --headless --path . --script res://tools/export_econ.gd [-- --out=res://build/econ.json]
##
## Colors become "#rrggbb" strings, Vector3 / AABB become arrays, int dictionary keys become
## strings (JSON). build/ holds a .gdignore so Godot never imports the export.

const DEFAULT_OUT := "res://build/econ.json"


func _init() -> void:
	var out := DEFAULT_OUT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var data := export_data()
	var dir := out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	if dir.begins_with("res://build") and not FileAccess.file_exists(dir.path_join(".gdignore")):
		var g := FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)
		if g:
			g.close()
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("export_econ: cannot write %s" % out)
		quit(1)
		return
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
	print("export_econ: wrote %s (%d EconData keys, %d machines)" % [ProjectSettings.globalize_path(out),
			(data["econ"] as Dictionary).size(), (data["machines"] as Dictionary).size()])
	_print_odds()
	quit(0)


## Everything the sim reads, as JSON-safe data.
static func export_data() -> Dictionary:
	var econ := {}
	var cmap := (load("res://scripts/core/econ_data.gd") as GDScript).get_script_constant_map()
	for c in cmap:
		econ[c] = _json(cmap[c])
	var machines := {}
	for id in ArsenalData.ORDER:
		var m: Dictionary = ArsenalData.MACHINES[id]
		machines[id] = {"rarity": m["rarity"], "family": m["family"], "verb": m["verb"], "home": m.get("home", 0),
				"live": ArsenalData.is_live(id), "phase": m.get("phase", 1), "sim": _json(m.get("sim", {})),
				"new_crate_level": ArsenalData.new_crate_level(id), "start_level": EconData.START_LEVEL[m["rarity"]]}
	var formulas := {"hero_cost": [], "barracks_cost": [], "victory_coins_s0": [], "hero_cap": [], "barracks_cap": []}
	for l in range(1, int(EconData.HERO["max"])):
		(formulas["hero_cost"] as Array).append(EconData.hero_cost(l))
	for l2 in range(1, EconData.BARRACKS_MAX + 1):
		(formulas["barracks_cost"] as Array).append(EconData.barracks_cost(l2))
	for l3 in range(1, ArsenalData.CAMPAIGN_LEVELS + 1):
		(formulas["victory_coins_s0"] as Array).append(EconData.victory_coins(l3, 0))
	for w in range(1, 8):
		(formulas["hero_cap"] as Array).append(EconData.hero_cap(w))
		(formulas["barracks_cap"] as Array).append(EconData.barracks_cap(w))
	return {
		"version": 2,
		"econ": econ,
		"arsenal": {"MAX_LEVEL": ArsenalData.MAX_LEVEL, "TALENT_LEVELS": _json(ArsenalData.TALENT_LEVELS),
				"LEAD_LEVEL": ArsenalData.LEAD_LEVEL, "ASCENSION_LEVEL": ArsenalData.ASCENSION_LEVEL,
				"APEX_LEVEL": ArsenalData.APEX_LEVEL, "PER_LEVEL": ArsenalData.PER_LEVEL,
				"START_OWNED": _json(ArsenalData.START_OWNED), "MYTHIC_ORDER": _json(ArsenalData.MYTHIC_ORDER),
				"LEVELS_PER_WORLD": ArsenalData.LEVELS_PER_WORLD, "CAMPAIGN_LEVELS": ArsenalData.CAMPAIGN_LEVELS,
				"NEW_CRATES": _json(ArsenalData.NEW_CRATES), "INRUN_BUDGET": _json(ArsenalData.INRUN_BUDGET),
				"RANK_MULT": _json(ArsenalData.RANK_MULT), "OVERFLOW": _json(ArsenalData.OVERFLOW),
				"DUP_SHARE_AT_2": ArsenalData.DUP_SHARE_AT_2, "RECIPE_WEIGHT": ArsenalData.RECIPE_WEIGHT,
				"RARITY_PICK_W": _json(ArsenalData.RARITY_PICK_W), "MAX_FIELDED": ArsenalData.MAX_FIELDED,
				"FEATURES": _json(ArsenalData.FEATURES), "PHASE": ArsenalData.PHASE},
		"machines": machines,
		"formulas": formulas,
		"totals": {"machine_coins": EconData.full_machine_cost("C")["coins"], "arsenal_coins": Arsenal.full_arsenal_coins(),
				"hero": HeroesMeta.total_cost(), "barracks_track": Barracks.total_cost()},
	}


## JSON-safe copy of `v`.
static func _json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _json(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var a: Array = []
			for e in v:
				a.append(_json(e))
			return a
		TYPE_COLOR:
			return "#" + (v as Color).to_html(false)
		TYPE_VECTOR3:
			return [v.x, v.y, v.z]
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_AABB:
			return [_json((v as AABB).position), _json((v as AABB).size)]
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL:
			return null
	return v


## The (i) screen tables for every pool state (design §5.4).
static func _print_odds() -> void:
	var states := {
		"World 1 (C, R)": ["drone", "ballista", "cannon", "rockets", "mortar"],
		"World 2 (C, R, E)": ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun"],
		"World 3+ (C, R, E, L)": ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun", "prism"],
	}
	for label in states:
		var pool: Array[String] = []
		pool.assign(states[label])
		for type in ["stone", "world"]:
			var pres := CacheRoller.present(pool, type)
			var o := CacheRoller.odds(type, pres)
			var best: Array[String] = []
			var guar: Array[String] = []
			for r in ArsenalData.RARITY_ORDER:
				if float(o["best"].get(r, 0.0)) > 0.0:
					best.append("%s %.2f%%" % [r, 100.0 * float(o["best"][r])])
				if float(o["guaranteed"].get(r, 0.0)) > 0.0:
					guar.append("%s %.2f%%" % [r, 100.0 * float(o["guaranteed"][r])])
			print("  %-22s %-6s best: %-40s guaranteed: %s" % [label, type, " · ".join(best), " · ".join(guar)])
