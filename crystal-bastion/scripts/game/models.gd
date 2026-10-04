class_name Models
## Procedural low-poly models for towers, enemies and props.
## Models face +Z. Tower models expose "head" (rotating part) and "muzzle" metadata.

const STONE := Color(0.62, 0.6, 0.58)
const STONE_DARK := Color(0.42, 0.41, 0.42)
const WOOD := Color(0.55, 0.36, 0.2)
const WOOD_DARK := Color(0.38, 0.24, 0.14)
const IRON := Color(0.22, 0.23, 0.27)
const GOLD := Color(1.0, 0.78, 0.3)
const BRASS := Color(0.85, 0.62, 0.3)
const COPPER := Color(0.85, 0.45, 0.25)


static var _templates := {}


## Returns a fresh copy of a cached, baked model. Building + baking happens once per key.
static func _instance(key: String, build: Callable) -> Node3D:
	if not _templates.has(key):
		var tpl: Node3D = build.call()
		Mats.bake(tpl)
		_stable_names(tpl, [0])
		_meta_to_paths(tpl)
		_templates[key] = tpl
	var inst := (_templates[key] as Node3D).duplicate() as Node3D
	_meta_to_nodes(inst)
	return inst


## Auto-generated names ("@Node3D@123") differ between duplicates; give every node a fixed one.
static func _stable_names(n: Node, counter: Array) -> void:
	for ch in n.get_children():
		if str(ch.name).begins_with("@"):
			counter[0] += 1
			ch.name = "n%d" % counter[0]
		_stable_names(ch, counter)


static func _meta_to_paths(root: Node3D) -> void:
	for k in root.get_meta_list():
		var v: Variant = root.get_meta(k)
		if v is Node:
			root.set_meta(k, root.get_path_to(v))
		elif v is Array and not (v as Array).is_empty() and (v as Array)[0] is Node:
			var paths: Array[NodePath] = []
			for n: Node in v:
				paths.append(root.get_path_to(n))
			root.set_meta(k, paths)


static func _meta_to_nodes(root: Node3D) -> void:
	for k in root.get_meta_list():
		var v: Variant = root.get_meta(k)
		if v is NodePath:
			root.set_meta(k, root.get_node(v))
		elif v is Array and not (v as Array).is_empty() and (v as Array)[0] is NodePath:
			var nodes: Array[Node3D] = []
			for pth: NodePath in v:
				nodes.append(root.get_node(pth))
			root.set_meta(k, nodes)


static func clear_templates() -> void:
	for k in _templates:
		(_templates[k] as Node).free()
	_templates.clear()


# ================================================================= towers

static func tower(type: String, level: int) -> Node3D:
	return _instance("tower|%s|%d" % [type, level], _build_tower.bind(type, level))


