class_name Bot
extends RefCounted
## Scripted player used for automated balance tests and screenshots.
##
## skill 1.0 plays like a good human: it reads the wave preview a couple of
## waves ahead, keeps enough anti-air ready before flying waves, puts towers on
## the cells that see the most path (merges and early stretches count extra),
## drops frost under its kill zones and upgrades its best-placed towers.
## skill ~0.6 plays like a casual player: it reacts slower, mostly answers the
## wave that just hurt it instead of reading the preview, upgrades less, has
## favourite towers, prefers cheap buys, sits on spare gold, underrates slow
## support and often settles for a worse cell. Intermediate skills blend the
## two. Every random choice goes through `rng`, so a run is reproducible per seed.
##
## Model: every upcoming wave is split into "streams" (one enemy group of one
## wave). For each stream and path the bot estimates the damage its towers deal
## to one passing enemy ("capacity"): effective DPS x time in range, capped by
## the share of tower time each enemy gets while the whole wave streams past
## (so single-target towers saturate on swarms while splash / chains do not).
## With r = capacity / hp, a stream is roughly safe at r >= 1; the bot spends
## gold where sum(lives at risk * (1 - exp(-K * r))) rises fastest per coin,
## which spreads the defense over air / armor / swarms and over every path.

const STEP := 0.25            # path sample spacing, tiles
const EARLY_BIAS := 0.25      # extra weight of the first part of every path
const SLOW_UPTIME := 0.75     # share of the time a frosted stretch keeps enemies slowed
const SLOW_MARGIN := 0.4      # slow lingers a little past the frost range
const THINK_STEP := 0.5       # callers think every 0.5 s of game time
const EARLY_CALL_R := 1.6     # defense / hp ratio a good player wants before calling early
const KILL_K := 1.5           # steepness of the "stream is handled" utility
# Measured (kill-capacity lab runs) vs modelled damage of each tower type: the
# formulas miss the laser's sticky beam, the cannon's ball lead and part of
# the tesla chain.
const EFFICIENCY := {"arrow": 1.0, "cannon": 1.25, "frost": 1.0, "tesla": 1.2, "laser": 1.5}
const TOP_CELLS := 5           # candidate cells kept per tower type
const LOOK_WEIGHTS: Array[float] = [1.0, 0.7, 0.45]   # wave preview, good player

var skill := 1.0
var call_early := false       # always call the next wave as soon as the field is clear
var verbose := false          # print every build / upgrade with the top options
var debug := false            # with verbose: also print the per-stream reasoning
var rng := RandomNumberGenerator.new()

var _map_ready := false
var _pos := PackedVector2Array()       # path sample positions (x, z)
var _spath := PackedInt32Array()       # path index of each sample
var _bias := PackedFloat32Array()      # weight of each sample
var _npaths := 1
var _cells: Array[Vector2i] = []
var _in_range := {}                    # Vector3(x, y, range) -> PackedInt32Array
var _cov_cache := {}                   # Vector3(x, y, range) -> PackedFloat32Array per path
var _tmult := PackedFloat32Array()     # time multiplier per sample from frost slow
var _slow_sig := ""
var _streams: Array[Dictionary] = []   # see _add_stream()
var _looks: Array[Dictionary] = []     # per looked-at wave: {"wave", "duration"}
var _cap: Array[PackedFloat32Array] = []   # per stream, per path
var _dens: Array[PackedFloat32Array] = []  # per stream, per sample: DPS that benefits from slow
var _wait := 0.0
var _clock := 0.0
var _earned: Array[Vector2] = []       # (time, gold earned so far), last 30 s
var _seen_wave := -1
var _lives_at_wave := 0
var _taste := {}                       # tower type -> personal preference multiplier


func _init() -> void:
	rng.seed = 1


func set_seed(value: int) -> void:
	rng.seed = value


## 0 at skill <= 0.5, 1 at skill >= 1.0.
func _t() -> float:
	return clampf((skill - 0.5) / 0.5, 0.0, 1.0)


