class_name Enemy
extends Node3D
## An enemy walking (or flying) along a baked path curve.

var game: Game
var type := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var armor := 0.0
var flying := false
var boss := false
var reward := 0
var lives_cost := 1
var size := 0.3
var color := Color.WHITE
var path_index := 0
var dist := 0.0
var path_len := 1.0
var alive := true
var slow_factor := 1.0
var slow_time := 0.0
var hit_flash := 0.0
var spawn_in := 0.0
var hp_mult := 1.0
var _curve: Curve3D
var _model: Node3D
var _anim_t := 0.0
var _meshes: Array[MeshInstance3D] = []
var _frost_overlay := false

const VISUAL_SCALE := 1.0

static var _flash_mat: StandardMaterial3D
static var _frost_mat: StandardMaterial3D


func setup(p_game: Game, p_type: String, p_path: int, p_hp_mult: float) -> void:
	game = p_game
	type = p_type
	def = GameData.ENEMIES[type]
	hp_mult = p_hp_mult
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	speed = float(def["speed"])
	armor = float(def["armor"])
	flying = bool(def["flying"])
	boss = bool(def.get("boss", false))
	reward = int(def["reward"])
	lives_cost = int(def["lives"])
	size = float(def["size"])
	color = def["color"]
	path_index = p_path
	_curve = game.map.curves[path_index]
	path_len = game.map.path_lengths[path_index]
	_anim_t = randf() * 10.0


func _ready() -> void:
	_model = Models.enemy(type, color, size)
	add_child(_model)
	_collect_meshes(_model)
	spawn_in = 0.35
	_model.scale = Vector3.ONE * 0.01 * VISUAL_SCALE
	_update_transform(0.0)


func _collect_meshes(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			_meshes.append(ch)
		_collect_meshes(ch)


func _process(delta: float) -> void:
	if not alive:
		return
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
			_set_frost(false)
	dist += speed * slow_factor * delta
	if dist >= path_len:
		alive = false
		game.on_enemy_leaked(self)
		queue_free()
		return
	_update_transform(delta)
	_anim_t += delta * slow_factor
	Models.animate_enemy(_model, _anim_t, slow_factor)
	if spawn_in > 0.0:
		spawn_in = maxf(spawn_in - delta, 0.0)
		var k := 1.0 - spawn_in / 0.35
		_model.scale = Vector3.ONE * (k * k * (3.0 - 2.0 * k)) * VISUAL_SCALE
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			_apply_overlay()


func _update_transform(delta: float) -> void:
	var p := _curve.sample_baked(dist, true)
	if flying:
		p.y += 0.9 + sin(_anim_t * 2.0) * 0.05
	position = p
	var ahead := _curve.sample_baked(minf(dist + 0.15, path_len), true)
	var dir := ahead - _curve.sample_baked(maxf(dist - 0.05, 0.0), true)
	dir.y = 0.0
	if dir.length_squared() > 1e-6:
		var yaw := atan2(dir.x, dir.z)
		if delta <= 0.0:
			_model.rotation.y = yaw
		else:
			_model.rotation.y = lerp_angle(_model.rotation.y, yaw, minf(1.0, delta * 10.0))


## Point used for aiming (center of the body).
func aim_point() -> Vector3:
	return global_position + Vector3(0, size * (0.9 if not flying else 0.0) + (0.05 if flying else 0.0), 0)


## Remaining distance to the crystal; smaller means more dangerous.
func remaining() -> float:
	return path_len - dist


func take_damage(amount: float, dmg_type := "phys") -> void:
	if not alive:
		return
	var dmg := amount
	if dmg_type == "phys":
		dmg *= (1.0 - armor)
	hp -= dmg
	game.on_enemy_damaged(self, dmg)
	if hit_flash <= 0.0:
		hit_flash = 0.07
		_apply_overlay()
	if hp <= 0.0:
		alive = false
		game.on_enemy_killed(self)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	if not alive:
		return
	var f := 1.0 - factor * (0.6 if boss else 1.0)
	# A weaker slow must not extend a stronger one that is still running.
	if slow_time <= 0.0 or f <= slow_factor + 0.001:
		slow_factor = f
		slow_time = maxf(slow_time, duration)
	_set_frost(true)


func _set_frost(on: bool) -> void:
	if _frost_overlay == on:
		return
	_frost_overlay = on
	_apply_overlay()


func _apply_overlay() -> void:
	var mat: Material = null
	if hit_flash > 0.0:
		mat = _get_flash_mat()
	elif _frost_overlay:
		mat = _get_frost_mat()
	for m in _meshes:
		m.material_overlay = mat


static func _get_flash_mat() -> StandardMaterial3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1, 1, 1, 0.65)
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _flash_mat


static func _get_frost_mat() -> StandardMaterial3D:
	if _frost_mat == null:
		_frost_mat = StandardMaterial3D.new()
		_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_frost_mat.albedo_color = Color(0.35, 0.7, 1.0, 0.45)
		_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _frost_mat
