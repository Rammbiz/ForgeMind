extends Node
## Headless unit tests of the KindView refactor (heroes design §10.4, phase H0): the kind table
## covers the starters, the shared ult rules (HeroKinds) drive a KindView in the right order,
## and LevelSim through HeroKinds is bit-identical to the Meta-1 inline rules (a verbatim copy
## of the 2.2.1 code lives below as the golden reference) on states sampled from real levels.
## The champion slots API stays empty while the phase flag is below H2.
## Phase H2 (champions in the run, §4.2, §4.3, §10.5; EconData.phase_override = 2, restored after):
## the ChampionKinds rules over a test-local FakeView (each class Action on its cooldown, tier
## upgrades, Block, Mend, the clash share accumulator, the absorb order, fallen = no aura, revive)
## and LevelSim with champions (SimKindView verbs, the hook table on hand-built levels, and phase 0 /
## no team = the old results).
##
## godot --headless --path . res://scenes/dev/test_kinds.tscn -- --autotest [--verbose]   Exit code = failures.
## --verbose also prints every passing check (with its measured numbers).

var _fails := 0
var _passes := 0
var _verbose := false


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_verbose = "--verbose" in OS.get_cmdline_user_args()
	_test_table()
	_test_rules_order()
	_test_slow_and_fork()
	_test_sim_golden()
	_test_champions_off()
	_test_champions_h2()
	print("TEST_KINDS %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
			float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		if _verbose:
			print("  ok ", what)
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


# ------------------------------------------------------------------ champions (H2: on)

## A test-local KindView: one army, hand-placed squads {id, d, x, n, hw} and hazards {id, d, x, kind,
## hp}; it logs hits [id, dmg, kind], statuses, soldiers added and fx events [event, data].
class FakeView extends KindView:
	var a := {"n": 100.0, "x": 0.0, "d": 0.0, "radius": 2.0, "reserves": 0.0, "revive_pool": 0.0}
	var fight := false
	var squads: Array = []
	var hazards: Array = []
	var hits: Array = []
	var statuses: Array = []
	var added := 0.0
	var events: Array = []

	func army() -> Dictionary:
		return a

	func in_fight() -> bool:
		return fight

	func squads_in(d0: float, d1: float, x0: float, x1: float) -> Array:
		var out: Array = []
		for sq: Dictionary in squads:
			var hw := float(sq.get("hw", 1.0))
			if float(sq["n"]) > 0.0 and float(sq["d"]) >= d0 and float(sq["d"]) <= d1 \
					and float(sq["x"]) + hw >= x0 and float(sq["x"]) - hw <= x1:
				out.append(sq.duplicate())
		return out

	func hazards_in(d0: float, d1: float) -> Array:
		var out: Array = []
		for h: Dictionary in hazards:
			if float(h["d"]) >= d0 and float(h["d"]) <= d1 and (str(h["kind"]) == "blade" or float(h["hp"]) > 0.0):
				out.append(h.duplicate())
		return out

	func hit(target_id: int, dmg: float, tags := {}) -> int:
		hits.append([target_id, dmg, tags.get("kind", &"")])
		for sq: Dictionary in squads:
			if int(sq["id"]) == target_id:
				var k := minf(dmg, float(sq["n"]))
				sq["n"] = float(sq["n"]) - k
				return int(k)
		for h: Dictionary in hazards:
			if int(h["id"]) == target_id:
				h["hp"] = float(h["hp"]) - dmg
		return 0

	func status(target_id: int, st: StringName, sec: float) -> void:
		statuses.append([target_id, st, sec])

	func add_soldiers(n: float, _cause: StringName) -> void:
		added += n
		a["n"] = float(a["n"]) + n

	func fx(event: StringName, data := {}) -> void:
		events.append([event, data])

	func count(event: StringName) -> int:
		var n := 0
		for e: Array in events:
			if e[0] == event:
				n += 1
		return n

	func hits_of(kind: StringName) -> Array:
		return hits.filter(func(h: Array) -> bool: return h[2] == kind)


## A team row (ChampionsMeta.stats shape) made into a member in `slot`.
static func _mem(id: String, cls: String, slot: StringName, tier: int, hp := 40.0, action := 3.0, aura := 0.1,
		el := "kinetic") -> Dictionary:
	return ChampionKinds.member({"id": id, "class": cls, "element": el, "tier": tier, "mult": 1.0, "hp": hp,
			"action": action, "aura": aura, "radius": 1.0}, slot)


## Steps `members` for `secs` seconds in `dt` steps.
static func _run_for(v: FakeView, members: Array, secs: float, dt := 0.05) -> void:
	for i in int(round(secs / dt)):
		ChampionKinds.step(v, members, dt)


func _test_champions_h2() -> void:
	var old := EconData.phase_override
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	print("== champions in the run (phase H2 forced: %d)" % EconData.heroes_phase())
	_ok(HeroKinds.champions_live(), "champions are live under the override")
	_test_champ_actions()
	_test_champ_block_mend()
	_test_champ_clash()
	_test_champ_auras()
	_test_sim_view()
	_test_sim_champions()
	EconData.phase_override = old
	_ok(EconData.phase_override == old and HeroKinds.phase() == 0, "phase override restored")


func _test_champ_actions() -> void:
	print("== champion Actions (class templates, tiers)")
	# Warrior (front): the blob centre at d 0, r 2 -> the front slot sits 1.26 ahead.
	var v := FakeView.new()
	var w := _mem("borko", "warrior", ChampionKinds.FRONT, 1)
	var ms := [w]
	v.squads = [{"id": 1, "d": 1.26 + 2.5, "x": 0.0, "n": 50.0}, {"id": 2, "d": 1.26 + 3.5, "x": 0.0, "n": 50.0}]
	ChampionKinds.step(v, ms, 0.05)
	_ok(is_equal_approx(float(w["d"]), 1.26) and is_zero_approx(float(w["x"])), "front slot placed off the blob centre")
	_ok(v.hits.size() == 1 and int(v.hits[0][0]) == 1 and is_equal_approx(float(v.hits[0][1]), 3.0)
			and v.hits[0][2] == &"leap", "warrior leaps at the nearest squad <= 3 u: 3 kills (%s)" % str(v.hits))
	_ok(v.count(&"champ_leap") == 1 and is_equal_approx(float(w["cd"]), 5.0), "leap fx and the 5 s cooldown")
	_run_for(v, ms, 4.9)
	_ok(v.count(&"champ_leap") == 1, "no leap while cooling down")
	_run_for(v, ms, 0.2)
	_ok(v.count(&"champ_leap") == 2, "leaps again after 5 s")
	var v2 := FakeView.new()
	v2.fight = true
	v2.squads = [{"id": 1, "d": 2.0, "x": 0.0, "n": 50.0}]
	_run_for(v2, [_mem("borko", "warrior", ChampionKinds.FRONT, 1)], 1.0)
	_ok(v2.hits.is_empty(), "no leap during a clash")
	var v3 := FakeView.new()
	v3.squads = [{"id": 2, "d": 1.26 + 3.5, "x": 0.0, "n": 50.0}]
	ChampionKinds.step(v3, [_mem("borko", "warrior", ChampionKinds.FRONT, 2)], 0.05)
	_ok(v3.hits.size() == 1 and is_equal_approx(float(v3.hits[0][1]), 4.0), "tier II: leap range 4 u, 4 kills")
	_ok(v3.statuses.is_empty(), "tier II leap applies no status")
	var w4 := _mem("borko", "warrior", ChampionKinds.FRONT, 4)
	var v4 := FakeView.new()
	v4.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 50.0}]
	ChampionKinds.step(v4, [w4], 0.05)
	_ok(v4.statuses.size() == 1 and is_equal_approx(float(w4["cd"]), 4.0), "tier III+ leap applies the status, tier IV cd 4 s")
	# Ranger (rear, 1.38 behind the centre): every 1.2 s at the nearest hostile <= 14 u.
	for tier: int in [1, 2, 4]:
		var vr := FakeView.new()
		vr.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 999.0}]
		_run_for(vr, [_mem("alba", "ranger", ChampionKinds.REAR, tier, 26.0, 1.0)], 12.0)
		var shots := 0
		var arrows := 0
		var every3 := true
		for ev: Array in vr.events:
			if ev[0] != &"champ_shot":
				continue
			shots += 1
			var n := int((ev[1] as Dictionary)["arrows"])
			arrows += n
			if n != (2 if tier >= 2 and shots % 3 == 0 else 1):
				every3 = false
		_ok(shots >= 9 and shots <= 11, "ranger tier %d: a shot every 1.2 s (%d in 12 s)" % [tier, shots])
		_ok(every3 and vr.hits_of(&"shot").size() == arrows, "ranger tier %d: %s (%d arrows, %d shots)" % [tier,
				"+1 arrow every 3rd shot" if tier >= 2 else "one arrow per shot", arrows, shots])
	var vb := FakeView.new()
	vb.hazards = [{"id": 9, "d": 3.0, "x": 0.0, "kind": &"blade", "hp": 0.0}]
	var rb := _mem("alba", "ranger", ChampionKinds.REAR, 1, 26.0, 1.0)
	_run_for(vb, [rb], 2.0)
	_ok(vb.hits.is_empty(), "ranger never shoots blades")
	vb.hazards.append({"id": 10, "d": 6.0, "x": 0.0, "kind": &"barricade", "hp": 20.0})
	_run_for(vb, [rb], 1.3)
	_ok(not vb.hits.is_empty() and int(vb.hits[0][0]) == 10, "ranger shoots a barricade ahead")
	var vp := FakeView.new()
	vp.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 999.0}, {"id": 2, "d": 4.0, "x": 0.0, "n": 999.0},
			{"id": 3, "d": 5.0, "x": 0.0, "n": 999.0}]
	_run_for(vp, [_mem("alba", "ranger", ChampionKinds.REAR, 4, 26.0, 1.0)], 6.0)
	var pierced := 0
	for ev3: Array in vp.events:
		if ev3[0] == &"champ_shot" and int((ev3[1] as Dictionary)["pierce"]) == 3:
			pierced += 1
	_ok(pierced == 1, "ranger tier IV: the 5th shot pierces 3 (%d pierced in 6 s)" % pierced)
	# Mage (rear): every 4 s an area hit on the densest squad; two squads 1.8 u apart, a barricade between.
	for tier: int in [1, 2, 3, 4]:
		var vm := FakeView.new()
		vm.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 999.0}, {"id": 2, "d": 6.8, "x": 0.0, "n": 999.0}]
		vm.hazards = [{"id": 7, "d": 5.5, "x": 0.0, "kind": &"barricade", "hp": 99.0}]
		var mg := _mem("taya", "mage", ChampionKinds.REAR, tier, 26.0, 4.0, 0.15, "rune")
		ChampionKinds.step(vm, [mg], 0.05)
		var spell_squads := 0
		var struct_dmg := 0.0
		for h: Array in vm.hits_of(&"spell"):
			if int(h[0]) == 7:
				struct_dmg = float(h[1])
			else:
				spell_squads += 1
		var ev_spell: Array = vm.events[0] if not vm.events.is_empty() else [&"", {"r": 0.0}]
		var want_r := 2.0 if tier >= 2 else 1.5
		_ok(ev_spell[0] == &"champ_spell" and is_equal_approx(float((ev_spell[1] as Dictionary)["r"]), want_r),
				"mage tier %d: spell radius %.1f" % [tier, want_r])
		_ok(spell_squads == (2 if tier >= 2 else 1), "mage tier %d: hits %d squad(s) of a pair 1.8 u apart" % [tier, spell_squads])
		_ok(is_equal_approx(struct_dmg, 4.0 * (1.5 if tier >= 3 else 1.0)), "mage tier %d: structures x%s" % [tier,
				"1.5" if tier >= 3 else "1"])
		_ok(vm.statuses.size() == spell_squads, "mage tier %d: the spell applies the element status" % tier)
		_ok(is_equal_approx(float(mg["cd"]), 3.5 if tier >= 4 else 4.0), "mage tier %d: cooldown" % tier)
		_run_for(vm, [mg], 2.5)
		var field := vm.hits_of(&"field").size()
		if tier >= 4:
			_ok(field >= 6 and field <= 10, "mage tier IV: the 2 s field keeps killing (%d field hits)" % field)
		else:
			_ok(field == 0, "mage tier %d: no field" % tier)
	var vm2 := FakeView.new()
	vm2.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 999.0}]
	_run_for(vm2, [_mem("taya", "mage", ChampionKinds.REAR, 1, 26.0, 4.0)], 12.0)
	_ok(vm2.count(&"champ_spell") == 3, "mage: a spell every 4 s (%d in 12 s)" % vm2.count(&"champ_spell"))


