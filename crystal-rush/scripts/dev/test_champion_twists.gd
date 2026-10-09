extends Node
## Headless tests of the champion twists (heroes design §4.3, §6.11-6.27, §10.5; phase H2 forced
## through EconData.phase_override and restored after):
## - every TWISTS row fires through ChampionKinds over a test-local view (TwistView: it logs hits,
##   statuses, holds, groundings, soldiers added and fx), and a stats row with `twist: {}` runs the
##   bare class template;
## - Німб's tier IV turret catch (ChampionKinds.absorb_turret; LevelSim._turrets on a hand-built level);
## - phase 0 with a team block / phase 2 without one = the old LevelSim result, bit for bit;
## - the budget table (§4.1, §4.3: every kit at KIT_INDEX = P0_c +- 3%): each champion's kit value in
##   LevelSim against its bare class template of the same gem, tier and slot. Per level of a fixed
##   spread: the EXPECTED synthetic account (Meta.synthetic_account), the planner's path without a team
##   (LevelSim.best_path, shared by every variant), then the same path with a one-champion team at the
##   account's Champion Level, native gem f0, no relic: (a) the bare template (`twist: {}`, the class
##   template Action x mult), (b) the champion without its twist (its own Action), (c) the champion.
##   Value = (army at the end + enemies killed) - the no-team run's: soldiers saved, healed and kills in
##   one currency. ratio = sum (c) / sum (a), the target 1 +- CHAMP_KIT_TOL. Statuses, holds, groundings
##   and reveals are not simulated (LevelSim is an expected-value model): a twist made only of those
##   measures as its template.
##
## godot --headless --path . res://scenes/dev/test_champion_twists.tscn -- --autotest [--verbose]
##     [--budget=0] [--from=15] [--to=112] [--step=4] [--hero=bolt] [--only=ivo,otto]
##     [--sweep=otto:plant_cd=8,12,16]   (prints the ratio per value of one twist field; no verdict)
## Exit code = failures (a budget miss counts as one).

## §4.3 template Action per class at f0 Lv1 (Quartz-normalised; x mult): leap kills, shot damage,
## spell kills per squad, kills per Block, soldiers per pulse.
const TEMPLATE_ACTION := {"warrior": 3.0, "ranger": 1.0, "mage": 4.0, "guardian": 1.0, "healer": 3.0}

