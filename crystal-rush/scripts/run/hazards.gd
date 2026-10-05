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

## Formation and crowd of one enemy squad (kept in the item under "sq").
class Squad extends RefCounted:
	var view: CrowdView
	var pos := PackedVector3Array()     # world feet positions, front rank first
	var home := PackedVector3Array()    # formation positions
	var per_row := 4
	var charging := false
	var shown := 0


var run: Run
var squads: Array[Dictionary] = []
var spikes: Array[Dictionary] = []
var blades: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var geodes: Array[Dictionary] = []
var crates: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(p_run: Run) -> void:
	run = p_run
	_rng.seed = 991


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
			it["hp"] = float(it["value"])
			it["hp0"] = float(it["value"])
			var c := WeaponModels.crate(str(it.get("weapon", "ballista")), int(it["value"]))
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
		var dist := muzzle.distance_to(target)
		run.effects.muzzle(muzzle, Color(1.0, 0.45, 0.15), (target - muzzle).normalized())
		Audio.play("turret_shot", -11.0, 0.1)
		node.set_meta("kick", 1.0)
		var item := it
		run.effects.projectile(muzzle, target, "turret", dist / TURRET_SHOT_SPEED, func() -> void: run.turret_hit(item, target))


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
	sq.view.setup(Models.raider_mesh(), SQUAD_SHOWN)
	sq.view.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	sq.view.set_gait(14.0)
	it["crowd"] = sq.view
	it["sq"] = sq
	_layout(it, sq, mini(ceili(float(it["hp"])), SQUAD_SHOWN))
	var l := Models.label(str(ceili(float(it["hp"]))), 120, Color(1.0, 0.93, 0.9), true)
	l.outline_modulate = Color(0.35, 0.03, 0.02)
	l.outline_size = 24
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
		for k in sq.shown:
			var p := sq.pos[k]
			var h := sq.home[k]
			if fighting:
				var rank := k / sq.per_row
				var tx := lerpf(h.x, army_x + (h.x - float(it["x"])) * 0.8, 0.35)
				var tz := line_z - rank * 0.3
				p.x += (tx - p.x) * (1.0 - exp(-4.0 * dt))
				p.z = move_toward(p.z, tz, 4.2 * dt)
			else:
				p.x += (h.x - p.x) * (1.0 - exp(-3.0 * dt))
				p.z += (h.z - p.z) * (1.0 - exp(-3.0 * dt))
			sq.pos[k] = p


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
			Audio.play("crate_hit", -9.0, 0.12)
			run.effects.hit_spark(at, WeaponModels.icon_color(str(it.get("weapon", ""))))
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
			var wc := WeaponModels.icon_color(str(it.get("weapon", "")))
			run.effects.loot_burst(at + Vector3(0, 0.4, 0), wc)
			for k in 4:
				run.fx.debris(at, [Color(0.93, 0.94, 0.98), Color(1.0, 0.76, 0.3), wc][k % 3], 2)
			Audio.play("crate_open", -2.0)
			_pop(node)
		"squad":
			_free_squad(it)
	if it.has("label") and is_instance_valid(it["label"]) and kind != "squad":
		(it["label"] as Label3D).visible = false


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
