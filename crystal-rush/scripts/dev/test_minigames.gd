extends Node
## Headless tests of the Fair's mini-game framework and of EVERY registered game (docs/design/minigames/README.md):
##   - registry: discovery by folder, order, entries, every game's registration valid (MinigameRegistry.errors);
##   - texts: the core and game tables merged into Loc (both languages), never shadowing a Loc key;
##   - save: the `fair` section in fresh accounts, a save written before the Fair, a damaged section, the v2 chain,
##     a file round trip (user://test_minigames/ only), the migration step;
##   - rules: local day and the clock moved back, 3 rewarded wins a day, the ad reward (once, latest play only),
##     losses and free plays pay nothing, one-time tiers, ore as coins until the heroes, the Fair's Road XP cap,
##     coin scaling, seeds per start, the budget check, the character hook;
##   - Ads stub and dev provider; the shell flow (intro, pause, result, ad button only when an ad can show, retry,
##     back) on the reference game;
##   - per game: its selftest.gd, its bot winning from 3 seeds and losing from 2, the same seed giving the same
##     result, every declared shot state.
## godot --headless --path crystal-rush res://scenes/dev/test_minigames.tscn -- --autotest     Exit code = failures.

const DIR := "user://test_minigames/"
const WATCHDOG_S := 300.0

var _passes := 0
var _fails := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("TEST_MINIGAMES FAIL: watchdog (%d s)" % int(WATCHDOG_S))
		get_tree().quit(99))
	_ok(Save.readonly, "Save is read-only (-- --autotest)")
	EconData.phase_override = -1
	Loc.set_language("uk", false)
	_test_registry()
	_test_texts()
	_test_save()
	_test_rules()
	await _test_ads()
	await _test_shell()
	for id in MinigameRegistry.ids():
		await _test_game(id)
	EconData.phase_override = -1
	Ads.provider = null
	print("TEST_MINIGAMES %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL: " + what)


# ======================================================================== registry

func _test_registry() -> void:
	print("== registry")
	var ids := MinigameRegistry.ids()
	_ok(ids.has("memory"), "the reference game is registered by its folder (%s)" % str(ids))
	_ok(not ids.has(MinigameRegistry.CORE), "the core folder is not a game")
	var orders: Array[int] = []
	for g in MinigameRegistry.list():
		orders.append(int(g["order"]))
	var sorted := orders.duplicate()
	sorted.sort()
	_ok(orders == sorted, "list() is in Fair order")
	_ok(MinigameRegistry.list("minigame").size() + MinigameRegistry.list("extra").size() == ids.size(), "kinds split the list")
	var m := MinigameRegistry.game("memory")
	_ok(m.has("rewards") and m.has("cosmetics") and m.has("shots") and m.has("dir") and m.has("texts"), "an entry carries its tables")
	_ok(MinigameRegistry.game("no_such_game").is_empty() and not MinigameRegistry.has("no_such_game"), "unknown id -> {}")
	_ok(not MinigameRegistry.errors("no_such_game").is_empty(), "errors() reports an unknown id")
	for id in ids:
		var errs := MinigameRegistry.errors(id)
		_ok(errs.is_empty(), "%s registration: %s" % [id, str(errs)])
	var cs := MinigameRegistry.cosmetics()
	_ok(cs.has("memory_frame_pairs") and str((cs["memory_frame_pairs"] as Dictionary)["game"]) == "memory", "cosmetics() lists every game's")


# ======================================================================== texts

func _test_texts() -> void:
	print("== texts")
	var core: Dictionary = (load(MinigameRegistry.ROOT + "core/texts.gd") as GDScript).get_script_constant_map()["ROWS"]
	var tables: Array = [["core", core]]
	for g in MinigameRegistry.list():
		tables.append([str(g["id"]), g["texts"]])
	var seen := {}
	for tb: Array in tables:
		var rows: Dictionary = tb[1]
		for key: String in rows:
			var row: Array = rows[key]
			_ok(not Loc.STRINGS.has(key), "%s %s does not shadow a Loc key" % [tb[0], key])
			_ok(not seen.has(key), "%s %s is in one table only" % [tb[0], key])
			seen[key] = true
			for li in Loc.LANGS.size():
				Loc.set_language(Loc.LANGS[li], false)
				if Loc.t(key) != str(row[li]):
					_ok(false, "Loc.t(%s) in %s = the table row" % [key, Loc.LANGS[li]])
			var bad := false
			for v in row:
				bad = bad or str(v).contains("…") or str(v).contains("...") or str(v).strip_edges() == ""
			_ok(not bad, "%s %s: no «…», no empty value" % [tb[0], key])
	Loc.set_language("uk", false)
	_ok(Loc.t("MG_PLAY") == "Грати" and Loc.has("MG_PLAY"), "core texts merged (MG_PLAY)")
	_ok(Loc.t("MG_MEMORY_TITLE") == "Хто де?", "game texts merged (MG_MEMORY_TITLE)")
	var probe := {}
	probe["PLAY_LEVEL"] = ["x", "y"]
	var skipped: Array = Loc.add_rows(probe)
	_ok(skipped == ["PLAY_LEVEL"] and Loc.t("PLAY_LEVEL") == str((Loc.STRINGS["PLAY_LEVEL"] as Array)[0]),
			"a merged table never shadows STRINGS")


