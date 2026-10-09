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
## HeroKinds (H2, the v3 hero kinds of §6) also uses: squads_in, hazards_in, structures_in, gates_in,
## hit, status, hold, ground, expose, strip, silence, reveal, grant_ward, buff, add_soldiers,
## champions, revive_champion, siege, army()["lost"] and the clock's H2 fields (HeroKinds.Clock: the
## hero kind's counters persist in the view's clock from ult to ult).
## Target ids are ints the view owns (Run: RunKindView maps them to the run's item dictionaries,
## LevelSim: the item index); hit / status accept exactly the ids squads_in / hazards_in /
## structures_in / gates_in returned.


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


## {n, x, d, radius, reserves, revive_pool, lost}: d = the blob CENTRE's run distance (champion slots
## hang off it), x = the blob centre x (= the hero's x), lost = soldiers the army has lost this run
## from any cause (clash, siege, hazard, turret, gate; HeroKinds' ward and army_loss policy read it; a
## view without it answers 0 and those rules see no loss).
func army() -> Dictionary:
	return {"n": 0.0, "x": 0.0, "d": 0.0, "radius": 0.0, "reserves": 0.0, "revive_pool": 0.0, "lost": 0.0}


## Run: VFX / SFX / HUD signals for `event`; LevelSim: counted only (budget checks).
func fx(_event: StringName, _data := {}) -> void:
	pass


# ------------------------------------------------------------------ H2: champions and new hero kinds

## Living squads with d in [d0, d1] whose span overlaps [x0, x1]:
## [{id, d, x, n, flying, armored, phantom, status, hw}] (n = soldiers left, hw = half its width; a
## row without hw counts as HeroKinds.SQUAD_HW).
func squads_in(_d0: float, _d1: float, _x0: float, _x1: float) -> Array:
	return []


## Gates still standing (rows not yet crossed) with d in [d0, d1], nearest first:
## [{id, row, d, x, hw, kind, value, hidden}] (kind = the op it shows now, "+" "-" "charge" ...; hidden =
## its value is not revealed yet). hit(id, n) on a gate = `n` hero hits (the view's own hero damage per
## hit, as area_hit's gate hits; a charge gate fills, a "-" gate shrinks); it returns 0.
func gates_in(_d0: float, _d1: float) -> Array:
	return []


## Living structures with d in [d0, d1]: [{id, d, x, kind, hp}], kind = barricade | blade | turret |
## geode (blades cannot be hit; the rules skip them).
func hazards_in(_d0: float, _d1: float) -> Array:
	return []


## What a hero ult or attack may break with d in [d0, d1] (H2 hero kinds): the hazards_in structures (never
## blades) plus crates (kind "crate") and the fortress (kind "fortress", hw = the half bridge): [{id, d, x,
## kind, hp, hw}]. The champion rules never ask (they hit no crates and no fortress). Default: hazards_in
## without the blades (a view that lists no crates or fortress: hero kinds then never break them).
func structures_in(d0: float, d1: float) -> Array:
	var out: Array = []
	for h: Dictionary in hazards_in(d0, d1):
		if str(h["kind"]) != "blade":
			out.append(h)
	return out


## True during the fortress siege (in_fight() is a clash or the siege).
func siege() -> bool:
	return false


## The run's Champions.members (ChampionKinds.member rows; empty while champions are off).
func champions() -> Array:
	return []


## Damages one target ("src" = champion / hero id, "kind" = the action) and returns the kills (squad
## soldiers removed; 0 for structures). The owner's normal hurt path: kill coins, ult charge, statuses.
## Hero kinds tag their hits "kind" &"attack" (a hero shot: MARK's vs applies, as on the starters' shots),
## &"ult" (never MARK's vs: the Meta-1 rule, ults and volleys take none) or &"gate" (a gate id: `dmg` hero
## hits, see gates_in). A crate or the fortress (structures_in ids) takes `dmg` like any structure.
func hit(_target_id: int, _dmg: float, _tags := {}) -> int:
	return 0


## Applies a status (BURN CHILL JOLT MARK BRAND STAGGER, the Statuses set) for `s` seconds.
func status(_target_id: int, _st: StringName, _s: float) -> void:
	pass


func lose(_n: int, _cause: StringName) -> void:
	pass


## A Healer hero stands fallen champion `id` back up at `hp_frac` of its max HP (§4.2: only Healer heroes
## revive; Ейра form II, Пава forms II / V and her Awakening): ChampionKinds.revive. False when it is alive or
## unknown.
func revive_champion(_id: StringName, _hp_frac: float) -> bool:
	return false


## Soldiers come back to the army (Healer Mend; Run: spawned at the blob front with a heal fx). Hero kinds:
## cause &"heal" (Ейра's rime), &"ward" (Пава's close), &"mend" / &"eye" (Healer hero procs, paid from the
## hero's revive pool, HeroKinds.Clock.pool). Whole soldiers.
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
## contact | clash) for `s` seconds (a hero kind's ult grants them; charges add up, the time keeps the
## longer, an expired ward starts over). `clash` (Вартан's wall HP): each charge takes one soldier of the
## army's clash / siege losses before the army loses it (the owner's clash tick spends it). No-op by default.
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


# ------------------------------------------------------------------ H2: the v3 hero kinds (§6.1-6.10, 6.28, 6.29)
# Every default below is "nothing happens": a view that does not model a verb simply loses that rider.

## Squad `squad_id` loses x (1 + `add`) of its clash losses for `s` seconds (Веста form II, Сірко form II:
## "squads hit lose +20% in clashes"; a new exposure keeps the larger add and the longer time).
func expose(_squad_id: int, _add: float, _s: float) -> void:
	pass


## Squad `squad_id` fights as a plain squad for `s` seconds: Armored and Shielded off (Сірко form IV).
func strip(_squad_id: int, _s: float) -> void:
	pass


## Turret `turret_id` misses every shot for `s` seconds (Ольга form IV).
func silence(_turret_id: int, _s: float) -> void:
	pass


## Hidden gates and Phantom squads with d in [d0, d1] are revealed (Мейра form III, Пава form IV, a row
## reveal of a hero hit, Мейра's beat 6).
func reveal(_d0: float, _d1: float) -> void:
	pass


## A timed team buff for `s` seconds (a new one keeps the larger value and the longer time): &"volleys"
## = army volley damage x (1 + value) (Веста's Sun Field), &"machines" = machine damage + value (bucket 2,
## inside TEAM_B2_CAP; Люмен form V), &"volley_status" = every army volley also applies data.statuses (id ->
## stacks) to its target (Сірко form V).
func buff(_kind: StringName, _value: float, _s: float, _data := {}) -> void:
	pass
