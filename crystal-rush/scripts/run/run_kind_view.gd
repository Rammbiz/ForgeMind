class_name RunKindView
extends KindView
## KindView over the live run (heroes design §10.4): the rules' hits land through the Run's own
## hurt / gate code, fx events become the hero's poses, VFX, SFX and HUD signals. The ult clock
## is the Run's own (Run.ult_clock), so fx handlers always see the current clock.
##
## H2 (champions): target ids are the items' indices in Run.items (stamped as "kid" at spawn,
## Run.kind_item); squads_in / hazards_in read the run's own lists in run distances (d >= 0,
## scene z = -d); hit lands through Run.hurt (kill coins, ult charge, statuses and kill fx as for
## any hit) and returns the soldiers removed; status goes through the run's Statuses; add_soldiers
## through Run.champion_mend (spawned at the blob front); champ_* fx go to Run._champ_fx (VFX and
## the HUD medallions), every other event to the ult's Run._ult_fx.
##
## The rules poll every step while a champion waits for a target, so the answers allocate nothing
## when nothing is there: army() refreshes one dictionary, an empty query returns `_none`, and an
## item's row dictionary is made once and refreshed in place ("kv" on the item).
##
## H2 verbs: a hold / grounding is stamped on the squad's item as the run time it ends ("hold_end",
## "hold_k", "ground_end"; Run's clash / siege ticks and Hazards.step_squads read hold_k); tethers and
## wards live here (Run.hurt passes a tether's share through tether_share); status_mult is the Run's
## Statuses.vs (MARK). Nothing is stamped or stored unless a champion or hero-kind rule calls a verb.

## Hurt source of every champion hit (Run.hurt / Statuses: not a machine, chains like a hero hit).
const SOURCE := "champion"

var run: Run
var _army := {"n": 0.0, "x": 0.0, "d": 0.0, "radius": 0.0, "reserves": 0.0, "revive_pool": 0.0}
var _none: Array = []
var _found: Array = []
var _no_status := {}
var _hz_lists: Array = []
## [[item a, item b, share, end run time], ...] (tether).
var _tethers: Array = []
var _tethering := false
## kind -> [charges, end run time] (grant_ward / absorb).
var _wards := {}


func _init(p_run: Run) -> void:
	run = p_run


func distance() -> float:
	return run.d


func ult_power() -> float:
	return run.hero.ult_power()


func clock() -> HeroKinds.Clock:
	return run.ult_clock


func store_clock(c: HeroKinds.Clock) -> void:
	if c != run.ult_clock:
		run.ult_clock = c


func area_hit(d0: float, d1: float, kills: float, breaks: float, gates: bool) -> void:
	run._ult_hit(d0, d1, gates, kills, breaks)


func grant_armor(sec: float) -> void:
	run._armor = sec


func in_fight() -> bool:
	return run.state == Run.State.CLASH or run.state == Run.State.SIEGE


## d = the blob CENTRE's run distance (the champion slots hang off it, as LevelSim.army_center_d),
## x = the blob centre x (the blob follows the hero's x). HeroKinds reads only n.
func army() -> Dictionary:
	var r := run.blob_radius()
	_army["n"] = float(run.army)
	_army["x"] = run.hx
	_army["d"] = run.d - Balance.HERO_GAP - r * Balance.BLOB_STRETCH
	_army["radius"] = r
	return _army


func champions() -> Array:
	return run.champions.members


func fx(event: StringName, data := {}) -> void:
	if ChampionKinds.FX.has(event):
		run._champ_fx(event, data)
	else:
		run._ult_fx(event, data)


# ------------------------------------------------------------------ H2: champions

## Living squads with d in [d0, d1] whose span (x +- w / 2) overlaps [x0, x1].
func squads_in(d0: float, d1: float, x0: float, x1: float) -> Array:
	_found.clear()
	var list := run.hazards.squads
	for i in range(_lower(list, d0), list.size()):
		var it := list[i]
		var di := float(it["d"])
		if di > d1:
			break
		if not it["alive"]:
			continue
		var x := float(it["x"])
		var hw := float(it.get("w", 2.4)) * 0.5
		if x + hw < x0 or x - hw > x1:
			continue
		_found.append(_squad_row(it))
	return _answer()


