class_name Mats
## Cached materials and low-poly (flat shaded) primitive meshes.

static var _mats := {}
static var _meshes := {}
static var _soft_tex: Texture2D


## Matte/glossy lit material.
static func solid(c: Color, rough := 0.85, metal := 0.0, rim := 0.0) -> StandardMaterial3D:
	var key := "s%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, rim]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if metal > 0.0:
		m.metallic_specular = 0.6
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.4
	_mats[key] = m
	return m


## Self-illuminated material that blooms with the environment glow.
static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "g%s|%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	_mats[key] = m
	return m


## Unshaded material, optionally transparent / additive.
static func flat_color(c: Color, additive := false, no_depth := false) -> StandardMaterial3D:
	var key := "u%s|%s|%s" % [c.to_html(), additive, no_depth]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0 or additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if no_depth:
		m.no_depth_test = true
		m.render_priority = 10
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Material that uses vertex colors (terrain, merged meshes).
static func vertex_colored(rough := 0.92) -> StandardMaterial3D:
	var key := "vc|%.2f" % rough
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	_mats[key] = m
	return m


## Billboard particle material with a soft round sprite.
static func particle(additive := true) -> StandardMaterial3D:
	var key := "p|%s" % additive
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func soft_texture() -> Texture2D:
	if _soft_tex:
		return _soft_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


# ---------------------------------------------------------------- meshes


## Converts a primitive mesh into a flat-shaded ArrayMesh (faceted low-poly look).
static func flatten(src: Mesh) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for i in verts.size():
			idx[i] = i
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(idx.size())
	out_n.resize(idx.size())
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			n = normals[idx[i]] if normals.size() > idx[i] else Vector3.UP
		n = n.normalized()
		if normals.size() > idx[i]:
			var ref := normals[idx[i]] + normals[idx[i + 1]] + normals[idx[i + 2]]
			if n.dot(ref) < 0.0:
				n = -n
		for k in 3:
			out_v[i + k] = verts[idx[i + k]]
			out_n[i + k] = n
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


static func _cached(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func box(size: Vector3) -> Mesh:
	return _cached("box%s" % size, func():
		var m := BoxMesh.new()
		m.size = size
		return m)


static func cyl(top: float, bottom: float, height: float, segs := 8, faceted := true) -> Mesh:
	return _cached("cyl%.3f|%.3f|%.3f|%d|%s" % [top, bottom, height, segs, faceted], func():
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segs
		m.rings = 1
		return flatten(m) if faceted else m)


static func sphere(radius: float, height := -1.0, segs := 10, rings := 6, faceted := true) -> Mesh:
	var h := radius * 2.0 if height < 0.0 else height
	return _cached("sph%.3f|%.3f|%d|%d|%s" % [radius, h, segs, rings, faceted], func():
		var m := SphereMesh.new()
		m.radius = radius
		m.height = h
		m.radial_segments = segs
		m.rings = rings
		return flatten(m) if faceted else m)


## Elongated octahedron - used for crystals.
static func crystal(radius: float, height: float) -> Mesh:
	return _cached("cry%.3f|%.3f" % [radius, height], func():
		var m := SphereMesh.new()
		m.radius = radius
		m.height = height
		m.radial_segments = 6
		m.rings = 2
		return flatten(m))


static func cone(radius: float, height: float, segs := 7) -> Mesh:
	return cyl(0.0, radius, height, segs)


static func torus(inner: float, outer: float, rings := 16, ring_segs := 6) -> Mesh:
	return _cached("tor%.3f|%.3f|%d|%d" % [inner, outer, rings, ring_segs], func():
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = rings
		m.ring_segments = ring_segs
		return flatten(m))


static func prism(size: Vector3) -> Mesh:
	return _cached("pri%s" % size, func():
		var m := PrismMesh.new()
		m.size = size
		return flatten(m))


static func quad(size: Vector2, facing_up := true) -> Mesh:
	return _cached("quad%s|%s" % [size, facing_up], func():
		var m := PlaneMesh.new()
		m.size = size
		if not facing_up:
			m.orientation = PlaneMesh.FACE_Z
		return m)


## Adds a MeshInstance3D child and returns it.
static func part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func clear_cache() -> void:
	_mats.clear()