func _test_champ_block_mend() -> void:
	print("== Guardian Block and Healer Mend")
	var v := FakeView.new()
	var g := _mem("ivo", "guardian", ChampionKinds.FRONT, 1, 60.0, 3.0)
	var ms := [g]
	var left := ChampionKinds.absorb_hazard(v, ms, 7, &"blade", 10.0, 100.0, 2.0)
	_ok(is_equal_approx(left, 6.0), "tier I Block spares at most 4 (10 -> %.2f)" % left)
	_ok(int(g["blocks"]) == 1 and is_equal_approx(float(g["cd"]), 5.0) and v.count(&"champ_block") == 1,
			"a Block starts the 5 s cooldown")
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(v, ms, 7, &"blade", 10.0, 100.0, 2.0), 10.0), "a used-up Block spares no more")
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(v, ms, 8, &"blade", 10.0, 100.0, 2.0), 10.0), "no Block while cooling down")
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(v, ms, 9, &"turret", 5.0, 100.0, 2.0), 5.0) and int(g["blocks"]) == 1,
			"turrets are never Blocked")
	_run_for(v, ms, 5.05)
	_ok(float(g["cd"]) == 0.0, "the cooldown runs out in step()")
	var l2 := ChampionKinds.absorb_hazard(v, ms, 11, &"barricade", 2.0, 100.0, 2.0)
	var l3 := ChampionKinds.absorb_hazard(v, ms, 11, &"barricade", 3.0, 100.0, 2.0)
	_ok(is_zero_approx(l2) and is_equal_approx(l3, 1.0),
			"the Block's share carries over the same barricade (%.1f, %.1f)" % [l2, l3])
	var bh := v.hits_of(&"block")
	_ok(bh.size() == 1 and int(bh[0][0]) == 11 and is_equal_approx(float(bh[0][1]), 3.0),
			"a blocked barricade takes the Block's damage")
	var l4 := ChampionKinds.absorb_hazard(FakeView.new(), [_mem("ivo", "guardian", ChampionKinds.FRONT, 2, 60.0)], 1, &"blade",
			20.0, 100.0, 2.0)
	_ok(is_equal_approx(l4, 20.0 - 4.0 * 1.96), "tier II block radius 1.4: cap 7.84 (20 -> %.2f)" % l4)
	var g3 := _mem("ivo", "guardian", ChampionKinds.FRONT, 1, 60.0, 3.0)
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(FakeView.new(), [g3], 1, &"blade", 3.0, 2.0, 0.5), 1.0),
			"a small blob: the Block spares what stands inside its circle (2 of 3)")
	var g4 := _mem("ivo", "guardian", ChampionKinds.FRONT, 4, 60.0, 3.0)
	var v4 := FakeView.new()
	ChampionKinds.absorb_hazard(v4, [g4], 3, &"barricade", 2.0, 100.0, 2.0)
	_ok(is_equal_approx(float(v4.hits_of(&"block")[0][1]), 8.0), "tier IV: the blocked barricade takes 3 + 5")
	_ok(ChampionKinds.tick_free([g4]) and not ChampionKinds.tick_free([g4]), "tier III+: one free clash tick after a Block")
	_ok(not ChampionKinds.tick_free([g3]), "tier I: no shield after a Block")
	var v5 := FakeView.new()
	v5.squads = [{"id": 4, "d": 1.26 + 3.0, "x": 0.0, "n": 20.0}]
	var g5 := _mem("ivo", "guardian", ChampionKinds.FRONT, 1, 60.0, 1.0)
	ChampionKinds.step(v5, [g5], 0.05)
	ChampionKinds.absorb_hazard(v5, [g5], 99, &"blade", 4.0, 100.0, 2.0)
	_ok(v5.hits_of(&"block").size() == 1 and int(v5.hits_of(&"block")[0][0]) == 4, "a blade Block kills on the squad behind it")
	# Healer: 30% of the losses feed the pool (cap 30 x mult per level); a pulse every 3 s returns 3.
	var vh := FakeView.new()
	var h := _mem("mila", "healer", ChampionKinds.LEFT, 1, 30.0, 3.0, 0.12, "tech")
	var hs := [h]
	ChampionKinds.feed(hs, 50.0)
	_ok(is_equal_approx(float(h["pool"]), 15.0), "feed: 30% of the soldiers lost")
	ChampionKinds.feed(hs, 200.0)
	_ok(is_equal_approx(float(h["pool"]), 30.0) and is_equal_approx(float(h["fed"]), 30.0), "the pool caps at 30 per level")
	_run_for(vh, hs, 3.05)
	_ok(vh.count(&"champ_mend") == 1 and is_equal_approx(vh.added, 3.0), "a pulse every 3 s returns 3 (%.1f)" % vh.added)
	_ok(vh.count(&"champ_mend") == 1 and not bool((vh.events[0][1] as Dictionary)["front"]), "tier I returns land in the blob")
	_run_for(vh, hs, 40.0)
	_ok(is_equal_approx(vh.added, 30.0) and is_zero_approx(float(h["pool"])) and is_equal_approx(float(h["heals"]), 30.0),
			"the pool empties in pulses (%.1f returned)" % vh.added)
	ChampionKinds.feed(hs, 100.0)
	_ok(is_zero_approx(float(h["pool"])), "what was fed counts against the cap after it is spent")
	var h2 := _mem("mila", "healer", ChampionKinds.LEFT, 2, 30.0, 3.0)
	var vh2 := FakeView.new()
	ChampionKinds.feed([h2], 100.0)
	_run_for(vh2, [h2], 3.05)
	_ok(is_equal_approx(vh2.added, 4.0) and vh2.count(&"champ_mend") == 1 and bool((vh2.events[0][1] as Dictionary)["front"]),
			"tier II: +1 per pulse, at the blob front")
	var h4 := _mem("mila", "healer", ChampionKinds.LEFT, 4, 30.0, 3.0)
	ChampionKinds.feed([h4], 1000.0)
	_ok(is_equal_approx(float(h4["pool_cap"]), 45.0) and is_equal_approx(float(h4["pool"]), 45.0), "tier IV: pool cap +50%")
	var vh4 := FakeView.new()
	_run_for(vh4, [h4], 6.05)
	_ok(vh4.count(&"champ_mend") == 3, "tier IV: a pulse every 2 s (%d in 6 s)" % vh4.count(&"champ_mend"))
	var vh0 := FakeView.new()
	vh0.a["n"] = 0.0
	var h0 := _mem("mila", "healer", ChampionKinds.LEFT, 1, 30.0, 3.0)
	ChampionKinds.feed([h0], 20.0)
	_run_for(vh0, [h0], 4.0)
	_ok(is_zero_approx(vh0.added) and is_equal_approx(float(h0["pool"]), 6.0), "no returns to an empty army (the pool waits)")
	var h3 := _mem("mila", "healer", ChampionKinds.LEFT, 3, 30.0, 3.0)
	var f3 := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0)
	f3["hp"] = 10.0
	var vh3 := FakeView.new()
	_run_for(vh3, [f3, h3], 15.05)
	_ok(is_equal_approx(float(f3["hp"]), 14.8) and vh3.count(&"champ_heal") == 1,
			"tier III: every 15 s the front heals 10%% of max (hp %.1f)" % float(f3["hp"]))


