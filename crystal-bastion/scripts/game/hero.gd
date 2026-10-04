class_name Hero
extends Node3D
## A player-controlled hero. It walks to the post the player picks, holds back ground enemies
## that come near (they stop and fight it), heals out of combat, respawns at the crystal after
## falling, and has a super ability on a short cooldown plus an ultimate on a long one.

signal died
signal respawned

var game: Game
var type := ""
var def: Dictionary
var ability: Dictionary
var ult: Dictionary
var color := Color.WHITE
var hp := 1.0
var max_hp := 1.0
var alive := true
var selected := false
var post := Vector3.ZERO          # where the hero stands guard
var home := Vector3.ZERO          # respawn point next to the crystal
var respawn_left := 0.0
var cooldown := 0.0               # ability cooldown left
var ult_cooldown := 0.0           # ultimate cooldown left (it charges up from the level start)
var target: Enemy
var _marching := false            # walking to a new post: ignores enemies until there
var _held: Array[Enemy] = []
var _attack_cd := 0.0
var _since_hit := 99.0
var _model: Node3D
var _meshes: Array[MeshInstance3D] = []
var _anim_t := 0.0
var _attack_anim := 0.0
var _ability_anim := 0.0
var _ult_anim := 0.0
var _punch_alt := false           # which hand strikes next
var _slam_left := 0.0             # titan: wind-up before the slam lands
var _ult_left := 0.0              # time left in the running ultimate
var _ult_tick := 0.0              # bolt: time to the next storm strike
var _quake_t := 0.0               # titan: time since the quake landed (negative while airborne)
var _quake_wave := -1             # titan: next crystal wave to raise, -1 before landing
var _quake_hit: Array[Enemy] = []
var _armor_left := 0.0            # titan: crystal armour after the quake
var _moving := false
var _hit_flash := 0.0
var _flash_cd := 0.0
var _ring: MeshInstance3D
var _trail: CPUParticles3D
var _vortex: MeshInstance3D       # bolt: the storm's spinning wall

static var _flash_mat: StandardMaterial3D
static var _armor_mat: ShaderMaterial
static var _ring_shader: Shader
static var _vortex_shader: Shader

## Seconds from the button to the moment the fists hit the ground; matches the animations.
const SLAM_WINDUP := 0.3
const QUAKE_WINDUP := 0.43
const QUAKE_WAVE_GAP := 0.2
const STORM_SPIN := 9.0           # rad/s around the vortex


func setup(p_game: Game, p_type: String, p_home: Vector3) -> void:
	game = p_game
	type = p_type
	def = GameData.HEROES[type]
	ability = def["ability"]
	ult = def["ult"]
	ult_cooldown = float(ult["charge"])
	color = def["color"]
	max_hp = float(def["hp"])
	hp = max_hp
	home = p_home
	post = p_home
	position = p_home


func _ready() -> void:
	_model = Models.hero(type)
	add_child(_model)
	_collect_meshes(_model)
	_make_ring()
	if type == "bolt":
		_make_trail()
		_make_vortex()


