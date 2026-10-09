class_name SaveMigrate
## Save v3 rules over the account dictionary (heroes_design.md §12.1, §12.3). Pure and static
## (account first, no Save / Meta access) so tests drive them directly.
##
## Two steps, both idempotent:
## - migrate_v2(acc, now_s, live): the schema step. A v2 account (already read over the v3
##   EconData.fresh_account() defaults by Save.account_from_cfg, so every Meta-1 key is kept) is
##   stamped version 3 with a marker {from 2, level, t}. Nothing is granted or removed. With
##   `live` it runs update_day() right away.
## - update_day(acc, now_s): the conversion of §12.3 steps 2-4, run ONCE when the hero systems go
##   live for this account (EconData.heroes_live(); the build that turns H3 on). It works from the
##   frontier of that day, so a player who keeps playing a flag-off build is still paid for every
##   level played before the systems open (no catch-up gating, critique E08):
##     heroes a v2 player had met (EconData.HERO_UNLOCK_V2: the Seer from the L5 win) become owned
##     (via "migration"); lvl kept; gem = native; Ult rank from the Meta-1 level ranks capped at
##     skill_cap(n, n, 0), the ranks above it refunded as Tomes; Attack = Rally = 1; native
##     Amethyst+ born awakened (BORN_AWAKENED_MIN: the Seer gets Awakening rank 1); Glory above 1 -> Star Ore owed at the Workshop unlock;
##     lump grant at frontier L (Beacons, Hero Chests + Grand Hero Chests into vault.hero_chests,
##     Tomes, Champion Level); the one-time MIGRATION_HEROES_CARD; telemetry `migration`.
## sanitize_v3(acc) repairs the v3 sections on every load (unknown ids -> _orphans, nested keys
## filled, gem clamped to [native, max gem], facets 0..5, ranks clamped to their caps,
## skills_peak >= skills).
##
## Account keys written: meta {version 3, v3_from {from, level, t}, v3_live (unix s, 0 = not yet),
## v3_grant {...}, max_day_seen}, unlocks {cards += MIGRATION_HEROES_CARD, heroes_migrated_level},
## wallet {beacons, tomes, ore, *_charge}, heroes, champions, team, summon, chests, workshop,
## vault.hero_chests, _orphans.

const VERSION := 3
const CARD := "MIGRATION_HEROES_CARD"
const VIA: Array[String] = ["start", "progress", "portal", "seal", "chest", "migration", "guest"]
const SKILLS: Array[String] = ["ult", "attack", "rally", "awakened"]
const GEAR_SLOTS: Array[String] = ["weapon", "armour", "charm"]
const CHEST_TYPES: Array[String] = ["hero_chest", "grand_hero_chest"]
const HISTORY_MAX := 100
const TEAM_PRESETS := 3
const TEAM_MAX := 3
const SCRIPTED_MAX := 2
const DAY_S := 86400


# ======================================================================== schema step

## v2 (or a migrated v1) account -> v3. Returns true when it changed the account (false = already v3).
static func migrate_v2(acc: Dictionary, now_s := 0, live := false) -> bool:
	var m: Dictionary = acc["meta"]
	if m.get("v3_from") is Dictionary and int(m.get("version", 0)) >= VERSION:
		if live:
			update_day(acc, now_s)
		return false
	sanitize_v3(acc)
	m["version"] = VERSION
	m["v3_from"] = {"from": 2, "level": MetaAcc.level(acc), "t": now_s}
	if not m.has("v3_live"):
		m["v3_live"] = 0
	see_day(acc, now_s)
	if live:
		update_day(acc, now_s)
	return true


# ======================================================================== update day (§12.3 2-4)