## Waves the player thinks about, as [wave index, weight]. A good player
## reads the preview two waves ahead; a casual one mostly reacts to the wave
## that just hurt him and barely glances at the next one.
func _look_plan(game: Game) -> Array:
	var t := _t()
	var out: Array = []
	var fighting := game.wave > 0 and (not game.can_call_wave() or not game.enemies.is_empty())
	if game.wave > 0:
		out.append([game.wave - 1, 0.7 if fighting else lerpf(1.0, 0.0, t)])
	var ahead: Array[float] = [
		LOOK_WEIGHTS[0] * lerpf(0.35, 1.0, t),
		LOOK_WEIGHTS[1] * clampf((skill - 0.6) / 0.3, 0.0, 1.0),
		LOOK_WEIGHTS[2] * clampf((skill - 0.8) / 0.2, 0.0, 1.0),
	]
	for k in ahead.size():
		if game.wave + k < game.waves.size() and ahead[k] > 0.0:
			out.append([game.wave + k, ahead[k]])
	return out


## Personal taste: casual players over-use some tower types and neglect others.
func _taste_of(type: String) -> float:
	if not _taste.has(type):
		_taste[type] = exp(rng.randfn(0.0, 0.45 * (1.0 - _t()) * (1.0 - _t())))
	return _taste[type]


# ------------------------------------------------------------------ main loop

func think(game: Game) -> void:
	if not game.is_running():
		return
	_prepare(game)
	_clock += THINK_STEP
	_earned.append(Vector2(_clock, float(game.stats["gold_earned"])))
	while _earned.size() > 1 and _clock - _earned[0].x > 30.0:
		_earned.pop_front()
	if game.wave != _seen_wave:
		_seen_wave = game.wave
		_lives_at_wave = game.lives
	var acted := false
	_wait -= THINK_STEP
	if _wait <= 0.0 and not _streams.is_empty():
		acted = _act(game)
		if acted:
			_wait = lerpf(6.0, 0.0, _t()) * rng.randf_range(0.5, 1.5)
	if acted:
		return
	if game.wave == 0:
		if not game.towers.is_empty() and _wait <= 0.0:
			game.start_next_wave()
	elif game.can_call_wave() and game.lives >= _lives_at_wave and _wants_early_call(game):
		game.start_next_wave()


## Good players call the next wave early (the countdown left is paid out as
## bonus gold) when the field is under control and the defense comfortably
## covers what comes next. Casual players just wait for the timer.
func _wants_early_call(game: Game) -> bool:
	if call_early:
		return game.enemies.is_empty()
	if skill < 0.7 or game.enemies.size() > 4:
		return false
	for e in game.enemies:
		if e.boss:
			return false
	var r_min := INF
	for si in _streams.size():
		var s: Dictionary = _streams[si]
		if int(_looks[int(s["look"])]["wave"]) != game.wave:
			continue
		var w: PackedFloat32Array = s["w"]
		var cap: PackedFloat32Array = _cap[si]
		for p in _npaths:
			if w[p] > 0.0:
				r_min = minf(r_min, cap[p] / float(s["hp"]))
	return r_min >= lerpf(2.6, EARLY_CALL_R, (skill - 0.7) / 0.3)


