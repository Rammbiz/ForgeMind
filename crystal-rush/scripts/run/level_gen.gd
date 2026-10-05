class_name LevelGen
## Builds a level as a list of items along the bridge (Etap 1 spec, section 4).
##
## Levels 1-3 are hand-made tutorials; from level 4 on a level is a string of chunks (Subway
## Surfers style) picked from a library that unlocks one or two elements per level. Every chunk
## asks for a real decision every 2-4 s: the best gate depends on the current army (forecast),
## on the hero (charge / power gates) or on risk, and hazards guard the best rewards.
##
## Numbers follow `e`, the army a good player is expected to have at that point (Supersonic
## rule: threats grow with the level, rewards compound through x-gates, which only appear while
## e is small enough not to explode). LevelSim / level_check verify the result: the best path
## must win with a margin, a lazy path down the middle must clearly lose from about level 5.
##
## Output: {"items": Array[Dictionary] sorted by d, "length": fortress distance,
##          "expected": e at the fortress, "hints": [{"d", "key"}], "script": {"ult_ready_at"}}

const START_D := 10.0
const ROW2_X := 1.65            # two gates: centres at +-ROW2_X, a gap in the middle
const ROW2_W := 2.1
const ROW3_X := 2.25            # three gates: left, centre, right
const ROW3_W := 1.7
const TURRET_X := 3.25
const BIG := 90.0               # above this expected army no more x-gates

## Level from which each element may appear (plan section 9 + weapons).
const UNLOCK := {
	"tiles": 1, "recruits": 1, "gates": 1, "squad": 1,
	"red": 2, "crate": 2,
	"barricade": 3, "charge": 3,
	"rotor": 4, "moving": 4, "arm": 4,
	"turret": 5, "geode": 5, "power": 5,
	"blink": 6, "hidden": 6, "sweeper": 6,
	"multi": 7, "blaster": 9,
}

## First hint for an element on the level it unlocks.
const FIRST_HINT := {
	"crate": "HINT_CRATE", "barricade": "HINT_SPIKES", "charge": "HINT_CHARGE", "rotor": "HINT_BLADES",
	"arm": "HINT_ARM", "turret": "HINT_TURRET", "geode": "HINT_GEODE", "sweeper": "HINT_BLADES",
}

## Weapon crate of each tutorial / unlock level.
const CRATE_AT := {2: "cannon", 4: "ballista", 6: "rockets", 8: "laser", 10: "drone"}


## Generator state while a level is being laid out.
class Gen extends RefCounted:
	var rng := RandomNumberGenerator.new()
	var level := 1
	var d := START_D
	var e := 3.0
	var items: Array[Dictionary] = []
	var hints: Array = []
	var row := 0
	var shown := {}
	var arm := 0
	var weapons := 0
	var script := {}
	var used := {}


static func build(level: int, base_army: int) -> Dictionary:
	var g := Gen.new()
	g.level = maxi(level, 1)
	g.rng.seed = 7919 * g.level + 104729
	g.e = float(base_army)
	match g.level:
		1:
			_tutorial_1(g)
		2:
			_tutorial_2(g)
		3:
			_tutorial_3(g)
		_:
			_procedural(g)
	return _finish(g)


static func target_length(level: int) -> float:
	return minf(160.0 + 20.0 * (level - 1), 380.0)


## Share of the expected army a threat is sized at; grows with the level.
static func threat(g: Gen) -> float:
	return 0.3 + 0.026 * mini(g.level, 16)


# ------------------------------------------------------------------ tutorials

## Level 1, "First dash": drag, collect, grow. Tiles, grey recruits, blue gate pairs and one
## small squad that is always smaller than the army.
static func _tutorial_1(g: Gen) -> void:
	_hint(g, 0.0, "HINT_DRAG")
	_tile_line(g, -2.2, -0.4, 12.0, 7, 1.3)
	_coin_line(g, 2.2, 13.0, 5)
	_hint(g, 22.0, "HINT_RECRUITS")
	_recruits(g, 2.3, 30.0, 4)
	_recruits(g, -2.3, 36.0, 3)
	g.e += 12.0
	_hint(g, 36.0, "HINT_GATES")
	_row(g, 48.0, [_gate("+", 6), _gate("x", 2)])
	g.e *= 2.0
	_tile_line(g, 0.0, 2.4, 58.0, 8, 1.2)
	g.e += 8.0
	_squad(g, -1.4, 76.0, 2.6, 6)
	_coin_line(g, -1.4, 80.0, 6)
	_tile_line(g, 2.0, 2.0, 74.0, 6, 1.2)
	_recruits(g, -2.4, 94.0, 5)
	_recruits(g, 2.4, 98.0, 4)
	g.e += 5.0
	_row(g, 112.0, [_gate("x", 2), _gate("+", 14)])
	g.e *= 1.9
	_tile_line(g, -2.0, 2.0, 122.0, 9, 1.15)
	_coin_line(g, 0.0, 134.0, 6)
	_row(g, 146.0, [_gate("+", 10), _gate("+", 18)])
	g.e += 18.0
	g.d = 160.0


