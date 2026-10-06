class_name Models
## Procedural models for the runner, styled after the space world's crystal road: white-silver
## metal with gold trim and glowing ice-blue crystal on the player's side; dark steel with red
## armour plates and orange glow on the enemy's side. Chunky, layered (bevel-like) shapes that
## read at phone size from the high run camera.
##
## Every builder first tries `asset(key, fit)` (a GLB override listed in the world's "models"
## map) and falls back to the procedural model. Static parts are merged with `Mats.bake` (or
## `merge` for crowd meshes) to keep draw calls low. Models face +Z (towards the army/camera).

const BLUE := Color(0.22, 0.48, 0.95)
const BLUE_DARK := Color(0.12, 0.26, 0.6)
const STEEL := Color(0.78, 0.8, 0.86)
const GOLD := Color(1.0, 0.78, 0.3)
const WOOD := Color(0.58, 0.38, 0.2)
const WOOD_DARK := Color(0.4, 0.25, 0.13)
const IRON := Color(0.3, 0.31, 0.35)
const RED := Color(0.86, 0.16, 0.14)
const RED_DARK := Color(0.5, 0.07, 0.08)
const SKIN := Color(0.98, 0.8, 0.66)
const ORC := Color(0.55, 0.62, 0.3)
# Player side.
const SILVER := Color(0.8, 0.84, 0.94)
const SILVER_SHADE := Color(0.46, 0.52, 0.7)
const ICE := Color(0.45, 0.88, 1.0)
const NAVY := Color(0.13, 0.17, 0.32)
# Enemy side.
const STEEL_DARK := Color(0.17, 0.18, 0.23)
const STEEL_MID := Color(0.28, 0.29, 0.35)
const PLATE := Color(0.72, 0.1, 0.09)
const PLATE_DARK := Color(0.42, 0.05, 0.06)
const BRONZE := Color(0.78, 0.45, 0.18)
const EMBER := Color(1.0, 0.24, 0.02)
const HOT_RED := Color(1.0, 0.1, 0.06)
const VIOLET := Color(0.68, 0.38, 1.0)

## Gate colours per style kind: [field, core/edge highlight, label outline].
const GATE_KINDS := {
	"good": [Color(0.1, 0.42, 1.0), Color(0.75, 0.93, 1.0), Color(0.02, 0.1, 0.36)],
	"bad": [Color(1.0, 0.16, 0.14), Color(1.0, 0.82, 0.7), Color(0.35, 0.02, 0.02)],
	"charge": [Color(0.66, 0.3, 1.0), Color(0.95, 0.85, 1.0), Color(0.2, 0.04, 0.38)],
	"hidden": [Color(0.5, 0.55, 0.68), Color(0.9, 0.92, 1.0), Color(0.1, 0.12, 0.2)],
	"power": [Color(1.0, 0.68, 0.12), Color(1.0, 0.96, 0.75), Color(0.38, 0.18, 0.0)],
	"arm": [Color(0.08, 0.85, 0.72), Color(0.8, 1.0, 0.95), Color(0.0, 0.25, 0.22)],
	"closed": [Color(0.38, 0.4, 0.48), Color(0.6, 0.62, 0.7), Color(0.1, 0.1, 0.14)],
}
const REWARD_COLORS := {"army": Color(0.35, 0.8, 1.0), "coins": Color(1.0, 0.76, 0.18), "ult": Color(0.72, 0.36, 1.0)}
const STAIRS_COLORS: Array[Color] = [Color(0.18, 0.5, 1.0), Color(0.58, 0.28, 1.0), Color(1.0, 0.62, 0.1)]

