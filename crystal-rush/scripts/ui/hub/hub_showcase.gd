class_name HubShowcase
extends SubViewportContainer
## A small 3D stage inside the UI (arsenal_design.md §7.1: "3D showcase" strips): its own world
## in a transparent SubViewport, so the tab's painted backdrop shows around it. UI v2 daylight
## studio: neutral-warm light, no shadow maps, and the owner's dais re-glazed as ivory marble
## with gold (shaders/hub/home_dais, the same dais as on the Home terrace).
##   mode "machine": the dais with its crystal ring in the family accent, a soft light cone from
##                   above, rising motes, the machine on a slow turntable (silhouette for a
##                   locked machine);
##   mode "hero":    the hero on the dais, its ring warmed by the hero colour;
##   mode "army":    a formation of the owner's Crystal Knights (VAT idle) on an ivory dais.
## Without the GLB both keep the procedural (ivory and gold) pedestal. Rendering stops while the
## container is hidden (UPDATE_WHEN_VISIBLE).

signal tapped

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float strength = 0.35;
varying float vy;
void vertex() { vy = UV.y; }
void fragment() {
	float edge = abs(dot(NORMAL, VIEW));
	// Vertical ramp: 0 at the top (never a hard edge where the strip cuts it), a peak at about
	// 60 % height, 0 again at the floor; sides feathered by the view angle.
	float ramp = smoothstep(0.0, 0.6, vy) * (1.0 - smoothstep(0.82, 1.0, vy));
	float a = ramp * pow(clamp(edge, 0.0, 1.0), 2.2) * strength * 0.8;
	ALBEDO = color.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

var mode := "machine"
var accent := Color(0.4, 0.7, 1.0)
## Hero mode frames by height: the subject region (w, h) in world units around the look target.
var hero_region := Vector2(1.7, 2.25)
var spin_speed := 0.45
var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _subject: Node3D
var _subject_key := ""
var _turn: Node3D
var _ring_mat: StandardMaterial3D
var _dais_mat: ShaderMaterial
var _beam_mat: ShaderMaterial
var _motes: CPUParticles3D
var _t := 0.0
var _crowd: CrowdView
var _clip: VatClip
var _crowd_pos := PackedVector3Array()
var _spin_boost := 0.0
var _drag_x := -1.0


func _init(p_mode := "machine") -> void:
	mode = p_mode
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	_build_stage()


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# UI v2 daylight studio: neutral-warm ambient, a soft key from the front left and a rim
	# without specular. No shadow maps: in gl_compatibility a shadowed directional light
	# double-adds the ambient and the other lights (the ivory dais clipped to gold-white).
	env.ambient_light_color = Color(0.88, 0.9, 0.98) if mode == "machine" else Color(0.95, 0.91, 0.9)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_color = Color(1.0, 0.97, 0.92)
	key.light_energy = 0.85
	key.shadow_enabled = false
	_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12, 160, 0)
	rim.light_color = Color(0.78, 0.88, 1.0) if mode == "machine" else Color(1.0, 0.84, 0.62)
	rim.light_energy = 0.5
	rim.light_specular = 0.0
	_root.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_root.add_child(_cam)
	_turn = Node3D.new()
	_root.add_child(_turn)
	_build_dais()
	match mode:
		"hero":
			_cam.look_at_from_position(Vector3(0, 1.1, 4.9), Vector3(0, 0.82, 0))
		"army":
			_cam.look_at_from_position(Vector3(0, 2.6, 5.6), Vector3(0, 0.3, 0))
			_build_army()
		_:
			_cam.look_at_from_position(Vector3(0, 1.55, 4.6), Vector3(0, 0.45, 0))
	resized.connect(_frame)


## The owner's dais `w` wide with its top centre at y = 0 (mesh cached per width):
## {node: MeshInstance3D, mat: ShaderMaterial (asset_altar: the ring glows with rune_k /
## rune_color)}, or {} without assets/ui/dais.glb.
static func owner_dais(w: float) -> Dictionary:
	var arr := WeaponModels.asset_arrays("dais", AABB(Vector3(-w * 0.5, 0, -w * 0.5), Vector3(w, 2.0, w)), 0.0, "width")
	if arr.is_empty():
		return {}
	var key := "%.3f" % w
	if not _dais_meshes.has(key):
		var sv: PackedVector3Array = arr["v"]
		var top := 0.0
		for p in sv:
			if Vector2(p.x, p.z).length() < w * 0.15:
				top = maxf(top, p.y)
		var all := PackedInt32Array()
		for i in (arr["idx"] as PackedInt32Array).size() / 3:
			all.append(i)
		_dais_meshes[key] = {"mesh": WeaponModels.asset_submesh(arr, all), "top": top}
	var d: Dictionary = _dais_meshes[key]
	var mi := MeshInstance3D.new()
	mi.name = "Dais"
	mi.mesh = d["mesh"]
	mi.position.y = -float(d["top"])
	var mat := WeaponModels.asset_material(arr, CacheModels.ALTAR_SHADER)
	mat.set_shader_parameter("rune_color", Color(0.45, 0.82, 1.0))
	mat.set_shader_parameter("rune_k", 0.3)
	mat.set_shader_parameter("rune_mix", 0.0)
	mat.set_shader_parameter("gem_k", 0.6)
	mi.material_override = mat
	return {"node": mi, "mat": mat, "depth": float(d["top"])}


