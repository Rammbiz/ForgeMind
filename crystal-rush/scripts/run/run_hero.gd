class_name RunHero
extends Node3D
## The hero leading the army: the model and its animation state, the ult charge ring at its
## feet, the small vault it makes over hazards (it is immune to them), and the hero's share of
## the account (Meta.run_profile "hero" block, §6.4): level multipliers, Ult Rank, Aspect and
## the Reinforcements damage bonus. Run reads them through mult(), ult_power(), cast_shots().
## Its run row `def` is the Run's (HeroKinds.def_for: Balance.HEROES for the starters at phase 0); the
## heroes without a 3D model yet stand in as grey-box figures (HeroModels.proxy).

const VAULT_TIME := 0.42
const VAULT_H := 0.75
## Forked Fox: every Nth cast of Bolt chains to one more target (HeroKinds.forks).
const FORK_EVERY := HeroKinds.FORK_EVERY

var type := "bolt"
var def: Dictionary
var model: Node3D
var ring: MeshInstance3D
var running := true
var fighting := false
var cheering := false
## The profile's hero block {id, lvl, aspect, glory, ult_rank, dmg_mult, hp_mult, ult_rate_mult}.
var meta_hero: Dictionary = {}
## Reinforcements {stacks, soldiers, dmg_add}.
var assist: Dictionary = {}
var _t := 0.0
var _attack := 0.0
var _ability := 0.0
var _ult := 0.0
var _alt := false
var _vault := 0.0
var _lean := 0.0
var _last_x := 0.0
var _casts := 0
var _rig: Dictionary


## Builds hero `p_type` for a run `profile` (the parent Run's when empty). `p_def` is the run row the Run
## read (HeroKinds.def_for); alone (galleries) the hero looks it up from its own profile block the same way.
func setup(p_type: String, profile: Dictionary = {}, p_def: Dictionary = {}) -> void:
	type = p_type
	if profile.is_empty():
		var run := get_parent()
		if run and run.get("profile") is Dictionary:
			profile = run.get("profile")
	use_profile(profile)
	def = p_def if not p_def.is_empty() else HeroKinds.def_for(type, meta_hero)
	_rig = HeroModels.rig(type)
	model = HeroModels.hero(type)
	model.rotation.y = PI   # the run heads to -Z
	add_child(model)
	ring = Models.ult_ring()
	ring.scale = Vector3.ONE * float(_rig["ring"])
	add_child(ring)


## Reads the hero and Reinforcements blocks of a run profile (Meta.run_profile).
func use_profile(profile: Dictionary) -> void:
	var h: Variant = profile.get("hero", {})
	meta_hero = h if h is Dictionary else {}
	var a: Variant = profile.get("assist", {})
	assist = a if a is Dictionary else {}


## Hero multiplier `key` (Run.hero_mult defers here): "dmg_mult" = level damage x (1 +
## Reinforcements bonus, bucket 2), "hp_mult", "ult_rate_mult" from the hero level.
func mult(key: String) -> float:
	var v := float(meta_hero.get(key, 1.0))
	if key == "dmg_mult":
		v *= 1.0 + float(assist.get("dmg_add", 0.0))
	return maxf(v, 0.0)


## Ult Rank I..IV (hero Lv1/5/15/25).
func ult_rank() -> int:
	return clampi(int(meta_hero.get("ult_rank", 1)), 1, 4)


## Ult effect multiplier: +20% per Ult Rank above I (EconData.HERO.ult_rank_bonus).
func ult_power() -> float:
	return 1.0 + float(EconData.HERO.get("ult_rank_bonus", 0.2)) * float(ult_rank() - 1)


## The hero's Aspect: the profile's when its hero block is this hero (dev runs may field another
## hero than the account's), else the hero's default (Balance.HEROES.aspect).
func aspect() -> String:
	var a := str(meta_hero.get("aspect", "")) if str(meta_hero.get("id", type)) == type else ""
	return a if a != "" else str(def.get("aspect", ""))


## Shots this cast (before power gates' extra shots): the Seer's orbs (HEROES.targets), plus
## one on every FORK_EVERY-th cast of a Forked Fox Bolt. Call once per cast.
func cast_shots() -> int:
	_casts += 1
	var n := int(def.get("targets", 1))
	if HeroKinds.forks(aspect(), _casts):
		n += 1
	return n


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
	_attack = maxf(_attack - delta * float(_rig["attack_decay"]), 0.0)
	_ability = maxf(_ability - delta * 1.4, 0.0)
	_ult = maxf(_ult - delta / float(get_meta("ult_len", 1.6)), 0.0)
	# Vault: a quick parabola; the ring stays on the road.
	var y := 0.0
	if _vault > 0.0:
		_vault = maxf(_vault - delta, 0.0)
		var s := 1.0 - _vault / VAULT_TIME
		y = VAULT_H * 4.0 * s * (1.0 - s)
	# Lean into sideways moves (the drag reads in the body).
	var vx := (position.x - _last_x) / maxf(delta, 0.001)
	_last_x = position.x
	_lean = lerpf(_lean, clampf(-vx * 0.035, -0.3, 0.3), 1.0 - exp(-10.0 * delta))
	model.rotation.z = _lean
	# Every hero keeps pace with the army (the titan's stomp runs faster than its walk).
	HeroModels.animate_hero(model, _t, running or cheering, _attack, _ability, _ult, _alt, fighting, float(_rig["pace"]))
	# Clip heroes float while their ult plays.
	y = maxf(y, float(model.get_meta("float", 0.0)))
	model.position.y = y
	ring.position.y = 0.03 - y


## Where strikes come from (chest height, a little ahead).
func muzzle() -> Vector3:
	return global_position + Vector3(0, float(_rig["muzzle_y"]) + model.position.y, -0.35)


## Height above the head for labels.
func top() -> float:
	return float(model.get_meta("bar_y", 1.5))
