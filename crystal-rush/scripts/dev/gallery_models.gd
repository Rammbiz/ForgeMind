extends Node3D
## Dev preview for Models: gates of every kind, hazards, geodes, soldiers of each tier, the enemy
## fortress (intact and damaged), the multiplier stairs and the ult ring, on a dark blue plane
## under the run's sun and sky. Saves one PNG per shot and quits:
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_models.tscn
##       [-- --out=DIR] [--only=overview,gates]

const SHOTS := ["overview", "gates", "gates2", "hazards", "units", "crowd", "fortress", "fortress_dmg",
		"stairs", "ult", "context", "anim", "hazards2"]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var cam: Camera3D
var stage: Node3D
var floor_node: Node3D
var _t := 0.0
var _spinners: Array[Node3D] = []
var _sweepers: Array[Node3D] = []
var _turrets: Array[Node3D] = []


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only: Array = SHOTS.duplicate()
	if args.has("only"):
		only = str(args["only"]).split(",")
	_build_env()
	_run(only)


func _process(delta: float) -> void:
	_t += delta
	for s in _spinners:
		if is_instance_valid(s):
			s.rotation.y = _t * 3.2
	for s in _sweepers:
		if is_instance_valid(s):
			(s.get_meta("bar") as Node3D).position.x = sin(_t * 1.4) * 1.6 + 0.6
	for tr in _turrets:
		if is_instance_valid(tr):
			(tr.get_meta("head") as Node3D).rotation.y = sin(_t * 0.8) * 0.5 + float(tr.get_meta("aim", 0.0))


func _run(list: Array) -> void:
	for name in list:
		_clear()
		var hold := 1.2
		match str(name):
			"overview":
				_overview()
			"gates":
				_gates_a()
			"gates2":
				_gates_b()
			"hazards":
				_hazards()
			"units":
				_units()
			"crowd":
				_crowd()
			"fortress":
				_fortress(0.0)
			"fortress_dmg":
				_fortress(0.85)
				hold = 2.4
			"stairs":
				_stairs()
			"ult":
				_ult()
			"context":
				if not _context():
					continue
			"anim":
				_anim()
			"asset":
				# GLB override path: the road module stands in for a geode and the soldier mesh.
				var w := (Worlds.LIST["space"] as Dictionary).duplicate(true)
				w["models"] = {"geode": "res://assets/worlds/space/road.glb", "soldier": "res://assets/worlds/space/road.glb"}
				Models.use_world(w)
				var g := _add(Models.geode("army"), Vector3(-1.2, 0, -3.0))
				(g.get_meta("label") as Label3D).text = "GLB"
				var mi := MeshInstance3D.new()
				mi.mesh = Models.soldier_mesh(1)
				var tex := Models.asset_texture("soldier")
				var m := StandardMaterial3D.new()
				m.albedo_texture = tex
				mi.material_override = m
				_add(mi, Vector3(1.2, 0, -3.0))
				print("asset aabb geode=", Models._mesh_aabb(g, true), " soldier=", mi.mesh.get_aabb(), " tex=", tex)
				Models.use_world({})
				_cam(Vector3(0.0, 2.6, 1.0), Vector3(0, 0.5, -3.0), 55.0)
			"hazards2":
				var rot := _add(Models.rotor(1.4), Vector3(-1.4, 0, -3.2))
				_spinners.append(rot.get_meta("spin"))
				var tr := _add(Models.turret(), Vector3(1.9, 0, -2.4), -0.5)
				(tr.get_meta("label") as Label3D).text = "15"
				tr.set_meta("aim", -0.5)
				_turrets.append(tr)
				var sw := _add(Models.sweeper(2.2), Vector3(0, 0, -6.5))
				_sweepers.append(sw)
				var t2 := _add(Models.turret(), Vector3(-3.25, 0, -8.5), 0.6)
				(t2.get_meta("label") as Label3D).text = "9"
				Models.damage(t2, 0.6)
				_cam(Vector3(0.0, 4.2, 2.6), Vector3(0, 0.4, -4.0), 62.0)
			"trail":
				var rot := Models.rotor(1.4)
				_add(rot, Vector3(0, 0, -3.0))
				var sp := rot.get_meta("spin") as Node3D
				for ch in sp.get_children():
					print(ch.name, " ", ch.get_class(), " ", (ch as MeshInstance3D).mesh.get_aabb() if ch is MeshInstance3D else "", " vis=", (ch as Node3D).visible)
				_cam(Vector3(0.0, 4.0, -1.0), Vector3(0, 0.0, -3.0), 60.0)
			"smoke":
				var sp := _add(Models.spikes(2.4, 16), Vector3(0, 0, -1.6))
				Models.damage(sp, 0.9)
				_cam(Vector3(0.0, 2.0, 1.6), Vector3(0, 0.6, -1.6), 50.0)
			_:
				continue
		await get_tree().create_timer(hold).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := out_dir.path_join("models_%s.png" % name)
		img.save_png(path)
		print("saved ", path)
	get_tree().quit(0)


