extends Node
## Headless unit tests of the KindView refactor (heroes design §10.4, phase H0): the kind table
## covers the starters, the shared ult rules (HeroKinds) drive a KindView in the right order,
## and LevelSim through HeroKinds is bit-identical to the Meta-1 inline rules (a verbatim copy
## of the 2.2.1 code lives below as the golden reference) on states sampled from real levels.
## The champion slots API stays empty while the phase flag is below H2.
##
## godot --headless --path . res://scenes/dev/test_kinds.tscn      Exit code = failures.

var _fails := 0
var _passes := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_test_table()
	_test_rules_order()
	_test_slow_and_fork()
	_test_sim_golden()
	_test_champions_off()
	print("TEST_KINDS %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		print("  FAIL ", what)


# ------------------------------------------------------------------ table

func _test_table() -> void:
	print("== kind table")
	_ok(HeroKinds.ult_kind("bolt") == &"storm" and HeroKinds.attack_kind("bolt") == HeroKinds.ATTACK_DART, "bolt = dart / storm")
	_ok(HeroKinds.ult_kind("titan") == &"quake" and HeroKinds.attack_kind("titan") == HeroKinds.ATTACK_BOULDER, "titan = boulder / quake")
	_ok(HeroKinds.ult_kind("seer") == &"rift" and HeroKinds.attack_kind("seer") == HeroKinds.ATTACK_ORBS, "seer = orbs / rift")
	for id: String in Balance.HERO_ORDER:
		_ok(HeroKinds.KINDS.has(id), "%s has a kind row" % id)
		var u: Dictionary = Balance.HEROES[id]["ult"]
		var kind := HeroKinds.ult_kind(id)
		_ok(HeroKinds.ULTS.has(kind), "%s ult kind %s is defined" % [id, kind])
		# The shape must match the numbers the hero carries.
		if HeroKinds.is_timed(kind):
			_ok(u.has("duration") and u.has("tick") and u.has("range"), "%s timed ult has duration / tick / range" % id)
		else:
			_ok(u.has("waves") and u.has("spacing") and u.has("gap"), "%s waves ult has waves / spacing / gap" % id)
		_ok(u.has("kills") and u.has("breaks") and u.has("charge"), "%s ult has kills / breaks / charge" % id)
	_ok(HeroKinds.phase() == 0, "heroes phase is 0 at H0 (got %d)" % HeroKinds.phase())
	# The kind names agree with WS-A's generated HeroData roster (when it is in the tree).
	if ResourceLoader.exists("res://scripts/core/hero_data.gd"):
		var roster: Dictionary = (load("res://scripts/core/hero_data.gd") as Script).get_script_constant_map().get("HEROES", {})
		for id: String in HeroKinds.KINDS:
			_ok(roster.has(id) and StringName(str(roster[id].get("ult", ""))) == HeroKinds.ult_kind(id),
					"%s ult kind matches HeroData (%s)" % [id, str((roster.get(id, {}) as Dictionary).get("ult", "?"))])


# ------------------------------------------------------------------ rule order on a mock view

class MockView extends KindView:
	var c := HeroKinds.Clock.new()
	var d := 10.0
	var pw := 1.2
	var log: PackedStringArray = PackedStringArray()
	var armor := 0.0

	func distance() -> float:
		return d

	func ult_power() -> float:
		return pw

	func clock() -> HeroKinds.Clock:
		return c

	func area_hit(d0: float, d1: float, kills: float, breaks: float, gates: bool) -> void:
		log.append("hit %.2f %.2f %.2f %.2f %s" % [d0, d1, kills, breaks, gates])

	func grant_armor(s: float) -> void:
		armor = s

	func fx(event: StringName, data := {}) -> void:
		if event == &"ult_wave":
			log.append("wave %d" % int(data["wave"]))
		elif event != &"ult_step":
			log.append(str(event))


func _run_mock(id: String, steps: int, dt: float) -> MockView:
	var v := MockView.new()
	var u: Dictionary = Balance.HEROES[id]["ult"]
	var kind := HeroKinds.ult_kind(id)
	HeroKinds.ult_cast(v, kind, u)
	for i in steps:
		if v.c.active():
			HeroKinds.ult_step(v, kind, u, dt)
	return v


func _count(log: PackedStringArray, prefix: String) -> int:
	var n := 0
	for l in log:
		if l.begins_with(prefix):
			n += 1
	return n


func _test_rules_order() -> void:
	print("== ult rules over a KindView")
	var b := _run_mock("bolt", 200, 1.0 / 60.0)
	var ub: Dictionary = Balance.HEROES["bolt"]["ult"]
	_ok(b.log[0] == "ult_cast", "storm: cast fx first")
	_ok(_count(b.log, "hit") == _count(b.log, "ult_tick_done") and _count(b.log, "hit") == b.log.count("ult_tick"), "storm: one pre / post fx per hit")
	var ticks := _count(b.log, "hit")
	var want := int(ceil(float(ub["duration"]) / float(ub["tick"])))
	_ok(absi(ticks - want) <= 1, "storm: %d ticks over %.1f s (about %d)" % [ticks, float(ub["duration"]), want])
	_ok(b.log[b.log.size() - 1] == "ult_end" and not b.c.active(), "storm: ends with ult_end, clock idle")
	_ok(b.log[2].begins_with("hit 9.50 %.2f %.2f %.2f true" % [10.0 + float(ub["range"]), float(ub["kills"]) * 1.2, float(ub["breaks"]) * 1.2]), "storm: hit band and Ult Rank power (%s)" % b.log[2])
	var t := _run_mock("titan", 200, 1.0 / 60.0)
	var ut: Dictionary = Balance.HEROES["titan"]["ult"]
	_ok(_count(t.log, "wave") == int(ut["waves"]) and _count(t.log, "hit") == int(ut["waves"]), "quake: %d bands" % int(ut["waves"]))
	_ok(t.log[t.log.size() - 1] == "ult_waves_end" and t.c.wave == 99, "quake: ends with ult_waves_end, clock idle")
	_ok(is_equal_approx(t.armor, float(ut["armor_time"])), "quake: grants the armour")
	_ok(t.log[1] == "wave 0" and t.log[2].ends_with("false"), "quake: band 0 first, bands never hit gates")
	var s := _run_mock("seer", 300, 1.0 / 60.0)
	var us: Dictionary = Balance.HEROES["seer"]["ult"]
	var sticks := _count(s.log, "hit")
	_ok(absi(sticks - int(float(us["duration"]) / float(us["tick"]))) <= 1, "rift: %d ticks" % sticks)
	_ok(is_zero_approx(s.armor) and is_zero_approx(b.armor), "timed ults grant no armour")


func _test_slow_and_fork() -> void:
	print("== slow and Forked Fox")
	var us: Dictionary = Balance.HEROES["seer"]["ult"]
	_ok(is_equal_approx(HeroKinds.hazard_slow(&"rift", us, 1.0), 1.0 - float(us["slow"])), "rift slows by ult.slow")
	_ok(HeroKinds.hazard_slow(&"rift", us, 0.0) == 1.0, "rift idle: no slow")
	_ok(HeroKinds.hazard_slow(&"storm", Balance.HEROES["bolt"]["ult"], 2.0) == 1.0, "storm never slows")
	_ok(HeroKinds.hazard_slow(&"quake", Balance.HEROES["titan"]["ult"], 2.0) == 1.0, "quake never slows")
	var forks := 0
	for n in range(1, 10):
		if HeroKinds.forks("forked_fox", n):
			forks += 1
	_ok(forks == 3 and HeroKinds.forks("forked_fox", 3) and not HeroKinds.forks("forked_fox", 4), "Forked Fox forks casts 3, 6, 9")
	_ok(not HeroKinds.forks("bulwark", 3) and not HeroKinds.forks("", 6), "other Aspects never fork")


# ------------------------------------------------------------------ LevelSim vs the Meta-1 rules

## Meta-1 (2.2.1) LevelSim.ult_worth, verbatim.
static func _old_worth(lv: LevelSim.Level, s: LevelSim.State) -> bool:
	if s.mode == LevelSim.Mode.CLASH or s.mode == LevelSim.Mode.SIEGE:
		return true
	var reach := float(((Balance.HEROES[s.hero] as Dictionary)["ult"] as Dictionary).get("range", 13.0)) if s.hero != "titan" else 13.0
	if s.hero == "titan" and s.army >= 25.0:
		var c := LevelSim.army_center_d(s)
		var lo_h := LevelSim._first_at(lv.d, lv.haz, c)
		if lo_h < lv.haz.size() and lv.d[lv.haz[lo_h]] < s.d + 6.0 and s.alive[lv.haz[lo_h]] == 1:
			return true
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
	return total >= maxf(8.0, s.army * 0.35)


## Meta-1 LevelSim.use_ult + _ult_step, verbatim (without the trace line).
static func _old_cast(s: LevelSim.State) -> void:
	var u: Dictionary = Balance.HEROES[s.hero]["ult"]
	s.ult = 0.0
	if u.has("duration"):
		s.ult_left = float(u["duration"])
		s.ult_tick = 0.25 if s.hero == "seer" else 0.0
	else:
		s.quake_d = s.d
		s.quake_wave = 0
		s.ult_tick = 0.43
		s.armor = float(u["armor_time"])


static func _old_step(lv: LevelSim.Level, s: LevelSim.State, dt: float) -> void:
	var u: Dictionary = Balance.HEROES[s.hero]["ult"]
	if s.ult_left > 0.0:
		s.ult_left -= dt
		s.ult_tick -= dt
		while s.ult_tick <= 0.0 and s.ult_left > -dt:
			s.ult_tick += float(u["tick"])
			LevelSim._ult_hit(lv, s, s.d - 0.5, s.d + float(u["range"]), float(u["kills"]) * s.ult_pow, float(u["breaks"]) * s.ult_pow, true)
		if s.ult_left <= 0.0:
			s.ult_left = 0.0
	elif s.quake_wave < 99:
		s.ult_tick -= dt
		var waves := int(u["waves"])
		var spacing := float(u["spacing"])
		while s.ult_tick <= 0.0 and s.quake_wave < waves:
			s.ult_tick += float(u["gap"])
			var near := s.quake_d + 1.0 + spacing * s.quake_wave
			LevelSim._ult_hit(lv, s, near - 0.5, near + spacing, float(u["kills"]) * s.ult_pow, float(u["breaks"]) * s.ult_pow, false)
			s.quake_wave += 1
		if s.quake_wave >= waves:
			s.quake_wave = 99


static func _old_slow(s: LevelSim.State) -> float:
	if s.ult_left > 0.0 and s.hero == "seer":
		return 1.0 - float(((Balance.HEROES["seer"] as Dictionary)["ult"] as Dictionary).get("slow", 0.0))
	return 1.0


## Field-by-field equality of the parts of a State the ult rules touch.
static func _same(a: LevelSim.State, b: LevelSim.State) -> bool:
	return a.ult == b.ult and a.ult_left == b.ult_left and a.ult_tick == b.ult_tick and a.quake_d == b.quake_d \
			and a.quake_wave == b.quake_wave and a.armor == b.armor and a.army == b.army and a.kills == b.kills \
			and a.alive == b.alive and a.hp == b.hp and a.val == b.val and a.val2 == b.val2 and a.rev == b.rev \
			and a.op == b.op and a.op2 == b.op2 and a.coins == b.coins and a.content == b.content


func _test_sim_golden() -> void:
	print("== LevelSim through HeroKinds == Meta-1 rules (sampled states)")
	var worth_n := 0
	var worth_bad := 0
	var cast_n := 0
	var cast_bad := 0
	var slow_bad := 0
	for level: int in [1, 3, 5, 8, 11, 14, 17, 20]:
		var def := LevelGen.build(level, Balance.START_ARMY)
		var lv := LevelSim.make_level(def, level)
		for hero: String in Balance.HERO_ORDER:
			var path := LevelSim.lazy_path()
			var s := LevelSim.start_state(lv, hero, 40, {"ult": false})
			var cap := float((Balance.HEROES[hero]["ult"] as Dictionary)["charge"])
			var k := 0
			while s.mode == LevelSim.Mode.RUN or s.mode == LevelSim.Mode.CLASH or s.mode == LevelSim.Mode.SIEGE:
				LevelSim.step(lv, s, path, LevelSim.DT)
				k += 1
				if s.t > 400.0:
					break
				if k % 7 != 0:
					continue
				worth_n += 1
				if LevelSim.ult_worth(lv, s) != _old_worth(lv, s):
					worth_bad += 1
				# Cast here on two copies and run the ult out with both rule sets.
				var a := s.copy()
				var b := s.copy()
				a.ult = cap
				b.ult = cap
				_old_cast(a)
				LevelSim.use_ult(lv, b)
				var ok := _same(a, b)
				for j in 120:
					_old_step(lv, a, LevelSim.DT)
					LevelSim._ult_step(lv, b, Balance.HEROES[hero], LevelSim.DT)
					if _old_slow(a) != LevelSim.hazard_slow(b):
						slow_bad += 1
					if not _same(a, b):
						ok = false
						break
				cast_n += 1
				if not ok:
					cast_bad += 1
	print("  sampled %d states, %d casts" % [worth_n, cast_n])
	_ok(worth_n > 500 and worth_bad == 0, "ult_worth identical on %d states (%d differ)" % [worth_n, worth_bad])
	_ok(cast_n > 500 and cast_bad == 0, "cast + 120 ult steps identical on %d states (%d differ)" % [cast_n, cast_bad])
	_ok(slow_bad == 0, "hazard_slow identical (%d differ)" % slow_bad)


# ------------------------------------------------------------------ champions API (H0: off)

func _test_champions_off() -> void:
	print("== champion slots API (phase < H2)")
	_ok(not HeroKinds.champions_live(), "champions are off")
	var team := [{"id": "mila", "class": "healer", "hp": 30.0}, {"id": "otto", "class": "guardian", "hp": 60.0}]
	_ok(ChampionKinds.assign_slots(team, 2).is_empty(), "no slots assigned while off")
	var ch := Champions.new()
	ch.setup({"team": {"champions": team, "slots": 2}}, 20)
	_ok(not ch.active() and ch.members.is_empty(), "Champions.setup keeps the run empty while off")
	ch.step(KindView.new(), 0.1)
	_ok(ch.members.is_empty(), "Champions.step is a no-op while empty")
	_ok(KindView.new().champions().is_empty() and not KindView.new().revive_champion(&"mila", 0.5), "KindView champion defaults are empty")
	# Slot geometry (§4.2 contract, r' = max(r, 0.6)).
	_ok(ChampionKinds.slot_offset(ChampionKinds.FRONT, 0.35).is_equal_approx(Vector2(0.0, -0.378)), "front slot at r' = 0.6")
	_ok(ChampionKinds.slot_offset(ChampionKinds.REAR, 2.0).is_equal_approx(Vector2(0.0, 1.38)), "rear slot at r = 2")
	_ok(ChampionKinds.slot_offset(ChampionKinds.LEFT, 1.0).is_equal_approx(Vector2(-0.55, 0.1)), "left slot")
	_ok(ChampionKinds.slot_offset(ChampionKinds.RIGHT, 1.0).is_equal_approx(Vector2(0.55, 0.1)), "right slot")
