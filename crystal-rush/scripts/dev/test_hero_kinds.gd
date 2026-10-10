extends Node
## Headless tests of the v3 hero kinds (heroes design §6.1-6.10, §6.28, §6.29, §10.4; phase H2): the rules of
## HeroKinds over a test-local HeroView (a KindView that records every verb), LevelSim playing every hero, and
## (with --measure) the balance table of the twelve heroes.
##
## 1. def_for: phase 0 and a Meta-1 block = exactly Balance.HEROES for the starters (the same const row);
##    phase 2 with a v3 block = the sheet's numbers x the block (dmg_mult, hp_mult, ult_rate_mult, ult_power),
##    class traits (Long sight, Bulwark), the ult at the block's form; another hero's block is rebased.
## 2. The nine new ult kinds at Form I and at their top form act as the sheet says (hits, holds, wards,
##    grounding, revives, statuses, buffs, the fx sequence start / hit / end of the contract), and the v3
##    riders of the timed starters (storm II, rift II / III).
## 3. The attack rule: the new heroes' procs (throw, pierce + comet, mend, eye, dove, focus, drones) and
##    the hero_attack fx; hero_step (the Healer revive pool, Пава's Awakening).
## 4. The §10.4 policies of all twelve kinds fire on their conditions and hold otherwise; a Meta-1 row keeps
##    the Meta-1 policy. Every v3 kind also fires in every clash and siege (the owner's rule, 10.10).
## 4b. The H2 review fixes: an ult's last step and end parts never charge the next ult (the clock stays active);
##    reveal splits gates from Phantoms; the ward kinds (wall_turret / wall_contact end with the wall, drones
##    replace their own grant) and the one spend order (KindView.WARD_SPEND) in LevelSim, over a whole Вартан
##    run; the starters' v3 attacks through HeroKinds.attack (Горан, Руді's fork, Мейра); damage gates x
##    dmg_mult; Люмен's machines buff inside bucket 2.
## 5. LevelSim plays L20, L41 and L60 with each of the 12 heroes at phase 2 (EXPECTED account, the two scripted
##    champions; one input per level: Руді's planned path, replayed by every hero) to the end: printed per hero
##    (won, army at the fortress, ult casts, attack volleys of the new heroes).
## --measure: wins and fortress army of every hero on L20-60 every 5th level (--from / --to / --step), each
##    against Руді (bolt) on the same level; a hero more than 15% off Руді's mean fortress army is flagged as a
##    balance note (numbers are generated data: the owner decides; nothing is tuned here). Printed with the ult
##    casts per run (every clash and siege, else the §10.4 policies, decide them: HeroKinds.ult_worth).
##    --levels= (empty) skips part 5.
##
##   godot --headless --path . res://scenes/dev/test_hero_kinds.tscn -- --autotest [--verbose] [--measure]
##        [--from=20] [--to=60] [--step=5] [--levels=20,41,60] [--heroes=arin,olha]
## Exit code = failures. Last line: TEST_HERO_KINDS PASS|FAIL: passed, failed, time.

