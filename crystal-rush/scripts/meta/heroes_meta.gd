class_name HeroesMeta
## Hero levels 1-30 (arsenal_design.md §4.1): coins per level round(30 x L^1.4, 10), +3.5% hero
## damage, +4% HP, +1% ult charge rate per level, cap 6 + 3 x world reached, Ult Rank II/III/IV
## at Lv5/15/25, Awakening looks at Lv10/20/30 (Meta-2). Pure rules over the account dictionary.
##
## Heroes & Champions (heroes_design.md §2.3, §3.1, §3.3; WS-A): Hero Sync, skill ranks bought
## with Tomes under the F-CAP caps, ult forms, Awakening ranks, «Переписати навички / Rewrite»,
## the kit-blind power index («Міць») and the run block. The Meta-1 functions above the v3 section
## keep their 2.2.1 behaviour while EconData.heroes_live() is false (HEROES_PHASE < 3); once the
## systems are live they use ownership (Save v3) and Hero Sync.

## The four hero skills (Save v3 `skills` keys); the first three have ranks 1..skill_cap.
const SKILLS: Array[String] = ["ult", "attack", "rally", "awakened"]
const RANKED: Array[String] = ["ult", "attack", "rally"]

## Hero level of `id` (1 when the hero has no entry yet). Under Hero Sync this is the hero's OWN
## level; eff_level() is the one the run uses.
static func level(acc: Dictionary, id: String) -> int:
	return maxi(1, int(((acc["heroes"] as Dictionary).get(id, {}) as Dictionary).get("lvl", 1)))


## Level cap for the account's world (30 in Invasion).
static func cap(acc: Dictionary, _id := "") -> int:
	return EconData.hero_cap(MetaAcc.world(acc), MetaAcc.level(acc) > ArsenalData.CAMPAIGN_LEVELS)


## Campaign WIN that unlocks the hero has happened (or the hero is a starter). `dev` opens every
## hero that exists in this phase (dev runs). Live hero systems: the hero is owned.
static func unlocked(acc: Dictionary, id: String, dev := false) -> bool:
	if EconData.heroes_live():
		return Roster.owned(acc, id) or (dev and HeroData.HEROES.has(id))
	var at := int(EconData.HERO_UNLOCK.get(id, -1))
	return at == 0 or (at > 0 and MetaAcc.level(acc) > at) or (dev and at >= 0)


## Coins for the next level of `id` (0 while the Heroes tab's free first level is unused).
static func cost(acc: Dictionary, id: String) -> int:
	if EconData.heroes_live():
		return sync_cost(acc, id)
	if bool(MetaAcc.free_steps(acc).get("hero", false)):
		return 0
	return EconData.hero_cost(level(acc, id))


static func can_level(acc: Dictionary, id: String, dev := false) -> bool:
	var lv := eff_level(acc, id) if EconData.heroes_live() else level(acc, id)
	return UnlockQueue.is_open(acc, "heroes") and unlocked(acc, id, dev) and lv < cap(acc) \
			and MetaAcc.amount(acc, "coins") >= cost(acc, id)


## Buys one level: {ok, id, lvl, milestone ("" | ult_rank | awakening), coins, free}.
## Live hero systems: Hero Sync (level_up_synced).
static func level_up(acc: Dictionary, id: String, dev := false) -> Dictionary:
	if EconData.heroes_live():
		return level_up_synced(acc, id, dev)
	if not can_level(acc, id, dev):
		var why := "cap" if level(acc, id) >= cap(acc) else ("locked" if not unlocked(acc, id, dev) else "coins")
		return {"ok": false, "id": id, "reason": why}
	var c := cost(acc, id)
	var free := c == 0
	MetaAcc.spend(acc, "coins", c)
	if free:
		MetaAcc.free_steps(acc).erase("hero")
	var hs: Dictionary = acc["heroes"]
	if not hs.has(id):
		var aspects: Array = EconData.HERO_ASPECTS.get(id, [""])
		hs[id] = {"lvl": 1, "glory": 1, "boss_wins": 0, "aspect": str(aspects[0]), "skin": ""}
	var h: Dictionary = hs[id]
	h["lvl"] = int(h["lvl"]) + 1
	var lv := int(h["lvl"])
	var ms := ""
	if lv in (EconData.HERO["ult_rank_at"] as Array):
		ms = "ult_rank"
	elif lv in (EconData.HERO["awakening_at"] as Array):
		ms = "awakening"
	MetaAcc.count(acc, "upgrades_bought", 1)
	MetaAcc.count(acc, "hero_levels", 1)
	return {"ok": true, "id": id, "lvl": lv, "milestone": ms, "coins": c, "free": free}


