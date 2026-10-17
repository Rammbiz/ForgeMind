class_name MinigamesMeta
## The Fair's mini-games over the account (docs/design/minigames/README.md; side_content_ideas.md «Рішення
## власника (11.10.2026)»). Pure and static, account first, no Save / Meta access: the Meta autoload wraps it
## (Meta.fair_*), saves after every call and emits the wallet signals; tests drive it directly.
##
## Limits (EconData.FAIR), per game and LOCAL day:
##   - `rewarded_per_day` rewarded WINS pay their table reward (a loss never pays and never uses a rewarded play,
##     so a quick loss can not be farmed);
##   - after those, ONE more win per day pays only after a player-started rewarded ad (book_ad; Ads.can_show() is
##     false offline and while no ad is loaded, and then the result panel has no ad button at all);
##   - every other play is free: unlimited, no reward, best score / stars still kept.
## Day rule: the counters belong to `fair.day`, a local day number (unix time + the device's UTC bias, / 86 400).
## They reset only when the local day is AFTER `fair.day`; a clock moved backwards never resets or removes
## anything, it only waits until the date passes the stored day again (arsenal_design.md §8.1, «Calendar»).
## One-time rewards (Star Ore, cosmetics) of a star tier are paid by the first REWARDED win that reaches it.
##
## Save section `fair` (EconData.fresh_account(); SCHEMA 1):
##   v        int   section schema (migrate() upgrades older sections in place)
##   day      int   local day the counters below belong to
##   today    {game id: rewarded wins booked on `day`}      ads {game id: ad rewards booked on `day`}
##   xp_day   int   Road XP the Fair booked on `day` (all games; capped by FAIR.road_xp_day_cap)
##   coins_day int  coins the Fair booked on `day` (all games; capped at FAIR.coins_day_missions daily missions)
##   road_xp  int   Road XP banked for the Road (arsenal_design.md §8.3; road.gd reads it once it ships)
##   games    {game id: GAME_KEYS}  (an unknown id is kept: a game a newer build removed keeps its record)
##   cosmetics [ids]  owned titles / frames / card backs (never removed)
##   chars    [character ids] granted by a Fair game (grant_character)

const SECTION := "fair"
const SCHEMA := 1
## Per-game record: best score and stars of ANY play (free plays too), plays (booked results), starts (plays
## begun, seeds the next board), wins, rewarded (all rewarded wins), once [star tiers whose one-time reward is
## paid], ad_play (the play number an ad last paid), counters {stats key: summed number} (numeric result stats,
## for a game's later milestones).
const GAME_KEYS := {"best_score": 0, "best_stars": 0, "plays": 0, "starts": 0, "wins": 0, "rewarded": 0, "once": [],
		"ad_play": 0, "counters": {}}
## Native gems a Fair game may grant as a whole character (Кварц, Сапфір, Аметист); Топаз / Опал only fragments.
const GRANT_GEMS: Array[String] = ["C", "R", "E"]
## Fragments a Fair game gives instead of a Топаз / Опал character (one duplicate copy's worth is HeroData's call;
## the hook takes the caller's number, capped here).
const GRANT_FRAGS_MAX := 10
const DAY_S := 86400


# ======================================================================== section

## The `fair` section (created, migrated and repaired on demand).
static func section(acc: Dictionary) -> Dictionary:
	if not acc.get(SECTION) is Dictionary or int((acc[SECTION] as Dictionary).get("v", 0)) < SCHEMA:
		migrate(acc)
	return acc[SECTION]


## A fresh `fair` section (EconData.fresh_account() holds the same shape).
static func fresh() -> Dictionary:
	return (EconData.fresh_account()[SECTION] as Dictionary).duplicate(true)


## The migration step: a save without the section (written before the Fair existed) gets the fresh one; a
## section of an older schema is upgraded in place (schema 0 -> 1: every key filled). Idempotent. Returns true
## when it changed the account.
static func migrate(acc: Dictionary) -> bool:
	if not acc.get(SECTION) is Dictionary:
		acc[SECTION] = fresh()
		return true
	var f: Dictionary = acc[SECTION]
	var v := int(f.get("v", 0)) if _num(f.get("v")) else 0
	if v >= SCHEMA:
		return false
	SaveMigrate._fill(f, fresh())
	f["v"] = SCHEMA
	return true


