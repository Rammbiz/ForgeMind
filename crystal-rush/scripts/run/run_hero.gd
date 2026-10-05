class_name RunHero
extends Node3D
## The hero leading the army: the rigged model, its animation state, the ult charge ring at its
## feet, and the small vault it makes over hazards (it is immune to them).

const VAULT_TIME := 0.42
const VAULT_H := 0.75

var type := "bolt"
var def: Dictionary
var model: Node3D
var ring: MeshInstance3D
var running := true
var fighting := false
var cheering := false
var _t := 0.0
var _attack := 0.0
var _ability := 0.0
var _ult := 0.0
var _alt := false
var _vault := 0.0
var _lean := 0.0
var _last_x := 0.0


func setup(p_type: String) -> void:
	type = p_type
	def = Balance.HEROES[type]
	model = HeroModels.hero(type)
	model.rotation.y = PI   # the run heads to -Z
	add_child(model)
	ring = Models.ult_ring()
	ring.scale = Vector3.ONE * (1.0 if type == "bolt" else 1.25)
	add_child(ring)


func strike() -> void:
	_attack = 1.0
	_alt = not _alt


func cast_ult(duration: float) -> void:
	_ult = 1.0
	_ability = 1.0
	set_meta("ult_len", duration)


## A small hop over a hazard (barricade, blade, crate...).
func vault() -> void:
	if _vault <= 0.0:
		_vault = VAULT_TIME


## Ult charge shown on the ring under the hero.
func set_charge(progress: float, ready: bool) -> void:
	Models.ult_ring_set(ring, progress, ready)


func _process(delta: float) -> void:
	_t += delta
	_attack = maxf(_attack - delta * (3.0 if type == "bolt" else 1.6), 0.0)
	_ability = maxf(_ability - delta * 1.4, 0.0)
	_ult = maxf(_ult - delta / float(get_meta("ult_len", 1.6)), 0.0)
	# Vault: a quick parabola; the ring stays on the road.
	var y := 0.0
	if _vault > 0.0:
		_vault = maxf(_vault - delta, 0.0)
		var s := 1.0 - _vault / VAULT_TIME
		y = VAULT_H * 4.0 * s * (1.0 - s)
	model.position.y = y
	ring.position.y = 0.03 - y
	# Lean into sideways moves (the drag reads in the body).
	var vx := (position.x - _last_x) / maxf(delta, 0.001)
	_last_x = position.x
	_lean = lerpf(_lean, clampf(-vx * 0.035, -0.3, 0.3), 1.0 - exp(-10.0 * delta))
	model.rotation.z = _lean
	# Both heroes keep pace with the army: the titan's stomp runs faster than its walk.
	var pace := 1.0 if type == "bolt" else 1.9
	HeroModels.animate_hero(model, _t, running or cheering, _attack, _ability, _ult, _alt, fighting, pace)


## Where strikes come from (chest height, a little ahead).
func muzzle() -> Vector3:
	return global_position + Vector3(0, (0.75 if type == "bolt" else 0.9) + model.position.y, -0.35)


## Height above the head for labels.
func top() -> float:
	return float(model.get_meta("bar_y", 1.5))
