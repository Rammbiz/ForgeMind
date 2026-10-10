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
##   spread (gates frozen: no sway, no blink): the EXPECTED synthetic account (Meta.synthetic_account),
##   the planner's path without a team (LevelSim.best_path, shared by every variant), then the same path
##   with a one-champion team at the account's Champion Level, native gem f0, no relic: (a) the bare
##   template (`twist: {}`, the class template Action x mult), (b) the champion without its twist (its
##   own Action), (c) the champion. Value = the member's kills + heals + soldiers saved (Blocks, plants,
##   rime, catches, the circle cut) + structure damage + what its statuses and holds did (LevelSim's
##   KindView records, booked on the State: State.st_kills = squad hp MARK's extra, BURN and JOLT chains
##   removed, State.hold_saved = clash losses holds spared; the team has one champion, so they are its
##   own), per second of play (the aura is the same in every variant and left out; whole-run outcomes are
##   dominated by timing: a shorter clash moves the ult and the blade phases, see --probe). ratio =
##   sum (c) / sum (a), the target 1 +- CHAMP_KIT_TOL. A twist whose columns (c), (b) and (a) are equal
##   (within 1e-6) changed nothing LevelSim models (CHILL, SEAL and STAGGER change nothing in the Run's
##   Statuses either; groundings and reveals need Flying / Phantom squads, Meta-2 properties; a tether needs
##   two squads <= 4 u apart): it is UNMEASURED, counted apart (never a pass) and listed on the BUDGET_TABLE
##   line. (c) = (b) != (a) is measured: the twist lives in the champion's own Action (Іво's barricade).
##   The budget P0_c is ChampionData.KIT_P0 (heroes_tables.CHAMP_P0, the column (a) of P0_SPREAD, owner
##   decision 2026-10-10: the measured class values replace the design's 1.00 / s). On P0_SPREAD (the default
##   spread) two more checks: column (a) within 1 +- CHAMP_KIT_TOL of its KIT_P0 row (else the table is stale:
##   re-measure, paste the --emit line into heroes_tables.py, gen_heroes_data.py --refresh), and KIT_INDEX =
##   (c) / KIT_P0 within 1 +- CHAMP_KIT_TOL for every measured twist. Other spreads check the ratio only.
##
## godot --headless --path . res://scenes/dev/test_champion_twists.tscn -- --autotest [--verbose]
##     [--budget=0] [--from=15] [--to=112] [--step=4] [--hero=bolt,seer] [--only=ivo,otto]
##     (defaults: both heroes pooled, 50 runs; the planner paths take ~4 min without --paths)
##     [--emit]   (also prints column (a) as the heroes_tables.py CHAMP_P0 line)
##     [--tiers]   (each template at Action tier I..its own: what each tier rule adds; no verdict)
##     [--sweep=otto:plant_cd=8,12,16]   (prints the ratio per value of one twist field; no verdict)
##     [--set=field=v;field=v]   (with --sweep: fixed overrides of the same twist row; "+" also separates)
##     [--paths=FILE]   (caches the planner's no-team paths as JSON between runs)
##     [--probe=L,L]   (per level: the no-team run and each champion's template / twist runs, in detail)
## Exit code = failures (a budget miss counts as one; an UNMEASURED twist is not a failure, not a pass).

