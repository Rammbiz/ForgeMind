class_name Models
## Procedural low-poly models for the runner: soldiers of both armies (single merged meshes
## for MultiMesh crowds), gates, barricades, the enemy fortress and coins.
## Models face +Z; the run heads towards -Z, so runner-side models are turned around.

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

static var _meshes := {}


## Merges every MeshInstance3D under `root` into one vertex-coloured mesh (one draw call, so a
## MultiMesh can draw a whole crowd at once).
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


## Crystal knight of the player's army (about 0.75 tall), shaped to read from above:
## a white helmet with a gold crest, a blue cape, a big round shield and an upright spear.
static func soldier_mesh() -> ArrayMesh:
	return _cached("soldier", func():
		var r := Node3D.new()
		# White and gold armour reads against any road (the space road is blue).
		var blue := Mats.solid(Color(0.93, 0.94, 0.98), 0.6, 0.2)
		var dark := Mats.solid(BLUE)
		var steel := Mats.solid(STEEL, 0.4, 0.6)
		var gold := Mats.solid(GOLD, 0.4, 0.6)
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.box(Vector3(0.1, 0.24, 0.12)), Mats.solid(Color(0.25, 0.2, 0.18)), Vector3(0.07 * sgn, 0.12, 0))
		Mats.part(r, Mats.cyl(0.15, 0.19, 0.3, 8), blue, Vector3(0, 0.38, 0))
		Mats.part(r, Mats.box(Vector3(0.34, 0.06, 0.26)), gold, Vector3(0, 0.27, 0))
		Mats.part(r, Mats.box(Vector3(0.3, 0.34, 0.05)), dark, Vector3(0, 0.38, -0.15))
		Mats.part(r, Mats.sphere(0.13, -1, 8, 5), Mats.solid(SKIN), Vector3(0, 0.63, 0.02))
		Mats.part(r, Mats.sphere(0.15, 0.17, 8, 4), blue, Vector3(0, 0.68, 0))
		Mats.part(r, Mats.box(Vector3(0.05, 0.13, 0.24)), gold, Vector3(0, 0.82, -0.02))
		Mats.part(r, Mats.cyl(0.16, 0.16, 0.04, 10), gold, Vector3(0.22, 0.4, 0.05), Vector3(0, 0, 90))
		Mats.part(r, Mats.cyl(0.11, 0.11, 0.045, 10), blue, Vector3(0.24, 0.4, 0.05), Vector3(0, 0, 90))
		Mats.part(r, Mats.box(Vector3(0.035, 0.95, 0.035)), Mats.solid(WOOD), Vector3(-0.22, 0.5, 0.08))
		Mats.part(r, Mats.cone(0.05, 0.16), steel, Vector3(-0.22, 1.05, 0.08))
		return r)


## Red Horde raider: hunched, horned helmet, spear.
static func raider_mesh() -> ArrayMesh:
	return _cached("raider", func():
		var r := Node3D.new()
		var red := Mats.solid(RED)
		var dark := Mats.solid(RED_DARK)
		var iron := Mats.solid(IRON, 0.5, 0.5)
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.box(Vector3(0.11, 0.22, 0.12)), dark, Vector3(0.07 * sgn, 0.11, 0))
		Mats.part(r, Mats.cyl(0.14, 0.2, 0.32, 7), red, Vector3(0, 0.37, 0), Vector3(12, 0, 0))
		Mats.part(r, Mats.sphere(0.13, -1, 8, 5), Mats.solid(ORC), Vector3(0, 0.6, 0.06))
		Mats.part(r, Mats.sphere(0.15, 0.15, 8, 4), iron, Vector3(0, 0.65, 0.05))
		for sgn in [-1.0, 1.0]:
			Mats.part(r, Mats.cone(0.04, 0.16), Mats.solid(Color(0.95, 0.9, 0.8)), Vector3(0.14 * sgn, 0.73, 0.05), Vector3(0, 0, -50 * sgn))
		Mats.part(r, Mats.box(Vector3(0.03, 0.03, 0.7)), Mats.solid(WOOD_DARK), Vector3(0.18, 0.4, 0.12))
		Mats.part(r, Mats.cone(0.045, 0.13), iron, Vector3(0.18, 0.4, 0.52), Vector3(90, 0, 0))
		return r)


static func vertex_material() -> StandardMaterial3D:
	return Mats.vertex_colored(0.8)


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


## Gate arch across one lane: posts, a lintel and a glowing panel with the effect text.
static func gate(text: String, good: bool, width: float) -> Node3D:
	var root := Node3D.new()
	var frame := Mats.solid(Color(0.85, 0.82, 0.78), 0.8)
	var cap := Mats.solid(GOLD if good else Color(0.45, 0.1, 0.1), 0.45, 0.4)
	var h := 2.0
	for sgn in [-1.0, 1.0]:
		Mats.part(root, Mats.box(Vector3(0.22, h, 0.22)), frame, Vector3(width * 0.5 * sgn, h * 0.5, 0))
		Mats.part(root, Mats.box(Vector3(0.3, 0.12, 0.3)), cap, Vector3(width * 0.5 * sgn, h + 0.06, 0))
	Mats.part(root, Mats.box(Vector3(width + 0.3, 0.2, 0.26)), frame, Vector3(0, h + 0.1, 0))
	var panel := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width - 0.2, h - 0.15)
	panel.mesh = q
	var col := Color(0.25, 0.55, 1.0, 0.42) if good else Color(1.0, 0.25, 0.22, 0.42)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = col
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material_override = pm
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.position = Vector3(0, h * 0.5, 0)
	root.add_child(panel)
	var l := label(text, 220, Color.WHITE)
	l.position = Vector3(0, h * 0.55, 0.06)
	root.add_child(l)
	root.set_meta("panel", panel)
	root.set_meta("label", l)
	return root


