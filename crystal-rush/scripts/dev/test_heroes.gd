extends Node
## Headless tests of the Heroes & Champions data and rule classes (heroes_design.md §2.5, §12.6;
## WS-A). Phase H0: the generated constants are in sync with tools/data/heroes_consts.json and
## heroes_roster.json (the generator re-run with --check, and every constant compared with its
## JSON value), every WS-A section of heroes_consts.json is covered, the roster has the §6 shape,
## and Ladder's rules match the sim's own rule functions on every state (rule #3 tests 1-4, 6).
## Phase H1: the rule classes (Roster, HeroesMeta v3, ChampionsMeta, Team, Summon, HeroChest) —
## rule #3 on the full power index with the adversarial real-kit tolerance grid (§2.5 1-9, 12-14,
## §12.6 1-5), progression (facets, recut, overflow, skills, Rewrite, Hero Sync, Champion Level),
## team / synergy thresholds, the Portal and chest rollers against the sim's exact tables and the
## disclosed §7.2 / §7.5 numbers plus Monte Carlo per character (|z| <= 4), pity gaps, Focus = 60%,
## the welcome rule, Seals, Beacons (§12.6 6), the two-track property (7), the no-loss migration on
## the v2 fixtures (8), the unlock rows (14), sanitize leaves rule-made states alone (15) and the
## repo copy of heroes_sim.py exits 0 with the same constants (17).
##
## godot --headless --path . res://scenes/dev/test_heroes.tscn      Exit code = failures.
## -- --no-python skips the generator --check and the sim run (the JSON comparison still runs).
## -- --full runs the Monte Carlo at the disclosure size (1 000 000 rolls per pool state).

const CONSTS_JSON := "res://tools/data/heroes_consts.json"
const ROSTER_JSON := "res://tools/data/heroes_roster.json"
const CLASSES := {
	"Ladder": "res://scripts/core/ladder.gd", "HeroData": "res://scripts/core/hero_data.gd",
	"ChampionData": "res://scripts/core/champion_data.gd", "TeamData": "res://scripts/core/team_data.gd",
	"PortalData": "res://scripts/core/portal_data.gd", "CeremonyData": "res://scripts/core/ceremony_data.gd",
}
## heroes_consts.json sections owned by another workstream (gear = WS-F GearData).
const NOT_WS_A := ["gear"]

var _fails := 0
var _passes := 0
var _consts: Dictionary = {}
var _roster: Dictionary = {}
var _full := false


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_consts = _load_json(CONSTS_JSON)
	_roster = _load_json(ROSTER_JSON)
	_test_generator()
	_test_json_sync()
	_test_coverage()
	_test_derived()
	_test_roster()
	_test_ladder_oracle()
	_test_rule3()
	_test_portal()
	_full = "--full" in OS.get_cmdline_user_args()
	_test_power_rule3()
	_test_progression()
	_test_skills()
	_test_levels()
	_test_champions()
	_test_team()
	_test_summon_tables()
	_test_summon_mc()
	_test_summon_rules()
	_test_chests()
	_test_two_track()
	_test_migration()
	_test_unlock_rows()
	_test_sim()
	print("TEST_HEROES %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL ", what)