## The one-time conversion when the hero systems go live. Returns the grant summary
## ({} when it already ran for this account).
static func update_day(acc: Dictionary, now_s := 0) -> Dictionary:
	var m: Dictionary = acc["meta"]
	if int(m.get("v3_live", 0)) != 0:
		return {}
	sanitize_v3(acc)
	var t := now_s if now_s > 0 else 1
	var level := MetaAcc.level(acc)
	var w: Dictionary = acc["wallet"]
	var hs: Dictionary = acc["heroes"]
	# 2. Heroes a v2 player had met stay (and become) owned.
	for id: String in EconData.HERO_UNLOCK_V2:
		var at := int(EconData.HERO_UNLOCK_V2[id])
		var met := at == 0 or (at > 0 and level > at)
		if not hs.has(id):
			hs[id] = EconData.new_hero_state(id)
		var h: Dictionary = hs[id]
		if met and not bool(h["owned"]):
			h["owned"] = true
			h["got"] = {"t": t, "via": "migration"}
	var refund := 0
	var ore := 0
	for id2: String in hs:
		var h2: Dictionary = hs[id2]
		if not bool(h2["owned"]):
			continue
		var n := native_index(id2)
		h2["gem"] = SaveV3Data.GEMS[maxi(n, gem_index(str(h2["gem"])))]
		var sk: Dictionary = h2["skills"]
		var r_v2 := EconData.hero_ult_rank(int(h2["lvl"]))
		var cap := skill_cap(n, n, 0)
		sk["ult"] = maxi(int(sk["ult"]), mini(maxi(1, r_v2), cap))
		for r in range(cap, r_v2):
			refund += tome_cost(r)
		sk["attack"] = maxi(1, int(sk["attack"]))
		sk["rally"] = maxi(1, int(sk["rally"]))
		if born_awakened(n):
			sk["awakened"] = maxi(1, int(sk["awakened"]))
		_peak(h2)
		ore += SaveV3Data.ORE_PER_GLORY_STEP * maxi(0, int(h2.get("glory", 1)) - 1)
		h2["seen"] = true
	MetaAcc.add(acc, "tomes", refund)
	var ws: Dictionary = acc["workshop"]
	ws["migration_ore"] = int(ws.get("migration_ore", 0)) + ore
	# 3. Lump grant at frontier L.
	var g := lump_grant(level, MetaAcc.world(acc))
	MetaAcc.add(acc, "beacons", int(g["beacons"]))
	MetaAcc.add(acc, "tomes", int(g["tomes"]))
	var chests: Array = (acc["vault"] as Dictionary)["hero_chests"]
	for i in int(g["hero_chests"]):
		chests.append({"type": "hero_chest", "source": "migration", "level": int(g["frontier"])})
	for i2 in int(g["grand_hero_chests"]):
		chests.append({"type": "grand_hero_chest", "source": "migration", "level": int(g["frontier"])})
	var ch: Dictionary = acc["champions"]
	ch["level"] = maxi(int(ch["level"]), int(g["champion_level"]))
	# Team: the hero picked for runs leads the team.
	var team: Dictionary = acc["team"]
	var cur := str((acc["progress"] as Dictionary).get("hero", "bolt"))
	if hs.has(cur) and bool((hs[cur] as Dictionary)["owned"]):
		team["hero"] = cur
	# 4. One summary card; every passed unlock opens on update day (UnlockQueue reads
	# unlocks.heroes_migrated_level from H1 on).
	var summary := g.duplicate()
	summary["tomes_refund"] = refund
	summary["ore_owed"] = ore
	summary["t"] = t
	m["v3_grant"] = summary
	m["v3_live"] = t
	var un: Dictionary = acc["unlocks"]
	if int(g["frontier"]) > 0:
		un["heroes_migrated_level"] = level
		if not un.get("cards") is Array:
			un["cards"] = []
		if not (un["cards"] as Array).has(CARD):
			(un["cards"] as Array).append(CARD)
	see_day(acc, now_s)
	MetaTelemetry.note(acc, "migration", {"from_level": int(g["frontier"]), "grant": summary}, t)
	return summary


## What the content up to frontier L (= next level - 1) would have paid since each unlock row
## (heroes_sim.migrate_grant): {frontier, beacons, hero_chests, grand_hero_chests, tomes,
## champion_level}.
static func lump_grant(next_level: int, world_reached: int) -> Dictionary:
	var L := maxi(0, next_level - SaveV3Data.FRONTIER_OFFSET)
	var u: Dictionary = SaveV3Data.UNLOCK_AT
	var beacons := mini(SaveV3Data.BEACON_CAP, int(SaveV3Data.BEACON_FIRST_CLEAR * float(maxi(0, L - int(u["portal"])))
			+ float(SaveV3Data.BEACON_BOSS * bosses_after(int(u["portal"]), L))))
	var hero_chests := mini(SaveV3Data.HERO_CHEST_CAP, maxi(0, (L - int(u["champions"])) / SaveV3Data.HERO_CHEST_EVERY))
	var grand := bosses_after(int(u["champions"]), L)
	var tomes := SaveV3Data.TOMES_BOSS * bosses_after(int(u["skills"]), L)
	var table: Array[int] = SaveV3Data.EXPECTED_CHAMPION_LEVEL
	var target := table[clampi(L, 0, table.size() - 1)]
	var cap := SaveV3Data.CHAMP_LEVEL_MAX if next_level > SaveV3Data.CAMPAIGN_LEVELS \
			else mini(SaveV3Data.CHAMP_LEVEL_MAX, 2 + 2 * world_reached)
	return {"frontier": L, "beacons": beacons, "hero_chests": hero_chests, "grand_hero_chests": grand, "tomes": tomes,
			"champion_level": maxi(1, mini(cap, target))}