func _test_champ_clash() -> void:
	print("== clash share, absorb order, revive, Cleave")
	var v := FakeView.new()
	var w := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0)
	var ms := [w]
	var hps: Array = []
	for i in 4:
		ChampionKinds.clash_hit(v, ms, 3.0, false)
		hps.append(float(w["hp"]))
	_ok(hps == [48.0, 47.0, 46.0, 45.0] and is_zero_approx(float(w["acc"])),
			"front share 0.25 x 3 per tick, floor() carried (%s)" % str(hps))
	var w2 := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0)
	for i in 8:
		ChampionKinds.clash_hit(v, [w2], 3.0, true)
	_ok(is_equal_approx(float(w2["hp"]), 45.0) and is_equal_approx(float(w2["dmg_taken"]), 3.0),
			"x0.5 with a Guardian hero (8 ticks = 3 HP)")
	var rear := _mem("alba", "ranger", ChampionKinds.REAR, 1, 26.0, 1.0)
	ChampionKinds.clash_hit(v, [rear], 30.0, false)
	_ok(is_equal_approx(float(rear["hp"]), 26.0), "only the front takes the clash share")
	var w3 := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 2.0)
	var v3 := FakeView.new()
	ChampionKinds.clash_hit(v3, [w3], 20.0, false)
	_ok(not bool(w3["alive"]) and is_zero_approx(float(w3["hp"])) and v3.count(&"champ_down") == 1,
			"a front at 0 HP falls (fx champ_down)")
	ChampionKinds.clash_hit(v3, [w3], 20.0, false)
	_ok(v3.count(&"champ_hit") == 1, "a fallen front takes nothing more")
	# Army 0: the living champions take the whole tick, front -> left -> right -> rear, then the hero.
	var team := [_mem("alba", "ranger", ChampionKinds.REAR, 1, 5.0), _mem("olena", "healer", ChampionKinds.RIGHT, 1, 5.0),
			_mem("mila", "healer", ChampionKinds.LEFT, 1, 5.0), _mem("ivo", "guardian", ChampionKinds.FRONT, 1, 5.0)]
	var va := FakeView.new()
	var took := 0
	while took < 10 and ChampionKinds.absorb_tick(va, team, 5.0):
		took += 1
	var order: Array = []
	for e: Array in va.events:
		if e[0] == &"champ_down":
			order.append(str((e[1] as Dictionary)["slot"]))
	_ok(took == 4 and order == ["front", "left", "right", "rear"], "absorb order front -> left -> right -> rear (%s)" % str(order))
	_ok(not ChampionKinds.absorb_tick(va, team, 5.0), "nobody left: the hero takes the tick")
	# Revive (a Healer hero): back at hp_frac of max, once.
	var vr := FakeView.new()
	_ok(ChampionKinds.revive(vr, team, "ivo", 0.5) and bool(team[3]["alive"]) and is_equal_approx(float(team[3]["hp"]), 2.5),
			"revive: back at 50% HP")
	_ok(vr.count(&"champ_revive") == 1 and not ChampionKinds.revive(vr, team, "ivo", 0.5),
			"revive: fx once, never a living champion")
	_ok(not ChampionKinds.revive(vr, team, "nobody", 0.5), "revive: unknown id")
	_ok(ChampionKinds.absorb_tick(vr, team, 1.0) and is_equal_approx(float(team[3]["hp"]), 1.5), "the revived front absorbs again")
	var rep := ChampionKinds.report(team)
	_ok(rep.size() == 4 and rep[3]["id"] == "ivo" and bool(rep[3]["alive"]) and int(rep[3]["dmg_taken"]) == 6,
			"report rows {id, alive, kills, heals, blocks, dmg_taken} (%s)" % str(rep[3]))
	# Cleave: 0.07 x mult kills per tick, fractions carry; tier III doubles it.
	var wc := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0)
	var wc3 := _mem("borko", "warrior", ChampionKinds.FRONT, 3, 48.0)
	var total := 0.0
	var total3 := 0.0
	for i in 100:
		total += ChampionKinds.cleave([wc])
		total3 += ChampionKinds.cleave([wc3])
	_ok(total >= 6.0 and total <= 7.0, "cleave: 0.07 per tick (%.0f kills in 100 ticks)" % total)
	_ok(total3 >= 13.0 and total3 <= 14.0, "cleave tier III: x2 (%.0f kills in 100 ticks)" % total3)


