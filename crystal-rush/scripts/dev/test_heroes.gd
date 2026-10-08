extends Node
## Headless tests of the Heroes & Champions data and rule classes (heroes_design.md §2.5, §12.6;
## WS-A). Phase H0: the generated constants are in sync with tools/data/heroes_consts.json and
## heroes_roster.json (the generator re-run with --check, and every constant compared with its
## JSON value), every WS-A section of heroes_consts.json is covered, the roster has the §6 shape,
## and Ladder's rules match the sim's own rule functions on every state (rule #3 tests 1-4, 6).
##
## godot --headless --path . res://scenes/dev/test_heroes.tscn      Exit code = failures.
## -- --no-python skips the generator --check (the JSON comparison still runs).

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
