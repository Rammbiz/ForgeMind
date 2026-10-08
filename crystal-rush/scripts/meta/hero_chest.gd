class_name HeroChest
## «Скриня героїв / Hero Chest» and «Велика скриня героїв / Grand Hero Chest» (heroes_design.md
## §7.5; WS-A rules) — a port of heroes_sim.py roll_chest / open_chest / pick_champ. Earned only:
## Hero Chests fill by wins (chest_charge += CHEST_CHARGE_PER_WIN), Grand ones come from world-boss
## first clears, weekly 5/5 and Expedition 5/5 (Rewards / Vault, WS-B, decide where a chest goes).
##
## A chest holds CHEST_CARDS[kind] champion cards (each gem by CHEST_ODDS; the Grand chest's last card
## among GRAND_LAST_CARD_MIN+; a Topaz card certain on the CHEST_PITY_L-th chest without one, both
## kinds counting), one hero-fragment card for an owned hero (the team hero at CHEST_TEAM_HERO_WEIGHT;
## round(CHEST_HERO_CARD x DUP) fragments, x CHEST_HERO_FRAG_MULT in a Grand chest) and, in a Grand
## chest after the skills unlock, CHEST_TOMES Tomes. Inside a gem: an unowned champion first, then
## the chest Focus exactly CHEST_FOCUS_TOTAL (the others share the rest), else even shares.
## Scripted chests: the first chest ever opened holds SCRIPTED_FIRST[team hero] (else the default),
## the second SCRIPTED_SECOND; each takes one card slot (the other cards roll) and joins a free team
## slot. Every result is written to the account before this returns; `rng` = the account's stream.
##
## Account: chests {since_l, total, focus {gem: id}, scripted 0..2}, wallet {chest_charge, tomes}.
## `eligible` (optional): ids allowed as cards (HeroArt `complete`, WS-E); [] = every champion.

const KINDS: Array[String] = ["hero", "grand"]


static func is_open(acc: Dictionary) -> bool:
	return Roster.system_open(acc, "champions")


static func state(acc: Dictionary) -> Dictionary:
	return acc["chests"]


## Adds the charge of `wins` qualifying wins (the caller applies the replay rule: only the first
## CHEST_REPLAYS_PER_DAY replay wins a day). Returns the whole Hero Chests completed (taken off the
## charge); 0 before the champions unlock level (Roster.income_open, the rule Rewards uses; review F8).
static func add_charge(acc: Dictionary, wins := 1) -> int:
	if not Roster.income_open(acc, "champions") or wins <= 0:
		return 0
	var w: Dictionary = acc["wallet"]
	var ch := float(w.get("chest_charge", 0.0)) + PortalData.CHEST_CHARGE_PER_WIN * wins
	var whole := int(ch + 1e-9)
	w["chest_charge"] = maxf(0.0, ch - whole)
	return whole


# ------------------------------------------------------------------ cards

## Card gem weights at or above `min_gem` (CHEST_ODDS).
static func card_weights(min_gem := "C") -> Dictionary:
	var out := {}
	for g: String in PortalData.CHEST_ODDS:
		if Ladder.gem_index(g) >= Ladder.gem_index(min_gem):
			out[g] = float(PortalData.CHEST_ODDS[g])
	return out


## One card gem (sim chest_draw).
static func draw_gem(rng: RandomNumberGenerator, min_gem := "C") -> String:
	var w := card_weights(min_gem)
	var t := 0.0
	for g: String in w:
		t += float(w[g])
	var x := rng.randf() * t
	var last := ""
	for g2: String in w:
		x -= float(w[g2])
		last = g2
		if x <= 0.0:
			return g2
	return last


## The card gems of a chest of `kind` with `forced` card slots already taken (sim roll_chest): the
## free cards roll, the last one at the Grand minimum or the pity gem. `pity` {since_l, total} is
## NOT changed here (open() updates it from the cards actually given).
static func roll_gems(kind: String, pity: Dictionary, rng: RandomNumberGenerator, forced := 0) -> Array[String]:
	var n := int(PortalData.CHEST_CARDS[kind]) - forced
	var out: Array[String] = []
	for i in maxi(0, n - 1):
		out.append(draw_gem(rng))
	if n >= 1:
		var last_min := PortalData.GRAND_LAST_CARD_MIN if kind == "grand" else "C"
		if int(pity.get("since_l", 0)) + 1 >= PortalData.CHEST_PITY_L:
			last_min = PortalData.CHEST_PITY_GEM
		out.append(draw_gem(rng, last_min))
	return out


