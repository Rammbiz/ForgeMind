extends Node
## Headless tests of the Loc tables (WS-Loc, heroes phase H1; heroes_design.md §12.4):
##   - flag off: Loc.t() returns exactly the STRINGS row for every key (the 2.2.1 text), the HEROES_LIVE
##     overlay never applies;
##   - flag on (EconData.phase_override = HEROES_LIVE_PHASE): the overlay rows win (Руді, Тавро, Топаз …),
##     every other key is unchanged;
##   - every row formats with arguments of the types its placeholders ask for (uk and en, overlay too);
##   - every character of every row exists in all four M PLUS Rounded 1c weights (FontFile.has_char), so
##     nothing renders as tofu or falls back to a system font;
##   - the rule / data classes find their keys: heroes, champions, classes, factions, elements, gems,
##     ult forms up to the native gem, Feats, the heroes unlock rows.
## The text-level rules (glossary, one name per thing, doc names, no literal numbers) are tools/loc_lint.py.
##
## godot --headless --path . res://scenes/dev/test_loc.tscn      Exit code = failures.

const FONTS: Array[String] = [
	"res://assets/fonts/MPLUSRounded1c-Regular.ttf",
	"res://assets/fonts/MPLUSRounded1c-Medium.ttf",
	"res://assets/fonts/MPLUSRounded1c-Bold.ttf",
	"res://assets/fonts/MPLUSRounded1c-ExtraBold.ttf",
]

var _fails := 0
var _passes := 0
var _lang0 := "uk"


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_lang0 = Loc.lang
	EconData.phase_override = -1
	_test_flag_off()
	_test_flag_on()
	_test_formats()
	_test_fonts()
	_test_data_keys()
	_test_helpers()
	EconData.phase_override = -1
	Loc.set_language(_lang0, false)
	print("TEST_LOC %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL: " + what)


func _test_flag_off() -> void:
	_ok(not EconData.heroes_live(), "the shipped heroes phase is below HEROES_LIVE_PHASE")
	var bad := 0
	for li in Loc.LANGS.size():
		Loc.set_language(Loc.LANGS[li], false)
		for key: String in Loc.STRINGS:
			if Loc.t(key) != str((Loc.STRINGS[key] as Array)[li]):
				bad += 1
				if bad <= 5:
					print("    off: %s.%s = «%s»" % [key, Loc.LANGS[li], Loc.t(key)])
	_ok(bad == 0, "flag off: Loc.t() == the STRINGS row for every key and language (%d differ)" % bad)
	Loc.set_language("uk", false)
	_ok(Loc.t("HERO_BOLT") == "Блискавка" and Loc.t("ST_SEAL") == "Печать" and Loc.t("RAR_LEGENDARY") == "Легендарна",
			"flag off: 2.2.1 names (Блискавка, Печать, Легендарна)")
	var nokey := "NO_SUCH" + "_KEY_X"
	_ok(Loc.t(nokey) == nokey, "a missing key returns the key")
	for key: String in Loc.HEROES_LIVE:
		_ok(Loc.STRINGS.has(key), "overlay row %s renames an existing STRINGS row" % key)


func _test_flag_on() -> void:
	EconData.phase_override = EconData.HEROES_LIVE_PHASE
	_ok(EconData.heroes_live(), "phase override turns the hero systems on")
	var bad := 0
	for li in Loc.LANGS.size():
		Loc.set_language(Loc.LANGS[li], false)
		for key: String in Loc.STRINGS:
			var want: String = str(((Loc.HEROES_LIVE[key] if Loc.HEROES_LIVE.has(key) else Loc.STRINGS[key]) as Array)[li])
			if Loc.t(key) != want:
				bad += 1
	_ok(bad == 0, "flag on: overlay rows win, every other key unchanged (%d differ)" % bad)
	Loc.set_language("uk", false)
	_ok(Loc.t("HERO_BOLT") == "Руді" and Loc.t("HERO_TITAN") == "Горан" and Loc.t("HERO_SEER") == "Мейра", "flag on: Руді, Горан, Мейра")
	_ok(Loc.t("ST_SEAL") == "Тавро", "flag on: ST_SEAL «Тавро»")
	_ok(Loc.t("RAR_COMMON") == Loc.t("GEM_C") and Loc.t("RAR_MYTHIC") == Loc.t("GEM_M"), "flag on: machine rarities read as gems")
	Loc.set_language("en", false)
	_ok(Loc.t("HERO_BOLT") == "Rudi" and Loc.t("ST_SEAL") == "Brand" and Loc.t("RAR_LEGENDARY") == "Topaz", "flag on (en): Rudi, Brand, Topaz")
	Loc.set_language("uk", false)
	EconData.phase_override = -1
	_ok(Loc.t("HERO_BOLT") == "Блискавка", "flag restored: Блискавка again")