const GATE_H := 2.2
const GATE_ASSET_SHADER := preload("res://shaders/gate_asset.gdshader")
const CRYSTAL_ASSET_SHADER := preload("res://shaders/crystal_asset.gdshader")
const EMBER_ASSET_SHADER := preload("res://shaders/ember_asset.gdshader")
## How far the fortress model reaches past each railing.
const FORTRESS_OVERHANG := 0.75
## The owner's turret GLB: the dome and barrel (above 59.5% of its height) turn on the base;
## its barrel points along -X in the model, so the moving part is turned to face +Z.
const TURRET_SPLIT := 0.595
const TURRET_YAW := PI * 0.5
## Layout of the owner's gate GLB as fractions of its bounding box (measured on the Meshy model):
## pylon centres at 80% of the half width, their inner edges at 60%, the crossbar's underside
## at 75% of the height; the crystal tips are the top. `sxz`/`sy` scale the pylons and the
## height in metres per model unit of the source (1.0 wide, 0.81 tall).
const GATE_ASSET := {"pylon": 0.8, "inner": 0.6, "bar": 0.749, "sxz": 2.2, "sy": 3.2}
const STEP_H := 0.4
const STEP_D := 1.4
const FIELD_SHADER := preload("res://shaders/gate_field.gdshader")
const RING_SHADER := preload("res://shaders/ult_ring.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

static var _meshes := {}
static var _mats := {}
static var _stripes: Texture2D
## World whose "models" map `asset()` reads; empty = the first world.
static var world: Dictionary = {}


# ================================================================== asset overrides

## Switches the GLB override map to `w` (a Worlds.LIST entry) and drops cached crowd meshes.
static func use_world(w: Dictionary) -> void:
	world = w
	_meshes.clear()


static func _models_map() -> Dictionary:
	var w: Dictionary = world if not world.is_empty() else Worlds.LIST[Worlds.ORDER[0]]
	return w.get("models", {})


## Loads the world's GLB override for `key`, scaled uniformly to fit inside `fit` (centred in
## X/Z, resting on fit's bottom). Returns null when the world has no such file, so callers fall
## back to the procedural model.
static func asset(key: String, fit: AABB) -> Node3D:
	var path := str(_models_map().get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	var box := _mesh_aabb(inst)
	var holder := Node3D.new()
	holder.name = "Asset_" + key
	holder.add_child(inst)
	if box.size.length() < 1e-5:
		return holder
	var s := INF
	for i in 3:
		if box.size[i] > 1e-5 and fit.size[i] > 1e-5:
			s = minf(s, fit.size[i] / box.size[i])
	if s == INF:
		s = 1.0
	inst.scale = Vector3.ONE * s
	var c := box.get_center()
	var fc := fit.get_center()
	inst.position = Vector3(fc.x - c.x * s, fit.position.y - box.position.y * s, fc.z - c.z * s)
	return holder


## The world's GLB for `key` fitted like asset() and cut in two at `split` (a fraction of its
## height, by triangle centre): a static "base" and a "top" that turns about its own centre.
## Returns {} when there is no such model, else {base: Node3D, top: MeshInstance3D (centred on
## the pivot), pivot: Vector3, tip: Vector3 (the top's farthest point along -X, relative to the
## pivot, unrotated)}.
static func _split_asset(key: String, fit: AABB, split: float) -> Dictionary:
	var path := str(_models_map().get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var ps := load(path) as PackedScene
	var inst := ps.instantiate() as Node3D if ps else null
	if inst == null:
		return {}
	var box := _mesh_aabb(inst)
	var sc := INF
	for i in 3:
		if box.size[i] > 1e-5 and fit.size[i] > 1e-5:
			sc = minf(sc, fit.size[i] / box.size[i])
	var c := box.get_center()
	var fc := fit.get_center()
	var place := Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3(fc.x - c.x * sc, fit.position.y - box.position.y * sc, fc.z - c.z * sc))
	var cut_y := (box.position.y + box.size.y * split) * sc + place.origin.y
	var parts := [SurfaceTool.new(), SurfaceTool.new()]
	for st in parts:
		(st as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat: Material = null
	var top_pts := PackedVector3Array()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := place * _relative_xf(inst, m)
		for si in m.mesh.get_surface_count():
			if mat == null:
				mat = m.get_active_material(si)
			var arr := m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			for t in range(0, idx.size() - 2, 3):
				var a := xf * verts[idx[t]]
				var b := xf * verts[idx[t + 1]]
				var cc := xf * verts[idx[t + 2]]
				var top := (a.y + b.y + cc.y) / 3.0 > cut_y
				var st := parts[1 if top else 0] as SurfaceTool
				for k in 3:
					var vi := idx[t + k]
					if norms.size() > vi:
						st.set_normal((xf.basis * norms[vi]).normalized())
					if uvs.size() > vi:
						st.set_uv(uvs[vi])
					var p := xf * verts[vi]
					st.add_vertex(p)
					if top:
						top_pts.append(p)
	inst.free()
	if top_pts.is_empty():
		return {}
	var pivot := Vector3.ZERO
	for p in top_pts:
		pivot += p
	pivot /= float(top_pts.size())
	pivot.y = cut_y
	var tip := pivot
	for p in top_pts:
		if p.x < tip.x:
			tip = p
	var base := MeshInstance3D.new()
	base.name = "AssetBase"
	(parts[0] as SurfaceTool).generate_tangents()
	base.mesh = (parts[0] as SurfaceTool).commit()
	base.material_override = mat
	var top_mi := MeshInstance3D.new()
	top_mi.name = "AssetTop"
	var stt := parts[1] as SurfaceTool
	stt.generate_tangents()
	var top_mesh := stt.commit()
	top_mi.mesh = top_mesh
	top_mi.material_override = mat
	# Re-centre the top on the pivot by offsetting its node (the mesh stays in fitted space).
	top_mi.position = -pivot
	var holder := Node3D.new()
	holder.add_child(top_mi)
	return {"base": base, "top": holder, "pivot": pivot, "tip": Vector3(tip.x - pivot.x, tip.y - pivot.y, 0.0)}


## Gives every mesh under an asset `shader` (gate_asset / crystal_asset) with the mesh's own
## albedo and normal textures, so its crystals take `color`.
static func _recolor_asset(node: Node3D, shader: Shader, color: Color) -> void:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var src := m.get_active_material(0) as StandardMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = shader
		if src:
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("normal_tex", src.normal_texture if src.normal_enabled else null)
			mat.set_shader_parameter("has_normal", src.normal_enabled and src.normal_texture != null)
		mat.set_shader_parameter("crystal_color", color)
		m.material_override = mat


## The world's GLB for `key` repeated side by side to span exactly `width` (for long hazards
## like barricades): n = round(width / module) copies, each stretched to width / n, `height`
## tall and `depth` deep, resting on y = 0. Null when the world has no such model.
static func _tiled_asset(key: String, width: float, height: float, depth: float, module: float) -> Node3D:
	var path := str(_models_map().get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var probe := ps.instantiate() as Node3D
	var box := _mesh_aabb(probe)
	probe.free()
	if box.size.x < 1e-5 or box.size.y < 1e-5:
		return null
	var n := maxi(1, roundi(width / module))
	var seg := width / float(n)
	var sc := Vector3(seg / box.size.x, height / box.size.y, depth / maxf(box.size.z, 1e-5))
	var holder := Node3D.new()
	holder.name = "Asset_" + key
	for i in n:
		var inst := ps.instantiate() as Node3D
		inst.scale = sc
		var cx := -width * 0.5 + seg * (float(i) + 0.5)
		inst.position = Vector3(cx - box.get_center().x * sc.x, -box.position.y * sc.y, -box.get_center().z * sc.z)
		holder.add_child(inst)
	return holder


## Bounding box of every mesh under `root`, in root space (works outside the tree).
static func _mesh_aabb(root: Node3D, solid_only := false) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		if solid_only and (m.has_meta("no_bake") or m.material_override is ShaderMaterial or _under(m, "DamageFx", root)):
			continue
		var xf := _relative_xf(root, m)
		var b := xf * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _under(n: Node, ancestor_name: String, stop: Node) -> bool:
	var cur := n.get_parent()
	while cur != null and cur != stop:
		if cur.name == ancestor_name:
			return true
		cur = cur.get_parent()
	return false


static func _relative_xf(root: Node, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## One mesh (with UVs) from a GLB override, scaled to `height` with its feet at y = 0, for
## MultiMesh crowds. Null when there is no override.
static func _asset_mesh(key: String, height: float) -> Mesh:
	var node := asset(key, AABB(Vector3(-height, 0, -height), Vector3(height * 2.0, height, height * 2.0)))
	if node == null:
		return null
	var st := SurfaceTool.new()
	var any := false
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _relative_xf(node, m)
		for si in m.mesh.get_surface_count():
			st.append_from(m.mesh, si, xf)
			any = true
	node.free()
	return st.commit() if any else null


## Albedo texture of a crowd GLB override (pass it to CrowdView.setup), or null.
static func asset_texture(key: String) -> Texture2D:
	var node := asset(key, AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2)))
	if node == null:
		return null
	var tex: Texture2D = null
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mat := m.get_active_material(0) as StandardMaterial3D
		if mat and mat.albedo_texture:
			tex = mat.albedo_texture
			break
	node.free()
	return tex


# ================================================================== merging helpers

## Merges every MeshInstance3D under `root` into one vertex-coloured mesh (one draw call, so a
## MultiMesh can draw a whole crowd at once). Frees `root`.
static func merge(root: Node3D) -> ArrayMesh:
	var g := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
	_merge_into(g, root, Transform3D.IDENTITY)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = g["v"]
	arrays[Mesh.ARRAY_NORMAL] = g["n"]
	arrays[Mesh.ARRAY_COLOR] = g["c"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	root.free()
	return mesh


static func _merge_into(g: Dictionary, n: Node, xf: Transform3D) -> void:
	for ch in n.get_children():
		var t: Transform3D = xf * (ch as Node3D).transform if ch is Node3D else xf
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			var col := Color.WHITE
			var mat := mi.material_override as StandardMaterial3D
			if mat:
				col = mat.albedo_color
				if mat.emission_enabled:
					col = col.lightened(0.25)
			Mats._append_mesh(g, mi.mesh, t, col)
		_merge_into(g, ch, t)


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		_meshes[key] = merge(build.call())
	return _meshes[key]


static func vertex_material() -> StandardMaterial3D:
	return Mats.vertex_colored(0.8)


## Additive soft glow card (billboard) - halos around crystals and lights.
static func _halo_mat(c: Color) -> StandardMaterial3D:
	var key := "halo%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := _new_halo_mat(c)
	_mats[key] = m
	return m


static func _new_halo_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Mats.soft_texture()
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func _halo(parent: Node3D, pos: Vector3, c: Color, size: float, mat: Material = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat if mat else _halo_mat(c)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_bake", true)
	parent.add_child(mi)
	return mi


## Diagonal orange/black hazard stripes (generated once).
static func _stripes_tex() -> Texture2D:
	if _stripes:
		return _stripes
	var s := 64
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var a := Color(1.0, 0.55, 0.08)
	var b := Color(0.07, 0.07, 0.09)
	for y in s:
		for x in s:
			var k := fposmod(float(x + y) / float(s) * 2.0, 1.0)
			var edge := smoothstep(0.47, 0.53, k) - smoothstep(0.97, 1.0, k) + (1.0 - smoothstep(0.0, 0.03, k))
			img.set_pixel(x, y, b.lerp(a, clampf(edge, 0.0, 1.0)))
	img.generate_mipmaps()
	_stripes = ImageTexture.create_from_image(img)
	return _stripes


static func _stripes_mat() -> StandardMaterial3D:
	var key := "stripes"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _stripes_tex()
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.emission_enabled = true
	m.emission_texture = _stripes_tex()
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.25
	_mats[key] = m
	return m


## Flat hazard-stripe plate facing +Z; `repeat` = stripe tiles across.
static func _stripe_plate(parent: Node3D, size: Vector2, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := _stripes_mat().duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(size.x / size.y * 0.5, 0.5, 1)
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.set_meta("no_bake", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ================================================================== crowd units

## Player soldier, about 0.75 tall: white armour, gold trim, a tier-coloured cape and crest so the
## tier reads from behind and above. tier 0 spear + shield (blue cape), 1 crossbow + quiver
## (teal cape, wide bow arms), 2 crystal blaster + glowing power cell on the back (gold cape).
static func soldier_mesh(tier := 0) -> Mesh:
	tier = clampi(tier, 0, 2)
	var key := "soldier%d" % tier
	if _meshes.has(key):
		return _meshes[key]
	var over := _asset_mesh("soldier" if tier == 0 else "soldier_%d" % tier, 0.75)
	if over == null and tier > 0:
		over = _asset_mesh("soldier", 0.75)
	if over:
		_meshes[key] = over
		return over
	_meshes[key] = merge(_soldier(tier))
	return _meshes[key]


static func _soldier(tier: int) -> Node3D:
	var r := Node3D.new()
	var white := Mats.solid(Color(0.95, 0.96, 1.0), 0.5)
	var shade := Mats.solid(SILVER_SHADE, 0.6)
	var gold := Mats.solid(GOLD, 0.4, 0.6)
	var navy := Mats.solid(NAVY)
	var capes: Array[Color] = [Color(0.18, 0.42, 0.98), Color(0.05, 0.66, 0.72), Color(1.0, 0.7, 0.18)]
	var cape := Mats.solid(capes[tier])
	var ice := Mats.glow(ICE, 1.5)
	# Legs and boots.
	for sgn in [-1.0, 1.0]:
		Mats.part(r, Mats.box(Vector3(0.1, 0.2, 0.12)), navy, Vector3(0.07 * sgn, 0.12, 0))
		Mats.part(r, Mats.box(Vector3(0.12, 0.07, 0.17)), shade, Vector3(0.07 * sgn, 0.035, 0.025))
	# Torso, belt, chest gem.
	Mats.part(r, Mats.cyl(0.15, 0.19, 0.3, 8), white, Vector3(0, 0.38, 0))
	Mats.part(r, Mats.box(Vector3(0.36, 0.055, 0.28)), gold, Vector3(0, 0.26, 0))
	Mats.part(r, Mats.crystal(0.05, 0.12), ice, Vector3(0, 0.42, 0.16), Vector3(90, 0, 0))
	# Pauldrons (big from above) with gold rims.
	for sgn in [-1.0, 1.0]:
		Mats.part(r, Mats.sphere(0.095, 0.11, 8, 4), white if tier < 2 else gold, Vector3(0.17 * sgn, 0.5, 0))
		Mats.part(r, Mats.box(Vector3(0.05, 0.03, 0.18)), gold if tier < 2 else white, Vector3(0.235 * sgn, 0.47, 0))
	# Cape on the back (what the run camera sees), flared, with a gold hem.
	Mats.part(r, Mats.box(Vector3(0.32, 0.38, 0.04)), cape, Vector3(0, 0.36, -0.2), Vector3(10, 0, 0))
	Mats.part(r, Mats.box(Vector3(0.34, 0.04, 0.05)), gold, Vector3(0, 0.18, -0.235), Vector3(10, 0, 0))
	# Head with a face under an open helmet.
	Mats.part(r, Mats.sphere(0.12, -1, 8, 5), Mats.solid(SKIN), Vector3(0, 0.62, 0.05))
	for sgn in [-1.0, 1.0]:
		Mats.part(r, Mats.box(Vector3(0.03, 0.04, 0.02)), Mats.solid(Color(0.1, 0.1, 0.18)), Vector3(0.045 * sgn, 0.63, 0.165))
	Mats.part(r, Mats.sphere(0.15, 0.16, 8, 4), white, Vector3(0, 0.7, -0.02))
	Mats.part(r, Mats.box(Vector3(0.31, 0.035, 0.29)), gold, Vector3(0, 0.66, -0.02))
	Mats.part(r, Mats.box(Vector3(0.3, 0.16, 0.06)), white, Vector3(0, 0.62, -0.12))
	match tier:
		0:
			Mats.part(r, Mats.box(Vector3(0.05, 0.14, 0.26)), gold, Vector3(0, 0.83, -0.02))
			# Round shield on the right arm, spear upright on the left.
			Mats.part(r, Mats.cyl(0.16, 0.16, 0.04, 10), gold, Vector3(0.23, 0.4, 0.05), Vector3(0, 0, 90))
			Mats.part(r, Mats.cyl(0.115, 0.115, 0.045, 10), Mats.solid(BLUE), Vector3(0.25, 0.4, 0.05), Vector3(0, 0, 90))
			Mats.part(r, Mats.crystal(0.04, 0.08), ice, Vector3(0.28, 0.4, 0.05), Vector3(0, 0, 90))
			Mats.part(r, Mats.box(Vector3(0.035, 0.95, 0.035)), Mats.solid(WOOD), Vector3(-0.22, 0.5, 0.08))
			Mats.part(r, Mats.cone(0.055, 0.18, 6), Mats.solid(SILVER, 0.35, 0.6), Vector3(-0.22, 1.06, 0.08))
			Mats.part(r, Mats.box(Vector3(0.07, 0.03, 0.07)), gold, Vector3(-0.22, 0.97, 0.08))
		1:
			# Teal plume, quiver of gold-fletched bolts, crossbow with wide silver arms.
			Mats.part(r, Mats.box(Vector3(0.05, 0.08, 0.22)), cape, Vector3(0, 0.8, -0.04), Vector3(-15, 0, 0))
			Mats.part(r, Mats.cyl(0.065, 0.06, 0.32, 6), Mats.solid(WOOD_DARK), Vector3(0.1, 0.48, -0.19), Vector3(0, 0, 18))
			for k in 3:
				Mats.part(r, Mats.box(Vector3(0.035, 0.08, 0.035)), gold, Vector3(0.055 + k * 0.035, 0.68 + k * 0.01, -0.19), Vector3(0, 0, 18))
			Mats.part(r, Mats.box(Vector3(0.07, 0.07, 0.42)), Mats.solid(WOOD), Vector3(0.0, 0.44, 0.2))
			Mats.part(r, Mats.box(Vector3(0.56, 0.05, 0.06)), Mats.solid(SILVER, 0.35, 0.6), Vector3(0, 0.46, 0.38))
			for sgn in [-1.0, 1.0]:
				Mats.part(r, Mats.box(Vector3(0.06, 0.06, 0.08)), gold, Vector3(0.28 * sgn, 0.46, 0.35))
			Mats.part(r, Mats.crystal(0.035, 0.12), ice, Vector3(0, 0.46, 0.46), Vector3(90, 0, 0))
		2:
			# Crystal visor, fins, chunky blaster and a glowing power cell on the back.
			Mats.part(r, Mats.box(Vector3(0.22, 0.05, 0.05)), ice, Vector3(0, 0.66, 0.13))
			for sgn in [-1.0, 1.0]:
				Mats.part(r, Mats.box(Vector3(0.03, 0.12, 0.16)), gold, Vector3(0.1 * sgn, 0.8, -0.03), Vector3(0, 0, -20 * sgn))
			Mats.part(r, Mats.box(Vector3(0.24, 0.26, 0.11)), Mats.solid(SILVER, 0.4, 0.5), Vector3(0, 0.44, -0.2))
			Mats.part(r, Mats.crystal(0.075, 0.32), ice, Vector3(0, 0.62, -0.21))
			Mats.part(r, Mats.box(Vector3(0.12, 0.13, 0.36)), Mats.solid(SILVER, 0.4, 0.5), Vector3(0.13, 0.42, 0.18))
			Mats.part(r, Mats.box(Vector3(0.06, 0.07, 0.2)), gold, Vector3(0.13, 0.5, 0.14))
			Mats.part(r, Mats.cyl(0.04, 0.05, 0.22, 6), ice, Vector3(0.13, 0.42, 0.44), Vector3(90, 0, 0))
	return r


## Enemy raider: dark steel armour with red plates, horned helmet with a glowing orange visor,
## spiked red pauldrons, a tattered red cape and a jagged ember-edged blade.
static func raider_mesh() -> Mesh:
	if _meshes.has("raider"):
		return _meshes["raider"]
	var over := _asset_mesh("raider", 0.72)
	if over:
		_meshes["raider"] = over
		return over
	return _cached("raider", func():
		var r := Node3D.new()
		var steel := Mats.solid(STEEL_MID, 0.5, 0.5)
		var dark := Mats.solid(STEEL_DARK)
		var plate := Mats.solid(PLATE, 0.55)
		var ember := Mats.glow(EMBER, 1.3)
		var bone := Mats.solid(Color(0.95, 0.88, 0.75))
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.box(Vector3(0.11, 0.22, 0.12)), dark, Vector3(0.075 * sgn, 0.11, 0))
		Mats.part(r, Mats.cyl(0.15, 0.2, 0.32, 7), steel, Vector3(0, 0.37, 0), Vector3(12, 0, 0))
		Mats.part(r, Mats.box(Vector3(0.24, 0.2, 0.06)), plate, Vector3(0, 0.4, 0.15), Vector3(12, 0, 0))
		Mats.part(r, Mats.box(Vector3(0.36, 0.05, 0.28)), Mats.solid(BRONZE, 0.45, 0.5), Vector3(0, 0.25, 0.01))
		Mats.part(r, Mats.box(Vector3(0.3, 0.32, 0.04)), plate, Vector3(0, 0.36, -0.15), Vector3(-10, 0, 0))
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.sphere(0.1, 0.11, 7, 4), plate, Vector3(0.17 * sgn, 0.5, 0.02))
			Mats.part(r, Mats.cone(0.04, 0.13, 5), dark, Vector3(0.22 * sgn, 0.56, 0.02), Vector3(0, 0, -55 * sgn))
		Mats.part(r, Mats.sphere(0.15, 0.16, 8, 4), steel, Vector3(0, 0.65, 0.05))
		Mats.part(r, Mats.box(Vector3(0.2, 0.04, 0.05)), ember, Vector3(0, 0.63, 0.18))
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.cone(0.045, 0.2, 5), bone, Vector3(0.15 * sgn, 0.76, 0.05), Vector3(0, 0, -50 * sgn))
		Mats.part(r, Mats.box(Vector3(0.035, 0.035, 0.62)), dark, Vector3(0.2, 0.4, 0.12))
		Mats.part(r, Mats.prism(Vector3(0.12, 0.2, 0.03)), ember, Vector3(0.2, 0.4, 0.5), Vector3(90, 0, 0))
		return r)


# ================================================================== labels

## A label in the world: big bold numbers with a dark outline.
static func label(text: String, px: int, color := Color.WHITE, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIKit.font(true)
	l.font_size = px
	l.pixel_size = 0.006
	l.outline_size = maxi(8, px / 6)
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.06, 0.15, 1.0)
	l.no_depth_test = false
	l.double_sided = false
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = false
	return l


## Shrinks a label's pixel size so its text fits `max_w` x `max_h` metres (never grows it past
## `base_px_size`).
static func _fit_label(l: Label3D, max_w: float, max_h: float, base_px_size := 0.006) -> void:
	if l.text == "" or l.font == null:
		l.pixel_size = base_px_size
		return
	var sz := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size)
	sz += Vector2(l.outline_size, l.outline_size) * 2.0
	var ps := base_px_size
	if sz.x * ps > max_w:
		ps = max_w / sz.x
	if sz.y * 0.72 * ps > max_h:
		ps = max_h / (sz.y * 0.72)
	l.pixel_size = ps


static func _mult_text(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "×%d" % int(roundf(m))
	return "×%s" % String.num(m, 1)


# ================================================================== gates

## Gate across `width` metres: two white-silver pylons with gold rings and glowing crystal caps,
## a crossbar, an emitter at the base and an animated energy field between them, plus a big
## number label, a forecast pill ("→ 47") and, for charge gates, a fill bar. Style it with
## gate_style(). Metas: "label" (Label3D), "sub" (forecast Label3D), "field" (MeshInstance3D),
## "width", "kind", "charge".
static func gate(width: float) -> Node3D:
	var w := clampf(width, 0.9, 4.0)
	var hw := w * 0.5
	var root := Node3D.new()
	root.name = "Gate"
	root.set_meta("width", w)
	var fitted := _gate_asset_frame(w)
	var frame: Node3D = fitted.get("node") if not fitted.is_empty() else _gate_frame(w)
	root.add_child(frame)
	if not fitted.is_empty():
		root.set_meta("asset_mat", fitted["mat"])
	# Accent parts (crystal caps, light strips, emitter) share one per-gate material so a
	# restyle is a colour change.
	var accent := MeshInstance3D.new()
	accent.name = "Accent"
	accent.mesh = _gate_accent_mesh(w)
	var am := StandardMaterial3D.new()
	am.vertex_color_use_as_albedo = true
	am.emission_enabled = true
	am.emission_energy_multiplier = 1.25
	am.roughness = 0.25
	accent.material_override = am
	accent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(accent)
	root.set_meta("accent_mat", am)
	accent.visible = fitted.is_empty()
	# Energy field.
	var fw: float = float(fitted.get("field_w", w - 0.26))
	var fh: float = float(fitted.get("field_h", GATE_H - 0.04))
	var field := MeshInstance3D.new()
	field.name = "Field"
	var q := QuadMesh.new()
	q.size = Vector2(fw, fh)
	field.mesh = q
	field.position = Vector3(0, fh * 0.5 + 0.02, 0)
	var fm := ShaderMaterial.new()
	fm.shader = FIELD_SHADER
	fm.set_shader_parameter("noise_tex", NOISE_TEX)
	fm.set_shader_parameter("size", Vector2(fw, fh))
	fm.set_shader_parameter("seed", randf())
	field.material_override = fm
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(field)
	root.set_meta("field", field)
	root.set_meta("field_mat", fm)
	root.set_meta("field_h", fh)
	# Halos on the crystal caps and the crossbar gem.
	var hm := _new_halo_mat(Color.WHITE)
	if fitted.is_empty():
		for sgn in [-1.0, 1.0]:
			_halo(root, Vector3(hw * sgn, GATE_H + 0.62, 0.05), Color.WHITE, 1.1, hm)
		_halo(root, Vector3(0, GATE_H + 0.16, 0.24), Color.WHITE, 0.9, hm)
	else:
		for sgn in [-1.0, 1.0]:
			_halo(root, Vector3(float(fitted["pylon_x"]) * sgn, float(fitted["tip_y"]) - 0.3, 0.05), Color.WHITE, 1.0, hm)
	root.set_meta("halo_mat", hm)
	# Charge bar under the crossbar.
	var bar := Node3D.new()
	bar.name = "ChargeBar"
	bar.position = Vector3(0, fh - 0.18, 0.14)
	var bw := fw - 0.36
	Mats.part(bar, Mats.box(Vector3(bw + 0.1, 0.22, 0.05)), Mats.solid(Color(0.05, 0.03, 0.1), 0.6), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	Mats.part(bar, Mats.box(Vector3(bw + 0.16, 0.035, 0.07)), Mats.solid(GOLD, 0.35, 0.6), Vector3(0, 0.115, 0), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(bar, Mats.box(Vector3(bw + 0.16, 0.035, 0.07)), Mats.solid(GOLD, 0.35, 0.6), Vector3(0, -0.115, 0), Vector3.ZERO, Vector3.ONE, false)
	var fill := Mats.part(bar, Mats.box(Vector3(bw, 0.13, 0.06)), _unlit(Color(0.78, 0.32, 1.0)), Vector3(0, 0, 0.01), Vector3.ZERO, Vector3.ONE, false)
	var fill_head := _halo(bar, Vector3(0, 0, 0.06), Color(1.0, 0.6, 1.0, 0.9), 0.55)
	bar.set_meta("fill", fill)
	bar.set_meta("head", fill_head)
	bar.set_meta("w", bw)
	bar.visible = false
	root.add_child(bar)
	root.set_meta("bar", bar)
	# Labels: the big effect number and the forecast pill.
	var l := label("", 230, Color.WHITE)
	l.position = Vector3(0, GATE_H * 0.58, 0.14)
	l.rotation_degrees = Vector3(-14, 0, 0)
	l.render_priority = 3
	l.outline_render_priority = 2
	root.add_child(l)
	root.set_meta("label", l)
	var pill := Node3D.new()
	pill.name = "Forecast"
	pill.position = Vector3(0, 0.46, 0.2)
	pill.rotation_degrees = Vector3(-24, 0, 0)
	var pill_bg := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(1.0, 0.54)
	pill_bg.mesh = pq
	pill_bg.material_override = _pill_mat()
	pill_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pill_bg.position = Vector3(0, 0, -0.01)
	pill.add_child(pill_bg)
	var sub := label("", 120, Color(0.92, 0.97, 1.0))
	sub.outline_size = 14
	sub.render_priority = 3
	sub.outline_render_priority = 2
	pill.add_child(sub)
	var arrow := _arrow_mesh()
	pill.add_child(arrow)
	pill.visible = false
	pill.set_meta("bg", pill_bg)
	pill.set_meta("arrow", arrow)
	root.add_child(pill)
	root.set_meta("sub", sub)
	root.set_meta("pill", pill)
	var icon := Node3D.new()
	icon.name = "Icon"
	icon.position = Vector3(0, fh * 0.77, 0.16)
	root.add_child(icon)
	root.set_meta("icon", icon)
	root.set_meta("charge", 0.0)
	root.set_meta("kind", "")
	gate_style(root, "", "", "good")
	return root


## The owner's gate GLB fitted to a gate `w` wide: the pylons keep their own thickness and stand
## at ±w/2, the crossbar stretches between them (a piecewise remap of x, cached per width).
## Returns {} when the world has no gate model; otherwise {node, mat, field_w, field_h, pylon_x,
## tip_y} so the field, labels and halos sit inside the real frame.
static func _gate_asset_frame(w: float) -> Dictionary:
	var path := str(_models_map().get("gate", ""))
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var hw := w * 0.5
	var key := "gate_asset:%s:%.2f" % [path, w]
	var src_tex: Array = [null, null]
	if not _meshes.has(key):
		var ps := load(path) as PackedScene
		var inst := ps.instantiate() as Node3D if ps else null
		if inst == null:
			return {}
		var box := _mesh_aabb(inst)
		var half := box.size.x * 0.5
		var cx := box.get_center().x
		var by := box.position.y
		var hy := box.size.y
		var unit := box.size.x                      # source model: 1.0 unit wide
		var sxz := float(GATE_ASSET["sxz"]) / unit
		var sy := float(GATE_ASSET["sy"]) / unit
		var pylon := float(GATE_ASSET["pylon"]) * half
		var inner := float(GATE_ASSET["inner"]) * half
		var inner_w := hw - (pylon - inner) * sxz   # world x of the pylons' inner edges
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var xf := _relative_xf(inst, m)
			for si in m.mesh.get_surface_count():
				var mat := m.get_active_material(si) as StandardMaterial3D
				if mat and src_tex[0] == null:
					src_tex = [mat.albedo_texture, mat.normal_texture if mat.normal_enabled else null]
				var arr := m.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var out_v := PackedVector3Array()
				var out_n := PackedVector3Array()
				out_v.resize(verts.size())
				out_n.resize(verts.size())
				for i in verts.size():
					var p := xf * verts[i]
					var x := p.x - cx
					var ax := absf(x)
					var sg := 1.0 if x >= 0.0 else -1.0
					var kx := sxz
					var nx: float
					if ax >= inner:
						nx = sg * (hw + (ax - pylon) * sxz)
					else:
						kx = inner_w / maxf(inner, 1e-4)
						nx = x * kx
					out_v[i] = Vector3(nx, (p.y - by) * sy, p.z * sxz)
					var n := (xf.basis * norms[i]) if norms.size() > i else Vector3.UP
					out_n[i] = Vector3(n.x / kx, n.y / sy, n.z / sxz).normalized()
				var na := []
				na.resize(Mesh.ARRAY_MAX)
				na[Mesh.ARRAY_VERTEX] = out_v
				na[Mesh.ARRAY_NORMAL] = out_n
				if uvs.size() == verts.size():
					na[Mesh.ARRAY_TEX_UV] = uvs
				if idx.size() > 0:
					na[Mesh.ARRAY_INDEX] = idx
				var tmp := ArrayMesh.new()
				tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
				st.append_from(tmp, 0, Transform3D.IDENTITY)
		inst.free()
		st.generate_tangents()
		var mesh := st.commit()
		_meshes[key] = mesh
		mesh.set_meta("tex", src_tex)
		mesh.set_meta("dims", {"field_w": inner_w * 2.0 - 0.06, "field_h": (float(GATE_ASSET["bar"]) * hy) * sy - 0.05,
			"pylon_x": hw, "tip_y": hy * sy})
	var gm: ArrayMesh = _meshes[key]
	var tex: Array = gm.get_meta("tex")
	var mat2 := ShaderMaterial.new()
	mat2.shader = GATE_ASSET_SHADER
	mat2.set_shader_parameter("albedo_tex", tex[0])
	mat2.set_shader_parameter("normal_tex", tex[1])
	mat2.set_shader_parameter("has_normal", tex[1] != null)
	var node := MeshInstance3D.new()
	node.name = "AssetFrame"
	node.mesh = gm
	node.material_override = mat2
	var dims: Dictionary = gm.get_meta("dims")
	var out := {"node": node, "mat": mat2}
	out.merge(dims)
	return out


static func _gate_frame(w: float) -> Node3D:
	var f := Node3D.new()
	f.name = "Frame"
	var hw := w * 0.5
	var silver := Mats.solid(SILVER, 0.4, 0.0, 0.3)
	var shade := Mats.solid(SILVER_SHADE, 0.5)
	var dark := Mats.solid(Color(0.32, 0.36, 0.5), 0.6)
	var gold := Mats.solid(GOLD, 0.35, 0.6)
	for sgn in [-1.0, 1.0]:
		var x: float = hw * sgn
		# Plinth: two bevel steps.
		Mats.part(f, Mats.box(Vector3(0.5, 0.14, 0.56)), dark, Vector3(x, 0.07, 0))
		Mats.part(f, Mats.box(Vector3(0.42, 0.12, 0.48)), shade, Vector3(x, 0.2, 0))
		Mats.part(f, Mats.box(Vector3(0.44, 0.05, 0.5)), gold, Vector3(x, 0.285, 0))
		# Shaft with chamfer-like corner strips.
		Mats.part(f, Mats.box(Vector3(0.28, GATE_H - 0.3, 0.32)), silver, Vector3(x, 0.3 + (GATE_H - 0.3) * 0.5, 0))
		Mats.part(f, Mats.box(Vector3(0.06, GATE_H - 0.4, 0.06)), shade, Vector3(x - 0.15, 0.3 + (GATE_H - 0.3) * 0.5, 0.17))
		Mats.part(f, Mats.box(Vector3(0.06, GATE_H - 0.4, 0.06)), shade, Vector3(x + 0.15, 0.3 + (GATE_H - 0.3) * 0.5, 0.17))
		Mats.part(f, Mats.box(Vector3(0.15, GATE_H - 0.5, 0.02)), Mats.solid(Color(0.1, 0.13, 0.28), 0.5), Vector3(x, 0.32 + (GATE_H - 0.55) * 0.5, 0.162))
		for y in [0.75, GATE_H - 0.35]:
			Mats.part(f, Mats.box(Vector3(0.34, 0.07, 0.38)), gold, Vector3(x, y, 0))
		# Head block holding the crystal.
		Mats.part(f, Mats.box(Vector3(0.38, 0.3, 0.42)), silver, Vector3(x, GATE_H + 0.15, 0))
		Mats.part(f, Mats.box(Vector3(0.42, 0.05, 0.46)), gold, Vector3(x, GATE_H + 0.32, 0))
		Mats.part(f, Mats.cyl(0.12, 0.17, 0.12, 6), gold, Vector3(x, GATE_H + 0.4, 0))
	# Crossbar with gold trims.
	Mats.part(f, Mats.box(Vector3(w, 0.26, 0.3)), silver, Vector3(0, GATE_H + 0.13, 0))
	Mats.part(f, Mats.box(Vector3(w - 0.1, 0.045, 0.33)), gold, Vector3(0, GATE_H + 0.27, 0))
	Mats.part(f, Mats.box(Vector3(w - 0.1, 0.045, 0.33)), gold, Vector3(0, GATE_H - 0.005, 0))
	# Gem setting in the middle of the crossbar.
	Mats.part(f, Mats.box(Vector3(0.36, 0.36, 0.08)), gold, Vector3(0, GATE_H + 0.15, 0.15), Vector3(0, 0, 45))
	# Base rail the emitter sits in.
	Mats.part(f, Mats.box(Vector3(w - 0.2, 0.06, 0.2)), dark, Vector3(0, 0.03, 0))
	Mats.bake(f)
	return f


## Glowing accent geometry in white vertex colour (the per-gate material tints it).
static func _gate_accent_mesh(w: float) -> ArrayMesh:
	return _cached("gate_accent%.2f" % w, func():
		var r := Node3D.new()
		var m := Mats.solid(Color.WHITE)
		var hw := w * 0.5
		for sgn in [-1.0, 1.0]:
			var x: float = hw * sgn
			Mats.part(r, Mats.crystal(0.15, 0.62), m, Vector3(x, GATE_H + 0.66, 0))
			Mats.part(r, Mats.crystal(0.07, 0.3), m, Vector3(x + 0.13 * sgn, GATE_H + 0.52, 0.05), Vector3(0, 0, -25 * sgn))
			# Inner light strip running up the pylon, facing the field and the camera.
			Mats.part(r, Mats.box(Vector3(0.07, GATE_H - 0.55, 0.03)), m, Vector3(x, 0.32 + (GATE_H - 0.55) * 0.5, 0.165))
			Mats.part(r, Mats.box(Vector3(0.03, GATE_H - 0.45, 0.08)), m, Vector3(x - 0.145 * sgn, 0.3 + (GATE_H - 0.45) * 0.5, 0))
		Mats.part(r, Mats.box(Vector3(w - 0.55, 0.05, 0.03)), m, Vector3(0, GATE_H + 0.13, 0.155))
		Mats.part(r, Mats.crystal(0.13, 0.34), m, Vector3(0, GATE_H + 0.15, 0.2), Vector3(90, 0, 0))
		Mats.part(r, Mats.box(Vector3(w - 0.3, 0.035, 0.1)), m, Vector3(0, 0.075, 0))
		return r)


static func _pill_mat() -> StandardMaterial3D:
	if _mats.has("pill"):
		return _mats["pill"]
	var img := Image.create(128, 54, false, Image.FORMAT_RGBA8)
	var rad := 26.0
	for y in 54:
		for x in 128:
			var cx := clampf(float(x), rad + 1.0, 127.0 - rad - 1.0)
			var d := Vector2(float(x) - cx, float(y) - 26.5).length()
			var a := clampf(rad - d, 0.0, 1.0)
			var rim := clampf(1.0 - absf(d - (rad - 2.0)) / 1.6, 0.0, 1.0)
			var c := Color(0.03, 0.05, 0.12, 0.78 * a).lerp(Color(1, 1, 1, 0.55 * a), rim * 0.5)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.render_priority = 1
	_mats["pill"] = m
	return m


## Flat arrow glyph for the forecast (the UI font has no "→").
static func _arrow_mesh() -> MeshInstance3D:
	var mesh: ArrayMesh = _meshes.get("arrow")
	if mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3(0, 0, 1))
		var pts := [Vector2(-0.16, 0.035), Vector2(0.04, 0.035), Vector2(0.04, 0.09), Vector2(0.16, 0.0),
				Vector2(0.04, -0.09), Vector2(0.04, -0.035), Vector2(-0.16, -0.035)]
		var tris := [[0, 6, 1], [1, 6, 5], [2, 4, 3]]
		for tri in tris:
			for k in tri:
				var p: Vector2 = pts[k]
				st.add_vertex(Vector3(p.x, p.y, 0))
		mesh = st.commit()
		_meshes["arrow"] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _arrow_mat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _arrow_mat(c: Color) -> StandardMaterial3D:
	var key := "arrow%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 4
	_mats[key] = m
	return m


## Styles a gate. kind: "good" blue, "bad" red, "charge" violet with a fill bar (meta "charge"
## 0..1, see gate_charge), "hidden" grey "?", "power" gold, "arm" teal, "closed" (dims and folds
## the field up into the crossbar, animated when the gate is in the tree). `text` is the big
## label ("+15", "×2", "Арбалети"), `sub` the forecast ("→ 47", or "" to hide). `icon` adds a
## small glowing emblem above the text: spear, crossbow, blaster, rate, dmg, multi, or any
## other word for a crystal star.
static func gate_style(node: Node3D, text: String, sub: String, kind: String, icon := "") -> void:
	if not GATE_KINDS.has(kind):
		kind = "good"
	var prev := str(node.get_meta("kind", ""))
	node.set_meta("kind", kind)
	var cols: Array = GATE_KINDS[kind]
	var col: Color = cols[0]
	var core: Color = cols[1]
	var outline: Color = cols[2]
	if kind == "hidden" and text == "":
		text = "?"
	var w := float(node.get_meta("width", 2.0))
	var fh := float(node.get_meta("field_h", GATE_H))
	var am := node.get_meta("accent_mat") as StandardMaterial3D
	am.albedo_color = col
	am.emission = col
	am.emission_energy_multiplier = 0.35 if kind == "closed" else 1.25
	if node.has_meta("asset_mat"):
		var gm := node.get_meta("asset_mat") as ShaderMaterial
		gm.set_shader_parameter("crystal_color", col)
		gm.set_shader_parameter("crystal_glow", 0.3 if kind == "closed" else 1.35)
		gm.set_shader_parameter("dim", 0.62 if kind == "closed" else 1.0)
	var hm := node.get_meta("halo_mat") as StandardMaterial3D
	hm.albedo_color = Color(col.r, col.g, col.b, 0.1 if kind == "closed" else 0.6)
	var fm := node.get_meta("field_mat") as ShaderMaterial
	fm.set_shader_parameter("color", col)
	fm.set_shader_parameter("core_color", core)
	fm.set_shader_parameter("empty_color", Color(0.22, 0.08, 0.3) if kind == "charge" else col * 0.4)
	fm.set_shader_parameter("turbulence", 1.6 if kind == "hidden" else 1.0)
	# Icon emblem.
	var icon_root := node.get_meta("icon") as Node3D
	if str(icon_root.get_meta("kind", "")) != icon:
		for ch in icon_root.get_children():
			ch.queue_free()
		icon_root.set_meta("kind", icon)
		if icon != "":
			icon_root.add_child(_emblem(icon, core))
	var has_icon := icon != ""
	# Charge bar.
	var bar := node.get_meta("bar") as Node3D
	bar.visible = kind == "charge"
	# Main label.
	var l := node.get_meta("label") as Label3D
	l.text = text
	l.modulate = Color.WHITE if kind != "closed" else Color(0.75, 0.77, 0.82, 0.6)
	l.outline_modulate = outline
	var top_used := 0.3 if kind == "charge" else 0.0
	var text_h := fh * (0.36 if has_icon else 0.5) - top_used * 0.5
	l.position.y = fh * (0.44 if has_icon else 0.58) - top_used * 0.4
	_fit_label(l, w - 0.36, text_h)
	icon_root.position.y = fh * 0.77 - top_used * 0.5
	icon_root.visible = has_icon
	# Forecast pill.
	var pill := node.get_meta("pill") as Node3D
	var s := node.get_meta("sub") as Label3D
	var arrow := pill.get_meta("arrow") as MeshInstance3D
	var shown := sub.strip_edges()
	var has_arrow := shown.begins_with("→")
	if has_arrow:
		shown = shown.trim_prefix("→").strip_edges()
	pill.visible = shown != "" and kind != "closed"
	if pill.visible:
		s.text = shown
		s.modulate = core
		s.outline_modulate = Color(0.02, 0.03, 0.08)
		# The forecast is the decision: big enough to read two rows ahead on a phone.
		_fit_label(s, w - 0.55, 0.4, 0.0052)
		var tw := s.font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, s.font_size).x * s.pixel_size
		var aw := 0.4 if has_arrow else 0.0
		arrow.scale = Vector3.ONE * 1.2
		var total := tw + aw
		s.position.x = aw * 0.5
		arrow.visible = has_arrow
		arrow.position = Vector3(-total * 0.5 + 0.16, 0.0, 0.002)
		arrow.material_override = _arrow_mat(core)
		var bg := pill.get_meta("bg") as MeshInstance3D
		bg.scale = Vector3(maxf(total + 0.32, 0.6), 1.0, 1.0)
	# Fill level, closing.
	gate_charge(node, float(node.get_meta("charge", 0.0)))
	var field := node.get_meta("field") as MeshInstance3D
	var closing := kind == "closed"
	var target_scale := 0.06 if closing else 1.0
	var target_y := (fh - fh * target_scale * 0.5 + 0.02) if closing else fh * 0.5 + 0.02
	if node.is_inside_tree() and prev != "" and (prev == "closed") != closing:
		var tw2 := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN if closing else Tween.EASE_OUT)
		tw2.tween_property(field, "scale:y", target_scale, 0.32)
		tw2.tween_property(field, "position:y", target_y, 0.32)
		tw2.tween_method(func(v: float) -> void: fm.set_shader_parameter("closed", v), 0.0 if closing else 1.0, 1.0 if closing else 0.0, 0.32)
		tw2.tween_property(l, "modulate:a", 0.35 if closing else 1.0, 0.25)
		tw2.tween_property(icon_root, "scale", Vector3.ONE * (0.6 if closing else 1.0), 0.25)
	else:
		field.scale.y = target_scale
		field.position.y = target_y
		fm.set_shader_parameter("closed", 1.0 if closing else 0.0)
		if closing:
			l.modulate.a = 0.35


## Sets a charge gate's fill (0..1): the bar under the crossbar and the field's fill level.
## Other kinds always show a full field.
static func gate_charge(node: Node3D, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	node.set_meta("charge", ratio)
	var kind := str(node.get_meta("kind", "good"))
	var fm := node.get_meta("field_mat") as ShaderMaterial
	fm.set_shader_parameter("fill", ratio if kind == "charge" else 1.0)
	var bar := node.get_meta("bar") as Node3D
	var bw := float(bar.get_meta("w"))
	var fill := bar.get_meta("fill") as MeshInstance3D
	var head := bar.get_meta("head") as MeshInstance3D
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -bw * 0.5 + bw * ratio * 0.5
	head.position.x = -bw * 0.5 + bw * ratio
	head.visible = ratio > 0.01 and ratio < 0.999


## Brief white flash of the field (e.g. when the hero's shot hits the gate).
static func gate_hit(node: Node3D, strength := 1.0) -> void:
	var fm := node.get_meta("field_mat") as ShaderMaterial
	if not node.is_inside_tree():
		return
	var tw := node.create_tween()
	tw.tween_method(func(v: float) -> void: fm.set_shader_parameter("flash", v), clampf(strength, 0.0, 1.0), 0.0, 0.22)


## Small glowing emblem facing +Z for arm/power gates: a gold silhouette with highlights in the
## gate colour `c`, on a soft halo.
static func _emblem(kind: String, c: Color) -> Node3D:
	var r := Node3D.new()
	var gold := Mats.glow(Color(1.0, 0.74, 0.22), 0.55)
	var hot := Mats.glow(c.lerp(Color.WHITE, 0.2), 0.8)
	var silver := Mats.solid(Color(0.92, 0.94, 1.0), 0.35, 0.0, 0.4)
	match kind:
		"spear":
			Mats.part(r, Mats.box(Vector3(0.06, 0.62, 0.05)), gold, Vector3(0, -0.04, 0), Vector3(0, 0, -35))
			Mats.part(r, _flat_shape("spearhead", PackedVector2Array([Vector2(0, 0.16), Vector2(0.08, -0.04), Vector2(0, -0.09), Vector2(-0.08, -0.04)]), 0.05), hot, Vector3(0.2, 0.28, 0), Vector3(0, 0, -35))
		"crossbow":
			Mats.part(r, Mats.box(Vector3(0.08, 0.5, 0.06)), gold, Vector3(0, -0.06, 0))
			for sgn in [-1.0, 1.0]:
				Mats.part(r, Mats.box(Vector3(0.34, 0.07, 0.06)), silver, Vector3(0.16 * sgn, 0.1, 0), Vector3(0, 0, -18 * sgn))
			Mats.part(r, Mats.box(Vector3(0.6, 0.018, 0.03)), hot, Vector3(0, 0.0, 0.03))
			Mats.part(r, _flat_shape("arrowhead", PackedVector2Array([Vector2(0, 0.1), Vector2(0.08, -0.04), Vector2(-0.08, -0.04)]), 0.05), hot, Vector3(0, 0.27, 0.02))
		"blaster":
			Mats.part(r, Mats.box(Vector3(0.46, 0.16, 0.08)), silver, Vector3(-0.02, 0.04, 0))
			Mats.part(r, Mats.box(Vector3(0.1, 0.22, 0.07)), gold, Vector3(-0.13, -0.12, 0), Vector3(0, 0, 14))
			Mats.part(r, Mats.box(Vector3(0.22, 0.07, 0.08)), hot, Vector3(0.31, 0.06, 0.01))
			Mats.part(r, Mats.box(Vector3(0.2, 0.05, 0.09)), gold, Vector3(-0.04, 0.14, 0.0))
			Mats.part(r, Mats.crystal(0.05, 0.16), hot, Vector3(0.08, 0.04, 0.05), Vector3(0, 0, 90))
		"rate":
			Mats.part(r, _flat_shape("bolt", PackedVector2Array([Vector2(0.06, 0.3), Vector2(-0.14, -0.02), Vector2(-0.01, -0.02),
					Vector2(-0.07, -0.3), Vector2(0.15, 0.04), Vector2(0.02, 0.04)]), 0.07), gold, Vector3.ZERO)
			Mats.part(r, _flat_shape("bolt_in", PackedVector2Array([Vector2(0.035, 0.2), Vector2(-0.08, 0.0), Vector2(0.02, 0.0),
					Vector2(-0.03, -0.19), Vector2(0.09, 0.02), Vector2(0.0, 0.02)]), 0.08), hot, Vector3(0, 0, 0.01))
		"dmg":
			Mats.part(r, _flat_shape("blade", PackedVector2Array([Vector2(0, 0.34), Vector2(0.055, 0.24), Vector2(0.055, -0.1), Vector2(-0.055, -0.1), Vector2(-0.055, 0.24)]), 0.05), silver, Vector3.ZERO)
			Mats.part(r, Mats.box(Vector3(0.024, 0.34, 0.06)), hot, Vector3(0, 0.1, 0.01))
			Mats.part(r, Mats.box(Vector3(0.3, 0.06, 0.07)), gold, Vector3(0, -0.13, 0))
			Mats.part(r, Mats.box(Vector3(0.06, 0.16, 0.06)), gold, Vector3(0, -0.24, 0))
			Mats.part(r, Mats.sphere(0.04, -1, 6, 3), gold, Vector3(0, -0.33, 0))
		"multi":
			for k in 3:
				var x := (k - 1) * 0.17
				var y := 0.0 if k == 1 else -0.05
				Mats.part(r, Mats.box(Vector3(0.04, 0.32, 0.04)), gold, Vector3(x, y - 0.04, 0))
				Mats.part(r, _flat_shape("arrowhead", PackedVector2Array([Vector2(0, 0.1), Vector2(0.08, -0.04), Vector2(-0.08, -0.04)]), 0.05), hot, Vector3(x, y + 0.15, 0))
		_:
			Mats.part(r, _flat_shape("star", _star_points(0.26, 0.11), 0.07), gold, Vector3.ZERO)
			Mats.part(r, _flat_shape("star_in", _star_points(0.15, 0.065), 0.08), hot, Vector3(0, 0, 0.01))
	for ch in r.get_children():
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo(r, Vector3(0, 0, -0.05), Color(c.r, c.g, c.b, 0.5), 0.9)
	return r


static func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var rad := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * rad)
	return pts


## Flat shape extruded `depth` along Z, centred on z = 0 (cached by `key`).
static func _flat_shape(key: String, pts: PackedVector2Array, depth: float) -> ArrayMesh:
	var k := "shape_%s_%.3f" % [key, depth]
	if _meshes.has(k):
		return _meshes[k]
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var cw := Geometry2D.is_polygon_clockwise(pts)
	for side in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		for i in range(0, idx.size(), 3):
			var tri := [idx[i], idx[i + 1], idx[i + 2]]
			if (side > 0.0) == cw:
				tri = [idx[i], idx[i + 2], idx[i + 1]]
			for j in tri:
				st.add_vertex(Vector3(pts[j].x, pts[j].y, hz * side))
	for i in pts.size():
		var p0 := pts[i]
		var p1 := pts[(i + 1) % pts.size()]
		var e := p1 - p0
		var nrm := Vector3(e.y, -e.x, 0).normalized() * (-1.0 if cw else 1.0)
		st.set_normal(nrm)
		var quad := [Vector3(p0.x, p0.y, hz), Vector3(p0.x, p0.y, -hz), Vector3(p1.x, p1.y, -hz), Vector3(p1.x, p1.y, hz)]
		var order := [0, 1, 2, 0, 2, 3] if not cw else [0, 2, 1, 0, 3, 2]
		for j in order:
			st.add_vertex(quad[j])
	var mesh := st.commit()
	_meshes[k] = mesh
	return mesh


## Unshaded opaque colour (keeps its hue where an emissive would clip to white).
static func _unlit(c: Color) -> StandardMaterial3D:
	var key := "unlit%s" % c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	_mats[key] = m
	return m


# ================================================================== hazards

## Spiked barricade `width` wide: a dark steel beam with hazard stripes, end posts with red
## beacons and two staggered rows of glowing red crystal spikes. Meta "label" (hp, floating
## above the spikes, tilted to the camera).
static func spikes(width: float, hp: int) -> Node3D:
	var w := maxf(width, 0.8)
	var root := Node3D.new()
	root.name = "Spikes"
	var body := _tiled_asset("barricade", w, 1.15, 0.8, 2.2)
	if body == null:
		body = Node3D.new()
		body.name = "Body"
		var steel := Mats.solid(STEEL_MID, 0.45, 0.0, 0.25)
		var dark := Mats.solid(STEEL_DARK, 0.6)
		var plate := Mats.solid(PLATE, 0.5)
		var bronze := Mats.solid(BRONZE, 0.4, 0.5)
		var spike := Mats.glow(HOT_RED, 1.5)
		var spike2 := Mats.glow(Color(0.95, 0.16, 0.1), 1.2)
		Mats.part(body, Mats.box(Vector3(w, 0.14, 0.66)), dark, Vector3(0, 0.07, 0))
		Mats.part(body, Mats.box(Vector3(w - 0.06, 0.38, 0.48)), steel, Vector3(0, 0.33, 0))
		Mats.part(body, Mats.box(Vector3(w - 0.02, 0.05, 0.52)), bronze, Vector3(0, 0.54, 0))
		Mats.part(body, Mats.box(Vector3(w - 0.2, 0.1, 0.36)), plate, Vector3(0, 0.6, 0))
		var n := maxi(3, int(w / 0.3))
		for i in n:
			var x := -w * 0.5 + 0.22 + (w - 0.44) * (float(i) / float(n - 1))
			var h := 0.62 + 0.14 * float((i * 7) % 3) / 2.0
			Mats.part(body, Mats.box(Vector3(0.14, 0.08, 0.14)), dark, Vector3(x, 0.66, 0.08))
			Mats.part(body, Mats.crystal(0.075, h), spike, Vector3(x, 0.66 + h * 0.36, 0.12), Vector3(28, 0, (i % 2) * 8.0 - 4.0))
			if i < n - 1:
				var x2 := x + (w - 0.44) / float(n - 1) * 0.5
				Mats.part(body, Mats.crystal(0.06, h * 0.75), spike2, Vector3(x2, 0.66 + h * 0.27, -0.1), Vector3(-24, 0, 0))
		for sgn in [-1.0, 1.0]:
			var px: float = (w * 0.5 - 0.1) * sgn
			Mats.part(body, Mats.box(Vector3(0.24, 0.9, 0.6)), dark, Vector3(px, 0.45, 0))
			Mats.part(body, Mats.box(Vector3(0.28, 0.06, 0.64)), bronze, Vector3(px, 0.9, 0))
			Mats.part(body, Mats.box(Vector3(0.18, 0.5, 0.05)), plate, Vector3(px, 0.5, 0.31))
			Mats.part(body, Mats.cyl(0.07, 0.09, 0.12, 6), steel, Vector3(px, 0.98, 0))
			Mats.part(body, Mats.sphere(0.08, -1, 8, 4), spike, Vector3(px, 1.08, 0))
		Mats.bake(body)
		for sgn in [-1.0, 1.0]:
			_halo(body, Vector3((w * 0.5 - 0.1) * sgn, 1.1, 0.05), Color(1.0, 0.2, 0.1, 0.8), 0.7)
		_halo(body, Vector3(0, 0.95, 0.1), Color(1.0, 0.15, 0.08, 0.35), w * 0.9)
		_stripe_plate(body, Vector2(w - 0.5, 0.2), Vector3(0, 0.29, 0.243))
	root.add_child(body)
	var l := label(str(hp), 170, Color(1.0, 0.95, 0.88))
	l.outline_modulate = Color(0.3, 0.02, 0.02)
	l.position = Vector3(0, 1.75, 0.2)
	l.rotation_degrees = Vector3(-35, 0, 0)
	l.render_priority = 3
	root.add_child(l)
	root.set_meta("label", l)
	root.set_meta("width", w)
	var pts: Array[Vector3] = []
	for i in 4:
		pts.append(Vector3(-w * 0.35 + w * 0.7 * float(i) / 3.0, 0.4, 0.25))
	root.set_meta("damage_points", pts)
	return root


## Legacy name: barricade(hp, width) -> spikes(width, hp).
static func barricade(hp: int, width: float) -> Node3D:
	return spikes(width, hp)


## Rotor hazard: a steel hub post with a red light ring and two long blades with glowing red
## edges and fading motion trails. Meta "spin": the Node3D to rotate about Y. A faint red disc
## on the road telegraphs the sweep area.
static func rotor(radius: float) -> Node3D:
	var rr := maxf(radius, 0.6)
	var root := Node3D.new()
	root.name = "Rotor"
	var over := asset("rotor", AABB(Vector3(-rr, 0, -rr), Vector3(rr * 2.0, 1.1, rr * 2.0)))
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position.y = 0.5
	var hub := Node3D.new()
	if over:
		spin.add_child(over)
		over.position.y = -0.5
	else:
		var dark := Mats.solid(STEEL_DARK, 0.55)
		var steel := Mats.solid(STEEL_MID, 0.4, 0.0, 0.3)
		var bronze := Mats.solid(BRONZE, 0.4, 0.5)
		var red := Mats.glow(HOT_RED, 1.6)
		# Hub base.
		Mats.part(hub, Mats.cyl(0.42, 0.5, 0.12, 8), dark, Vector3(0, 0.06, 0))
		Mats.part(hub, Mats.cyl(0.3, 0.36, 0.22, 8), steel, Vector3(0, 0.23, 0))
		Mats.part(hub, Mats.cyl(0.33, 0.33, 0.05, 8), red, Vector3(0, 0.36, 0))
		Mats.bake(hub)
		# Spinning head and blades.
		Mats.part(spin, Mats.cyl(0.24, 0.28, 0.2, 8), dark, Vector3(0, 0, 0))
		Mats.part(spin, Mats.cyl(0.16, 0.24, 0.12, 8), bronze, Vector3(0, 0.15, 0))
		Mats.part(spin, Mats.sphere(0.12, 0.14, 8, 4), red, Vector3(0, 0.24, 0))
		for sgn in [-1.0, 1.0]:
			var mid: float = (rr * 0.5 + 0.1) * sgn
			var bl := rr - 0.2
			Mats.part(spin, Mats.box(Vector3(bl, 0.1, 0.2)), dark, Vector3(mid, 0, 0))
			Mats.part(spin, Mats.box(Vector3(bl - 0.1, 0.04, 0.22)), steel, Vector3(mid, 0.07, 0))
			# Glowing blade edges on both sides.
			Mats.part(spin, Mats.box(Vector3(bl, 0.06, 0.06)), red, Vector3(mid, 0.0, 0.13))
			Mats.part(spin, Mats.box(Vector3(bl, 0.06, 0.06)), red, Vector3(mid, 0.0, -0.13))
			Mats.part(spin, Mats.box(Vector3(bl * 0.6, 0.03, 0.08)), Mats.solid(PLATE, 0.45), Vector3(mid * 1.1, 0.1, 0))
			Mats.part(spin, Mats.box(Vector3(0.16, 0.18, 0.28)), bronze, Vector3((rr - 0.08) * sgn, 0, 0))
			Mats.part(spin, Mats.cone(0.06, 0.18, 5), red, Vector3((rr + 0.04) * sgn, 0, 0), Vector3(0, 0, -90 * sgn))
		Mats.bake(spin)
		# Motion trails behind each blade.
		var trail := MeshInstance3D.new()
		trail.mesh = _rotor_trail(rr)
		trail.material_override = _trail_mat(false)
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.position.y = 0.06
		spin.add_child(trail)
	root.add_child(hub)
	root.add_child(spin)
	# Danger disc on the road.
	var disc := MeshInstance3D.new()
	disc.mesh = _danger_disc()
	disc.scale = Vector3(rr + 0.15, 1, rr + 0.15)
	disc.position.y = 0.02
	disc.material_override = _trail_mat()
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	_halo(root, Vector3(0, 0.78, 0), Color(1.0, 0.2, 0.1, 0.8), 1.0)
	root.set_meta("spin", spin)
	root.set_meta("radius", rr)
	return root


static func _trail_mat(additive := true) -> StandardMaterial3D:
	var key := "trail%s" % additive
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_is_srgb = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mats[key] = m
	return m


## Two fan-shaped additive trails (60° each) fading behind the blades' leading edges.
static func _rotor_trail(rr: float) -> ArrayMesh:
	var key := "rotor_trail%.2f" % rr
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var span := deg_to_rad(80.0)
	for b in 2:
		var base := PI * b
		for i in segs:
			var a0 := base + span * float(i) / segs
			var a1 := base + span * float(i + 1) / segs
			var f0 := 1.0 - float(i) / segs
			var f1 := 1.0 - float(i + 1) / segs
			var c0 := Color(1.0, 0.16, 0.08, 0.75 * pow(f0, 1.4))
			var c1 := Color(1.0, 0.16, 0.08, 0.75 * pow(f1, 1.4))
			var r0 := 0.3
			var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a0) * rr, 0, sin(a0) * rr),
					Vector3(cos(a1) * rr, 0, sin(a1) * rr), Vector3(cos(a1) * r0, 0, sin(a1) * r0)]
			var cs := [Color(c0, c0.a * 0.3), c0, c1, Color(c1, c1.a * 0.3)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(cs[k])
				st.add_vertex(p[k])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Unit-radius ring on the ground (additive red), scaled per hazard.
static func _danger_disc() -> ArrayMesh:
	if _meshes.has("danger_disc"):
		return _meshes["danger_disc"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var rings := [[0.0, 0.0], [0.7, 0.06], [0.93, 0.2], [0.975, 0.6], [1.0, 0.0]]
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		for j in rings.size() - 1:
			var ra: float = rings[j][0]
			var rb: float = rings[j + 1][0]
			var ca := Color(1.0, 0.2, 0.08, rings[j][1])
			var cb := Color(1.0, 0.2, 0.08, rings[j + 1][1])
			var p := [Vector3(cos(a0) * ra, 0, sin(a0) * ra), Vector3(cos(a0) * rb, 0, sin(a0) * rb),
					Vector3(cos(a1) * rb, 0, sin(a1) * rb), Vector3(cos(a1) * ra, 0, sin(a1) * ra)]
			var cs := [ca, cb, cb, ca]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_color(cs[k])
				st.add_vertex(p[k])
	var mesh := st.commit()
	_meshes["danger_disc"] = mesh
	return mesh


## Sweeper: a rail across the whole bridge (place the root at x = 0) and a heavy bar riding it.
## Meta "bar": the Node3D to move along X (its local x = the sweeper's live x). `width` is the
## bar's width.
static func sweeper(width: float) -> Node3D:
	var w := maxf(width, 0.8)
	var root := Node3D.new()
	root.name = "Sweeper"
	var half := Balance.BRIDGE_HALF
	var dark := Mats.solid(STEEL_DARK, 0.55)
	var steel := Mats.solid(STEEL_MID, 0.4, 0.0, 0.3)
	var bronze := Mats.solid(BRONZE, 0.4, 0.5)
	var red := Mats.glow(HOT_RED, 1.5)
	var ember := Mats.glow(EMBER, 1.3)
	var rail := Node3D.new()
	rail.name = "Rail"
	Mats.part(rail, Mats.box(Vector3(half * 2.0 + 0.4, 0.06, 0.42)), dark, Vector3(0, 0.03, 0))
	for sgn in [-1.0, 1.0]:
		Mats.part(rail, Mats.box(Vector3(half * 2.0 + 0.4, 0.05, 0.05)), bronze, Vector3(0, 0.07, 0.16 * sgn))
		var px: float = (half + 0.05) * sgn
		Mats.part(rail, Mats.box(Vector3(0.34, 1.2, 0.5)), dark, Vector3(px, 0.6, 0))
		Mats.part(rail, Mats.box(Vector3(0.38, 0.06, 0.54)), bronze, Vector3(px, 1.2, 0))
		Mats.part(rail, Mats.box(Vector3(0.06, 0.8, 0.06)), ember, Vector3(px - 0.17 * sgn, 0.6, 0.25))
		Mats.part(rail, Mats.sphere(0.09, -1, 8, 4), red, Vector3(px, 1.32, 0))
	Mats.part(rail, Mats.box(Vector3(half * 2.0, 0.015, 0.05)), ember, Vector3(0, 0.065, 0))
	Mats.bake(rail)
	for sgn in [-1.0, 1.0]:
		_halo(rail, Vector3((half + 0.05) * sgn, 1.35, 0.05), Color(1.0, 0.2, 0.1, 0.8), 0.7)
	root.add_child(rail)
	var bar := Node3D.new()
	bar.name = "Bar"
	var over := asset("sweeper", AABB(Vector3(-w * 0.5, 0, -0.3), Vector3(w, 0.9, 0.6)))
	if over:
		bar.add_child(over)
	else:
		Mats.part(bar, Mats.box(Vector3(0.7, 0.16, 0.46)), dark, Vector3(0, 0.12, 0))
		Mats.part(bar, Mats.box(Vector3(w, 0.32, 0.3)), steel, Vector3(0, 0.42, 0))
		Mats.part(bar, Mats.box(Vector3(w + 0.04, 0.05, 0.34)), bronze, Vector3(0, 0.6, 0))
		Mats.part(bar, Mats.box(Vector3(w - 0.2, 0.14, 0.24)), Mats.solid(PLATE, 0.5), Vector3(0, 0.68, 0))
		for sgn in [-1.0, 1.0]:
			# Glowing blade edges front and back.
			Mats.part(bar, Mats.prism(Vector3(0.1, w - 0.1, 0.06)), red, Vector3(0, 0.42, 0.17 * sgn), Vector3(0, 0, 90))
			Mats.part(bar, Mats.box(Vector3(0.16, 0.5, 0.36)), dark, Vector3((w * 0.5 - 0.02) * sgn, 0.45, 0))
		var n := maxi(2, int(w / 0.35))
		for i in n:
			var x := -w * 0.5 + 0.2 + (w - 0.4) * float(i) / float(n - 1)
			Mats.part(bar, Mats.crystal(0.06, 0.38), red, Vector3(x, 0.84, 0))
		Mats.bake(bar)
		_stripe_plate(bar, Vector2(w - 0.4, 0.14), Vector3(0, 0.36, 0.152))
		_halo(bar, Vector3(0, 0.8, 0.05), Color(1.0, 0.18, 0.08, 0.45), w * 0.85)
	root.add_child(bar)
	root.set_meta("bar", bar)
	root.set_meta("width", w)
	return root


## Railing turret: a steel pedestal clamped to the railing with a rotating armoured head, twin
## barrels with ember tips and a red sensor eye. Metas: "head" (yaw pivot, faces +Z at 0),
## "muzzle" (Node3D marker at the barrels' tip, child of head), "label" (hp, billboard).
static func turret() -> Node3D:
	var root := Node3D.new()
	root.name = "Turret"
	var dark := Mats.solid(STEEL_DARK, 0.55)
	var steel := Mats.solid(STEEL_MID, 0.4, 0.0, 0.3)
	var bronze := Mats.solid(BRONZE, 0.4, 0.5)
	var plate := Mats.solid(PLATE, 0.45)
	var plate_d := Mats.solid(PLATE_DARK, 0.6)
	var red := Mats.glow(HOT_RED, 1.7)
	var ember := Mats.glow(EMBER, 1.4)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.95
	var split := _split_asset("turret", AABB(Vector3(-0.7, 0, -0.7), Vector3(1.4, 1.6, 1.4)), TURRET_SPLIT)
	var over: Node3D = null
	if not split.is_empty():
		over = split["base"]
		_recolor_asset(over, EMBER_ASSET_SHADER, Color.WHITE)
		_recolor_asset(split["top"], EMBER_ASSET_SHADER, Color.WHITE)
		root.add_child(over)
		head.position = split["pivot"]
		var top := split["top"] as Node3D
		top.rotation.y = TURRET_YAW
		head.add_child(top)
	else:
		var base := Node3D.new()
		base.name = "Base"
		# Clamp on the railing, a stepped pedestal and a slewing ring with an ember band.
		Mats.part(base, Mats.box(Vector3(0.9, 0.16, 0.9)), dark, Vector3(0, 0.08, 0))
		Mats.part(base, Mats.box(Vector3(0.96, 0.05, 0.96)), bronze, Vector3(0, 0.17, 0))
		Mats.part(base, Mats.cyl(0.3, 0.42, 0.5, 8), steel, Vector3(0, 0.44, 0))
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			Mats.part(base, Mats.box(Vector3(0.12, 0.46, 0.3)), plate_d, Vector3(cos(a) * 0.36, 0.38, sin(a) * 0.36), Vector3(0, -rad_to_deg(a), 10))
		Mats.part(base, Mats.cyl(0.4, 0.4, 0.06, 10), ember, Vector3(0, 0.72, 0))
		Mats.part(base, Mats.cyl(0.42, 0.36, 0.14, 10), dark, Vector3(0, 0.82, 0))
		Mats.bake(base)
		root.add_child(base)
		# Armoured head: wedge-fronted housing, side cheek plates, visor band and twin barrels.
		Mats.part(head, Mats.box(Vector3(0.7, 0.4, 0.62)), dark, Vector3(0, 0.12, -0.06))
		Mats.part(head, Mats.box(Vector3(0.64, 0.14, 0.56)), plate, Vector3(0, 0.38, -0.08))
		Mats.part(head, Mats.box(Vector3(0.66, 0.04, 0.58)), bronze, Vector3(0, 0.3, -0.08))
		Mats.part(head, Mats.prism(Vector3(0.7, 0.26, 0.4)), plate, Vector3(0, 0.22, 0.38), Vector3(-90, 0, 0))
		Mats.part(head, Mats.box(Vector3(0.5, 0.07, 0.06)), red, Vector3(0, 0.2, 0.47), Vector3(-30, 0, 0))
		for sgn in [-1.0, 1.0]:
			Mats.part(head, Mats.box(Vector3(0.12, 0.5, 0.74)), steel, Vector3(0.4 * sgn, 0.12, -0.06))
			Mats.part(head, Mats.box(Vector3(0.05, 0.3, 0.5)), plate, Vector3(0.47 * sgn, 0.14, -0.06))
			Mats.part(head, Mats.cyl(0.075, 0.085, 0.7, 8), dark, Vector3(0.17 * sgn, 0.0, 0.62), Vector3(90, 0, 0))
			Mats.part(head, Mats.cyl(0.1, 0.1, 0.12, 8), bronze, Vector3(0.17 * sgn, 0.0, 0.45), Vector3(90, 0, 0))
			Mats.part(head, Mats.cyl(0.095, 0.08, 0.1, 8), bronze, Vector3(0.17 * sgn, 0.0, 0.94), Vector3(90, 0, 0))
			Mats.part(head, Mats.cyl(0.05, 0.05, 0.03, 8), ember, Vector3(0.17 * sgn, 0.0, 1.0), Vector3(90, 0, 0))
		# Sensor mast with a beacon.
		Mats.part(head, Mats.box(Vector3(0.05, 0.36, 0.05)), steel, Vector3(-0.22, 0.6, -0.26))
		Mats.part(head, Mats.sphere(0.045, -1, 6, 3), red, Vector3(-0.22, 0.8, -0.26))
		Mats.bake(head)
		_halo(head, Vector3(0, 0.22, 0.56), Color(1.0, 0.12, 0.06, 0.8), 0.7)
		_halo(head, Vector3(-0.22, 0.8, -0.24), Color(1.0, 0.15, 0.06, 0.8), 0.3)
		root.add_child(head)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.0, 1.02)
	if not split.is_empty():
		muzzle.position = Basis(Vector3.UP, TURRET_YAW) * (split["tip"] as Vector3)
	head.add_child(muzzle)
	if over:
		root.add_child(head)
	var l := label("", 130, Color(1.0, 0.9, 0.85), true)
	l.outline_modulate = Color(0.3, 0.02, 0.02)
	l.position = Vector3(0, 1.85, 0)
	l.render_priority = 3
	root.add_child(l)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)
	root.set_meta("label", l)
	root.set_meta("damage_points", [Vector3(0, 0.5, 0.42), Vector3(0, 1.1, 0.4)] as Array[Vector3])
	return root


