extends Node
## Champion survival on a synthetic profile (heroes design §4.2 "Survival targets", measured in
## LevelSim, never assumed). Every campaign level in [--from, --to] is played by the planner
## (LevelSim.best_path, the level_check path) once with the account's team and once without it;
## per level and hero it prints won, the team and per champion alive / hp left / kills / blocks /
## heals. A measurement, not a tuner: kit HP is generated data (heroes_tables.py) and the lead
## decides what changes.
##
##   godot --headless --path . res://scenes/dev/champ_survival.tscn -- --autotest [--from=15] [--to=112]
##        [--profile=expected|fresh|max] [--hero=bolt,titan,seer] [--step=1] [--levels=16,24,..]
##        [--run=1] [--inv_fix=1] [--front_hp=1.0] [--out=DIR]
##
## The team is the synthetic account's (Meta.synthetic_account: the two scripted champions from
## L > UNLOCK_AT.champions, the first one picked by the team hero: Bolt -> Альба, Titan / Seer -> Отто,
## then Міла) built into the run's team block by Meta.team_block_of. The run with the team plays the
## level with the heroes-phase enemy budget (LevelGen.team_demand, as the Run builds it), the run without
## it the level as built. Phase 2 is forced for the measurement (EconData.phase_override, restored at
## the end). `--autotest` keeps the save read-only. --levels replaces from / to / step.
##
## By default both runs field the Meta-1 hero block (LevelSim.profile_from_account). --run=1 builds the
## profile as a phase-2 dev run does (Meta.run_profile: the hero's v3 block and the team block; the run
## without the team drops the team block), the profile TEAM_DEMAND was re-baked on (demand_bake p2).
## --inv_fix=1 lifts the synthetic account's world caps on Invasion levels (invasion_fix, as demand_bake's
## H2 bake did). --front_hp=K multiplies the HP of every champion whose kit slot is front (Guardian,
## Warrior; ChampionData.CHAMPIONS slot) by K, wherever it stands: a sweep of the generator's one HP knob
## (heroes_tables.FRONT_HP_MULT) without regenerating the data.
##
## Final line: CHAMP_SURVIVAL front_campaign=..% front_boss=..% side_rear=..% levels=N wins=W
## (+ the win rate without the team and the delta), after one CHAMP_SURVIVAL_HERO line per hero
## (the team depends on the hero; Bolt's has no front). front_campaign counts the non-boss levels of
## the range (Invasion levels past CAMPAIGN_LEVELS included when the range reaches them), front_boss
## the boss levels (8th of a world). Targets (§4.2): the front champion survives >= 75% of campaign
## levels and 40-60% of boss levels; side / rear >= 90%. Exit code 0.

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
	var levels: Array[int] = []
	for l in str(args.get("levels", "")).split(",", false):
		if int(l) >= 1:
			levels.append(int(l))
	if levels.is_empty():
		for l in range(from, to + 1, step):
			levels.append(l)
	var run_prof := int(args.get("run", "0")) != 0
	var inv := int(args.get("inv_fix", "0")) != 0
	var front_hp := float(args.get("front_hp", "1.0"))
	var old_phase := EconData.phase_override
	EconData.phase_override = maxi(EconData.HEROES_RUN_PHASE, HeroKinds.CHAMPIONS_PHASE)
	var t0 := Time.get_ticks_msec()
	_say("CHAMP_SURVIVAL_RUN profile=%s levels %d..%d step %d heroes %s (phase %d)" % [kind, levels[0],
			levels[-1], step, ",".join(heroes), EconData.heroes_phase()]
			+ " n=%d hero_block=%s inv_fix=%d front_hp=%.3f" % [levels.size(), "v3" if run_prof else "meta1",
			int(inv), front_hp])
	# Tallies: "all" and per hero -> bucket (fc front campaign, fb front boss, side) -> [alive, total];
	# runs and wins with / without the team.
	var tally := {"all": _buckets()}
	for h in heroes:
		tally[h] = _buckets()
	var runs := 0
	var wins := 0
	var base_wins := 0
	var falls: PackedStringArray = PackedStringArray()
	var side_falls: PackedStringArray = PackedStringArray()
	var army := Balance.start_army(0)
	for level in levels:
		var def := LevelGen.build(level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, level)
		var boss := ArsenalData.is_boss(level)
		for hero in heroes:
			var acc := account_for(level, kind, hero)
			if inv:
				invasion_fix(acc, level)
			var prof: Dictionary
			var prof_t: Dictionary
			if run_prof:
				prof_t = run_profile_of(acc, level, hero)
				prof = prof_t.duplicate()
				prof.erase("team")
			else:
				prof = LevelSim.profile_from_account(acc, level, kind)
				prof_t = prof.duplicate()
				prof_t["team"] = Meta.team_block_of(acc, hero)
			scale_front_hp(prof_t["team"], front_hp)
			# The team's run meets the heroes-phase enemy budget (LevelGen.team_demand), as the Run builds it.
			var dem := LevelGen.team_demand(level, prof_t)
			var lv_t := LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY, dem), level)
			var res_t: Dictionary = LevelSim.best_path(lv_t, hero, army, {"profile": prof_t})
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
				var front := StringName(str(m["slot"])) == ChampionKinds.FRONT
				var bucket := ("fb" if boss else "fc") if front else "side"
				for key: String in ["all", hero]:
					var t: Array = (tally[key] as Dictionary)[bucket]
					t[0] = int(t[0]) + (1 if alive else 0)
					t[1] = int(t[1]) + 1
				if not alive and front:
					falls.append(tag)
				elif not alive:
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
	for h in heroes:
		var th: Dictionary = tally[h]
		_say("CHAMP_SURVIVAL_HERO %-5s front_campaign=%s front_boss=%s side_rear=%s (%s)" % [h, _pct(th["fc"]),
				_pct(th["fb"]), _pct(th["side"]), _counts(th)])
	var ta: Dictionary = tally["all"]
	_say("CHAMP_SURVIVAL front_campaign=%s front_boss=%s side_rear=%s levels=%d wins=%d" % [_pct(ta["fc"]),
			_pct(ta["fb"]), _pct(ta["side"]), runs, wins] + " base_wins=%d win_delta=%+.1f%% (%.1f s)" % [base_wins,
			wr - wr0, float(Time.get_ticks_msec() - t0) / 1000.0])
	_say("  %s; targets front >= 75%%, boss 40-60%%, side / rear >= 90%%" % _counts(ta))
	EconData.phase_override = old_phase
	if args.has("out"):
		_write(str(args["out"]), "champ_survival_%s_%d_%d_%s%s%s%s.txt" % [kind, levels[0], levels[-1],
				"_".join(heroes), "_run" if run_prof else "", "_inv" if inv else "",
				"" if is_equal_approx(front_hp, 1.0) else "_fhp%.2f" % front_hp])
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


