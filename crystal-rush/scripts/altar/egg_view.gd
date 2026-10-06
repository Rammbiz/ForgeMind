class_name EggView
extends SubViewportContainer
## A Cache egg on a small glowing dais inside the UI (arsenal_design.md §5.6: the inline Stone
## reveal on the result screen). Its own world in a transparent SubViewport: warm key light, a
## cool rim, the owner's dais (assets/ui/dais.glb; procedural disc without it) with its rune ring,
## and CacheModels.cache(type) breathing on top. present() drops it in; tell(best) cracks it in
## the colour of the BEST card (final from the first frame); burst() shatters it. The UI draws
## the flash, rays and sparks over it (2D, so the additive bloom never fights the transparent
## background). Rendering stops when hidden.

var type := "stone"
var cache: Node3D
var best := "C"
## Frame size relative to the egg's square: > 1 leaves room round the egg for the burst
## chunks (the egg keeps its pixel size; set before adding to the tree).
var frame_k := 1.0

var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _lamp: OmniLight3D
var _dais_mat: ShaderMaterial
var _t := 0.0
var _drop := -1.0


func _init(p_type := "stone") -> void:
	type = p_type
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.95)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.2
	_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	rim.light_color = Color(0.55, 0.75, 1.0)
	rim.light_energy = 1.0
	_root.add_child(rim)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 0.7, 1.2)
	_lamp.omni_range = 4.0
	_lamp.light_energy = 0.0
	_root.add_child(_lamp)
	var d := HubShowcase.owner_dais(1.5)
	if not d.is_empty():
		_root.add_child(d["node"])
		_dais_mat = d["mat"]
		_dais_mat.set_shader_parameter("rune_color", Color(0.45, 0.82, 1.0))
		_dais_mat.set_shader_parameter("rune_k", 0.5)
	else:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.82
		cyl.height = 0.18
		disc.mesh = cyl
		disc.position.y = -0.09
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.15, 0.3)
		m.metallic = 0.4
		m.roughness = 0.35
		disc.material_override = m
		_root.add_child(disc)
	cache = CacheModels.cache(type)
	_root.add_child(cache)
	var h := float(cache.get_meta("height", 1.0))
	_cam = Camera3D.new()
	_cam.fov = 20.6
	_root.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, h * 1.05, h * 3.6), Vector3(0, h * 0.42, 0))
	_root.set_meta("h", h)


func _ready() -> void:
	if frame_k != 1.0:
		_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(20.6 * 0.5)) * frame_k))


## The egg falls onto the dais (ease-out-back) with a thud.
func present() -> void:
	_drop = 0.0
	cache.position.y = 1.6
	Audio.play("crate_hit", -6.0)


## The honest tell: the crack opens in the colour of `rarity` (the best card inside).
func tell(rarity: String) -> void:
	best = rarity
	CacheModels.set_tell(cache, rarity)
	CacheModels.set_crack(cache, 1)
	_no_pillars()
	var c := CacheModels.rarity_color(rarity)
	_lamp.light_color = c
	_lamp.light_energy = 1.5
	if _dais_mat:
		_dais_mat.set_shader_parameter("rune_color", c)
		_dais_mat.set_shader_parameter("rune_k", 1.0)


func heavy() -> void:
	CacheModels.set_crack(cache, 2)
	_no_pillars()
	_lamp.light_energy = 2.4


## The Legendary+ light pillars are additive columns meant for the Altar's opaque scene; on
## this transparent stage they would punch dark bars, so the UI rays carry the tell instead.
func _no_pillars() -> void:
	for p: Node3D in cache.get_meta("pillars", []):
		p.visible = false


## The shell flies apart (pre-fractured chunks with gravity).
func burst() -> void:
	CacheModels.set_crack(cache, 3)
	_lamp.light_energy = 4.0


## The egg's centre in this control's local pixels (for 2D flashes and card fan-outs).
func egg_point() -> Vector2:
	var h := float(cache.get_meta("height", 1.0))
	var p := _cam.unproject_position(Vector3(0, h * 0.5, 0))
	var vs := Vector2(_vp.size)
	return p / maxf(vs.x, 1.0) * size.x if vs.x > 0.0 else size * 0.5


func _process(delta: float) -> void:
	_t = fmod(_t + delta, 3600.0)
	if _drop >= 0.0:
		_drop += delta
		var k := clampf(_drop / 0.35, 0.0, 1.0)
		var u := k - 1.0
		var e := 1.0 + 2.70158 * u * u * u + 1.70158 * u * u
		cache.position.y = 1.6 * (1.0 - e)
		if k >= 1.0:
			_drop = -1.0
			cache.position.y = 0.0
	CacheModels.animate(cache, _t)
	if _lamp.light_energy > 0.0 and int(cache.get_meta("stage", 0)) == 3:
		_lamp.light_energy = maxf(0.0, _lamp.light_energy - delta * 4.0)
