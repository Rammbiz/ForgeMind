class_name Hazards
extends Node3D
## Per-kind behaviour of the run's hostile and solid items, working on the Run's item
## dictionaries (Etap 1 spec section 4): spiked barricades, rotor and sweeper blades, railing
## turrets, crystal geodes, weapon crates and enemy squads.
##
## Builds each item's model, keeps its live state (`x` of a sweeper bar, blade angle, squad
## formation), kills the army units that touch a blade or the spikes (one per unit, through
## Run.hazard_kills), fires the turrets at the nearest soldier, and plays the hit and break
## effects. Squads get their crowd only when they come into view and lose it behind the camera.
## Squads are the owner's Emberhorn Sentinels (VAT bake, VatClip.EMBER) when the bake is present:
## a menacing guard idle while they wait, a charge (run) as the clash starts, and the front rank
## stabbing (zone clip) while the ranks behind run up; their deaths are UnitFx's baked fall. The
## procedural raider stays as the fallback.
## Rules mirror LevelSim (blade angle = phase + speed * t, sweeper x = x + amp sin(2pi t / period
## + phase), hit boxes shrunk by HAZARD_SHRINK plus the soldier radius).

const SQUAD_SHOWN := Balance.SQUAD_SHOWN
const SQUAD_DX := Balance.SQUAD_DX
const SQUAD_DZ := Balance.SQUAD_DZ
const BLADE_HALF := 0.08        # half thickness of a blade bar (the soldier radius is added)
const SWEEP_HALF_Z := 0.17
const SPIKES_HALF_Z := 0.3
const ROTOR_HUB := 0.45         # solid hub radius
const VIEW_AHEAD := 75.0
const VIEW_BEHIND := 14.0
const TURRET_SHOT_SPEED := 17.0
## A warded turret shot (a hero ult ward spent) ends in this matte white-gold spark, costing nothing.
const WARD_SPARK := Color(1.0, 0.91, 0.64)
## Emberhorn squads: march speed of the charge (step_squads moves units at 4.2 u/s), their run
## clip rate (stylised like the knights', VatClip.RUN_RATE), the stab rate and unit size.
const SQUAD_CHARGE_SPEED := 4.2
const EMBER_RUN_RATE := 1.25
const EMBER_ATTACK_RATE := 1.2
const EMBER_SCALE := 1.0
const EMBER_SCALE_DENSE := 0.9   # at SQUAD_SHOWN units

## Formation and crowd of one enemy squad (kept in the item under "sq").
class Squad extends RefCounted:
	var view: CrowdView
	var pos := PackedVector3Array()     # world feet positions, front rank first
	var home := PackedVector3Array()    # formation positions
	var per_row := 4
	var charging := false
	var shown := 0
	## Baked Emberhorn clips of this squad (null: procedural raiders).
	var anim: VatClip
	## Units still running to their place in the charge (CLASH).
	var moving := false
	## Seconds every unit has stood in place (the run clip ends after a short settle).
	var still := 0.0


var run: Run
var squads: Array[Dictionary] = []
var spikes: Array[Dictionary] = []
var blades: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var geodes: Array[Dictionary] = []
var crates: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _ember := false


func setup(p_run: Run) -> void:
	run = p_run
	_rng.seed = 991
	_ember = ResourceLoader.exists(VatClip.EMBER + "_vat_mesh.res")
	if _ember and run.fx:
		run.fx.set_enemy_vat(VatClip.create(VatClip.EMBER))


