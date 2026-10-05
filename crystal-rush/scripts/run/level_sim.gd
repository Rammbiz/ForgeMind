class_name LevelSim
## Pure, static simulation of one run along a path x(d). The bot and `level_check` use it to
## judge choices, so it mirrors the run rules of the Etap 1 spec (sections 2-4) as closely as an
## expected-value model can. Nothing here touches the scene tree.
##
## Assumptions (the Run must agree with these for the bot and level_check to be trustworthy):
## - The hero runs at Balance.RUN_SPEED and stops only in a clash / the siege. Its x follows the
##   path exactly (the real spring is ~0.05 s). During a clash and the siege x stays put.
## - The army is a uniform disk of radius Balance.blob_radius(army) (an ellipse BLOB_STRETCH
##   longer along the run), centred on the hero x, its centre HERO_GAP + r * BLOB_STRETCH behind
##   the hero. Soldiers pushed past the railing pile up at +-(BRIDGE_HALF - UNIT_R).
## - Tiles / coins are taken when the hero crosses them within r + PICKUP_PAD; recruits within
##   r + RECRUIT_PAD. Gates: when the hero crosses a row, the gate whose span holds the hero x
##   applies (none in a gap); the whole row then closes.
## - Gate x(t) = x + amp * sin(TAU * t / period + phase) with t = seconds since start (clash time
##   included). Blinking gates show the base op/value while floor(t / period) is even and the
##   blink op/value while it is odd; hero hits change the variant shown at that moment.
## - Hero targeting: the nearest live target ahead (by d, then |dx|) whose span is within the
##   hero corridor, inside hero range. Targets: squads, barricades, turrets, geodes, crates, the
##   fortress, and gates whose current op is in Balance.GATE_HIT_GAIN (plus unrevealed hidden
##   gates). Extra shots from power.multi go to the next targets (or the first one again).
##   Damage = HEROES.damage + power.dmg; a squad hit also kills `splash` more. Rate =
##   HEROES.rate * Balance.power_mult(upgrade) * (1 + power.rate).
## - Gate hits: "+" grows, "-" shrinks (floor 0), "rate" grows by 2 per point, "charge" (negative
##   value) grows and turns into its reward at >= 0. A hit reveals a hidden gate.
## - Hazards are resolved band by band: the soldiers whose depth in the blob crosses a hazard's
##   line during a step meet it at the army centre x of that moment (the centre follows the hero
##   x at ARMY_FOLLOW per second, as the real blob trails a swerve), spread evenly across the
##   blob's chord at that depth. Barricade: soldiers whose x lies in the (shrunk) span die, at
##   most its hp; its hp drops by the soldiers killed. Rotor: a soldier dies if a blade arm
##   sweeps over it while it crosses the rotor disk. Sweeper: dies if the bar covers its x when it
##   crosses the rail. The titan's armour makes the army immune to all hazards and turrets.
## - Blaster volleys hit structures for `struct_share` of their squad damage.
## - Turrets kill `rate` soldiers per second while the blob edge is within `range` of them.
## - Squads: when the hero gets within CONTACT and the blob x-extent overlaps the squad span,
##   a clash starts: every FIGHT_TICK both sides lose max(1, ceil(min(army, foes) / 14)); the hero,
##   machines and volleys keep shooting. With no army the hero absorbs the ticks with its hp.
## - Fortress: the same ticks against its hp; with no army the hero has FINALE_TIME seconds.
##   Survivors then climb the stairs, paying each step's cost; coins = (victory_coins + collected)
##   x the multiplier of the last step reached.
## - War machines target the nearest hostile ahead within their range and WEAPON_LATERAL of the
##   hero x. Vs squads one shot kills damage * pierce + splash; vs structures it deals damage.
## - Army volleys (crossbows/blasters) hit the nearest squad ahead within range (blasters also
##   turrets, barricades and the fortress) for volley * army every period.
## - Ult points: soldiers gained (gate gains capped at 15 per gate) + enemies killed, not while the
##   ult runs. Bolt storm: 12 ticks of `kills` per squad / `breaks` per structure within range,
##   gates in range get a hero-damage hit per tick. Titan quake: 4 bands of `spacing` from the cast
##   point, then `armor_time` s of hazard immunity. The script key ult_ready_at fills the ult.

enum K { TILE, COIN, RECRUITS, GATE, BARRICADE, BLADE, TURRET, SQUAD, GEODE, CRATE, FORTRESS, STAIRS }
enum Mode { RUN, CLASH, SIEGE, WON, LOST }

const KINDS := {
	"tile": K.TILE, "coin": K.COIN, "recruits": K.RECRUITS, "gate": K.GATE, "barricade": K.BARRICADE,
	"blade": K.BLADE, "turret": K.TURRET, "squad": K.SQUAD, "geode": K.GEODE, "crate": K.CRATE,
	"fortress": K.FORTRESS, "stairs": K.STAIRS,
}
const DT := 0.05
const DT_COARSE := 0.1
const GATE_GAIN_CAP := 15.0     # ult points from one gate


## Static view of a level (or of a window of a live run) with per-kind index lists.
class Level extends RefCounted:
	var level := 1
	var items: Array[Dictionary] = []
	var kind := PackedInt32Array()
	var d := PackedFloat32Array()
	var x := PackedFloat32Array()
	var hw := PackedFloat32Array()      ## half span used for corridor / overlap tests
	var pick := PackedInt32Array()      ## tiles, coins, recruits, gates (hero crossing)
	var targ := PackedInt32Array()      ## anything the hero / machines may hit
	var haz := PackedInt32Array()       ## barricades and blades (army crossing)
	var tur := PackedInt32Array()
	var block := PackedInt32Array()     ## squads and the fortress
	var rows := {}                      ## row id -> PackedInt32Array of gate indices
	var length := 100.0
	var fortress := -1
	var steps: Array = []
	var ult_ready_at := -1.0