static func _build_tower(type: String, level: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match type:
		"arrow":
			_arrow_tower(root, level)
		"cannon":
			_cannon_tower(root, level)
		"frost":
			_frost_tower(root, level)
		"tesla":
			_tesla_tower(root, level)
		"laser":
			_laser_tower(root, level)
	return root


static func _plinth(root: Node3D, level: int, accent: Color) -> void:
	Mats.part(root, Mats.cyl(0.43, 0.47, 0.14, 6), Mats.solid(STONE_DARK), Vector3(0, 0.07, 0))
	Mats.part(root, Mats.cyl(0.4, 0.43, 0.06, 6), Mats.solid(STONE), Vector3(0, 0.17, 0))
	# Level gems around the plinth.
	for i in level + 1:
		var a := deg_to_rad(-90.0 + (i - level * 0.5) * 32.0)
		var p := Vector3(cos(a) * 0.41, 0.11, -sin(a) * 0.41)
		Mats.part(root, Mats.crystal(0.045, 0.1), Mats.glow(accent, 1.6), p, Vector3.ZERO, Vector3.ONE, false)


static func _crenellations(root: Node3D, radius: float, y: float, count: int, mat: Material, size := 0.09) -> void:
	for i in count:
		var a := TAU * i / count
		Mats.part(root, Mats.box(Vector3(size, size * 1.1, size)), mat, Vector3(cos(a) * radius, y, sin(a) * radius), Vector3(0, -rad_to_deg(a), 0))


static func _arrow_tower(root: Node3D, level: int) -> void:
	var accent := Color(1.0, 0.7, 0.3)
	_plinth(root, level, accent)
	var h := 0.55 + level * 0.12
	var stone := Mats.solid(STONE)
	Mats.part(root, Mats.cyl(0.26, 0.33, h, 8), stone, Vector3(0, 0.2 + h * 0.5, 0))
	# Wooden bands / windows.
	Mats.part(root, Mats.cyl(0.275, 0.29, 0.05, 8), Mats.solid(WOOD_DARK), Vector3(0, 0.2 + h * 0.35, 0))
	Mats.part(root, Mats.box(Vector3(0.08, 0.14, 0.04)), Mats.solid(Color(0.1, 0.08, 0.08)), Vector3(0, 0.2 + h * 0.6, 0.28))
	var top := 0.2 + h
	Mats.part(root, Mats.cyl(0.34, 0.3, 0.08, 8), Mats.solid(STONE_DARK), Vector3(0, top + 0.04, 0))
	_crenellations(root, 0.3, top + 0.13, 8, stone)
	if level >= 1:
		# Banners
		for s in [-1.0, 1.0]:
			Mats.part(root, Mats.box(Vector3(0.1, 0.22, 0.015)), Mats.solid(Color(0.85, 0.2, 0.2) if level == 1 else Color(0.25, 0.35, 0.9)), Vector3(0.2 * s, 0.2 + h * 0.7, 0.24), Vector3(0, 30 * s, 0))
	if level >= 2:
		Mats.part(root, Mats.cyl(0.35, 0.35, 0.03, 8), Mats.solid(GOLD, 0.35, 0.8), Vector3(0, top + 0.085, 0))
	# Rotating ballista.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, top + 0.12, 0)
	root.add_child(head)
	var wood := Mats.solid(WOOD)
	Mats.part(head, Mats.cyl(0.1, 0.12, 0.08, 6), Mats.solid(WOOD_DARK), Vector3(0, 0.0, 0))
	Mats.part(head, Mats.box(Vector3(0.07, 0.07, 0.42)), wood, Vector3(0, 0.08, 0.04))
	var bow_mat := Mats.solid(GOLD if level >= 2 else WOOD_DARK, 0.5, 0.5 if level >= 2 else 0.0)
	var bows := 2 if level >= 2 else 1
	for b in bows:
		var y := 0.08 + b * 0.07
		Mats.part(head, Mats.box(Vector3(0.24, 0.035, 0.035)), bow_mat, Vector3(0.11, y, 0.2), Vector3(0, -28, 0))
		Mats.part(head, Mats.box(Vector3(0.24, 0.035, 0.035)), bow_mat, Vector3(-0.11, y, 0.2), Vector3(0, 28, 0))
		Mats.part(head, Mats.box(Vector3(0.4, 0.01, 0.01)), Mats.solid(Color(0.95, 0.92, 0.85)), Vector3(0, y, 0.1))
	Mats.part(head, Mats.box(Vector3(0.025, 0.025, 0.36)), Mats.solid(Color(0.9, 0.85, 0.7)), Vector3(0, 0.11, 0.12))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.1, 0.3)
	head.add_child(muzzle)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)


static func _cannon_tower(root: Node3D, level: int) -> void:
	var accent := Color(1.0, 0.45, 0.2)
	_plinth(root, level, accent)
	var stone := Mats.solid(STONE)
	var h := 0.3 + level * 0.06
	Mats.part(root, Mats.cyl(0.36, 0.4, h, 8), stone, Vector3(0, 0.2 + h * 0.5, 0))
	Mats.part(root, Mats.cyl(0.375, 0.39, 0.06, 8), Mats.solid(IRON, 0.5, 0.6), Vector3(0, 0.2 + h * 0.75, 0))
	if level >= 1:
		_crenellations(root, 0.36, 0.2 + h + 0.04, 10, Mats.solid(STONE_DARK), 0.08)
	var top := 0.2 + h
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, top + 0.05, 0)
	root.add_child(head)
	Mats.part(head, Mats.cyl(0.22, 0.25, 0.1, 8), Mats.solid(WOOD_DARK), Vector3(0, 0.03, 0))
	for s in [-1.0, 1.0]:
		Mats.part(head, Mats.box(Vector3(0.05, 0.18, 0.22)), Mats.solid(WOOD), Vector3(0.14 * s, 0.14, 0))
	var barrels := 2 if level >= 2 else 1
	var iron := Mats.solid(IRON, 0.35, 0.75)
	var rad := 0.085 + level * 0.012
	var barrel_root := Node3D.new()
	barrel_root.name = "Barrel"
	barrel_root.position = Vector3(0, 0.18, 0)
	barrel_root.rotation_degrees = Vector3(-12, 0, 0)
	head.add_child(barrel_root)
	for b in barrels:
		var x := 0.0 if barrels == 1 else (b - 0.5) * 0.17
		Mats.part(barrel_root, Mats.cyl(rad * 0.85, rad, 0.5, 10), iron, Vector3(x, 0, 0.12), Vector3(90, 0, 0))
		Mats.part(barrel_root, Mats.cyl(rad * 1.15, rad * 1.15, 0.05, 10), Mats.solid(BRASS, 0.35, 0.8), Vector3(x, 0, 0.36), Vector3(90, 0, 0))
		Mats.part(barrel_root, Mats.sphere(rad * 1.2, -1, 10, 5), iron, Vector3(x, 0, -0.12))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, 0.42)
	barrel_root.add_child(muzzle)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)
	root.set_meta("barrel", barrel_root)