## §4.3 template Action per class at f0 Lv1 (Quartz-normalised; x mult): leap kills, shot damage,
## spell kills per squad, kills per Block, soldiers per pulse.
const TEMPLATE_ACTION := {"warrior": 3.0, "ranger": 1.0, "mage": 4.0, "guardian": 1.0, "healer": 3.0}
## The spread ChampionData.KIT_P0 was measured on (the --budget defaults).
const P0_SPREAD := {"from": 15, "to": 112, "step": 4, "hero": "bolt,seer"}

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
	if not _args.has("sweep") and not _args.has("probe") and not _args.has("tiers"):
		_test_rows()
		_test_healers()
		_test_guardians()
		_test_warriors()
		_test_rangers()
		_test_mages()
		_test_turret_catch()
		_test_sim_books()
		_test_unchanged()
		_test_cost()
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
## phantom} and hazards {id, d, x, kind, hp}; logs everything the rules do (a tether is logged, never
## applied: its shares are the views' own, test_kind_parity checks them).
class TwistView extends KindView:
	var a := {"n": 100.0, "x": 0.0, "d": 0.0, "radius": 2.0, "reserves": 0.0, "revive_pool": 0.0}
	var fight := false
	var squads: Array = []
	var hazards: Array = []
	var hits: Array = []
	var statuses: Array = []
	var holds: Array = []
	var grounds: Array = []
	var tethers: Array = []
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

	func hold(squad_id: int, sec: float, strength := 1.0) -> void:
		holds.append([squad_id, sec, strength])

	func ground(squad_id: int, sec: float) -> void:
		grounds.append([squad_id, sec])

	func tether(a_id: int, b_id: int, share: float, sec: float) -> void:
		tethers.append([a_id, b_id, share, sec, hits.size()])

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
	var budgeted := ChampionData.CHAMPION_ORDER.filter(func(id: String) -> bool:
		return float(ChampionData.KIT_P0.get(id, 0.0)) > 0.0)
	_ok(budgeted.size() == ChampionData.CHAMPION_ORDER.size() and ChampionData.KIT_P0.size() == budgeted.size(),
			"every champion has a twist budget P0_c in KIT_P0 (%d of %d)" % [budgeted.size(),
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
	var tonic_s := float(ChampionKinds.twist("mila")["pulse_s"])
	_ok(v.status_of(2, &"mark").size() == 1 and is_equal_approx(float(v.status_of(2, &"mark")[0][2]), tonic_s),
			"Міла: the vial MARKs it for %.2f s (pulse_s)" % tonic_s)
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
	var cap := float(ChampionKinds.twist("olena")["rime_cap"])
	_ok(vo.twists(&"balm").size() == 1 and is_equal_approx(float(olena["rimed"]), cap),
			"Олена: 4 returned, rimed capped at %.0f (%.1f)" % [cap, float(olena["rimed"])])
	var left := ChampionKinds.absorb_hazard(vo, [olena], 40, &"blade", 0.5, 100.0, 2.0)
	var left2 := ChampionKinds.absorb_hazard(vo, [olena], 40, &"blade", 10.0, 100.0, 2.0)
	var left3 := ChampionKinds.absorb_hazard(vo, [olena], 41, &"blade", 5.0, 100.0, 2.0)
	_ok(is_zero_approx(left) and is_equal_approx(left2, 10.5 - cap) and is_equal_approx(left3, 5.0)
			and vo.twists(&"rime").size() == 1,
			"Олена: the rime spares %.0f over the next hazard's contacts, then is spent (%.1f %.1f %.1f)" % [cap, left,
			left2, left3])
	_ok(is_equal_approx(ChampionKinds.absorb_hazard(vo, [olena], 42, &"turret", 5.0, 100.0, 2.0), 5.0),
			"Олена: turrets never use the rime")


# ------------------------------------------------------------------ guardians

func _test_guardians() -> void:
	print("== Guardians: Іво, Отто, Снаряд, Німб")
	# Іво: the barricade takes his Action (here 3) and burns; a blade Block kills 1 x mult behind.
	var v := TwistView.new()
	v.squads = [{"id": 5, "d": 4.0, "x": 0.0, "n": 30.0}]
	var ivo := _mem("ivo", 1, 3.0, 60.0)
	ChampionKinds.step(v, [ivo], 0.05)
	ChampionKinds.absorb_hazard(v, [ivo], 11, &"barricade", 5.0, 100.0, 2.0)
	var bh := v.hits_of(&"block")
	_ok(bh.size() == 1 and int(bh[0][0]) == 11 and is_equal_approx(float(bh[0][1]), 3.0)
			and v.twists(&"brazier").size() == 1,
			"Іво: the blocked barricade takes his Action and burns (%s)" % str(bh))
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
	# A clash-start status (fight_every 0, the rule Іво's sheet had before the cut; contact = 4.0 ahead of the
	# centre): once at the clash start, again for a new foe in contact. Іво's own row puts none.
	var vf := TwistView.new()
	vf.squads = [{"id": 7, "d": 4.0, "x": 0.0, "n": 30.0}]
	vf.fight = true
	var start_row := {"fight_status": "burn", "fight_every": 0.0, "fight_s": 3.0, "fight_fx": &"brazier"}
	var ivo2 := _mem("ivo", 1, 3.0, 60.0, start_row)
	var ivo3 := _mem("ivo", 1, 3.0, 60.0)
	_run_for(vf, [ivo2], 1.0)
	_ok(vf.status_of(7, &"burn").size() == 1 and vf.twists(&"brazier").size() == 1,
			"clash-start status: one BURN at the clash start (%d)" % vf.status_of(7, &"burn").size())
	vf.squads[0]["n"] = 0.0
	vf.squads.append({"id": 8, "d": 4.2, "x": 0.0, "n": 30.0})
	_run_for(vf, [ivo2], 0.1)
	_ok(vf.status_of(8, &"burn").size() == 1, "clash-start status: a new foe in contact is a new clash start")
	var vf3 := TwistView.new()
	vf3.squads = [{"id": 7, "d": 4.0, "x": 0.0, "n": 30.0}]
	vf3.fight = true
	_run_for(vf3, [ivo3], 1.0)
	_ok(vf3.statuses.is_empty() and vf3.events.is_empty(), "Іво: no status on the clash squad (cut to the band)")
	# Отто, the whole-tick plant (plant_cut 1): the first 2 ticks of a clash are free; he takes them at x0.5;
	# 8 s between plants.
	var whole: Dictionary = ChampionKinds.twist("otto").duplicate()
	whole["plant_cut"] = 1.0
	var vo := TwistView.new()
	vo.squads = [{"id": 3, "d": 4.0, "x": 0.0, "n": 30.0}]
	var otto := _mem("otto", 2, 1.0, 65.0, whole)
	ChampionKinds.step(vo, [otto], 0.05)
	_ok(not ChampionKinds.tick_free([otto]), "Отто: no plant outside a clash")
	vo.fight = true
	ChampionKinds.step(vo, [otto], 0.05)
	var free := [ChampionKinds.tick_free([otto]), ChampionKinds.tick_free([otto]), ChampionKinds.tick_free([otto])]
	_ok(free == [true, true, false] and vo.twists(&"plant").size() == 1,
			"Отто (plant_cut 1): 2 planted ticks cost the army 0 (%s)" % str(free))
	var o2 := _mem("otto", 2, 1.0, 65.0, whole)
	vo.fight = false
	ChampionKinds.step(vo, [o2], 0.05)
	vo.fight = true
	ChampionKinds.step(vo, [o2], 0.05)
	ChampionKinds.tick_free([o2])
	ChampionKinds.clash_hit(vo, [o2], 4.0, false)
	_ok(is_equal_approx(float(o2["hp"]), 63.0) and is_equal_approx(float(o2["saved"]), 4.0),
			"Отто (plant_cut 1): a planted tick of 4 costs him 4 x 0.5 = 2 HP (hp %.1f)" % float(o2["hp"]))
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
	# Отто's row (plant_cut < 1): a planted tick is not free; it costs the army x (1 - plant_cut) (after the
	# Guardian aura), he takes the spared share at x0.5, and the next tick is a plain one.
	var cut := float(ChampionKinds.twist("otto")["plant_cut"])
	var vp := TwistView.new()
	vp.squads = [{"id": 3, "d": 4.0, "x": 0.0, "n": 30.0}]
	vp.fight = true
	var o3 := _mem("otto", 2, 1.0, 65.0)
	ChampionKinds.step(vp, [o3], 0.05)
	var aura := 1.0 - float(o3["aura_effect"])
	var f1 := ChampionKinds.tick_free([o3])
	var k1 := ChampionKinds.clash_loss_mult([o3])
	ChampionKinds.clash_hit(vp, [o3], 40.0, false)
	var hp1 := 65.0 - float(o3["hp"])
	ChampionKinds.tick_free([o3])
	ChampionKinds.tick_free([o3])
	var k3 := ChampionKinds.clash_loss_mult([o3])
	_ok(not f1 and is_equal_approx(k1, aura * (1.0 - cut)) and is_equal_approx(k3, aura)
			and is_equal_approx(float(o3["saved"]), 40.0 * cut)
			and is_equal_approx(hp1, floorf(40.0 * lerpf(0.25, 0.5, cut))),
			"Отто: a planted tick costs the army x%.3f (aura x%.3f), books %.2f saved, costs him %.0f HP" % [k1, aura,
			float(o3["saved"]), hp1])
	# Снаряд: Block cd 6 s, the charge on the nearest squad <= 6 u (his Action + MARK 3 s), stamp «ЧИСТО!».
	var vs := TwistView.new()
	vs.squads = [{"id": 1, "d": 6.5, "x": 0.0, "n": 30.0}, {"id": 2, "d": 9.0, "x": 0.0, "n": 30.0}]
	var sn := _mem("snaryad", 3, 2.0, 70.0)
	ChampionKinds.step(vs, [sn], 0.05)
	ChampionKinds.absorb_hazard(vs, [sn], 20, &"blade", 6.0, 100.0, 2.0)
	var ch := vs.hits_of(&"charge")
	var blk: Array = vs.events.filter(func(e: Array) -> bool: return e[0] == &"champ_block")
	_ok(ch.size() == 1 and int(ch[0][0]) == 1 and is_equal_approx(float(ch[0][1]), 2.0)
			and vs.hits_of(&"block").is_empty(),
			"Снаряд: the defused charge on the nearest squad replaces the +1 kill (%s)" % str(ch))
	_ok(vs.status_of(1, &"mark").size() == 1 and float(sn["cd"]) == 6.0
			and blk.size() == 1 and (blk[0][1] as Dictionary)["stamp"] == &"clear",
			"Снаряд: MARK 3 s, Block cd 6 s, the stamp reads ЧИСТО")
	var vs2 := TwistView.new()
	var sn2 := _mem("snaryad", 3, 2.0, 70.0)
	ChampionKinds.step(vs2, [sn2], 0.05)
	ChampionKinds.absorb_hazard(vs2, [sn2], 21, &"barricade", 6.0, 100.0, 2.0)
	var ch2 := vs2.hits_of(&"charge")
	_ok(ch2.size() == 1 and int(ch2[0][0]) == 21 and is_equal_approx(float(ch2[0][1]), 2.0 * 0.5)
			and vs2.twists(&"charge").is_empty(),
			"Снаряд: no squad near: half the charge into the blocked barricade (%s)" % str(ch2))
	# Німб (tier IV): every Block chains 3 hostiles <= 5 u (his Action each, JOLT on squads).
	var vn := TwistView.new()
	vn.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 30.0}, {"id": 2, "d": 5.0, "x": 1.0, "n": 30.0},
			{"id": 3, "d": 12.0, "x": 0.0, "n": 30.0}]
	vn.hazards = [{"id": 9, "d": 2.0, "x": 2.0, "kind": &"turret", "hp": 10.0},
			{"id": 10, "d": 6.5, "x": 0.0, "kind": &"barricade", "hp": 10.0}]
	var nimb := _mem("nimb", 4, 2.0, 76.0)
	ChampionKinds.step(vn, [nimb], 0.05)
	ChampionKinds.absorb_hazard(vn, [nimb], 30, &"blade", 6.0, 100.0, 2.0)
	var rod := vn.hits_of(&"rod")
	var rod_ids: Array = rod.map(func(h: Array) -> int: return int(h[0]))
	rod_ids.sort()
	_ok(rod.size() == 3 and rod_ids == [1, 2, 9]
			and rod.all(func(h: Array) -> bool: return is_equal_approx(float(h[1]), 2.0)),
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
	_ok(vr.status_of(1, &"burn").size() == 1 and vr.status_of(2, &"burn").size() == 1
			and vr.status_of(3, &"burn").is_empty()
			and vr.twists(&"cross").size() == 1, "Брант: the burning cross BURNs the squads <= 1.5 u of the target")
	var vc := TwistView.new()
	vc.squads = [{"id": 4, "d": 4.0, "x": 0.0, "n": 50.0}]
	vc.fight = true
	_run_for(vc, [_mem("brant", 3, 3.5, 56.0)], 2.1)
	_ok(vc.status_of(4, &"burn").size() == 3 and vc.twists(&"blades").size() == 3,
			"Брант: BURN on the clash squad at the start and every 1 s (%d)" % vc.status_of(4, &"burn").size())
	# Довбуш (tier IV): the bartka through 2 squads <= 7 u, the armoured first, 1.5 + add_ii each, cd 4 s.
	var per := 1.5 + float(ChampionKinds.twist("dovbush")["add_ii"])
	var vd := TwistView.new()
	vd.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 50.0}, {"id": 2, "d": 5.0, "x": 0.0, "n": 50.0, "armored": true},
			{"id": 3, "d": 6.0, "x": 0.0, "n": 50.0}, {"id": 4, "d": 4.0, "x": 1.8, "n": 50.0}]
	var db := _mem("dovbush", 4, 1.5, 60.0)
	ChampionKinds.step(vd, [db], 0.05)
	var hd := vd.hits_of(&"leap")
	_ok(hd.size() == 2 and int(hd[0][0]) == 2 and int(hd[1][0]) == 1 and is_equal_approx(float(hd[0][1]), per)
			and is_equal_approx(float(db["cd"]), 4.0),
			"Довбуш: the armoured squad first, then the nearest; %.2f each; cd 4 s (%s)" % [
			per, str(hd)])
	_ok(vd.status_of(1, &"stagger").size() == 1 and vd.status_of(2, &"stagger").size() == 1
			and vd.status_of(4, &"stagger").size() == 1 and vd.status_of(3, &"stagger").is_empty()
			and vd.twists(&"bartka").size() == 1, "Довбуш: STAGGER on both, tier III also <= 1 u of the path")
	var v1 := TwistView.new()
	v1.squads = [{"id": 7, "d": 5.0, "x": 0.0, "n": 50.0}]
	ChampionKinds.step(v1, [_mem("dovbush", 4, 1.5, 60.0)], 0.05)
	var h1 := v1.hits_of(&"leap")
	_ok(h1.size() == 2 and int(h1[0][0]) == 7 and int(h1[1][0]) == 7,
			"Довбуш: one squad in range: the bartka strikes it again on its way back (%s)" % str(h1))


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
	_ok(vd.twists(&"harpoon").size() == 1 and th.size() == 1 and int(th[0][0]) == 2
			and is_equal_approx(float(th[0][1]), 1.0),
			"Дара: the 3rd shot (2 arrows) stitches the partner for 50%% (%s)" % str(th))
	var tt: Array = vd.tethers[0] if vd.tethers.size() == 1 else []
	_ok(tt.size() == 5 and int(tt[0]) == 1 and int(tt[1]) == 2 and is_equal_approx(float(tt[2]), 0.5)
			and is_equal_approx(float(tt[3]), 3.0) and int(tt[4]) == vd.hits.size(),
			"Дара: the harpoon tethers 1 to 2 (KindView.tether, 50%%, 3 s) after the partner's share (%s)" % str(
			vd.tethers))
	_ok(vd.grounds.size() == 1 and int(vd.grounds[0][0]) == 1 and is_equal_approx(float(vd.grounds[0][1]), 1.5),
			"Дара: the harpooned Flying squad is grounded 1.5 s")
	_shots(vd, da, 5)
	_ok(vd.hits_of(&"tether").size() == 1 and vd.tethers.size() == 1,
			"Дара: her later hits are never mirrored by the rule (the view's tether shares them; %d)" %
			vd.hits_of(&"tether").size())
	var short: Dictionary = ChampionKinds.twist("dara").duplicate()
	short["tether_s"] = 1.0
	var vl := TwistView.new()
	vl.squads = vd.squads.duplicate(true)
	var dl := _mem("dara", 4, 1.0, 33.0, short)
	_shots(vl, dl, 3)
	_ok(vl.tethers.size() == 1 and is_equal_approx(float((vl.tethers[0] as Array)[3]), 1.0),
			"Дара: the tether lasts tether_s (%s)" % str(vl.tethers))


