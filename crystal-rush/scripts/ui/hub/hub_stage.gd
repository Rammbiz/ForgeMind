class_name HubStage
extends Node3D
## The 3D world behind the Play tab (arsenal_design.md §7.1 "hero showcase"): the current
## world's road under its sky, the chosen hero in front and the Deck machines flanking it, a
## slow orbiting camera. Other tabs cover it with their own backdrop; then `active = false`
## stops the animation work and hides the props (the sky still clears the screen).

const HERO_Z := -6.0

var active := true:
	set(v):
		active = v
		if _props:
			_props.visible = v
var _cam: Camera3D
var _hero: Node3D
var _hero_id := ""
var _machines: Array[Node3D] = []
var _deck_key := ""
var _props: Node3D
var _t := 0.0
## Camera framing: the hero stands in the upper middle of the screen, above the level path.
var look_y := -0.62
var cam_h := 1.75
var cam_d := 5.0


func _ready() -> void:
	var track := Track.new()
	add_child(track)
	track.build(40.0, Save.quality == "high", Worlds.for_level(Meta.level()))
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 50.0
	add_child(_cam)
	_cam.make_current()
	refresh()


## Re-reads the hero and the Deck from Meta (cheap when nothing changed).
func refresh() -> void:
	var h := Meta.hero()
	if h != _hero_id:
		_hero_id = h
		if _hero:
			_hero.queue_free()
		_hero = HeroModels.hero(h)
		_hero.position = Vector3(0, 0, HERO_Z)
		_props.add_child(_hero)
	var d := Meta.deck()
	var key := ",".join(d)
	for id in d:
		key += ":%d" % Meta.machine_level(id)
	if key == _deck_key:
		return
	_deck_key = key
	for m in _machines:
		m.queue_free()
	_machines.clear()
	# Behind the hero in a shallow V, facing the camera a little (machines face -Z = away).
	var slots := [Vector3(-1.25, 0, HERO_Z - 0.9), Vector3(1.25, 0, HERO_Z - 0.9), Vector3(0, 0, HERO_Z - 1.9)]
	for i in mini(d.size(), slots.size()):
		var id: String = d[i]
		if not WeaponModels.KINDS.has(id):
			continue
		var lv := Meta.machine_level(id)
		var m := WeaponModels.machine(id, {"rank": 1, "ascended": lv >= ArsenalData.ASCENSION_LEVEL, "crew": true})
		m.position = slots[i]
		m.rotation.y = PI + (0.35 if slots[i].x < 0 else (-0.35 if slots[i].x > 0 else 0.0))
		m.scale = Vector3.ONE * 0.9
		_props.add_child(m)
		_machines.append(m)


func _process(delta: float) -> void:
	_t += delta
	if not active:
		return
	if _hero:
		HeroModels.animate_hero(_hero, _t, false, 0.0)
		_hero.rotation.y = sin(_t * 0.4) * 0.3
	for i in _machines.size():
		WeaponModels.animate(_machines[i], _t + i * 0.7, 0.0, 0.0)
	var a := sin(fmod(_t, 200.0 * PI) * 0.15) * 0.28
	_cam.position = Vector3(sin(a) * cam_d, cam_h, HERO_Z + cos(a) * cam_d)
	_cam.look_at(Vector3(0, look_y, HERO_Z))


## Screen position (viewport px) of the hero's chest, for RewardFly sources.
func hero_screen_pos() -> Vector2:
	if _cam == null or _hero == null:
		return Vector2.ZERO
	return _cam.unproject_position(_hero.global_position + Vector3(0, 0.8, 0))


func camera() -> Camera3D:
	return _cam
