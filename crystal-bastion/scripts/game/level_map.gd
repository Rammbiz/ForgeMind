class_name LevelMap
extends Node3D
## Builds the floating-island terrain, decorations, enemy paths, spawn portals and the crystal.

const GRASS_Y := 0.0
const PATH_Y := -0.1
const WATER_BED_Y := -0.34
const WATER_Y := -0.12

var width := 0
var height := 0
var cells := {}           # Vector2i -> String (map char)
var top_y := {}           # Vector2i -> float
var depth := {}           # Vector2i -> float (column bottom)
var theme := {}
var spawns: Array[Vector2i] = []
var exit_cell := Vector2i(-1, -1)
var path_cells: Array = []     # Array[Array[Vector2i]] per spawn
var curves: Array[Curve3D] = []
var path_lengths: Array[float] = []
const DECOR_CHUNK := 4
var _decor_parts := {}    # chunk Vector2i -> Array of [cell, mesh, material, Transform3D, casts_shadow]
var _decor_nodes := {}    # chunk Vector2i -> Node3D (baked)
var _hidden := {}         # cells whose decorations are hidden (tower built there)
var crystal: Node3D
var crystal_core: MeshInstance3D
var _crystal_flash := 0.0
var _portals: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _water: MeshInstance3D
var arena := {}           # fit of the sculpted arena model (empty = procedural island)


func build(level: Dictionary, quality_high := true) -> void:
	theme = level["theme"]
	_rng.seed = hash(str(level["id"]))
	arena = Arena.load_fit(str(level["id"]))
	_parse(level["map"])
	if not arena.is_empty():
		for c: Vector2i in cells:
			top_y[c] = Arena.height_at(arena, c, top_y[c])
	_compute_paths()
	if arena.is_empty():
		_build_terrain()
	else:
		add_child(Arena.instantiate(arena, quality_high))
		_build_build_grid()
	if arena.is_empty() or Arena.keeps(arena, "water"):
		_build_water()
	if arena.is_empty() or Arena.keeps(arena, "decor"):
		_build_decorations()
	_build_portals()
	_build_crystal()
	if arena.is_empty() or Arena.keeps(arena, "clouds"):
		_build_clouds()
	_build_ambient(quality_high)


# ------------------------------------------------------------------ grid

func _parse(rows: Array) -> void:
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, str(r).length())
	for y in height:
		var row: String = rows[y]
		for x in width:
			var ch := row[x] if x < row.length() else "x"
			if ch == "x" or ch == " ":
				continue
			var c := Vector2i(x, y)
			cells[c] = ch
			match ch:
				"#", "S":
					top_y[c] = PATH_Y
				"w":
					top_y[c] = WATER_BED_Y
				_:
					top_y[c] = GRASS_Y + _rng.randf_range(0.0, 0.035)
			if ch == "S":
				spawns.append(c)
			elif ch == "C":
				exit_cell = c
	# Column depth: deeper towards the middle of the island => inverted mountain.
	var dist := _distance_to_void()
	for c in cells:
		var d: float = dist[c]
		depth[c] = -0.55 - 0.62 * d - _rng.randf_range(0.0, 0.35) * minf(d, 2.0)


func _distance_to_void() -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for c in cells:
		for n in _neighbors4(c):
			if not cells.has(n):
				dist[c] = 0
				queue.append(c)
				break
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for n in _neighbors4(c):
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	for c in cells:
		if not dist.has(c):
			dist[c] = 0
	return dist


static func _neighbors4(c: Vector2i) -> Array[Vector2i]:
	return [c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP]


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x - width * 0.5 + 0.5, float(top_y.get(c, 0.0)), c.y - height * 0.5 + 0.5)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x + width * 0.5), floori(p.z + height * 0.5))


func is_buildable(c: Vector2i) -> bool:
	return cells.get(c, "") == "."


func is_path(c: Vector2i) -> bool:
	var ch: String = cells.get(c, "")
	return ch == "#" or ch == "S" or ch == "C"


func map_size() -> Vector2:
	return Vector2(width, height)


# ------------------------------------------------------------------ paths