func _collect_meshes(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			_meshes.append(ch)
		_collect_meshes(ch)


# ------------------------------------------------------------------ per frame

func _process(raw_delta: float) -> void:
	var delta := Game.step(raw_delta)
	_anim_t += delta
	_attack_anim = maxf(_attack_anim - delta * (3.0 if type == "bolt" else 1.6), 0.0)
	_ability_anim = maxf(_ability_anim - delta * (2.0 if type == "bolt" else 1.4), 0.0)
	_ult_anim = maxf(_ult_anim - delta / float(ult["anim"]), 0.0)
	_flash_cd = maxf(_flash_cd - delta, 0.0)
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			_set_overlay(_base_overlay())
	if _ring:
		_ring.visible = selected and alive
	if game == null or not game.is_running():
		_moving = false
		if not _held.is_empty():
			_release_all()
		# The level ended mid-move: put the hero back on its post and drop the armour glow.
		if _ult_left > 0.0:
			_end_ult()
		if _armor_left > 0.0:
			_armor_left = 0.0
			_set_overlay(null)
		if _trail:
			_trail.emitting = false
		_animate()
		return
	cooldown = maxf(cooldown - delta, 0.0)
	ult_cooldown = maxf(ult_cooldown - delta, 0.0)
	if not alive:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		return
	_since_hit += delta
	_attack_cd -= delta
	_prune_held()
	if _armor_left > 0.0:
		_armor_left -= delta
		if _armor_left <= 0.0 and _hit_flash <= 0.0:
			_set_overlay(null)
	if _slam_left > 0.0:
		_slam_left -= delta
		if _slam_left <= 0.0:
			_slam()
	if _since_hit > 2.5 and hp < max_hp:
		hp = minf(max_hp, hp + float(def["regen"]) * delta)
	_moving = false
	if _ult_left > 0.0:
		# The ultimate takes the hero over: no walking or swinging until it is done.
		_ult_step(delta)
		if _trail:
			_trail.emitting = _ult_left > 0.0
		_animate()
		return
	if _marching:
		_moving = _walk_to(post, delta, 0.05)
		_marching = _moving
	else:
		_fight(delta)
		_catch_passers()
	if _trail:
		_trail.emitting = _moving
	_animate()


func _fight(delta: float) -> void:
	_pick_target()
	if target == null:
		if _flat_dist(post) > 0.08:
			_moving = _walk_to(post, delta, 0.05)
		return
	if target.flying:
		_face(target.global_position, delta)
		if _attack_cd <= 0.0:
			_attack(delta)
		return
	var reach := float(def["reach"]) + target.size * 0.5
	if _flat_dist(target.global_position) > reach:
		_moving = _walk_to(target.global_position, delta, reach * 0.85)
	else:
		_hold(target)
		_face(target.global_position, delta)
		if _attack_cd <= 0.0:
			_attack(delta)


## Keeps the current target while it is still reachable; otherwise takes an enemy it already
## holds, or the nearest enemy around its post that nobody else is holding.
func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.alive or not _can_engage(target)):
		target = null
	# Fight what we hold first: never walk off and leave held enemies frozen behind.
	if not _held.is_empty() and not _held.has(target):
		target = _held[0]
		return
	if target != null:
		return
	var best: Enemy = null
	var best_d := INF
	for e in game.enemies:
		if not e.alive or e.spawn_in > 0.2 or not _can_engage(e):
			continue
		if not e.flying and e.blocker != null and e.blocker != self:
			continue
		var d := _flat_dist(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	target = best


func _can_engage(e: Enemy) -> bool:
	if e.flying:
		var air := float(def["air_reach"])
		return air > 0.0 and _flat_dist(e.global_position) <= air
	if e.blocker == self:
		return true
	var leash := float(def["aggro"])
	var dx := e.global_position.x - post.x
	var dz := e.global_position.z - post.z
	return dx * dx + dz * dz <= leash * leash


func _hold(e: Enemy) -> void:
	if e.flying or e.blocker != null or _held.size() >= int(def["block"]):
		return
	e.blocker = self
	_held.append(e)


## Ground enemies that walk right into the hero are stopped too (up to its block count).
func _catch_passers() -> void:
	if _held.size() >= int(def["block"]):
		return
	for e in game.enemies:
		if e.alive and not e.flying and e.blocker == null and e.spawn_in <= 0.2 \
				and _flat_dist(e.global_position) <= 0.35 + e.size * 0.5:
			_hold(e)
			if _held.size() >= int(def["block"]):
				return


func _prune_held() -> void:
	for i in range(_held.size() - 1, -1, -1):
		var e := _held[i]
		if not is_instance_valid(e) or not e.alive or e.blocker != self:
			_held.remove_at(i)


func _release_all() -> void:
	for e in _held:
		if is_instance_valid(e) and e.blocker == self:
			e.blocker = null
	_held.clear()
	target = null


func _attack(delta: float) -> void:
	# Carry this frame's overshoot (like towers) so 2x/3x speed keeps the same hit rate.
	_attack_cd = maxf(_attack_cd, -delta) + 1.0 / float(def["rate"])
	_attack_anim = 1.0
	_punch_alt = not _punch_alt
	var dmg := float(def["damage"])
	var at := target.aim_point()
	match type:
		"bolt":
			if target.flying:
				game.effects.lightning([global_position + Vector3(0, 0.6, 0), at], Color(0.55, 0.85, 1.0), 0.12, 0.035)
			game.effects.hit_spark(at, Color(0.55, 0.85, 1.0))
			Audio.play("hit", -12.0, 0.2)
			target.take_damage(dmg, str(def["dmg_type"]))
		"titan":
			var splash := float(def.get("splash", 0.0))
			var ground := target.global_position
			game.effects.burst(ground + Vector3(0, 0.1, 0), Color(0.45, 0.4, 0.35), 10, 1.6, 0.12, 0.5, -4.0, false)
			game.effects.ring(ground, Color(0.5, 1.0, 0.65), splash, 0.3)
			Audio.play("cannon", -9.0, 0.15)
			for e in game.enemies_in_radius(ground, splash, false, true):
				e.take_damage(dmg if e == target else dmg * 0.5, str(def["dmg_type"]))


func _walk_to(dest: Vector3, delta: float, stop: float) -> bool:
	var to := Vector2(dest.x - position.x, dest.z - position.z)
	var d := to.length()
	if d <= stop:
		return false
	var step := minf(float(def["speed"]) * delta, d - stop * 0.5)
	var dir := to / d
	position.x += dir.x * step
	position.z += dir.y * step
	position.y = lerpf(position.y, game.map.ground_y(position), minf(1.0, delta * 12.0))
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.y), minf(1.0, delta * 14.0))
	return true


