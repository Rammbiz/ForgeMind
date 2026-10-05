class_name Bot
## Test player for the autotest and screenshots. Every THINK seconds it scores ~21 target x
## across the bridge by simulating the next ~22 units with LevelSim from a snapshot of the live
## run, keeps its current line unless another is clearly better (hysteresis), then calls
## run.steer_to(x). It fires the ult when LevelSim.ult_worth() says a big squad / the fortress /
## (titan) a hazard is ahead.
##
## Modes: "best" (the planner), "lazy" (always x 0), "random" (a new random x every 4-10 u).
## `skill` < 1 adds aim noise, a reaction delay and the odd random pick. Call reset() between
## levels.
##
## The run is used untyped (Run is rewritten in parallel); it needs the spec section 2 fields:
## state, d, hx, army, coins, hero_hp, items, weapons, arm_tier, power, level, hero_type, def,
## start(), steer_to(), ult_ready(), use_ult(); optional: t (run seconds, for moving / blinking
## gates), ult_points, length.

const THINK := 0.2
const AHEAD := 22.0
const BEHIND := 8.0
const STATE_READY := 0
const STATE_RUNNING := 1
const STATE_CLASH := 2

var mode := "best"
var skill := 1.0
var candidates := 21
var horizon := AHEAD
var power_level := 0                ## Save.upgrades["power"] of the run (autoplay sets it)
var rng := RandomNumberGenerator.new()

var _next_think := -1.0
var _target := 0.0
var _pending: Array = []            ## [[apply_at_time, x], ...] (reaction delay)
var _wander_until := 0.0
var _clock := 0.0
var _last_ms := -1
var _cands := PackedFloat32Array()


## Forgets everything about the previous level (keeps mode, skill and the rng).
func reset() -> void:
	_next_think = -1.0
	_target = 0.0
	_pending.clear()
	_wander_until = 0.0
	_clock = 0.0
	_last_ms = -1


## Call every frame.
func think(run: Object) -> void:
	var st := int(run.get("state"))
	if st == STATE_READY:
		run.call("start")
	var t := _run_time(run)
	_apply_pending(run, t)
	if t < _next_think:
		return
	_next_think = t + THINK
	var snap := snapshot(run, mode == "best" and skill < 1.0)
	var lv: LevelSim.Level = snap[0]
	var s: LevelSim.State = snap[1]
	if bool(run.call("ult_ready")) and LevelSim.ult_worth(lv, s):
		run.call("use_ult")
	if st != STATE_RUNNING:
		return
	match mode:
		"lazy":
			_steer(run, t, 0.0)
		"random":
			if float(run.get("d")) >= _wander_until:
				_wander_until = float(run.get("d")) + rng.randf_range(4.0, 10.0)
				_target = rng.randf_range(-Balance.X_LIMIT, Balance.X_LIMIT)
			_steer(run, t, _target)
		_:
			_steer(run, t, _best_x(lv, s))


## The planner's pick with hysteresis and skill noise.
func _best_x(lv: LevelSim.Level, s: LevelSim.State) -> float:
	if _cands.size() != candidates:
		_cands = LevelSim.candidates(candidates)
	var cands := _cands.duplicate()
	cands.append(clampf(_target, -Balance.X_LIMIT, Balance.X_LIMIT))
	var pick := LevelSim.plan(lv, s, cands, horizon, LevelSim.DT_COARSE, INF, 0.0, PackedFloat32Array(LevelSim.PAIRS))
	var scores: PackedFloat32Array = pick["scores"]
	var keep := scores[scores.size() - 1]
	var x := float(pick["x"])
	# Hysteresis: only change line when it is clearly better.
	if float(pick["score"]) < keep + 1.0 + absf(keep) * 0.02:
		x = _target
	if skill < 1.0:
		var miss := 1.0 - skill
		if rng.randf() < miss * 0.25:
			x = cands[rng.randi() % cands.size()]
		x += rng.randfn(0.0, miss * 1.2)
	return clampf(x, -Balance.X_LIMIT, Balance.X_LIMIT)


func _steer(run: Object, t: float, x: float) -> void:
	_target = x
	var delay := (1.0 - skill) * 0.35
	if delay <= 0.01:
		run.call("steer_to", x)
	else:
		_pending.append([t + delay, x])


func _apply_pending(run: Object, t: float) -> void:
	while not _pending.is_empty() and float(_pending[0][0]) <= t:
		run.call("steer_to", float(_pending[0][1]))
		_pending.pop_front()


