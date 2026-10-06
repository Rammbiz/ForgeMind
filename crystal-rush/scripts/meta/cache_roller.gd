class_name CacheRoller
## The Cache roller (arsenal_design.md §5.3-§5.5): a line-by-line port of economy_sim.roll_cache
## plus the card grant of economy_sim.Player._grant_card. One table (EconData.CACHES, CARD_ODDS,
## STACK, PITY) feeds the roller, the (i) odds screen and the sim.
##
## roll():  slots 1..n-1 draw from the per-card weights of the rarities present in the pool;
##          the last slot is re-rolled from rarities >= the guaranteed minimum (Epic pity at 8,
##          Legendary welcome / soft pity from 20 / hard pity at 30); then the pity counters
##          update (frozen while that rarity is not in the pool); then one Wild check per slot.
## grant(): Legendary/Mythic cards go to an unowned machine first (duplicate protection), else
##          40% to the Focus machine of that rarity, else Deck machines x1.5; a card for an
##          unowned machine unlocks it (walkout) and carries one blueprint less; blueprints for a
##          Lv15 machine become Wild Blueprints of its rarity 1:1.
## The result and the RNG state are saved by Meta BEFORE any animation.


## Rarities present in `pool` for a Cache of `type` (Mythic only where the Cache allows it).
static func present(pool: Array[String], type: String) -> Array[String]:
	var out: Array[String] = []
	var allow_m := bool((EconData.CACHES[type] as Dictionary).get("mythic", false))
	for r in ArsenalData.RARITY_ORDER:
		for id in pool:
			if ArsenalData.rarity_of(id) == r and (r != "M" or allow_m):
				out.append(r)
				break
	return out


## sim: guaranteed_min — the Cache's guarantee capped at the best non-Mythic rarity present.
static func guaranteed_min(type: String, pres: Array[String]) -> String:
	var want := str((EconData.CACHES[type] as Dictionary).get("guaranteed", "C"))
	var best := "C"
	for r in pres:
		if r != "M" and ArsenalData.rarity_index(r) > ArsenalData.rarity_index(best):
			best = r
	return want if ArsenalData.rarity_index(want) <= ArsenalData.rarity_index(best) else best


## sim: slot_weights — CARD_ODDS over the present rarities (>= min_r when given), Legendary x
## the Cache's leg_weight.
static func slot_weights(pres: Array[String], type: String, min_r := "") -> Dictionary:
	var w := {}
	var lw := float((EconData.CACHES[type] as Dictionary).get("leg_weight", 1.0))
	for r in ArsenalData.RARITY_ORDER:
		if not pres.has(r):
			continue
		if min_r != "" and ArsenalData.rarity_index(r) < ArsenalData.rarity_index(min_r):
			continue
		w[r] = float(EconData.CARD_ODDS[r]) * (lw if r == "L" else 1.0)
	return w