## Arguments for `fmt`: an int for %d / %i / %x, a float for %f, a string otherwise; null when the
## placeholder grammar is unknown (fails the test instead of erroring).
func _args_for(fmt: String) -> Variant:
	var out: Array = []
	var i := 0
	while i < fmt.length():
		if fmt[i] != "%":
			i += 1
			continue
		i += 1
		if i >= fmt.length():
			return null
		if fmt[i] == "%":
			i += 1
			continue
		while i < fmt.length() and "+-0123456789.".contains(fmt[i]):
			i += 1
		if i >= fmt.length():
			return null
		match fmt[i]:
			"d", "i", "x", "X", "c":
				out.append(7)
			"f":
				out.append(1.5)
			"s":
				out.append("Ab")
			"v":
				out.append(Vector2.ONE)
			_:
				return null
		i += 1
	return out


func _test_formats() -> void:
	var bad := 0
	var n := 0
	var plain := 0
	for tbl: Dictionary in [Loc.STRINGS, Loc.HEROES_LIVE]:
		for key: String in tbl:
			var row: Array = tbl[key]
			var sig: Array = []
			for v in row:
				var args: Variant = _args_for(str(v))
				if args == null:
					# A 2.2.1 plain row with a literal "40%" (never formatted, LEGACY_PCT in loc_lint): fine
					# as long as it carries no real placeholder that a caller would format.
					var rx := RegEx.create_from_string("%[-+0-9.]*[dsf]")
					if rx.search(str(v)) != null:
						bad += 1
						print("    mixed literal % and placeholder: %s «%s»" % [key, v])
					plain += 1
					sig.append("plain")
					continue
				sig.append((args as Array).map(func(a: Variant) -> int: return typeof(a)))
				if not (args as Array).is_empty():
					var s: String = str(v) % (args as Array)
					n += 1
					if s.contains("%d") or s.contains("%s"):
						bad += 1
			if sig.size() == 2 and sig[0] != sig[1]:
				bad += 1
				print("    uk / en placeholders differ: " + key)
	_ok(bad == 0, "every template formats with its own argument types, uk == en (%d formatted, %d plain 2.2.1 rows, %d bad)" % [n, plain, bad])


func _test_fonts() -> void:
	var chars := {}
	for tbl: Dictionary in [Loc.STRINGS, Loc.HEROES_LIVE]:
		for key: String in tbl:
			for v in (tbl[key] as Array):
				var s := str(v)
				for i in s.length():
					var c := s.unicode_at(i)
					if c >= 32:
						chars[c] = key
	for path in FONTS:
		var f := load(path) as FontFile
		_ok(f != null, "font loads: " + path)
		if f == null:
			continue
		var missing: Array[String] = []
		for c: int in chars:
			if not f.has_char(c):
				missing.append("U+%04X %s (%s)" % [c, String.chr(c), chars[c]])
		_ok(missing.is_empty(), "%s has all %d characters of Loc %s" % [path.get_file(), chars.size(), str(missing.slice(0, 6))])
	# Every heroes-block string measures to a real width with the UI font (no zero-width glyphs).
	var font := load(FONTS[1]) as FontFile
	var zero := 0
	if font:
		for key: String in Loc.STRINGS:
			for v in (Loc.STRINGS[key] as Array):
				for line in str(v).split("\n"):
					if line.strip_edges() != "" and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x <= 0.0:
						zero += 1
	_ok(zero == 0, "every line measures wider than zero at 22 px (%d do not)" % zero)