## Run seconds: the run's own clock when it has one, else the bot's (scaled by time_scale).
func _run_time(run: Object) -> float:
	var t: Variant = run.get("t")
	if t != null:
		return float(t)
	var now := Time.get_ticks_msec()
	if _last_ms >= 0 and int(run.get("state")) != STATE_READY:
		_clock += (now - _last_ms) / 1000.0 * Engine.time_scale
	_last_ms = now
	return _clock


## [LevelSim.Level, LevelSim.State] for the live run: items from BEHIND to AHEAD + 30 units
## around the hero with their live state. `fog`: unrevealed hidden gates count as +0.
func snapshot(run: Object, fog := true) -> Array:
	var d := float(run.get("d"))
	var t := _run_time(run)
	var view: Array[Dictionary] = []
	var live: Array[Dictionary] = []
	var items: Array = run.get("items")
	for it: Dictionary in items:
		var di := float(it["d"])
		if di < d - BEHIND:
			continue
		if di > d + horizon + 30.0 and str(it["kind"]) != "fortress":
			continue
		var v := it.duplicate()
		v.erase("node")
		v.erase("crowd")
		v.erase("label")
		# Moving things: the run stores the live x; the sim wants the rail centre.
		if it.has("move"):
			var m: Dictionary = it["move"]
			v["x"] = float(it["x"]) - float(m.get("amp", 0.0)) * sin(TAU * t / maxf(float(m.get("period", 2.0)), 0.1) + float(m.get("phase", 0.0)))
		elif str(it.get("type", "")) == "sweeper":
			v["x"] = float(it["x"]) - float(it.get("amp", 0.0)) * sin(TAU * t / maxf(float(it.get("period", 2.0)), 0.1) + float(it.get("phase", 0.0)))
		view.append(v)
		live.append(it)
	var length := float(run.get("length")) if run.get("length") != null else d + 200.0
	var lv := LevelSim.level_from_items(view, int(run.get("level")), length)
	var hero := str(run.get("hero_type"))
	var s := LevelSim.start_state(lv, hero, int(run.get("army")), {"power": power_level})
	s.d = d
	s.t = t
	s.hx = float(run.get("hx"))
	s.coins = int(run.get("coins"))
	s.hero_hp = float(run.get("hero_hp"))
	s.arm = int(run.get("arm_tier"))
	var pw: Dictionary = run.get("power")
	s.p_rate = float(pw.get("rate", 0.0))
	s.p_dmg = int(pw.get("dmg", 0))
	s.p_multi = int(pw.get("multi", 0))
	for w: Dictionary in run.get("weapons"):
		s.weapons.append([str(w["kind"]), int(w["level"]), 0.0])
	var up: Variant = run.get("ult_points")
	if up != null:
		s.ult = float(up)
	elif bool(run.call("ult_ready")):
		s.ult = float((Balance.HEROES[hero]["ult"] as Dictionary)["charge"])
	for i in live.size():
		var it := live[i]
		s.alive[i] = 1 if bool(it.get("alive", true)) else 0
		if it.has("hp"):
			s.hp[i] = float(it["hp"])
		if str(it["kind"]) == "gate":
			var hidden := bool(it.get("hidden", false)) and not bool(it.get("revealed", false))
			s.rev[i] = 0 if hidden else 1
			if it.has("faces"):
				# The run keeps both faces of a blinking gate (with the hero's hits on each).
				var faces: Array = it["faces"]
				s.op[i] = str(faces[0][0])
				s.val[i] = float(faces[0][1])
				if faces.size() > 1:
					s.op2[i] = str(faces[1][0])
					s.val2[i] = float(faces[1][1])
				if hidden and fog:
					s.op[i] = "+"
					s.val[i] = 0.0
					s.op2[i] = "+"
					s.val2[i] = 0.0
				continue
			var shown_op := str(it.get("op", ""))
			var shown_v := float(it.get("value", 0))
			if hidden and fog:
				shown_op = "+"
				shown_v = 0.0
			if it.has("blink") and LevelSim.blink_phase(lv, i, t) == 1:
				s.op2[i] = shown_op
				s.val2[i] = shown_v
			else:
				s.op[i] = shown_op
				s.val[i] = shown_v
	if int(run.get("state")) == STATE_CLASH:
		# Keep fighting the squad in front.
		for i in live.size():
			if str(live[i]["kind"]) == "squad" and s.alive[i] == 1 and absf(float(live[i]["d"]) - Balance.CONTACT - d) < 0.6:
				s.mode = LevelSim.Mode.CLASH
				s.foe = i
	LevelSim.sync_cursors(lv, s)
	return [lv, s]
