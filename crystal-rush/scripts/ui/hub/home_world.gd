class_name HomeWorld
extends Node3D
## The Home stage scenery (UI v2, fusion §6.8 "Home"): a bright summer morning at the head of
## the crystal bridge. A gradient sky with a soft sun and painterly clouds (home_sky), a sea of
## clouds below, floating meadow islands far away, the crystal bridge (ice planks, gold rails,
## glowing crystal posts) running to the horizon, and the ivory-marble rotunda terrace (gold
## inlay, balustrade, crystal lanterns, flower planters) the hero's dais stands on. Origin = the
## dais centre on the terrace floor (y = 0); the bridge runs towards -Z.
##   var w := HomeWorld.new(); add_child(w); w.build(Save.quality == "high")
## Everything is procedural (no new assets); `set_accent()` tints the lantern crystals.

const SKY_SHADER := preload("res://shaders/hub/home_sky.gdshader")
const MARBLE_SHADER := preload("res://shaders/hub/home_marble.gdshader")
const BRIDGE_SHADER := preload("res://shaders/hub/home_bridge.gdshader")
const CLOUD_SHADER := preload("res://shaders/hub/home_cloud.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

const RIM_R := 6.0             ## terrace radius
const BRIDGE_W := 2.6          ## deck width
const BRIDGE_LEN := 170.0
const PLANK := 1.2
## Direction towards the sun in the sky (behind the bridge, to the right).
const SUN_DIR := Vector3(0.42, 0.3, -0.86)

var quality_high := true
var environment: Environment
var key_light: DirectionalLight3D
var sky_mat: ShaderMaterial
var _crystal_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D
var _halos: Array[MeshInstance3D] = []
var _motes: CPUParticles3D
var _t := 0.0
var _gold: StandardMaterial3D
var _ivory: StandardMaterial3D


func build(p_quality_high := true) -> void:
	quality_high = p_quality_high
	_materials()
	_build_env()
	_build_terrace()
	_build_balustrade()
	_build_lanterns()
	_build_planters()
	_build_bridge()
	_build_islands()
	_build_clouds()
	_build_motes()


func _process(delta: float) -> void:
	_t += delta
	if sky_mat:
		sky_mat.set_shader_parameter("drift", fmod(_t, 4000.0))
	var k := 0.85 + 0.15 * sin(fmod(_t, 200.0 * PI) * 1.4)
	for i in _halos.size():
		var h := _halos[i]
		var kk := k + 0.08 * sin(_t * 0.9 + i * 1.7)
		h.scale = Vector3.ONE * kk


## Tints the lantern crystals and halos (the hero's gem colour, softened).
func set_accent(c: Color) -> void:
	var cc := Color(0.78, 0.93, 1.0).lerp(c, 0.35)
	if _crystal_mat:
		_crystal_mat.albedo_color = cc.lightened(0.2)
		_crystal_mat.emission = cc
	if _halo_mat:
		_halo_mat.albedo_color = Color(cc.r, cc.g, cc.b, 0.55)
	if _motes:
		_motes.color = Color(1.0, 0.95, 0.82).lerp(c.lightened(0.5), 0.25)


# ------------------------------------------------------------------ materials and environment

func _materials() -> void:
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(0.95, 0.78, 0.46)
	_gold.metallic = 0.3
	_gold.roughness = 0.32
	_gold.metallic_specular = 0.7
	_gold.emission_enabled = true
	_gold.emission = Color(0.55, 0.4, 0.18)
	_gold.emission_energy_multiplier = 0.35
	_ivory = StandardMaterial3D.new()
	_ivory.albedo_color = Color(0.95, 0.92, 0.86)
	_ivory.roughness = 0.45
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.86, 0.96, 1.0)
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Color(0.6, 0.86, 1.0)
	_crystal_mat.emission_energy_multiplier = 1.6
	_crystal_mat.roughness = 0.12
	_crystal_mat.metallic_specular = 0.9
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = HubShowcase._radial_tex()
	_halo_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.55)
	_halo_mat.no_depth_test = false


