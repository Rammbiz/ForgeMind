class_name Arena
## Optional sculpted arena model (Meshy GLB) that replaces the procedural island of a level.
##
## Each arena lives in res://assets/models/arenas/<level id>.glb with a fit file
## <level id>.json written by tools/fit_arena.gd:
##   "xf"      12 floats: basis columns x, y, z and origin (model space -> map space)
##   "heights" rows of surface heights per grid cell (same size as the level map)
##   "keep"    procedural parts that stay visible on top of the model
##             ("decor", "water", "portal_base", "crystal_base", "clouds")

const DIR := "res://assets/models/arenas/"


## Returns the parsed fit for a level, or an empty dictionary when the level has no arena model.
static func load_fit(level_id: String) -> Dictionary:
	if not Save.arena_models:
		return {}
	var json_path := DIR + level_id + ".json"
	var glb_path := DIR + level_id + ".glb"
	if not FileAccess.file_exists(json_path) or not ResourceLoader.exists(glb_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("xf"):
		push_warning("Arena fit %s is invalid" % json_path)
		return {}
	data["glb"] = glb_path
	return data


static func transform_of(fit: Dictionary) -> Transform3D:
	var f: Array = fit["xf"]
	return Transform3D(
		Basis(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8])),
		Vector3(f[9], f[10], f[11]))


## Surface height of a cell, or `fallback` when the fit has no sample for it.
static func height_at(fit: Dictionary, c: Vector2i, fallback: float) -> float:
	var rows: Array = fit.get("heights", [])
	if c.y < 0 or c.y >= rows.size():
		return fallback
	var row: Array = rows[c.y]
	if c.x < 0 or c.x >= row.size() or row[c.x] == null:
		return fallback
	return float(row[c.x])


static func keeps(fit: Dictionary, part: String) -> bool:
	return part in fit.get("keep", [])


## Instantiates the arena model in map space, tuned for the compatibility renderer.
static func instantiate(fit: Dictionary, quality_high: bool) -> Node3D:
	var scene := load(str(fit["glb"])) as PackedScene
	var model := scene.instantiate() as Node3D
	var root := Node3D.new()
	root.name = "Arena"
	root.add_child(model)
	model.transform = transform_of(fit)
	_tune(model, quality_high, fit)
	return root


static func _tune(n: Node, quality_high: bool, fit: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality_high else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			if src is StandardMaterial3D:
				mi.set_surface_override_material(s, _material(src as StandardMaterial3D, quality_high, fit))
	for ch in n.get_children():
		_tune(ch, quality_high, fit)


static var _mat_cache := {}


## Meshy's PBR output is tuned for physically based viewers; the game uses a linear
## tonemapper and a strong sun, so keep the painted albedo and soften the specular.
static func _material(src: StandardMaterial3D, quality_high: bool, fit: Dictionary) -> StandardMaterial3D:
	var key := [src, quality_high]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := src.duplicate() as StandardMaterial3D
	m.albedo_color = m.albedo_color * Color(fit.get("tint", "ffffff"))
	m.metallic = minf(m.metallic, float(fit.get("max_metallic", 0.2)))
	m.metallic_specular = float(fit.get("specular", 0.3))
	if not quality_high:
		m.normal_enabled = false
		m.roughness_texture = null
		m.metallic_texture = null
	if m.albedo_texture == null:
		# Untextured export: colours live in the vertex colours.
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_mat_cache[key] = m
	return m


static func clear_cache() -> void:
	_mat_cache.clear()