static func _frost_tower(root: Node3D, level: int) -> void:
	var ice := Color(0.55, 0.9, 1.0)
	_plinth(root, level, ice)
	var stone := Mats.solid(Color(0.7, 0.76, 0.84))
	var h := 0.36 + level * 0.1
	Mats.part(root, Mats.cyl(0.18, 0.3, h, 6), stone, Vector3(0, 0.2 + h * 0.5, 0))
	Mats.part(root, Mats.cyl(0.26, 0.2, 0.08, 6), Mats.solid(Color(0.85, 0.92, 1.0), 0.3, 0.3), Vector3(0, 0.2 + h + 0.04, 0))
	# Ice spikes on the sides
	for i in 3 + level:
		var a := TAU * i / (3 + level)
		Mats.part(root, Mats.crystal(0.05, 0.3), Mats.solid(Color(0.75, 0.95, 1.0), 0.15, 0.1), Vector3(cos(a) * 0.27, 0.32, sin(a) * 0.27), Vector3(rad_to_deg(sin(a)) * 0.4, 0, -rad_to_deg(cos(a)) * 0.4))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.2 + h + 0.38, 0)
	root.add_child(head)
	Mats.part(head, Mats.crystal(0.13 + level * 0.02, 0.46 + level * 0.06), Mats.glow(ice, 0.9 + level * 0.25), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in 2 + level:
		var a := TAU * i / (2 + level)
		Mats.part(head, Mats.crystal(0.04, 0.14), Mats.glow(Color(0.8, 0.97, 1.0), 2.0), Vector3(cos(a) * 0.24, 0.02 * i, sin(a) * 0.24), Vector3(0, 0, 0), Vector3.ONE, false)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	head.add_child(muzzle)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)
	root.set_meta("spin", head)


static func _tesla_tower(root: Node3D, level: int) -> void:
	var bolt := Color(0.55, 0.75, 1.0)
	_plinth(root, level, bolt)
	var steel := Mats.solid(Color(0.32, 0.34, 0.4), 0.4, 0.7)
	Mats.part(root, Mats.cyl(0.2, 0.3, 0.2, 8), steel, Vector3(0, 0.3, 0))
	var pole_h := 0.55 + level * 0.1
	Mats.part(root, Mats.cyl(0.05, 0.07, pole_h, 6), Mats.solid(IRON, 0.4, 0.7), Vector3(0, 0.4 + pole_h * 0.5, 0))
	var copper := Mats.solid(COPPER, 0.3, 0.85)
	var rings := 3 + level
	for i in rings:
		var r := 0.2 - i * 0.022
		Mats.part(root, Mats.torus(r - 0.035, r, 14, 5), copper, Vector3(0, 0.45 + i * (pole_h - 0.1) / rings, 0))
	if level >= 2:
		for i in 3:
			var a := TAU * i / 3.0
			Mats.part(root, Mats.cyl(0.02, 0.03, 0.4, 5), Mats.solid(IRON, 0.4, 0.7), Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Vector3(0, 0, 0))
			Mats.part(root, Mats.sphere(0.05, -1, 8, 4), Mats.glow(bolt, 2.5), Vector3(cos(a) * 0.3, 0.67, sin(a) * 0.3), Vector3.ZERO, Vector3.ONE, false)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.45 + pole_h, 0)
	root.add_child(head)
	Mats.part(head, Mats.sphere(0.13 + level * 0.015, -1, 12, 6), Mats.glow(bolt, 2.2), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	Mats.part(head, Mats.torus(0.15, 0.18, 16, 4), Mats.solid(BRASS, 0.3, 0.8), Vector3.ZERO, Vector3(90, 0, 0))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	head.add_child(muzzle)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)
	root.set_meta("pulse", head)