## Mutable run state. `copy()` is cheap (packed arrays + scalars).
class State extends RefCounted:
	var d := 0.0
	var t := 0.0
	var hx := 0.0
	var ax := 0.0                       ## army centre x (follows hx with a lag, like the real blob)
	var d_prev := 0.0                   ## hero distance before the last step (hazard bands)
	var mode := 0
	var hero := "bolt"
	var army := 0.0
	var coins := 0
	var hero_hp := 0.0
	var ult := 0.0
	var ult_left := 0.0
	var ult_tick := 0.0
	var quake_d := 0.0
	var quake_wave := 99
	var armor := 0.0
	var atk_cd := 0.0
	var volley_cd := 0.0
	var tick := 0.0
	var finale := 0.0
	var foe := -1
	var weapons: Array = []             ## [kind: String, level: int, cd: float]
	var arm := 0
	var p_rate := 0.0
	var p_dmg := 0
	var p_multi := 0
	var upgrade := 0                    ## Save.upgrades["power"]
	var script_done := false
	var pk := 0
	var bk := 0
	var armed := PackedInt32Array()     ## squads met clear of the blob, live until passed
	var hz := 0
	var alive := PackedByteArray()
	var hp := PackedFloat32Array()
	var val := PackedFloat32Array()
	var val2 := PackedFloat32Array()
	var op := PackedStringArray()
	var op2 := PackedStringArray()
	var rev := PackedByteArray()
	var hazard_deaths := 0.0
	var clash_deaths := 0.0
	var kills := 0.0
	var peak := 0.0
	var army_at_fortress := -1.0
	var survivors := 0
	var stairs_mult := 1.0
	var total_coins := 0
	var reason := ""
	var trace: PackedStringArray = PackedStringArray()
	var tracing := false
	var auto_ult := true                ## fire the ult by the auto policy (LevelSim.ult_worth)
	var gate_margin := 0.0              ## planning only: a gate counts only this far inside its span
	var sample_every := 0.0             ## > 0: record (d, hx, army) every this many units
	var samples := PackedVector3Array()

	func copy() -> State:
		var s := State.new()
		s.d = d; s.t = t; s.hx = hx; s.ax = ax; s.d_prev = d_prev; s.mode = mode; s.hero = hero; s.army = army; s.coins = coins
		s.hero_hp = hero_hp; s.ult = ult; s.ult_left = ult_left; s.ult_tick = ult_tick
		s.quake_d = quake_d; s.quake_wave = quake_wave; s.armor = armor; s.atk_cd = atk_cd
		s.volley_cd = volley_cd; s.tick = tick; s.finale = finale; s.foe = foe
		s.weapons = []
		for w: Array in weapons:
			s.weapons.append(w.duplicate())
		s.arm = arm; s.p_rate = p_rate; s.p_dmg = p_dmg; s.p_multi = p_multi; s.upgrade = upgrade
		s.script_done = script_done; s.pk = pk; s.bk = bk; s.armed = armed.duplicate(); s.hz = hz
		s.alive = alive.duplicate(); s.hp = hp.duplicate(); s.val = val.duplicate()
		s.val2 = val2.duplicate(); s.op = op.duplicate(); s.op2 = op2.duplicate(); s.rev = rev.duplicate()
		s.hazard_deaths = hazard_deaths; s.clash_deaths = clash_deaths; s.kills = kills; s.peak = peak
		s.army_at_fortress = army_at_fortress; s.survivors = survivors; s.stairs_mult = stairs_mult
		s.total_coins = total_coins; s.reason = reason; s.auto_ult = auto_ult; s.gate_margin = gate_margin
		return s


# ------------------------------------------------------------------ building

## Wraps a LevelGen.build() result.
static func make_level(def: Dictionary, level: int) -> Level:
	var lv := Level.new()
	lv.level = level
	lv.length = float(def.get("length", 100.0))
	var sc: Dictionary = def.get("script", {})
	lv.ult_ready_at = float(sc.get("ult_ready_at", -1.0))
	for it: Dictionary in def["items"]:
		lv.items.append(it)
	_index(lv)
	return lv


static func _index(lv: Level) -> void:
	var n := lv.items.size()
	lv.kind.resize(n)
	lv.d.resize(n)
	lv.x.resize(n)
	lv.hw.resize(n)
	for i in n:
		var it := lv.items[i]
		var k: int = KINDS.get(str(it["kind"]), K.TILE)
		lv.kind[i] = k
		lv.d[i] = float(it["d"])
		lv.x[i] = float(it.get("x", 0.0))
		var hw := 0.3
		match k:
			K.GATE, K.SQUAD, K.BARRICADE:
				hw = float(it.get("w", 2.0)) * 0.5
			K.TURRET:
				hw = 0.45
			K.GEODE:
				hw = 0.6
			K.CRATE:
				hw = 0.55
			K.FORTRESS:
				hw = Balance.BRIDGE_HALF
		lv.hw[i] = hw
		match k:
			K.TILE, K.COIN, K.RECRUITS:
				lv.pick.append(i)
			K.GATE:
				var row := int(it.get("row", i))
				if not lv.rows.has(row):
					lv.pick.append(i)
				# Packed arrays are values inside a Dictionary: append to a copy, store it back.
				var gates: PackedInt32Array = lv.rows.get(row, PackedInt32Array())
				gates.append(i)
				lv.rows[row] = gates
				lv.targ.append(i)
			K.BARRICADE:
				lv.haz.append(i)
				lv.targ.append(i)
			K.BLADE:
				lv.haz.append(i)
			K.TURRET:
				lv.tur.append(i)
				lv.targ.append(i)
			K.SQUAD:
				lv.block.append(i)
				lv.targ.append(i)
			K.GEODE, K.CRATE:
				lv.targ.append(i)
			K.FORTRESS:
				lv.block.append(i)
				lv.targ.append(i)
				lv.fortress = i
			K.STAIRS:
				lv.steps = it.get("steps", [])


## A fresh state at the start line.
static func start_state(lv: Level, hero: String, army: int, opts := {}) -> State:
	var s := State.new()
	s.hero = hero
	s.army = float(army)
	s.peak = s.army
	var def: Dictionary = Balance.HEROES[hero]
	s.hero_hp = float(def["hp"])
	s.upgrade = int(opts.get("power", 0))
	s.tracing = bool(opts.get("trace", false))
	s.auto_ult = bool(opts.get("ult", true))
	s.sample_every = float(opts.get("sample", 0.0))
	var n := lv.items.size()
	s.alive.resize(n)
	s.hp.resize(n)
	s.val.resize(n)
	s.val2.resize(n)
	s.op.resize(n)
	s.op2.resize(n)
	s.rev.resize(n)
	for i in n:
		var it := lv.items[i]
		s.alive[i] = 1
		s.hp[i] = float(it.get("value", 0))
		s.val[i] = float(it.get("value", 0))
		s.op[i] = str(it.get("op", ""))
		s.rev[i] = 0 if it.get("hidden", false) else 1
		if it.has("blink"):
			var b: Dictionary = it["blink"]
			s.op2[i] = str(b.get("op", "+"))
			s.val2[i] = float(b.get("value", 0))
	return s


# ------------------------------------------------------------------ paths

## Hero x at distance `d` on a waypoint path [d0, x0, d1, x1, ...] (held past both ends).
static func path_x(path: PackedFloat32Array, d: float) -> float:
	var n := path.size() / 2
	if n == 0:
		return 0.0
	if d <= path[0]:
		return path[1]
	for k in range(1, n):
		var d1 := path[k * 2]
		if d <= d1:
			var d0 := path[k * 2 - 2]
			var f := 0.0 if d1 - d0 < 0.0001 else (d - d0) / (d1 - d0)
			return lerpf(path[k * 2 - 1], path[k * 2 + 1], f)
	return path[n * 2 - 1]


## Simulates a whole level along `path` and returns the result dictionary.
static func run_path(lv: Level, hero: String, army: int, path: PackedFloat32Array, opts := {}) -> Dictionary:
	return result(lv, simulate(lv, hero, army, path, opts))


## Like run_path but returns the final State (samples, trace, item states).
static func simulate(lv: Level, hero: String, army: int, path: PackedFloat32Array, opts := {}) -> State:
	var s := start_state(lv, hero, army, opts)
	s.hx = path_x(path, 0.0)
	s.ax = s.hx
	advance(lv, s, path, lv.length + 50.0, DT, 600.0)
	return s