# ------------------------------------------------------------------ mages

func _test_mages() -> void:
	print("== Mages: Тая, Менгір, Тарас")
	var v := TwistView.new()
	v.squads = [{"id": 1, "d": 5.0, "x": 0.0, "n": 99.0}, {"id": 2, "d": 6.8, "x": 0.0, "n": 99.0}]
	ChampionKinds.step(v, [_mem("taya", 2, 4.0, 28.0)], 0.05)
	var lk := float(ChampionKinds.twist("taya")["lull_strength"])
	var lulled := 0
	for h: Array in v.holds:
		if is_equal_approx(float(h[1]), 1.5) and is_equal_approx(float(h[2]), lk):
			lulled += 1
	_ok(v.holds.size() == 2 and lulled == 2 and v.twists(&"lull").size() == 1 and v.events[0][0] == &"champ_spell",
			"Тая: every squad of the dust burst is lulled 1.5 s at strength %.3f (hold) (%s)" % [lk, str(v.holds)])
	# Менгір (tier IV, right slot): the circle Brands the squads in it; the foe in it costs x (1 - circle_cut).
	var cc := float(ChampionKinds.twist("menhir")["circle_cut"])
	var vm := TwistView.new()
	vm.squads = [{"id": 1, "d": 4.0, "x": 0.0, "n": 99.0}, {"id": 2, "d": 9.0, "x": 0.0, "n": 99.0}]
	var me := _mem("menhir", 4, 5.0, 33.0)
	ChampionKinds.step(vm, [me], 0.05)
	_ok(vm.twists(&"circle").size() == 1 and vm.status_of(1, &"seal").size() >= 2 and int(me["cut_id"]) == 1,
			"Менгір: the strike carves a circle that Brands the squad in it")
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 1.0), "Менгір: no cut outside a clash")
	vm.fight = true
	ChampionKinds.step(vm, [me], 0.05)
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 1.0 - cc) and cc > 0.0,
			"Менгір: the foe in the circle deals -%.1f%% clash damage" % (100.0 * cc))
	vm.fight = false
	_run_for(vm, [me], 8.5)
	vm.fight = true
	vm.squads[1]["n"] = 0.0
	vm.squads.append({"id": 5, "d": 4.0, "x": 2.4, "n": 99.0})
	vm.squads[0]["n"] = 0.0
	ChampionKinds.step(vm, [me], 0.05)
	_ok(is_equal_approx(ChampionKinds.clash_loss_mult([me]), 1.0),
			"Менгір: a squad never in the circle deals full damage")
	# Тарас (rear): the book at the nearest squad (not the densest); pages cut on into the next <= 3 u.
	var vt := TwistView.new()
	vt.squads = [{"id": 1, "d": 3.0, "x": 0.0, "n": 5.0}, {"id": 2, "d": 5.8, "x": 0.3, "n": 99.0},
			{"id": 3, "d": 9.0, "x": 0.0, "n": 99.0}, {"id": 4, "d": 9.6, "x": 0.0, "n": 99.0}]
	ChampionKinds.step(vt, [_mem("taras", 1, 4.0, 33.0)], 0.05)
	var sp := vt.hits_of(&"spell")
	var pg := vt.hits_of(&"pages")
	_ok(sp.size() == 1 and int(sp[0][0]) == 1, "Тарас: the book hits the nearest squad (%s)" % str(sp))
	_ok(pg.size() == 1 and int(pg[0][0]) == 2 and is_equal_approx(float(pg[0][1]), 2.0)
			and vt.status_of(2, &"seal").size() == 1 and vt.twists(&"pages").size() == 1,
			"Тарас: the pages take 50%% from the next squad <= 3 u, BRAND (%s)" % str(pg))
	var vtb := TwistView.new()
	vtb.squads = vt.squads.duplicate(true)
	for s: Dictionary in vtb.squads:
		s["n"] = 99.0 if int(s["id"]) != 1 else 5.0
	ChampionKinds.step(vtb, [_mem("taras", 1, 4.0, 33.0, {})], 0.05)
	_ok(int(vtb.hits_of(&"spell")[0][0]) == 3 and vtb.hits_of(&"pages").is_empty(),
			"bare Mage: the densest squad, no pages")


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
	_ok(is_equal_approx(float(nimb["cd"]), 5.0) and is_zero_approx(float(nimb["catch_cd"])),
			"Німб: the catch shares the Block cooldown (5 s)")
	ChampionKinds.absorb_hazard(v, [nimb], 30, &"blade", 4.0, 100.0, 2.0)
	_ok(int(nimb["blocks"]) == 1, "Німб: no hazard Block right after a catch (the shared cd)")
	_run_for(v, [nimb], 5.05)
	ChampionKinds.absorb_hazard(v, [nimb], 31, &"blade", 4.0, 100.0, 2.0)
	_ok(int(nimb["blocks"]) == 2, "Німб: a hazard Block once the cd ran out")
	_run_for(v, [nimb], 5.05)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [nimb], 10, 1.0), 1.0),
			"Німб: a shot at the far flank (beyond the catch radius) is not caught")
	var n3 := _mem("nimb", 3, 2.0, 76.0)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [n3], 9, 1.0), 1.0), "below tier IV: no catch")
	var ivo := _mem("ivo", 1, 3.0, 60.0)
	_ok(is_equal_approx(ChampionKinds.absorb_turret(v, [ivo], 9, 1.0), 1.0),
			"a Guardian without the catch never takes a shot")
	var vs := TwistView.new()
	vs.hazards = v.hazards.duplicate(true)
	var own := _mem("nimb", 4, 2.0, 76.0, {"catch_r": 1.6, "catch_cd": 5.0, "catch_tier": 4})
	ChampionKinds.step(vs, [own], 0.05)
	ChampionKinds.absorb_turret(vs, [own], 9, 1.0)
	_ok(is_equal_approx(float(own["catch_cd"]), 5.0) and float(own["cd"]) == 0.0,
			"with catch_cd the catch keeps its own timer")
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


