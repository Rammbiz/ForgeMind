class_name Rewards
## Books a finished run (arsenal_design.md §4.4, §6.2, §7.3, §9.3 Rewards.level_end) and returns
## the result bundle (meta1_contracts.md §6.5) for the result / loss flow:
##   coins (win: (victory + pickups) x stairs, replay 60%; loss: (0.25 x victory(L, 0) + 0.70 x
##   pickups) x bridge fraction) · Crowns (improvement only) · NEW machine (kept on a loss) ·
##   run drip (x1.5 at Rank III, x0.5 on a loss) · Cache (win from L6: Stone, World on bosses;
##   first 3 replay wins a day: Stone; loss: +1/3 charge, three = Stone) · frontier, boss wins ·
##   Reinforcements · unlock rows · counters · telemetry.
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
		if cache != "stone" or _stone_to_vault(acc):
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