func _test_champ_auras() -> void:
	print("== auras: living members only")
	var w := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0, 3.0, 0.1)
	var g := _mem("ivo", "guardian", ChampionKinds.FRONT, 1, 60.0, 3.0, 0.1)
	var h := _mem("mila", "healer", ChampionKinds.LEFT, 1, 30.0, 3.0, 0.12)
	var r := _mem("alba", "ranger", ChampionKinds.REAR, 1, 26.0, 1.0, 0.15)
	var m := _mem("taya", "mage", ChampionKinds.RIGHT, 1, 26.0, 4.0, 0.15, "rune")
	var all := [w, g, h, r, m]
	_ok(is_equal_approx(ChampionKinds.clash_kill_mult(all), 1.035), "Warrior aura x the slot share (front 0.35)")
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult(all), 0.965), "Guardian aura: clash losses -3.5%")
	_ok(is_equal_approx(ChampionKinds.hazard_loss_mult(all), 0.964), "Healer aura (left 0.30): hazard losses -3.6%")
	_ok(is_equal_approx(ChampionKinds.volley_mult(all), 1.0375), "Ranger aura (rear 0.25): volleys +3.75%")
	var vs := ChampionKinds.volley_status(all)
	_ok(vs.size() == 1 and str(vs[0]["status"]) == "seal" and is_equal_approx(float(vs[0]["proc"]), 0.045),
			"Mage aura: the element status proc (%s)" % str(vs))
	var big := _mem("borko", "warrior", ChampionKinds.FRONT, 1, 48.0, 3.0, 0.9)
	_ok(is_equal_approx(ChampionKinds.clash_kill_mult([big]), 1.0 + 0.4 * 0.35), "aura value capped at AURA_CAP")
	for x: Dictionary in all:
		x["alive"] = false
		x["hp"] = 0.0
	_ok(ChampionKinds.clash_kill_mult(all) == 1.0 and ChampionKinds.clash_loss_mult(all) == 1.0
			and ChampionKinds.hazard_loss_mult(all) == 1.0 and ChampionKinds.volley_mult(all) == 1.0
			and ChampionKinds.volley_status(all).is_empty(), "fallen members add no aura")
	_ok(ChampionKinds.cleave(all) == 0.0, "a fallen warrior cleaves nothing")
	ChampionKinds.feed(all, 100.0)
	_ok(is_zero_approx(float(h["pool"])), "a fallen healer's pool is not fed")
	var v := FakeView.new()
	v.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 50.0}]
	_run_for(v, all, 10.0)
	_ok(v.events.is_empty() and v.hits.is_empty(), "fallen members take no Action")
	g["shield"] = 1.0
	_ok(not ChampionKinds.tick_free(all) and not ChampionKinds.absorb_tick(v, all, 1.0), "no shield, no absorb from the fallen")
	var ch := Champions.new()
	ch.setup({"team": {"hero": "titan", "champions": [{"id": "otto", "class": "guardian", "hp": 60.0, "slot": "front"},
			{"id": "mila", "class": "healer", "hp": 30.0, "slot": "left"}]}}, 20)
	_ok(ch.active() and ch.members.size() == 2 and ch.guardian_hero == (str(HeroData.HEROES["titan"]["class"]) == "guardian"),
			"Champions.setup reads the team block when live")
	var cp := ch.copy()
	(cp.members[0] as Dictionary)["hp"] = 1.0
	_ok(float((ch.members[0] as Dictionary)["hp"]) == 60.0, "Champions.copy is deep")