# ======================================================================== save

func _test_save() -> void:
	print("== save section")
	var f := EconData.fresh_account()
	_ok(f.get(MinigamesMeta.SECTION) is Dictionary and int(f["fair"]["v"]) == MinigamesMeta.SCHEMA, "fresh_account has the fair section")
	for k in ["day", "today", "ads", "xp_day", "coins_day", "road_xp", "games", "cosmetics", "chars"]:
		_ok((f["fair"] as Dictionary).has(k), "fair.%s default" % k)
	# A v3 save written before the Fair (no [fair] section) -> the fresh section.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 3)
	cfg.set_value("progress", "level", 12)
	var acc := Save.account_from_cfg(cfg)
	_ok(var_to_str(acc["fair"]) == var_to_str(MinigamesMeta.fresh()), "a save without [fair] loads the fresh section")
	# A damaged section is repaired.
	cfg.set_value("fair", "games", {"memory": {"best_stars": 9, "plays": -3, "once": [3, 3, 7, "x"]}, 5: "junk"})
	cfg.set_value("fair", "today", {"memory": -2, "x": "y"})
	cfg.set_value("fair", "cosmetics", ["a", "a", 1, ""])
	cfg.set_value("fair", "xp_day", "lots")
	var acc2 := Save.account_from_cfg(cfg)
	var g: Dictionary = acc2["fair"]["games"]["memory"]
	_ok(int(g["best_stars"]) == 3 and int(g["plays"]) == 0 and g["once"] == [3] and g.has("counters"), "a damaged game record is repaired")
	_ok(not (acc2["fair"]["games"] as Dictionary).has("5") or (acc2["fair"]["games"] as Dictionary)["5"] is Dictionary, "junk records dropped")
	_ok((acc2["fair"]["today"] as Dictionary).is_empty() and acc2["fair"]["cosmetics"] == ["a"] and int(acc2["fair"]["xp_day"]) == 0,
			"counters and cosmetics repaired")
	# The migration step.
	var old := EconData.fresh_account()
	old.erase("fair")
	_ok(MinigamesMeta.migrate(old) and int(old["fair"]["v"]) == MinigamesMeta.SCHEMA, "migrate: a missing section is created")
	_ok(not MinigamesMeta.migrate(old), "migrate is idempotent")
	old["fair"] = {"games": {"memory": {"best_score": 40}}}
	_ok(MinigamesMeta.migrate(old) and (old["fair"] as Dictionary).has("cosmetics") and int(old["fair"]["games"]["memory"]["best_score"]) == 40,
			"migrate: a schema-0 section is filled, its data kept")
	# The v2 chain (fixture) gets the section.
	var v2 := ConfigFile.new()
	if v2.load("res://scripts/dev/fixtures/save_v2_L30.cfg") == OK:
		var a3 := Save.account_from_cfg(v2)
		Save.migrate_v2(a3, 1700000000, 0)
		_ok(a3.get("fair") is Dictionary and int(a3["fair"]["v"]) == MinigamesMeta.SCHEMA, "v2 -> v3 has the fair section")
	else:
		_ok(false, "fixture save_v2_L30.cfg loads")
	# File round trip (test folder only; the player's save is never touched).
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := DIR + "save.cfg"
	var acc3 := EconData.fresh_account()
	MinigamesMeta.book(acc3, "memory", {"won": true, "score": 900, "stars": 3, "stats": {"tries": 12}}, "rewarded",
			MinigameRegistry.rewards("memory"), 1760000000, 0)
	_ok(Save.write_file(p, {"level": 1, "coins": MetaAcc.amount(acc3, "coins")}, acc3) == OK, "write_file ok")
	var res := Save.read_file(p)
	var back := Save.account_from_cfg(res["cfg"])
	_ok(var_to_str(back["fair"]) == var_to_str(acc3["fair"]), "the fair section survives a save and a load")
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + fn)


