extends Node
## Meta: the account facade (arsenal_design.md §9.3). The hub, the result flow and the run talk
## to the account ONLY through this autoload; nothing outside scripts/meta/ and Save mutates the
## account dictionary directly.
##
## WS0 contract stubs: every public function below has its final signature and already works on
## an in-memory account (EconData.fresh_account() shape = Save v2 sections). WS1 replaces the
## bodies with scripts/meta/* (Arsenal, CacheRoller, Rewards, HeroesMeta, Barracks,
## UnlockQueue, Telemetry) and Save v2 persistence WITHOUT changing names, arguments, return
## shapes or signals. See scratchpad meta1_contracts.md for every shape.
##
## Persistence: when Save exposes `account: Dictionary` (Save v2, WS1) Meta works on that very
## dictionary and save() calls Save.save_data(). Until then the account lives in memory and the
## legacy Save fields (level, coins, hero) are kept in sync both ways.
## Dev runs (Save.readonly: --autotest / --shot) never persist; `--profile=fresh|expected|max`
## and `--deck=a,b,c` shape the synthetic account used by run_profile().

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


func _ready() -> void:
	load_account()
	if Save.has_signal("coins_changed"):
		Save.coins_changed.connect(_on_legacy_coins)


# ======================================================================== account lifecycle

## Loads (or builds) the account. Called once on start; WS1 calls it after a Save v2 load.
func load_account() -> void:
	var saved: Variant = Save.get("account")
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		account = saved
	else:
		account = EconData.fresh_account()
		_catch_up(maxi(1, int(Save.level)))
		(account["wallet"] as Dictionary)["coins"] = int(Save.coins)
		if saved is Dictionary:
			Save.set("account", account)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			dev_profile = a.trim_prefix("--profile=")
		elif a.begins_with("--deck="):
			dev_deck.clear()
			for id in a.trim_prefix("--deck=").split(",", false):
				if ArsenalData.MACHINES.has(id):
					dev_deck.append(id)
	if Save.readonly:
		_rng.seed = 1
		if dev_profile == "":
			dev_profile = "fresh"
		account = synthetic_account(maxi(1, int(Save.level)), dev_profile)
	else:
		var m: Dictionary = account["meta"]
		if int(m.get("rng_seed", 0)) == 0:
			m["rng_seed"] = randi() | 1
			_rng.seed = int(m["rng_seed"])
		else:
			_rng.seed = int(m["rng_seed"])
			if int(m.get("rng_state", 0)) != 0:
				_rng.state = int(m["rng_state"])


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
	account = EconData.fresh_account()
	account["settings"] = settings
	Save.level = 1
	_set_wallet("coins", 0)
	save()