## World bosses b with after < b <= L.
static func bosses_after(after: int, L: int) -> int:
	var n := 0
	for b in SaveV3Data.BOSS_LEVELS:
		if b > after and b <= L:
			n += 1
	return n


## Highest unix day seen (the monotonic day guard): never moves back with the device clock.
static func see_day(acc: Dictionary, now_s: int) -> int:
	var m: Dictionary = acc["meta"]
	var d := maxi(int(m.get("max_day_seen", 0)), maxi(0, now_s) / DAY_S)
	m["max_day_seen"] = d
	return d


# ======================================================================== ladder helpers (save side)

static func gem_index(g: String) -> int:
	return maxi(0, SaveV3Data.GEMS.find(g))


static func native_index(id: String) -> int:
	return gem_index(str(SaveV3Data.HERO_NATIVE.get(id, "C")))


## F-CAP: SKILL_BASE[g] - [g > n] + [facets = 5] (same formula as Ladder.skill_cap, §1.4).
static func skill_cap(n: int, g: int, facets: int) -> int:
	return SaveV3Data.SKILL_BASE[clampi(g, 0, 4)] - (1 if g > n else 0) + (1 if facets >= SaveV3Data.FACETS_PER_GEM else 0)


## Awakening cap: 0 below AWAKEN_MIN_GEM, else AWAKEN_CAP[g] - [g > n] (F-AWK2).
static func awaken_cap(n: int, g: int) -> int:
	if g < gem_index(SaveV3Data.AWAKEN_MIN_GEM):
		return 0
	return int(SaveV3Data.AWAKEN_CAP.get(SaveV3Data.GEMS[g], 0)) - (1 if g > n else 0)


static func born_awakened(n: int) -> bool:
	return n >= gem_index(SaveV3Data.BORN_AWAKENED_MIN)


## Tomes for skill rank r -> r + 1 (the last price repeats past the table).
static func tome_cost(r: int) -> int:
	var t: Array[int] = SaveV3Data.TOME_COST
	return t[clampi(r, 0, t.size() - 1)]


# ======================================================================== sanitize

## Repairs every v3 section in place (run by Save.sanitize on every load).
static func sanitize_v3(acc: Dictionary) -> void:
	var tmpl := EconData.fresh_account()
	for section in ["champions", "team", "summon", "chests", "workshop", "_orphans"]:
		if not acc.get(section) is Dictionary:
			acc[section] = tmpl[section]
		_fill(acc[section], tmpl[section])
	var m: Dictionary = acc["meta"]
	m["max_day_seen"] = maxi(0, int(m.get("max_day_seen", 0)) if _num(m.get("max_day_seen")) else 0)
	var w: Dictionary = acc["wallet"]
	for c in ["beacons", "tomes", "ore"]:
		w[c] = maxi(0, int(w.get(c, 0)) if _num(w.get(c)) else 0)
	for c2 in ["beacon_charge", "chest_charge", "ore_charge"]:
		w[c2] = maxf(0.0, float(w.get(c2, 0.0)) if _num(w.get(c2)) else 0.0)
	var v: Dictionary = acc["vault"]
	var hc: Array = []
	if v.get("hero_chests") is Array:
		for c3 in v["hero_chests"]:
			if c3 is Dictionary and str((c3 as Dictionary).get("type", "")) in CHEST_TYPES:
				hc.append(c3)
	v["hero_chests"] = hc
	_sanitize_heroes(acc)
	_sanitize_champions(acc)
	_sanitize_team(acc)
	var su: Dictionary = acc["summon"]
	for k in ["seals", "since_e", "since_l", "total"]:
		su[k] = maxi(0, int(su[k]))
	su["focus"] = _str_dict(su["focus"])
	var hist: Array = su["history"]
	while hist.size() > HISTORY_MAX:
		hist.remove_at(0)
	var cs: Dictionary = acc["chests"]
	for k2 in ["since_l", "total"]:
		cs[k2] = maxi(0, int(cs[k2]))
	cs["scripted"] = clampi(int(cs["scripted"]), 0, SCRIPTED_MAX)
	cs["focus"] = _str_dict(cs["focus"])
	var ws: Dictionary = acc["workshop"]
	for k3 in ["items", "relics"]:
		var clean := {}
		for id in (ws[k3] as Dictionary):
			clean[str(id)] = maxi(0, int((ws[k3] as Dictionary)[id]) if _num((ws[k3] as Dictionary)[id]) else 0)
		ws[k3] = clean
	var tr: Array = []
	for b in (ws["trophies"] as Array):
		if _num(b) and not tr.has(int(b)):
			tr.append(int(b))
	ws["trophies"] = tr
	ws["migration_ore"] = maxi(0, int(ws["migration_ore"]))