func _build_env() -> void:
	var env := Environment.new()
	environment = env
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("noise_tex", NOISE_TEX)
	sky_mat.set_shader_parameter("sun_dir", SUN_DIR.normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.96)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for lv in 7:
		env.set_glow_level(lv, 1.0 if lv in [1, 2, 3] else 0.0)
	# Aerial perspective: far islands and the bridge melt into the warm morning haze.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.99, 0.92, 0.82)
	env.fog_light_energy = 1.0
	env.fog_density = 0.85
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 130.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Key light: warm morning sun from the front left (the sky's sun disc sits behind the
	# bridge for the glow; the hero is lit from the camera side).
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-46, -32, 0)
	key_light.light_color = Color(1.0, 0.96, 0.9)
	key_light.light_energy = 0.9
	# No shadow maps: in gl_compatibility a shadowed directional light double-adds the ambient
	# and the other lights (the marble clipped to white). Contact shadows are soft blobs
	# (HubStage) and painted AO instead.
	key_light.shadow_enabled = false
	add_child(key_light)
	# Golden rim from the sun behind the bridge.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 150, 0)
	rim.light_color = Color(1.0, 0.8, 0.52)
	rim.light_energy = 0.55
	rim.light_specular = 0.0
	add_child(rim)


# ------------------------------------------------------------------ terrace

func _build_terrace() -> void:
	var top := MeshInstance3D.new()
	top.name = "Terrace"
	var cm := CylinderMesh.new()
	cm.top_radius = RIM_R
	cm.bottom_radius = RIM_R - 0.25
	cm.height = 0.5
	cm.radial_segments = 96
	cm.rings = 1
	top.mesh = cm
	var mm := ShaderMaterial.new()
	mm.shader = MARBLE_SHADER
	mm.set_shader_parameter("noise_tex", NOISE_TEX)
	mm.set_shader_parameter("rim_r", RIM_R)
	top.material_override = mm
	top.position.y = -0.25
	add_child(top)
	# Gold edge band and a lower ivory tier with a second gold line.
	_torus(RIM_R, 0.035, 0.0, _gold)
	var tier := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = RIM_R + 0.28
	tm.bottom_radius = RIM_R - 0.6
	tm.height = 1.1
	tm.radial_segments = 96
	tier.mesh = tm
	tier.material_override = _ivory
	tier.position.y = -0.5 - 0.55
	add_child(tier)
	_torus(RIM_R + 0.28, 0.03, -0.5, _gold)
	# Underside: the terrace is a floating platform (seen at the screen edges on tall phones).
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = RIM_R - 0.6
	um.bottom_radius = 0.8
	um.height = 4.0
	um.radial_segments = 48
	under.mesh = um
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.84, 0.79, 0.72)
	stone.roughness = 0.9
	under.material_override = stone
	under.position.y = -1.6 - 2.0
	add_child(under)


func _torus(r: float, thick: float, y: float, mat: Material) -> MeshInstance3D:
	var t := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 96
	tm.ring_segments = 8
	t.mesh = tm
	t.material_override = mat
	t.position.y = y
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(t)
	return t


## Angle (radians, atan2(z, x) in the xz plane) of the bridge opening and its half width.
func _gap() -> Vector2:
	return Vector2(-PI * 0.5, asin((BRIDGE_W * 0.5 + 0.45) / RIM_R))


func _in_gap(a: float) -> bool:
	var g := _gap()
	return absf(wrapf(a - g.x, -PI, PI)) < g.y


