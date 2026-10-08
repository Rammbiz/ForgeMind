class_name Roster
## Characters on the account (heroes_design.md §3.2, §4.1, §7.4; WS-A rules): ownership, duplicate
## copies -> fragments, Facets («Грані», 0..5 per gem), Full facets («Повні грані»), Recut
## («Огранка», to the next gem) and overflow at the absolute max (fragments -> Tomes 20 : 1). One
## set of rules for heroes AND champions (champions reuse HeroData.PROGRESS; their recut stops at
## Ladder.CHAMPION_MAX_GEM). Pure and static, account first: callers (the Meta API) save the
## account after each call and before any ceremony plays.
##
## Account (Save v3, heroes_design.md §12.1):
##   heroes     {<id>: {owned, lvl, gem, facets, frags, skills {...}, skills_peak {...}, seen, got {t, via}, ...}}
##   champions  {level, roster {<id>: {owned, gem, facets, frags, seen, got {t, via}}}}
##   wallet     {tomes, ...}             counters {recuts, full_cuts, awakenings}   (Feats F-62 / F-63 / F-66)
## `native` is never saved: HeroData.HEROES[id].native / ChampionData.CHAMPIONS[id].native.
## Nothing in the shipped flow calls this class before EconData.HEROES_PHASE turns the systems on.

const KIND_HERO := "hero"
const KIND_CHAMPION := "champion"
## got.via values that count for the hero Feats (§3.6): every copy earned by play. "guest" never owns.
const EARNED_VIA: Array[String] = ["start", "progress", "portal", "seal", "chest", "migration"]
## Hero-system unlock ids (HeroData.UNLOCK_AT keys).
const SYSTEMS: Array[String] = ["champions", "portal", "seer", "skills", "workshop", "slot3"]


# ------------------------------------------------------------------ identity

## "hero" | "champion" | "" (unknown id).
static func kind_of(id: String) -> String:
	if HeroData.HEROES.has(id):
		return KIND_HERO
	if ChampionData.CHAMPIONS.has(id):
		return KIND_CHAMPION
	return ""


## The gem the character was born with ("" for an unknown id).
static func native(id: String) -> String:
	if HeroData.HEROES.has(id):
		return str(HeroData.HEROES[id]["native"])
	if ChampionData.CHAMPIONS.has(id):
		return str(ChampionData.CHAMPIONS[id]["native"])
	return ""


## Highest gem a recut can reach: Opal for heroes, Topaz for champions (§4.1).
static func max_gem(id: String) -> String:
	return Ladder.HERO_MAX_GEM if kind_of(id) == KIND_HERO else Ladder.CHAMPION_MAX_GEM


# ------------------------------------------------------------------ account state

## The saved entry of `id` ({} when the account has none yet).
static func entry(acc: Dictionary, id: String) -> Dictionary:
	match kind_of(id):
		KIND_HERO:
			return (acc.get("heroes", {}) as Dictionary).get(id, {})
		KIND_CHAMPION:
			return ((acc.get("champions", {}) as Dictionary).get("roster", {}) as Dictionary).get(id, {})
	return {}


## The saved entry of `id`, created (not owned) when missing.
static func ensure(acc: Dictionary, id: String) -> Dictionary:
	var e := entry(acc, id)
	if not e.is_empty():
		return e
	match kind_of(id):
		KIND_HERO:
			if not acc.get("heroes") is Dictionary:
				acc["heroes"] = {}
			e = EconData.new_hero_state(id)
			(acc["heroes"] as Dictionary)[id] = e
		KIND_CHAMPION:
			var ch: Dictionary = acc["champions"]
			if not ch.get("roster") is Dictionary:
				ch["roster"] = {}
			e = EconData.new_champion_state(id)
			(ch["roster"] as Dictionary)[id] = e
	return e


static func owned(acc: Dictionary, id: String) -> bool:
	return bool(entry(acc, id).get("owned", false))


