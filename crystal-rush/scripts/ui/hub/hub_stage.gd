class_name HubStage
extends Node3D
## The 3D Home stage behind the Play tab (UI v2, fusion §6.8 "Home"): HomeWorld's bright
## morning scenery (sky, clouds, islands, the crystal bridge, the ivory rotunda terrace), the
## chosen hero LARGE and centred on the owner's dais (assets/ui/dais.glb; its crystal ring glows
## in the hero's gem colour) and the Deck machines idling behind on both sides. A slow 12 s
## camera sway (±2°). Other tabs cover it with their own backdrop; `active = false` stops the
## animation work and hides the props.
##   stage.deck_screen_pos(i)  -> where Deck machine i stands on screen (tab_play's chips)
##   stage.poke_hero()         -> the hero turns to the camera with a little spin

## Hero's native gem (the dais ring colour).
const HERO_GEM := {"bolt": "sapphire", "titan": "topaz", "seer": "amethyst"}
const DAIS_W := 1.15
## UI v2 final pass: the hero 17 % smaller (the placeholder chibi's head reads less dominant),
## with a soft gem-coloured back-glow and rim light.
const HERO_SCALE := 0.95
## Deck machine places: two fixed slots either side behind the hero (screen x ~130 / 590, feet
## at y ~770 at 720x1280, §6.8) so they never stack; an empty side gets a crystal lantern.
const SLOTS: Array[Vector3] = [Vector3(-0.9, 0, -0.75), Vector3(0.9, 0, -0.75)]
const MACHINE_H := 0.78
const DAIS_SHADER := preload("res://shaders/hub/home_dais.gdshader")

var active := true:
	set(v):
		active = v
		if _props:
			_props.visible = v
		if world:
			world.set_process(v)
var world: HomeWorld
var _cam: Camera3D
var _hero: Node3D
var _hero_id := ""
var _machines: Array[Node3D] = []
var _machine_ids: Array[String] = []
var _deck_key := ""
var _props: Node3D
var _dais_mat: ShaderMaterial
var _ring: MeshInstance3D
var _glow: Sprite3D
var _rim_light: OmniLight3D
var _filler: Node3D
var _hero_y := 0.0
var _t := 0.0
var _poke := 0.0
var _dolly := 0.0
## Camera framing (kept as fields; the dev skins tune them): look target height, camera height
## and distance from the hero.
var look_y := 0.8
var cam_h := 1.95
var cam_d := 3.55
var fov := 36.0


func _ready() -> void:
	world = HomeWorld.new()
	world.name = "HomeWorld"
	add_child(world)
	world.build(Save.quality == "high")
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	var dais := HubShowcase.owner_dais(DAIS_W)
	if not dais.is_empty():
		_hero_y = float(dais["depth"])
		var dn: Node3D = dais["node"]
		dn.position = Vector3(0, dn.position.y + _hero_y, 0)
		_props.add_child(dn)
		# Re-glaze the owner's navy dais as ivory marble for the morning terrace.
		var src: ShaderMaterial = dais["mat"]
		_dais_mat = ShaderMaterial.new()
		_dais_mat.shader = DAIS_SHADER
		for k in ["albedo_tex", "normal_tex", "has_normal"]:
			_dais_mat.set_shader_parameter(k, src.get_shader_parameter(k))
		(dn as MeshInstance3D).material_override = _dais_mat
	else:
		_hero_y = _fallback_dais()
	_blob(Vector3.ZERO, DAIS_W * 1.6, 0.34)
	_ring = _glow_ring(DAIS_W * 0.5 + 0.12)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = fov
	_cam.near = 0.1
	_cam.far = 400.0
	add_child(_cam)
	_cam.make_current()
	_place_camera(0.0)
	refresh()


## A plain ivory dais with a gold rim when the owner's GLB is missing; returns its top height.
func _fallback_dais() -> float:
	var h := 0.32
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = DAIS_W * 0.5
	cm.bottom_radius = DAIS_W * 0.56
	cm.height = h
	cm.radial_segments = 48
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.86)
	mat.roughness = 0.4
	m.material_override = mat
	m.position.y = h * 0.5
	_props.add_child(m)
	return h