# ------------------------------------------------------------------ SimKindView books (the budget's inputs)

## What the budget table adds up is booked once: a champion's own hit on a MARKed squad returns the whole
## drop (MARK's extra included) and leaves State.st_kills alone; a hero / machine hit books the extra there;
## a tether's share is booked there; a ward absorbs only with one whole charge of one kind.
func _test_sim_books() -> void:
	print("== SimKindView books: MARK once, tether shares, wards")
	var lv := _level([{"kind": "squad", "d": 30.0, "x": 0.0, "value": 50, "w": 2.4},
			{"kind": "squad", "d": 32.0, "x": 1.0, "value": 50, "w": 2.4}], 90.0)
	var s := LevelSim.start_state(lv, "bolt", 60, {"profile": _prof([])})
	var ids: Array[int] = []
	for i in lv.items.size():
		if lv.kind[i] == LevelSim.K.SQUAD:
			ids.append(i)
	var v := SimKindView.new(lv, s)
	v.status(ids[0], &"mark", 3.0)
	var got := v.hit(ids[0], 4.0)
	_ok(got == 5 and is_zero_approx(s.st_kills),
			"a champion hit of 4 on a MARKed squad: drop %d (want 5), st_kills %.2f (want 0)" % [got, s.st_kills])
	LevelSim._hurt_vs(lv, s, ids[0], 4.0)
	_ok(is_equal_approx(s.st_kills, 1.0), "a hero / machine hit of 4 books MARK's extra 1 (%.2f)" % s.st_kills)
	var hp1 := s.hp[ids[1]]
	v.tether(ids[0], ids[1], 0.5, 3.0)
	v.hit(ids[0], 4.0)
	_ok(is_equal_approx(hp1 - s.hp[ids[1]], 2.5) and is_equal_approx(s.st_kills, 3.5),
			"a tether passes 50%% of the 5 on (%.2f) and books it (st_kills %.2f, want 3.5)" % [hp1 - s.hp[ids[1]],
			s.st_kills])
	LevelSim.grant_ward(s, &"blade", 0.5, 5.0)
	LevelSim.grant_ward(s, &"contact", 0.5, 5.0)
	var split := v.absorb(&"blade")
	LevelSim.grant_ward(s, &"contact", 0.5, 5.0)
	var whole := v.absorb(&"blade")
	_ok(not split and whole and is_equal_approx(LevelSim.ward_left(s, &"blade"), 0.5),
			"wards: half a blade + half a contact charge absorb nothing, a whole contact charge does (%s %s, %.2f)" %
			[split, whole, LevelSim.ward_left(s, &"blade")])


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


