class_name Statuses
extends RefCounted
## Squad statuses of the run (arsenal_design.md §2.1, ArsenalData.STATUSES; Meta-1: no
## reactions, no set bonuses). Statuses live on the SQUAD (the item dictionary, key "status"),
## never per unit. Each source applies `proc` stacks per hit (MACHINES[id].proc); fractional
## stacks accumulate per squad and status ("acc").
##
## Rules implemented:
## - STAGGER (1 stack, 0.4 s): the squad is knocked back 0.3 u (x stagger_push_mult) - a visual
##   recoil of its formation; ignores the Armored penalty (properties are Meta-2).
## - JOLT (max 3, 2 s per stack): the squad's next received hit (hero or machine) chains to the
##   nearest other squad within 2 u (+ jump_r_add) for 75% of it and consumes one stack.
## - BURN (refresh, 3 s): removes `units_per_s x acc_mult(source)` (+ burn_units_add) units per
##   second (fractions accumulate); a squad wiped while burning passes the Burn to the nearest
##   squad within 3 u (1 + burn_jumps_add times).
## - MARK (refresh, mark_s of the source, 3 s): every hit on the squad gets vs 1.25 (source
##   mark_vs, + mark_add) in bucket 3.
## - CHILL / SEAL: tracked and drawn with the same grammar (no Meta-1 machine applies them).
## Overlays: Effects.status() ring per squad and status (stacks lit) + a unit tint through
## CrowdView.set_overlay in the colour of the strongest status.

## Draw priority of the unit tint (the ring shows every status).
const ORDER: Array[String] = ["burn", "jolt", "chill", "mark", "seal", "stagger"]
const CHAIN_SHARE := 0.75

var run: Run
## Squads that carry (or carried) a status this run.
var _list: Array[Dictionary] = []
## Applications per status this run (Run.result stats.statuses).
var counts := {"freeze": 0, "burn": 0, "mark": 0, "stun": 0, "jolt": 0, "seal": 0, "stagger": 0, "chill": 0}


func _init(p_run: Run) -> void:
	run = p_run


## Applies `stacks` (the source's proc) of status `st` to squad `it`. `src` = the source machine
## entry (its stats / mods: mark_s, mark_vs, mark_add, burn_units_add, burn_jumps_add,
## stagger_push_mult, jolt_s_add, jump_r_add, acc_mult).
func apply(it: Dictionary, st: String, stacks: float, src: Dictionary = {}) -> void:
	if st == "" or it.is_empty() or not it.get("alive", false) or str(it.get("kind", "")) != "squad":
		return
	if not bool(ArsenalData.FEATURES["statuses"]) or not ArsenalData.STATUSES.has(st):
		return
	var rule: Dictionary = ArsenalData.STATUSES[st]
	var ss: Dictionary = it.get("status", {})
	if ss.is_empty():
		it["status"] = ss
		_list.append(it)
	var e: Dictionary = ss.get(st, {})
	var fresh := e.is_empty() or float(e.get("t", 0.0)) <= 0.0
	var acc := float(e.get("acc", 0.0)) + stacks
	var whole := int(floor(acc + 0.0001))
	e["acc"] = acc - whole
	ss[st] = e
	if whole <= 0:
		return
	var mods: Dictionary = src.get("mods", {})
	var stats: Dictionary = src.get("stats", {})
	var cap := int(rule.get("max_stacks", 1))
	e["stacks"] = mini(int(e.get("stacks", 0)) + whole, cap) if bool(rule.get("per_stack", false)) else 1
	var life := float(rule.get("decay_s", 1.0))
	match st:
		"mark":
			life = float(stats.get("mark_s", life))
			e["vs"] = maxf(float(e.get("vs", 0.0)), float(stats.get("mark_vs", rule.get("vs", 1.25))) + float(mods.get("mark_add", 0.0)))
		"burn":
			var rate := float(rule.get("units_per_s", 1.0)) * float(src.get("acc_mult", 1.0)) + float(mods.get("burn_units_add", 0.0))
			e["rate"] = maxf(float(e.get("rate", 0.0)), rate)
			e["jumps"] = maxi(int(e.get("jumps", 0)), 1 + int(mods.get("burn_jumps_add", 0)))
			e["src"] = str(src.get("id", ""))
		"jolt":
			life += float(mods.get("jolt_s_add", 0.0))
			e["r"] = float(rule.get("chain_r", 2.0)) + float(mods.get("jump_r_add", 0.0))
			e["chains"] = 1 + int(mods.get("chain_add", 0))
		"stagger":
			var push := float(rule.get("push", 0.3)) * float(mods.get("stagger_push_mult", 1.0))
			run.hazards.push_squad(it, push)
	e["t"] = life
	e["life"] = life
	counts[st] = int(counts.get(st, 0)) + 1
	if fresh:
		run.effects.status_pop(_center(it) + Vector3(0, 1.0, 0), st)


