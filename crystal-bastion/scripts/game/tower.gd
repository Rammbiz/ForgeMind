class_name Tower
extends Node3D
## A defensive tower on a grid cell. Handles targeting, firing and upgrades.

enum Target { FIRST, STRONG, CLOSE }

var game: Game
var type := ""
var def: Dictionary
var level := 0
var cell := Vector2i.ZERO
var stats: Dictionary
var invested := 0
var target: Enemy
var target_mode := Target.FIRST
var kills := 0
var _model: Node3D
var _head: Node3D
var _muzzle: Node3D
var _cooldown := 0.3
var _retarget := 0.0
var _t := 0.0
var _pop := 0.0
var _recoil := 0.0
var _beam: Node3D
var _beam_core: MeshInstance3D
var _beam_glow: MeshInstance3D
var _beam_on := false
var _beam_target: Enemy
var _beam_time := 0.0
var _spark_t := 0.0


func setup(p_game: Game, p_type: String, p_cell: Vector2i) -> void:
	game = p_game
	type = p_type
	cell = p_cell
	def = GameData.TOWERS[type]
	level = 0
	stats = GameData.tower_stats(type, 0)
	invested = int(stats["cost"])


func _ready() -> void:
	_rebuild_model()
	_pop = 1.0


func _exit_tree() -> void:
	_set_beam(false)


func _rebuild_model() -> void:
	var yaw := 0.0
	if _head:
		yaw = _head.rotation.y
	if _model:
		_model.queue_free()
	_model = Models.tower(type, level)
	add_child(_model)
	_head = _model.get_meta("head")
	_muzzle = _model.get_meta("muzzle")
	if type == "arrow" or type == "cannon":
		_head.rotation.y = yaw
	if type == "laser" and _beam == null:
		_make_beam()


func range_radius() -> float:
	return float(stats["range"])


func can_upgrade() -> bool:
	return level < GameData.tower_max_level(type)


func upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	return int(GameData.tower_stats(type, level + 1)["cost"])


func sell_value() -> int:
	return int(round(invested * GameData.SELL_REFUND))


func upgrade() -> void:
	if not can_upgrade():
		return
	level += 1
	stats = GameData.tower_stats(type, level)
	invested += int(stats["cost"])
	_rebuild_model()
	_pop = 1.0


func cycle_target_mode() -> void:
	target_mode = ((int(target_mode) + 1) % 3) as Target
	target = null
	_retarget = 0.0


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle else global_position + Vector3(0, 0.8, 0)


func _process(delta: float) -> void:
	_t += delta
	_animate(delta)
	if game == null or not game.is_running():
		_set_beam(false)
		return
	_cooldown -= delta
	_retarget -= delta
	if target != null and (not is_instance_valid(target) or not target.alive or not _in_range(target)):
		target = null
	var sticky := type == "laser" and target != null
	if (_retarget <= 0.0 or target == null) and not sticky:
		_retarget = 0.12
		target = game.find_target(global_position, range_radius(), def["air"], def["ground"], target_mode)
	_aim(delta)
	if type == "laser":
		_update_beam(delta)
	elif target != null and _cooldown <= 0.0:
		_fire()
		# Carry this frame's overshoot so the fire rate does not depend on FPS / game speed.
		_cooldown = maxf(_cooldown, -delta) + 1.0 / float(stats["rate"])


func _in_range(e: Enemy) -> bool:
	var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z)
	return d.length() <= range_radius() + 0.05


func _aim(delta: float) -> void:
	if target == null or _head == null:
		return
	if type == "arrow" or type == "cannon":
		var to := target.global_position - global_position
		var yaw := atan2(to.x, to.z)
		_head.rotation.y = lerp_angle(_head.rotation.y, yaw, minf(1.0, delta * 12.0))


func _animate(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 2.5, 0.0)
		var k := 1.0 - _pop
		var wob := sin(k * PI * 3.0) * _pop * 0.22
		_model.scale = Vector3(1.0 - wob * 0.5, 1.0 + wob, 1.0 - wob * 0.5) * (0.5 + 0.5 * minf(k * 4.0, 1.0))
	if _model.has_meta("spin"):
		var spin: Node3D = _model.get_meta("spin")
		spin.rotation.y += delta * (2.5 if target else 0.8)
	if _model.has_meta("pulse"):
		var pulse: Node3D = _model.get_meta("pulse")
		var s2 := 1.0 + sin(_t * 6.0) * 0.06 + (0.25 if _cooldown > 1.0 / float(stats["rate"]) - 0.1 else 0.0)
		pulse.scale = Vector3.ONE * s2
	if _recoil > 0.0 and _model.has_meta("barrel"):
		_recoil = maxf(_recoil - delta * 4.0, 0.0)
		var barrel: Node3D = _model.get_meta("barrel")
		barrel.position.z = -_recoil * 0.12