## Run-ready hero block (§9.4 "hero"): {id, lvl, aspect, glory, ult_rank, dmg_mult, hp_mult,
## ult_rate_mult}. Live hero systems: lvl is the Hero Sync level (run_block() has the v3 numbers).
static func profile(acc: Dictionary, id: String) -> Dictionary:
	var lvl := eff_level(acc, id) if EconData.heroes_live() else level(acc, id)
	var h: Dictionary = (acc["heroes"] as Dictionary).get(id, {})
	var mults := EconData.hero_mults(lvl)
	return {"id": id, "lvl": lvl, "aspect": str(h.get("aspect", "")), "glory": int(h.get("glory", 1)),
			"ult_rank": int(mults["ult_rank"]), "dmg_mult": float(mults["dmg_mult"]), "hp_mult": float(mults["hp_mult"]),
			"ult_rate_mult": float(mults["ult_rate_mult"])}


## Coins from Lv1 to Lv30 for one hero (design: 42 140).
static func total_cost() -> int:
	var n := 0
	for l in range(1, int(EconData.HERO["max"])):
		n += EconData.hero_cost(l)
	return n


# ======================================================================== v3: Hero Sync (§3.1)

## Highest OWN level among the owned heroes (1 when none).
static func best_own(acc: Dictionary) -> int:
	var best := 1
	for id in Roster.owned_ids(acc, Roster.KIND_HERO):
		best = maxi(best, level(acc, id))
	return best


## Hero Sync: eff_lvl(h) = max(own, min(cap, best_own - HERO_SYNC_BEHIND)). A new hero arrives synced.
static func eff_level(acc: Dictionary, id: String) -> int:
	return maxi(level(acc, id), mini(cap(acc), best_own(acc) - HeroData.HERO_SYNC_BEHIND))


## «Синхронізовано з найкращим героєм»: the hero plays above its own level.
static func synced(acc: Dictionary, id: String) -> bool:
	return eff_level(acc, id) > level(acc, id)


## Coins for the next Hero Sync level: hero_cost(eff) (0 while the free first level is unused).
static func sync_cost(acc: Dictionary, id: String) -> int:
	if bool(MetaAcc.free_steps(acc).get("hero", false)):
		return 0
	return EconData.hero_cost(eff_level(acc, id))


## v3 level purchase: pays hero_cost(eff) and sets own = eff + 1.
## {ok, reason, id, lvl, synced, milestone ("" | gear_slot), coins, free}.
static func level_up_synced(acc: Dictionary, id: String, dev := false) -> Dictionary:
	var eff := eff_level(acc, id)
	if not (Roster.owned(acc, id) or (dev and HeroData.HEROES.has(id))):
		return {"ok": false, "id": id, "reason": "locked"}
	if eff >= cap(acc):
		return {"ok": false, "id": id, "reason": "cap"}
	if not UnlockQueue.is_open(acc, "heroes"):
		return {"ok": false, "id": id, "reason": "locked"}
	var c := sync_cost(acc, id)
	if not MetaAcc.spend(acc, "coins", c):
		return {"ok": false, "id": id, "reason": "coins"}
	var free := c == 0
	if free:
		MetaAcc.free_steps(acc).erase("hero")
	var was_synced := eff > level(acc, id)
	var h := Roster.ensure(acc, id)
	h["lvl"] = eff + 1
	var ms := ""
	if Roster.system_open(acc, "workshop") and (eff + 1) in HeroData.GEAR_SLOT_AT.values():
		ms = "gear_slot"
	MetaAcc.count(acc, "upgrades_bought", 1)
	MetaAcc.count(acc, "hero_levels", 1)
	MetaTelemetry.note(acc, "hero_level", {"id": id, "lvl": eff + 1, "synced": was_synced})
	return {"ok": true, "reason": "", "id": id, "lvl": eff + 1, "synced": was_synced, "milestone": ms, "coins": c,
			"free": free}