static var _dais_meshes := {}


## The owner's dais re-glazed as the v2 ivory marble with gold (home_dais), the same as on the
## Home terrace, Heroes and Arsenal; its crystal ring glows in `ring` (rune_color / rune_k work
## as on the altar shader). {} without the GLB.
static func ivory_dais(w: float, ring := Color(0.45, 0.82, 1.0)) -> Dictionary:
	var d := owner_dais(w)
	if d.is_empty():
		return d
	var src: ShaderMaterial = d["mat"]
	var m := ShaderMaterial.new()
	m.shader = HubStage.DAIS_SHADER
	for k in ["albedo_tex", "normal_tex", "has_normal"]:
		m.set_shader_parameter(k, src.get_shader_parameter(k))
	m.set_shader_parameter("rune_color", ring)
	m.set_shader_parameter("rune_k", 0.6)
	(d["node"] as MeshInstance3D).material_override = m
	d["mat"] = m
	return d


func _build_dais() -> void:
	var dw := 1.5 if mode == "hero" else 2.0
	var owner := owner_dais(dw) if mode != "army" else {}
	if not owner.is_empty():
		# UI v2: the owner's dais re-glazed as warm ivory marble with gold (home_dais), its
		# crystal ring glowing in the accent colour - the same dais as on the Home terrace.
		var src: ShaderMaterial = owner["mat"]
		_dais_mat = ShaderMaterial.new()
		_dais_mat.shader = HubStage.DAIS_SHADER
		for k in ["albedo_tex", "normal_tex", "has_normal"]:
			_dais_mat.set_shader_parameter(k, src.get_shader_parameter(k))
		(owner["node"] as MeshInstance3D).material_override = _dais_mat
		_root.add_child(owner["node"])
		_build_glow_fx(dw * 0.5, -float(owner["depth"]) - 0.01)
		return
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.9, 0.87, 0.82)
	dark.metallic = 0.05
	dark.roughness = 0.45
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.46)
	gold.metallic = 0.3
	gold.roughness = 0.32
	var r := 1.2 if mode != "army" else 2.3
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 1.06
	cm.height = 0.26
	cm.radial_segments = 48
	base.mesh = cm
	base.material_override = dark
	base.position.y = -0.13
	_root.add_child(base)
	var step := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = r * 1.12
	cm2.bottom_radius = r * 1.2
	cm2.height = 0.14
	cm2.radial_segments = 48
	step.mesh = cm2
	step.material_override = dark
	step.position.y = -0.31
	_root.add_child(step)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.035
	tm.outer_radius = r + 0.035
	tm.rings = 48
	rim.mesh = tm
	rim.material_override = gold
	rim.position.y = 0.0
	_root.add_child(rim)
	# Accent ring inlaid in the top (emissive), and a soft floor glow below the dais.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = accent
	var ring := MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = r * 0.72
	tm2.outer_radius = r * 0.76
	tm2.rings = 48
	ring.mesh = tm2
	ring.material_override = _ring_mat
	ring.position.y = 0.005
	ring.scale = Vector3(1, 0.2, 1)
	_root.add_child(ring)
	_build_glow_fx(r, -0.37)