## Picks and performs the most valuable affordable action. Returns false when
## the bot decides to save gold (or has nothing worth buying).
func _act(game: Game) -> bool:
	var t := _t()
	var sigma := lerpf(0.4, 0.06, t)
	var cands: Array[Dictionary] = []
	for type: String in game.level["towers"]:
		var ranked := _rank_cells(game, type)
		if ranked.is_empty():
			continue
		# Weaker players often settle for a worse cell: a decent one for an
		# intermediate player, anything that looks fine for a casual one.
		var pick := 0
		if rng.randf() < (1.0 - skill) * 1.2 and ranked.size() > 1:
			var deepest := 1 + int(round((1.0 - _t()) * (TOP_CELLS - 2)))
			pick = rng.randi_range(1, mini(deepest, ranked.size() - 1))
		var cost := game.tower_cost(type)
		cands.append({"kind": "build", "type": type, "cell": ranked[pick][1], "cost": cost, "score": float(ranked[pick][0]) / cost * _taste_of(type)})
	var up_mult := lerpf(0.4, 1.0, t)
	var max_lvl := 2 if skill >= 0.7 else 1
	for tw: Tower in game.towers.values():
		if not tw.can_upgrade() or tw.level + 1 > max_lvl:
			continue
		var cost := tw.upgrade_cost()
		var g := _gain(_upgrade_delta(game, tw))
		cands.append({"kind": "upgrade", "tower": tw, "type": tw.type, "cell": tw.cell, "cost": cost, "score": g / cost * up_mult * _taste_of(tw.type)})
	if cands.is_empty():
		return false
	# Casual players also favour cheap buys over expensive specialists.
	var cheap := 0.5 * (1.0 - t) * (1.0 - t)
	for c in cands:
		c["score"] = float(c["score"]) * maxf(0.2, 1.0 + rng.randfn(0.0, sigma)) * pow(70.0 / float(c["cost"]), cheap)
	# Options we cannot afford yet are discounted by how long saving for them
	# would take at the current income. Good players save for a strong buy,
	# casual ones (and anyone who is leaking right now) buy what they can.
	# Before the first wave there is no income, so there is nothing to save for.
	var tau := lerpf(4.0, 14.0, t)
	if game.lives < _lives_at_wave:
		tau *= 0.4
	var income := maxf(_income_rate(game), 0.5)
	# Casual players also like to sit on a cushion of gold once the game runs.
	var cushion := 0.0 if game.wave == 0 else 0.8 * (1.0 - t) * (1.0 - t)
	for c in cands:
		var deficit := int(c["cost"]) * (1.0 + cushion) - game.gold
		if deficit > 0.0:
			c["score"] = 0.0 if game.wave == 0 else float(c["score"]) * exp(-deficit / income / tau)
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	if float(cands[0]["score"]) <= 0.0:
		return false
	var choice: Dictionary = cands[0]
	if int(choice["cost"]) * (1.0 + cushion) > game.gold:
		return false
	if verbose:
		var top := ""
		for i in mini(cands.size(), 5):
			top += " %s:%s/%s=%.4f" % [cands[i]["kind"][0], cands[i]["type"], cands[i]["cell"], float(cands[i]["score"]) * 100.0]
		print("  BOT options", top)
		if debug:
			for si in _streams.size():
				var st: Dictionary = _streams[si]
				var line := "    stream w%d %s hp=%.0f sp=%.2f w=%s cap=%s |" % [int(_looks[int(st["look"])]["wave"]) + 1, st["type"], float(st["hp"]), float(st["spacing"]), st["w"], _cap[si]]
				for c in cands:
					if c["kind"] != "build":
						continue
					var dl := _build_delta(game, c["type"], c["cell"])
					line += " %s:%s" % [str(c["type"]).substr(0, 3), dl[si]]
				print(line)
	if choice["kind"] == "build":
		var built := game.build_tower(choice["cell"], choice["type"])
		if built and verbose:
			print("  BOT w%d build %s at %s (gold %d)" % [game.wave, choice["type"], choice["cell"], game.gold])
		return built != null
	var tw2: Tower = choice["tower"]
	var ok := game.upgrade_tower(tw2)
	if ok and verbose:
		print("  BOT w%d upgrade %s at %s -> L%d (gold %d)" % [game.wave, tw2.type, tw2.cell, tw2.level + 1, game.gold])
	return ok


## Gold per second over the last half minute.
func _income_rate(game: Game) -> float:
	if _earned.size() < 2:
		return 0.0
	var a: Vector2 = _earned[0]
	var b: Vector2 = _earned[_earned.size() - 1]
	return (b.y - a.y) / maxf(b.x - a.x, 1.0)


## Best buildable cell for a tower type (used by the screenshot tool too).
func best_cell(game: Game, type: String) -> Vector2i:
	_prepare(game)
	var ranked := _rank_cells(game, type)
	return ranked[0][1] if not ranked.is_empty() else Vector2i(-1, -1)


# ------------------------------------------------------------------ path model