func _clear() -> void:
	if stage:
		stage.free()
	stage = Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	_spinners.clear()
	_sweepers.clear()
	_turrets.clear()
	floor_node.visible = true


func _build_env() -> void:
	var env := Environment.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/worlds/space/sky.png")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.75)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(0.92, 0.94, 1.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.05
	add_child(sun)
	floor_node = Node3D.new()
	add_child(floor_node)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://assets/textures/stone_floor.png")
	floor_mat.albedo_color = Color(0.2, 0.32, 0.62)
	floor_mat.uv1_scale = Vector3(6, 16, 1)
	floor_mat.roughness = 0.7
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 120.0)
	var road := MeshInstance3D.new()
	road.mesh = plane
	road.material_override = floor_mat
	road.position = Vector3(0, 0, -40)
	floor_node.add_child(road)
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.05, 0.08, 0.2)
	var under := PlaneMesh.new()
	under.size = Vector2(200, 200)
	var deep := MeshInstance3D.new()
	deep.mesh = under
	deep.material_override = void_mat
	deep.position = Vector3(0, -0.02, -40)
	floor_node.add_child(deep)
	for sgn in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.35, 120)
		rail.mesh = bm
		rail.material_override = Mats.solid(Color(0.75, 0.8, 0.95), 0.4, 0.0, 0.3)
		rail.position = Vector3(3.62 * sgn, 0.17, -40)
		floor_node.add_child(rail)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 300.0
	add_child(cam)
	cam.make_current()


func _cam(pos: Vector3, at: Vector3, fov := 50.0) -> void:
	cam.fov = fov
	cam.position = pos
	cam.look_at(at)