func _compute_paths() -> void:
	for s in spawns:
		var prev := {s: s}
		var queue: Array[Vector2i] = [s]
		var head := 0
		var found := false
		while head < queue.size():
			var c := queue[head]
			head += 1
			if c == exit_cell:
				found = true
				break
			for n in _neighbors4(c):
				if is_path(n) and not prev.has(n):
					prev[n] = c
					queue.append(n)
		var cells_list: Array[Vector2i] = []
		if found:
			var c := exit_cell
			while c != s:
				cells_list.push_front(c)
				c = prev[c]
			cells_list.push_front(s)
		else:
			push_error("No path from spawn %s to exit" % s)
			cells_list = [s]
		path_cells.append(cells_list)
		curves.append(_make_curve(cells_list))
		path_lengths.append(curves.back().get_baked_length())


func _make_curve(list: Array[Vector2i]) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.05
	var pts: Array[Vector3] = []
	for c in list:
		var p := cell_to_world(c)
		p.y = PATH_Y
		pts.append(p)
	# Start slightly inside the portal, end at the crystal edge.
	if pts.size() >= 2:
		pts[0] = pts[0] + (pts[0] - pts[1]).normalized() * 0.2
		pts[pts.size() - 1] = pts[pts.size() - 1] - (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized() * 0.35
	for i in pts.size():
		var tangent := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			var dir_in := (pts[i] - pts[i - 1]).normalized()
			var dir_out := (pts[i + 1] - pts[i]).normalized()
			if dir_in.dot(dir_out) < 0.99:
				tangent = (dir_in + dir_out).normalized() * 0.28
		curve.add_point(pts[i], -tangent, tangent)
	return curve


# ------------------------------------------------------------------ terrain

func _color_at(y: float, ch: String) -> Color:
	var lip: Color = theme["grass_a"] if ch != "#" and ch != "S" else theme["path_edge"]
	if ch == "w":
		lip = theme["dirt"]
	if y > -0.16:
		return lip.darkened(0.12)
	if y > -0.5:
		return (theme["dirt"] as Color).lerp(theme["rock"], clampf((-0.16 - y) / 0.34, 0.0, 1.0) * 0.4)
	return (theme["rock"] as Color).lerp(theme["deep"], clampf((-0.5 - y) / 2.5, 0.0, 1.0))


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in cells:
		var ch: String = cells[c]
		var y: float = top_y[c]
		var cx := c.x - width * 0.5
		var cz := c.y - height * 0.5
		# Top face.
		var col: Color
		match ch:
			"#", "S":
				col = (theme["path"] as Color) * (0.96 + _rng.randf() * 0.08)
			"w":
				col = (theme["dirt"] as Color).darkened(0.25)
			_:
				var checker := (c.x + c.y) % 2 == 0
				col = (theme["grass_a"] if checker else theme["grass_b"]) as Color
				col = col * (0.95 + _rng.randf() * 0.1)
		col.a = 1.0
		var corners := [Vector3(cx, y, cz), Vector3(cx + 1, y, cz), Vector3(cx + 1, y, cz + 1), Vector3(cx, y, cz + 1)]
		if ch == "#" or ch == "S":
			# Path: slightly darker towards grass edges using a 3x3 split (inner square brighter).
			_add_path_top(st, cx, cz, y, col, c)
		else:
			_add_quad(st, corners[0], corners[1], corners[2], corners[3], Vector3.UP, [col, col, col, col])
		# Sides.
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for d: Vector2i in dirs:
			var n := c + d
			var my_bot: float = depth[c]
			if not cells.has(n):
				_add_side(st, c, d, y, my_bot, ch)
			else:
				var ny: float = top_y[n]
				var nbot: float = depth[n]
				if ny < y - 0.001:
					_add_side(st, c, d, y, maxf(ny, my_bot), ch)
				if my_bot < nbot - 0.001:
					_add_side(st, c, d, minf(nbot, y), my_bot, ch)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = Mats.vertex_colored()
	add_child(mi)


func _add_path_top(st: SurfaceTool, cx: float, cz: float, y: float, col: Color, c: Vector2i) -> void:
	var edge: Color = theme["path_edge"]
	var inset := 0.16
	var xs := [cx, cx + inset, cx + 1.0 - inset, cx + 1.0]
	var zs := [cz, cz + inset, cz + 1.0 - inset, cz + 1.0]
	# Which sides border non-path tiles -> darker rim.
	var side_l := not is_path(c + Vector2i.LEFT)
	var side_r := not is_path(c + Vector2i.RIGHT)
	var side_u := not is_path(c + Vector2i.UP)
	var side_d := not is_path(c + Vector2i.DOWN)
	for iz in 3:
		for ix in 3:
			var cols: Array = []
			for k in 4:
				var vx: int = ix + (1 if k == 1 or k == 2 else 0)
				var vz: int = iz + (1 if k >= 2 else 0)
				var dark := (vx == 0 and side_l) or (vx == 3 and side_r) or (vz == 0 and side_u) or (vz == 3 and side_d)
				cols.append(col.lerp(edge, 0.75) if dark else col)
			_add_quad(st, Vector3(xs[ix], y, zs[iz]), Vector3(xs[ix + 1], y, zs[iz]), Vector3(xs[ix + 1], y, zs[iz + 1]), Vector3(xs[ix], y, zs[iz + 1]), Vector3.UP, cols)


func _add_side(st: SurfaceTool, c: Vector2i, d: Vector2i, y_top: float, y_bot: float, ch: String) -> void:
	if y_top - y_bot < 0.001:
		return
	var cx := c.x - width * 0.5
	var cz := c.y - height * 0.5
	var a: Vector3
	var b: Vector3
	var normal := Vector3(d.x, 0, d.y)
	match d:
		Vector2i(1, 0):
			a = Vector3(cx + 1, 0, cz + 1)
			b = Vector3(cx + 1, 0, cz)
		Vector2i(-1, 0):
			a = Vector3(cx, 0, cz)
			b = Vector3(cx, 0, cz + 1)
		Vector2i(0, 1):
			a = Vector3(cx, 0, cz + 1)
			b = Vector3(cx + 1, 0, cz + 1)
		_:
			a = Vector3(cx + 1, 0, cz)
			b = Vector3(cx, 0, cz)
	# Split the side at color band boundaries for nice gradients.
	var cuts: Array[float] = [y_top]
	for band in [-0.16, -0.5, -1.2, -2.0]:
		if band < y_top and band > y_bot:
			cuts.append(band)
	cuts.append(y_bot)
	for i in cuts.size() - 1:
		var t0 := cuts[i]
		var t1 := cuts[i + 1]
		var c0 := _color_at(t0 - 0.001, ch)
		var c1 := _color_at(t1 + 0.001, ch)
		_add_quad(st, Vector3(a.x, t0, a.z), Vector3(b.x, t0, b.z), Vector3(b.x, t1, b.z), Vector3(a.x, t1, a.z), normal, [c0, c0, c1, c1])


## Quad given in clockwise order when viewed from the front (Godot front faces are clockwise).
func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, cols: Array) -> void:
	var tri := [[0, 1, 2], [0, 2, 3]]
	var pts := [p0, p1, p2, p3]
	# Ensure winding matches the normal.
	var face_n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
	var flip := face_n.dot(n) > 0.0
	for t in tri:
		var order: Array = t if not flip else [t[0], t[2], t[1]]
		for k in order:
			st.set_color(cols[k])
			st.set_normal(n)
			st.add_vertex(pts[k])