func _prepare(game: Game) -> void:
	_ensure_map(game)
	_update_slow(game)
	_read_threat(game)
	_compute_capacity(game)


func _ensure_map(game: Game) -> void:
	if _map_ready:
		return
	_map_ready = true
	_npaths = maxi(game.map.curves.size(), 1)
	for pi in game.map.curves.size():
		var curve: Curve3D = game.map.curves[pi]
		var length: float = game.map.path_lengths[pi]
		var d := STEP * 0.5
		while d < length:
			var p := curve.sample_baked(d)
			_pos.append(Vector2(p.x, p.z))
			_spath.append(pi)
			_bias.append(1.0 + EARLY_BIAS * (1.0 - d / length))
			d += STEP
	for c: Vector2i in game.map.cells:
		if game.map.is_buildable(c):
			_cells.append(c)
	_tmult.resize(_pos.size())
	_tmult.fill(1.0)


func _samples_in(game: Game, c: Vector2i, r: float) -> PackedInt32Array:
	var key := Vector3(c.x, c.y, r)
	if _in_range.has(key):
		return _in_range[key]
	var w := game.map.cell_to_world(c)
	var center := Vector2(w.x, w.z)
	var r2 := r * r
	var out := PackedInt32Array()
	for i in _pos.size():
		if _pos[i].distance_squared_to(center) <= r2:
			out.append(i)
	_in_range[key] = out
	return out


## Path length (stretched by slows) a tower at `c` with range `r` sees per
## path; entries [npaths, 2 * npaths) hold the same for bosses, which shrug
## off 40% of every slow.
func _cov(game: Game, c: Vector2i, r: float) -> PackedFloat32Array:
	var key := Vector3(c.x, c.y, r)
	if _cov_cache.has(key):
		return _cov_cache[key]
	var out := PackedFloat32Array()
	out.resize(_npaths * 2)
	for i in _samples_in(game, c, r):
		var w := STEP * _bias[i]
		var slowed := 1.0 - 1.0 / _tmult[i]
		out[_spath[i]] += w * _tmult[i]
		out[_npaths + _spath[i]] += w / (1.0 - 0.6 * slowed)
	_cov_cache[key] = out
	return out


func _slow_mult(slow: float) -> float:
	return 1.0 / (1.0 - slow * SLOW_UPTIME)


func _slow_map(game: Game, skip: Tower = null) -> PackedFloat32Array:
	var tm := PackedFloat32Array()
	tm.resize(_pos.size())
	tm.fill(1.0)
	for tw: Tower in game.towers.values():
		if tw == skip or not tw.stats.has("slow"):
			continue
		var m := _slow_mult(float(tw.stats["slow"]))
		for i in _samples_in(game, tw.cell, tw.range_radius() + SLOW_MARGIN):
			tm[i] = maxf(tm[i], m)
	return tm


func _update_slow(game: Game) -> void:
	var sig := ""
	for tw: Tower in game.towers.values():
		if tw.stats.has("slow"):
			sig += "%s%d;" % [tw.cell, tw.level]
	if sig == _slow_sig:
		return
	_slow_sig = sig
	_tmult = _slow_map(game)
	_cov_cache.clear()


# ------------------------------------------------------------------ threat

