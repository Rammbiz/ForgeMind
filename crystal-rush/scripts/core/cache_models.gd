class_name CacheModels
## Procedural Caches (arsenal_design.md §5.2, §5.6, §5.7) and the Crystal Altar they are
## cracked on. Fallbacks for the Meshy assets A-32 (Stone), A-33 (World), A-34 (Royal),
## A-35 (X-Ray) and the Altar; every phase ships without them.
##
## A Cache is an egg pre-fractured into 18 thick stone chunks (bottom cap, three bands of
## 5/6/5 jittered bricks, top cap) round a light core. The crack stages (set_crack) follow the
## Opening ceremony (§5.6):
##   0 intact   - idle breathe 1.00 <-> 1.02 every 1.6 s, core dark
##   1 tell     - the first crack: glowing crack lines on every chunk edge and thin gaps leak
##                the colour of the BEST rarity inside (final from this frame; set_tell first),
##                Legendary+ add two light pillars
##   2 heavy    - wider gaps, tilted chunks, shaking, brighter core
##   3 burst    - the chunks fly apart with gravity and spin, then dissolve (call
##                Effects.cache_burst at the same time for the shockwave and sparks)
## Looks: Stone = slate with sapphire points and gold rings; World = basalt with permanent
## amethyst seams, amethyst clusters and double gold rings; Royal = obsidian with gold seams;
## X-Ray = pale opal (Meta-3 stubs).
##
## Asset hook: a GLB "cache_<type>" (Worlds models or res://assets/machines/) replaces the
## intact egg for stages 0..2 (a sheen in the tell colour shows the crack); the procedural
## chunks take over for the burst. "altar" replaces the altar body (rune ring, pylons and the
## socket stay procedural so altar_light() keeps working).

const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")
const SHELL_SHADER := preload("res://shaders/cache_shell.gdshader")
const BEAM_SHADER := preload("res://shaders/rarity_beam.gdshader")
const SHEEN_SHADER := preload("res://shaders/rarity_sheen.gdshader")
## Egg size per type (height, radius) and its looks.
const TYPES := {
	"stone": {"h": 1.04, "r": 0.37, "base": Color(0.46, 0.52, 0.64), "base2": Color(0.3, 0.34, 0.45), "gem": Color(0.26, 0.56, 1.0),
		"seam": 0.0, "seam_color": Color(0.3, 0.6, 1.0), "rough": 0.55, "metal": 0.1, "rings": 1},
	"world": {"h": 1.2, "r": 0.43, "base": Color(0.2, 0.19, 0.27), "base2": Color(0.1, 0.1, 0.15), "gem": Color(0.74, 0.42, 1.0),
		"seam": 0.9, "seam_color": Color(0.72, 0.38, 1.0), "rough": 0.4, "metal": 0.2, "rings": 2},
	"royal": {"h": 1.28, "r": 0.46, "base": Color(0.08, 0.08, 0.12), "base2": Color(0.03, 0.03, 0.05), "gem": Color(1.0, 0.74, 0.25),
		"seam": 1.0, "seam_color": Color(1.0, 0.72, 0.25), "rough": 0.2, "metal": 0.4, "rings": 3},
	"xray": {"h": 1.0, "r": 0.44, "base": Color(0.9, 0.88, 0.97), "base2": Color(0.74, 0.8, 0.92), "gem": Color(0.8, 0.95, 1.0),
		"seam": 0.5, "seam_color": Color(0.85, 0.75, 1.0), "rough": 0.15, "metal": 0.3, "rings": 1},
}
## Latitude boundaries (radians from the bottom pole) and bricks per band.
const BANDS: Array[float] = [0.0, 0.66, 1.36, 2.12, 2.64, PI]
const SECTORS: Array[int] = [1, 5, 6, 5, 1]
const WHITE := Color(0.93, 0.94, 0.98)
const GOLD := Color(1.0, 0.76, 0.3)
const NAVY := Color(0.14, 0.18, 0.31)
const ICE := Color(0.36, 0.82, 1.0)

static var _shell_mats := {}


## Rarity colour of the meta UI (§5.7; Mythic is opal and hue-cycles in animate()).
static func rarity_color(r: String) -> Color:
	return (ArsenalData.RARITIES.get(r, ArsenalData.RARITIES["C"]) as Dictionary)["ui_color"]


## Ceremony tier 0..4 of a rarity (Common..Mythic): particles, camera trauma, stingers.
static func tier(r: String) -> int:
	return maxi(ArsenalData.RARITY_ORDER.find(r), 0)


# ------------------------------------------------------------------ cache