# ======================================================================== rules

const T0 := 1760000000      ## a fixed unix time (UTC)
const DAY := 86400
const RW := {"coins": [0, 20, 30, 40], "road_xp": [0, 5, 5, 5], "ore_once": [0, 0, 2, 3],
		"cosmetic_once": ["", "", "memory_title_sharp_eye", "memory_frame_pairs"]}


func _win(stars := 3) -> Dictionary:
	return {"won": true, "score": 500, "stars": stars, "stats": {"tries": 13}}


func _test_rules() -> void:
	print("== rules")
	var fr: Dictionary = EconData.FAIR
	# Local day.
	_ok(MinigamesMeta.local_day(T0, 0) == T0 / DAY and MinigamesMeta.local_day(T0, 180) == (T0 + 180 * 60) / DAY,
			"local day = (unix + bias) / 86400")
	var acc := EconData.fresh_account()
	(acc["progress"] as Dictionary)["level"] = 1
	var st := MinigamesMeta.status(acc, "memory", T0)
	_ok(int(st["rewarded_left"]) == int(fr["rewarded_per_day"]) and str(st["mode"]) == "rewarded" and int(st["ad_left"]) == 0,
			"a new day: 3 rewarded wins, no ad yet")
	# Losses and free plays pay nothing and use nothing.
	var c0 := MetaAcc.amount(acc, "coins")
	var lb := MinigamesMeta.book(acc, "memory", {"won": false, "score": 100, "stars": 2}, "rewarded", RW, T0)
	_ok(not bool(lb["rewarded"]) and int(lb["stars"]) == 0 and str(lb["reason"]) == "loss" and MetaAcc.amount(acc, "coins") == c0,
			"a loss pays nothing")
	_ok(int(MinigamesMeta.status(acc, "memory", T0)["rewarded_left"]) == 3, "a loss does not use a rewarded play")
	var fb := MinigamesMeta.book(acc, "memory", _win(), "free", RW, T0)
	_ok(not bool(fb["rewarded"]) and str(fb["reason"]) == "free" and MetaAcc.amount(acc, "coins") == c0, "a free play pays nothing")
	_ok(int(MinigamesMeta.game(acc, "memory")["best_stars"]) == 3, "a free play still counts for the best")
	# Three rewarded wins.
	var b1 := MinigamesMeta.book(acc, "memory", _win(3), "rewarded", RW, T0)
	_ok(bool(b1["rewarded"]) and int(b1["coins"]) == EconData.fair_coins(40, 1) and int(b1["road_xp"]) == 5, "a rewarded 3-star win pays its row")
	_ok(int(b1["ore"]) == 0 and int(b1["ore_coins"]) == 5 * int(fr["ore_coins"]), "one-time ore paid as coins while the heroes are off")
	_ok((b1["cosmetics"] as Array) == ["memory_title_sharp_eye", "memory_frame_pairs"] and MinigamesMeta.cosmetics(acc).size() == 2,
			"one-time cosmetics of tiers 2 and 3")
	var b2 := MinigamesMeta.book(acc, "memory", _win(3), "rewarded", RW, T0 + 60)
	_ok(int(b2["ore_coins"]) == 0 and (b2["cosmetics"] as Array).is_empty() and int(b2["coins"]) > 0, "one-time tiers pay once")
	var b3 := MinigamesMeta.book(acc, "memory", _win(1), "rewarded", RW, T0 + 120)
	_ok(bool(b3["rewarded"]) and int(b3["rewarded_left"]) == 0 and not bool(b3["ad_offer"]), "the third rewarded win, none left")
	var st2 := MinigamesMeta.status(acc, "memory", T0 + 130)
	_ok(str(st2["mode"]) == "free" and int(st2["ad_left"]) == 1, "then free mode with one ad reward")
	# The fourth win: no pay, an ad offer; the ad pays once, only the latest play.
	var b4 := MinigamesMeta.book(acc, "memory", _win(2), "rewarded", RW, T0 + 200)
	_ok(not bool(b4["rewarded"]) and bool(b4["ad_offer"]) and str(b4["reason"]) == "limit", "a 4th win offers the ad reward")
	var c1 := MetaAcc.amount(acc, "coins")
	_ok(not bool(MinigamesMeta.book_ad(acc, "memory", _win(2), int(b4["play_n"]) - 1, RW, T0 + 210)["ok"]), "an ad never pays an older play")
	var ad := MinigamesMeta.book_ad(acc, "memory", _win(2), int(b4["play_n"]), RW, T0 + 210)
	_ok(bool(ad["ok"]) and int(ad["coins"]) == EconData.fair_coins(30, 1) and MetaAcc.amount(acc, "coins") == c1 + int(ad["coins"]),
			"the ad pays the 2-star row")
	_ok(not bool(MinigamesMeta.book_ad(acc, "memory", _win(2), int(b4["play_n"]), RW, T0 + 220)["ok"]), "the same play is paid once")
	var b5 := MinigamesMeta.book(acc, "memory", _win(3), "free", RW, T0 + 300)
	_ok(not bool(b5["ad_offer"]) and not bool(MinigamesMeta.book_ad(acc, "memory", _win(3), int(b5["play_n"]), RW, T0 + 310)["ok"]),
			"one ad reward a day")
	_ok(MinigamesMeta.book(acc, "memory", {"won": false}, "rewarded", RW, T0 + 320)["ad_offer"] == false, "a loss never offers the ad")
	# Clock moved back: nothing resets.
	var back := MinigamesMeta.status(acc, "memory", T0 - 3 * DAY)
	_ok(int(back["rewarded_left"]) == 0 and int(back["ad_left"]) == 0, "a clock moved backwards resets nothing")
	MinigamesMeta.book(acc, "memory", _win(), "rewarded", RW, T0 - 3 * DAY)
	_ok(int(MinigamesMeta.section(acc)["day"]) == T0 / DAY, "the stored day never moves back")
	# The next local day resets.
	var nd := MinigamesMeta.status(acc, "memory", T0 + DAY)
	_ok(int(nd["rewarded_left"]) == 3 and int(nd["ad_left"]) == 0, "the next local day: 3 rewarded wins again")
	var bias_day := MinigamesMeta.status(acc, "memory", (T0 / DAY + 1) * DAY - 3600, 120)
	_ok(int(bias_day["rewarded_left"]) == 3, "midnight is LOCAL: UTC+2 is already the next day at 23:00 UTC")
	# Road XP cap across games.
	var acc2 := EconData.fresh_account()
	var xp := 0
	for gid in ["a", "b", "c"]:
		for i in 3:
			xp += int(MinigamesMeta.book(acc2, gid, _win(), "rewarded", RW, T0)["road_xp"])
	_ok(xp == int(fr["road_xp_day_cap"]) and int(MinigamesMeta.section(acc2)["road_xp"]) == xp, "the Fair's Road XP stops at the daily cap (%d)" % xp)
	# The Fair's coins stop at FAIR.coins_day_missions daily missions (many games, one day).
	var acc3 := EconData.fresh_account()
	var paid := 0
	var capped := false
	for gi in 12:
		for j in 3:
			var bc := MinigamesMeta.book(acc3, "g%d" % gi, _win(), "rewarded", RW, T0)
			paid += int(bc["coins"])
			capped = capped or bool(bc.get("coins_capped", false))
	_ok(paid == MinigamesMeta.coins_cap(1) and capped, "the Fair's coins stop at the daily cap (%d of %d)" % [paid, MinigamesMeta.coins_cap(1)])
	_ok(int(MinigamesMeta.status(acc3, "g0", T0 + DAY)["rewarded_left"]) == 3 and int(MinigamesMeta.book(acc3, "g0", _win(), "rewarded",
			RW, T0 + DAY)["coins"]) > 0, "a new day pays coins again")
	# Coins scale like the daily mission coins.
	_ok(EconData.fair_coins(40, 1) == 40 and EconData.fair_coins(40, 56) > 150
			and EconData.fair_coins(int(fr["coins_3star_max"]), 56) <= EconData.mission_coins(56), "coins scale with the frontier, under a mission")
	_ok(EconData.fair_coins(0, 30) == 0, "a 0 row stays 0")
	# Seeds per start.
	var acc4 := EconData.fresh_account()
	var s1 := MinigamesMeta.begin(acc4, "memory", T0)
	var s2 := MinigamesMeta.begin(acc4, "memory", T0)
	_ok(int(s1["seed"]) != int(s2["seed"]) and int(s2["start"]) == 2, "every start deals a new board")
	var acc5 := EconData.fresh_account()
	_ok(int(MinigamesMeta.begin(acc5, "memory", T0)["seed"]) == int(s1["seed"]), "the same account state deals the same board")
	# Budget check.
	_ok(MinigamesMeta.budget_errors(RW, MinigameRegistry.game("memory")["cosmetics"]).is_empty(), "the reference rewards are in budget")
	var bad := {"coins": [5, 30, 45, 999], "road_xp": [0, 5, 9, 9], "ore_once": [0, 6, 6, 6], "cosmetic_once": ["", "", "", "nope"]}
	_ok(MinigamesMeta.budget_errors(bad, {}).size() >= 4, "a table over budget is caught: %s" % str(MinigamesMeta.budget_errors(bad, {})))
	# Ore once the heroes are live.
	EconData.phase_override = EconData.HEROES_LIVE_PHASE
	var acc6 := EconData.fresh_account()
	var bl := MinigamesMeta.book(acc6, "memory", _win(3), "rewarded", RW, T0)
	_ok(int(bl["ore"]) == 5 and MetaAcc.amount(acc6, "ore") == 5 and int(bl["ore_coins"]) == 0, "live: one-time Star Ore is Star Ore")
	# The character hook.
	var low := ""
	var high := ""
	for id: String in ChampionData.CHAMPION_ORDER:
		var gem := Roster.native(id)
		if low == "" and gem in MinigamesMeta.GRANT_GEMS:
			low = id
		if high == "" and not gem in MinigamesMeta.GRANT_GEMS:
			high = id
	var gl := MinigamesMeta.grant_character(acc6, low, T0)
	_ok(bool(gl["ok"]) and bool(gl["joined"]) and Roster.owned(acc6, low)
			and str((Roster.entry(acc6, low)["got"] as Dictionary)["via"]) == "fair", "a Кварц–Аметист character joins (via fair): %s" % low)
	var gh := MinigamesMeta.grant_character(acc6, high, T0, 4)
	_ok(bool(gh["ok"]) and not bool(gh["joined"]) and not Roster.owned(acc6, high) and int(gh["frags"]) == 4,
			"a Топаз / Опал character gives fragments only: %s" % high)
	_ok(not bool(MinigamesMeta.grant_character(acc6, "nobody", T0)["ok"]), "an unknown id is refused")
	SaveMigrate.sanitize_v3(acc6)
	_ok(str((Roster.entry(acc6, low)["got"] as Dictionary)["via"]) == "fair", "via fair survives sanitize")
	EconData.phase_override = -1
	_ok(not bool(MinigamesMeta.grant_character(EconData.fresh_account(), low, T0)["ok"]), "the hook waits for the heroes phase")