## Builds the model of a hazard / hostile item and fills in its runtime fields.
func add(it: Dictionary) -> void:
	var kind := str(it["kind"])
	var at := Vector3(float(it["x"]), 0.0, -float(it["d"]))
	match kind:
		"barricade":
			it["hp"] = float(it["value"])
			it["hp0"] = float(it["value"])
			var n := Models.spikes(float(it.get("w", 2.0)), int(it["value"]))
			n.position = at
			add_child(n)
			it["node"] = n
			it["label"] = n.get_meta("label")
			spikes.append(it)
		"blade":
			it["x0"] = float(it["x"])
			if str(it.get("type", "rotor")) == "rotor":
				var r := Models.rotor(float(it.get("len", 1.6)))
				r.position = at
				add_child(r)
				it["node"] = r
				# Trails are modelled for a positive spin; mirror them for the other way round.
				var spin := r.get_meta("spin") as Node3D
				if float(it.get("speed", 2.5)) > 0.0:
					spin.scale.z = -1.0
				it["theta"] = float(it.get("phase", 0.0))
			else:
				var s := Models.sweeper(float(it.get("w", 2.0)))
				s.position = Vector3(0.0, 0.0, at.z)
				add_child(s)
				it["node"] = s
			blades.append(it)
		"turret":
			it["hp"] = float(it["value"])
			it["hp0"] = float(it["value"])
			var tn := Models.turret()
			tn.position = at
			add_child(tn)
			it["node"] = tn
			it["label"] = tn.get_meta("label")
			(it["label"] as Label3D).text = str(int(it["value"]))
			it["cd"] = 0.6
			(tn.get_meta("head") as Node3D).rotation.y = PI if at.x > 0.0 else 0.0
			turrets.append(it)
		"geode":
			it["hp"] = float(it["value"])
			it["hp0"] = float(it["value"])
			var g := Models.geode(str(it.get("reward", "army")))
			g.position = at
			g.rotation.y = _rng.randf_range(-0.4, 0.4)
			add_child(g)
			it["node"] = g
			it["label"] = g.get_meta("label")
			(it["label"] as Label3D).text = str(int(it["value"]))
			geodes.append(it)
		"crate":
			# OPEN segment = value, then the gold BONUS segment (Run._prepare_crate sets "bonus").
			var bonus := int(it.get("bonus", 0))
			it["hp"] = float(it["value"]) + bonus
			it["hp0"] = float(it["value"]) + bonus
			var c := _crate_node(it)
			c.position = at
			add_child(c)
			it["node"] = c
			it["label"] = c.get_meta("label")
			crates.append(it)
		"squad":
			it["hp"] = float(it["value"])
			it["hp0"] = float(it["value"])
			squads.append(it)


## Live x (sweeper bar centre) and blade angle at run time `t`.
func update_live(t: float) -> void:
	for it in blades:
		if str(it.get("type", "rotor")) == "rotor":
			it["theta_prev"] = float(it.get("theta", 0.0))
			it["theta"] = float(it.get("phase", 0.0)) + float(it.get("speed", 2.5)) * t
		else:
			it["x_prev"] = float(it["x"])
			it["x"] = sweeper_x(it, t)


static func sweeper_x(it: Dictionary, t: float) -> float:
	return float(it["x0"]) + float(it.get("amp", 1.5)) * sin(TAU * t / maxf(float(it.get("period", 2.0)), 0.1) + float(it.get("phase", 0.0)))


## Solid circles the army is pushed out of: [Vector3 centre, radius].
func solids(near_z: float, span: float) -> Array:
	var out: Array = []
	for it in geodes:
		if it["alive"] and absf(-float(it["d"]) - near_z) < span:
			out.append([Vector3(float(it["x"]), 0, -float(it["d"])), 0.62])
	for it in crates:
		if it["alive"] and absf(-float(it["d"]) - near_z) < span:
			out.append([Vector3(float(it["x"]), 0, -float(it["d"])), 0.58])
	for it in blades:
		if str(it.get("type", "rotor")) == "rotor" and absf(-float(it["d"]) - near_z) < span:
			out.append([Vector3(float(it["x0"]), 0, -float(it["d"])), ROTOR_HUB])
	return out


# ------------------------------------------------------------------ army vs hazards