## Floor glow (at `floor_y`), the machine stage's light cone and the rising motes round a dais
## of radius `r`.
func _build_glow_fx(r: float, floor_y: float) -> void:
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	# Hero mode frames a narrow region (tall phones fit it by width): the glow must fade out
	# inside the viewport, or its cut edge shows as a vertical seam beside the dais.
	var gs := r * (2.5 if mode == "hero" else 4.2)
	q.size = Vector2(gs, gs)
	q.orientation = PlaneMesh.FACE_Y
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = _radial_tex()
	gm.albedo_color = Color(accent.r, accent.g, accent.b, 0.5)
	glow.material_override = gm
	glow.position.y = floor_y
	glow.set_meta("glow_mat", gm)
	_root.add_child(glow)
	glow.name = "FloorGlow"
	if mode == "machine":
		var beam := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.25
		bm.bottom_radius = r * 1.05
		bm.height = 4.2
		bm.cap_top = false
		bm.cap_bottom = false
		bm.radial_segments = 32
		beam.mesh = bm
		_beam_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = BEAM_SHADER
		_beam_mat.shader = sh
		_beam_mat.set_shader_parameter("color", Color(0.65, 0.8, 1.0))
		beam.material_override = _beam_mat
		beam.position.y = 2.0
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(beam)
	_motes = CPUParticles3D.new()
	_motes.amount = 26
	_motes.lifetime = 3.2
	_motes.preprocess = 3.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = r * 0.95
	_motes.emission_ring_inner_radius = r * 0.5
	_motes.emission_ring_height = 0.05
	_motes.direction = Vector3.UP
	_motes.spread = 12.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.25
	_motes.initial_velocity_max = 0.55
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.0
	var mq := QuadMesh.new()
	mq.size = Vector2(0.06, 0.06)
	_motes.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Light, not dust: additive warm-white / gem-light motes with a bloom falloff.
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_texture = _radial_tex()
	mm.vertex_color_use_as_albedo = true
	_motes.material_override = mm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.25, Color(1, 1, 1, 1.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	_motes.color_ramp = grad
	_motes.color = accent.lightened(0.3)
	_root.add_child(_motes)


## Fits the camera's vertical FOV so the subject region (width x height, world units, around
## the look target) fills the strip at any aspect without cutting the dais.
func _frame() -> void:
	if size.y < 4.0 or _cam == null:
		return
	var region: Vector2 = {"hero": hero_region, "army": Vector2(5.2, 3.0)}.get(mode, Vector2(3.3, 2.5))
	var d := _cam.position.length()
	var aspect := size.x / size.y
	var v_need := 2.0 * atan(region.y * 0.5 / d)
	var h_need := 2.0 * atan(region.x * 0.5 / d)
	var v_from_h := 2.0 * atan(tan(h_need * 0.5) / aspect)
	_cam.fov = clampf(rad_to_deg(maxf(v_need, v_from_h)), 14.0, 70.0)


static var _radial: Texture2D


static func _radial_tex() -> Texture2D:
	if _radial:
		return _radial
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_radial = ImageTexture.create_from_image(img)
	return _radial


## The accent colour of the ring, motes and floor glow.
func set_accent(c: Color) -> void:
	accent = c
	if _ring_mat:
		_ring_mat.albedo_color = c.lightened(0.15)
	if _dais_mat:
		# The hero keeps the owner's ice ring warmed by its colour; a machine's ring takes the
		# family accent.
		_dais_mat.set_shader_parameter("rune_color", Color(0.45, 0.8, 1.0).lerp(c, 0.9 if mode == "hero" else 0.7))
	var g := _root.get_node_or_null("FloorGlow") as MeshInstance3D
	if g:
		(g.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.55)
	if _motes:
		_motes.color = c.lerp(Color(1.0, 0.97, 0.9), 0.6)
	if _beam_mat:
		_beam_mat.set_shader_parameter("color", c.lerp(Color(0.75, 0.85, 1.0), 0.55))


## Shows machine `id` at account level `lvl` (Ascension look from Lv8); `locked` = silhouette.
func show_machine(id: String, lvl := 1, locked := false) -> void:
	var key := "%s:%s:%s" % [id, lvl >= ArsenalData.ASCENSION_LEVEL, locked]
	if key == _subject_key:
		return
	_subject_key = key
	_clear_subject()
	set_accent(UITokens.family(ArsenalData.family_of(id)) if ArsenalData.MACHINES.has(id) else accent)
	if not WeaponModels.KINDS.has(id):
		return
	var m := WeaponModels.machine(id, {"rank": 1, "ascended": lvl >= ArsenalData.ASCENSION_LEVEL and not locked, "crew": true})
	hide_rank_marks(m)
	_fit(m, 1.75, 1.15 if _dais_mat == null else 1.45)
	if locked:
		_silhouette(m)
	_subject = m
	_turn.add_child(m)
	_turn.rotation.y = PI - 0.7
	_spin_boost = 2.5


## Shows hero `id` on the dais.
func show_hero(id: String) -> void:
	if _subject_key == "hero:" + id:
		return
	_subject_key = "hero:" + id
	_clear_subject()
	var h := HeroModels.hero(id)
	h.scale = Vector3.ONE * 1.12
	_subject = h
	_turn.add_child(h)
	_turn.rotation.y = 0.35
	_spin_boost = 1.5
	set_accent(Balance.HEROES[id]["color"] if Balance.HEROES.has(id) else accent)


## Stops / resumes rendering (a full-screen opaque modal covers the page).
func set_paused(paused: bool) -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if paused else SubViewport.UPDATE_WHEN_VISIBLE


## Hides the in-run Rank chevrons and aura of a machine shown in the hub.
static func hide_rank_marks(m: Node3D) -> void:
	for n in ["Chevrons", "Stars", "Aura"]:
		var c := m.get_node_or_null(n) as Node3D
		if c:
			c.visible = false


func _clear_subject() -> void:
	if _subject:
		_subject.queue_free()
		_subject = null


## Scales `m` so its visual box fits `max_w` wide and `max_h` tall, standing on y = 0.
func _fit(m: Node3D, max_w: float, max_h: float) -> void:
	var box := WeaponModels._visual_aabb(m, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return
	var s := minf(max_w / maxf(maxf(box.size.x, box.size.z), 0.01), max_h / maxf(box.size.y, 0.01))
	m.scale = Vector3.ONE * s
	m.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)


func _silhouette(n: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.025, 0.06)
	mat.rim_enabled = false
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).material_override = mat
			(ch as GeometryInstance3D).material_overlay = null
		_silhouette(ch)