## A Cache of `type` ("stone", "world"; "royal" / "xray" are Meta-3 look stubs). The egg's
## bottom sits on the node origin. Metas: role "cache", "type", "stage", "rarity".
static func cache(type := "stone") -> Node3D:
	if not TYPES.has(type):
		type = "stone"
	var spec: Dictionary = TYPES[type]
	var h := float(spec["h"])
	var r := float(spec["r"])
	var root := Node3D.new()
	root.name = "Cache_" + type
	root.set_meta("role", "cache")
	root.set_meta("type", type)
	root.set_meta("stage", 0)
	root.set_meta("rarity", "C")
	root.set_meta("height", h)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	root.set_meta("body", body)
	# Light core.
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = Mats.sphere(r * 0.8, h * 0.8, 18, 9, false)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(0.08, 0.1, 0.2)
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = Vector3(0, h * 0.5, 0)
	body.add_child(core)
	root.set_meta("core", core)
	var mat := _shell_material(type)
	root.set_meta("shell_mat", mat)
	var chunks: Array[Dictionary] = []
	var centre := Vector3(0, h * 0.5, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type) + 7
	for band in SECTORS.size():
		var n: int = SECTORS[band]
		var offset := band * 0.53
		for j in n:
			var phi0 := TAU * j / n + offset + (0.0 if n == 1 else 0.11 * sin(j * 2.3 + band))
			var phi1 := TAU * (j + 1) / n + offset + (0.0 if n == 1 else 0.11 * sin((j + 1) % n * 2.3 + band))
			if j == n - 1 and n > 1:
				phi1 = TAU * n / n + offset + 0.11 * sin(0 * 2.3 + band)
			var data := _chunk_mesh(h, r, band, phi0, phi1, n == 1)
			var pivot := Node3D.new()
			pivot.name = "Chunk"
			pivot.position = data["centroid"]
			body.add_child(pivot)
			var mi := MeshInstance3D.new()
			mi.mesh = data["mesh"]
			mi.material_override = mat
			pivot.add_child(mi)
			var dir: Vector3 = (Vector3(data["centroid"]) - centre)
			dir = dir.normalized() if dir.length_squared() > 1e-6 else Vector3.UP
			var info := {"node": pivot, "rest": data["centroid"], "dir": dir, "band": band, "j": j,
				"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(),
				"spin": rng.randf_range(4.0, 9.0), "speed": rng.randf_range(2.4, 4.2), "lift": rng.randf_range(1.6, 3.4),
				"tilt": rng.randf_range(-1.0, 1.0), "wide": (band + j) % 3 == 0}
			chunks.append(info)
			_decorate(type, spec, pivot, info, data, rng)
	root.set_meta("chunks", chunks)
	# Gold rings round the caps (they ride with the cap chunks).
	_rings(type, spec, chunks, h, r)
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = ICE
	lamp.light_energy = 0.0
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, h * 0.55, 0.3)
	root.add_child(lamp)
	root.set_meta("lamp", lamp)
	# Legendary+ light pillars (hidden until the tell).
	var pillars: Array[MeshInstance3D] = []
	for sx: float in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		p.name = "Pillar"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.22
		cyl.height = 7.0
		cyl.radial_segments = 16
		cyl.rings = 1
		cyl.cap_top = false
		cyl.cap_bottom = false
		p.mesh = cyl
		var pm := ShaderMaterial.new()
		pm.shader = BEAM_SHADER
		pm.set_shader_parameter("noise_tex", NOISE_TEX)
		p.material_override = pm
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.position = Vector3(r * 0.95 * sx, 3.5 + h * 0.3, -0.12)
		p.visible = false
		root.add_child(p)
		pillars.append(p)
	root.set_meta("pillars", pillars)
	var glb := WeaponModels.asset("cache_" + type, AABB(Vector3(-r, 0, -r), Vector3(r * 2.0, h, r * 2.0)))
	if glb != null:
		glb.name = "Asset"
		root.add_child(glb)
		root.set_meta("asset", glb)
		for c: Dictionary in chunks:
			(c["node"] as Node3D).visible = false
	set_tell(root, "C")
	set_crack(root, 0)
	return root


static func _shell_material(type: String) -> ShaderMaterial:
	var spec: Dictionary = TYPES[type]
	var m := ShaderMaterial.new()
	m.shader = SHELL_SHADER
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	m.set_shader_parameter("base", spec["base"])
	m.set_shader_parameter("base2", spec["base2"])
	m.set_shader_parameter("seam_color", spec["seam_color"])
	m.set_shader_parameter("seam", float(spec["seam"]))
	m.set_shader_parameter("roughness", float(spec["rough"]))
	m.set_shader_parameter("metallic", float(spec["metal"]))
	return m


static func _egg(h: float, r: float, theta: float, phi: float) -> Vector3:
	var y := h * 0.5 * (1.0 - cos(theta))
	var rr := r * sin(theta) * (1.0 + 0.1 * cos(theta))
	return Vector3(rr * cos(phi), y, rr * sin(phi))


## Latitude of the jittered boundary `b` (1..4) at longitude `phi` (0 / PI at the poles).
static func _lat(b: int, phi: float) -> float:
	if b <= 0:
		return 0.0
	if b >= BANDS.size() - 1:
		return PI
	return BANDS[b] + 0.07 * sin(3.0 * phi + b * 1.7) + 0.04 * sin(7.0 * phi + b * 0.9)