## Steps `s` forward until the hero passes `d_end`, the run ends or `max_t` seconds pass.
static func advance(lv: Level, s: State, path: PackedFloat32Array, d_end: float, dt := DT, max_t := 600.0) -> void:
	var t_end := s.t + max_t
	while s.mode != Mode.WON and s.mode != Mode.LOST and s.d < d_end and s.t < t_end:
		step(lv, s, path, dt)


static func result(lv: Level, s: State) -> Dictionary:
	var ws: Array = []
	for w: Array in s.weapons:
		ws.append({"kind": w[0], "level": w[1]})
	return {
		"won": s.mode == Mode.WON, "reason": s.reason, "army_at_fortress": int(round(maxf(s.army_at_fortress, 0.0))),
		"survivors": s.survivors, "stairs_mult": s.stairs_mult, "coins": s.total_coins if s.mode == Mode.WON else s.coins,
		"coins_run": s.coins, "weapons": ws, "arm_tier": s.arm, "hazard_deaths": int(round(s.hazard_deaths)),
		"clash_deaths": int(round(s.clash_deaths)), "kills": int(round(s.kills)), "peak": int(round(s.peak)),
		"time": snappedf(s.t, 0.1), "length": lv.length, "d": snappedf(s.d, 0.1),
		"power": {"rate": s.p_rate, "dmg": s.p_dmg, "multi": s.p_multi},
	}


# ------------------------------------------------------------------ one step

static func step(lv: Level, s: State, path: PackedFloat32Array, dt: float) -> void:
	s.t += dt
	var def: Dictionary = Balance.HEROES[s.hero]
	if s.auto_ult and s.ult >= float((def["ult"] as Dictionary)["charge"]) - 0.001 and ult_ready(s) and ult_worth(lv, s):
		use_ult(lv, s)
	s.d_prev = s.d
	if s.mode == Mode.RUN:
		var nd := s.d + Balance.RUN_SPEED * dt
		var hx_n := path_x(path, nd)
		nd = _blocks(lv, s, nd, hx_n)
		s.hx = path_x(path, nd)
		_picks(lv, s, nd)
		s.d = nd
	s.ax += (s.hx - s.ax) * (1.0 - exp(-ARMY_FOLLOW * dt))
	if lv.ult_ready_at >= 0.0 and not s.script_done and s.d >= lv.ult_ready_at:
		s.script_done = true
		s.ult = float((def["ult"] as Dictionary)["charge"])
	_hero_attack(lv, s, def, dt)
	_machines(lv, s, dt)
	_volleys(lv, s, dt)
	_ult_step(lv, s, def, dt)
	_hazards(lv, s)
	_turrets(lv, s, dt)
	match s.mode:
		Mode.CLASH:
			_clash(lv, s, dt)
		Mode.SIEGE:
			_siege(lv, s, dt)
	s.armor = maxf(s.armor - dt, 0.0)
	s.peak = maxf(s.peak, s.army)
	if s.sample_every > 0.0 and (s.samples.is_empty() or s.d >= s.samples[s.samples.size() - 1].x + s.sample_every):
		s.samples.append(Vector3(s.d, s.hx, s.army))


## Squads and the fortress met before `nd`: returns the distance the hero may reach. A squad met
## clear of the blob stays armed until the hero passes its last rank (Run._blocks).
static func _blocks(lv: Level, s: State, nd: float, hx: float) -> float:
	for k in range(s.armed.size() - 1, -1, -1):
		var j := s.armed[k]
		if s.alive[j] == 0 or s.d > lv.d[j] + squad_depth(lv, j):
			s.armed.remove_at(k)
		elif absf(hx - lv.x[j]) < Balance.blob_radius(s.army) + lv.hw[j]:
			s.armed.remove_at(k)
			s.mode = Mode.CLASH
			s.foe = j
			s.tick = 0.0
			_log(s, "clash %d vs %d" % [int(s.army), int(s.hp[j])])
			return s.d
	while s.bk < lv.block.size():
		var i := lv.block[s.bk]
		var meet := lv.d[i] - Balance.CONTACT
		if meet > nd:
			break
		s.bk += 1
		if s.alive[i] == 0:
			continue
		if lv.kind[i] == K.FORTRESS:
			s.mode = Mode.SIEGE
			s.foe = i
			s.tick = 0.0
			s.finale = Balance.FINALE_TIME
			s.army_at_fortress = s.army
			_log(s, "siege army %d hp %d" % [int(s.army), int(s.hp[i])])
			return maxf(s.d, meet)
		var r := Balance.blob_radius(s.army)
		if absf(hx - lv.x[i]) < r + lv.hw[i]:
			s.mode = Mode.CLASH
			s.foe = i
			s.tick = 0.0
			_log(s, "clash %d vs %d" % [int(s.army), int(s.hp[i])])
			return maxf(s.d, meet)
		s.armed.append(i)
	return nd


static func squad_depth(lv: Level, i: int) -> float:
	var it := lv.items[i]
	return Balance.squad_depth(float(it.get("w", 2.4)), float(it.get("value", 0)))


## Tiles, coins, recruits and gate rows crossed by the hero up to `nd`.
static func _picks(lv: Level, s: State, nd: float) -> void:
	while s.pk < lv.pick.size():
		var i := lv.pick[s.pk]
		if lv.d[i] > nd:
			break
		s.pk += 1
		var k := lv.kind[i]
		if k == K.GATE:
			_gate_row(lv, s, i)
			continue
		if s.alive[i] == 0:
			continue
		var r := Balance.blob_radius(s.army)
		var pad := Balance.RECRUIT_PAD if k == K.RECRUITS else Balance.PICKUP_PAD
		if absf(lv.x[i] - s.hx) > r + pad:
			continue
		s.alive[i] = 0
		match k:
			K.TILE:
				_gain(s, 1.0, 1.0)
			K.COIN:
				s.coins += 1
			K.RECRUITS:
				_gain(s, s.val[i], s.val[i])


static func _gate_row(lv: Level, s: State, first: int) -> void:
	var row := int(lv.items[first].get("row", first))
	var gates: PackedInt32Array = lv.rows.get(row, PackedInt32Array([first]))
	var chosen := -1
	for g in gates:
		if s.alive[g] == 0:
			continue
		if absf(s.hx - gate_x(lv, g, s.t)) <= lv.hw[g] - s.gate_margin:
			# Planning: a moving gate must hold the hero a moment before and after too.
			if s.gate_margin > 0.0 and lv.items[g].has("move"):
				var ok := true
				for dt in [-PLAN_TIME_MARGIN, PLAN_TIME_MARGIN]:
					if absf(s.hx - gate_x(lv, g, s.t + dt)) > lv.hw[g] - s.gate_margin:
						ok = false
				if not ok:
					continue
			chosen = g
	for g in gates:
		s.alive[g] = 0
	if chosen < 0:
		_log(s, "row %d: gap" % row)
		return
	var v := gate_view(lv, s, chosen)
	if s.gate_margin > 0.0 and lv.items[chosen].has("blink"):
		# Planning: near a blink switch assume the worse face.
		var p0 := blink_phase(lv, chosen, s.t - PLAN_TIME_MARGIN)
		var p1 := blink_phase(lv, chosen, s.t + PLAN_TIME_MARGIN)
		if p0 != p1:
			var a := [s.op[chosen], s.val[chosen]]
			var b := [s.op2[chosen], s.val2[chosen]]
			v = a if _forecast(s, str(a[0]), float(a[1])) <= _forecast(s, str(b[0]), float(b[1])) else b
	var before := s.army
	_apply(lv, s, chosen, str(v[0]), float(v[1]))
	_log(s, "row %d: %s%s  %d -> %d" % [row, v[0], str(int(v[1])), int(before), int(s.army)])