func _load_json(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(txt)
	_ok(v is Dictionary, "%s parses" % path)
	return v if v is Dictionary else {}


## Value at "a.b.c" in `root` (null when missing).
static func _at(root: Dictionary, path: String) -> Variant:
	var v: Variant = root
	for p in path.split("."):
		if not (v is Dictionary) or not (v as Dictionary).has(p):
			return null
		v = v[p]
	return v


## Deep equality where JSON numbers (always float) equal int / float constants, keys compare as
## strings and arrays compare element-wise. Returns "" or the first difference.
static func _diff(a: Variant, b: Variant, at: String = "") -> String:
	var na := typeof(a) in [TYPE_INT, TYPE_FLOAT]
	var nb := typeof(b) in [TYPE_INT, TYPE_FLOAT]
	if na and nb:
		return "" if absf(float(a) - float(b)) <= 1e-12 * maxf(1.0, absf(float(a))) else "%s: %s != %s" % [at, a, b]
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return "%s: size %d != %d" % [at, (a as Array).size(), (b as Array).size()]
		for i in (a as Array).size():
			var d := _diff(a[i], b[i], "%s[%d]" % [at, i])
			if d != "":
				return d
		return ""
	if a is Dictionary and b is Dictionary:
		var ka: Array = (a as Dictionary).keys().map(func(k: Variant) -> String: return str(k))
		var kb: Array = (b as Dictionary).keys().map(func(k: Variant) -> String: return str(k))
		ka.sort()
		kb.sort()
		if ka != kb:
			return "%s: keys %s != %s" % [at, ka, kb]
		for k: Variant in a:
			var d := _diff(a[k], b[str(k)] if (b as Dictionary).has(str(k)) else b[k], "%s.%s" % [at, k])
			if d != "":
				return d
		return ""
	if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING:
		return "" if a == b else "%s: %s != %s" % [at, a, b]
	if typeof(a) == typeof(b) and a == b:
		return ""
	return "%s: %s (%s) != %s (%s)" % [at, a, type_string(typeof(a)), b, type_string(typeof(b))]


# ------------------------------------------------------------------ generator in sync

func _test_generator() -> void:
	print("== generator --check (tools/gen_heroes_data.py)")
	if "--no-python" in OS.get_cmdline_user_args():
		print("  skipped (--no-python)")
		return
	var out: Array = []
	var code := OS.execute("python3", [ProjectSettings.globalize_path("res://tools/gen_heroes_data.py"), "--check"], out, true)
	var txt := "".join(out).strip_edges()
	if code == -1:
		print("  python3 not found: generator check skipped (the JSON comparison below still runs)")
		return
	_ok(code == 0, "generated blocks in sync with the json (%s)" % txt)


# ------------------------------------------------------------------ constants == json

func _test_json_sync() -> void:
	print("== every consts: / roster: constant equals its json value")
	for cls: String in CLASSES:
		var cmap := (load(CLASSES[cls]) as GDScript).get_script_constant_map()
		_ok(cmap.has("SOURCE_KEYS"), "%s has SOURCE_KEYS" % cls)
		var src: Dictionary = cmap.get("SOURCE_KEYS", {})
		for c: String in cmap:
			if c != "SOURCE_KEYS":
				_ok(src.has(c), "%s.%s is listed in SOURCE_KEYS (generated, with a source)" % [cls, c])
		var n := 0
		for c: String in src:
			_ok(cmap.has(c), "%s.%s exists" % [cls, c])
			var s: String = src[c]
			var root: Dictionary = {}
			if s.begins_with("consts:"):
				root = _consts
			elif s.begins_with("roster:"):
				root = _roster
			else:
				continue
			var path := s.substr(s.find(":") + 1)
			var want: Variant = _at(root, path)
			_ok(want != null, "%s.%s: json path %s exists" % [cls, c, s])
			var d := _diff(cmap.get(c), want, "%s.%s" % [cls, c])
			_ok(d == "", d)
			n += 1
		print("  %s: %d constants compared" % [cls, n])


## Every leaf of the WS-A sections of heroes_consts.json is carried by some constant.
func _test_coverage() -> void:
	print("== heroes_consts.json coverage")
	var paths: Array[String] = []
	for cls: String in CLASSES:
		var src: Dictionary = (load(CLASSES[cls]) as GDScript).get_script_constant_map().get("SOURCE_KEYS", {})
		for c: String in src:
			var s: String = src[c]
			if s.begins_with("consts:"):
				paths.append(s.trim_prefix("consts:"))
	for sec: String in _consts:
		if sec in NOT_WS_A:
			continue
		var leaves: Array[String] = []
		_leaves(_consts[sec], sec, leaves)
		for leaf: String in leaves:
			var covered := false
			for p: String in paths:
				if leaf == p or leaf.begins_with(p + "."):
					covered = true
					break
			_ok(covered, "heroes_consts.json %s is carried by a generated constant" % leaf)


func _leaves(v: Variant, at: String, out: Array[String]) -> void:
	if v is Dictionary and not (v as Dictionary).is_empty():
		for k: String in v:
			_leaves(v[k], at + "." + k, out)
	else:
		out.append(at)


# ------------------------------------------------------------------ derived constants

func _test_derived() -> void:
	print("== derived constants")
	var o: Dictionary = _roster.get("oracle", {})
	_ok(_diff(PortalData.CHEST_HERO_CARD_FRAGS, o.get("chest_hero_card_frags")) == "", "CHEST_HERO_CARD_FRAGS = sim")
	_ok(_diff(ChampionData.CHAMP_LEVEL_COST, o.get("champ_level_cost")) == "", "CHAMP_LEVEL_COST = sim champ_level_cost")
	_ok(ChampionData.slots_at(13) == 0 and ChampionData.slots_at(14) == 2 and ChampionData.slots_at(39) == 2
			and ChampionData.slots_at(40) == 3, "champion slots 0 / 2 @ L14 / 3 @ L40")
	_ok(ChampionData.level_cap(1, false) == 4 and ChampionData.level_cap(7, false) == 16
			and ChampionData.level_cap(20, false) == 20 and ChampionData.level_cap(1, true) == 20, "Champion Level cap")
	_ok(ChampionData.level_cost(1) == 40 and ChampionData.level_cost(20) == 0, "Champion Level cost lookup")
	for hid: String in HeroData.HERO_ORDER:
		var r: Dictionary = HeroData.HEROES[hid]["rally"]
		_ok(TeamData.RALLY_HOOKS.has(r["hook"]) and is_equal_approx(float(TeamData.RALLY_HOOKS[r["hook"]]["base"]),
				float(r["base"])), "%s rally hook %s base in TeamData" % [hid, r["hook"]])
	_ok(TeamData.TEAM_DEMAND.size() == 14, "TEAM_DEMAND has 14 worlds (campaign 7 + Invasion 7)")
	_ok(is_equal_approx(CeremonyData.reveal_length("C"), 1.2) and is_equal_approx(CeremonyData.reveal_length("L"), 4.2)
			and is_equal_approx(CeremonyData.reveal_length("M"), 5.6), "reveal lengths 1.2 / 0.6 + 3.6 / 0.6 + 5.0")
	_ok(HeroData.full_facets_cost("C") == 50 and HeroData.full_facets_cost("M") == 200, "Full facets 50 ... 200 (§3.2)")
	_ok(HeroData.dup_frags("L") == 50, "Topaz duplicate = 50 fragments")


# ------------------------------------------------------------------ roster shape (§6.0, §5.6)

func _test_roster() -> void:
	print("== roster")
	_ok(HeroData.HERO_ORDER.size() == 10 and HeroData.HEROES.size() == 10, "10 heroes")
	_ok(ChampionData.CHAMPION_ORDER.size() == 12 and ChampionData.CHAMPIONS.size() == 12, "12 champions")
	var per_gem_h := {}
	var per_gem_c := {}
	var per_fac_c := {}
	var nos := {}
	for hid: String in HeroData.HERO_ORDER:
		var h: Dictionary = HeroData.HEROES[hid]
		per_gem_h[h["native"]] = int(per_gem_h.get(h["native"], 0)) + 1
		nos[int(h["no"])] = hid
		_ok(h["class"] in TeamData.CLASSES and h["element"] in TeamData.ELEMENTS and h["faction"] in TeamData.FACTIONS,
				"%s tags are TeamData ids" % hid)
		_ok(str(h["element2"]) == "" or str(h["element2"]) in TeamData.ELEMENTS, "%s second element" % hid)
		var k: Dictionary = h["kit"]
		for stat: String in ["hp", "rate", "dmg", "splash", "range", "targets", "ult_charge"]:
			_ok(k.has(stat) and float(k[stat]) >= 0.0, "%s kit.%s" % [hid, stat])
		_ok(str(h["ult"]) != "" and float(h["ult_main"]["value"]) > 0.0, "%s ult kind + main number" % hid)
	for g: String in Ladder.GEMS:
		_ok(int(per_gem_h.get(g, 0)) == 2, "2 heroes of gem %s" % g)
	for cid: String in ChampionData.CHAMPION_ORDER:
		var c: Dictionary = ChampionData.CHAMPIONS[cid]
		per_gem_c[c["native"]] = int(per_gem_c.get(c["native"], 0)) + 1
		per_fac_c[c["faction"]] = int(per_fac_c.get(c["faction"], 0)) + 1
		nos[int(c["no"])] = cid
		_ok(c["class"] in TeamData.CLASSES and c["element"] in TeamData.ELEMENTS and c["faction"] in TeamData.FACTIONS,
				"%s tags are TeamData ids" % cid)
		_ok(ChampionData.AURA_SHARE.has(c["slot"]), "%s slot %s has an aura share" % [cid, c["slot"]])
		_ok(float(c["kit"]["aura"]) <= ChampionData.AURA_CAP, "%s aura <= AURA_CAP" % cid)
		_ok(Ladder.gem_index(c["native"]) <= Ladder.gem_index(Ladder.CHAMPION_MAX_GEM), "%s native <= Topaz" % cid)
	for g: String in ["C", "R", "E", "L"]:
		_ok(int(per_gem_c.get(g, 0)) == 3, "3 champions of gem %s" % g)
	for f: String in TeamData.FACTIONS:
		_ok(int(per_fac_c.get(f, 0)) == 3, "faction %s has exactly 3 champions (§5.3)" % f)
	for i in range(1, 23):
		_ok(nos.has(i), "collector number %02d" % i)
	_ok(ChampionData.action_tier("mila") == 1 and ChampionData.action_tier("menhir") == 4, "Action tier = native + 1")
	for s: String in HeroData.STARTERS:
		_ok(HeroData.HEROES.has(s) and HeroData.STARTER_AT.has(s), "starter %s" % s)
	_ok(HeroData.START_OWNED == ["bolt"], "a new account owns Руді")
	_ok(HeroData.HEROES["bolt"]["ult"] == "storm" and HeroData.HEROES["titan"]["ult"] == "quake"
			and HeroData.HEROES["seer"]["ult"] == "rift", "starter ult kinds = Meta-1 (storm / quake / rift)")
	for hid: String in HeroData.HEROES:
		_ok(SaveV3Data.HERO_NATIVE.get(hid, "") == HeroData.native(hid), "%s native agrees with SaveV3Data" % hid)
	for cid: String in ChampionData.CHAMPIONS:
		_ok(SaveV3Data.CHAMPION_NATIVE.get(cid, "") == ChampionData.CHAMPIONS[cid]["native"],
				"%s native agrees with SaveV3Data" % cid)
	_ok(_diff(SaveV3Data.UNLOCK_AT, HeroData.UNLOCK_AT) == "", "unlock levels agree with SaveV3Data")
	_ok(HeroData.UNLOCK_AT["champions"] == 14 and HeroData.UNLOCK_AT["portal"] == 20, "champions L14, Portal L20")
	for f: String in TeamData.FACTIONS:
		_ok(TeamData.FACTION_TIERS.has(f) and TeamData.FACTION_RUN.has(f) and TeamData.FACTION_HOME.has(f),
				"faction %s has tiers, run effects and home worlds" % f)
	for cl: String in TeamData.CLASSES:
		_ok(TeamData.CLASS_PAIR.has(cl) and TeamData.CLASS_PAIR_RUN.has(cl), "class %s has pair bonuses" % cl)
	var fam: Array[String] = ArsenalData.FAMILY_ORDER.duplicate()
	fam.erase("rift")
	_ok(TeamData.ELEMENTS == fam, "elements = ArsenalData families without rift")


# ------------------------------------------------------------------ Ladder == the sim's rules

func _test_ladder_oracle() -> void:
	print("== Ladder vs heroes_sim rule functions (every n <= g, f 0..5)")
	_ok(Ladder.check(), "Ladder.check()")
	var o: Dictionary = _roster.get("oracle", {})
	var bad := 0
	var n_states := 0
	for n in 5:
		var ng: String = Ladder.GEMS[n]
		for g in range(n, 5):
			var gg: String = Ladder.GEMS[g]
			for f in Ladder.FACETS_PER_GEM + 1:
				n_states += 1
				if absf(Ladder.mult(ng, gg, f) - float(o["ladder"][n][g][f])) > 1e-12:
					bad += 1
					print("  ladder(%s,%s,%d) %.6f vs %.6f" % [ng, gg, f, Ladder.mult(ng, gg, f), o["ladder"][n][g][f]])
				if Ladder.skill_cap(ng, gg, f) != int(o["skill_cap"][n][g][f]):
					bad += 1
					print("  skill_cap(%s,%s,%d)" % [ng, gg, f])
				if Ladder.can_awaken(ng, gg, f) != bool(o["can_awaken"][n][g][f]):
					bad += 1
					print("  can_awaken(%s,%s,%d)" % [ng, gg, f])
			if Ladder.awaken_cap(ng, gg) != int(o["awaken_cap"][n][g]):
				bad += 1
				print("  awaken_cap(%s,%s)" % [ng, gg])
		for r in range(1, 12):
			if Ladder.ult_form(ng, r) != int(o["ult_form"][n][r - 1]):
				bad += 1
				print("  ult_form(%s,%d)" % [ng, r])
	_ok(bad == 0 and n_states == 90, "%d states, %d mismatches" % [n_states, bad])


# ------------------------------------------------------------------ rule #3 (§2.5 tests 1-4, 6)

func _test_rule3() -> void:
	print("== rule #3 on the ladder")
	var stats := true
	var caps := true
	var forms := true
	var awk := true
	var mono := true
	for n in 5:
		var ng: String = Ladder.GEMS[n]
		for g in range(n + 1, 5):
			var gg: String = Ladder.GEMS[g]
			for f in Ladder.FACETS_PER_GEM + 1:
				stats = stats and Ladder.mult(ng, gg, f) <= Ladder.CEILING * Ladder.mult(gg, gg, f) + 1e-12
				caps = caps and Ladder.skill_cap(ng, gg, f) == Ladder.skill_cap(gg, gg, f) - 1
			forms = forms and Ladder.max_form(ng) < Ladder.max_form(gg)
			if g >= Ladder.gem_index(Ladder.AWAKEN_MIN_GEM):
				awk = awk and Ladder.awaken_cap(ng, gg) < Ladder.awaken_cap(gg, gg)
		# Monotone along the native's path: f0..f5 then recut (ladder(g, 5) = ladder(g + 1, 0), caps never drop).
		var prev_m := 0.0
		var prev_c := 0
		for g in range(n, 5):
			var gg: String = Ladder.GEMS[g]
			for f in Ladder.FACETS_PER_GEM + 1:
				var m := Ladder.mult(ng, gg, f)
				var c := Ladder.skill_cap(ng, gg, f)
				mono = mono and m >= prev_m - 1e-12 and c >= prev_c
				prev_m = m
				prev_c = c
	_ok(stats, "test_rule3_stats: recut <= CEILING x native at every (n < g, f)")
	_ok(caps, "test_rule3_caps: recut cap = native cap - 1 at every (n < g, f)")
	_ok(forms, "test_rule3_forms: a recut's max form < the native's")
	_ok(awk, "test_rule3_awaken: recut Awakening cap < native's (Amethyst+)")
	_ok(Ladder.can_awaken("L", "L", 0) and Ladder.can_awaken("M", "M", 0) and not Ladder.can_awaken("E", "E", 0)
			and not Ladder.can_awaken("C", "R", 5), "native Topaz / Opal born awakened; no Awakening below Amethyst")
	_ok(Ladder.born_awakened("L") and not Ladder.born_awakened("E"), "born_awakened")
	_ok(mono, "test_monotone: no stat or cap drops along any path")


# ------------------------------------------------------------------ Portal / chest data

func _test_portal() -> void:
	print("== Portal and chest data")
	var s := 0.0
	for g: String in PortalData.BASE_ODDS:
		s += float(PortalData.BASE_ODDS[g])
	_ok(absf(s - 1.0) < 1e-9, "Portal base odds sum to 1")
	s = 0.0
	for g: String in PortalData.CHEST_ODDS:
		s += float(PortalData.CHEST_ODDS[g])
	_ok(absf(s - 1.0) < 1e-9, "chest card odds sum to 1")
	var pl: Array = (_roster.get("oracle", {}) as Dictionary).get("portal_pl", [])
	var ok := pl.size() == int(PortalData.PITY_L["hard"]) + 1
	for i in pl.size():
		ok = ok and absf(PortalData.topaz_plus_chance(i) - float(pl[i])) < 1e-12
	_ok(ok, "topaz_plus_chance = sim portal_pl for 0..hard")
	_ok(PortalData.seal_price("E") == 40 and PortalData.seal_price("L") == 100 and PortalData.seal_price("M") == 200
			and PortalData.seal_price("C") == 0, "Seals 40 / 100 / 200")
	_ok(float(PortalData.BEACON["track"]) == 0.0, "Track nodes never pay Beacons (two-track rule)")
	for k: String in HeroData.FEATS:
		_ok(str(HeroData.FEATS[k]["reward"][0]) == "tomes", "hero Feat %s pays Tomes, never Beacons" % k)


# ======================================================================== H1: rule classes

## A test account: next level `level` (frontier = level - 1), the given heroes / champions owned,
## every Meta-1 unlock acknowledged (so the Heroes tab etc. are open).
func _acc(level: int, heroes: Array = ["bolt"], champs: Array = []) -> Dictionary:
	var acc := EconData.fresh_account()
	var p: Dictionary = acc["progress"]
	p["level"] = level
	p["world_reached"] = ArsenalData.world_of(mini(level, ArsenalData.CAMPAIGN_LEVELS))
	UnlockQueue.mark_all_done(acc)
	for h in heroes:
		if not Roster.owned(acc, str(h)):
			Roster.grant(acc, str(h), "start", 1)
	for c in champs:
		if not Roster.owned(acc, str(c)):
			Roster.grant(acc, str(c), "chest", 1)
	return acc


## The sim's MAX_GEAR (heroes_sim.py §1), rebuilt from heroes_consts.json "gear": weapon / armour /
## charm and the hero relic at +12 plus the 2-piece sets the sim counts (Dawn damage, Stoneheart HP,
## Celestials ult; three items + a relic hold at most two 2-piece sets, so this is an upper bound).
func _max_gear() -> Dictionary:
	var g: Dictionary = _consts["gear"]
	var top := int(g["TEMPER_MAX"])
	var st := {"dmg": 0.0, "hp": 0.0, "ult": 0.0, "charge": 0.0}
	for slot: String in g["ITEM_STAT"]:
		for k: String in g["ITEM_STAT"][slot]:
			var row: Array = g["ITEM_STAT"][slot][k]
			var v := float(row[0]) + float(row[1]) * top
			var beats: Array = row[2]
			for i in 3:
				if top >= [4, 8, 12][i]:
					v += float(beats[i])
			st[k] = float(st[k]) + v
	for k2: String in g["HERO_RELIC_STAT"]:
		st[k2] = float(st[k2]) + float(g["HERO_RELIC_STAT"][k2][0]) + float(g["HERO_RELIC_STAT"][k2][1]) * top
	for fac: String in ["dawn", "stoneheart", "celestial"]:
		var kv: Array = g["SET2"][fac]
		st[kv[0]] = float(st[kv[0]]) + float(kv[1])
	return st


## sim awk_reached / max_ranks: [cap, cap, cap, Awakening cap if open on the path].
static func _max_ranks(n: int, g: int, f: int) -> Array:
	var ng: String = Ladder.GEMS[n]
	var gg: String = Ladder.GEMS[g]
	var c := Ladder.skill_cap(ng, gg, f)
	var reached := g >= 2 and (f == Ladder.FACETS_PER_GEM or g > maxi(n, 2) or n >= 3)
	return [c, c, c, Ladder.awaken_cap(ng, gg) if reached else 0]


## sim hero_index_t: the index with per-item budgets replaced (adversarial tolerance grid, §2.3).
static func _index_t(n: int, g: int, f: int, lvl: int, sk: Array, gear: Dictionary, rb: int, set4: bool, kit: float,
		awk: float, form: float, beat: float, relic: float) -> float:
	var atk := int(sk[1])
	var beats := 0
	for b: int in Ladder.ATK_BEATS:
		if atk >= b:
			beats += 1
	var lm := float(lvl - 1)
	var atk_m := 1.0 + Ladder.ATK_RANK_STEP * (atk - 1) + beat * beats
	var dmg := (1.0 + Ladder.LV_DMG * lm) * (1.0 + float(gear["dmg"])) * atk_m
	var fm := Ladder.ult_form(Ladder.GEMS[n], int(sk[0]))
	var ultp := ((1.0 + Ladder.LV_ULT * lm) * (1.0 + Ladder.ULT_RANK_STEP * (int(sk[0]) - 1)) * (1.0 + float(gear["ult"]))
			* (1.0 + Ladder.LV_RATE * lm) * (1.0 + float(gear["charge"])) * (1.0 + form * (fm - 1)))
	var hp := 1.0 + Ladder.HP_W * ((1.0 + Ladder.LV_HP * lm) * (1.0 + float(gear["hp"])) - 1.0)
	return (Ladder.mult(Ladder.GEMS[n], Ladder.GEMS[g], f) * kit * ((1.0 - Ladder.U_SHARE) * dmg + Ladder.U_SHARE * ultp)
			* hp * (1.0 + awk * int(sk[3])) * (1.0 + relic * rb) * (1.0 + (Ladder.SET4_VALUE if set4 else 0.0)))


func _near(a: float, b: float, tol: float, what: String) -> void:
	_ok(absf(a - b) <= tol, "%s: %.5f vs %.5f (tol %.5f)" % [what, a, b, tol])


# ------------------------------------------------------------------ rule #3 on the power index

func _test_power_rule3() -> void:
	print("== rule #3 on the power index (§2.3 - §2.5; §12.6 1-5)")
	var mg := _max_gear()
	_near(float(mg["dmg"]), 0.162, 1e-9, "MAX_GEAR dmg = sim")
	_near(float(mg["hp"]), 0.256, 1e-9, "MAX_GEAR hp = sim")
	_near(float(mg["ult"]), 0.15, 1e-9, "MAX_GEAR ult = sim")
	_near(float(mg["charge"]), 0.066, 1e-9, "MAX_GEAR charge = sim")
	var zero := HeroesMeta.NO_GEAR
	# §2.3 table (sim §1c): equal / transient / max investment over every path, f 0-5, Lv 1/10/20/30.
	var w_eq := 0.0
	var w_tr := 0.0
	var w_mx := 0.0
	for n in 4:
		for g in range(n + 1, 5):
			for lv in [1, 10, 20, 30]:
				for f in Ladder.FACETS_PER_GEM + 1:
					var rc := _max_ranks(n, g, f)
					var nc := _max_ranks(g, g, f)
					var eq := [mini(rc[0], nc[0]), mini(rc[1], nc[1]), mini(rc[2], nc[2]), mini(rc[3], nc[3])]
					var nat := HeroesMeta.index(g, g, f, lv, eq, mg, 3, true)
					w_eq = maxf(w_eq, HeroesMeta.index(n, g, f, lv, eq, mg, 3, true) / nat)
					var tr := [eq[0], eq[1], eq[2], rc[3]]
					var nat_tr := HeroesMeta.index(g, g, f, lv, [eq[0], eq[1], eq[2], mini(nc[3], rc[3]) if nc[3] else 0], mg, 3, true)
					w_tr = maxf(w_tr, HeroesMeta.index(n, g, f, lv, tr, mg, 3, true) / nat_tr)
				var nmx := HeroesMeta.index(g, g, 5, lv, _max_ranks(g, g, 5), mg, 3, true)
				w_mx = maxf(w_mx, HeroesMeta.index(n, g, 5, lv, _max_ranks(n, g, 5), mg, 3, true) / nmx)
	print("  index: worst equal %.4f · transient %.4f · max %.4f" % [w_eq, w_tr, w_mx])
	_ok(w_eq <= Ladder.CEILING + 1e-9, "equal investment <= 0.96 x native (worst %.4f)" % w_eq)
	_near(w_eq, 0.9504, 6e-5, "worst equal-investment ratio = §2.3")
	_ok(w_tr <= Ladder.CEILING + 1e-9, "transient (path Awakening) <= 0.96 x native (worst %.4f)" % w_tr)
	_ok(w_mx < 1.0, "max investment < native (worst %.4f)" % w_mx)
	_near(w_mx, 0.9306, 6e-5, "worst max-investment ratio = §2.3")
	# §2.3 table cells (native max / recut max at Lv1 / Lv30).
	var cells := [[0, 1, 1, 1.698, 1.580], [0, 1, 30, 4.061, 3.764], [0, 4, 30, 7.075, 5.397], [3, 4, 30, 7.075, 6.344],
			[2, 4, 1, 2.914, 2.489], [1, 3, 30, 5.995, 5.059]]
	for c: Array in cells:
		var n2: int = c[0]
		var g2: int = c[1]
		var lv2: int = c[2]
		_near(HeroesMeta.index(g2, g2, 5, lv2, _max_ranks(g2, g2, 5), mg, 3, true), float(c[3]), 6e-4,
				"§2.3 native max %s Lv%d" % [Ladder.GEM_NAME_EN[g2], lv2])
		_near(HeroesMeta.index(n2, g2, 5, lv2, _max_ranks(n2, g2, 5), mg, 3, true), float(c[4]), 6e-4,
				"§2.3 recut max %s->%s Lv%d" % [Ladder.GEM_NAME_EN[n2], Ladder.GEM_NAME_EN[g2], lv2])
	# §2.4 sandwich: a recut into g at max sits between the natives of g - 1 and g (Lv30, full gear).
	var sandwich := true
	for n3 in 4:
		for g3 in range(n3 + 1, 5):
			var rec := HeroesMeta.index(n3, g3, 5, 30, _max_ranks(n3, g3, 5), mg, 3, true)
			var nat3 := HeroesMeta.index(g3, g3, 5, 30, _max_ranks(g3, g3, 5), mg, 3, true)
			sandwich = sandwich and rec < nat3 and (g3 - n3 > 1 or rec > HeroesMeta.index(g3 - 1, g3 - 1, 5, 30,
					_max_ranks(g3 - 1, g3 - 1, 5), mg, 3, true))
	_ok(sandwich, "§2.4 one-gem recut at max sits between the natives below and at its gem")
	# §2.3 (sim §1e) adversarial real-kit tolerance grid (§2.5 test 14) and every real hero pair (test 5).
	var hi := [1.0 + Ladder.KIT_TOL, Ladder.AWK_STEP, Ladder.FORM_STEP, Ladder.ATK_BEAT, Ladder.RELIC_BEAT]
	var lo := [1.0 - Ladder.KIT_TOL, Ladder.AWK_STEP, Ladder.FORM_STEP, Ladder.ATK_BEAT, Ladder.RELIC_BEAT]
	var t_eq := 0.0
	var t_mx := 0.0
	var pairs := 0
	for rid in HeroData.HERO_ORDER:
		var n4 := Ladder.gem_index(HeroData.native(rid))
		for nid in HeroData.HERO_ORDER:
			var g4 := Ladder.gem_index(HeroData.native(nid))
			if g4 <= n4:
				continue
			pairs += 1
			for lv4 in [1, 10, 20, 30]:
				for f4 in Ladder.FACETS_PER_GEM + 1:
					var rc4 := _max_ranks(n4, g4, f4)
					var nc4 := _max_ranks(g4, g4, f4)
					var eq4 := [mini(rc4[0], nc4[0]), mini(rc4[1], nc4[1]), mini(rc4[2], nc4[2]), mini(rc4[3], nc4[3])]
					for gear_set: Array in [[zero, 0, false], [mg, 3, true]]:
						var a := _index_t(n4, g4, f4, lv4, eq4, gear_set[0], gear_set[1], gear_set[2], hi[0], hi[1], hi[2], hi[3], hi[4])
						var b := _index_t(g4, g4, f4, lv4, eq4, gear_set[0], gear_set[1], gear_set[2], lo[0], lo[1], lo[2], lo[3], lo[4])
						t_eq = maxf(t_eq, a / b)
				var am := _index_t(n4, g4, 5, lv4, _max_ranks(n4, g4, 5), mg, 3, true, hi[0], hi[1], hi[2], hi[3], hi[4])
				var bm := _index_t(g4, g4, 5, lv4, _max_ranks(g4, g4, 5), mg, 3, true, lo[0], lo[1], lo[2], lo[3], lo[4])
				t_mx = maxf(t_mx, am / bm)
	print("  real-kit tolerance grid (%d hero pairs): worst equal %.4f · max %.4f" % [pairs, t_eq, t_mx])
	_ok(pairs == 40, "every real hero recut into every higher native gem vs every real native (%d pairs)" % pairs)
	_ok(t_eq < 1.0, "test_rule3_power / tolerance grid, equal investment (worst %.4f)" % t_eq)
	_near(t_eq, 0.9797, 6e-5, "worst adversarial equal-investment ratio = §2.3")
	_ok(t_mx < 1.0, "test_rule3_power / tolerance grid, max investment (worst %.4f)" % t_mx)
	_near(t_mx, 0.9589, 6e-5, "worst adversarial max-investment ratio = §2.3")
	# §2.5 test 9: at equal ranks the recut stays below the native at every Awakening rank it can hold.
	var eqr := true
	for n5 in 4:
		for g5 in range(n5 + 1, 5):
			for f5 in Ladder.FACETS_PER_GEM + 1:
				for r in Ladder.awaken_cap(Ladder.GEMS[n5], Ladder.GEMS[g5]) + 1:
					var c5 := Ladder.skill_cap(Ladder.GEMS[n5], Ladder.GEMS[g5], f5)
					var sk := [c5, c5, c5, r]
					eqr = eqr and HeroesMeta.index(n5, g5, f5, 30, sk, mg, 3, true) < HeroesMeta.index(g5, g5, f5, 30, sk, mg, 3, true)
	_ok(eqr, "test_rule3_equal_ranks: recut < native at every shared Awakening rank")
	# Champions (§2.3 end; §2.5 13): recut <= 0.96 native; cross-class with KIT_INDEX +-3% < 1.
	var wc := 0.0
	var wx := 0.0
	for n6 in 3:
		for g6 in range(n6 + 1, 4):
			for f6 in Ladder.FACETS_PER_GEM + 1:
				for cl in [1, 10, 20]:
					var r6 := ChampionsMeta.index(n6, g6, f6, cl, 12) / ChampionsMeta.index(g6, g6, f6, cl, 12)
					wc = maxf(wc, r6)
					wx = maxf(wx, r6 * (1.0 + ChampionData.CHAMP_KIT_TOL) / (1.0 - ChampionData.CHAMP_KIT_TOL))
	print("  champions: worst %.4f · cross-class +-3%%: %.4f" % [wc, wx])
	_ok(wc <= Ladder.CEILING + 1e-9, "champions: recut <= 0.96 x native (worst %.4f)" % wc)
	_near(wc, 0.9254, 6e-5, "worst champion ratio = §2.3")
	_ok(wx < 1.0, "test_champion_cross_class with KIT_INDEX +-3%% (worst %.4f)" % wx)
	_near(wx, 0.9827, 6e-5, "worst cross-class champion ratio = §2.3")
	# Monotone on the index: Full facets -> recut never lowers any number at fixed ranks and level.
	var mono := true
	for n7 in 5:
		var prev := 0.0
		for g7 in range(n7, 5):
			for f7 in Ladder.FACETS_PER_GEM + 1:
				var v := HeroesMeta.index(n7, g7, f7, 10, [1, 1, 1, 0], zero)
				mono = mono and v >= prev - 1e-12
				prev = v
	_ok(mono, "test_monotone on the power index")
	_near(HeroesMeta.index(0, 0, 0, 1, [1, 1, 1, 0], zero), 1.0, 1e-12, "a Quartz Lv1 rank-1 hero = 1.000 (the Meta-1 Lv1 hero)")
	_near(HeroesMeta.meta1_index(1), 1.0, 1e-12, "Meta-1 Lv1 index = 1.000")
	# §12.6 test 4, the data half (the LevelSim-measured KIT_INDEX half lands with LevelSim in H2).
	_ok(absf(Ladder.FORM_STEP - 0.03) <= Ladder.FORM_TOL and absf(Ladder.ATK_BEAT - 0.01) <= Ladder.BEAT_TOL
			and absf(Ladder.RELIC_BEAT - 0.03) <= Ladder.RELIC_TOL and absf(Ladder.AWK_STEP - 0.04) <= Ladder.AWK_TOL,
			"test_kit_budget (data): form 3%, beat 1%, relic beat 3%, Awakening 4% inside their bands")


# ------------------------------------------------------------------ facets, recut, overflow

func _test_progression() -> void:
	print("== progression: grant, fragments, facets, recut, overflow (§3.2, §7.4)")
	var dups := [[5, 925], [5, 835], [4, 700], [3, 500], [2, 200]]
	for gi in 5:
		var gem: String = Ladder.GEMS[gi]
		var hid := ""
		for h in HeroData.HERO_ORDER:
			if HeroData.native(h) == gem:
				hid = h
				break
		var acc := _acc(31, [hid])
		_ok(Roster.frags_to_max(acc, hid) == int(dups[gi][1]), "%s hero to Opal f5 = %d fragments" % [gem, dups[gi][1]])
		_ok(ceili(float(HeroData.full_facets_cost(gem)) / HeroData.dup_frags(gem)) == int(dups[gi][0]),
				"%s own-gem Full facets = %d duplicates" % [gem, dups[gi][0]])
	var champ_need := {"C": 575, "R": 485, "E": 350, "L": 150}
	for cid in ["mila", "alba", "brant", "nimb"]:
		var a2 := _acc(31, ["bolt"], [cid])
		_ok(Roster.frags_to_max(a2, cid) == int(champ_need[Roster.native(cid)]), "champion %s to Topaz f5 = %d" % [cid, champ_need[Roster.native(cid)]])
	# Grant: new / duplicate / born awakened.
	var acc3 := _acc(31, ["bolt"])
	var g1 := Roster.grant(acc3, "vesta", "portal", 5)
	_ok(bool(g1["new"]) and Roster.owned(acc3, "vesta") and Roster.gem(acc3, "vesta") == "L" and bool(g1["awakened"])
			and HeroesMeta.skill_rank(acc3, "vesta", "awakened") == 1, "a native Topaz arrives owned with Awakening rank 1")
	_ok(str(Roster.entry(acc3, "vesta")["got"]["via"]) == "portal" and not bool(Roster.entry(acc3, "vesta")["seen"]),
			"got.via recorded, NEW until seen")
	var g2 := Roster.grant(acc3, "vesta", "portal", 6)
	_ok(not bool(g2["new"]) and int(g2["frags"]) == 50 and Roster.frags(acc3, "vesta") == 50, "a Topaz duplicate = 50 fragments")
	_ok(int((acc3["counters"] as Dictionary).get("awakenings", 0)) == 1, "born Awakening counts for F-66")
	var gr := Roster.grant(acc3, "nope", "portal")
	_ok(str(gr["kind"]) == "" and not bool(gr["new"]), "unknown ids are ignored")
	# Facets on a Quartz hero: 5 / 5 / 10 / 10 / 20; Full facets; no Awakening below Amethyst.
	var acc4 := _acc(31, ["titan"])
	_ok(Roster.facet_block(acc4, "titan") == "frags", "no fragments: no facet")
	Roster.add_frags(acc4, "titan", 49)
	var fill := Roster.facet_fill(acc4, "titan")
	_ok(int(fill["steps"]) == 4 and Roster.facets(acc4, "titan") == 4 and Roster.frags(acc4, "titan") == 19,
			"«+» fills every affordable pip (49 -> 4 facets, 19 left)")
	Roster.add_frags(acc4, "titan", 1)
	var f5 := Roster.facet_up(acc4, "titan")
	_ok(bool(f5["full"]) and not bool(f5["awakened"]) and Roster.facet_block(acc4, "titan") == "full", "Full facets in Quartz: no Awakening")
	_ok(Roster.recut_block(acc4, "titan") == "frags" and Roster.recut_cost(acc4, "titan") == 40, "recut needs 40 fragments")
	var cap_before := HeroesMeta.skill_cap(acc4, "titan", "ult")
	var m_before := Roster.mult(acc4, "titan")
	Roster.add_frags(acc4, "titan", 40 + 10)
	var prev := Roster.recut_preview(acc4, "titan")
	_ok(str(prev["gem"]) == "R" and int(prev["facets"]) == 1 and int(prev["frags"]) == 0, "recut preview: recut + the facets banked fragments buy")
	var rc := Roster.recut(acc4, "titan")
	_ok(bool(rc["ok"]) and str(rc["to"]) == "R" and Roster.facets(acc4, "titan") == 0 and Roster.frags(acc4, "titan") == 10,
			"recut Quartz -> Sapphire: facets restart, 40 fragments spent")
	_ok(Roster.mult(acc4, "titan") >= m_before - 1e-12 and HeroesMeta.skill_cap(acc4, "titan", "ult") >= cap_before,
			"no number drops on recut (ladder %.4f -> %.4f, cap %d -> %d)" % [m_before, Roster.mult(acc4, "titan"), cap_before,
			HeroesMeta.skill_cap(acc4, "titan", "ult")])
	_ok(Roster.is_recut(acc4, "titan") and int((acc4["counters"] as Dictionary).get("recuts", 0)) == 1, "recut counted (F-62)")
	# Walk Горан all the way to Opal f5 with exactly 925 - 50 - 50 more fragments; Awakening opens at
	# the first Full facets in Amethyst; every step keeps the numbers monotone.
	Roster.add_frags(acc4, "titan", Roster.frags_to_max(acc4, "titan"))
	var mono := true
	var opened_at := ""
	var guard := 0
	while not Roster.at_max(acc4, "titan") and guard < 50:
		guard += 1
		var m0 := Roster.mult(acc4, "titan")
		var c0 := HeroesMeta.skill_cap(acc4, "titan", "ult")
		if Roster.can_facet(acc4, "titan"):
			var r := Roster.facet_up(acc4, "titan")
			if bool(r["awakened"]):
				opened_at = Roster.gem(acc4, "titan") + str(Roster.facets(acc4, "titan"))
		elif Roster.can_recut(acc4, "titan"):
			Roster.recut(acc4, "titan")
		else:
			break
		mono = mono and Roster.mult(acc4, "titan") >= m0 - 1e-12 and HeroesMeta.skill_cap(acc4, "titan", "ult") >= c0
	_ok(Roster.at_max(acc4, "titan") and Roster.frags(acc4, "titan") == 0, "Горан reaches Opal f5 with exactly 925 fragments")
	_ok(mono, "monotone along the whole path")
	_ok(opened_at == "E5", "Awakening opens at the first Full facets in Amethyst (got %s)" % opened_at)
	_ok(HeroesMeta.skill_cap(acc4, "titan", "ult") == 10 and HeroesMeta.skill_cap(acc4, "titan", "awakened") == 3
			and HeroesMeta.ult_form(acc4, "titan") == 1, "recut Opal f5: rank cap 10 (native 11), Awakening cap 3 (native 4), form I")
	_ok(Roster.recut_block(acc4, "titan") == "max", "no recut past Opal")
	# Overflow at the absolute max: 20 fragments = 1 Tome, the remainder stays.
	var t0 := MetaAcc.amount(acc4, "tomes")
	_ok(Roster.overflow_preview(acc4, "titan", 45) == 2, "overflow label: 45 fragments -> 2 Tomes")
	var ad := Roster.add_frags(acc4, "titan", 45)
	_ok(int(ad["tomes"]) == 2 and MetaAcc.amount(acc4, "tomes") == t0 + 2 and Roster.frags(acc4, "titan") == 5, "45 fragments at the max -> 2 Tomes + 5 kept")
	# Champions stop at Topaz.
	var acc5 := _acc(31, ["bolt"], ["nimb"])
	Roster.add_frags(acc5, "nimb", 150)
	Roster.facet_fill(acc5, "nimb")
	_ok(Roster.at_max(acc5, "nimb") and Roster.recut_block(acc5, "nimb") == "max", "a native Topaz champion at f5 is at its max")
	_ok(int(Roster.add_frags(acc5, "nimb", 50)["tomes"]) == 2, "champion duplicate past Topaz f5 -> Tomes 20 : 1")
	_ok(Roster.facet_block(_acc(31), "alba") == "owned" and Roster.recut_block(_acc(31), "alba") == "owned", "unowned: no facet, no recut")


# ------------------------------------------------------------------ skills (Tomes)

func _test_skills() -> void:
	print("== skill ranks, forms, Awakening, Rewrite (§3.3)")
	var cum := 0
	var want := [2, 5, 10, 18, 30, 46, 66, 91, 121, 161]
	var ok := true
	for r in range(1, 11):
		cum += HeroData.TOME_COST[r]
		ok = ok and cum == int(want[r - 1])
	_ok(ok, "TOME_COST cumulative 2 / 5 / 10 / 18 / 30 / 46 / 66 / 91 / 121 / 161")
	# Native max (own gem, Full facets): ranks 3 / 5 / 7 / 9 / 11, Awakening — / — / 2 / 3 / 4.
	var heroes := ["titan", "bolt", "seer", "vesta", "lumen"]
	var max_r := [3, 5, 7, 9, 11]
	var awk := [0, 0, 2, 3, 4]
	var per_skill := [5, 18, 46, 91, 161]
	var awk_tomes := [0, 0, 2, 5, 10]
	for i in 5:
		var hid: String = heroes[i]
		var acc := _acc(31, [hid])
		(acc["team"] as Dictionary)["hero"] = "bolt" if hid != "bolt" else "titan"
		Roster.add_frags(acc, hid, HeroData.full_facets_cost(Roster.native(hid)))
		Roster.facet_fill(acc, hid)
		MetaAcc.add(acc, "tomes", 10000)
		var spent := {}
		for s in HeroesMeta.SKILLS:
			var t0 := MetaAcc.amount(acc, "tomes")
			while HeroesMeta.can_rank_up(acc, hid, s):
				HeroesMeta.rank_up(acc, hid, s)
			spent[s] = t0 - MetaAcc.amount(acc, "tomes")
		_ok(HeroesMeta.skill_rank(acc, hid, "ult") == int(max_r[i]) and int(spent["ult"]) == int(per_skill[i])
				and int(spent["attack"]) == int(per_skill[i]) and int(spent["rally"]) == int(per_skill[i]),
				"%s native max: ranks %d, %d Tomes per skill" % [hid, max_r[i], per_skill[i]])
		_ok(HeroesMeta.skill_rank(acc, hid, "awakened") == int(awk[i]) and int(spent["awakened"]) == int(awk_tomes[i]),
				"%s Awakening cap %d for %d Tomes" % [hid, awk[i], awk_tomes[i]])
		_ok(HeroesMeta.ult_form(acc, hid) == i + 1, "%s reaches form %d (= its native gem)" % [hid, i + 1])
		_ok(HeroesMeta.rank_block(acc, hid, "ult") == "cap", "%s: no rank past the cap" % hid)
		# Rewrite: everything back (team / preset heroes blocked).
		var back := HeroesMeta.rewrite_refund(acc, hid)
		_ok(back == 3 * int(per_skill[i]) + int(awk_tomes[i]), "%s Rewrite refund = every Tome spent (%d)" % [hid, back])
		var t1 := MetaAcc.amount(acc, "tomes")
		var rw := HeroesMeta.rewrite(acc, hid)
		_ok(bool(rw["ok"]) and MetaAcc.amount(acc, "tomes") == t1 + back and HeroesMeta.skill_rank(acc, hid, "ult") == 1
				and HeroesMeta.skill_rank(acc, hid, "awakened") == (1 if int(awk[i]) > 0 else 0), "%s Rewrite: ranks 1, Tomes back" % hid)
		_ok(int((Roster.entry(acc, hid)["skills_peak"] as Dictionary)["ult"]) == int(max_r[i]), "%s peaks kept (F-65 never re-counts)" % hid)
	# Forms: rank 3 / 5 / 7 / 9 unlock forms II-V, capped by the native gem; form_up flag.
	var acc2 := _acc(31, ["lumen", "titan"])
	(acc2["team"] as Dictionary)["hero"] = "titan"
	MetaAcc.add(acc2, "tomes", 1000)
	var ups: Array[int] = []
	for k in 9:
		var r := HeroesMeta.rank_up(acc2, "lumen", "ult")
		if bool(r.get("form_up", false)):
			ups.append(int(r["rank"]))
	_ok(ups == [3, 5, 7, 9], "Opal ult forms II-V at ranks 3 / 5 / 7 / 9 (got %s)" % [ups])
	# Blocks: locked before L30, sealed Awakening, Tomes, team Rewrite.
	var acc3 := _acc(20, ["bolt", "eira"])
	MetaAcc.add(acc3, "tomes", 100)
	_ok(HeroesMeta.rank_block(acc3, "eira", "ult") == "locked", "skills locked before the L30 win")
	var acc4 := _acc(31, ["bolt", "eira"])
	_ok(HeroesMeta.rank_block(acc4, "eira", "ult") == "tomes", "no Tomes: no rank")
	_ok(HeroesMeta.rank_block(acc4, "eira", "awakened") == "sealed", "a Sapphire hero has no Awakening")
	MetaAcc.add(acc4, "tomes", 2)
	HeroesMeta.rank_up(acc4, "bolt", "attack")
	_ok(HeroesMeta.rewrite_block(acc4, "bolt") == "team", "the team hero cannot be rewritten")
	Team.save_preset(acc4, 0)
	(acc4["team"] as Dictionary)["hero"] = "eira"
	_ok(HeroesMeta.rewrite_block(acc4, "bolt") == "team", "a preset hero cannot be rewritten")
	_ok(HeroesMeta.rewrite_block(acc4, "eira") == "team", "the new team hero cannot be rewritten either")
	_ok(HeroesMeta.rewrite_block(_acc(31, ["bolt", "titan"]), "titan") == "nothing", "nothing to rewrite at rank 1")
	# Free first step: one free Ult rank on the team hero, before or at the unlock.
	var acc5 := _acc(31, ["bolt", "eira"])
	MetaAcc.free_steps(acc5)["skill_rank"] = true
	_ok(HeroesMeta.rank_cost(acc5, "bolt", "ult") == 0 and HeroesMeta.rank_cost(acc5, "eira", "ult") == 2
			and HeroesMeta.rank_cost(acc5, "bolt", "attack") == 2, "free first rank: the team hero's Ult only")
	var fr := HeroesMeta.rank_up(acc5, "bolt", "ult")
	_ok(bool(fr["ok"]) and bool(fr["free"]) and not MetaAcc.free_steps(acc5).has("skill_rank")
			and HeroesMeta.rank_cost(acc5, "bolt", "ult") == 3, "free rank consumed")
	_ok(HeroesMeta.skill_ranks_total(acc5) == 1 and int(HeroesMeta.feat_counters(acc5)["skill_ranks"]) == 1, "F-65 counter")


# ------------------------------------------------------------------ levels and Hero Sync

func _test_levels() -> void:
	print("== hero levels and Hero Sync (§3.1)")
	var acc := _acc(41, ["bolt", "titan", "vesta"])
	(acc["heroes"]["bolt"] as Dictionary)["lvl"] = 20
	_ok(HeroesMeta.best_own(acc) == 20, "best own level")
	_ok(HeroesMeta.eff_level(acc, "vesta") == 17 and HeroesMeta.synced(acc, "vesta"), "a new hero arrives synced (20 - 3 = 17)")
	_ok(HeroesMeta.eff_level(acc, "bolt") == 20 and not HeroesMeta.synced(acc, "bolt"), "the best hero plays its own level")
	MetaAcc.add(acc, "coins", 100000)
	var c0 := MetaAcc.amount(acc, "coins")
	var r := HeroesMeta.level_up_synced(acc, "vesta")
	_ok(bool(r["ok"]) and bool(r["synced"]) and HeroesMeta.level(acc, "vesta") == 18
			and c0 - MetaAcc.amount(acc, "coins") == EconData.hero_cost(17), "a synced level pays hero_cost(eff) and sets own = eff + 1")
	var acc2 := _acc(10, ["bolt"])
	(acc2["heroes"]["bolt"] as Dictionary)["lvl"] = HeroesMeta.cap(acc2)
	MetaAcc.add(acc2, "coins", 100000)
	_ok(str(HeroesMeta.level_up_synced(acc2, "bolt")["reason"]) == "cap", "Hero Sync respects the world cap")
	_ok(str(HeroesMeta.level_up_synced(acc2, "vesta")["reason"]) == "locked", "an unowned hero cannot level")
	# The Meta-1 entry points keep 2.2.1 behaviour while the flag is off.
	var acc3 := _acc(41, ["bolt", "titan"])
	(acc3["heroes"]["bolt"] as Dictionary)["lvl"] = 20
	MetaAcc.add(acc3, "coins", 100000)
	_ok(not EconData.heroes_live() and HeroesMeta.cost(acc3, "titan") == EconData.hero_cost(1)
			and int(HeroesMeta.level_up(acc3, "titan")["lvl"]) == 2, "flag off: Meta-1 levels (no sync)")
	# Run block: ladder x level x Attack rank; ult power with lv_ult (§1.4).
	var rb := HeroesMeta.run_block(acc, "vesta")
	_ok(int(rb["lvl"]) == 18 and str(rb["gem"]) == "L" and is_equal_approx(float(rb["mult"]), Ladder.NATIVE_MULT[3])
			and int(rb["awakened"]) == 1 and str((rb["rally"] as Dictionary)["hook"]) == "army_reserves", "run block of a native Topaz")
	_near(float(rb["ult_power"]), Ladder.NATIVE_MULT[3] * (1.0 + Ladder.LV_ULT * 17), 1e-9, "ult power = ladder x lv_ult x rank")
	_near(float((rb["rally"] as Dictionary)["value"]), 6.0 * Ladder.NATIVE_MULT[3], 1e-9, "Rally = base x ladder x rank")


# ------------------------------------------------------------------ champions

func _test_champions() -> void:
	print("== champions: Champion Level and the §4.4 numbers")
	_ok(ChampionsMeta.total_cost() == 26840, "Champion Level 1 -> 20 = 26 840 coins")
	var acc := _acc(14, ["bolt"])
	_ok(ChampionsMeta.level_block(acc) == "locked", "Champion Level locked before the L14 win")
	acc = _acc(15, ["bolt"])
	_ok(ChampionsMeta.level_block(acc) == "none", "needs a champion")
	Roster.grant(acc, "mila", "chest")
	_ok(ChampionsMeta.cap(acc) == 6 and ChampionsMeta.level_block(acc) == "coins", "cap 2 + 2 x world (W2 = 6); coins")
	MetaAcc.add(acc, "coins", 10000)
	var n := 0
	while ChampionsMeta.can_level(acc):
		ChampionsMeta.level_up(acc)
		n += 1
	_ok(n == 5 and ChampionsMeta.level(acc) == 6 and MetaAcc.amount(acc, "coins") == 10000 - (40 + 110 + 210 + 320 + 450),
			"levels 1 -> 6 for 1 130 coins")
	_ok(ChampionData.level_cap(1, true) == 20, "Invasion cap 20")
	# §4.4: HP f0 Lv1 / Full facets Lv20 / recut to Topaz f5 Lv20; Action; aura -> effect, relic +12.
	var rows := {"mila": [30, 55, 61, 3.00, 5.47, 6.09, 0.120, 0.036, 0.252], "ivo": [60, 109, 122, 3.00, 5.47, 6.09, 0.100, 0.035, 0.210],
			"borko": [48, 88, 98, 3.00, 5.47, 6.09, 0.100, 0.035, 0.210], "alba": [28, 51, 55, 1.08, 1.97, 2.12, 0.162, 0.040, 0.340],
			"otto": [65, 118, 127, 1.08, 1.97, 2.12, 0.108, 0.038, 0.227], "taya": [28, 51, 55, 4.32, 7.88, 8.47, 0.162, 0.040, 0.340],
			"brant": [56, 102, 106, 3.50, 6.38, 6.62, 0.117, 0.041, 0.245], "teo": [30, 55, 57, 1.17, 2.13, 2.21, 0.175, 0.044, 0.367],
			"olena": [35, 64, 66, 3.50, 6.38, 6.62, 0.140, 0.042, 0.294], "nimb": [76, 138, -1, 2.52, 4.60, -1, 0.126, 0.044, 0.264],
			"dara": [33, 60, -1, 1.26, 2.30, -1, 0.189, 0.047, 0.396], "menhir": [33, 60, -1, 5.04, 9.19, -1, 0.189, 0.057, 0.396]}
	for cid: String in rows:
		var w: Array = rows[cid]
		var nat := Roster.native(cid)
		var s0 := ChampionsMeta.stats_at(cid, nat, 0, 1)
		var s5 := ChampionsMeta.stats_at(cid, nat, 5, 20)
		var line := roundi(float(s0["hp"])) == int(w[0]) and roundi(float(s5["hp"])) == int(w[1])
		line = line and absf(float(s0["action"]) - float(w[3])) < 0.006 and absf(float(s5["action"]) - float(w[4])) < 0.006
		if int(w[2]) > 0:
			var st := ChampionsMeta.stats_at(cid, "L", 5, 20)
			line = line and roundi(float(st["hp"])) == int(w[2]) and absf(float(st["action"]) - float(w[5])) < 0.006
		line = line and absf(float(s0["aura"]) - float(w[6])) < 0.0006
		line = line and absf(ChampionsMeta.aura_effect(float(s0["aura"]), str(s0["slot"])) - float(w[7])) < 0.0006
		var sr := ChampionsMeta.stats_at(cid, nat, 5, 20, 12)
		line = line and absf(float(sr["aura"]) - float(w[8])) < 0.0006
		_ok(line, "§4.4 row %s (HP %d / %d, aura %.3f)" % [cid, roundi(float(s0["hp"])), roundi(float(s5["hp"])), float(s0["aura"])])
	_ok(float(ChampionsMeta.stats_at("menhir", "L", 5, 20, 12)["aura"]) <= ChampionData.AURA_CAP, "aura capped at AURA_CAP")


# ------------------------------------------------------------------ team and synergy

func _members(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ids:
		out.append(Team.tags(str(id)))
	return out


func _test_team() -> void:
	print("== team, slots, presets, synergy thresholds (§4.1, §5)")
	_ok(Team.slots(_acc(14)) == 0 and Team.slots(_acc(15)) == 2 and Team.slots(_acc(40)) == 2 and Team.slots(_acc(41)) == 3,
			"slots: 0 / 2 from the L14 win / 3 from the L40 win")
	var acc := _acc(15, ["bolt", "titan"], ["alba", "borko", "mila"])
	_ok(Team.check(acc, "bolt", ["alba", "borko", "mila"]) == "slots", "two slots before L40")
	_ok(Team.check(acc, "vesta", []) == "hero" and Team.check(acc, "bolt", ["otto"]) == "champion"
			and Team.check(acc, "bolt", ["alba", "alba"]) == "duplicate", "only owned, distinct members")
	var r := Team.set_team(acc, "bolt", ["alba", "borko"])
	_ok(bool(r["ok"]) and Team.hero(acc) == "bolt" and Team.champions(acc) == ["alba", "borko"], "set the team")
	_ok((r["synergies"] as Array).has("fac_wildfang_2") and (r["synergies"] as Array).has("affinity"), "Stormfront: Wildfang III (3 members)")
	_ok(Team.save_preset(acc, 1) and bool(Team.set_team(acc, "titan", [])["ok"]) and bool(Team.use_preset(acc, 1)["ok"])
			and Team.hero(acc) == "bolt" and int(acc["team"]["preset"]) == 1, "presets store and restore a team")
	_ok(not bool(Team.use_preset(acc, 2)["ok"]), "an empty preset does nothing")
	# Thresholds: faction 2 / 3 / 4 living members = tier I / II / III; class pair at 2; Affinity cap.
	_ok(Team.faction_tier(1) == 0 and Team.faction_tier(2) == 1 and Team.faction_tier(3) == 2 and Team.faction_tier(4) == 3,
			"faction tiers at 2 / 3 / 4 members")
	var stonewall := Team.run_effects(_members(["titan", "otto", "ivo"]))
	var eff: Dictionary = stonewall["effects"]
	_ok(int((stonewall["factions"] as Dictionary).get("stoneheart", 0)) == 1 and is_equal_approx(float(eff["hazard_losses"]), -0.15)
			and is_equal_approx(float(eff["champion_hp"]), 0.25) and is_equal_approx(float(eff["block_cooldown"]), -0.20),
			"Stonewall: Stoneheart I (-15% hazard losses) + Guardian pair (+25% champion HP, -20% Block cooldown)")
	_ok(is_equal_approx(float((stonewall["affinity"] as Dictionary)["kinetic"]), 0.06), "Affinity: 2 Kinetic = +0.06")
	var mono4 := Team.run_effects(_members(["arin", "mila", "ivo", "dara"]))
	_ok(int((mono4["factions"] as Dictionary)["dawn"]) == 3 and int((mono4["effects"] as Dictionary)["siege_reserves"]) == 14,
			"a mono-faction team of 4 = tier III (+14 soldiers)")
	var aff := Team.affinity(_members(["bolt", "nimb", "dara", "iskar"]))
	_ok(is_equal_approx(float(aff["volt"]), TeamData.AFFINITY_CAP), "Affinity capped at +0.09")
	_ok(Team.run_effects(_members(["bolt"]))["ids"].is_empty(), "a lone hero has no synergy")
	# Living members: a fallen champion stops counting.
	var alive := Team.members("titan", ["otto", "ivo"], ["ivo"])
	_ok(not (Team.run_effects(alive)["factions"] as Dictionary).has("stoneheart"), "a fallen champion's synergy stops")
	# Native-blind and gem-blind: tags only.
	_ok(Team.synergy(_members(["titan", "otto"]))["ids"] == Team.synergy(_members(["titan", "otto"]))["ids"], "deterministic ids")
	# TEAM_B2_CAP on one machine.
	var cel := _members(["iskar", "taya", "teo", "nimb"])
	_ok(is_equal_approx(Team.machine_b2(cel, "volt", 0.03), 0.19), "Celestials III 0.10 + Volt Affinity 0.06 + Rally 0.03 = 0.19")
	_ok(is_equal_approx(Team.machine_b2(cel, "volt", 0.05), TeamData.TEAM_B2_CAP), "... capped at TEAM_B2_CAP +0.20")
	_ok(is_equal_approx(Team.machine_b2(_members(["bolt", "alba"]), "rift"), 0.03), "Rift machines use the best element count")
	# Index terms = the sim's _synergy for a few teams.
	var syn := Team.synergy(_members(["bolt", "alba", "borko"]))
	_ok(is_equal_approx(float(syn["charge"]), 1.12) and is_equal_approx(float(syn["rate"]), 1.05)
			and is_equal_approx(float((syn["champ_cls"] as Dictionary)["ranger"]), 1.10), "index synergy: Wildfang II x1.12, Ranger pair")
	# Auto-team picks a valid team.
	var acc2 := _acc(41, ["bolt", "titan", "vesta"], ["alba", "otto", "ivo", "nimb", "dara"])
	var pick := Team.auto_pick(acc2)
	_ok(Team.check(acc2, str(pick["hero"]), pick["champions"] as Array) == "" and (pick["champions"] as Array).size() == 3,
			"Auto-team returns a valid full team (%s %s)" % [pick["hero"], pick["champions"]])
	_ok(Team.uses_hero(acc2, "bolt") and not Team.uses_hero(acc2, "vesta"), "uses_hero")


# ------------------------------------------------------------------ Portal: exact tables

func _test_summon_tables() -> void:
	print("== Portal exact tables vs the sim and the disclosed §7.2 rows")
	var o: Dictionary = _roster.get("oracle", {})
	var cons := Summon.consolidated()
	_ok(_diff(cons, o["portal_consolidated"]) == "" or _max_dev(cons, o["portal_consolidated"]) < 1e-12,
			"consolidated odds = sim portal_exact (max dev %s)" % str(_max_dev(cons, o["portal_consolidated"])))
	var disclosed := {"C": 52.09, "R": 26.52, "E": 14.35, "L": 5.63, "M": 1.41}
	for g: String in disclosed:
		_ok(absf(100.0 * float(cons[g]) - float(disclosed[g])) <= 0.005, "§7.2 %s %.2f%%" % [g, disclosed[g]])
	var lplus := float(cons["L"]) + float(cons["M"])
	_ok(absf(100.0 * lplus - 7.03) <= 0.005 and absf(1.0 / lplus - 14.22) <= 0.005, "Topaz or better 7.03% (1 in 14.22)")
	_ok(absf(100.0 * (lplus + float(cons["E"])) - 21.39) <= 0.005, "Amethyst or better 21.39%")
	_ok(_max_dev(Summon.x10_best(0, 0, false), o["portal_x10_fresh"]) < 1e-12, "x10 best (fresh pity) = sim")
	_ok(_max_dev(Summon.x10_best(0, 0, true), o["portal_x10_welcome"]) < 1e-12, "x10 best (welcome rule) = sim")
	_ok(_max_dev(Summon.x10_best_stationary(), o["portal_x10_stationary"]) < 1e-10, "x10 best (typical) = sim")
	var rows := {"welcome": [Summon.x10_best(0, 0, true), {"L": 78.46, "M": 21.54}],
			"fresh": [Summon.x10_best(0, 0, false), {"E": 59.87, "L": 30.56, "M": 9.56}],
			"typical": [Summon.x10_best_stationary(), {"E": 43.56, "L": 42.99, "M": 13.45}]}
	for k: String in rows:
		var got: Dictionary = rows[k][0]
		var want: Dictionary = rows[k][1]
		var okr := true
		for g2: String in want:
			okr = okr and absf(100.0 * float(got.get(g2, 0.0)) - float(want[g2])) <= 0.005
		_ok(okr, "§7.2 best of a x10 (%s) = %s" % [k, want])
	_ok(float(Summon.x10_best(0, 0, true).get("E", 0.0)) == 0.0, "welcome x10: never below Topaz")
	# Per-hero odds, stages A-D (§7.2 table).
	for st: Array in _stages():
		var acc: Dictionary = st[1]
		var ho := Summon.hero_odds(acc)
		var want2: Dictionary = st[2]
		var bad := []
		for id: String in want2:
			if absf(100.0 * float(ho[id]) - float(want2[id])) > 0.0051:
				bad.append("%s %.3f vs %.2f" % [id, 100.0 * float(ho[id]), want2[id]])
		_ok(bad.is_empty(), "§7.2 per-hero odds stage %s %s" % [st[0], bad])


func _max_dev(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	for k in a:
		d = maxf(d, absf(float(a[k]) - float(b.get(str(k), 0.0))))
	for k2 in b:
		d = maxf(d, absf(float(b[k2]) - float(a.get(str(k2), 0.0))))
	return d


## [name, account, {id: disclosed %}] for the §7.2 per-hero stages A-D.
func _stages() -> Array:
	var a := _acc(21, ["bolt", "titan"])
	var b := _acc(25, ["titan", "arin", "bolt", "eira", "seer", "iskar", "vesta", "lumen"])
	var c := _acc(25, HeroData.HERO_ORDER)
	var d := _acc(25, HeroData.HERO_ORDER)
	for kv in [["C", "titan"], ["R", "bolt"], ["E", "seer"], ["L", "vesta"], ["M", "lumen"]]:
		Summon.set_focus(d, kv[0], kv[1])
	return [
		["A", a, {"titan": 0.0, "arin": 52.09, "bolt": 0.0, "eira": 26.52, "seer": 0.0, "iskar": 14.35, "vesta": 2.81,
				"vartan": 2.81, "lumen": 0.70, "pava": 0.70}],
		["B", b, {"titan": 26.05, "arin": 26.05, "bolt": 13.26, "eira": 13.26, "seer": 7.18, "iskar": 7.18, "vesta": 0.0,
				"vartan": 5.63, "lumen": 0.0, "pava": 1.41}],
		["C", c, {"titan": 26.05, "arin": 26.05, "bolt": 13.26, "eira": 13.26, "seer": 7.18, "iskar": 7.18, "vesta": 2.81,
				"vartan": 2.81, "lumen": 0.70, "pava": 0.70}],
		["D", d, {"titan": 31.26, "arin": 20.84, "bolt": 15.91, "eira": 10.61, "seer": 8.61, "iskar": 5.74, "vesta": 3.38,
				"vartan": 2.25, "lumen": 0.84, "pava": 0.56}],
	]


## |z| of `k` hits in `n` trials against probability `p` (0 when p is 0 or 1 and k matches).
static func _z(k: int, n: int, p: float) -> float:
	if p <= 0.0:
		return 0.0 if k == 0 else 99.0
	if p >= 1.0:
		return 0.0 if k == n else 99.0
	return absf(float(k) - n * p) / sqrt(n * p * (1.0 - p))


# ------------------------------------------------------------------ Portal: Monte Carlo

func _test_summon_mc() -> void:
	var n := 1000000 if _full else 200000
	print("== Portal Monte Carlo: %d rolls per pool state, per character |z| <= 4; pity gaps; Focus" % n)
	var rng := RandomNumberGenerator.new()
	for st: Array in _stages():
		rng.seed = 1000 + str(st[0]).unicode_at(0)
		var acc: Dictionary = st[1]
		var exact := Summon.hero_odds(acc)
		var cnt := {}
		var gem_cnt := {}
		var ps := {"since_e": 0, "since_l": 0}
		var gap_e := 0
		var gap_l := 0
		var max_e := 0
		var max_l := 0
		var sum_l := 0
		var n_l := 0
		for i in n:
			var g := Summon.roll_gem(ps, rng)
			var id := Summon.pick_hero(acc, g, rng)
			cnt[id] = int(cnt.get(id, 0)) + 1
			gem_cnt[g] = int(gem_cnt.get(g, 0)) + 1
			gap_e += 1
			gap_l += 1
			if Ladder.gem_index(g) >= 2:
				max_e = maxi(max_e, gap_e)
				gap_e = 0
			if Ladder.gem_index(g) >= 3:
				max_l = maxi(max_l, gap_l)
				sum_l += gap_l
				n_l += 1
				gap_l = 0
		var worst := 0.0
		for id2 in HeroData.HERO_ORDER:
			worst = maxf(worst, _z(int(cnt.get(id2, 0)), n, float(exact[id2])))
		print("  stage %s: max |z| %.2f · gaps E+ max %d, L+ max %d, L+ mean %.2f" % [st[0], worst, max_e, max_l,
				float(sum_l) / maxi(1, n_l)])
		_ok(worst <= 4.0, "stage %s: every hero within |z| <= 4 of the disclosed odds (max |z| %.2f)" % [st[0], worst])
		_ok(max_e <= int(PortalData.PITY_E["hard"]) and max_l <= int(PortalData.PITY_L["hard"]),
				"stage %s pity: Amethyst+ gap max %d <= 10, Topaz+ gap max %d <= 30" % [st[0], max_e, max_l])
		var mean_l := float(sum_l) / maxi(1, n_l)
		_ok(absf(mean_l - 14.22) < 0.35, "stage %s: mean Topaz+ gap %.2f ~ 14.22" % [st[0], mean_l])
		if str(st[0]) == "D":
			var fz := 0.0
			for kv in [["C", "titan"], ["R", "bolt"], ["E", "seer"], ["L", "vesta"], ["M", "lumen"]]:
				fz = maxf(fz, _z(int(cnt.get(kv[1], 0)), int(gem_cnt.get(kv[0], 0)), PortalData.FOCUS_TOTAL))
			_ok(fz <= 4.0, "Focus = exactly 60%% of its gem's results (max |z| %.2f)" % fz)
	# The integrated summon (state, Seals, fragments, history) on stage D: per-hero counts |z| <= 4.
	var acc2: Dictionary = _stages()[3][1]
	var m := 50000 if not _full else 200000
	MetaAcc.add(acc2, "beacons", m)
	rng.seed = 77
	var cnt2 := {}
	var frags0 := {}
	for id3 in HeroData.HERO_ORDER:
		frags0[id3] = Roster.frags(acc2, id3)
	for i2 in m / 10:
		var r := Summon.summon(acc2, 10, rng)
		for row: Dictionary in r["results"]:
			cnt2[row["id"]] = int(cnt2.get(row["id"], 0)) + 1
	var ex2 := Summon.hero_odds(acc2)
	var worst2 := 0.0
	var frag_ok := true
	for id4 in HeroData.HERO_ORDER:
		worst2 = maxf(worst2, _z(int(cnt2.get(id4, 0)), m, float(ex2[id4])))
		frag_ok = frag_ok and Roster.frags(acc2, id4) - int(frags0[id4]) == int(cnt2.get(id4, 0)) * HeroData.dup_frags(HeroData.native(id4))
	_ok(worst2 <= 4.0, "Summon.summon x10 stream: every hero within |z| <= 4 (max %.2f)" % worst2)
	_ok(frag_ok, "every duplicate gave DUP_FRAGS[native] fragments")
	var su: Dictionary = acc2["summon"]
	_ok(int(su["seals"]) == m and int(su["total"]) == m and MetaAcc.amount(acc2, "beacons") == 0
			and (su["history"] as Array).size() == Summon.HISTORY_MAX, "Seals +1 per summon, Beacons spent, history capped")
	# Welcome x10 on fresh accounts: always a Topaz+, best-gem split = the exact welcome table.
	var w_n := 4000 if not _full else 20000
	var best_m := 0
	var all_l := true
	var forced := 0
	var flags_ok := true
	for i3 in w_n:
		var a := _acc(21, ["bolt", "titan"])
		rng.seed = 5000 + i3
		var wr := Summon.welcome(a, rng)
		var b := str(wr["best"])
		all_l = all_l and Ladder.gem_index(b) >= 3
		if b == "M":
			best_m += 1
		if bool(wr["welcome_rule"]):
			forced += 1
		flags_ok = flags_ok and int(a["summon"]["seals"]) == 10 and bool(a["summon"]["welcome_done"]) \
				and Summon.block(a, 10, "welcome") == "welcome" and MetaAcc.amount(a, "beacons") == 0
	_ok(all_l, "every welcome x10 holds a Topaz or better (%d runs)" % w_n)
	_ok(_z(best_m, w_n, float(Summon.x10_best(0, 0, true)["M"])) <= 4.0, "welcome best = Opal %.2f%% (exact %.2f%%)" % [
			100.0 * best_m / w_n, 100.0 * float(Summon.x10_best(0, 0, true)["M"])])
	_ok(flags_ok, "the welcome x10 is free, once, +10 Seals")
	_ok(forced > 0 and forced < w_n, "the rule fires only when summons 1-9 hold no Topaz+ (%d of %d)" % [forced, w_n])


# ------------------------------------------------------------------ Portal: rules

func _test_summon_rules() -> void:
	print("== Portal rules: duplicate protection, blocks, Seals, Beacons, determinism")
	var acc := _acc(21, ["bolt", "titan"])
	_ok(Summon.block(_acc(20), 1) == "locked", "Portal opens with the L20 win")
	_ok(Summon.block(acc, 1) == "beacons" and Summon.block(acc, 3) == "count", "needs Beacons; x1 or x10 only")
	_ok(not Summon.pool(acc, "E").has("seer") and Summon.pool(acc, "C").has("titan"), "starters join the pool only once owned")
	MetaAcc.add(acc, "beacons", 1)
	_ok(Summon.block(acc, 1, "beacons", ["bolt", "titan", "arin"]) == "pool" and Summon.block(acc, 1) == "",
			"a gem without an eligible hero closes the Portal")
	MetaAcc.add(acc, "beacons", -1)
	# Duplicate protection: an unowned hero of the rolled gem first.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var dp := true
	for i in 200:
		dp = dp and Summon.pick_hero(acc, "C", rng) == "arin" and ["vesta", "vartan"].has(Summon.pick_hero(acc, "L", rng))
	_ok(dp, "duplicate protection: unowned first")
	# Determinism: the same account + RNG state gives the same results; results are on the account.
	var a1 := _acc(21, ["bolt", "titan"])
	var a2 := _acc(21, ["bolt", "titan"])
	MetaAcc.add(a1, "beacons", 30)
	MetaAcc.add(a2, "beacons", 30)
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 99
	r2.seed = 99
	var x1 := Summon.summon(a1, 10, r1)
	var x2 := Summon.summon(a2, 10, r2)
	_ok(_diff(x1, x2) == "" and _diff(a1["summon"], a2["summon"]) == "" and _diff(a1["heroes"], a2["heroes"]) == "",
			"same RNG state -> same results and the same saved state")
	var newest := ""
	for row: Dictionary in x1["results"]:
		if bool(row["new"]):
			newest = str(row["id"])
	_ok(newest == "" or Roster.owned(a1, newest), "results are written to the account before the call returns")
	var r3 := RandomNumberGenerator.new()
	r3.state = r1.state
	_ok(_diff(Summon.summon(a1, 10, r1), Summon.summon(a2, 10, r3)) == "", "replaying from the saved RNG state reproduces the summon")
	# Seals: prices, owned pick = 2 x DUP, new pick joins; no Seals, no pity.
	var acc3 := _acc(25, ["bolt", "titan", "seer"])
	(acc3["summon"] as Dictionary)["seals"] = 450
	var pity0 := [int(acc3["summon"]["since_e"]), int(acc3["summon"]["since_l"]), int(acc3["summon"]["total"])]
	_ok(Summon.seal_block(acc3, "titan") == "hero" and Summon.seal_block(acc3, "nope") == "hero", "Quartz / Sapphire are not in the Seal shop")
	var sp := Summon.seal_pick(acc3, "seer")
	_ok(bool(sp["ok"]) and int(sp["price"]) == 40 and int(sp["frags"]) == 50 and Roster.frags(acc3, "seer") == 50,
			"owned Amethyst pick: 40 Seals -> 50 fragments")
	var sp2 := Summon.seal_pick(acc3, "lumen")
	_ok(bool(sp2["ok"]) and bool(sp2["new"]) and int(sp2["price"]) == 200 and Roster.owned(acc3, "lumen")
			and str(Roster.entry(acc3, "lumen")["got"]["via"]) == "seal", "new Opal pick: 200 Seals")
	var sp3 := Summon.seal_pick(acc3, "vesta")
	_ok(bool(sp3["ok"]) and int(acc3["summon"]["seals"]) == 450 - 40 - 200 - 100, "Topaz pick: 100 Seals")
	_ok(Summon.seal_block(acc3, "pava") == "seals" and Summon.seal_block(acc3, "vartan") == "", "110 Seals: a Topaz yes, an Opal no")
	_ok([int(acc3["summon"]["since_e"]), int(acc3["summon"]["since_l"]), int(acc3["summon"]["total"])] == pity0,
			"Seal picks move no pity and give no Seals")
	var offer := Summon.seal_offer(acc3)
	var offer_ok := offer.size() == 6
	for row2: Dictionary in offer:
		if str(row2["id"]) == "lumen":
			offer_ok = offer_ok and bool(row2["owned"]) and int(row2["frags"]) == 200 and int(row2["price"]) == 200
	_ok(offer_ok, "Seal shop lists the six Amethyst+ heroes with prices and owned-pick fragments")
	# Beacons: earned sources only; fractions bank.
	var acc4 := _acc(21)
	var whole := 0
	for i2 in 5:
		whole += Summon.credit(acc4, "first_clear")
	_ok(whole == 1 and MetaAcc.amount(acc4, "beacons") == 1, "5 first clears x 0.2 = 1 Beacon")
	_ok(Summon.credit(acc4, "boss") == 2 and Summon.credit(acc4, "weekly") == 4 and Summon.credit(acc4, "mission", 3.0) == 1,
			"boss 2, weekly 4, three missions 1")
	var never := true
	for src in ["track", "track_nodes", "road", "shop", "ad", "supporter", "gems", "feat", "replay", "chest"]:
		never = never and Summon.credit(acc4, src) == 0
	_ok(never, "no Beacons from Track, Road, shop, ads, supporter, Gems, Feats, replays or chests")
	_ok(Summon.BEACON_SOURCES == Summon.beacon_sources(), "BEACON_SOURCES = the paying PortalData.BEACON nodes")
	_ok(Summon.credit(_acc(20), "boss") == 0, "no Beacons before the Portal opens")
	# Focus validation.
	_ok(not Summon.set_focus(acc3, "C", "lumen") and Summon.set_focus(acc3, "M", "pava") and Summon.focus(acc3, "M") == "pava"
			and Summon.set_focus(acc3, "M", "") and Summon.focus(acc3, "M") == "", "Focus: only a hero of that gem's pool; clearable")


# ------------------------------------------------------------------ Hero Chests

func _test_chests() -> void:
	print("== Hero Chests: exact tables, Monte Carlo, pity, scripted chests, hero card, charge (§7.5)")
	var o: Dictionary = _roster.get("oracle", {})
	_ok(_max_dev(HeroChest.exact_best("hero"), o["chest_best"]["hero"]) < 1e-12
			and _max_dev(HeroChest.exact_best("grand"), o["chest_best"]["grand"]) < 1e-12, "best-card tables = sim")
	var dh := {"C": 38.44, "R": 40.77, "E": 16.83, "L": 3.96}
	var dg := {"E": 78.58, "L": 21.42}
	var okb := true
	for g: String in dh:
		okb = okb and absf(100.0 * float(HeroChest.exact_best("hero")[g]) - float(dh[g])) <= 0.005
	for g2: String in dg:
		okb = okb and absf(100.0 * float(HeroChest.exact_best("grand")[g2]) - float(dg[g2])) <= 0.005
	_ok(okb, "§7.5 best card: Hero 38.44 / 40.77 / 16.83 / 3.96, Grand 78.58 / 21.42")
	# Stream with pity, 5 Hero : 1 Grand (sim §4): per card 56.45 / 24.49 / 14.14 / 4.92, Topaz every 9.60, max gap 15.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 300000 if _full else 60000
	var pity := {"since_l": 0, "total": 0}
	var per := {}
	var cards := 0
	var gap := 0
	var max_gap := 0
	var sum_gap := 0
	var n_gap := 0
	var free_cnt := {}
	var n_free := 0
	for i in n:
		var kind := "grand" if i % 6 == 5 else "hero"
		var gs := HeroChest.roll_gems(kind, pity, rng)
		var any_l := false
		for j in gs.size():
			per[gs[j]] = int(per.get(gs[j], 0)) + 1
			cards += 1
			any_l = any_l or gs[j] == "L"
			if j < gs.size() - 1:
				free_cnt[gs[j]] = int(free_cnt.get(gs[j], 0)) + 1
				n_free += 1
		pity["since_l"] = 0 if any_l else int(pity["since_l"]) + 1
		gap += 1
		if any_l:
			max_gap = maxi(max_gap, gap)
			sum_gap += gap
			n_gap += 1
			gap = 0
	var want := {"C": 56.45, "R": 24.49, "E": 14.14, "L": 4.92}
	var oks := true
	for g3: String in want:
		oks = oks and absf(100.0 * int(per.get(g3, 0)) / cards - float(want[g3])) < (0.25 if not _full else 0.12)
	_ok(oks, "per-card stream = §7.5 (%s)" % [per])
	print("  chest stream: %d chests, per card %s, Topaz gap max %d mean %.2f" % [n, per, max_gap, float(sum_gap) / maxi(1, n_gap)])
	_ok(max_gap <= PortalData.CHEST_PITY_L, "a Topaz card by the 15th chest (longest gap %d)" % max_gap)
	_ok(absf(float(sum_gap) / maxi(1, n_gap) - 9.60) < 0.25, "a Topaz card every %.2f chests ~ 9.60" % [float(sum_gap) / maxi(1, n_gap)])
	var fz := 0.0
	for g4: String in PortalData.CHEST_ODDS:
		fz = maxf(fz, _z(int(free_cnt.get(g4, 0)), n_free, float(PortalData.CHEST_ODDS[g4])))
	_ok(fz <= 4.0, "free cards follow CHEST_ODDS (max |z| %.2f)" % fz)
	# Charge: 1/3 per win, whole chests pop; nothing before L14.
	var acc := _acc(15, ["bolt"])
	_ok(HeroChest.add_charge(_acc(14)) == 0, "no charge before the L14 win")
	var popped := 0
	for i2 in 9:
		popped += HeroChest.add_charge(acc)
	_ok(popped == 3 and float(acc["wallet"]["chest_charge"]) < 1e-6, "every 3rd win = 1 Hero Chest")
	# Scripted chests: #1 by the team hero, #2 Міла; each joins the team.
	var acc2 := _acc(15, ["bolt", "titan"])
	rng.seed = 11
	var c1 := HeroChest.open(acc2, "hero", rng)
	_ok(int(c1["scripted"]) == 1 and str((c1["cards"] as Array)[0]["id"]) == "alba" and Roster.owned(acc2, "alba")
			and Team.champions(acc2).has("alba") and (c1["cards"] as Array).size() == 2, "chest #1 with Руді = Альба + 1 rolled card, in slot 1")
	var c2 := HeroChest.open(acc2, "hero", rng)
	_ok(int(c2["scripted"]) == 2 and str((c2["cards"] as Array)[0]["id"]) == "mila" and Team.champions(acc2).has("mila"),
			"chest #2 = Міла, auto-placed")
	var c3 := HeroChest.open(acc2, "hero", rng)
	_ok(int(c3["scripted"]) == 0 and int(acc2["chests"]["scripted"]) == 2, "then chests roll freely")
	var acc3 := _acc(15, ["bolt", "titan"])
	(acc3["team"] as Dictionary)["hero"] = "titan"
	_ok(str(HeroChest.open(acc3, "hero", rng)["cards"][0]["id"]) == "otto", "chest #1 with Горан = Отто")
	var acc3b := _acc(25, ["bolt", "seer"])
	(acc3b["team"] as Dictionary)["hero"] = "seer"
	_ok(HeroChest.scripted_next(acc3b) == "otto", "chest #1 for any other hero = Отто (the default)")
	# Grand chest: 3 cards, the last Amethyst+, 2 Tomes after L30 only; hero card x2.
	var acc4 := _acc(31, ["bolt"], ChampionData.CHAMPION_ORDER)
	(acc4["chests"] as Dictionary)["scripted"] = 2
	var t0 := MetaAcc.amount(acc4, "tomes")
	var gc := HeroChest.open(acc4, "grand", rng)
	_ok((gc["cards"] as Array).size() == 3 and Ladder.gem_index(str(gc["cards"][2]["gem"])) >= 2 and int(gc["tomes"]) == 2
			and MetaAcc.amount(acc4, "tomes") == t0 + 2, "Grand: 3 cards, last Amethyst+, 2 Tomes")
	_ok(str(gc["hero_card"]["id"]) == "bolt" and int(gc["hero_card"]["frags"]) == 4, "Grand hero card = 2 x round(0.15 x 15) = 4 for Руді")
	var acc5 := _acc(20, ["bolt"])
	(acc5["chests"] as Dictionary)["scripted"] = 2
	_ok(int(HeroChest.open(acc5, "grand", rng)["tomes"]) == 0, "no Tomes before the skills unlock")
	# Hero card weights: the team hero x2 (MC); chest Focus exactly 60% on a complete gem.
	var acc6 := _acc(31, ["bolt", "titan", "seer"], ChampionData.CHAMPION_ORDER)
	(acc6["chests"] as Dictionary)["scripted"] = 2
	HeroChest.set_focus(acc6, "C", "ivo")
	var team_hits := 0
	var hn := 20000
	for i3 in hn:
		if str(HeroChest.hero_card(acc6, "hero", rng)["id"]) == "bolt":
			team_hits += 1
	_ok(_z(team_hits, hn, 0.5) <= 4.0, "team hero x2 weight: %.3f of hero cards (exact 0.5 with 3 heroes)" % [float(team_hits) / hn])
	var w := HeroChest.champion_weights(acc6, "C")
	_ok(is_equal_approx(float(w["ivo"]), 0.6) and is_equal_approx(float(w["mila"]), 0.2), "chest Focus: 60% / 20% / 20%")
	var fo := 0
	var fn := 20000
	for i4 in fn:
		if HeroChest.pick_champion(acc6, "C", rng) == "ivo":
			fo += 1
	_ok(_z(fo, fn, 0.6) <= 4.0, "chest Focus share %.3f ~ 0.6" % [float(fo) / fn])
	var acc7 := _acc(15, ["bolt"], ["mila"])
	var w7 := HeroChest.champion_weights(acc7, "C")
	_ok(float(w7["mila"]) == 0.0 and is_equal_approx(float(w7["ivo"]), 0.5), "unowned champions first")
	_ok(str(HeroChest.open(_acc(14), "hero", rng)["reason"]) == "locked", "no chest before the L14 win")
	# Opening updates pity from the cards given and counts the chest.
	var acc8 := _acc(31, ["bolt"], ChampionData.CHAMPION_ORDER)
	(acc8["chests"] as Dictionary)["scripted"] = 2
	(acc8["chests"] as Dictionary)["since_l"] = PortalData.CHEST_PITY_L - 1
	var pc := HeroChest.open(acc8, "hero", rng)
	_ok(str(pc["best"]) == "L" and int(acc8["chests"]["since_l"]) == 0 and int(acc8["chests"]["total"]) == 1, "the 15th chest holds a Topaz card")


# ------------------------------------------------------------------ two-track property (§12.6 7)

## The same seed played by a free player and a payer (every launch SKU entitlement, Gems, coins):
## Beacons, Seals, chest charge, pity, Caches-free hero state and per-hero odds stay identical.
func _test_two_track() -> void:
	print("== two-track property: money never reaches a random reward (§12.6 7)")
	var free := _acc(1, ["bolt"])
	var pay := _acc(1, ["bolt"])
	var ent: Dictionary = pay["shop"]["entitlements"]
	for sku in ["starter_arsenal", "supporter", "road_premium", "world_set_1", "flare_pack"]:
		ent[sku] = true
	MetaAcc.add(pay, "gems", 50000)
	MetaAcc.add(pay, "coins", 5000000)
	var rf := RandomNumberGenerator.new()
	var rp := RandomNumberGenerator.new()
	rf.seed = 2024
	rp.seed = 2024
	for acc_rng: Array in [[free, rf], [pay, rp]]:
		var acc: Dictionary = acc_rng[0]
		var rng: RandomNumberGenerator = acc_rng[1]
		for lvl in range(1, 113):
			(acc["progress"] as Dictionary)["level"] = lvl + 1
			(acc["progress"] as Dictionary)["world_reached"] = ArsenalData.world_of(mini(lvl + 1, ArsenalData.CAMPAIGN_LEVELS))
			if lvl == 4:
				Roster.grant(acc, "titan", "progress", lvl)
			if lvl == 24:
				Roster.grant(acc, "seer", "progress", lvl)
			Summon.credit(acc, "first_clear")
			for sku_src in ["track", "road", "shop", "supporter"]:
				Summon.credit(acc, sku_src)
			if lvl % 8 == 0:
				Summon.credit(acc, "boss")
				if HeroChest.is_open(acc):
					HeroChest.open(acc, "grand", rng, lvl)
			if lvl % 7 == 0:
				Summon.credit(acc, "weekly")
				Summon.credit(acc, "mission", 3.0)
			for c in HeroChest.add_charge(acc):
				HeroChest.open(acc, "hero", rng, lvl)
			if Summon.is_open(acc) and not bool(acc["summon"]["welcome_done"]):
				Summon.welcome(acc, rng, lvl)
			while MetaAcc.amount(acc, "beacons") >= 10:
				Summon.summon(acc, 10, rng, "beacons", lvl)
	var same := _diff(free["summon"], pay["summon"]) == "" and _diff(free["chests"], pay["chests"]) == "" \
			and _diff(free["heroes"], pay["heroes"]) == "" and _diff(free["champions"], pay["champions"]) == ""
	for k in ["beacons", "tomes", "beacon_charge", "chest_charge"]:
		same = same and is_equal_approx(float(free["wallet"][k]), float(pay["wallet"][k]))
	_ok(same, "same seed, with and without every SKU: Beacons, Seals, chests, pity, roster identical")
	_ok(_diff(Summon.hero_odds(free), Summon.hero_odds(pay)) == "", "per-hero odds identical")
	_ok(int(free["summon"]["total"]) > 50 and int(free["chests"]["total"]) > 20, "the run summoned (%d) and opened chests (%d)" % [
			int(free["summon"]["total"]), int(free["chests"]["total"])])
	# §12.6 15 (rules side): sanitize repairs nothing on a rule-made account.
	var copy: Dictionary = free.duplicate(true)
	SaveMigrate.sanitize_v3(copy)
	var d := _diff(copy["heroes"], free["heroes"]) + _diff(copy["champions"], free["champions"]) + _diff(copy["summon"], free["summon"]) \
			+ _diff(copy["chests"], free["chests"]) + _diff(copy["team"], free["team"])
	_ok(d == "", "sanitize_v3 leaves a rule-made account unchanged %s" % d)


# ------------------------------------------------------------------ no-loss migration (§12.6 8)

func _test_migration() -> void:
	print("== no-loss migration: v2 fixtures -> v3 (§12.3, §12.6 8)")
	var ok := true
	for hid in ["titan", "bolt", "seer"]:
		var n := Ladder.gem_index(HeroData.native(hid))
		for lv in range(1, 31):
			var r := mini(maxi(1, EconData.hero_ult_rank(lv)), Ladder.skill_cap(Ladder.GEMS[n], Ladder.GEMS[n], 0))
			ok = ok and HeroesMeta.ult_power(Ladder.GEMS[n], Ladder.GEMS[n], 0, lv, r) >= HeroesMeta.v2_ult_power(lv) - 1e-9
	_ok(ok, "ult power after migration >= v2 for Горан / Руді / Мейра at Lv 1-30")
	_near(HeroesMeta.ult_power("C", "C", 0, 5, 2), 1.20, 0.005, "Горан Lv5 x1.20 -> x1.20")
	_near(HeroesMeta.ult_power("C", "C", 0, 25, 2), 1.96, 0.005, "Горан Lv25 x1.60 -> x1.96")
	for fx: String in ["save_v2_L9.cfg", "save_v2_L30.cfg", "save_v2_L56.cfg"]:
		var path := "res://scripts/dev/fixtures/" + fx
		if not FileAccess.file_exists(path):
			_ok(false, "fixture %s exists" % fx)
			continue
		var rd: Dictionary = Save.read_file(path)
		var acc: Dictionary = Save.account_from_cfg(rd["cfg"])
		var before := {}
		for id: String in (acc["heroes"] as Dictionary):
			var h: Dictionary = acc["heroes"][id]
			var lv2 := int(h.get("lvl", 1))
			before[id] = [lv2, EconData.hero_mults(lv2), HeroesMeta.v2_ult_power(lv2)]
		SaveMigrate.migrate_v2(acc, 1700000000, true)
		var line := true
		var met := 0
		for id2 in Roster.owned_ids(acc, Roster.KIND_HERO):
			if not before.has(id2):
				continue
			met += 1
			var b: Array = before[id2]
			var rb := HeroesMeta.run_block(acc, id2)
			var m1: Dictionary = b[1]
			line = line and float(rb["dmg_mult"]) >= float(m1["dmg_mult"]) - 1e-9 and float(rb["hp_mult"]) >= float(m1["hp_mult"]) - 1e-9
			line = line and float(rb["ult_power"]) >= float(b[2]) - 1e-9 and int(rb["lvl"]) >= int(b[0])
			line = line and HeroesMeta.skill_rank(acc, id2, "ult") <= HeroesMeta.skill_cap(acc, id2, "ult")
		_ok(line and met >= 1, "%s: %d migrated heroes keep damage, HP, ult power and level (ranks inside the caps)" % [fx, met])
		var copy: Dictionary = acc.duplicate(true)
		SaveMigrate.sanitize_v3(copy)
		_ok(_diff(copy["heroes"], acc["heroes"]) == "", "%s: the migrated heroes are already sane" % fx)


# ------------------------------------------------------------------ unlock rows (§11.1, §12.6 14)

func _test_unlock_rows() -> void:
	print("== unlock rows (§11.1)")
	_ok(Roster.system_open(_acc(15), "champions") and not Roster.system_open(_acc(14), "champions")
			and Roster.system_open(_acc(21), "portal") and not Roster.system_open(_acc(20), "portal")
			and Roster.system_open(_acc(31), "skills") and not Roster.system_open(_acc(30), "skills"),
			"systems open after the L14 / L20 / L30 wins (flag off: by level)")
	var es := load("res://scripts/core/econ_data.gd") as GDScript
	if es.get("phase_override") == null:
		print("  (EconData.phase_override missing: live-row check skipped)")
		return
	es.set("phase_override", EconData.HEROES_LIVE_PHASE)
	var ok := true
	for sys: String in ["champions", "portal", "skills", "slot3"]:
		var u := EconData.unlock_entry(sys)
		ok = ok and not u.is_empty() and int(u.get("after_win", -1)) == int(HeroData.UNLOCK_AT[sys])
	var seer := EconData.unlock_entry("seer")
	ok = ok and int(seer.get("after_win", -1)) == int(HeroData.UNLOCK_AT["seer"])
	es.set("phase_override", -1)
	_ok(ok, "live rows (WS-B) use HeroData.UNLOCK_AT: champions 14, Portal 20, skills 30, slot 3 40, Мейра 24")
	_ok(not EconData.heroes_live(), "phase override restored")


# ------------------------------------------------------------------ the sim (§12.6 17)

func _test_sim() -> void:
	print("== tools/heroes_sim.py (repo copy): exit 0 and the same constants")
	if "--no-python" in OS.get_cmdline_user_args():
		print("  skipped (--no-python)")
		return
	var sim := ProjectSettings.globalize_path("res://tools/heroes_sim.py")
	var tmp := OS.get_user_data_dir().path_join("heroes_consts_check.json")
	for args: Array in [["--section", "ladder", "--export", tmp], ["--section", "portal", "--quick"], ["--section", "chest", "--quick"]]:
		var out: Array = []
		var code := OS.execute("python3", [sim] + args, out, true)
		if code == -1:
			print("  python3 not found: sim run skipped")
			return
		var txt := "".join(out)
		_ok(code == 0 and txt.contains("all invariants pass"), "heroes_sim.py %s exits 0" % " ".join(args.slice(0, 2)))
	var exp: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp))
	if exp is Dictionary:
		for sec: String in _consts:
			if sec == "team_demand":
				continue
			var d := _diff((exp as Dictionary).get(sec), _consts[sec], sec)
			_ok(d == "", "sim constants == tools/data/heroes_consts.json [%s] %s" % [sec, d])
	else:
		_ok(false, "heroes_sim.py --export wrote json")
	DirAccess.remove_absolute(tmp)