## One thick shell chunk between latitude boundaries `band` and `band + 1` and longitudes
## phi0..phi1 (a cap when `cap`). Vertices are relative to the chunk centroid. Returns
## {mesh, centroid, normal (outward at the centre), top (outer point at the chunk centre)}.
static func _chunk_mesh(h: float, r: float, band: int, phi0: float, phi1: float, cap: bool) -> Dictionary:
	var ns := 16 if cap else 5
	var nv := 4
	var centre := Vector3(0, h * 0.5, 0)
	var k_in := 0.84
	var outer: Array = []
	var inner: Array = []
	var edge: Array = []
	var meridian := 0.5 * h
	for i in ns + 1:
		var s := float(i) / ns
		var phi := lerpf(phi0, phi1, s) if not cap else TAU * s
		var lo := _lat(band, phi)
		var hi := _lat(band + 1, phi)
		var col_o: Array[Vector3] = []
		var col_i: Array[Vector3] = []
		var col_e: Array[float] = []
		for k in nv + 1:
			var v := float(k) / nv
			var th := lerpf(lo, hi, v)
			var p := _egg(h, r, th, phi)
			col_o.append(p)
			col_i.append(centre + (p - centre) * k_in)
			var width := maxf(r * sin(th), 0.02) * absf(phi1 - phi0)
			var e_v := minf(v, 1.0 - v) * (hi - lo) * meridian
			if cap:
				e_v = ((1.0 - v) if band == 0 else v) * (hi - lo) * meridian
				col_e.append(e_v)
			else:
				col_e.append(minf(minf(s, 1.0 - s) * width, e_v))
		outer.append(col_o)
		inner.append(col_i)
		edge.append(col_e)
	# Centroid of the outer surface.
	var cen := Vector3.ZERO
	var cnt := 0
	for col: Array in outer:
		for p: Vector3 in col:
			cen += p
			cnt += 1
	cen /= cnt
	var mid_o: Vector3 = outer[ns / 2][nv / 2]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rest_c := cen
	# Outer face (out from the egg centre) and inner face (towards it).
	for i in ns:
		for k in nv:
			var a: Vector3 = outer[i][k]
			var b: Vector3 = outer[i + 1][k]
			var c: Vector3 = outer[i + 1][k + 1]
			var d: Vector3 = outer[i][k + 1]
			var ea := float(edge[i][k])
			var eb := float(edge[i + 1][k])
			var ec := float(edge[i + 1][k + 1])
			var ed := float(edge[i][k + 1])
			var na := _egg_normal(a, centre, r, h)
			var nb := _egg_normal(b, centre, r, h)
			var nc := _egg_normal(c, centre, r, h)
			var nd := _egg_normal(d, centre, r, h)
			_tri(st, [a, b, c], [ea, eb, ec], (a + b + c) / 3.0 - centre, rest_c, 0.0, [na, nb, nc])
			_tri(st, [a, c, d], [ea, ec, ed], (a + c + d) / 3.0 - centre, rest_c, 0.0, [na, nc, nd])
			var ai: Vector3 = inner[i][k]
			var bi: Vector3 = inner[i + 1][k]
			var ci: Vector3 = inner[i + 1][k + 1]
			var di: Vector3 = inner[i][k + 1]
			_tri(st, [ai, bi, ci], [0.0, 0.0, 0.0], centre - (ai + bi + ci) / 3.0, rest_c, 1.0)
			_tri(st, [ai, ci, di], [0.0, 0.0, 0.0], centre - (ai + ci + di) / 3.0, rest_c, 1.0)
	# Broken walls along the four edges (out from the chunk centroid).
	var rims: Array = []
	if not cap:
		var left: Array = []
		var right: Array = []
		for k in nv + 1:
			left.append([outer[0][k], inner[0][k]])
			right.append([outer[ns][k], inner[ns][k]])
		rims.append(left)
		rims.append(right)
	var bottom: Array = []
	var top: Array = []
	for i in ns + 1:
		bottom.append([outer[i][0], inner[i][0]])
		top.append([outer[i][nv], inner[i][nv]])
	if not (cap and band == 0):
		rims.append(bottom)
	if not (cap and band == SECTORS.size() - 1):
		rims.append(top)
	var inner_c := centre + (cen - centre) * 0.92
	for rim: Array in rims:
		for i in rim.size() - 1:
			var o0: Vector3 = rim[i][0]
			var i0: Vector3 = rim[i][1]
			var o1: Vector3 = rim[i + 1][0]
			var i1: Vector3 = rim[i + 1][1]
			var mid := (o0 + i0 + o1 + i1) * 0.25
			_tri(st, [o0, o1, i1], [0.0, 0.0, 0.0], mid - inner_c, rest_c, 1.0)
			_tri(st, [o0, i1, i0], [0.0, 0.0, 0.0], mid - inner_c, rest_c, 1.0)
	var mesh := st.commit()
	return {"mesh": mesh, "centroid": cen, "normal": (mid_o - centre).normalized(), "top": mid_o}


## Smooth outward normal of the egg at `p` (ellipsoid gradient; polished stone, not facets).
static func _egg_normal(p: Vector3, centre: Vector3, r: float, h: float) -> Vector3:
	var q := p - centre
	var hy := h * 0.5
	var n := Vector3(q.x / (r * r), q.y / (hy * hy), q.z / (r * r))
	return n.normalized() if n.length_squared() > 1e-9 else Vector3.UP


