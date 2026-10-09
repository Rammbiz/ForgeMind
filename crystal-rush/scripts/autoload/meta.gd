extends Node
## Meta: the account facade (arsenal_design.md §9.3). The hub, the result flow and the run talk
## to the account ONLY through this autoload; nothing outside scripts/meta/ and Save mutates the
## account dictionary directly.
##
## The rules live in pure classes (scripts/meta/*: Arsenal, CacheRoller, Rewards, HeroesMeta,
## Barracks, UnlockQueue, MetaTelemetry, MetaAcc) that take the account dictionary first. This
## facade keeps the frozen public API of meta1_contracts.md §4, emits the signals (wallet changes
## are found by diffing a wallet snapshot around every mutation), keeps the legacy Save fields in
## sync and saves.
##
## Persistence: Save v2 owns `Save.account`; Meta works on that very dictionary and save() calls
## Save.save_data(). Dev runs (Save.readonly: --autotest / --shot) never persist; their account
## is synthetic: `--profile=fresh|expected|max` and `--deck=a,b,c`.
## Sessions: a new session starts on launch and whenever the app returns after >= 5 min away
## (UnlockQueue.on_session_start); session lengths go to the local telemetry.

signal wallet_changed(cur: String, value: int)     ## cur: coins | gems | crowns | cores | wild_C..wild_M
signal machine_changed(id: String)                 ## level, blueprints, talents, finish or unlock changed
signal hero_changed(id: String)
signal unlocked(kind: String, id: String)          ## kind: machine | tab | system | currency | inrun | hero
signal cache_added(type: String)                   ## a Cache entered the Vault
signal deck_changed
signal barracks_changed(track: String)
signal focus_changed(id: String)
signal run_finished(bundle: Dictionary)            ## emitted by finish_run() with the result bundle
## Heroes & Champions (heroes_design.md §12.2; live phase only). wallet_changed also reports beacons,
## tomes and ore; unlocked reports kind "hero" / "champion" for characters that joined.
signal champion_changed(id: String)                ## "" = the shared Champion Level changed
signal team_changed
signal summoned(bundle: Dictionary)                ## a Portal summon was booked (and saved)
signal chest_opened(bundle: Dictionary)            ## a Hero Chest was opened (and saved)

const CURRENCIES: Array[String] = ["coins", "gems", "crowns", "cores"]
## Hero entries the synthetic dev profiles level (the 2.2.1 fresh account's entries) while the heroes
## phase is off.
const SYNTH_HERO_ENTRIES: Array[String] = ["bolt", "titan"]

var account: Dictionary = {}
var dev_profile := ""                  ## "" = the real account; else fresh | expected | max
var dev_deck: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _syncing := false
var _open_run_id := 0                  ## run id issued by the last run_profile(), consumed by finish_run()
var _open_guest := ""                  ## the guest hero of the run issued by run_profile() ("" none)
var _last_bundle: Dictionary = {}


func _ready() -> void:
	load_account()
	if Save.has_signal("coins_changed"):
		Save.coins_changed.connect(_on_legacy_coins)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_session_pause()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_session_resume()


# ======================================================================== account lifecycle

## Loads (or builds) the account. Called once on start.
func load_account() -> void:
	dev_profile = ""
	dev_deck.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			dev_profile = a.trim_prefix("--profile=")
		elif a.begins_with("--deck="):
			for id in a.trim_prefix("--deck=").split(",", false):
				if ArsenalData.MACHINES.has(id) and not dev_deck.has(id):
					dev_deck.append(id)
	if Save.readonly:
		_rng.seed = 1
		if dev_profile == "":
			dev_profile = "fresh"
		account = synthetic_account(maxi(1, int(Save.level)), dev_profile)
		(account["progress"] as Dictionary)["hero"] = str(Save.hero)
		return
	dev_deck.clear()
	dev_profile = ""
	var saved: Variant = Save.get("account")
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		account = saved
	else:
		account = EconData.fresh_account()
		Save.set("account", account)
	var p: Dictionary = account["progress"]
	if int(Save.level) > int(p.get("level", 1)):
		p["level"] = int(Save.level)
	p["hero"] = str(Save.hero)
	var m: Dictionary = account["meta"]
	if int(m.get("rng_seed", 0)) == 0:
		m["rng_seed"] = (randi() & 0x3fffffff) | 1
		_rng.seed = int(m["rng_seed"])
	else:
		_rng.seed = int(m["rng_seed"])
		if int(m.get("rng_state", 0)) != 0:
			_rng.state = int(m["rng_state"])
	_session_resume()


## Writes the account (no-op in dev runs). Results are saved BEFORE any reveal animation.
func save() -> void:
	if Save.readonly:
		return
	(account["meta"] as Dictionary)["rng_state"] = _rng.state
	Save.level = level()
	Save.coins = currency("coins")
	Save.save_data()


## Dev / QA: start over with a fresh account (keeps settings).
func reset_account() -> void:
	var settings: Dictionary = account.get("settings", {})
	var before := MetaAcc.wallet_snapshot(account)
	account.clear()
	account.merge(EconData.fresh_account())
	account["settings"] = settings
	(account["progress"] as Dictionary)["hero"] = "bolt"
	Save.level = 1
	Save.hero = "bolt"
	_emit_wallet(before)
	deck_changed.emit()
	save()