## Repairs the section in place (run by SaveMigrate.sanitize_v3 on every load): types, non-negative counters,
## stars 0..3, unique cosmetic and character ids, every game record filled.
static func sanitize(acc: Dictionary) -> void:
	migrate(acc)
	var f: Dictionary = acc[SECTION]
	SaveMigrate._fill(f, fresh())
	f["v"] = maxi(SCHEMA, int(f["v"]))
	for k in ["day", "xp_day", "coins_day", "road_xp"]:
		f[k] = maxi(0, int(f[k]))
	for k2 in ["today", "ads"]:
		var clean := {}
		for id in (f[k2] as Dictionary):
			var n: Variant = (f[k2] as Dictionary)[id]
			if _num(n) and int(n) > 0:
				clean[str(id)] = int(n)
		f[k2] = clean
	var games: Dictionary = f["games"]
	for id2 in games.keys():
		if not games[id2] is Dictionary:
			games.erase(id2)
			continue
		if not id2 is String:
			games[str(id2)] = games[id2]
			games.erase(id2)
	for id3: String in games:
		var g: Dictionary = games[id3]
		SaveMigrate._fill(g, GAME_KEYS)
		for k3 in ["best_score", "plays", "starts", "wins", "rewarded", "ad_play"]:
			g[k3] = maxi(0, int(g[k3]))
		g["best_stars"] = clampi(int(g["best_stars"]), 0, 3)
		var once: Array = []
		for t in (g["once"] as Array):
			if _num(t) and int(t) >= 1 and int(t) <= 3 and not once.has(int(t)):
				once.append(int(t))
		once.sort()
		g["once"] = once
	f["cosmetics"] = _str_list(f["cosmetics"])
	f["chars"] = _str_list(f["chars"])


## The record of game `id` (created on first use).
static func game(acc: Dictionary, id: String) -> Dictionary:
	var games: Dictionary = section(acc)["games"]
	if not games.get(id) is Dictionary:
		games[id] = GAME_KEYS.duplicate(true)
	return games[id]


# ======================================================================== day

## Local day number of unix time `now_s` with the device's UTC bias `bias_min` (minutes east of UTC, as
## Time.get_time_zone_from_system().bias).
static func local_day(now_s: int, bias_min := 0) -> int:
	return int(floor(float(maxi(0, now_s) + bias_min * 60) / float(DAY_S)))


## The device's UTC bias in minutes (Time.get_time_zone_from_system).
static func system_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## Starts a new day when the local day passed `fair.day` (counters cleared). A day before `fair.day` (the clock
## moved backwards) changes nothing. Returns true on a new day.
static func roll_day(acc: Dictionary, now_s: int, bias_min := 0) -> bool:
	var f := section(acc)
	var d := local_day(now_s, bias_min)
	if d <= int(f["day"]):
		return false
	f["day"] = d
	f["today"] = {}
	f["ads"] = {}
	f["xp_day"] = 0
	f["coins_day"] = 0
	return true


## Counters as they read at (now_s, bias): {rewarded_used, ads_used, xp_day} (no write).
static func _today(acc: Dictionary, id: String, now_s: int, bias_min: int) -> Dictionary:
	var f := section(acc)
	if local_day(now_s, bias_min) > int(f["day"]):
		return {"rewarded_used": 0, "ads_used": 0, "xp_day": 0}
	return {"rewarded_used": int((f["today"] as Dictionary).get(id, 0)), "ads_used": int((f["ads"] as Dictionary).get(id, 0)),
			"xp_day": int(f["xp_day"])}


# ======================================================================== status, begin

## Game `id` now: {rewarded_left, ad_left, mode ("rewarded" | "free"), best_score, best_stars, plays, wins,
## starts}. `ad_left` counts only once the rewarded wins of the day are used up.
static func status(acc: Dictionary, id: String, now_s: int, bias_min := 0) -> Dictionary:
	var t := _today(acc, id, now_s, bias_min)
	var per := int(EconData.FAIR["rewarded_per_day"])
	var left := maxi(0, per - int(t["rewarded_used"]))
	var ad_left := maxi(0, int(EconData.FAIR["ad_per_day"]) - int(t["ads_used"])) if left == 0 else 0
	var g: Dictionary = (section(acc)["games"] as Dictionary).get(id, GAME_KEYS)
	return {"rewarded_left": left, "rewarded_per_day": per, "ad_left": ad_left, "mode": "rewarded" if left > 0 else "free",
			"best_score": int(g["best_score"]), "best_stars": int(g["best_stars"]), "plays": int(g["plays"]),
			"wins": int(g["wins"]), "starts": int(g["starts"])}