# ======================================================================== v3: skills (§3.3)

static func _skills(acc: Dictionary, id: String) -> Dictionary:
	var e := Roster.entry(acc, id)
	return e.get("skills", {}) if e.get("skills") is Dictionary else {}


## Rank of `skill` (ult / attack / rally 1..; awakened 0 = sealed).
static func skill_rank(acc: Dictionary, id: String, skill: String) -> int:
	var r := int(_skills(acc, id).get(skill, 0 if skill == "awakened" else 1))
	return maxi(r, 0 if skill == "awakened" else 1)


## Rank cap of `skill`: F-CAP for ult / attack / rally; awaken_cap for an open Awakening (0 sealed).
static func skill_cap(acc: Dictionary, id: String, skill: String) -> int:
	var n := Roster.native(id)
	var g := Roster.gem(acc, id)
	if skill == "awakened":
		return Ladder.awaken_cap(n, g) if skill_rank(acc, id, "awakened") > 0 else 0
	return Ladder.skill_cap(n, g, Roster.facets(acc, id))


## Ult form 1..5 (I..V) at the current Ult rank, capped by the native gem.
static func ult_form(acc: Dictionary, id: String) -> int:
	return Ladder.ult_form(Roster.native(id), skill_rank(acc, id, "ult"))


## The free first step of the skills unlock (one free Ult rank on the team hero, §11.4):
## free_steps.skill_rank = true (the team hero) or a hero id.
static func free_rank(acc: Dictionary, id: String, skill: String) -> bool:
	if skill != "ult":
		return false
	var v: Variant = MetaAcc.free_steps(acc).get("skill_rank", false)
	if v is String:
		return str(v) == id
	return bool(v) and str((acc.get("team", {}) as Dictionary).get("hero", "")) == id


## Tomes for the next rank of `skill` (0 when the free step applies).
static func rank_cost(acc: Dictionary, id: String, skill: String) -> int:
	if free_rank(acc, id, skill):
		return 0
	var r := skill_rank(acc, id, skill)
	return HeroData.TOME_COST[clampi(r, 0, HeroData.TOME_COST.size() - 1)]


## "" when the next rank can be bought, else owned | locked | sealed | cap | tomes | skill.
static func rank_block(acc: Dictionary, id: String, skill: String) -> String:
	if not skill in SKILLS:
		return "skill"
	if not Roster.owned(acc, id) or Roster.kind_of(id) != Roster.KIND_HERO:
		return "owned"
	if not Roster.system_open(acc, "skills") and not free_rank(acc, id, skill):
		return "locked"
	if skill == "awakened" and skill_rank(acc, id, skill) == 0:
		return "sealed"
	if skill_rank(acc, id, skill) >= skill_cap(acc, id, skill):
		return "cap"
	if MetaAcc.amount(acc, "tomes") < rank_cost(acc, id, skill):
		return "tomes"
	return ""


static func can_rank_up(acc: Dictionary, id: String, skill: String) -> bool:
	return rank_block(acc, id, skill) == ""


## One rank of `skill` for Tomes (no coins). {ok, reason, id, skill, rank, form, form_up, tomes, free}.
static func rank_up(acc: Dictionary, id: String, skill: String, now_s := 0) -> Dictionary:
	var why := rank_block(acc, id, skill)
	if why != "":
		return {"ok": false, "reason": why, "id": id, "skill": skill}
	var c := rank_cost(acc, id, skill)
	var free := free_rank(acc, id, skill)
	MetaAcc.spend(acc, "tomes", c)
	if free:
		MetaAcc.free_steps(acc).erase("skill_rank")
	var form0 := ult_form(acc, id)
	var e := Roster.entry(acc, id)
	var sk: Dictionary = e["skills"]
	sk[skill] = skill_rank(acc, id, skill) + 1
	if not free:
		var bp := _paid(e, skill)
		bp[0] = int(bp[0]) + 1
		bp[1] = int(bp[1]) + c
	Roster.sync_peak(e)
	var form := ult_form(acc, id)
	var r := int(sk[skill])
	MetaTelemetry.note(acc, "skill_rank", {"id": id, "skill": skill, "rank": r, "form": form}, now_s)
	return {"ok": true, "reason": "", "id": id, "skill": skill, "rank": r, "form": form,
			"form_up": skill == "ult" and form > form0, "tomes": c, "free": free}