const CS := preload("res://scripts/dev/champ_survival.gd")
const NEW_KINDS: Array[String] = ["arin", "eira", "iskar", "vesta", "vartan", "lumen", "pava", "sirko", "olha"]
const SIM_LEVELS: Array[int] = [20, 41, 60]
## The measure's balance note: a hero's mean fortress army this far off Руді's.
const FLAG_SHARE := 0.15
const DT := 0.05

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
	EconData.phase_override = 0
	_test_def_phase0()
	EconData.phase_override = HeroKinds.V3_PHASE
	print("== phase forced to %d" % EconData.heroes_phase())
	_test_def_v3()
	_test_shapes()
	_test_timed_riders()
	_test_attacks()
	_test_hero_step()
	_test_policies()
	_test_fallback()
	_test_end_of_ult()
	_test_reveals()
	_test_wards()
	_test_starters_v3()
	_test_damage()
	_test_sim()
	if _args.has("measure"):
		_measure()
	EconData.phase_override = old
	_ok(EconData.phase_override == old, "phase override restored")
	print("TEST_HERO_KINDS %s: %d passed, %d failed (%.1f s)" % ["PASS" if _fails == 0 else "FAIL", _passes, _fails,
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


# ------------------------------------------------------------------ the recording view

## A KindView that records every verb: squads / structures / gates live in arrays, hits lower their n / hp.
class HeroView extends KindView:
	var d := 10.0
	var a := {"n": 50.0, "x": 0.0, "d": 7.0, "radius": 2.0, "reserves": 0.0, "revive_pool": 0.0, "lost": 0.0}
	var c := HeroKinds.Clock.new()
	var fight := false
	var sieging := false
	var squads: Array = []      ## {id, d, x, n, hw, flying, armored, phantom}
	var structs: Array = []     ## {id, d, x, kind, hp, hw} (kind "blade" = a blade: never in structures_in)
	var gates: Array = []       ## {id, row, d, x, hw, kind, value, hidden}
	var members: Array = []     ## {id, alive, hp, hp_max}
	var hits: Array = []        ## [id, dmg, kind]
	var statuses: Array = []    ## [id, status, s]
	var holds: Array = []       ## [id, s, strength]
	var grounds: Array = []     ## [id, s]
	var exposes: Array = []     ## [id, add, s]
	var strips: Array = []      ## [id, s]
	var silences: Array = []    ## [id, s]
	var reveals: Array = []     ## [d0, d1, what]
	var wards: Array = []       ## [kind, charges, s, replace]
	var buffs: Array = []       ## [kind, value, s, data]
	var added: Array = []       ## [n, cause]
	var revived: Array = []     ## [id, hp]
	var areas: Array = []       ## [d0, d1, kills, breaks, gates]
	var armor := 0.0
	var events: Array = []      ## [event, data]
	var idle_hits := 0          ## hits landed while the clock was idle (in the Run they would charge the next ult)

	func distance() -> float:
		return d

	## A Meta-1 Ult Rank power the v3 rows must never use.
	func ult_power() -> float:
		return 1.7

	func clock() -> HeroKinds.Clock:
		return c

	func store_clock(p: HeroKinds.Clock) -> void:
		c = p

	func army() -> Dictionary:
		return a

	func in_fight() -> bool:
		return fight or sieging

	func siege() -> bool:
		return sieging

	func area_hit(d0: float, d1: float, kills: float, breaks: float, g: bool) -> void:
		areas.append([d0, d1, kills, breaks, g])

	func grant_armor(sec: float) -> void:
		armor = sec

	func squads_in(d0: float, d1: float, x0: float, x1: float) -> Array:
		var out: Array = []
		for sq: Dictionary in squads:
			var hw := float(sq.get("hw", 1.2))
			if float(sq["n"]) > 0.0 and float(sq["d"]) >= d0 and float(sq["d"]) <= d1 \
					and float(sq["x"]) + hw >= x0 and float(sq["x"]) - hw <= x1:
				out.append(sq.duplicate())
		return out

	func hazards_in(d0: float, d1: float) -> Array:
		var out: Array = []
		for h: Dictionary in structs:
			if str(h["kind"]) in ["crate", "fortress"]:
				continue
			if float(h["d"]) >= d0 and float(h["d"]) <= d1 and (str(h["kind"]) == "blade" or float(h["hp"]) > 0.0):
				out.append(h.duplicate())
		return out

	func structures_in(d0: float, d1: float) -> Array:
		var out: Array = []
		for h: Dictionary in structs:
			if str(h["kind"]) != "blade" and float(h["d"]) >= d0 and float(h["d"]) <= d1 and float(h["hp"]) > 0.0:
				out.append(h.duplicate())
		return out

	func gates_in(d0: float, d1: float) -> Array:
		var out: Array = []
		for g: Dictionary in gates:
			if float(g["d"]) >= d0 and float(g["d"]) <= d1:
				out.append(g.duplicate())
		return out

	func champions() -> Array:
		return members

	func hit(target_id: int, dmg: float, tags := {}) -> int:
		hits.append([target_id, dmg, tags.get("kind", &"")])
		if not c.active():
			idle_hits += 1
		for sq: Dictionary in squads:
			if int(sq["id"]) == target_id:
				var before := ceilf(maxf(float(sq["n"]) - 0.001, 0.0))
				sq["n"] = maxf(float(sq["n"]) - dmg, 0.0)
				return int(before - ceilf(maxf(float(sq["n"]) - 0.001, 0.0)))
		for h: Dictionary in structs:
			if int(h["id"]) == target_id:
				h["hp"] = float(h["hp"]) - dmg
		return 0

	func status(target_id: int, st: StringName, sec: float) -> void:
		statuses.append([target_id, st, sec])

	func hold(squad_id: int, sec: float, strength := 1.0) -> void:
		holds.append([squad_id, sec, strength])

	func ground(squad_id: int, sec: float) -> void:
		grounds.append([squad_id, sec])

	func expose(squad_id: int, add: float, sec: float) -> void:
		exposes.append([squad_id, add, sec])

	func strip(squad_id: int, sec: float) -> void:
		strips.append([squad_id, sec])

	func silence(turret_id: int, sec: float) -> void:
		silences.append([turret_id, sec])

	func reveal(d0: float, d1: float, what: StringName) -> void:
		reveals.append([d0, d1, what])

	func grant_ward(kind: StringName, charges: int, sec: float, replace := false) -> void:
		wards.append([kind, charges, sec, replace])

	func buff(kind: StringName, value: float, sec: float, data := {}) -> void:
		buffs.append([kind, value, sec, data])

	func add_soldiers(n: float, cause: StringName) -> void:
		added.append([n, cause])
		a["n"] = float(a["n"]) + n

	func revive_champion(id: StringName, hp_frac: float) -> bool:
		for m: Dictionary in members:
			if str(m["id"]) == String(id) and not bool(m["alive"]):
				m["alive"] = true
				revived.append([String(id), hp_frac])
				return true
		return false

	func fx(event: StringName, data := {}) -> void:
		events.append([event, data])

	# ---- queries of the record

	func dealt(id: int, kind := &"") -> float:
		var t := 0.0
		for h: Array in hits:
			if int(h[0]) == id and (kind == &"" or h[2] == kind):
				t += float(h[1])
		return t

	func n_hits(id: int, kind := &"") -> int:
		var n := 0
		for h: Array in hits:
			if int(h[0]) == id and (kind == &"" or h[2] == kind):
				n += 1
		return n

	func st_count(id: int, st: StringName) -> int:
		var n := 0
		for e: Array in statuses:
			if int(e[0]) == id and e[1] == st:
				n += 1
		return n

	func st_len(id: int, st: StringName) -> float:
		for e: Array in statuses:
			if int(e[0]) == id and e[1] == st:
				return float(e[2])
		return -1.0

	## The SHAPE_FX phases in order.
	func phases() -> Array:
		var out: Array = []
		for e: Array in events:
			if e[0] == HeroKinds.SHAPE_FX and (e[1] as Dictionary).get("kind", &"") != &"field" \
					and (e[1] as Dictionary).get("kind", &"") != &"rivets":
				out.append(str((e[1] as Dictionary)["phase"]))
		return out

	func count(event: StringName) -> int:
		var n := 0
		for e: Array in events:
			if e[0] == event:
				n += 1
		return n


## A v3 block of hero `id` at ult form `form` with every multiplier 1 (the sheet's own numbers) or `m`.
static func _block(id: String, form: int, m := 1.0, atk_rank := 1) -> Dictionary:
	return {"id": id, "lvl": 1, "dmg_mult": m, "hp_mult": m, "ult_rate_mult": m, "ult_power": m, "ult_rank": 1,
			"ult_form": form, "attack_rank": atk_rank, "awakened": 1}


static func _def(id: String, form: int, atk_rank := 1) -> Dictionary:
	return HeroKinds.def_for(id, _block(id, form, 1.0, atk_rank))


static func _sq(id: int, d: float, x: float, n := 100.0, more := {}) -> Dictionary:
	var out := {"id": id, "d": d, "x": x, "n": n, "hw": 0.5, "flying": false, "armored": false, "phantom": false}
	out.merge(more, true)
	return out


static func _st(id: int, d: float, x: float, kind: String, hp := 100.0, hw := 0.5) -> Dictionary:
	return {"id": id, "d": d, "x": x, "kind": kind, "hp": hp, "hw": hw}


static func _gate(id: int, d: float, x: float, op := "+", value := 5.0, hidden := false) -> Dictionary:
	return {"id": id, "row": int(d), "d": d, "x": x, "hw": 1.0, "kind": op, "value": value, "hidden": hidden}


## Casts the ult of `def` on `v` and steps it until it ends (or `secs`), the hero running `speed` u/s.
static func _play(v: HeroView, def: Dictionary, secs := 10.0, speed := 0.0) -> void:
	var kind := HeroKinds.ult_kind(str(def["kind"]))
	var u: Dictionary = def["ult"]
	HeroKinds.ult_cast(v, kind, u)
	var t := 0.0
	while v.c.active() and t < secs:
		v.d += speed * DT
		HeroKinds.ult_step(v, kind, u, DT)
		t += DT


# ------------------------------------------------------------------ 1. def_for

func _test_def_phase0() -> void:
	print("== def_for at phase 0")
	for id: String in Balance.HERO_ORDER:
		_ok(is_same(HeroKinds.def_for(id, {}), Balance.HEROES[id]), "%s: no block = Balance.HEROES (the same row)" % id)
		_ok(is_same(HeroKinds.def_for(id, {"id": id, "lvl": 5, "dmg_mult": 1.2, "ult_rank": 2}), Balance.HEROES[id]),
				"%s: a Meta-1 block = Balance.HEROES" % id)
		_ok(is_same(HeroKinds.def_for(id, _block(id, 2, 1.5)), Balance.HEROES[id]), "%s: a v3 block at phase 0 = Balance" % id)
	var arin := HeroKinds.def_for("arin", {})
	_ok(HeroKinds.scaled(arin) and float(arin["damage"]) == 3.0 and float(arin["hp"]) == 26.0,
			"a hero without a Balance row gets its Lv1 v3 row even at phase 0 (dev tools)")


func _test_def_v3() -> void:
	print("== def_for at phase 2")
	for id: String in Balance.HERO_ORDER:
		_ok(is_same(HeroKinds.def_for(id, {"id": id, "lvl": 5, "dmg_mult": 1.2}), Balance.HEROES[id]),
				"%s: a Meta-1 block still = Balance.HEROES at phase 2" % id)
	var b := {"id": "bolt", "lvl": 10, "dmg_mult": 1.5, "hp_mult": 1.2, "ult_rate_mult": 1.1, "ult_power": 1.3,
			"ult_rank": 3, "ult_form": 2, "attack_rank": 1}
	var bolt := HeroKinds.def_for("bolt", b)
	var u: Dictionary = bolt["ult"]
	_ok(HeroKinds.scaled(bolt) and is_equal_approx(float(bolt["damage"]), 1.5) and is_equal_approx(float(bolt["hp"]), 14.0 * 1.2),
			"bolt v3: damage 1 x dmg_mult, hp 14 x hp_mult (%s, %s)" % [bolt["damage"], bolt["hp"]])
	_ok(is_equal_approx(float(bolt["range"]), 17.0), "bolt v3: range 15 + Long sight 2 (%s)" % bolt["range"])
	_ok(is_equal_approx(float(u["kills"]), 5.0 * 1.3) and is_equal_approx(float(u["breaks"]), 3.0 * 1.3)
			and is_equal_approx(float(u["charge"]), 35.0 / 1.1) and is_equal_approx(float(u["power"]), 1.3),
			"bolt v3 ult: kills / breaks x ult_power, charge / ult_rate_mult (%s)" % u)
	_ok(int(u["form"]) == 2 and is_equal_approx(float(u["flying_mult"]), 1.5) and u.has("statuses"),
			"bolt v3 ult at form II carries the Ranger rule")
	_ok(str(bolt["aspect"]) == "forked_fox" and float(bolt["corridor"]) == 0.8 and str(u["icon"]) == "storm",
			"bolt v3 keeps its Meta-1 aspect, corridor and icon")
	var titan := HeroKinds.def_for("titan", _block("titan", 1, 1.0))
	_ok(is_equal_approx(float(titan["hp"]), 32.0 * 1.5), "titan v3: Bulwark x1.5 hp (%s)" % titan["hp"])
	var seer := HeroKinds.def_for("seer", _block("seer", 3, 1.0))
	_ok(bool(seer.get("reveal_row", false)) and float(seer["charge_mult"]) == 1.5 and int(seer["targets"]) == 2
			and float(seer["hp"]) == 18.0, "seer v3: row reveal, charge gates x1.5, 2 orbs, kit hp 18")
	var lumen := HeroKinds.def_for("lumen", _block("lumen", 5, 1.2))
	var lu: Dictionary = lumen["ult"]
	_ok(int(lu["form"]) == 5 and lu.has("buff") and (lu["status_at"] as Dictionary).has("cast")
			and is_equal_approx(float((lu["extra"] as Dictionary)["kills"]), 4.0 * 1.2),
			"lumen form V: buff, status at the cast, the extra's kills x ult_power")
	var vartan := HeroKinds.def_for("vartan", _block("vartan", 4, 2.0))
	_ok(is_equal_approx(float(vartan["ult"]["wall_hp"]), 60.0) and float(vartan["ult"]["contact_breaks"]) == 10.0,
			"vartan: wall_hp x ult_power, contact_breaks never scales")
	# Another hero's block (a dev run fielding Арін on Руді's account): rebased onto Арін's native gem.
	var arin := HeroKinds.def_for("arin", b)
	var lad := Ladder.mult("C", "C", 0)
	_ok(str(arin["kind"]) == "arin" and is_equal_approx(float(arin["damage"]), 3.0 * lad * (1.0 + Ladder.LV_DMG * 9.0)),
			"arin on bolt's block: rebased (Lv10, Quartz) (%s)" % arin["damage"])
	_ok(int(arin["ult"]["form"]) == 1, "arin: Quartz caps the ult at form I")
	for id: String in HeroData.HERO_ORDER:
		var row := HeroKinds.def_for(id, _block(id, 9))
		var ok := HeroKinds.KINDS.has(id) and row.has("ult") and HeroKinds.ULTS.has(StringName(str(HeroData.HEROES[id]["ult"])))
		ok = ok and int(row["ult"]["form"]) == HeroData.ult_top_form(str(HeroData.HEROES[id]["ult"]))
		ok = ok and str(row["attack"]) == str(HeroData.ATTACKS[id]["pattern"])
		_ok(ok, "%s: kind row, ult shape, top form %d, attack %s" % [id, int(row["ult"]["form"]), row["attack"]])


# ------------------------------------------------------------------ 2. the nine new ult kinds

func _test_shapes() -> void:
	print("== ult shapes (Form I and the top form)")
	_anchor()
	_rime()
	_comet()
	_sunglaive()
	_forgewall()
	_spectrum()
	_eyes()
	_letter()
	_doves()


func _fx_ok(v: HeroView, what: String) -> void:
	var ph := v.phases()
	_ok(not ph.is_empty() and ph[0] == "start" and ph[ph.size() - 1] == "end" and ph.count("start") == 1
			and ph.count("end") == 1 and not v.c.active() and v.count(&"ult_cast") == 0,
			"%s: fx start .. end on the contract, the clock idle (%s)" % [what, ",".join(ph)])


func _anchor() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 18.5, 0.0), _sq(2, 19.0, 3.6), _sq(3, 30.0, 0.0)]
	v.structs = [_st(10, 17.0, 1.0, "barricade", 40.0, 1.0)]
	v.gates = [_gate(20, 18.0, -1.0)]
	_play(v, _def("arin", 1))
	_ok(v.dealt(1) == 22.0 and v.dealt(2) == 0.0 and v.dealt(3) == 0.0 and v.dealt(10) == 22.0,
			"anchor I: impact 8 u ahead r 2.5 kills 22 / breaks 22 (%s)" % str(v.hits))
	_ok(v.holds.size() == 1 and int(v.holds[0][0]) == 1 and float(v.holds[0][1]) == 3.0 and float(v.holds[0][2]) == 1.0
			and v.st_count(1, &"stagger") == 1, "anchor I: the chain holds the squad 3 s at strength 1, STAGGER")
	_ok(v.dealt(20, &"gate") == 3.0, "anchor I: gates under the impact take 3 hero hits")
	_ok(v.c.n == 1, "anchor I: one impact")
	_fx_ok(v, "anchor")
	_ok(HeroData.ult_top_form("anchor") == 1, "anchor: only form I (native Quartz)")


