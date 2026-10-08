class_name SimKindView
extends KindView
## KindView over LevelSim's arrays (heroes design §10.4): the bot, level_check and the planner
## run the same HeroKinds rules as the Run. Made on demand (only while an ult is charged or
## running), so LevelSim.State stays a plain copyable record. fx is a counter.

var lv: LevelSim.Level
var s: LevelSim.State
## fx events seen (budget checks; LevelSim draws nothing).
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
	return {"n": s.army, "x": s.ax, "d": LevelSim.army_center_d(s), "radius": Balance.blob_radius(s.army),
			"reserves": s.reserves, "revive_pool": 0.0}


func fx(_event: StringName, _data := {}) -> void:
	fx_count += 1