func _test_data_keys() -> void:
	EconData.phase_override = EconData.HEROES_LIVE_PHASE
	var miss: Array[String] = []
	var need := func(k: String) -> void:
		if not Loc.STRINGS.has(k):
			miss.append(k)
	var starter_ult := {"titan": "ULT_QUAKE", "bolt": "ULT_STORM", "seer": "ULT_RIFT"}
	for id: String in HeroData.HERO_ORDER:
		var u := id.to_upper()
		var h: Dictionary = HeroData.HEROES[id]
		for k in ["HERO_%s", "HERO_%s_TITLE", "HERO_%s_LORE", "ATK_%s", "ATK_%s_DESC", "RALLY_%s", "RALLY_%s_DESC",
				"RALLY_%s_VALUE", "AWK_%s", "AWK_%s_DESC", "RELIC_%s", "RELIC_%s_DESC", "ULT_%s_DESC", "ULT_%s_VALUE"]:
			need.call(k % u)
		need.call(str(starter_ult.get(id, "ULT_" + u)))
		for b in [3, 6, 9]:
			need.call("ATK_%s_B%d" % [u, b])
			need.call("ATK_%s_B%d_DESC" % [u, b])
		for n in range(2, Ladder.GEMS.find(str(h["native"])) + 2):
			need.call("ULT_%s_F%d_DESC" % [u, n])
		need.call("CLASS_" + str(h["class"]).to_upper())
		need.call("FACTION_" + str(h["faction"]).to_upper())
		need.call("FAM_" + str(h["element"]).to_upper())
		_ok(Loc.t("HERO_" + u) != "HERO_" + u and Loc.t("HERO_" + u).length() >= 3, "hero %s has a live name" % id)
	for id: String in ChampionData.CHAMPION_ORDER:
		var u := id.to_upper()
		var c: Dictionary = ChampionData.CHAMPIONS[id]
		for k in ["CHAMP_%s", "CHAMP_%s_TITLE", "CHAMP_%s_ROLE", "CHAMP_%s_LORE", "ACT_%s", "ACT_%s_DESC", "ACT_%s_VALUE",
				"RELIC_%s", "RELIC_%s_DESC"]:
			need.call(k % u)
		need.call("ACT_" + str(c["class"]).to_upper())
		need.call("AURA_" + str(c["class"]).to_upper())
	for cls: String in TeamData.CLASSES:
		need.call("CLASS_" + cls.to_upper())
	for fac: String in TeamData.FACTIONS:
		need.call("FACTION_" + fac.to_upper())
		need.call("SYN_" + fac.to_upper())
	for el: String in TeamData.ELEMENTS:
		need.call("FAM_" + el.to_upper())
	for g: String in Ladder.GEMS:
		for k in ["GEM_%s", "GEM_%s_GEN", "GEM_%s_PL", "GEM_%s_ADJ", "FORM_%s"]:
			need.call(k % g)
	for fid: String in HeroData.FEATS:
		need.call("FEAT_" + fid)
	for row: Dictionary in EconData.unlocks_heroes():
		if str(row.get("line", "")) != "":
			need.call(str(row["line"]))
		if str(row["kind"]) != "inrun":
			need.call("UNF_" + str(row["id"]).to_upper())
	need.call("MIGRATION_HEROES_CARD")
	need.call("GUEST_SEER_RETURN")
	EconData.phase_override = -1
	_ok(miss.is_empty(), "every roster / tag / gem / Feat / unlock key exists (missing: %s)" % str(miss))


func _test_helpers() -> void:
	Loc.set_language("uk", false)
	_ok(Loc.from_gem("C") == "із" and Loc.from_gem("R") == "із" and Loc.from_gem("E") == "з" and Loc.from_gem("M") == "з",
			"from_gem: із Кварцу, із Сапфіру, з Аметисту, з Опалу")
	_ok(Loc.has("GEM_L") and not Loc.has("NO_SUCH_KEY_X"), "Loc.has")
	Loc.set_language("en", false)
	_ok(Loc.from_gem("L") == "from", "from_gem (en)")
	Loc.set_language("uk", false)