## Crystal geode: a cracked-open rock shell of dark violet stone holding a glowing crystal
## cluster tinted by the reward (army ice-blue, coins gold, ult violet). Meta "label".
static func geode(reward: String) -> Node3D:
	var col: Color = REWARD_COLORS.get(reward, REWARD_COLORS["army"])
	var root := Node3D.new()
	root.name = "Geode"
	var over := asset("geode", AABB(Vector3(-0.9, 0, -0.9), Vector3(1.8, 1.8, 1.8)))
	if over:
		_recolor_asset(over, CRYSTAL_ASSET_SHADER, col)
		root.add_child(over)
	else:
		var body := Node3D.new()
		body.name = "Body"
		var rock := Mats.solid(Color(0.3, 0.25, 0.4), 0.85)
		var rock2 := Mats.solid(Color(0.42, 0.34, 0.55), 0.8)
		var rim := Mats.solid(col.lerp(Color.WHITE, 0.5), 0.35, 0.0, 0.4)
		var glow := Mats.glow(col, 1.5)
		var glow2 := Mats.glow(col.lerp(Color.WHITE, 0.3), 1.2)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(reward) + 11
		# Shell: a ring of faceted boulders around a hollow, the front lower so the crystals show.
		var n := 7
		for i in n:
			var a := TAU * float(i) / n + 0.3
			var front := 0.5 + 0.5 * sin(a)    # +Z side is lower
			var s := 0.36 - front * 0.1 + rng.randf_range(-0.03, 0.04)
			var p := Vector3(cos(a) * 0.5, s * 0.75, sin(a) * 0.5)
			Mats.part(body, Mats.sphere(s, s * 1.5, 7, 4), rock if i % 2 == 0 else rock2, p, Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))
			Mats.part(body, Mats.crystal(0.07, 0.2), rim, p * 0.8 + Vector3(0, s * 0.7, 0), Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)))
		Mats.part(body, Mats.cyl(0.55, 0.62, 0.16, 9), rock, Vector3(0, 0.08, 0))
		# Crystal cluster.
		Mats.part(body, Mats.crystal(0.22, 1.15), glow, Vector3(0, 0.62, 0), Vector3(0, 0, 4))
		var cluster := [[Vector3(0.22, 0.42, 0.12), Vector3(18, 0, -28), 0.14, 0.7], [Vector3(-0.24, 0.4, 0.05), Vector3(-10, 0, 30), 0.14, 0.75],
				[Vector3(0.05, 0.36, 0.28), Vector3(35, 0, 6), 0.12, 0.6], [Vector3(-0.1, 0.42, -0.22), Vector3(-30, 0, 12), 0.13, 0.7],
				[Vector3(0.2, 0.38, -0.2), Vector3(-24, 0, -24), 0.1, 0.55]]
		for c in cluster:
			Mats.part(body, Mats.crystal(float(c[2]), float(c[3])), glow2 if c[3] < 0.65 else glow, c[0], c[1])
		Mats.bake(body)
		root.add_child(body)
		_halo(root, Vector3(0, 0.8, 0.05), Color(col.r, col.g, col.b, 0.75), 1.8)
		_halo(root, Vector3(0, 1.15, 0.0), Color(1, 1, 1, 0.4), 0.5)
	var l := label("", 130, Color.WHITE, true)
	l.outline_modulate = Color(col.r * 0.25, col.g * 0.25, col.b * 0.3)
	l.position = Vector3(0, 1.75, 0)
	l.render_priority = 3
	root.add_child(l)
	root.set_meta("label", l)
	root.set_meta("reward", reward)
	return root