## Synthetic account at campaign `level` for dev runs, level_check and the bot.
## kind: fresh (only what the NEW crates gave, rarity start levels), expected (curve fit of the
## sim's regular player, design §6.4; build/expected_profile.json replaces it when present),
## max (all live machines Lv15, heroes and Barracks maxed). Every level-open unlock is done.
static func synthetic_account(level: int, kind := "fresh") -> Dictionary:
	var acc := EconData.fresh_account()
	var prog: Dictionary = acc["progress"]
	prog["level"] = level
	prog["world_reached"] = ArsenalData.world_of(level)
	prog["hero"] = "bolt"
	var ms: Dictionary = (acc["arsenal"] as Dictionary)["machines"]
	for id in ArsenalData.live_ids():
		var at := ArsenalData.new_crate_level(id)
		if kind == "max" or id in ArsenalData.START_OWNED or (at > 0 and at < level):
			ms[id] = EconData.new_machine_state(id, int(EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
	var w := ArsenalData.world_of(level)
	# Only the heroes a 2.2.1 fresh account had entries for (Save v3 adds the Seer's entry); keeps
	# dev runs, level_check and the bot identical until the heroes phase goes live.
	var heroes := {}
	for h0: String in (acc["heroes"] as Dictionary):
		if h0 in SYNTH_HERO_ENTRIES or EconData.heroes_run():
			heroes[h0] = (acc["heroes"] as Dictionary)[h0]
	match kind:
		"expected":
			var exp := _expected_row(level)
			var per: Dictionary = exp["machines"]
			for id: String in ms:
				var st: Dictionary = ms[id]
				var lv := int(per.get(id, round(float(exp["machine_lvl"]))))
				st["lvl"] = clampi(lv, int(st["lvl"]), ArsenalData.MAX_LEVEL)
				_auto_talents(id, st)
			for h: String in heroes:
				(heroes[h] as Dictionary)["lvl"] = clampi(int(exp["hero_lvl"]), 1, EconData.hero_cap(w))
			var bar: Dictionary = exp["barracks"]
			for t in EconData.BARRACKS_ORDER:
				(acc["barracks"] as Dictionary)[t] = mini(EconData.barracks_cap(w), int(bar.get(t, 0)))
		"max":
			for id: String in ms:
				var st2: Dictionary = ms[id]
				st2["lvl"] = ArsenalData.MAX_LEVEL
				_auto_talents(id, st2)
			for h2: String in heroes:
				(heroes[h2] as Dictionary)["lvl"] = int(EconData.HERO["max"])
			for t2 in EconData.BARRACKS_ORDER:
				(acc["barracks"] as Dictionary)[t2] = EconData.BARRACKS_MAX
	UnlockQueue.mark_all_done(acc)
	(acc["pity"] as Dictionary)["leg_welcome_done"] = w >= 3
	if EconData.heroes_run():
		_synthetic_heroes(acc, level, kind)
	return acc


## Hero systems of a synthetic account (heroes phase >= HEROES_RUN_PHASE): the starters a player at
## `level` has met by progress, the two scripted champions (gift chest #1 by the team hero, #2) in
## the team slots, Champion Level (expected: SaveV3Data.EXPECTED_CHAMPION_LEVEL; max: the cap).
## Never a random-sourced character (the EXPECTED profile is the free floor, heroes_design.md P4);
## the disclosed welcome Topaz of the EXPECTED profile is WS-A / WS-C's choice (H2, TEAM_DEMAND).
static func _synthetic_heroes(acc: Dictionary, level: int, kind: String) -> void:
	var hs: Dictionary = acc["heroes"]
	for id: String in SaveV3Data.STARTERS:
		var at := EconData.hero_unlock_at(id)
		if at >= 0 and level > at and hs.has(id) and not bool((hs[id] as Dictionary)["owned"]):
			(hs[id] as Dictionary)["owned"] = true
			(hs[id] as Dictionary)["seen"] = true
			(hs[id] as Dictionary)["got"] = {"t": 0, "via": "progress"}
	var team: Dictionary = acc["team"]
	team["hero"] = str((acc["progress"] as Dictionary).get("hero", "bolt"))
	var ch: Dictionary = acc["champions"]
	var champs: Array = []
	if level > int(SaveV3Data.UNLOCK_AT["champions"]):
		champs.append(str(PortalData.SCRIPTED_FIRST.get(str(team["hero"]), PortalData.SCRIPTED_FIRST_DEFAULT)))
		champs.append(PortalData.SCRIPTED_SECOND)
		for cid: String in champs:
			(ch["roster"] as Dictionary)[cid] = EconData.new_champion_state(cid, true, "chest")
		(acc["chests"] as Dictionary)["scripted"] = 2
		(acc["chests"] as Dictionary)["unlock_gift"] = true
	team["champions"] = champs
	var cl_table: Array[int] = SaveV3Data.EXPECTED_CHAMPION_LEVEL
	match kind:
		"expected":
			ch["level"] = cl_table[clampi(level - 1, 0, cl_table.size() - 1)]
		"max":
			ch["level"] = SaveV3Data.CHAMP_LEVEL_MAX


static var _expected_cache: Dictionary = {}


## EXPECTED profile row for `level`: build/expected_profile.json (economy_sim --export-expected)
## when it exists, else the design §6.4 curve fit (deck Lv ~8 at L30, ~11.6 at L60; hero ~15.8
## at L60; Barracks from L12).
static func _expected_row(level: int) -> Dictionary:
	if _expected_cache.is_empty():
		_expected_cache["levels"] = {}
		for p in ["res://build/expected_profile.json"]:
			if FileAccess.file_exists(p):
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
				if data is Dictionary and (data as Dictionary).get("levels") is Dictionary:
					_expected_cache["levels"] = data["levels"]
	var rows: Dictionary = _expected_cache["levels"]
	if rows.has(str(level)):
		var row: Dictionary = rows[str(level)]
		return {"machine_lvl": float(row.get("machine_lvl", 1.0)), "hero_lvl": int(row.get("hero_lvl", 1)),
				"barracks": row.get("barracks", {}) if row.get("barracks") is Dictionary else {},
				"machines": row.get("machines", {}) if row.get("machines") is Dictionary else {}}
	var lv := 1.0 + 7.0 * clampf(float(level - 3) / 27.0, 0.0, 1.0) + 3.6 * clampf(float(level - 30) / 30.0, 0.0, 1.0)
	var b := 0 if level <= 12 else (level - 12) / 8 + 1
	var bar := {}
	for t in EconData.BARRACKS_ORDER:
		bar[t] = b
	return {"machine_lvl": lv, "hero_lvl": int(round(1.0 + 14.8 * float(level) / 60.0)), "barracks": bar, "machines": {}}


static func _auto_talents(id: String, st: Dictionary) -> void:
	var tal: Array = st["talents"]
	for tier in 3:
		var opts := ArsenalData.talent_options(id, tier)
		var live := bool(ArsenalData.FEATURES["talents12" if tier < 2 else "talent3"])
		if live and int(st["lvl"]) >= ArsenalData.TALENT_LEVELS[tier] and not opts.is_empty():
			tal[tier] = str((opts[0] as Dictionary)["id"])


# ======================================================================== progress and unlocks

## Next campaign level to play (1-based).
func level() -> int:
	var p: Dictionary = account["progress"]
	if not Save.readonly and int(Save.level) > int(p.get("level", 1)):
		p["level"] = int(Save.level)      # the legacy router advanced it (until WS5 switches to finish_run)
		p["world_reached"] = maxi(int(p.get("world_reached", 1)), ArsenalData.world_of(int(p["level"])))
	return maxi(int(p.get("level", 1)), 1)


func world_reached() -> int:
	level()
	return MetaAcc.world(account)


## True once the design's unlock `id` is open (level AND session rules; phase-gated).
## Unknown ids are open.
func is_unlocked(id: String) -> bool:
	level()
	return UnlockQueue.is_open(account, id)


## Unlocks whose tutorial line the hub should show now, oldest first (≤ 2 per session; the
## one-time migration card first: {id "migration", kind "card", line "MIGRATION_CARD"}).
func pending_unlocks() -> Array[Dictionary]:
	level()
	return UnlockQueue.pending(account)


## The UI showed unlock `id` (tutorial line + first free step). Returns {} or, for the champions
## unlock of a player whose unlock win did not open it (a migrated player's catch-up card), the
## reveal of the gift chest (scripted chest #1; its champion takes slot 1), already saved.
func ack_unlock(id: String) -> Dictionary:
	var before := MetaAcc.wallet_snapshot(account)
	var u := EconData.unlock_entry(id)
	UnlockQueue.ack(account, id)
	var reveal := {}
	match str(u.get("free", "")):
		"recruits_lv1":
			barracks_changed.emit("recruits")
		"auto_deck":
			deck_changed.emit()
		"ballista_lv2":
			machine_changed.emit(str(MetaAcc.free_steps(account).get("machine", "ballista")))
		"hero_level":
			hero_changed.emit(hero())
		"first_champion":
			if heroes_on():
				var hc := Vault.hero_chests(account)
				for i in range(hc.size() - 1, -1, -1):
					if str((hc[i] as Dictionary).get("source", "")) == "unlock":
						reveal = open_hero_chest(i)
						break
	_emit_wallet(before)
	note("unlock_ack", {"id": id})
	save()
	return reveal


# ======================================================================== wallet

## Balance of `cur` (coins, gems, crowns, cores; wild_<R> also works).
func currency(cur: String) -> int:
	return MetaAcc.amount(account, cur)


## Wild Blueprints of rarity `r`.
func wild(r: String) -> int:
	return MetaAcc.amount(account, "wild_" + r)


## Currencies only earned income may credit (Meta.add_currency refuses them, review F9).
const EARNED_ONLY: Array[String] = ["beacons", "seals", "tomes", "ore"]


## Adds (or with n < 0 removes, never below 0) currency. `source` feeds telemetry.
func add_currency(cur: String, n: int, source := "") -> void:
	if n > 0 and cur in EARNED_ONLY:
		# Two-track rule (§7.3, review F9): Beacons, Seals, Tomes and Star Ore come only from earned
		# sources (Rewards, Summon, HeroChest, migration), never from a shop / IAP / dev helper.
		push_warning("Meta.add_currency refused %s (earned-only currency, source %s)" % [cur, source])
		return
	var before := MetaAcc.wallet_snapshot(account)
	MetaAcc.add(account, cur, n)
	_emit_wallet(before)
	if source != "":
		note("currency", {"cur": cur, "n": n, "source": source})
	save()


## Spends `n` of `cur` if affordable. Returns false (and changes nothing) otherwise.
func spend(cur: String, n: int) -> bool:
	var before := MetaAcc.wallet_snapshot(account)
	if not MetaAcc.spend(account, cur, n):
		return false
	_emit_wallet(before)
	save()
	return true


## Emits wallet_changed for every currency that differs from `before` and mirrors coins to Save.
func _emit_wallet(before: Dictionary) -> void:
	var now := MetaAcc.wallet_snapshot(account)
	for cur: String in now:
		if int(now[cur]) != int(before.get(cur, 0)):
			if cur == "coins":
				_mirror_coins(int(now[cur]))
			wallet_changed.emit(cur, int(now[cur]))


func _mirror_coins(v: int) -> void:
	if _syncing:
		return
	_syncing = true
	Save.coins = v
	Save.coins_changed.emit(v)
	_syncing = false


func _on_legacy_coins(v: int) -> void:
	if _syncing:
		return
	(account["wallet"] as Dictionary)["coins"] = v
	wallet_changed.emit("coins", v)


# ======================================================================== arsenal

func owned(id: String) -> bool:
	return MetaAcc.owned(account, id)


## Ids of owned machines in roster order.
func owned_ids() -> Array[String]:
	return Arsenal.owned_ids(account)


## Copy of the saved machine state ({} when not owned).
func machine_state(id: String) -> Dictionary:
	return (MetaAcc.machines(account).get(id, {}) as Dictionary).duplicate(true)


func machine_level(id: String) -> int:
	return MetaAcc.machine_level(account, id)


## Final numbers for UI and Run (§6.1 + `final` {damage, dps, add}).
func stats(id: String, rank := 1) -> Dictionary:
	return Arsenal.stats(account, id, rank)


## Price of the next level of `id` (§6.3): {id, to_lvl, coins, bp_need, bp_have, wild_use, can,
## reason, beat, free}.
func upgrade_cost(id: String) -> Dictionary:
	level()
	return Arsenal.cost(account, id)


func can_upgrade(id: String) -> bool:
	return bool(upgrade_cost(id)["can"])


## Buys the next level. Returns {ok, id, lvl, beat, coins, bp, wild, free} (ok false = nothing changed).
func upgrade(id: String) -> Dictionary:
	level()
	var before := MetaAcc.wallet_snapshot(account)
	var lead_before := lead()
	var res := Arsenal.upgrade(account, id)
	if not bool(res["ok"]):
		return res
	_emit_wallet(before)
	machine_changed.emit(id)
	if lead() != lead_before:
		deck_changed.emit()
	note("upgrade", {"id": id, "lvl": res["lvl"], "coins": res["coins"]})
	save()
	return res


## The beat reached at machine level `lvl` (talent1 | lead | talent2 | ascension | talent3 |
## apex | prestige | mastered | "").
static func beat_at(lvl: int) -> String:
	return Arsenal.beat_at(lvl)


## Unlocks `id` (NEW crate, Cache card, migration) at its Arsenal Sync level. True when new.
func unlock_machine(id: String, source := "") -> bool:
	if not Arsenal.unlock(account, id, source):
		return false
	note("unlock", {"id": id, "source": source})
	machine_changed.emit(id)
	unlocked.emit("machine", id)
	save()
	return true


## Picks Talent `talent_id` for tier 0/1/2 ("" clears; free respec). False if not allowed.
func set_talent(id: String, tier: int, talent_id: String) -> bool:
	if not Arsenal.set_talent(account, id, tier, talent_id):
		return false
	machine_changed.emit(id)
	save()
	return true


## Ascension branch "a"/"b" for Epic+ (false while FEATURES.branches is off).
func set_branch(id: String, branch: String) -> bool:
	if not Arsenal.set_branch(account, id, branch):
		return false
	machine_changed.emit(id)
	save()
	return true


## Focus machine (40% of Cache cards of its rarity). "" = default (the Lead).
func set_focus(id: String) -> void:
	Arsenal.set_focus(account, id)
	focus_changed.emit(focus())
	save()


func focus() -> String:
	return Arsenal.focus(account)


## Deck slots open now (3 in Meta-1).
func deck_slots() -> int:
	return Arsenal.deck_slots(account)


## The active deck (slot 0 = Lead slot). Automatic before the Deck unlock; dev runs may force it
## with --deck=.
func deck() -> Array[String]:
	if not dev_deck.is_empty():
		var out: Array[String] = []
		for id in dev_deck:
			if ArsenalData.is_live(id) and out.size() < maxi(deck_slots(), 3):
				out.append(id)
		return out
	level()
	return Arsenal.deck(account)


## The Lead (deck slot 1, Lv5+, after the Deck unlock), "" when none.
func lead() -> String:
	if not dev_deck.is_empty():
		var d := deck()
		return d[0] if not d.is_empty() and machine_level(d[0]) >= ArsenalData.LEAD_LEVEL else ""
	return Arsenal.lead(account)


## Saves deck `ids` into the active preset. False if an id is unknown / unowned / too many.
func set_deck(ids: Array) -> bool:
	if not Arsenal.set_deck(account, ids):
		return false
	deck_changed.emit()
	focus_changed.emit(focus())
	save()
	return true


## Suggested deck for the next level: answers to `threats` (property ids) first, then the
## strongest owned machines.
func auto_deck(threats: Array = []) -> Array[String]:
	return Arsenal.auto_deck(account, threats)


## Everything a machine card / detail screen needs (§6.2).
func machine_card(id: String) -> Dictionary:
	level()
	return Arsenal.card(account, id, Arsenal.best_upgrade(account), deck())


## Cards for the grid. filter: all | owned | upgradable | <family id>.
func machine_cards(filter := "all") -> Array[Dictionary]:
	level()
	return Arsenal.cards(account, filter)


## The pre-selected "Best upgrade" {kind: machine | hero | barracks, id, cost, label, to_lvl}.
func best_upgrade() -> Dictionary:
	level()
	return Arsenal.best_upgrade(account)


## Arsenal header milestone: the nearest beat among Deck machines {id, lvl, beat, levels_left}.
func next_milestone() -> Dictionary:
	return Arsenal.next_milestone(account)


## Coins left to max every owned machine: {coins, share_done, bp}.
func remaining_cost() -> Dictionary:
	return Arsenal.remaining_cost(account)


## Arsenal Rating (no damage; drives the Track in Meta-3).
func rating() -> int:
	return Arsenal.rating(account)


# ======================================================================== heroes

## The hero picked for the next run (Save.hero while the legacy menu exists; live phase: the team
## hero, team.hero, which Save.hero mirrors).
func hero() -> String:
	if heroes_on():
		var t := Team.hero(account)
		if Roster.owned(account, t):
			return t
	return str(Save.hero) if Balance.HEROES.has(str(Save.hero)) else "bolt"


func set_hero(id: String) -> void:
	if heroes_on():
		if hero_unlocked(id):
			set_team(id, Team.champions(account))
		return
	if hero_unlocked(id) and Balance.HEROES.has(id):
		(account["progress"] as Dictionary)["hero"] = id
		Save.set_hero(id)
		hero_changed.emit(id)
		save()


func hero_unlocked(id: String) -> bool:
	level()
	return HeroesMeta.unlocked(account, id, Save.readonly)


## The level hero `id` plays at (live phase: Hero Sync, HeroesMeta.eff_level; hero_own_level() is
## its own level).
func hero_level(id: String) -> int:
	if heroes_on():
		level()
		return HeroesMeta.eff_level(account, id)
	return HeroesMeta.level(account, id)


func hero_cap() -> int:
	level()
	return HeroesMeta.cap(account)


## Coins for the next level of hero `id` (0 while the free first level is unused).
func hero_cost(id: String) -> int:
	return HeroesMeta.cost(account, id)


func can_level_hero(id: String) -> bool:
	level()
	return HeroesMeta.can_level(account, id, Save.readonly)


## Buys a hero level: {ok, id, lvl, milestone ("" | ult_rank | awakening), coins, free}.
func level_hero(id: String) -> Dictionary:
	level()
	var before := MetaAcc.wallet_snapshot(account)
	var res := HeroesMeta.level_up(account, id, Save.readonly)
	if not bool(res["ok"]):
		return res
	_emit_wallet(before)
	hero_changed.emit(id)
	if not heroes_on():
		note("hero_level", {"id": id, "lvl": res["lvl"]})     # live: HeroesMeta logs {id, lvl, synced}
	save()
	return res


## Run-ready hero block (§6.4 "hero").
func hero_profile(id: String) -> Dictionary:
	return HeroesMeta.profile(account, id)


# ======================================================================== Heroes & Champions (v3)
# heroes_design.md §12.2 / framework §9.3: query + mutate the hero systems through the WS-A rule
# classes (Roster, HeroesMeta, ChampionsMeta, Team, Summon, HeroChest). Queries work in every phase
# (the hub UI of H3 and the dev galleries read them); every MUTATION returns {ok false, reason
# "phase"} and changes nothing while EconData.heroes_live() is false, so no 2.2.1 flow can touch the
# v3 sections. A grant (summon, Seal pick, chest) is saved BEFORE it is returned; when the write
# fails the account and the RNG roll back and {ok false, reason "save"} comes back (§12.1).

## True while the hero systems are live (EconData.heroes_live()).
func heroes_on() -> bool:
	return EconData.heroes_live()


func _phase_off(extra: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "reason": "phase"}
	out.merge(extra)
	return out


## Saves after a hero-system change. When the write fails, the in-memory account (the very
## dictionary Save holds) and the RNG go back to `snap` / `rng_state` and false is returned.
func _commit(snap: Dictionary, rng_state: int) -> bool:
	if Save.readonly:
		(account["meta"] as Dictionary)["rng_state"] = _rng.state
		return true
	(account["meta"] as Dictionary)["rng_state"] = _rng.state
	Save.level = level()
	Save.coins = currency("coins")
	if Save.save_data() == OK:
		return true
	account.clear()
	account.merge(snap)
	_rng.state = rng_state
	Save.level = level()
	Save.coins = currency("coins")
	return false


## Runs `fn` (a rule call returning a result Dictionary with "ok") as one saved transaction: wallet
## signals, rollback on a failed write. Returns the rule's result ({ok false, reason "save"} after a
## rollback).
func _transact(fn: Callable) -> Dictionary:
	var snap := account.duplicate(true)
	var rs := _rng.state
	var before := MetaAcc.wallet_snapshot(account)
	var res: Dictionary = fn.call()
	if not bool(res.get("ok", false)):
		return res
	if not _commit(snap, rs):
		_emit_wallet(before)
		return {"ok": false, "reason": "save"}
	_emit_wallet(before)
	return res


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# ------------------------------------------------------------------ heroes

## Hero ids in collector order. filter: all | owned | gem:<C..M> (current gem) | native:<C..M> |
## class:<c> | element:<e> | faction:<f>.
func hero_ids(filter := "all") -> Array[String]:
	return _ids(HeroData.HERO_ORDER, filter)


## Champion ids in collector order (same filters as hero_ids).
func champion_ids(filter := "all") -> Array[String]:
	return _ids(ChampionData.CHAMPION_ORDER, filter)


func _ids(order: Array[String], filter: String) -> Array[String]:
	var out: Array[String] = []
	var parts := filter.split(":", false, 1)
	var key := parts[0] if parts.size() > 0 else "all"
	var val := parts[1] if parts.size() > 1 else ""
	for id in order:
		var keep := true
		match key:
			"owned":
				keep = Roster.owned(account, id)
			"gem":
				keep = Roster.gem(account, id) == val
			"native":
				keep = Roster.native(id) == val
			"class", "element", "faction":
				keep = str(Team.tags(id).get(key, "")) == val
		if keep:
			out.append(id)
	return out


## The hero's OWN level (Hero Sync: hero_level() is the level it plays at).
func hero_own_level(id: String) -> int:
	return HeroesMeta.level(account, id)


## Everything a hero card / Showcase reads (framework §9.6 with the final design's resources: no
## coins in the hero axes). Names are Loc keys (HERO_<ID>, HERO_<ID>_TITLE).
func hero_card(id: String) -> Dictionary:
	if not HeroData.HEROES.has(id):
		return {}
	level()
	var d: Dictionary = HeroData.HEROES[id]
	var e := Roster.entry(account, id)
	var owned_now := Roster.owned(account, id)
	var n := Roster.native(id)
	var g := Roster.gem(account, id)
	var f := Roster.facets(account, id)
	var skills := {}
	for s in HeroesMeta.RANKED:
		var c := skill_cost(id, s)
		skills[s] = {"rank": HeroesMeta.skill_rank(account, id, s), "cap": HeroesMeta.skill_cap(account, id, s),
				"native_max": Ladder.skill_cap(g, g, f), "can": bool(c["can"]), "cost": int(c["tomes"]),
				"free": bool(c["free"])}
	(skills["ult"] as Dictionary)["form"] = HeroesMeta.ult_form(account, id)
	(skills["ult"] as Dictionary)["form_max"] = Ladder.max_form(n)
	var awk := HeroesMeta.skill_rank(account, id, "awakened")
	var need := ""
	if awk == 0:
		need = "gem_E" if Ladder.gem_index(g) < Ladder.gem_index(Ladder.AWAKEN_MIN_GEM) else "full_cut"
	var ac := skill_cost(id, "awakened")
	skills["awakened"] = {"open": awk > 0, "rank": awk, "cap": Ladder.awaken_cap(n, g) if awk > 0 else 0,
			"native_max": Ladder.awaken_cap(g, g), "can": bool(ac["can"]), "cost": int(ac["tomes"]), "need": need,
			"born": Ladder.born_awakened(n)}
	var fc := facet_cost("hero", id)
	var rc := recut_cost("hero", id)
	var card := {"id": id, "kind": "hero", "owned": owned_now, "name": "HERO_" + id.to_upper(),
			"title": "HERO_" + id.to_upper() + "_TITLE", "no": int(d.get("no", 0)), "native": n, "gem": g,
			"recut": Roster.is_recut(account, id), "facets": f, "frags": Roster.frags(account, id),
			"frags_need": int(fc["frags_need"]), "can_facet": bool(fc["can"]), "can_recut": bool(rc["can"]),
			"recut_to": str(rc["to_gem"]), "recut_frags": int(rc["frags"]), "at_max": Roster.at_max(account, id),
			"lvl": hero_level(id), "own_lvl": hero_own_level(id), "cap": hero_cap(),
			"synced": HeroesMeta.synced(account, id) if heroes_on() else false,
			"class": str(d["class"]), "element": str(d["element"]), "faction": str(d["faction"]), "skills": skills,
			"power": HeroesMeta.might(account, id), "seen": bool(e.get("seen", false)),
			"got": (e.get("got", {}) as Dictionary).duplicate(), "chronicle": int(e.get("chronicle", 0)),
			"loadout": (e.get("loadout", {}) as Dictionary).duplicate(), "in_team": Team.hero(account) == id,
			"rewrite": HeroesMeta.rewrite_refund(account, id), "can_rewrite": HeroesMeta.rewrite_block(account, id) == ""}
	if Roster.is_recut(account, id):
		# A native of the current gem at the same investment (rule #3 printed on the card).
		var ranks := HeroesMeta.ranks(account, id)
		var nat := HeroesMeta.index(Ladder.gem_index(g), Ladder.gem_index(g), f, HeroesMeta.eff_level(account, id), ranks)
		card["ceiling_power"] = roundi(1000.0 * nat)
	if not owned_now:
		card["sources"] = hero_sources(id)
	var badge := ""
	if owned_now and not bool(e.get("seen", true)):
		badge = "!"
	elif owned_now and (bool(fc["can"]) or bool(rc["can"])):
		badge = "arrow"
	card["badge"] = badge
	return card


## Where an unowned hero comes from: ["progress:<level>"] for a starter, else ["portal",
## "seal:<price>"] (Seal shop from Amethyst; only `complete` art enters the pool, HeroArt, WS-E).
func hero_sources(id: String) -> Array[String]:
	var out: Array[String] = []
	var at := EconData.hero_unlock_at(id)
	if id in SaveV3Data.STARTERS and at >= 0:
		out.append("progress:%d" % (at + 1))
		return out
	out.append("portal")
	var price := PortalData.seal_price(Roster.native(id))
	if price > 0:
		out.append("seal:%d" % price)
	return out


## The hero (or champion) card was shown: its NEW mark clears.
func mark_seen(id: String) -> void:
	if not heroes_on():
		return
	var e := Roster.entry(account, id)
	if e.is_empty() or bool(e.get("seen", false)):
		return
	e["seen"] = true
	save()


## Facets: {frags_need, frags_have, can, reason}. kind = hero | champion (checked against the id).
func facet_cost(kind: String, id: String) -> Dictionary:
	var why := "kind" if Roster.kind_of(id) != kind else Roster.facet_block(account, id)
	return {"frags_need": Roster.facet_cost(account, id), "frags_have": Roster.frags(account, id), "can": why == "",
			"reason": why}


## One facet («Грань»): {ok, reason, id, gem, facets, full_cut, awakened, tomes}.
func add_facet(kind: String, id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	if Roster.kind_of(id) != kind:
		return {"ok": false, "reason": "kind", "id": id}
	var res := _transact(func() -> Dictionary: return Roster.facet_up(account, id, _now()))
	if bool(res.get("ok", false)):
		res["gem"] = Roster.gem(account, id)
		res["full_cut"] = bool(res.get("full", false))
		_changed(id)
	return res


## «+»: every facet the banked fragments buy (one ceremony): {ok, reason, id, steps, facets, full, awakened, tomes}.
func fill_facets(kind: String, id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	if Roster.kind_of(id) != kind:
		return {"ok": false, "reason": "kind", "id": id}
	var res := _transact(func() -> Dictionary: return Roster.facet_fill(account, id, _now()))
	if bool(res.get("ok", false)):
		_changed(id)
	return res


## Recut («Огранка»): {to_gem, frags, coins (always 0: no coins in hero axes), can, reason}.
func recut_cost(kind: String, id: String) -> Dictionary:
	var why := "kind" if Roster.kind_of(id) != kind else Roster.recut_block(account, id)
	var g := Ladder.gem_index(Roster.gem(account, id))
	var to := "" if g < 0 or g >= Ladder.gem_index(Roster.max_gem(id)) else Ladder.GEMS[g + 1]
	return {"to_gem": to, "frags": Roster.recut_cost(account, id), "coins": 0, "can": why == "", "reason": why,
			"preview": Roster.recut_preview(account, id)}


## Recut to the next gem: {ok, reason, id, from, to, frags}.
func recut(kind: String, id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	if Roster.kind_of(id) != kind:
		return {"ok": false, "reason": "kind", "id": id}
	var res := _transact(func() -> Dictionary: return Roster.recut(account, id, _now()))
	if bool(res.get("ok", false)):
		_changed(id)
	return res


## Skill rank price: {to_rank, tomes, coins (0), cap, native_max, can, reason, free}.
func skill_cost(id: String, skill: String) -> Dictionary:
	var why := HeroesMeta.rank_block(account, id, skill) if HeroData.HEROES.has(id) else "owned"
	var g := Roster.gem(account, id)
	var f := Roster.facets(account, id)
	var nmax := Ladder.awaken_cap(g, g) if skill == "awakened" else Ladder.skill_cap(g, g, f)
	return {"to_rank": HeroesMeta.skill_rank(account, id, skill) + 1, "tomes": HeroesMeta.rank_cost(account, id, skill),
			"coins": 0, "cap": HeroesMeta.skill_cap(account, id, skill), "native_max": nmax, "can": why == "",
			"reason": why, "free": HeroesMeta.free_rank(account, id, skill)}


## One rank of `skill` (ult | attack | rally | awakened) for Tomes: {ok, reason, id, skill, rank,
## form_before, form_after, tomes, free}.
func rank_skill(id: String, skill: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id, "skill": skill})
	var form0 := HeroesMeta.ult_form(account, id)
	var res := _transact(func() -> Dictionary: return HeroesMeta.rank_up(account, id, skill, _now()))
	if bool(res.get("ok", false)):
		res["form_before"] = form0
		res["form_after"] = HeroesMeta.ult_form(account, id)
		hero_changed.emit(id)
	return res


## The hero may raise its Awakening («Пробудження») now.
func can_awaken(id: String) -> bool:
	return HeroesMeta.can_rank_up(account, id, "awakened")


## One Awakening rank (Awakening opens by itself at Full facets in Amethyst+, or at birth for a
## native Amethyst / Topaz / Opal): rank_skill(id, "awakened").
func awaken(id: String) -> Dictionary:
	return rank_skill(id, "awakened")


## Tomes a «Переписати навички / Rewrite skills» would return now.
func rewrite_refund(id: String) -> int:
	return HeroesMeta.rewrite_refund(account, id)


## Rewrite skills (never on a team / preset hero): {ok, reason, id, tomes_back}.
func rewrite_skills(id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	var res := _transact(func() -> Dictionary: return HeroesMeta.rewrite(account, id, _now()))
	if bool(res.get("ok", false)):
		hero_changed.emit(id)
	return res


## «Хроніка героя / Hero Chronicle» (§3.5): the next page of hero `id` (1..5) and its Tomes
## ({page 0 = all bought, tomes, can, reason}); cosmetic only, opens with the skills (L30).
func chronicle_cost(id: String) -> Dictionary:
	var e := Roster.entry(account, id)
	var page := int(e.get("chronicle", 0)) + 1
	var prices: Array[int] = HeroData.CHRONICLE_PRICES
	var tomes := prices[page - 1] if page <= prices.size() else 0
	var why := ""
	if not Roster.owned(account, id) or Roster.kind_of(id) != Roster.KIND_HERO:
		why = "owned"
	elif page > prices.size():
		why = "done"
	elif not Roster.system_open(account, "skills"):
		why = "locked"
	elif currency("tomes") < tomes:
		why = "tomes"
	return {"page": page if page <= prices.size() else 0, "tomes": tomes, "can": why == "", "reason": why}


## Buys the next Chronicle page with Tomes: {ok, reason, id, page, tomes}.
func buy_chronicle(id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	level()
	var fn := func() -> Dictionary:
		var c := chronicle_cost(id)
		if not bool(c["can"]):
			return {"ok": false, "reason": c["reason"], "id": id}
		MetaAcc.spend(account, "tomes", int(c["tomes"]))
		Roster.entry(account, id)["chronicle"] = int(c["page"])
		MetaTelemetry.note(account, "chronicle", {"id": id, "page": int(c["page"])}, _now())
		return {"ok": true, "reason": "", "id": id, "page": int(c["page"]), "tomes": int(c["tomes"])}
	var res := _transact(fn)
	if bool(res.get("ok", false)):
		hero_changed.emit(id)
	return res


## The UI played (or skipped) ceremony `kind` for `s` seconds (live phase; §12.5 `ceremony`).
func note_ceremony(kind: String, s: float, skipped: bool) -> void:
	if heroes_on():
		note("ceremony", {"kind": kind, "s": snappedf(s, 0.01), "skipped": skipped})


func _changed(id: String) -> void:
	if Roster.kind_of(id) == Roster.KIND_CHAMPION:
		champion_changed.emit(id)
	else:
		hero_changed.emit(id)


# ------------------------------------------------------------------ champions

## Champion card (framework §9.6; Loc keys CHAMP_<ID>, CHAMP_<ID>_TITLE, CHAMP_<ID>_ROLE).
func champion_card(id: String) -> Dictionary:
	if not ChampionData.CHAMPIONS.has(id):
		return {}
	level()
	var d: Dictionary = ChampionData.CHAMPIONS[id]
	var e := Roster.entry(account, id)
	var st := ChampionsMeta.stats(account, id)
	var fc := facet_cost("champion", id)
	var rc := recut_cost("champion", id)
	var up := id.to_upper()
	return {"id": id, "kind": "champion", "owned": Roster.owned(account, id), "name": "CHAMP_" + up,
			"title": "CHAMP_" + up + "_TITLE", "role": "CHAMP_" + up + "_ROLE", "no": int(d.get("no", 0)),
			"native": Roster.native(id), "gem": Roster.gem(account, id), "recut": Roster.is_recut(account, id),
			"facets": Roster.facets(account, id), "frags": Roster.frags(account, id), "frags_need": int(fc["frags_need"]),
			"can_facet": bool(fc["can"]), "can_recut": bool(rc["can"]), "recut_to": str(rc["to_gem"]),
			"recut_frags": int(rc["frags"]), "at_max": Roster.at_max(account, id), "class": str(d["class"]),
			"element": str(d["element"]), "faction": str(d["faction"]), "slot": str(d["slot"]),
			"action": {"tier": int(st["tier"]), "tier_max": ChampionData.action_tier(id), "power": float(st["action"])},
			"aura": {"value": float(st["aura"]), "effect": ChampionsMeta.aura_effect(float(st["aura"]), str(d["slot"])),
					"radius": float(st["radius"])},
			"hp": float(st["hp"]), "level": ChampionsMeta.level(account), "power": roundi(1000.0 * ChampionsMeta.power(account, id)),
			"seen": bool(e.get("seen", false)), "got": (e.get("got", {}) as Dictionary).duplicate(),
			"in_team": Team.champions(account).has(id), "sources": ["chest"] if not Roster.owned(account, id) else [],
			"chest_focus": chest_focus(Roster.native(id)) == id}


## Shared Champion Level («Рівень чемпіонів»).
func champion_level() -> int:
	return ChampionsMeta.level(account)


func champion_level_cap() -> int:
	level()
	return ChampionsMeta.cap(account)


## Coins for the next Champion Level (0 at the max).
func champion_level_cost() -> int:
	return ChampionsMeta.cost(account)


func can_level_champions() -> bool:
	level()
	return heroes_on() and ChampionsMeta.can_level(account)


## One Champion Level for coins: {ok, reason, level, coins}.
func level_champions() -> Dictionary:
	if not heroes_on():
		return _phase_off({"level": champion_level()})
	level()
	var res := _transact(func() -> Dictionary: return ChampionsMeta.level_up(account, _now()))
	if bool(res.get("ok", false)):
		champion_changed.emit("")
	return res


## Chest Focus of `gem` (a champion id, "" = none). Applies once every champion of that gem is owned
## (exactly CHEST_FOCUS_TOTAL of that gem's cards).
func chest_focus(gem: String) -> String:
	return str(((account["chests"] as Dictionary).get("focus", {}) as Dictionary).get(gem, ""))


## Sets champion `id` as the chest Focus of its native gem ("" id clears `gem`). Free, any time.
func set_chest_focus(id: String, gem := "") -> bool:
	if not heroes_on():
		return false
	var fo: Dictionary = (account["chests"] as Dictionary)["focus"]
	if id == "":
		fo.erase(gem)
	elif ChampionData.CHAMPIONS.has(id):
		fo[Roster.native(id)] = id
	else:
		return false
	save()
	return true


# ------------------------------------------------------------------ team

## The active team {hero, champions, slots, preset}.
func team() -> Dictionary:
	return {"hero": Team.hero(account), "champions": Team.champions(account), "slots": team_slots(),
			"preset": int(Team.team(account).get("preset", 0))}


## Champion slots open now (0 before the champions unlock, 2 from L14, 3 from L40).
func team_slots() -> int:
	level()
	return Team.slots(account)


## Sets the active team (owned hero + owned champions within the slots). The hero also becomes
## the hero of the next run (Save.hero / progress.hero follow it).
func set_team(hero_id: String, champs: Array) -> bool:
	if not heroes_on():
		return false
	level()
	var fn := func() -> Dictionary:
		var r := Team.set_team(account, hero_id, champs, _now())
		if bool(r.get("ok", false)):
			(account["progress"] as Dictionary)["hero"] = hero_id
			Save.hero = hero_id
		return r
	var res := _transact(fn)
	if not bool(res.get("ok", false)):
		return false
	team_changed.emit()
	hero_changed.emit(hero_id)
	return true


## Synergy of a candidate team (Team.synergy over the members: ids, faction tiers, class pairs,
## Affinity) + the run effects (Team.run_effects).
func team_synergy(hero_id: String, champs: Array) -> Dictionary:
	var m := Team.members(hero_id, champs)
	var syn := Team.synergy(m)
	syn["run"] = Team.run_effects(m)
	return syn


## «Підібрати / Auto-team»: the best (hero, champions) by Team.score for the deck's families
## (`threats` reserved for the level's threat preview): {hero, champions, gains [synergy ids]}.
func auto_team(threats: Array = []) -> Dictionary:
	level()
	var fams: Array = []
	for id in deck():
		var fam := str((ArsenalData.MACHINES.get(id, {}) as Dictionary).get("family", ""))
		if fam != "" and not fams.has(fam):
			fams.append(fam)
	var pick := Team.auto_pick(account, fams)
	pick["gains"] = (Team.synergy(Team.members(str(pick["hero"]), pick["champions"] as Array))["ids"] as Array).duplicate()
	pick["answers"] = []
	pick["threats"] = threats.duplicate()
	return pick


## The three team presets [{hero, champions}].
func team_presets() -> Array:
	return (Team.team(account).get("presets", []) as Array).duplicate(true)


func save_team_preset(i: int) -> bool:
	if not heroes_on() or not Team.save_preset(account, i):
		return false
	save()
	return true


func load_team_preset(i: int) -> bool:
	if not heroes_on():
		return false
	var res := _transact(func() -> Dictionary: return Team.use_preset(account, i, _now()))
	if not bool(res.get("ok", false)):
		return false
	(account["progress"] as Dictionary)["hero"] = Team.hero(account)
	Save.hero = Team.hero(account)
	save()
	team_changed.emit()
	return true


# ------------------------------------------------------------------ Portal (§7.1 - §7.4)

## Characters allowed in the Portal pool, chests and the Seal shop ([] = every one). Only `complete`
## characters enter (HeroArt.state, WS-E); until HeroArt exists every character is eligible.
func eligible() -> Array:
	return []


## Portal screen state: {open, beacons, beacon_charge, seals, total, e_left, l_left, focus {gem: id},
## pool {gem: [ids]}, welcome_ready, welcome_done}.
func portal() -> Dictionary:
	level()
	var st := Summon.state(account)
	var left := Summon.pity_left(account)
	var pools := {}
	var fo := {}
	for g in Ladder.GEMS:
		pools[g] = Summon.pool(account, g, eligible())
		var f := Summon.focus(account, g, eligible())
		if f != "":
			fo[g] = f
	var open := Summon.is_open(account)
	return {"open": open, "beacons": currency("beacons"),
			"beacon_charge": float((account["wallet"] as Dictionary).get("beacon_charge", 0.0)),
			"seals": int(st["seals"]), "total": int(st["total"]), "e_left": int(left["e"]), "l_left": int(left["l"]),
			"focus": fo, "pool": pools, "welcome_done": bool(st["welcome_done"]),
			"welcome_ready": open and not bool(st["welcome_done"])}


## Summons `count` heroes (1 or 10) for Beacons, or the free welcome ×10 (`welcome`). Rolls, grants,
## SAVES, then returns the bundle (the ceremony plays from it): Summon's result + {items [{kind,
## id, gem, new, frags, overflow_tomes, awakened}], best_gem, seals {before, after}, pity
## {e_left_before, e_left_after, l_left_before, l_left_after}, beacons_after, history_id}.
## {ok false, reason} changes nothing (locked | count | welcome | beacons | pool | phase | save).
func summon(count: int, welcome := false) -> Dictionary:
	if not heroes_on():
		return _phase_off({"count": count, "results": []})
	level()
	var src := "welcome" if welcome else "beacons"
	var seals0 := int(Summon.state(account)["seals"])
	var left0 := Summon.pity_left(account)
	var owned0 := Roster.owned_ids(account, Roster.KIND_HERO)
	var res := _transact(func() -> Dictionary: return Summon.summon(account, count, _rng, src, _now(), eligible()))
	if not bool(res.get("ok", false)):
		return res
	var left1 := Summon.pity_left(account)
	var items: Array = []
	for r in res["results"]:
		var rd: Dictionary = r
		items.append({"kind": "hero", "id": rd["id"], "gem": rd["gem"], "new": rd["new"], "frags": rd["frags"],
				"overflow_tomes": rd["tomes"], "awakened": rd["awakened"]})
	res["items"] = items
	res["best_gem"] = res["best"]
	res["seals"] = {"before": seals0, "after": int(Summon.state(account)["seals"])}
	res["pity"] = {"e_left_before": int(left0["e"]), "e_left_after": int(left1["e"]), "l_left_before": int(left0["l"]),
			"l_left_after": int(left1["l"])}
	res["beacons_after"] = currency("beacons")
	res["history_id"] = int(Summon.state(account)["total"])
	for id in Roster.owned_ids(account, Roster.KIND_HERO):
		if not owned0.has(id):
			unlocked.emit("hero", id)
			hero_changed.emit(id)
	summoned.emit(res)
	return res


## The free welcome ×10 («Серед десяти — щонайменше Топаз»).
func welcome_summon() -> Dictionary:
	return summon(PortalData.X10_SUMMONS, true)


## The Seal shop: [{id, gem, price, owned, frags, tomes, can}] (Amethyst 40 · Topaz 100 · Opal 200).
func seal_shop() -> Array[Dictionary]:
	level()
	var out := Summon.seal_offer(account, eligible())
	for o in out:
		o["can"] = heroes_on() and Summon.seal_block(account, str(o["id"]), eligible()) == ""
	return out


## Buys hero `id` with Seals (new hero, or 2 × its duplicate fragments): saved before it returns.
## {ok, reason, id, gem, price, new, frags, tomes, seals {before, after}}.
func seal_pick(id: String) -> Dictionary:
	if not heroes_on():
		return _phase_off({"id": id})
	level()
	var seals0 := int(Summon.state(account)["seals"])
	var res := _transact(func() -> Dictionary: return Summon.seal_pick(account, id, _now(), eligible()))
	if not bool(res.get("ok", false)):
		return res
	res["seals"] = {"before": seals0, "after": int(Summon.state(account)["seals"])}
	if bool(res["new"]):
		unlocked.emit("hero", id)
	hero_changed.emit(id)
	return res


## The (i) sheet (§7.2, KR item-level disclosure): {base, consolidated, x10_best {welcome, fresh,
## typical}, welcome_done, heroes {id: p} for the current pool, pity {e_hard, l_soft_from, l_step, l_hard,
## opal_share_in_l}, focus_total, e_left, l_left}.
func portal_odds() -> Dictionary:
	level()
	var left := Summon.pity_left(account)
	return {"base": PortalData.BASE_ODDS.duplicate(), "consolidated": Summon.consolidated(),
			"x10_best": {"welcome": Summon.welcome_odds(account), "fresh": PortalData.ODDS_X10_FRESH.duplicate(),
					"typical": Summon.x10_best_stationary()},
			"welcome_done": Summon.welcome_done(account),
			"heroes": Summon.hero_odds(account, eligible()),
			"pity": {"e_hard": int(PortalData.PITY_E["hard"]), "l_soft_from": int(PortalData.PITY_L["soft_from"]),
					"l_step": float(PortalData.PITY_L["step"]), "l_hard": int(PortalData.PITY_L["hard"]),
					"opal_share_in_l": PortalData.OPAL_SHARE_IN_L},
			"focus_total": PortalData.FOCUS_TOTAL, "e_left": int(left["e"]), "l_left": int(left["l"])}


## The Portal Focus of `gem` ("" none).
func portal_focus(gem: String) -> String:
	return Summon.focus(account, gem, eligible())


## Sets (or clears with "") the Portal Focus hero of `gem`. Free, any time.
func set_portal_focus(gem: String, id: String) -> bool:
	if not heroes_on() or not Summon.set_focus(account, gem, id, eligible()):
		return false
	save()
	return true


## The last summons (≤ 100), oldest first: [{g, id, t}].
func summon_history() -> Array:
	return ((account["summon"] as Dictionary).get("history", []) as Array).duplicate(true)


# ------------------------------------------------------------------ Hero Chests (§7.5)

## Hero Chests waiting in the Vault: [{type, source, level}].
func hero_chests() -> Array:
	return Vault.hero_chests(account)


## Opens the Vault Hero Chest at `index`: rolls, grants, SAVES, then returns the reveal ({} for a bad
## index; {ok false, reason} when it cannot open yet: it stays in the Vault).
func open_hero_chest(index := 0) -> Dictionary:
	if not heroes_on():
		return _phase_off()
	var hc := Vault.hero_chests(account)
	if index < 0 or index >= hc.size():
		return {}
	var c: Dictionary = (hc[index] as Dictionary).duplicate()
	var owned0 := Roster.owned_ids(account, Roster.KIND_CHAMPION)
	var fn := func() -> Dictionary:
		var r := Rewards.open_chest(account, c, _rng, _now(), false, eligible())
		if bool(r.get("ok", false)):
			Vault.take(account, index)
		return r
	var res := _transact(fn)
	if not bool(res.get("ok", false)):
		return res
	_after_chest(res, owned0)
	return res


func _after_chest(rev: Dictionary, owned0: Array[String]) -> void:
	for id in Roster.owned_ids(account, Roster.KIND_CHAMPION):
		if not owned0.has(id):
			unlocked.emit("champion", id)
	for cd in rev.get("cards", []):
		champion_changed.emit(str((cd as Dictionary).get("id", "")))
	if not (rev.get("new_ids", []) as Array).is_empty():
		team_changed.emit()
	chest_opened.emit(rev)


## The (i) sheet of a Hero Chest `type` (hero_chest | grand_hero_chest): {cards, per_card (CHEST_ODDS),
## best (exact, no pity), champions {id: p}, pity_hard, since_l, focus_total, hero_card_frags}.
func chest_odds(type: String) -> Dictionary:
	var kind := Vault.kind_of(type)
	if kind == "":
		return {}
	return {"type": type, "cards": int(PortalData.CHEST_CARDS[kind]), "per_card": PortalData.CHEST_ODDS.duplicate(),
			"best": HeroChest.exact_best(kind), "champions": HeroChest.champion_odds(account, eligible()),
			"pity_hard": PortalData.CHEST_PITY_L, "since_l": int((account["chests"] as Dictionary).get("since_l", 0)),
			"focus_total": PortalData.CHEST_FOCUS_TOTAL, "hero_card_frags": PortalData.CHEST_HERO_CARD_FRAGS.duplicate(),
			"hero_card_mult": int(PortalData.CHEST_HERO_FRAG_MULT[kind]), "team_hero_weight": PortalData.CHEST_TEAM_HERO_WEIGHT}


## Hero Chest charge (1/3 per qualifying win): {value 0..2, of 3}.
func chest_charge() -> Dictionary:
	return {"value": clampi(int(round(float((account["wallet"] as Dictionary).get("chest_charge", 0.0)) * 3.0)), 0, 3), "of": 3}


# ------------------------------------------------------------------ earned income outside runs

## A daily mission was completed: its Beacon share (live phase). {beacons}.
func hero_mission_done() -> Dictionary:
	return _income(func() -> Dictionary: return Rewards.hero_mission_done(account))


## Weekly 5/5: Beacons, a Grand Hero Chest into the Vault, Tomes (live phase).
func hero_weekly_done() -> Dictionary:
	return _income(func() -> Dictionary: return Rewards.hero_weekly_done(account))


## A weekly Expedition with `stars` of 5 (live phase).
func hero_expedition(stars: int) -> Dictionary:
	return _income(func() -> Dictionary: return Rewards.hero_expedition(account, stars))


## The login cycle card of `cycle_day` (1..7) (live phase).
func hero_login(cycle_day: int) -> Dictionary:
	return _income(func() -> Dictionary: return Rewards.hero_login(account, cycle_day))


func _income(fn: Callable) -> Dictionary:
	if not heroes_on():
		return {}
	level()
	var before := MetaAcc.wallet_snapshot(account)
	var n := Vault.hero_chests(account).size()
	var res: Dictionary = fn.call()
	_emit_wallet(before)
	if Vault.hero_chests(account).size() > n:
		cache_added.emit(Vault.GRAND)
	save()
	return res


# ------------------------------------------------------------------ run (live phase)

## The hero who leads the run of campaign level `lvl`: Мейра on her guest level (L5 while she is not
## owned and L5 is the frontier), else hero(). main.gd should start the run with this.
func run_hero(lvl: int) -> String:
	return "seer" if _guest_level(lvl) else hero()


## The run reads the v3 hero / team blocks: live phase, or a dev run from HEROES_RUN_PHASE (H2).
func _v3_run() -> bool:
	return heroes_on() or (EconData.heroes_run() and Save.readonly)


func _guest_level(lvl: int) -> bool:
	var g := EconData.seer_guest_level()
	return g > 0 and lvl == g and level() == g and not Roster.owned(account, "seer")


## Run-ready v3 hero block: the Meta-1 keys (HeroesMeta.profile) with the v3 numbers on top
## (HeroesMeta.run_block: ladder, Hero Sync level, skill ranks, form, Rally) + {kind, skills,
## gear (Workshop, WS-F: zeros until H4), guest}.
func _hero_block(id: String, guest := false) -> Dictionary:
	var acc := account
	if guest:
		# The guest plays her real kit at the guest level, owned by nobody: a scratch account.
		var st := EconData.new_hero_state(id, true, "guest")
		st["lvl"] = EconData.seer_guest_level()
		acc = {"heroes": {id: st}, "progress": account["progress"], "champions": account["champions"],
				"team": {"hero": id, "champions": []}, "unlocks": account["unlocks"], "wallet": {}, "counters": {}}
	var p := HeroesMeta.profile(acc, id)
	p.merge(HeroesMeta.run_block(acc, id), true)
	var sk := {}
	for s in HeroesMeta.SKILLS:
		sk[s] = HeroesMeta.skill_rank(acc, id, s)
	p["skills"] = sk
	p["kind"] = id
	p["gear"] = HeroesMeta.NO_GEAR.duplicate()
	p["guest"] = guest
	return p


## The run's team block: {hero, champions [{id, slot, ...ChampionsMeta.stats}], synergy (Team
## run effects of the full team; the run recounts LIVING members)}.
func _team_block(hero_id: String, guest := false) -> Dictionary:
	return team_block_of(account, hero_id, guest)


## _team_block for any account `acc` (dev tools on synthetic accounts: champ_survival, level checks).
static func team_block_of(acc: Dictionary, hero_id: String, guest := false) -> Dictionary:
	var champs: Array = [] if guest else Team.champions(acc)
	var used := {}
	var rows: Array = []
	for cid in champs:
		var st := ChampionsMeta.stats(acc, str(cid))
		var slot := str(st["slot"])
		if used.has(slot):
			for alt in ["front", "rear", "left", "right"]:
				if not used.has(alt):
					slot = alt
					break
		used[slot] = true
		st["slot"] = slot
		st["aura_effect"] = ChampionsMeta.aura_effect(float(st["aura"]), slot)
		rows.append(st)
	var m := Team.members(hero_id, champs)
	return {"hero": hero_id, "champions": rows, "synergy": Team.run_effects(m),
			"synergy_ids": (Team.synergy(m)["ids"] as Array).duplicate()}


# ======================================================================== barracks

func barracks_level(track: String) -> int:
	return Barracks.level(account, track)


func barracks_cap() -> int:
	level()
	return Barracks.cap(account)


func barracks_cost(track: String) -> int:
	return Barracks.cost(account, track)


func can_buy_barracks(track: String) -> bool:
	level()
	return Barracks.can_buy(account, track)


## Buys one level of `track`: {ok, track, lvl, value, coins}.
func buy_barracks(track: String) -> Dictionary:
	level()
	var before := MetaAcc.wallet_snapshot(account)
	var res := Barracks.buy(account, track)
	if not bool(res["ok"]):
		return res
	_emit_wallet(before)
	barracks_changed.emit(track)
	note("barracks", {"track": track, "lvl": res["lvl"]})
	save()
	return res


## Run-ready army block (§6.4 "army").
func army_profile() -> Dictionary:
	level()
	return Barracks.profile(account)


# ======================================================================== caches

## Caches waiting in the Vault: [{type, source, level}].
func vault() -> Array:
	return (account["vault"] as Dictionary)["caches"]


## Puts a Cache into the Vault.
func add_cache(type: String, source := "") -> void:
	if not EconData.CACHES.has(type):
		return
	(vault() as Array).append({"type": type, "source": source, "level": level()})
	cache_added.emit(type)
	save()


## Opens the Vault Cache at `index`: rolls, grants, SAVES, then returns the reveal bundle (§6.6;
## {} when the index is invalid). The UI animates the bundle afterwards.
func open_cache(index := 0) -> Dictionary:
	var v := vault()
	if index < 0 or index >= v.size():
		return {}
	var c: Dictionary = v[index]
	v.remove_at(index)
	return roll_cache(str(c["type"]), str(c.get("source", "")))


## Rolls and grants a Cache of `type` right away (§6.6), saves, then returns the reveal bundle.
func roll_cache(type: String, source := "") -> Dictionary:
	if not EconData.CACHES.has(type) or int((EconData.CACHES[type] as Dictionary).get("slots", 0)) <= 0:
		return {}
	level()
	var before := MetaAcc.wallet_snapshot(account)
	var owned_before := owned_ids()
	var rev := CacheRoller.open(account, type, source, _rng)
	_after_cards(rev.get("cards", []), owned_before)
	_emit_wallet(before)
	note("cache", {"type": type, "best": rev["best"], "source": source})
	save()
	return rev


## Machines a Cache card may hold: live machines whose home world is reached + forged Mythics.
func cache_pool() -> Array[String]:
	level()
	return CacheRoller.pool(account)


## The (i) odds screen for `type` and the CURRENT pool (§6.7).
func odds(type: String) -> Dictionary:
	return CacheRoller.odds(type, CacheRoller.present(cache_pool(), type), account["pity"])


## Caches until a guaranteed Legendary (the Altar bar), -1 while no Legendary is in the pool.
func pity_left() -> int:
	return CacheRoller.pity_left(CacheRoller.present(cache_pool(), "stone"), account["pity"])


## Signals for granted cards: machine_changed per machine, unlocked for new ones.
func _after_cards(cards: Array, owned_before: Array[String]) -> void:
	var done: Array[String] = []
	for c in cards:
		var id := str((c as Dictionary).get("id", ""))
		if id == "" or done.has(id):
			continue
		done.append(id)
		machine_changed.emit(id)
		if not owned_before.has(id) and owned(id):
			unlocked.emit("machine", id)


# ======================================================================== run

## Reinforcements stacks for the next attempt of `lvl` (-1 = the next level).
func assist_stacks(lvl := -1) -> int:
	return Rewards.assist_stacks(account, level() if lvl < 0 else lvl)


## Everything a run reads from the account, built once in Run.setup (§6.4). Issues the run's
## `run_id` (echo it in Run.result so finish_run books it exactly once).
func run_profile(lvl: int) -> Dictionary:
	level()
	var d := deck()
	var ld := lead()
	var machines := {}
	for id in d:
		var st: Dictionary = MetaAcc.machines(account).get(id, {})
		var e := stats(id, 1)
		var by_rank: Array = []
		for r in 3:
			by_rank.append(stats(id, r + 1)["stats"])
		e["by_rank"] = by_rank
		e["finish"] = int(st.get("finish", 0))
		e["lead"] = id == ld
		e["live"] = ArsenalData.is_live(id)
		machines[id] = e
	var owned_now := owned_ids()
	var nc := ArsenalData.new_crate_at(lvl)
	var carry := false
	if (nc == "" or owned_now.has(nc)) and ArsenalData.crate_events(lvl, ArsenalData.is_boss(lvl)) > 0:
		# A NEW machine passed up on an earlier level (its crate was in a pair, or never opened)
		# comes back as this level's first crate, so the scripted unlock is never lost.
		for back in range(lvl - 1, 0, -1):
			var miss := ArsenalData.new_crate_at(back)
			if miss != "" and ArsenalData.is_live(miss) and not owned_now.has(miss):
				nc = miss
				carry = true
				break
	var boss := ArsenalData.is_boss(lvl)
	var m: Dictionary = account["meta"]
	m["run_seq"] = int(m.get("run_seq", 0)) + 1
	_open_run_id = int(m["run_seq"])
	_open_guest = "seer" if heroes_on() and _guest_level(lvl) else ""
	var prof := {
		"level": lvl, "world": ArsenalData.world_of(lvl), "boss": boss,
		"profile": dev_profile if dev_profile != "" else "account", "run_id": _open_run_id,
		"deck": d, "lead": ld, "machines": machines, "owned": owned_now,
		"new_crate": nc if nc != "" and not owned_now.has(nc) else "",
		"new_carry": carry,
		"inrun": {"crates": ArsenalData.crate_events(lvl, boss), "rank_gates": ArsenalData.rank_gates(lvl),
				"pairs": ArsenalData.pairs_on(lvl), "crate_bonus": bool(ArsenalData.FEATURES["crate_bonus"])},
		"hero": hero_profile(hero()) if not _v3_run() else _hero_block(run_hero(lvl), _guest_level(lvl)),
		"army": army_profile(),
		"tactics": {"crate_bonus_mult": 1.0, "weak_point": 0.0, "streak_every": 0, "lead_add": 0.0, "ult_start": 0.0},
		"assist": EconData.assist(assist_stacks(lvl)),
		"haven_info": [], "codex": {}, "auto_apex": bool((account["settings"] as Dictionary).get("auto_apex", false)),
		"features": ArsenalData.FEATURES,
	}
	if _v3_run():
		prof["team"] = _team_block(run_hero(lvl), _guest_level(lvl))
		prof["guest"] = _open_guest
	return prof


## Books a finished run ONCE and returns the result bundle for the result / loss flow (§6.5).
## `result` = Run.result (+ won, level, pickups, bridge_fraction, fielded, new_unlock, crowns,
## shards, boss_core, stats, run_id). A repeated call for the same run returns
## {duplicate: true, ...} and credits nothing. Saves before returning (and before any reveal).
func finish_run(result: Dictionary) -> Dictionary:
	level()
	var res := result.duplicate(true)
	if int(res.get("run_id", 0)) <= 0 and _open_run_id > 0:
		res["run_id"] = _open_run_id
	if heroes_on() and _open_guest != "" and not res.has("guest") and int(res.get("run_id", _open_run_id)) == _open_run_id:
		res["guest"] = _open_guest
	if heroes_on():
		res["eligible"] = eligible()          # HeroArt gating for chests opened inline (review F6)
	if int(res.get("run_id", 0)) > 0 and int(res["run_id"]) == int(_last_bundle.get("run_id", -1)):
		var dup := _last_bundle.duplicate(true)
		dup["duplicate"] = true
		return dup
	var before := MetaAcc.wallet_snapshot(account)
	var owned_before := owned_ids()
	var lead_before := lead()
	var champs_before := Roster.owned_ids(account, Roster.KIND_CHAMPION)
	var bundle := Rewards.level_end(account, res, _rng, int(Time.get_unix_time_from_system()))
	if bool(bundle.get("duplicate", false)):
		return bundle
	_open_run_id = 0
	# Saved before any signal: every reveal a listener shows is already on disk (review F7). A failed
	# write keeps the result in memory (the 2.2.1 behaviour; the next save retries) instead of
	# taking back a win the player just watched.
	Save.level = level()
	save()
	_last_bundle = bundle
	_emit_wallet(before)
	for dr in bundle["drip"]:
		machine_changed.emit(str((dr as Dictionary)["id"]))
	if str(bundle["new_unlock"]) != "":
		machine_changed.emit(str(bundle["new_unlock"]))
		unlocked.emit("machine", str(bundle["new_unlock"]))
	for c in bundle["caches"]:
		var cd: Dictionary = c
		if bool(cd["inline"]):
			_after_cards((cd["reveal"] as Dictionary).get("cards", []), owned_before)
		else:
			cache_added.emit(str(cd["type"]))
	for u in bundle["unlocks"]:
		unlocked.emit(str((u as Dictionary)["kind"]), str((u as Dictionary)["id"]))
	for j in bundle.get("hero_joined", []):
		hero_changed.emit(str((j as Dictionary)["id"]))
		unlocked.emit("hero", str((j as Dictionary)["id"]))
	for hc in bundle.get("hero_chests", []):
		var hcd: Dictionary = hc
		if bool(hcd["inline"]):
			_after_chest(hcd["reveal"], champs_before)
		else:
			cache_added.emit(str(hcd["type"]))
	if lead() != lead_before:
		deck_changed.emit()
	run_finished.emit(bundle)
	return bundle


# ======================================================================== settings and telemetry

func setting(key: String, default: Variant = null) -> Variant:
	return (account["settings"] as Dictionary).get(key, default)


func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = account["settings"]
	s[key] = value
	if key == "caches_to_vault":
		s["caches_to_vault_set"] = true
	save()


## Local telemetry (never sent anywhere): one event row, capped at 400.
func note(event: String, data: Dictionary = {}) -> void:
	MetaTelemetry.note(account, event, data)


## The player skipped a ceremony (inline_reveal, altar, upgrade, walkout, result ...).
func note_skip(ceremony: String) -> void:
	MetaTelemetry.skip(account, ceremony)


## Debug export (7 taps on the version label): writes user://telemetry.json, returns the path.
func export_telemetry() -> String:
	return MetaTelemetry.EXPORT_PATH if MetaTelemetry.write_export(account) == OK else ""


func _session_resume() -> void:
	if account.is_empty() or Save.readonly:
		return
	var now := int(Time.get_unix_time_from_system())
	var m: Dictionary = account["meta"]
	var last_seen := int(m.get("last_session", 0))
	if UnlockQueue.on_session_start(account, now):
		var begin := int(m.get("session_begin", 0))
		if begin > 0 and last_seen >= begin:
			MetaTelemetry.session(account, last_seen - begin)
		m["session_begin"] = now
		note("session_start", {"n": m.get("sessions", 0)})


func _session_pause() -> void:
	if account.is_empty() or Save.readonly:
		return
	UnlockQueue.on_session_pause(account, int(Time.get_unix_time_from_system()))
	save()