## Level 2, "Not everything that shines": red gates and forecasts, a row where the bigger number
## is worse, the first squad bigger than an ungrown army, and the first weapon crate (cannon).
static func _tutorial_2(g: Gen) -> void:
	_hint(g, 0.0, "HINT_GATES")
	_tile_line(g, 1.8, 1.8, 12.0, 6, 1.2)
	_recruits(g, -2.3, 16.0, 5)
	g.e += 6.0
	_hint(g, 22.0, "HINT_FORECAST")
	# Army ~9 here: x2 gives ~18, +15 gives ~24: the bigger-looking x2 is worse.
	_row(g, 32.0, [_gate("x", 2), _gate("-", 4), _gate("+", 15)])
	g.e += 15.0
	_tile_line(g, -2.3, -0.6, 42.0, 7, 1.2)
	_coin_line(g, 2.2, 42.0, 7)
	g.e += 7.0
	# The first squad bigger than an ungrown army: skirt it by the rail or fight it.
	_squad(g, 0.6, 62.0, 3.6, 22)
	_tile_line(g, -2.9, -2.9, 58.0, 5, 1.2)
	_coin_line(g, 0.6, 66.0, 6)
	_hint(g, 72.0, "HINT_CRATE")
	_crate(g, -2.0, 86.0, 6, "cannon")
	_row(g, 96.0, [_gate("+", 12), _gate("x", 2)])
	g.e *= 2.0
	_tile_line(g, 2.2, -2.2, 106.0, 9, 1.2)
	g.e += 6.0
	_row(g, 128.0, [_gate("-", 10), _gate("x", 2), _gate("+", 20)])
	g.e = maxf(g.e * 2.0, g.e + 20.0) * 0.95
	_squad(g, -1.7, 146.0, 3.0, int(g.e * 0.3))
	_recruits(g, 2.4, 150.0, 6)
	_coin_line(g, -1.7, 152.0, 6)
	_row(g, 166.0, [_gate("+", 16), _gate("-", 8), _gate("+", 24)])
	g.e += 18.0
	g.d = 180.0


## Level 3, "The hero at work": a spiked barricade over half the bridge, a charge gate that the
## hero's shots flip into x2, and an ult charged by script before a big squad.
static func _tutorial_3(g: Gen) -> void:
	_tile_line(g, -2.0, 0.0, 12.0, 6, 1.2)
	_recruits(g, 2.3, 18.0, 6)
	g.e += 10.0
	_row(g, 30.0, [_gate("+", 10), _gate("x", 2)])
	g.e *= 1.9
	_hint(g, 36.0, "HINT_SPIKES")
	_barricade(g, -1.6, 50.0, 3.6, 30)
	_recruits(g, -2.1, 58.0, 8)
	_tile_line(g, 2.2, 2.2, 52.0, 5, 1.2)
	g.e += 5.0
	_hint(g, 62.0, "HINT_CHARGE")
	var charge := _gate("charge", -10)
	charge["reward"] = {"op": "x", "value": 2}
	_row(g, 78.0, [charge, _gate("+", 14)])
	g.e *= 1.85
	_tile_line(g, 2.4, -2.4, 88.0, 8, 1.2)
	_coin_line(g, 0.0, 92.0, 5)
	g.e += 5.0
	_row(g, 108.0, [_gate("-", 8), _gate("+", int(g.e * 0.4)), _gate("x", 2)])
	g.e *= 1.9
	# Scripted ult right before the big squad.
	g.script["ult_ready_at"] = 124.0
	_hint(g, 126.0, "HINT_ULT")
	_squad(g, 0.0, 142.0, 4.4, int(g.e * 0.75))
	g.e *= 0.85
	_coin_line(g, 0.0, 148.0, 6)
	_recruits(g, -2.3, 156.0, 6)
	_recruits(g, 2.3, 160.0, 6)
	_crate(g, 2.0, 172.0, 7, "cannon")
	_row(g, 184.0, [_gate("+", int(g.e * 0.4)), _gate("+", int(g.e * 0.25))])
	g.e *= 1.3
	g.d = 200.0