## Adds a triangle facing `want` (re-wound if needed), positions relative to `rest_c`, with the
## shell shader's UV data (edge distance, rest position) and wall flag. Flat-shaded unless
## per-vertex `normals` are given.
static func _tri(st: SurfaceTool, p: Array, e: Array, want: Vector3, rest_c: Vector3, wall: float, normals: Array = []) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	var order := [0, 2, 1]
	if n.dot(want) < 0.0:
		n = -n
		order = [0, 1, 2]
	n = n.normalized()
	# Godot's front faces wind clockwise seen from the outside.
	for idx: int in order:
		var v: Vector3 = p[idx]
		st.set_normal(n if normals.is_empty() else normals[idx])
		st.set_color(Color(1, 1, 1, wall))
		st.set_uv(Vector2(float(e[idx]), v.y))
		st.set_uv2(Vector2(v.x, v.z))
		st.add_vertex(v - rest_c)


## Gem points / clusters riding on the chunks.
static func _decorate(type: String, spec: Dictionary, pivot: Node3D, info: Dictionary, data: Dictionary, rng: RandomNumberGenerator) -> void:
	var band := int(info["band"])
	var j := int(info["j"])
	var gem := Mats.glow(spec["gem"], 1.2 if type == "stone" else 1.6)
	var n: Vector3 = data["normal"]
	var top: Vector3 = Vector3(data["top"]) - Vector3(data["centroid"])
	match type:
		"stone":
			# Sapphire points on every other brick, two on the top cap.
			if band in [1, 2, 3] and (j + band) % 2 == 0:
				_crystal_on(pivot, top, n, 0.045, 0.2, gem, 0.0)
			elif band == 4:
				_crystal_on(pivot, top + Vector3(0, -0.02, 0), Vector3.UP, 0.06, 0.26, gem, 0.0)
				_crystal_on(pivot, top + Vector3(0.07, -0.05, 0.02), (Vector3.UP + Vector3(0.6, 0, 0.2)).normalized(), 0.035, 0.15, gem, 0.0)
		"world":
			# Amethyst clusters: a crown of three on the top cap, one per brick on the middle band.
			if band == 4:
				for k in 3:
					var a := TAU * k / 3.0
					var d := (Vector3.UP * 1.4 + Vector3(cos(a), 0, sin(a))).normalized()
					_crystal_on(pivot, top + Vector3(cos(a), 0, sin(a)) * 0.05, d, 0.05, 0.26 + 0.05 * k, gem, 0.0)
				_crystal_on(pivot, top, Vector3.UP, 0.07, 0.36, gem, 0.0)
			elif band == 2:
				_crystal_on(pivot, top, n, 0.05, 0.2, gem, 0.0)
				_crystal_on(pivot, top + (n.cross(Vector3.UP)).normalized() * 0.05, (n + Vector3.UP * 0.4).normalized(), 0.03, 0.13, gem, 0.0)
		_:
			if band == 4:
				_crystal_on(pivot, top, Vector3.UP, 0.07, 0.3, gem, 0.0)


