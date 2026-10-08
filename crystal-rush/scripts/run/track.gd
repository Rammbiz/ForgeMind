class_name Track
extends Node3D
## The road a run takes place on, with its sky, light and scenery. A world with a sculpted
## road module (see Worlds) repeats it along the run; otherwise a stone bridge over the sea
## is built procedurally.
## Distance along the run is `d`; the world position is z = -d (the run heads to -Z).
##
## Space world look ("heavy luxe"): a nebula sky shader over the star panorama, a calmer road
## (desaturated, with softly pulsing crystal veins), filmic tonemap with real bloom on emissive
## things, a violet depth haze far down the road, ringed planets, distant stations with lit
## windows, drifting asteroids with glowing crystals and twinkling space dust.

const FLOOR_TEX := preload("res://assets/textures/stone_floor.png")
const WALL_TEX := preload("res://assets/textures/wall_stone.png")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const SKY_SHADER := preload("res://shaders/world_sky.gdshader")
const ROAD_SHADER := preload("res://shaders/world_road.gdshader")
const PLANET_SHADER := preload("res://shaders/world_planet.gdshader")
const RING_SHADER := preload("res://shaders/world_ring.gdshader")
const CRYSTAL_SHADER := preload("res://shaders/world_crystal.gdshader")
const DUST_SHADER := preload("res://shaders/world_dust.gdshader")
const SEA_Y := -5.0
const WALL_H := 0.55
const BEHIND := 25.0            # road shown behind the start line
const BEYOND := 30.0            # road shown past the finish
## Look of the space world when Worlds does not override it (keys of the same name in the
## world dictionary win). Road values keep it calmer than the units and gates.
const SPACE_LOOK := {
	"road_saturation": 0.72,
	"road_brightness": 0.74,
	"road_contrast": 1.06,
	"vein_glow": 0.6,
	"tonemap": Environment.TONE_MAPPER_LINEAR,
	"exposure": 1.0,
	"glow_threshold": 1.1,
	"glow_intensity": 0.85,
	"glow_bloom": 0.04,
	"fog_color": Color(0.16, 0.12, 0.34),
	"fog_begin": 18.0,
	"fog_end": 95.0,
	"fog_max": 0.7,
	"rim_light": Color(0.62, 0.5, 1.0),
	"rim_energy": 0.45,
}

var length := 100.0
var world: Dictionary = {}
var sun: DirectionalLight3D
var environment: Environment
var _drifters: Array[Dictionary] = []   # [{mm: MultiMesh, items: [{pos, axis, speed, phase, scale}]}]
var _t := 0.0


func build(p_length: float, quality_high: bool, p_world := {}) -> void:
	length = p_length
	world = p_world
	if world.has("road"):
		_build_world_environment(quality_high)
		_build_road()
		match str(world.get("scenery", "")):
			"space":
				_build_space(quality_high)
	else:
		_build_environment(quality_high)
		_build_bridge()
		_build_sea()


func _process(delta: float) -> void:
	if _drifters.is_empty():
		return
	_t = fmod(_t + delta, TAU * 100.0)
	# One buffer upload per drifting MultiMesh per frame.
	for dr: Dictionary in _drifters:
		var items: Array = dr["items"]
		var cols: PackedColorArray = dr.get("colors", PackedColorArray())
		var stride := 16 if not cols.is_empty() else 12
		var buf := PackedFloat32Array()
		buf.resize(items.size() * stride)
		var i := 0
		var k := 0
		for a: Dictionary in items:
			var b := Basis(a["axis"], _t * float(a["speed"]) + float(a["phase"])).scaled(a["scale"])
			var p: Vector3 = a["pos"]
			p.y += sin(_t * 0.5 + float(a["phase"])) * float(a.get("bob", 0.4))
			buf[i] = b.x.x
			buf[i + 1] = b.y.x
			buf[i + 2] = b.z.x
			buf[i + 3] = p.x
			buf[i + 4] = b.x.y
			buf[i + 5] = b.y.y
			buf[i + 6] = b.z.y
			buf[i + 7] = p.y
			buf[i + 8] = b.x.z
			buf[i + 9] = b.y.z
			buf[i + 10] = b.z.z
			buf[i + 11] = p.z
			if stride == 16:
				var c := cols[k]
				buf[i + 12] = c.r
				buf[i + 13] = c.g
				buf[i + 14] = c.b
				buf[i + 15] = c.a
			i += stride
			k += 1
		(dr["mm"] as MultiMesh).buffer = buf