func _rime() -> void:
	var v := HeroView.new()
	v.c.pool = 8.0
	v.squads = [_sq(1, 12.0, 0.0), _sq(2, 23.0, 2.5), _sq(3, 26.0, 0.0)]
	v.members = [{"id": "mila", "alive": false}]
	_play(v, _def("eira", 1))
	_ok(v.dealt(1) == 4.0 and v.dealt(2) == 4.0 and v.dealt(3) == 0.0 and v.n_hits(1) == 1,
			"rime I: the wave to 14 u hits every squad once for 4 (%s)" % str(v.hits))
	_ok(v.st_count(1, &"chill") == 3 and v.st_count(2, &"chill") == 3, "rime I: 3 CHILL stacks each")
	_ok(v.added.size() == 1 and float(v.added[0][0]) == 7.0 and v.added[0][1] == &"heal" and is_equal_approx(v.c.pool, 6.0),
			"rime I: the army regains 5 + 25%% of the revive pool (8): 7, the pool pays 2 (%s)" % str(v.added))
	_ok(v.revived.is_empty(), "rime I: no revive")
	_fx_ok(v, "rime")
	var v2 := HeroView.new()
	v2.members = [{"id": "mila", "alive": true}, {"id": "otto", "alive": false}, {"id": "ivo", "alive": false}]
	_play(v2, _def("eira", 2))
	_ok(v2.revived.size() == 1 and str(v2.revived[0][0]) == "otto" and float(v2.revived[0][1]) == 0.5,
			"rime II (Healer): revives the first fallen champion at 50%% (%s)" % str(v2.revived))


func _comet() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 20.0, 0.0), _sq(2, 20.0, 2.5), _sq(3, 25.0, 0.3, 100.0, {"flying": true})]
	v.structs = [_st(10, 30.0, 0.2, "turret", 100.0, 0.45)]
	_play(v, _def("iskar", 1))
	_ok(v.c.n == 6 and v.dealt(1) == 36.0 and v.dealt(2) == 0.0 and v.dealt(3) == 36.0 and v.dealt(10) == 30.0,
			"comet I: 6 ticks of 6 kills / 5 breaks down his x (1.6 u), Flying hit (%s)" % str([v.dealt(1), v.dealt(3), v.dealt(10)]))
	_ok(v.grounds.is_empty(), "comet I: no grounding")
	_fx_ok(v, "comet")
	var v3 := HeroView.new()
	v3.squads = [_sq(1, 20.0, 0.0), _sq(2, 20.0, 2.5), _sq(3, 25.0, 0.3, 100.0, {"flying": true})]
	v3.gates = [_gate(20, 15.0, 0.0), _gate(21, 15.0, 2.5)]
	var def := _def("iskar", 3)
	HeroKinds.ult_cast(v3, &"comet", def["ult"])
	for k in 3:
		HeroKinds.ult_step(v3, &"comet", def["ult"], DT)
	v3.a["x"] = 2.5     # Comet Tail follows his x live
	for k2 in 60:
		if v3.c.active():
			HeroKinds.ult_step(v3, &"comet", def["ult"], DT)
	_ok(v3.dealt(3) == 6.0 * 1.5 * float(v3.n_hits(3)) and v3.grounds.size() == v3.n_hits(3) and float(v3.grounds[0][1]) == 2.0,
			"comet III: Flying x1.5 and grounded 2 s")
	_ok(v3.dealt(2) > 0.0 and v3.dealt(20, &"gate") >= 1.0 and v3.dealt(20, &"gate") + v3.dealt(21, &"gate") == 6.0,
			"comet III: the strike follows his x; the gate under it takes a hit per tick (%s + %s)"
			% [v3.dealt(20, &"gate"), v3.dealt(21, &"gate")])
	var painted := false
	for e: Array in v3.events:
		if e[0] == HeroKinds.SHAPE_FX and (e[1] as Dictionary).has("paint"):
			painted = true
	_ok(painted, "comet II+: the biggest squad hit is PAINTED (fx)")


func _sunglaive() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 16.0, 0.0), _sq(2, 30.0, 0.0, 200.0)]
	_play(v, _def("vesta", 1))
	_ok(v.c.n == 4 and v.dealt(1) == 40.0 and v.dealt(2) == 0.0 and v.st_count(1, &"burn") == 4,
			"sunrise I: 4 pulses of 10 on the burst 5 u ahead r 6, BURN each (%s)" % v.dealt(1))
	_ok(v.exposes.is_empty() and v.buffs.is_empty(), "sunrise I: no Warrior rule, no field")
	_fx_ok(v, "sunrise")
	var v4 := HeroView.new()
	v4.a["d"] = 15.0
	v4.squads = [_sq(1, 16.0, 0.0), _sq(2, 25.0, 0.0, 200.0)]
	v4.gates = [_gate(20, 22.0, -1.5, "-", 6.0), _gate(21, 22.0, 1.5, "+", 6.0), _gate(22, 28.0, 0.0, "-", 6.0)]
	_play(v4, _def("vesta", 4))
	_ok(v4.exposes.size() == 4 and float(v4.exposes[0][1]) == 0.2 and float(v4.exposes[0][2]) == 3.0,
			"sunrise II (Warrior): squads hit lose +20% in clashes for 3 s")
	var vol := 0
	for b: Array in v4.buffs:
		if b[0] == &"volleys" and float(b[1]) == 0.1:
			vol += 1
	_ok(vol > 0 and v4.st_count(1, &"burn") > 4, "sunrise III: the Sun Field burns squads inside, volleys +10%% (%d)" % vol)
	_ok(v4.dealt(2) == 8.0 and v4.dealt(20, &"gate") == 2.0 and v4.dealt(21) == 0.0 and v4.dealt(22) == 0.0,
			"sunrise IV: Sunstride slams the biggest hostile (8), the next row's negative gates take 2 hits")


func _forgewall() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 16.0, 0.0), _sq(2, 16.5, 0.0, 100.0, {"flying": true})]
	v.structs = [_st(10, 20.0, 0.5, "barricade", 40.0, 1.0)]
	_play(v, _def("vartan", 1), 10.0, Balance.RUN_SPEED)
	var tur := false
	var clash := false
	var contact := false
	var off := 0
	for w: Array in v.wards:
		tur = tur or (w[0] == &"wall_turret" and int(w[1]) == HeroKinds.ALL_CHARGES and float(w[2]) == 5.0
				and bool(w[3]))
		clash = clash or (w[0] == &"clash" and int(w[1]) == 30 and float(w[2]) == 5.0 and bool(w[3]))
		contact = contact or (w[0] == &"wall_contact" and int(w[1]) == 50 and bool(w[3]))
		if int(w[1]) == 0 and bool(w[3]) and HeroKinds.WALL_WARDS.has(w[0]):
			off += 1
	_ok(tur and clash, "forgewall I: every turret shot warded 5 s (wall_turret), the wall's 30 HP take the clash (%s)"
			% str(v.wards))
	_ok(v.dealt(1) == 8.0 and v.n_hits(1) == 1 and v.st_count(1, &"stagger") == 1 and v.dealt(2) == 0.0,
			"forgewall I: a squad reaching the wall loses 8 once and is Staggered; Flying passes over")
	_ok(v.dealt(10) == 10.0 and contact,
			"forgewall I: the first barricade takes 10, the army's contact is warded (wall_contact)")
	var last: Array = v.wards[v.wards.size() - 1]
	_ok(off == 3 and int(last[1]) == 0 and v.phases()[v.phases().size() - 1] == "end",
			"forgewall I: its end clears the three wall wards (replace with 0: they end with the wall)")
	_fx_ok(v, "forgewall")
	var v4 := HeroView.new()
	v4.squads = [_sq(1, 22.0, 0.0, 300.0), _sq(2, 18.5, 1.0, 300.0)]
	_play(v4, _def("vartan", 4))
	var clash4 := false
	for w2: Array in v4.wards:
		clash4 = clash4 or (w2[0] == &"clash" and int(w2[1]) == 45)
	_ok(clash4, "forgewall II (Guardian): wall HP +50% (45)")
	var rivets := 0
	for h: Array in v4.hits:
		if is_equal_approx(float(h[1]), 1.0):
			rivets += 1
	_ok(rivets >= 36 and v4.st_count(2, &"mark") > 0, "forgewall III: 4 rivets every 0.5 s with MARK (%d)" % rivets)
	_ok(v4.dealt(2) >= 8.0 + 8.0, "forgewall IV: the landslide to 10 u ahead kills 8 at the end (%s)" % v4.dealt(2))


func _spectrum() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 18.0, 0.0, 200.0, {"hw": 1.2}), _sq(2, 18.0, 3.3, 200.0), _sq(3, 40.0, 0.0)]
	v.structs = [_st(10, 22.0, 0.0, "barricade", 100.0, 1.0)]
	_play(v, _def("lumen", 1))
	_ok(v.c.n == 10 and v.dealt(1) == 40.0 and v.dealt(2) == 20.0 and v.dealt(3) == 0.0 and v.dealt(10) == 20.0,
			"spectrum I: 10 ticks; 2 per ray, a squad takes <= 2 rays (%s)" % str([v.dealt(1), v.dealt(2), v.dealt(10)]))
	_ok(v.statuses.is_empty(), "spectrum I: no BURN")
	_fx_ok(v, "spectrum")
	var v5 := HeroView.new()
	v5.squads = [_sq(1, 18.0, 0.0, 300.0, {"hw": 1.2}), _sq(2, 27.0, -2.0, 50.0)]
	v5.gates = [_gate(20, 16.0, 0.0)]
	_play(v5, _def("lumen", 5))
	_ok(v5.st_count(1, &"burn") >= 10 and v5.st_count(1, &"seal") == 1 and v5.st_count(2, &"seal") == 1,
			"spectrum II / V: BURN on every hit, the ring of light Brands every squad on the screen")
	_ok(v5.dealt(20, &"gate") == 10.0, "spectrum III: the gate in the fan takes a hit per tick")
	_ok(v5.dealt(1) == 40.0 + 4.0 and v5.dealt(2) == 4.0, "spectrum IV: Crown Shards: 4 on each of the biggest (%s)"
			% str([v5.dealt(1), v5.dealt(2)]))
	_ok(v5.buffs.size() == 1 and v5.buffs[0][0] == &"machines" and float(v5.buffs[0][1]) == 0.1 and float(v5.buffs[0][2]) == 6.0,
			"spectrum V: machines +10% for 6 s")