## Army after a plain army gate (power / arm / weapon gates count as no change).
static func _forecast(s: State, op: String, v: float) -> float:
	match op:
		"+":
			return s.army + v
		"-":
			return maxf(s.army - v, 0.0)
		"x":
			return s.army * v
		"/":
			return floorf(s.army / maxf(v, 1.0))
		"charge":
			return maxf(s.army + v, 0.0) if v < 0.0 else s.army
	return s.army


## The [op, value] a gate shows at the state's time.
static func gate_view(lv: Level, s: State, g: int) -> Array:
	if blink_phase(lv, g, s.t) == 1:
		return [s.op2[g], s.val2[g]]
	return [s.op[g], s.val[g]]


static func blink_phase(lv: Level, g: int, t: float) -> int:
	var it := lv.items[g]
	if not it.has("blink"):
		return 0
	var period := maxf(float((it["blink"] as Dictionary).get("period", 1.0)), 0.05)
	return int(floor(t / period)) % 2


## Live x of a gate (moving gates slide on a rail).
static func gate_x(lv: Level, g: int, t: float) -> float:
	var it := lv.items[g]
	if not it.has("move"):
		return lv.x[g]
	var m: Dictionary = it["move"]
	return lv.x[g] + float(m.get("amp", 0.0)) * sin(TAU * t / maxf(float(m.get("period", 2.0)), 0.1) + float(m.get("phase", 0.0)))


static func _apply(lv: Level, s: State, g: int, op: String, v: float) -> void:
	match op:
		"+":
			_gain(s, v, minf(v, GATE_GAIN_CAP))
		"-":
			s.army = maxf(s.army - v, 0.0)
		"x":
			var add := s.army * (v - 1.0)
			_gain(s, add, minf(add, GATE_GAIN_CAP))
		"/":
			s.army = floorf(s.army / maxf(v, 1.0))
		"arm":
			s.arm = maxi(s.arm, clampi(int(v), 0, Balance.ARM_TIERS.size() - 1))
		"rate":
			s.p_rate += v / 100.0
		"dmg":
			s.p_dmg += int(v)
		"multi":
			s.p_multi += int(v)
		"charge":
			if v < 0.0:
				s.army = maxf(s.army + v, 0.0)
			else:
				var rw: Dictionary = lv.items[g].get("reward", {})
				_apply(lv, s, g, str(rw.get("op", "+")), float(rw.get("value", 0)))
		"weapon":
			var rw2: Dictionary = lv.items[g].get("reward", {})
			add_weapon(s, str(rw2.get("weapon", lv.items[g].get("weapon", "ballista"))))
		"ult":
			s.ult = float((Balance.HEROES[s.hero]["ult"] as Dictionary)["charge"])


static func _gain(s: State, n: float, points: float) -> void:
	s.army += n
	_charge(s, points)


static func _charge(s: State, points: float) -> void:
	if s.ult_left > 0.0 or s.quake_wave < 99:
		return
	var cap := float((Balance.HEROES[s.hero]["ult"] as Dictionary)["charge"])
	s.ult = minf(s.ult + maxf(points, 0.0), cap)


## Adds a war machine: a duplicate levels its kind up; a new kind with every slot taken levels
## up the lowest machine instead.
static func add_weapon(s: State, kind: String) -> void:
	for w: Array in s.weapons:
		if str(w[0]) == kind:
			w[1] = mini(int(w[1]) + 1, Balance.WEAPON_LEVEL_MULT.size())
			return
	if s.weapons.size() < Balance.MAX_WEAPONS:
		s.weapons.append([kind, 1, 0.0])
		return
	var low: Array = s.weapons[0]
	for w2: Array in s.weapons:
		if int(w2[1]) < int(low[1]):
			low = w2
	low[1] = mini(int(low[1]) + 1, Balance.WEAPON_LEVEL_MULT.size())


# ------------------------------------------------------------------ shooting

static func hero_rate(s: State) -> float:
	var def: Dictionary = Balance.HEROES[s.hero]
	return float(def["rate"]) * Balance.power_mult(s.upgrade) * (1.0 + s.p_rate)


static func hero_damage(s: State) -> int:
	return int(Balance.HEROES[s.hero]["damage"]) + s.p_dmg


static func _hero_attack(lv: Level, s: State, def: Dictionary, dt: float) -> void:
	s.atk_cd -= dt
	if s.atk_cd > 0.0:
		return
	var corridor := float(def.get("corridor", Balance.CORRIDOR))
	var shots := 1 + s.p_multi
	var targets := _targets(lv, s, s.hx, corridor, float(def["range"]), shots, true)
	if targets.is_empty():
		s.atk_cd = 0.0
		return
	s.atk_cd += 1.0 / hero_rate(s)
	s.atk_cd = maxf(s.atk_cd, 0.02)
	var dmg := hero_damage(s)
	for k in shots:
		var i: int = targets[mini(k, targets.size() - 1)]
		if s.alive[i] == 0:
			continue
		if lv.kind[i] == K.GATE:
			_hit_gate(lv, s, i, float(dmg))
		elif lv.kind[i] == K.SQUAD:
			_hurt(lv, s, i, float(dmg + int(def["splash"])))
		else:
			_hurt(lv, s, i, float(dmg))


## Up to `count` live targets ahead, nearest first, whose span is within `lateral` of x.
static func _targets(lv: Level, s: State, x: float, lateral: float, reach: float, count: int, gates: bool) -> Array[int]:
	var out: Array[int] = []
	var near := s.d - 0.5
	var far := s.d + reach
	# The target list is sorted by d; start from the first one that may still be ahead.
	var lo := _first_at(lv.d, lv.targ, near)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		var di := lv.d[i]
		if di > far:
			break
		if s.alive[i] == 0:
			continue
		var k := lv.kind[i]
		if k == K.GATE:
			if not gates or di < s.d:
				continue
			var v := gate_view(lv, s, i)
			if s.rev[i] == 1 and not Balance.GATE_HIT_GAIN.has(str(v[0])):
				continue
			if absf(gate_x(lv, i, s.t) - x) > lateral + lv.hw[i]:
				continue
		elif absf(lv.x[i] - x) > lateral + lv.hw[i]:
			continue
		out.append(i)
		if out.size() >= count:
			break
	return out


