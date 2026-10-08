class_name Rewards
## Books a finished run (arsenal_design.md §4.4, §6.2, §7.3, §9.3 Rewards.level_end) and returns
## the result bundle (meta1_contracts.md §6.5) for the result / loss flow:
##   coins (win: (victory + pickups) x stairs, replay 60%; loss: (0.25 x victory(L, 0) + 0.70 x
##   pickups) x bridge fraction) · Crowns (improvement only) · NEW machine (kept on a loss) ·
##   run drip (x1.5 at Rank III, x0.5 on a loss) · Cache (win from L6: Stone, World on bosses;
##   first 3 replay wins a day: Stone; loss: +1/3 charge, three = Stone) · frontier, boss wins ·
##   Reinforcements · unlock rows · counters · telemetry.
##
## Heroes & Champions (heroes_design.md §7.3 - §7.5, §11.1; only while EconData.heroes_live(), so
## the 2.2.1 bundle is unchanged with the flag off): step 5b books the earned-only hero income of the
## run (hero_level_end): starters joining by progress, Beacons (+0.2 per first clear, +2 per world
## boss once the Portal is open), Tomes (+1 per world boss after the skills unlock), Hero Chests
## (charge 1/3 per win from the champions unlock, the first 3 replay wins a day; a Grand Hero
## Chest per world-boss first clear; scripted chests #1 at the unlock and #2 as the next one) and
## the one inline reveal per result screen (scripted > Grand > Hero Chest > Stone Cache: whatever it
## displaces goes to the Vault). Daily / weekly / Expedition / login income: hero_mission_done,
## hero_weekly_done, hero_expedition, hero_login. Nothing here reads money: no SKU, Gem, coin or
## rating value ever enters these numbers (the two-track rule, test_meta._test_two_track).
##
## Idempotent: every run carries a `run_id` (Meta.run_profile issues it; Run.result echoes it).
## A result whose id is already booked (or, without an id, the very same result as the last one
## booked) returns {duplicate: true, ...} and credits nothing.

const BOOKED_KEEP := 32


## The Cache a WIN of `level` grants ("" before CACHE_FROM_LEVEL).
static func cache_for_win(level: int) -> String:
	return EconData.win_cache(level)


## Fingerprint of a result without a run id (stable across key order).
static func signature(result: Dictionary) -> int:
	var keys := result.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		if str(k) == "run_id":
			continue
		parts.append("%s=%s" % [str(k), var_to_str(result[k])])
	return "|".join(parts).hash()


## True when `result` was already booked on this account.
static func is_duplicate(acc: Dictionary, result: Dictionary) -> bool:
	var m: Dictionary = acc["meta"]
	var rid := int(result.get("run_id", 0))
	if rid > 0:
		return (m.get("booked", []) as Array).has(rid)
	return int(m.get("last_sig", 0)) != 0 and int(m.get("last_sig", 0)) == signature(result)