static func _laser_tower(root: Node3D, level: int) -> void:
	var violet := Color(0.85, 0.45, 1.0)
	_plinth(root, level, violet)
	var dark := Mats.solid(Color(0.2, 0.18, 0.26), 0.5, 0.3)
	Mats.part(root, Mats.cyl(0.24, 0.32, 0.22, 6), dark, Vector3(0, 0.31, 0))
	Mats.part(root, Mats.cyl(0.26, 0.26, 0.04, 6), Mats.solid(GOLD, 0.3, 0.85), Vector3(0, 0.43, 0))
	# Three golden prongs holding the crystal.
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		Mats.part(root, Mats.box(Vector3(0.05, 0.42 + level * 0.06, 0.05)), Mats.solid(GOLD, 0.3, 0.85), Vector3(cos(a) * 0.18, 0.62, sin(a) * 0.18), Vector3(rad_to_deg(sin(a)) * 0.25, 0, -rad_to_deg(cos(a)) * 0.25))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.9 + level * 0.06, 0)
	root.add_child(head)
	Mats.part(head, Mats.crystal(0.12 + level * 0.02, 0.36 + level * 0.05), Mats.glow(violet, 1.3 + level * 0.3), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
	for i in level + 1:
		Mats.part(head, Mats.torus(0.2 + i * 0.05, 0.215 + i * 0.05, 20, 3), Mats.glow(Color(1.0, 0.8, 1.0), 1.2), Vector3.ZERO, Vector3(70 - i * 40, i * 50, 0), Vector3.ONE, false)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	head.add_child(muzzle)
	root.set_meta("head", head)
	root.set_meta("muzzle", muzzle)
	root.set_meta("spin", head)


# ================================================================= enemies

static func enemy(type: String, color: Color, size: float) -> Node3D:
	return _instance("enemy|%s|%s|%.3f" % [type, color.to_html(), size], _build_enemy.bind(type, color, size))


static func _build_enemy(type: String, color: Color, size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match type:
		"slime", "slimelet", "splitter":
			_slime(root, color, size, type == "splitter")
		"runner":
			_runner(root, color, size)
		"beetle":
			_beetle(root, color, size)
		"bat":
			_bat(root, color, size)
		"golem":
			_golem(root, color, size)
	return root


static func _eyes(parent: Node3D, y: float, z: float, spread: float, r: float, pupil_color := Color(0.05, 0.05, 0.08)) -> void:
	for s in [-1.0, 1.0]:
		Mats.part(parent, Mats.sphere(r, -1, 10, 5), Mats.solid(Color(1, 1, 1), 0.3), Vector3(spread * s, y, z))
		Mats.part(parent, Mats.sphere(r * 0.55, -1, 8, 4), Mats.solid(pupil_color, 0.2), Vector3(spread * s, y, z + r * 0.6))


static func _slime(root: Node3D, color: Color, size: float, splitter: bool) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var mat := Mats.solid(color, 0.25, 0.0, 0.6)
	Mats.part(body, Mats.sphere(size, size * 1.5, 12, 6), mat, Vector3(0, size * 0.72, 0))
	Mats.part(body, Mats.sphere(size * 0.35, size * 0.3, 8, 3), Mats.solid(color.lightened(0.45), 0.2), Vector3(-size * 0.35, size * 1.2, -size * 0.1))
	_eyes(body, size * 0.95, size * 0.72, size * 0.32, size * 0.17)
	if splitter:
		for i in 3:
			var a := TAU * i / 3.0
			Mats.part(body, Mats.sphere(size * 0.16, -1, 8, 4), Mats.glow(Color(1.0, 0.7, 0.95), 1.5), Vector3(cos(a) * size * 0.75, size * 0.55, sin(a) * size * 0.75 - size * 0.1), Vector3.ZERO, Vector3.ONE, false)
	root.set_meta("anim", "hop")
	root.set_meta("body", body)


static func _runner(root: Node3D, color: Color, size: float) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var skin := Mats.solid(color, 0.6, 0.0, 0.4)
	var dark := Mats.solid(color.darkened(0.45), 0.7)
	Mats.part(body, Mats.sphere(size * 0.55, size * 1.2, 8, 5), skin, Vector3(0, size * 0.95, 0), Vector3(15, 0, 0))
	var head := Node3D.new()
	head.position = Vector3(0, size * 1.65, size * 0.15)
	body.add_child(head)
	Mats.part(head, Mats.sphere(size * 0.48, -1, 10, 5), skin)
	for s in [-1.0, 1.0]:
		Mats.part(head, Mats.cone(size * 0.16, size * 0.55, 5), dark, Vector3(size * 0.38 * s, size * 0.35, -size * 0.05), Vector3(0, 0, -35 * s))
	_eyes(head, size * 0.06, size * 0.38, size * 0.2, size * 0.13, Color(0.9, 0.2, 0.1))
	Mats.part(head, Mats.cone(size * 0.1, size * 0.22, 5), Mats.solid(Color(0.95, 0.9, 0.8)), Vector3(0, -size * 0.18, size * 0.38), Vector3(90, 0, 0))
	var legs: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(size * 0.22 * s, size * 0.6, 0)
		body.add_child(hip)
		Mats.part(hip, Mats.cyl(size * 0.09, size * 0.12, size * 0.6, 5), dark, Vector3(0, -size * 0.3, 0), Vector3.ZERO, Vector3.ONE, false)
		legs.append(hip)
	# Dagger
	Mats.part(body, Mats.box(Vector3(size * 0.06, size * 0.06, size * 0.6)), Mats.solid(Color(0.8, 0.82, 0.88), 0.3, 0.8), Vector3(size * 0.45, size * 0.9, size * 0.3))
	root.set_meta("anim", "run")
	root.set_meta("body", body)
	root.set_meta("legs", legs)


static func _beetle(root: Node3D, color: Color, size: float) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var shell := Mats.solid(color, 0.25, 0.55, 0.3)
	Mats.part(body, Mats.sphere(size, size * 1.0, 10, 5), shell, Vector3(0, size * 0.42, 0), Vector3.ZERO, Vector3(0.95, 1.0, 1.25))
	Mats.part(body, Mats.box(Vector3(size * 0.05, size * 0.06, size * 2.3)), Mats.solid(color.darkened(0.6)), Vector3(0, size * 0.9, 0))
	var dark := Mats.solid(Color(0.12, 0.12, 0.16), 0.5, 0.2)
	Mats.part(body, Mats.sphere(size * 0.42, -1, 8, 4), dark, Vector3(0, size * 0.4, size * 1.05))
	Mats.part(body, Mats.cone(size * 0.12, size * 0.6, 5), Mats.solid(Color(0.95, 0.88, 0.7), 0.4), Vector3(0, size * 0.7, size * 1.3), Vector3(60, 0, 0))
	for s in [-1.0, 1.0]:
		Mats.part(body, Mats.sphere(size * 0.09, -1, 6, 3), Mats.glow(Color(1.0, 0.85, 0.2), 2.0), Vector3(size * 0.2 * s, size * 0.52, size * 1.38), Vector3.ZERO, Vector3.ONE, false)
	var legs: Array[Node3D] = []
	for i in 3:
		for s in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(size * 0.75 * s, size * 0.25, (i - 1) * size * 0.6)
			body.add_child(hip)
			Mats.part(hip, Mats.cyl(size * 0.05, size * 0.06, size * 0.6, 4), dark, Vector3(size * 0.22 * s, -size * 0.1, 0), Vector3(0, 0, 60 * s), Vector3.ONE, false)
			legs.append(hip)
	root.set_meta("anim", "crawl")
	root.set_meta("body", body)
	root.set_meta("legs", legs)


static func _bat(root: Node3D, color: Color, size: float) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var fur := Mats.solid(color, 0.7, 0.0, 0.5)
	var wing_mat := Mats.solid(color.darkened(0.35), 0.8)
	Mats.part(body, Mats.sphere(size * 0.55, size * 1.2, 10, 5), fur, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		Mats.part(body, Mats.cone(size * 0.15, size * 0.4, 4), fur, Vector3(size * 0.25 * s, size * 0.62, 0.0), Vector3(0, 0, -15 * s))
		Mats.part(body, Mats.sphere(size * 0.1, -1, 6, 3), Mats.glow(Color(1.0, 0.25, 0.25), 2.2), Vector3(size * 0.2 * s, size * 0.15, size * 0.48), Vector3.ZERO, Vector3.ONE, false)
	var wings: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(size * 0.35 * s, size * 0.1, 0)
		body.add_child(pivot)
		Mats.part(pivot, Mats.prism(Vector3(size * 1.5, size * 0.8, size * 0.05)), wing_mat, Vector3(size * 0.75 * s, 0, -size * 0.1), Vector3(90, 0, 0), Vector3.ONE, false)
		wings.append(pivot)
	root.set_meta("anim", "fly")
	root.set_meta("body", body)
	root.set_meta("wings", wings)


static func _golem(root: Node3D, color: Color, size: float) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var stone := Mats.solid(color, 0.95)
	var dark := Mats.solid(color.darkened(0.35), 0.95)
	var core := Mats.glow(Color(0.35, 0.95, 1.0), 2.4)
	Mats.part(body, Mats.box(Vector3(size * 1.3, size * 1.1, size * 0.9)), stone, Vector3(0, size * 1.25, 0), Vector3(8, 0, 0))
	Mats.part(body, Mats.box(Vector3(size * 0.65, size * 0.55, size * 0.6)), dark, Vector3(0, size * 2.0, size * 0.2))
	for s in [-1.0, 1.0]:
		Mats.part(body, Mats.box(Vector3(size * 0.14, size * 0.08, size * 0.05)), core, Vector3(size * 0.15 * s, size * 2.05, size * 0.51), Vector3.ZERO, Vector3.ONE, false)
	Mats.part(body, Mats.crystal(size * 0.22, size * 0.4), core, Vector3(0, size * 1.35, size * 0.47), Vector3(90, 0, 0), Vector3.ONE, false)
	for i in 3:
		Mats.part(body, Mats.crystal(size * 0.14, size * 0.6), core, Vector3((i - 1) * size * 0.35, size * 1.9, -size * 0.35), Vector3(-25, 0, (i - 1) * 20), Vector3.ONE, false)
	var arms: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(size * 0.82 * s, size * 1.6, 0)
		body.add_child(sh)
		Mats.part(sh, Mats.box(Vector3(size * 0.4, size * 1.0, size * 0.42)), stone, Vector3(0, -size * 0.45, 0))
		Mats.part(sh, Mats.box(Vector3(size * 0.48, size * 0.4, size * 0.5)), dark, Vector3(0, -size * 1.0, 0))
		arms.append(sh)
	var legs: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(size * 0.38 * s, size * 0.7, 0)
		body.add_child(hip)
		Mats.part(hip, Mats.box(Vector3(size * 0.42, size * 0.7, size * 0.48)), dark, Vector3(0, -size * 0.35, 0))
		legs.append(hip)
	root.set_meta("anim", "stomp")
	root.set_meta("body", body)
	root.set_meta("legs", legs)
	root.set_meta("arms", arms)


## Per-frame procedural animation for enemy models.
static func animate_enemy(model: Node3D, t: float, speed_factor: float) -> void:
	var body: Node3D = model.get_meta("body")
	match str(model.get_meta("anim", "")):
		"hop":
			var p := t * 7.0
			var s := sin(p)
			body.position.y = absf(s) * 0.08
			body.scale = Vector3(1.0 + 0.08 * cos(2.0 * p), 1.0 - 0.1 * cos(2.0 * p), 1.0 + 0.08 * cos(2.0 * p))
		"run":
			var p := t * 13.0
			body.position.y = absf(sin(p)) * 0.04
			var legs: Array = model.get_meta("legs")
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = sin(p + PI * i) * 0.8
		"crawl":
			var p := t * 9.0
			body.position.y = absf(sin(p * 2.0)) * 0.01
			var legs: Array = model.get_meta("legs")
			for i in legs.size():
				(legs[i] as Node3D).rotation.y = sin(p + PI * (i % 2) + i * 0.6) * 0.45
		"fly":
			var p := t * 16.0
			body.position.y = sin(t * 3.0) * 0.06
			var wings: Array = model.get_meta("wings")
			(wings[0] as Node3D).rotation.z = sin(p) * 0.7
			(wings[1] as Node3D).rotation.z = -sin(p) * 0.7
		"stomp":
			var p := t * 4.0
			body.position.y = absf(sin(p)) * 0.05
			body.rotation.z = sin(p) * 0.05
			var legs: Array = model.get_meta("legs")
			var arms: Array = model.get_meta("arms")
			for i in 2:
				(legs[i] as Node3D).rotation.x = sin(p + PI * i) * 0.35
				(arms[i] as Node3D).rotation.x = -sin(p + PI * i) * 0.4


# ================================================================= heroes

static func hero(type: String) -> Node3D:
	return _instance("hero|" + type, _build_hero.bind(type))


static func _build_hero(type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	match type:
		"bolt":
			_speedster(root)
		"titan":
			_giant(root)
	return root


## "Блискавка": a slim speedster in a cobalt suit with gold trim, a cyan visor, swept-back
## gold fins on the helmet and a gold chevron on the chest.
static func _speedster(root: Node3D) -> void:
	var suit := Mats.solid(Color(0.15, 0.36, 0.95), 0.45, 0.1, 0.35)
	var suit_dark := Mats.solid(Color(0.07, 0.13, 0.4), 0.55)
	var gold := Mats.solid(GOLD, 0.3, 0.7)
	var skin := Mats.solid(Color(0.95, 0.76, 0.62), 0.7)
	var visor := Mats.glow(Color(0.25, 0.85, 1.0), 1.1)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	# Torso (narrow waist, broad chest), belt and chest chevron with a small gem.
	Mats.part(body, Mats.cyl(0.13, 0.09, 0.26, 8), suit, Vector3(0, 0.5, 0))
	Mats.part(body, Mats.sphere(0.13, 0.12, 8, 4), suit, Vector3(0, 0.62, 0))
	Mats.part(body, Mats.cyl(0.1, 0.1, 0.05, 8), gold, Vector3(0, 0.37, 0))
	Mats.part(body, Mats.prism(Vector3(0.14, 0.1, 0.03)), gold, Vector3(0, 0.56, 0.115), Vector3(0, 0, 180))
	Mats.part(body, Mats.crystal(0.022, 0.06), visor, Vector3(0, 0.58, 0.135), Vector3(90, 0, 0), Vector3.ONE, false)
	# Head: face in front, helmet over the top and back, visor band and two gold fins.
	Mats.part(body, Mats.cyl(0.032, 0.036, 0.07, 6), skin, Vector3(0, 0.695, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 0.78, 0)
	body.add_child(head)
	Mats.part(head, Mats.sphere(0.08, 0.11, 8, 5), skin, Vector3(0, -0.012, 0.012))
	Mats.part(head, Mats.sphere(0.094, 0.135, 10, 5), suit, Vector3(0, 0.024, -0.02))
	Mats.part(head, Mats.box(Vector3(0.14, 0.028, 0.03)), visor, Vector3(0, 0.014, 0.077), Vector3.ZERO, Vector3.ONE, false)
	for sgn in [-1.0, 1.0]:
		Mats.part(head, Mats.cone(0.03, 0.18, 4), gold, Vector3(0.085 * sgn, 0.045, -0.03), Vector3(-65, 0, -30 * sgn))
	# Arms and legs on pivots for the run cycle.
	var arms: Array[Node3D] = []
	for sgn in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.15 * sgn, 0.66, 0)
		body.add_child(sh)
		Mats.part(sh, Mats.sphere(0.045, -1, 6, 3), suit, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		Mats.part(sh, Mats.cyl(0.032, 0.038, 0.24, 8), suit, Vector3(0, -0.13, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(sh, Mats.cyl(0.042, 0.04, 0.06, 8), gold, Vector3(0, -0.24, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(sh, Mats.sphere(0.036, -1, 6, 3), gold, Vector3(0, -0.29, 0), Vector3.ZERO, Vector3.ONE, false)
		arms.append(sh)
	var legs: Array[Node3D] = []
	for sgn in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.06 * sgn, 0.36, 0)
		body.add_child(hip)
		Mats.part(hip, Mats.cyl(0.045, 0.038, 0.3, 8), suit_dark, Vector3(0, -0.15, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(hip, Mats.box(Vector3(0.075, 0.07, 0.14)), gold, Vector3(0, -0.31, 0.025), Vector3.ZERO, Vector3.ONE, false)
		legs.append(hip)
	root.set_meta("anim", "speedster")
	root.set_meta("body", body)
	root.set_meta("arms", arms)
	root.set_meta("legs", legs)


## "Громило": a hulking giant of mossy green stone with emerald crystals growing from the
## shoulders and back, gold bracers and belt, glowing eyes and huge fists. Warm greens and
## gold keep it apart from the grey, cyan-cored golem enemy.
static func _giant(root: Node3D) -> void:
	var stone := Mats.solid(Color(0.43, 0.5, 0.36), 0.95)
	var stone_dark := Mats.solid(Color(0.27, 0.32, 0.24), 0.95)
	var moss := Mats.solid(Color(0.36, 0.66, 0.24), 0.95)
	var gold := Mats.solid(GOLD, 0.35, 0.7)
	var gem := Mats.glow(Color(0.15, 0.95, 0.4), 1.15)
	var eye := Mats.glow(Color(1.0, 0.85, 0.3), 1.3)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	Mats.part(body, Mats.sphere(0.34, 0.6, 9, 5), stone, Vector3(0, 0.72, 0), Vector3(10, 0, 0), Vector3(1.0, 1.0, 0.85))
	Mats.part(body, Mats.sphere(0.3, 0.18, 9, 4), moss, Vector3(0, 0.99, -0.06), Vector3.ZERO, Vector3(1.0, 1.0, 0.9))
	Mats.part(body, Mats.box(Vector3(0.44, 0.13, 0.32)), stone_dark, Vector3(0, 0.46, 0.02))
	Mats.part(body, Mats.box(Vector3(0.46, 0.06, 0.34)), gold, Vector3(0, 0.5, 0.02))
	Mats.part(body, Mats.box(Vector3(0.1, 0.09, 0.04)), gold, Vector3(0, 0.5, 0.2))
	# Small head sunk between the shoulders.
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, 0.16)
	body.add_child(head)
	Mats.part(head, Mats.box(Vector3(0.2, 0.17, 0.18)), stone_dark, Vector3.ZERO, Vector3(5, 0, 0))
	Mats.part(head, Mats.box(Vector3(0.22, 0.04, 0.2)), stone, Vector3(0, 0.06, 0.01))
	for sgn in [-1.0, 1.0]:
		Mats.part(head, Mats.box(Vector3(0.05, 0.025, 0.02)), eye, Vector3(0.05 * sgn, 0.0, 0.095), Vector3.ZERO, Vector3.ONE, false)
	# Emerald growths on the back.
	for i in 5:
		var x := (i - 2) * 0.11
		Mats.part(body, Mats.crystal(0.06, 0.34 - absf(i - 2) * 0.07), gem, Vector3(x, 0.98, -0.24), Vector3(-35, 0, (i - 2) * 18), Vector3.ONE, false)
	var arms: Array[Node3D] = []
	for sgn in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.38 * sgn, 0.9, 0)
		body.add_child(sh)
		Mats.part(sh, Mats.sphere(0.15, 0.19, 7, 4), stone, Vector3(0, 0.02, 0))
		Mats.part(sh, Mats.sphere(0.12, 0.08, 7, 3), moss, Vector3(0, 0.1, 0))
		for k in 2:
			Mats.part(sh, Mats.crystal(0.05, 0.22 - k * 0.06), gem, Vector3((0.03 + k * 0.06) * sgn, 0.14, -0.03 + k * 0.05), Vector3(-10, 0, -(20 + k * 25) * sgn), Vector3.ONE, false)
		Mats.part(sh, Mats.cyl(0.1, 0.12, 0.36, 7), stone, Vector3(0, -0.2, 0))
		Mats.part(sh, Mats.cyl(0.13, 0.13, 0.08, 8), gold, Vector3(0, -0.33, 0.01))
		Mats.part(sh, Mats.box(Vector3(0.23, 0.22, 0.25)), stone_dark, Vector3(0, -0.46, 0.02))
		arms.append(sh)
	var legs: Array[Node3D] = []
	for sgn in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.16 * sgn, 0.4, 0)
		body.add_child(hip)
		Mats.part(hip, Mats.cyl(0.11, 0.13, 0.34, 7), stone_dark, Vector3(0, -0.2, 0))
		Mats.part(hip, Mats.box(Vector3(0.2, 0.08, 0.26)), stone, Vector3(0, -0.36, 0.03))
		legs.append(hip)
	root.set_meta("anim", "giant")
	root.set_meta("body", body)
	root.set_meta("arms", arms)
	root.set_meta("legs", legs)


## Per-frame hero animation. `attack` runs 1 -> 0 over one swing.
static func animate_hero(model: Node3D, t: float, moving: bool, attack: float) -> void:
	var body: Node3D = model.get_meta("body")
	var arms: Array = model.get_meta("arms")
	var legs: Array = model.get_meta("legs")
	var swing := sin(PI * clampf(1.0 - attack, 0.0, 1.0)) if attack > 0.0 else 0.0
	match str(model.get_meta("anim", "")):
		"speedster":
			if moving:
				var p := t * 22.0
				body.position.y = absf(sin(p)) * 0.03
				body.rotation.x = 0.4
				for i in 2:
					(legs[i] as Node3D).rotation.x = sin(p + PI * i) * 1.1
					(arms[i] as Node3D).rotation.x = -sin(p + PI * i) * 1.0
			else:
				var p := t * 3.0
				body.position.y = sin(p) * 0.01
				body.rotation.x = 0.08
				for i in 2:
					(legs[i] as Node3D).rotation.x = 0.0
					(arms[i] as Node3D).rotation.x = -0.25 + sin(p + i) * 0.05
				if attack > 0.0:
					# Flurry of punches, alternating hands.
					var punch := sin(attack * TAU * 2.0)
					(arms[0] as Node3D).rotation.x = -1.5 * maxf(punch, 0.0) - 0.25
					(arms[1] as Node3D).rotation.x = -1.5 * maxf(-punch, 0.0) - 0.25
		"giant":
			var p := t * (5.0 if moving else 1.6)
			body.position.y = absf(sin(p)) * (0.05 if moving else 0.015)
			body.rotation.z = sin(p) * (0.06 if moving else 0.02)
			for i in 2:
				(legs[i] as Node3D).rotation.x = sin(p + PI * i) * (0.45 if moving else 0.0)
				(arms[i] as Node3D).rotation.x = -sin(p + PI * i) * (0.35 if moving else 0.08) - 2.4 * swing
			body.rotation.x = 0.25 * swing


# ================================================================= props

static func coin() -> Node3D:
	var root := Node3D.new()
	Mats.part(root, Mats.cyl(0.11, 0.11, 0.03, 12), Mats.glow(Color(1.0, 0.8, 0.25), 0.9), Vector3.ZERO, Vector3(90, 0, 0), Vector3.ONE, false)
	return root