# ------------------------------------------------------------------ procedural levels

## Chunk pool: name -> [weight, unlock key].
const CHUNKS := {
	"tiles": [2.0, "tiles"], "gates": [3.0, "gates"], "squad_wall": [2.0, "squad"],
	"squad_fork": [2.0, "squad"], "recruits": [1.5, "recruits"], "red_row": [2.0, "red"],
	"crate": [1.6, "crate"], "barricade": [2.2, "barricade"], "charge": [1.6, "charge"],
	"rotor": [1.8, "rotor"], "moving": [1.5, "moving"], "arm": [1.4, "arm"], "turret": [1.8, "turret"],
	"geode": [1.5, "geode"], "power": [1.4, "power"], "blink": [1.4, "blink"], "hidden": [1.3, "hidden"],
	"sweeper": [1.6, "sweeper"],
}
const THREATS := ["squad_wall", "squad_fork", "barricade", "rotor", "turret", "sweeper"]


static func _procedural(g: Gen) -> void:
	var length := target_length(g.level)
	# New elements of this level go first so their hint lands early; crates on schedule.
	var intro: Array[String] = []
	for chunk: String in CHUNKS:
		var key: String = CHUNKS[chunk][1]
		if int(UNLOCK[key]) == g.level:
			intro.append(chunk)
	var crate_kind := str(CRATE_AT.get(g.level, ""))
	_chunk(g, "tiles")
	var last := "tiles"
	var since_threat := 0
	var since_gate := 0
	var n := 0
	while g.d < length - 26.0:
		var pick := ""
		if not intro.is_empty() and n >= 1:
			pick = intro.pop_front()
		elif crate_kind != "" and g.d > length * 0.3:
			pick = "crate"
		elif since_threat >= 2:
			pick = _weighted(g, THREATS, last)
		elif since_gate >= 2:
			pick = _weighted(g, ["gates", "red_row", "charge", "moving", "power", "blink", "hidden", "arm"], last)
		else:
			pick = _weighted(g, CHUNKS.keys(), last)
		if pick == "crate":
			_crate_chunk(g, crate_kind if crate_kind != "" else _late_weapon(g))
			crate_kind = ""
		else:
			_chunk(g, pick)
		since_threat = 0 if pick in THREATS else since_threat + 1
		since_gate = 0 if pick in ["gates", "red_row", "charge", "moving", "power", "blink", "hidden", "arm", "squad_fork", "barricade"] else since_gate + 1
		last = pick
		n += 1
	# A late extra crate from level 7 on.
	g.d = maxf(g.d, length - 6.0)


static func _weighted(g: Gen, pool: Array, last: String) -> String:
	var total := 0.0
	var ok: Array[String] = []
	var ws: Array[float] = []
	for c: String in pool:
		var key: String = CHUNKS[c][1]
		if int(UNLOCK[key]) > g.level or c == last:
			continue
		if c == "arm" and g.arm >= (2 if g.level >= int(UNLOCK["blaster"]) else 1):
			continue
		var w := float(CHUNKS[c][0])
		# Newer elements a little more often so each world feels different.
		if int(UNLOCK[key]) >= g.level - 2:
			w *= 1.4
		ok.append(c)
		ws.append(w)
		total += w
	var roll := g.rng.randf() * total
	for k in ok.size():
		roll -= ws[k]
		if roll <= 0.0:
			return ok[k]
	return ok[ok.size() - 1] if not ok.is_empty() else "tiles"


static func _late_weapon(g: Gen) -> String:
	var pool: Array[String] = ["cannon", "ballista", "rockets"]
	if g.level >= 8:
		pool.append("laser")
	if g.level >= 10:
		pool.append("drone")
	return pool[g.rng.randi() % pool.size()]


static func _chunk(g: Gen, name: String) -> void:
	var key: String = CHUNKS[name][1]
	if FIRST_HINT.has(key) and int(UNLOCK[key]) == g.level:
		_hint(g, g.d - 4.0, FIRST_HINT[key])
	g.used[name] = int(g.used.get(name, 0)) + 1
	match name:
		"tiles":
			_c_tiles(g)
		"gates":
			_c_gates(g)
		"red_row":
			_c_red_row(g)
		"recruits":
			_c_recruits(g)
		"squad_wall":
			_c_squad_wall(g)
		"squad_fork":
			_c_squad_fork(g)
		"crate":
			_crate_chunk(g, _late_weapon(g))
		"barricade":
			_c_barricade(g)
		"charge":
			_c_charge(g)
		"rotor":
			_c_rotor(g)
		"moving":
			_c_moving(g)
		"arm":
			_c_arm(g)
		"turret":
			_c_turret(g)
		"geode":
			_c_geode(g)
		"power":
			_c_power(g)
		"blink":
			_c_blink(g)
		"hidden":
			_c_hidden(g)
		"sweeper":
			_c_sweeper(g)


