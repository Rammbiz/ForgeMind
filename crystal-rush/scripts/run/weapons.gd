class_name Weapons
extends Node3D
## The fielded war machines of a run (arsenal_design.md §2, §3) and the army's own volleys
## (crossbow / blaster tiers, etap1). Numbers come from the account through the run profile
## (Meta.run_profile, built once in Run.setup): `profile.machines[id].by_rank[rank - 1]` are the
## bucket-1 stats (acc_mult x rank_mult already inside), `add` is bucket 2 (talents, Ascension),
## `mods` the rule keys a talent / Ascension adds.
##
## Damage (§2.1): dmg = stats x (1 + add + overflow + Reinforcements + Prism amp) x vs, with vs =
## clamp(max(structures, Mark, boss) , 0.25, 3). Vs a squad a hit is enemies killed (etap1 rule).
## Machines never target crates or gates (hero and ult only).
##
## The 9 Meta-1 behaviours, by verb (PAINT = the hero's painted target, else the nearest hostile
## ahead within WEAPON_LATERAL; LANE = straight down the hero's corridor; PLACE = a spot ahead of
## the hero with a friendly telegraph):
## - drone (PAINT): drones fly out to the target and Mark it (proc 0.5); Rank II 2 drones.
## - ballista (LANE): a bolt pierces `pierce` targets down the lane (squads: damage x pierce
##   kills), Stagger; Rank III twin bolts.
## - cannon (PAINT): plasma orb, target + splash, AoE radius, Burn; Rank III splits into 3.
## - rockets (PAINT): homing volley of `volley` rockets, structures x1.5; Rank III bomblets.
## - mortar (PLACE): a shell lands 12 u ahead of the hero after a 0.8 s dashed ring; area hit,
##   Stagger; ground only; Rank III bomblets.
## - gatling (PAINT): one tracer stream, spin-up from 50% over 1 s, ricochet, Stagger (proc 0.3).
## - laser (LANE): beam that ramps +50%/s on one target up to ramp_cap; Rank III pierces 2.
## - railgun (LANE): charge, 0.4 s dashed rails telegraph locking the lane, then one shot through
##   EVERY hostile in the lane (structures x2), Jolt each; Rank III leaves a Jolt strip.
## - prism (LANE): hovers 3 u ahead of the hero; every shot that crosses it (hero shots always,
##   LANE shots, PAINT shots into the hero's lane) gains +amp damage (bucket 2) and +1 pierce;
##   the laser splits into 3 at 60%; alone it fires a 1-dmg ray per second.
## A machine joins from its crate: it hops out, unfolds (WeaponModels.dock) and skids into its
## convoy slot (A / B on the flanks of the blob, C behind on the roomier side, §2.2).

signal ranked(id: String, rank: int)

const SPEED := {"ballista": 24.0, "cannon": 15.0, "rockets": 15.0, "drone": 18.0, "prism": 30.0}
const KICK_DECAY := 2.5
const ARRIVE_TIME := 0.8
## Squads killed per area hit: damage + radius x AREA_KILLS (+ splash), the etap1 crowd grammar.
const AREA_KILLS := 2.0
const STRUCTURES := ["turret", "barricade", "geode", "fortress"]

var run: Run
var machines: Array[Dictionary] = []
var statuses: Statuses
var _volley_cd := 0.0
var _laser_on := false
var _lane_strips: Array[Dictionary] = []    # railgun Rank III: [{x, d0, d1, t}]


func setup(p_run: Run) -> void:
	run = p_run
	statuses = Statuses.new(run)


# ------------------------------------------------------------------ fielding

## The profile entry of `id` (the account numbers), computing one for a machine outside the deck
## (the NEW crate's machine) at its Arsenal Sync level.
func entry_of(id: String) -> Dictionary:
	var ms: Dictionary = run.profile.get("machines", {})
	if not ms.has(id):
		var lvl := int(EconData.START_LEVEL[ArsenalData.rarity_of(id)])
		var acc: Variant = run.account()
		if acc is Dictionary and not (acc as Dictionary).is_empty():
			lvl = Arsenal.sync_level(acc, id)
		ms[id] = LevelSim.entry(id, lvl)
		run.profile["machines"] = ms
	return ms[id]


## {id: rank} of the fielded machines.
func fielded() -> Dictionary:
	var out := {}
	for m in machines:
		out[str(m["id"])] = int(m["rank"])
	return out


func find(id: String) -> Dictionary:
	for m in machines:
		if str(m["id"]) == id:
			return m
	return {}


## What opening a crate of `id` now would do: {kind: "new" | "rank" | "overflow" | "swap",
## id (the machine that changes), rank (after), pct (overflow %, bucket 2)}. `bonus` adds the
## BONUS segment's +1 Rank.
func forecast(id: String, bonus := false, extra := 0) -> Dictionary:
	var m := find(id)
	var steps := 1 + (1 if bonus else 0) + extra
	if m.is_empty():
		if machines.size() < ArsenalData.MAX_FIELDED:
			return {"kind": "new", "id": id, "rank": mini(steps, 3)}
		var low := _lowest()
		return {"kind": "swap", "id": str(low["id"]), "rank": mini(int(low["rank"]) + 1, 3)}
	var r := int(m["rank"])
	if r >= 3:
		return {"kind": "overflow", "id": id, "rank": 3, "pct": int(round(ArsenalData.overflow_bonus(int(m["over"]) + 1) * 100.0))}
	return {"kind": "rank", "id": id, "rank": mini(r + steps, 3)}