func _fire() -> void:
	match type:
		"arrow":
			_spawn_projectile("arrow")
			Audio.play("arrow", -6.0, 0.12)
		"cannon":
			_spawn_projectile("ball")
			_recoil = 1.0
			game.effects.burst(muzzle_position(), Color(1.0, 0.75, 0.4), 8, 1.5, 0.12, 0.3, 0.0)
			game.effects.burst(muzzle_position(), Color(0.6, 0.6, 0.6), 6, 0.8, 0.22, 0.6, 0.5, false)
			Audio.play("cannon", -3.0)
		"frost":
			_spawn_projectile("shard")
			Audio.play("frost", -6.0, 0.15)
		"tesla":
			_fire_tesla()


func _spawn_projectile(kind: String) -> void:
	var p := Projectile.new()
	p.launch(game, kind, muzzle_position(), target, stats, def["color"])
	p.dmg_type = def["dmg_type"]
	game.projectiles_root.add_child(p)


func _fire_tesla() -> void:
	var hit: Array[Enemy] = [target]
	var cur := target
	var chains := int(stats["chains"])
	var chain_range := float(stats["chain_range"])
	while hit.size() < chains:
		var best: Enemy = null
		var best_d := chain_range
		for e in game.enemies:
			if not e.alive or e in hit:
				continue
			var d := e.global_position.distance_to(cur.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		cur = best
	var pts: Array[Vector3] = [muzzle_position()]
	for e in hit:
		pts.append(e.aim_point())
	game.effects.lightning(pts, Color(0.55, 0.75, 1.0))
	Audio.play("tesla", -5.0, 0.15)
	var dmg := float(stats["damage"])
	for e in hit:
		if is_instance_valid(e):
			e.take_damage(dmg, "magic")
		dmg *= 0.85


# ------------------------------------------------------------------ laser

func _make_beam() -> void:
	_beam = Node3D.new()
	_beam.name = "Beam"
	_beam.top_level = true
	add_child(_beam)
	_beam_glow = MeshInstance3D.new()
	_beam_glow.mesh = Mats.cyl(1.0, 1.0, 1.0, 8, false)
	_beam_glow.material_override = Mats.flat_color(Color(0.8, 0.35, 1.0, 0.55), true)
	_beam_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(_beam_glow)
	_beam_core = MeshInstance3D.new()
	_beam_core.mesh = Mats.cyl(1.0, 1.0, 1.0, 6, false)
	_beam_core.material_override = Mats.flat_color(Color(1.0, 0.9, 1.0, 1.0), true)
	_beam_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.add_child(_beam_core)
	_beam.visible = false


func _set_beam(on: bool) -> void:
	if on == _beam_on:
		return
	_beam_on = on
	if _beam:
		_beam.visible = on
	if on:
		Audio.laser_on()
	else:
		Audio.laser_off()


func _update_beam(delta: float) -> void:
	if target == null:
		_set_beam(false)
		_beam_target = null
		_beam_time = 0.0
		return
	if target != _beam_target:
		_beam_target = target
		_beam_time = 0.0
	_beam_time += delta
	var ramp := float(stats["ramp"])
	var mult := 1.0 + (ramp - 1.0) * clampf(_beam_time / float(stats["ramp_time"]), 0.0, 1.0)
	_set_beam(true)
	var a := muzzle_position()
	var b := target.aim_point()
	var dir := b - a
	var length := dir.length()
	if length > 0.01:
		var y := dir / length
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y).normalized()
		var flicker := 1.0 + sin(_t * 40.0) * 0.12
		var w := (0.035 + 0.03 * (mult - 1.0) / maxf(ramp - 1.0, 0.01)) * flicker
		_beam.global_transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
		_beam_glow.scale = Vector3(w * 2.4, length, w * 2.4)
		_beam_core.scale = Vector3(w * 0.8, length, w * 0.8)
	_spark_t -= delta
	if _spark_t <= 0.0:
		_spark_t = 0.12
		game.effects.hit_spark(b, Color(0.9, 0.5, 1.0))
	var dmg := float(stats["dps"]) * mult * delta
	target.take_damage(dmg, "magic")