## Synthetic account at campaign `level` for dev runs, level_check and the bot.
## kind: fresh (only what the NEW crates gave, rarity start levels), expected (approximation of
## the sim's regular player; WS1 replaces it with build/expected_profile.json), max (all Lv15).
static func synthetic_account(level: int, kind := "fresh") -> Dictionary:
	var acc := EconData.fresh_account()
	var prog: Dictionary = acc["progress"]
	prog["level"] = level
	prog["world_reached"] = ArsenalData.world_of(level)
	var ms: Dictionary = (acc["arsenal"] as Dictionary)["machines"]
	for id in ArsenalData.live_ids():
		var at := ArsenalData.new_crate_level(id)
		if kind == "max" or id in ArsenalData.START_OWNED or (at > 0 and at < level):
			ms[id] = EconData.new_machine_state(id, int(EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
	var w := ArsenalData.world_of(level)
	var heroes: Dictionary = acc["heroes"]
	match kind:
		"expected":
			# Design §6.4 regular player: deck Lv ~8 at L30, ~11.6 at L60; hero ~15.8 at L60.
			var lv := 1.0 + 7.0 * clampf(float(level - 3) / 27.0, 0.0, 1.0) + 3.6 * clampf(float(level - 30) / 30.0, 0.0, 1.0)
			for id: String in ms:
				var st: Dictionary = ms[id]
				st["lvl"] = clampi(int(round(lv)), int(st["lvl"]), ArsenalData.MAX_LEVEL)
				_auto_talents(id, st)
			for h: String in heroes:
				(heroes[h] as Dictionary)["lvl"] = clampi(int(round(1.0 + 14.8 * float(level) / 60.0)), 1, EconData.hero_cap(w))
			if level > 12:
				for t in EconData.BARRACKS_ORDER:
					(acc["barracks"] as Dictionary)[t] = mini(EconData.barracks_cap(w), (level - 12) / 4 + 1)
		"max":
			for id: String in ms:
				var st2: Dictionary = ms[id]
				st2["lvl"] = ArsenalData.MAX_LEVEL
				_auto_talents(id, st2)
			for h2: String in heroes:
				(heroes[h2] as Dictionary)["lvl"] = int(EconData.HERO["max"])
			for t2 in EconData.BARRACKS_ORDER:
				(acc["barracks"] as Dictionary)[t2] = EconData.BARRACKS_MAX
	(acc["unlocks"] as Dictionary)["done"] = []
	return acc


static func _auto_talents(id: String, st: Dictionary) -> void:
	var tal: Array = st["talents"]
	for tier in 3:
		var opts := ArsenalData.talent_options(id, tier)
		if int(st["lvl"]) >= ArsenalData.TALENT_LEVELS[tier] and not opts.is_empty():
			tal[tier] = str((opts[0] as Dictionary)["id"])


# ======================================================================== progress and unlocks

## Next campaign level to play (1-based).
func level() -> int:
	var p: Dictionary = account["progress"]
	if not Save.readonly and int(Save.level) > int(p.get("level", 1)):
		p["level"] = int(Save.level)      # the legacy router advanced it (until WS5 switches to finish_run)
	return maxi(int(p.get("level", 1)), 1)


func world_reached() -> int:
	return maxi(int((account["progress"] as Dictionary).get("world_reached", 1)), ArsenalData.world_of(level()))


## True once the design's unlock `id` is open (by level; phase-gated). Unknown ids are open.
func is_unlocked(id: String) -> bool:
	var u := EconData.unlock_entry(id)
	if u.is_empty():
		return true
	if int(u.get("phase", 1)) > ArsenalData.PHASE:
		return false
	if u.has("after_win"):
		return level() > int(u["after_win"])
	return level() >= int(u.get("from_level", 1))


## Open unlocks whose tutorial line has not been shown yet, oldest first, at most
## UNLOCK_RULES.per_session per session (UnlockQueue owns the session rule).
func pending_unlocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done: Array = (account["unlocks"] as Dictionary)["done"]
	for u: Dictionary in EconData.UNLOCKS:
		var id := str(u["id"])
		if is_unlocked(id) and not done.has(id) and str(u.get("line", "")) != "":
			out.append(u)
	var room := maxi(0, int(EconData.UNLOCK_RULES["per_session"]) - int((account["unlocks"] as Dictionary).get("session_count", 0)))
	return out.slice(0, room)


## The UI showed unlock `id` (tutorial line + first free step).
func ack_unlock(id: String) -> void:
	var un: Dictionary = account["unlocks"]
	if not (un["done"] as Array).has(id):
		(un["done"] as Array).append(id)
		un["session_count"] = int(un.get("session_count", 0)) + 1
		save()


# ======================================================================== wallet

## Balance of `cur` (coins, gems, crowns, cores).
func currency(cur: String) -> int:
	return int((account["wallet"] as Dictionary).get(cur, 0))


## Wild Blueprints of rarity `r`.
func wild(r: String) -> int:
	return int(((account["wallet"] as Dictionary)["wild"] as Dictionary).get(r, 0))


## Adds (or with n < 0 removes, never below 0) currency. `source` feeds telemetry.
func add_currency(cur: String, n: int, source := "") -> void:
	if cur.begins_with("wild_"):
		var r := cur.trim_prefix("wild_")
		var wd: Dictionary = (account["wallet"] as Dictionary)["wild"]
		wd[r] = maxi(0, int(wd.get(r, 0)) + n)
		wallet_changed.emit(cur, int(wd[r]))
	else:
		_set_wallet(cur, maxi(0, currency(cur) + n))
	if source != "":
		note("currency", {"cur": cur, "n": n, "source": source})


## Spends `n` of `cur` if affordable. Returns false (and changes nothing) otherwise.
func spend(cur: String, n: int) -> bool:
	if currency(cur) < n:
		return false
	_set_wallet(cur, currency(cur) - n)
	return true


func _set_wallet(cur: String, v: int) -> void:
	(account["wallet"] as Dictionary)[cur] = v
	if cur == "coins" and not _syncing:
		_syncing = true
		Save.coins = v
		Save.coins_changed.emit(v)
		_syncing = false
	wallet_changed.emit(cur, v)


func _on_legacy_coins(v: int) -> void:
	if _syncing:
		return
	(account["wallet"] as Dictionary)["coins"] = v
	wallet_changed.emit("coins", v)


# ======================================================================== arsenal

func owned(id: String) -> bool:
	return _machines().has(id)


## Ids of owned machines in roster order.
func owned_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ArsenalData.ORDER:
		if owned(id):
			out.append(id)
	return out


## Copy of the saved machine state ({} when not owned).
func machine_state(id: String) -> Dictionary:
	return (_machines().get(id, {}) as Dictionary).duplicate(true)


func machine_level(id: String) -> int:
	return int((_machines().get(id, {}) as Dictionary).get("lvl", 0))


## Final numbers for UI and Run: ArsenalData.machine_stats with this account's level, talents
## and branch (Lv1 for unowned machines, so locked cards can preview).
func stats(id: String, rank := 1) -> Dictionary:
	var st: Dictionary = _machines().get(id, {})
	var lvl := int(st.get("lvl", EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
	return ArsenalData.machine_stats(id, lvl, rank, st.get("talents", []), str(st.get("branch", "")))


## Price of the next level of `id`: {to_lvl, coins, bp_need, bp_have, wild_use, can, reason, beat}.
## reason: "" | max | locked | not_owned | coins | blueprints.
func upgrade_cost(id: String) -> Dictionary:
	var out := {"id": id, "to_lvl": 0, "coins": 0, "bp_need": 0, "bp_have": 0, "wild_use": 0, "can": false, "reason": "", "beat": ""}
	if not owned(id):
		out["reason"] = "not_owned"
		return out
	var st: Dictionary = _machines()[id]
	var nl := int(st["lvl"]) + 1
	if nl > ArsenalData.MAX_LEVEL:
		out["reason"] = "max"
		return out
	var r := ArsenalData.rarity_of(id)
	var need := EconData.bp_to(r, nl)
	var have := int(st["bp"])
	out["to_lvl"] = nl
	out["coins"] = EconData.coin_to(nl)
	out["bp_need"] = need
	out["bp_have"] = have
	out["wild_use"] = maxi(0, need - have)
	out["beat"] = beat_at(nl)
	if not is_unlocked("arsenal"):
		out["reason"] = "locked"
	elif have + wild(r) < need:
		out["reason"] = "blueprints"
	elif currency("coins") < int(out["coins"]):
		out["reason"] = "coins"
	else:
		out["can"] = true
	return out


func can_upgrade(id: String) -> bool:
	return bool(upgrade_cost(id)["can"])


## Buys the next level. Returns {ok, id, lvl, beat, coins, bp, wild} (ok false = nothing changed).
func upgrade(id: String) -> Dictionary:
	var c := upgrade_cost(id)
	if not bool(c["can"]):
		return {"ok": false, "id": id, "reason": c["reason"]}
	var st: Dictionary = _machines()[id]
	var r := ArsenalData.rarity_of(id)
	var from_bp := mini(int(st["bp"]), int(c["bp_need"]))
	st["bp"] = int(st["bp"]) - from_bp
	if int(c["wild_use"]) > 0:
		add_currency("wild_" + r, -int(c["wild_use"]))
	spend("coins", int(c["coins"]))
	st["lvl"] = int(c["to_lvl"])
	_count("upgrades_bought", 1)
	machine_changed.emit(id)
	save()
	return {"ok": true, "id": id, "lvl": int(st["lvl"]), "beat": c["beat"], "coins": c["coins"], "bp": from_bp, "wild": c["wild_use"]}


## The beat reached at machine level `lvl`: talent1 | lead | talent2 | ascension | talent3 |
## apex | prestige | mastered | "" (ceremony tier: beats = full, else standard).
static func beat_at(lvl: int) -> String:
	match lvl:
		3: return "talent1"
		5: return "lead"
		6: return "talent2"
		8: return "ascension"
		10: return "talent3"
		12: return "apex"
		13, 14: return "prestige"
		15: return "mastered"
	return ""


## Unlocks `id` (NEW crate, Cache card, migration). Arsenal Sync sets the start level.
## Returns true when it was new.
func unlock_machine(id: String, source := "") -> bool:
	if owned(id) or not ArsenalData.MACHINES.has(id):
		return false
	var levels: Array[int] = []
	for k: String in _machines():
		levels.append(int((_machines()[k] as Dictionary)["lvl"]))
	levels.sort()
	levels.reverse()
	var start := int(EconData.START_LEVEL[ArsenalData.rarity_of(id)])
	var lvl := start
	if levels.size() >= 3:
		lvl = maxi(start, mini(EconData.SYNC_CAP, levels[2] - EconData.SYNC_BEHIND))
	_machines()[id] = EconData.new_machine_state(id, lvl)
	note("unlock", {"id": id, "source": source})
	machine_changed.emit(id)
	unlocked.emit("machine", id)
	save()
	return true


## Picks Talent `talent_id` for tier 0/1/2 ("" clears; free respec). False if not allowed.
func set_talent(id: String, tier: int, talent_id: String) -> bool:
	if not owned(id) or tier < 0 or tier > 2:
		return false
	var st: Dictionary = _machines()[id]
	if talent_id != "":
		if int(st["lvl"]) < ArsenalData.TALENT_LEVELS[tier] or not _has_talent(id, tier, talent_id):
			return false
		if tier == 2 and not bool(ArsenalData.FEATURES["talent3"]):
			return false
	(st["talents"] as Array)[tier] = talent_id
	machine_changed.emit(id)
	save()
	return true


func _has_talent(id: String, tier: int, talent_id: String) -> bool:
	for t: Dictionary in ArsenalData.talent_options(id, tier):
		if str(t["id"]) == talent_id:
			return true
	return false


## Ascension branch "a"/"b" for Epic+ (free switch; Meta-2 feature flag "branches").
func set_branch(id: String, branch: String) -> bool:
	if not owned(id) or not bool(ArsenalData.FEATURES["branches"]) or not branch in ["a", "b"]:
		return false
	(_machines()[id] as Dictionary)["branch"] = branch
	machine_changed.emit(id)
	save()
	return true


## Focus machine (40% of Cache cards of its rarity). "" = default (the Lead).
func set_focus(id: String) -> void:
	(account["arsenal"] as Dictionary)["focus"] = id if owned(id) or id == "" else ""
	focus_changed.emit(focus())
	save()


func focus() -> String:
	var f := str((account["arsenal"] as Dictionary).get("focus", ""))
	return f if f != "" else lead()


## Deck slots open now (3 in Meta-1; +1 at World 3/4/5 later, max 6).
func deck_slots() -> int:
	var n := mini(6, 3 + maxi(0, world_reached() - 2))
	return mini(n, int(ArsenalData.FEATURES.get("deck_slots_max", 3)))


## The active deck (ids, slot 0 = Lead slot). Before the Deck unlock: automatic, all owned
## (max 5). Dev runs may force it with --deck=.
func deck() -> Array[String]:
	if not dev_deck.is_empty():
		return dev_deck.duplicate()
	if not is_unlocked("deck"):
		var all := _by_strength(owned_ids())
		return all.slice(0, 5)
	var ar: Dictionary = account["arsenal"]
	var d: Array = (ar["decks"] as Array)[int(ar.get("deck_active", 0))]
	var out: Array[String] = []
	for id in d:
		if owned(str(id)) and out.size() < deck_slots():
			out.append(str(id))
	return out if not out.is_empty() else auto_deck()


## The Lead (deck slot 1, Lv5+, after the Deck unlock), "" when none.
func lead() -> String:
	if not bool(ArsenalData.FEATURES["lead"]) or not is_unlocked("deck"):
		return ""
	var d := deck()
	if d.is_empty() or machine_level(d[0]) < ArsenalData.LEAD_LEVEL:
		return ""
	return d[0]


## Saves deck `ids` into the active preset. False if an id is unknown / unowned / too many.
func set_deck(ids: Array) -> bool:
	if ids.size() > deck_slots():
		return false
	var clean: Array[String] = []
	for id in ids:
		if not owned(str(id)) or clean.has(str(id)):
			return false
		clean.append(str(id))
	var ar: Dictionary = account["arsenal"]
	(ar["decks"] as Array)[int(ar.get("deck_active", 0))] = clean
	deck_changed.emit()
	save()
	return true


## Suggested deck for the next level: answers to `threats` (property ids) first, then the
## strongest owned machines (recipes join in Meta-2).
func auto_deck(threats: Array = []) -> Array[String]:
	var ids := _by_strength(owned_ids())
	var first: Array[String] = []
	for id in ids:
		for p in threats:
			if ArsenalData.PROPERTIES.has(p) and id in ((ArsenalData.PROPERTIES[p] as Dictionary)["answers"] as Array):
				if not first.has(id):
					first.append(id)
	for id2 in ids:
		if not first.has(id2):
			first.append(id2)
	return first.slice(0, deck_slots())


func _by_strength(ids: Array[String]) -> Array[String]:
	var out := ids.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool:
		var la := machine_level(a)
		var lb := machine_level(b)
		if la != lb:
			return la > lb
		return ArsenalData.rarity_index(ArsenalData.rarity_of(a)) > ArsenalData.rarity_index(ArsenalData.rarity_of(b)))
	return out


## Everything a machine card / detail screen needs (shape in meta1_contracts.md §UI data).
func machine_card(id: String) -> Dictionary:
	var m: Dictionary = ArsenalData.MACHINES[id]
	var r := str(m["rarity"])
	var own := owned(id)
	var st: Dictionary = _machines().get(id, {})
	var lvl := int(st.get("lvl", 0))
	var cost := upgrade_cost(id)
	var d := deck()
	var locked := ""
	if bool(m.get("meta2", false)):
		locked = "phase"
	elif not own:
		locked = "world"
	var best := best_upgrade()
	var badge := ""
	if own and bool(cost["can"]) and (d.has(id) or str(best.get("id", "")) == id):
		badge = "arrow"
	elif own and _talent_pending(id):
		badge = "!"
	var tal_opts: Array = []
	for tier in 3:
		tal_opts.append(ArsenalData.talent_options(id, tier))
	return {
		"id": id, "name": str(m["name"]), "desc": str(m["desc"]), "rarity": r, "family": str(m["family"]),
		"verb": str(m["verb"]), "shape": str(m.get("shape", "")), "home": int(m.get("home", 0)),
		"home_level": ArsenalData.new_crate_level(id), "owned": own, "locked": locked,
		"lvl": lvl, "max_lvl": ArsenalData.MAX_LEVEL, "bp": int(st.get("bp", 0)), "bp_need": int(cost["bp_need"]),
		"wild": wild(r), "coins_need": int(cost["coins"]), "can_upgrade": bool(cost["can"]), "reason": str(cost["reason"]),
		"next_beat": _next_beat(lvl), "in_deck": d.has(id), "is_lead": lead() == id, "is_focus": focus() == id,
		"badge": badge, "talents": (st.get("talents", ["", "", ""]) as Array).duplicate(), "talent_options": tal_opts,
		"branch": str(st.get("branch", "")), "finish": int(st.get("finish", 0)),
		"stats": stats(id), "accent": ArsenalData.accent(id), "rarity_color": (ArsenalData.RARITIES[r] as Dictionary)["ui_color"],
		"pips": int((ArsenalData.RARITIES[r] as Dictionary)["pips"]), "flags": (m.get("flags", {}) as Dictionary).duplicate(),
	}


## Cards for the grid. filter: all | owned | upgradable | <family id>.
func machine_cards(filter := "all") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ArsenalData.ORDER:
		var keep := true
		match filter:
			"owned": keep = owned(id)
			"upgradable": keep = can_upgrade(id)
			"all": keep = true
			_: keep = ArsenalData.family_of(id) == filter
		if keep:
			out.append(machine_card(id))
	return out


func _talent_pending(id: String) -> bool:
	if not is_unlocked("talents"):
		return false
	var st: Dictionary = _machines()[id]
	for tier in 2:
		if int(st["lvl"]) >= ArsenalData.TALENT_LEVELS[tier] and str((st["talents"] as Array)[tier]) == "":
			return true
	return false


## Next beat after `lvl`: {lvl, beat} ({} at max).
static func _next_beat(lvl: int) -> Dictionary:
	for l in range(lvl + 1, ArsenalData.MAX_LEVEL + 1):
		if beat_at(l) != "":
			return {"lvl": l, "beat": beat_at(l)}
	return {}


## The pre-selected "Best upgrade" (the sim's greedy value function): {kind, id, cost, label}
## kind: machine | hero | barracks; {} when nothing is affordable.
func best_upgrade() -> Dictionary:
	var best := {}
	var best_v := -1.0
	var top := deck().slice(0, 3)
	for id in owned_ids():
		var c := upgrade_cost(id)
		if not bool(c["can"]):
			continue
		var share := 0.5 / 3.0 if top.has(id) else 0.5 * 0.2 / 3.0
		var v := 1.3 * share * ArsenalData.PER_LEVEL / float(maxi(int(c["coins"]), 1))
		if v > best_v:
			best_v = v
			best = {"kind": "machine", "id": id, "cost": int(c["coins"]), "label": str((ArsenalData.MACHINES[id] as Dictionary)["name"]), "to_lvl": c["to_lvl"]}
	var h := hero()
	if can_level_hero(h):
		var v2 := 0.25 * float(EconData.HERO["dmg_per_lvl"]) / float(maxi(hero_cost(h), 1))
		if v2 > best_v:
			best_v = v2
			best = {"kind": "hero", "id": h, "cost": hero_cost(h), "label": str((Balance.HEROES[h] as Dictionary)["name"]), "to_lvl": hero_level(h) + 1}
	const BAR_W := {"recruits": 0.015, "reserves": 0.010, "scrape_guard": 0.010, "drill": 0.012, "volleys": 0.012}
	for t in EconData.BARRACKS_ORDER:
		if can_buy_barracks(t):
			var v3 := 0.25 * float(BAR_W[t]) / float(maxi(barracks_cost(t), 1))
			if v3 > best_v:
				best_v = v3
				best = {"kind": "barracks", "id": t, "cost": barracks_cost(t), "label": str((EconData.BARRACKS[t] as Dictionary)["name"]), "to_lvl": barracks_level(t) + 1}
	return best


## Arsenal header milestone: the nearest beat among Deck machines {id, lvl, beat, levels_left}.
func next_milestone() -> Dictionary:
	var best := {}
	for id in deck():
		var nb := _next_beat(machine_level(id))
		if nb.is_empty():
			continue
		var left := int(nb["lvl"]) - machine_level(id)
		if best.is_empty() or left < int(best["levels_left"]):
			best = {"id": id, "lvl": nb["lvl"], "beat": nb["beat"], "levels_left": left}
	return best


## Coins / blueprints left to max every owned live machine: {coins, share_done}.
func remaining_cost() -> Dictionary:
	var left := 0
	var total := 0
	for id in ArsenalData.live_ids():
		var r := ArsenalData.rarity_of(id)
		for l in range(int(EconData.START_LEVEL[r]) + 1, ArsenalData.MAX_LEVEL + 1):
			total += EconData.coin_to(l)
			if l > machine_level(id):
				left += EconData.coin_to(l)
	return {"coins": left, "share_done": 1.0 - float(left) / float(maxi(total, 1))}


## Arsenal Rating (no damage; drives the Track in Meta-3).
func rating() -> int:
	var n := 0
	for id in owned_ids():
		var l := machine_level(id)
		n += l * int(EconData.RATING["per_level"])
		if l >= ArsenalData.ASCENSION_LEVEL:
			n += int(EconData.RATING["ascension"])
	return n


func _machines() -> Dictionary:
	return (account["arsenal"] as Dictionary)["machines"]


# ======================================================================== heroes

## The hero picked for the next run (Save.hero while the legacy menu exists).
func hero() -> String:
	return str(Save.hero) if Balance.HEROES.has(str(Save.hero)) else "bolt"


func set_hero(id: String) -> void:
	if hero_unlocked(id):
		Save.set_hero(id)
		hero_changed.emit(id)


func hero_unlocked(id: String) -> bool:
	var at := int(EconData.HERO_UNLOCK.get(id, -1))
	return at == 0 or (at > 0 and level() > at) or (Save.readonly and at >= 0)


func hero_level(id: String) -> int:
	return int(((account["heroes"] as Dictionary).get(id, {}) as Dictionary).get("lvl", 1))


func hero_cap() -> int:
	return EconData.hero_cap(world_reached())


## Coins for the next level of hero `id`.
func hero_cost(id: String) -> int:
	return EconData.hero_cost(hero_level(id))


func can_level_hero(id: String) -> bool:
	return is_unlocked("heroes") and hero_unlocked(id) and hero_level(id) < hero_cap() and currency("coins") >= hero_cost(id)


## Buys a hero level: {ok, id, lvl, milestone ("" | ult_rank | awakening), coins}.
func level_hero(id: String) -> Dictionary:
	if not can_level_hero(id):
		return {"ok": false, "id": id}
	var c := hero_cost(id)
	spend("coins", c)
	var hs: Dictionary = account["heroes"]
	if not hs.has(id):
		hs[id] = {"lvl": 1, "glory": 1, "boss_wins": 0, "aspect": "", "skin": ""}
	var h: Dictionary = hs[id]
	h["lvl"] = int(h["lvl"]) + 1
	var ms := ""
	if int(h["lvl"]) in (EconData.HERO["ult_rank_at"] as Array):
		ms = "ult_rank"
	elif int(h["lvl"]) in (EconData.HERO["awakening_at"] as Array):
		ms = "awakening"
	_count("upgrades_bought", 1)
	hero_changed.emit(id)
	save()
	return {"ok": true, "id": id, "lvl": int(h["lvl"]), "milestone": ms, "coins": c}


## Run-ready hero block (§9.4 "hero").
func hero_profile(id: String) -> Dictionary:
	var lvl := hero_level(id)
	var h: Dictionary = (account["heroes"] as Dictionary).get(id, {})
	var mults := EconData.hero_mults(lvl)
	return {"id": id, "lvl": lvl, "aspect": str(h.get("aspect", "")), "glory": int(h.get("glory", 1)),
			"ult_rank": int(mults["ult_rank"]), "dmg_mult": float(mults["dmg_mult"]), "hp_mult": float(mults["hp_mult"]),
			"ult_rate_mult": float(mults["ult_rate_mult"])}


# ======================================================================== barracks

func barracks_level(track: String) -> int:
	return int((account["barracks"] as Dictionary).get(track, 0))


func barracks_cap() -> int:
	return EconData.barracks_cap(world_reached())


func barracks_cost(track: String) -> int:
	return EconData.barracks_cost(barracks_level(track) + 1)


func can_buy_barracks(track: String) -> bool:
	return is_unlocked("barracks") and EconData.BARRACKS.has(track) and barracks_level(track) < barracks_cap() \
			and currency("coins") >= barracks_cost(track)


## Buys one level of `track`: {ok, track, lvl, value, coins}.
func buy_barracks(track: String) -> Dictionary:
	if not can_buy_barracks(track):
		return {"ok": false, "track": track}
	var c := barracks_cost(track)
	spend("coins", c)
	var b: Dictionary = account["barracks"]
	b[track] = barracks_level(track) + 1
	_count("upgrades_bought", 1)
	barracks_changed.emit(track)
	save()
	return {"ok": true, "track": track, "lvl": int(b[track]), "value": EconData.barracks_value(track, int(b[track])), "coins": c}


## Run-ready army block (§9.4 "army").
func army_profile() -> Dictionary:
	return {
		"recruit_bonus": int(EconData.barracks_value("recruits", barracks_level("recruits"))),
		"reserves": int(EconData.barracks_value("reserves", barracks_level("reserves"))),
		"scrape_guard": int(EconData.barracks_value("scrape_guard", barracks_level("scrape_guard"))),
		"drill": EconData.barracks_value("drill", barracks_level("drill")),
		"volley_mult": 1.0 + EconData.barracks_value("volleys", barracks_level("volleys")),
		"max_tier": _max_army_tier(),
		"glory_reserves": 0,
	}


func _max_army_tier() -> int:
	var t := 0
	for i in ArsenalData.ARMY_TIERS.size():
		var tier: Dictionary = ArsenalData.ARMY_TIERS[i]
		if bool(tier.get("meta2", false)) and not bool(ArsenalData.FEATURES["army_tiers_t3"]):
			continue
		if world_reached() >= int(tier["unlock_world"]):
			t = i
	return t


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


## Opens the Vault Cache at `index`: rolls, grants, SAVES, then returns the reveal bundle
## ({} when the index is invalid). The UI animates the bundle afterwards.
func open_cache(index := 0) -> Dictionary:
	var v := vault()
	if index < 0 or index >= v.size():
		return {}
	var c: Dictionary = v[index]
	v.remove_at(index)
	return roll_cache(str(c["type"]), str(c.get("source", "")))


## Rolls and grants a Cache of `type` right away (inline Stone reveal on the result screen).
## STUB of CacheRoller.roll + grant (WS1 moves it to scripts/meta/cache_roller.gd).
func roll_cache(type: String, source := "") -> Dictionary:
	var g: Dictionary = EconData.CACHES[type]
	var pool := cache_pool()
	var present := _present(pool, type)
	var pity: Dictionary = account["pity"]
	var pity_before := pity.duplicate()
	var rars: Array[String] = []
	var slots := int(g["slots"])
	for i in slots - 1:
		rars.append(_draw(_slot_weights(present, type, "")))
	var gmin := _guaranteed_min(type, present)
	var e_in := present.has("E")
	var l_in := present.has("L")
	if e_in and int(pity["since_epic"]) + 1 >= int(EconData.PITY["epic"]) and ArsenalData.rarity_index(gmin) < 2:
		gmin = "E"
	var w := _slot_weights(present, type, gmin)
	if l_in:
		var n := int(pity["since_leg"]) + 1
		if not bool(pity["leg_welcome_done"]) or n >= int(EconData.PITY["leg_hard"]):
			w = {"L": 1.0}
		elif n >= int(EconData.PITY["leg_soft"]):
			var target := minf(1.0, float(EconData.PITY["leg_soft_step"]) * float(n - int(EconData.PITY["leg_soft"]) + 1))
			var tot := 0.0
			for r: String in w:
				tot += float(w[r])
			if float(w.get("L", 0.0)) / tot < target:
				var rest := tot - float(w.get("L", 0.0))
				for r2: String in w.keys():
					w[r2] = target if r2 == "L" else float(w[r2]) / rest * (1.0 - target)
	rars.append(_draw(w))
	var best := "C"
	for r3 in rars:
		if ArsenalData.rarity_index(r3) > ArsenalData.rarity_index(best):
			best = r3
	if e_in:
		pity["since_epic"] = 0 if ArsenalData.rarity_index(best) >= 2 else int(pity["since_epic"]) + 1
	if l_in:
		pity["since_leg"] = 0 if ArsenalData.rarity_index(best) >= 3 else int(pity["since_leg"]) + 1
		pity["leg_welcome_done"] = true
	var cards: Array[Dictionary] = []
	for i2 in rars.size():
		var card := _grant_card(rars[i2], pool, _rng.randf() < EconData.WILD_CARD_CHANCE)
		card["guaranteed"] = i2 == rars.size() - 1
		cards.append(card)
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ArsenalData.rarity_index(str(a["rarity"])) < ArsenalData.rarity_index(str(b["rarity"])))
	var coins := EconData.cache_coins(type, level())
	add_currency("coins", coins)
	if type == "stone":
		var vd: Dictionary = account["vault"]
		vd["stone_total"] = int(vd.get("stone_total", 0)) + 1
	_count("caches_opened", 1)
	note("cache", {"type": type, "best": best, "source": source})
	save()
	return {"type": type, "source": source, "best": best, "cards": cards, "coins": coins,
			"pity_before": pity_before, "pity_after": pity.duplicate(), "pity_left": pity_left(),
			"altar": bool(g.get("altar", false))}


## Machines a Cache card may hold: live machines whose home world is reached + forged Mythics.
func cache_pool() -> Array[String]:
	var out: Array[String] = []
	for id in ArsenalData.ORDER:
		var m: Dictionary = ArsenalData.MACHINES[id]
		if not ArsenalData.is_live(id):
			continue
		if str(m["rarity"]) == "M":
			if owned(id):
				out.append(id)
		elif int(m["home"]) >= 1 and int(m["home"]) <= world_reached():
			out.append(id)
	return out


## The (i) odds screen for `type` and the CURRENT pool: {present, per_card, guaranteed, best,
## pity_left, stack, wild, focus, deck}; probabilities 0..1 per rarity, no pity active.
func odds(type: String) -> Dictionary:
	var present := _present(cache_pool(), type)
	var g: Dictionary = EconData.CACHES[type]
	var free := _norm(_slot_weights(present, type, ""))
	var guar := _norm(_slot_weights(present, type, _guaranteed_min(type, present)))
	var best := {}
	var prev := 0.0
	var cf := 0.0
	var cg := 0.0
	for r in ArsenalData.RARITY_ORDER:
		cf += float(free.get(r, 0.0))
		cg += float(guar.get(r, 0.0))
		var F := pow(cf, float(int(g["slots"]) - 1)) * cg
		best[r] = maxf(F - prev, 0.0)
		prev = F
	return {"type": type, "present": present, "per_card": free, "guaranteed": guar, "best": best,
			"pity_left": pity_left(), "stack": EconData.STACK, "wild": EconData.WILD_CARD_CHANCE,
			"focus": EconData.FOCUS_SHARE, "deck": EconData.DECK_WEIGHT}


## Caches until a guaranteed Legendary (the Altar bar), -1 while no Legendary is in the pool.
func pity_left() -> int:
	if not _present(cache_pool(), "stone").has("L"):
		return -1
	var p: Dictionary = account["pity"]
	if not bool(p["leg_welcome_done"]):
		return 1
	return maxi(1, int(EconData.PITY["leg_hard"]) - int(p["since_leg"]))


func _present(pool: Array[String], type: String) -> Array[String]:
	var out: Array[String] = []
	for id in pool:
		var r := ArsenalData.rarity_of(id)
		if r == "M" and not bool((EconData.CACHES[type] as Dictionary).get("mythic", false)):
			continue
		if not out.has(r):
			out.append(r)
	return out


func _guaranteed_min(type: String, present: Array[String]) -> String:
	var want := str((EconData.CACHES[type] as Dictionary).get("guaranteed", "C"))
	var best := "C"
	for r in present:
		if r != "M" and ArsenalData.rarity_index(r) > ArsenalData.rarity_index(best):
			best = r
	return want if ArsenalData.rarity_index(want) <= ArsenalData.rarity_index(best) else best


func _slot_weights(present: Array[String], type: String, min_r: String) -> Dictionary:
	var w := {}
	var lw := float((EconData.CACHES[type] as Dictionary).get("leg_weight", 1.0))
	for r in ArsenalData.RARITY_ORDER:
		if not present.has(r):
			continue
		if min_r != "" and ArsenalData.rarity_index(r) < ArsenalData.rarity_index(min_r):
			continue
		w[r] = float(EconData.CARD_ODDS[r]) * (lw if r == "L" else 1.0)
	return w


static func _norm(w: Dictionary) -> Dictionary:
	var tot := 0.0
	for r: String in w:
		tot += float(w[r])
	var out := {}
	for r2: String in w:
		out[r2] = float(w[r2]) / maxf(tot, 1e-9)
	return out


func _draw(w: Dictionary) -> String:
	var tot := 0.0
	for r: String in w:
		tot += float(w[r])
	var x := _rng.randf() * tot
	var last := "C"
	for r2: String in w:
		x -= float(w[r2])
		last = r2
		if x <= 0.0:
			return r2
	return last


## Grants one card of rarity `r` and returns its reveal entry (shape in meta1_contracts.md).
func _grant_card(r: String, pool: Array[String], is_wild: bool) -> Dictionary:
	if is_wild:
		add_currency("wild_" + r, 1)
		return {"rarity": r, "id": "", "count": 1, "wild": true, "new": false}
	var cands: Array[String] = []
	for id in pool:
		if ArsenalData.rarity_of(id) == r:
			cands.append(id)
	if cands.is_empty():
		return {"rarity": r, "id": "", "count": 0, "wild": false, "new": false}
	var unowned: Array[String] = []
	for id2 in cands:
		if not owned(id2):
			unowned.append(id2)
	var mid := ""
	if r in ["L", "M"] and not unowned.is_empty():
		mid = unowned[_rng.randi_range(0, unowned.size() - 1)]
	else:
		var f := focus()
		var d := deck()
		if f != "" and cands.has(f) and _rng.randf() < EconData.FOCUS_SHARE:
			mid = f
		else:
			var w := {}
			for id3 in cands:
				w[id3] = EconData.DECK_WEIGHT if d.has(id3) else 1.0
			mid = _draw(w)
	var st_range: Array = EconData.STACK[r]
	var n := _rng.randi_range(int(st_range[0]), int(st_range[1]))
	var is_new := false
	if not owned(mid):
		unlock_machine(mid, "cache")
		is_new = true
		n -= 1
	var st: Dictionary = _machines()[mid]
	var before := int(st["bp"])
	if int(st["lvl"]) >= ArsenalData.MAX_LEVEL:
		add_currency("wild_" + r, maxi(n, 0))
	else:
		st["bp"] = before + maxi(n, 0)
		machine_changed.emit(mid)
	if r == "L":
		_count("legendary_cards", 1)
	var need := EconData.bp_to(r, int(st["lvl"]) + 1)
	return {"rarity": r, "id": mid, "count": maxi(n, 0) + (1 if is_new else 0), "wild": false, "new": is_new,
			"lvl": int(st["lvl"]), "bp_before": before, "bp_after": int(st["bp"]), "bp_need": need,
			"upgradable": can_upgrade(mid)}


# ======================================================================== run

## Reinforcements stacks for the next attempt of `lvl` (-1 = the next level).
func assist_stacks(lvl := -1) -> int:
	if not bool((account["settings"] as Dictionary).get("reinforcements", true)):
		return 0
	var p: Dictionary = account["progress"]
	var l := level() if lvl < 0 else lvl
	if int(p.get("assist_level", 0)) != l:
		return 0
	return mini(int(p.get("losses_here", 0)), int(EconData.RETRY_ASSIST["cap"]))


## Everything a run reads from the account, built once in Run.setup (§9.4 shape + Meta-1 keys).
func run_profile(lvl: int) -> Dictionary:
	var d := deck()
	var ld := lead()
	var machines := {}
	for id in d:
		var st: Dictionary = _machines().get(id, {})
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
	var boss := ArsenalData.is_boss(lvl)
	return {
		"level": lvl, "world": ArsenalData.world_of(lvl), "boss": boss,
		"profile": dev_profile if dev_profile != "" else "account",
		"deck": d, "lead": ld, "machines": machines, "owned": owned_now,
		"new_crate": nc if nc != "" and not owned_now.has(nc) else "",
		"inrun": {"crates": ArsenalData.crate_events(lvl, boss), "rank_gates": ArsenalData.rank_gates(lvl),
				"pairs": ArsenalData.pairs_on(lvl), "crate_bonus": bool(ArsenalData.FEATURES["crate_bonus"])},
		"hero": hero_profile(hero()),
		"army": army_profile(),
		"tactics": {"crate_bonus_mult": 1.0, "weak_point": 0.0, "streak_every": 0, "lead_add": 0.0, "ult_start": 0.0},
		"assist": EconData.assist(assist_stacks(lvl)),
		"haven_info": [], "codex": {}, "auto_apex": bool((account["settings"] as Dictionary).get("auto_apex", false)),
		"features": ArsenalData.FEATURES,
	}


## Books a finished run and returns the result bundle for the result / loss flow (shape in
## meta1_contracts.md). STUB of Rewards.level_end: coins, level advance, Caches (inline Stone
## or Vault), loss charge, drip, NEW unlock, Reinforcements, unlocks, counters, telemetry.
## `result` = Run.result (+ won, level, pickups, bridge_fraction, fielded, new_unlock, stats).
func finish_run(result: Dictionary) -> Dictionary:
	var lvl := int(result.get("level", level()))
	var won := bool(result.get("won", int(result.get("victory", 0)) > 0))
	var replay := lvl < level()
	var pickups := int(result.get("pickups", result.get("coins_run", 0)))
	var p: Dictionary = account["progress"]
	var bundle := {"won": won, "level": lvl, "replay": replay, "caches": [], "drip": [], "unlocks": [],
			"new_unlock": "", "walkout": false}
	# Coins.
	var coins := 0
	if won:
		var victory := int(result.get("victory", EconData.victory_coins(lvl, int(result.get("survivors", 0)))))
		var mult := float(result.get("mult", 1.0))
		coins = int(result["total"]) if result.has("total") and not replay else EconData.win_coins(victory, pickups, mult, replay)
		bundle["coins"] = {"victory": victory, "pickups": pickups, "stairs_mult": mult, "total": coins}
	else:
		var frac := float(result.get("bridge_fraction", 0.5))
		coins = EconData.loss_coins(lvl, pickups, frac)
		bundle["coins"] = {"victory": 0, "pickups": pickups, "bridge_fraction": frac, "total": coins}
	add_currency("coins", coins, "run")
	# NEW machine (kept even on a loss).
	var nu := str(result.get("new_unlock", ""))
	if nu != "" and unlock_machine(nu, "crate"):
		bundle["new_unlock"] = nu
		bundle["walkout"] = not ((account["arsenal"] as Dictionary)["seen"] as Dictionary).has(nu)
		((account["arsenal"] as Dictionary)["seen"] as Dictionary)[nu] = true
	# Caches.
	var cache := ""
	if won and not replay:
		cache = EconData.win_cache(lvl)
	elif not won:
		var w: Dictionary = account["wallet"]
		w["cache_charge"] = float(w.get("cache_charge", 0.0)) + EconData.LOSS_CACHE_CHARGE
		bundle["cache_charge"] = {"value": int(round(float(w["cache_charge"]) * 3.0)), "of": 3}
		if float(w["cache_charge"]) >= 0.999 and lvl >= EconData.CACHE_FROM_LEVEL:
			w["cache_charge"] = 0.0
			cache = "stone"
	if cache != "":
		var to_vault := cache != "stone" or bool((account["settings"] as Dictionary).get("caches_to_vault", false))
		if to_vault:
			add_cache(cache, "win" if won else "loss")
			(bundle["caches"] as Array).append({"type": cache, "inline": false, "reveal": {}})
		else:
			(bundle["caches"] as Array).append({"type": cache, "inline": true, "reveal": roll_cache(cache, "win" if won else "loss")})
	# Drip into fielded machines.
	for f: Dictionary in result.get("fielded", []):
		var id := str(f.get("id", ""))
		if not owned(id):
			continue
		var st: Dictionary = _machines()[id]
		var r := ArsenalData.rarity_of(id)
		var add := float(EconData.DRIP[r]) * (EconData.DRIP_RANK3 if int(f.get("rank", 1)) >= 3 else 1.0) * (1.0 if won else EconData.DRIP_LOSS)
		var before := int(st["bp"])
		st["frac"] = float(st.get("frac", 0.0)) + add
		var whole := int(floor(float(st["frac"])))
		st["frac"] = float(st["frac"]) - whole
		if int(st["lvl"]) >= ArsenalData.MAX_LEVEL:
			add_currency("wild_" + r, whole)
		else:
			st["bp"] = before + whole
		(bundle["drip"] as Array).append({"id": id, "add": add, "bp_before": before, "bp_after": int(st["bp"]),
				"frac": float(st["frac"]), "bp_need": EconData.bp_to(r, int(st["lvl"]) + 1)})
		machine_changed.emit(id)
	# Progress, Reinforcements, unlocks.
	var before_level := level()
	if won:
		p["losses_here"] = 0
		if not replay:
			p["level"] = lvl + 1
			p["world_reached"] = maxi(int(p.get("world_reached", 1)), ArsenalData.world_of(lvl + 1))
			if ArsenalData.is_boss(lvl):
				p["boss_wins"] = int(p.get("boss_wins", 0)) + 1
	else:
		if int(p.get("assist_level", 0)) != lvl:
			p["losses_here"] = 0
		p["assist_level"] = lvl
		p["losses_here"] = mini(int(p.get("losses_here", 0)) + 1, int(EconData.RETRY_ASSIST["cap"]))
	if won:
		p["assist_level"] = 0
	bundle["assist"] = EconData.assist(assist_stacks(lvl))
	for u: Dictionary in EconData.UNLOCKS:
		if int(u.get("phase", 1)) > ArsenalData.PHASE:
			continue
		var opened := (u.has("after_win") and before_level <= int(u["after_win"]) and level() > int(u["after_win"])) \
				or (u.has("from_level") and before_level < int(u["from_level"]) and level() >= int(u["from_level"]))
		if opened:
			(bundle["unlocks"] as Array).append({"id": u["id"], "kind": u["kind"], "line": u.get("line", ""), "free": u.get("free", "")})
			unlocked.emit(str(u["kind"]), str(u["id"]))
	# Counters and telemetry.
	_count("wins" if won else "losses", 1)
	for k: String in (result.get("stats", {}) as Dictionary):
		_count(k, result["stats"][k])
	var tl: Dictionary = (account["telemetry"] as Dictionary)["levels"]
	var row: Dictionary = tl.get(str(lvl), {"attempts": 0, "wins": 0})
	row["attempts"] = int(row["attempts"]) + 1
	row["wins"] = int(row["wins"]) + (1 if won else 0)
	tl[str(lvl)] = row
	bundle["best_upgrade"] = best_upgrade()
	bundle["coins_balance"] = currency("coins")
	save()
	run_finished.emit(bundle)
	return bundle


# ======================================================================== settings and telemetry

func setting(key: String, default: Variant = null) -> Variant:
	return (account["settings"] as Dictionary).get(key, default)


func set_setting(key: String, value: Variant) -> void:
	(account["settings"] as Dictionary)[key] = value
	save()


## Local telemetry (never sent anywhere): one event row, capped.
func note(event: String, data: Dictionary = {}) -> void:
	var ev: Array = (account["telemetry"] as Dictionary)["events"]
	ev.append({"e": event, "t": Time.get_unix_time_from_system(), "d": data})
	if ev.size() > 400:
		ev.remove_at(0)


## Sums `v` (int, float or nested dictionary) into [counters] under `key`.
func _count(key: String, v: Variant) -> void:
	var c: Dictionary = account["counters"]
	_sum_into(c, key, v)


static func _sum_into(d: Dictionary, key: String, v: Variant) -> void:
	if v is Dictionary:
		if not d.get(key) is Dictionary:
			d[key] = {}
		for k: String in (v as Dictionary):
			_sum_into(d[key], k, v[k])
	elif v is int or v is float:
		d[key] = d.get(key, 0) + v


## Migration-lite for a legacy (v1) progress level: grants the NEW machines behind the player.
func _catch_up(lvl: int) -> void:
	(account["progress"] as Dictionary)["level"] = lvl
	(account["progress"] as Dictionary)["world_reached"] = ArsenalData.world_of(lvl)
	for id in ArsenalData.live_ids():
		var at := ArsenalData.new_crate_level(id)
		if at > 0 and at < lvl and not owned(id):
			_machines()[id] = EconData.new_machine_state(id, int(EconData.START_LEVEL[ArsenalData.rarity_of(id)]))