## Opens a crate / takes a reward of machine `id` at world position `from`: fields it, ranks it
## up (+1, +2 with the BONUS) or adds overflow. A new kind with every slot taken ranks up the
## lowest machine (etap1 rule). Returns {id, rank, kind}.
func grant(id: String, from: Vector3, bonus := false) -> Dictionary:
	var fc := forecast(id, bonus)
	match str(fc["kind"]):
		"new":
			field(id, int(fc["rank"]), from)
		"swap":
			rank_up(str(fc["id"]))
		"rank":
			var m := find(id)
			while int(m["rank"]) < int(fc["rank"]):
				rank_up(id)
		"overflow":
			add_overflow(id)
	return fc


## Puts machine `id` on the field at `rank`. `docked`: already in its slot (the Lead at start).
func field(id: String, rank := 1, from := Vector3.INF, docked := false) -> Dictionary:
	var e := entry_of(id)
	var node := WeaponModels.machine(id, {"rank": rank, "ascended": bool(e.get("ascended", false)), "branch": str(e.get("branch", "a"))})
	node.scale = Vector3.ONE * float(ArsenalData.CONVOY["scale"])
	add_child(node)
	var m := {"id": id, "kind": id, "rank": rank, "level": rank, "e": e, "node": node, "slot": 0, "cd": 0.5,
			"kick": 0.0, "arrive": 1.0 if docked else 0.0, "from": from, "roll": 0.0, "aim": Vector3.INF,
			"tg": {}, "kills": 0.0, "over": 0, "over_add": 0.0, "ramp": 0.0, "ramp_tg": {}, "spin": 0.0,
			"bullets": 0.0, "charge": 0.0, "tele": -1.0, "lane_x": 0.0, "cheer": 0.0, "pos2": Vector3.ZERO}
	m["st"] = _rank_stats(m)
	machines.append(m)
	_assign_slots()
	if docked or from == Vector3.INF:
		m["arrive"] = 1.0
		node.position = slot_pos(m)
		WeaponModels.dock(node, 1.0)
	else:
		node.position = from
		WeaponModels.dock(node, 0.0)
	m["pos2"] = node.position
	ranked.emit(id, rank)
	return m


## +1 Rank (max III; beyond III it becomes overflow): the forge moment.
func rank_up(id: String) -> void:
	var m := find(id)
	if m.is_empty():
		return
	if int(m["rank"]) >= 3:
		add_overflow(id)
		return
	m["rank"] = int(m["rank"]) + 1
	m["level"] = m["rank"]
	m["st"] = _rank_stats(m)
	var node := m["node"] as Node3D
	WeaponModels.set_rank(node, int(m["rank"]))
	var col := WeaponModels.glow_color(id)
	run.effects.rank_up(node.global_position, col)
	m["cheer"] = 1.2
	_pop(node, 1.5)
	Audio.play("upgrade", -3.0)
	run.juice.haptic("weapon")
	ranked.emit(id, int(m["rank"]))


## A copy past Rank III: +10% / +7% / +5% / +3% bucket 2 (§2.1 overflow).
func add_overflow(id: String) -> void:
	var m := find(id)
	if m.is_empty():
		return
	m["over"] = int(m["over"]) + 1
	m["over_add"] = float(m["over_add"]) + ArsenalData.overflow_bonus(int(m["over"]))
	var node := m["node"] as Node3D
	run.effects.upgrade_fx(node.global_position, WeaponModels.glow_color(id))
	_pop(node, 1.3)
	Audio.play("upgrade", -6.0)
	ranked.emit(id, int(m["rank"]))


func _rank_stats(m: Dictionary) -> Dictionary:
	var e: Dictionary = m["e"]
	var by: Array = e.get("by_rank", [])
	var r := clampi(int(m["rank"]), 1, 3)
	if by.size() >= r:
		return by[r - 1]
	return ArsenalData.machine_stats(str(m["id"]), int(e.get("lvl", 1)), r)["stats"]


func _lowest() -> Dictionary:
	var low: Dictionary = machines[0]
	for m in machines:
		if int(m["rank"]) < int(low["rank"]):
			low = m
	return low