# ------------------------------------------------------------------ LevelSim with champions

const _BRIDGE := 7.0


## A short hand-built level: `items` + a 1-hp fortress at `fort` and its stairs, sorted by d.
static func _level(items: Array, fort := 70.0) -> LevelSim.Level:
	var all := items.duplicate()
	all.append({"kind": "fortress", "x": 0.0, "d": fort, "value": 1})
	all.append({"kind": "stairs", "x": 0.0, "d": fort + 6.0, "steps": []})
	all.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	return LevelSim.level_from_items(all, 1, fort + 6.0)


## The reference profile of L1 with a team block of `rows` (ChampionsMeta.stats shape), led by `hero`.
static func _prof(rows: Array, hero := "bolt") -> Dictionary:
	var p := LevelSim.reference_profile(1).duplicate()
	if not rows.is_empty():
		p["team"] = {"hero": hero, "champions": rows, "synergy": {}, "synergy_ids": []}
	return p


static func _row(id: String, cls: String, slot: String, hp := 40.0, action := 3.0, aura := 0.1) -> Dictionary:
	var el := str((ChampionData.CHAMPIONS.get(id, {}) as Dictionary).get("element", "kinetic"))
	return {"id": id, "class": cls, "element": el, "tier": 1, "mult": 1.0, "hp": hp, "action": action, "aura": aura,
			"radius": 1.0, "slot": slot, "aura_effect": aura * float(ChampionData.AURA_SHARE.get(slot, 0.0))}