## Meta.run_profile(level) for `acc` led by `hero` (the account and Save.hero swapped in, restored), under the
## phase in effect: phase 0 gives the Meta-1 hero block, HEROES_RUN_PHASE the v3 block and the team block.
static func run_profile_of(acc: Dictionary, level: int, hero: String) -> Dictionary:
	var keep := [Meta.account, str(Save.hero)]
	Meta.account = acc
	Save.hero = hero
	var prof: Dictionary = Meta.run_profile(level)
	Meta.account = keep[0]
	Save.hero = str(keep[1])
	return prof


## Meta.synthetic_account caps the EXPECTED hero level and Barracks by world_of(level), which starts again at 1
## past CAMPAIGN_LEVELS (the hero at L60 is Lv9, at L56 Lv15); a real account keeps world_reached 7 and the
## Invasion hero cap. An Invasion level's account gets world_reached 7, its leveled heroes the EXPECTED hero
## level under the Invasion cap and its Barracks the EXPECTED row under the W7 cap. Campaign levels: no change.
static func invasion_fix(acc: Dictionary, level: int) -> void:
	if level <= ArsenalData.CAMPAIGN_LEVELS:
		return
	var row: Dictionary = Meta._expected_row(level)
	(acc["progress"] as Dictionary)["world_reached"] = 7
	var hs: Dictionary = acc["heroes"]
	for h: String in hs:
		if h in Meta.SYNTH_HERO_ENTRIES or EconData.heroes_run():
			(hs[h] as Dictionary)["lvl"] = clampi(int(row["hero_lvl"]), 1, EconData.hero_cap(7, true))
	var bar: Dictionary = row["barracks"]
	for t in EconData.BARRACKS_ORDER:
		(acc["barracks"] as Dictionary)[t] = mini(EconData.barracks_cap(7), int(bar.get(t, 0)))


## --front_hp: the HP of every team row whose kit slot is front (Guardian, Warrior) x k, wherever it stands.
static func scale_front_hp(team: Dictionary, k: float) -> void:
	if is_equal_approx(k, 1.0):
		return
	for st: Dictionary in team.get("champions", []):
		if str((ChampionData.CHAMPIONS.get(str(st["id"]), {}) as Dictionary).get("slot", "")) == "front":
			st["hp"] = float(st["hp"]) * k


static func _buckets() -> Dictionary:
	return {"fc": [0, 0], "fb": [0, 0], "side": [0, 0]}


## "alive / samples: front campaign a/n, front boss a/n, side / rear a/n".
static func _counts(t: Dictionary) -> String:
	return "alive / samples: front campaign %d/%d, front boss %d/%d, side / rear %d/%d" % [int(t["fc"][0]),
			int(t["fc"][1]), int(t["fb"][0]), int(t["fb"][1]), int(t["side"][0]), int(t["side"][1])]


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