func _face(p: Vector3, delta: float) -> void:
	var dir := Vector2(p.x - position.x, p.z - position.z)
	if dir.length_squared() > 1e-4:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.y), minf(1.0, delta * 12.0))


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


func _animate() -> void:
	var fighting := is_instance_valid(target) and target.alive
	Models.animate_hero(_model, _anim_t, _moving, _attack_anim, _ability_anim, _ult_anim, _punch_alt, fighting)


# ------------------------------------------------------------------ commands

## Sends the hero to guard a new spot. It drops what it was fighting and walks there.
func command_move(dest: Vector3) -> void:
	if not alive:
		return
	_release_all()
	post = Vector3(dest.x, game.map.ground_y(dest), dest.z)
	_marching = true


func can_use_ability() -> bool:
	return alive and cooldown <= 0.0 and _ult_left <= 0.0 and game != null and game.is_running()


func use_ability() -> bool:
	if not can_use_ability():
		return false
	cooldown = float(ability["cooldown"])
	_ability_anim = 1.0
	match type:
		"bolt":
			_dash()
		"titan":
			_slam_left = SLAM_WINDUP
	return true


func can_use_ult() -> bool:
	return alive and ult_cooldown <= 0.0 and _ult_left <= 0.0 and _slam_left <= 0.0 \
			and game != null and game.is_running()


func use_ult() -> bool:
	if not can_use_ult():
		return false
	ult_cooldown = float(ult["cooldown"])
	_ult_anim = 1.0
	match type:
		"bolt":
			_ult_left = float(ult["duration"])
			_ult_tick = 0.0
			game.effects.flash(global_position + Vector3(0, 0.5, 0), Color(0.6, 0.9, 1.0), 1.2, 0.3)
			game.camera_shake(0.15)
			Audio.play("tesla", 0.0)
		"titan":
			_quake_t = -QUAKE_WINDUP
			_quake_wave = -1
			_quake_hit.clear()
			# Stay put until the landing crouch has played out, not just the waves.
			_ult_left = maxf(QUAKE_WINDUP + QUAKE_WAVE_GAP * int(ult["waves"]) + 0.2, float(ult["anim"]))
	return true


func _ult_step(delta: float) -> void:
	_ult_left -= delta
	match type:
		"bolt":
			_storm_step(delta)
		"titan":
			_quake_step(delta)
	if _ult_left <= 0.0:
		_end_ult()


func _end_ult() -> void:
	_ult_left = 0.0
	_model.position = Vector3.ZERO
	if _vortex:
		_vortex.visible = false
	if _trail:
		_trail.position = Vector3(0, 0.45, 0)