## Kills the army units touching live spikes or blades this step (unless armoured).
func check_army(army: Army, armored: bool) -> void:
	if army.shown == 0 or armored:
		army.hold_slots(false)
		return
	var cz := army.center.z
	var reach := army.radius * Balance.BLOB_STRETCH + 1.8
	var near := false
	for it in spikes:
		if not it["alive"]:
			continue
		var bz := -float(it["d"])
		if absf(bz - cz) > reach:
			continue
		if not near:
			near = true
			army.hold_slots(true)
		var half := float(it.get("w", 2.0)) * 0.5 * Balance.HAZARD_SHRINK + Balance.UNIT_R
		var bx := float(it["x"])
		var hits := PackedInt32Array()
		# Units still flying in (regrown from the rear, recruits) have not reached the line yet.
		for i in army.shown:
			if army.flying(i):
				continue
			var p := army.position_of(i)
			if absf(p.x - bx) <= half and absf(p.z - bz) <= SPIKES_HALF_Z + Balance.UNIT_R and p.y < 0.5:
				hits.append(i)
		if not hits.is_empty():
			run.hazard_kills(it, hits, Vector3(0, 0, 2.0))
	for it in blades:
		var bz2 := -float(it["d"])
		if absf(bz2 - cz) > reach + 1.0:
			continue
		if not near:
			near = true
			army.hold_slots(true)
		var hits2 := PackedInt32Array()
		if str(it.get("type", "rotor")) == "rotor":
			var px := float(it["x0"])
			var length := float(it.get("len", 1.6)) * Balance.HAZARD_SHRINK + Balance.UNIT_R
			var th0 := float(it.get("theta_prev", it.get("theta", 0.0)))
			var th1 := float(it.get("theta", 0.0))
			for i in army.shown:
				if army.flying(i):
					continue
				var p2 := army.position_of(i)
				var dx := p2.x - px
				var dz := p2.z - bz2
				var rho := sqrt(dx * dx + dz * dz)
				if rho >= length or rho < 0.05 or p2.y > 0.7:
					continue
				var m := asin(minf(1.0, (Balance.UNIT_R + BLADE_HALF) / rho))
				if _swept(atan2(dz, dx), th0, th1, m):
					hits2.append(i)
		else:
			var half2 := float(it.get("w", 2.0)) * 0.5 * Balance.HAZARD_SHRINK + Balance.UNIT_R
			var xa := minf(float(it["x"]), float(it.get("x_prev", it["x"]))) - half2
			var xb := maxf(float(it["x"]), float(it.get("x_prev", it["x"]))) + half2
			for i in army.shown:
				if army.flying(i):
					continue
				var p3 := army.position_of(i)
				if p3.x >= xa and p3.x <= xb and absf(p3.z - bz2) <= SWEEP_HALF_Z + Balance.UNIT_R and p3.y < 0.7:
					hits2.append(i)
		if not hits2.is_empty():
			var side := 1.0 if float(it.get("speed", 1.0)) > 0.0 else -1.0
			run.hazard_kills(it, hits2, Vector3(2.2 * side, 0, 0.6))
	army.hold_slots(near)


## True when angle `phi` (mod pi: the blade has two arms) lies within `m` of the arc the blade
## swept from `a` to `b`.
static func _swept(phi: float, a: float, b: float, m: float) -> bool:
	var s := b - a
	if absf(s) >= PI:
		return true
	var rel := fposmod((phi - a) if s >= 0.0 else (a - phi), PI)
	return rel <= absf(s) + m or rel >= PI - m


# ------------------------------------------------------------------ turrets

## Turrets fire at the nearest soldier within range (rate shots/s, one soldier per shot).
func step_turrets(dt: float, army: Army) -> void:
	for it in turrets:
		if not it["alive"]:
			continue
		var node := it["node"] as Node3D
		var tp := Vector3(float(it["x"]), 0.0, -float(it["d"]))
		var reach := float(it.get("range", 7.0))
		if absf(tp.z - army.center.z) > reach + army.radius * 1.3 + 0.5 or army.shown == 0 or run.army <= 0:
			it["aim"] = Vector3.INF
			continue
		var i := army.nearest(tp, reach)
		if i < 0:
			it["aim"] = Vector3.INF
			continue
		var target := army.position_of(i) + Vector3(0, 0.35, 0)
		it["aim"] = target
		it["cd"] = float(it.get("cd", 0.0)) - dt
		if float(it["cd"]) > 0.0:
			continue
		it["cd"] = 1.0 / maxf(float(it.get("rate", 2.0)), 0.1)
		var muzzle := (node.get_meta("muzzle") as Node3D).global_position
		run.effects.muzzle(muzzle, Color(1.0, 0.45, 0.15), (target - muzzle).normalized())
		Audio.play("turret_shot", -11.0, 0.1)
		node.set_meta("kick", 1.0)
		var item := it
		var dist := muzzle.distance_to(target)
		# Hero ult wards (KindView.absorb, H2), where LevelSim._turrets spends them: one charge takes one
		# shot (one soldier), before Німб's catch; under the quake's armour the shot is free and spends none.
		# No-op until a hero kind grants wards (RunKindView.absorb answers false at once without any).
		if run._armor <= 0.0 and run.kind_view and run.kind_view.absorb(&"turret"):
			run.effects.projectile(muzzle, target, "turret", dist / TURRET_SHOT_SPEED,
					func() -> void: run.effects.hit_spark(target, WARD_SPARK))
			continue
		# Under the quake's armour the shot is free anyway: Німб keeps his catch (LevelSim._turrets).
		if run.champions.active() and run._armor <= 0.0 and _caught(it, muzzle):
			continue
		run.effects.projectile(muzzle, target, "turret", dist / TURRET_SHOT_SPEED, func() -> void: run.turret_hit(item, target))