## Reads the waves the player can see coming (the one in progress plus the
## wave preview, further ahead for better players).
func _read_threat(game: Game) -> void:
	_streams.clear()
	_looks.clear()
	var looks := _look_plan(game)
	var total := 0.0
	for look: Array in looks:
		var wi: int = look[0]
		var lw: float = look[1]
		var mult := GameData.wave_hp_mult(game.level_index, wi)
		var groups: Array = game.waves[wi]
		var density := PackedFloat32Array()    # enemies per tile while the wave streams
		density.resize(_npaths)
		var duration := 1.0
		for g: Array in groups:
			var def: Dictionary = GameData.ENEMIES[g[0]]
			var shares := _shares(int(g[4]))
			var n := int(g[1])
			duration = maxf(duration, float(g[3]) + n * float(g[2]))
			for p in _npaths:
				if n > 1 and float(g[2]) > 0.0:
					density[p] += shares[p] / (float(g[2]) * float(def["speed"]))
		var li := _looks.size()
		_looks.append({"wave": wi, "duration": duration})
		for g: Array in groups:
			var type: String = g[0]
			var def2: Dictionary = GameData.ENEMIES[type]
			var shares2 := _shares(int(g[4]))
			var own := 0.0
			if int(g[1]) > 1 and float(g[2]) > 0.0:
				own = 1.0 / (float(g[2]) * float(def2["speed"]))
			var sp := _spacing(own, shares2, density)
			total += _add_stream(li, type, int(g[1]), mult, lw, shares2, sp)
			if def2.has("split"):
				var n2 := int(g[1]) * int(def2.get("split_count", 2))
				total += _add_stream(li, str(def2["split"]), n2, mult, lw, shares2, 0.3)
	if total <= 0.0:
		_streams.clear()
		return
	for s in _streams:
		var w: PackedFloat32Array = s["w"]
		for p in _npaths:
			w[p] /= total
		s["w"] = w