func _eyes() -> void:
	var v := HeroView.new()
	v.c.pool = 10.0
	v.squads = [_sq(1, 20.0, 0.0), _sq(2, 30.0, 0.0)]
	var def := _def("pava", 1)
	HeroKinds.ult_cast(v, &"eyes", def["ult"])
	for k in 80:
		v.a["lost"] = float(v.a["lost"]) + (0.25 if k < 48 else 0.0)
		if v.c.active():
			HeroKinds.ult_step(v, &"eyes", def["ult"], DT)
	_ok(v.st_count(1, &"seal") == 1 and v.st_count(2, &"seal") == 0, "eyes I: Brands every squad <= 16 u at the cast")
	_ok(v.added.size() == 1 and float(v.added[0][0]) == 11.0 and is_equal_approx(v.c.pool, 7.0),
			"eyes I: 12 lost, returns min(12, 8 + 30%% of 10) = 11, the pool pays 3 (%s)" % str(v.added))
	_fx_ok(v, "eyes")
	var v5 := HeroView.new()
	v5.c.pool = 10.0
	v5.squads = [_sq(1, 20.0, 0.0), _sq(2, 30.0, 0.0, 100.0, {"phantom": true})]
	v5.members = [{"id": "mila", "alive": false}, {"id": "otto", "alive": false}]
	var d5 := _def("pava", 5)
	HeroKinds.ult_cast(v5, &"eyes", d5["ult"])
	for k2 in 80:
		v5.a["lost"] = float(v5.a["lost"]) + (0.1 if k2 < 40 else 0.0)
		if v5.c.active():
			HeroKinds.ult_step(v5, &"eyes", d5["ult"], DT)
	_ok(v5.revived.size() == 2, "eyes V: revives ALL fallen champions (%s)" % str(v5.revived))
	_ok(v5.st_count(1, &"chill") == 3 and v5.st_count(1, &"seal") == 1, "eyes V: CHILL to FREEZE with the BRAND at the cast")
	_ok(v5.added.size() == 1 and float(v5.added[0][0]) == 8.0, "eyes III: 4 lost are recorded twice: returns 8 (%s)" % str(v5.added))
	_ok(v5.dealt(1) == 4.0 and v5.dealt(2) == 4.0 and v5.st_count(2, &"mark") == 1 and v5.st_count(1, &"mark") == 0
			and not v5.reveals.is_empty(), "eyes IV: every squad loses 4, Phantoms revealed and MARKed")


func _letter() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 14.0, 0.0), _sq(2, 24.0, 2.0), _sq(3, 26.5, 0.0)]
	v.structs = [_st(10, 20.0, -2.0, "turret", 100.0, 0.45)]
	_play(v, _def("sirko", 1))
	_ok(v.dealt(1) == 16.0 and v.dealt(2) == 16.0 and v.dealt(3) == 0.0 and v.dealt(10) == 16.0,
			"letter I: the scroll 3-15 u ahead: 16 kills / breaks (%s)" % str(v.hits))
	_ok(v.st_len(1, &"stagger") == 2.0 and v.st_count(1, &"seal") == 1, "letter I: STAGGER 2 s and BRAND")
	_ok(v.exposes.is_empty() and v.strips.is_empty() and v.buffs.is_empty(), "letter I: no form riders")
	_fx_ok(v, "letter")
	var vs := HeroView.new()
	vs.sieging = true
	vs.structs = [_st(30, 11.1, 0.0, "fortress", 500.0, 3.5)]
	_play(vs, _def("sirko", 1))
	_ok(vs.dealt(30) == 16.0, "letter I at the siege: the fortress takes the breaks")
	var v5 := HeroView.new()
	v5.squads = [_sq(1, 14.0, 0.0, 200.0), _sq(2, 27.0, 0.0, 200.0)]
	_play(v5, _def("sirko", 5))
	_ok(v5.dealt(2) == 16.0 + 8.0 and v5.dealt(1) == 16.0 + 8.0, "letter II / III: to 19 u; the Second Roar 8 more")
	_ok(v5.exposes.size() == 2 and float(v5.exposes[0][1]) == 0.2 and float(v5.exposes[0][2]) == HeroKinds.NEXT_CLASH_S,
			"letter II: +20% in their next clash")
	_ok(v5.st_count(1, &"stagger") == 2 and v5.strips.size() == 2 and float(v5.strips[0][1]) == 5.0,
			"letter III / IV: the Stagger refreshed, armour stripped 5 s")
	_ok(v5.buffs.size() == 1 and v5.buffs[0][0] == &"volley_status" and float(v5.buffs[0][2]) == 5.0
			and ((v5.buffs[0][3] as Dictionary)["statuses"] as Dictionary).has("mark"),
			"letter V: 5 s of volleys that Brand and MARK")


func _doves() -> void:
	var v := HeroView.new()
	v.squads = [_sq(1, 20.0, 1.0), _sq(2, 20.0, -3.2, 100.0)]
	v.structs = [_st(10, 30.0, 2.0, "barricade", 100.0, 1.0), _st(11, 22.0, -2.0, "turret", 100.0, 0.45),
			_st(12, 45.0, 0.0, "barricade", 100.0, 1.0)]
	v.gates = [_gate(20, 25.0, 0.0)]
	_play(v, _def("olha", 1))
	_ok(v.c.n == 3 and is_equal_approx(v.dealt(10), 18.0) and is_equal_approx(v.dealt(11), 18.0) and v.dealt(12) == 0.0,
			"doves I: 3 waves: every structure <= 30 u takes 18 (%s)" % str([v.dealt(10), v.dealt(11)]))
	_ok(v.dealt(20, &"gate") == 3.0, "doves I: the gate takes a hero hit per wave (R8)")
	_ok(is_equal_approx(v.dealt(1), 6.0) and v.dealt(2) == 0.0 and v.st_len(1, &"burn") == 3.0,
			"doves I: the squad under the flight path loses 6 in all (R4) and BURNs 3 s; one off the path none")
	_ok(v.silences.is_empty(), "doves I: no silence")
	_fx_ok(v, "doves")
	var v5 := HeroView.new()
	v5.squads = [_sq(1, 20.0, 1.0, 100.0, {"flying": true}), _sq(2, 26.0, -1.0, 300.0)]
	v5.structs = [_st(10, 30.0, 2.0, "barricade", 100.0, 1.0), _st(11, 22.0, -2.0, "turret", 100.0, 0.45)]
	_play(v5, _def("olha", 5))
	_ok(is_equal_approx(v5.dealt(1), 9.0) and not v5.grounds.is_empty() and float(v5.grounds[0][1]) == 2.0,
			"doves II: Flying on the path x1.5, grounded 2 s (%s)" % v5.dealt(1))
	_ok(v5.dealt(2) >= 8.0, "doves III: a fourth wave strikes the biggest squad (8)")
	_ok(v5.silences.size() == 1 and int(v5.silences[0][0]) == 11 and float(v5.silences[0][1]) == 3.0,
			"doves IV: the turret struck falls silent 3 s")
	_ok(is_equal_approx(v5.dealt(10), 18.0 + 12.0), "doves V: the farthest structure burns 4 s at 3 / s (%s)" % v5.dealt(10))
	_ok(v5.st_len(2, &"stagger") == 1.5, "doves V: squads <= 6 u of a struck structure Staggered 1.5 s")


func _test_timed_riders() -> void:
	print("== timed v3 riders (storm II, rift II / III) and the Meta-1 rows")
	var v := HeroView.new()
	v.squads = [_sq(1, 15.0, 0.0, 100.0, {"flying": true}), _sq(2, 15.0, 2.0)]
	var def := _def("bolt", 2)
	_play(v, def)
	var ticks := v.areas.size()
	_ok(absi(ticks - 12) <= 1 and float(v.areas[0][2]) == 5.0 and bool(v.areas[0][4]),
			"storm v3: %d ticks (about 12) of 5 at power 1 (not the view's 1.7), gates hit" % ticks)
	_ok(v.dealt(1) == 2.5 * ticks and v.grounds.size() == ticks and v.st_count(1, &"jolt") == ticks and v.st_count(2, &"jolt") == ticks,
			"storm II: Flying takes x1.5 (the extra half here), grounded, a JOLT per tick")
	_ok(v.count(&"ult_cast") == 1 and v.count(&"ult_end") == 1, "storm v3 keeps the Meta-1 fx")
	var r := HeroView.new()
	r.squads = [_sq(1, 15.0, 0.0)]
	_play(r, _def("seer", 3))
	var rv_gates := 0
	var rv_ph := 0
	for rv: Array in r.reveals:
		rv_gates += 1 if rv[2] == KindView.REVEAL_GATES and float(rv[1]) - float(rv[0]) == 30.0 else 0
		rv_ph += 1 if rv[2] == KindView.REVEAL_PHANTOMS and float(rv[1]) - float(rv[0]) == 30.0 else 0
	_ok(bool(r.areas[0][4]) and r.st_count(1, &"seal") == r.areas.size() and rv_gates == r.areas.size()
			and rv_ph == r.areas.size(),
			"rift II / III: BRAND each tick, gates hit, hidden gates and Phantoms revealed <= 30 u")
	var r1 := HeroView.new()
	_play(r1, _def("seer", 1))
	_ok(not bool(r1.areas[0][4]), "rift I (v3): no gate hits on the sheet's Form I")
	var m := HeroView.new()
	_play(m, {"kind": "bolt", "ult": Balance.HEROES["bolt"]["ult"]})
	_ok(float(m.areas[0][2]) == 5.0 * 1.7 and bool(m.areas[0][4]) and m.statuses.is_empty(),
			"a Meta-1 row keeps the view's Ult Rank power and the Meta-1 gate hits")


# ------------------------------------------------------------------ 3. attacks and hero_step

## Fires `n` volleys of `def` at the view's nearest squad (the owner's targeting stand-in).
static func _volleys(v: HeroView, def: Dictionary, n: int, targets: Array = []) -> void:
	for k in n:
		var t: Array = targets if not targets.is_empty() else [_row(v.squads[0])]
		HeroKinds.attack(v, def, t, HeroKinds.volley_shots(v, def), float(def["damage"]))


static func _row(sq: Dictionary) -> Dictionary:
	var r := sq.duplicate()
	r["kind"] = "squad"
	return r