## CPU of the rules (§10.6: Champions.step <= 0.25 ms in the Run, measured there by Run.champ_perf):
## ChampionKinds.step over a SimKindView on real level states, a four-champion team with its twists
## against the same team as bare templates. Printed, plus a loose bound (twists < 3x the templates).
func _test_cost() -> void:
	print("== cost of ChampionKinds.step (LevelSim view, 4 champions)")
	var lv := LevelSim.make_level(LevelGen.build(47, Balance.START_ARMY), 47)
	var rows := [_stats("menhir", 5), _stats("otto", 5), _stats("olena", 5), _stats("dara", 5)]
	var us := {}
	for tag: String in ["bare", "twists"]:
		var team: Array = []
		for r: Dictionary in rows:
			var row := r.duplicate()
			if tag == "bare":
				row["twist"] = {}
			team.append(row)
		var s := LevelSim.start_state(lv, "bolt", 60, {"profile": _prof(team)})
		var path := LevelSim.lazy_path()
		var total := 0
		var steps := 0
		while s.mode != LevelSim.Mode.WON and s.mode != LevelSim.Mode.LOST and s.t < 120.0:
			# One step of the rules on a copy (the run itself advances untouched).
			var c := s.copy()
			var view := SimKindView.new(lv, c)
			var t0 := Time.get_ticks_usec()
			ChampionKinds.step(view, c.champs.members, LevelSim.DT)
			total += Time.get_ticks_usec() - t0
			steps += 1
			LevelSim.step(lv, s, path, LevelSim.DT)
		us[tag] = float(total) / maxf(float(steps), 1.0)
		print("  %-6s %.1f us per step over %d steps" % [tag, float(us[tag]), steps])
	_ok(float(us["twists"]) < 3.0 * float(us["bare"]) + 5.0, "the twists cost < 3x the bare templates per step (%.1f vs %.1f us)" % [
			float(us["twists"]), float(us["bare"])])