## Thunder vortex: the fox runs circles around its post so fast it becomes a storm. Every
## enemy inside, fliers too, is struck by lightning and slowed to a crawl.
func _storm_step(delta: float) -> void:
	var r := float(ult["radius"])
	var a := _anim_t * STORM_SPIN
	var lap := r * 0.6
	var spent := float(ult["duration"]) - _ult_left
	# Spiral out from the post at the start and back into it at the end.
	var off := Vector3(cos(a), 0.0, sin(a)) * lap * smoothstep(0.0, 0.2, spent) * smoothstep(0.0, 0.3, _ult_left)
	var y := lerpf(_model.position.y, game.map.ground_y(global_position + off) - global_position.y, minf(1.0, delta * 15.0))
	_model.position = Vector3(off.x, y, off.z)
	_model.rotation.y = atan2(-sin(a), cos(a))
	if _trail:
		_trail.position = _model.position + Vector3(0, 0.45, 0)
	_vortex.visible = true
	(_vortex.material_override as ShaderMaterial).set_shader_parameter("fade", clampf(minf(spent / 0.25, _ult_left / 0.35), 0.0, 1.0))
	_ult_tick -= delta
	if _ult_tick > 0.0:
		return
	var tick := float(ult["tick"])
	_ult_tick += tick
	var center := global_position
	var ring: Array[Vector3] = []
	for i in 13:
		var ang := a + i * TAU / 12.0
		ring.append(center + Vector3(cos(ang) * lap, 0.3 + 0.25 * sin(ang * 3.0 + _anim_t * 7.0), sin(ang) * lap))
	game.effects.lightning(ring, Color(0.5, 0.8, 1.0), 0.26, 0.06, false)
	game.effects.ring(center, Color(0.45, 0.75, 1.0), r, 0.3)
	var from := center + off + Vector3(0, 0.5, 0)
	# Every enemy inside is hit; only the first few get a visible bolt, to keep a crowd cheap.
	var bolts := 6 if game.effects.quality_high else 3
	for e in game.enemies_in_radius(center, r, true, true):
		var at := e.aim_point()
		e.take_damage(float(ult["dps"]) * tick, "magic")
		if e.alive:
			e.apply_slow(float(ult["slow"]), tick + 0.5)
		if bolts > 0:
			bolts -= 1
			game.effects.lightning([from, at], Color(1.0, 0.85, 0.35), 0.12, 0.035, false)
			game.effects.hit_spark(at, Color(0.6, 0.9, 1.0))
	Audio.play("tesla", -9.0, 0.25)


## Emerald quake: the guardian leaps and crashes down; rings of crystal spikes burst out of
## the ground one after another, hitting and stunning every ground enemy they reach, and
## crystal armour covers the guardian for a while.
func _quake_step(delta: float) -> void:
	_quake_t += delta
	var center := global_position
	if _quake_wave < 0:
		if _quake_t < 0.0:
			return
		_quake_wave = 0
		_armor_left = float(ult["armor_time"])
		if _hit_flash <= 0.0:
			_set_overlay(_base_overlay())
		game.effects.flash(center + Vector3(0, 0.2, 0), Color(0.4, 1.0, 0.6), 1.6, 0.3)
		game.effects.burst(center + Vector3(0, 0.15, 0), Color(0.5, 0.44, 0.38), 36, 3.6, 0.15, 0.9, -6.0, false)
		game.camera_shake(0.55)
		Save.vibrate(80)
		Audio.play("explosion", 1.0)
	var waves := int(ult["waves"])
	while _quake_wave < waves and _quake_t >= _quake_wave * QUAKE_WAVE_GAP:
		var radius := float(ult["spacing"]) * (_quake_wave + 1)
		var count := 7 + 5 * _quake_wave
		var spikes: Array[Vector3] = []
		for i in count:
			var ang := (i + 0.5 * (_quake_wave % 2)) * TAU / count
			var at := center + Vector3(cos(ang), 0.0, sin(ang)) * radius
			if not game.map.top_y.has(game.map.world_to_cell(at)):
				continue  # past the island's edge
			at.y = game.map.ground_y(at)
			spikes.append(at)
		game.effects.crystal_spikes(spikes, center, Color(0.12, 0.85, 0.4))
		game.effects.ring(center, Color(0.4, 1.0, 0.6), radius, 0.4)
		for e in game.enemies_in_radius(center, radius, false, true):
			if _quake_hit.has(e):
				continue
			_quake_hit.append(e)
			e.take_damage(float(ult["damage"]), "phys")
			if e.alive:
				e.stun(float(ult["stun"]))
		Audio.play("cannon", -4.0, 0.2)
		_quake_wave += 1


