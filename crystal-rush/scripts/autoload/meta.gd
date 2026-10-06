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

const CURRENCIES: Array[String] = ["coins", "gems", "crowns", "cores"]

var account: Dictionary = {}
var dev_profile := ""                  ## "" = the real account; else fresh | expected | max
var dev_deck: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _syncing := false
var _open_run_id := 0                  ## run id issued by the last run_profile(), consumed by finish_run()
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
	var heroes: Dictionary = acc["heroes"]
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
	return acc


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


## The UI showed unlock `id` (tutorial line + first free step).
func ack_unlock(id: String) -> void:
	var before := MetaAcc.wallet_snapshot(account)
	var u := EconData.unlock_entry(id)
	UnlockQueue.ack(account, id)
	match str(u.get("free", "")):
		"recruits_lv1":
			barracks_changed.emit("recruits")
		"auto_deck":
			deck_changed.emit()
		"ballista_lv2":
			machine_changed.emit(str(MetaAcc.free_steps(account).get("machine", "ballista")))
		"hero_level":
			hero_changed.emit(hero())
	_emit_wallet(before)
	note("unlock_ack", {"id": id})
	save()


# ======================================================================== wallet

## Balance of `cur` (coins, gems, crowns, cores; wild_<R> also works).
func currency(cur: String) -> int:
	return MetaAcc.amount(account, cur)


## Wild Blueprints of rarity `r`.
func wild(r: String) -> int:
	return MetaAcc.amount(account, "wild_" + r)


## Adds (or with n < 0 removes, never below 0) currency. `source` feeds telemetry.
func add_currency(cur: String, n: int, source := "") -> void:
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

## The hero picked for the next run (Save.hero while the legacy menu exists).
func hero() -> String:
	return str(Save.hero) if Balance.HEROES.has(str(Save.hero)) else "bolt"


func set_hero(id: String) -> void:
	if hero_unlocked(id) and Balance.HEROES.has(id):
		(account["progress"] as Dictionary)["hero"] = id
		Save.set_hero(id)
		hero_changed.emit(id)
		save()


func hero_unlocked(id: String) -> bool:
	level()
	return HeroesMeta.unlocked(account, id, Save.readonly)


func hero_level(id: String) -> int:
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
	note("hero_level", {"id": id, "lvl": res["lvl"]})
	save()
	return res


## Run-ready hero block (§6.4 "hero").
func hero_profile(id: String) -> Dictionary:
	return HeroesMeta.profile(account, id)


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
	return {
		"level": lvl, "world": ArsenalData.world_of(lvl), "boss": boss,
		"profile": dev_profile if dev_profile != "" else "account", "run_id": _open_run_id,
		"deck": d, "lead": ld, "machines": machines, "owned": owned_now,
		"new_crate": nc if nc != "" and not owned_now.has(nc) else "",
		"new_carry": carry,
		"inrun": {"crates": ArsenalData.crate_events(lvl, boss), "rank_gates": ArsenalData.rank_gates(lvl),
				"pairs": ArsenalData.pairs_on(lvl), "crate_bonus": bool(ArsenalData.FEATURES["crate_bonus"])},
		"hero": hero_profile(hero()),
		"army": army_profile(),
		"tactics": {"crate_bonus_mult": 1.0, "weak_point": 0.0, "streak_every": 0, "lead_add": 0.0, "ult_start": 0.0},
		"assist": EconData.assist(assist_stacks(lvl)),
		"haven_info": [], "codex": {}, "auto_apex": bool((account["settings"] as Dictionary).get("auto_apex", false)),
		"features": ArsenalData.FEATURES,
	}


## Books a finished run ONCE and returns the result bundle for the result / loss flow (§6.5).
## `result` = Run.result (+ won, level, pickups, bridge_fraction, fielded, new_unlock, crowns,
## shards, boss_core, stats, run_id). A repeated call for the same run returns
## {duplicate: true, ...} and credits nothing. Saves before returning (and before any reveal).
func finish_run(result: Dictionary) -> Dictionary:
	level()
	var res := result.duplicate(true)
	if int(res.get("run_id", 0)) <= 0 and _open_run_id > 0:
		res["run_id"] = _open_run_id
	if int(res.get("run_id", 0)) > 0 and int(res["run_id"]) == int(_last_bundle.get("run_id", -1)):
		var dup := _last_bundle.duplicate(true)
		dup["duplicate"] = true
		return dup
	var before := MetaAcc.wallet_snapshot(account)
	var owned_before := owned_ids()
	var lead_before := lead()
	var bundle := Rewards.level_end(account, res, _rng, int(Time.get_unix_time_from_system()))
	if bool(bundle.get("duplicate", false)):
		return bundle
	_open_run_id = 0
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
	if lead() != lead_before:
		deck_changed.emit()
	Save.level = level()
	save()
	_last_bundle = bundle
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