# ================================================================== fortress

## The enemy citadel across the bridge (`width` = the bridge width it spans): a dark steel wall
## faced with red armour plates and orange window slits, a gatehouse with a glowing energy door
## and a horned emblem, two octagonal towers with spiked crowns and red beacons, a keep behind,
## and red banners. Metas: "label" (hp), "door" (energy door material), "damage_points".
static func fortress(width: float, hp: int) -> Node3D:
	var w := maxf(width, 4.0)
	var root := Node3D.new()
	root.name = "Fortress"
	var tower_x := w * 0.5 + 1.15
	# The owner's model spans the bridge with its towers just past the railings, so the whole
	# fortress fits the siege camera.
	var fit_w := w + FORTRESS_OVERHANG * 2.0
	var over := asset("fortress", AABB(Vector3(-fit_w * 0.5, 0, -3.0), Vector3(fit_w, 10.0, 3.6)))
	var points: Array[Vector3] = []
	var label_y := 4.45
	var label_z := 1.6
	if over:
		_recolor_asset(over, EMBER_ASSET_SHADER, Color.WHITE)
		root.add_child(over)
		var box := _mesh_aabb(over)
		root.set_meta("visual_width", box.size.x)
		label_y = box.size.y * 0.66
		label_z = box.end.z + 0.25
		for i in 8:
			points.append(Vector3(randf_range(-w * 0.45, w * 0.45), randf_range(0.6, box.size.y * 0.75), box.end.z - 0.1))
	else:
		var body := Node3D.new()
		body.name = "Body"
		var dark := Mats.solid(STEEL_DARK, 0.6)
		var mid := Mats.solid(STEEL_MID, 0.45, 0.0, 0.25)
		var plate := Mats.solid(PLATE, 0.45)
		var plate_d := Mats.solid(PLATE_DARK, 0.6)
		var bronze := Mats.solid(BRONZE, 0.35, 0.55)
		var ember := Mats.glow(EMBER, 1.4)
		var red := Mats.glow(HOT_RED, 1.7)
		var wall_w := w + 1.2
		var wall_h := 3.6
		var base_h := 0.5
		# Plinth with an ember strip.
		Mats.part(body, Mats.box(Vector3(wall_w + 3.4, base_h, 3.6)), dark, Vector3(0, base_h * 0.5, -0.6))
		Mats.part(body, Mats.box(Vector3(wall_w + 3.5, 0.08, 3.7)), bronze, Vector3(0, base_h, -0.6))
		Mats.part(body, Mats.box(Vector3(wall_w + 3.2, 0.06, 0.04)), ember, Vector3(0, 0.3, 1.21))
		# Curtain wall.
		var wz := 0.35
		Mats.part(body, Mats.box(Vector3(wall_w, wall_h, 1.8)), mid, Vector3(0, base_h + wall_h * 0.5, wz - 0.9))
		Mats.part(body, Mats.box(Vector3(wall_w + 0.1, 0.16, 1.9)), bronze, Vector3(0, base_h + wall_h, wz - 0.9))
		# Armour plates in two rows, slanted, with window slits between.
		var gate_half := 1.9
		var span := (wall_w * 0.5 - gate_half)
		var cols := maxi(1, int(span / 1.05))
		var pw := span / cols
		for sgn in [-1.0, 1.0]:
			for c in cols:
				var x: float = (gate_half + pw * (c + 0.5)) * sgn
				for row in 2:
					var y := base_h + 0.95 + row * 1.6
					Mats.part(body, Mats.box(Vector3(pw - 0.12, 1.35, 0.14)), plate if (c + row) % 2 == 0 else plate_d, Vector3(x, y, wz + 0.05), Vector3(-6 if row == 0 else 6, 0, 0))
					points.append(Vector3(x, y, wz + 0.15))
				Mats.part(body, Mats.box(Vector3(pw * 0.5, 0.1, 0.06)), ember, Vector3(x, base_h + 1.75, wz + 0.02))
				Mats.part(body, Mats.box(Vector3(0.1, 0.1, 0.18)), bronze, Vector3(x - pw * 0.5 + 0.05, base_h + 1.75, wz + 0.05))
		# Battlements with red caps and spikes.
		var merlons := int(wall_w / 0.75)
		for i in merlons:
			var x := -wall_w * 0.5 + (i + 0.5) * wall_w / merlons
			if absf(x) < gate_half:
				continue
			Mats.part(body, Mats.box(Vector3(0.48, 0.5, 0.5)), dark, Vector3(x, base_h + wall_h + 0.33, wz - 0.15))
			Mats.part(body, Mats.prism(Vector3(0.48, 0.22, 0.5)), plate, Vector3(x, base_h + wall_h + 0.69, wz - 0.15))
		# Gatehouse.
		var gh_h := 5.4
		var gz := wz + 0.55
		Mats.part(body, Mats.box(Vector3(gate_half * 2.0, gh_h, 2.6)), mid, Vector3(0, base_h + gh_h * 0.5, gz - 1.3))
		for sgn in [-1.0, 1.0]:
			Mats.part(body, Mats.box(Vector3(0.6, gh_h + 0.3, 2.8)), dark, Vector3((gate_half - 0.1) * sgn, base_h + (gh_h + 0.3) * 0.5, gz - 1.25))
			Mats.part(body, Mats.box(Vector3(0.66, 0.12, 2.9)), bronze, Vector3((gate_half - 0.1) * sgn, base_h + gh_h + 0.3, gz - 1.25))
			Mats.part(body, Mats.box(Vector3(0.4, 1.8, 0.12)), plate, Vector3((gate_half - 0.1) * sgn, base_h + 3.6, gz + 0.16))
			Mats.part(body, Mats.box(Vector3(0.08, 1.2, 0.06)), ember, Vector3((gate_half - 0.1) * sgn, base_h + 3.6, gz + 0.24))
			Mats.part(body, Mats.cone(0.2, 0.9, 5), plate, Vector3((gate_half - 0.1) * sgn, base_h + gh_h + 0.8, gz - 0.5))
			Mats.part(body, Mats.sphere(0.12, -1, 8, 4), red, Vector3((gate_half - 0.1) * sgn, base_h + gh_h + 1.3, gz - 0.5))
			# Door jambs.
			Mats.part(body, Mats.box(Vector3(0.36, 2.9, 0.34)), dark, Vector3(1.22 * sgn, base_h + 1.45, gz + 0.06))
			Mats.part(body, Mats.box(Vector3(0.08, 2.6, 0.08)), bronze, Vector3(1.05 * sgn, base_h + 1.4, gz + 0.24))
		Mats.part(body, Mats.box(Vector3(2.9, 0.42, 0.4)), dark, Vector3(0, base_h + 3.05, gz + 0.08))
		Mats.part(body, Mats.box(Vector3(3.0, 0.08, 0.44)), bronze, Vector3(0, base_h + 3.28, gz + 0.08))
		Mats.part(body, Mats.box(Vector3(2.2, 2.75, 0.2)), Mats.solid(Color(0.05, 0.03, 0.04)), Vector3(0, base_h + 1.38, gz - 0.12))
		# Dark plaque with a bronze frame behind the hp number, ember slits under the crown.
		Mats.part(body, Mats.box(Vector3(2.75, 1.45, 0.12)), Mats.solid(Color(0.08, 0.06, 0.09), 0.5), Vector3(0, base_h + 3.95, gz + 0.04))
		Mats.part(body, Mats.box(Vector3(2.95, 0.1, 0.16)), bronze, Vector3(0, base_h + 4.72, gz + 0.04))
		Mats.part(body, Mats.box(Vector3(2.95, 0.1, 0.16)), bronze, Vector3(0, base_h + 3.2, gz + 0.04))
		for sgn in [-1.0, 1.0]:
			Mats.part(body, Mats.box(Vector3(0.1, 1.6, 0.16)), bronze, Vector3(1.43 * sgn, base_h + 3.96, gz + 0.04))
		for k in 5:
			Mats.part(body, Mats.box(Vector3(0.12, 0.34, 0.05)), ember, Vector3(-0.9 + k * 0.45, base_h + 5.05, gz + 0.02))
		# Horned emblem on the gatehouse crown.
		var ey := base_h + gh_h + 0.55
		Mats.part(body, Mats.box(Vector3(0.95, 0.95, 0.25)), plate, Vector3(0, ey, gz - 0.25), Vector3(0, 0, 45))
		Mats.part(body, Mats.box(Vector3(0.62, 0.62, 0.3)), dark, Vector3(0, ey, gz - 0.22), Vector3(0, 0, 45))
		Mats.part(body, Mats.box(Vector3(0.4, 0.08, 0.06)), ember, Vector3(0, ey + 0.02, gz - 0.05))
		for sgn in [-1.0, 1.0]:
			Mats.part(body, Mats.cone(0.15, 0.9, 5), Mats.solid(Color(0.95, 0.88, 0.75), 0.6), Vector3(0.55 * sgn, ey + 0.45, gz - 0.25), Vector3(0, 0, -38 * sgn))
		# Towers.
		for sgn in [-1.0, 1.0]:
			var tx: float = tower_x * sgn
			var tz := wz - 0.4
			var th := 6.6
			Mats.part(body, Mats.cyl(1.32, 1.5, 0.6, 8), dark, Vector3(tx, base_h + 0.3, tz))
			Mats.part(body, Mats.cyl(1.12, 1.3, th, 8), mid, Vector3(tx, base_h + th * 0.5, tz))
			for y in [2.0, 4.6]:
				Mats.part(body, Mats.cyl(1.24, 1.24, 0.34, 8), plate, Vector3(tx, base_h + y, tz))
				Mats.part(body, Mats.cyl(1.27, 1.27, 0.06, 8), bronze, Vector3(tx, base_h + y + 0.2, tz))
			# Window slits facing the bridge.
			for row in 3:
				for k in [-1.0, 0.0, 1.0]:
					var a: float = k * 0.5
					var y2 := base_h + 1.2 + row * 1.35 + (0.3 if row == 1 else 0.0)
					if row == 1 and k == 0.0:
						continue
					var p := Vector3(tx + sin(a) * 1.18, y2, tz + cos(a) * 1.18)
					Mats.part(body, Mats.box(Vector3(0.16, 0.5, 0.08)), ember, p, Vector3(0, rad_to_deg(a), 0))
			points.append(Vector3(tx, base_h + 3.2, tz + 1.2))
			points.append(Vector3(tx, base_h + 5.4, tz + 1.15))
			# Spiked crown, roof, spire and beacon.
			Mats.part(body, Mats.cyl(1.45, 1.22, 0.55, 8), dark, Vector3(tx, base_h + th + 0.27, tz))
			Mats.part(body, Mats.cyl(1.48, 1.48, 0.06, 8), bronze, Vector3(tx, base_h + th + 0.56, tz))
			for i in 8:
				var a2 := TAU * i / 8.0 + PI / 8.0
				Mats.part(body, Mats.cone(0.16, 0.65, 5), plate, Vector3(tx + cos(a2) * 1.28, base_h + th + 0.85, tz + sin(a2) * 1.28), Vector3(sin(a2) * 18.0, 0, -cos(a2) * 18.0))
			Mats.part(body, Mats.cone(1.05, 2.3, 8), plate_d, Vector3(tx, base_h + th + 1.7, tz))
			Mats.part(body, Mats.cyl(0.05, 0.08, 1.3, 6), mid, Vector3(tx, base_h + th + 3.3, tz))
			Mats.part(body, Mats.crystal(0.2, 0.7), red, Vector3(tx, base_h + th + 4.1, tz))
			# Banner hanging down the tower front.
			Mats.part(body, Mats.box(Vector3(0.12, 0.12, 1.0)), bronze, Vector3(tx, base_h + th - 0.4, tz + 1.05))
			Mats.part(body, Mats.box(Vector3(0.85, 2.3, 0.05)), plate, Vector3(tx, base_h + th - 1.6, tz + 1.5))
			Mats.part(body, Mats.box(Vector3(0.36, 0.36, 0.06)), ember, Vector3(tx, base_h + th - 1.3, tz + 1.53), Vector3(0, 0, 45))
			Mats.part(body, Mats.prism(Vector3(0.85, 0.35, 0.05)), plate, Vector3(tx, base_h + th - 2.9, tz + 1.5), Vector3(0, 0, 180))
		# Wall banners between the gatehouse and the towers.
		for sgn in [-1.0, 1.0]:
			var bx: float = (gate_half + span * 0.5) * sgn
			Mats.part(body, Mats.box(Vector3(1.25, 0.1, 0.12)), bronze, Vector3(bx, base_h + wall_h - 0.1, wz + 0.25))
			Mats.part(body, Mats.box(Vector3(1.0, 2.6, 0.05)), plate, Vector3(bx, base_h + wall_h - 1.45, wz + 0.25))
			Mats.part(body, Mats.box(Vector3(0.8, 2.4, 0.06)), plate_d, Vector3(bx, base_h + wall_h - 1.45, wz + 0.23))
			Mats.part(body, Mats.box(Vector3(0.44, 0.44, 0.07)), ember, Vector3(bx, base_h + wall_h - 1.1, wz + 0.29), Vector3(0, 0, 45))
			Mats.part(body, Mats.box(Vector3(0.24, 0.24, 0.08)), dark, Vector3(bx, base_h + wall_h - 1.1, wz + 0.31), Vector3(0, 0, 45))
			Mats.part(body, Mats.prism(Vector3(1.0, 0.4, 0.05)), plate, Vector3(bx, base_h + wall_h - 2.95, wz + 0.25), Vector3(0, 0, 180))
		# Keep behind the wall.
		var kz := wz - 2.6
		Mats.part(body, Mats.box(Vector3(3.2, 7.6, 2.4)), dark, Vector3(0, base_h + 3.8, kz))
		Mats.part(body, Mats.box(Vector3(3.4, 0.14, 2.6)), bronze, Vector3(0, base_h + 7.6, kz))
		Mats.part(body, Mats.box(Vector3(0.3, 2.6, 0.08)), ember, Vector3(0, base_h + 6.2, kz + 1.22))
		for sgn in [-1.0, 1.0]:
			Mats.part(body, Mats.box(Vector3(0.18, 1.4, 0.08)), ember, Vector3(0.9 * sgn, base_h + 6.6, kz + 1.22))
		Mats.part(body, Mats.cone(1.4, 3.2, 4), plate_d, Vector3(0, base_h + 9.2, kz), Vector3(0, 45, 0))
		Mats.part(body, Mats.crystal(0.3, 1.1), red, Vector3(0, base_h + 11.2, kz))
		points.append(Vector3(-0.8, base_h + 4.3, gz + 0.2))
		points.append(Vector3(0.8, base_h + 4.6, gz + 0.2))
		Mats.bake(body)
		root.add_child(body)
		# Energy door (animated field shader, red).
		var door := MeshInstance3D.new()
		var dq := QuadMesh.new()
		dq.size = Vector2(2.1, 2.65)
		door.mesh = dq
		door.position = Vector3(0, base_h + 1.33, gz - 0.0)
		var dm := ShaderMaterial.new()
		dm.shader = FIELD_SHADER
		dm.set_shader_parameter("noise_tex", NOISE_TEX)
		dm.set_shader_parameter("size", Vector2(2.1, 2.65))
		dm.set_shader_parameter("color", Color(1.0, 0.24, 0.08))
		dm.set_shader_parameter("core_color", Color(1.0, 0.75, 0.4))
		dm.set_shader_parameter("opacity", 1.25)
		dm.set_shader_parameter("seed", 0.37)
		door.material_override = dm
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(door)
		root.set_meta("door", dm)
		# Glow halos on beacons and the door.
		for sgn in [-1.0, 1.0]:
			_halo(root, Vector3(tower_x * sgn, base_h + 6.6 + 4.1, wz - 0.4), Color(1.0, 0.2, 0.1, 0.9), 1.6)
			_halo(root, Vector3((gate_half - 0.1) * sgn, base_h + gh_h + 1.3, gz - 0.4), Color(1.0, 0.2, 0.1, 0.8), 0.8)
		_halo(root, Vector3(0, base_h + 11.2, kz), Color(1.0, 0.2, 0.1, 0.9), 2.0)
		_halo(root, Vector3(0, base_h + 1.4, gz + 0.3), Color(1.0, 0.3, 0.1, 0.35), 3.4)
	var l := label(str(hp), 300, Color(1.0, 0.94, 0.86))
	l.outline_modulate = Color(0.28, 0.02, 0.02)
	l.outline_size = 52
	l.position = Vector3(0, label_y, label_z)
	l.rotation_degrees = Vector3(-8, 0, 0)
	# Always on top: the gate's front plates hid the hp counter from the high siege camera.
	l.no_depth_test = true
	l.render_priority = 5
	l.outline_render_priority = 4
	l.modulate = Color(1.0, 0.86, 0.8)
	_fit_label(l, 2.6, 1.15)
	root.add_child(l)
	root.set_meta("label", l)
	root.set_meta("damage_points", points)
	root.set_meta("width", w)
	return root