## Lightning dash: runs up the nearest path towards the portals and back in a blink, hitting
## and slowing everything along the way (fliers too).
func _dash() -> void:
	var curve: Curve3D = null
	var best_d := INF
	var start := 0.0
	for c: Curve3D in game.map.curves:
		var off := c.get_closest_offset(global_position)
		var d := _flat_dist(c.sample_baked(off))
		if d < best_d:
			best_d = d
			curve = c
			start = off
	if curve == null:
		return
	var end := maxf(start - float(ability["length"]), 0.0)
	var pts: Array[Vector3] = [global_position + Vector3(0, 0.4, 0)]
	var o := start
	while o > end:
		pts.append(curve.sample_baked(o) + Vector3(0, 0.35, 0))
		o -= 0.3
	pts.append(curve.sample_baked(end) + Vector3(0, 0.35, 0))
	var width := float(ability["width"])
	var hit: Array[Enemy] = []
	for e in game.enemies:
		if not e.alive:
			continue
		for p in pts:
			if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() <= width + e.size * 0.5:
				hit.append(e)
				break
	for e in hit:
		e.apply_slow(float(ability["slow"]), float(ability["slow_time"]))
		e.take_damage(float(ability["damage"]), "magic")
		game.effects.hit_spark(e.aim_point(), Color(0.6, 0.9, 1.0))
	game.effects.lightning(pts, Color(0.5, 0.8, 1.0), 0.45, 0.09)
	game.effects.lightning(pts, Color(1.0, 0.85, 0.35), 0.3, 0.04)
	for i in range(0, pts.size(), 3):
		game.effects.burst(pts[i], Color(0.55, 0.85, 1.0), 6, 1.4, 0.06, 0.35, -1.0)
	game.effects.flash(global_position + Vector3(0, 0.4, 0), Color(0.6, 0.9, 1.0), 0.6, 0.2)
	game.camera_shake(0.12)
	Audio.play("tesla", -2.0)


## Ground slam: damages and stuns every ground enemy around the giant.
func _slam() -> void:
	var r := float(ability["radius"])
	var at := Vector3(global_position.x, global_position.y, global_position.z)
	for e in game.enemies_in_radius(at, r, false, true):
		e.take_damage(float(ability["damage"]), "phys")
		if is_instance_valid(e) and e.alive:
			e.stun(float(ability["stun"]))
	game.effects.ring(at, Color(0.4, 1.0, 0.6), r, 0.5)
	game.effects.ring(at, Color(0.85, 0.75, 0.55), r * 0.7, 0.35)
	game.effects.flash(at + Vector3(0, 0.2, 0), Color(0.4, 1.0, 0.6), r * 0.6, 0.25)
	game.effects.burst(at + Vector3(0, 0.15, 0), Color(0.5, 0.44, 0.38), 26, 3.0, 0.14, 0.8, -6.0, false)
	game.effects.burst(at + Vector3(0, 0.3, 0), Color(0.45, 1.0, 0.6), 14, 2.2, 0.08, 0.5, -3.0)
	game.camera_shake(0.35)
	Save.vibrate(40)
	Audio.play("explosion", -1.0)


# ------------------------------------------------------------------ health

func take_damage(amount: float, _from: Enemy = null) -> void:
	if not alive or amount <= 0.0 or game == null or not game.is_running():
		return
	if _armor_left > 0.0:
		amount *= 1.0 - float(ult["armor"])
	hp -= amount
	_since_hit = 0.0
	# Held enemies hit every frame: pulse the flash about twice a second instead of strobing.
	if _flash_cd <= 0.0:
		_hit_flash = 0.12
		_flash_cd = 0.45
		_set_overlay(_get_flash_mat())
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	hp = 0.0
	if game.selected_hero == self:
		game.deselect_hero()
	_release_all()
	_marching = false
	_slam_left = 0.0
	_armor_left = 0.0
	_quake_hit.clear()
	if _ult_left > 0.0:
		_end_ult()
	respawn_left = float(def["respawn"])
	game.effects.death(global_position, color, 0.45)
	game.effects.flash(global_position + Vector3(0, 0.4, 0), color, 0.8, 0.25)
	Audio.play("death", -2.0)
	_model.visible = false
	if _trail:
		_trail.emitting = false
	died.emit()