## Balustrade round the back half of the rim (the camera side stays open): vase balusters, a
## top rail, square pedestals with gold caps every few balusters.
func _build_balustrade() -> void:
	var r := RIM_R - 0.16
	var step := 0.26
	var count := int(TAU * r / step)
	var bal := CylinderMesh.new()
	bal.top_radius = 0.035
	bal.bottom_radius = 0.055
	bal.height = 0.5
	bal.radial_segments = 8
	bal.rings = 1
	var xfs: Array[Transform3D] = []
	var rail_pts: Array = []          # arrays of contiguous angles
	var cur: Array = []
	var ped_xfs: Array[Transform3D] = []
	for i in count:
		var a := -PI + TAU * float(i) / count
		# Keep the front (towards the camera, +Z) open and the bridge gap clear.
		var front := sin(a) > 0.35
		if _in_gap(a) or front:
			if cur.size() > 1:
				rail_pts.append(cur)
			cur = []
			continue
		cur.append(a)
		var p := Vector3(cos(a) * r, 0.25, sin(a) * r)
		if i % 6 == 0:
			ped_xfs.append(Transform3D(Basis.from_euler(Vector3(0, -a, 0)), p + Vector3(0, 0.07, 0)))
		else:
			xfs.append(Transform3D(Basis.IDENTITY, p))
	if cur.size() > 1:
		rail_pts.append(cur)
	_multi(bal, _ivory, xfs)
	var ped := BoxMesh.new()
	ped.size = Vector3(0.16, 0.64, 0.16)
	_multi(ped, _ivory, ped_xfs)
	var cap := SphereMesh.new()
	cap.radius = 0.07
	cap.height = 0.12
	cap.radial_segments = 12
	cap.rings = 6
	var cap_xfs: Array[Transform3D] = []
	for t in ped_xfs:
		cap_xfs.append(Transform3D(Basis.IDENTITY, t.origin + Vector3(0, 0.36, 0)))
	_multi(cap, _gold, cap_xfs)
	# Top rail and plinth: short tangent boxes between consecutive angles.
	var seg := BoxMesh.new()
	seg.size = Vector3(1, 1, 1)
	var rail_xfs: Array[Transform3D] = []
	var plinth_xfs: Array[Transform3D] = []
	var gold_xfs: Array[Transform3D] = []
	for run: Array in rail_pts:
		for k in run.size() - 1:
			var a0: float = run[k]
			var a1: float = run[k + 1]
			var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
			var mid := (p0 + p1) * 0.5
			var dir := (p1 - p0)
			var len := dir.length() + 0.02
			var yaw := atan2(dir.x, dir.z)
			var b := Basis.from_euler(Vector3(0, yaw, 0))
			rail_xfs.append(Transform3D(b.scaled(Vector3(0.12, 0.07, len)), mid + Vector3(0, 0.53, 0)))
			gold_xfs.append(Transform3D(b.scaled(Vector3(0.124, 0.015, len)), mid + Vector3(0, 0.575, 0)))
			plinth_xfs.append(Transform3D(b.scaled(Vector3(0.16, 0.06, len)), mid + Vector3(0, 0.03, 0)))
	_multi(seg, _ivory, rail_xfs)
	_multi(seg, _ivory, plinth_xfs)
	_multi(seg, _gold, gold_xfs)


func _multi(mesh: Mesh, mat: Material, xfs: Array[Transform3D], colors := PackedColorArray()) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)
	return mi


## Crystal lanterns: two tall ones flanking the bridge entrance, four round the rim.
func _build_lanterns() -> void:
	var g := _gap()
	var spots: Array[Vector3] = []
	var hx := BRIDGE_W * 0.5 + 0.28
	spots.append(Vector3(-hx, 0, -(RIM_R - 0.12)))
	spots.append(Vector3(hx, 0, -(RIM_R - 0.12)))
	for da in [0.75, 1.45]:
		for sgn in [-1.0, 1.0]:
			var a: float = g.x + sgn * da
			spots.append(Vector3(cos(a) * (RIM_R - 0.16), 0, sin(a) * (RIM_R - 0.16)))
	for i in spots.size():
		var tall := i < 2
		_lantern(spots[i], 1.55 if tall else 1.15)


func _lantern(p: Vector3, h: float) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.22, 0.3)
	base.mesh = bm
	base.material_override = _ivory
	base.position.y = 0.11
	n.add_child(base)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.09
	cm.height = h - 0.42
	cm.radial_segments = 12
	col.mesh = cm
	col.material_override = _ivory
	col.position.y = 0.22 + (h - 0.42) * 0.5
	n.add_child(col)
	var capm := CylinderMesh.new()
	capm.top_radius = 0.13
	capm.bottom_radius = 0.08
	capm.height = 0.08
	capm.radial_segments = 12
	var cap := MeshInstance3D.new()
	cap.mesh = capm
	cap.material_override = _gold
	cap.position.y = h - 0.16
	n.add_child(cap)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.1
	rm.bottom_radius = 0.1
	rm.height = 0.03
	rm.radial_segments = 12
	ring.mesh = rm
	ring.material_override = _gold
	ring.position.y = 0.26
	n.add_child(ring)
	# The crystal: an elongated octahedron (4-sided sphere) floating over the cap.
	var cry := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.42
	sm.radial_segments = 4
	sm.rings = 2
	cry.mesh = sm
	cry.material_override = _crystal_mat
	cry.position.y = h + 0.1
	cry.rotation.y = PI * 0.25
	cry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(cry)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	halo.mesh = q
	halo.material_override = _halo_mat
	halo.position.y = h + 0.1
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(halo)
	_halos.append(halo)


