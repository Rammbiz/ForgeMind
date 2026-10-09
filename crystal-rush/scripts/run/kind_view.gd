class_name KindView
extends RefCounted
## The one interface the hero / champion rules (HeroKinds, ChampionKinds) act through (heroes
## design §10.4). Abstract: RunKindView implements it with the run's nodes, VFX and signals,
## SimKindView with LevelSim's arrays; the rules are written once.
##
## Distances are run distances `d` (>= 0, ahead = larger; the scene's z is -d). Every default
## below is the "nothing there" answer, so a view only overrides what its rules use.
##
## HeroKinds (H0) uses: distance, ult_power, clock / store_clock, area_hit, grant_armor, in_fight,
## threat_ahead, hazard_near, army, fx. ChampionKinds (H2) uses: army, in_fight, squads_in,
## hazards_in, hit, status, add_soldiers, fx (the champ_* events listed at ChampionKinds.FX).
## Target ids are ints the view owns (Run: RunKindView maps them to the run's item dictionaries,
## LevelSim: the item index); hit / status accept exactly the ids squads_in / hazards_in returned.


# ------------------------------------------------------------------ H0: starters' rules

## The hero's run distance.
func distance() -> float:
	return 0.0


## Ult effect multiplier (Ult Rank): kills / breaks of every ult hit are x this.
func ult_power() -> float:
	return 1.0


## The ult clock (a live object or a copy; the rules hand it back through store_clock).
func clock() -> HeroKinds.Clock:
	return HeroKinds.Clock.new()


func store_clock(_c: HeroKinds.Clock) -> void:
	pass


## An ult hit on everything alive with d in [d0, d1]: squads lose `kills`, structures `breaks`;
## with `gates`, gates at or ahead of the hero take one hero hit.
func area_hit(_d0: float, _d1: float, _kills: float, _breaks: float, _gates: bool) -> void:
	pass


## The army is immune to hazards and turrets for `s` seconds (Горан's quake).
func grant_armor(_s: float) -> void:
	pass


## True in a clash or the fortress siege.
func in_fight() -> bool:
	return false


## Hostile hp the ult would meet within `reach` u ahead: squads whose span overlaps the blob's
## lane (+0.5 u) count their hp, the fortress counts 99.
func threat_ahead(_reach: float) -> float:
	return 0.0


## True when the first hazard at or ahead of the army centre is alive and within `ahead` u of
## the hero.
func hazard_near(_ahead: float) -> bool:
	return false


## {n, x, d, radius, reserves, revive_pool}: d = the blob CENTRE's run distance (champion slots
## hang off it), x = the blob centre x.
func army() -> Dictionary:
	return {"n": 0.0, "x": 0.0, "d": 0.0, "radius": 0.0, "reserves": 0.0, "revive_pool": 0.0}


## Run: VFX / SFX / HUD signals for `event`; LevelSim: counted only (budget checks).
func fx(_event: StringName, _data := {}) -> void:
	pass


# ------------------------------------------------------------------ H2: champions and new hero kinds

## Living squads with d in [d0, d1] whose span overlaps [x0, x1]:
## [{id, d, x, n, flying, armored, phantom, status}] (n = soldiers left).
func squads_in(_d0: float, _d1: float, _x0: float, _x1: float) -> Array:
	return []


## [{row, x, kind, value}]
func gates_in(_d0: float, _d1: float) -> Array:
	return []


## Living structures with d in [d0, d1]: [{id, d, x, kind, hp}], kind = barricade | blade | turret |
## geode (blades cannot be hit; the rules skip them).
func hazards_in(_d0: float, _d1: float) -> Array:
	return []


## The run's Champions.members (ChampionKinds.member rows; empty while champions are off).
func champions() -> Array:
	return []


## Damages one target ("src" = champion / hero id, "kind" = the action) and returns the kills (squad
## soldiers removed; 0 for structures). The owner's normal hurt path: kill coins, ult charge, statuses.
func hit(_target_id: int, _dmg: float, _tags := {}) -> int:
	return 0


## Applies a status (BURN CHILL JOLT MARK BRAND STAGGER, the Statuses set) for `s` seconds.
func status(_target_id: int, _st: StringName, _s: float) -> void:
	pass


func lose(_n: int, _cause: StringName) -> void:
	pass


func revive_champion(_id: StringName, _hp_frac: float) -> bool:
	return false


## Soldiers come back to the army (Healer Mend; Run: spawned at the blob front with a heal fx).
func add_soldiers(_n: float, _cause: StringName) -> void:
	pass


## Grounds Flying squad `squad_id` for `s` seconds: it counts as a ground squad (no Flying bonuses
## or immunities, ground-only attacks reach it). No-op on a squad that is not Flying.
func ground(_squad_id: int, _s: float) -> void:
	pass


## Holds squad `squad_id` for `s` seconds at `strength` (1 = a full stop, Арін's anchor chain; 0.5 =
## Тая's lull): its advance speed and the clash losses it deals are both x (1 - strength). A new hold
## keeps the stronger strength and the longer time.
func hold(_squad_id: int, _s: float, _strength := 1.0) -> void:
	pass


## Takes one hit of `kind` (turret | blade | contact = a blade or barricade contact) off the army if
## a shield / ward is up (hero ult wards: Пава, Вартан); true = absorbed (consumes one charge). A blade
## hit spends a blade ward first, then a contact ward; a barricade hit (contact) only contact wards.
## The owners ask at every hit (LevelSim._hazards / _turrets spend fractions per soldier lost).
func absorb(_kind: StringName) -> bool:
	return false


## The per-run ward store absorb() spends: `charges` more wards against `kind` hits (turret | blade |
## contact) for `s` seconds (a hero kind's ult grants them; charges add up, the time keeps the longer,
## an expired ward starts over). No-op by default.
func grant_ward(_kind: StringName, _charges: int, _s: float) -> void:
	pass


## Tethers squads `a` and `b` for `s` seconds: `share` of every damage one takes (from any source)
## also hits the other (Дара's harpoon, §6.21); one hop (a share never passes on).
func tether(_a: int, _b: int, _share: float, _s: float) -> void:
	pass


## The damage multiplier a hit on `target_id` gets from its statuses now: MARK's vs (1.25) while it
## runs, 1.0 when none (SEAL, CHILL and STAGGER change no damage in the Run's Statuses). The Run reads
## its Statuses, LevelSim its expected-value mirror. The rules never need it; views use it inside hit().
func status_mult(_target_id: int) -> float:
	return 1.0