## Німб's tier IV (heroes design §6.20, §10.5): a shot aimed at the soldiers near him is caught on his
## aegis (ChampionKinds.absorb_turret, one shot = one soldier); it flies to him and costs nothing.
func _caught(it: Dictionary, muzzle: Vector3) -> bool:
	var m := run.champions.members
	if ChampionKinds.absorb_turret(run.kind_view, m, int(it["kid"]), 1.0) > 0.5:
		return false
	var c := ChampionKinds.catcher(m, int(it["kid"]))
	var at := Vector3(float(c.get("x", it["x"])), 0.7, -float(c.get("d", it["d"])))
	run.effects.projectile(muzzle, at, "turret", muzzle.distance_to(at) / TURRET_SHOT_SPEED,
			func() -> void: run.effects.hit_spark(at, Color(0.94, 0.71, 0.94)))
	return true


# ------------------------------------------------------------------ squads

## Enemy crowd of a squad in view (created on demand).
func squad_state(it: Dictionary) -> Squad:
	if it.has("sq"):
		return it["sq"]
	var sq := Squad.new()
	var w := float(it.get("w", 2.4))
	sq.per_row = maxi(3, int(w / SQUAD_DX))
	sq.view = CrowdView.new()
	sq.view.name = "Squad"
	add_child(sq.view)
	if _ember:
		sq.anim = VatClip.create(VatClip.EMBER)
	sq.view.setup(sq.anim.mesh if sq.anim else Models.raider_mesh(), SQUAD_SHOWN)
	sq.view.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	sq.view.set_gait(14.0)
	it["crowd"] = sq.view
	it["sq"] = sq
	_layout(it, sq, mini(ceili(float(it["hp"])), SQUAD_SHOWN))
	if sq.anim:
		sq.anim.attach(sq.view)
		sq.anim.spread["idle"] = 1.0
		sq.anim.play("idle", 0.0)
		# Each squad starts somewhere else in its breath.
		sq.anim.seek(_rng.randf() * sq.anim.length("idle"))
		_size_squad(sq)
	var l := Models.label(str(ceili(float(it["hp"]))), 120, Color(1.0, 0.93, 0.9), true)
	Models.soft_outline(l, Color("#5A1410"), 0.0)
	l.render_priority = 4
	add_child(l)
	it["label"] = l
	return sq


func _layout(it: Dictionary, sq: Squad, n: int) -> void:
	sq.pos.resize(n)
	sq.home.resize(n)
	var front_z := -float(it["d"])
	var cx := float(it["x"])
	for k in n:
		var row := k / sq.per_row
		var col := k % sq.per_row
		var in_row := mini(sq.per_row, n - row * sq.per_row)
		var x := cx + (col - (in_row - 1) * 0.5) * SQUAD_DX + (0.1 if row % 2 == 1 else 0.0)
		var p := Vector3(clampf(x, -Army.WALL, Army.WALL), 0.0, front_z - row * SQUAD_DZ)
		sq.home[k] = p
		sq.pos[k] = p
	sq.shown = n


## Emberhorn unit size: a little smaller in big squads so horns and spears stay apart.
func _size_squad(sq: Squad) -> void:
	if sq.anim == null:
		return
	var k := clampf((sq.shown - 24.0) / float(SQUAD_SHOWN - 24), 0.0, 1.0)
	var s := lerpf(EMBER_SCALE, EMBER_SCALE_DENSE, k)
	sq.anim.set_unit_scale(s)
	if run.fx:
		run.fx.unit_scale[1] = s


## Clip per squad state: guard idle while waiting; in the clash the ranks still moving up run,
## the front rank (beyond the line) stabs, and everyone stands guard once in place.
func _animate_squad(sq: Squad, dt: float, fighting: bool, line_z: float) -> void:
	if sq.anim == null:
		return
	sq.still = 0.0 if sq.moving else sq.still + dt
	var running := sq.still < 0.2
	if fighting:
		sq.anim.play("run" if running else "idle", 0.15, false, EMBER_RUN_RATE if running else 1.0)
		sq.anim.set_zone("attack", line_z - 0.1, 0.12, EMBER_ATTACK_RATE)
	else:
		sq.anim.play("idle", 0.25, false, 1.0)
		sq.anim.clear_zone()
	sq.anim.tick(dt)