## First index j in `idx` (sorted by d) with d[idx[j]] >= v (binary search).
static func _first_at(d: PackedFloat32Array, idx: PackedInt32Array, v: float) -> int:
	var lo := 0
	var hi := idx.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if d[idx[mid]] < v:
			lo = mid + 1
		else:
			hi = mid
	return lo


static func _hit_gate(lv: Level, s: State, g: int, dmg: float) -> void:
	s.rev[g] = 1
	var ph := blink_phase(lv, g, s.t)
	var op := s.op2[g] if ph == 1 else s.op[g]
	if not Balance.GATE_HIT_GAIN.has(op):
		return
	var v := s.val2[g] if ph == 1 else s.val[g]
	var gain := float(Balance.GATE_HIT_GAIN[op]) * dmg
	match op:
		"-":
			v = maxf(v - gain, 0.0)
		"charge":
			v += gain
			if v >= 0.0:
				var rw: Dictionary = lv.items[g].get("reward", {})
				op = str(rw.get("op", "+"))
				v = float(rw.get("value", 0))
				if op == "weapon" or op == "ult":
					v = 1.0
				_log(s, "charge flipped -> %s" % op)
		_:
			v += gain
	if ph == 1:
		s.op2[g] = op
		s.val2[g] = v
	else:
		s.op[g] = op
		s.val[g] = v


## Damages a hostile; for squads `n` is enemies killed. Breaking things pays out.
static func _hurt(lv: Level, s: State, i: int, n: float) -> void:
	if s.alive[i] == 0 or n <= 0.0:
		return
	var dealt := minf(n, s.hp[i])
	s.hp[i] -= dealt
	var k := lv.kind[i]
	if k == K.SQUAD:
		s.kills += dealt
		_charge(s, dealt)
	if s.hp[i] > 0.001:
		return
	s.hp[i] = 0.0
	s.alive[i] = 0
	var it := lv.items[i]
	match k:
		K.CRATE:
			add_weapon(s, str(it.get("weapon", "ballista")))
			_log(s, "crate -> %s" % str(it.get("weapon", "")))
		K.GEODE:
			var amount := float(it.get("amount", 0))
			match str(it.get("reward", "army")):
				"army":
					_gain(s, amount, amount)
				"coins":
					s.coins += int(amount)
				"ult":
					_charge(s, amount)
			_log(s, "geode %s +%d" % [str(it.get("reward", "")), int(amount)])
		K.FORTRESS:
			_win(lv, s)


static func weapon_dps(kind: String, level: int, crowd: bool) -> float:
	var w: Dictionary = Balance.WEAPONS[kind]
	var mult: float = Balance.WEAPON_LEVEL_MULT[clampi(level - 1, 0, Balance.WEAPON_LEVEL_MULT.size() - 1)]
	match kind:
		"laser":
			return float(w["dps_crowd" if crowd else "dps"]) * mult
		"rockets":
			return float(w["damage"]) * float(w["volley"]) / float(w["period"]) * mult
	var per := float(w["damage"])
	if crowd:
		per = per * float(w.get("pierce", 1)) + float(w.get("splash", 0))
	return per * float(w["rate"]) * mult


static func _machines(lv: Level, s: State, dt: float) -> void:
	for w: Array in s.weapons:
		var kind := str(w[0])
		var spec: Dictionary = Balance.WEAPONS[kind]
		w[2] = float(w[2]) - dt
		if kind != "laser" and float(w[2]) > 0.0:
			continue
		var tg := _targets(lv, s, s.hx, Balance.WEAPON_LATERAL, float(spec["range"]), 1, false)
		if tg.is_empty():
			w[2] = maxf(float(w[2]), 0.0)
			continue
		var i: int = tg[0]
		var crowd := lv.kind[i] == K.SQUAD
		if kind == "laser":
			_hurt(lv, s, i, weapon_dps(kind, int(w[1]), crowd) * dt)
			continue
		var period := float(spec["period"]) if kind == "rockets" else 1.0 / float(spec["rate"])
		w[2] = float(w[2]) + period
		_hurt(lv, s, i, weapon_dps(kind, int(w[1]), crowd) * period)


static func _volleys(lv: Level, s: State, dt: float) -> void:
	if s.arm <= 0 or s.army < 1.0:
		return
	s.volley_cd -= dt
	if s.volley_cd > 0.0:
		return
	var tier: Dictionary = Balance.ARM_TIERS[s.arm]
	var r := Balance.blob_radius(s.army)
	var reach := float(tier["range"])
	var structures := bool(tier.get("structures", false))
	var lo := _first_at(lv.d, lv.targ, s.d - 1.0)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		if lv.d[i] > s.d + reach:
			break
		if s.alive[i] == 0:
			continue
		var k := lv.kind[i]
		var ok := k == K.SQUAD or (structures and (k == K.TURRET or k == K.BARRICADE or k == K.FORTRESS))
		if not ok or absf(lv.x[i] - s.hx) > r + lv.hw[i] + 1.0:
			continue
		s.volley_cd = float(tier["period"])
		var dmg := maxf(1.0, s.army * float(tier["volley"]))
		if k != K.SQUAD:
			dmg = maxf(1.0, dmg * float(tier.get("struct_share", 1.0)))
		_hurt(lv, s, i, dmg)
		return
	s.volley_cd = 0.0


# ------------------------------------------------------------------ ult

## True when the ult is charged and not running.
static func ult_ready(s: State) -> bool:
	var cap := float((Balance.HEROES[s.hero]["ult"] as Dictionary)["charge"])
	return s.ult >= cap - 0.001 and s.ult_left <= 0.0 and s.quake_wave >= 99


## The auto policy: is there enough to hit right now? The titan also fires it for the armour
## when a hazard is about to cut into a decent army.
static func ult_worth(lv: Level, s: State) -> bool:
	if s.mode == Mode.CLASH or s.mode == Mode.SIEGE:
		return true
	var reach := 16.0 if s.hero == "bolt" else 13.0
	if s.hero == "titan" and s.army >= 25.0:
		var c := army_center_d(s)
		var lo_h := _first_at(lv.d, lv.haz, c)
		if lo_h < lv.haz.size() and lv.d[lv.haz[lo_h]] < s.d + 6.0 and s.alive[lv.haz[lo_h]] == 1:
			return true
	var total := 0.0
	var lo := _first_at(lv.d, lv.targ, s.d)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		if lv.d[i] > s.d + reach:
			break
		if s.alive[i] == 0:
			continue
		if lv.kind[i] == K.SQUAD and absf(lv.x[i] - s.hx) <= Balance.blob_radius(s.army) + lv.hw[i] + 0.5:
			total += s.hp[i]
		elif lv.kind[i] == K.FORTRESS:
			total += 99.0
	return total >= maxf(8.0, s.army * 0.35)


static func use_ult(lv: Level, s: State) -> bool:
	if not ult_ready(s):
		return false
	var u: Dictionary = Balance.HEROES[s.hero]["ult"]
	s.ult = 0.0
	if s.hero == "bolt":
		s.ult_left = float(u["duration"])
		s.ult_tick = 0.0
	else:
		s.quake_d = s.d
		s.quake_wave = 0
		s.ult_tick = 0.43
		s.armor = float(u["armor_time"])
	_log(s, "ult at %d" % int(s.d))
	return true


