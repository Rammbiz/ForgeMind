class_name WorldEnv
## Builds the sky / fog / glow environment and sun for a level theme.


static func make_environment(theme: Dictionary, quality_high: bool) -> WorldEnvironment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
	sky_mat.ground_horizon_color = theme["ground_horizon"]
	sky_mat.ground_bottom_color = theme["ground_bottom"]
	sky_mat.sky_curve = 0.12
	sky_mat.ground_curve = float(theme.get("ground_curve", 0.5))
	sky_mat.sun_angle_max = 20.0
	_dev_override(sky_mat, "CB_SKY")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme["ambient"]
	env.ambient_light_energy = float(theme["ambient_energy"])
	# Linear keeps the stylized palette vivid; lighting is tuned so lit albedo stays below 1.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = float(theme.get("exposure", 1.0))
	env.glow_enabled = quality_high
	env.glow_intensity = 0.4
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set("glow_levels/1", 0.0)
	env.set("glow_levels/2", 0.6)
	env.set("glow_levels/3", 0.9)
	env.set("glow_levels/4", 0.5)
	env.set("glow_levels/5", 0.2)
	env.fog_enabled = true
	env.fog_light_color = theme["fog"]
	env.fog_density = float(theme["fog_density"])
	env.fog_sky_affect = 0.0
	env.fog_height = -2.0
	env.fog_height_density = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	_dev_override(env, "CB_ENV")
	var we := WorldEnvironment.new()
	we.environment = env
	return we


## Dev hook: CB_ENV="prop=value;prop=value" tweaks the environment without code edits.
static func _dev_override(obj: Object, var_name: String) -> void:
	var spec := OS.get_environment(var_name)
	if spec == "":
		return
	for pair in spec.split(";", false):
		var kv := pair.split("=")
		if kv.size() == 2:
			obj.set(kv[0].strip_edges(), str_to_var(kv[1].strip_edges()))


static func make_sun(theme: Dictionary, quality_high: bool) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = theme["sun_rot"]
	sun.light_color = theme["sun_color"]
	sun.light_energy = float(theme["sun_energy"])
	sun.shadow_enabled = quality_high
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_opacity = 0.75
	_dev_override(sun, "CB_SUN")
	return sun