## A play of `id` begins: counts the start and returns {seed, mode, start}. The seed depends on the account's
## own seed, the game and the start count, so every start deals a new board (quitting and reopening never
## replays a board) and the same account state always deals the same one.
static func begin(acc: Dictionary, id: String, now_s: int, bias_min := 0) -> Dictionary:
	roll_day(acc, now_s, bias_min)
	var g := game(acc, id)
	g["starts"] = int(g["starts"]) + 1
	var base := int((acc.get("meta", {}) as Dictionary).get("rng_seed", 0))
	var s := absi(("%s:%d:%d" % [id, base, int(g["starts"])]).hash()) % 2000000000 + 1
	return {"seed": s, "mode": str(status(acc, id, now_s, bias_min)["mode"]), "start": int(g["starts"])}


# ======================================================================== booking

## Books a finished play of `id` (`result` = MinigameGame.finish(): {won, score, stars, stats}). `mode` is the mode
## the play was STARTED in; a "rewarded" play pays only while a rewarded win is left now, a win only. `rewards` =
## the game's REWARDS table (info.gd). Returns the bundle the result panel shows:
##   {ok, rewarded, coins, road_xp, ore, ore_coins, cosmetics [ids], won, stars, score, best_score, best_stars,
##    new_best, play_n, rewarded_left, ad_offer, reason ("" | "free" | "loss" | "limit")}
## `ad_offer` = this win could be paid by a rewarded ad (the day's rewarded wins are used up, an ad reward is
## left); the panel shows the ad button only when Ads.can_show() as well.
static func book(acc: Dictionary, id: String, result: Dictionary, mode: String, rewards: Dictionary, now_s: int,
		bias_min := 0) -> Dictionary:
	roll_day(acc, now_s, bias_min)
	var f := section(acc)
	var g := game(acc, id)
	var won := bool(result.get("won", false))
	var stars := clampi(int(result.get("stars", 0)), 0, 3) if won else 0
	if won:
		stars = maxi(1, stars)
	var score := maxi(0, int(result.get("score", 0)))
	g["plays"] = int(g["plays"]) + 1
	if won:
		g["wins"] = int(g["wins"]) + 1
	var new_best := score > int(g["best_score"])
	g["best_score"] = maxi(int(g["best_score"]), score)
	g["best_stars"] = maxi(int(g["best_stars"]), stars)
	var stats: Variant = result.get("stats", {})
	if stats is Dictionary:
		for k in (stats as Dictionary):
			var v: Variant = (stats as Dictionary)[k]
			if v is int or v is float or v is Dictionary:
				MetaAcc.sum_into(g["counters"], str(k), v)
	var out := {"ok": true, "rewarded": false, "coins": 0, "road_xp": 0, "ore": 0, "ore_coins": 0, "cosmetics": [],
			"won": won, "stars": stars, "score": score, "best_score": int(g["best_score"]), "best_stars": int(g["best_stars"]),
			"new_best": new_best, "play_n": int(g["plays"]), "rewarded_left": 0, "ad_offer": false, "reason": ""}
	var st := status(acc, id, now_s, bias_min)
	if not won:
		# "loss" = a win would have paid; otherwise the day's rewards are used up (or the play was free).
		var could := mode == "rewarded" and int(st["rewarded_left"]) > 0
		out["reason"] = "loss" if could else ("limit" if mode == "rewarded" else "free")
	elif mode == "rewarded" and int(st["rewarded_left"]) > 0:
		_pay(acc, id, stars, rewards, out)
		var today: Dictionary = f["today"]
		today[id] = int(today.get(id, 0)) + 1
		g["rewarded"] = int(g["rewarded"]) + 1
		out["rewarded"] = true
	else:
		out["reason"] = "free" if mode != "rewarded" else "limit"
	var st2 := status(acc, id, now_s, bias_min)
	out["rewarded_left"] = int(st2["rewarded_left"])
	out["ad_offer"] = won and not bool(out["rewarded"]) and int(st2["ad_left"]) > 0
	# Only the rewarded wins go to the shared 400-row event log (free plays are unlimited and would flush it).
	if bool(out["rewarded"]):
		MetaTelemetry.note(acc, "fair_play", {"id": id, "stars": stars, "score": score}, now_s)
	return out