var _fails := 0
var _passes := 0
var _verbose := false
var _args := {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_verbose = _args.has("verbose")
	var old := EconData.phase_override
	EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
	_ok(HeroKinds.champions_live(), "champions are live under the override")
	if not _args.has("sweep"):
		_test_rows()
		_test_healers()
		_test_guardians()
		_test_warriors()
		_test_rangers()
		_test_mages()
		_test_turret_catch()
		_test_unchanged()
	if str(_args.get("budget", "1")) != "0":
		_budget()
	EconData.phase_override = old
	_ok(EconData.phase_override == old, "phase override restored")
	print("TEST_CHAMPION_TWISTS %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes,
			_fails, float(Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(_fails)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		if _verbose:
			print("  ok ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


# ------------------------------------------------------------------ the test view

## A test-local KindView: one army (blob centre d 0, x 0, r 2: the front slot 1.26 ahead, the hero
## 2.9 ahead, the clash contact 4.0 ahead), hand-placed squads {id, d, x, n, hw, flying, armored,
## phantom} and hazards {id, d, x, kind, hp}; logs everything the rules do.
class TwistView extends KindView:
	var a := {"n": 100.0, "x": 0.0, "d": 0.0, "radius": 2.0, "reserves": 0.0, "revive_pool": 0.0}
	var fight := false
	var squads: Array = []
	var hazards: Array = []
	var hits: Array = []
	var statuses: Array = []
	var holds: Array = []
	var grounds: Array = []
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
				var r := sq.duplicate()
				for p: String in ["flying", "armored", "phantom"]:
					r[p] = bool(sq.get(p, false))
				out.append(r)
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

	func hold(squad_id: int, sec: float) -> void:
		holds.append([squad_id, sec])

	func ground(squad_id: int, sec: float) -> void:
		grounds.append([squad_id, sec])

	func add_soldiers(n: float, _cause: StringName) -> void:
		added += n
		a["n"] = float(a["n"]) + n

	func fx(event: StringName, data := {}) -> void:
		events.append([event, data])

	func twists(name: StringName) -> Array:
		return events.filter(func(e: Array) -> bool:
			return e[0] == ChampionKinds.TWIST_FX and (e[1] as Dictionary).get("twist") == name)

	func count(event: StringName) -> int:
		return events.filter(func(e: Array) -> bool: return e[0] == event).size()

	func hits_of(kind: StringName) -> Array:
		return hits.filter(func(h: Array) -> bool: return h[2] == kind)

	func status_of(id: int, st: StringName) -> Array:
		return statuses.filter(func(s: Array) -> bool: return int(s[0]) == id and s[1] == st)


## A real champion (its ChampionData class, element and slot) as a member: tier, mult 1, `action`;
## `twist` replaces its TWISTS row when given.
static func _mem(id: String, tier: int, action: float, hp := 50.0, twist: Variant = null) -> Dictionary:
	var row: Dictionary = ChampionData.CHAMPIONS[id]
	var st := {"id": id, "class": str(row["class"]), "element": str(row["element"]), "tier": tier, "mult": 1.0,
			"hp": hp, "action": action, "aura": 0.1, "radius": 1.0}
	if twist is Dictionary:
		st["twist"] = twist
	return ChampionKinds.member(st, StringName(str(row["slot"])))


static func _run_for(v: KindView, members: Array, secs: float, dt := 0.05) -> void:
	for i in int(round(secs / dt)):
		ChampionKinds.step(v, members, dt)


## Steps the Ranger `m` alone until it has fired `n` shots (at most 30 s).
static func _shots(v: KindView, m: Dictionary, n: int) -> void:
	var k := 0
	while int(m["shots"]) < n and k < 600:
		ChampionKinds.step(v, [m], 0.05)
		k += 1


# ------------------------------------------------------------------ rows

func _test_rows() -> void:
	print("== TWISTS rows")
	var known := 0
	for id: String in ChampionData.CHAMPION_ORDER:
		var tw := ChampionKinds.twist(id)
		known += 1 if not tw.is_empty() else 0
		var m := _mem(id, ChampionData.action_tier(id), 1.0)
		_ok(m["tw"] == tw, "%s: member() carries its TWISTS row" % id)
	_ok(known == ChampionData.CHAMPION_ORDER.size(), "every champion has a twist row (%d of %d)" % [known,
			ChampionData.CHAMPION_ORDER.size()])
	var bare := _mem("ivo", 1, 3.0, 60.0, {})
	_ok((bare["tw"] as Dictionary).is_empty(), "a stats row with twist {} runs the bare template")


# ------------------------------------------------------------------ healers

func _test_healers() -> void:
	print("== Healers: Міла's Tonic, Олена's Frost Balm and rime")
	var v := TwistView.new()
	v.squads = [{"id": 1, "d": 9.0, "x": 0.0, "n": 50.0}, {"id": 2, "d": 6.0, "x": 1.0, "n": 50.0},
			{"id": 3, "d": 20.0, "x": 0.0, "n": 50.0}]
	var mila := _mem("mila", 1, 3.0, 30.0)
	ChampionKinds.feed([mila], 50.0)
	_run_for(v, [mila], 3.05)
	var tonic := v.twists(&"tonic")
	_ok(v.added == 3.0 and tonic.size() == 1 and int((tonic[0][1] as Dictionary)["target"]) == 2,
			"Міла: a returning pulse throws the vial at the nearest squad ahead (%s)" % str(tonic))
	_ok(v.status_of(2, &"mark").size() == 1 and is_equal_approx(float(v.status_of(2, &"mark")[0][2]), 3.0),
			"Міла: the vial MARKs it for 3 s")
	var v0 := TwistView.new()
	v0.squads = v.squads.duplicate(true)
	var mila0 := _mem("mila", 1, 3.0, 30.0)
	_run_for(v0, [mila0], 3.05)
	_ok(v0.twists(&"tonic").is_empty() and v0.statuses.is_empty(), "Міла: no vial from an empty pulse")
	var vb := TwistView.new()
	vb.squads = v.squads.duplicate(true)
	var bare := _mem("mila", 1, 3.0, 30.0, {})
	ChampionKinds.feed([bare], 50.0)
	_run_for(vb, [bare], 3.05)
	_ok(vb.added == 3.0 and vb.statuses.is_empty() and vb.twists(&"tonic").is_empty(), "bare Healer: Mend only")
	# Олена (right slot, tier III): army front = centre + r x 1.15 = 2.3.
	var vo := TwistView.new()
	vo.squads = [{"id": 1, "d": 3.5, "x": 0.0, "n": 50.0}, {"id": 2, "d": 1.0, "x": 0.5, "n": 50.0},
			{"id": 3, "d": 6.0, "x": 0.0, "n": 50.0}]
	var olena := _mem("olena", 3, 3.0, 35.0)
	ChampionKinds.feed([olena], 100.0)
	_run_for(vo, [olena], 3.05)
	_ok(vo.added == 4.0 and vo.status_of(1, &"chill").size() == 1 and vo.status_of(2, &"chill").size() == 1
			and vo.status_of(3, &"chill").is_empty(), "Олена: the pulse CHILLs the squads <= 2 u of the army front")
	_ok(vo.twists(&"balm").size() == 1 and is_equal_approx(float(olena["rimed"]), 3.0),
			"Олена: 4 returned, rimed capped at 3 (%.1f)" % float(olena["rimed"]))
	var left := ChampionKinds.absorb_hazard(vo, [olena], 40, &"blade", 10.0, 100.0, 2.0)
	var left2 := ChampionKinds.absorb_hazard(vo, [olena], 40, &"blade", 2.0, 100.0, 2.0)
	var left3 := ChampionKinds.absorb_hazard(vo, [olena], 41, &"blade", 5.0, 100.0, 2.0)
	_ok(is_equal_approx(left, 7.0) and is_equal_approx(left2, 2.0) and is_equal_approx(left3, 5.0)
			and vo.twists(&"rime").size() == 1, "Олена: the rime spares 3 at the next hazard, then is spent (%.1f %.1f %.1f)" % [
			left, left2, left3])
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(vo, [olena], 42, &"turret", 5.0, 100.0, 2.0), 5.0),
			"Олена: turrets never use the rime")


# ------------------------------------------------------------------ guardians

func _test_guardians() -> void:
	print("== Guardians: Іво, Отто, Снаряд, Німб")
	# Іво: the barricade takes his Action (3) and burns; a blade Block kills 1 x mult behind.
	var v := TwistView.new()
	v.squads = [{"id": 5, "d": 4.0, "x": 0.0, "n": 30.0}]
	var ivo := _mem("ivo", 1, 3.0, 60.0)
	ChampionKinds.step(v, [ivo], 0.05)
	ChampionKinds.absorb_hazard(v, [ivo], 11, &"barricade", 5.0, 100.0, 2.0)
	var bh := v.hits_of(&"block")
	_ok(bh.size() == 1 and int(bh[0][0]) == 11 and is_equal_approx(float(bh[0][1]), 3.0) and v.twists(&"brazier").size() == 1,
			"Іво: the blocked barricade takes 3 x power and burns (%s)" % str(bh))
	_run_for(v, [ivo], 5.05)
	ChampionKinds.absorb_hazard(v, [ivo], 12, &"blade", 5.0, 100.0, 2.0)
	bh = v.hits_of(&"block")
	_ok(bh.size() == 2 and int(bh[1][0]) == 5 and is_equal_approx(float(bh[1][1]), 1.0),
			"Іво: a blade Block kills 1 x power on the squad behind (%s)" % str(bh))
	var vt := TwistView.new()
	vt.squads = [{"id": 5, "d": 4.0, "x": 0.0, "n": 30.0}]
	var tpl := _mem("ivo", 1, 1.0, 60.0, {})
	ChampionKinds.step(vt, [tpl], 0.05)
	ChampionKinds.absorb_hazard(vt, [tpl], 11, &"barricade", 5.0, 100.0, 2.0)
	_ok(is_equal_approx(float(vt.hits_of(&"block")[0][1]), 1.0) and vt.events.size() == 1,
			"bare Guardian: the barricade takes the template Action, no twist fx")
	# Іво: BURN on the clash squad at each clash start (contact = 4.0 ahead of the centre).
	var vf := TwistView.new()
	vf.squads = [{"id": 7, "d": 4.0, "x": 0.0, "n": 30.0}]
	vf.fight = true
	var ivo2 := _mem("ivo", 1, 3.0, 60.0)
	_run_for(vf, [ivo2], 1.0)
	_ok(vf.status_of(7, &"burn").size() == 1 and vf.twists(&"brazier").size() == 1,
			"Іво: one BURN at the clash start (%d)" % vf.status_of(7, &"burn").size())
	vf.squads[0]["n"] = 0.0
	vf.squads.append({"id": 8, "d": 4.2, "x": 0.0, "n": 30.0})
	_run_for(vf, [ivo2], 0.1)
	_ok(vf.status_of(8, &"burn").size() == 1, "Іво: a new foe in contact is a new clash start")
	# Отто: the first 2 ticks of a clash are free; he takes them at x0.5; 8 s between plants.
	var vo := TwistView.new()
	vo.squads = [{"id": 3, "d": 4.0, "x": 0.0, "n": 30.0}]
	var otto := _mem("otto", 2, 1.0, 65.0)
	ChampionKinds.step(vo, [otto], 0.05)
	_ok(not ChampionKinds.tick_free([otto]), "Отто: no plant outside a clash")
	vo.fight = true
	ChampionKinds.step(vo, [otto], 0.05)
	var free := [ChampionKinds.tick_free([otto]), ChampionKinds.tick_free([otto]), ChampionKinds.tick_free([otto])]
	_ok(free == [true, true, false] and vo.twists(&"plant").size() == 1, "Отто: 2 planted ticks cost the army 0 (%s)" % str(free))
	var o2 := _mem("otto", 2, 1.0, 65.0)
	vo.fight = false
	ChampionKinds.step(vo, [o2], 0.05)
	vo.fight = true
	ChampionKinds.step(vo, [o2], 0.05)
	ChampionKinds.tick_free([o2])
	ChampionKinds.clash_hit(vo, [o2], 4.0, false)
	_ok(is_equal_approx(float(o2["hp"]), 63.0) and is_equal_approx(float(o2["saved"]), 4.0),
			"Отто: a planted tick of 4 costs him 4 x 0.5 = 2 HP (hp %.1f)" % float(o2["hp"]))
	vo.fight = false
	_run_for(vo, [o2], 2.0)
	vo.fight = true
	ChampionKinds.step(vo, [o2], 0.05)
	_ok(int(o2["plant"]) == 1, "Отто: no new plant within 8 s (planted %d)" % int(o2["plant"]))
	vo.fight = false
	_run_for(vo, [o2], 6.0)
	vo.fight = true
	ChampionKinds.step(vo, [o2], 0.05)
	_ok(int(o2["plant"]) == 2, "Отто: plants again after 8 s")
	# Снаряд: Block cd 6 s, the charge on the nearest squad <= 6 u (his Action + MARK 3 s), stamp «ЧИСТО!».
	var vs := TwistView.new()
	vs.squads = [{"id": 1, "d": 6.5, "x": 0.0, "n": 30.0}, {"id": 2, "d": 9.0, "x": 0.0, "n": 30.0}]
	var sn := _mem("snaryad", 3, 2.0, 70.0)
	ChampionKinds.step(vs, [sn], 0.05)
	ChampionKinds.absorb_hazard(vs, [sn], 20, &"blade", 6.0, 100.0, 2.0)
	var ch := vs.hits_of(&"charge")
	var blk: Array = vs.events.filter(func(e: Array) -> bool: return e[0] == &"champ_block")
	_ok(ch.size() == 1 and int(ch[0][0]) == 1 and is_equal_approx(float(ch[0][1]), 2.0) and vs.hits_of(&"block").is_empty(),
			"Снаряд: the defused charge on the nearest squad replaces the +1 kill (%s)" % str(ch))
	_ok(vs.status_of(1, &"mark").size() == 1 and float(sn["cd"]) == 6.0
			and blk.size() == 1 and (blk[0][1] as Dictionary)["stamp"] == &"clear",
			"Снаряд: MARK 3 s, Block cd 6 s, the stamp reads ЧИСТО")
	# Німб (tier IV): every Block chains 3 hostiles <= 5 u (his Action each, JOLT on squads).
	var vn := TwistView.new()
	vn.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 30.0}, {"id": 2, "d": 5.0, "x": 1.0, "n": 30.0},
			{"id": 3, "d": 12.0, "x": 0.0, "n": 30.0}]
	vn.hazards = [{"id": 9, "d": 2.0, "x": 2.0, "kind": &"turret", "hp": 10.0}, {"id": 10, "d": 6.5, "x": 0.0, "kind": &"barricade",
			"hp": 10.0}]
	var nimb := _mem("nimb", 4, 2.0, 76.0)
	ChampionKinds.step(vn, [nimb], 0.05)
	ChampionKinds.absorb_hazard(vn, [nimb], 30, &"blade", 6.0, 100.0, 2.0)
	var rod := vn.hits_of(&"rod")
	var rod_ids: Array = rod.map(func(h: Array) -> int: return int(h[0]))
	rod_ids.sort()
	_ok(rod.size() == 3 and rod_ids == [1, 2, 9] and rod.all(func(h: Array) -> bool: return is_equal_approx(float(h[1]), 2.0)),
			"Німб: the Lightning Rod hits the 3 nearest hostiles <= 5 u for his Action (%s)" % str(rod))
	_ok(vn.status_of(1, &"jolt").size() == 1 and vn.status_of(9, &"jolt").is_empty() and vn.twists(&"rod").size() == 1,
			"Німб: JOLT on the squads only")
	_ok(vn.hits_of(&"block").size() == 1 and is_equal_approx(float(vn.hits_of(&"block")[0][1]), 1.0),
			"Німб: the Block's own +1 kill x power")