# ------------------------------------------------------------------ chunks

## A snake of +1 tiles across the bridge, coins on the other side: steer for soldiers or coins.
static func _c_tiles(g: Gen) -> void:
	var s := _side(g)
	var n := 7 + g.rng.randi_range(0, 3) + mini(g.level / 3, 4)
	_tile_line(g, 2.2 * s, -0.6 * s, g.d + 2.0, n, 1.2)
	_coin_line(g, -2.2 * s, g.d + 3.0, 6)
	g.e += n * 0.9
	g.d += 6.0 + n * 1.2


## Grey recruits by the rails; the bigger group sits next to a hazard from level 3 on.
static func _c_recruits(g: Gen) -> void:
	var s := _side(g)
	var small := 3 + g.rng.randi_range(0, 2)
	var big := 6 + g.rng.randi_range(0, 3) + int(g.e * 0.08)
	_recruits(g, -2.3 * s, g.d + 4.0, small)
	_recruits(g, 2.4 * s, g.d + 12.0, big)
	_tile_line(g, -1.6 * s, -1.6 * s, g.d + 8.0, 5, 1.2)
	if g.level >= 4:
		# The big group is guarded: a short barricade in front of it at the rail.
		_barricade(g, 1.9 * s, g.d + 8.0, 2.4, int(6 + g.level + g.e * 0.12))
	g.e += big * 0.9
	g.d += 20.0


## Gate row whose best choice depends on the army: +N vs x2 near the break-even point, with a
## tile lead-in on one side that moves the forecast.
static func _c_gates(g: Gen) -> void:
	var s := _side(g)
	var lead := g.rng.randf() < 0.6
	var a := g.e
	if lead:
		_tile_line(g, 1.65 * s, 1.65 * s, g.d + 1.0, 6, 1.1)
	var rd := g.d + 15.0
	var mult := g.e < BIG
	var opts: Array[Dictionary] = []
	if mult:
		var k := 3 if g.e < 18.0 and g.rng.randf() < 0.35 else 2
		# +N close to the break-even point of xk (pumping a + gate adds ~6 more).
		var n := int(round(a * (k - 1) * g.rng.randf_range(0.75, 1.2))) + g.level
		var xg := _gate("x", k)
		var pg := _gate("+", maxi(n, 4))
		# The x gate sits on the lead side half of the time: then the tiles make it better.
		opts = [xg, pg] if g.rng.randf() < 0.5 else [pg, xg]
		g.e = maxf((a + (6.0 if lead else 0.0)) * k, a + n + 6.0) * 0.96
	else:
		var n2 := int(round(a * g.rng.randf_range(0.35, 0.55))) + g.level
		var n3 := int(round(a * g.rng.randf_range(0.2, 0.3))) + g.level
		opts = [_gate("+", n2), _gate("+", n3)]
		if g.rng.randf() < 0.5:
			opts.reverse()
		g.e = a + n2 + 5.0
	if s < 0:
		opts.reverse()
	if g.level >= int(UNLOCK["red"]) and g.rng.randf() < 0.55:
		# A red gate in the middle punishes autopilot.
		opts.insert(1, _gate("-", int(round(a * 0.3)) + 3 + g.level))
	_row(g, rd, opts)
	g.d = rd + 6.0