## Ranks bought with Tomes and the Tomes paid, per skill: hero.skills_paid {skill: [ranks, tomes]}
## (created on first use; Save v3 sanitize keeps it consistent).
static func _paid(e: Dictionary, skill: String) -> Array:
	if not e.get("skills_paid") is Dictionary:
		e["skills_paid"] = {}
	var sp: Dictionary = e["skills_paid"]
	if not sp.get(skill) is Array or (sp[skill] as Array).size() != 2:
		sp[skill] = [0, 0]
	return sp[skill]


## Ranks of `skill` bought with Tomes (what a Rewrite takes back).
static func paid_ranks(acc: Dictionary, id: String, skill: String) -> int:
	var sp: Variant = Roster.entry(acc, id).get("skills_paid", {})
	if not sp is Dictionary or not (sp as Dictionary).get(skill) is Array or ((sp as Dictionary)[skill] as Array).size() != 2:
		return 0
	return int(((sp as Dictionary)[skill] as Array)[0])


## The refund of a Rewrite: exactly the Tomes paid for ranks (hero.skills_paid). Ranks that cost no
## Tomes (the free first Ult rank, ranks carried over from 2.2.1, a born Awakening) are kept by the
## Rewrite and never pay Tomes back (review F5: counting the refund from ranks minted Tomes).
static func rewrite_refund(acc: Dictionary, id: String) -> int:
	var sp: Variant = Roster.entry(acc, id).get("skills_paid", {})
	if not sp is Dictionary:
		return 0
	var t := 0
	for s in SKILLS:
		var row: Variant = (sp as Dictionary).get(s)
		if row is Array and (row as Array).size() == 2:
			t += maxi(0, int((row as Array)[1]))
	return t


## "" when a Rewrite is possible, else owned | team (in the active team or a preset) | nothing.
static func rewrite_block(acc: Dictionary, id: String) -> String:
	if not Roster.owned(acc, id) or Roster.kind_of(id) != Roster.KIND_HERO:
		return "owned"
	if Team.uses_hero(acc, id):
		return "team"
	var bought := 0
	for s in SKILLS:
		bought += paid_ranks(acc, id, s)
	if bought == 0 and rewrite_refund(acc, id) == 0:
		return "nothing"
	return ""


## «Переписати навички / Rewrite skills»: every Tome spent on the hero's ranks comes back (100%)
## and exactly the ranks bought with Tomes go; free ranks stay (the free first Ult rank, 2.2.1 ranks,
## a born Awakening), so nothing is minted and nothing the player did not pay for is lost.
## skills_peak is kept (F-65 never re-counts). {ok, reason, id, tomes_back}.
static func rewrite(acc: Dictionary, id: String, now_s := 0) -> Dictionary:
	var why := rewrite_block(acc, id)
	if why != "":
		return {"ok": false, "reason": why, "id": id, "tomes_back": 0}
	var back := rewrite_refund(acc, id)
	var e := Roster.entry(acc, id)
	var sk: Dictionary = e["skills"]
	for s in SKILLS:
		var base := 0 if s == "awakened" else 1
		if s == "awakened" and int(sk.get(s, 0)) > 0:
			base = 1
		sk[s] = maxi(base, skill_rank(acc, id, s) - paid_ranks(acc, id, s))
		_paid(e, s)
		(e["skills_paid"] as Dictionary)[s] = [0, 0]
	MetaAcc.add(acc, "tomes", back)
	MetaTelemetry.note(acc, "rewrite", {"id": id, "tomes_back": back}, now_s)
	return {"ok": true, "reason": "", "id": id, "tomes_back": back}


## F-65 counter: Σ (peak rank - 1) over the owned heroes' four skills.
static func skill_ranks_total(acc: Dictionary) -> int:
	var t := 0
	for id in Roster.owned_ids(acc, Roster.KIND_HERO):
		var pk: Dictionary = Roster.entry(acc, id).get("skills_peak", {})
		for s in SKILLS:
			t += maxi(0, int(pk.get(s, 1)) - 1)
	return t