## Middle of the squad's formation (labels, aiming).
func squad_point(it: Dictionary) -> Vector3:
	var x := float(it["x"])
	var z := -float(it["d"])
	if it.has("sq"):
		var sq: Squad = it["sq"]
		if sq.shown > 0:
			var fz := sq.pos[0].z
			for k in mini(sq.shown, sq.per_row):
				fz = maxf(fz, sq.pos[k].z)
			return Vector3(x, 0.0, fz - 0.2)
	return Vector3(x, 0.0, z)


## The squad lost soldiers: its front units die until the drawn count matches.
func squad_losses(it: Dictionary) -> void:
	if not it.has("sq"):
		return
	var sq: Squad = it["sq"]
	var want := mini(ceili(maxf(float(it["hp"]), 0.0)), SQUAD_SHOWN)
	var hp0 := float(it.get("hp0", it["hp"]))
	if hp0 > SQUAD_SHOWN:
		want = ceili(float(SQUAD_SHOWN) * maxf(float(it["hp"]), 0.0) / hp0)
	while sq.shown > want:
		# Front-most unit (largest z) falls back towards the enemy line.
		var best := 0
		for k in sq.shown:
			if sq.pos[k].z > sq.pos[best].z:
				best = k
		run.fx.die(sq.pos[best], 1, Vector3(_rng.randf_range(-0.8, 0.8), 0, -1.6))
		sq.pos.remove_at(best)
		sq.home.remove_at(best)
		sq.shown -= 1
	_size_squad(sq)


## Moves and draws the squads near the camera; frees the crowds far behind.
func step_squads(dt: float, d: float, foe: Dictionary, line_z: float, army_x: float) -> void:
	for it in squads:
		var sd := float(it["d"])
		if sd > d + VIEW_AHEAD:
			continue
		if not it["alive"] or sd < d - VIEW_BEHIND:
			_free_squad(it)
			continue
		var sq := squad_state(it)
		var fighting := foe == it
		sq.charging = fighting
		var moving := false
		# A held squad (KindView.hold, heroes design §10.4) charges x (1 - its hold strength).
		var pace := SQUAD_CHARGE_SPEED * dt
		if run.kind_view:
			pace *= 1.0 - run.kind_view.hold_k(it)
		for k in sq.shown:
			var p := sq.pos[k]
			var h := sq.home[k]
			if fighting:
				var rank := k / sq.per_row
				var tx := lerpf(h.x, army_x + (h.x - float(it["x"])) * 0.8, 0.35)
				var tz := line_z - rank * 0.3
				p.x += (tx - p.x) * (1.0 - exp(-4.0 * dt))
				p.z = move_toward(p.z, tz, pace)
				moving = moving or absf(p.z - tz) > 0.04
			else:
				p.x += (h.x - p.x) * (1.0 - exp(-3.0 * dt))
				p.z += (h.z - p.z) * (1.0 - exp(-3.0 * dt))
			sq.pos[k] = p
		sq.moving = moving
		_animate_squad(sq, dt, fighting, line_z)


func _free_squad(it: Dictionary) -> void:
	if it.has("sq"):
		var sq: Squad = it["sq"]
		if is_instance_valid(sq.view):
			sq.view.queue_free()
		it.erase("sq")
		it.erase("crowd")
	if it.has("label") and is_instance_valid(it["label"]):
		(it["label"] as Node).queue_free()
		it.erase("label")


# ------------------------------------------------------------------ hits and breaks

## A hit landed on a hostile `it` (hp already lowered): flash, shake, damage stage, label.
func on_hit(it: Dictionary, at: Vector3) -> void:
	var kind := str(it["kind"])
	var node: Node3D = it.get("node")
	var hp := maxf(float(it.get("hp", 0.0)), 0.0)
	var ratio := 1.0 - hp / maxf(float(it.get("hp0", 1.0)), 1.0)
	if it.has("label") and is_instance_valid(it["label"]):
		var l := it["label"] as Label3D
		if kind == "squad":
			run.juice.counter(l, ceili(hp))
		else:
			l.text = str(ceili(hp))
			_punch(l)
	match kind:
		"crate":
			WeaponModels.crate_damage(node, ratio, 1.0)
			_crate_label(it)
			Audio.play("crate_hit", -9.0, 0.12)
			run.effects.hit_spark(at, WeaponModels.icon_color(_crate_id(it)))
		"geode":
			_shake(node, 0.08)
			run.effects.burst(at, Models.REWARD_COLORS.get(str(it.get("reward", "army")), Color.WHITE), 6, 2.6, 0.06, 0.35, -6.0)
			Models.damage(node, ratio)
		"barricade", "turret":
			Models.damage(node, ratio)
			_shake(node, 0.05)
		"squad":
			squad_losses(it)