# ------------------------------------------------------------------ budget (§4.1, §4.3)

## The budget table (see the header). With --sweep=id:field=v1,v2 only that champion, once per value.
func _budget() -> void:
	var from := maxi(1, int(_args.get("from", str(P0_SPREAD["from"]))))
	var to := maxi(from, int(_args.get("to", str(P0_SPREAD["to"]))))
	var step := maxi(1, int(_args.get("step", str(P0_SPREAD["step"]))))
	var heroes := str(_args.get("hero", P0_SPREAD["hero"])).split(",", false)
	# KIT_P0 was measured on P0_SPREAD: only there is column (a) comparable with it.
	var on_p0 := from == int(P0_SPREAD["from"]) and to == int(P0_SPREAD["to"]) and step == int(P0_SPREAD["step"]) \
			and ",".join(heroes) == str(P0_SPREAD["hero"])
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
	print("== budget: %s, levels %d..%d step %d, EXPECTED profile, one-champion teams (phase %d)" % [",".join(heroes),
			from, to, step, EconData.heroes_phase()])
	# Per level: the shared no-team path and baseline, then each variant on that path.
	var cases: Array = []
	var army := Balance.start_army(0)
	# --paths=FILE keeps the planner's no-team paths between runs (they do not depend on the twists).
	var cache_file := str(_args.get("paths", ""))
	var cache := {}
	if cache_file != "" and FileAccess.file_exists(cache_file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_file))
		cache = parsed if parsed is Dictionary else {}
	var fresh := 0
	for hero in heroes:
		for level in range(from, to + 1, step):
			var lv := LevelSim.make_level(_frozen(LevelGen.build(level, Balance.START_ARMY)), level)
			var acc := Meta.synthetic_account(level, "expected")
			var prof := LevelSim.profile_from_account(acc, level, "expected")
			var key := "%s:%d:frozen" % [hero, level]
			var path := PackedFloat32Array(cache.get(key, []))
			if path.is_empty():
				var bp: Dictionary = LevelSim.best_path(lv, hero, army, {"profile": prof})
				path = bp["path"]
				cache[key] = Array(path)
				fresh += 1
			var s0 := LevelSim.simulate(lv, hero, army, path, {"profile": prof})
			cases.append({"hero": hero, "level": level, "lv": lv, "prof": prof, "path": path,
					"cl": ChampionsMeta.level(acc), "t": s0.t})
	if cache_file != "" and fresh > 0:
		var f := FileAccess.open(cache_file, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(cache))
			f.close()
	var t_total := 0.0
	for cs: Dictionary in cases:
		t_total += float(cs["t"])
	print("  %d runs (heroes x levels), %d planner paths in %.1f s, %.0f s of play" % [cases.size(), fresh,
			float(Time.get_ticks_msec() - t0) / 1000.0, t_total])
	if _args.has("probe"):
		_probe_levels(cases, ids, army, str(_args["probe"]).split(",", false))
		return
	if _args.has("tiers"):
		_tier_steps(cases, ids, army, t_total)
		return
	if not sweep_vals.is_empty():
		# --set=field=v;field=v: fixed overrides of the same twist row under the sweep.
		var tw0: Dictionary = ChampionKinds.twist(sweep_id).duplicate()
		for pair in str(_args.get("set", "")).replace("+", ";").split(";", false):
			var fv := pair.split("=", true, 1)
			if fv.size() == 2:
				tw0[fv[0]] = str_to_var(fv[1])
		for v: Variant in sweep_vals:
			var tw := tw0.duplicate()
			tw[sweep_key] = v
			var r := _measure(sweep_id, cases, army, tw)
			print("  SWEEP %s %s=%s %s ratio %.4f (template %.4f/s, twist %.4f/s)" % [sweep_id, sweep_key, str(v),
					str(_args.get("set", "")), float(r["ratio"]), float(r["tpl"]) / t_total, float(r["twist"]) / t_total])
		return
	print("  value / s = the champion's kills + heals + soldiers saved + structure damage + its statuses' kills and")
	print("  its holds' spared soldiers, per second of play (the aura is the same in every column and left out);")
	print("  ratio = twist / template, target 1 +- %.2f; statuses + holds = that part of the twist column" %
			ChampionData.CHAMP_KIT_TOL)
	if on_p0:
		print("  P0_c = ChampionData.KIT_P0 (the template column as measured on this spread);")
		print("  KIT_INDEX = twist / P0_c, target 1 +- %.2f; template / P0_c past that band = a stale row (STALE)" %
				ChampionData.CHAMP_KIT_TOL)
	else:
		print("  (not the KIT_P0 spread L%d-%d step %d %s: P0_c and KIT_INDEX are shown, not checked)" % [
				int(P0_SPREAD["from"]), int(P0_SPREAD["to"]), int(P0_SPREAD["step"]), str(P0_SPREAD["hero"])])
	print("  %-8s %-8s %-4s %-5s | %8s %8s %8s | %8s | %7s | %8s %8s" % ["id", "class", "tier", "slot", "template",
			"no twist", "twist", "st+hold", "ratio", "P0_c", "KIT_IDX"])
	var tol := ChampionData.CHAMP_KIT_TOL
	var misses: PackedStringArray = PackedStringArray()
	var unmeasured: PackedStringArray = PackedStringArray()
	var stale: PackedStringArray = PackedStringArray()
	var p0_now := {}
	var within := 0
	for id in ids:
		var r := _measure(id, cases, army, ChampionKinds.twist(id))
		var row: Dictionary = ChampionData.CHAMPIONS[id]
		var ratio := float(r["ratio"])
		var ok := absf(ratio - 1.0) <= tol + 1e-9
		var tpl := float(r["tpl"]) / t_total
		var p0 := float(ChampionData.KIT_P0.get(id, 0.0))
		var kit_index := float(r["twist"]) / t_total / maxf(p0, 1e-6)
		p0_now[id] = tpl
		# The twist changed nothing LevelSim models: not measured, so never a pass (see the header). A twist
		# carried by the champion's own Action (Іво's barricade damage) shows in the no-twist column instead.
		var eps := 1e-6 * maxf(absf(float(r["plain"])), 1.0)
		var same := absf(float(r["twist"]) - float(r["plain"])) <= eps \
				and absf(float(r["plain"]) - float(r["tpl"])) <= eps
		var fresh_p0 := absf(tpl / maxf(p0, 1e-6) - 1.0) <= tol + 1e-9
		var ok_index := absf(kit_index - 1.0) <= tol + 1e-9
		var verdict := "UNMEASURED" if same else ("" if ok and (ok_index or not on_p0) else "MISS")
		if on_p0 and not fresh_p0:
			verdict = (verdict + " STALE").strip_edges()
			stale.append("%s x%.3f" % [id, tpl / maxf(p0, 1e-6)])
		if same:
			unmeasured.append(id)
		elif not ok or (on_p0 and not ok_index):
			misses.append("%s %s %.3f" % [id, "ratio" if not ok else "KIT_INDEX", ratio if not ok else kit_index])
		else:
			within += 1
		print("  %-8s %-8s %-4d %-5s | %8.4f %8.4f %8.4f | %8.4f | %7.4f | %8.4f %8.4f %s" % [id, str(row["class"]),
				ChampionData.action_tier(id), str(row["slot"]), tpl, float(r["plain"]) / t_total,
				float(r["twist"]) / t_total, float(r["twist_st"]) / t_total, ratio, p0, kit_index, verdict])
		if not same:
			_ok(ok, "budget %s: twist / template %.4f within 1 +- %.2f" % [id, ratio, tol])
		if on_p0:
			_ok(fresh_p0, "P0_c %s: template %.4f / s vs KIT_P0 %.4f within 1 +- %.2f (else re-measure: --emit)" % [id,
					tpl, p0, tol])
			if not same:
				_ok(ok_index, "KIT_INDEX %s: twist / P0_c %.4f within 1 +- %.2f" % [id, kit_index, tol])
	var verdict_all := "MISS" if not misses.is_empty() else ("STALE" if not stale.is_empty() else (
			"UNMEASURED" if not unmeasured.is_empty() else "PASS"))
	var head := "BUDGET_TABLE %s: %d champions, %d runs, %d measured within, %d misses%s, %d unmeasured%s, P0_c %s"
	print((head + " (%.1f s)") % [verdict_all, ids.size(), cases.size(), within, misses.size(),
			"" if misses.is_empty() else " [" + ", ".join(misses) + "]", unmeasured.size(),
			"" if unmeasured.is_empty() else " [" + ", ".join(unmeasured) + "]",
			("not checked (another spread)" if not on_p0 else ("%d stale [%s]" % [stale.size(), ", ".join(stale)]
			if not stale.is_empty() else "in step")), float(Time.get_ticks_msec() - t0) / 1000.0])
	if _args.has("emit"):
		_emit_p0(p0_now, on_p0)