## Flower planters on the rim, either side of the bridge.
func _build_planters() -> void:
	var g := _gap()
	var leaf := StandardMaterial3D.new()
	leaf.vertex_color_use_as_albedo = true
	leaf.roughness = 0.85
	var bush := SphereMesh.new()
	bush.radius = 0.5
	bush.height = 0.85
	bush.radial_segments = 12
	bush.rings = 6
	var flower := SphereMesh.new()
	flower.radius = 0.045
	flower.height = 0.09
	flower.radial_segments = 6
	flower.rings = 3
	var bush_x: Array[Transform3D] = []
	var bush_c := PackedColorArray()
	var fl_x: Array[Transform3D] = []
	var fl_c := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var greens := [Color(0.42, 0.62, 0.3), Color(0.5, 0.7, 0.34), Color(0.36, 0.55, 0.3)]
	var blooms := [Color(1.0, 0.78, 0.84), Color(1.0, 0.96, 0.9), Color(1.0, 0.86, 0.45), Color(0.86, 0.78, 1.0)]
	for sgn in [-1.0, 1.0]:
		for da in [0.42, 1.1]:
			var a: float = g.x + sgn * da
			var p := Vector3(cos(a) * (RIM_R - 0.75), 0, sin(a) * (RIM_R - 0.75))
			var pot := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.42
			pm.bottom_radius = 0.3
			pm.height = 0.36
			pm.radial_segments = 16
			pot.mesh = pm
			pot.material_override = _ivory
			pot.position = p + Vector3(0, 0.18, 0)
			add_child(pot)
			var band := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.4
			tm.outer_radius = 0.44
			tm.rings = 24
			tm.ring_segments = 6
			band.mesh = tm
			band.material_override = _gold
			band.position = p + Vector3(0, 0.35, 0)
			add_child(band)
			for k in 4:
				var o := Vector3(rng.randf_range(-0.16, 0.16), 0.46 + rng.randf_range(0.0, 0.12), rng.randf_range(-0.16, 0.16))
				var s := rng.randf_range(0.5, 0.78)
				bush_x.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p + o))
				bush_c.append(greens[k % greens.size()])
			for k in 14:
				var aa := rng.randf() * TAU
				var rr := rng.randf_range(0.1, 0.36)
				var y := 0.6 + rng.randf_range(0.0, 0.22) * (1.0 - rr * 2.0)
				fl_x.append(Transform3D(Basis.IDENTITY, p + Vector3(cos(aa) * rr, y, sin(aa) * rr)))
				fl_c.append(blooms[k % blooms.size()])
	_multi(bush, leaf, bush_x, bush_c)
	_multi(flower, leaf, fl_x, fl_c)


# ------------------------------------------------------------------ bridge