## Destruction effects for a hostile (the Run applies the reward).
func on_destroy(it: Dictionary) -> void:
	var kind := str(it["kind"])
	var node: Node3D = it.get("node")
	var at := Vector3(float(it["x"]), 0.6, -float(it["d"]))
	match kind:
		"barricade":
			run.effects.explosion(at, 1.2)
			run.effects.shockwave(Vector3(at.x, 0, at.z), Color(1.0, 0.35, 0.15), 1.8)
			for k in 8:
				run.fx.debris(at + Vector3(_rng.randf_range(-1.2, 1.2), 0.2, 0), [Color(0.3, 0.31, 0.36), Color(1.0, 0.2, 0.1), Color(0.72, 0.1, 0.09)][k % 3], 2)
			Audio.play("explosion", -4.0)
			_sink(node)
		"turret":
			run.effects.explosion(at + Vector3(0, 0.6, 0), 1.0)
			for k in 4:
				run.fx.debris(at, Color(0.3, 0.31, 0.36) if k % 2 == 0 else Color(0.72, 0.1, 0.09), 2)
			Audio.play("explosion", -6.0)
			_sink(node)
		"geode":
			var col: Color = Models.REWARD_COLORS.get(str(it.get("reward", "army")), Color.WHITE)
			run.effects.loot_burst(at + Vector3(0, 0.3, 0), col)
			for k in 5:
				run.fx.debris(at, col.lerp(Color.WHITE, 0.25 * (k % 2)), 2)
			Audio.play("geode_break", -3.0)
			_pop(node)
		"crate":
			var wc := WeaponModels.glow_color(_crate_id(it)) if _crate_id(it) != "" else Color(0.85, 0.95, 1.0)
			run.effects.loot_burst(at + Vector3(0, 0.4, 0), wc)
			for k in 4:
				run.fx.debris(at, [Color(0.93, 0.94, 0.98), Color(1.0, 0.76, 0.3), wc][k % 3], 2)
			Audio.play("crate_open", -2.0)
			_pop(node)
		"squad":
			_free_squad(it)
	if it.has("label") and is_instance_valid(it["label"]) and kind != "squad":
		(it["label"] as Label3D).visible = false


# ------------------------------------------------------------------ crates (arsenal §3.3)

## The machine a crate holds ("" while unresolved).
static func _crate_id(it: Dictionary) -> String:
	var c := str(it.get("content", ""))
	if c == "":
		return ""
	return str(CratePicker.parse(c)[0])


## Crate model for its current state: a "?" steel crate until resolved, then the machine's
## rarity shell and miniature; the platinum NEW crate from the start.
func _crate_node(it: Dictionary) -> Node3D:
	var id := _crate_id(it)
	var is_new := bool(it.get("new", false))
	var opts := {"new": is_new, "bonus": int(it.get("bonus", 0))}
	if id != "" and ArsenalData.MACHINES.has(id):
		opts["rarity"] = ArsenalData.rarity_of(id)
	var open_hp := maxi(ceili(float(it.get("hp", it["value"])) - float(it.get("bonus", 0))), 0)
	var c := WeaponModels.crate(id if id != "" else "deck", open_hp, opts)
	if is_new:
		c.scale = Vector3.ONE * 1.12
	# The hp count reads over the crate's light pillar (drawn after it, outlined).
	var l := c.get_meta("label") as Label3D
	if l:
		l.no_depth_test = true
		l.render_priority = 7
		l.outline_render_priority = 6
		l.outline_size = 4
		l.outline_modulate.a = 0.38
	return c