## Soft rounded tiles that mark buildable cells on top of a sculpted arena model.
func _build_build_grid() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in cells:
		if not is_buildable(c):
			continue
		var p := cell_to_world(c) + Vector3(0, 0.02, 0)
		var q := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(p + q[i])
	var mi := MeshInstance3D.new()
	mi.name = "BuildGrid"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float strength = 0.22;
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	vec2 q = max(p - vec2(0.72), vec2(0.0));
	float d = length(q) + min(max(p.x, p.y) - 0.72, 0.0) - 0.18;
	float edge = smoothstep(-0.12, -0.04, d) * (1.0 - smoothstep(-0.02, 0.0, d));
	ALBEDO = tint.rgb;
	ALPHA = edge * strength + (1.0 - smoothstep(-0.02, 0.0, d)) * strength * 0.15;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", float(arena.get("grid_strength", 0.22)))
	mi.material_override = mat
	add_child(mi)


func _build_water() -> void:
	var has_water := false
	for c in cells:
		if cells[c] == "w":
			has_water = true
			break
	if not has_water:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c: Vector2i in cells:
		if cells[c] != "w":
			continue
		var cx := c.x - width * 0.5
		var cz := c.y - height * 0.5
		var col: Color = theme["water"]
		_add_quad(st, Vector3(cx, WATER_Y, cz), Vector3(cx + 1, WATER_Y, cz), Vector3(cx + 1, WATER_Y, cz + 1), Vector3(cx, WATER_Y, cz + 1), Vector3.UP, [col, col, col, col])
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = st.commit()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;
uniform vec4 water_color : source_color;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w = sin(wpos.x * 6.0 + TIME * 1.7) * 0.5 + sin(wpos.z * 7.0 - TIME * 1.3) * 0.5;
	float sparkle = smoothstep(0.75, 0.98, sin(wpos.x * 13.0 + TIME * 2.3) * sin(wpos.z * 11.0 - TIME * 1.9));
	ALBEDO = water_color.rgb * (0.9 + w * 0.08) + vec3(sparkle * 0.5);
	ALPHA = 0.82;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(cos(wpos.x * 6.0 + TIME * 1.7) * 0.08, 0.0, cos(wpos.z * 7.0 - TIME * 1.3) * 0.08, 0.0)).xyz);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("water_color", theme["water"])
	_water.material_override = mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