# ------------------------------------------------------------------ warriors

func _test_warriors() -> void:
	print("== Warriors: Борко, Брант, Довбуш")
	# Борко (front slot 1.26 ahead): Undermine never takes a Flying squad; STAGGER at tier I.
	var v := TwistView.new()
	v.squads = [{"id": 1, "d": 2.5, "x": 0.0, "n": 50.0, "flying": true}, {"id": 2, "d": 3.8, "x": 0.0, "n": 50.0}]
	var bo := _mem("borko", 1, 3.0, 48.0)
	ChampionKinds.step(v, [bo], 0.05)
	var lp: Array = v.events.filter(func(e: Array) -> bool: return e[0] == &"champ_leap")
	_ok(v.hits.size() == 1 and int(v.hits[0][0]) == 2 and is_equal_approx(float(v.hits[0][1]), 3.0),
			"Борко: Undermine skips the Flying squad (%s)" % str(v.hits))
	_ok(v.status_of(2, &"stagger").size() == 1 and lp.size() == 1 and (lp[0][1] as Dictionary)["verb"] == &"undermine"
			and is_equal_approx(float((v.twists(&"undermine")[0][1] as Dictionary)["burrow_s"]), 0.4),
			"Борко: STAGGER at tier I, the burrow fx")
	var vb := TwistView.new()
	vb.squads = v.squads.duplicate(true)
	ChampionKinds.step(vb, [_mem("borko", 1, 3.0, 48.0, {})], 0.05)
	_ok(int(vb.hits[0][0]) == 1 and vb.statuses.is_empty(), "bare Warrior: leaps at the nearest (Flying too), no status")
	# Брант (tier III): the leap BURNs its target and the squads <= 1.5 u of it; BURN on the clash squad.
	var vr := TwistView.new()
	vr.squads = [{"id": 1, "d": 3.5, "x": 0.0, "n": 50.0}, {"id": 2, "d": 4.6, "x": 0.5, "n": 50.0},
			{"id": 3, "d": 8.0, "x": 0.0, "n": 50.0}]
	var br := _mem("brant", 3, 3.5, 56.0)
	ChampionKinds.step(vr, [br], 0.05)
	_ok(vr.status_of(1, &"burn").size() == 1 and vr.status_of(2, &"burn").size() == 1 and vr.status_of(3, &"burn").is_empty()
			and vr.twists(&"cross").size() == 1, "Брант: the burning cross BURNs the squads <= 1.5 u of the target")
	var vc := TwistView.new()
	vc.squads = [{"id": 4, "d": 4.0, "x": 0.0, "n": 50.0}]
	vc.fight = true
	_run_for(vc, [_mem("brant", 3, 3.5, 56.0)], 2.1)
	_ok(vc.status_of(4, &"burn").size() == 3 and vc.twists(&"blades").size() == 3,
			"Брант: BURN on the clash squad at the start and every 1 s (%d)" % vc.status_of(4, &"burn").size())
	# Довбуш (tier IV): the bartka through 2 squads <= 7 u, the armoured first, 1.5 + 0.5 each, cd 4 s.
	var vd := TwistView.new()
	vd.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 50.0}, {"id": 2, "d": 5.0, "x": 0.0, "n": 50.0, "armored": true},
			{"id": 3, "d": 6.0, "x": 0.0, "n": 50.0}, {"id": 4, "d": 4.0, "x": 1.8, "n": 50.0}]
	var db := _mem("dovbush", 4, 1.5, 60.0)
	ChampionKinds.step(vd, [db], 0.05)
	var hd := vd.hits_of(&"leap")
	_ok(hd.size() == 2 and int(hd[0][0]) == 2 and int(hd[1][0]) == 1 and is_equal_approx(float(hd[0][1]), 2.0)
			and is_equal_approx(float(db["cd"]), 4.0), "Довбуш: the armoured squad first, then the nearest; 2.0 each; cd 4 s (%s)" % str(hd))
	_ok(vd.status_of(1, &"stagger").size() == 1 and vd.status_of(2, &"stagger").size() == 1
			and vd.status_of(4, &"stagger").size() == 1 and vd.status_of(3, &"stagger").is_empty()
			and vd.twists(&"bartka").size() == 1, "Довбуш: STAGGER on both, tier III also <= 1 u of the path")