static func _crystal_on(parent: Node3D, pos: Vector3, up: Vector3, radius: float, height: float, mat: Material, spin: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.crystal(radius, height)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := Basis.IDENTITY
	if absf(up.dot(Vector3.UP)) < 0.999:
		var axis := Vector3.UP.cross(up).normalized()
		b = Basis(axis, Vector3.UP.angle_to(up))
	mi.transform = Transform3D(b * Basis(Vector3.UP, spin), pos + up * height * 0.3)
	parent.add_child(mi)


static func _rings(type: String, spec: Dictionary, chunks: Array[Dictionary], h: float, r: float) -> void:
	var gold := Mats.solid(GOLD, 0.3, 0.85)
	for c: Dictionary in chunks:
		var band := int(c["band"])
		if band != 0 and band != SECTORS.size() - 1:
			continue
		var pivot := c["node"] as Node3D
		var rest: Vector3 = c["rest"]
		var rings := int(spec["rings"])
		for k in rings:
			var th := (BANDS[1] - 0.06 - k * 0.09) if band == 0 else (BANDS[4] + 0.07 + k * 0.09)
			var p := _egg(h, r, th, 0.0)
			var rr := p.x + 0.012
			var mi := MeshInstance3D.new()
			mi.mesh = Mats.torus(rr - 0.016, rr + 0.014, 36, 4)
			mi.material_override = gold
			mi.position = Vector3(0, p.y, 0) - rest
			pivot.add_child(mi)
		if band == SECTORS.size() - 1:
			# A gold finial on the crown.
			var tip := _egg(h, r, PI, 0.0)
			Mats.part(pivot, Mats.cyl(0.0, 0.035, 0.07, 8), gold, tip - rest + Vector3(0, 0.03, 0))
		elif type != "stone":
			for k in 6:
				var a := TAU * k / 6.0
				var p2 := _egg(h, r, BANDS[1] - 0.2, a)
				Mats.part(pivot, Mats.sphere(0.022, -1, 8, 4), gold, p2 * 1.03 - rest)


## The tell: rarity of the BEST card inside (§5.6, final from the first crack). "C".."M".
static func set_tell(node: Node3D, rarity: String) -> void:
	node.set_meta("rarity", rarity)
	_refresh(node)


## Crack stage 0 intact, 1 tell, 2 heavy, 3 burst (see the header).
static func set_crack(node: Node3D, stage: int) -> void:
	stage = clampi(stage, 0, 3)
	var was := int(node.get_meta("stage", 0))
	node.set_meta("stage", stage)
	if stage == 3 and was != 3:
		node.set_meta("burst_t", -1.0)
		var glb: Node3D = _nm(node, "asset")
		if glb:
			glb.visible = false
			for c: Dictionary in node.get_meta("chunks", []):
				(c["node"] as Node3D).visible = true
		for c: Dictionary in node.get_meta("chunks", []):
			c["vel"] = (c["dir"] as Vector3) * float(c["speed"]) + Vector3.UP * float(c["lift"])
			c["pos"] = (c["node"] as Node3D).position
	_refresh(node)


static func _refresh(node: Node3D) -> void:
	var stage := int(node.get_meta("stage", 0))
	var r := str(node.get_meta("rarity", "C"))
	var col := rarity_color(r)
	var mat: ShaderMaterial = node.get_meta("shell_mat")
	var tell := [0.0, 1.0, 1.4, 2.0][stage] as float
	mat.set_shader_parameter("tell_color", col)
	mat.set_shader_parameter("tell", tell)
	mat.set_shader_parameter("crack_w", [0.0, 0.03, 0.055, 0.06][stage])
	var core: MeshInstance3D = node.get_meta("core")
	var cm := core.material_override as StandardMaterial3D
	cm.albedo_color = Color(0.08, 0.1, 0.2) if stage == 0 else col.lerp(Color.WHITE, 0.35) * (1.2 + 0.4 * stage)
	var lamp: OmniLight3D = node.get_meta("lamp")
	lamp.light_color = col
	lamp.light_energy = [0.0, 1.6, 2.4, 4.0][stage]
	var beam := r in ["L", "M"] and stage >= 1 and stage < 3
	for p: MeshInstance3D in node.get_meta("pillars", []):
		p.visible = beam
		(p.material_override as ShaderMaterial).set_shader_parameter("color", col)
	var glb: Node3D = _nm(node, "asset")
	if glb:
		var sheen: ShaderMaterial = null
		if stage >= 1 and stage < 3:
			sheen = ShaderMaterial.new()
			sheen.shader = SHEEN_SHADER
			sheen.set_shader_parameter("color", col)
			sheen.set_shader_parameter("strength", 0.8 + 0.5 * stage)
		_overlay(glb, sheen)
	if stage < 3:
		for c: Dictionary in node.get_meta("chunks", []):
			var pivot := c["node"] as Node3D
			var gap := [0.0, 0.012, 0.04, 0.0][stage] as float
			if bool(c["wide"]):
				gap *= 1.8
			pivot.position = Vector3(c["rest"]) + (c["dir"] as Vector3) * gap
			pivot.rotation = (c["axis"] as Vector3) * (deg_to_rad(4.0) * float(c["tilt"]) if stage == 2 else 0.0)
			pivot.scale = Vector3.ONE
			pivot.visible = _nm(node, "asset") == null


static func _overlay(n: Node, mat: Material) -> void:
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).material_overlay = mat
		_overlay(ch, mat)


## Animates a Cache (breathe, shake, burst physics, Mythic opal hue, pillars) or the Altar
## (rune ring, pylon shimmer, floating shards). `t` in seconds.
static func animate(node: Node3D, t: float) -> void:
	var last := float(node.get_meta("last_t", t))
	var dt := clampf(t - last, 0.0, 0.1)
	node.set_meta("last_t", t)
	if str(node.get_meta("role", "")) == "altar":
		_animate_altar(node, t, dt)
		return
	var body: Node3D = node.get_meta("body")
	var stage := int(node.get_meta("stage", 0))
	var r := str(node.get_meta("rarity", "C"))
	if r == "M" and stage >= 1:
		var opal := Color.from_hsv(fposmod(t * 0.18, 1.0), 0.32, 1.0)
		var mat: ShaderMaterial = node.get_meta("shell_mat")
		mat.set_shader_parameter("tell_color", opal)
		(node.get_meta("lamp") as OmniLight3D).light_color = opal
	match stage:
		0, 1:
			var b := 1.0 + 0.01 * (1.0 - cos(t * TAU / 1.6))
			body.scale = Vector3(b, b, b)
			body.position = Vector3.ZERO
		2:
			body.scale = Vector3.ONE * 1.03
			body.position = Vector3(sin(t * 53.0) * 0.012, 0, cos(t * 47.0) * 0.012)
		3:
			body.scale = Vector3.ONE
			body.position = Vector3.ZERO
			var t0 := float(node.get_meta("burst_t", -1.0))
			if t0 < 0.0:
				t0 = t
				node.set_meta("burst_t", t0)
			var age := t - t0
			for c: Dictionary in node.get_meta("chunks", []):
				var pivot := c["node"] as Node3D
				var v: Vector3 = c["vel"]
				var p: Vector3 = c["pos"]
				v.y -= 9.8 * dt
				p += v * dt
				if p.y < 0.05:
					p.y = 0.05
					v = Vector3(v.x * 0.5, absf(v.y) * 0.3, v.z * 0.5)
				c["vel"] = v
				c["pos"] = p
				pivot.position = p
				pivot.rotate(c["axis"] as Vector3, float(c["spin"]) * dt * clampf(v.length() / 3.0, 0.0, 1.0))
				var k := 1.0 - smoothstep(0.8, 1.3, age)
				pivot.scale = Vector3.ONE * maxf(k, 0.001)
				pivot.visible = k > 0.002
			var core: MeshInstance3D = node.get_meta("core")
			var ck := 1.0 + age * 3.0
			core.scale = Vector3.ONE * ck
			core.visible = age < 0.3
			var lamp: OmniLight3D = node.get_meta("lamp")
			lamp.light_energy = 4.0 * (1.0 - smoothstep(0.0, 0.9, age))
	for p: MeshInstance3D in node.get_meta("pillars", []):
		if p.visible:
			var s := 1.0 + 0.08 * sin(t * 5.0)
			p.scale = Vector3(s, 1.0, s)