func has(it: Dictionary, st: String) -> bool:
	var ss: Dictionary = it.get("status", {})
	return ss.has(st) and float((ss[st] as Dictionary).get("t", 0.0)) > 0.0


func stacks(it: Dictionary, st: String) -> int:
	return int(((it.get("status", {}) as Dictionary).get(st, {}) as Dictionary).get("stacks", 0)) if has(it, st) else 0


## Bucket-3 condition from statuses on `it` (Mark), 1.0 when none.
func vs(it: Dictionary) -> float:
	if not has(it, "mark"):
		return 1.0
	return float(((it["status"] as Dictionary)["mark"] as Dictionary).get("vs", 1.25))


## A hit of `n` landed on `it` from `source`: a Jolt stack chains it to a neighbour squad.
func on_hit(it: Dictionary, n: float, source: String) -> void:
	if source in ["burn", "chain", "clash", "siege"] or n <= 0.0 or not has(it, "jolt"):
		return
	var e: Dictionary = (it["status"] as Dictionary)["jolt"]
	var from := it
	var hit: Array[Dictionary] = [it]
	# Capacitor (+chain_add): the chain jumps on to further squads.
	for k in maxi(int(e.get("chains", 1)), 1):
		var other := _nearest_squad(from, float(e.get("r", 2.0)), hit)
		if other.is_empty():
			break
		if k == 0:
			e["stacks"] = int(e.get("stacks", 1)) - 1
			if int(e["stacks"]) <= 0:
				e["t"] = 0.0
		var a := _center(from) + Vector3(0, 0.7, 0)
		var b := _center(other) + Vector3(0, 0.7, 0)
		var col: Color = (Effects.STATUS_LOOK["jolt"] as Dictionary)["color"]
		run.effects.lightning([a, a.lerp(b, 0.5) + Vector3(0, 0.6, 0), b], col, 0.22, 0.06, true)
		run.hurt(other, n * pow(CHAIN_SHARE, k + 1), "chain")
		hit.append(other)
		from = other


## Decays statuses and ticks Burn.
func step(dt: float) -> void:
	for k in range(_list.size() - 1, -1, -1):
		var it := _list[k]
		var ss: Dictionary = it.get("status", {})
		if not it.get("alive", false):
			_on_wiped(it)
			_list.remove_at(k)
			continue
		var any := false
		for st: String in ss:
			var e: Dictionary = ss[st]
			var t := float(e.get("t", 0.0))
			if t <= 0.0:
				continue
			t -= dt
			if st == "burn" and t > -dt:
				e["tick"] = float(e.get("tick", 0.0)) + float(e.get("rate", 1.0)) * minf(dt, t + dt)
				if float(e["tick"]) >= 1.0:
					var n := floorf(float(e["tick"]))
					e["tick"] = float(e["tick"]) - n
					run.hurt(it, n, "burn")
			# Jolt and Chill lose one stack per decay period.
			var rule: Dictionary = ArsenalData.STATUSES.get(st, {})
			if bool(rule.get("per_stack", false)) and t <= 0.0 and int(e.get("stacks", 0)) > 1:
				e["stacks"] = int(e["stacks"]) - 1
				t = float(e.get("life", 1.0))
			e["t"] = maxf(t, 0.0)
			any = any or t > 0.0
		if not any and it.has("crowd") and is_instance_valid(it["crowd"]):
			(it["crowd"] as CrowdView).set_overlay(Color.BLACK, 0.0)