func _test_sim_view() -> void:
	print("== SimKindView verbs over LevelSim")
	var lv := _level([{"kind": "squad", "d": 10.0, "x": 1.0, "value": 12, "w": 2.0},
			{"kind": "squad", "d": 30.0, "x": -2.0, "value": 8, "w": 1.0},
			{"kind": "barricade", "d": 20.0, "x": 0.0, "value": 9, "w": 2.0},
			{"kind": "blade", "type": "rotor", "x": 0.0, "d": 25.0, "len": 1.6, "speed": 2.5, "phase": 0.0},
			{"kind": "turret", "d": 40.0, "x": 2.0, "value": 3, "range": 7.0, "rate": 2.0}])
	var s := LevelSim.start_state(lv, "bolt", 30, {"profile": _prof([_row("borko", "warrior", "front")])})
	var v := SimKindView.new(lv, s)
	_ok(s.champs.active() and v.champions().size() == 1, "the State carries the run's champions")
	var sq := v.squads_in(0.0, 50.0, -0.5, 0.5)
	_ok(sq.size() == 1 and int(sq[0]["id"]) == 0 and is_equal_approx(float(sq[0]["n"]), 12.0),
			"squads_in: span overlap in x, n = hp (%s)" % str(sq))
	_ok(v.squads_in(0.0, 50.0, -3.0, 3.0).size() == 2 and v.squads_in(11.0, 50.0, -3.0, 3.0).size() == 1, "squads_in: the d window")
	var kinds: Array = []
	for h: Dictionary in v.hazards_in(0.0, 50.0):
		kinds.append(str(h["kind"]))
	kinds.sort()
	_ok(kinds == ["barricade", "blade", "turret"], "hazards_in: barricade, blade and turret (%s)" % str(kinds))
	var got := v.hit(0, 2.5, {"src": "borko"})
	_ok(got == 2 and is_equal_approx(s.hp[0], 9.5) and is_equal_approx(s.kills, 2.5),
			"hit: whole soldiers removed (12 shown -> 10 = 2)")
	_ok(v.hit(0, 100.0) == 10 and s.alive[0] == 0 and v.squads_in(0.0, 50.0, -3.0, 3.0).size() == 1, "hit: a squad wiped out")
	var bi := -1
	for i in lv.items.size():
		if str(lv.items[i]["kind"]) == "barricade":
			bi = i
	_ok(v.hit(bi, 4.0) == 0 and is_equal_approx(s.hp[bi], 5.0), "hit on a structure: damage, no kills")
	var a0 := s.army
	v.add_soldiers(3.0, &"mend")
	_ok(is_equal_approx(s.army, a0 + 3.0) and s.peak >= s.army, "add_soldiers: army and peak")
	v.fx(&"champ_block", {})
	v.fx(&"champ_block", {})
	_ok(int(s.champ_fx.get(&"champ_block", 0)) == 2 and v.fx_count == 2, "fx: counted per event")
	var c := s.copy()
	(c.champs.members[0] as Dictionary)["hp"] = 1.0
	c.champ_fx[&"champ_block"] = 9
	_ok(float((s.champs.members[0] as Dictionary)["hp"]) == 40.0 and int(s.champ_fx[&"champ_block"]) == 2,
			"State.copy deep-copies the champions and their fx counts")