# ------------------------------------------------------------------ decorations

func _build_decorations() -> void:
	var tufts := Mats.solid((theme["grass_b"] as Color).darkened(0.12), 0.9)
	var stem := Mats.solid((theme["grass_b"] as Color).darkened(0.25), 0.9)
	var flowers: Array = theme["flowers"]
	for c: Vector2i in cells:
		var ch: String = cells[c]
		# Scratch holder (never enters the tree); its meshes are harvested into chunk batches.
		var holder := Node3D.new()
		holder.position = cell_to_world(c)
		match ch:
			".":
				var n_tuft := _rng.randi_range(1, 3)
				for i in n_tuft:
					var p := Vector3(_rng.randf_range(-0.38, 0.38), 0.0, _rng.randf_range(-0.38, 0.38))
					for b in 3:
						Mats.part(holder, Mats.cone(0.028, 0.15, 3), tufts, p + Vector3((b - 1) * 0.03, 0.06, 0.0), Vector3(_rng.randf_range(-12, 12), _rng.randf() * 120, (b - 1) * 22.0), Vector3.ONE, false)
				if _rng.randf() < 0.45:
					var fc: Color = flowers[_rng.randi() % flowers.size()]
					var p2 := Vector3(_rng.randf_range(-0.38, 0.38), 0.0, _rng.randf_range(-0.38, 0.38))
					Mats.part(holder, Mats.cyl(0.008, 0.008, 0.1, 3), stem, p2 + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3.ONE, false)
					Mats.part(holder, Mats.sphere(0.035, -1, 6, 3), Mats.solid(fc, 0.6), p2 + Vector3(0, 0.11, 0), Vector3.ZERO, Vector3.ONE, false)
				if _rng.randf() < 0.12:
					var p3 := Vector3(_rng.randf_range(-0.35, 0.35), 0.02, _rng.randf_range(-0.35, 0.35))
					Mats.part(holder, Mats.sphere(0.07, 0.07, 6, 3), Mats.solid(theme["rock"]), p3)
				elif _rng.randf() < 0.14 and not _near_path(c):
					var p4 := Vector3(_rng.randf_range(-0.25, 0.25), 0.06, _rng.randf_range(-0.25, 0.25))
					var bush := Mats.solid((theme["foliage"] as Color).lightened(0.05), 0.85)
					Mats.part(holder, Mats.sphere(0.15, 0.2, 7, 4), bush, p4)
					Mats.part(holder, Mats.sphere(0.1, 0.14, 6, 3), Mats.solid(theme["foliage_b"], 0.85), p4 + Vector3(0.1, 0.03, 0.05))
			"t":
				_add_tree(holder, Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12)), _rng.randf_range(0.85, 1.15))
				if _rng.randf() < 0.5:
					_add_tree(holder, Vector3(_rng.randf_range(-0.35, 0.35), 0, _rng.randf_range(-0.35, 0.35)), _rng.randf_range(0.5, 0.7))
			"r":
				_add_rocks(holder)
			"#":
				if _rng.randf() < 0.3:
					var p := Vector3(_rng.randf_range(-0.42, 0.42), 0.01, _rng.randf_range(-0.42, 0.42))
					if absf(p.x) > 0.3 or absf(p.z) > 0.3:
						Mats.part(holder, Mats.sphere(0.04, 0.03, 5, 2), Mats.solid((theme["path"] as Color).darkened(0.25)), p, Vector3.ZERO, Vector3.ONE, false)
		_harvest(c, holder, Transform3D.IDENTITY)
		holder.free()
	for key in _decor_parts:
		_rebuild_chunk(key)


