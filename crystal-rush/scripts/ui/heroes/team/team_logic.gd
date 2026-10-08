class_name HeroesTeamLogic
extends RefCounted
## Pure helpers of the Team screen (heroes_design.md §4.2, §5.3-§5.6; part U §2.7):
##  * slot_layout(): where each member stands in the formation, with the run's own slot rules
##    (ChampionKinds.CLASS_SLOTS / SLOT_ORDER / slot_offset, §4.2), so the stage shows exactly
##    the run's formation;
##  * score(): a synergy score of a hypothetical team (faction tiers, class pairs, element pairs,
##    from TeamData) for the delta badges and Auto-team;
##  * delta(): the badges a candidate card shows («+Фракція», «+Клас», dim «−Стихія»);
##  * auto_team(): the strongest team from owned characters (never applied silently);
##  * presets: three saved teams per mock account (H3b: Meta presets).
## Reads characters only through HeroesUIModel.

## Members of one class that make a class pair (§5.1 "Pair bonus (2 of the class)"; the model's
## _synergy uses the same rule).
const PAIR := 2

static var _live_elements := {}


## True when at least one LIVE machine (ArsenalData.is_live) of element `e` exists (ArsenalData families = elements, §5.2).
static func element_has_machine(e: String) -> bool:
	if _live_elements.is_empty():
		for id: String in ArsenalData.MACHINES:
			if ArsenalData.is_live(id):
				_live_elements[ArsenalData.family_of(id)] = true
	return _live_elements.has(e)


## Normalised slot offsets (x across the bridge, y along the run, + = behind the hero), r' = 1.
static func offset(slot: StringName) -> Vector2:
	return ChampionKinds.slot_offset(slot, 1.0)


## Formation of `team` (HeroesUIModel.team()): [{index, id, slot, state "champion" | "empty" |
## "locked"}] for the slots_max positions; locked / empty ones take the free positions left.
static func slot_layout(team: Dictionary) -> Array[Dictionary]:
	var champs: Array = team["champions"]
	var free: Array[StringName] = ChampionKinds.SLOT_ORDER.duplicate()
	var out: Array[Dictionary] = []
	for i in int(team["slots_max"]):
		out.append({"index": i, "id": "", "slot": &"", "state": "locked" if i >= int(team["slots"]) else "empty"})
	for i in champs.size():
		var id := str(champs[i])
		if id == "" or i >= out.size():
			continue
		var cls := str(HeroesUIModel.champion(id).get("class", ""))
		var pick: StringName = &""
		for sl: StringName in ChampionKinds.CLASS_SLOTS.get(cls, []):
			if sl in free:
				pick = sl
				break
		if pick == &"" and not free.is_empty():
			pick = free[0]
		free.erase(pick)
		out[i]["id"] = id
		out[i]["slot"] = pick
		out[i]["state"] = "champion"
	for o in out:
		if o["slot"] == &"" and not free.is_empty():
			o["slot"] = free.pop_front()
	return out


static func slot_label(slot: StringName) -> String:
	return HeroesText.t("TEAM_SLOT_" + str(slot).to_upper())


## Synergy components of a hypothetical team: {faction (sum of active tiers), class (active
## pairs), element (elements held by 2+), total}. Native-blind and gem-blind (§5.5).
static func score(hero_id: String, champs: Array) -> Dictionary:
	var fac := {}
	var cls := {}
	var el := {}
	var members: Array[Dictionary] = []
	if hero_id != "":
		members.append(HeroesUIModel.hero(hero_id))
	for c in champs:
		if str(c) != "":
			members.append(HeroesUIModel.champion(str(c)))
	for m in members:
		if m.is_empty():
			continue
		fac[m["faction"]] = int(fac.get(m["faction"], 0)) + 1
		cls[m["class"]] = int(cls.get(m["class"], 0)) + 1
		el[m["element"]] = int(el.get(m["element"], 0)) + 1
	var ft := 0
	for f: String in fac:
		ft += faction_tier(int(fac[f]))
	var cp := 0
	for c: String in cls:
		if int(cls[c]) >= PAIR:
			cp += 1
	var ep := 0
	for e: String in el:
		if int(el[e]) >= PAIR:
			ep += 1
	return {"faction": ft, "class": cp, "element": ep, "total": ft * 2 + cp * 2 + ep, "factions": fac, "classes": cls, "elements": el}


## Active faction tier (0..3) for `n` living members (TeamData.FACTION_MEMBERS_FOR_TIER).
static func faction_tier(n: int) -> int:
	var tier := 0
	for t in TeamData.FACTION_MEMBERS_FOR_TIER.size():
		if t > 0 and n >= TeamData.FACTION_MEMBERS_FOR_TIER[t]:
			tier = t
	return tier