# ------------------------------------------------------------------ rangers

func _test_rangers() -> void:
	print("== Rangers: Альба, Тео, Дара")
	# Альба (rear slot 1.38 behind the centre): a Flying squad 15.5 u ahead of her, past 14 u.
	var v := TwistView.new()
	v.squads = [{"id": 1, "d": 6.0, "x": 0.0, "n": 50.0}, {"id": 2, "d": 14.1, "x": 0.0, "n": 50.0, "flying": true}]
	var al := _mem("alba", 2, 1.0, 28.0)
	ChampionKinds.step(v, [al], 0.05)
	_ok(v.hits.size() == 1 and int(v.hits[0][0]) == 2 and is_equal_approx(float(v.hits[0][1]), 1.5),
			"Альба: prefers the Flying squad (16 u vs Flying), x1.5 (%s)" % str(v.hits))
	_ok(v.status_of(2, &"chill").size() == 1, "Альба: CHILL from her tier II")
	var vb := TwistView.new()
	vb.squads = v.squads.duplicate(true)
	ChampionKinds.step(vb, [_mem("alba", 2, 1.0, 28.0, {})], 0.05)
	_ok(int(vb.hits[0][0]) == 1 and vb.statuses.is_empty(), "bare Ranger: the nearest, no status at tier II")
	# Тео: every 4th shot is a probe (MARK 3 s on the target, reveals the Phantoms <= 14 u).
	var vt := TwistView.new()
	vt.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 999.0}, {"id": 2, "d": 9.0, "x": 3.0, "n": 20.0, "phantom": true},
			{"id": 3, "d": 30.0, "x": 0.0, "n": 20.0, "phantom": true}]
	_run_for(vt, [_mem("teo", 3, 1.0, 30.0)], 4.9)
	var pr := vt.twists(&"probe")
	_ok(vt.count(&"champ_shot") == 5 and pr.size() == 1 and (pr[0][1] as Dictionary)["reveal"] == [2],
			"Тео: the 4th shot is a probe revealing the Phantom <= 14 u (%s)" % str(pr))
	_ok(vt.status_of(1, &"mark").filter(func(s: Array) -> bool: return is_equal_approx(float(s[2]), 3.0)).size() == 1,
			"Тео: the probe MARKs its target for 3 s")
	# Дара (tier IV): every 3rd shot tethers the hit squad to the nearest other <= 4 u.
	var vd := TwistView.new()
	vd.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 999.0, "flying": true}, {"id": 2, "d": 7.5, "x": 1.0, "n": 999.0},
			{"id": 3, "d": 20.0, "x": 0.0, "n": 999.0}]
	var da := _mem("dara", 4, 1.0, 33.0)
	_shots(vd, da, 2)
	_ok(vd.twists(&"harpoon").is_empty() and vd.hits_of(&"tether").is_empty(), "Дара: no harpoon on shots 1-2")
	_shots(vd, da, 3)
	var th := vd.hits_of(&"tether")
	_ok(vd.twists(&"harpoon").size() == 1 and th.size() == 1 and int(th[0][0]) == 2 and is_equal_approx(float(th[0][1]), 1.0),
			"Дара: the 3rd shot (2 arrows) stitches the partner for 50%% (%s)" % str(th))
	_ok(vd.grounds.size() == 1 and int(vd.grounds[0][0]) == 1 and is_equal_approx(float(vd.grounds[0][1]), 1.5),
			"Дара: the harpooned Flying squad is grounded 1.5 s")
	_shots(vd, da, 4)
	th = vd.hits_of(&"tether")
	_ok(th.size() == 2 and int(th[1][0]) == 2 and is_equal_approx(float(th[1][1]), 0.5),
			"Дара: her next hit on a tethered squad lands on the other too (%s)" % str(th))
	_shots(vd, da, 5)
	_ok(vd.hits_of(&"tether").size() == 4, "Дара: the tether holds 3 s (shot 5 at +2.4 s pierces both: 2 more)")
	var short: Dictionary = ChampionKinds.twist("dara").duplicate()
	short["tether_s"] = 1.0
	var vl := TwistView.new()
	vl.squads = vd.squads.duplicate(true)
	var dl := _mem("dara", 4, 1.0, 33.0, short)
	_shots(vl, dl, 4)
	_ok(vl.hits_of(&"tether").size() == 1, "Дара: a lapsed tether (tether_s 1 < the 1.2 s shot) mirrors nothing")