## --tiers: each champion's bare class template (its own gem f0 stats, the EXPECTED account's Champion
## Level) at Action tier I up to its own tier: value / s and what each tier rule added, as a share of the
## tier I template (§2.3 designs every Action tier rule at +4%). A report, no verdict.
func _tier_steps(cases: Array, ids: Array[String], army: int, t_total: float) -> void:
	print("  tier rules: template value / s at tier I..its own; step = (tier k - tier k-1) / tier I (design +0.04)")
	for id in ids:
		var cls := str(ChampionData.CHAMPIONS[id]["class"])
		var top := ChampionData.action_tier(id)
		var vals: Array[float] = []
		for k in range(1, top + 1):
			var sum := 0.0
			for cs: Dictionary in cases:
				var hero := str(cs["hero"])
				var tpl := _stats(id, int(cs["cl"]))
				tpl["twist"] = {}
				tpl["tier"] = k
				tpl["action"] = float(TEMPLATE_ACTION[cls]) * float(tpl["mult"])
				var prof: Dictionary = (cs["prof"] as Dictionary).duplicate()
				prof["team"] = {"hero": hero, "champions": [tpl], "synergy": {}, "synergy_ids": []}
				var s := LevelSim.simulate(cs["lv"], hero, army, cs["path"], {"profile": prof})
				var m: Dictionary = s.champs.members[0]
				sum += float(m["kills"]) + float(m["heals"]) + float(m["saved"]) + float(m["struct"]) + s.st_kills \
						+ s.hold_saved
			vals.append(sum / t_total)
		var cells: PackedStringArray = PackedStringArray()
		for k in vals.size():
			var step := "" if k == 0 else " (%+.3f)" % ((vals[k] - vals[k - 1]) / maxf(vals[0], 1e-6))
			cells.append("%s %.4f%s" % [["I", "II", "III", "IV"][k], vals[k], step])
		print("  TIERS %-8s %-8s %s" % [id, cls, " | ".join(cells)])