func _test_attacks() -> void:
	print("== the attack rule (v3 heroes)")
	var v := HeroView.new()
	v.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 20.0, 1.0, 500.0)]
	var arin := _def("arin", 1)
	_volleys(v, arin, 4)
	_ok(v.dealt(1, &"attack") == 3.0 * (3.0 + 2.0) and v.dealt(2, &"attack") == 3.0 * 2.0 and v.st_count(1, &"stagger") == 3,
			"arin: swings 3 + splash 2, STAGGER each; every 4th is the Anchor Throw to the farthest x2, no splash (%s)"
			% str(v.hits))
	_ok(v.count(HeroKinds.ATTACK_FX) == 4 and str((v.events[3][1] as Dictionary)["proc"]) == "throw", "arin: hero_attack fx per volley, proc throw")
	var vi := HeroView.new()
	vi.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 18.0, 0.2, 500.0), _sq(3, 22.0, -0.2, 500.0)]
	var iskar := _def("iskar", 1)
	_volleys(vi, iskar, 6)
	_ok(vi.n_hits(1) == 6 and vi.n_hits(2) == 6 and vi.n_hits(3) == 1, "iskar: needles pierce 1; the 6th is a Comet Bolt down the corridor")
	_ok(vi.dealt(3) == 3.0 * float(iskar["damage"]) and vi.st_count(3, &"jolt") == 1, "iskar: the Comet Bolt x3 with JOLT")
	var ve := HeroView.new()
	ve.c.pool = 2.0
	ve.squads = [_sq(1, 14.0, 0.0, 500.0)]
	_volleys(ve, _def("eira", 1), 12)
	_ok(ve.added.size() == 2 and ve.added[0][1] == &"mend" and is_zero_approx(ve.c.pool), "eira: a mend chord every 6th hit from the pool")
	_ok(ve.st_count(1, &"chill") == 6, "eira: CHILL at proc 0.5 = every 2nd hit")
	var vp := HeroView.new()
	vp.c.pool = 3.0
	vp.squads = [_sq(1, 14.0, 0.0, 4.0), _sq(2, 30.0, 0.0, 500.0)]
	var pava := _def("pava", 1)
	_volleys(vp, pava, 5)
	_ok(vp.c.eyes.has(1) and vp.st_count(1, &"seal") == 5, "pava: BRAND every hit, an Eye on the 5th")
	vp.squads[0]["n"] = 0.0
	HeroKinds.hero_step(vp, pava, 0.3)
	_ok(not vp.c.eyes.has(1) and vp.added.size() == 1 and vp.added[0][1] == &"eye" and is_equal_approx(vp.c.pool, 2.0),
			"pava: the Eye's squad wiped: 1 soldier back from the pool")
	var vo := HeroView.new()
	vo.squads = [_sq(1, 14.0, 0.0, 500.0)]
	vo.structs = [_st(10, 28.0, 2.0, "barricade", 100.0), _st(11, 40.0, 0.0, "barricade", 100.0)]
	var olha := _def("olha", 1)
	_volleys(vo, olha, 6)
	_ok(vo.n_hits(1) == 5 and vo.n_hits(10) == 1 and vo.n_hits(11) == 0 and vo.st_len(10, &"burn") == 3.0,
			"olha: every 6th shot a dove to the farthest structure <= 20 u (+2 sight: 18 from her), BURN 3 s")
	var vo2 := HeroView.new()
	vo2.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 20.0, 1.0, 900.0)]
	_volleys(vo2, olha, 6)
	_ok(vo2.n_hits(2) == 1, "olha: no structure in reach: the dove takes the biggest squad")
	var vl := HeroView.new()
	vl.squads = [_sq(1, 14.0, 0.0, 500.0)]
	var lumen := _def("lumen", 1)
	_volleys(vl, lumen, 1)
	_ok(is_equal_approx(vl.dealt(1), (float(lumen["damage"]) + 1.0) + float(lumen["damage"]) * 0.5),
			"lumen: two rays, one target: the spare ray converges (x1.5)")
	var vv := HeroView.new()
	vv.squads = [_sq(1, 14.0, 0.0, 500.0)]
	var vartan := _def("vartan", 1)
	_volleys(vv, vartan, 1)
	_ok(vv.st_count(1, &"mark") == 1, "vartan: rivets MARK")
	for k in 130:
		HeroKinds.hero_step(vv, vartan, DT)
	var drones := 0
	for w: Array in vv.wards:
		if w[0] == &"drone" and int(w[1]) == 2 and float(w[2]) == 6.0 and bool(w[3]):
			drones += 1
	_ok(drones == 2 and vv.wards.size() == 2,
			"vartan: 2 ward-drones every 6 s, each recharge replacing the last (%d grants in 6.5 s)" % drones)
	var vs := HeroView.new()
	vs.fight = true
	vs.squads = [_sq(1, 10.0 + Balance.CONTACT, 0.0, 500.0)]
	var sirko := _def("sirko", 1)
	_volleys(vs, sirko, 1)
	_ok(is_equal_approx(vs.dealt(1), (float(sirko["damage"]) + 2.0) * 1.5) and vs.st_count(1, &"seal") == 1,
			"sirko: BRAND on hit; Warrior Cleave x1.5 on the squad in the clash")
	var a9 := _def("arin", 1, 9)
	_ok(int((a9["atk"]["procs"]["throw"] as Dictionary)["every"]) == 3 and (a9["atk"]["procs"] as Dictionary).has("burst"),
			"arin at Attack rank 9: the beats merged (throw every 3rd, Little Anchor)")


func _test_hero_step() -> void:
	print("== hero_step")
	var v := HeroView.new()
	var eira := _def("eira", 1)
	HeroKinds.hero_step(v, eira, DT)
	v.a["lost"] = 10.0
	HeroKinds.hero_step(v, eira, DT)
	_ok(is_equal_approx(v.c.pool, 2.0), "eira (Healer): 20%% of the soldiers lost feed her revive pool (%s)" % v.c.pool)
	var vb := HeroView.new()
	HeroKinds.hero_step(vb, _def("bolt", 1), DT)
	vb.a["lost"] = 10.0
	HeroKinds.hero_step(vb, _def("bolt", 1), DT)
	_ok(is_zero_approx(vb.c.pool), "bolt: no revive pool")
	var vp := HeroView.new()
	vp.members = [{"id": "mila", "alive": false}]
	var pava := _def("pava", 1)
	for k in int(9.5 / DT):
		HeroKinds.hero_step(vp, pava, DT)
	_ok(vp.revived.is_empty(), "pava Awakening rank 1: nobody stands up before 10 s")
	for k2 in int(1.0 / DT):
		HeroKinds.hero_step(vp, pava, DT)
	_ok(vp.revived.size() == 1 and is_equal_approx(float(vp.revived[0][1]), 0.3), "pava Awakening: up at 30% after 10 s, once")
	var mb := HeroView.new()
	HeroKinds.hero_step(mb, Balance.HEROES["bolt"], DT)
	_ok(is_zero_approx(mb.c.now), "hero_step is a no-op on a Meta-1 row")


# ------------------------------------------------------------------ 4. policies

func _worth(id: String, v: HeroView, form := 1) -> float:
	var def := _def(id, form)
	return HeroKinds.ult_worth(HeroKinds.ult_kind(id), v, def["ult"])


func _test_policies() -> void:
	print("== §10.4 policies")
	var v := HeroView.new()
	_ok(_worth("titan", v) == 0.0, "quake: nothing ahead -> hold")
	v.structs = [_st(10, 21.0, 0.0, "barricade")]
	_ok(_worth("titan", v) == 1.0, "quake: a structure <= 12 u")
	v = HeroView.new()
	v.structs = [_st(10, 15.0, 0.0, "blade", 0.0)]
	_ok(_worth("titan", v) == 1.0, "quake: a hazard row <= 6 u")
	v = HeroView.new()
	v.squads = [_sq(1, 17.0, 0.0, 30.0, {"armored": true})]
	_ok(_worth("arin", v) == 1.0, "anchor: an Armored squad <= 8 u")
	v.squads[0]["armored"] = false
	_ok(_worth("arin", v) == 0.0, "anchor: a plain squad -> hold")
	v.gates = [_gate(20, 16.0, 0.0)]
	_ok(_worth("arin", v) == 1.0, "anchor: the next gate row <= 8 u")
	v = HeroView.new()
	v.squads = [_sq(1, 20.0, 0.0)]
	_ok(_worth("bolt", v) == 0.0, "storm: one squad -> hold")
	v.squads.append(_sq(2, 24.0, 1.0))
	_ok(_worth("bolt", v) == 1.0, "storm: 2 squads in 16 u")
	v = HeroView.new()
	v.squads = [_sq(1, 20.0, 0.0, 10.0, {"flying": true})]
	_ok(_worth("bolt", v) == 1.0, "storm: a Flying squad in 16 u")
	v = HeroView.new()
	v.squads = [_sq(1, 10.0 + Balance.CONTACT + 1.5 * Balance.RUN_SPEED - 0.5, 0.0)]
	_ok(_worth("eira", v) == 1.0, "rime: a clash starts <= 1.5 s")
	v.squads[0]["d"] = 10.0 + Balance.CONTACT + 1.5 * Balance.RUN_SPEED + 1.0
	_ok(_worth("eira", v) == 0.0, "rime: a clash later -> hold")
	v = HeroView.new()
	v.gates = [_gate(20, 18.0, 0.0, "+", 5.0, true)]
	_ok(_worth("seer", v) == 1.0, "rift: a hidden gate row <= 10 u")
	v.gates[0]["hidden"] = false
	_ok(_worth("seer", v) == 0.0, "rift: a revealed row -> hold")
	v.squads = [_sq(1, 12.0, 0.0), _sq(2, 15.0, 2.0), _sq(3, 20.0, -2.0)]
	_ok(_worth("seer", v) == 1.0, "rift: 3 squads <= 12 u")
	v = HeroView.new()
	v.squads = [_sq(1, 14.0, 0.0), _sq(2, 18.0, 0.3)]
	v.structs = [_st(10, 24.0, -0.4, "turret")]
	_ok(_worth("iskar", v) == 1.0, "comet: 3 hostiles in his lane <= 16 u")
	v.structs[0]["x"] = 2.5
	_ok(_worth("iskar", v) == 0.0, "comet: one off the lane -> hold")
	v = HeroView.new()
	v.squads = [_sq(1, 13.0, -2.0), _sq(2, 15.0, 2.0)]
	_ok(_worth("vesta", v) == 1.0, "sunrise: 2 squads <= 6 u")
	v = HeroView.new()
	v.sieging = true
	_ok(_worth("vesta", v) == 1.0 and _worth("lumen", v) == 1.0 and _worth("sirko", v) == 1.0 and _worth("olha", v) == 1.0,
			"sunrise, spectrum, letter, doves: the siege")
	v = HeroView.new()
	v.structs = [_st(10, 15.0, 0.0, "turret")]
	_ok(_worth("vartan", v) == 1.0, "forgewall: a turret row <= 6 u")
	v.structs = [_st(10, 15.0, 0.0, "barricade")]
	_ok(_worth("vartan", v) == 0.0, "forgewall: a barricade only -> hold")
	v = HeroView.new()
	v.squads = [_sq(1, 18.0, 0.0), _sq(2, 18.0, 2.5), _sq(3, 22.0, -2.0)]
	_ok(_worth("lumen", v) == 1.0, "spectrum: 3 squads inside the fan")
	v.squads.pop_back()
	_ok(_worth("lumen", v) == 0.0, "spectrum: 2 -> hold")
	v = HeroView.new()
	var pava := _def("pava", 1)
	for k in 30:
		v.a["lost"] = float(v.a["lost"]) + (1.0 if k >= 10 else 0.0)
		v.a["n"] = maxf(float(v.a["n"]) - (1.0 if k >= 10 else 0.0), 0.0)
		HeroKinds.hero_step(v, pava, 0.1)
	_ok(_worth("pava", v) == 1.0, "eyes: >= 25% of the army lost in 3 s")
	var v2 := HeroView.new()
	for k2 in 30:
		HeroKinds.hero_step(v2, pava, 0.1)
	_ok(_worth("pava", v2) == 0.0, "eyes: no losses -> hold")
	v2.members = [{"id": "mila", "alive": false}]
	_ok(_worth("pava", v2) == 1.0, "eyes: a champion down")
	v = HeroView.new()
	v.squads = [_sq(1, 14.0, 0.0), _sq(2, 22.0, 2.0)]
	_ok(_worth("sirko", v) == 1.0, "letter: 2 squads under the scroll")
	v.squads[0]["d"] = 11.0
	_ok(_worth("sirko", v) == 0.0, "letter: one in front of the scroll -> hold")
	v = HeroView.new()
	v.structs = [_st(10, 25.0, 0.0, "barricade"), _st(11, 35.0, 0.0, "turret")]
	_ok(_worth("olha", v) == 1.0, "doves: 2 barricades / turrets <= 30 u")
	v.structs.pop_back()
	_ok(_worth("olha", v) == 0.0, "doves: one -> hold")
	var m := HeroView.new()
	m.fight = true
	_ok(HeroKinds.ult_worth(&"storm", m, Balance.HEROES["bolt"]["ult"]) == 1.0
			and HeroKinds.ult_worth(&"storm", HeroView.new(), Balance.HEROES["bolt"]["ult"]) == 0.0,
			"a Meta-1 row keeps the Meta-1 policy (always in a fight)")