# ------------------------------------------------------------------ mages

func _test_mages() -> void:
	print("== Mages: Тая, Менгір, Тарас")
	var v := TwistView.new()
	v.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 99.0}, {"id": 2, "d": 6.8, "x": 0.0, "n": 99.0}]
	ChampionKinds.step(v, [_mem("taya", 2, 4.0, 28.0)], 0.05)
	_ok(v.holds.size() == 2 and v.holds.all(func(h: Array) -> bool: return is_equal_approx(float(h[1]), 1.5))
			and v.twists(&"lull").size() == 1 and v.events[0][0] == &"champ_spell",
			"Тая: every squad of the dust burst is lulled 1.5 s (hold) (%s)" % str(v.holds))
	# Менгір (tier IV, right slot): the circle Brands the squads in it; the foe in it costs -25%.
	var vm := TwistView.new()
	vm.squads = [{"id": 1, "d": 4.0, "x": 0.0, "n": 99.0}, {"id": 2, "d": 9.0, "x": 0.0, "n": 99.0}]
	var me := _mem("menhir", 4, 5.0, 33.0)
	ChampionKinds.step(vm, [me], 0.05)
	_ok(vm.twists(&"circle").size() == 1 and vm.status_of(1, &"seal").size() >= 2 and int(me["cut_id"]) == 1,
			"Менгір: the strike carves a circle that Brands the squad in it")
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 1.0), "Менгір: no cut outside a clash")
	vm.fight = true
	ChampionKinds.step(vm, [me], 0.05)
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 0.75), "Менгір: the foe in the circle deals -25% clash damage")
	vm.fight = false
	_run_for(vm, [me], 8.5)
	vm.fight = true
	vm.squads[1]["n"] = 0.0
	vm.squads.append({"id": 5, "d": 4.0, "x": 2.4, "n": 99.0})
	vm.squads[0]["n"] = 0.0
	ChampionKinds.step(vm, [me], 0.05)
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 1.0), "Менгір: a squad never in the circle deals full damage")
	# Тарас (rear): the book at the nearest squad (not the densest); pages cut on into the next <= 3 u.
	var vt := TwistView.new()
	vt.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 5.0}, {"id": 2, "d": 5.8, "x": 0.3, "n": 99.0},
			{"id": 3, "d": 9.0, "x": 0.0, "n": 99.0}, {"id": 4, "d": 9.6, "x": 0.0, "n": 99.0}]
	ChampionKinds.step(vt, [_mem("taras", 1, 4.0, 33.0)], 0.05)
	var sp := vt.hits_of(&"spell")
	var pg := vt.hits_of(&"pages")
	_ok(sp.size() == 1 and int(sp[0][0]) == 1, "Тарас: the book hits the nearest squad (%s)" % str(sp))
	_ok(pg.size() == 1 and int(pg[0][0]) == 2 and is_equal_approx(float(pg[0][1]), 2.0) and vt.status_of(2, &"seal").size() == 1
			and vt.twists(&"pages").size() == 1, "Тарас: the pages take 50%% from the next squad <= 3 u, BRAND (%s)" % str(pg))
	var vtb := TwistView.new()
	vtb.squads = vt.squads.duplicate(true)
	for s: Dictionary in vtb.squads:
		s["n"] = 99.0 if int(s["id"]) != 1 else 5.0
	ChampionKinds.step(vtb, [_mem("taras", 1, 4.0, 33.0, {})], 0.05)
	_ok(int(vtb.hits_of(&"spell")[0][0]) == 3 and vtb.hits_of(&"pages").is_empty(), "bare Mage: the densest squad, no pages")