## Hero Feat counters (§3.6) from the account: {heroes_owned, champions_owned, skill_ranks,
## champion_level, recuts, full_cuts, awakenings}. Owned counts take earned copies only.
static func feat_counters(acc: Dictionary) -> Dictionary:
	var h := 0
	for id in Roster.owned_ids(acc, Roster.KIND_HERO):
		if str((Roster.entry(acc, id).get("got", {}) as Dictionary).get("via", "")) in Roster.EARNED_VIA:
			h += 1
	var c := 0
	for id2 in Roster.owned_ids(acc, Roster.KIND_CHAMPION):
		if str((Roster.entry(acc, id2).get("got", {}) as Dictionary).get("via", "")) in Roster.EARNED_VIA:
			c += 1
	var cn: Dictionary = acc.get("counters", {})
	return {"heroes_owned": h, "champions_owned": c, "skill_ranks": skill_ranks_total(acc),
			"champion_level": ChampionsMeta.level(acc), "recuts": int(cn.get("recuts", 0)),
			"full_cuts": int(cn.get("full_cuts", 0)), "awakenings": int(cn.get("awakenings", 0))}


# ======================================================================== v3: power index (§2.3, sim hero_index)

## Gear block {dmg, hp, ult, charge} with zeros (the Workshop, WS-F, fills it).
const NO_GEAR := {"dmg": 0.0, "hp": 0.0, "ult": 0.0, "charge": 0.0}


## The kit-blind hero power index (sim hero_index; 1.000 = a Quartz hero Lv1 rank 1 without gear =
## the Meta-1 Lv1 hero). n / g = gem indices, f facets, lvl the (synced) level, sk [ult, attack,
## rally, awakened], gear {dmg, hp, ult, charge}, relic_beats 0..3, set4 the 4-piece rule, syn the
## team multipliers {rate, charge, ultp} (Team.synergy).
static func index(n: int, g: int, f: int, lvl: int, sk: Array, gear: Dictionary = NO_GEAR, relic_beats := 0,
		set4 := false, syn: Dictionary = {}) -> float:
	var ult := int(sk[0])
	var atk := int(sk[1])
	var awk := int(sk[3])
	var ng: String = Ladder.GEMS[n]
	var lad := Ladder.mult(ng, Ladder.GEMS[g], f)
	var beats := 0
	for b: int in Ladder.ATK_BEATS:
		if atk >= b:
			beats += 1
	var atk_m := 1.0 + Ladder.ATK_RANK_STEP * (atk - 1) + Ladder.ATK_BEAT * beats
	var lm := float(lvl - 1)
	var dmg := (1.0 + Ladder.LV_DMG * lm) * (1.0 + float(gear.get("dmg", 0.0))) * atk_m * float(syn.get("rate", 1.0))
	var form := Ladder.ult_form(ng, ult)
	var ultp := ((1.0 + Ladder.LV_ULT * lm) * (1.0 + Ladder.ULT_RANK_STEP * (ult - 1)) * (1.0 + float(gear.get("ult", 0.0)))
			* (1.0 + Ladder.LV_RATE * lm) * (1.0 + float(gear.get("charge", 0.0))) * (1.0 + Ladder.FORM_STEP * (form - 1))
			* float(syn.get("charge", 1.0)) * float(syn.get("ultp", 1.0)))
	var hp := 1.0 + Ladder.HP_W * ((1.0 + Ladder.LV_HP * lm) * (1.0 + float(gear.get("hp", 0.0))) - 1.0)
	return (lad * ((1.0 - Ladder.U_SHARE) * dmg + Ladder.U_SHARE * ultp) * hp * (1.0 + Ladder.AWK_STEP * awk)
			* (1.0 + Ladder.RELIC_BEAT * relic_beats) * (1.0 + (Ladder.SET4_VALUE if set4 else 0.0)))


## The same index for the Meta-1 hero at `lvl` (Ult Rank I-IV from level, +20% per rank).
static func meta1_index(lvl: int) -> float:
	var rank := EconData.hero_ult_rank(lvl)
	var lm := float(lvl - 1)
	var dmg := 1.0 + Ladder.LV_DMG * lm
	var ultp := (1.0 + float(EconData.HERO["ult_rank_bonus"]) * (rank - 1)) * (1.0 + Ladder.LV_RATE * lm)
	var hp := 1.0 + Ladder.HP_W * Ladder.LV_HP * lm
	return ((1.0 - Ladder.U_SHARE) * dmg + Ladder.U_SHARE * ultp) * hp