## Soft round contact shadow on the terrace floor (works without shadow maps).
func _blob(p: Vector3, size: float, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = HubShowcase._radial_tex()
	m.albedo_color = Color(0.25, 0.2, 0.22, alpha)
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p + Vector3(0, 0.012, 0)
	_props.add_child(mi)
	return mi


## The hero's gem rim: a soft additive ring of light on the floor round the dais.
func _glow_ring(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(r, r) * 2.6
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _ring_tex()
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.02
	_props.add_child(mi)
	return mi


static var _ring_img: Texture2D


## A soft ring (peak at 77 % of the radius) for the dais glow.
static func _ring_tex() -> Texture2D:
	if _ring_img:
		return _ring_img
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := exp(-pow((d - 0.77) / 0.09, 2.0)) + 0.25 * exp(-pow((d - 0.77) / 0.22, 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_ring_img = ImageTexture.create_from_image(img)
	return _ring_img


## Re-reads the hero and the Deck from Meta (cheap when nothing changed).
func refresh() -> void:
	var h := Meta.hero()
	if h != _hero_id:
		_hero_id = h
		if _hero:
			_hero.queue_free()
		_hero = HeroModels.hero(h)
		_hero.scale = Vector3.ONE * HERO_SCALE
		_hero.position = Vector3(0, _hero_y, 0)
		_props.add_child(_hero)
		var gem := str(HERO_GEM.get(h, UITokens.RARITY_GEM.get(str((HeroData.HEROES.get(h, {}) as Dictionary).get("native", "")),
				"sapphire")))
		var g: Dictionary = UITokens.GEMS.get(gem, UITokens.GEMS["sapphire"])
		var rim: Color = g["rim"]
		_set_back_glow(rim, g["light"])
		if _dais_mat:
			_dais_mat.set_shader_parameter("rune_color", rim.lightened(0.1))
		if _ring:
			(_ring.material_override as StandardMaterial3D).albedo_color = Color(rim.r, rim.g, rim.b, 0.55)
		world.set_accent(rim)
	world.set_world(ArsenalData.world_of(Meta.level()))
	var d := Meta.deck()
	var key := ",".join(d)
	for id in d:
		key += ":%d" % Meta.machine_level(id)
	if key == _deck_key:
		return
	_deck_key = key
	for m in _machines:
		var ob: Variant = m.get_meta("blob", null)
		if ob is Node and is_instance_valid(ob):
			(ob as Node).queue_free()
		m.queue_free()
	_machines.clear()
	_machine_ids.clear()
	if _filler:
		_filler.queue_free()
		_filler = null
	for i in mini(d.size(), SLOTS.size()):
		var id: String = d[i]
		if not WeaponModels.KINDS.has(id):
			continue
		var lv := Meta.machine_level(id)
		var holder := Node3D.new()
		holder.position = SLOTS[i]
		# Machines face -Z (away); turn them to show a three-quarter view towards the centre.
		holder.rotation.y = PI + (0.55 if SLOTS[i].x < 0 else -0.55)
		var m := WeaponModels.machine(id, {"rank": 1, "ascended": lv >= ArsenalData.ASCENSION_LEVEL, "crew": true})
		HubShowcase.hide_rank_marks(m)
		_fit(m, 1.0, MACHINE_H)
		holder.add_child(m)
		holder.set_meta("model", m)
		_props.add_child(holder)
		var b := _blob(SLOTS[i], 1.25, 0.26)
		holder.set_meta("blob", b)
		_machines.append(holder)
		_machine_ids.append(id)
	# Only one machine: mirror the composition with a crystal lantern in the empty slot.
	if _machines.size() == 1:
		_filler = _crystal_lantern()
		_filler.position = SLOTS[1] if _machines[0].position.x < 0.0 else SLOTS[0]
		_props.add_child(_filler)


## A soft gem-coloured glow behind the hero (billboard bloom) and a rim light from behind.
func _set_back_glow(rim: Color, light: Color) -> void:
	if _glow == null:
		_glow = Sprite3D.new()
		_glow.texture = UIKit.glow_texture()
		_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_glow.shaded = false
		_glow.pixel_size = 0.022
		_glow.position = Vector3(0, _hero_y + 0.95, -0.55)
		_glow.render_priority = -2
		_props.add_child(_glow)
		_rim_light = OmniLight3D.new()
		_rim_light.position = Vector3(0, _hero_y + 1.3, -0.9)
		_rim_light.omni_range = 1.9
		_rim_light.light_energy = 1.1
		_rim_light.light_specular = 0.2
		_rim_light.shadow_enabled = false
		_props.add_child(_rim_light)
	_glow.modulate = Color(rim.r, rim.g, rim.b, 0.42)
	_rim_light.light_color = light


## A small crystal lantern on an ivory plinth (stands in an empty machine slot).
func _crystal_lantern() -> Node3D:
	var n := Node3D.new()
	var ivory := StandardMaterial3D.new()
	ivory.albedo_color = Color(0.9, 0.86, 0.79)
	ivory.roughness = 0.5
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.2
	bm.bottom_radius = 0.26
	bm.height = 0.34
	bm.radial_segments = 8
	base.mesh = bm
	base.material_override = ivory
	base.position.y = 0.17
	n.add_child(base)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.86, 0.95, 1.0)
	cm.emission_enabled = true
	cm.emission = Color(0.6, 0.85, 1.0)
	cm.emission_energy_multiplier = 1.2
	cm.roughness = 0.15
	for i in 3:
		var c := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09 - i * 0.015
		sm.height = 0.5 - i * 0.12
		sm.radial_segments = 4
		sm.rings = 2
		c.mesh = sm
		c.material_override = cm
		c.position = Vector3((i - 1) * 0.09, 0.55 - i * 0.04, (i % 2) * 0.05)
		c.rotation = Vector3(0, PI * 0.25, (i - 1) * 0.25)
		n.add_child(c)
	var halo := Sprite3D.new()
	halo.texture = UIKit.glow_texture()
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.shaded = false
	halo.pixel_size = 0.008
	halo.modulate = Color(0.7, 0.9, 1.0, 0.35)
	halo.position.y = 0.55
	n.add_child(halo)
	var b := _blob(Vector3.ZERO, 0.9, 0.2)
	_props.remove_child(b)
	n.add_child(b)
	return n


## Scales `m` to fit `max_w` x `max_h` standing on y = 0, centred.
static func _fit(m: Node3D, max_w: float, max_h: float) -> void:
	var box := WeaponModels._visual_aabb(m, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return
	var s := minf(max_w / maxf(maxf(box.size.x, box.size.z), 0.01), max_h / maxf(box.size.y, 0.01))
	m.scale = Vector3.ONE * s
	m.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)


func _process(delta: float) -> void:
	_t += delta
	if not active:
		return
	if _hero:
		HeroModels.animate_hero(_hero, _t, false, 0.0)
		var spin := 0.0
		if _poke > 0.0:
			_poke = maxf(0.0, _poke - delta / 0.9)
			var k := 1.0 - _poke
			spin = TAU * (1.0 - pow(1.0 - k, 3.0))
		_hero.rotation.y = 0.22 + sin(fmod(_t, 200.0 * PI) * 0.32) * 0.16 + spin
	for i in _machines.size():
		var m: Node3D = _machines[i].get_meta("model")
		WeaponModels.animate(m, _t + i * 0.7, 0.0, 0.0)
	var pulse := 0.5 + 0.5 * sin(fmod(_t, 100.0 * PI) * 1.6)
	if _dais_mat:
		_dais_mat.set_shader_parameter("pulse", pulse)
	if _ring:
		_ring.scale = Vector3.ONE * (1.0 + 0.03 * pulse)
	_place_camera(_t)


## A slow 12 s sway of ±2° round the hero.
func _place_camera(t: float) -> void:
	var a := deg_to_rad(2.0) * sin(fmod(t, 1200.0) * TAU / 12.0)
	_cam.fov = fov
	var pos := Vector3(sin(a) * cam_d, cam_h, cos(a) * cam_d)
	var target := Vector3(0, look_y, 0)
	if _dolly > 0.0:
		# Rise over the hero's shoulder and glide down the bridge.
		pos = pos.lerp(Vector3(0.55, 1.55, -2.4), _dolly)
		target = target.lerp(Vector3(0, 1.0, -14.0), _dolly)
	_cam.position = pos
	_cam.look_at(target)
	# Taller phones: the art band grows, so lift the view a little (the hero sits lower, nearer
	# PLAY, and the sky grows above) instead of growing both ends evenly.
	var vs := get_viewport().get_visible_rect().size
	var extra := maxf(0.0, vs.y / maxf(vs.x, 1.0) - 1280.0 / 720.0)
	var d := Vector3(0, cam_h - look_y, cam_d).length()
	_cam.v_offset = extra * 2.0 * d * tan(deg_to_rad(fov * 0.5)) * 0.32


## PLAY: the camera dollies past the hero onto the bridge (the run loads right after).
func dolly(dur := 0.5) -> void:
	_dolly = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_dolly", 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


## The hero turns to the camera with a full spin (a tap on the hero).
func poke_hero() -> void:
	if _poke <= 0.0:
		_poke = 1.0


## Screen position (viewport px) of the hero's chest, for RewardFly sources.
func hero_screen_pos() -> Vector2:
	if _cam == null or _hero == null:
		return Vector2.ZERO
	return _cam.unproject_position(_hero.global_position + Vector3(0, 0.8 * HERO_SCALE, 0))


## Screen rect (viewport px) roughly covering the hero and the dais (tap target).
func hero_screen_rect() -> Rect2:
	if _cam == null:
		return Rect2()
	var top := _cam.unproject_position(Vector3(0, _hero_y + 1.45 * HERO_SCALE, 0))
	var bot := _cam.unproject_position(Vector3(0, 0.0, DAIS_W * 0.5))
	var w := (bot.y - top.y) * 0.42
	return Rect2(Vector2(top.x - w * 0.5, top.y), Vector2(w, bot.y - top.y))


## Deck machines shown on the stage, in Deck order.
func deck_ids() -> Array[String]:
	return _machine_ids


## Screen position (viewport px) under Deck machine `i` (its foot), or (-1, -1).
func deck_screen_pos(i: int) -> Vector2:
	if _cam == null or i < 0 or i >= _machines.size():
		return Vector2(-1, -1)
	return _cam.unproject_position(_machines[i].global_position + Vector3(0, 0.02, 0.35))


func camera() -> Camera3D:
	return _cam