## Spiked wooden barricade across one lane with its strength written on it.
static func barricade(hp: int, width: float) -> Node3D:
	var root := Node3D.new()
	var wood := Mats.solid(WOOD, 0.9)
	var dark := Mats.solid(WOOD_DARK, 0.9)
	var iron := Mats.solid(IRON, 0.5, 0.5)
	var planks := int(width / 0.36)
	for i in planks:
		var x := -width * 0.5 + (i + 0.5) * width / planks
		Mats.part(root, Mats.box(Vector3(width / planks - 0.04, 1.25 + (i % 2) * 0.12, 0.16)), wood if i % 2 == 0 else dark, Vector3(x, 0.66, 0))
		Mats.part(root, Mats.cone(0.07, 0.3, 5), iron, Vector3(x, 1.45 + (i % 2) * 0.12, 0))
	for y in [0.35, 1.0]:
		Mats.part(root, Mats.box(Vector3(width, 0.1, 0.2)), iron, Vector3(0, y, 0.02))
	for sgn in [-1.0, 1.0]:
		Mats.part(root, Mats.box(Vector3(0.24, 1.7, 0.3)), Mats.solid(Color(0.6, 0.58, 0.55)), Vector3(width * 0.5 * sgn, 0.85, 0))
	Mats.bake(root)
	var l := label(str(hp), 200, Color(1.0, 0.95, 0.85))
	l.position = Vector3(0, 0.75, 0.14)
	root.add_child(l)
	root.set_meta("label", l)
	return root


## The Red Horde's fortress spanning the bridge: towers, battlements, banners and a great
## gate whose strength is written above it.
static func fortress(hp: int, width: float) -> Node3D:
	var root := Node3D.new()
	var stone := Mats.solid(Color(0.62, 0.57, 0.55), 0.9)
	var stone_d := Mats.solid(Color(0.46, 0.42, 0.42), 0.9)
	var roof := Mats.solid(RED, 0.7)
	var wood := Mats.solid(WOOD_DARK, 0.9)
	var iron := Mats.solid(IRON, 0.5, 0.5)
	var wall_h := 3.4
	Mats.part(root, Mats.box(Vector3(width + 1.2, wall_h, 1.4)), stone, Vector3(0, wall_h * 0.5, -0.4))
	for i in int(width + 1.2):
		Mats.part(root, Mats.box(Vector3(0.5, 0.45, 0.5)), stone_d, Vector3(-width * 0.5 - 0.35 + i + 0.5, wall_h + 0.22, 0.1))
	for sgn in [-1.0, 1.0]:
		var x: float = (width * 0.5 + 0.9) * sgn
		Mats.part(root, Mats.cyl(1.0, 1.15, 5.0, 10), stone, Vector3(x, 2.5, -0.3))
		Mats.part(root, Mats.cyl(1.2, 1.2, 0.4, 10), stone_d, Vector3(x, 5.1, -0.3))
		Mats.part(root, Mats.cone(1.35, 2.2, 10), roof, Vector3(x, 6.4, -0.3))
		Mats.part(root, Mats.box(Vector3(0.05, 1.2, 0.05)), wood, Vector3(x, 8.0, -0.3))
		Mats.part(root, Mats.box(Vector3(0.7, 0.45, 0.04)), roof, Vector3(x + 0.38, 8.3, -0.3))
		# Hanging banners on the wall.
		Mats.part(root, Mats.box(Vector3(0.9, 1.6, 0.05)), roof, Vector3(width * 0.26 * sgn, 2.3, 0.33))
		Mats.part(root, Mats.box(Vector3(0.5, 0.5, 0.06)), Mats.solid(GOLD, 0.4, 0.5), Vector3(width * 0.26 * sgn, 2.5, 0.35), Vector3(0, 0, 45))
	# The great gate.
	Mats.part(root, Mats.box(Vector3(2.4, 2.6, 0.3)), wood, Vector3(0, 1.3, 0.35))
	for y in [0.5, 1.3, 2.1]:
		Mats.part(root, Mats.box(Vector3(2.5, 0.12, 0.34)), iron, Vector3(0, y, 0.37))
	Mats.bake(root)
	var l := label(str(hp), 260, Color(1.0, 0.92, 0.8))
	l.position = Vector3(0, 4.3, 0.4)
	root.add_child(l)
	root.set_meta("label", l)
	return root


static func coin() -> Node3D:
	var root := Node3D.new()
	Mats.part(root, Mats.cyl(0.2, 0.2, 0.05, 14), Mats.glow(Color(1.0, 0.8, 0.25), 0.9), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	return root