## Books `result` (Run.result + won, level, pickups, bridge_fraction, fielded, new_unlock, crowns,
## shards, boss_core, stats, run_id) and returns the §6.5 bundle. `now_s` = unix time (replay
## caches per day, telemetry).
static func level_end(acc: Dictionary, result: Dictionary, rng: RandomNumberGenerator, now_s := 0) -> Dictionary:
	var p: Dictionary = acc["progress"]
	var frontier := MetaAcc.level(acc)
	var lvl := maxi(1, int(result.get("level", frontier)))
	var won := bool(result.get("won", int(result.get("victory", 0)) > 0))
	if is_duplicate(acc, result):
		return {"duplicate": true, "won": won, "level": lvl, "replay": lvl < frontier, "coins": {"total": 0},
				"caches": [], "drip": [], "unlocks": [], "new_unlock": "", "walkout": false,
				"assist": EconData.assist(assist_stacks(acc, lvl)), "best_upgrade": Arsenal.best_upgrade(acc),
				"coins_balance": MetaAcc.amount(acc, "coins")}
	_book(acc, result)
	var replay := lvl < frontier
	if lvl > frontier:
		lvl = frontier          # never skip the frontier (dev / stale results)
	var pickups := int(result.get("pickups", result.get("coins_run", 0)))
	var bundle := {"won": won, "level": lvl, "replay": replay, "caches": [], "drip": [], "unlocks": [],
			"new_unlock": "", "walkout": false, "duplicate": false}
	# 1. Coins.
	var coins := 0
	if won:
		var victory := int(result.get("victory", EconData.victory_coins(lvl, int(result.get("survivors", 0)))))
		var mult := float(result.get("mult", result.get("stairs_mult", 1.0)))
		if result.has("total") and not replay:
			coins = int(result["total"])
		else:
			coins = EconData.win_coins(victory, pickups, mult, replay)
		bundle["coins"] = {"victory": victory, "pickups": pickups, "stairs_mult": mult, "total": coins}
	else:
		var frac := clampf(float(result.get("bridge_fraction", 0.5)), 0.0, 1.0)
		coins = EconData.loss_coins(lvl, pickups, frac)
		bundle["coins"] = {"victory": 0, "pickups": pickups, "bridge_fraction": frac, "total": coins}
	MetaAcc.add(acc, "coins", coins)
	# 2. Crowns (improvement only) and star-shards.
	var crowns := clampi(int(result.get("crowns", 1 if won else 0)), 0, 3)
	var cb: Dictionary = p["crowns_best"]
	var gained := maxi(0, crowns - int(cb.get(lvl, 0)))
	if gained > 0:
		cb[lvl] = crowns
		MetaAcc.add(acc, "crowns", gained)
		MetaAcc.count(acc, "crowns_gained", gained)
	bundle["crowns"] = {"run": crowns, "gained": gained}
	if result.has("shards"):
		var sb: Dictionary = p["shards_best"]
		sb[lvl] = int(sb.get(lvl, 0)) | int(result["shards"])
	# 3. NEW machine from the platinum crate (kept even on a loss).
	var nu := str(result.get("new_unlock", ""))
	if nu != "" and Arsenal.unlock(acc, nu, "crate"):
		bundle["new_unlock"] = nu
	if nu != "" and MetaAcc.owned(acc, nu):
		var seen: Dictionary = (acc["arsenal"] as Dictionary)["seen"]
		if bundle["new_unlock"] == nu:
			bundle["walkout"] = not seen.has(nu)
			seen[nu] = true
	# 4. Run drip into the fielded machines.
	for f in result.get("fielded", []):
		if not f is Dictionary:
			continue
		var id := str((f as Dictionary).get("id", ""))
		if not MetaAcc.owned(acc, id):
			continue
		var st: Dictionary = MetaAcc.machines(acc)[id]
		var r := ArsenalData.rarity_of(id)
		var add := float(EconData.DRIP[r]) * (EconData.DRIP_RANK3 if int((f as Dictionary).get("rank", 1)) >= 3 else 1.0) \
				* (1.0 if won else EconData.DRIP_LOSS)
		var before := int(st["bp"])
		st["frac"] = float(st.get("frac", 0.0)) + add
		var whole := int(floor(float(st["frac"]) + 1e-6))
		st["frac"] = maxf(0.0, float(st["frac"]) - whole)
		var to_wild := 0
		if int(st["lvl"]) >= ArsenalData.MAX_LEVEL:
			to_wild = whole
			MetaAcc.add(acc, "wild_" + r, whole)
		else:
			st["bp"] = before + whole
		(bundle["drip"] as Array).append({"id": id, "add": add, "bp_before": before, "bp_after": int(st["bp"]),
				"frac": float(st["frac"]), "bp_need": EconData.bp_to(r, int(st["lvl"]) + 1), "to_wild": to_wild,
				"upgradable": bool(Arsenal.cost(acc, id)["can"])})
	# 5. Frontier, boss wins, Boss Core.
	var before_level := frontier
	if won:
		if not replay:
			p["level"] = lvl + 1
			p["world_reached"] = maxi(int(p.get("world_reached", 1)), ArsenalData.world_of(lvl + 1))
			if ArsenalData.is_boss(lvl):
				p["boss_wins"] = int(p.get("boss_wins", 0)) + 1
				MetaAcc.count(acc, "bosses_beaten", 1)
				var h := str(p.get("hero", "bolt"))
				var hs: Dictionary = (acc["heroes"] as Dictionary).get(h, {})
				if not hs.is_empty():
					hs["boss_wins"] = int(hs.get("boss_wins", 0)) + 1
		if bool(result.get("boss_core", false)):
			MetaAcc.add(acc, "cores", 1)
	# 5b. Heroes & Champions income (live phase only; sets hero_inline when a chest takes the one
	# inline reveal of this result screen).
	var hero_inline := false
	if EconData.heroes_live():
		hero_inline = hero_level_end(acc, bundle, result, lvl, won, replay, before_level, rng, now_s)
	# 6. Cache or loss charge.
	var cache := ""
	var w: Dictionary = acc["wallet"]
	if won and not replay:
		cache = cache_for_win(lvl)
	elif won and replay and lvl >= EconData.CACHE_FROM_LEVEL and _replay_cache_left(acc, now_s) > 0:
		cache = "stone"
		_replay_cache_take(acc, now_s)
	elif not won and lvl >= EconData.CACHE_FROM_LEVEL:
		w["cache_charge"] = float(w.get("cache_charge", 0.0)) + EconData.LOSS_CACHE_CHARGE
		var charge := float(w["cache_charge"])
		bundle["cache_charge"] = {"value": clampi(int(round(charge * 3.0)), 0, 3), "of": 3}
		if charge >= 0.999:
			w["cache_charge"] = 0.0
			cache = "stone"
	elif not won:
		bundle["cache_charge"] = {"value": 0, "of": 3}
	if cache != "":
		var src := "loss" if not won else ("replay" if replay else "win")
		if cache != "stone" or hero_inline or _stone_to_vault(acc):
			var v: Array = (acc["vault"] as Dictionary)["caches"]
			v.append({"type": cache, "source": src, "level": lvl})
			(bundle["caches"] as Array).append({"type": cache, "inline": false, "reveal": {}, "vault_index": v.size() - 1})
		else:
			(bundle["caches"] as Array).append({"type": cache, "inline": true, "reveal": CacheRoller.open(acc, cache, src, rng)})
	# 7. Reinforcements.
	if won:
		p["losses_here"] = 0
		p["assist_level"] = 0
	else:
		if int(p.get("assist_level", 0)) != lvl:
			p["losses_here"] = 0
		p["assist_level"] = lvl
		p["losses_here"] = mini(int(p.get("losses_here", 0)) + 1, int(EconData.RETRY_ASSIST["cap"]))
	bundle["assist"] = EconData.assist(assist_stacks(acc, lvl))
	# 8. Unlock rows (the hub shows the lines via UnlockQueue.pending).
	bundle["unlocks"] = UnlockQueue.opened_between(before_level, MetaAcc.level(acc))
	# 9. Counters and telemetry.
	MetaAcc.count(acc, "wins" if won else "losses", 1)
	var stats: Variant = result.get("stats", {})
	if stats is Dictionary:
		for k in (stats as Dictionary):
			if str(k) != "wins":
				MetaAcc.count(acc, str(k), (stats as Dictionary)[k])
	MetaTelemetry.attempt(acc, lvl, won, now_s)
	bundle["best_upgrade"] = Arsenal.best_upgrade(acc)
	bundle["coins_balance"] = MetaAcc.amount(acc, "coins")
	bundle["run_id"] = int(result.get("run_id", 0))
	return bundle