# ======================================================================== ads

func _test_ads() -> void:
	print("== ads")
	Ads.provider = null
	_ok(not Ads.can_show(), "no SDK: no ad can show")
	var got := [null]
	Ads.show(func(ok: bool) -> void: got[0] = ok)
	_ok(got[0] == false, "show() without an ad reports false at once")
	var dev := Ads.DevProvider.new()
	Ads.provider = dev
	_ok(Ads.can_show(), "the dev provider can show")
	got[0] = null
	Ads.show(func(ok: bool) -> void: got[0] = ok)
	await get_tree().process_frame
	_ok(got[0] == true and dev.shown == 1, "the dev ad completes")
	dev.ready = false
	_ok(not Ads.can_show(), "no ad loaded: can_show false")
	Ads.provider = null


# ======================================================================== shell

func _test_shell() -> void:
	print("== shell")
	var fair: Dictionary = MinigamesMeta.section(Meta.account)
	fair["games"] = {}
	fair["today"] = {}
	fair["ads"] = {}
	var sh := MinigameShell.open("memory", {"seed": 3, "manual_time": true, "no_auto_pause": true, "keep_on_close": true})
	add_child(sh)
	await get_tree().process_frame
	_ok(sh.state == "intro" and sh.overlay is MinigameIntroCard, "the intro card shows first")
	_ok(sh.mode == "rewarded", "a fresh day starts in rewarded mode")
	(sh.overlay as MinigameIntroCard).play_pressed.emit()
	await get_tree().process_frame
	_ok(sh.state == "play" and sh.game.started, "Грати starts the play")
	sh.pause()
	_ok(sh.state == "pause" and sh.game.paused, "pause")
	sh.resume()
	_ok(sh.state == "play" and not sh.game.paused, "resume")
	var bot: Object = load(str(MinigameRegistry.game("memory")["dir"]) + "bot.gd").new()
	var c0 := Meta.currency("coins")
	bot.call("play", sh.game, true)
	await get_tree().process_frame
	_ok(sh.state == "result" and sh.overlay is MinigameResultPanel, "the result panel shows after the play")
	_ok(bool(sh.bundle.get("rewarded", false)) and Meta.currency("coins") > c0, "the win was booked and paid (dev account)")
	_ok((sh.overlay as MinigameResultPanel).ad_button == null, "no ad button while rewarded wins are left")
	# Retry deals a new board.
	(sh.overlay as MinigameResultPanel).retry_pressed.emit()
	await get_tree().process_frame
	_ok(sh.state == "intro" and sh.game != null and not sh.game.is_done(), "«Ще раз» deals a new play")
	# Use up the day: the 4th win offers the ad; the button exists only when an ad can show.
	var day := MinigamesMeta.local_day(int(Time.get_unix_time_from_system()), MinigamesMeta.system_bias())
	fair["day"] = day
	fair["today"] = {"memory": int(EconData.FAIR["rewarded_per_day"])}
	for with_ad in [false, true]:
		Ads.provider = Ads.DevProvider.new() if with_ad else null
		sh.begin()
		await get_tree().process_frame
		(sh.overlay as MinigameIntroCard).play_pressed.emit()
		bot.call("play", sh.game, true)
		await get_tree().process_frame
		var rp := sh.overlay as MinigameResultPanel
		_ok(rp != null and bool(sh.bundle.get("ad_offer", false)), "the day's rewards used: the win offers an ad reward")
		if not with_ad:
			_ok(rp.ad_button == null, "offline / no ad loaded: no ad button at all")
			continue
		_ok(rp.ad_button != null, "an ad is ready: the ad button shows")
		var c1 := Meta.currency("coins")
		rp.ad_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(Meta.currency("coins") > c1 and rp.ad_button == null, "the watched ad paid and its button went away")
	Ads.provider = null
	var closed := [false]
	sh.closed.connect(func(_b: Dictionary) -> void: closed[0] = true)
	(sh.overlay as MinigameResultPanel).back_pressed.emit()
	_ok(closed[0] and sh.state == "closed", "«Назад» closes the shell")
	sh.queue_free()
	await get_tree().process_frame