# ------------------------------------------------------------------ 4b. the H2 review fixes

## A hand-built level: `items` + a fortress of `fort_hp` at `fort` and its stairs, sorted by d.
static func _mini(items: Array, fort := 90.0, fort_hp := 300) -> LevelSim.Level:
	var all := items.duplicate()
	all.append({"kind": "fortress", "x": 0.0, "d": fort, "value": fort_hp})
	all.append({"kind": "stairs", "x": 0.0, "d": fort + 6.0, "steps": []})
	all.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["d"]) < float(q["d"]))
	return LevelSim.level_from_items(all, 20, fort + 6.0)


## The reference profile of L20 with `id`'s v3 block at ult form `form` (the sheet's own numbers x `m`).
static func _v3_prof(id: String, form: int, m := 1.0, atk_rank := 1) -> Dictionary:
	var p := LevelSim.reference_profile(20).duplicate()
	p["hero"] = _block(id, form, m, atk_rank)
	return p


## The reveals of `v` by what: [gates, phantoms].
static func _reveals(v: HeroView) -> Array[int]:
	var out: Array[int] = [0, 0]
	for r: Array in v.reveals:
		if r[2] == KindView.REVEAL_GATES:
			out[0] += 1
		elif r[2] == KindView.REVEAL_PHANTOMS:
			out[1] += 1
	return out


func _test_fallback() -> void:
	print("== the auto ult: every v3 kind fires in every clash and siege")
	var fired := PackedStringArray()
	var idle := PackedStringArray()
	for id: String in HeroData.HERO_ORDER:
		var vc := HeroView.new()
		vc.fight = true
		var vs := HeroView.new()
		vs.sieging = true
		if _worth(id, vc) == 1.0 and _worth(id, vs) == 1.0:
			fired.append(id)
		if _worth(id, HeroView.new()) != 0.0:
			idle.append(id)
	_ok(fired.size() == HeroData.HERO_ORDER.size(), "all %d v3 kinds fire in a clash and in the siege (%s)"
			% [HeroData.HERO_ORDER.size(), ",".join(fired)])
	_ok(idle.is_empty(), "outside a fight an empty bridge still holds every v3 kind (%s)" % ",".join(idle))
	var lv := _mini([{"kind": "squad", "d": 6.0, "x": 0.0, "value": 40, "w": 2.4}])
	var s := LevelSim.start_state(lv, "iskar", 60, {"profile": _v3_prof("iskar", 1)})
	s.ult = float(s.def["ult"]["charge"])
	var calm := LevelSim.ult_worth(lv, s)
	s.mode = LevelSim.Mode.CLASH
	s.foe = 0
	_ok(not calm and LevelSim.ult_worth(lv, s), "LevelSim: Іскар's comet holds on one squad, fires once the clash starts")


func _test_end_of_ult() -> void:
	print("== the end of an ult never charges the next one")
	var vl := HeroView.new()
	vl.squads = [_sq(1, 18.0, 0.0, 300.0, {"hw": 1.2}), _sq(2, 27.0, -2.0, 50.0)]
	_play(vl, _def("lumen", 4))
	_ok(vl.idle_hits == 0 and vl.dealt(2) == 4.0 and not vl.c.active(),
			"spectrum IV: the Crown Shards land with the clock still running (%d idle hits)" % vl.idle_hits)
	var vv := HeroView.new()
	vv.squads = [_sq(1, 22.0, 0.0, 300.0), _sq(2, 18.5, 1.0, 300.0)]
	_play(vv, _def("vartan", 4))
	_ok(vv.idle_hits == 0 and vv.dealt(2) >= 16.0 and not vv.c.active(),
			"forgewall IV: the Landslide lands with the clock still running (%d idle hits)" % vv.idle_hits)
	var vp := HeroView.new()
	vp.squads = [_sq(1, 20.0, 0.0), _sq(2, 30.0, 0.0, 100.0, {"phantom": true})]
	_play(vp, _def("pava", 4))
	_ok(vp.idle_hits == 0 and vp.dealt(1) == 4.0 and vp.dealt(2) == 4.0 and not vp.c.active(),
			"eyes IV: Eyes Wide lands with the clock still running (%d idle hits)" % vp.idle_hits)
	# Every shape at its top form, with something to hit everywhere: no hit ever lands on an idle clock.
	var idle := 0
	for id: String in NEW_KINDS:
		var v := HeroView.new()
		v.squads = [_sq(1, 12.0, 0.0, 400.0), _sq(2, 18.0, 1.0, 400.0), _sq(3, 24.0, -1.0, 400.0)]
		v.structs = [_st(10, 20.0, 2.0, "barricade", 300.0, 1.0), _st(11, 26.0, -2.0, "turret", 300.0, 0.45)]
		_play(v, _def(id, 9), 12.0, Balance.RUN_SPEED * 0.5)
		idle += v.idle_hits
	_ok(idle == 0, "the nine H2 shapes at their top forms: %d hits on an idle clock" % idle)
	# LevelSim: State.ult stays 0 through the whole ult, the end parts included.
	var lv := _mini([{"kind": "squad", "d": 18.0, "x": 0.0, "value": 300, "w": 2.4},
			{"kind": "squad", "d": 27.0, "x": -2.0, "value": 50, "w": 2.4}])
	var s := LevelSim.start_state(lv, "lumen", 60, {"profile": _v3_prof("lumen", 4)})
	s.d = 10.0
	s.ult = float(s.def["ult"]["charge"])
	LevelSim.use_ult(lv, s)
	var steps := 0
	while s.ult_left > 0.0 and steps < 200:
		HeroKinds.ult_step(SimKindView.new(lv, s), &"spectrum", s.def["ult"], DT)
		steps += 1
	_ok(s.kills > 40.0 and s.ult == 0.0 and s.uc.ults == 1,
			"LevelSim spectrum IV: %.0f kills, ult points %.1f after its end (want 0)" % [s.kills, s.ult])


func _test_reveals() -> void:
	print("== reveal: hidden gates or Phantoms")
	var v := HeroView.new()
	v.squads = [_sq(1, 20.0, 0.0), _sq(2, 30.0, 0.0, 100.0, {"phantom": true})]
	v.gates = [_gate(20, 18.0, 0.0, "+", 5.0, true)]
	_play(v, _def("pava", 4))
	var rv := _reveals(v)
	_ok(rv[0] == 0 and rv[1] == 1 and v.st_count(2, &"mark") == 1,
			"eyes IV: Eyes Wide reveals the Phantoms only, never a hidden gate (gates %d, phantoms %d)" % [rv[0], rv[1]])
	var seer := _def("seer", 1, 9)
	var vg := HeroView.new()
	vg.gates = [_gate(20, 18.0, 0.0, "charge", -6.0, true), _gate(21, 26.0, 0.0, "+", 5.0, true)]
	HeroKinds.attack(vg, seer, [{"id": 20, "kind": "gate", "d": 18.0, "x": 0.0, "op": "charge"}], 1, float(seer["damage"]))
	var rg := _reveals(vg)
	_ok(rg[0] == 2 and rg[1] == 0 and vg.dealt(20, &"gate") == 1.5,
			"seer v3: a gate hit reveals its row and (beat 9) the next one, gates only; a charge gate takes x1.5")
	var vk := HeroView.new()
	vk.squads = [_sq(1, 14.0, 0.0, 500.0)]
	_volleys(vk, seer, 8)
	var rk := _reveals(vk)
	_ok(rk[0] == 0 and rk[1] == 1 and vk.st_count(1, &"mark") == 1 and float(vk.reveals[0][1]) - float(vk.reveals[0][0]) == 8.0,
			"seer v3 beat 6: the 8th hit MARKs and reveals Phantoms <= 4 u, no gates")
	var lv := _mini([{"kind": "gate", "d": 20.0, "x": 0.0, "op": "+", "value": 5, "w": 2.0, "row": 1, "hidden": true}])
	var s := LevelSim.start_state(lv, "bolt", 30, {"profile": _v3_prof("bolt", 1)})
	var gi := -1
	for i in lv.items.size():
		if lv.kind[i] == LevelSim.K.GATE:
			gi = i
	var sv := SimKindView.new(lv, s)
	sv.reveal(10.0, 30.0, KindView.REVEAL_PHANTOMS)
	var after_ph := s.rev[gi]
	sv.reveal(10.0, 30.0, KindView.REVEAL_GATES)
	_ok(after_ph == 0 and s.rev[gi] == 1, "SimKindView: a Phantom reveal leaves the hidden gate hidden, a gate reveal opens it")


