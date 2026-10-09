extends Node
## Headless tests of the Heroes meta UI foundation (phase H3a): the HeroesUIModel mock states and
## its summon roller (PortalData odds, both pities, welcome rule, determinism, force_next), rule #3
## visible in the model rows, the HeroesText table (§9.1 lint: no emoji, no literal "N%"), HeroArt
## states, and every widget building and drawing a frame.
##   godot --headless --path . res://scenes/dev/test_heroes_ui.tscn        Exit code = failures.

var _fails := 0
var _passes := 0


func _ready() -> void:
	_test_states()
	_test_rule3_rows()
	_test_odds()
	_test_summon()
	_test_text()
	_test_art()
	await _test_widgets()
	HeroesUIModel.set_state("mid")
	print("test_heroes_ui: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(_fails)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails += 1
		push_error("FAIL " + what)
		print("FAIL ", what)


func _test_states() -> void:
	for st: String in HeroesUIModel.STATES:
		HeroesUIModel.set_state(st)
		_check(HeroesUIModel.state_name() == st, "state %s loads" % st)
		_check(HeroesUIModel.heroes().size() == HeroData.HERO_ORDER.size(), "%s: every hero row" % st)
		_check(HeroesUIModel.champions().size() == ChampionData.CHAMPION_ORDER.size(), "%s: every champion row" % st)
		var cap := HeroesUIModel.level_cap()
		for h in HeroesUIModel.heroes():
			if not bool(h["owned"]):
				continue
			_check(int(h["level"]) <= cap, "%s %s level %d <= cap %d" % [st, h["id"], h["level"], cap])
			for s: String in ["ult", "attack", "rally"]:
				var row: Dictionary = h["skills"][s]
				_check(int(row["rank"]) <= int(row["cap"]), "%s %s %s rank %d <= cap %d" % [st, h["id"], s, row["rank"], row["cap"]])
			var awk: Dictionary = h["skills"]["awakened"]
			_check(int(awk["rank"]) <= maxi(int(awk["cap"]), 0), "%s %s awakening within cap" % [st, h["id"]])
			if Ladder.born_awakened(str(h["native"])):
				_check(int(awk["rank"]) >= 1 and bool(awk["visible"]), "%s %s born awakened" % [st, h["id"]])
		var t := HeroesUIModel.team()
		_check((t["champions"] as Array).size() == int(t["slots"]), "%s: team slots filled to the open count" % st)
	HeroesUIModel.set_state("mid")
	_check(HeroesUIModel.hero("vesta")["native"] == "L" and int(HeroesUIModel.hero("vesta")["facets"]) == 3, "mid: Веста native Топаз 3/5")
	_check(int(HeroesUIModel.currencies()["seals"]) == 37, "mid: Seals 37")
	_check(int(HeroesUIModel.portal_state()["seal_target"]["price"]) == PortalData.seal_price("E"), "mid: next Seal target = Аметист")
	HeroesUIModel.set_state("late")
	_check(HeroesUIModel.team()["slots"] == 3, "late: three champion slots")
	_check(bool(HeroesUIModel.unlocks()["workshop"]), "late: Workshop open")
	_check(HeroesUIModel.hero("lumen")["skills"]["awakened"]["rank"] >= 1, "late: Люмен awakened")
	# C23 Тарас (§6.25): owned and NEW in 'late', listed but not owned in every other state; his art is the owner's card.
	var tr := HeroesUIModel.champion("taras")
	_check(bool(tr["owned"]) and bool(tr["is_new"]) and str(tr["gem"]) == "L" and not bool(tr["is_recut"]), "late: Тарас owned, NEW, native Топаз")
	_check(str(tr["name"]) != "CHAMP_TARAS" and str(tr["title"]) != "CHAMP_TARAS_TITLE", "late: Тарас name and title from Loc")
	_check(int(tr["action_tier"]) == 4 and str(tr["class"]) == "mage" and str(tr["faction"]) == "wildfang", "late: Тарас Mage of Wildfang, tier IV")
	var owned_c := 0
	for c in HeroesUIModel.champions():
		owned_c += 1 if bool(c["owned"]) else 0
	_check(owned_c < HeroesUIModel.champions().size(), "late: the Hall count follows the data (%d / %d)" % [owned_c, HeroesUIModel.champions().size()])
	for st2: String in HeroesUIModel.STATES:
		if st2 == "late":
			continue
		HeroesUIModel.set_state(st2)
		_check(not bool(HeroesUIModel.champion("taras")["owned"]), "%s: Тарас listed as not owned" % st2)
	HeroesUIModel.set_state("late")
	HeroesUIModel.set_state("fresh")
	_check(not bool(HeroesUIModel.unlocks()["portal"]) and not bool(HeroesUIModel.hero("arin")["listed"]), "fresh: Portal heroes hidden")
	_check(bool(HeroesUIModel.hero("seer")["listed"]) and not bool(HeroesUIModel.hero("seer")["owned"]), "fresh: Мейра listed, not owned")


func _test_rule3_rows() -> void:
	for st: String in HeroesUIModel.STATES:
		HeroesUIModel.set_state(st)
		for h in HeroesUIModel.heroes() + HeroesUIModel.champions():
			if not bool(h["is_recut"]):
				continue
			if h["kind"] == "hero":
				_check(int(h["skills"]["ult"]["cap"]) < int(h["skills"]["ult"]["cap_native"]), "%s %s: recut cap below native" % [st, h["id"]])
				_check(float(h["stat_ratio"]) < 1.0, "%s %s: recut stats below native" % [st, h["id"]])
				_check(Ladder.gem_index(str(h["skills"]["ult"]["form_gem"])) <= Ladder.gem_index(str(h["native"])), "%s %s: ult bezel never past native" % [st, h["id"]])


func _test_odds() -> void:
	var o := HeroesUIModel.consolidated_odds()
	var s := 0.0
	for g: String in o:
		s += float(o[g])
	_check(absf(s - 1.0) < 1e-6, "consolidated odds sum to 1")
	# The disclosed table of heroes_design.md §7.2 (exact stationary pity chain).
	var doc := {"C": 0.5209, "R": 0.2652, "E": 0.1435, "L": 0.0563, "M": 0.0141}
	for g: String in doc:
		_check(absf(float(o[g]) - float(doc[g])) < 0.00006, "consolidated %s %.4f vs §7.2 %.4f" % [g, o[g], doc[g]])
	for st: String in HeroesUIModel.STATES:
		HeroesUIModel.set_state(st)
		var rows := HeroesUIModel.odds_rows()
		var ps := 0.0
		for r in rows["heroes"]:
			ps += float(r["pct"])
		_check(absf(ps - 1.0) < 1e-6, "%s: per-hero odds sum to 1" % st)
		_check((rows["lines"] as Array).size() >= 5, "%s: odds sentences generated" % st)
	HeroesUIModel.set_state("mid")
	var a := HeroesUIModel.odds_rows()
	for r in a["heroes"]:
		if r["id"] == "vartan":
			_check(absf(float(r["pct"]) - float(o["L"])) < 1e-9, "mid: unowned Вартан takes all Топаз results (duplicate protection)")


func _test_summon() -> void:
	HeroesUIModel.set_state("mid")
	var a := HeroesUIModel.summon("portal", 10, 7)
	HeroesUIModel.set_state("mid")
	var b := HeroesUIModel.summon("portal", 10, 7)
	var same := a.size() == 10 and b.size() == 10
	for i in mini(a.size(), b.size()):
		same = same and a[i]["id"] == b[i]["id"]
	_check(same, "summon is deterministic per seed")
	_check(int(HeroesUIModel.currencies()["seals"]) == 47, "x10 gives +10 Seals")
	# Welcome x10: free, holds Topaz+, then the flag clears.
	for seed in 12:
		HeroesUIModel.set_state("welcome")
		var bc := int(HeroesUIModel.currencies()["beacons"])
		var w := HeroesUIModel.summon("portal", 10, seed)
		var top := false
		for r in w:
			top = top or Ladder.gem_index(str(r["gem"])) >= Ladder.gem_index("L")
		_check(top, "welcome x10 seed %d holds Topaz or better" % seed)
		_check(int(HeroesUIModel.currencies()["beacons"]) == bc, "welcome x10 is free")
		_check(not bool(HeroesUIModel.portal_state()["welcome"]), "welcome flag clears")
	# Pity gaps over a long run.
	HeroesUIModel.set_state("late")
	var since_e := int(HeroesUIModel.portal_state()["since_e"])
	var since_l := int(HeroesUIModel.portal_state()["since_l"])
	var ok_e := true
	var ok_l := true
	for i in 40:
		for r in HeroesUIModel.summon("portal", 10, 100 + i):
			var gi := Ladder.gem_index(str(r["gem"]))
			since_e = 0 if gi >= 2 else since_e + 1
			since_l = 0 if gi >= 3 else since_l + 1
			ok_e = ok_e and since_e < int(PortalData.PITY_E["hard"])
			ok_l = ok_l and since_l < int(PortalData.PITY_L["hard"])
	_check(ok_e, "Amethyst+ pity holds over 400 summons")
	_check(ok_l, "Topaz+ pity holds over 400 summons")
	# force_next.
	HeroesUIModel.set_state("mid")
	HeroesUIModel.force_next = [{"id": "lumen", "gem": "M"}]
	var f := HeroesUIModel.summon("portal", 1, 3)
	_check(f.size() == 1 and f[0]["id"] == "lumen" and bool(f[0]["is_new"]) and bool(f[0]["forced"]), "force_next gives the forced NEW Опал")
	_check(bool(HeroesUIModel.hero("lumen")["owned"]), "the forced hero is owned after")
	# Facet + recut mutations.
	HeroesUIModel.set_state("late")
	var ok := HeroesUIModel.recut("arin")
	_check(ok and HeroesUIModel.hero("arin")["gem"] == "R" and int(HeroesUIModel.hero("arin")["facets"]) == 0, "recut Арін Кварц -> Сапфір, facets restart")
	var chest := HeroesUIModel.summon("chest", 1, 5)
	_check(chest.size() == int(PortalData.CHEST_CARDS["hero"]), "a Hero Chest gives its cards")


func _test_text() -> void:
	var bad_emoji := 0
	var bad_pct := 0
	var re := RegEx.new()
	re.compile("[0-9]\\s?%(?![sd%])")
	for s in HeroesText.all_strings():
		for i in s.length():
			var cp := s.unicode_at(i)
			if (cp >= 0x1F300 and cp <= 0x1FAFF) or (cp >= 0x2600 and cp <= 0x27BF):
				bad_emoji += 1
		if re.search(s) != null:
			bad_pct += 1
			print("literal percentage: ", s)
	_check(bad_emoji == 0, "no emoji code points in hero strings")
	_check(bad_pct == 0, "no literal N%% in hero strings")
	for id: String in HeroData.HERO_ORDER:
		for k in ["HERO_" + id.to_upper(), "HERO_" + id.to_upper() + "_TITLE"]:
			_check(HeroesText.t(k) != k, "text " + k)
		for sk: String in ["ult", "attack", "rally", "awakened", "relic"]:
			var n := HeroesText.skill_name(id, sk)
			_check(n != "" and not n.begins_with("ULT_") and not n.begins_with("ATK_") and not n.ends_with("!"), "skill name %s %s" % [id, sk])
	for id: String in ChampionData.CHAMPION_ORDER:
		for k in ["CHAMP_" + id.to_upper(), "CHAMP_" + id.to_upper() + "_TITLE", "CHAMP_" + id.to_upper() + "_ROLE"]:
			_check(HeroesText.t(k) != k, "text " + k)
	_check(HeroesText.hero_name("bolt") == ("Руді" if HeroesText.lang() == "uk" else "Rudi"), "stale Meta-1 HERO_BOLT is not used")
	_check(HeroesText.t("PORTAL_PITY_L", [7]).contains("7"), "args format")
	_check(HeroesText.count(46, "tome") == "46 томів" or HeroesText.lang() != "uk", "uk plural")


func _test_art() -> void:
	_check(HeroArt.state("vesta") == "splash", "Веста has her splash")
	_check(HeroArt.card_texture("vesta") != null, "Веста card crop")
	# The starters fall back to their live 3D bust until their painted splash lands (all three have one now).
	var bolt_want := "splash" if ResourceLoader.exists("res://assets/heroes/bolt/splash.png") else "live3d"
	_check(HeroArt.state("bolt") == bolt_want, "Руді uses his splash, else the live 3D bust")
	_check(HeroArt.splash_variant("seer", "eyes_closed") != null, "Мейра has the eyes-closed walkout splash")
	_check(HeroArt.splash_variant("vesta", "eyes_closed") == null, "no variant means null, not a crash")
	# Every hero has a painted splash now (Пава's landed 2026-10-08); the fallback is checked on a champion whose
	# art has not landed yet (the first one without a folder), so the test follows the assets.
	_check(HeroArt.state("pava") == "splash", "Пава has her splash")
	var no_art := ""
	for cid: String in ChampionData.CHAMPION_ORDER:
		if not ResourceLoader.exists("res://assets/heroes/%s/splash.png" % cid) and not ResourceLoader.exists("res://assets/heroes/%s/card.png" % cid):
			no_art = cid
			break
	_check(no_art == "" or HeroArt.state(no_art) == "placeholder", "%s falls back to the class emblem" % (no_art if no_art != "" else "(every champion has art)"))
	_check(HeroArt.state("taras") == "splash" and HeroArt.card_texture("taras") != null, "Тарас has the owner's card art")
	_check(HeroArt.state("no_such_hero") == "placeholder", "an unknown id never crashes")


func _test_widgets() -> void:
	HeroesUIModel.set_state("late")
	var host := Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var ws: Array[Control] = [
		HeroGemEmblem.make("M", 96, "E"), HeroLivingGem.make_living("L", 160, 3, "E"), HeroFacetPips.make("R", 5),
		HeroEngravedBar.make("M", 3, 10, 300), HeroChip.make("Шанси", "odds"), HeroWaxSeal.make(64),
		HeroSkillPlate.from_model(HeroesUIModel.hero("iskar"), "ult"), HeroCurrencyChip.make("seals", "37 / 40"),
		HeroIcons.make("ore", 48), HeroCard.make(HeroesUIModel.hero("vesta"), "L"),
		HeroCard.make(HeroesUIModel.champion("menhir"), "M"), HeroCard.make(HeroesUIModel.hero("titan"), "S"),
	]
	for w in ws:
		host.add_child(w)
	(ws[5] as HeroWaxSeal).stamp()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(host.get_child_count() == ws.size(), "every widget builds")
	var g := HeroesWidgetSpecimen.build("widgets")
	host.add_child(g)
	var g2 := HeroesWidgetSpecimen.build("widgets_cards")
	host.add_child(g2)
	await get_tree().process_frame
	_check(is_instance_valid(g) and is_instance_valid(g2), "specimen pages build")
	var p := HeroesNav.open(null, "hero/vesta", self)
	await get_tree().process_frame
	_check(p != null, "HeroesNav opens a (placeholder) screen")
	HeroesNav.close_all()
	# Route gates (§9.2): Team / Portal are locked at L4, open at L40; force skips the gate.
	HeroesUIModel.set_state("fresh")
	_check(HeroesNav.locked_reason("team") != "" and HeroesNav.locked_reason("portal/odds") != "", "fresh: team + portal locked")
	_check(HeroesNav.locked_reason("hero/bolt") == "", "fresh: the Showcase is open")
	_check(HeroesNav.open(null, "portal", self) == null, "a locked route does not open")
	var forced := HeroesNav.open(null, "codex", self, true)
	_check(forced != null, "codex route opens (modal layer without a hub)")
	HeroesNav.close_all()
	HeroesUIModel.set_state("late")
	_check(HeroesNav.locked_reason("team") == "" and HeroesNav.locked_reason("workshop") == "", "late: team + workshop open")
	# Level price: the shipped curve, paid by level_up, 0 at the cap.
	HeroesUIModel.set_state("mid")
	var cost := HeroesUIModel.level_cost("vesta")
	var coins0 := int(HeroesUIModel.currencies()["coins"])
	_check(cost == EconData.hero_cost(int(HeroesUIModel.hero("vesta")["level"])) and cost > 0, "level_cost = EconData.hero_cost")
	_check(HeroesUIModel.level_up("vesta") and int(HeroesUIModel.currencies()["coins"]) == coins0 - cost, "level_up pays level_cost")
	HeroesUIModel.set_state("mid")
	host.queue_free()