func _harvest(c: Vector2i, node: Node3D, parent_xf: Transform3D) -> void:
	var xf := parent_xf * node.transform
	for ch in node.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			var key := _chunk_of(c)
			if not _decor_parts.has(key):
				_decor_parts[key] = []
			_decor_parts[key].append([c, mi.mesh, mi.material_override, xf * mi.transform, mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF])
		elif ch is Node3D:
			_harvest(c, ch, xf)


func _chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(c.x / DECOR_CHUNK, c.y / DECOR_CHUNK)


## Rebuilds one batched decoration chunk, skipping cells that are covered by towers.
func _rebuild_chunk(key: Vector2i) -> void:
	if not _decor_parts.has(key):
		return
	if _decor_nodes.has(key):
		(_decor_nodes[key] as Node).queue_free()
	var node := Node3D.new()
	node.name = "Decor_%d_%d" % [key.x, key.y]
	for part: Array in _decor_parts.get(key, []):
		if _hidden.has(part[0]):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = part[1]
		mi.material_override = part[2]
		mi.transform = part[3]
		if not part[4]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	Mats.bake(node)
	add_child(node)
	_decor_nodes[key] = node


func _add_tree(parent: Node3D, pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = _rng.randf() * TAU
	root.scale = Vector3.ONE * s
	parent.add_child(root)
	var foliage := Mats.solid(theme["foliage"], 0.8)
	var foliage_b := Mats.solid(theme["foliage_b"], 0.8)
	var trunk := Mats.solid(theme["trunk"], 0.9)
	match str(theme["tree"]):
		"round":
			Mats.part(root, Mats.cyl(0.05, 0.08, 0.4, 5), trunk, Vector3(0, 0.2, 0))
			Mats.part(root, Mats.sphere(0.3, 0.5, 7, 4), foliage, Vector3(0, 0.55, 0))
			Mats.part(root, Mats.sphere(0.2, 0.32, 7, 4), foliage_b, Vector3(0.12, 0.72, 0.05))
			Mats.part(root, Mats.sphere(0.18, 0.28, 6, 3), foliage_b, Vector3(-0.14, 0.62, -0.08))
		"cactus":
			var green := Mats.solid(theme["foliage"], 0.7)
			Mats.part(root, Mats.cyl(0.09, 0.1, 0.6, 7), green, Vector3(0, 0.3, 0))
			Mats.part(root, Mats.sphere(0.09, -1, 7, 4), green, Vector3(0, 0.6, 0))
			for s2 in [-1.0, 1.0]:
				var arm_h := _rng.randf_range(0.2, 0.32)
				Mats.part(root, Mats.cyl(0.055, 0.055, 0.14, 6), green, Vector3(0.13 * s2, 0.3, 0), Vector3(0, 0, 90))
				Mats.part(root, Mats.cyl(0.055, 0.06, arm_h, 6), green, Vector3(0.2 * s2, 0.3 + arm_h * 0.5, 0))
				Mats.part(root, Mats.sphere(0.055, -1, 6, 3), green, Vector3(0.2 * s2, 0.3 + arm_h, 0))
			Mats.part(root, Mats.sphere(0.04, -1, 6, 3), Mats.solid(Color(1.0, 0.45, 0.55)), Vector3(0, 0.69, 0))
		"snowpine":
			Mats.part(root, Mats.cyl(0.04, 0.06, 0.25, 5), trunk, Vector3(0, 0.12, 0))
			for i in 3:
				var r := 0.3 - i * 0.07
				var y := 0.3 + i * 0.18
				Mats.part(root, Mats.cone(r, 0.32, 7), foliage, Vector3(0, y, 0))
				Mats.part(root, Mats.cone(r * 0.75, 0.16, 7), foliage_b, Vector3(0, y + 0.1, 0))
		_:
			Mats.part(root, Mats.cyl(0.05, 0.07, 0.3, 5), trunk, Vector3(0, 0.15, 0))
			Mats.part(root, Mats.cone(0.3, 0.6, 7), foliage, Vector3(0, 0.55, 0))


func _add_rocks(parent: Node3D) -> void:
	if str(theme.get("rocks", "")) == "ice":
		# Glowing ice crystal cluster (night level eye-candy).
		var n_c := _rng.randi_range(3, 5)
		for i in n_c:
			var h := _rng.randf_range(0.25, 0.6) * (1.3 if i == 0 else 1.0)
			var p := Vector3(_rng.randf_range(-0.22, 0.22), h * 0.35, _rng.randf_range(-0.22, 0.22))
			var tilt := Vector3(_rng.randf_range(-25, 25), _rng.randf() * 180, _rng.randf_range(-25, 25))
			Mats.part(parent, Mats.crystal(h * 0.22, h), Mats.glow(Color(0.45, 0.85, 1.0), 0.9 + _rng.randf() * 0.6), p, tilt, Vector3.ONE, false)
		Mats.part(parent, Mats.sphere(0.2, 0.18, 6, 3), Mats.solid(theme["rock"], 0.9), Vector3(0, 0.03, 0))
		return
	var mat := Mats.solid(theme["rock"], 0.95)
	var mat2 := Mats.solid((theme["rock"] as Color).lightened(0.12), 0.95)
	var n := _rng.randi_range(2, 3)
	for i in n:
		var r := _rng.randf_range(0.14, 0.26) * (1.4 if i == 0 else 1.0)
		var p := Vector3(_rng.randf_range(-0.22, 0.22), r * 0.35, _rng.randf_range(-0.22, 0.22))
		Mats.part(parent, Mats.sphere(r, r * 1.3, 6, 3), mat if i % 2 == 0 else mat2, p, Vector3(_rng.randf() * 20, _rng.randf() * 180, 0))


func _near_path(c: Vector2i) -> bool:
	for n in _neighbors4(c):
		if is_path(n):
			return true
	return false


func hide_deco(c: Vector2i) -> void:
	if _hidden.has(c):
		return
	_hidden[c] = true
	_rebuild_chunk(_chunk_of(c))


func show_deco(c: Vector2i) -> void:
	if not _hidden.has(c):
		return
	_hidden.erase(c)
	_rebuild_chunk(_chunk_of(c))


# ------------------------------------------------------------------ portals & crystal

func _build_portals() -> void:
	for i in spawns.size():
		var s: Vector2i = spawns[i]
		var list: Array = path_cells[i]
		var dir := Vector3(0, 0, 1)
		if list.size() >= 2:
			dir = (cell_to_world(list[1]) - cell_to_world(list[0])).normalized()
		var root := Node3D.new()
		root.name = "Portal%d" % i
		root.position = cell_to_world(s)
		root.rotation.y = atan2(dir.x, dir.z)
		add_child(root)
		var stone := Mats.solid(Color(0.28, 0.25, 0.34), 0.85)
		var stone_l := Mats.solid(Color(0.42, 0.38, 0.5), 0.85)
		# Ring of standing stones around a glowing vortex on the ground
		# (an arena model brings its own stones).
		var stones := arena.is_empty() or Arena.keeps(arena, "portal_base")
		if stones:
			Mats.part(root, Mats.cyl(0.47, 0.5, 0.08, 10), stone, Vector3(0, 0.0, 0))
		var swirl := MeshInstance3D.new()
		swirl.mesh = Mats.quad(Vector2(0.9, 0.9))
		swirl.position = Vector3(0, 0.05, 0)
		swirl.material_override = _portal_material()
		swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(swirl)
		for k in (6 if stones else 0):
			var a := TAU * k / 6.0 + PI / 6.0
			# Leave the side facing the path (+Z) open.
			if absf(wrapf(a, -PI, PI)) < 0.7:
				continue
			var p := Vector3(sin(a) * 0.46, 0.0, cos(a) * 0.46)
			var h := 0.42 + 0.12 * (k % 2)
			Mats.part(root, Mats.box(Vector3(0.13, h, 0.13)), stone_l if k % 2 == 0 else stone, p + Vector3(0, h * 0.5, 0), Vector3(0, rad_to_deg(a), 4.0 * (k - 2.5)))
			Mats.part(root, Mats.crystal(0.05, 0.16), Mats.glow(Color(0.85, 0.4, 1.0), 2.6), p + Vector3(0, h + 0.1, 0), Vector3.ZERO, Vector3.ONE, false)
		var parts := CPUParticles3D.new()
		parts.amount = 22
		parts.lifetime = 1.6
		parts.mesh = Mats.quad(Vector2(0.08, 0.08), false)
		parts.material_override = Mats.particle(true)
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		parts.emission_ring_axis = Vector3.UP
		parts.emission_ring_radius = 0.38
		parts.emission_ring_inner_radius = 0.1
		parts.emission_ring_height = 0.02
		parts.direction = Vector3.UP
		parts.spread = 12
		parts.initial_velocity_min = 0.35
		parts.initial_velocity_max = 0.8
		# In 3D the tangential axis is cross(radial, gravity), so gravity must not be zero.
		parts.gravity = Vector3(0, 0.05, 0)
		parts.tangential_accel_min = 1.2
		parts.tangential_accel_max = 2.2
		parts.color_ramp = _ramp(Color(0.95, 0.55, 1.0, 1.0), Color(0.45, 0.15, 1.0, 0.0))
		parts.position = Vector3(0, 0.06, 0)
		root.add_child(parts)
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(0.75, 0.4, 1.0)
		light.light_energy = 1.4
		light.omni_range = 2.0
		light.position = Vector3(0, 0.6, 0)
		root.add_child(light)
		Mats.bake(root)
		_portals.append(root)


func _portal_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 9.0 - TIME * 4.0) * 0.5 + 0.5;
	float mask = smoothstep(1.0, 0.55, r);
	vec3 col = mix(vec3(0.35, 0.05, 0.6), vec3(1.0, 0.55, 1.0), swirl * (1.0 - r));
	ALBEDO = col * 1.6;
	ALPHA = mask * (0.55 + swirl * 0.45);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _build_crystal() -> void:
	if exit_cell.x < 0:
		return
	crystal = Node3D.new()
	crystal.name = "Crystal"
	crystal.position = cell_to_world(exit_cell)
	add_child(crystal)
	var stone := Mats.solid(Color(0.75, 0.74, 0.78), 0.8)
	var base := arena.is_empty() or Arena.keeps(arena, "crystal_base")
	if base:
		Mats.part(crystal, Mats.cyl(0.42, 0.48, 0.16, 6), Mats.solid(Color(0.45, 0.44, 0.5)), Vector3(0, 0.08, 0))
		Mats.part(crystal, Mats.cyl(0.3, 0.38, 0.14, 6), stone, Vector3(0, 0.23, 0))
	for i in (6 if base else 0):
		var a := TAU * i / 6.0
		Mats.part(crystal, Mats.crystal(0.07, 0.3), Mats.glow(Color(0.4, 0.95, 1.0), 1.3), Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36), Vector3(rad_to_deg(sin(a)) * 0.35, 0, -rad_to_deg(cos(a)) * 0.35), Vector3.ONE, false)
	crystal_core = Mats.part(crystal, Mats.crystal(0.26, 0.9), _crystal_mat(Color(0.35, 0.95, 1.0)), Vector3(0, 1.0, 0))
	crystal_core.set_meta("no_bake", true)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.9, 1.0)
	light.light_energy = 1.6
	light.omni_range = 3.0
	light.position = Vector3(0, 1.0, 0)
	crystal.add_child(light)
	crystal.set_meta("light", light)
	var parts := CPUParticles3D.new()
	parts.amount = 16
	parts.lifetime = 2.2
	parts.mesh = Mats.quad(Vector2(0.07, 0.07), false)
	parts.material_override = Mats.particle(true)
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 0.45
	parts.direction = Vector3.UP
	parts.initial_velocity_min = 0.15
	parts.initial_velocity_max = 0.4
	parts.gravity = Vector3.ZERO
	parts.color_ramp = _ramp(Color(0.6, 1.0, 1.0, 1.0), Color(0.3, 0.8, 1.0, 0.0))
	parts.position = Vector3(0, 0.8, 0)
	crystal.add_child(parts)
	Mats.bake(crystal)