## [ult, attack, rally, awakened] of the hero now.
static func ranks(acc: Dictionary, id: String) -> Array[int]:
	var out: Array[int] = []
	for s in SKILLS:
		out.append(skill_rank(acc, id, s))
	return out


## The hero's power index now (Hero Sync level; gear from the Workshop when given).
static func power(acc: Dictionary, id: String, gear: Dictionary = NO_GEAR, relic_beats := 0, set4 := false,
		syn: Dictionary = {}) -> float:
	return index(Ladder.gem_index(Roster.native(id)), Ladder.gem_index(Roster.gem(acc, id)), Roster.facets(acc, id),
			eff_level(acc, id), ranks(acc, id), gear, relic_beats, set4, syn)


## «Міць» on cards = power x 1000.
static func might(acc: Dictionary, id: String) -> int:
	return roundi(1000.0 * power(acc, id))


## Ult power multiplier: ladder x lv_ult(L) x (1 + ULT_RANK_STEP (rank - 1)) (§1.4; the no-loss
## migration check compares it with the Meta-1 Ult Rank I-IV value).
static func ult_power(native_gem: String, gem_now: String, f: int, lvl: int, rank: int) -> float:
	return (Ladder.mult(native_gem, gem_now, f) * (1.0 + Ladder.LV_ULT * (lvl - 1))
			* (1.0 + Ladder.ULT_RANK_STEP * (rank - 1)))


## Meta-1's ult power at `lvl` (Ult Rank I-IV from level, +20% per rank).
static func v2_ult_power(lvl: int) -> float:
	return 1.0 + float(EconData.HERO["ult_rank_bonus"]) * (EconData.hero_ult_rank(lvl) - 1)


## Rally value (§5.4): {hook, param, op, value = base x ladder x (1 + RALLY_RANK_STEP (rank - 1))}.
static func rally(acc: Dictionary, id: String) -> Dictionary:
	var r: Dictionary = HeroData.HEROES[id]["rally"]
	var hook := str(r["hook"])
	var v := float(r["base"]) * Roster.mult(acc, id) * (1.0 + Ladder.RALLY_RANK_STEP * (skill_rank(acc, id, "rally") - 1))
	return {"hook": hook, "param": str(r["param"]), "op": str((TeamData.RALLY_HOOKS[hook] as Dictionary)["op"]), "value": v}


## Run-ready v3 hero numbers (read by the Meta API / KindView, WS-B / WS-C): {id, native, gem,
## facets, lvl, mult (ladder), dmg_mult, hp_mult, ult_rate_mult, ult_power, ult_rank, ult_form,
## attack_rank, attack_beats, rally {hook, param, op, value}, awakened}. Gear and synergy are
## applied by their owners on top.
static func run_block(acc: Dictionary, id: String) -> Dictionary:
	var lvl := eff_level(acc, id)
	var n := Roster.native(id)
	var g := Roster.gem(acc, id)
	var f := Roster.facets(acc, id)
	var lad := Ladder.mult(n, g, f)
	var atk := skill_rank(acc, id, "attack")
	var beats := 0
	for b: int in Ladder.ATK_BEATS:
		if atk >= b:
			beats += 1
	var lm := float(lvl - 1)
	var ult := skill_rank(acc, id, "ult")
	return {"id": id, "native": n, "gem": g, "facets": f, "lvl": lvl, "mult": lad,
			"dmg_mult": lad * (1.0 + Ladder.LV_DMG * lm) * (1.0 + Ladder.ATK_RANK_STEP * (atk - 1)),
			"hp_mult": lad * (1.0 + Ladder.LV_HP * lm), "ult_rate_mult": 1.0 + Ladder.LV_RATE * lm,
			"ult_power": ult_power(n, g, f, lvl, ult), "ult_rank": ult, "ult_form": Ladder.ult_form(n, ult),
			"attack_rank": atk, "attack_beats": beats, "rally": rally(acc, id),
			"awakened": skill_rank(acc, id, "awakened")}