## Owned ids of `kind` in collector order.
static func owned_ids(acc: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	var order: Array[String] = HeroData.HERO_ORDER if kind == KIND_HERO else ChampionData.CHAMPION_ORDER
	for id in order:
		if owned(acc, id):
			out.append(id)
	return out


## Current gem (the native gem when the entry is missing or invalid).
static func gem(acc: Dictionary, id: String) -> String:
	var g := str(entry(acc, id).get("gem", ""))
	var n := native(id)
	return g if Ladder.gem_index(g) >= Ladder.gem_index(n) else n


static func facets(acc: Dictionary, id: String) -> int:
	return clampi(int(entry(acc, id).get("facets", 0)), 0, Ladder.FACETS_PER_GEM)


static func frags(acc: Dictionary, id: String) -> int:
	return maxi(0, int(entry(acc, id).get("frags", 0)))


## B1 stat multiplier of the character's current state (§2.2).
static func mult(acc: Dictionary, id: String) -> float:
	return Ladder.mult(native(id), gem(acc, id), facets(acc, id))


## True for a character above its native gem (doublet emblem, ceilings printed).
static func is_recut(acc: Dictionary, id: String) -> bool:
	return Ladder.gem_index(gem(acc, id)) > Ladder.gem_index(native(id))


## The absolute max: the highest gem of its kind at Full facets. Fragments past it become Tomes.
static func at_max(acc: Dictionary, id: String) -> bool:
	return gem(acc, id) == max_gem(id) and facets(acc, id) == Ladder.FACETS_PER_GEM


## Last campaign level won (the "after_win" frontier of the unlock rows).
static func frontier(acc: Dictionary) -> int:
	return MetaAcc.level(acc) - 1


## A hero system (HeroData.UNLOCK_AT key) is open: through UnlockQueue once Save / Meta (WS-B) adds
## its row to EconData.UNLOCKS, by the level rule (after_win) until then.
## Income rule (review F8): a hero system pays its earned income (Beacons, chest charge, chest
## Tomes) once the frontier passed its unlock level (SaveV3Data.UNLOCK_AT; heroes_sim and the
## migration lump grant use the same rule). UnlockQueue only paces when its row and tutorial show.
static func income_open(acc: Dictionary, sys: String) -> bool:
	return MetaAcc.level(acc) > int(SaveV3Data.UNLOCK_AT[sys])


static func system_open(acc: Dictionary, sys: String) -> bool:
	if not EconData.unlock_entry(sys).is_empty():
		return UnlockQueue.is_open(acc, sys)
	return frontier(acc) >= int(HeroData.UNLOCK_AT.get(sys, 0))


# ------------------------------------------------------------------ grants

## One copy of `id` (Portal, Seal pick, chest card, progress, migration, start). A new character
## becomes owned at its native gem (a native Amethyst+ hero with Awakening rank 1, F-AWK2); a
## copy of an owned one gives DUP_FRAGS[native] fragments (overflow to Tomes at the absolute max).
## Returns {id, kind, new, gem, frags, tomes, awakened}.
static func grant(acc: Dictionary, id: String, via: String, now_s := 0) -> Dictionary:
	var kind := kind_of(id)
	var out := {"id": id, "kind": kind, "new": false, "gem": native(id), "frags": 0, "tomes": 0, "awakened": false}
	if kind == "":
		return out
	var e := ensure(acc, id)
	if bool(e.get("owned", false)):
		var add := add_frags(acc, id, HeroData.dup_frags(native(id)), via)
		out["frags"] = int(add["frags"])
		out["tomes"] = int(add["tomes"])
		return out
	e["owned"] = true
	e["gem"] = gem(acc, id)
	e["facets"] = facets(acc, id)
	e["frags"] = frags(acc, id)
	e["seen"] = false
	e["got"] = {"t": maxi(0, now_s), "via": via}
	out["new"] = true
	if kind == KIND_HERO and Ladder.born_awakened(native(id)):
		var sk: Dictionary = e["skills"]
		if int(sk.get("awakened", 0)) < 1:
			sk["awakened"] = 1
		sync_peak(e)
		MetaAcc.count(acc, "awakenings", 1)
		MetaTelemetry.note(acc, "awaken", {"id": id, "born": true}, now_s)
		out["awakened"] = true
	return out


## Adds `n` fragments to an owned character; at the absolute max they turn into Tomes at once.
## Returns {frags (added), tomes (from overflow)}.
static func add_frags(acc: Dictionary, id: String, n: int, _via := "") -> Dictionary:
	if n <= 0 or kind_of(id) == "":
		return {"frags": 0, "tomes": 0}
	var e := ensure(acc, id)
	e["frags"] = frags(acc, id) + n
	return {"frags": n, "tomes": overflow(acc, id)}


## Fragments at the absolute max -> Tomes (OVERFLOW_FRAGS_PER_TOME : 1); the remainder stays.
## Returns the Tomes credited.
static func overflow(acc: Dictionary, id: String) -> int:
	if not at_max(acc, id):
		return 0
	var e := entry(acc, id)
	var t := frags(acc, id) / HeroData.OVERFLOW_FRAGS_PER_TOME
	if t <= 0:
		return 0
	e["frags"] = frags(acc, id) - t * HeroData.OVERFLOW_FRAGS_PER_TOME
	MetaAcc.add(acc, "tomes", t)
	return t


## Tomes the next `n` fragments would give right now (the overflow label every granting screen
## shows first, §3.2).
static func overflow_preview(acc: Dictionary, id: String, n: int) -> int:
	if not at_max(acc, id):
		return 0
	return (frags(acc, id) + maxi(0, n)) / HeroData.OVERFLOW_FRAGS_PER_TOME


# ------------------------------------------------------------------ facets (Грані)

## Fragments for the next facet (0 at Full facets).
static func facet_cost(acc: Dictionary, id: String) -> int:
	var f := facets(acc, id)
	if f >= Ladder.FACETS_PER_GEM:
		return 0
	return int((HeroData.FACET_FRAGS[Ladder.gem_index(gem(acc, id))] as Array)[f])


## "" when a facet can be cut now, else owned | full | frags.
static func facet_block(acc: Dictionary, id: String) -> String:
	if not owned(acc, id):
		return "owned"
	if facets(acc, id) >= Ladder.FACETS_PER_GEM:
		return "full"
	if frags(acc, id) < facet_cost(acc, id):
		return "frags"
	return ""


static func can_facet(acc: Dictionary, id: String) -> bool:
	return facet_block(acc, id) == ""


## One facet (a free tap; fragments only). Full facets (5/5) opens Awakening on a hero in
## Amethyst+ that has none yet (F-AWK2). Returns {ok, reason, id, facets, full, awakened, tomes}.
static func facet_up(acc: Dictionary, id: String, now_s := 0) -> Dictionary:
	var why := facet_block(acc, id)
	if why != "":
		return {"ok": false, "reason": why, "id": id}
	var e := entry(acc, id)
	e["frags"] = frags(acc, id) - facet_cost(acc, id)
	e["facets"] = facets(acc, id) + 1
	var f := int(e["facets"])
	var full := f == Ladder.FACETS_PER_GEM
	var awakened := false
	if full:
		MetaAcc.count(acc, "full_cuts", 1)
		awakened = _open_awakening(acc, id, now_s)
	MetaTelemetry.note(acc, "facet", {"kind": kind_of(id), "id": id, "gem": gem(acc, id), "f": f}, now_s)
	return {"ok": true, "reason": "", "id": id, "facets": f, "full": full, "awakened": awakened,
			"tomes": overflow(acc, id)}


## «+»: every facet the fragments buy now (one micro ceremony for the whole visit).
## Returns {ok, reason, id, steps, facets, full, awakened, tomes}.
static func facet_fill(acc: Dictionary, id: String, now_s := 0) -> Dictionary:
	var out := {"ok": false, "reason": facet_block(acc, id), "id": id, "steps": 0, "facets": facets(acc, id),
			"full": false, "awakened": false, "tomes": 0}
	while can_facet(acc, id):
		var r := facet_up(acc, id, now_s)
		out["ok"] = true
		out["reason"] = ""
		out["steps"] = int(out["steps"]) + 1
		out["facets"] = int(r["facets"])
		out["full"] = bool(out["full"]) or bool(r["full"])
		out["awakened"] = bool(out["awakened"]) or bool(r["awakened"])
		out["tomes"] = int(out["tomes"]) + int(r["tomes"])
	return out


## Awakening rank 1 on a hero that may hold it now and has none (Full facets in Amethyst+).
static func _open_awakening(acc: Dictionary, id: String, now_s: int) -> bool:
	if kind_of(id) != KIND_HERO or not Ladder.can_awaken(native(id), gem(acc, id), facets(acc, id)):
		return false
	var e := entry(acc, id)
	var sk: Dictionary = e["skills"]
	if int(sk.get("awakened", 0)) > 0:
		return false
	sk["awakened"] = 1
	sync_peak(e)
	MetaAcc.count(acc, "awakenings", 1)
	MetaTelemetry.note(acc, "awaken", {"id": id, "born": false}, now_s)
	return true


# ------------------------------------------------------------------ recut (Огранка)

## Fragments for the recut to the next gem (0 at the max gem).
static func recut_cost(acc: Dictionary, id: String) -> int:
	var g := Ladder.gem_index(gem(acc, id))
	if g >= Ladder.gem_index(max_gem(id)):
		return 0
	return HeroData.RECUT_FRAGS[g]


## "" when the recut is possible now, else owned | max | facets | frags.
static func recut_block(acc: Dictionary, id: String) -> String:
	if not owned(acc, id):
		return "owned"
	if Ladder.gem_index(gem(acc, id)) >= Ladder.gem_index(max_gem(id)):
		return "max"
	if facets(acc, id) < Ladder.FACETS_PER_GEM:
		return "facets"
	if frags(acc, id) < recut_cost(acc, id):
		return "frags"
	return ""


static func can_recut(acc: Dictionary, id: String) -> bool:
	return recut_block(acc, id) == ""


## Recut to the next gem: needs Full facets and RECUT_FRAGS[g] (no coins). Facets restart at 0;
## no number drops (RECUT_STEP = 1 + 5 a; the cap at (g + 1, 0) equals the cap at (g, 5)).
## Returns {ok, reason, id, from, to, frags}.
static func recut(acc: Dictionary, id: String, now_s := 0) -> Dictionary:
	var why := recut_block(acc, id)
	if why != "":
		return {"ok": false, "reason": why, "id": id}
	var e := entry(acc, id)
	var from := gem(acc, id)
	e["frags"] = frags(acc, id) - recut_cost(acc, id)
	var to: String = Ladder.GEMS[Ladder.gem_index(from) + 1]
	e["gem"] = to
	e["facets"] = 0
	MetaAcc.count(acc, "recuts", 1)
	MetaTelemetry.note(acc, "recut", {"kind": kind_of(id), "id": id, "from": from, "to": to}, now_s)
	return {"ok": true, "reason": "", "id": id, "from": from, "to": to, "frags": frags(acc, id)}


## What "recut + every facet the banked fragments buy at once" reaches (Best upgrade, §3.2):
## {gem, facets, frags} without changing the account; {} when no recut is possible.
static func recut_preview(acc: Dictionary, id: String) -> Dictionary:
	if not can_recut(acc, id):
		return {}
	var g := Ladder.gem_index(gem(acc, id)) + 1
	var fr := frags(acc, id) - recut_cost(acc, id)
	var f := 0
	while f < Ladder.FACETS_PER_GEM and fr >= int((HeroData.FACET_FRAGS[g] as Array)[f]):
		fr -= int((HeroData.FACET_FRAGS[g] as Array)[f])
		f += 1
	return {"gem": Ladder.GEMS[g], "facets": f, "frags": fr}


## Fragments still needed from the current state to the absolute max (0 at it).
static func frags_to_max(acc: Dictionary, id: String) -> int:
	var g := Ladder.gem_index(gem(acc, id))
	var top := Ladder.gem_index(max_gem(id))
	var need := 0
	for f in range(facets(acc, id), Ladder.FACETS_PER_GEM):
		need += int((HeroData.FACET_FRAGS[g] as Array)[f])
	for gi in range(g, top):
		need += HeroData.RECUT_FRAGS[gi] + HeroData.full_facets_cost(Ladder.GEMS[gi + 1])
	return maxi(0, need - frags(acc, id))


# ------------------------------------------------------------------ helpers

## skills_peak >= skills, key by key (F-65 counts peaks, so a Rewrite never re-counts).
static func sync_peak(e: Dictionary) -> void:
	if not e.get("skills") is Dictionary:
		return
	if not e.get("skills_peak") is Dictionary:
		e["skills_peak"] = {}
	var sk: Dictionary = e["skills"]
	var pk: Dictionary = e["skills_peak"]
	for k in sk:
		pk[k] = maxi(int(pk.get(k, 0)), int(sk[k]))