# ======================================================================== per game

func _test_game(id: String) -> void:
	print("== game %s" % id)
	var t := MinigameTest.new(id, self)
	var e := MinigameRegistry.game(id)
	var dir := str(e["dir"])
	for f in ["selftest.gd", "bot.gd", "texts.gd"]:
		t.ok(ResourceLoader.exists(dir + f), "%s%s exists" % [dir, f])
	# Determinism guard: no global random numbers or wall clock in a game's own code (comments ignored).
	var bad := RegEx.create_from_string("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize)\\(|\\.shuffle\\(\\)|\\.pick_random\\(\\)|Time\\.get_(ticks|unix|time|date)")
	for fn in DirAccess.get_files_at(dir):
		if not fn.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string(dir + fn).split("\n")
		var hits: Array[String] = []
		for i in lines.size():
			var m := bad.search(lines[i].get_slice("#", 0))
			if m:
				hits.append("%d: %s" % [i + 1, m.get_string()])
		t.ok(hits.is_empty(), "%s%s: no global random numbers or clock in game code (use rng / tick) %s" % [dir, fn, str(hits)])
	if ResourceLoader.exists(dir + "selftest.gd"):
		var st: Object = (load(dir + "selftest.gd") as GDScript).new()
		await st.call("run", t)
	for sd in [1, 2, 3]:
		var r := await t.run_bot(sd, true)
		t.ok(bool(r.get("won", false)) and int(r.get("stars", 0)) >= 1, "bot wins from seed %d: %s" % [sd, str(r)])
	for sd2 in [1, 2]:
		var r2 := await t.run_bot(sd2, false)
		t.ok(not r2.is_empty() and not bool(r2.get("won", true)) and int(r2.get("stars", -1)) == 0, "bot loses from seed %d: %s" % [sd2, str(r2)])
	var a := await t.run_bot(7, true)
	var b := await t.run_bot(7, true)
	t.ok(var_to_str(a) == var_to_str(b) and not a.is_empty(), "the same seed gives the same result")
	for shot in (e["shots"] as Array):
		var g := t.make_game(4, "free", false)
		await g.prepare_shot(str(shot))
		t.ok(not g.is_done(), "shot %s prepares a board in play" % str(shot))
		t.free_game(g)
	_passes += t.passes
	_fails += t.fails
	print("   %s: %d passed, %d failed" % [id, t.passes, t.fails])