## The latest play of `id` (number `play_n`, from book()) is paid after a rewarded ad finished: the day's one ad
## reward. Refused ({ok false, reason}) when no ad reward is left, the play lost, it already got one or a later play
## exists. Returns the same bundle shape as book().
static func book_ad(acc: Dictionary, id: String, result: Dictionary, play_n: int, rewards: Dictionary, now_s: int,
		bias_min := 0) -> Dictionary:
	roll_day(acc, now_s, bias_min)
	var f := section(acc)
	var g := game(acc, id)
	var won := bool(result.get("won", false))
	var stars := maxi(1, clampi(int(result.get("stars", 1)), 1, 3)) if won else 0
	if not won:
		return {"ok": false, "reason": "loss"}
	if play_n != int(g["plays"]) or play_n <= int(g["ad_play"]):
		return {"ok": false, "reason": "stale"}
	if int(status(acc, id, now_s, bias_min)["ad_left"]) <= 0:
		return {"ok": false, "reason": "limit"}
	var out := {"ok": true, "rewarded": true, "coins": 0, "road_xp": 0, "ore": 0, "ore_coins": 0, "cosmetics": [],
			"won": true, "stars": stars, "score": maxi(0, int(result.get("score", 0))), "best_score": int(g["best_score"]),
			"best_stars": int(g["best_stars"]), "new_best": false, "play_n": play_n, "rewarded_left": 0, "ad_offer": false,
			"reason": "", "ad": true}
	_pay(acc, id, stars, rewards, out)
	var ads: Dictionary = f["ads"]
	ads[id] = int(ads.get(id, 0)) + 1
	g["ad_play"] = play_n
	g["rewarded"] = int(g["rewarded"]) + 1
	MetaTelemetry.note(acc, "fair_ad", {"id": id, "stars": stars}, now_s)
	return out


## Pays row `stars` of `rewards` into the account and `out`: coins (EconData.fair_coins at the frontier, under the
## Fair's daily coin cap; `coins_capped` when the cap cut them), Road XP (under the Fair's daily cap), the one-time
## tiers 1..stars not paid yet (Star Ore, or coins while the hero systems are off; cosmetics).
static func _pay(acc: Dictionary, id: String, stars: int, rewards: Dictionary, out: Dictionary) -> void:
	var f := section(acc)
	var g := game(acc, id)
	var frontier := MetaAcc.level(acc)
	var want := EconData.fair_coins(_row(rewards, "coins", stars), frontier)
	var coins := mini(want, maxi(0, coins_cap(frontier) - int(f["coins_day"])))
	out["coins_capped"] = coins < want
	var xp := mini(_row(rewards, "road_xp", stars), maxi(0, int(EconData.FAIR["road_xp_day_cap"]) - int(f["xp_day"])))
	var ore := 0
	var cos: Array = []
	var once: Array = g["once"]
	for tier in range(1, stars + 1):
		if once.has(tier):
			continue
		once.append(tier)
		ore += _row(rewards, "ore_once", tier)
		var c := _row_str(rewards, "cosmetic_once", tier)
		if c != "" and not (f["cosmetics"] as Array).has(c):
			(f["cosmetics"] as Array).append(c)
			cos.append(c)
	once.sort()
	var ore_coins := 0
	if ore > 0 and not EconData.heroes_live():
		ore_coins = ore * int(EconData.FAIR["ore_coins"])
		ore = 0
	MetaAcc.add(acc, "coins", coins + ore_coins)
	f["coins_day"] = int(f["coins_day"]) + coins
	if ore > 0:
		MetaAcc.add(acc, "ore", ore)
	f["road_xp"] = int(f["road_xp"]) + xp
	f["xp_day"] = int(f["xp_day"]) + xp
	out["coins"] = coins
	out["road_xp"] = xp
	out["ore"] = ore
	out["ore_coins"] = ore_coins
	out["cosmetics"] = cos


## The Fair's coins a local day may pay at campaign `frontier` (FAIR.coins_day_missions daily missions).
static func coins_cap(frontier: int) -> int:
	return int(EconData.FAIR["coins_day_missions"]) * EconData.mission_coins(mini(maxi(1, frontier), ArsenalData.CAMPAIGN_LEVELS))


static func _row(rewards: Dictionary, key: String, i: int) -> int:
	var r: Variant = rewards.get(key, [])
	if r is Array and i >= 0 and i < (r as Array).size() and _num((r as Array)[i]):
		return maxi(0, int((r as Array)[i]))
	return 0


static func _row_str(rewards: Dictionary, key: String, i: int) -> String:
	var r: Variant = rewards.get(key, [])
	if r is Array and i >= 0 and i < (r as Array).size():
		return str((r as Array)[i])
	return ""


# ======================================================================== budget (test_minigames)