## §9.6 orphans are never deleted: an entry an older build parked in `_orphans` (an id it did not know yet, e.g. a
## champion added after launch) comes back when this build knows the id again. Only Dictionary entries whose id is
## not already in `section` are moved back; anything else stays parked.
static func _restore_orphans(section: Dictionary, orphans: Dictionary, known: Dictionary) -> void:
	for id in orphans.keys():
		var sid := str(id)
		if known.has(sid) and orphans[id] is Dictionary and not section.has(sid):
			section[sid] = orphans[id]
			orphans.erase(id)


static func _sanitize_heroes(acc: Dictionary) -> void:
	if not acc.get("heroes") is Dictionary:
		acc["heroes"] = {}
	var hs: Dictionary = acc["heroes"]
	var orphans: Dictionary = (acc["_orphans"] as Dictionary)["heroes"]
	_restore_orphans(hs, orphans, SaveV3Data.HERO_NATIVE)
	for id in hs.keys():
		var sid := str(id)
		if not SaveV3Data.HERO_NATIVE.has(sid) or not hs[id] is Dictionary:
			orphans[sid] = hs[id]
			hs.erase(id)
			continue
		if not id is String:
			hs[sid] = hs[id]
			hs.erase(id)
	for s in SaveV3Data.STARTERS:
		if not hs.has(s):
			hs[s] = EconData.new_hero_state(s, SaveV3Data.START_OWNED.has(s), "start" if SaveV3Data.START_OWNED.has(s) else "")
	for id2: String in hs:
		var h: Dictionary = hs[id2]
		var base := EconData.new_hero_state(id2, SaveV3Data.START_OWNED.has(id2), "start" if SaveV3Data.START_OWNED.has(id2) else "")
		_fill(h, base)
		h["lvl"] = clampi(int(h["lvl"]), 1, int(EconData.HERO["max"]))
		var n := native_index(id2)
		var g := clampi(maxi(n, SaveV3Data.GEMS.find(str(h["gem"]))), n, gem_index(SaveV3Data.HERO_MAX_GEM))
		h["gem"] = SaveV3Data.GEMS[g]
		h["facets"] = clampi(int(h["facets"]), 0, SaveV3Data.FACETS_PER_GEM)
		h["frags"] = maxi(0, int(h["frags"]))
		h["chronicle"] = clampi(int(h["chronicle"]), 0, 5)
		var sk: Dictionary = h["skills"]
		var cap := skill_cap(n, g, int(h["facets"]))
		for k in ["ult", "attack", "rally"]:
			sk[k] = clampi(int(sk[k]), 1, cap)
		var acap := awaken_cap(n, g)
		sk["awakened"] = clampi(int(sk["awakened"]), 1 if born_awakened(n) else 0, maxi(acap, 1 if born_awakened(n) else 0))
		_peak(h)
		# skills_paid {skill: [ranks bought, Tomes paid]} (Rewrite refunds exactly what was paid):
		# never more bought ranks than the skill holds above its base.
		var sp: Dictionary = h["skills_paid"]
		for k2 in SKILLS:
			var row: Variant = sp.get(k2)
			var floor_r := 0 if k2 == "awakened" and int(sk["awakened"]) == 0 else 1
			if not row is Array or (row as Array).size() != 2 or not _num((row as Array)[0]) or not _num((row as Array)[1]):
				sp[k2] = [0, 0]
				continue
			sp[k2] = [clampi(int((row as Array)[0]), 0, maxi(0, int(sk[k2]) - floor_r)), maxi(0, int((row as Array)[1]))]
		var lo: Dictionary = h["loadout"]
		for slot in GEAR_SLOTS:
			lo[slot] = str(lo[slot]) if lo[slot] != null else ""
		var got: Dictionary = h["got"]
		got["t"] = maxi(0, int(got["t"]))
		if not str(got["via"]) in VIA:
			got["via"] = ""