## sim: roll_cache. `pity` {since_epic, since_leg, leg_welcome_done} is updated IN PLACE.
## Returns {rarities [slot order], wild [bool per slot], best, pity_after (copy)}.
static func roll(type: String, pool: Array[String], pity: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var g: Dictionary = EconData.CACHES[type]
	var pres := present(pool, type)
	var e_in := pres.has("E")
	var l_in := pres.has("L")
	var cards: Array[String] = []
	for i in int(g["slots"]) - 1:
		var w0 := slot_weights(pres, type)
		cards.append(draw(w0, rng))
	# guaranteed (last) slot
	var gmin := guaranteed_min(type, pres)
	if e_in and int(pity.get("since_epic", 0)) + 1 >= int(EconData.PITY["epic"]) \
			and ArsenalData.rarity_index(gmin) < ArsenalData.rarity_index("E"):
		gmin = "E"
	var w := slot_weights(pres, type, gmin)
	if l_in:
		var n := int(pity.get("since_leg", 0)) + 1
		if not bool(pity.get("leg_welcome_done", false)) or n >= int(EconData.PITY["leg_hard"]):
			w = {"L": 1.0}
		elif n >= int(EconData.PITY["leg_soft"]):
			var target := minf(1.0, float(EconData.PITY["leg_soft_step"]) * float(n - int(EconData.PITY["leg_soft"]) + 1))
			var tot := 0.0
			for r: String in w:
				tot += float(w[r])
			if float(w.get("L", 0.0)) / tot < target:
				var rest := tot - float(w.get("L", 0.0))
				var w2 := {}
				for r2: String in w:
					w2[r2] = target if r2 == "L" else float(w[r2]) / rest * (1.0 - target)
				w = w2
	cards.append(draw(w, rng))
	var best := best_of(cards)
	if e_in:
		pity["since_epic"] = 0 if ArsenalData.rarity_index(best) >= ArsenalData.rarity_index("E") else int(pity.get("since_epic", 0)) + 1
	if l_in:
		pity["since_leg"] = 0 if ArsenalData.rarity_index(best) >= ArsenalData.rarity_index("L") else int(pity.get("since_leg", 0)) + 1
		pity["leg_welcome_done"] = true
	var wild: Array[bool] = []
	for _r in cards:
		wild.append(bool(ArsenalData.FEATURES.get("wild", true)) and rng.randf() < EconData.WILD_CARD_CHANCE)
	return {"rarities": cards, "wild": wild, "best": best, "pity_after": pity.duplicate()}


## sim: _draw — weighted pick in dictionary order.
static func draw(w: Dictionary, rng: RandomNumberGenerator) -> String:
	var tot := 0.0
	for k in w:
		tot += float(w[k])
	var x := rng.randf() * tot
	var last := ""
	for k2 in w:
		x -= float(w[k2])
		last = str(k2)
		if x <= 0.0:
			return last
	return last


static func best_of(rars: Array[String]) -> String:
	var best := "C"
	for r in rars:
		if ArsenalData.rarity_index(r) > ArsenalData.rarity_index(best):
			best = r
	return best


## Machines a Cache card may hold: live machines whose home world is reached + forged Mythics.
static func pool(acc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var w := MetaAcc.world(acc)
	for id in ArsenalData.ORDER:
		if not ArsenalData.is_live(id):
			continue
		var m: Dictionary = ArsenalData.MACHINES[id]
		if str(m["rarity"]) == "M":
			if MetaAcc.owned(acc, id):
				out.append(id)
		elif int(m["home"]) >= 1 and int(m["home"]) <= w:
			out.append(id)
	return out


## Grants rolled `rarities` (with per-slot `wild` flags) to the account and returns the card
## entries of §6.6 in slot order (the last one flagged `guaranteed`).
static func grant(acc: Dictionary, rarities: Array[String], pl: Array[String], rng: RandomNumberGenerator,
		wild: Array[bool] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in rarities.size():
		var c := grant_card(acc, rarities[i], pl, rng, i < wild.size() and wild[i])
		c["guaranteed"] = i == rarities.size() - 1
		out.append(c)
	return out


## sim: _grant_card. One card of rarity `r` (machine choice, stack, unlock, Lv15 overflow).
static func grant_card(acc: Dictionary, r: String, pl: Array[String], rng: RandomNumberGenerator, is_wild: bool,
		force_id := "", force_n := 0) -> Dictionary:
	if is_wild:
		MetaAcc.add(acc, "wild_" + r, 1)
		MetaAcc.count(acc, "wild_cards", 1)
		return {"rarity": r, "id": "", "count": 1, "wild": true, "new": false, "lvl": 0, "bp_before": 0,
				"bp_after": 0, "bp_need": 0, "upgradable": false, "to_wild": 0}
	var cands: Array[String] = []
	for id in pl:
		if ArsenalData.rarity_of(id) == r:
			cands.append(id)
	if force_id != "":
		cands = [force_id]
	if cands.is_empty():
		return {"rarity": r, "id": "", "count": 0, "wild": false, "new": false, "lvl": 0, "bp_before": 0,
				"bp_after": 0, "bp_need": 0, "upgradable": false, "to_wild": 0}
	var unowned: Array[String] = []
	for id2 in cands:
		if not MetaAcc.owned(acc, id2):
			unowned.append(id2)
	var mid := ""
	if r in ["L", "M"] and not unowned.is_empty():
		mid = unowned[rng.randi_range(0, unowned.size() - 1)]          # duplicate protection
	elif cands.size() == 1:
		mid = cands[0]
	else:
		var f := Arsenal.focus(acc)
		if f != "" and cands.has(f) and rng.randf() < EconData.FOCUS_SHARE:
			mid = f
		else:
			var d := Arsenal.deck(acc)
			var w := {}
			for id3 in cands:
				w[id3] = EconData.DECK_WEIGHT if d.has(id3) else 1.0
			mid = draw(w, rng)
	var st_range: Array = EconData.STACK[r]
	var n := force_n if force_n > 0 else rng.randi_range(int(st_range[0]), int(st_range[1]))
	var is_new := false
	if not MetaAcc.owned(acc, mid):
		Arsenal.unlock(acc, mid, "cache")
		is_new = true
		n -= 1
	var st: Dictionary = MetaAcc.machines(acc)[mid]
	var before := int(st["bp"])
	var to_wild := 0
	if int(st["lvl"]) >= ArsenalData.MAX_LEVEL:
		to_wild = maxi(n, 0)
		MetaAcc.add(acc, "wild_" + r, to_wild)
	else:
		st["bp"] = before + maxi(n, 0)
	if r == "L":
		MetaAcc.count(acc, "legendary_cards", 1)
	return {"rarity": r, "id": mid, "count": maxi(n, 0) + (1 if is_new else 0), "wild": false, "new": is_new,
			"lvl": int(st["lvl"]), "bp_before": before, "bp_after": int(st["bp"]),
			"bp_need": EconData.bp_to(r, int(st["lvl"]) + 1), "upgradable": bool(Arsenal.cost(acc, mid)["can"]),
			"to_wild": to_wild}


## Rolls, grants and books one Cache of `type` on the account: the §6.6 reveal bundle
## {type, source, best, altar, coins, pity_before, pity_after, pity_left, cards (ascending), scripted}.
## The first Stone Cache of a World-1 account is the scripted one (§4.6: Ballista + Drone).
static func open(acc: Dictionary, type: String, source: String, rng: RandomNumberGenerator) -> Dictionary:
	var g: Dictionary = EconData.CACHES[type]
	var pl := pool(acc)
	var pity: Dictionary = acc["pity"]
	var pity_before := pity.duplicate()
	var rolled := roll(type, pl, pity, rng)
	var rars: Array[String] = rolled["rarities"]
	var wild: Array[bool] = rolled["wild"]
	var vd: Dictionary = acc["vault"]
	var un: Dictionary = acc["unlocks"]
	var scripted := type == "stone" and int(vd.get("stone_total", 0)) == 0 and not bool(un.get("scripted_done", false)) \
			and MetaAcc.world(acc) == 1
	var cards: Array[Dictionary] = []
	if scripted:
		un["scripted_done"] = true
		var fixed: Array[String] = []
		for id in ["ballista", "drone"]:
			if MetaAcc.owned(acc, id) and pl.has(id):
				fixed.append(id)
		for i in rars.size():
			var c: Dictionary
			if i < fixed.size() and i < rars.size() - 1:
				rars[i] = "C"
				c = grant_card(acc, "C", pl, rng, false, fixed[i], 3)
			else:
				c = grant_card(acc, rars[i], pl, rng, i < wild.size() and wild[i])
			c["guaranteed"] = i == rars.size() - 1
			cards.append(c)
	else:
		cards = grant(acc, rars, pl, rng, wild)
	var best := best_of(rars)
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return ArsenalData.rarity_index(str(a["rarity"])) < ArsenalData.rarity_index(str(b["rarity"])))
	var coins := EconData.cache_coins(type, MetaAcc.level(acc))
	MetaAcc.add(acc, "coins", coins)
	if type == "stone":
		vd["stone_total"] = int(vd.get("stone_total", 0)) + 1
	MetaAcc.count(acc, "caches_opened", 1)
	return {"type": type, "source": source, "best": best, "cards": cards, "coins": coins,
			"pity_before": pity_before, "pity_after": pity.duplicate(), "pity_left": pity_left(present(pl, "stone"), pity),
			"altar": bool(g.get("altar", false)), "scripted": scripted}


## Caches until a guaranteed Legendary (the Altar bar); -1 while no Legendary is in the pool.
static func pity_left(pres: Array[String], pity: Dictionary) -> int:
	if not pres.has("L"):
		return -1
	if not bool(pity.get("leg_welcome_done", false)):
		return 1
	return maxi(1, int(EconData.PITY["leg_hard"]) - int(pity.get("since_leg", 0)))


## The (i) screen for `type` and the rarities `pres` (§6.7): exact per-card, guaranteed-slot and
## best-card probabilities (no pity active; sim exact_best_table / per_card_table).
static func odds(type: String, pres: Array[String], pity: Dictionary = {}) -> Dictionary:
	var g: Dictionary = EconData.CACHES[type]
	var free := norm(slot_weights(pres, type))
	var guar := norm(slot_weights(pres, type, guaranteed_min(type, pres)))
	var best := {}
	var prev := 0.0
	var cf := 0.0
	var cg := 0.0
	for r in ArsenalData.RARITY_ORDER:
		cf += float(free.get(r, 0.0))
		cg += float(guar.get(r, 0.0))
		var big_f := pow(minf(cf, 1.0), float(int(g["slots"]) - 1)) * minf(cg, 1.0)
		if pres.has(r):
			best[r] = maxf(big_f - prev, 0.0)
		prev = big_f
	return {"type": type, "present": pres, "per_card": free, "guaranteed": guar, "best": best,
			"pity_left": pity_left(pres, pity) if not pity.is_empty() else (-1 if not pres.has("L") else int(EconData.PITY["leg_hard"])),
			"stack": EconData.STACK, "wild": EconData.WILD_CARD_CHANCE if bool(ArsenalData.FEATURES.get("wild", true)) else 0.0,
			"focus": EconData.FOCUS_SHARE, "deck": EconData.DECK_WEIGHT, "slots": int(g["slots"]),
			"pity": {"epic": int(EconData.PITY["epic"]), "leg_soft": int(EconData.PITY["leg_soft"]),
					"leg_hard": int(EconData.PITY["leg_hard"]), "leg_soft_step": float(EconData.PITY["leg_soft_step"])}}


static func norm(w: Dictionary) -> Dictionary:
	var tot := 0.0
	for r in w:
		tot += float(w[r])
	var out := {}
	for r2 in w:
		out[r2] = float(w[r2]) / maxf(tot, 1e-9)
	return out