## Reinforcements stacks for the next attempt of `lvl` (0 when off or another level).
static func assist_stacks(acc: Dictionary, lvl: int) -> int:
	if not bool((acc["settings"] as Dictionary).get("reinforcements", true)):
		return 0
	var p: Dictionary = acc["progress"]
	if int(p.get("assist_level", 0)) != lvl:
		return 0
	return mini(int(p.get("losses_here", 0)), int(EconData.RETRY_ASSIST["cap"]))


static func _book(acc: Dictionary, result: Dictionary) -> void:
	var m: Dictionary = acc["meta"]
	var rid := int(result.get("run_id", 0))
	if rid > 0:
		if not m.get("booked") is Array:
			m["booked"] = []
		var b: Array = m["booked"]
		b.append(rid)
		while b.size() > BOOKED_KEEP:
			b.remove_at(0)
	m["last_sig"] = signature(result)


## Stone Caches go to the Vault when the player chose so, or by default from the
## VAULT_DEFAULT_FROM-th Stone Cache on (the setting was never touched).
static func _stone_to_vault(acc: Dictionary) -> bool:
	var s: Dictionary = acc["settings"]
	if bool(s.get("caches_to_vault_set", false)):
		return bool(s.get("caches_to_vault", false))
	if bool(s.get("caches_to_vault", false)):
		return true
	return int((acc["vault"] as Dictionary).get("stone_total", 0)) >= EconData.VAULT_DEFAULT_FROM - 1 \
			and UnlockQueue.is_open(acc, "altar")


