class_name UnlockQueue
## UnlockQueue (arsenal_design.md §4.6): systems open by level AND by session. At most
## EconData.UNLOCK_RULES.per_session new systems per session (session = the app comes to the
## foreground after >= session_gap_s away); a new tab or currency at least tab_gap_levels after
## the previous one unless "gap_exempt". Each unlock shows one tutorial line (the hub calls
## ack() after showing it) and grants its first step free.
##
## In-run unlocks (drag, pairs, rank gates) and hero unlocks open by level alone and never take a
## session slot (the run shows its own line).
## A system is OPEN when its level condition holds and it is either in-run / line-less,
## already acknowledged, part of a migrated player's catch-up below the migration level, or
## presentable right now (inside this session's window). The 3rd unlock of a session therefore
## stays closed until the next session, as the design asks.
##
## Account keys: unlocks {done [ids], pending [ids], session_count, done_at {id: level},
## migrated_level (0 = none), heroes_migrated_level (0 = none; the v2 -> v3 update day), cards [Loc
## keys of one-time cards], free {}}; meta {sessions, last_session}.
##
## Heroes & Champions (heroes_design.md §11.1 - §11.2): the rows come from EconData.unlocks(), which
## is the 2.2.1 table while the heroes phase is off. From the live phase the champions / Portal /
## skills / Workshop / slot 3 rows join (Seer 5 -> 24), a migrated v2 player finds every row below
## the update-day frontier open at once (its line still waits for a session slot, as a hub card),
## and the free first steps first_champion / welcome_x10 / first_rank / first_craft are granted.

## Synthetic pending entry for the one-time migration card (does not use a session slot).
const MIGRATION_ID := "migration"


## True once unlock `id` is open for this account (unknown ids are open).
static func is_open(acc: Dictionary, id: String) -> bool:
	var u := EconData.unlock_entry(id)
	if u.is_empty():
		return true
	if not level_open(acc, u):
		return false
	var un: Dictionary = acc["unlocks"]
	if str(u.get("kind", "")) in ["inrun", "hero"] or str(u.get("line", "")) == "":
		return true
	if (un.get("done", []) as Array).has(id) or _catch_up(acc, u):
		return true
	for p in pending(acc):
		if str(p["id"]) == id:
			return true
	return false


## The level (and phase) condition of an UNLOCKS entry, ignoring sessions.
static func level_open(acc: Dictionary, u: Dictionary) -> bool:
	if int(u.get("phase", 1)) > EconData.meta_phase() or int(u.get("heroes", 0)) > EconData.heroes_phase():
		return false
	var lvl := MetaAcc.level(acc)
	if u.has("after_win"):
		return lvl > int(u["after_win"])
	return lvl >= int(u.get("from_level", 1))