# ================================================================== damage states

## Shows battle damage on a fortress, barricade, crate or any model: `ratio` is the damage taken,
## 0 = intact .. 1 = wrecked. Stages: > 0.2 glowing ember cracks, > 0.45 more cracks and spark
## showers, > 0.7 black smoke plumes and the fortress door flickers. Idempotent (only grows).
## Places effects on the node's "damage_points" meta when it has one, else on the front face of
## its mesh bounds.
static func damage(node: Node3D, ratio: float) -> void:
	if node == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	var stage := 0
	if ratio > 0.2:
		stage = 1
	if ratio > 0.45:
		stage = 2
	if ratio > 0.7:
		stage = 3
	var have := int(node.get_meta("damage_stage", 0))
	if stage <= have:
		return
	node.set_meta("damage_stage", stage)
	var fx: Node3D = node.get_node_or_null("DamageFx") as Node3D
	if fx == null:
		fx = Node3D.new()
		fx.name = "DamageFx"
		node.add_child(fx)
	var pts := _damage_points(node)
	if pts.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = node.get_instance_id() + stage * 7919
	var big := float(node.get_meta("width", 2.0)) > 4.0
	for s in range(have + 1, stage + 1):
		match s:
			1:
				for i in mini(pts.size(), 4 if big else 2):
					_crack(fx, pts[(i * 3) % pts.size()], rng, 1.2 if big else 0.35)
			2:
				for i in mini(pts.size(), 5 if big else 2):
					_crack(fx, pts[(i * 3 + 1) % pts.size()], rng, 1.4 if big else 0.42)
				for i in (3 if big else 1):
					_sparks(fx, pts[rng.randi() % pts.size()], 1.0 if big else 0.6)
			3:
				for i in (3 if big else 1):
					var p := pts[rng.randi() % pts.size()]
					_smoke(fx, p + Vector3(0, 0.3, 0), 1.0 if big else 0.55)
				for i in (2 if big else 1):
					_sparks(fx, pts[rng.randi() % pts.size()], 1.2 if big else 0.7)
				if node.has_meta("door"):
					var dm := node.get_meta("door") as ShaderMaterial
					dm.set_shader_parameter("turbulence", 2.0)
					dm.set_shader_parameter("opacity", 0.9)