static func _ult_step(lv: Level, s: State, def: Dictionary, dt: float) -> void:
	var u: Dictionary = def["ult"]
	if s.ult_left > 0.0:
		s.ult_left -= dt
		s.ult_tick -= dt
		while s.ult_tick <= 0.0 and s.ult_left > -dt:
			s.ult_tick += float(u["tick"])
			_ult_hit(lv, s, s.d - 0.5, s.d + float(u["range"]), float(u["kills"]), float(u["breaks"]), true)
		if s.ult_left <= 0.0:
			s.ult_left = 0.0
	elif s.quake_wave < 99:
		s.ult_tick -= dt
		var waves := int(u["waves"])
		var spacing := float(u["spacing"])
		while s.ult_tick <= 0.0 and s.quake_wave < waves:
			s.ult_tick += float(u["gap"])
			var near := s.quake_d + 1.0 + spacing * s.quake_wave
			_ult_hit(lv, s, near - 0.5, near + spacing, float(u["kills"]), float(u["breaks"]), false)
			s.quake_wave += 1
		if s.quake_wave >= waves:
			s.quake_wave = 99


static func _ult_hit(lv: Level, s: State, a: float, b: float, kills: float, breaks: float, gates: bool) -> void:
	var lo := _first_at(lv.d, lv.targ, a)
	for j in range(lo, lv.targ.size()):
		var i := lv.targ[j]
		if lv.d[i] > b:
			break
		if s.alive[i] == 0:
			continue
		match lv.kind[i]:
			K.SQUAD:
				_hurt(lv, s, i, kills)
			K.GATE:
				if gates and lv.d[i] >= s.d:
					_hit_gate(lv, s, i, float(hero_damage(s)))
			_:
				_hurt(lv, s, i, breaks)


# ------------------------------------------------------------------ hazards

## Mass of a uniform unit disk left of u.
static func _disk_cdf(u: float) -> float:
	if u <= -1.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return (asin(u) + u * sqrt(1.0 - u * u)) / PI + 0.5


static func army_center_d(s: State) -> float:
	return s.d - Balance.HERO_GAP - Balance.blob_radius(s.army) * Balance.BLOB_STRETCH


## Hazards act band by band as the army crosses them: the soldiers whose depth in the blob
## crossed a hazard's line during the last step meet it at the army x of this moment (the blob
## trails the hero by ARMY_FOLLOW), so swerving while the rear still crosses costs soldiers,
## as it does in the run.
static func _hazards(lv: Level, s: State) -> void:
	var d0 := s.d_prev
	var d1 := s.d
	if d1 <= d0 + 0.00001:
		return
	var r := Balance.blob_radius(s.army)
	var rz := r * Balance.BLOB_STRETCH
	var gap := Balance.HERO_GAP
	# Hazards the whole army has crossed are done.
	while s.hz < lv.haz.size() and lv.d[lv.haz[s.hz]] + gap + 2.0 * rz < d0 - 0.0001:
		s.hz += 1
	var k := s.hz
	while k < lv.haz.size():
		var i := lv.haz[k]
		k += 1
		var hd := lv.d[i]
		if hd + gap > d1:
			break
		if s.alive[i] == 0 or s.army < 0.5 or s.armor > 0.0:
			continue
		# Depths v (-1 front .. 1 rear) of the soldiers that crossed this step.
		var v0 := maxf((d0 - hd - gap) / maxf(rz, 0.001) - 1.0, -1.0)
		var v1 := minf((d1 - hd - gap) / maxf(rz, 0.001) - 1.0, 1.0)
		if v1 <= v0:
			continue
		var mass := _disk_cdf(v1) - _disk_cdf(v0)
		if mass <= 0.0:
			continue
		var vm := (v0 + v1) * 0.5
		var half_w := r * sqrt(maxf(1.0 - vm * vm, 0.0))
		var lost := 0.0
		if lv.kind[i] == K.BARRICADE:
			var half := lv.hw[i] * Balance.HAZARD_SHRINK + Balance.UNIT_R
			lost = minf(mass * _chord_share(s.ax, half_w, lv.x[i] - half, lv.x[i] + half) * s.army, s.hp[i])
			s.hp[i] -= lost
			if s.hp[i] <= 0.001:
				s.alive[i] = 0
		else:
			lost = mass * _blade_band(lv, s, i, half_w) * s.army
		if lost > 0.0:
			s.army = maxf(s.army - lost, 0.0)
			s.hazard_deaths += lost
			_log(s, "%s -%d" % [str(lv.items[i]["kind"]), int(round(lost))])


const SLICES := 12
const ARMY_FOLLOW := 10.0       # 1/s: how fast the blob centre follows the hero x


## Share of a band of soldiers spread evenly over [cx - half, cx + half] that lies in [a, b];
## soldiers pushed past the railing stand at the railing.
static func _chord_share(cx: float, half: float, a: float, b: float) -> float:
	var wall := Balance.BRIDGE_HALF - Balance.UNIT_R
	var lo := clampf(cx - half, -wall, wall)
	var hi := clampf(cx + half, -wall, wall)
	if hi - lo < 0.001:
		return 1.0 if lo >= a and lo <= b else 0.0
	var share := maxf(minf(b, hi) - maxf(a, lo), 0.0) / (hi - lo)
	# Soldiers squeezed against a railing.
	var pile_lo := maxf(-wall - (cx - half), 0.0) / maxf(2.0 * half, 0.001)
	var pile_hi := maxf((cx + half) - wall, 0.0) / maxf(2.0 * half, 0.001)
	share *= 1.0 - pile_lo - pile_hi
	if pile_lo > 0.0 and -wall >= a and -wall <= b:
		share += pile_lo
	if pile_hi > 0.0 and wall >= a and wall <= b:
		share += pile_hi
	return clampf(share, 0.0, 1.0)


## Share of a band of soldiers (spread over the chord of half width `half_w` around the army
## x) that a rotor or a sweeper hits as they cross it now.
static func _blade_band(lv: Level, s: State, i: int, half_w: float) -> float:
	var it := lv.items[i]
	var wall := Balance.BRIDGE_HALF - Balance.UNIT_R
	var rotor := str(it.get("type", "rotor")) == "rotor"
	var bx := lv.x[i]
	var dead := 0.0
	for k in SLICES:
		var ux := clampf(s.ax + half_w * (-1.0 + (2.0 * k + 1.0) / SLICES), -wall, wall)
		var hit := _rotor_hits(it, ux - bx, s.t) if rotor else _sweeper_hits(it, ux, s.t)
		if hit:
			dead += 1.0 / SLICES
	return dead


