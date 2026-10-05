class_name Track
extends Node3D
## The road a run takes place on, with its sky, light and scenery. A world with a sculpted
## road module (see Worlds) repeats it along the run; otherwise a stone bridge over the sea
## is built procedurally.
## Distance along the run is `d`; the world position is z = -d (the run heads to -Z).

const FLOOR_TEX := preload("res://assets/textures/stone_floor.png")
const WALL_TEX := preload("res://assets/textures/wall_stone.png")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const SEA_Y := -5.0
const WALL_H := 0.55
const BEHIND := 25.0            # road shown behind the start line
const BEYOND := 30.0            # road shown past the finish

var length := 100.0
var world: Dictionary = {}
var sun: DirectionalLight3D
var _spinners: MultiMeshInstance3D
var _spin: Array[Dictionary] = []
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
	if _spinners == null:
		return
	_t += delta
	for i in _spin.size():
		var a: Dictionary = _spin[i]
		var b := Basis(a["axis"], _t * float(a["speed"]) + float(a["phase"])).scaled(a["scale"])
		var p: Vector3 = a["pos"]
		_spinners.multimesh.set_instance_transform(i, Transform3D(b, p + Vector3(0, sin(_t * 0.5 + float(a["phase"])) * 0.4, 0)))


# ------------------------------------------------------------------ sculpted worlds

func _build_world_environment(quality_high: bool) -> void:
	var env := Environment.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load(str(world["sky"]))
	sky_mat.energy_multiplier = float(world.get("sky_energy", 1.0))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = world.get("ambient", Color(0.5, 0.5, 0.6))
	env.ambient_light_energy = float(world.get("ambient_energy", 0.8))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = quality_high
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
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


## Repeats the world's road module from behind the start to past the finish. The walkway is
## scaled to the game's lane width and its surface put at y = 0.
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
	var seg := float(fit["length"]) * s * 0.995
	var count := ceili((length + BEHIND + BEYOND) / seg) + 1
	var basis := Basis(Vector3(0, 0, -s), Vector3(0, sy, 0), Vector3(s, 0, 0))
	var centre := (float(fit["walk_min"]) + float(fit["walk_max"])) * 0.5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var z0 := BEHIND - i * seg
		var origin := Vector3(-centre * s, -float(fit["top"]) * sy, z0 + s * float(fit["x_min"]))
		mm.set_instance_transform(i, Transform3D(basis, origin) * local)
	var road := MultiMeshInstance3D.new()
	road.name = "Road"
	road.multimesh = mm
	if mat is StandardMaterial3D:
		var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.metallic = 0.0
		m.roughness = 0.75
		m.metallic_specular = 0.3
		m.albedo_color = world.get("road_tint", Color.WHITE)
		road.material_override = m
	add_child(road)


static func _relative_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Space: distant planets below and beside the road, and tumbling asteroids and crystals.
func _build_space(quality_high: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length) * 31 + 7
	var planets := [
		{"pos": Vector3(-70, -55, -length * 0.45), "r": 34.0, "a": Color(0.45, 0.2, 0.7), "b": Color(0.95, 0.45, 0.8), "ring": true},
		{"pos": Vector3(85, -30, -length * 0.9 - 40), "r": 22.0, "a": Color(0.1, 0.35, 0.6), "b": Color(0.4, 0.9, 1.0), "ring": false},
		{"pos": Vector3(60, -80, -length * 0.15), "r": 18.0, "a": Color(0.6, 0.3, 0.15), "b": Color(1.0, 0.75, 0.4), "ring": false},
	]
	for pl: Dictionary in planets:
		_planet(pl)
	# Tumbling asteroids and crystal shards along both sides.
	var rock := Models.merge(_rock_shape())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	var n := int((length + BEHIND + BEYOND) / (3.0 if quality_high else 5.0))
	mm.instance_count = n
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(Balance.BRIDGE_HALF + 3.0, Balance.BRIDGE_HALF + 22.0),
			rng.randf_range(-9.0, 2.5), BEHIND - rng.randf_range(0.0, length + BEHIND + BEYOND))
		var sc := rng.randf_range(0.5, 2.6)
		_spin.append({"pos": pos, "axis": Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized(),
			"speed": rng.randf_range(0.1, 0.5), "phase": rng.randf() * TAU, "scale": Vector3(sc, sc * rng.randf_range(0.7, 1.2), sc)})
	_spinners = MultiMeshInstance3D.new()
	_spinners.multimesh = mm
	_spinners.material_override = Models.vertex_material()
	_spinners.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spinners)
	_process(0.0)


func _rock_shape() -> Node3D:
	var r := Node3D.new()
	Mats.part(r, Mats.sphere(0.5, 0.8, 6, 4), Mats.solid(Color(0.42, 0.36, 0.55)), Vector3.ZERO, Vector3(0, 0, 15))
	Mats.part(r, Mats.sphere(0.32, 0.5, 5, 3), Mats.solid(Color(0.35, 0.3, 0.48)), Vector3(0.3, 0.15, 0.1))
	Mats.part(r, Mats.crystal(0.12, 0.6), Mats.glow(Color(0.75, 0.4, 1.0), 1.2), Vector3(-0.1, 0.45, 0.05), Vector3(0, 0, -20))
	Mats.part(r, Mats.crystal(0.08, 0.4), Mats.glow(Color(0.4, 0.85, 1.0), 1.2), Vector3(0.15, 0.4, -0.1), Vector3(15, 0, 25))
	return r


func _planet(pl: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = float(pl["r"])
	sphere.height = float(pl["r"]) * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	mi.mesh = sphere
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 col_a : source_color;
uniform vec4 col_b : source_color;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
void fragment() {
	// Banded gas giant lit from the upper left, with a soft atmosphere at the rim.
	float bands = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 6.0)).r;
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.3, 0.75, bands * 0.6 + UV.y * 0.5));
	float lit = clamp(dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.6))) * 0.7 + 0.45, 0.15, 1.1);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = c * lit + col_b.rgb * rim * 0.6;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("col_a", pl["a"])
	mat.set_shader_parameter("col_b", pl["b"])
	mat.set_shader_parameter("noise_tex", NOISE_TEX)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pl["pos"]
	add_child(mi)
	if pl["ring"]:
		var ring := MeshInstance3D.new()
		ring.mesh = Mats.torus(float(pl["r"]) * 1.35, float(pl["r"]) * 1.9, 48, 3)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color = Color((pl["b"] as Color).r, (pl["b"] as Color).g, (pl["b"] as Color).b, 0.45)
		ring.material_override = rm
		ring.scale = Vector3(1, 0.04, 1)
		ring.rotation_degrees = Vector3(18, 0, 12)
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