## Contents locked at CRATE_RESOLVE_D: the "?" crate turns into its machine's crate with a
## flash (the NEW crate keeps its model).
func resolve_crate(it: Dictionary) -> void:
	if bool(it.get("new", false)):
		return
	var old := it.get("node") as Node3D
	var c := _crate_node(it)
	add_child(c)
	if old:
		c.position = old.position
		old.queue_free()
	else:
		c.position = Vector3(float(it["x"]), 0.0, -float(it["d"]))
	it["node"] = c
	it["label"] = c.get_meta("label")
	var col := WeaponModels.glow_color(_crate_id(it))
	run.effects.flash(c.position + Vector3(0, 0.9, 0), col, 1.8, 0.3)
	run.effects.burst(c.position + Vector3(0, 0.9, 0), col.lerp(Color.WHITE, 0.3), 16, 3.0, 0.06, 0.45, -3.0)
	c.scale = Vector3.ONE * 0.7
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The forecast badge above a resolved crate (live: "НОВА · Railgun", "Ballista II", "+10% ...").
func style_crate(it: Dictionary, text: String) -> void:
	var c := it.get("node") as Node3D
	if c == null or not is_instance_valid(c):
		return
	var b: Label3D = c.get_meta("badge") if c.has_meta("badge") else null
	if b == null:
		b = Label3D.new()
		b.name = "Badge"
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.font = UIKit.font(true)
		b.font_size = 54
		b.pixel_size = 0.0068
		# Two crates of a pair stand 2.2 u apart: long names wrap instead of running together.
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.width = 300.0
		b.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		b.outline_size = 4
		b.outline_modulate = Color(0.35, 0.2, 0.04, 0.4)
		b.modulate = Color(1.0, 0.86, 0.4)
		b.no_depth_test = true
		# Above the gate labels (3) with its own outline too, so a gate row behind the crate
		# never prints through the forecast name.
		b.render_priority = 9
		b.outline_render_priority = 8
		b.position = Vector3(0, 2.46, 0)
		c.add_child(b)
		c.set_meta("badge", b)
	if bool(it.get("new", false)):
		# Platinum text with a deep navy outline: readable against the NEW crate's white beam.
		b.modulate = Color(0.8, 0.93, 1.0)
		b.outline_modulate = Color(0.118, 0.141, 0.2, 0.4)
		b.outline_size = 4
		b.font_size = 54
	b.text = text
	var cl := it.get("label") as Label3D
	if cl:
		cl.position.y = 1.98


## The OPEN segment emptied: the hp turns into the gold BONUS count and the ring glints.
func crate_opened(it: Dictionary) -> void:
	_crate_label(it)
	var c := it.get("node") as Node3D
	if c:
		run.effects.flash(c.position + Vector3(0, 1.0, 0), Color(1.0, 0.82, 0.35), 1.4, 0.25)
		_punch(it["label"] as Label3D)


## Crate hp text: OPEN hp in white, then the BONUS hp in gold with the ring filling.
func _crate_label(it: Dictionary) -> void:
	var l := it.get("label") as Label3D
	if l == null or not is_instance_valid(l):
		return
	var b := float(it.get("bonus", 0))
	var hp := maxf(float(it.get("hp", 0.0)), 0.0)
	var c := it.get("node") as Node3D
	if hp > b + 0.001 or b <= 0.0:
		l.text = str(ceili(hp - b))
		l.modulate = Color(1.0, 0.96, 0.86)
	else:
		l.text = "%s %d" % [Loc.t("CRATE_BONUS"), ceili(hp)]
		l.modulate = Color(1.0, 0.8, 0.3)
		if c:
			WeaponModels.crate_bonus(c, 1.0 - hp / maxf(b, 0.001))


## The other crate of a pair after one was opened: folds, dims and sinks (0.2 s, gate grammar).
func fold_crate(it: Dictionary) -> void:
	var c := it.get("node") as Node3D
	if c == null or not is_instance_valid(c):
		return
	if it.has("label") and is_instance_valid(it["label"]):
		(it["label"] as Label3D).visible = false
	if c.has_meta("badge"):
		(c.get_meta("badge") as Label3D).visible = false
	run.effects.burst(c.position + Vector3(0, 0.6, 0), Color(0.6, 0.62, 0.7), 10, 2.0, 0.06, 0.35, -5.0)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector3(0.75, 0.2, 0.75), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "position:y", -0.6, 0.35).set_delay(0.15)
	tw.chain().tween_callback(c.queue_free)


## A Staggered squad's formation recoils by `dz` (the units spring back to their places).
func push_squad(it: Dictionary, dz: float) -> void:
	if not it.has("sq"):
		return
	var sq: Squad = it["sq"]
	for k in sq.shown:
		var p := sq.pos[k]
		p.z -= dz * (1.0 if k < sq.per_row * 2 else 0.5)
		sq.pos[k] = p