## Living structures with d in [d0, d1]: spiked barricades ("barricade"), blades, turrets and
## geodes (never crates, gates or the fortress). Blades are listed (hp 0); the rules skip them.
func hazards_in(d0: float, d1: float) -> Array:
	_found.clear()
	if _hz_lists.is_empty():
		var hz := run.hazards
		_hz_lists = [hz.spikes, hz.blades, hz.turrets, hz.geodes]
	for list: Array[Dictionary] in _hz_lists:
		for i in range(_lower(list, d0), list.size()):
			var it := list[i]
			if float(it["d"]) > d1:
				break
			if it["alive"]:
				_found.append(_hazard_row(it))
	return _answer()


## One hit of `dmg` (on a squad x status_mult: MARK) through Run.hurt; returns the squad soldiers
## removed (0 for structures).
func hit(target_id: int, dmg: float, _tags := {}) -> int:
	var it := run.kind_item(target_id)
	if it.is_empty() or not it.get("alive", false) or dmg <= 0.0:
		return 0
	var kind := str(it["kind"])
	if kind == "blade" or kind == "gate" or kind == "crate":
		return 0
	var t0 := Time.get_ticks_usec()
	# Soldiers removed = the change of the squad's shown count ceil(hp), as SimKindView counts them.
	var before := ceili(maxf(float(it["hp"]) - 0.001, 0.0))
	run.hurt(it, dmg * (_vs(it) if kind == "squad" else 1.0), SOURCE)
	if run.champ_stepping:
		run.champ_perf["hit_us"] = int(run.champ_perf["hit_us"]) + Time.get_ticks_usec() - t0
	if kind != "squad":
		return 0
	return before - (ceili(maxf(float(it["hp"]) - 0.001, 0.0)) if it["alive"] else 0)


## One stack of status `st` (ChampionKinds.ELEMENT_STATUS names) on squad `target_id`, kept at
## least `s` seconds.
func status(target_id: int, st: StringName, s: float) -> void:
	var it := run.kind_item(target_id)
	if it.is_empty() or run.arsenal == null or run.arsenal.statuses == null:
		return
	var sts := run.arsenal.statuses
	var key := String(st)
	sts.apply(it, key, 1.0, {"id": SOURCE, "stats": {"mark_s": s}})
	if s > 0.0 and sts.has(it, key):
		var e: Dictionary = (it["status"] as Dictionary)[key]
		e["t"] = maxf(float(e["t"]), s)


## Healer Mend: `n` soldiers back at the blob front.
func add_soldiers(n: float, _cause: StringName) -> void:
	run.champion_mend(int(floor(n + 0.0001)))


## The Run's Statuses.vs on squad `target_id` (MARK 1.25 while it runs), 1.0 when none.
func status_mult(target_id: int) -> float:
	return _vs(run.kind_item(target_id))


func _vs(it: Dictionary) -> float:
	if it.is_empty() or run.arsenal == null or run.arsenal.statuses == null or str(it.get("kind", "")) != "squad":
		return 1.0
	return run.arsenal.statuses.vs(it)


## Holds squad `squad_id`: stamps the run time it ends and its strength on the item (a new hold keeps
## the stronger strength and the longer time; an expired one is replaced).
func hold(squad_id: int, sec: float, strength := 1.0) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or sec <= 0.0 or strength <= 0.0:
		return
	var k := clampf(strength, 0.0, 1.0)
	var end := float(it.get("hold_end", 0.0))
	if end > run.t:
		k = maxf(k, float(it.get("hold_k", 0.0)))
	it["hold_k"] = k
	it["hold_end"] = maxf(end, run.t + sec)


## The hold on squad item `it` now: its strength, 0 when none (Run's clash / siege ticks: a held foe
## deals x (1 - this); Hazards.step_squads: its charge runs x (1 - this)).
func hold_k(it: Dictionary) -> float:
	if float(it.get("hold_end", 0.0)) <= run.t:
		return 0.0
	return float(it.get("hold_k", 0.0))


## Grounds a Flying squad for `sec` s (its rows say flying false meanwhile); no-op on any other.
func ground(squad_id: int, sec: float) -> void:
	var it := run.kind_item(squad_id)
	if it.is_empty() or not it.get("alive", false) or str(it["kind"]) != "squad" or sec <= 0.0:
		return
	var props: Variant = it.get("props")
	if not (props is Array and (props as Array).has("flying")):
		return
	it["ground_end"] = maxf(float(it.get("ground_end", 0.0)), run.t + sec)