# ------------------------------------------------------------------ altar

## The Crystal Altar (§5.6): a white marble ziggurat of three octagonal tiers with gold trims
## and navy inlays, a rune ring dais with a gold three-claw socket on top, four ice crystal
## pylons and (opts.temple, default true) two columns with an arch and a crystal keystone
## behind it. Faces +Z (the camera). Metas: role "altar", "socket" (Node3D where a Cache
## sits; place_on_altar()), "rune_mats", "pylon_mats".
static func altar(opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = "CacheAltar"
	root.set_meta("role", "altar")
	var marble := Mats.solid(WHITE, 0.32, 0.15)
	var marble2 := Mats.solid(Color(0.8, 0.83, 0.92), 0.4, 0.15)
	var gold := Mats.solid(GOLD, 0.3, 0.85)
	var navy := Mats.solid(NAVY, 0.5, 0.3)
	var ice := Mats.glow(ICE, 1.8)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var glb := WeaponModels.asset("altar", AABB(Vector3(-1.4, 0, -1.4), Vector3(2.8, 0.72, 2.8)))
	if glb != null:
		body.add_child(glb)
	else:
		Mats.part(body, Mats.cyl(2.3, 2.35, 0.06, 8, true), Mats.solid(Color(0.16, 0.19, 0.32), 0.35, 0.3), Vector3(0, 0.03, 0), Vector3(0, 22.5, 0))
		Mats.part(body, Mats.torus(1.95, 2.0, 48, 3), gold, Vector3(0, 0.065, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
		Mats.part(body, Mats.cyl(1.3, 1.36, 0.22, 8, true), marble, Vector3(0, 0.17, 0), Vector3(0, 22.5, 0))
		Mats.part(body, Mats.cyl(1.33, 1.33, 0.04, 8, true), gold, Vector3(0, 0.3, 0), Vector3(0, 22.5, 0))
		Mats.part(body, Mats.cyl(1.0, 1.06, 0.22, 8, true), marble2, Vector3(0, 0.42, 0), Vector3(0, 22.5, 0))
		Mats.part(body, Mats.cyl(1.02, 1.02, 0.07, 8, true), navy, Vector3(0, 0.42, 0), Vector3(0, 22.5, 0))
		Mats.part(body, Mats.cyl(1.03, 1.03, 0.03, 8, true), gold, Vector3(0, 0.545, 0), Vector3(0, 22.5, 0))
		# Ice inlays on the navy band, one per face.
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector3(sin(a), 0, cos(a))
			Mats.part(body, WeaponModels.bevel_box(Vector3(0.36, 0.035, 0.02), 0.01), ice, d * 0.96 + Vector3(0, 0.42, 0), Vector3(0, rad_to_deg(a), 0), Vector3.ONE, false)
			Mats.part(body, Mats.crystal(0.03, 0.09), ice, d * 1.0 + Vector3(0, 0.42, 0), Vector3(0, rad_to_deg(a), 90), Vector3.ONE, false)
		Mats.part(body, Mats.cyl(0.78, 0.82, 0.12, 24, false), marble, Vector3(0, 0.62, 0))
		Mats.part(body, Mats.torus(0.78, 0.84, 40, 4), gold, Vector3(0, 0.68, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		Mats.part(body, Mats.cyl(0.7, 0.7, 0.03, 32, false), navy, Vector3(0, 0.695, 0))
		# Front steps.
		for i in 2:
			Mats.part(body, WeaponModels.bevel_box(Vector3(0.9 - i * 0.2, 0.1, 0.32), 0.03), marble, Vector3(0, 0.05 + i * 0.1 + 0.06, 1.42 - i * 0.24))
			Mats.part(body, WeaponModels.bevel_box(Vector3(0.92 - i * 0.2, 0.02, 0.33), 0.006), gold, Vector3(0, 0.11 + i * 0.1 + 0.06, 1.42 - i * 0.24))
		Mats.bake(body)
	# Rune ring (glows with altar_light()).
	var ring := Node3D.new()
	ring.name = "RuneRing"
	ring.position = Vector3(0, 0.712, 0)
	root.add_child(ring)
	var rune_mat := _dyn_glow(Color(0.45, 0.75, 1.0), 1.2)
	var rm := Mats.part(ring, Mats.torus(0.58, 0.61, 48, 3), rune_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.3, 1), false)
	rm.set_meta("no_bake", true)
	Mats.part(ring, Mats.torus(0.44, 0.455, 40, 3), rune_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.3, 1), false)
	for k in 12:
		var a := TAU * k / 12.0
		var d := Vector3(sin(a), 0, cos(a))
		var g := Node3D.new()
		g.position = d * 0.515
		g.rotation.y = a
		ring.add_child(g)
		# A small rune: a bar with one or two ticks (varies by k).
		Mats.part(g, Mats.box(Vector3(0.012, 0.006, 0.07)), rune_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(g, Mats.box(Vector3(0.04, 0.006, 0.012)), rune_mat, Vector3(0, 0, -0.03 + (k % 3) * 0.03), Vector3(0, 30.0 * (k % 2), 0), Vector3.ONE, false)
		if k % 2 == 0:
			Mats.part(g, Mats.box(Vector3(0.03, 0.006, 0.012)), rune_mat, Vector3(0.01, 0, 0.03), Vector3(0, -40, 0), Vector3.ONE, false)
	root.set_meta("ring", ring)
	# Socket: three gold claws holding the egg.
	var socket := Node3D.new()
	socket.name = "Socket"
	socket.position = Vector3(0, 0.72, 0)
	root.add_child(socket)
	var claws := Node3D.new()
	claws.name = "Claws"
	root.add_child(claws)
	Mats.part(claws, Mats.cyl(0.22, 0.26, 0.05, 18, false), gold, Vector3(0, 0.735, 0))
	for k in 3:
		var a := TAU * k / 3.0 + PI / 6.0
		var d := Vector3(sin(a), 0, cos(a))
		var claw := Mats.part(claws, WeaponModels.bevel_box(Vector3(0.05, 0.22, 0.05), 0.015), gold, d * 0.27 + Vector3(0, 0.83, 0))
		claw.rotation = Vector3(0, a, 0)
		claw.rotate_object_local(Vector3.RIGHT, 0.45)
		Mats.part(claws, Mats.crystal(0.025, 0.08), ice, d * 0.31 + Vector3(0, 0.96, 0), Vector3.ZERO, Vector3.ONE, false)
	Mats.bake(claws)
	root.set_meta("socket", socket)
	root.set_meta("rune_mats", [rune_mat])
	# Pylons.
	var pylon_mat := _dyn_glow(ICE, 1.6)
	var pylons: Array[Node3D] = []
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var d := Vector3(sin(a), 0, cos(a))
		var py := Node3D.new()
		py.name = "Pylon"
		py.position = d * 1.62
		root.add_child(py)
		Mats.part(py, Mats.cyl(0.17, 0.2, 0.32, 8, true), marble, Vector3(0, 0.16, 0))
		Mats.part(py, Mats.cyl(0.2, 0.2, 0.04, 8, true), gold, Vector3(0, 0.34, 0))
		Mats.part(py, Mats.cyl(0.12, 0.16, 0.06, 8, true), gold, Vector3(0, 0.38, 0))
		var cluster := Node3D.new()
		cluster.name = "Cluster"
		cluster.position = Vector3(0, 0.42, 0)
		py.add_child(cluster)
		var c1 := Mats.part(cluster, Mats.crystal(0.11, 0.86), pylon_mat, Vector3(0, 0.4, 0), Vector3.ZERO, Vector3.ONE, false)
		c1.set_meta("no_bake", true)
		var c2 := Mats.part(cluster, Mats.crystal(0.06, 0.44), pylon_mat, Vector3(0.1, 0.18, 0.03), Vector3(0, 0, -22), Vector3.ONE, false)
		c2.set_meta("no_bake", true)
		var c3 := Mats.part(cluster, Mats.crystal(0.05, 0.36), pylon_mat, Vector3(-0.08, 0.15, -0.05), Vector3(14, 0, 18), Vector3.ONE, false)
		c3.set_meta("no_bake", true)
		Mats.bake(py)
		pylons.append(cluster)
	root.set_meta("pylons", pylons)
	root.set_meta("pylon_mats", [pylon_mat])
	if bool(opts.get("temple", true)):
		_temple(root, marble, marble2, gold, navy, ice)
	var lamp := OmniLight3D.new()
	lamp.name = "AltarLamp"
	lamp.light_color = Color(0.5, 0.75, 1.0)
	lamp.light_energy = 0.8
	lamp.omni_range = 4.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 1.3, 0.8)
	root.add_child(lamp)
	root.set_meta("lamp", lamp)
	altar_light(root, 0.4, Color(0.5, 0.8, 1.0))
	return root


static func _temple(root: Node3D, marble: Material, marble2: Material, gold: Material, navy: Material, ice: Material) -> void:
	var t := Node3D.new()
	t.name = "Temple"
	t.position = Vector3(0, 0, -1.75)
	root.add_child(t)
	for sx: float in [-1.0, 1.0]:
		var x := 1.25 * sx
		Mats.part(t, WeaponModels.bevel_box(Vector3(0.5, 0.18, 0.5), 0.04), marble2, Vector3(x, 0.09, 0))
		Mats.part(t, WeaponModels.bevel_box(Vector3(0.52, 0.04, 0.52), 0.01), gold, Vector3(x, 0.2, 0))
		Mats.part(t, Mats.cyl(0.17, 0.19, 2.6, 12, true), marble, Vector3(x, 1.52, 0))
		for y: float in [0.6, 1.5, 2.4]:
			Mats.part(t, Mats.cyl(0.195, 0.195, 0.03, 12, true), gold, Vector3(x, y, 0))
		Mats.part(t, Mats.cyl(0.28, 0.2, 0.16, 12, true), gold, Vector3(x, 2.88, 0))
		Mats.part(t, WeaponModels.bevel_box(Vector3(0.6, 0.1, 0.6), 0.03), marble2, Vector3(x, 3.01, 0))
		Mats.part(t, Mats.crystal(0.08, 0.34), ice, Vector3(x, 3.22, 0), Vector3.ZERO, Vector3.ONE, false)
	# Arch: a segmented half ring.
	var segs := 9
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var am := (a0 + a1) * 0.5
		var p := Vector3(cos(am) * 1.25, 3.06 + sin(am) * 0.75, 0)
		var seg := WeaponModels.bevel_box(Vector3(0.46, 0.22, 0.34), 0.04)
		var mi := Mats.part(t, seg, marble, p)
		mi.rotation = Vector3(0, 0, am - PI * 0.5)
		var trim := Mats.part(t, WeaponModels.bevel_box(Vector3(0.47, 0.035, 0.36), 0.01), gold, p + Vector3(cos(am), sin(am), 0) * 0.11)
		trim.rotation = Vector3(0, 0, am - PI * 0.5)
	Mats.part(t, WeaponModels.bevel_box(Vector3(0.34, 0.4, 0.38), 0.06), navy, Vector3(0, 3.82, 0))
	Mats.part(t, Mats.crystal(0.16, 0.6), ice, Vector3(0, 3.86, 0.12), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(t, Mats.torus(0.2, 0.235, 24, 4), gold, Vector3(0, 3.86, 0.2), Vector3(90, 0, 0))
	Mats.bake(t)


## Puts `cache` on the altar socket (re-parents it).
static func place_on_altar(altar_node: Node3D, cache_node: Node3D) -> void:
	var socket: Node3D = altar_node.get_meta("socket")
	if cache_node.get_parent():
		cache_node.get_parent().remove_child(cache_node)
	socket.add_child(cache_node)
	cache_node.position = Vector3(0, 0.02, 0)


## Altar glow 0..1 in `color` (rune ring and pylon crystals): ~0.4 idle in ice blue; 1.0 in
## the tell colour from the Honest tell beat.
static func altar_light(altar_node: Node3D, k: float, color: Color) -> void:
	altar_node.set_meta("light_k", k)
	altar_node.set_meta("light_c", color)
	for m: StandardMaterial3D in altar_node.get_meta("rune_mats", []):
		m.albedo_color = color
		m.emission = color
		m.emission_energy_multiplier = 0.4 + 2.6 * k
	for m2: StandardMaterial3D in altar_node.get_meta("pylon_mats", []):
		var c := ICE.lerp(color, clampf(k, 0.0, 1.0) * 0.8)
		m2.albedo_color = c
		m2.emission = c
		m2.emission_energy_multiplier = 0.7 + 0.9 * k
	var lamp: OmniLight3D = _nm(altar_node, "lamp")
	if lamp:
		lamp.light_color = color
		lamp.light_energy = 0.5 + 1.5 * k


static func _animate_altar(node: Node3D, t: float, _dt: float) -> void:
	var ring: Node3D = _nm(node, "ring")
	if ring:
		ring.rotation.y = fposmod(t * 0.25, TAU)
	var i := 0
	for c: Node3D in node.get_meta("pylons", []):
		c.position.y = 0.42 + 0.03 * sin(t * 1.4 + i * 1.7)
		c.rotation.y = fposmod(t * 0.3 + i, TAU)
		i += 1
	for m: StandardMaterial3D in node.get_meta("rune_mats", []):
		var k := float(node.get_meta("light_k", 0.4))
		m.emission_energy_multiplier = (0.4 + 2.6 * k) * (0.85 + 0.15 * sin(t * 2.2))


static func _dyn_glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


## A node meta or null when it is missing (get_meta(key, null) prints an error in Godot 4).
static func _nm(n: Object, key: String) -> Variant:
	return n.get_meta(key) if n.has_meta(key) else null