static func _day(now_s: int) -> String:
	return Time.get_date_string_from_unix_time(now_s) if now_s > 0 else ""


static func _replay_cache_left(acc: Dictionary, now_s: int) -> int:
	var p: Dictionary = acc["progress"]
	var rd: Dictionary = p.get("replay_day", {}) if p.get("replay_day") is Dictionary else {}
	var n := int(rd.get("n", 0)) if str(rd.get("day", "")) == _day(now_s) else 0
	return int(EconData.REPLAY["caches_per_day"]) - n


static func _replay_cache_take(acc: Dictionary, now_s: int) -> void:
	var p: Dictionary = acc["progress"]
	var day := _day(now_s)
	var rd: Dictionary = p.get("replay_day", {}) if p.get("replay_day") is Dictionary else {}
	var n := int(rd.get("n", 0)) if str(rd.get("day", "")) == day else 0
	p["replay_day"] = {"day": day, "n": n + 1}


# ======================================================================== Heroes & Champions income

## True when hero system `sys` (SaveV3Data.UNLOCK_AT key) was open BEFORE a result booked at frontier
## `before_level` (next level to play before the result): the win that opens a system pays nothing
## of it, exactly as heroes_sim (and the update-day lump grant) count.
static func hero_open_before(sys: String, before_level: int) -> bool:
	return before_level > int(SaveV3Data.UNLOCK_AT[sys])


## The account's hero system `sys` is open by level now (frontier past its after_win; income follows
## the level rule like heroes_sim, the session queue only paces the tutorial lines).
static func hero_open(acc: Dictionary, sys: String) -> bool:
	return MetaAcc.level(acc) > int(SaveV3Data.UNLOCK_AT[sys])


## Step 5b of level_end (live phase): fills bundle {hero_joined [{id, gem, new}], beacons {add,
## charge}, tomes {add}, hero_chests [{type, inline, reveal, vault_index, scripted, source}], guest}
## and returns true when a Hero Chest took the result screen's one inline reveal.
static func hero_level_end(acc: Dictionary, bundle: Dictionary, result: Dictionary, lvl: int, won: bool, replay: bool,
		before_level: int, rng: RandomNumberGenerator, now_s := 0) -> bool:
	var first_clear := won and not replay
	var boss := ArsenalData.is_boss(lvl)
	# Starters joining by progress (Горан after L4, Мейра after the World 3 boss).
	var joined: Array = []
	if first_clear:
		for id: String in SaveV3Data.STARTERS:
			if EconData.hero_unlock_at(id) == lvl and not Roster.owned(acc, id):
				var g := Roster.grant(acc, id, "progress", now_s)
				joined.append({"id": id, "gem": str(g["gem"]), "new": bool(g["new"])})
	bundle["hero_joined"] = joined
	# Beacons (PortalData.BEACON; the fraction banks in wallet.beacon_charge).
	var w: Dictionary = acc["wallet"]
	var b_before := MetaAcc.amount(acc, "beacons")
	if first_clear and hero_open_before("portal", before_level):
		w["beacon_charge"] = float(w.get("beacon_charge", 0.0)) + float(PortalData.BEACON["first_clear"])
		if boss:
			MetaAcc.add(acc, "beacons", int(PortalData.BEACON["boss"]))
	bank_beacons(acc)
	bundle["beacons"] = {"add": MetaAcc.amount(acc, "beacons") - b_before, "charge": float(w.get("beacon_charge", 0.0))}
	# Tomes: a world-boss first clear after the skills unlock.
	var tomes := 0
	if first_clear and boss and hero_open_before("skills", before_level):
		tomes = PortalData.TOMES_BOSS
		MetaAcc.add(acc, "tomes", tomes)
	bundle["tomes"] = {"add": tomes}
	# Hero Chests (PortalData.CHEST_*): scripted #1 on the win that opens the champions row, a Grand
	# Hero Chest per world-boss first clear, a Hero Chest every 3rd win (replays: 3 a day).
	var drops: Array[Dictionary] = []
	var champs_at := int(SaveV3Data.UNLOCK_AT["champions"])
	if first_clear and lvl == champs_at and not hero_open_before("champions", before_level):
		var s1 := Vault.scripted_entry(acc, 1, "unlock", lvl)
		if not s1.is_empty():
			drops.append(s1)
	if hero_open_before("champions", before_level) and won:
		if first_clear and boss:
			drops.append({"type": Vault.GRAND, "source": "boss", "level": lvl, "scripted": 0})
		if not replay or _replay_chest_left(acc, now_s) > 0:
			if replay:
				_replay_chest_take(acc, now_s)
			w["chest_charge"] = float(w.get("chest_charge", 0.0)) + PortalData.CHEST_CHARGE_PER_WIN
			if float(w["chest_charge"]) >= 1.0 - 1e-6:
				w["chest_charge"] = maxf(0.0, float(w["chest_charge"]) - 1.0)
				var s2 := Vault.scripted_entry(acc, 2, "win", lvl)
				drops.append(s2 if not s2.is_empty() else {"type": Vault.HERO_CHEST, "source": "replay" if replay else "win",
						"level": lvl, "scripted": 0})
	bundle["chest_charge"] = {"value": clampi(int(round(float(w.get("chest_charge", 0.0)) * 3.0)), 0, 3), "of": 3}
	# One inline reveal per result screen: scripted > Grand > Hero Chest (> the Stone Cache, step 6).
	var best := -1
	for i in drops.size():
		if best < 0 or _chest_rank(drops[i]) > _chest_rank(drops[best]):
			best = i
	var rows: Array = []
	for i2 in drops.size():
		var d: Dictionary = drops[i2]
		if i2 == best:
			var rev := open_chest(acc, d, rng, now_s)
			rows.append({"type": d["type"], "source": d["source"], "scripted": int(d["scripted"]), "inline": true,
					"reveal": rev, "vault_index": -1})
			MetaTelemetry.note(acc, "chest", {"type": d["type"], "best": str(rev.get("best_gem", rev.get("best", ""))),
					"scripted": int(d["scripted"]), "inline": true}, now_s)
		else:
			var at := Vault.add(acc, str(d["type"]), str(d["source"]), int(d["level"]), int(d["scripted"]))
			rows.append({"type": d["type"], "source": d["source"], "scripted": int(d["scripted"]), "inline": false,
					"reveal": {}, "vault_index": at})
	bundle["hero_chests"] = rows
	# Мейра's guest level: no ownership, one line after the result.
	if str(result.get("guest", "")) != "":
		bundle["guest"] = {"id": str(result["guest"]), "line": "GUEST_SEER_RETURN"}
	_team_run(acc, result, lvl, won, now_s)
	return best >= 0