## Members needed for the next faction tier after `n` (0 when at the top tier).
static func next_tier_at(n: int) -> int:
	for t in TeamData.FACTION_MEMBERS_FOR_TIER:
		if t > n:
			return t
	return 0


## Badges for putting `cand` into champion slot `slot_index` (-1 = the hero slot) of `team`:
## [{key, gain}] with gain true = gold «+…», false = dim «−…».
static func delta(team: Dictionary, cand: String, slot_index: int) -> Array[Dictionary]:
	var hero_id := str(team["hero"])
	var champs: Array = (team["champions"] as Array).duplicate()
	var before := score(hero_id, champs)
	if slot_index < 0:
		hero_id = cand
	else:
		var j := champs.find(cand)
		if j >= 0:
			champs[j] = ""
		while champs.size() <= slot_index:
			champs.append("")
		champs[slot_index] = cand
	var after := score(hero_id, champs)
	var out: Array[Dictionary] = []
	for k: String in ["faction", "class", "element"]:
		var d := int(after[k]) - int(before[k])
		if d > 0:
			out.append({"key": "TEAM_DELTA_" + k.to_upper(), "gain": true})
		elif d < 0:
			out.append({"key": "TEAM_DELTA_" + k.to_upper() + "_LOSS", "gain": false})
	return out


## The strongest team from owned characters: power (gem, facets, level) + synergy. Returns
## {hero, champions, score} (never applied by itself: the screen shows it as ghosts first).
static func auto_team() -> Dictionary:
	var team := HeroesUIModel.team()
	var slots := int(team["slots"])
	var heroes: Array[Dictionary] = []
	for h: Dictionary in HeroesUIModel.heroes():
		if bool(h["owned"]):
			heroes.append(h)
	var champs: Array[Dictionary] = []
	for c: Dictionary in HeroesUIModel.champions():
		if bool(c["owned"]):
			champs.append(c)
	var best := {"hero": str(team["hero"]), "champions": team["champions"], "score": -1.0}
	var combos := _combos(champs.size(), mini(slots, champs.size()))
	for h in heroes:
		var hp := _power(h) * 1.6
		for combo: Array in combos:
			var ids: Array = []
			var cp := 0.0
			for i: int in combo:
				ids.append(champs[i]["id"])
				cp += _power(champs[i])
			var s := hp + cp + float(score(str(h["id"]), ids)["total"]) * 0.9
			if s > float(best["score"]) + 1e-6:
				best = {"hero": str(h["id"]), "champions": ids, "score": s}
	return best


static func _power(d: Dictionary) -> float:
	var p := float(Ladder.gem_index(str(d["gem"]))) * 1.0 + 0.12 * int(d.get("facets", 0))
	if str(d.get("kind", "")) == "hero":
		p += 0.04 * int(d.get("eff_level", 1))
	return p


static func _combos(n: int, k: int) -> Array:
	var out: Array = []
	if k <= 0:
		out.append([])
		return out
	var cur: Array = []
	_rec(0, n, k, cur, out)
	return out


static func _rec(start: int, n: int, k: int, cur: Array, out: Array) -> void:
	if cur.size() == k:
		out.append(cur.duplicate())
		return
	for i in range(start, n):
		cur.append(i)
		_rec(i + 1, n, k, cur, out)
		cur.pop_back()


# ------------------------------------------------------------------ presets (mock; H3b: Meta)

static var _presets := {}


## The three presets of the current mock account: [{hero, champions} or {}].
static func presets() -> Array:
	var k := HeroesUIModel.state_name()
	if not _presets.has(k):
		var t := HeroesUIModel.team()
		_presets[k] = [{"hero": str(t["hero"]), "champions": (t["champions"] as Array).duplicate()}, {}, {}]
	return _presets[k]


static func save_preset(i: int) -> void:
	var t := HeroesUIModel.team()
	presets()[i] = {"hero": str(t["hero"]), "champions": (t["champions"] as Array).duplicate()}


## Loads preset `i` into the team; false when it is empty.
static func load_preset(i: int) -> bool:
	var p: Dictionary = presets()[i]
	if p.is_empty():
		return false
	HeroesUIModel.set_team(str(p["hero"]), p["champions"])
	return true


## Index of the preset equal to the current team (-1 when none).
static func active_preset() -> int:
	var t := HeroesUIModel.team()
	var ps := presets()
	for i in ps.size():
		var p: Dictionary = ps[i]
		if not p.is_empty() and str(p["hero"]) == str(t["hero"]) and _same(p["champions"], t["champions"]):
			return i
	return -1


static func _same(a: Array, b: Array) -> bool:
	var x: Array = []
	var y: Array = []
	for v in a:
		if str(v) != "":
			x.append(str(v))
	for v in b:
		if str(v) != "":
			y.append(str(v))
	x.sort()
	y.sort()
	return x == y
