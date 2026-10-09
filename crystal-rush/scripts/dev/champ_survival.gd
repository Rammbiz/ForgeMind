extends Node
## Champion survival on a synthetic profile (heroes design §4.2 "Survival targets", measured in
## LevelSim, never assumed). Every campaign level in [--from, --to] is played by the planner
## (LevelSim.best_path, the level_check path) once with the account's team and once without it;
## per level and hero it prints won, the team and per champion alive / hp left / kills / blocks /
## heals. A measurement, not a tuner: kit HP is generated data (heroes_tables.py) and the lead
## decides what changes.
##
##   godot --headless --path . res://scenes/dev/champ_survival.tscn -- --autotest [--from=15] [--to=112]
##        [--profile=expected|fresh|max] [--hero=bolt,titan,seer] [--step=1] [--out=DIR]
##
## The team is the synthetic account's (Meta.synthetic_account: the two scripted champions from
## L > UNLOCK_AT.champions, the first one picked by the team hero: Bolt -> Альба, Titan / Seer -> Отто,
## then Міла) built into the run's team block by Meta.team_block_of. Phase 2 is forced for the
## measurement (EconData.phase_override, restored at the end). `--autotest` keeps the save read-only.
##
## Final line: CHAMP_SURVIVAL front_campaign=..% front_boss=..% side_rear=..% levels=N wins=W
## (+ the win rate without the team and the delta). Targets (§4.2): the front champion survives
## >= 75% of campaign levels and 40-60% of boss levels; side / rear >= 90%. Exit code 0.