func _test_sim_champions() -> void:
	print("== LevelSim: the hook table on hand-built levels")
	var path := LevelSim.lazy_path()
	# A front Warrior takes the clash share and can fall.
	var lv := _level([{"kind": "squad", "d": 15.0, "x": 0.0, "value": 400, "w": 3.0}])
	var s := LevelSim.simulate(lv, "bolt", 40, path, {"profile": _prof([_row("borko", "warrior", "front", 6.0)])})
	var rep: Array = LevelSim.result(lv, s).get("team_report", [])
	_ok(rep.size() == 1 and not bool(rep[0]["alive"]) and int(rep[0]["dmg_taken"]) == 6,
			"a front Warrior falls in a big clash (%s)" % str(rep))
	_ok(int(s.champ_fx.get(&"champ_down", 0)) == 1, "one champ_down fx")
	var lv2 := _level([{"kind": "squad", "d": 15.0, "x": 0.0, "value": 30, "w": 3.0}])
	var r_t := LevelSim.run_path(lv2, "bolt", 60, path, {"profile": _prof([_row("borko", "warrior", "front", 500.0)])})
	var r_0 := LevelSim.run_path(lv2, "bolt", 60, path, {"profile": _prof([])})
	var rep2: Array = r_t.get("team_report", [])
	_ok(rep2.size() == 1 and bool(rep2[0]["alive"]) and int(rep2[0]["dmg_taken"]) > 0,
			"the front takes clash damage (%s)" % str(rep2))
	_ok(int(r_t["clash_deaths"]) <= int(r_0["clash_deaths"]), "Warrior aura + Cleave: no more clash losses (%d vs %d)" % [
			int(r_t["clash_deaths"]), int(r_0["clash_deaths"])])
	_ok(not r_0.has("team_report"), "no team: no team_report")
	# Army 0 in a clash: the champion takes the ticks; the hero is untouched while it stands.
	var lv3 := _level([{"kind": "squad", "d": 15.0, "x": 0.0, "value": 60, "w": 3.0}])
	var s3 := LevelSim.simulate(lv3, "bolt", 5, path, {"profile": _prof([_row("ivo", "guardian", "front", 400.0)])})
	var s3b := LevelSim.simulate(lv3, "bolt", 5, path, {"profile": _prof([])})
	_ok(s3.hero_hp > s3b.hero_hp and float((s3.champs.members[0] as Dictionary)["dmg_taken"]) > 5.0,
			"army 0: the champion absorbs the clash ticks before the hero (hero %.0f vs %.0f)" % [s3.hero_hp, s3b.hero_hp])
	# A Healer returns soldiers (Mend from the losses at a full-width barricade).
	var lv4 := _level([{"kind": "barricade", "d": 12.0, "x": 0.0, "value": 30, "w": _BRIDGE}], 90.0)
	var s4 := LevelSim.simulate(lv4, "bolt", 60, path, {"profile": _prof([_row("mila", "healer", "left", 30.0, 3.0, 0.12)])})
	var s4b := LevelSim.simulate(lv4, "bolt", 60, path, {"profile": _prof([])})
	var heals := float((s4.champs.members[0] as Dictionary)["heals"])
	_ok(heals >= 3.0 and int(s4.champ_fx.get(&"champ_mend", 0)) >= 1, "a Healer returns soldiers (%.0f in %d pulses)" % [heals,
			int(s4.champ_fx.get(&"champ_mend", 0))])
	_ok(s4.army_at_fortress >= s4b.army_at_fortress + heals - 0.001, "the returns reach the fortress (%.1f vs %.1f)" % [
			s4.army_at_fortress, s4b.army_at_fortress])
	_ok(s4.hazard_deaths <= s4b.hazard_deaths, "Healer aura: no more hazard losses (%.1f vs %.1f)" % [
			s4.hazard_deaths, s4b.hazard_deaths])
	# A Guardian lowers hazard losses (Blocks on two barricades 12 s apart and a rotor between).
	var lv5 := _level([{"kind": "barricade", "d": 12.0, "x": 0.0, "value": 25, "w": _BRIDGE},
			{"kind": "blade", "type": "rotor", "x": 0.0, "d": 50.0, "len": 2.5, "speed": 3.0, "phase": 0.0},
			{"kind": "barricade", "d": 95.0, "x": 0.0, "value": 25, "w": _BRIDGE}], 130.0)
	var s5 := LevelSim.simulate(lv5, "bolt", 60, path, {"profile": _prof([_row("ivo", "guardian", "front", 60.0)])})
	var s5b := LevelSim.simulate(lv5, "bolt", 60, path, {"profile": _prof([])})
	var blocks := int((s5.champs.members[0] as Dictionary)["blocks"])
	_ok(blocks >= 2 and s5.hazard_deaths < s5b.hazard_deaths, "a Guardian lowers hazard losses (%.1f vs %.1f, %d Blocks)" % [
			s5.hazard_deaths, s5b.hazard_deaths, blocks])
	_ok(int(s5.champ_fx.get(&"champ_block", 0)) == blocks, "one champ_block fx per Block")
	# Phase 0 with a team block, or phase 2 without one: the old result, bit for bit.
	var same := 0
	var cases := 0
	for level: int in [3, 9, 14, 21]:
		var lvx := LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY), level)
		var base := LevelSim.reference_profile(level)
		var teamed := base.duplicate()
		teamed["team"] = {"hero": "titan", "champions": [_row("otto", "guardian", "front", 60.0),
				_row("mila", "healer", "left", 30.0, 3.0, 0.12)], "synergy": {}, "synergy_ids": []}
		for hero: String in ["bolt", "titan"]:
			EconData.phase_override = 0
			var a := LevelSim.simulate(lvx, hero, 40, path, {"profile": teamed})
			var b := LevelSim.simulate(lvx, hero, 40, path, {"profile": base})
			EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
			var c := LevelSim.simulate(lvx, hero, 40, path, {"profile": base})
			var ra := LevelSim.result(lvx, a)
			cases += 1
			if ra == LevelSim.result(lvx, b) and ra == LevelSim.result(lvx, c) and not ra.has("team_report") \
					and a.hp == b.hp and a.hp == c.hp and a.alive == c.alive and a.t == c.t and a.army == c.army \
					and a.champ_fx.is_empty() and not a.champs.active():
				same += 1
	_ok(cases == 8 and same == cases, "phase 0 with a team / phase 2 without one = the old result (%d of %d)" % [same, cases])
	EconData.phase_override = 0
	var lv6 := LevelSim.make_level(LevelGen.build(6, Balance.START_ARMY), 6)
	var bp_a: Dictionary = LevelSim.best_path(lv6, "bolt", 40, {"profile": _prof([_row("otto", "guardian", "front")])})
	var bp_b: Dictionary = LevelSim.best_path(lv6, "bolt", 40, {"profile": _prof([])})
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	_ok(bp_a["result"] == bp_b["result"] and bp_a["path"] == bp_b["path"],
			"phase 0: the planner's path and result ignore a team block")