## Per-frame overlays: one ring per status on the squad, and a unit tint for the strongest.
func draw() -> void:
	for it in _list:
		if not it.get("alive", false):
			continue
		var ss: Dictionary = it.get("status", {})
		var c := _center(it)
		var r := _radius(it)
		var tint := ""
		var tint_k := 0.0
		for st in ORDER:
			if not ss.has(st):
				continue
			var e: Dictionary = ss[st]
			var t := float(e.get("t", 0.0))
			if t <= 0.0:
				continue
			# One ring id per squad (its d and x are unique on a level) and status.
			var sid := int(float(it["d"]) * 64.0) * 64 + int((float(it.get("x0", it["x"])) + 4.0) * 4.0)
			run.effects.status(sid, c, r, st, maxi(int(e.get("stacks", 1)), 1), true)
			if tint == "":
				tint = st
				tint_k = clampf(t / 0.3, 0.0, 1.0)
		if it.has("crowd") and is_instance_valid(it["crowd"]):
			var cv := it["crowd"] as CrowdView
			if tint != "":
				var col: Color = (Effects.STATUS_LOOK[tint] as Dictionary)["color"]
				cv.set_overlay(col, (0.8 if tint != "stagger" else 0.35) * tint_k)
			else:
				cv.set_overlay(Color.BLACK, 0.0)


## A squad died: Burn jumps on to the nearest squad within its jump radius.
func _on_wiped(it: Dictionary) -> void:
	if not has(it, "burn"):
		return
	var e: Dictionary = (it["status"] as Dictionary)["burn"]
	var jumps := int(e.get("jumps", 1))
	if jumps <= 0:
		return
	var other := _nearest_squad(it, float((ArsenalData.STATUSES["burn"] as Dictionary).get("jump_r", 3.0)))
	if other.is_empty():
		return
	var src := {"id": str(e.get("src", "")), "acc_mult": float(e.get("rate", 1.0)), "mods": {"burn_jumps_add": jumps - 2}}
	apply(other, "burn", 1.0, src)
	var a := _center(it) + Vector3(0, 0.5, 0)
	var b := _center(other) + Vector3(0, 0.5, 0)
	run.effects.projectile(a, b, "plasma", 0.3, Callable())


func _nearest_squad(it: Dictionary, reach: float, skip: Array[Dictionary] = []) -> Dictionary:
	var best: Dictionary = {}
	var bd := reach
	var p := _center(it)
	for sq: Dictionary in run.hazards.squads:
		if sq == it or not sq.get("alive", false) or skip.has(sq):
			continue
		var q := _center(sq)
		var dist := Vector2(p.x - q.x, p.z - q.z).length() - float(sq.get("w", 2.4)) * 0.5
		if dist < bd:
			bd = dist
			best = sq
	return best


func _center(it: Dictionary) -> Vector3:
	var p := run.hazards.squad_point(it)
	var rows := 1.0
	if it.has("sq"):
		var sq: Hazards.Squad = it["sq"]
		rows = ceilf(float(sq.shown) / float(maxi(sq.per_row, 1)))
	return Vector3(p.x, 0.0, p.z - rows * Hazards.SQUAD_DZ * 0.5 + 0.1)


func _radius(it: Dictionary) -> float:
	var w := float(it.get("w", 2.4)) * 0.5
	var depth := 0.4
	if it.has("sq"):
		var sq: Hazards.Squad = it["sq"]
		depth = ceilf(float(sq.shown) / float(maxi(sq.per_row, 1))) * Hazards.SQUAD_DZ * 0.5
	return clampf(maxf(w, depth) * 0.85, 0.7, 2.4)