## Whole Beacons out of wallet.beacon_charge (the fraction stays). Returns the Beacons banked.
static func bank_beacons(acc: Dictionary) -> int:
	var w: Dictionary = acc["wallet"]
	var ch := float(w.get("beacon_charge", 0.0))
	var whole := int(floor(ch + 1e-6))
	if whole <= 0:
		return 0
	w["beacon_charge"] = maxf(0.0, ch - float(whole))
	MetaAcc.add(acc, "beacons", whole)
	return whole


## A daily mission was completed (live phase): +1/3 Beacon once the Portal is open (§7.3).
## Returns {beacons}.
static func hero_mission_done(acc: Dictionary) -> Dictionary:
	if not EconData.heroes_live() or not hero_open(acc, "portal"):
		return {"beacons": 0}
	var w: Dictionary = acc["wallet"]
	w["beacon_charge"] = float(w.get("beacon_charge", 0.0)) + float(PortalData.BEACON["mission"])
	return {"beacons": bank_beacons(acc)}


## Weekly 5/5 (live phase): +4 Beacons (Portal open), a Grand Hero Chest into the Vault (champions
## open), +2 Tomes (skills open). Returns {beacons, tomes, vault_index}.
static func hero_weekly_done(acc: Dictionary) -> Dictionary:
	var out := {"beacons": 0, "tomes": 0, "vault_index": -1}
	if not EconData.heroes_live():
		return out
	if hero_open(acc, "portal"):
		out["beacons"] = int(PortalData.BEACON["weekly"])
		MetaAcc.add(acc, "beacons", int(out["beacons"]))
	if hero_open(acc, "champions"):
		out["vault_index"] = Vault.add(acc, Vault.GRAND, "weekly", MetaAcc.level(acc))
	if hero_open(acc, "skills"):
		out["tomes"] = PortalData.TOMES_WEEKLY
		MetaAcc.add(acc, "tomes", int(out["tomes"]))
	return out