func _look(key: String) -> Variant:
	return world.get(key, SPACE_LOOK.get(key))


# ------------------------------------------------------------------ sculpted worlds

func _build_world_environment(quality_high: bool) -> void:
	var env := Environment.new()
	environment = env
	var sky := Sky.new()
	if str(world.get("scenery", "")) == "space":
		var sm := ShaderMaterial.new()
		sm.shader = SKY_SHADER
		sm.set_shader_parameter("panorama", load(str(world["sky"])))
		sm.set_shader_parameter("noise_tex", NOISE_TEX)
		sm.set_shader_parameter("energy", float(world.get("sky_energy", 1.0)))
		for k in ["neb_a", "neb_b", "neb_c", "deep"]:
			if world.has(k):
				sm.set_shader_parameter(k, world[k])
		sky.sky_material = sm
	else:
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = load(str(world["sky"]))
		sky_mat.energy_multiplier = float(world.get("sky_energy", 1.0))
		sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = world.get("ambient", Color(0.5, 0.5, 0.6))
	env.ambient_light_energy = float(world.get("ambient_energy", 0.8))
	# Linear keeps the gold and white of the army crisp and saturated: in gl_compatibility,
	# enabling glow moves tonemapping into a post pass, and Filmic/ACES/AgX there wash the
	# whites grey (compared on screenshots). Glow still blooms everything above the threshold
	# (emissive crystals, projectiles, beams); the lit road and units stay below it.
	env.tonemap_mode = int(_look("tonemap")) as Environment.ToneMapper
	env.tonemap_exposure = float(_look("exposure"))
	env.tonemap_white = 6.0
	env.glow_enabled = quality_high
	env.glow_hdr_threshold = float(_look("glow_threshold"))
	env.glow_hdr_scale = 2.0
	env.glow_intensity = float(_look("glow_intensity"))
	env.glow_strength = 1.0
	env.glow_bloom = float(_look("glow_bloom"))
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for lv in 7:
		env.set_glow_level(lv, 1.0 if lv in [1, 2, 3, 4] else 0.0)
	# Depth haze: the far road melts into a violet nebula instead of ending in a hard line.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _look("fog_color")
	env.fog_light_energy = 1.0
	env.fog_density = float(_look("fog_max"))
	env.fog_depth_begin = float(_look("fog_begin"))
	env.fog_depth_end = float(_look("fog_end"))
	env.fog_depth_curve = 1.25
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = float(world.get("sun_energy", 1.0))
	sun.light_color = world.get("sun", Color.WHITE)
	sun.shadow_enabled = quality_high
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.05
	add_child(sun)
	# A cool violet rim light from ahead outlines units and models against the road.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 165, 0)
	rim.light_color = _look("rim_light")
	rim.light_energy = float(_look("rim_energy"))
	rim.light_specular = 0.6
	rim.shadow_enabled = false
	add_child(rim)


## Repeats the world's road module from behind the start to past the finish. The walkway is
## scaled to the game's lane width and its surface put at y = 0. Modules butt together on the
## walkway top (measured from the mesh), so no seam gaps show between them.
func _build_road() -> void:
	var fit: Dictionary = world["road_fit"]
	var scene := load(str(world["road"])) as PackedScene
	var inst := scene.instantiate() as Node3D
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	var local := _relative_xf(inst, mi)
	var mat := mi.get_active_material(0)
	inst.free()
	var walk := float(fit["walk_max"]) - float(fit["walk_min"])
	var s := Balance.BRIDGE_HALF * 2.0 / walk
	var sy := s * float(fit.get("vscale", 1.0))
	var span := _walk_span(mesh, local, fit)
	var seg := span.y * s * 0.998
	var count := ceili((length + BEHIND + BEYOND) / seg) + 1
	var basis := Basis(Vector3(0, 0, -s), Vector3(0, sy, 0), Vector3(s, 0, 0))
	var centre := (float(fit["walk_min"]) + float(fit["walk_max"])) * 0.5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var z0 := BEHIND - i * seg
		var origin := Vector3(-centre * s, -float(fit["top"]) * sy, z0 + s * span.x)
		mm.set_instance_transform(i, Transform3D(basis, origin) * local)
	var road := MultiMeshInstance3D.new()
	road.name = "Road"
	road.multimesh = mm
	if mat is StandardMaterial3D:
		var src := mat as StandardMaterial3D
		var m := ShaderMaterial.new()
		m.shader = ROAD_SHADER
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("noise_tex", NOISE_TEX)
		m.set_shader_parameter("tint", world.get("road_tint", Color.WHITE))
		m.set_shader_parameter("saturation", float(_look("road_saturation")))
		m.set_shader_parameter("brightness", float(_look("road_brightness")))
		m.set_shader_parameter("contrast", float(_look("road_contrast")))
		m.set_shader_parameter("vein_glow", float(_look("vein_glow")))
		m.set_shader_parameter("normal_depth", 1.0 if src.normal_enabled else 0.0)
		road.material_override = m
	add_child(road)


