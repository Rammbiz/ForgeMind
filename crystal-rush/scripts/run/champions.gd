class_name Champions
extends RefCounted
## The run's champion slots (heroes design §4.2, §10.5). Run and LevelSim each own one; the rules
## are ChampionKinds (pure static, over a KindView). setup() reads nothing while
## HeroKinds.champions_live() is false or the profile has no team block, so `members` stays empty
## and the run behaves exactly as Meta-1.
##
## members: ChampionKinds.member() rows (the KindView.champions() shape).

var members: Array = []
## True when the run's hero is a Guardian (§4.2: the front champion's clash share x0.5).
var guardian_hero := false


## Reads the profile's team block (Meta.run_profile `team`: {hero, champions [ChampionsMeta.stats
## + slot + aura_effect], synergy}) for `level`.
func setup(profile: Dictionary, _level: int) -> void:
	members.clear()
	guardian_hero = false
	if not HeroKinds.champions_live():
		return
	var team: Variant = profile.get("team", {})
	if not team is Dictionary:
		return
	var hero_id := str((team as Dictionary).get("hero", ""))
	guardian_hero = str((HeroData.HEROES.get(hero_id, {}) as Dictionary).get("class", "")) == "guardian"
	var list: Array = (team as Dictionary).get("champions", [])
	var slots := ChampionKinds.assign_slots(list, int((team as Dictionary).get("slots", list.size())))
	for m: Variant in list:
		if not m is Dictionary or not slots.has(str(m.get("id", ""))):
			continue
		members.append(ChampionKinds.member(m, slots[str(m["id"])]))


func active() -> bool:
	return not members.is_empty()


## A deep copy (LevelSim.State.copy: the planner branches states).
func copy() -> Champions:
	var c := Champions.new()
	c.guardian_hero = guardian_hero
	for m: Dictionary in members:
		c.members.append(m.duplicate())
	return c


## Advances every living champion (ChampionKinds.step through the view). No-op while empty.
func step(view: KindView, dt: float) -> void:
	if members.is_empty():
		return
	ChampionKinds.step(view, members, dt)


## Per champion {id, alive, kills, heals, blocks, dmg_taken} for the result screen (§10.5).
func report() -> Array:
	return ChampionKinds.report(members)


func alive_count() -> int:
	return ChampionKinds.living(members).size()