func _test_wards() -> void:
	print("== wards: kinds, replace, the shared spend order (LevelSim)")
	var t: Array = KindView.WARD_SPEND[&"turret"]
	var b: Array = KindView.WARD_SPEND[&"blade"]
	var k: Array = KindView.WARD_SPEND[&"contact"]
	_ok(t == [&"wall_turret", &"drone", &"turret"] and b == [&"wall_contact", &"blade", &"contact"]
			and k == [&"wall_contact", &"contact"] and LevelSim.WARD_KINDS == KindView.WARD_SPEND,
			"one spend table: turret wall > drone > turret, blade wall > blade > contact, contact wall > contact")
	var lv := _mini([{"kind": "squad", "d": 30.0, "x": 0.0, "value": 40, "w": 2.4}])
	var s := LevelSim.start_state(lv, "vartan", 40, {"profile": _v3_prof("vartan", 1)})
	var v := SimKindView.new(lv, s)
	v.grant_ward(&"drone", 2, 6.0, true)
	v.grant_ward(&"drone", 2, 6.0, true)
	_ok(is_equal_approx(LevelSim.ward_left(s, &"turret"), 2.0), "drone grants replace their own kind: 2 charges, not 4")
	v.grant_ward(&"turret", 1, 6.0)
	v.grant_ward(&"turret", 1, 6.0)
	_ok(is_equal_approx(LevelSim.ward_left(s, &"turret"), 4.0), "plain grants still add up (2 drone + 2 turret)")
	v.grant_ward(&"wall_turret", HeroKinds.ALL_CHARGES, 5.0, true)
	var spent := LevelSim.ward_spend(s, &"turret", 3.0)
	_ok(is_equal_approx(spent, 3.0) and is_equal_approx(float(s.wards[&"wall_turret"][0]), HeroKinds.ALL_CHARGES - 3.0)
			and is_equal_approx(float(s.wards[&"drone"][0]), 2.0), "turret shots spend the wall's ward first")
	v.grant_ward(&"wall_turret", 0, 0.0, true)
	_ok(not s.wards.has(&"wall_turret") and is_equal_approx(LevelSim.ward_left(s, &"turret"), 4.0),
			"the wall's end clears its turret ward; the drones' and plain ones stay")
	LevelSim.ward_spend(s, &"turret", 2.5)
	_ok(is_zero_approx(float(s.wards[&"drone"][0])) and is_equal_approx(float(s.wards[&"turret"][0]), 1.5),
			"then the drones' (2), then the plain ward (0.5 of 2)")
	v.grant_ward(&"blade", 1, 5.0)
	v.grant_ward(&"contact", 1, 5.0)
	v.grant_ward(&"wall_contact", 1, 5.0, true)
	var c1 := v.absorb(&"contact")
	var wall_left := float(s.wards[&"wall_contact"][0])
	var c2 := v.absorb(&"contact")
	var c3 := v.absorb(&"contact")
	_ok(c1 and is_zero_approx(wall_left) and c2 and not c3 and is_equal_approx(float(s.wards[&"blade"][0]), 1.0),
			"a barricade contact spends the wall's contact ward, then a contact ward, never a blade ward")
	v.grant_ward(&"wall_contact", 1, 5.0, true)
	v.grant_ward(&"contact", 1, 5.0)
	var b1 := v.absorb(&"blade")
	var after_wall := float(s.wards[&"wall_contact"][0])
	var b2 := v.absorb(&"blade")
	var after_blade := float(s.wards[&"blade"][0])
	var b3 := v.absorb(&"blade")
	_ok(b1 and is_zero_approx(after_wall) and b2 and is_zero_approx(after_blade) and b3
			and is_zero_approx(float(s.wards[&"contact"][0])), "a blade spends wall_contact, then blade, then contact")
	LevelSim.grant_ward(s, &"drone", 0.5, 5.0, true)
	LevelSim.grant_ward(s, &"turret", 0.5, 5.0, true)
	_ok(not v.absorb(&"turret"), "half a drone and half a turret charge absorb no whole shot")
	# hero_step over a minute: the drones never bank.
	var s2 := LevelSim.start_state(lv, "vartan", 40, {"profile": _v3_prof("vartan", 1, 1.0, 6)})
	var v2 := SimKindView.new(lv, s2)
	var most := 0.0
	for n in int(60.0 / DT):
		s2.t += DT
		HeroKinds.hero_step(v2, s2.def, DT)
		most = maxf(most, LevelSim.ward_left(s2, &"turret"))
	_ok(int(s2.def["drones"]) == 3 and is_equal_approx(most, 3.0) and is_equal_approx(LevelSim.ward_left(s2, &"contact"), 1.0),
			"vartan rank 6: 3 drones and the contact drone over 60 s: at most %.1f turret / 1 contact charges" % most)
	# A whole Вартан run on turret rows: the wall's wards end with the wall.
	var items: Array = []
	for row in 22:
		items.append({"kind": "turret", "d": 14.0 + 12.0 * row, "x": 2.2, "value": 40, "range": 7.0, "rate": 2.0})
		items.append({"kind": "squad", "d": 18.0 + 12.0 * row, "x": 0.0, "value": 6, "w": 2.4})
	var lv3 := _mini(items, 285.0, 60)
	lv3.ult_ready_at = 4.0
	var s3 := LevelSim.start_state(lv3, "vartan", 200, {"profile": _v3_prof("vartan", 1)})
	var path := PackedFloat32Array([0.0, 0.0, 400.0, 0.0])
	var worst := 0.0
	var up := 0.0
	var at_45 := -1.0
	while s3.mode != LevelSim.Mode.WON and s3.mode != LevelSim.Mode.LOST and s3.t < 90.0:
		LevelSim.step(lv3, s3, path, DT)
		if s3.ult_left <= 0.0:
			worst = maxf(worst, LevelSim.ward_left(s3, &"turret"))
		else:
			up = maxf(up, LevelSim.ward_left(s3, &"turret"))
		if at_45 < 0.0 and s3.t >= 45.0:
			at_45 = LevelSim.ward_left(s3, &"turret")
	_ok(s3.uc.ults >= 2 and up >= HeroKinds.ALL_CHARGES and worst <= float(s3.def["drones"]) + 0.001 and at_45 >= 0.0
			and at_45 <= float(s3.def["drones"]) + 0.001, ("a Вартан run (%d walls of 5 s, %.0f s): every turret shot warded "
			+ "while a wall stands, else never more than the %d drones (most %.1f; at t=45 %.1f)")
			% [s3.uc.ults, s3.t, int(s3.def["drones"]), worst, at_45])


func _test_starters_v3() -> void:
	print("== the starters' v3 attacks (HeroKinds.attack)")
	var tit := _def("titan", 1, 9)
	var dt := float(tit["damage"])
	var vt := HeroView.new()
	vt.squads = [_sq(1, 14.0, 0.0, 500.0)]
	_volleys(vt, tit, 1)
	_ok(is_equal_approx(vt.dealt(1), dt + 3.0) and vt.st_len(1, &"stagger") == 0.4,
			"titan v3: rock + splash 3, beat 3 STAGGER 0.4 s (%s)" % vt.dealt(1))
	var vs := HeroView.new()
	vs.structs = [_st(10, 14.0, 0.0, "barricade", 1000.0, 1.0), _st(11, 17.0, 0.0, "barricade", 1000.0, 1.0)]
	for n in 4:
		HeroKinds.attack(vs, tit, [{"id": 10, "kind": "barricade", "d": 14.0, "x": 0.0, "hp": 1000.0}], 1, dt)
	_ok(is_equal_approx(vs.dealt(10), 4.0 * dt * 1.5) and is_equal_approx(vs.dealt(11), dt * 1.5 * 0.5),
			"titan v3: structures x1.5; beat 6: every 4th structure hit echoes 50%% of it on the next <= 4 u behind (%s)"
			% vs.dealt(11))
	var vb := HeroView.new()
	vb.structs = [_st(10, 14.0, 0.0, "barricade", 1.0, 1.0), _st(11, 14.5, 1.0, "turret", 100.0, 0.45)]
	HeroKinds.attack(vb, tit, [{"id": 10, "kind": "barricade", "d": 14.0, "x": 0.0, "hp": 1.0}], 1, dt)
	_ok(vb.dealt(11) == 2.0, "titan v3 beat 9: a structure he breaks bursts 2 on structures <= 1.5 u")
	var bolt := _def("bolt", 1, 1)
	var vr := HeroView.new()
	vr.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 16.5, 1.0, 500.0), _sq(3, 25.0, 0.0, 500.0)]
	_volleys(vr, bolt, 3)
	_ok(vr.n_hits(1) == 3 and vr.n_hits(2) == 1 and vr.n_hits(3) == 0
			and str((vr.events[2][1] as Dictionary)["proc"]) == "fork" and vr.statuses.is_empty(),
			"bolt v3: every 3rd dart forks to 1 more <= 4 u (no JOLT before beat 9)")
	var vf := HeroView.new()
	vf.squads = [_sq(1, 14.0, 0.0, 500.0, {"flying": true})]
	_volleys(vf, bolt, 2)
	_ok(vf.grounds.size() == 1 and float(vf.grounds[0][1]) == 1.2, "bolt v3: a hit grounds a Flying squad 1.2 s, not again within 4 s")
	var bolt9 := _def("bolt", 1, 9)
	var v9 := HeroView.new()
	v9.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 17.0, 1.0, 500.0), _sq(3, 20.0, 2.0, 500.0)]
	_volleys(v9, bolt9, 3)
	_ok(v9.n_hits(2) == 1 and v9.n_hits(3) == 1 and v9.st_count(2, &"jolt") == 1 and v9.st_count(3, &"jolt") == 1
			and v9.st_count(1, &"jolt") == 0, "bolt v3 beats 3 / 9: the fork reaches 5 u, chains once more, JOLTs what it forks to")
	var vl := HeroView.new()
	vl.squads = [_sq(1, 14.0, 0.0, 500.0), _sq(2, 20.0, 0.2, 500.0), _sq(3, 20.0, 3.0, 500.0)]
	_volleys(vl, bolt9, 8)
	_ok(str((vl.events[7][1] as Dictionary)["proc"]) == "lance" and is_equal_approx(vl.dealt(2), float(bolt9["damage"]) * 2.0)
			and vl.dealt(3) == 0.0, "bolt v3 beat 6: the 8th dart is a rail shot down the corridor x2")
	var seer := _def("seer", 1, 9)
	var vm := HeroView.new()
	vm.squads = [_sq(1, 14.0, 0.0, 2.0), _sq(2, 15.0, 1.0, 500.0)]
	HeroKinds.attack(vm, seer, [_row(vm.squads[0])], HeroKinds.volley_shots(vm, seer), float(seer["damage"]))
	_ok(vm.n_hits(1) == 2 and vm.st_count(1, &"seal") == 1 and vm.dealt(2, &"attack") >= 1.0,
			"seer v3: twin orbs, BRAND on every 2nd hit (proc 0.5), beat 3: a killing orb bounces 1 to a squad <= 3 u")
	# LevelSim: the starters' v3 rows attack through HeroKinds.attack (the hero clock counts the volleys).
	var lv := _mini([{"kind": "squad", "d": 12.0, "x": 0.0, "value": 400, "w": 2.4}])
	var casts := PackedStringArray()
	for id: String in Balance.HERO_ORDER:
		var s := LevelSim.start_state(lv, id, 60, {"profile": _v3_prof(id, 1)})
		var path := PackedFloat32Array([0.0, 0.0, 200.0, 0.0])
		for n2 in 40:
			LevelSim.step(lv, s, path, DT)
		casts.append("%s %d/%d" % [id, s.uc.casts, s.casts])
		_ok(s.v3 and s.uc.casts > 0 and s.uc.casts == s.casts, "LevelSim %s v3: volleys through HeroKinds.attack (%d)" % [id, s.uc.casts])