static func _sanitize_champions(acc: Dictionary) -> void:
	var ch: Dictionary = acc["champions"]
	ch["level"] = clampi(int(ch["level"]), 1, SaveV3Data.CHAMP_LEVEL_MAX)
	var ro: Dictionary = ch["roster"]
	var orphans: Dictionary = (acc["_orphans"] as Dictionary)["champions"]
	_restore_orphans(ro, orphans, SaveV3Data.CHAMPION_NATIVE)
	for id in ro.keys():
		var sid := str(id)
		if not SaveV3Data.CHAMPION_NATIVE.has(sid) or not ro[id] is Dictionary:
			orphans[sid] = ro[id]
			ro.erase(id)
	for id2: String in ro:
		var c: Dictionary = ro[id2]
		_fill(c, EconData.new_champion_state(id2))
		var n := gem_index(str(SaveV3Data.CHAMPION_NATIVE[id2]))
		c["gem"] = SaveV3Data.GEMS[clampi(SaveV3Data.GEMS.find(str(c["gem"])), n, gem_index(SaveV3Data.CHAMPION_MAX_GEM))]
		c["facets"] = clampi(int(c["facets"]), 0, SaveV3Data.FACETS_PER_GEM)
		c["frags"] = maxi(0, int(c["frags"]))
		var got: Dictionary = c["got"]
		got["t"] = maxi(0, int(got["t"]))
		if not str(got["via"]) in VIA:
			got["via"] = ""


static func _sanitize_team(acc: Dictionary) -> void:
	var team: Dictionary = acc["team"]
	var hs: Dictionary = acc["heroes"]
	if not hs.has(str(team["hero"])):
		team["hero"] = "bolt"
	team["hero"] = str(team["hero"])
	team["champions"] = _champ_list(team["champions"])
	var presets: Array = []
	for p in (team["presets"] as Array):
		if presets.size() >= TEAM_PRESETS:
			break
		var pd: Dictionary = p if p is Dictionary else {}
		var ph := str(pd.get("hero", ""))
		presets.append({"hero": ph if hs.has(ph) else "", "champions": _champ_list(pd.get("champions", []))})
	while presets.size() < TEAM_PRESETS:
		presets.append({"hero": "", "champions": []})
	team["presets"] = presets
	team["preset"] = clampi(int(team["preset"]), 0, TEAM_PRESETS - 1)


static func _champ_list(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for id in v:
			if SaveV3Data.CHAMPION_NATIVE.has(str(id)) and not out.has(str(id)) and out.size() < TEAM_MAX:
				out.append(str(id))
	return out


## skills_peak >= skills, key by key.
static func _peak(h: Dictionary) -> void:
	var sk: Dictionary = h["skills"]
	var pk: Dictionary = h["skills_peak"]
	for k in SKILLS:
		pk[k] = maxi(int(pk.get(k, 0)) if _num(pk.get(k)) else 0, int(sk[k]))


## Fills `d` with every key of `base` (recursively for dictionaries); a value of an incompatible
## type takes the default. Extra keys are kept (forward compatibility).
static func _fill(d: Dictionary, base: Dictionary) -> void:
	for k in base:
		var bv: Variant = base[k]
		if not d.has(k):
			d[k] = bv.duplicate(true) if bv is Dictionary or bv is Array else bv
			continue
		var v: Variant = d[k]
		if bv is Dictionary:
			if v is Dictionary:
				if not (bv as Dictionary).is_empty():
					_fill(v, bv)
			else:
				d[k] = (bv as Dictionary).duplicate(true)
		elif bv is Array:
			if not v is Array:
				d[k] = (bv as Array).duplicate(true)
		elif typeof(bv) == TYPE_INT:
			d[k] = int(v) if _num(v) else bv
		elif typeof(bv) == TYPE_FLOAT:
			d[k] = float(v) if _num(v) else bv
		elif typeof(bv) == TYPE_BOOL:
			d[k] = bool(v) if _num(v) else bv
		elif typeof(bv) == TYPE_STRING:
			d[k] = str(v) if v is String or v is StringName else bv


static func _num(v: Variant) -> bool:
	return v is int or v is float or v is bool


static func _str_dict(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in (v as Dictionary):
			out[str(k)] = str((v as Dictionary)[k])
	return out