func _respawn() -> void:
	alive = true
	hp = max_hp
	position = home
	post = home
	_since_hit = 99.0
	_model.visible = true
	_set_overlay(null)
	game.effects.flash(home + Vector3(0, 0.4, 0), color, 0.7, 0.3)
	game.effects.burst(home + Vector3(0, 0.3, 0), color, 16, 2.0, 0.08, 0.6, -2.0)
	Audio.play("upgrade", -6.0)
	respawned.emit()


## Point above the head for the health bar.
func bar_point() -> Vector3:
	return global_position + _model.position + Vector3(0, float(_model.get_meta("bar_y", 1.4)), 0)


func _set_overlay(mat: Material) -> void:
	for m in _meshes:
		m.material_overlay = mat


## The overlay the hero wears when it is not flashing from a hit.
func _base_overlay() -> Material:
	return _get_armor_mat() if _armor_left > 0.0 else null


static func _get_armor_mat() -> ShaderMaterial:
	if _armor_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.25, 1.0, 0.5, 0.7);
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.7 + 0.3 * sin(TIME * 5.0);
	ALBEDO = tint.rgb;
	ALPHA = (0.03 + rim * 0.75) * pulse * tint.a;
}
"""
		_armor_mat = ShaderMaterial.new()
		_armor_mat.shader = sh
	return _armor_mat


static func _get_flash_mat() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.0, 0.35, 0.3, 0.5)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _flash_mat


# ------------------------------------------------------------------ visuals

func _make_ring() -> void:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float pulse = 0.75 + 0.25 * sin(TIME * 6.0);
	float ring = smoothstep(0.7, 0.85, r) * (1.0 - smoothstep(0.9, 1.0, r));
	ALBEDO = tint.rgb;
	ALPHA = ring * pulse + (1.0 - smoothstep(0.0, 0.85, r)) * 0.12;
}
"""
	_ring = MeshInstance3D.new()
	_ring.mesh = Mats.quad(Vector2(1.1, 1.1) * (1.4 if type == "titan" else 1.0))
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("tint", color)
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(0, 0.04, 0)
	_ring.visible = false
	add_child(_ring)


func _make_vortex() -> void:
	if _vortex_shader == null:
		_vortex_shader = Shader.new()
		_vortex_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform float fade = 1.0;
void fragment() {
	// CylinderMesh sides span UV.y 0 (top) .. 0.5 (bottom).
	float v = UV.y * 2.0;
	float a = UV.x * 6.2831 * 4.0 - TIME * 16.0 + v * 5.0;
	float streak = pow(0.5 + 0.5 * sin(a), 6.0);
	float spark = pow(0.5 + 0.5 * sin(UV.x * 6.2831 * 9.0 + TIME * 23.0 - v * 9.0), 24.0);
	float band = smoothstep(0.0, 0.3, v) * (1.0 - smoothstep(0.55, 1.0, v));
	ALBEDO = mix(mix(tint.rgb, vec3(0.75, 0.9, 1.0), streak), vec3(1.0, 0.92, 0.5), spark);
	ALPHA = clamp(0.32 + streak * 0.6 + spark, 0.0, 1.0) * band * fade;
}
"""
	var lap := float(ult["radius"]) * 0.6
	var cyl := CylinderMesh.new()
	cyl.top_radius = lap * 1.12
	cyl.bottom_radius = lap * 0.92
	cyl.height = 0.9
	cyl.radial_segments = 40
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_vortex = MeshInstance3D.new()
	_vortex.mesh = cyl
	var mat := ShaderMaterial.new()
	mat.shader = _vortex_shader
	_vortex.material_override = mat
	_vortex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vortex.position = Vector3(0, 0.45, 0)
	_vortex.visible = false
	add_child(_vortex)


func _make_trail() -> void:
	_trail = CPUParticles3D.new()
	_trail.amount = 28
	_trail.lifetime = 0.35
	_trail.local_coords = false
	_trail.mesh = Mats.quad(Vector2(0.07, 0.07), false)
	_trail.material_override = Mats.particle(true)
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = 0.12
	_trail.gravity = Vector3(0, 0.3, 0)
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.15
	_trail.scale_amount_min = 0.6
	_trail.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.35, 0.9))
	g.add_point(0.4, Color(0.45, 0.8, 1.0, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.5, 1.0, 0.0))
	_trail.color_ramp = g
	_trail.position = Vector3(0, 0.45, 0)
	_trail.emitting = false
	add_child(_trail)
