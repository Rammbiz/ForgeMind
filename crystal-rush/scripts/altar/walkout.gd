class_name Walkout
extends Control
## NEW machine walkout (arsenal_design.md §7.3 step 5a, Brawl Stars unlock): a full-screen
## stage that plays silhouette -> light -> name slam -> one demo volley in <= 4 s.
##   0.00 the machine stands on the owner's dais as a black silhouette against a family-accent
##        halo (rim light only), motes rise;
##   0.70 a light beam drops onto it, the key light and the dais ring come up (white flash);
##   1.30 the name slams in (2.2 -> 1 with back easing, THUD), "Нова машина!" over it and
##        rarity · family under it;
##   2.10 one demo volley down the stage;
##   3.20 "Торкнись, щоб продовжити"; auto-closes at 4.0 s.
## The first walkout of a machine cannot be skipped before 3.2 s; later ones skip on any tap
## (Meta.note_skip("walkout")). `done` fires once.

signal done

const TOTAL := 4.0
const UNLOCK_AT := 3.2

var id := ""
var first := true

var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _machine: Node3D
var _key: DirectionalLight3D
var _fill: OmniLight3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _halo: Sprite3D
var _dais_mat: ShaderMaterial
var _fx: Effects
var _t := 0.0
var _fire := 0.0
var _beats := {}
var _closing := false
var _title: Label
var _name: Label
var _sub: Label
var _tap: Label
var _shade: ColorRect
var _flash: ColorRect


func setup(p_id: String, p_first := true) -> void:
	id = p_id
	first = p_first


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var acc := UITokens.family(ArsenalData.family_of(id))
	var rc := UITokens.rarity(ArsenalData.rarity_of(id))
	_shade = ColorRect.new()
	_shade.color = Color(0.01, 0.015, 0.05, 0.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.create_tween().tween_property(_shade, "color:a", 0.96, 0.25)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	_build_stage(acc, rc)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_title = UIKit.gradient_heading(Loc.t("NEW_MACHINE"), 44, Color(1, 1, 1), rc.lightened(0.4), rc, 10)
	_name = UIKit.gradient_heading(Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])), 76)
	var fam := str((ArsenalData.FAMILIES[ArsenalData.family_of(id)] as Dictionary)["name"])
	var rar := str((ArsenalData.RARITIES[ArsenalData.rarity_of(id)] as Dictionary)["name"])
	_sub = UIKit.heading("%s · %s" % [Loc.t(rar), Loc.t(fam)], 30, rc.lightened(0.3), 6)
	_tap = UIKit.heading(Loc.t("TAP_CONTINUE"), 26, UIKit.TEXT_DIM, 5)
	for l: Label in [_title, _name, _sub, _tap]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.modulate.a = 0.0
		add_child(l)
	var fs := UIKit.fit_size(_name.text, 660.0, 76, 40)
	_name.add_theme_font_size_override("font_size", fs)
	resized.connect(_layout)
	_layout()
	Audio.play("weapon_get", -8.0)


func _layout() -> void:
	var vp := size
	_title.size = Vector2(vp.x, 56)
	_title.position = Vector2(0, vp.y * 0.12)
	_name.size = Vector2(vp.x, 96)
	_name.position = Vector2(0, vp.y * 0.66)
	_name.pivot_offset = _name.size * 0.5
	_sub.size = Vector2(vp.x, 40)
	_sub.position = Vector2(0, vp.y * 0.66 + 98)
	_tap.size = Vector2(vp.x, 34)
	_tap.position = Vector2(0, vp.y * 0.88)


func _build_stage(acc: Color, rc: Color) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.56, 0.9)
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	_root.set_meta("env", env)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-35, -28, 0)
	_key.light_color = Color(1.0, 0.95, 0.86)
	_key.light_energy = 0.0
	_key.shadow_enabled = true
	_root.add_child(_key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, 165, 0)
	rim.light_color = acc.lerp(Color.WHITE, 0.3)
	rim.light_energy = 2.2
	_root.add_child(rim)
	_fill = OmniLight3D.new()
	_fill.position = Vector3(0, 1.6, 1.6)
	_fill.omni_range = 5.0
	_fill.light_color = rc.lerp(Color.WHITE, 0.5)
	_fill.light_energy = 0.0
	_root.add_child(_fill)
	# Family halo behind the machine (silhouette backdrop).
	_halo = Sprite3D.new()
	_halo.texture = UIKit.glow_texture()
	_halo.pixel_size = 0.012
	_halo.modulate = Color(acc.r, acc.g, acc.b, 0.85)
	_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_halo.shaded = false
	_halo.no_depth_test = false
	_halo.position = Vector3(0, 0.75, -1.4)
	_halo.scale = Vector3.ONE * 2.2
	_root.add_child(_halo)
	var d := HubShowcase.owner_dais(2.0)
	if not d.is_empty():
		_root.add_child(d["node"])
		_dais_mat = d["mat"]
		_dais_mat.set_shader_parameter("rune_color", acc)
		_dais_mat.set_shader_parameter("rune_k", 0.0)
	_machine = WeaponModels.machine(id, {"rank": 1})
	HubShowcase.hide_rank_marks(_machine)
	_root.add_child(_machine)
	_machine.rotation.y = deg_to_rad(-28)
	# Light beam that drops onto the machine at the "light" beat.
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.8
	cyl.height = 12.0
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = CacheModels.BEAM_SHADER
	_beam_mat.set_shader_parameter("noise_tex", CacheModels.NOISE_TEX)
	_beam_mat.set_shader_parameter("color", rc.lerp(Color.WHITE, 0.25))
	_beam_mat.set_shader_parameter("strength", 0.0)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0, 6.0, 0)
	_root.add_child(_beam)
	_fx = Effects.new()
	_root.add_child(_fx)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_root.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 1.7, 5.6), Vector3(0, 0.45, 0))
	_cam.v_offset = -0.25


