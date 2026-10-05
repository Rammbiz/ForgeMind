class_name RunHero
extends Node3D
## The hero leading the army: the rigged model, its animation state and its strike effects.

var type := "bolt"
var def: Dictionary
var model: Node3D
var running := true
var fighting := false
var _t := 0.0
var _attack := 0.0
var _ability := 0.0
var _ult := 0.0
var _alt := false


func setup(p_type: String) -> void:
	type = p_type
	def = Balance.HEROES[type]
	model = HeroModels.hero(type)
	model.rotation.y = PI   # the run heads to -Z
	add_child(model)


func strike() -> void:
	_attack = 1.0
	_alt = not _alt


func cast_ult(duration: float) -> void:
	_ult = 1.0
	set_meta("ult_len", duration)


func _process(delta: float) -> void:
	_t += delta
	_attack = maxf(_attack - delta * (3.0 if type == "bolt" else 1.6), 0.0)
	_ability = maxf(_ability - delta * 1.4, 0.0)
	_ult = maxf(_ult - delta / float(get_meta("ult_len", 1.6)), 0.0)
	# Both heroes keep pace with the army: the titan's stomp runs faster than its walk.
	var pace := 1.0 if type == "bolt" else 1.9
	HeroModels.animate_hero(model, _t, running, _attack, _ability, _ult, _alt, fighting, pace)


## Where strikes come from (chest height, a little ahead).
func muzzle() -> Vector3:
	return global_position + Vector3(0, 0.75 if type == "bolt" else 0.9, -0.35)


## Height above the head for labels.
func top() -> float:
	return float(model.get_meta("bar_y", 1.5))