## Three gates: the best one is guarded by a red gate in front of it.
static func _c_red_row(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var red := int(round(a * g.rng.randf_range(0.18, 0.3))) + 2 + g.level
	# Front row: a red gate on the side of the big reward, nothing on the other.
	_row(g, g.d + 6.0, [_gate_at("-", red, 1.65 * s, 2.0), _gate_at("+", int(a * 0.15) + 2, -1.65 * s, 2.0)])
	var best := _gate("x", 2) if a < BIG else _gate("+", int(round(a * 0.7)) + g.level)
	var mid := _gate("+", int(round(a * 0.25)) + g.level)
	var weak := _gate("-", int(round(a * 0.15)) + 2)
	var opts: Array[Dictionary] = [weak, mid, best]
	if s < 0:
		opts.reverse()
	_row(g, g.d + 18.0, opts)
	var via_red := (maxf(a - red, 1.0)) * 2.0 if a < BIG else a - red + a * 0.7
	g.e = maxf(via_red, a + a * 0.4 + 5.0) * 0.96
	g.d += 24.0


## A wide squad in the middle with a reward behind it. Small armies slip by at the rail;
## big ones must fight (or the hero thins it first).
static func _c_squad_wall(g: Gen) -> void:
	var a := g.e
	var size := int(round(a * threat(g) * g.rng.randf_range(0.9, 1.2))) + g.level + 2
	var w := 3.4 + minf(g.level * 0.05, 0.6)
	_squad(g, 0.0, g.d + 10.0, w, size)
	var rew := int(round(4 + a * 0.12))
	_recruits(g, 0.0, g.d + 15.0, rew)
	_coin_line(g, 0.0, g.d + 17.0, 5)
	_tile_line(g, -2.9, -2.9, g.d + 4.0, 4, 1.2)
	_tile_line(g, 2.9, 2.9, g.d + 4.0, 4, 1.2)
	g.e = maxf(a + rew - size * 0.85, a + 2.0)
	g.d += 22.0


## Squad on one side guarding a big gate; the free side has a small one.
static func _c_squad_fork(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var size := int(round(a * threat(g) * g.rng.randf_range(1.0, 1.3))) + g.level + 2
	_squad(g, 1.75 * s, g.d + 8.0, 2.8, size)
	var big := _gate("x", 2) if a < BIG else _gate("+", int(round(a * 0.8)) + g.level)
	var small := _gate("+", int(round(a * 0.3)) + g.level)
	_row(g, g.d + 17.0, [big, small] if s > 0 else [small, big])
	if s > 0:
		_row_fix_x(g, 1.65 * s, -1.65 * s)
	else:
		_row_fix_x(g, -1.65 * s, 1.65 * s)
	var after := maxf(a - size * 0.8, 1.0)
	var via_big := after * 2.0 if a < BIG else after + a * 0.8
	g.e = maxf(via_big, a + a * 0.3 + 6.0) * 0.96
	g.d += 24.0


## A spiked barricade over one half guards the better gate; slipping by the edge costs a few,
## going straight through costs many.
static func _c_barricade(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var hp := int(round(6 + g.level * 1.5 + a * 0.3))
	var w := g.rng.randf_range(2.8, 3.4)
	_barricade(g, (3.5 - w * 0.5) * s, g.d + 6.0, w, hp)
	var best := _gate("x", 2) if a < BIG else _gate("+", int(round(a * 0.75)) + g.level)
	var other := _gate("+", int(round(a * 0.3)) + g.level)
	_row(g, g.d + 15.0, [best, other] if s > 0 else [other, best])
	_row_fix_x(g, 1.65, -1.65)
	_coin_line(g, -2.4 * s, g.d + 6.0, 5)
	var edge := a * 0.12
	g.e = maxf(((a - edge) * 2.0 if a < BIG else a - edge + a * 0.75), a * 1.3 + 4.0) * 0.96
	g.d += 22.0


## Charge gate next to a plain + gate: spend the hero's fire flipping it or take the sure thing.
static func _c_charge(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var need := 8 + g.level / 2 + g.rng.randi_range(0, 3)
	var cg := _gate("charge", -need)
	var roll := g.rng.randf()
	if roll < 0.45 and a < BIG:
		cg["reward"] = {"op": "x", "value": 2}
	elif roll < 0.7:
		cg["reward"] = {"op": "weapon", "value": 1, "weapon": _late_weapon(g)}
	elif roll < 0.85:
		cg["reward"] = {"op": "ult", "value": 1}
	else:
		cg["reward"] = {"op": "+", "value": int(round(a * 0.8)) + g.level}
	var plus := _gate("+", int(round(a * 0.4)) + g.level)
	_row(g, g.d + 16.0, [cg, plus] if s > 0 else [plus, cg])
	# Something else wants the hero's fire on the other side.
	if g.level >= 6:
		if g.rng.randf() < 0.3:
			_crate(g, -2.2 * s, g.d + 6.0, 5 + g.level / 3, _late_weapon(g))
		else:
			_squad(g, -1.7 * s, g.d + 8.0, 2.4, int(a * 0.2) + g.level)
	var rw: Dictionary = cg["reward"]
	match str(rw["op"]):
		"x":
			g.e = maxf(a * 2.0, a + a * 0.4 + 6.0) * 0.95
		"+":
			g.e = a + a * 0.8
		_:
			g.e = a + a * 0.4 + 6.0
	g.d += 22.0


## Weapon crate off the best line: shoot it open (aim away from the better gate) or not.
static func _crate_chunk(g: Gen, weapon: String) -> void:
	if weapon == "":
		weapon = _late_weapon(g)
	var s := _side(g)
	var a := g.e
	var hp := 6 + g.level / 3
	_crate(g, 2.1 * s, g.d + 8.0, hp, weapon)
	var good := _gate("+", int(round(a * 0.5)) + g.level + 2) if a >= BIG * 0.6 else _gate("x", 2)
	var meh := _gate("+", int(round(a * 0.25)) + g.level)
	# The better gate is on the far side from the crate.
	_row(g, g.d + 18.0, [meh, good] if s > 0 else [good, meh])
	_row_fix_x(g, 1.65, -1.65)
	_tile_line(g, 2.1 * s, 2.1 * s, g.d + 10.0, 4, 1.1)
	g.weapons += 1
	g.e = maxf(a * 2.0 if a < BIG * 0.6 else a * 1.5 + 6.0, a + 8.0) * 0.95
	g.d += 24.0


## Rotor blade guarding a big recruit group; the free side has a few tiles.
static func _c_rotor(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var length := 1.4 + g.rng.randf_range(0.0, 0.4)
	_rotor(g, 1.6 * s, g.d + 8.0, length, 2.4 + g.level * 0.05, g.rng.randf() * TAU)
	var rew := int(round(6 + a * 0.18))
	_recruits(g, 1.6 * s, g.d + 13.0, rew)
	_tile_line(g, -1.8 * s, -1.8 * s, g.d + 4.0, 6, 1.2)
	if g.level >= 6 and g.rng.randf() < 0.5:
		_rotor(g, -0.4 * s, g.d + 16.0, 1.3, -2.6, g.rng.randf() * TAU)
	g.e += maxf(rew * 0.7, 6.0)
	g.d += 20.0


## A narrow moving x gate against a wide still + gate: timing vs a sure thing.
static func _c_moving(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var k := 3 if a < 25.0 else 2
	var mv := _gate("x", k) if a < BIG else _gate("+", int(round(a * 0.8)) + g.level)
	mv["w"] = 1.3
	mv["move"] = {"amp": 1.4, "period": 2.4 + g.rng.randf_range(0.0, 0.6), "phase": g.rng.randf() * TAU}
	var still := _gate("+", int(round(a * 0.45)) + g.level + 2)
	_row(g, g.d + 15.0, [mv, still] if s > 0 else [still, mv])
	_row_fix_x(g, 1.2, -1.95)
	g.e = maxf(a * k if a < BIG else a * 1.8, a * 1.45 + 2.0) * 0.95
	g.d += 21.0


## Army weapons gate: crossbows (later blasters) vs soldiers now.
static func _c_arm(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var tier := 2 if g.level >= int(UNLOCK["blaster"]) and g.arm >= 1 else 1
	var arm := _gate("arm", tier)
	var plus := _gate("+", int(round(a * 0.45)) + g.level + 3)
	var opts: Array[Dictionary] = [arm, plus] if s > 0 else [plus, arm]
	if g.level >= 6:
		opts.insert(1, _gate("-", int(round(a * 0.25)) + g.level))
	_row(g, g.d + 14.0, opts)
	g.arm = maxi(g.arm, tier)
	g.e = a * 1.15 + 3.0
	# A squad soon after so the choice shows.
	_squad(g, -1.2 * s, g.d + 22.0, 3.0, int(round(a * threat(g) * 0.8)) + g.level)
	g.d += 28.0


## A railing turret mows the army until the hero takes it down; the better gate is across.
static func _c_turret(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var hp := 5 + g.level / 2
	_turret(g, s, g.d + 14.0, hp, 7.0, 2.2 + g.level * 0.08)
	var good := _gate("+", int(round(a * 0.55)) + g.level + 2) if a >= BIG * 0.7 else _gate("x", 2)
	var meh := _gate("+", int(round(a * 0.25)) + g.level)
	_row(g, g.d + 12.0, [meh, good] if s > 0 else [good, meh])
	_row_fix_x(g, 1.65, -1.65)
	_recruits(g, 2.4 * s, g.d + 18.0, int(4 + a * 0.08))
	g.e = maxf(a * 1.8 if a < BIG * 0.7 else a * 1.45, a + 8.0) * 0.93
	g.d += 24.0


## A crystal geode with a prize competes for the hero's fire with a squad on the other side.
static func _c_geode(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var roll := g.rng.randf()
	var reward := "army" if roll < 0.55 else ("coins" if roll < 0.8 else "ult")
	var amount := int(round(a * 0.3)) + 6 if reward == "army" else (12 + g.level * 2 if reward == "coins" else 25)
	_geode(g, 1.9 * s, g.d + 9.0, 7 + g.level / 2, reward, amount)
	_squad(g, -1.5 * s, g.d + 12.0, 2.6, int(round(a * threat(g) * 0.7)) + g.level)
	_tile_line(g, 0.0, 0.0, g.d + 15.0, 5, 1.1)
	g.e += (amount * 0.8 if reward == "army" else 2.0) + 4.0
	g.d += 20.0


## Hero power gates: +rate vs +damage vs soldiers. The best one depends on the hero.
static func _c_power(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var opts: Array[Dictionary] = [_gate("rate", 25), _gate("dmg", 1)]
	if g.level >= int(UNLOCK["multi"]) and g.rng.randf() < 0.4:
		opts[g.rng.randi() % 2] = _gate("multi", 1)
	opts.append(_gate("+", int(round(a * 0.35)) + g.level + 2))
	if s < 0:
		opts.reverse()
	_row(g, g.d + 14.0, opts)
	g.e = a * 1.1 + 3.0
	_squad(g, 1.0 * s, g.d + 22.0, 3.2, int(round(a * threat(g) * 0.9)) + g.level)
	g.d += 26.0


## Blinking gate (x2 <-> a red one) beside a modest still gate: timing and risk.
static func _c_blink(g: Gen) -> void:
	var s := _side(g)
	var a := g.e
	var bg := _gate("x", 2) if a < BIG else _gate("+", int(round(a * 0.8)) + g.level)
	bg["blink"] = {"op": "-", "value": int(round(a * 0.35)) + g.level, "period": 0.9 + g.rng.randf_range(0.0, 0.3)}
	var still := _gate("+", int(round(a * 0.35)) + g.level + 2)
	_row(g, g.d + 15.0, [bg, still] if s > 0 else [still, bg])
	_row_fix_x(g, 1.65, -1.65)
	g.e = maxf(a * 2.0 if a < BIG else a * 1.8, a * 1.35 + 2.0) * 0.93
	g.d += 21.0


## Hidden gates: one great, one bad, one fair; the hero's shots scout them.
static func _c_hidden(g: Gen) -> void:
	var a := g.e
	var opts: Array[Dictionary] = [
		_gate("x", 2) if a < BIG else _gate("+", int(round(a * 0.8)) + g.level),
		_gate("-", int(round(a * 0.35)) + g.level),
		_gate("+", int(round(a * 0.35)) + g.level + 2),
	]
	# Shuffle deterministically.
	for k in range(opts.size() - 1, 0, -1):
		var j := g.rng.randi() % (k + 1)
		var tmp: Dictionary = opts[k]
		opts[k] = opts[j]
		opts[j] = tmp
	for o in opts:
		o["hidden"] = true
	_row(g, g.d + 15.0, opts)
	g.e = maxf(a * 2.0 if a < BIG else a * 1.8, a * 1.35) * 0.92
	g.d += 21.0


## A sweeper bar slides over the middle where a line of tiles and a recruit group lie.
static func _c_sweeper(g: Gen) -> void:
	var a := g.e
	_sweeper(g, 0.0, g.d + 10.0, 2.2, 1.6, 2.0 + g.rng.randf_range(0.0, 0.6), g.rng.randf() * TAU)
	_tile_line(g, 0.0, 0.0, g.d + 4.0, 5, 1.0)
	_recruits(g, 0.0, g.d + 13.0, int(round(5 + a * 0.12)))
	_coin_line(g, -2.6, g.d + 6.0, 4)
	_coin_line(g, 2.6, g.d + 6.0, 4)
	g.e += 5.0 + a * 0.08
	g.d += 18.0


# ------------------------------------------------------------------ finish

static func _finish(g: Gen) -> Dictionary:
	var fd := maxf(g.d + 8.0, target_length(g.level))
	var ratio := clampf(0.3 + 0.045 * (g.level - 1), 0.3, 0.72)
	var hp := int(round(g.e * ratio)) + 6 + g.level * 2
	g.items.append({"kind": "fortress", "x": 0.0, "d": fd, "value": hp})
	# Stairs: a good run reaches about x2.5-x3, a great one the top.
	var surv := maxf(g.e - hp, 6.0)
	var base := maxf(surv / 13.0, 1.0)
	var steps: Array = []
	for k in Balance.STAIRS_MULTS.size():
		steps.append({"mult": Balance.STAIRS_MULTS[k], "cost": maxi(1, int(round(base * (1.0 + 0.25 * k))))})
	g.items.append({"kind": "stairs", "x": 0.0, "d": fd + 6.0, "steps": steps})
	g.items.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	g.hints.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	return {"items": g.items, "length": fd, "expected": g.e, "hints": g.hints, "script": g.script}


# ------------------------------------------------------------------ item helpers

static func _side(g: Gen) -> float:
	return -1.0 if g.rng.randf() < 0.5 else 1.0


static func _hint(g: Gen, d: float, key: String) -> void:
	if g.shown.has(key):
		return
	g.shown[key] = true
	g.hints.append({"d": maxf(d, 0.0), "key": key})


static func _tile_line(g: Gen, x0: float, x1: float, d0: float, n: int, step: float) -> void:
	for k in n:
		var f := 0.0 if n <= 1 else float(k) / (n - 1)
		g.items.append({"kind": "tile", "x": clampf(lerpf(x0, x1, f), -3.0, 3.0), "d": d0 + k * step})


static func _coin_line(g: Gen, x: float, d0: float, n: int) -> void:
	for k in n:
		g.items.append({"kind": "coin", "x": clampf(x, -3.0, 3.0), "d": d0 + k * 1.1})


static func _recruits(g: Gen, x: float, d: float, v: int) -> void:
	g.items.append({"kind": "recruits", "x": x, "d": d, "value": clampi(v, 3, 8) if g.level <= 3 else maxi(v, 3)})


## A gate spec without position; `_row` lays a row out.
static func _gate(op: String, value: int) -> Dictionary:
	return {"kind": "gate", "op": op, "value": value}


static func _gate_at(op: String, value: int, x: float, w: float) -> Dictionary:
	return {"kind": "gate", "op": op, "value": value, "x": x, "w": w}


## Places a row of 2-3 gates at `d` (left to right in list order) unless they carry their x.
static func _row(g: Gen, d: float, gates: Array) -> void:
	g.row += 1
	var n := gates.size()
	for k in n:
		var gt: Dictionary = gates[k]
		if not gt.has("x"):
			if n == 2:
				gt["x"] = -ROW2_X if k == 0 else ROW2_X
			else:
				gt["x"] = [-ROW3_X, 0.0, ROW3_X][mini(k, 2)]
		if not gt.has("w"):
			gt["w"] = ROW2_W if n == 2 else ROW3_W
		gt["d"] = d
		gt["row"] = g.row
		g.items.append(gt)


## Moves the two gates of the last row to x_a (first) and x_b (second).
static func _row_fix_x(g: Gen, x_a: float, x_b: float) -> void:
	var found: Array[Dictionary] = []
	for it in g.items:
		if str(it["kind"]) == "gate" and int(it["row"]) == g.row:
			found.append(it)
	if found.size() != 2:
		return
	# Keep the list order: the first gate listed was put on the left by _row.
	var left := found[0] if float(found[0]["x"]) < float(found[1]["x"]) else found[1]
	var right := found[1] if left == found[0] else found[0]
	left["x"] = minf(x_a, x_b)
	right["x"] = maxf(x_a, x_b)


static func _squad(g: Gen, x: float, d: float, w: float, v: int) -> void:
	g.items.append({"kind": "squad", "x": x, "d": d, "w": w, "value": maxi(v, 2)})


static func _barricade(g: Gen, x: float, d: float, w: float, hp: int) -> void:
	g.items.append({"kind": "barricade", "x": x, "d": d, "w": w, "value": maxi(hp, 3)})


static func _rotor(g: Gen, x: float, d: float, length: float, speed: float, phase: float) -> void:
	g.items.append({"kind": "blade", "type": "rotor", "x": x, "d": d, "len": length, "speed": speed, "phase": phase})


static func _sweeper(g: Gen, x: float, d: float, w: float, amp: float, period: float, phase: float) -> void:
	g.items.append({"kind": "blade", "type": "sweeper", "x": x, "d": d, "w": w, "amp": amp, "period": period, "phase": phase})


static func _turret(g: Gen, side: float, d: float, hp: int, reach: float, rate: float) -> void:
	g.items.append({"kind": "turret", "x": TURRET_X * side, "d": d, "value": hp, "range": reach, "rate": rate})


static func _geode(g: Gen, x: float, d: float, hp: int, reward: String, amount: int) -> void:
	g.items.append({"kind": "geode", "x": x, "d": d, "value": hp, "reward": reward, "amount": amount})


static func _crate(g: Gen, x: float, d: float, hp: int, weapon: String) -> void:
	g.items.append({"kind": "crate", "x": x, "d": d, "value": hp, "weapon": weapon})