func _add(n: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	stage.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	return n


func _gate(w: float, pos: Vector3, text: String, sub: String, kind: String, icon := "", charge := 0.0) -> Node3D:
	var g := Models.gate(w)
	_add(g, pos)
	if kind == "charge":
		g.set_meta("charge", charge)
	Models.gate_style(g, text, sub, kind, icon)
	return g


func _row_a(z: float) -> void:
	_gate(1.7, Vector3(-2.6, 0, z), "+15", "→ 47", "good")
	_gate(1.7, Vector3(-0.87, 0, z), "−10", "→ 22", "bad")
	_gate(1.7, Vector3(0.87, 0, z), "−20", "→ ×2", "charge", "", 0.4)
	_gate(1.7, Vector3(2.6, 0, z), "", "", "hidden")


func _row_b(z: float) -> void:
	_gate(2.2, Vector3(-2.3, 0, z), "+20%", "", "power", "rate")
	_gate(2.2, Vector3(0.0, 0, z), "Арбалети", "", "arm", "crossbow")
	_gate(2.2, Vector3(2.3, 0, z), "×2", "→ 64", "closed")


func _overview() -> void:
	_cam(Vector3(0, 11.2, 8.8), Vector3(0, 0, -3.2), 66.0)
	var ring := Models.ult_ring()
	_add(ring, Vector3(0, 0, 0))
	Models.ult_ring_set(ring, 0.65, false)
	var hero := HeroModels.hero("bolt")
	_add(hero, Vector3.ZERO, PI)
	_blob(Models.soldier_mesh(0), Vector3(0, 0, 2.6), 60, 1.6)
	_row_a(-5.0)
	_row_b(-10.5)
	_add(Models.spikes(3.0, 24), Vector3(-1.9, 0, -15.0))
	var rot := _add(Models.rotor(1.4), Vector3(2.0, 0, -15.5))
	_spinners.append(rot.get_meta("spin"))
	var tl := _add(Models.turret(), Vector3(-3.25, 0, -18.5), 0.5)
	(tl.get_meta("label") as Label3D).text = "12"
	_turrets.append(tl)
	tl.set_meta("aim", 0.5)
	var tr := _add(Models.turret(), Vector3(3.25, 0, -18.5), -0.5)
	(tr.get_meta("label") as Label3D).text = "12"
	tr.set_meta("aim", -0.5)
	_turrets.append(tr)
	var sw := _add(Models.sweeper(2.2), Vector3(0, 0, -21.0))
	_sweepers.append(sw)
	var k := 0
	for r in ["army", "coins", "ult"]:
		var g := _add(Models.geode(r), Vector3(-2.2 + k * 2.2, 0, -25.0))
		(g.get_meta("label") as Label3D).text = str(8 + k * 4)
		k += 1
	_blob(Models.raider_mesh(), Vector3(0, 0, -29.0), 30, 1.3, true)
	_add(Models.fortress(7.0, 120), Vector3(0, 0, -36.0))


func _gates_a() -> void:
	_row_a(-5.0)
	_cam(Vector3(0.0, 4.6, 3.6), Vector3(0, 1.0, -5.0), 60.0)


func _gates_b() -> void:
	_row_b(-5.0)
	_gate(1.7, Vector3(-2.3, 0, -10.5), "+8", "→ 33", "charge", "", 1.0)
	_gate(1.7, Vector3(0.0, 0, -10.5), "×3", "→ 90", "good")
	_gate(1.7, Vector3(2.3, 0, -10.5), "+1", "", "power", "multi")
	_cam(Vector3(-1.2, 5.6, 2.8), Vector3(0, 0.8, -6.8), 55.0)


func _hazards() -> void:
	var s := _add(Models.spikes(3.2, 30), Vector3(-1.6, 0, -4.0))
	var rot := _add(Models.rotor(1.4), Vector3(1.8, 0, -7.6))
	_spinners.append(rot.get_meta("spin"))
	var tr := _add(Models.turret(), Vector3(3.25, 0, -3.5), -0.6)
	(tr.get_meta("label") as Label3D).text = "15"
	tr.set_meta("aim", -0.6)
	_turrets.append(tr)
	var sw := _add(Models.sweeper(2.0), Vector3(0, 0, -11.0))
	_sweepers.append(sw)
	var s2 := _add(Models.spikes(1.6, 9), Vector3(-2.2, 0, -8.0))
	Models.damage(s2, 0.8)
	s.name = "spikes_main"
	_cam(Vector3(0.0, 6.4, 4.2), Vector3(0.4, 0.4, -6.0), 64.0)


func _units() -> void:
	var k := 0
	for r in ["army", "coins", "ult"]:
		var g := _add(Models.geode(r), Vector3(-2.2 + k * 2.2, 0, -8.5))
		(g.get_meta("label") as Label3D).text = str(8 + k * 4)
		k += 1
	for t in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.soldier_mesh(t)
		mi.material_override = Models.vertex_material()
		mi.scale = Vector3.ONE * 1.8
		_add(mi, Vector3(-2.1 + t * 1.3, 0, -2.6), 0.35)
		var back := MeshInstance3D.new()
		back.mesh = Models.soldier_mesh(t)
		back.material_override = Models.vertex_material()
		back.scale = Vector3.ONE * 1.8
		_add(back, Vector3(-2.1 + t * 1.3, 0, -5.0), PI + 0.3)
	var rd := MeshInstance3D.new()
	rd.mesh = Models.raider_mesh()
	rd.material_override = Models.vertex_material()
	rd.scale = Vector3.ONE * 1.8
	_add(rd, Vector3(1.9, 0, -2.6), -0.35)
	var rd2 := MeshInstance3D.new()
	rd2.mesh = Models.raider_mesh()
	rd2.material_override = Models.vertex_material()
	rd2.scale = Vector3.ONE * 1.8
	_add(rd2, Vector3(1.9, 0, -5.0), PI - 0.3)
	_cam(Vector3(0.0, 3.6, 2.4), Vector3(0, 0.7, -4.6), 58.0)


## Each tier as a small blob seen from the run camera, plus an enemy squad.
func _crowd() -> void:
	_blob(Models.soldier_mesh(0), Vector3(-2.2, 0, 1.5), 40, 1.1)
	_blob(Models.soldier_mesh(1), Vector3(0.0, 0, 1.5), 40, 1.1)
	_blob(Models.soldier_mesh(2), Vector3(2.2, 0, 1.5), 40, 1.1)
	_blob(Models.raider_mesh(), Vector3(0, 0, -5.0), 40, 1.4, true)
	var ring := Models.ult_ring()
	_add(ring, Vector3(0, 0, -1.5))
	Models.ult_ring_set(ring, 1.0, true)
	_cam(Vector3(0, 11.2, 8.8), Vector3(0, 0, -3.2), 66.0)


func _blob(mesh: Mesh, center: Vector3, n: int, radius: float, enemy := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 13 + int(center.x * 10)
	for i in n:
		var r := radius * sqrt((i + 0.5) / n)
		var a := i * 2.39996
		var p := center + Vector3(r * cos(a), 0, r * sin(a) * 1.15)
		var yaw := 0.0 if enemy else PI
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.15, 0.15)), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Models.vertex_material()
	stage.add_child(mmi)