static func _damage_points(node: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if node.has_meta("damage_points"):
		for p in node.get_meta("damage_points"):
			out.append(p)
		if not out.is_empty():
			return out
	var box := _mesh_aabb(node, true)
	if box.size.length() < 1e-4:
		return out
	var front := box.end.z - 0.02
	for i in 6:
		var fx := 0.15 + 0.7 * fposmod(i * 0.618, 1.0)
		var fy := 0.15 + 0.35 * fposmod(i * 0.382 + 0.2, 1.0)
		out.append(Vector3(box.position.x + box.size.x * fx, box.position.y + box.size.y * fy, front))
	return out


## Jagged glowing crack on a front face around `p` (in the XY plane).
static func _crack(parent: Node3D, p: Vector3, rng: RandomNumberGenerator, size: float) -> void:
	var crack := Node3D.new()
	crack.position = p + Vector3(rng.randf_range(-0.2, 0.2) * size, rng.randf_range(-0.2, 0.2) * size, 0.04)
	var hot := Mats.glow(EMBER, 1.8)
	var dark := Mats.solid(Color(0.04, 0.03, 0.03))
	for branch in 2 + rng.randi() % 2:
		var cur := Vector2.ZERO
		var dir := Vector2.from_angle(rng.randf_range(0, TAU))
		var w := 0.07 * size
		for seg in 4:
			var l := rng.randf_range(0.15, 0.3) * size
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			var nxt := cur + dir * l
			var mid := (cur + nxt) * 0.5
			var ang := rad_to_deg(dir.angle())
			# One cached unit box scaled per segment (random sizes would each be a new mesh kept
			# forever in the Mats cache); bake() applies the scale, so the geometry is the same.
			Mats.part(crack, Mats.box(Vector3.ONE), dark, Vector3(mid.x, mid.y, 0), Vector3(0, 0, ang), Vector3(l + w * 0.5, w * 1.8, 0.02), false)
			Mats.part(crack, Mats.box(Vector3.ONE), hot, Vector3(mid.x, mid.y, 0.01), Vector3(0, 0, ang), Vector3(l, w * 0.7, 0.03), false)
			cur = nxt
			w *= 0.75
	Mats.bake(crack)
	_halo(crack, Vector3(0, 0, 0.08), Color(1.0, 0.35, 0.08, 0.5), 0.9 * size)
	parent.add_child(crack)


static func _sparks(parent: Node3D, p: Vector3, size: float) -> void:
	var e := CPUParticles3D.new()
	e.position = p + Vector3(0, 0, 0.1)
	e.amount = int(26 * size)
	e.lifetime = 0.8
	e.preprocess = e.lifetime
	e.explosiveness = 0.0
	e.randomness = 0.6
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07) * size
	e.mesh = q
	e.material_override = Mats.particle(true)
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.2 * size
	e.direction = Vector3(0, 1, 0.6)
	e.spread = 50.0
	e.initial_velocity_min = 1.5 * size
	e.initial_velocity_max = 3.6 * size
	e.gravity = Vector3(0, -7.0, 0)
	e.scale_amount_min = 0.5
	e.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	g.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	g.add_point(0.4, Color(1.0, 0.6, 0.15, 1.0))
	e.color_ramp = g
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(e)