func _shares(spawn: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(_npaths)
	if spawn < 0 or spawn >= _npaths:
		s.fill(1.0 / _npaths)
	else:
		s[spawn] = 1.0
	return s


## Typical distance between neighbours, for splash / chain hit estimates.
func _spacing(own: float, shares: PackedFloat32Array, density: PackedFloat32Array) -> float:
	var dens := 0.0
	for p in _npaths:
		if shares[p] > 0.0:
			dens = maxf(dens, maxf(own * shares[p], 0.75 * density[p]))
	return clampf(1.0 / dens, 0.3, 20.0) if dens > 0.0 else 20.0


func _add_stream(look: int, type: String, count: int, mult: float, lw: float, shares: PackedFloat32Array, spacing: float) -> float:
	var def: Dictionary = GameData.ENEMIES[type]
	var hp := float(def["hp"]) * mult
	var weight := float(count) * int(def["lives"]) * lw
	var w := PackedFloat32Array()
	w.resize(_npaths)
	var n := PackedFloat32Array()
	n.resize(_npaths)
	for p in _npaths:
		w[p] = weight * shares[p]
		n[p] = count * shares[p]
	_streams.append({"look": look, "type": type, "w": w, "n": n, "hp": hp, "spacing": spacing,
		"speed": float(def["speed"]), "armor": float(def["armor"]), "flying": bool(def["flying"]),
		"boss": bool(def.get("boss", false))})
	return weight


# ------------------------------------------------------------------ capacity

## Effective damage per second of a tower against one enemy of a stream,
## counting splash / chain hits, armor and the laser ramp.
func _dps(type: String, lvl: int, s: Dictionary) -> float:
	var def: Dictionary = GameData.TOWERS[type]
	var st: Dictionary = def["levels"][lvl]
	if bool(s["flying"]) and not bool(def["air"]):
		return 0.0
	if not bool(s["flying"]) and not bool(def["ground"]):
		return 0.0
	var sp := float(s["spacing"])
	var dmg := 0.0
	if st.has("dps"):
		var d := float(st["dps"])
		dmg = d * _ramp_avg(d, float(s["hp"]), float(st["ramp"]), float(st["ramp_time"]))
	else:
		dmg = float(st["damage"]) * float(st["rate"])
	if def["dmg_type"] == "phys":
		dmg *= 1.0 - float(s["armor"])
	if st.has("chains"):
		var n := 1.0 + (float(st["chains"]) - 1.0) * clampf(float(st["chain_range"]) / sp, 0.0, 1.0)
		dmg *= (1.0 - pow(0.85, n)) / 0.15
	elif st.has("splash"):
		# Fitted to measured cannon hits: ~1 when neighbours sit outside the blast.
		dmg *= clampf(1.0 + 1.6 * (float(st["splash"]) / sp - 0.8), 1.0, 4.0)
	return dmg * float(EFFICIENCY.get(type, 1.0))


## Average damage multiplier of a ramping beam while it kills `hp`.
func _ramp_avg(d: float, hp: float, ramp: float, ramp_time: float) -> float:
	var k := (ramp - 1.0) / ramp_time
	var full := d * (ramp_time + 0.5 * k * ramp_time * ramp_time)
	var t := 0.0
	if hp <= full:
		t = (-1.0 + sqrt(1.0 + 2.0 * k * hp / d)) / k
	else:
		t = ramp_time + (hp - full) / (d * ramp)
	return hp / (d * maxf(t, 0.01))


## Damage a tower deals to one enemy of every stream, per path, as
## [damage, util] per stream (util: the part of its DPS limited by the time an
## enemy stays in range, which is what slow improves). While a wave streams
## past, the tower's fire time is shared by every enemy it can hit in
## proportion to how long each takes to kill, and no enemy can take more than
## the time it spends in range.
func _vs_all(type: String, lvl: int, cov: PackedFloat32Array) -> Array:
	var ns := _streams.size()
	var f := PackedFloat32Array()
	f.resize(ns)
	var busy := PackedFloat32Array()
	busy.resize(_looks.size())
	var need := PackedFloat32Array()
	need.resize(_looks.size())
	var tail := PackedFloat32Array()
	tail.resize(_looks.size())
	for si in ns:
		var s: Dictionary = _streams[si]
		f[si] = _dps(type, lvl, s)
		if f[si] <= 0.0:
			continue
		var li := int(s["look"])
		var n: PackedFloat32Array = s["n"]
		var speed := float(s["speed"])
		var off := _npaths if bool(s["boss"]) else 0
		for p in _npaths:
			if cov[p] <= 0.3:
				continue
			busy[li] += n[p] * cov[off + p] / speed
			need[li] += n[p] * float(s["hp"]) / f[si]
			tail[li] = maxf(tail[li], cov[off + p] / speed)
	var share := PackedFloat32Array()
	share.resize(_looks.size())
	for li in _looks.size():
		if need[li] > 0.0:
			share[li] = minf(busy[li], float(_looks[li]["duration"]) + tail[li]) / need[li]
	var out := []
	for si in ns:
		var dmg := PackedFloat32Array()
		dmg.resize(_npaths)
		var util := PackedFloat32Array()
		util.resize(_npaths)
		if f[si] > 0.0:
			var s2: Dictionary = _streams[si]
			var kill := share[int(s2["look"])] * float(s2["hp"])
			var off2 := _npaths if bool(s2["boss"]) else 0
			for p in _npaths:
				if cov[p] <= 0.3:
					continue
				var alone := f[si] * cov[off2 + p] / float(s2["speed"])
				dmg[p] = minf(kill, alone)
				util[p] = f[si] * minf(1.0, kill / alone)
		out.append([dmg, util])
	return out


func _compute_capacity(game: Game) -> void:
	_cap.clear()
	_dens.clear()
	for s in _streams:
		var cap := PackedFloat32Array()
		cap.resize(_npaths)
		_cap.append(cap)
		var dens := PackedFloat32Array()
		dens.resize(_pos.size())
		_dens.append(dens)
	for tw: Tower in game.towers.values():
		var all := _vs_all(tw.type, tw.level, _cov(game, tw.cell, tw.range_radius()))
		var idx := _samples_in(game, tw.cell, tw.range_radius())
		for si in _streams.size():
			var dmg: PackedFloat32Array = all[si][0]
			var util: PackedFloat32Array = all[si][1]
			var cap: PackedFloat32Array = _cap[si]
			for p in _npaths:
				cap[p] += dmg[p]
			_cap[si] = cap
			var dens: PackedFloat32Array = _dens[si]
			for i in idx:
				dens[i] += util[_spath[i]]
			_dens[si] = dens


## Utility gained from extra capacity: sum(lives at risk * (1 - exp(-K * cap / hp))).
func _gain(delta: Array[PackedFloat32Array]) -> float:
	var g := 0.0
	for si in _streams.size():
		var s: Dictionary = _streams[si]
		var w: PackedFloat32Array = s["w"]
		var cap: PackedFloat32Array = _cap[si]
		var d: PackedFloat32Array = delta[si]
		var k := float(s["hp"])
		for p in _npaths:
			if w[p] <= 0.0 or d[p] == 0.0:
				continue
			g += w[p] * (exp(-KILL_K * cap[p] / k) - exp(-KILL_K * maxf(cap[p] + d[p], 0.0) / k))
	return g


func _empty_delta() -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	for s in _streams:
		var d := PackedFloat32Array()
		d.resize(_npaths)
		out.append(d)
	return out


## Adds (sign 1) or removes (sign -1) a tower's own damage to `delta`.
func _tower_delta(game: Game, type: String, lvl: int, c: Vector2i, sign: float, delta: Array[PackedFloat32Array]) -> void:
	var cov := _cov(game, c, float(GameData.tower_stats(type, lvl)["range"]))
	var all := _vs_all(type, lvl, cov)
	for si in _streams.size():
		var dmg: PackedFloat32Array = all[si][0]
		var d := delta[si]
		for p in _npaths:
			d[p] += sign * dmg[p]
		delta[si] = d


## Extra damage other towers deal because a slow at `c` keeps enemies longer
## in their range. `base` is the slow map without it.
func _slow_delta(game: Game, c: Vector2i, slow: float, r: float, base: PackedFloat32Array, sign: float, delta: Array[PackedFloat32Array]) -> void:
	var m := _slow_mult(slow)
	var idx := _samples_in(game, c, r + SLOW_MARGIN)
	sign *= lerpf(0.3, 1.0, _t())   # casual players underrate slow support
	for si in _streams.size():
		var dens: PackedFloat32Array = _dens[si]
		var d := delta[si]
		var inv := sign / float(_streams[si]["speed"]) * (0.6 if bool(_streams[si]["boss"]) else 1.0)
		for i in idx:
			var extra := m - base[i]
			if extra > 0.0 and dens[i] > 0.0:
				d[_spath[i]] += STEP * _bias[i] * extra * dens[i] * inv
		delta[si] = d


func _build_delta(game: Game, type: String, c: Vector2i) -> Array[PackedFloat32Array]:
	var delta := _empty_delta()
	_tower_delta(game, type, 0, c, 1.0, delta)
	var st: Dictionary = GameData.tower_stats(type, 0)
	if st.has("slow"):
		_slow_delta(game, c, float(st["slow"]), float(st["range"]), _tmult, 1.0, delta)
	return delta


func _upgrade_delta(game: Game, tw: Tower) -> Array[PackedFloat32Array]:
	var delta := _empty_delta()
	_tower_delta(game, tw.type, tw.level + 1, tw.cell, 1.0, delta)
	_tower_delta(game, tw.type, tw.level, tw.cell, -1.0, delta)
	if tw.stats.has("slow"):
		var base := _slow_map(game, tw)
		var nxt: Dictionary = GameData.tower_stats(tw.type, tw.level + 1)
		_slow_delta(game, tw.cell, float(nxt["slow"]), float(nxt["range"]), base, 1.0, delta)
		_slow_delta(game, tw.cell, float(tw.stats["slow"]), tw.range_radius(), base, -1.0, delta)
	return delta


## Best TOP_CELLS buildable cells for a tower type as [gain, cell], best first.
func _rank_cells(game: Game, type: String) -> Array:
	var top: Array = []
	var r := float(GameData.tower_stats(type, 0)["range"])
	for c in _cells:
		if not game.can_build(c):
			continue
		var g := 0.0
		if _streams.is_empty():
			# Nothing announced: plain path coverage.
			var cov := _cov(game, c, r)
			for p in _npaths:
				g += cov[p]
		else:
			g = _gain(_build_delta(game, type, c))
		if g > 0.0:
			_push_top(top, g, c)
	return top


func _push_top(top: Array, score: float, c: Vector2i) -> void:
	var i := top.size()
	while i > 0 and float(top[i - 1][0]) < score:
		i -= 1
	if i >= TOP_CELLS:
		return
	top.insert(i, [score, c])
	if top.size() > TOP_CELLS:
		top.pop_back()
