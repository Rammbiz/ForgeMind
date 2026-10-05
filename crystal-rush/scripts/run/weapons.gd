class_name Weapons
extends Node3D
## The army's war machines (from weapon crates and charge gates) and the army's own volleys
## (crossbow / blaster tiers). Etap 1 spec 5.6, rules as in LevelSim:
## - a machine shoots the nearest hostile ahead within its range and WEAPON_LATERAL of the
##   hero x (squads, turrets, barricades, geodes, crates, the fortress); vs a squad one shot
##   kills damage * pierce + splash, vs a structure it deals damage, times the level multiplier;
##   rockets fire `volley` rockets every `period` s, the laser burns `dps` continuously;
## - a duplicate crate levels its machine up (stars), a 4th kind levels up the lowest machine;
## - army volleys hit the nearest squad ahead within range (blasters also turrets, barricades
##   and the fortress) for volley * army every period.
## Machines ride at the army's flanks and behind it; a new one hops out of its crate and rolls
## into its slot. Projectiles fly with Effects; damage lands on impact.

# Rockets fly fast enough to land ahead of the marching army (at 9 u/s the army overtook the
# impact point and the explosions went off inside our own blob).
const SPEED := {"ballista": 22.0, "cannon": 15.0, "rockets": 15.0, "drone": 18.0}
const SHOT := {"ballista": "bolt", "cannon": "plasma", "rockets": "rocket", "drone": "drone"}
const KICK_DECAY := 2.5
const ARRIVE_TIME := 0.9

var run: Run
var machines: Array[Dictionary] = []    # {kind, level, cd, node, kick, slot, arrive, from, roll, lasing}
var _volley_cd := 0.0
var _laser_on := false


func setup(p_run: Run) -> void:
	run = p_run


## Adds a weapon by the crate rules. Returns the machine that changed: [kind, level].
func add(kind: String, from: Vector3) -> Array:
	for m in machines:
		if str(m["kind"]) == kind:
			return _level_up(m)
	if machines.size() < Balance.MAX_WEAPONS:
		var node := WeaponModels.machine(kind)
		add_child(node)
		node.global_position = from
		var m := {"kind": kind, "level": 1, "cd": 0.4, "node": node, "kick": 0.0, "slot": machines.size(),
				"arrive": 0.0, "from": from, "roll": 0.0, "lasing": false}
		machines.append(m)
		_place(m, 0.0, true)
		return [kind, 1]
	var low: Dictionary = machines[0]
	for m2 in machines:
		if int(m2["level"]) < int(low["level"]):
			low = m2
	return _level_up(low)