static func _smoke(parent: Node3D, p: Vector3, size: float) -> void:
	var e := CPUParticles3D.new()
	e.position = p
	e.amount = int(22 * size) + 6
	e.lifetime = 2.6
	# Unemitted instances render as black billboards in gl_compatibility (alpha-blended
	# particles), so start fully populated.
	e.preprocess = e.lifetime
	e.randomness = 0.5
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8) * size
	e.mesh = q
	e.material_override = Mats.particle(false)
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.3 * size
	e.direction = Vector3(0.15, 1, 0.1)
	e.spread = 12.0
	e.initial_velocity_min = 0.9 * size
	e.initial_velocity_max = 1.6 * size
	e.gravity = Vector3(0.25, 0.3, 0)
	e.damping_min = 0.2
	e.damping_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.4))
	e.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.2, 0.7))
	g.set_color(1, Color(0.3, 0.28, 0.32, 0.0))
	g.add_point(0.12, Color(0.55, 0.45, 0.42, 0.8))
	g.add_point(0.55, Color(0.4, 0.38, 0.42, 0.5))
	e.color_ramp = g
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(e)


# ================================================================== finale stairs

## Multiplier stairs climbing towards -Z: one step per multiplier (STEP_H high, STEP_D deep,
## `width` wide), coloured along blue → violet → gold, with crystal lamps on silver balusters,
## glowing nosings and a "×1.2" label on each riser. A golden crystal monument with orbit rings
## crowns the top. Meta "steps": Array[Vector3], the top centre of each step (local).
static func stairs(mults: Array, width: float) -> Node3D:
	var w := maxf(width, 2.0)
	var n := mults.size()
	var root := Node3D.new()
	root.name = "Stairs"
	var steps: Array[Vector3] = []
	var body := Node3D.new()
	body.name = "Body"
	var silver := Mats.solid(SILVER, 0.4, 0.0, 0.3)
	var shade := Mats.solid(SILVER_SHADE, 0.5)
	var gold := Mats.solid(GOLD, 0.35, 0.6)
	var halos: Array = []
	for i in n:
		var k := float(i) / maxf(1.0, float(n - 1))
		var c := _stairs_color(k)
		var top := (i + 1) * STEP_H
		var z0 := -i * STEP_D
		var zc := z0 - STEP_D * 0.5
		# Solid block down to the ground, a lighter inset tread and a glowing nosing.
		Mats.part(body, Mats.box(Vector3(w, top, STEP_D)), Mats.solid(c.darkened(0.3), 0.6), Vector3(0, top * 0.5, zc))
		Mats.part(body, Mats.box(Vector3(w - 0.3, 0.06, STEP_D - 0.24)), Mats.solid(c.lerp(Color.WHITE, 0.08), 0.4, 0.0, 0.2), Vector3(0, top + 0.03, zc - 0.04))
		Mats.part(body, Mats.box(Vector3(w, 0.07, 0.1)), Mats.glow(c.lerp(Color.WHITE, 0.2), 1.4), Vector3(0, top - 0.02, z0 + 0.0))
		Mats.part(body, Mats.box(Vector3(w - 0.4, STEP_H - 0.12, 0.04)), Mats.solid(c.darkened(0.6), 0.5), Vector3(0, top - STEP_H * 0.5 - 0.02, z0 + 0.01))
		# Balusters with crystal lamps on both sides.
		for sgn in [-1.0, 1.0]:
			var x: float = (w * 0.5 + 0.16) * sgn
			Mats.part(body, Mats.box(Vector3(0.3, top + 0.16, STEP_D)), shade, Vector3(x, (top + 0.16) * 0.5, zc))
			Mats.part(body, Mats.box(Vector3(0.36, 0.06, STEP_D + 0.02)), gold, Vector3(x, top + 0.17, zc))
			Mats.part(body, Mats.box(Vector3(0.14, 0.5, 0.14)), silver, Vector3(x, top + 0.45, z0 - 0.2))
			Mats.part(body, Mats.crystal(0.1, 0.36), Mats.glow(c, 1.5), Vector3(x, top + 0.86, z0 - 0.2))
			halos.append([Vector3(x, top + 0.86, z0 - 0.2), c])
		steps.append(Vector3(0, top, zc))
	# Monument on the top platform.
	var tz := -n * STEP_D - 1.4
	var th := (n + 0.0) * STEP_H
	Mats.part(body, Mats.box(Vector3(w + 0.6, th, 2.8)), Mats.solid(Color(0.55, 0.42, 0.2), 0.6), Vector3(0, th * 0.5, tz))
	Mats.part(body, Mats.box(Vector3(w + 0.7, 0.08, 2.9)), gold, Vector3(0, th, tz))
	Mats.part(body, Mats.cyl(0.9, 1.1, 0.4, 8), silver, Vector3(0, th + 0.2, tz))
	Mats.part(body, Mats.cyl(0.95, 0.95, 0.06, 8), gold, Vector3(0, th + 0.42, tz))
	Mats.part(body, Mats.crystal(0.55, 2.6), Mats.glow(Color(1.0, 0.76, 0.26), 1.6), Vector3(0, th + 1.75, tz))
	for sgn in [-1.0, 1.0]:
		Mats.part(body, Mats.crystal(0.25, 1.2), Mats.glow(Color(1.0, 0.66, 0.2), 1.3), Vector3(0.6 * sgn, th + 1.0, tz + 0.1), Vector3(0, 0, -18 * sgn))
	Mats.bake(body)
	root.add_child(body)
	for h in halos:
		_halo(root, h[0], Color(h[1].r, h[1].g, h[1].b, 0.7), 0.8)
	_halo(root, Vector3(0, th + 1.8, tz), Color(1.0, 0.8, 0.35, 0.8), 4.0)
	# Orbit rings around the monument (rotated by the ring holder for a touch of life).
	var orbit := Node3D.new()
	orbit.name = "Orbit"
	orbit.position = Vector3(0, th + 1.7, tz)
	Mats.part(orbit, Mats.torus(1.25, 1.33, 40, 4), Mats.glow(Color(1.0, 0.85, 0.45), 1.8), Vector3.ZERO, Vector3(70, 0, 15), Vector3.ONE, false)
	Mats.part(orbit, Mats.torus(1.5, 1.56, 40, 4), Mats.glow(Color(0.7, 0.5, 1.0), 1.6), Vector3.ZERO, Vector3(64, 0, -25), Vector3.ONE, false)
	root.add_child(orbit)
	root.set_meta("orbit", orbit)
	# Multiplier labels: a big sign leaning back on the front of each tread (reads from the high
	# finale camera) and a small one on the riser.
	for i in n:
		var k := float(i) / maxf(1.0, float(n - 1))
		var c := _stairs_color(k)
		var txt := _mult_text(float(mults[i]))
		var l := label(txt, 200, Color.WHITE)
		l.outline_modulate = c.darkened(0.7)
		l.outline_size = 34
		l.position = Vector3(0, (i + 1) * STEP_H + 0.24, -i * STEP_D - 0.5)
		l.rotation_degrees = Vector3(-58, 0, 0)
		l.render_priority = 3
		l.outline_render_priority = 2
		_fit_label(l, w * 0.5, 0.62)
		root.add_child(l)
		var rl := label(txt, 90, c.lerp(Color.WHITE, 0.6))
		rl.outline_modulate = c.darkened(0.8)
		rl.outline_size = 16
		rl.position = Vector3(w * 0.32, i * STEP_H + STEP_H * 0.47, -i * STEP_D + 0.04)
		rl.render_priority = 3
		_fit_label(rl, 1.2, STEP_H - 0.1)
		root.add_child(rl)
		var rl2 := rl.duplicate() as Label3D
		rl2.position.x = -w * 0.32
		root.add_child(rl2)
	root.set_meta("steps", steps)
	root.set_meta("width", w)
	return root