func _build_bridge() -> void:
	var z0 := -(RIM_R - 0.3)
	var count := int(BRIDGE_LEN / PLANK)
	var pm := BoxMesh.new()
	var half := Vector3(BRIDGE_W * 0.5, 0.09, PLANK * 0.5 - 0.025)
	pm.size = half * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = BRIDGE_SHADER
	mat.set_shader_parameter("noise_tex", NOISE_TEX)
	mat.set_shader_parameter("half", half)
	var xfs: Array[Transform3D] = []
	for i in count:
		xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, -0.09, z0 - PLANK * (i + 0.5))))
	var deck := _multi(pm, mat, xfs)
	deck.name = "Bridge"
	var far_z := z0 - BRIDGE_LEN
	var mid_z := (z0 + far_z) * 0.5
	# Keel under the deck.
	var keel := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(BRIDGE_W - 0.5, 0.32, BRIDGE_LEN)
	keel.mesh = km
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color(0.62, 0.82, 0.95)
	kmat.emission_enabled = true
	kmat.emission = Color(0.4, 0.7, 0.9)
	kmat.emission_energy_multiplier = 0.25
	kmat.roughness = 0.2
	keel.material_override = kmat
	keel.position = Vector3(0, -0.34, mid_z)
	add_child(keel)
	# Gold rails on low crystal posts along both edges.
	for sgn in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.05, 0.05, BRIDGE_LEN)
		rail.mesh = rm
		rail.material_override = _gold
		rail.position = Vector3(sgn * (BRIDGE_W * 0.5 - 0.05), 0.42, mid_z)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)
		var lip := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.07, 0.04, BRIDGE_LEN)
		lip.mesh = lm
		lip.material_override = _gold
		lip.position = Vector3(sgn * (BRIDGE_W * 0.5 + 0.0), 0.0, mid_z)
		add_child(lip)
	var post := CylinderMesh.new()
	post.top_radius = 0.04
	post.bottom_radius = 0.055
	post.height = 0.42
	post.radial_segments = 6
	var tip := SphereMesh.new()
	tip.radius = 0.05
	tip.height = 0.2
	tip.radial_segments = 4
	tip.rings = 2
	var post_x: Array[Transform3D] = []
	var tip_x: Array[Transform3D] = []
	var z := z0 - 1.2
	while z > far_z:
		for sgn in [-1.0, 1.0]:
			var x: float = sgn * (BRIDGE_W * 0.5 - 0.05)
			post_x.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.21, z)))
			tip_x.append(Transform3D(Basis.from_euler(Vector3(0, PI * 0.25, 0)), Vector3(x, 0.52, z)))
		z -= 3.6
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.85, 0.95, 1.0)
	pmat.roughness = 0.15
	pmat.emission_enabled = true
	pmat.emission = Color(0.55, 0.85, 1.0)
	pmat.emission_energy_multiplier = 0.25
	_multi(post, pmat, post_x)
	_multi(tip, _crystal_mat, tip_x)


# ------------------------------------------------------------------ islands and clouds

func _build_islands() -> void:
	var spots := [
		# x, y, z, radius, trees (inside the camera's narrow view, above the balustrade line)
		[-6.2, 1.6, -31.0, 1.7, 2],
		[7.4, 2.8, -40.0, 2.3, 3],
		[-13.5, 5.0, -64.0, 3.8, 4],
		[16.0, 7.5, -82.0, 4.8, 5],
		[-26.0, 10.0, -118.0, 7.0, 6],
		[29.0, 12.5, -135.0, 8.0, 6],
		[4.2, -1.2, -19.0, 0.8, 1],
	]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for s: Array in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = _island_mesh(float(s[3]), rng)
		mi.material_override = mat
		mi.position = Vector3(s[0], s[1], s[2])
		mi.rotation.y = rng.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_trees(mi, float(s[3]), int(s[4]), rng)