# ------------------------------------------------------------------ Німб's tier IV catch

func _test_turret_catch() -> void:
	print("== Німб tier IV: a turret shot caught on the aegis (absorb_turret)")
	# The army centre at d 0, r 2; Німб at the front slot (d 1.26). A turret ahead at d 5: the shot's
	# soldier is the blob front (d 2.3), 1.04 from him.
	var v := TwistView.new()
	v.hazards = [{"id": 9, "d": 5.0, "x": 0.0, "kind": &"turret", "hp": 10.0},
			{"id": 10, "d": 0.0, "x": 3.3, "kind": &"turret", "hp": 10.0}]
	var nimb := _mem("nimb", 4, 2.0, 76.0)
	ChampionKinds.step(v, [nimb], 0.05)
	_ok(is_zero_approx(ChampionKinds.absorb_turret(v, [nimb], 9, 1.0)) and int(nimb["blocks"]) == 1
			and v.twists(&"catch").size() == 1 and ChampionKinds.catcher([nimb], 9) == nimb,
			"Німб: a shot aimed near him is caught (one Block)")
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [nimb], 9, 1.0), 1.0), "Німб: one shot per catch")
	_ok(is_equal_approx(float(nimb["catch_cd"]), 5.0) and float(nimb["cd"]) == 0.0, "Німб: the catch has its own 5 s timer")
	ChampionKinds.absorb_hazard(v, [nimb], 30, &"blade", 4.0, 100.0, 2.0)
	_ok(int(nimb["blocks"]) == 2, "Німб: a hazard Block right after a catch")
	_run_for(v, [nimb], 5.05)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [nimb], 10, 1.0), 1.0), "Німб: a shot at the far flank (> 1.6 u) is not caught")
	var n3 := _mem("nimb", 3, 2.0, 76.0)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [n3], 9, 1.0), 1.0), "below tier IV: no catch")
	var ivo := _mem("ivo", 1, 3.0, 60.0)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [ivo], 9, 1.0), 1.0), "a Guardian without the catch never takes a shot")
	var vs := TwistView.new()
	vs.hazards = v.hazards.duplicate(true)
	var shared := _mem("nimb", 4, 2.0, 76.0, {"catch_r": 1.6, "catch_tier": 4})
	ChampionKinds.step(vs, [shared], 0.05)
	ChampionKinds.absorb_turret(vs, [shared], 9, 1.0)
	_ok(is_equal_approx(float(shared["cd"]), 5.0), "without catch_cd the catch shares the Block cooldown")
	# LevelSim: a turret by the road; Німб catches some shots (fewer turret deaths than his bare self).
	var items := [{"kind": "turret", "d": 30.0, "x": 1.6, "value": 40, "range": 7.0, "rate": 2.0},
			{"kind": "turret", "d": 60.0, "x": -1.6, "value": 40, "range": 7.0, "rate": 2.0}]
	var lv := _level(items, 90.0)
	var path := LevelSim.lazy_path()
	var row := _stats("nimb", 1)
	var s1 := LevelSim.simulate(lv, "bolt", 60, path, {"profile": _prof([row])})
	var bare := row.duplicate()
	bare["twist"] = {}
	var s0 := LevelSim.simulate(lv, "bolt", 60, path, {"profile": _prof([bare])})
	var m1: Dictionary = s1.champs.members[0]
	_ok(int(m1["blocks"]) >= 2 and s1.hazard_deaths < s0.hazard_deaths - 1.5,
			"LevelSim: Німб catches turret shots (%d catches, turret losses %.1f vs %.1f)" % [int(m1["blocks"]),
			s1.hazard_deaths, s0.hazard_deaths])