## The module's walkway top along its length axis: (start, length) in module units. Falls
## back to the world's road_fit when the mesh cannot be read.
static func _walk_span(mesh: Mesh, local: Transform3D, fit: Dictionary) -> Vector2:
	var fallback := Vector2(float(fit["x_min"]), float(fit["length"]))
	if mesh == null or mesh.get_surface_count() == 0:
		return fallback
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var top := float(fit["top"])
	var w0 := float(fit["walk_min"]) + 0.05
	var w1 := float(fit["walk_max"]) - 0.05
	var lo := INF
	var hi := -INF
	for v in verts:
		var p := local * v
		if p.y > top - 0.04 and p.z > w0 and p.z < w1:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	if hi - lo < fallback.y * 0.5:
		return fallback
	return Vector2(lo, hi - lo)


static func _relative_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf



# ------------------------------------------------------------------ space scenery

## Space: ringed planets far below, distant stations with lit windows, crystal clusters on
## the road's flanks, drifting asteroids with glowing crystals and twinkling dust.
func _build_space(quality_high: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length) * 31 + 7
	var span := length + BEHIND + BEYOND
	var planets := [
		{"pos": Vector3(-100, -78, -length * 0.42), "r": 40.0, "a": Color(0.36, 0.16, 0.62), "b": Color(0.95, 0.5, 0.85), "rim": Color(1.0, 0.6, 0.95), "ring": true, "bands": 7.0},
		{"pos": Vector3(92, -34, -length * 0.88 - 40), "r": 24.0, "a": Color(0.06, 0.25, 0.55), "b": Color(0.35, 0.85, 1.0), "rim": Color(0.55, 0.9, 1.0), "ring": false, "bands": 5.0},
		{"pos": Vector3(58, -78, -length * 0.12), "r": 16.0, "a": Color(0.55, 0.25, 0.12), "b": Color(1.0, 0.76, 0.42), "rim": Color(1.0, 0.85, 0.6), "ring": false, "bands": 9.0},
		{"pos": Vector3(-36, -44, -length * 0.42 + 46), "r": 5.0, "a": Color(0.5, 0.5, 0.6), "b": Color(0.85, 0.85, 0.95), "rim": Color(0.8, 0.85, 1.0), "ring": false, "bands": 3.0},
	]
	for pl: Dictionary in planets:
		_planet(pl)
	# Stations drift past on alternating sides.
	var n_st := maxi(2, int(span / 70.0))
	for i in n_st:
		var side := -1.0 if i % 2 == 0 else 1.0
		var st := _station(i % 2)
		st.position = Vector3(side * rng.randf_range(19.0, 27.0), rng.randf_range(-22.0, -13.0), BEHIND - 30.0 - i * span / n_st)
		st.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), rng.randf_range(-10, 10))
		st.scale = Vector3.ONE * rng.randf_range(0.9, 1.25)
		add_child(st)
	_build_flank_crystals(rng, span)
	_build_asteroids(rng, span, quality_high)
	_build_dust(rng, span, quality_high)
	_process(0.0)