## RANK gate emblem: the machine's miniature in the gate's icon slot ("" restores the star).
func gate_machine_icon(gate: Node3D, id: String) -> void:
	if not gate.has_meta("icon"):
		return
	var icon_root := gate.get_meta("icon") as Node3D
	var cur := str(gate.get_meta("rank_icon", ""))
	if cur == id:
		return
	gate.set_meta("rank_icon", id)
	if id == "":
		return
	for ch in icon_root.get_children():
		ch.queue_free()
	var mini := WeaponModels.machine(id, {"mini": true, "crew": false})
	mini.scale = Vector3.ONE * (0.55 if id != "prism" else 0.35)
	mini.position = Vector3(0, -0.28 if id != "prism" else -0.45, 0)
	mini.rotation.y = PI * 0.15
	icon_root.add_child(mini)
	# gate_style() swaps the emblem only when its icon kind changes: keep "star" as its kind.
	icon_root.set_meta("kind", "star")


func _punch(l: Label3D) -> void:
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.3, 0.05)
	tw.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(node: Node3D, amount: float) -> void:
	if node == null:
		return
	var base := float(node.get_meta("base_x", node.position.x))
	node.set_meta("base_x", base)
	var tw := node.create_tween()
	tw.tween_property(node, "position:x", base + amount, 0.03)
	tw.tween_property(node, "position:x", base - amount, 0.05)
	tw.tween_property(node, "position:x", base, 0.05)


func _sink(node: Node3D) -> void:
	if node == null:
		return
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", -1.6, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "rotation:z", _rng.randf_range(-0.4, 0.4), 0.7)
	tw.chain().tween_callback(node.queue_free)


func _pop(node: Node3D) -> void:
	if node == null:
		return
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 1.25, 0.06)
	tw.tween_property(node, "scale", Vector3(0.01, 0.01, 0.01), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


# ------------------------------------------------------------------ visuals

## Per-frame visuals: blade spin and bars, turret heads, crates and geodes, squad crowds.
func draw(t: float, dt: float, d: float, foe: Dictionary) -> void:
	for it in blades:
		if absf(float(it["d"]) - d) > VIEW_AHEAD:
			continue
		var node := it["node"] as Node3D
		if str(it.get("type", "rotor")) == "rotor":
			(node.get_meta("spin") as Node3D).rotation.y = -float(it.get("theta", 0.0))
		else:
			(node.get_meta("bar") as Node3D).position.x = float(it["x"])
	for it in turrets:
		if not it["alive"] or absf(float(it["d"]) - d) > VIEW_AHEAD:
			continue
		var node2 := it["node"] as Node3D
		var head := node2.get_meta("head") as Node3D
		var aim: Vector3 = it.get("aim", Vector3.INF)
		var want := head.rotation.y
		if aim != Vector3.INF:
			var lp := aim - node2.global_position
			want = atan2(lp.x, lp.z)
		else:
			want = (PI * 0.5 if float(it["x"]) < 0.0 else -PI * 0.5) + sin(t * 0.8) * 0.5
		head.rotation.y = lerp_angle(head.rotation.y, want, 1.0 - exp(-8.0 * dt))
		var kick := float(node2.get_meta("kick", 0.0))
		head.position.z = -kick * 0.08
		node2.set_meta("kick", maxf(kick - dt * 6.0, 0.0))
	for it in crates:
		if it["alive"] and absf(float(it["d"]) - d) < VIEW_AHEAD:
			WeaponModels.animate(it["node"], t, 0.0)
	for it in geodes:
		if it["alive"] and absf(float(it["d"]) - d) < VIEW_AHEAD:
			var gl := it["label"] as Label3D
			gl.position.y = 1.75 + sin(t * 2.0 + float(it["d"])) * 0.05
	for it in squads:
		if not it.has("sq"):
			continue
		var sq: Squad = it["sq"]
		var fighting := foe == it
		sq.view.draw(sq.pos, sq.shown, 0.0, 0.08 if fighting else 0.015, 0.06 if fighting else 0.03)
		if it.has("label") and is_instance_valid(it["label"]):
			var l := it["label"] as Label3D
			var c := squad_point(it)
			var rows := ceili(float(sq.shown) / sq.per_row)
			l.position = Vector3(c.x, 2.1 if fighting else 1.45, c.z - rows * SQUAD_DZ * 0.5 - (0.9 if fighting else 0.0))
			if run.juice.counter_shown(l) < 0:
				l.text = str(ceili(float(it["hp"])))
