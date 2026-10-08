class_name Champions
extends RefCounted
## The run's champion slots (heroes design §4.2, §10.5). Phase H0: the API WS-C fills in H2 —
## setup() reads nothing while HeroKinds.champions_live() is false, so `members` stays empty and
## the run behaves exactly as Meta-1.
##
## members: [{id, slot, class, hp, hp_max, alive, x, d}] (the KindView.champions() shape).

var members: Array[Dictionary] = []
## Per champion {id, alive, kills, heals, blocks, dmg_taken} for the result screen (§10.5).
var report: Array[Dictionary] = []


## Reads the profile's team block (WS-B's Meta.run_profile `team`, framework §9.8) for `level`.
func setup(profile: Dictionary, _level: int) -> void:
	members.clear()
	report.clear()
	if not HeroKinds.champions_live():
		return
	var team: Variant = profile.get("team", {})
	if not team is Dictionary:
		return
	var list: Array = (team as Dictionary).get("champions", [])
	var slots := ChampionKinds.assign_slots(list, int((team as Dictionary).get("slots", list.size())))
	for m: Variant in list:
		if not m is Dictionary or not slots.has(str(m.get("id", ""))):
			continue
		var hp := float(m.get("hp", 0.0))
		members.append({"id": str(m["id"]), "slot": slots[str(m["id"])], "class": str(m.get("class", "")),
				"hp": hp, "hp_max": hp, "alive": hp > 0.0, "x": 0.0, "d": 0.0})


func active() -> bool:
	return not members.is_empty()


## Advances every champion (H2: ChampionKinds.step through the view). No-op while empty.
func step(view: KindView, dt: float) -> void:
	if members.is_empty():
		return
	ChampionKinds.step(view, members, dt)