func _fortress(dmg: float) -> void:
	var f := _add(Models.fortress(7.0, 120 if dmg == 0.0 else 18), Vector3(0, 0, -8.0))
	if dmg > 0.0:
		Models.damage(f, 0.3)
		Models.damage(f, dmg)
	_blob(Models.soldier_mesh(0), Vector3(0, 0, -3.5), 50, 1.5)
	_cam(Vector3(0, 7.5, 6.5), Vector3(0, 3.0, -7.0), 60.0)


func _stairs() -> void:
	var st := _add(Models.stairs([1.2, 1.4, 1.6, 1.8, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0], 6.0), Vector3(0, 0, -4.0))
	var steps: Array = st.get_meta("steps")
	# A few soldiers already standing on the lower steps.
	for i in 3:
		_blob(Models.soldier_mesh(0), Vector3(0, 0, -4.0) + (steps[i] as Vector3), 10 - i * 3, 0.9)
	_cam(Vector3(6.5, 9.0, 6.0), Vector3(0, 2.0, -11.0), 60.0)


func _ult() -> void:
	var vals := [[0.3, false], [0.8, false], [1.0, true]]
	for i in 3:
		var ring := Models.ult_ring()
		var x := -2.3 + i * 2.3
		_add(ring, Vector3(x, 0, -3.0))
		Models.ult_ring_set(ring, vals[i][0], vals[i][1])
		var hero := HeroModels.hero("bolt" if i != 1 else "titan")
		_add(hero, Vector3(x, 0, -3.0), PI * 0.9)
	_cam(Vector3(0, 6.0, 2.6), Vector3(0, 0.3, -3.2), 58.0)


## The real space track (if Track loads), with a gate row and hazards, from the run camera.
func _context() -> bool:
	var script := load("res://scripts/run/track.gd") as Script
	if script == null:
		return false
	var track := script.new() as Node3D
	if track == null or not track.has_method("build"):
		return false
	floor_node.visible = false
	stage.add_child(track)
	track.call("build", 80.0, true, Worlds.for_level(1))
	var hero := HeroModels.hero("bolt")
	_add(hero, Vector3.ZERO, PI)
	var ring := Models.ult_ring()
	_add(ring, Vector3.ZERO)
	Models.ult_ring_set(ring, 0.45, false)
	_blob(Models.soldier_mesh(1), Vector3(0, 0, 2.6), 50, 1.5)
	_gate(2.0, Vector3(-2.3, 0, -6.0), "+12", "→ 42", "good")
	_gate(2.0, Vector3(0.0, 0, -6.0), "×2", "→ 60", "good")
	_gate(2.0, Vector3(2.3, 0, -6.0), "−15", "→ 15", "bad")
	_add(Models.spikes(2.6, 20), Vector3(1.8, 0, -12.0))
	var g := _add(Models.geode("coins"), Vector3(-2.2, 0, -12.5))
	(g.get_meta("label") as Label3D).text = "10"
	var tr := _add(Models.turret(), Vector3(-3.25, 0, -17.0), 0.5)
	(tr.get_meta("label") as Label3D).text = "8"
	tr.set_meta("aim", 0.5)
	_turrets.append(tr)
	_gate(1.6, Vector3(-1.6, 0, -20.0), "", "", "hidden")
	_gate(1.6, Vector3(1.6, 0, -20.0), "Бластери", "", "arm", "blaster")
	_cam(Vector3(0, 11.2, 8.8), Vector3(0, 0, -3.2), 66.0)
	return true


## Runtime paths: a gate folding closed in the tree, a charge filling, a hit flash, damage stages
## applied one by one to a barricade, and the ult ring filling to ready.
func _anim() -> void:
	var a := _gate(1.9, Vector3(-2.1, 0, -5.0), "+10", "→ 40", "good")
	var b := _gate(1.9, Vector3(0.0, 0, -5.0), "−12", "→ 0", "charge", "", 0.0)
	var c := _gate(1.9, Vector3(2.1, 0, -5.0), "×2", "→ 60", "good")
	var sp := _add(Models.spikes(2.4, 16), Vector3(0, 0, -1.6))
	var ring := Models.ult_ring()
	_add(ring, Vector3(-2.2, 0, -1.2))
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void: Models.gate_style(a, "+10", "", "closed"))
	tw.tween_method(func(v: float) -> void:
		Models.gate_charge(b, v)
		Models.ult_ring_set(ring, v, v >= 1.0)
		Models.damage(sp, v), 0.0, 0.75, 0.6)
	tw.tween_callback(func() -> void:
		Models.gate_hit(c)
		Models.gate_style(b, "+4", "→ 44", "charge"))
	_cam(Vector3(0.0, 5.0, 3.6), Vector3(0, 0.8, -4.0), 62.0)