## Violet and ice-blue crystal clusters growing out of the road's sides below the railing.
func _build_flank_crystals(rng: RandomNumberGenerator, span: float) -> void:
	var mesh := WeaponModels.merge(_cluster_shape(rng, 7))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var step := 9.0
	var n := int(span / step) * 2
	mm.instance_count = n
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := BEHIND - (i / 2) * step - rng.randf_range(0.0, step * 0.8)
		var pos := Vector3(side * (Balance.BRIDGE_HALF + rng.randf_range(0.9, 2.2)), rng.randf_range(-2.6, -1.3), z)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, side * rng.randf_range(0.25, 0.7))
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), pos))
		mm.set_instance_color(i, Color(0.72, 0.42, 1.0) if rng.randf() < 0.65 else Color(0.38, 0.8, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FlankCrystals"
	mmi.multimesh = mm
	mmi.material_override = _crystal_material(1.5)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Tumbling rocks with crystals (rock and crystal MultiMeshes share transforms) and loose
## crystal shards on both sides of the road.
func _build_asteroids(rng: RandomNumberGenerator, span: float, quality_high: bool) -> void:
	var rocks: Array[Dictionary] = []
	var shards: Array[Dictionary] = []
	var n := int(span / (2.4 if quality_high else 4.5))
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var far := rng.randf()
		var pos := Vector3(side * lerpf(Balance.BRIDGE_HALF + 3.5, Balance.BRIDGE_HALF + 26.0, far * far),
			rng.randf_range(-12.0, 2.0) - far * 6.0, BEHIND - rng.randf_range(0.0, span))
		var sc := rng.randf_range(0.5, 1.6) * (1.0 + far * 1.4)
		var a := {"pos": pos, "axis": Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(),
			"speed": rng.randf_range(0.08, 0.4), "phase": rng.randf() * TAU,
			"scale": Vector3(sc, sc * rng.randf_range(0.7, 1.2), sc), "bob": rng.randf_range(0.2, 0.6)}
		if rng.randf() < 0.3:
			a["scale"] = Vector3.ONE * sc * 0.7
			a["speed"] = rng.randf_range(0.3, 0.8)
			shards.append(a)
		else:
			rocks.append(a)
	var rock_mm := _drifter(rocks, WeaponModels.merge(_rock_shape()), Mats.vertex_colored(0.85), false)
	var crys_mm := _drifter(rocks, WeaponModels.merge(_rock_crystals()), _crystal_material(1.7), true)
	var shard_mm := _drifter(shards, WeaponModels.merge(_cluster_shape(rng, 3)), _crystal_material(1.9), true)
	_drifters.append({"mm": rock_mm, "items": rocks})
	_drifters.append({"mm": crys_mm, "items": rocks, "colors": _crystal_colors(rocks.size())})
	_drifters.append({"mm": shard_mm, "items": shards, "colors": _crystal_colors(shards.size())})


static func _crystal_colors(n: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(n)
	for i in n:
		out[i] = Color(0.75, 0.45, 1.0) if (i * 7) % 5 < 3 else Color(0.4, 0.85, 1.0)
	return out


func _drifter(items: Array[Dictionary], mesh: Mesh, mat: Material, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = items.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Twinkling dust and far glints around the road (static, one MultiMesh).
func _build_dust(rng: RandomNumberGenerator, span: float, quality_high: bool) -> void:
	var n := int(span * (2.6 if quality_high else 1.2))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Mats.quad(Vector2(1, 1), false)
	mm.instance_count = n
	var cols := [Color(0.6, 0.8, 1.0), Color(0.8, 0.6, 1.0), Color(1.0, 0.95, 0.9), Color(1.0, 0.6, 0.85)]
	for i in n:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var far := rng.randf()
		var pos := Vector3(side * lerpf(Balance.BRIDGE_HALF + 1.5, 45.0, far * far), rng.randf_range(-28.0, 4.0) * (0.4 + far),
			BEHIND - rng.randf_range(0.0, span))
		var sc := rng.randf_range(0.12, 0.35) * (1.0 + far * 3.0)
		if rng.randf() < 0.06:
			sc *= 3.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), pos))
		var c: Color = cols[rng.randi() % cols.size()]
		mm.set_instance_color(i, c * rng.randf_range(0.5, 1.0))
	var sm := ShaderMaterial.new()
	sm.shader = DUST_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Dust"
	mmi.multimesh = mm
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _crystal_material(energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CRYSTAL_SHADER
	m.set_shader_parameter("energy", energy)
	return m


func _rock_shape() -> Node3D:
	var r := Node3D.new()
	Mats.part(r, Mats.sphere(0.5, 0.8, 7, 4), Mats.solid(Color(0.36, 0.31, 0.5)), Vector3.ZERO, Vector3(0, 0, 15))
	Mats.part(r, Mats.sphere(0.34, 0.52, 6, 3), Mats.solid(Color(0.3, 0.26, 0.44)), Vector3(0.3, 0.12, 0.12), Vector3(20, 40, 0))
	Mats.part(r, Mats.sphere(0.24, 0.36, 5, 3), Mats.solid(Color(0.42, 0.37, 0.58)), Vector3(-0.28, -0.1, -0.15), Vector3(0, 70, 30))
	return r


## The crystals growing on _rock_shape (same local space).
func _rock_crystals() -> Node3D:
	var r := Node3D.new()
	var w := Mats.solid(Color.WHITE)
	Mats.part(r, Mats.crystal(0.13, 0.7), w, Vector3(-0.08, 0.5, 0.05), Vector3(0, 0, -20))
	Mats.part(r, Mats.crystal(0.09, 0.46), w, Vector3(0.16, 0.42, -0.1), Vector3(15, 0, 25))
	Mats.part(r, Mats.crystal(0.07, 0.34), w, Vector3(-0.3, 0.3, -0.12), Vector3(-10, 0, -45))
	return r


## A cluster of `n` hexagonal crystals fanning out of one base, white (tinted per instance).
func _cluster_shape(rng: RandomNumberGenerator, n: int) -> Node3D:
	var r := Node3D.new()
	var w := Mats.solid(Color.WHITE)
	for i in n:
		var h := rng.randf_range(0.7, 1.6) * (1.3 if i == 0 else 1.0)
		var rad := h * rng.randf_range(0.14, 0.2)
		var tilt := Vector3(rng.randf_range(-35, 35), rng.randf() * 360.0, rng.randf_range(-35, 35)) if i > 0 else Vector3.ZERO
		var c := MeshInstance3D.new()
		c.mesh = Mats.cyl(rad * 0.75, rad, h * 0.62, 6)
		c.material_override = w
		var piv := Node3D.new()
		piv.rotation_degrees = tilt
		piv.position = Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		r.add_child(piv)
		c.position = Vector3(0, h * 0.31, 0)
		piv.add_child(c)
		Mats.part(piv, Mats.cone(rad * 0.75, h * 0.38, 6), w, Vector3(0, h * 0.62 + h * 0.19, 0))
	return r


## A distant station: 0 = a ring station on a spindle, 1 = a spire with docking arms.
## White hull, dark steel, gold trim and lit ice-blue windows (bloom in the haze).
func _station(kind: int) -> Node3D:
	var root := Node3D.new()
	var hull := Mats.solid(Color(0.82, 0.84, 0.92), 0.5, 0.3)
	var steel := Mats.solid(Color(0.22, 0.25, 0.36), 0.5, 0.5)
	var gold := Mats.solid(Color(1.0, 0.78, 0.35), 0.35, 0.7)
	var win := Mats.glow(Color(0.45, 0.85, 1.0), 3.0)
	var warm := Mats.glow(Color(1.0, 0.75, 0.4), 3.0)
	if kind == 0:
		Mats.part(root, Mats.torus(4.2, 5.0, 28, 6), hull, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
		Mats.part(root, Mats.torus(4.95, 5.12, 28, 4), gold, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
		for k in 14:
			var a := TAU * k / 14.0
			Mats.part(root, Mats.box(Vector3(0.5, 0.22, 0.12)), win, Vector3(cos(a) * 4.6, sin(a) * 4.6, 0.42), Vector3(0, 0, rad_to_deg(a) + 90.0), Vector3.ONE, false)
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			Mats.part(root, Mats.box(Vector3(0.28, 4.2, 0.28)), steel, Vector3(cos(a) * 2.2, sin(a) * 2.2, 0), Vector3(0, 0, rad_to_deg(a) - 90.0), Vector3.ONE, false)
		Mats.part(root, Mats.cyl(1.1, 1.1, 2.0, 12), hull, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
		Mats.part(root, Mats.cyl(0.5, 0.5, 9.0, 8), steel, Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
		Mats.part(root, Mats.cyl(1.25, 1.25, 0.25, 12), gold, Vector3(0, 0, 0.9), Vector3(90, 0, 0), Vector3.ONE, false)
		Mats.part(root, Mats.sphere(0.6, -1, 10, 6), win, Vector3(0, 0, 1.15), Vector3.ZERO, Vector3.ONE, false)
		for z: float in [-4.6, 4.6]:
			Mats.part(root, Mats.box(Vector3(3.6, 0.1, 1.2)), steel, Vector3(0, 0, z), Vector3.ZERO, Vector3.ONE, false)
			Mats.part(root, Mats.sphere(0.22, -1, 6, 4), warm, Vector3(1.9, 0, z), Vector3.ZERO, Vector3.ONE, false)
			Mats.part(root, Mats.sphere(0.22, -1, 6, 4), win, Vector3(-1.9, 0, z), Vector3.ZERO, Vector3.ONE, false)
	else:
		Mats.part(root, Mats.cyl(0.9, 1.5, 7.0, 10), hull, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(root, Mats.cyl(0.15, 0.9, 3.5, 10), hull, Vector3(0, 5.25, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(root, Mats.cyl(1.5, 0.6, 2.4, 10), steel, Vector3(0, -4.7, 0), Vector3.ZERO, Vector3.ONE, false)
		for y: float in [-2.2, 0.4, 3.0]:
			Mats.part(root, Mats.cyl(1.55 - y * 0.06, 1.55 - y * 0.06, 0.22, 12), gold, Vector3(0, y, 0), Vector3.ZERO, Vector3.ONE, false)
			for k in 8:
				var a := TAU * k / 8.0
				var rr := 1.3 - y * 0.06
				Mats.part(root, Mats.box(Vector3(0.28, 0.5, 0.1)), win if k % 3 != 0 else warm, Vector3(cos(a) * rr, y + 0.6, sin(a) * rr), Vector3(0, -rad_to_deg(a) + 90.0, 0), Vector3.ONE, false)
		for k in 3:
			var a := TAU * k / 3.0
			var dir := Vector3(cos(a), 0, sin(a))
			Mats.part(root, Mats.box(Vector3(3.6, 0.3, 0.3)), steel, dir * 2.6 + Vector3(0, -1.0, 0), Vector3(0, -rad_to_deg(a), 0), Vector3.ONE, false)
			Mats.part(root, Mats.box(Vector3(1.1, 1.1, 0.7)), hull, dir * 4.4 + Vector3(0, -1.0, 0), Vector3(0, -rad_to_deg(a), 0), Vector3.ONE, false)
			Mats.part(root, Mats.box(Vector3(0.12, 0.6, 0.72)), win, dir * 4.97 + Vector3(0, -1.0, 0), Vector3(0, -rad_to_deg(a), 0), Vector3.ONE, false)
		Mats.part(root, Mats.sphere(0.35, -1, 8, 5), warm, Vector3(0, 7.1, 0), Vector3.ZERO, Vector3.ONE, false)
	Mats.bake(root)
	return root


func _planet(pl: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = float(pl["r"])
	sphere.height = float(pl["r"]) * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mi.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = PLANET_SHADER
	mat.set_shader_parameter("col_a", pl["a"])
	mat.set_shader_parameter("col_b", pl["b"])
	mat.set_shader_parameter("rim_col", pl["rim"])
	mat.set_shader_parameter("band_scale", pl["bands"])
	mat.set_shader_parameter("noise_tex", NOISE_TEX)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pl["pos"]
	mi.rotation_degrees = Vector3(0, 0, 14)
	add_child(mi)
	if pl["ring"]:
		var ring := MeshInstance3D.new()
		var q := PlaneMesh.new()
		var outer := float(pl["r"]) * 2.1
		q.size = Vector2(outer * 2.0, outer * 2.0)
		ring.mesh = q
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", (pl["b"] as Color).lightened(0.15))
		rm.set_shader_parameter("color_b", (pl["a"] as Color).lightened(0.3))
		rm.set_shader_parameter("noise_tex", NOISE_TEX)
		rm.set_shader_parameter("inner", 0.64)
		rm.set_shader_parameter("alpha", 0.5)
		ring.material_override = rm
		ring.rotation_degrees = Vector3(16, 0, 14)
		ring.position = pl["pos"]
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


# ------------------------------------------------------------------ stone bridge (fallback)

func _build_environment(quality_high: bool) -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.56, 0.92)
	sky_mat.sky_horizon_color = Color(0.72, 0.85, 0.98)
	sky_mat.ground_horizon_color = Color(0.6, 0.78, 0.95)
	sky_mat.ground_bottom_color = Color(0.2, 0.42, 0.75)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = quality_high
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.84, 0.97)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = quality_high
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.05
	add_child(sun)


func _build_bridge() -> void:
	var start := 25.0                       # the bridge begins behind the start line
	var total := length + start + 30.0
	var mid := -(length - start) * 0.5 + 15.0
	# Walkway: one long slab with tiled paving on top.
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = FLOOR_TEX
	floor_mat.uv1_scale = Vector3(2.0, total / 3.6, 1.0)
	floor_mat.roughness = 0.95
	floor_mat.albedo_color = Color(0.86, 0.8, 0.72)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Balance.BRIDGE_HALF * 2.0, total)
	top.mesh = plane
	top.material_override = floor_mat
	top.position = Vector3(0, 0, mid)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(top)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = WALL_TEX
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_world_triplanar = true
	wall_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	wall_mat.roughness = 0.95
	wall_mat.albedo_color = Color(0.8, 0.74, 0.68)
	# Bridge body down to the sea.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Balance.BRIDGE_HALF * 2.0 + 0.6, -SEA_Y + 1.0, total)
	body.mesh = bm
	body.material_override = wall_mat
	body.position = Vector3(0, (SEA_Y - 1.0) * 0.5 - 0.02, mid)
	add_child(body)
	# Parapets with merlons on both sides.
	var merlon := Mats.box(Vector3(0.55, 0.55, 0.85))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = merlon
	var step := 1.6
	var per_side := int(total / step)
	mm.instance_count = per_side * 2
	var z0 := mid + total * 0.5
	for i in per_side:
		for s in 2:
			var x := (Balance.BRIDGE_HALF + 0.05) * (-1.0 if s == 0 else 1.0)
			mm.set_instance_transform(i * 2 + s, Transform3D(Basis.IDENTITY, Vector3(x, WALL_H + 0.27, z0 - i * step - 0.4)))
	var merlons := MultiMeshInstance3D.new()
	merlons.multimesh = mm
	merlons.material_override = wall_mat
	add_child(merlons)
	for s in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.6, WALL_H, total)
		rail.mesh = rm
		rail.material_override = wall_mat
		rail.position = Vector3((Balance.BRIDGE_HALF + 0.05) * s, WALL_H * 0.5, mid)
		add_child(rail)
	# Buttress piers along the sides, every 12 units.
	var pier := MultiMesh.new()
	pier.transform_format = MultiMesh.TRANSFORM_3D
	pier.mesh = Mats.box(Vector3(1.0, -SEA_Y + 0.6, 1.6))
	var piers := int(total / 12.0)
	pier.instance_count = piers * 2
	for i in piers:
		for s in 2:
			var x := (Balance.BRIDGE_HALF + 0.65) * (-1.0 if s == 0 else 1.0)
			pier.set_instance_transform(i * 2 + s, Transform3D(Basis.IDENTITY, Vector3(x, (SEA_Y + 0.6) * 0.5 - 0.3, z0 - i * 12.0 - 6.0)))
	var pi := MultiMeshInstance3D.new()
	pi.multimesh = pier
	pi.material_override = wall_mat
	add_child(pi)


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, length + 200)
	sea.mesh = plane
	sea.position = Vector3(0, SEA_Y, -length * 0.5)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
// Waves from a tiled noise texture (no per-pixel sin() noise: phones render that as squares).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.1, 0.36, 0.72, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.6, 0.9, 1.0);
uniform vec4 foam : source_color = vec4(0.85, 0.94, 1.0, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float t = mod(TIME, 400.0);
	vec2 uv = wpos.xz * 0.035;
	float a = texture(noise_tex, uv + vec2(t * 0.01, t * 0.004)).r;
	float b = texture(noise_tex, uv * 2.3 - vec2(t * 0.006, t * 0.012)).r;
	float n = a * 0.6 + b * 0.4;
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.35, 0.7, n));
	float crest = smoothstep(0.66, 0.74, b * 0.7 + a * 0.3);
	col = mix(col, foam.rgb, crest * 0.55);
	ALBEDO = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("noise_tex", NOISE_TEX)
	sea.material_override = mat
	add_child(sea)