static func _rotor_hits(it: Dictionary, o: float, tc: float) -> bool:
	var length := float(it.get("len", 1.6)) * Balance.HAZARD_SHRINK + Balance.UNIT_R
	if absf(o) >= length:
		return false
	var w := float(it.get("speed", 2.5))
	var th0 := float(it.get("phase", 0.0))
	var half := sqrt(length * length - o * o)
	var t_in := tc - half / Balance.RUN_SPEED
	var t_out := tc + half / Balance.RUN_SPEED
	var n := 8
	var prev := 0.0
	for k in n + 1:
		var tt := lerpf(t_in, t_out, float(k) / n)
		# The soldier at (o, z) relative to the pivot, z from +half (near side) to -half.
		var z := half - 2.0 * half * float(k) / n
		var phi := atan2(z, o)
		var cur := sin(th0 + w * tt - phi)
		# Close to the bar (within a soldier's width at that radius) counts as a hit.
		var rho := maxf(sqrt(o * o + z * z), 0.2)
		if absf(cur) * rho < Balance.UNIT_R + 0.08:
			return true
		if k > 0 and signf(cur) != signf(prev):
			return true
		prev = cur
	return false


static func _sweeper_hits(it: Dictionary, ux: float, tc: float) -> bool:
	var amp := float(it.get("amp", 1.5))
	var period := maxf(float(it.get("period", 2.0)), 0.1)
	var xs := float(it.get("x", 0.0)) + amp * sin(TAU * tc / period + float(it.get("phase", 0.0)))
	var half := float(it.get("w", 2.0)) * 0.5 * Balance.HAZARD_SHRINK + Balance.UNIT_R
	return absf(ux - xs) <= half


static func _turrets(lv: Level, s: State, dt: float) -> void:
	if lv.tur.is_empty() or s.army < 0.5 or s.armor > 0.0:
		return
	var c := army_center_d(s)
	var r := Balance.blob_radius(s.army)
	for i in lv.tur:
		if s.alive[i] == 0:
			continue
		var it := lv.items[i]
		var reach := float(it.get("range", 7.0))
		var dz := lv.d[i] - c
		if absf(dz) > reach + r:
			continue
		if Vector2(lv.x[i] - s.hx, dz).length() - r > reach:
			continue
		var lost := minf(float(it.get("rate", 2.0)) * dt, s.army)
		s.army -= lost
		s.hazard_deaths += lost


# ------------------------------------------------------------------ fights

static func _burst(n: float) -> float:
	return maxf(1.0, ceilf(n / 14.0))


static func _clash(lv: Level, s: State, dt: float) -> void:
	var f := s.foe
	if f < 0 or s.alive[f] == 0:
		s.mode = Mode.RUN
		s.foe = -1
		return
	s.tick -= dt
	while s.tick <= 0.0 and s.mode == Mode.CLASH:
		s.tick += Balance.FIGHT_TICK
		if s.army >= 0.5:
			var hit := minf(_burst(minf(s.army, s.hp[f])), minf(s.army, s.hp[f]))
			s.army -= hit
			s.clash_deaths += hit
			_hurt(lv, s, f, hit)
		else:
			s.army = 0.0
			var hit2 := minf(_burst(minf(s.hero_hp, s.hp[f])), s.hp[f])
			s.hero_hp -= hit2
			_hurt(lv, s, f, hit2)
			if s.hero_hp <= 0.0 and s.alive[f] == 1:
				_lose(s, "ARMY_LOST")
				return
		if s.alive[f] == 0:
			s.mode = Mode.RUN
			s.foe = -1


static func _siege(lv: Level, s: State, dt: float) -> void:
	var f := s.foe
	if f < 0 or s.alive[f] == 0:
		_win(lv, s)
		return
	s.tick -= dt
	while s.tick <= 0.0 and s.mode == Mode.SIEGE and s.army >= 0.5:
		s.tick += Balance.FIGHT_TICK
		var hit := minf(_burst(minf(s.army, s.hp[f])), minf(s.army, s.hp[f]))
		s.army -= hit
		s.clash_deaths += hit
		_hurt(lv, s, f, hit)
	if s.mode != Mode.SIEGE:
		return
	if s.army < 0.5:
		s.army = 0.0
		s.finale -= dt
		if s.finale <= 0.0:
			_lose(s, "NOT_ENOUGH")


static func _win(lv: Level, s: State) -> void:
	if s.mode == Mode.WON or s.mode == Mode.LOST:
		return
	s.mode = Mode.WON
	s.reason = "FORTRESS_FALLS"
	if s.army_at_fortress < 0.0:
		s.army_at_fortress = s.army
	var left := int(floor(s.army + 0.001))
	s.survivors = left
	var mult := 1.0
	for st: Dictionary in lv.steps:
		var cost := int(st.get("cost", 1))
		if left < cost:
			break
		left -= cost
		mult = float(st.get("mult", 1.0))
	s.stairs_mult = mult
	s.total_coins = int(round(float(Balance.victory_coins(lv.level, s.survivors) + s.coins) * mult))
	_log(s, "won: survivors %d x%s" % [s.survivors, str(mult)])


static func _lose(s: State, reason: String) -> void:
	s.mode = Mode.LOST
	s.reason = reason
	_log(s, "lost: " + reason)


static func _log(s: State, msg: String) -> void:
	if s.tracing:
		s.trace.append("%6.1f %s" % [s.d, msg])


# ------------------------------------------------------------------ planning (bot / level_check)

const LAT_SLOPE := 4.0          # sideways units per unit run when a planned path changes x
const PLAN_STEP := 2.0          # level_check: distance between re-plans
const PLAN_GATE_MARGIN := 0.25
const PLAN_TIME_MARGIN := 0.12  # planning: moving / blinking gates must hold this long
const PAIRS := [-2.7, -1.0, 1.0, 2.7]   # coarse x for two-stage (weaving) lines
const PAIR_SPLITS := [0.3, 0.55]        # where (share of the horizon) two-stage lines switch


## How good a state is, in soldiers: the army plus what weapons, powers, coins and the ult
## are worth over the rest of the level.
static func value(lv: Level, s: State) -> float:
	if s.mode == Mode.LOST:
		return -10000.0 + s.d
	if s.mode == Mode.WON:
		return 1000.0 + s.survivors * 2.0 + s.total_coins * 0.2
	var left := maxf(lv.length - s.d, 0.0) / Balance.RUN_SPEED
	var v := s.army
	for w: Array in s.weapons:
		v += weapon_dps(str(w[0]), int(w[1]), true) * left * 0.22
	if s.arm > 0:
		var tier: Dictionary = Balance.ARM_TIERS[s.arm]
		v += s.army * float(tier["volley"]) / float(tier["period"]) * left * 0.1
	var def: Dictionary = Balance.HEROES[s.hero]
	var hero_dps := hero_rate(s) * float(hero_damage(s) + int(def["splash"])) * (1 + s.p_multi)
	# The hero's fire also pumps gates and opens crates, so it is worth more than its kills.
	v += hero_dps * left * 0.3
	v += s.coins * 0.15 + s.ult * 0.25
	if s.army < 0.5:
		v -= 30.0
	return v


## Path that moves from (d, x0) to x1 at LAT_SLOPE and holds it.
static func hold_path(d: float, x0: float, x1: float) -> PackedFloat32Array:
	return PackedFloat32Array([d, x0, d + maxf(absf(x1 - x0) / LAT_SLOPE, 0.15), x1])


