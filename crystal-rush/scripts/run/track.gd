class_name Track
extends Node3D
## The long stone bridge over the sea that a run takes place on, with sky and light.
## Distance along the run is `d`; the world position is z = -d (the run heads to -Z).

const FLOOR_TEX := preload("res://assets/textures/stone_floor.png")
const WALL_TEX := preload("res://assets/textures/wall_stone.png")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const SEA_Y := -5.0
const WALL_H := 0.55

var length := 100.0
var sun: DirectionalLight3D


func build(p_length: float, quality_high: bool) -> void:
	length = p_length
	_build_environment(quality_high)
	_build_bridge()
	_build_sea()


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