func _test_damage() -> void:
	print("== damage gates x dmg_mult; Люмен's machines inside bucket 2")
	var lv := _mini([{"kind": "squad", "d": 6.0, "x": 0.0, "value": 5000, "w": 2.4}])
	var s := LevelSim.start_state(lv, "bolt", 30, {"profile": _v3_prof("bolt", 1, 1.5)})
	s.p_dmg = 2
	_ok(s.v3 and is_equal_approx(LevelSim.hero_damage(s), 1.5 + 2.0 * 1.5) and is_equal_approx(HeroKinds.gate_damage(s.def, 2.0), 4.5),
			"a v3 row: damage 1 x 1.5 + 2 gates x 1.5 = 4.5 (%s)" % LevelSim.hero_damage(s))
	var sx := LevelSim.start_state(lv, "lumen", 30, {"profile": _v3_prof("lumen", 1, 2.0)})
	sx.p_dmg = 3
	_ok(is_equal_approx(LevelSim.hero_damage(sx), float(sx.def["damage"]) + 3.0 * 2.0), "a new hero's gates scale the same (%s)"
			% LevelSim.hero_damage(sx))
	EconData.phase_override = 0
	var p0 := LevelSim.reference_profile(20).duplicate()
	p0["hero"] = {"id": "bolt", "lvl": 5, "dmg_mult": 1.5}
	var s0 := LevelSim.start_state(lv, "bolt", 30, {"profile": p0})
	s0.p_dmg = 2
	_ok(not s0.v3 and is_equal_approx(LevelSim.hero_damage(s0), 3.0 * 1.5), "phase 0: (1 + 2 gates) x 1.5, as shipped")
	EconData.phase_override = HeroKinds.V3_PHASE
	_ok(is_equal_approx(HeroKinds.machines_b2(0.1), 0.1) and is_equal_approx(HeroKinds.machines_b2(0.3), TeamData.TEAM_B2_CAP)
			and is_equal_approx(HeroKinds.machines_b2(0.1, 0.15), TeamData.TEAM_B2_CAP),
			"the machines buff joins the team part of bucket 2, capped at TEAM_B2_CAP %.2f" % TeamData.TEAM_B2_CAP)
	var sm := LevelSim.start_state(lv, "lumen", 30, {"profile": _v3_prof("lumen", 5)})
	sm.weapons = [["cannon", 1, 0.0, 0]]
	var sb := sm.copy()
	LevelSim.buff(sb, &"machines", 0.1, 5.0, {})
	var sq := 0
	for i in lv.items.size():
		if lv.kind[i] == LevelSim.K.SQUAD:
			sq = i
	var hp0 := sm.hp[sq]
	LevelSim._machines(lv, sm, 0.3)
	LevelSim._machines(lv, sb, 0.3)
	var row := LevelSim.machine_row(sm, sm.weapons[0])
	var want := (float(row["b2"]) + 0.1) / float(row["b2"])
	_ok(hp0 - sm.hp[sq] > 0.0 and absf((hp0 - sb.hp[sq]) / (hp0 - sm.hp[sq]) - want) < 0.002,
			"LevelSim: a machine hit under the buff is x (b2 + 0.1) / b2 = %.3f (b2 %.2f), inside bucket 2 (%.3f / %.3f)"
			% [want, row["b2"], hp0 - sb.hp[sq], hp0 - sm.hp[sq]])


# ------------------------------------------------------------------ 5. LevelSim with every hero

## The EXPECTED profile of campaign `level` led by `hero` at phase 2 (Meta.run_profile on the synthetic
## account, as test_kind_parity builds it) with `hero`'s v3 block and its team (the two scripted champions).
static func profile_for(level: int, hero: String) -> Dictionary:
	var acc := CS.account_for(level, "expected", hero)
	var keep := [Meta.account, str(Save.hero)]
	Meta.account = acc
	Save.hero = hero if Balance.HEROES.has(hero) else "bolt"
	var prof: Dictionary = Meta.run_profile(level)
	Meta.account = keep[0]
	Save.hero = str(keep[1])
	prof["hero"] = LevelSim.v3_hero_block(acc, hero)
	prof["team"] = Meta.team_block_of(acc, hero)
	return prof


static func _level(level: int) -> LevelSim.Level:
	return LevelSim.make_level(LevelGen.build(level, Balance.START_ARMY), level)


## One planned run: {won, army (at the fortress), casts (ult casts), state}.
static func play(lv: LevelSim.Level, hero: String, prof: Dictionary, candidates := 9) -> Dictionary:
	var bp: Dictionary = LevelSim.best_path(lv, hero, Balance.START_ARMY, {"profile": prof, "candidates": candidates})
	var r: Dictionary = bp["result"]
	var s: LevelSim.State = bp["state"]
	return {"won": bool(r["won"]), "army": int(r["army_at_fortress"]), "surv": int(r["survivors"]), "state": s,
			"reason": str(r["reason"]), "d": float(r["d"])}


## Part 5: per level, Руді's planned path (the planner with his v3 profile), then every hero runs that same path
## (LevelSim.simulate: one input for all, fast; --measure plans per hero).
func _test_sim() -> void:
	print("== LevelSim plays every hero (phase 2, EXPECTED, the two scripted champions; Руді's planned path)")
	var levels: Array[int] = SIM_LEVELS
	if _args.has("levels"):
		levels = []
		for p in str(_args["levels"]).split(",", false):
			levels.append(int(p))
	var heroes: Array = Array(HeroData.HERO_ORDER) if not _args.has("heroes") else Array(str(_args["heroes"]).split(",", false))
	for level in levels:
		var lv := _level(level)
		var bp: Dictionary = LevelSim.best_path(lv, "bolt", Balance.START_ARMY, {"profile": profile_for(level, "bolt"),
				"candidates": 9})
		var path: PackedFloat32Array = bp["path"]
		var line := PackedStringArray()
		for hero: String in heroes:
			var s := LevelSim.simulate(lv, hero, Balance.START_ARMY, path, {"profile": profile_for(level, hero)})
			var r := LevelSim.result(lv, s)
			var ended := s.mode == LevelSim.Mode.WON or s.mode == LevelSim.Mode.LOST
			_ok(ended and s.v3 and str(s.def["kind"]) == hero, "L%d %s: plays to the end on its v3 row (%s)" % [level, hero,
					"W" if r["won"] else "L " + str(r["reason"])])
			line.append("%s %s%d ult%d atk%d" % [hero, "W" if r["won"] else "L", int(r["army_at_fortress"]),
					s.uc.ults if s.uc else 0, s.uc.casts if s.uc else 0])
		print("  L%d: %s" % [level, " | ".join(line)])


# ------------------------------------------------------------------ --measure

func _measure() -> void:
	var from := int(_args.get("from", "20"))
	var to := int(_args.get("to", "60"))
	var step := int(_args.get("step", "5"))
	var heroes: Array = Array(HeroData.HERO_ORDER) if not _args.has("heroes") else Array(str(_args["heroes"]).split(",", false))
	if not heroes.has("bolt"):
		heroes.push_front("bolt")
	print("== MEASURE: phase %d, EXPECTED, team of the two scripted champions, L%d-%d step %d (planner, 9 candidates)"
			% [EconData.heroes_phase(), from, to, step])
	var t0 := Time.get_ticks_msec()
	var tab := {}
	for h: String in heroes:
		tab[h] = {"wins": 0, "runs": 0, "army": 0.0, "ults": 0, "by": {}}
	for level in range(from, to + 1, step):
		var lv := _level(level)
		var parts := PackedStringArray()
		for hero: String in heroes:
			var res := play(lv, hero, profile_for(level, hero))
			var s: LevelSim.State = res["state"]
			var ults := s.uc.ults if s.uc != null else 0
			var row: Dictionary = tab[hero]
			row["runs"] = int(row["runs"]) + 1
			row["wins"] = int(row["wins"]) + (1 if res["won"] else 0)
			row["army"] = float(row["army"]) + float(res["army"])
			row["ults"] = int(row["ults"]) + ults
			(row["by"] as Dictionary)[level] = int(res["army"])
			parts.append("%s %s%d u%d" % [hero, "W" if res["won"] else "L", int(res["army"]), ults])
		print("MEASURE L%d: %s" % [level, " | ".join(parts)])
	var ref: Dictionary = tab["bolt"]
	var ref_mean := float(ref["army"]) / maxf(float(ref["runs"]), 1.0)
	print("MEASURE hero   wins  mean army  vs Руді  ults/run   per level: army (vs Руді)")
	for hero: String in heroes:
		var row2: Dictionary = tab[hero]
		var runs := maxf(float(row2["runs"]), 1.0)
		var mean := float(row2["army"]) / runs
		var dv := (mean - ref_mean) / maxf(ref_mean, 1.0)
		var per := PackedStringArray()
		for level2: int in (row2["by"] as Dictionary):
			var a := int((row2["by"] as Dictionary)[level2])
			per.append("L%d %d (%+d)" % [level2, a, a - int((ref["by"] as Dictionary)[level2])])
		var flag := "  BALANCE NOTE: %+.0f%% vs Руді" % (100.0 * dv) if absf(dv) > FLAG_SHARE and hero != "bolt" else ""
		print("MEASURE %-6s %2d/%-2d %8.1f %+7.1f%% %6.1f   %s%s" % [hero, int(row2["wins"]), int(row2["runs"]), mean,
				100.0 * dv, float(row2["ults"]) / runs, ", ".join(per), flag])
	print("MEASURE done in %.1f s" % [(Time.get_ticks_msec() - t0) / 1000.0])