## Scores each candidate line from state `s` over `horizon` units: holding one x, and (with
## `pairs`) going to x1 for the first half, then x2 (weaving between hazards). Returns
## {"x": first x of the best line, "score": its value, "scores": PackedFloat32Array for the
## single-x candidates in order}.
static func plan(lv: Level, s: State, candidates: PackedFloat32Array, horizon: float, dt := DT_COARSE, bias_x := INF, bias := 0.0, pairs := PackedFloat32Array()) -> Dictionary:
	var scores := PackedFloat32Array()
	var best_x := candidates[0]
	var best_v := -INF
	for k in candidates.size():
		var x := candidates[k]
		var v := _line_value(lv, s, hold_path(s.d, s.hx, x), horizon, dt)
		# Small preference for staying put (hysteresis) and for the centre on ties.
		if bias_x != INF:
			v -= absf(x - bias_x) * bias
		v -= absf(x) * 0.002
		scores.append(v)
		if v > best_v:
			best_v = v
			best_x = x
	# Two-stage lines switch early (slip past a threat, then cut in) or half way.
	for split in PAIR_SPLITS:
		var mid := s.d + horizon * float(split)
		for x1 in pairs:
			for x2 in pairs:
				if absf(x1 - x2) < 0.5:
					continue
				var p := hold_path(s.d, s.hx, x1)
				p.append_array(PackedFloat32Array([mid, x1, mid + absf(x2 - x1) / LAT_SLOPE, x2]))
				var v2 := _line_value(lv, s, p, horizon, dt) - 0.5
				if bias_x != INF:
					v2 -= absf(x1 - bias_x) * bias
				if v2 > best_v:
					best_v = v2
					best_x = x1
	return {"x": best_x, "score": best_v, "scores": scores}


static func _line_value(lv: Level, s: State, path: PackedFloat32Array, horizon: float, dt: float) -> float:
	var c := s.copy()
	c.tracing = false
	# Plans keep clear of gate edges so a slightly late hero still lands in the gate.
	c.gate_margin = PLAN_GATE_MARGIN
	advance(lv, c, path, s.d + horizon, dt, horizon / Balance.RUN_SPEED + 4.0)
	return value(lv, c)


## Evenly spaced candidate x across the bridge.
static func candidates(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in n:
		out.append(lerpf(-Balance.X_LIMIT, Balance.X_LIMIT, float(k) / (n - 1)))
	return out


## The planner's own path through a whole level (full knowledge, no noise): re-plans every
## PLAN_STEP units over `horizon`. Returns {"path": waypoints, "result": result dict, "trace"}.
static func best_path(lv: Level, hero: String, army: int, opts := {}) -> Dictionary:
	var s := start_state(lv, hero, army, opts)
	var cands := candidates(int(opts.get("candidates", 13)))
	var horizon := float(opts.get("horizon", 22.0))
	var path := PackedFloat32Array([0.0, 0.0])
	var guard := 0
	while s.mode != Mode.WON and s.mode != Mode.LOST and s.d < lv.length + 50.0 and guard < 2000:
		guard += 1
		var pick := plan(lv, s, cands, horizon, DT_COARSE, s.hx, 0.05, PackedFloat32Array(PAIRS))
		var x := float(pick["x"])
		var seg := hold_path(s.d, s.hx, x)
		path.append_array(seg)
		advance(lv, s, seg, s.d + PLAN_STEP, DT, 30.0)
	var res := result(lv, s)
	return {"path": path, "result": res, "trace": s.trace, "samples": s.samples}


## Straight down the middle (the "lazy" player).
static func lazy_path() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0])


## A random wanderer: a new random x every 4-10 units.
static func random_path(length: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var p := PackedFloat32Array([0.0, 0.0])
	var d := 0.0
	var x := 0.0
	while d < length + 40.0:
		d += rng.randf_range(4.0, 10.0)
		var nx := rng.randf_range(-Balance.X_LIMIT, Balance.X_LIMIT)
		p.append_array(PackedFloat32Array([d, x, d + absf(nx - x) / LAT_SLOPE, nx]))
		d += absf(nx - x) / LAT_SLOPE
		x = nx
	return p


## Points the state's item cursors at distance s.d (for a state started mid-run, e.g. a bot
## snapshot): things the hero has already crossed are not triggered again.
static func sync_cursors(lv: Level, s: State) -> void:
	s.pk = _first_after(lv.d, lv.pick, s.d)
	s.bk = 0
	s.armed.clear()
	while s.bk < lv.block.size() and lv.d[lv.block[s.bk]] - Balance.CONTACT < s.d - 0.001:
		var j := lv.block[s.bk]
		if lv.kind[j] == K.SQUAD and s.alive[j] == 1 and s.d <= lv.d[j] + squad_depth(lv, j):
			s.armed.append(j)
		s.bk += 1
	s.hz = _first_after(lv.d, lv.haz, s.d - Balance.HERO_GAP - 2.0 * Balance.blob_radius(s.army) * Balance.BLOB_STRETCH)
	s.d_prev = s.d


static func _first_after(d: PackedFloat32Array, idx: PackedInt32Array, v: float) -> int:
	var lo := 0
	var hi := idx.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if d[idx[mid]] <= v:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Rebuilds the index lists of `lv` after items were appended to `lv.items` (in d order, after
## the old ones); old indices and cursors stay valid. LevelGen uses it (with grow_state) to walk
## its reference players through a level while the level is being laid out.
static func reindex(lv: Level) -> void:
	lv.kind = PackedInt32Array()
	lv.d = PackedFloat32Array()
	lv.x = PackedFloat32Array()
	lv.hw = PackedFloat32Array()
	lv.pick = PackedInt32Array()
	lv.targ = PackedInt32Array()
	lv.haz = PackedInt32Array()
	lv.tur = PackedInt32Array()
	lv.block = PackedInt32Array()
	lv.rows = {}
	lv.fortress = -1
	_index(lv)


## Grows the per-item arrays of `s` to the items of `lv` (new items start fresh).
static func grow_state(lv: Level, s: State) -> void:
	var old := s.alive.size()
	var n := lv.items.size()
	s.alive.resize(n)
	s.hp.resize(n)
	s.val.resize(n)
	s.val2.resize(n)
	s.op.resize(n)
	s.op2.resize(n)
	s.rev.resize(n)
	for i in range(old, n):
		var it := lv.items[i]
		s.alive[i] = 1
		s.hp[i] = float(it.get("value", 0))
		s.val[i] = float(it.get("value", 0))
		s.op[i] = str(it.get("op", ""))
		s.rev[i] = 0 if it.get("hidden", false) else 1
		if it.has("blink"):
			var b: Dictionary = it["blink"]
			s.op2[i] = str(b.get("op", "+"))
			s.val2[i] = float(b.get("value", 0))


## Builds a Level from item dictionaries that are already in d order (e.g. a window of a live
## run's items, with base positions for moving things).
static func level_from_items(items: Array, level: int, length: float) -> Level:
	var lv := Level.new()
	lv.level = level
	lv.length = length
	for it: Dictionary in items:
		lv.items.append(it)
	_index(lv)
	return lv