func _gui_input(e: InputEvent) -> void:
	if not UIJuice.is_tap(e):
		return
	accept_event()
	if _t >= UNLOCK_AT or not first:
		if _t < UNLOCK_AT:
			Meta.note_skip("walkout")
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UITokens.EXIT)
	tw.tween_callback(func():
		done.emit()
		queue_free())


func _beat(name: String, at: float) -> bool:
	if _t >= at and not _beats.has(name):
		_beats[name] = true
		return true
	return false


func _process(delta: float) -> void:
	_t += delta
	var rc := UITokens.rarity(ArsenalData.rarity_of(id))
	# Slow push-in and turntable.
	var k := clampf(_t / TOTAL, 0.0, 1.0)
	_cam.position = Vector3(0, 1.7 - 0.25 * k, 5.6 - 1.0 * k)
	_cam.look_at(Vector3(0, 0.45, 0))
	_machine.rotation.y = deg_to_rad(-28) + sin(_t * 0.6) * 0.35
	_fire = maxf(0.0, _fire - delta * 3.0)
	WeaponModels.animate(_machine, _t, _fire, 0.0)
	if _beat("light", 0.7):
		_flash.color.a = 0.75
		Audio.play("upgrade", -4.0)
		UIJuice.haptic("QUICK_RISE", 0.6)
	if _t >= 0.7:
		var l := clampf((_t - 0.7) / 0.5, 0.0, 1.0)
		_key.light_energy = 1.25 * l
		_fill.light_energy = 1.4 * l
		(_root.get_meta("env") as Environment).ambient_light_energy = 0.6 * l
		_beam_mat.set_shader_parameter("strength", 1.6 * (1.0 - smoothstep(0.35, 1.6, _t - 0.7)) * minf(1.0, (_t - 0.7) * 8.0))
		if _dais_mat:
			_dais_mat.set_shader_parameter("rune_k", 0.4 + 0.6 * l)
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 2.5)
	if _beat("title", 0.25):
		_title.create_tween().tween_property(_title, "modulate:a", 1.0, 0.3)
	if _beat("name", 1.3):
		_name.modulate.a = 1.0
		_name.scale = Vector2(2.2, 2.2)
		_name.create_tween().tween_property(_name, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_sub.create_tween().tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.2)
		Audio.play("stairs_top", -4.0)
		UIJuice.haptic("THUD", 1.0)
		UIKit.sparkles(self, _name.position + _name.size * 0.5, rc.lightened(0.4), 34, 360.0)
	if _beat("volley", 2.1):
		_volley()
	if _beat("tap", UNLOCK_AT):
		_tap.create_tween().tween_property(_tap, "modulate:a", 1.0, 0.3)
	if _t >= TOTAL:
		close()


## One demo volley: muzzle flash, the machine's own projectile look down the stage.
func _volley() -> void:
	_fire = 1.0
	var mz: Node3D = _machine.get_meta("muzzle") if _machine.has_meta("muzzle") else null
	var from := mz.global_position if mz else _machine.global_position + Vector3(0, 0.6, 0)
	var col := WeaponModels.glow_color(id)
	_fx.muzzle(from, col, Vector3(0, 0, 1))
	var kind := Effects.shot_kind(id)
	var to := Vector3(0.0, 0.3, 6.0)
	if kind == "beam" or not Effects.KINDS.has(Effects.ALIAS.get(kind, kind)):
		_fx.rail_fire(from, to, col)
	else:
		for i in (3 if id in ["rockets", "gatling", "drone"] else 1):
			var off := Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.5), 0)
			_fx.projectile(from, to + off, str(Effects.ALIAS.get(kind, kind)), 0.45 + i * 0.06, func(): pass)
	_sfx()
	UIJuice.haptic("CLICK", 0.7)


func _sfx() -> void:
	for s in (ArsenalData.MACHINES[id] as Dictionary).get("sfx", []):
		if Audio.has_sfx(str(s)):
			Audio.play(str(s), -4.0)
			return
	var fallback := {"ballista": "ballista", "cannon": "plasma", "rockets": "rocket", "drone": "drone",
			"laser": "laser", "mortar": "cannon", "gatling": "turret_shot", "railgun": "tesla", "prism": "laser"}
	Audio.play(str(fallback.get(id, "ballista")), -4.0)