## A short hand-built level: `items` + a 1-hp fortress at `fort` and its stairs, sorted by d.
static func _level(items: Array, fort := 70.0) -> LevelSim.Level:
	var all := items.duplicate()
	all.append({"kind": "fortress", "x": 0.0, "d": fort, "value": 1})
	all.append({"kind": "stairs", "x": 0.0, "d": fort + 6.0, "steps": []})
	all.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	return LevelSim.level_from_items(all, 1, fort + 6.0)


## The reference profile of L1 with a team block of `rows`, led by `hero`.
static func _prof(rows: Array, hero := "bolt") -> Dictionary:
	var p := LevelSim.reference_profile(1).duplicate()
	if not rows.is_empty():
		p["team"] = {"hero": hero, "champions": rows, "synergy": {}, "synergy_ids": []}
	return p


## Champion `id`'s team row at native gem f0, Champion Level `cl`, no relic, in its own slot.
static func _stats(id: String, cl: int) -> Dictionary:
	var st := ChampionsMeta.stats_at(id, str(ChampionData.CHAMPIONS[id]["native"]), 0, cl)
	st["aura_effect"] = ChampionsMeta.aura_effect(float(st["aura"]), str(st["slot"]))
	return st


# ------------------------------------------------------------------ phase 0 / no team

func _test_unchanged() -> void:
	print("== phase 0 with a team / phase 2 without one = the old LevelSim result")
	var path := LevelSim.lazy_path()
	var same := 0
	var cases := 0
	for level: int in [17, 26, 33, 47, 61]:
		var lvx := LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY), level)
		var base := LevelSim.reference_profile(level)
		var teamed := base.duplicate()
		teamed["team"] = {"hero": "bolt", "champions": [_stats("nimb", 5), _stats("olena", 5), _stats("dara", 5)],
				"synergy": {}, "synergy_ids": []}
		EconData.phase_override = 0
		var a := LevelSim.simulate(lvx, "bolt", 40, path, {"profile": teamed})
		var b := LevelSim.simulate(lvx, "bolt", 40, path, {"profile": base})
		EconData.phase_override = HeroKinds.CHAMPIONS_PHASE
		var c := LevelSim.simulate(lvx, "bolt", 40, path, {"profile": base})
		var ra := LevelSim.result(lvx, a)
		cases += 1
		if ra == LevelSim.result(lvx, b) and ra == LevelSim.result(lvx, c) and not ra.has("team_report") \
				and a.hp == c.hp and a.alive == c.alive and a.t == c.t and a.army == c.army and not a.champs.active():
			same += 1
	_ok(same == cases, "phase 0 with a twisted team / phase 2 without one = the old result (%d of %d)" % [same, cases])


# ------------------------------------------------------------------ budget (§4.1, §4.3)