## An irregular floating island: a grassy cap over an earthy, rocky cone that narrows to a
## point; vertex colours only.
func _island_mesh(r: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var seg := 18
	var rings := 6
	var depth := r * rng.randf_range(1.1, 1.5)
	var jit := PackedFloat32Array()
	for i in seg:
		jit.append(rng.randf_range(0.82, 1.12))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_a := Color(0.52, 0.72, 0.36)
	var grass_b := Color(0.62, 0.8, 0.42)
	var earth := Color(0.66, 0.54, 0.42)
	var rock := Color(0.55, 0.5, 0.56)
	var ring_pts: Array = []
	for k in rings + 1:
		var t := float(k) / rings
		var rr := r * pow(1.0 - t, 0.75) * (1.0 if k > 0 else 1.0)
		var y := -depth * t - (0.0 if k == 0 else 0.15)
		var pts := PackedVector3Array()
		for i in seg:
			var a := TAU * i / seg
			var j := jit[i] * (1.0 + 0.12 * sin(a * 3.0 + k))
			pts.append(Vector3(cos(a) * rr * j, y + (rng.randf_range(-0.12, 0.12) * r * 0.1 if k > 0 else 0.0), sin(a) * rr * j))
		ring_pts.append(pts)
	# Grass top: a slightly domed fan.
	var centre := Vector3(0, r * 0.06, 0)
	var top: PackedVector3Array = ring_pts[0]
	for i in seg:
		var a := top[i]
		var b := top[(i + 1) % seg]
		st.set_color(grass_b)
		st.add_vertex(centre)
		st.set_color(grass_a)
		st.add_vertex(b)
		st.add_vertex(a)
	# Sides.
	for k in rings:
		var up: PackedVector3Array = ring_pts[k]
		var dn: PackedVector3Array = ring_pts[k + 1]
		var cu := earth.lerp(rock, float(k) / rings) if k > 0 else grass_a.darkened(0.2)
		var cd := earth.lerp(rock, float(k + 1) / rings)
		for i in seg:
			var i2 := (i + 1) % seg
			st.set_color(cu)
			st.add_vertex(up[i])
			st.add_vertex(up[i2])
			st.set_color(cd)
			st.add_vertex(dn[i])
			st.set_color(cu)
			st.add_vertex(up[i2])
			st.set_color(cd)
			st.add_vertex(dn[i2])
			st.add_vertex(dn[i])
	st.generate_normals()
	return st.commit()


func _trees(parent: Node3D, r: float, n: int, rng: RandomNumberGenerator) -> void:
	var leaf := StandardMaterial3D.new()
	leaf.vertex_color_use_as_albedo = true
	leaf.roughness = 0.9
	var trunk := StandardMaterial3D.new()
	trunk.albedo_color = Color(0.5, 0.38, 0.3)
	for i in n:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, r * 0.65)
		var s := r * rng.randf_range(0.16, 0.26)
		var p := Vector3(cos(a) * d, r * 0.04, sin(a) * d)
		var tr := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = s * 0.08
		tm.bottom_radius = s * 0.12
		tm.height = s * 0.9
		tm.radial_segments = 6
		tr.mesh = tm
		tr.material_override = trunk
		tr.position = p + Vector3(0, s * 0.45, 0)
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(tr)
		var crown := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = s * 0.55
		cm.height = s * 1.0
		cm.radial_segments = 10
		cm.rings = 5
		crown.mesh = cm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = [Color(0.36, 0.58, 0.32), Color(0.44, 0.66, 0.34), Color(0.5, 0.7, 0.4)][i % 3]
		lm.roughness = 0.9
		crown.material_override = lm
		crown.position = p + Vector3(0, s * 1.15, 0)
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(crown)


## Soft cloud puffs below and around the terrace and along the bridge (depth layers).
func _build_clouds() -> void:
	var spots := [
		[-6.5, -2.4, -20.0, 10.0], [7.5, -2.8, -24.0, 12.0], [-14.0, 0.5, -50.0, 18.0],
		[15.0, 1.5, -62.0, 20.0], [0.0, -5.5, -45.0, 24.0], [-24.0, 4.5, -100.0, 26.0],
		[26.0, 5.5, -112.0, 28.0], [-4.0, -3.0, -32.0, 12.0],
	]
	var q := QuadMesh.new()
	q.size = Vector2(1, 0.55)
	for i in spots.size():
		var s: Array = spots[i]
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = CLOUD_SHADER
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		m.set_shader_parameter("seed", float(i) * 1.37)
		mi.material_override = m
		mi.position = Vector3(s[0], s[1], s[2])
		mi.scale = Vector3.ONE * float(s[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.amount = 36 if quality_high else 16
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(3.2, 1.3, 6.0)
	_motes.position = Vector3(0, 1.5, -6.0)
	_motes.direction = Vector3(0.2, 1, 0)
	_motes.spread = 40.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.06
	_motes.initial_velocity_max = 0.18
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.0
	var mq := QuadMesh.new()
	mq.size = Vector2(0.07, 0.07)
	_motes.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_texture = HubShowcase._radial_tex()
	mm.vertex_color_use_as_albedo = true
	_motes.material_override = mm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.3, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	_motes.color_ramp = grad
	_motes.color = Color(1.0, 0.94, 0.78)
	add_child(_motes)