## Champions of `gem` that can be cards (eligible ones).
static func pool(gem: String, eligible: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in ChampionData.CHAMPION_ORDER:
		if str(ChampionData.CHAMPIONS[id]["native"]) == gem and (eligible.is_empty() or eligible.has(id)):
			out.append(id)
	return out


## The chest Focus champion of `gem` ("" none).
static func focus(acc: Dictionary, gem: String, eligible: Array = []) -> String:
	var f := str((state(acc).get("focus", {}) as Dictionary).get(gem, ""))
	return f if pool(gem, eligible).has(f) else ""


## Sets (or clears with "") the chest Focus of `gem`.
static func set_focus(acc: Dictionary, gem: String, id: String, eligible: Array = []) -> bool:
	var fd: Dictionary = state(acc)["focus"]
	if id == "":
		fd.erase(gem)
		return true
	if not pool(gem, eligible).has(id):
		return false
	fd[gem] = id
	return true


## Share of each champion inside a `gem` card now: unowned first (even), else Focus exactly
## CHEST_FOCUS_TOTAL and the rest even, else even. {id: p}.
static func champion_weights(acc: Dictionary, gem: String, eligible: Array = []) -> Dictionary:
	var p := pool(gem, eligible)
	var out := {}
	if p.is_empty():
		return out
	var un: Array[String] = []
	for id in p:
		if not Roster.owned(acc, id):
			un.append(id)
	if not un.is_empty():
		for id2 in p:
			out[id2] = 1.0 / un.size() if un.has(id2) else 0.0
		return out
	var f := focus(acc, gem, eligible)
	if f == "" or p.size() == 1:
		for id3 in p:
			out[id3] = 1.0 / p.size()
		return out
	for id4 in p:
		out[id4] = PortalData.CHEST_FOCUS_TOTAL if id4 == f else (1.0 - PortalData.CHEST_FOCUS_TOTAL) / (p.size() - 1)
	return out


## The champion of a `gem` card (sim pick_champ with the player's chest Focus).
static func pick_champion(acc: Dictionary, gem: String, rng: RandomNumberGenerator, eligible: Array = []) -> String:
	var w := champion_weights(acc, gem, eligible)
	if w.is_empty():
		return ""
	var x := rng.randf()
	var last := ""
	for id: String in w:
		if float(w[id]) <= 0.0:
			continue
		x -= float(w[id])
		last = id
		if x <= 0.0:
			return id
	return last


## The owned hero a hero-fragment card goes to (team hero at CHEST_TEAM_HERO_WEIGHT) and its
## fragments for a chest of `kind`: {id, frags}.
static func hero_card(acc: Dictionary, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var hs := Roster.owned_ids(acc, Roster.KIND_HERO)
	if hs.is_empty():
		return {"id": "", "frags": 0}
	var team_h := Team.hero(acc)
	var tot := 0
	for h in hs:
		tot += PortalData.CHEST_TEAM_HERO_WEIGHT if h == team_h else 1
	var x := rng.randi_range(1, tot)
	var pick := hs[hs.size() - 1]
	for h2 in hs:
		x -= PortalData.CHEST_TEAM_HERO_WEIGHT if h2 == team_h else 1
		if x <= 0:
			pick = h2
			break
	var fr := PortalData.CHEST_HERO_CARD_FRAGS[Ladder.gem_index(Roster.native(pick))] * int(PortalData.CHEST_HERO_FRAG_MULT[kind])
	return {"id": pick, "frags": fr}


## The scripted champion the next opened chest holds ("" once both scripted chests are done).
static func scripted_next(acc: Dictionary) -> String:
	match int(state(acc).get("scripted", 0)):
		0:
			return str(PortalData.SCRIPTED_FIRST.get(Team.hero(acc), PortalData.SCRIPTED_FIRST_DEFAULT))
		1:
			return PortalData.SCRIPTED_SECOND
	return ""


# ------------------------------------------------------------------ opening

## Opens one chest of `kind` ("hero" | "grand"). {ok, reason, kind, scripted (0 | 1 | 2 = which
## scripted chest this was), cards [{gem, id, new, frags, tomes, scripted}], hero_card {id, frags,
## tomes}, tomes (Grand), best (best card gem), new_ids [champions that joined]}.
static func open(acc: Dictionary, kind: String, rng: RandomNumberGenerator, now_s := 0, source := "",
		inline := true, eligible: Array = []) -> Dictionary:
	if not kind in KINDS:
		return {"ok": false, "reason": "kind", "kind": kind}
	if not is_open(acc):
		return {"ok": false, "reason": "locked", "kind": kind}
	var st := state(acc)
	var forced: Array[String] = []
	var scripted := 0
	var sc := scripted_next(acc)
	if sc != "" and (eligible.is_empty() or eligible.has(sc)):
		forced.append(sc)
		scripted = int(st.get("scripted", 0)) + 1
		st["scripted"] = scripted
	var gems := roll_gems(kind, st, rng, forced.size())
	var cards: Array[Dictionary] = []
	var new_ids: Array[String] = []
	var best := "C"
	var any_l := false
	for cid in forced:
		var gr := Roster.grant(acc, cid, "chest", now_s)
		cards.append({"gem": Roster.native(cid), "id": cid, "new": bool(gr["new"]), "frags": int(gr["frags"]),
				"tomes": int(gr["tomes"]), "scripted": true})
		if bool(gr["new"]):
			new_ids.append(cid)
			Team.place(acc, cid)
	for g0 in gems:
		# A gem with no eligible champion (HeroArt gating, review F6) gives its card from the nearest
		# lower gem that has one (else the nearest higher), so a chest never loses a card.
		var g := _gem_with_pool(g0, eligible)
		var id := pick_champion(acc, g, rng, eligible) if g != "" else ""
		if id == "":
			continue
		var gr2 := Roster.grant(acc, id, "chest", now_s)
		cards.append({"gem": g, "id": id, "new": bool(gr2["new"]), "frags": int(gr2["frags"]), "tomes": int(gr2["tomes"]),
				"scripted": false})
		if bool(gr2["new"]):
			new_ids.append(id)
	for c in cards:
		var cg := str(c["gem"])
		if Ladder.gem_index(cg) > Ladder.gem_index(best):
			best = cg
		any_l = any_l or cg == PortalData.CHEST_PITY_GEM
	st["since_l"] = 0 if any_l else int(st.get("since_l", 0)) + 1
	st["total"] = int(st.get("total", 0)) + 1
	var hc := hero_card(acc, kind, rng)
	var hc_tomes := 0
	if str(hc["id"]) != "":
		hc_tomes = int(Roster.add_frags(acc, str(hc["id"]), int(hc["frags"]), "chest")["tomes"])
	hc["tomes"] = hc_tomes
	var tomes := 0
	if Roster.income_open(acc, "skills"):          # level rule, not the session-paced row (review F8)
		var tr: Array = PortalData.CHEST_TOMES[kind]
		tomes = int(tr[0]) if int(tr[0]) == int(tr[1]) else rng.randi_range(int(tr[0]), int(tr[1]))
		MetaAcc.add(acc, "tomes", tomes)
	MetaAcc.count(acc, "hero_chests", 1)
	MetaTelemetry.note(acc, "chest", {"type": kind, "best": best, "scripted": scripted > 0, "inline": inline,
			"source": source}, now_s)
	return {"ok": true, "reason": "", "kind": kind, "scripted": scripted, "cards": cards, "hero_card": hc,
			"tomes": tomes, "best": best, "new_ids": new_ids}


## `gem` when its champion pool (filtered by `eligible`) is not empty, else the nearest lower gem
## with one, else the nearest higher; "" when no gem has any.
static func _gem_with_pool(gem: String, eligible: Array) -> String:
	if not pool(gem, eligible).is_empty():
		return gem
	var gi := Ladder.gem_index(gem)
	for d in range(1, Ladder.GEMS.size()):
		for gj in [gi - d, gi + d]:
			if gj >= 0 and gj < Ladder.GEMS.size() and PortalData.CHEST_ODDS.has(Ladder.GEMS[gj]) \
					and not pool(Ladder.GEMS[gj], eligible).is_empty():
				return Ladder.GEMS[gj]
	return ""


# ------------------------------------------------------------------ disclosure

## Exact best-card distribution of a chest of `kind` without pity (sim chest_exact_best). {gem: p}.
static func exact_best(kind: String) -> Dictionary:
	var free := _cdf("C")
	var last := _cdf(PortalData.GRAND_LAST_CARD_MIN if kind == "grand" else "C")
	var n := int(PortalData.CHEST_CARDS[kind])
	var out := {}
	var prev := 0.0
	for g: String in PortalData.CHEST_ODDS:
		var fb := pow(float(free[g]), n - 1) * float(last[g])
		out[g] = fb - prev
		prev = fb
	return out


static func _cdf(min_gem: String) -> Dictionary:
	var w := card_weights(min_gem)
	var t := 0.0
	for g: String in w:
		t += float(w[g])
	var acc_p := 0.0
	var out := {}
	for g2: String in PortalData.CHEST_ODDS:
		acc_p += float(w.get(g2, 0.0)) / t
		out[g2] = acc_p
	return out


## Per-champion chance that one free card is that champion now ((i) sheet): CHEST_ODDS[gem] x the
## in-gem share. {id: p}.
static func champion_odds(acc: Dictionary, eligible: Array = []) -> Dictionary:
	var out := {}
	for g: String in PortalData.CHEST_ODDS:
		var w := champion_weights(acc, g, eligible)
		for id: String in w:
			out[id] = float(PortalData.CHEST_ODDS[g]) * float(w[id])
	return out