## The budget table (see the header). With --sweep=id:field=v1,v2 only that champion, once per value.
func _budget() -> void:
	var from := maxi(1, int(_args.get("from", "15")))
	var to := maxi(from, int(_args.get("to", "112")))
	var step := maxi(1, int(_args.get("step", "4")))
	var hero := str(_args.get("hero", "bolt"))
	var ids: Array[String] = []
	for id in str(_args.get("only", ",".join(ChampionData.CHAMPION_ORDER))).split(",", false):
		if ChampionData.CHAMPIONS.has(id):
			ids.append(id)
	var sweep_id := ""
	var sweep_key := ""
	var sweep_vals: Array = []
	if _args.has("sweep"):
		var sw := str(_args["sweep"]).split(":", true, 1)
		var kv := sw[1].split("=", true, 1) if sw.size() > 1 else PackedStringArray()
		if sw.size() < 2 or kv.size() < 2 or not ChampionData.CHAMPIONS.has(sw[0]):
			_ok(false, "--sweep=id:field=v1,v2 (got %s)" % str(_args["sweep"]))
			return
		sweep_id = sw[0]
		sweep_key = kv[0]
		for v in kv[1].split(",", false):
			sweep_vals.append(str_to_var(v))
		ids = [sweep_id]
	var t0 := Time.get_ticks_msec()
	print("== budget: %s, levels %d..%d step %d, EXPECTED profile, one-champion teams (phase %d)" % [hero, from, to,
			step, EconData.heroes_phase()])
	# Per level: the shared no-team path and baseline, then each variant on that path.
	var cases: Array = []
	var army := Balance.start_army(0)
	for level in range(from, to + 1, step):
		var lv := LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY), level)
		var acc := Meta.synthetic_account(level, "expected")
		var prof := LevelSim.profile_from_account(acc, level, "expected")
		var bp: Dictionary = LevelSim.best_path(lv, hero, army, {"profile": prof})
		var path: PackedFloat32Array = bp["path"]
		var s0 := LevelSim.simulate(lv, hero, army, path, {"profile": prof})
		cases.append({"level": level, "lv": lv, "prof": prof, "path": path, "cl": ChampionsMeta.level(acc),
				"army": _army_end(s0), "kills": s0.kills, "t": s0.t})
	var t_total := 0.0
	for cs: Dictionary in cases:
		t_total += float(cs["t"])
	print("  %d levels, planner paths in %.1f s, %.0f s of play" % [cases.size(), float(Time.get_ticks_msec() - t0) / 1000.0,
			t_total])
	if not sweep_vals.is_empty():
		var tw0: Dictionary = ChampionKinds.twist(sweep_id)
		for v: Variant in sweep_vals:
			var tw := tw0.duplicate()
			tw[sweep_key] = v
			var r := _measure(sweep_id, cases, hero, army, tw)
			print("  SWEEP %s %s=%s  ratio %.4f  (template %.3f/s, twist %.3f/s)" % [sweep_id, sweep_key, str(v),
					float(r["ratio"]), float(r["tpl"]) / t_total, float(r["twist"]) / t_total])
		return
	print("  value / s = (army at the end + kills) over the no-team run, per second of play; ratio = twist / template")
	print("  %-8s %-8s %-4s %-5s | %8s %8s %8s | %7s | %s" % ["id", "class", "tier", "slot", "template", "no twist",
			"twist", "ratio", "attributed / s (kills + heals + saved): template / twist"])
	var tol := ChampionData.CHAMP_KIT_TOL
	var misses: PackedStringArray = PackedStringArray()
	for id in ids:
		var r := _measure(id, cases, hero, army, ChampionKinds.twist(id))
		var row: Dictionary = ChampionData.CHAMPIONS[id]
		var ratio := float(r["ratio"])
		var ok := absf(ratio - 1.0) <= tol + 1e-9
		if not ok:
			misses.append("%s %.3f" % [id, ratio])
		print("  %-8s %-8s %-4d %-5s | %8.4f %8.4f %8.4f | %7.4f | %.4f / %.4f %s" % [id, str(row["class"]),
				ChampionData.action_tier(id), str(row["slot"]), float(r["tpl"]) / t_total, float(r["plain"]) / t_total,
				float(r["twist"]) / t_total, ratio, float(r["att_tpl"]) / t_total, float(r["att_twist"]) / t_total,
				"" if ok else "MISS"])
		_ok(ok, "budget %s: twist / template %.4f within 1 +- %.2f" % [id, ratio, tol])
	print("BUDGET_TABLE %s: %d champions, %d levels, %d misses%s (%.1f s)" % ["PASS" if misses.is_empty() else "MISS",
			ids.size(), cases.size(), misses.size(), "" if misses.is_empty() else " [" + ", ".join(misses) + "]",
			float(Time.get_ticks_msec() - t0) / 1000.0])


## Sums over `cases` of each variant's value over the no-team run: tpl (the bare class template), plain
## (the champion's Action, no twist), twist (with `tw`); att_* = the member's kills + heals + saved.
func _measure(id: String, cases: Array, hero: String, army: int, tw: Dictionary) -> Dictionary:
	var out := {"tpl": 0.0, "plain": 0.0, "twist": 0.0, "att_tpl": 0.0, "att_twist": 0.0}
	var cls := str(ChampionData.CHAMPIONS[id]["class"])
	for cs: Dictionary in cases:
		var st := _stats(id, int(cs["cl"]))
		var tpl := st.duplicate()
		tpl["twist"] = {}
		tpl["action"] = float(TEMPLATE_ACTION[cls]) * float(st["mult"])
		var plain := st.duplicate()
		plain["twist"] = {}
		var tws := st.duplicate()
		tws["twist"] = tw
		for key: String in ["tpl", "plain", "twist"]:
			var row: Dictionary = {"tpl": tpl, "plain": plain, "twist": tws}[key]
			var prof: Dictionary = (cs["prof"] as Dictionary).duplicate()
			prof["team"] = {"hero": hero, "champions": [row], "synergy": {}, "synergy_ids": []}
			var s := LevelSim.simulate(cs["lv"], hero, army, cs["path"], {"profile": prof})
			out[key] = float(out[key]) + _army_end(s) - float(cs["army"]) + s.kills - float(cs["kills"])
			if key != "plain" and s.champs.active():
				var m: Dictionary = s.champs.members[0]
				var att := float(m["kills"]) + float(m["heals"]) + float(m["saved"])
				out["att_" + key] = float(out["att_" + key]) + att
	out["ratio"] = float(out["twist"]) / maxf(float(out["tpl"]), 0.001)
	return out


## The army a run ends with (0 when lost).
static func _army_end(s: LevelSim.State) -> float:
	return s.army if s.mode == LevelSim.Mode.WON else 0.0