var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var from := maxi(1, int(args.get("from", "15")))
	var to := maxi(from, int(args.get("to", "112")))
	var step := maxi(1, int(args.get("step", "1")))
	var kind := str(args.get("profile", "expected"))
	var heroes: Array[String] = []
	for h in str(args.get("hero", "bolt,titan,seer")).split(",", false):
		if Balance.HEROES.has(h):
			heroes.append(h)
	var old_phase := EconData.phase_override
	EconData.phase_override = maxi(EconData.HEROES_RUN_PHASE, HeroKinds.CHAMPIONS_PHASE)
	var t0 := Time.get_ticks_msec()
	_say("CHAMP_SURVIVAL_RUN profile=%s levels %d..%d step %d heroes %s (phase %d)" % [kind, from, to, step,
			",".join(heroes), EconData.heroes_phase()])
	# Tallies: [alive, total] per bucket; runs and wins with / without the team.
	var front_c := [0, 0]
	var front_b := [0, 0]
	var side := [0, 0]
	var runs := 0
	var wins := 0
	var base_wins := 0
	var falls: PackedStringArray = PackedStringArray()
	var side_falls: PackedStringArray = PackedStringArray()
	var army := Balance.start_army(0)
	for level in range(from, to + 1, step):
		var def := LevelGen.build(level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, level)
		var boss := ArsenalData.is_boss(level)
		for hero in heroes:
			var acc := account_for(level, kind, hero)
			var prof := LevelSim.profile_from_account(acc, level, kind)
			var team := Meta.team_block_of(acc, hero)
			var prof_t := prof.duplicate()
			prof_t["team"] = team
			var res_t: Dictionary = LevelSim.best_path(lv, hero, army, {"profile": prof_t})
			var res_0: Dictionary = LevelSim.best_path(lv, hero, army, {"profile": prof})
			var r: Dictionary = res_t["result"]
			var r0: Dictionary = res_0["result"]
			var st: LevelSim.State = res_t["state"]
			runs += 1
			wins += 1 if bool(r["won"]) else 0
			base_wins += 1 if bool(r0["won"]) else 0
			var parts: PackedStringArray = PackedStringArray()
			for m: Dictionary in st.champs.members:
				var alive := bool(m["alive"])
				var tag := "%s %s:%s" % [("L%d" % level), hero, str(m["id"])]
				if StringName(str(m["slot"])) == ChampionKinds.FRONT:
					var bucket: Array = front_b if boss else front_c
					bucket[1] = int(bucket[1]) + 1
					bucket[0] = int(bucket[0]) + (1 if alive else 0)
					if not alive:
						falls.append(tag)
				else:
					side[1] = int(side[1]) + 1
					side[0] = int(side[0]) + (1 if alive else 0)
					if not alive:
						side_falls.append(tag)
				parts.append("%s:%s %s hp %.1f/%.1f k %d b %d h %d dmg %d" % [str(m["id"]), str(m["slot"]),
						"A" if alive else "X", float(m["hp"]), float(m["hp_max"]),
						int(round(float(m["kills"]))), int(m["blocks"]), int(round(float(m["heals"]))),
						int(round(float(m["dmg_taken"])))])
			if parts.is_empty():
				parts.append("no team")
			_say("CS L%3d %-5s %s %s | %s | army %d surv %d (no team: %s army %d surv %d)" % [level, hero,
					"boss" if boss else "    ", "W" if bool(r["won"]) else "L", " | ".join(parts),
					int(r["army_at_fortress"]), int(r["survivors"]), "W" if bool(r0["won"]) else "L",
					int(r0["army_at_fortress"]), int(r0["survivors"])])
	_say("FRONT_FALLS (%d): %s" % [falls.size(), ", ".join(falls) if not falls.is_empty() else "none"])
	_say("SIDE_REAR_FALLS (%d): %s" % [side_falls.size(), ", ".join(side_falls) if not side_falls.is_empty() else "none"])
	var wr := 100.0 * float(wins) / float(maxi(runs, 1))
	var wr0 := 100.0 * float(base_wins) / float(maxi(runs, 1))
	_say("CHAMP_SURVIVAL front_campaign=%s front_boss=%s side_rear=%s levels=%d wins=%d" % [_pct(front_c),
			_pct(front_b), _pct(side), runs, wins] + " base_wins=%d win_delta=%+.1f%% (%.1f s)" % [base_wins, wr - wr0,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	_say("  alive / samples: front campaign %d/%d, front boss %d/%d, side / rear %d/%d" % [int(front_c[0]),
			int(front_c[1]), int(front_b[0]), int(front_b[1]), int(side[0]), int(side[1])]
			+ "; targets front >= 75%, boss 40-60%, side / rear >= 90%")
	EconData.phase_override = old_phase
	if args.has("out"):
		_write(str(args["out"]), "champ_survival_%s_%d_%d_%s.txt" % [kind, from, to, "_".join(heroes)])
	get_tree().quit(0)


## The synthetic account at `level` (Meta.synthetic_account) led by `hero`: the team hero and its
## scripted first champion (PortalData.SCRIPTED_FIRST, by the hero that opened chest #1) replace
## the synthetic Bolt's, and the hero is owned.
static func account_for(level: int, kind: String, hero: String) -> Dictionary:
	var acc := Meta.synthetic_account(level, kind)
	(acc["progress"] as Dictionary)["hero"] = hero
	var hs: Dictionary = acc.get("heroes", {})
	if hs.has(hero):
		(hs[hero] as Dictionary)["owned"] = true
	var team: Dictionary = acc["team"]
	team["hero"] = hero
	var champs: Array = team.get("champions", [])
	if not champs.is_empty():
		var first := str(PortalData.SCRIPTED_FIRST.get(hero, PortalData.SCRIPTED_FIRST_DEFAULT))
		var was := str(champs[0])
		if first != was and not champs.has(first):
			var roster: Dictionary = (acc["champions"] as Dictionary)["roster"]
			roster.erase(was)
			roster[first] = EconData.new_champion_state(first, true, "chest")
			champs[0] = first
	return acc


static func _pct(t: Array) -> String:
	if int(t[1]) <= 0:
		return "n/a"
	return "%.1f%%" % (100.0 * float(t[0]) / float(t[1]))


func _say(line: String) -> void:
	print(line)
	_lines.append(line)


func _write(dir: String, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("champ_survival: cannot write " + path)
		return
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	print("CHAMP_SURVIVAL written ", path)
