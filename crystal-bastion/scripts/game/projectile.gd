class_name Projectile
extends Node3D
## Arrow / cannon ball / frost shard. Homing (arrow, shard) or ballistic (ball).

var game: Game
var kind := "arrow"
var target: Enemy
var target_pos := Vector3.ZERO
var speed := 10.0
var damage := 1.0
var dmg_type := "phys"
var splash := 0.0
var slow := 0.0
var slow_time := 0.0
var hits_air := true
var hits_ground := true
var color := Color.WHITE
var _start := Vector3.ZERO
var _t := 0.0
var _flight := 1.0
var _arc := 0.0
var _visual: Node3D
var _trail: CPUParticles3D


func launch(p_game: Game, p_kind: String, from: Vector3, p_target: Enemy, stats: Dictionary, p_color: Color) -> void:
	game = p_game
	kind = p_kind
	target = p_target
	color = p_color
	position = from
	_start = from
	speed = float(stats.get("proj_speed", 10.0))
	damage = float(stats.get("damage", 1.0))
	splash = float(stats.get("splash", 0.0))
	slow = float(stats.get("slow", 0.0))
	slow_time = float(stats.get("slow_time", 0.0))
	target_pos = target.aim_point()
	if kind == "ball":
		# Lead the target: predict where it will be when the ball lands.
		var d := from.distance_to(target_pos)
		_flight = clampf(d / speed, 0.35, 1.2)
		var future := minf(target.dist + target.speed * target.slow_factor * _flight, target.path_len - 0.01)
		target_pos = game.map.curves[target.path_index].sample_baked(future, true)
		_arc = 0.6 + d * 0.18


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"arrow":
			Mats.part(_visual, Mats.box(Vector3(0.025, 0.025, 0.32)), Mats.solid(Color(0.55, 0.38, 0.22)), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			Mats.part(_visual, Mats.cone(0.03, 0.07, 4), Mats.glow(Color(1.0, 0.85, 0.5), 2.0), Vector3(0, 0, 0.18), Vector3(90, 0, 0), Vector3.ONE, false)
			Mats.part(_visual, Mats.box(Vector3(0.07, 0.005, 0.07)), Mats.solid(Color(0.95, 0.95, 0.95)), Vector3(0, 0, -0.14), Vector3(0, 45, 0), Vector3.ONE, false)
			_add_trail(Color(1.0, 0.92, 0.7, 0.6), 0.05, 10)
		"ball":
			Mats.part(_visual, Mats.sphere(0.085, -1, 10, 5), Mats.solid(Color(0.12, 0.12, 0.14), 0.4, 0.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
			Mats.part(_visual, Mats.sphere(0.06, -1, 8, 4, false), Mats.glow(Color(1.0, 0.5, 0.15), 3.0), Vector3(0, 0, -0.04), Vector3.ZERO, Vector3.ONE, false)
			_add_trail(Color(1.0, 0.55, 0.2, 0.8), 0.1, 18)
		"shard":
			Mats.part(_visual, Mats.crystal(0.06, 0.24), Mats.glow(Color(0.6, 0.95, 1.0), 2.4), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
			_add_trail(Color(0.6, 0.95, 1.0, 0.8), 0.07, 14)


func _add_trail(c: Color, size: float, amount: int) -> void:
	_trail = CPUParticles3D.new()
	_trail.amount = amount
	_trail.lifetime = 0.35
	_trail.mesh = Mats.quad(Vector2(size, size), false)
	_trail.material_override = Mats.particle(true)
	_trail.local_coords = false
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.1
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	_trail.color_ramp = g
	add_child(_trail)


func _process(delta: float) -> void:
	match kind:
		"ball":
			_t += delta
			var k := minf(_t / _flight, 1.0)
			var prev := position
			position = _start.lerp(target_pos, k) + Vector3.UP * _arc * 4.0 * k * (1.0 - k)
			_orient(position - prev)
			if k >= 1.0:
				_impact()
		_:
			if is_instance_valid(target) and target.alive:
				target_pos = target.aim_point()
			var to := target_pos - position
			var step := speed * delta
			if to.length() <= step + 0.05:
				_impact()
				return
			var dir := to.normalized()
			position += dir * step
			_orient(dir)
			if kind == "shard":
				_visual.rotate_object_local(Vector3.FORWARD, delta * 10.0)


func _orient(dir: Vector3) -> void:
	if dir.length_squared() < 1e-8:
		return
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	# Model points along +Z, look_at points -Z: so look backwards.
	look_at(global_position - d, up)


func _impact() -> void:
	match kind:
		"arrow":
			if is_instance_valid(target) and target.alive:
				game.effects.hit_spark(target_pos, Color(1.0, 0.9, 0.6))
				Audio.play("hit", -10.0, 0.15)
				target.take_damage(damage, dmg_type)
		"shard":
			game.effects.frost_nova(target_pos - Vector3(0, 0.15, 0), splash)
			for e in game.enemies_in_radius(target_pos, splash, true, true):
				e.apply_slow(slow, slow_time)
				e.take_damage(damage, dmg_type)
		"ball":
			game.effects.explosion(target_pos, splash)
			game.camera_shake(0.06)
			Audio.play("explosion", -4.0)
			for e in game.enemies_in_radius(target_pos, splash, false, true):
				var falloff := 1.0 - 0.4 * clampf(e.global_position.distance_to(target_pos) / maxf(splash, 0.01), 0.0, 1.0)
				e.take_damage(damage * falloff, dmg_type)
	if _trail:
		_trail.emitting = false
		var gt := _trail.global_transform
		remove_child(_trail)
		game.effects.add_child(_trail)
		_trail.global_transform = gt
		game.get_tree().create_timer(0.5, false).timeout.connect(_trail.queue_free)
		_trail = null
	queue_free()