## Tethers squads `a` and `b` for `sec` s: Run.hurt hands every damage either takes to tether_share.
func tether(a: int, b: int, share: float, sec: float) -> void:
	var ia := run.kind_item(a)
	var ib := run.kind_item(b)
	if a == b or ia.is_empty() or ib.is_empty() or share <= 0.0 or sec <= 0.0:
		return
	if not ia.get("alive", false) or not ib.get("alive", false) or str(ia["kind"]) != "squad" or str(ib["kind"]) != "squad":
		return
	for k in range(_tethers.size() - 1, -1, -1):
		if float((_tethers[k] as Array)[3]) <= run.t:
			_tethers.remove_at(k)
	_tethers.append([ia, ib, share, run.t + sec])


## True while any tether was made this run (Run.hurt's cheap test).
func tethered() -> bool:
	return not _tethers.is_empty()


## Run.hurt: `dealt` landed on squad item `it`; each live tether hands its share to the partner (a
## "tether" hit; one hop: the share never passes on).
func tether_share(it: Dictionary, dealt: float) -> void:
	if _tethering or dealt <= 0.0:
		return
	for tt: Array in _tethers:
		if float(tt[3]) <= run.t:
			continue
		var other: Dictionary = {}
		if is_same(tt[0], it):
			other = tt[1]
		elif is_same(tt[1], it):
			other = tt[0]
		if other.is_empty() or not other.get("alive", false):
			continue
		_tethering = true
		run.hurt(other, dealt * float(tt[2]), "tether")
		_tethering = false


func grant_ward(kind: StringName, charges: int, sec: float) -> void:
	if charges <= 0 or sec <= 0.0:
		return
	var w: Array = _wards.get(kind, [0.0, 0.0])
	if float(w[1]) <= run.t:
		w = [0.0, 0.0]
	_wards[kind] = [float(w[0]) + float(charges), maxf(float(w[1]), run.t + sec)]


## One ward charge a `kind` hit may spend (LevelSim.WARD_KINDS: a blade hit spends a blade ward, then a
## contact ward); true = the hit is absorbed.
func absorb(kind: StringName) -> bool:
	if _wards.is_empty():
		return false
	for wk: StringName in LevelSim.WARD_KINDS.get(kind, [kind]):
		var w: Array = _wards.get(wk, [])
		if not w.is_empty() and float(w[1]) > run.t and float(w[0]) >= 1.0:
			w[0] = float(w[0]) - 1.0
			return true
	return false


func _answer() -> Array:
	if _found.is_empty():
		_none.clear()
		return _none
	return _found.duplicate()


func _squad_row(it: Dictionary) -> Dictionary:
	var r: Dictionary = it.get("kv", _no_status)
	if r.is_empty():
		var props: Array = it.get("props", []) if it.get("props") is Array else []
		r = {"id": int(it["kid"]), "d": 0.0, "x": 0.0, "n": 0.0, "flying": props.has("flying"),
				"armored": props.has("armored"), "phantom": props.has("phantom"), "status": _no_status}
		it["kv"] = r
	r["d"] = float(it["d"])
	r["x"] = float(it["x"])
	r["n"] = float(it["hp"])
	r["status"] = it.get("status", _no_status)
	if it.has("ground_end"):
		# A grounded Flying squad reads as a ground squad (ground).
		var props: Array = it.get("props", []) if it.get("props") is Array else []
		r["flying"] = props.has("flying") and float(it["ground_end"]) <= run.t
	return r


func _hazard_row(it: Dictionary) -> Dictionary:
	var r: Dictionary = it.get("kv", _no_status)
	if r.is_empty():
		r = {"id": int(it["kid"]), "d": float(it["d"]), "x": 0.0, "kind": str(it["kind"]), "hp": 0.0}
		it["kv"] = r
	r["x"] = float(it["x"])
	r["hp"] = float(it.get("hp", 0.0))
	return r


## First index of `list` (items sorted by d) with d >= `d0` (binary search).
static func _lower(list: Array[Dictionary], d0: float) -> int:
	var lo := 0
	var hi := list.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(list[mid]["d"]) < d0:
			lo = mid + 1
		else:
			hi = mid
	return lo