func _level_up(m: Dictionary) -> Array:
	m["level"] = mini(int(m["level"]) + 1, Balance.WEAPON_LEVEL_MULT.size())
	var node := m["node"] as Node3D
	WeaponModels.set_level(node, int(m["level"]))
	run.effects.upgrade_fx(node.global_position, WeaponModels.icon_color(str(m["kind"])))
	run.effects.shockwave(node.global_position, WeaponModels.icon_color(str(m["kind"])), 1.2)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.35, 0.1)
	tw.tween_property(node, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Audio.play("upgrade", -3.0)
	return [str(m["kind"]), int(m["level"])]


## World slot of machine `m` next to the army.
func slot_pos(m: Dictionary) -> Vector3:
	var army := run.army_view
	var r := army.radius
	var rz := r * Balance.BLOB_STRETCH
	var c := army.center
	var p := c
	match int(m["slot"]):
		0:
			p += Vector3(-(r * 0.92 + 0.62), 0, -rz * 0.15)
		1:
			p += Vector3(r * 0.92 + 0.62, 0, -rz * 0.15)
		_:
			p += Vector3(0.0, 0, rz + 0.6)
	p.x = clampf(p.x, -Balance.BRIDGE_HALF + 0.5, Balance.BRIDGE_HALF - 0.5)
	return p


## Solid circles for the army (units step around the machines).
func solids() -> Array:
	var out: Array = []
	for m in machines:
		if float(m["arrive"]) >= 1.0:
			out.append([(m["node"] as Node3D).position, 0.42])
	return out


func _place(m: Dictionary, dt: float, snap := false) -> void:
	var node := m["node"] as Node3D
	var target := slot_pos(m)
	var a := float(m["arrive"])
	var before := node.position
	if a < 1.0 and not snap:
		# Hop out of the crate, land and roll into the slot.
		a = minf(a + dt / ARRIVE_TIME, 1.0)
		m["arrive"] = a
		var from: Vector3 = m["from"]
		var e := 1.0 - pow(1.0 - a, 3.0)
		var p := from.lerp(target, e)
		p.y = 1.4 * 4.0 * minf(a * 2.2, 1.0) * (1.0 - minf(a * 2.2, 1.0)) if a < 0.45 else 0.0
		node.position = p
		if a >= 1.0:
			run.effects.shockwave(target, WeaponModels.icon_color(str(m["kind"])), 0.9)
	elif not snap:
		var k := 1.0 - exp(-9.0 * dt)
		var p2 := node.position
		p2.x += (target.x - p2.x) * k
		p2.z += (target.z - p2.z) * k + run.step_advance
		p2.y = 0.0
		node.position = p2
	else:
		node.position = m["from"]
	m["roll"] = float(m["roll"]) + absf(node.position.z - before.z) + absf(node.position.x - before.x) * 0.5


## Moves, aims and fires the machines and the army volleys for one step.
func step(dt: float) -> void:
	var lasing := false
	for m in machines:
		_place(m, dt)
		m["kick"] = maxf(float(m["kick"]) - KICK_DECAY * dt, 0.0)
		if float(m["arrive"]) < 1.0:
			continue
		var kind := str(m["kind"])
		var spec: Dictionary = Balance.WEAPONS[kind]
		var node := m["node"] as Node3D
		m["cd"] = float(m["cd"]) - dt
		var tg := run.targets(run.hx, Balance.WEAPON_LATERAL, float(spec["range"]), 1, false)
		if tg.is_empty():
			m["lasing"] = false
			m["cd"] = maxf(float(m["cd"]), 0.0)
			continue
		var it: Dictionary = tg[0]
		var aim := run.aim_point(it)
		m["aim"] = aim
		var mult: float = Balance.WEAPON_LEVEL_MULT[clampi(int(m["level"]) - 1, 0, 2)]
		var crowd := str(it["kind"]) == "squad"
		if kind == "laser":
			m["lasing"] = true
			lasing = true
			var dps := float(spec["dps_crowd" if crowd else "dps"]) * mult
			run.hurt(it, dps * dt, "laser")
			continue
		if float(m["cd"]) > 0.0:
			continue
		var period := float(spec["period"]) if kind == "rockets" else 1.0 / float(spec["rate"])
		m["cd"] = float(m["cd"]) + period
		var per := float(spec["damage"])
		if crowd:
			per = per * float(spec.get("pierce", 1)) + float(spec.get("splash", 0))
		var mz := (node.get_meta("muzzle") as Node3D).global_position
		m["kick"] = 1.0
		var col := WeaponModels.icon_color(kind)
		run.effects.muzzle(mz, col, (aim - mz).normalized())
		var item := it
		if kind == "rockets":
			var n := int(spec["volley"])
			Audio.play("rocket", -7.0, 0.1)
			for k in n:
				var off := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.3, 0.3))
				var dist := mz.distance_to(aim)
				var dmg := per * mult
				var tw := get_tree().create_timer(0.07 * k, false)
				tw.timeout.connect(func() -> void:
					if is_instance_valid(node):
						var from := (node.get_meta("muzzle") as Node3D).global_position
						run.effects.projectile(from, aim + off, "rocket", dist / SPEED["rockets"], func() -> void: run.hurt(item, dmg, "rockets")))
		else:
			var dmg2 := per * mult
			Audio.play(kind if kind != "cannon" else "plasma", -8.0 if kind != "drone" else -12.0, 0.1)
			run.effects.projectile(mz, aim, SHOT[kind], mz.distance_to(aim) / SPEED[kind], func() -> void: run.hurt(item, dmg2, kind))
	if lasing != _laser_on:
		_laser_on = lasing
		if lasing:
			Audio.laser_on()
		else:
			Audio.laser_off()
	_volleys(dt)


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
	var dmg := maxf(1.0, float(run.army) * float(tier["volley"]))
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


## Per-frame visuals: aiming, recoil, wheels, the laser beam.
func draw(dt: float, t: float) -> void:
	for m in machines:
		var node := m["node"] as Node3D
		var aim: Vector3 = m.get("aim", Vector3.INF)
		var kind := str(m["kind"])
		if aim != Vector3.INF and float(m["arrive"]) >= 1.0:
			WeaponModels.aim(node, aim, 1.0 - exp(-12.0 * dt))
		else:
			WeaponModels.aim(node, node.global_position + Vector3(0, 0, -5), 1.0 - exp(-6.0 * dt))
		var fire := float(m["kick"])
		if kind == "laser":
			fire = 1.0 if bool(m["lasing"]) else 0.0
			var mz := (node.get_meta("muzzle") as Node3D).global_position
			if bool(m["lasing"]) and aim != Vector3.INF:
				run.effects.beam(node.get_instance_id(), mz, aim, WeaponModels.icon_color("laser"), true)
			else:
				run.effects.beam(node.get_instance_id(), mz, mz, WeaponModels.icon_color("laser"), false)
		WeaponModels.animate(node, t, fire, float(m["roll"]))


## Weapons as {kind, level} for Run.weapons.
func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in machines:
		out.append({"kind": str(m["kind"]), "level": int(m["level"])})
	return out


func stop() -> void:
	if _laser_on:
		_laser_on = false
		Audio.laser_off()
	for m in machines:
		m["lasing"] = false


## Leaving a run mid-beam (pause -> Menu / Retry frees it): the looping hum must stop too.
func _exit_tree() -> void:
	stop()