## Unlocks whose tutorial line waits to be shown, oldest first, limited by the session rule
## (and the migration card first, once).
static func pending(acc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var un: Dictionary = acc["unlocks"]
	var done: Array = un.get("done", [])
	if (un.get("cards", []) as Array).has("MIGRATION_CARD") and not done.has(MIGRATION_ID):
		out.append({"id": MIGRATION_ID, "kind": "card", "line": "MIGRATION_CARD", "free": "", "phase": 1})
	var room := maxi(0, int(EconData.UNLOCK_RULES["per_session"]) - int(un.get("session_count", 0)))
	var gap_hold := _gap_hold(acc)
	for u: Dictionary in EconData.unlocks():
		if room <= 0:
			break
		var id := str(u["id"])
		if str(u.get("line", "")) == "" or done.has(id) or not level_open(acc, u):
			continue
		if str(u.get("kind", "")) in ["inrun", "hero"]:
			continue          # in-run lines are shown by the run itself; no session slot
		if gap_hold and str(u["kind"]) in ["tab", "currency"] and not bool(u.get("gap_exempt", false)) \
				and not _catch_up(acc, u):
			continue
		out.append(u)
		room -= 1
	return out


## The UI showed unlock `id` (tutorial line + its free first step). Grants the free step.
static func ack(acc: Dictionary, id: String) -> void:
	var un: Dictionary = acc["unlocks"]
	var done: Array = un["done"]
	if done.has(id):
		return
	done.append(id)
	if not un.get("done_at") is Dictionary:
		un["done_at"] = {}
	(un["done_at"] as Dictionary)[id] = MetaAcc.level(acc)
	(un.get("pending", []) as Array).erase(id)
	if id == MIGRATION_ID:
		return
	un["session_count"] = int(un.get("session_count", 0)) + 1
	_grant_free(acc, EconData.unlock_entry(id))


## App came to the foreground at unix time `now_s`. A new session starts after >= session_gap_s
## away (or on the very first call); it resets the per-session unlock count.
static func on_session_start(acc: Dictionary, now_s: int) -> bool:
	var m: Dictionary = acc["meta"]
	var last := int(m.get("last_session", 0))
	var fresh := last == 0 or now_s - last >= int(EconData.UNLOCK_RULES["session_gap_s"])
	if fresh:
		m["sessions"] = int(m.get("sessions", 0)) + 1
		(acc["unlocks"] as Dictionary)["session_count"] = 0
	m["last_session"] = now_s
	return fresh


## The app went to the background at `now_s` (keeps last_session = time last seen).
static func on_session_pause(acc: Dictionary, now_s: int) -> void:
	(acc["meta"] as Dictionary)["last_session"] = now_s


## UNLOCKS entries (phase-live) that a frontier move from `before_level` to `after_level`
## opened, as result-bundle rows {id, kind, line, free}.
static func opened_between(before_level: int, after_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in EconData.unlocks():
		if int(u.get("phase", 1)) > EconData.meta_phase() or int(u.get("heroes", 0)) > EconData.heroes_phase():
			continue
		var opened := false
		if u.has("after_win"):
			opened = before_level <= int(u["after_win"]) and after_level > int(u["after_win"])
		else:
			opened = before_level < int(u.get("from_level", 1)) and after_level >= int(u.get("from_level", 1))
		if opened:
			out.append({"id": str(u["id"]), "kind": str(u["kind"]), "line": str(u.get("line", "")),
					"free": str(u.get("free", ""))})
	return out


## Marks every unlock open by level as done (synthetic dev / bot accounts: no tutorials).
static func mark_all_done(acc: Dictionary) -> void:
	var done: Array = (acc["unlocks"] as Dictionary)["done"]
	for u: Dictionary in EconData.unlocks():
		if level_open(acc, u) and not done.has(str(u["id"])):
			done.append(str(u["id"]))


## Catch-up tour of a migrated v1 player: every unlock below `level` is open at once and its
## tutorial line is queued (still at most per_session per session).
static func start_catch_up(acc: Dictionary, level: int) -> void:
	var un: Dictionary = acc["unlocks"]
	un["migrated_level"] = level
	var pend: Array = un["pending"]
	for u: Dictionary in EconData.unlocks():
		if level_open(acc, u) and str(u.get("line", "")) != "" and not str(u["kind"]) in ["inrun", "hero"] \
				and not pend.has(str(u["id"])):
			pend.append(str(u["id"]))


static func _catch_up(acc: Dictionary, u: Dictionary) -> bool:
	var un: Dictionary = acc["unlocks"]
	var ml := int(un.get("migrated_level", 0))
	# The v2 -> v3 update day opens every heroes row (and the moved Seer row) the frontier had passed.
	if u.has("heroes") or str(u.get("id", "")) == "seer":
		ml = maxi(ml, int(un.get("heroes_migrated_level", 0)))
	if ml <= 0:
		return false
	if u.has("after_win"):
		return ml > int(u["after_win"])
	return ml >= int(u.get("from_level", 1))


## True while the last acknowledged tab/currency unlock is closer than tab_gap_levels.
static func _gap_hold(acc: Dictionary) -> bool:
	var un: Dictionary = acc["unlocks"]
	var at: Dictionary = un.get("done_at", {}) if un.get("done_at") is Dictionary else {}
	var lvl := MetaAcc.level(acc)
	for id in at:
		var u := EconData.unlock_entry(str(id))
		if u.is_empty() or not str(u.get("kind", "")) in ["tab", "currency"] or bool(u.get("gap_exempt", false)):
			continue
		if _catch_up(acc, u):
			continue
		if lvl < int(at[id]) + int(EconData.UNLOCK_RULES["tab_gap_levels"]):
			return true
	return false


## First step free (§4.6 table): Ballista Lv2, a hero level, Recruits Lv1, the auto-deck.
## The scripted first Stone Cache and the first World Cache are handled by Rewards / CacheRoller.
static func _grant_free(acc: Dictionary, u: Dictionary) -> void:
	match str(u.get("free", "")):
		"ballista_lv2":
			var id := "ballista" if MetaAcc.owned(acc, "ballista") else "drone"
			if MetaAcc.machine_level(acc, id) < 2:
				MetaAcc.free_steps(acc)["machine"] = id
		"hero_level":
			MetaAcc.free_steps(acc)["hero"] = true
		"recruits_lv1":
			var b: Dictionary = acc["barracks"]
			if int(b.get("recruits", 0)) == 0:
				b["recruits"] = 1
		"auto_deck":
			var ar: Dictionary = acc["arsenal"]
			var d: Array = (ar["decks"] as Array)[int(ar.get("deck_active", 0))]
			if d.is_empty():
				(ar["decks"] as Array)[int(ar.get("deck_active", 0))] = Arsenal.auto_deck(acc)
		# Heroes & Champions (heroes_design.md §11.1, §11.4).
		"first_champion":
			# The champions-unlock gift chest (it opens as scripted chest #1, HeroChest) when the unlock
			# win's result screen did not grant it (a migrated player's catch-up card): into the Vault;
			# Meta.ack_unlock opens it at once and its champion takes slot 1.
			if Vault.take_unlock_gift(acc):
				Vault.add(acc, Vault.HERO_CHEST, "unlock", MetaAcc.level(acc) - 1)
		"welcome_x10":
			pass          # the free x10 waits in the Portal until summon.welcome_done (Meta.portal().welcome_ready)
		"first_rank":
			MetaAcc.free_steps(acc)["skill_rank"] = true        # one free Ult rank on the team hero (HeroesMeta.free_rank)
		"first_craft":
			MetaAcc.free_steps(acc)["craft"] = true             # the first Workshop craft is free (WS-F; + retro grant)