## Every way a game's REWARDS table breaks the Fair budget (EconData.FAIR) or the table shape ([] = fine).
## Shape: every row has 4 entries, one per star count 0..3; index 0 (a loss) is always 0 / "" (a loss never pays).
## coins / road_xp: non-decreasing ints; ore_once: ints; cosmetic_once: strings ("" = none), each a cosmetic id the
## game declares in its COSMETICS.
static func budget_errors(rewards: Dictionary, cosmetics: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var fr: Dictionary = EconData.FAIR
	for key in ["coins", "road_xp", "ore_once", "cosmetic_once"]:
		var r: Variant = rewards.get(key)
		if not r is Array or (r as Array).size() != 4:
			out.append("%s: needs 4 values (stars 0..3)" % key)
	if not out.is_empty():
		return out
	for i in range(1, 4):
		if _row(rewards, "coins", i) < _row(rewards, "coins", i - 1) or _row(rewards, "road_xp", i) < _row(rewards, "road_xp", i - 1):
			out.append("coins / road_xp must not drop with more stars")
	if _row(rewards, "coins", 3) > int(fr["coins_3star_max"]):
		out.append("coins: 3 stars pays %d > FAIR.coins_3star_max %d" % [_row(rewards, "coins", 3), int(fr["coins_3star_max"])])
	if _row(rewards, "road_xp", 3) > int(fr["road_xp_play_max"]):
		out.append("road_xp: %d > FAIR.road_xp_play_max %d" % [_row(rewards, "road_xp", 3), int(fr["road_xp_play_max"])])
	var ore := 0
	for i2 in 4:
		ore += _row(rewards, "ore_once", i2)
	if _row(rewards, "coins", 0) != 0 or _row(rewards, "road_xp", 0) != 0 or _row(rewards, "ore_once", 0) != 0 			or _row_str(rewards, "cosmetic_once", 0) != "":
		out.append("index 0 of every row (a loss) must be 0 / \"\": a loss never pays")
	if ore > int(fr["ore_per_game_max"]):
		out.append("ore_once: %d in all > FAIR.ore_per_game_max %d" % [ore, int(fr["ore_per_game_max"])])
	for i3 in range(1, 4):
		var c := _row_str(rewards, "cosmetic_once", i3)
		if c != "" and not cosmetics.has(c):
			out.append("cosmetic_once: %s is not in COSMETICS" % c)
	for v in (rewards["coins"] as Array) + (rewards["road_xp"] as Array) + (rewards["ore_once"] as Array):
		if not _num(v) or int(v) < 0:
			out.append("rewards: negative or non-numeric value %s" % str(v))
			break
	return out


# ======================================================================== character hook

## Hook (no game uses it yet): a Fair game or story grants character `char_id`. A native Кварц / Сапфір / Аметист
## character joins (Roster.grant, via "fair"; an owned one gets its duplicate fragments); a Топаз / Опал one gets
## `frags_if_high` fragments only (capped by GRANT_FRAGS_MAX). Only while the hero systems are live. Returns
## {ok, reason?, id, kind, joined, frags, gem}.
static func grant_character(acc: Dictionary, char_id: String, now_s: int, frags_if_high := GRANT_FRAGS_MAX) -> Dictionary:
	if not EconData.heroes_live():
		return {"ok": false, "reason": "phase", "id": char_id}
	var kind := Roster.kind_of(char_id)
	if kind == "":
		return {"ok": false, "reason": "unknown", "id": char_id}
	var gem := Roster.native(char_id)
	var out := {"ok": true, "id": char_id, "kind": kind, "gem": gem, "joined": false, "frags": 0}
	if gem in GRANT_GEMS:
		var g := Roster.grant(acc, char_id, "fair", now_s)
		out["joined"] = bool(g.get("new", false))
		out["frags"] = int(g.get("frags", 0))
	else:
		out["frags"] = int(Roster.add_frags(acc, char_id, clampi(frags_if_high, 0, GRANT_FRAGS_MAX), "fair").get("frags", 0))
	var chars: Array = section(acc)["chars"]
	if bool(out["joined"]) and not chars.has(char_id):
		chars.append(char_id)
	return out


# ======================================================================== helpers

## Owned cosmetic ids (titles, card frames, card backs) in the order they were earned.
static func cosmetics(acc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for c in (section(acc)["cosmetics"] as Array):
		out.append(str(c))
	return out


static func _num(v: Variant) -> bool:
	return v is int or v is float or v is bool


static func _str_list(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for e in v:
			if (e is String or e is StringName) and str(e) != "" and not out.has(str(e)):
				out.append(str(e))
	return out