## A weekly Expedition finished with `stars` of 5 (live phase): 3/5 +1 Beacon; 5/5 also +2 Beacons,
## a Grand Hero Chest and +2 Tomes (each only once its system is open). Returns {beacons, tomes,
## vault_index}.
static func hero_expedition(acc: Dictionary, stars: int) -> Dictionary:
	var out := {"beacons": 0, "tomes": 0, "vault_index": -1}
	if not EconData.heroes_live() or stars < 3:
		return out
	var portal := hero_open(acc, "portal")
	if portal:
		out["beacons"] = int(PortalData.BEACON["exp3"])
	if stars >= 5:
		if portal:
			out["beacons"] = int(out["beacons"]) + int(PortalData.BEACON["exp5"])
		if hero_open(acc, "champions"):
			out["vault_index"] = Vault.add(acc, Vault.GRAND, "expedition", MetaAcc.level(acc))
		if hero_open(acc, "skills"):
			out["tomes"] = PortalData.TOMES_EXP5
			MetaAcc.add(acc, "tomes", int(out["tomes"]))
	MetaAcc.add(acc, "beacons", int(out["beacons"]))
	return out


## The login cycle card of `cycle_day` (1..7) was claimed (live phase): the day-7 card adds +1 Beacon
## once the Portal is open. Returns {beacons}.
static func hero_login(acc: Dictionary, cycle_day: int) -> Dictionary:
	if not EconData.heroes_live() or cycle_day != EconData.LOGIN_CYCLE.size() or not hero_open(acc, "portal"):
		return {"beacons": 0}
	MetaAcc.add(acc, "beacons", int(PortalData.BEACON["login7"]))
	return {"beacons": int(PortalData.BEACON["login7"])}


static func _chest_rank(d: Dictionary) -> int:
	if int(d.get("scripted", 0)) > 0:
		return 3
	return 2 if str(d.get("type", "")) == Vault.GRAND else 1


static func _replay_chest_left(acc: Dictionary, now_s: int) -> int:
	var p: Dictionary = acc["progress"]
	var rd: Dictionary = p.get("replay_chest_day", {}) if p.get("replay_chest_day") is Dictionary else {}
	var n := int(rd.get("n", 0)) if str(rd.get("day", "")) == _day(now_s) else 0
	return PortalData.CHEST_REPLAYS_PER_DAY - n


static func _replay_chest_take(acc: Dictionary, now_s: int) -> void:
	var p: Dictionary = acc["progress"]
	var day := _day(now_s)
	var rd: Dictionary = p.get("replay_chest_day", {}) if p.get("replay_chest_day") is Dictionary else {}
	var n := int(rd.get("n", 0)) if str(rd.get("day", "")) == day else 0
	p["replay_chest_day"] = {"day": day, "n": n + 1}


## Telemetry `team_run` (§12.5) from the run's team report (WS-C: result.team_report [{id, alive,
## kills, heals, blocks}], result.synergies [ids]).
static func _team_run(acc: Dictionary, result: Dictionary, lvl: int, won: bool, now_s: int) -> void:
	var team: Dictionary = acc.get("team", {})
	var champs: Array = []
	var lost: Array = []
	var rep: Variant = result.get("team_report", [])
	if rep is Array:
		for r in rep:
			if r is Dictionary:
				champs.append(str((r as Dictionary).get("id", "")))
				if not bool((r as Dictionary).get("alive", true)):
					lost.append(str((r as Dictionary).get("id", "")))
	if champs.is_empty():
		champs = (team.get("champions", []) as Array).duplicate()
	var syn: Variant = result.get("synergies", [])
	MetaTelemetry.note(acc, "team_run", {"level": lvl, "hero": str(result.get("hero", team.get("hero", ""))),
			"champions": champs, "synergies": syn if syn is Array else [], "won": won, "lost_ids": lost}, now_s)


## Opens Hero Chest entry `d` ({type, source, level, scripted}) at once through the HeroChest roller
## (WS-A) and returns its reveal bundle; the result is booked before any animation.
static func open_chest(acc: Dictionary, d: Dictionary, rng: RandomNumberGenerator, now_s := 0) -> Dictionary:
	# TEMP (H1 WIP): until WS-A's HeroChest lands the chest waits in the Vault.
	var at := Vault.add(acc, str(d["type"]), str(d["source"]), int(d["level"]), int(d["scripted"]))
	return {"pending": true, "vault_index": at}