static func _stairs_color(k: float) -> Color:
	if k < 0.5:
		return STAIRS_COLORS[0].lerp(STAIRS_COLORS[1], k * 2.0)
	return STAIRS_COLORS[1].lerp(STAIRS_COLORS[2], (k - 0.5) * 2.0)


# ================================================================== ult ring

## Ground ring under the hero showing the ult charge (see ult_ring_set). Place it at the
## hero's feet; it lies flat at y = 0.03.
static func ult_ring() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "UltRing"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 2.4)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.render_priority = 1
	mi.material_override = m
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("mat", m)
	return mi


## Arc fills clockwise with `progress` (0..1); `ready` turns it gold and makes it pulse.
static func ult_ring_set(ring: MeshInstance3D, progress: float, ready: bool) -> void:
	var m := ring.get_meta("mat") as ShaderMaterial
	m.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	m.set_shader_parameter("ready", 1.0 if ready else 0.0)


# ================================================================== pickups

## +1 pickup tile lying on the road: a faceted ice-crystal plate with a gold rim and a "+1".
static func tile_mesh() -> Mesh:
	return _cached("tile", func():
		var r := Node3D.new()
		# Run.TILE_SHADER decodes the vertex colours as sRGB and gl_compatibility writes sRGB
		# as is, so the rim is pre-encoded to come out GOLD (the plate was tuned as it renders).
		Mats.part(r, Mats.cyl(0.36, 0.4, 0.06, 6), Mats.solid(GOLD.linear_to_srgb(), 0.35, 0.6), Vector3(0, 0.03, 0))
		Mats.part(r, Mats.cyl(0.3, 0.34, 0.08, 6), Mats.glow(ICE, 1.6), Vector3(0, 0.05, 0))
		Mats.part(r, Mats.box(Vector3(0.24, 0.04, 0.07)), Mats.solid(Color.WHITE), Vector3(0, 0.1, 0))
		Mats.part(r, Mats.box(Vector3(0.07, 0.04, 0.24)), Mats.solid(Color.WHITE), Vector3(0, 0.1, 0))
		return r)


static func coin() -> Node3D:
	var root := Node3D.new()
	Mats.part(root, Mats.cyl(0.2, 0.2, 0.05, 14), Mats.glow(Color(1.0, 0.8, 0.25), 0.9), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	Mats.part(root, Mats.cyl(0.13, 0.13, 0.06, 14), Mats.glow(Color(1.0, 0.9, 0.5), 1.2), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	return root