## --emit: the measured template column as the heroes_tables.py CHAMP_P0 line (roster order; a champion
## left out by --only keeps its KIT_P0 value).
func _emit_p0(p0_now: Dictionary, on_p0: bool) -> void:
	var items: PackedStringArray = PackedStringArray()
	for id: String in ChampionData.CHAMPION_ORDER:
		items.append("\"%s\": %.4f" % [id, float(p0_now.get(id, ChampionData.KIT_P0.get(id, 0.0)))])
	var lines: PackedStringArray = PackedStringArray()
	var cur := "CHAMP_P0 = {"
	for i in items.size():
		var piece := items[i] + ("}" if i == items.size() - 1 else ",")
		if cur.length() + 1 + piece.length() > 116:
			lines.append(cur)
			cur = " ".repeat(12) + piece
		else:
			cur += ("" if cur.ends_with("{") else " ") + piece
	lines.append(cur)
	print("CHAMP_P0_EMIT%s" % ("" if on_p0 else " (NOT the KIT_P0 spread: do not paste)"))
	for ln in lines:
		print(ln)


## Sums over `cases` of each variant's value (the member's kills + heals + saved + struct + the State's
## st_kills + hold_saved, all the lone champion's): tpl (the bare class template), plain (the champion's
## own Action, no twist), twist (with `tw`); twist_st = the statuses' and holds' part of twist.
func _measure(id: String, cases: Array, army: int, tw: Dictionary) -> Dictionary:
	var out := {"tpl": 0.0, "plain": 0.0, "twist": 0.0, "twist_st": 0.0}
	var cls := str(ChampionData.CHAMPIONS[id]["class"])
	for cs: Dictionary in cases:
		var hero := str(cs["hero"])
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
			var m: Dictionary = s.champs.members[0]
			out[key] = float(out[key]) + float(m["kills"]) + float(m["heals"]) + float(m["saved"]) + float(m["struct"]) \
					+ s.st_kills + s.hold_saved
			if key == "twist":
				out["twist_st"] = float(out["twist_st"]) + s.st_kills + s.hold_saved
	out["ratio"] = float(out["twist"]) / maxf(float(out["tpl"]), 0.001)
	return out


## A LevelGen level with its gates frozen (no sway, no blink): the variants share one path, and a
## champion that shortens a clash must not meet a different gate on it (a different army downstream).
static func _frozen(def: Dictionary) -> Dictionary:
	var out := def.duplicate()
	var items: Array = []
	for it: Dictionary in def["items"]:
		if str(it.get("kind", "")) == "gate" and (it.has("move") or it.has("blink")):
			var g := it.duplicate()
			g.erase("move")
			g.erase("blink")
			items.append(g)
		else:
			items.append(it)
	out["items"] = items
	return out


## --probe=L,L: per level of the spread, the no-team run and each champion's template / twist run on
## the shared path (mode, army, kills, losses, the member's books).
func _probe_levels(cases: Array, ids: Array[String], army: int, levels: PackedStringArray) -> void:
	for cs: Dictionary in cases:
		if not levels.has(str(cs["level"])):
			continue
		var hero := str(cs["hero"])
		var base := LevelSim.simulate(cs["lv"], hero, army, cs["path"], {"profile": cs["prof"]})
		print("  PROBE %s L%d cl %d" % [hero, int(cs["level"]), int(cs["cl"])])
		_probe_line("none", base)
		for id in ids:
			var cls := str(ChampionData.CHAMPIONS[id]["class"])
			var st := _stats(id, int(cs["cl"]))
			var tpl := st.duplicate()
			tpl["twist"] = {}
			tpl["action"] = float(TEMPLATE_ACTION[cls]) * float(st["mult"])
			var noaura := tpl.duplicate()
			noaura["aura"] = 0.0
			noaura["aura_effect"] = 0.0
			for tag: String in ["template", "tpl-noaura", "twist"]:
				var row: Dictionary = {"template": tpl, "tpl-noaura": noaura, "twist": st}[tag]
				var prof: Dictionary = (cs["prof"] as Dictionary).duplicate()
				prof["team"] = {"hero": hero, "champions": [row], "synergy": {}, "synergy_ids": []}
				_probe_line("%s %s" % [id, tag], LevelSim.simulate(cs["lv"], hero, army, cs["path"], {"profile": prof}))


static func _probe_line(tag: String, s: LevelSim.State) -> void:
	var extra := ""
	if s.champs.active():
		var m: Dictionary = s.champs.members[0]
		extra = "| k %.1f h %.1f sv %.1f st %.1f hp %.0f %s | statuses %.1f holds %.1f" % [float(m["kills"]),
				float(m["heals"]), float(m["saved"]), float(m["struct"]), float(m["hp"]), "A" if bool(m["alive"]) else "X",
				s.st_kills, s.hold_saved]
	print("    %-20s mode %d army %.1f fort %.1f kills %.1f peak %.1f haz %.1f clash %.1f t %.1f casts %d %s" % [tag,
			s.mode, s.army, s.army_at_fortress, s.kills, s.peak, s.hazard_deaths, s.clash_deaths, s.t, s.casts, extra])