func _pop(node: Node3D, k: float) -> void:
	var base := Vector3.ONE * float(ArsenalData.CONVOY["scale"])
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * k, 0.1)
	tw.tween_property(node, "scale", base, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ convoy

## Convoy slots (§2.2): A left / B right of the blob (|x| = r + 0.9, clamped to 3.0), C behind on
## the roomier side; 1 u ahead of the blob centre while the army is small. The Prism hovers in
## front of the hero instead.
func _assign_slots() -> void:
	var k := 0
	for m in machines:
		if str(m["id"]) == "prism":
			m["slot"] = -1
			continue
		m["slot"] = k
		k += 1


func slot_pos(m: Dictionary) -> Vector3:
	var cv: Dictionary = ArsenalData.CONVOY
	if int(m["slot"]) < 0:
		return Vector3(run.hx, 0.0, -run.d - 3.0)
	var av := run.army_view
	var r := av.radius
	var c := av.center
	var gap := float(cv["gap"])
	var lim := float(cv["clamp_x"])
	var z := c.z - (float(cv["small_ahead"]) if run.army <= int(cv["small_army"]) else 0.0)
	var p := Vector3(0, 0, z)
	match int(m["slot"]):
		0:
			p.x = c.x - (r + gap)
		1:
			p.x = c.x + (r + gap)
		_:
			# C: behind the blob on the roomier side (clear of A / B, never under the counter).
			var side := -1.0 if c.x > 0.0 else 1.0
			p.x = c.x + side * maxf(r * 0.55, 0.6)
			p.z = c.z + r * Balance.BLOB_STRETCH + float(cv["c_back"]) * 0.75
	p.x = clampf(p.x, -lim, lim)
	return p


## Solid circles for the army (units step around the machines).
func solids() -> Array:
	var out: Array = []
	for m in machines:
		if float(m["arrive"]) >= 1.0 and int(m["slot"]) >= 0 and str(m["id"]) != "drone":
			out.append([(m["node"] as Node3D).position, 0.5])
	return out


func _place(m: Dictionary, dt: float) -> void:
	var node := m["node"] as Node3D
	var target := slot_pos(m)
	if str(m["id"]) == "drone":
		target = _drone_goal(m, target)
	var a := float(m["arrive"])
	var before := node.position
	if a < 1.0:
		# Hop out of the crate, unfold (dock), skid into the slot (<= 0.8 s, §2.8).
		a = minf(a + dt / ARRIVE_TIME, 1.0)
		m["arrive"] = a
		var from: Vector3 = m["from"]
		var e := 1.0 - pow(1.0 - a, 3.0)
		var p := from.lerp(target, e)
		var hop := minf(a * 2.4, 1.0)
		p.y = 1.6 * 4.0 * hop * (1.0 - hop) if a < 0.42 else 0.0
		node.position = p
		WeaponModels.dock(node, smoothstep(0.1, 0.9, a))
		if a >= 1.0:
			run.effects.shockwave(Vector3(target.x, 0.0, target.z), WeaponModels.glow_color(str(m["id"])), 1.1)
			run.effects.burst(target + Vector3(0, 0.2, 0), Color(0.85, 0.85, 0.9), 12, 2.4, 0.07, 0.4, -6.0)
			Audio.play("crate_hit", -6.0, 0.1)
	else:
		var k := 1.0 - exp(-(9.0 if str(m["id"]) != "drone" else 5.0) * dt)
		var p2 := node.position
		p2.x += (target.x - p2.x) * k
		p2.z += (target.z - p2.z) * k + (run.step_advance if str(m["id"]) != "prism" else 0.0)
		if str(m["id"]) == "prism":
			p2 = Vector3(lerpf(node.position.x, target.x, 1.0 - exp(-10.0 * dt)), 0.0, target.z)
		p2.y += (target.y - p2.y) * k
		node.position = p2
	m["roll"] = float(m["roll"]) + absf(node.position.z - before.z) + absf(node.position.x - before.x) * 0.5


## Drones fly out to their target (hovering 2.4 u short of it, 1.2 u up), else ride their slot.
func _drone_goal(m: Dictionary, slot: Vector3) -> Vector3:
	var tg: Dictionary = m["tg"]
	slot.y = 0.6
	if tg.is_empty() or not tg.get("alive", false):
		return slot
	var aim := run.aim_point(tg)
	var goal := Vector3(aim.x * 0.8 + slot.x * 0.2, 0.75, aim.z + 2.6)
	# Keep within range of the army.
	if goal.z < slot.z - 7.0:
		goal.z = slot.z - 7.0
	return goal


# ------------------------------------------------------------------ targeting

func _corridor() -> float:
	return float(run.def.get("corridor", Balance.CORRIDOR))


## PAINT: the hero's painted target when it is in reach, else the nearest hostile ahead.
func _paint_target(m: Dictionary) -> Dictionary:
	var reach := float((m["st"] as Dictionary).get("range", 10.0))
	var p: Dictionary = run.painted
	if not p.is_empty() and p.get("alive", false):
		var di := float(p["d"]) - run.d
		if di >= -0.5 and di <= reach:
			return p
	var tg := run.machine_targets(run.hx, Balance.WEAPON_LATERAL, reach, 1)
	return tg[0] if not tg.is_empty() else {}


## LANE: hostiles in the hero corridor (x = `x`), nearest first.
func _lane_targets(x: float, reach: float, count: int) -> Array[Dictionary]:
	return run.machine_targets(x, _corridor(), reach, count)


## True when a shot at `it` crosses the Prism (the Prism is fielded and docked, and the target
## is in the hero's lane beyond it).
func prism_crosses(it: Dictionary) -> bool:
	var pm := find("prism")
	if pm.is_empty() or float(pm["arrive"]) < 1.0 or it.is_empty():
		return false
	if float(it["d"]) < run.d + 2.5:
		return false
	return absf(float(it["x"]) - run.hx) <= _corridor() + run.half_span(it)


func prism_amp() -> float:
	var pm := find("prism")
	if pm.is_empty():
		return 0.0
	return float((pm["st"] as Dictionary).get("amp", 0.2)) + float(((pm["e"] as Dictionary).get("mods", {}) as Dictionary).get("amp_add", 0.0))


func prism_pos() -> Vector3:
	var pm := find("prism")
	if pm.is_empty():
		return Vector3.INF
	var node := pm["node"] as Node3D
	return node.global_position + Vector3(0, WeaponModels.PRISM_Y * float(ArsenalData.CONVOY["scale"]), 0)


# ------------------------------------------------------------------ damage

## Bucket 2 of machine `m` (plus the Prism amp when `amp`).
func _b2(m: Dictionary, amp := false) -> float:
	var e: Dictionary = m["e"]
	var b := 1.0 + float(e.get("add", 0.0)) + float(m["over_add"])
	var assist: Dictionary = run.profile.get("assist", {})
	b += float(assist.get("dmg_add", 0.0))
	if amp:
		b += prism_amp()
	return b


## Bucket 3 for a hit of machine `m` on `it` (§2.1): the best condition, clamped.
func _vs(m: Dictionary, it: Dictionary) -> float:
	var st: Dictionary = m["st"]
	var k := str(it.get("kind", ""))
	var v := 1.0
	if k in STRUCTURES:
		v = maxf(v, float(st.get("structures", 1.0)))
	if k == "fortress":
		v = maxf(v, float(((m["e"] as Dictionary).get("mods", {}) as Dictionary).get("boss_vs", 1.0)))
	if k == "squad":
		v = maxf(v, statuses.vs(it))
	return clampf(v, ArsenalData.VS_CLAMP.x, ArsenalData.VS_CLAMP.y)


## Deals `n` (bucket 1) of machine `m` to `it` and applies its status. Returns what landed.
func deal(m: Dictionary, it: Dictionary, n: float, amp := false, status := true) -> float:
	if it.is_empty() or not it.get("alive", false) or n <= 0.0:
		return 0.0
	var id := str(m["id"])
	var dealt := run.hurt(it, n * _b2(m, amp) * _vs(m, it), id)
	if str(it.get("kind", "")) == "squad":
		m["kills"] = float(m["kills"]) + dealt
		if status:
			_status_hit(m, it)
	return dealt


func _status_hit(m: Dictionary, it: Dictionary) -> void:
	var e: Dictionary = m["e"]
	var mods: Dictionary = e.get("mods", {})
	var src := {"id": str(m["id"]), "stats": m["st"], "mods": mods, "acc_mult": float(e.get("acc_mult", 1.0))}
	var proc := float(e.get("proc", 1.0))
	var st := str(e.get("status", ""))
	if st != "" and not bool(mods.get("no_mark", false)):
		statuses.apply(it, st, proc, src)
	# Ascension extras (Storm Ballista Jolt, Hunter Pod Mark, Spectral Lance Burn).
	for pair: Array in [["applies_jolt", "jolt"], ["applies_mark", "mark"], ["applies_burn", "burn"]]:
		if bool(mods.get(pair[0], false)) and str(pair[1]) != st:
			statuses.apply(it, str(pair[1]), proc, src)


## Damage to everything hostile within `radius` of `pos` (structures by their span), except
## `skip`. Returns the hits.
func area(m: Dictionary, pos: Vector3, radius: float, n_squad: float, n_struct: float, skip: Dictionary = {}, ground := false) -> int:
	var hits := 0
	for it in run.machine_targets_near(pos, radius):
		if it == skip:
			continue
		var sq := str(it["kind"]) == "squad"
		deal(m, it, n_squad if sq else n_struct)
		hits += 1
	return hits


# ------------------------------------------------------------------ step

## Moves, aims and fires the machines and the army volleys for one step.
func step(dt: float) -> void:
	var lasing := false
	for m in machines:
		_place(m, dt)
		m["kick"] = maxf(float(m["kick"]) - KICK_DECAY * dt, 0.0)
		m["cheer"] = maxf(float(m["cheer"]) - dt, 0.0)
		if float(m["arrive"]) < 1.0:
			continue
		m["cd"] = float(m["cd"]) - dt
		match str(m["id"]):
			"drone":
				_drone(m)
			"ballista":
				_ballista(m)
			"cannon":
				_cannon(m)
			"rockets":
				_rockets(m)
			"mortar":
				_mortar(m)
			"gatling":
				_gatling(m, dt)
			"laser":
				lasing = _laser(m, dt) or lasing
			"railgun":
				_railgun(m, dt)
			"prism":
				_prism(m)
			_:
				_generic(m)
	_strips(dt)
	statuses.step(dt)
	if lasing != _laser_on:
		_laser_on = lasing
		if lasing:
			Audio.laser_on()
		else:
			Audio.laser_off()
	_volleys(dt)


func _ready_to_fire(m: Dictionary, period: float, tg: Dictionary) -> bool:
	m["tg"] = tg
	if tg.is_empty():
		m["cd"] = maxf(float(m["cd"]), 0.0)
		return false
	m["aim"] = run.aim_point(tg)
	if float(m["cd"]) > 0.0:
		return false
	m["cd"] = float(m["cd"]) + period
	m["kick"] = 1.0
	return true


func _muzzle(m: Dictionary) -> Vector3:
	var node := m["node"] as Node3D
	var mz: Node3D = node.get_meta("muzzle") if node.has_meta("muzzle") else null
	return mz.global_position if mz else node.global_position + Vector3(0, 0.7, 0)


## A straight shot (bolt / orb / dart) from the muzzle to `to`; through the Prism when `amp`
## (two legs: muzzle -> prism flash -> target). Calls `cb` on impact.
func _shot(m: Dictionary, to: Vector3, kind: String, speed: float, amp: bool, cb: Callable) -> void:
	var mz := _muzzle(m)
	run.effects.muzzle(mz, WeaponModels.glow_color(str(m["id"])), (to - mz).normalized())
	if amp:
		var pp := prism_pos()
		if pp != Vector3.INF and pp.z > to.z:
			var col := WeaponModels.glow_color("prism")
			run.effects.projectile(mz, pp, kind, mz.distance_to(pp) / speed, func() -> void:
				run.effects.prism_flash(pp, col, (to - pp).normalized(), 1 + int(find("prism").get("rank", 1) >= 3))
				run.effects.projectile(pp, to, kind, pp.distance_to(to) / speed, cb))
			return
	run.effects.projectile(mz, to, kind, mz.distance_to(to) / speed, cb)


func _drone(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var tg := _paint_target(m)
	if not _ready_to_fire(m, 1.0 / maxf(float(st.get("rate", 2.0)), 0.1), tg):
		return
	var n := clampi(int(st.get("drones", 1)), 1, int(ArsenalData.CAPS["drones"]))
	var amp := prism_crosses(tg)
	var per := float(st.get("damage", 1.0)) * float(st.get("pierce", 1))
	_sfx("drone", 0, -13.0)
	for k in n:
		var to := run.aim_point(tg) + Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.2), 0.0)
		var item := tg
		_shot(m, to, "tracer_dot", SPEED["drone"], amp, func() -> void: deal(m, item, per, amp))


