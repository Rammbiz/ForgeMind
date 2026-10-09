class_name SimKindView
extends KindView
## KindView over LevelSim's arrays (heroes design §10.4): the bot, level_check and the planner
## run the same HeroKinds / ChampionKinds rules as the Run. Made on demand (while an ult is charged
## or running, and each step that has champions), so LevelSim.State stays a plain copyable record.
## Target ids are LevelSim item indices. fx is a counter (per event in State.champ_fx while the
## state has champions).

## The shared empty answers (read-only constants: the rules never change what they get).
const _NONE: Array = []
const _NO_STATUS: Dictionary = {}

var lv: LevelSim.Level
var s: LevelSim.State
## fx events seen by this view (budget checks; LevelSim draws nothing).
var fx_count := 0


func _init(p_lv: LevelSim.Level, p_s: LevelSim.State) -> void:
	lv = p_lv
	s = p_s


func distance() -> float:
	return s.d


func ult_power() -> float:
	return s.ult_pow


func clock() -> HeroKinds.Clock:
	var c := HeroKinds.Clock.new()
	c.left = s.ult_left
	c.tick = s.ult_tick
	c.wave = s.quake_wave
	c.wave_d = s.quake_d
	return c


func store_clock(c: HeroKinds.Clock) -> void:
	s.ult_left = c.left
	s.ult_tick = c.tick
	s.quake_wave = c.wave
	s.quake_d = c.wave_d


func area_hit(d0: float, d1: float, kills: float, breaks: float, gates: bool) -> void:
	LevelSim._ult_hit(lv, s, d0, d1, kills, breaks, gates)


func grant_armor(sec: float) -> void:
	s.armor = sec


func in_fight() -> bool:
	return s.mode == LevelSim.Mode.CLASH or s.mode == LevelSim.Mode.SIEGE


func threat_ahead(reach: float) -> float:
	var total := 0.0
	var lo := LevelSim._first_at(lv.d, lv.targ, s.d)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		if lv.d[i] > s.d + reach:
			break
		if s.alive[i] == 0:
			continue
		if lv.kind[i] == LevelSim.K.SQUAD and absf(lv.x[i] - s.hx) <= Balance.blob_radius(s.army) + lv.hw[i] + 0.5:
			total += s.hp[i]
		elif lv.kind[i] == LevelSim.K.FORTRESS:
			total += 99.0
	return total


func hazard_near(ahead: float) -> bool:
	var c := LevelSim.army_center_d(s)
	var lo_h := LevelSim._first_at(lv.d, lv.haz, c)
	return lo_h < lv.haz.size() and lv.d[lv.haz[lo_h]] < s.d + ahead and s.alive[lv.haz[lo_h]] == 1


func army() -> Dictionary:
	# x = the hero's x, the Run's blob centre (Run._army_center); the lagged s.ax stays the hazards'
	# model of the trailing soldiers. HeroKinds reads only n.
	return {"n": s.army, "x": s.hx, "d": LevelSim.army_center_d(s), "radius": Balance.blob_radius(s.army),
			"reserves": s.reserves, "revive_pool": 0.0}


func fx(event: StringName, _data := {}) -> void:
	fx_count += 1
	if s.champs.active():
		s.champ_fx[event] = int(s.champ_fx.get(event, 0)) + 1


# ------------------------------------------------------------------ H2: champions (§4.2, §10.4)

## Living squads with d in [d0, d1] whose span (x +- half width) overlaps [x0, x1]; n = soldiers
## left (hp). flying / armored / phantom come from the item's `props` array, as in the Run; status is
## an empty Dictionary (statuses are not simulated). An empty answer is a shared empty array.
func squads_in(d0: float, d1: float, x0: float, x1: float) -> Array:
	var out: Array = _NONE
	var lo := LevelSim._first_at(lv.d, lv.block, d0)
	for j in range(lo, lv.block.size()):
		var i := lv.block[j]
		if lv.d[i] > d1:
			break
		if s.alive[i] == 0 or lv.kind[i] != LevelSim.K.SQUAD:
			continue
		if lv.x[i] + lv.hw[i] < x0 or lv.x[i] - lv.hw[i] > x1:
			continue
		var it := lv.items[i]
		var props: Array = it["props"] if it.get("props") is Array else _NONE
		if is_same(out, _NONE):
			out = []
		out.append({"id": i, "d": float(lv.d[i]), "x": float(lv.x[i]), "n": float(s.hp[i]),
				"flying": props.has("flying"), "armored": props.has("armored"),
				"phantom": props.has("phantom"), "status": _NO_STATUS})
	return out


## Living barricades, turrets and geodes with d in [d0, d1], then the blades (kind "blade": the
## rules never hit them): [{id, d, x, kind, hp}].
func hazards_in(d0: float, d1: float) -> Array:
	var out: Array = _NONE
	var lo := LevelSim._first_at(lv.d, lv.targ, d0)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		if lv.d[i] > d1:
			break
		if s.alive[i] == 0:
			continue
		var kind: StringName
		match lv.kind[i]:
			LevelSim.K.BARRICADE:
				kind = &"barricade"
			LevelSim.K.TURRET:
				kind = &"turret"
			LevelSim.K.GEODE:
				kind = &"geode"
			_:
				continue
		if is_same(out, _NONE):
			out = []
		out.append({"id": i, "d": float(lv.d[i]), "x": float(lv.x[i]), "kind": kind, "hp": float(s.hp[i])})
	var lo_h := LevelSim._first_at(lv.d, lv.haz, d0)
	for j in range(lo_h, lv.haz.size()):
		var i := lv.haz[j]
		if lv.d[i] > d1:
			break
		if lv.kind[i] == LevelSim.K.BLADE:
			if is_same(out, _NONE):
				out = []
			out.append({"id": i, "d": float(lv.d[i]), "x": float(lv.x[i]), "kind": &"blade", "hp": 0.0})
	return out


func champions() -> Array:
	return s.champs.members


## LevelSim's own hurt path (kills, ult charge, breaking pays out). Returns the whole soldiers a
## squad lost (its shown count is ceil(hp)); 0 for structures.
func hit(target_id: int, dmg: float, _tags := {}) -> int:
	if target_id < 0 or target_id >= s.alive.size() or s.alive[target_id] == 0:
		return 0
	if lv.kind[target_id] != LevelSim.K.SQUAD:
		LevelSim._hurt(lv, s, target_id, dmg)
		return 0
	var before := ceilf(maxf(s.hp[target_id] - 0.001, 0.0))
	LevelSim._hurt(lv, s, target_id, dmg)
	var after := ceilf(maxf(s.hp[target_id] - 0.001, 0.0)) if s.alive[target_id] == 1 else 0.0
	return int(before - after)


## Statuses are not simulated (LevelSim is an expected-value model).
func status(_target_id: int, _st: StringName, _s: float) -> void:
	pass


## Mend returns join the army (the Run spawns them at the blob front).
func add_soldiers(n: float, _cause: StringName) -> void:
	s.army += n
	s.peak = maxf(s.peak, s.army)