func _crystal_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.0
	m.roughness = 0.15
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.8
	return m


## Visual feedback when an enemy reaches the crystal.
func crystal_hit() -> void:
	_crystal_flash = 1.0


func crystal_top() -> Vector3:
	return crystal.global_position + Vector3(0, 1.0, 0) if crystal else Vector3.ZERO


static func _ramp(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


# ------------------------------------------------------------------ sky dressing

func _build_clouds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = theme["clouds"]
	mat.roughness = 1.0
	var count := 14
	for i in count:
		var cloud := Node3D.new()
		var a := TAU * i / count + _rng.randf_range(-0.2, 0.2)
		var r := _rng.randf_range(maxf(width, height) * 0.62, maxf(width, height) * 0.95)
		cloud.position = Vector3(cos(a) * r * 1.1, _rng.randf_range(-3.5, -0.8), sin(a) * r * 0.75)
		var puffs := _rng.randi_range(3, 5)
		for p in puffs:
			var pr := _rng.randf_range(0.5, 1.0)
			var mi := Mats.part(cloud, Mats.sphere(pr, pr * 1.3, 8, 4), mat, Vector3(p * 0.7 - puffs * 0.35, _rng.randf_range(-0.1, 0.25), _rng.randf_range(-0.3, 0.3)))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.scale = Vector3.ONE * _rng.randf_range(0.8, 1.5)
		cloud.set_meta("speed", _rng.randf_range(0.05, 0.15))
		Mats.bake(cloud)
		add_child(cloud)
		_clouds.append(cloud)


func _build_ambient(quality_high: bool) -> void:
	var kind := str(theme.get("particles", ""))
	var p := CPUParticles3D.new()
	p.name = "Ambient"
	p.mesh = Mats.quad(Vector2(0.06, 0.06), false)
	p.material_override = Mats.particle(true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.55, 1.2, height * 0.55)
	p.position = Vector3(0, 1.4, 0)
	p.preprocess = 6.0
	match kind:
		"snow":
			p.amount = 160 if quality_high else 70
			p.lifetime = 6.0
			p.direction = Vector3(0.2, -1, 0.1)
			p.spread = 15
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.6
			p.gravity = Vector3(0, -0.15, 0)
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.4
			p.position.y = 3.0
			p.color_ramp = _ramp(Color(1, 1, 1, 0.9), Color(0.85, 0.92, 1.0, 0.0))
			p.material_override = Mats.particle(false)
		"dust":
			p.amount = 50 if quality_high else 25
			p.lifetime = 5.0
			p.direction = Vector3(1, 0.1, 0)
			p.spread = 25
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.45
			p.gravity = Vector3.ZERO
			p.color_ramp = _ramp(Color(1.0, 0.8, 0.55, 0.7), Color(1.0, 0.6, 0.4, 0.0))
		_:
			p.amount = 40 if quality_high else 20
			p.lifetime = 5.0
			p.direction = Vector3.UP
			p.spread = 60
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
			p.gravity = Vector3.ZERO
			p.color_ramp = _ramp(Color(1.0, 0.95, 0.55, 0.9), Color(1.0, 0.9, 0.4, 0.0))
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	for cloud in _clouds:
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		var lim := width * 1.1
		if cloud.position.x > lim:
			cloud.position.x = -lim
	if crystal_core:
		crystal_core.rotation.y += delta * 0.8
		crystal_core.position.y = 1.0 + sin(_t * 1.6) * 0.06
		if _crystal_flash > 0.0:
			_crystal_flash = maxf(_crystal_flash - delta * 2.0, 0.0)
			var m := crystal_core.material_override as StandardMaterial3D
			var base := Color(0.35, 0.95, 1.0)
			var hurt := Color(1.0, 0.25, 0.3)
			var c := base.lerp(hurt, _crystal_flash)
			m.albedo_color = c
			m.emission = c
			crystal_core.scale = Vector3.ONE * (1.0 + _crystal_flash * 0.15)
	for p in _portals:
		(p.get_node("Light") as OmniLight3D).light_energy = 1.2 + sin(_t * 3.0) * 0.35