func _ballista(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var reach := float(st.get("range", 16.0))
	var lane := _lane_targets(run.hx, reach, int(ArsenalData.CAPS["pierce"]) + 1)
	if not _ready_to_fire(m, 1.0 / maxf(float(st.get("rate", 0.9)), 0.1), lane[0] if not lane.is_empty() else {}):
		return
	var amp := prism_crosses(lane[0])
	var pierce := mini(int(st.get("pierce", 2)) + (1 if amp else 0), int(ArsenalData.CAPS["pierce"]))
	var dmg := float(st.get("damage", 3.0))
	var bolts := clampi(int(st.get("bolts", 1)), 1, 3)
	_sfx("ballista", 0, -8.0)
	for b in bolts:
		var list := lane.duplicate()
		var off := Vector3((b - (bolts - 1) * 0.5) * 0.35, 0.0, 0.0)
		var end := run.aim_point(list[mini(pierce, list.size()) - 1]) + off
		var first := run.aim_point(list[0])
		_shot(m, first + off, "bolt", SPEED["ballista"], amp, func() -> void: _pierce_line(m, list, pierce, dmg, amp, end))


## A piercing bolt spends `pierce` hits down the lane: a squad takes damage x the hits left
## (it passes through ranks) and stops the bolt unless wiped; a structure takes one hit.
func _pierce_line(m: Dictionary, list: Array[Dictionary], pierce: int, dmg: float, amp: bool, end: Vector3) -> void:
	var left := pierce
	var col := WeaponModels.glow_color(str(m["id"]))
	var k := 0
	for it in list:
		if left <= 0:
			break
		if not it.get("alive", false):
			continue
		var at := run.aim_point(it)
		if k > 0:
			run.effects.pierce_ring(at, Vector3(0, 0, -1), col)
		k += 1
		if str(it["kind"]) == "squad":
			var dealt := deal(m, it, dmg * left, amp)
			left -= maxi(1, ceili(dealt / maxf(dmg * _b2(m, amp), 0.01)))
			if it.get("alive", false):
				break
		else:
			deal(m, it, dmg, amp)
			left -= 1
	if k > 1:
		run.effects.projectile(run.aim_point(list[0]), end, "bolt", 0.12, Callable())


func _cannon(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var tg := _paint_target(m)
	var rate := float(st.get("rate", 0.6))
	if not _ready_to_fire(m, 1.0 / maxf(rate, 0.05), tg):
		return
	var amp := prism_crosses(tg)
	var to := run.aim_point(tg)
	var item := tg
	_sfx("cannon", 0, -8.0)
	_shot(m, to, "orb", SPEED["cannon"], amp, func() -> void: _orb_hit(m, item, to, amp, false))


func _orb_hit(m: Dictionary, it: Dictionary, at: Vector3, amp: bool, mini_orb: bool) -> void:
	var st: Dictionary = m["st"]
	var dmg := float(st.get("damage", 2.0)) * (0.5 if mini_orb else 1.0)
	var r := float(st.get("radius", 1.2))
	if it.get("alive", false):
		var sq := str(it["kind"]) == "squad"
		deal(m, it, dmg + (float(st.get("splash", 0)) if sq and not mini_orb else 0.0), amp)
	area(m, Vector3(at.x, 0.0, at.z), r, dmg * 0.5, dmg * 0.5, it)
	if mini_orb:
		return
	var split := int(st.get("split", 0)) + int(((m["e"] as Dictionary).get("mods", {}) as Dictionary).get("split_add", 0))
	if bool(((m["e"] as Dictionary).get("mods", {}) as Dictionary).get("burn_ring", false)):
		run.effects.ring(Vector3(at.x, 0.05, at.z), WeaponModels.glow_color("cannon"), r * 1.3, 0.6)
	for k in split:
		var a := TAU * k / maxf(float(split), 1.0) + randf() * 0.6
		var to := Vector3(at.x + cos(a) * 1.1, 0.4, at.z + sin(a) * 0.9)
		var item := it
		run.effects.projectile(at + Vector3(0, 0.4, 0), to, "orb", 0.22, func() -> void: _orb_hit(m, item, to, amp, true))


func _rockets(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var tg := _paint_target(m)
	if not _ready_to_fire(m, float(st.get("period", 2.5)), tg):
		return
	var amp := prism_crosses(tg)
	var n := int(st.get("volley", 4))
	var dmg := float(st.get("damage", 2.0))
	var node := m["node"] as Node3D
	var item := tg
	_sfx("rockets", 0, -7.0)
	for k in n:
		var off := Vector3(randf_range(-0.45, 0.45), 0.0, randf_range(-0.35, 0.35))
		var tw := get_tree().create_timer(0.07 * k, false)
		tw.timeout.connect(func() -> void:
			if not is_instance_valid(node):
				return
			var from := _muzzle(m)
			var to := run.aim_point(item) + off
			run.effects.projectile(from, to, "missile_trail", from.distance_to(to) / SPEED["rockets"], func() -> void: _rocket_hit(m, item, to, dmg, amp)))


func _rocket_hit(m: Dictionary, it: Dictionary, at: Vector3, dmg: float, amp: bool) -> void:
	var st: Dictionary = m["st"]
	deal(m, it, dmg, amp)
	area(m, Vector3(at.x, 0.0, at.z), float(st.get("radius", 0.8)), dmg * 0.25, 0.0, it)
	var bl := int(st.get("bomblets", 0))
	if bl > 0 and it.get("alive", false):
		var bd := float(st.get("bomblet_damage", 1.0))
		for k in bl:
			var to := at + Vector3(randf_range(-0.7, 0.7), -0.3, randf_range(-0.6, 0.6))
			var item := it
			run.effects.projectile(at + Vector3(0, 0.5, 0), to, "drone", 0.25, func() -> void:
				deal(m, item, bd, amp, false)
				run.effects.tech_blast(to, float(st.get("bomblet_radius", 0.6))))


func _mortar(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var ahead := float((((m["e"] as Dictionary).get("move", {})) as Dictionary).get("ahead", 12.0))
	m["tg"] = {}
	# The ring shows where the next shell will land: (hero x, hero d + 12).
	m["aim"] = Vector3(run.hx, 0.0, -run.d - ahead)
	if float(m["cd"]) > 0.0:
		return
	# Hold fire until something hostile is ahead (no shells into an empty road).
	if run.machine_targets(run.hx, 3.5, ahead + 4.0, 1).is_empty():
		m["cd"] = 0.0
		return
	m["cd"] = float(st.get("period", 2.2))
	m["kick"] = 1.0
	var land := Vector3(run.hx, 0.0, -run.d - ahead)
	var r := float(st.get("radius", 1.6))
	var tele := float(st.get("telegraph", 0.8))
	var col := WeaponModels.glow_color("mortar")
	run.effects.telegraph_ring(land, r, col, tele)
	var mz := _muzzle(m)
	run.effects.muzzle(mz, col, (land - mz).normalized())
	_sfx("mortar", 0, -6.0)
	run.effects.projectile(mz, land, "shell_arc", tele, func() -> void: _shell_hit(m, land, r))


func _shell_hit(m: Dictionary, land: Vector3, r: float) -> void:
	var st: Dictionary = m["st"]
	var dmg := float(st.get("damage", 4.0))
	area(m, land, r, dmg + r * AREA_KILLS, dmg, {}, true)
	run.juice.add_trauma(0.08)
	var bl := int(st.get("bomblets", 0))
	if bl > 0:
		var bd := float(st.get("bomblet_damage", 1.5))
		var br := float(st.get("bomblet_radius", 0.8))
		for k in bl:
			var a := TAU * k / float(bl) + 0.4
			var p := land + Vector3(cos(a), 0.0, sin(a)) * (r * 0.9)
			var tw := get_tree().create_timer(0.12 + 0.07 * k, false)
			tw.timeout.connect(func() -> void:
				run.effects.shell_impact(p, br)
				area(m, p, br, bd + br * AREA_KILLS * 0.5, bd))
	var quake := float(((m["e"] as Dictionary).get("mods", {}) as Dictionary).get("quake_s", 0.0))
	if quake > 0.0:
		run.effects.ring(land + Vector3(0, 0.05, 0), WeaponModels.glow_color("mortar"), r * 1.6, quake)


func _gatling(m: Dictionary, dt: float) -> void:
	var st: Dictionary = m["st"]
	var tg := _paint_target(m)
	m["tg"] = tg
	var spin_t := float(st.get("spinup", 1.0))
	var from := float(st.get("spin_from", 0.5))
	if tg.is_empty():
		m["spin"] = maxf(float(m["spin"]) - dt * 1.5, 0.0)
		m["bullets"] = 0.0
		return
	m["aim"] = run.aim_point(tg)
	m["spin"] = 1.0 if spin_t <= 0.0 else minf(float(m["spin"]) + dt / spin_t, 1.0)
	var rate := float(st.get("rate", 6.0)) * lerpf(from, 1.0, float(m["spin"]))
	m["bullets"] = float(m["bullets"]) + rate * dt
	m["kick"] = 0.35
	var amp := prism_crosses(tg)
	var per := float(st.get("damage", 0.6)) * (1.0 + 0.5 * float(st.get("ricochet", 1)))
	while float(m["bullets"]) >= 1.0:
		m["bullets"] = float(m["bullets"]) - 1.0
		deal(m, tg, per, amp)
		if not tg.get("alive", false):
			break
	if randf() < 6.0 * dt:
		_sfx("gatling", 0, -13.0)


func _laser(m: Dictionary, dt: float) -> bool:
	var st: Dictionary = m["st"]
	var reach := float(st.get("range", 10.0))
	var lane := _lane_targets(run.hx, reach, maxi(int(st.get("pierce", 1)), 1))
	if lane.is_empty():
		m["tg"] = {}
		m["ramp"] = 0.0
		return false
	var tg: Dictionary = lane[0]
	m["tg"] = tg
	m["aim"] = run.aim_point(tg)
	if m["ramp_tg"] != tg:
		m["ramp_tg"] = tg
		m["ramp"] = 0.0
	m["ramp"] = float(m["ramp"]) + dt
	var cap := float(st.get("ramp_cap", 2.5))
	var mult := minf(1.0 + float(st.get("ramp", 0.5)) * float(m["ramp"]), cap)
	var amp := prism_crosses(tg)
	var hits: Array[Dictionary] = lane.duplicate()
	var share := 1.0
	if amp:
		# Through the Prism the beam splits into 3 at 60% (§2.5).
		var more := run.machine_targets(run.hx, Balance.WEAPON_LATERAL, reach, int(st.get("beam_split", 3)) + 2)
		for x in more:
			if hits.size() >= 3:
				break
			if not hits.has(x):
				hits.append(x)
		share = float((find("prism")["st"] as Dictionary).get("beam_split_share", 0.6)) if hits.size() > 1 else 1.0
	m["beams"] = hits
	m["kick"] = 1.0
	for it in hits:
		var crowd := str(it["kind"]) == "squad"
		var dps := float(st.get("dps_crowd" if crowd else "dps", 3.0)) * mult * share
		# Status procs every 0.2 s of beam (proc 0.2 per tick).
		var tick := fmod(float(m["ramp"]), 0.2) < dt
		deal(m, it, dps * dt, amp, tick)
	return true


func _railgun(m: Dictionary, dt: float) -> void:
	var st: Dictionary = m["st"]
	var reach := float(st.get("range", 22.0))
	var charge := float(st.get("charge", 3.0))
	var tele := float(st.get("telegraph", 0.4))
	var col := WeaponModels.glow_color("railgun")
	if float(m["tele"]) >= 0.0:
		m["tele"] = float(m["tele"]) + dt
		m["charge"] = 1.0
		if float(m["tele"]) >= tele:
			m["tele"] = -1.0
			m["charge"] = 0.0
			_rail_fire(m, reach)
		return
	m["charge"] = minf(float(m["charge"]) + dt / maxf(charge, 0.2), 1.0)
	var lane := _lane_targets(run.hx, reach, 1)
	m["tg"] = lane[0] if not lane.is_empty() else {}
	if not lane.is_empty():
		m["aim"] = run.aim_point(lane[0])
	if float(m["charge"]) >= 1.0 and not lane.is_empty():
		# The glow: the lane locks where the hero stands now (line it up before the glow).
		m["tele"] = 0.0
		m["lane_x"] = run.hx
		run.effects.telegraph_rails(Vector3(run.hx, 0.0, -run.d + 0.5), Vector3(0, 0, -1), reach, col, tele, _corridor() * 2.0)
		_sfx("railgun_charge", 0, -6.0)


func _rail_fire(m: Dictionary, reach: float) -> void:
	var st: Dictionary = m["st"]
	var x := float(m["lane_x"])
	var lane := run.machine_targets(x, _corridor(), reach, 64)
	var amp := false
	for it in lane:
		amp = amp or prism_crosses(it)
	var dmg := float(st.get("damage", 18.0))
	var hits: Array[Vector3] = []
	for it in lane:
		hits.append(run.aim_point(it))
		deal(m, it, dmg, amp)
	var mz := _muzzle(m)
	var end := Vector3(x, 0.9, -run.d - reach)
	run.effects.rail_fire(mz, end, WeaponModels.glow_color("railgun"), hits)
	if amp:
		run.effects.prism_flash(prism_pos(), WeaponModels.glow_color("prism"), Vector3(0, 0, -1), 3)
	m["kick"] = 1.0
	run.juice.add_trauma(0.12)
	_sfx("railgun", 1, -3.0)
	var strip := float(st.get("lane_jolt_s", 0.0))
	if strip > 0.0:
		_lane_strips.append({"x": x, "d0": run.d, "d1": run.d + reach, "t": strip, "m": m})


## Railgun Rank III: the lane strip Jolts squads that cross it for a while.
func _strips(dt: float) -> void:
	for k in range(_lane_strips.size() - 1, -1, -1):
		var s: Dictionary = _lane_strips[k]
		s["t"] = float(s["t"]) - dt
		if float(s["t"]) <= 0.0:
			_lane_strips.remove_at(k)
			continue
		var m: Dictionary = s["m"]
		for it in run.machine_targets(float(s["x"]), _corridor(), float(s["d1"]) - run.d, 16):
			if str(it["kind"]) == "squad" and float(it["d"]) >= float(s["d0"]) and not statuses.has(it, "jolt"):
				_status_hit(m, it)
		if randf() < dt * 10.0:
			var z := -lerpf(maxf(float(s["d0"]), run.d), float(s["d1"]), randf())
			run.effects.lightning([Vector3(float(s["x"]) - 0.5, 0.05, z), Vector3(float(s["x"]), 0.25, z - 0.4), Vector3(float(s["x"]) + 0.5, 0.05, z - 0.2)],
				WeaponModels.glow_color("railgun"), 0.12, 0.04, false)


func _prism(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var lane := _lane_targets(run.hx, float(st.get("range", 10.0)), 1)
	if not _ready_to_fire(m, 1.0 / maxf(float(st.get("ray_rate", 1.0)), 0.1), lane[0] if not lane.is_empty() else {}):
		return
	var tg: Dictionary = lane[0]
	var from := prism_pos()
	var to := run.aim_point(tg)
	run.effects.prism_flash(from, WeaponModels.glow_color("prism"), (to - from).normalized(), 1)
	var item := tg
	run.effects.projectile(from, to, "orb", from.distance_to(to) / SPEED["prism"], func() -> void: deal(m, item, float(st.get("ray_damage", 1.0))))
	_sfx("prism", 0, -10.0)


## Fallback for machines without a Meta-1 behaviour: plain shots by their sheet numbers.
func _generic(m: Dictionary) -> void:
	var st: Dictionary = m["st"]
	var tg := _paint_target(m)
	if not _ready_to_fire(m, 1.0 / maxf(float(st.get("rate", 1.0)), 0.1), tg):
		return
	var item := tg
	_shot(m, run.aim_point(tg), "bolt", 20.0, false, func() -> void: deal(m, item, float(st.get("damage", 1.0))))


## Sound per machine: its own sfx names (MACHINES[id].sfx, WS3) when they exist, else the etap1
## stand-ins.
func _sfx(id: String, which: int, db: float) -> void:
	var own: Array = (ArsenalData.MACHINES.get(id, {}) as Dictionary).get("sfx", [])
	if which < own.size() and Audio.has_sfx(str(own[which])):
		Audio.play(str(own[which]), db, 0.08)
		return
	var fallback := {"drone": "drone", "ballista": "ballista", "cannon": "plasma", "rockets": "rocket", "mortar": "cannon",
			"gatling": "turret_shot", "railgun": "tesla", "railgun_charge": "laser", "prism": "upgrade"}
	Audio.play(str(fallback.get(id, "arrow")), db - (6.0 if id == "railgun_charge" else 0.0), 0.1)


# ------------------------------------------------------------------ army volleys

## Crossbow / blaster volleys of the army itself.
func _volleys(dt: float) -> void:
	if run.arm_tier <= 0 or run.army < 1:
		return
	_volley_cd -= dt
	if _volley_cd > 0.0:
		return
	var tier: Dictionary = Balance.ARM_TIERS[run.arm_tier]
	var it := run.volley_target(float(tier["range"]), bool(tier.get("structures", false)))
	if it.is_empty():
		_volley_cd = 0.0
		return
	_volley_cd = float(tier["period"])
	var dmg := maxf(1.0, float(run.army) * float(tier["volley"]) * run.volley_mult())
	if str(it["kind"]) != "squad":
		dmg = maxf(1.0, dmg * float(tier.get("struct_share", 1.0)))
	var aim := run.aim_point(it)
	var army := run.army_view
	var shooters := army.front(mini(3 + run.army / 40, 6))
	var item := it
	var first := true
	for i in shooters:
		var p := army.position_of(i) + Vector3(0, 0.55, 0)
		var cb := (func() -> void: run.hurt(item, dmg, "volley")) if first else Callable()
		first = false
		run.effects.projectile(p, aim, "volley", p.distance_to(aim) / 24.0, cb)
	Audio.play("volley", -9.0, 0.12)


# ------------------------------------------------------------------ visuals

## Per-frame visuals: aiming, recoil, wheels, beams, the gatling stream, the railgun charge,
## the mortar's next landing ring, status overlays.
func draw(dt: float, t: float) -> void:
	for m in machines:
		var node := m["node"] as Node3D
		var id := str(m["id"])
		var aim: Vector3 = m.get("aim", Vector3.INF)
		var ready := float(m["arrive"]) >= 1.0
		if aim != Vector3.INF and ready:
			WeaponModels.aim(node, aim, 1.0 - exp(-12.0 * dt))
		else:
			WeaponModels.aim(node, node.global_position + Vector3(0, 0, -5), 1.0 - exp(-6.0 * dt))
		var fire := float(m["kick"])
		var col := WeaponModels.glow_color(id)
		match id:
			"laser":
				var beams: Array = m.get("beams", [])
				var on: bool = ready and not (m["tg"] as Dictionary).is_empty() and not beams.is_empty()
				fire = 1.0 if on else 0.0
				var mz := _muzzle(m)
				var cap := float((m["st"] as Dictionary).get("ramp_cap", 2.5))
				var ramp := clampf((minf(1.0 + 0.5 * float(m["ramp"]), cap) - 1.0) / maxf(cap - 1.0, 0.01), 0.0, 1.0)
				var bid := node.get_instance_id()
				if on and prism_crosses(m["tg"]):
					var pts: Array[Vector3] = []
					for it: Dictionary in beams:
						if it.get("alive", false):
							pts.append(run.aim_point(it))
					run.effects.refract_beam(bid, mz, prism_pos(), pts, col, true, ramp)
				elif on:
					run.effects.beam(bid, mz, run.aim_point(beams[0]), col, true, ramp)
					for i in range(1, beams.size()):
						var it2: Dictionary = beams[i]
						if it2.get("alive", false):
							run.effects.beam(bid + i, run.aim_point(beams[0]), run.aim_point(it2), col, true, ramp, 0.16)
				else:
					run.effects.beam(bid, mz, mz, col, false)
			"gatling":
				var on2: bool = ready and not (m["tg"] as Dictionary).is_empty()
				fire = float(m["spin"])
				var gold := bool(((m["e"] as Dictionary).get("mods", {}) as Dictionary).get("gold_tracers", false))
				run.effects.stream(node.get_instance_id(), _muzzle(m), aim if aim != Vector3.INF else _muzzle(m), Color(1.0, 0.78, 0.3) if gold else col, on2, float(m["spin"]))
			"railgun":
				var k := float(m["charge"])
				WeaponModels.set_charge(node, k)
				if ready and k > 0.05:
					run.effects.rail_charge(_muzzle(m), col, k)
		if float(m["cheer"]) > 0.0:
			WeaponModels.set_crew_pose(node, "cheer")
		elif fire > 0.2:
			WeaponModels.set_crew_pose(node, "load")
		else:
			WeaponModels.set_crew_pose(node, "idle")
		WeaponModels.animate(node, t, fire, float(m["roll"]))
	statuses.draw()


## Fielded machines for Run.weapons: [{kind, level, id, rank, family}] (kind / level = id / rank
## for etap1 readers).
func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in machines:
		out.append({"kind": str(m["id"]), "level": int(m["rank"]), "id": str(m["id"]), "rank": int(m["rank"]),
				"family": ArsenalData.family_of(str(m["id"])), "over": int(m["over"])})
	return out


## Run.result `fielded`: [{id, rank, kills, evolved, fused}].
func fielded_report() -> Array:
	var out: Array = []
	for m in machines:
		out.append({"id": str(m["id"]), "rank": int(m["rank"]), "kills": int(round(float(m["kills"]))), "evolved": false, "fused": false})
	return out


func stop() -> void:
	if _laser_on:
		_laser_on = false
		Audio.laser_off()
	for m in machines:
		m["tg"] = {}
		m["beams"] = []
		m["spin"] = 0.0


## Leaving a run mid-beam (pause -> Menu / Retry frees it): the looping hum must stop too.
func _exit_tree() -> void:
	stop()