func _build_army() -> void:
	var rows := [5, 4, 3]
	var z := 0.6
	for ri in rows.size():
		var n: int = rows[ri]
		for i in n:
			_crowd_pos.append(Vector3((i - (n - 1) * 0.5) * 0.72, 0.0, z))
		z -= 0.62
	if ResourceLoader.exists("res://assets/units/knight/knight_vat_mesh.res"):
		_clip = VatClip.create()
		_crowd = CrowdView.new()
		_root.add_child(_crowd)
		_crowd.setup(_clip.mesh, _crowd_pos.size())
		_clip.attach(_crowd)
		_clip.set_unit_scale(1.35)
		_clip.play("idle", 0.0, true, 1.0)
	else:
		for p in _crowd_pos:
			var mi := MeshInstance3D.new()
			mi.mesh = Models.soldier_mesh(0)
			mi.material_override = Models.vertex_material()
			mi.position = p
			mi.scale = Vector3.ONE * 1.35
			_root.add_child(mi)


## Plays the knights' cheer (Barracks purchase).
func cheer() -> void:
	if _clip:
		_clip.play("victory", 0.15, true, 1.0, 0)
		get_tree().create_timer(1.6).timeout.connect(func():
			if _clip:
				_clip.play("idle", 0.3, true, 1.0))


## A quick celebratory spin of the turntable (upgrade ceremony).
func celebrate(strength := 1.0) -> void:
	_spin_boost = 6.0 * strength
	if _motes:
		_motes.restart()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_spin_boost = move_toward(_spin_boost, 0.0, delta * 3.0)
	if _drag_x < 0.0:
		_turn.rotation.y += (spin_speed + _spin_boost) * delta * (0.25 if mode == "hero" else 1.0)
	if mode == "hero":
		_turn.rotation.y = 0.35 + sin(fmod(_t, 100.0 * PI) * 0.45) * 0.45 + _spin_boost * 0.2
	if _subject:
		if mode == "hero":
			HeroModels.animate_hero(_subject, _t, false, 0.0)
		elif _subject.has_meta("kind"):
			WeaponModels.animate(_subject, _t, 0.0, 0.0)
	if _crowd and _clip:
		_clip.tick(delta)
		_crowd.draw(_crowd_pos, _crowd_pos.size(), 0.0, 0.012, 0.03)
	if _ring_mat:
		var k := 0.75 + 0.25 * sin(fmod(_t, 100.0 * PI) * 2.2)
		_ring_mat.albedo_color = accent.lightened(0.15) * Color(k, k, k, 1.0)
	if _dais_mat:
		_dais_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(fmod(_t, 100.0 * PI) * 2.2))


func _gui_input(event: InputEvent) -> void:
	# Drag spins the turntable; a tap emits `tapped`.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_x = event.position.x
			set_meta("moved", 0.0)
		else:
			if float(get_meta("moved", 0.0)) < 12.0:
				tapped.emit()
			_drag_x = -1.0
	elif event is InputEventMouseMotion and _drag_x >= 0.0:
		var dx: float = event.position.x - _drag_x
		_drag_x = event.position.x
		set_meta("moved", float(get_meta("moved", 0.0)) + absf(dx))
		if mode != "hero":
			_turn.rotation.y += dx * 0.012
