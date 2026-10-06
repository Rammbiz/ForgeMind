extends Node3D
## Dev preview for WS3 (Meta-1 models, caches and VFX): the 9 live machines at Rank I/II/III
## and Ascended, firing VFX, the Stone/World Caches at every crack stage, the Crystal Altar,
## telegraphs and status visuals. Saves a PNG and quits:
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://scenes/dev/gallery_meta_models.tscn -- --view=VIEW [opts]
## Views:
##   lineup   [--rank=1..3] [--asc]   the 9 machines in a 3×3 grid
##   machine  --id=ID                 one machine: Rank I, II, III and Ascended (+ crew poses)
##   ranks    [--ids=a,b,c]           three machines × Rank I/II/III
##   run      [--ids=a,b,c] [--rank]  run camera: hero, army, convoy firing (phone readability)
##   fire     --id=ID                 the machine firing its VFX at a squad, from the run camera
##   fxlab                            every new projectile / beam / telegraph kind side by side
##   status                           the six squad status visuals
##   caches   [--type=stone|world]    a Cache at crack stages 0..3 with rarity tells
##   rarity                           Stone + World Caches glowing in each rarity
##   altar    [--type] [--stage]      the Crystal Altar with a Cache on it
##   crates                           crate shells per rarity, platinum NEW, BONUS ring, "?" crate
##   dock                             docking sequence frames
##   fit                              prints measured FIT data (no image)
## Common: --name=FILE --t=SECONDS (capture time) --cam=x,y,z --look=x,y,z

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var args := {}
var view := "lineup"
var cam: Camera3D
var fx: Effects
var track: Track
var _t := 0.0
var _shot_at := 1.6
var _done := false
var _machines: Array[Node3D] = []
var _fire := {}
var _caches: Array[Node3D] = []
var _anim_extra: Array[Callable] = []
var _rng := RandomNumberGenerator.new()
var _done_once := {}
var _d := 20.0
var _origin := Vector3.ZERO


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_rng.seed = 11
	seed(11)
	view = str(args.get("view", "lineup"))
	_shot_at = float(args.get("t", "1.6"))
	if view == "fit":
		for k in WeaponModels.KINDS:
			print("FIT ", k, " ", WeaponModels.measure(k))
			for r in [1, 2, 3]:
				var m := WeaponModels.machine(k, {"rank": r})
				print("  rank ", r, " meshes=", _count_meshes(m), " crew=", m.has_meta("crew"))
				m.free()
		var c := CacheModels.cache("stone")
		print("cache stone meshes=", _count_meshes(c))
		c.free()
		var a := CacheModels.altar()
		print("altar meshes=", _count_meshes(a))
		a.free()
		get_tree().quit(0)
		return
	var studio := args.has("studio")
	if studio:
		_studio()
	else:
		track = Track.new()
		add_child(track)
		track.build(160.0, true, Worlds.LIST["space"])
	_origin = Vector3(0, 0, -_d)
	fx = Effects.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 400.0
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	match view:
		"lineup":
			_lineup()
		"machine":
			_one_machine()
		"ranks":
			_ranks()
		"run":
			_run_scene(false)
		"fire":
			_run_scene(true)
		"fxlab":
			_fxlab()
		"status":
			_status()
		"caches":
			_cache_stages()
		"rarity":
			_cache_rarity()
		"altar":
			_altar()
		"crates":
			_crates()
		"dock":
			_dock()
	if args.has("cam"):
		cam.position = _origin + _v3(str(args["cam"]))
	if args.has("look"):
		cam.look_at(_origin + _v3(str(args["look"])))


func _count_meshes(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch is Node3D and not (ch as Node3D).visible:
			continue
		if ch is GeometryInstance3D:
			c += 1
		c += _count_meshes(ch)
	return c


## Camera relative to the scene origin; `fov` is the HORIZONTAL field of view (portrait).
func _studio_cam(pos: Vector3, look: Vector3, fov_h: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(fov_h * 0.5)) / aspect))
	cam.position = _origin + pos
	cam.look_at(_origin + look)


func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## Studio: dark navy stage, key light, rim light, soft environment and glow.
func _studio() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.85)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.rotation_degrees = Vector3(-20, 150, 0)
	add_child(rim)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = Mats.quad(Vector2(60, 60))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.16, 0.3)
	fm.roughness = 0.6
	floor_mi.material_override = fm
	add_child(floor_mi)
	# Soft grid rings on the floor so scale reads.
	for i in 6:
		var r := MeshInstance3D.new()
		r.mesh = Mats.torus(1.0 + i * 1.6, 1.02 + i * 1.6, 64, 3)
		r.material_override = Mats.flat_color(Color(0.3, 0.4, 0.7, 0.25))
		r.position = Vector3(0, 0.005, -2.0)
		r.scale = Vector3(1, 0.05, 1)
		add_child(r)


func _place(kind: String, pos: Vector3, opts := {}) -> Node3D:
	var m := WeaponModels.machine(kind, opts)
	m.position = pos if view in ["run", "fire"] else _origin + pos
	add_child(m)
	_machines.append(m)
	_fire[m] = 0.0
	return m


func _lineup() -> void:
	var rank := int(args.get("rank", "1"))
	var asc := args.has("asc")
	var kinds := ["drone", "ballista", "cannon", "rockets", "mortar", "gatling", "laser", "railgun", "prism"]
	for i in kinds.size():
		var col := i % 3
		var row := i / 3
		var m := _place(kinds[i], Vector3((col - 1) * 1.75, 0, -row * 2.1), {"rank": rank, "ascended": asc})
		m.rotation.y = deg_to_rad(-28)
	_studio_cam(Vector3(0, 6.4, 5.2), Vector3(0, 0.3, -2.2), 50.0)


func _one_machine() -> void:
	var id := str(args.get("id", "mortar"))
	var spots := [[Vector3(-1.05, 0, 0.9), 1, false], [Vector3(1.05, 0, 0.9), 2, false], [Vector3(-1.05, 0, -1.4), 3, false], [Vector3(1.05, 0, -1.4), 3, true]]
	for s: Array in spots:
		var m := _place(id, s[0], {"rank": s[1], "ascended": s[2]})
		m.rotation.y = deg_to_rad(-30)
		if s[1] == 3:
			WeaponModels.set_crew_pose(m, "cheer" if s[2] else "load")
	_studio_cam(Vector3(0.0, 3.6, 4.2), Vector3(0, 0.3, -0.3), 52.0)


func _ranks() -> void:
	var ids := str(args.get("ids", "mortar,gatling,railgun")).split(",")
	for r in ids.size():
		for c in 3:
			var m := _place(ids[r], Vector3((c - 1) * 1.6, 0, -r * 2.0), {"rank": c + 1})
			m.rotation.y = deg_to_rad(-28)
	_studio_cam(Vector3(0, 6.0, 4.8), Vector3(0, 0.3, -2.0), 50.0)


# ------------------------------------------------------------------ run views

var _squad_at := Vector3.ZERO
var _hero: Node3D


func _run_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	cam.fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(20.0)) / aspect)), 50.0, 66.0)
	var h := float(args.get("h", "8.6"))
	cam.position = Vector3(0, h, -_d + 6.0 + (h - 8.6) * 0.8)
	cam.look_at(Vector3(0, 0, -_d - 3.2))


func _run_scene(firing: bool) -> void:
	_run_camera()
	var hz := -_d
	_hero = HeroModels.hero("bolt")
	_hero.position = Vector3(0, 0, hz)
	_hero.rotation.y = PI
	add_child(_hero)
	var n := int(args.get("army", "60"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.soldier_mesh()
	mm.instance_count = n
	var rad := sqrt(n / 30.0) * 1.0
	for i in n:
		var r := sqrt((i + 0.5) / n) * rad
		var a := i * 2.39996
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI + randf_range(-0.2, 0.2)), Vector3(cos(a) * r, 0, hz + 0.6 + rad * 1.15 + sin(a) * r * 1.15)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.vertex_colored(0.8)
	add_child(mmi)
	_squad_at = Vector3(0.4, 0.4, hz - 10.0)
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = Models.raider_mesh()
	rm.instance_count = 30
	for i in 30:
		rm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0.4 + (i % 6 - 2.5) * 0.42, 0, hz - 10.0 - (i / 6) * 0.42)))
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rm
	rmi.material_override = Mats.vertex_colored(0.8)
	add_child(rmi)
	var ids: PackedStringArray
	if firing:
		ids = PackedStringArray([str(args.get("id", "mortar"))])
	else:
		ids = str(args.get("ids", "mortar,gatling,railgun")).split(",")
	var rank := int(args.get("rank", "1"))
	var slots := [Vector3(-(rad + 0.9), 0, hz + 0.6 + rad * 1.1), Vector3(rad + 0.9, 0, hz + 0.6 + rad * 1.1), Vector3(-(rad + 0.9) * 0.5, 0, hz + 0.6 + rad * 2.3 + 1.4)]
	for i in ids.size():
		var id := ids[i]
		var p: Vector3 = slots[i % 3]
		if id == "prism":
			p = Vector3(0, 0, hz - 3.0)
		var m := _place(id, p, {"rank": rank, "ascended": args.has("asc")})
		m.scale = Vector3.ONE * ArsenalData.CONVOY["scale"]
	if args.has("prism") and not "prism" in ids:
		var pr := _place("prism", Vector3(0, 0, hz - 3.0), {"rank": rank})
		pr.scale = Vector3.ONE * ArsenalData.CONVOY["scale"]


func _process(delta: float) -> void:
	_t += delta
	for m in _machines:
		var kind := str(m.get_meta("kind"))
		if view in ["run", "fire"]:
			if kind != "prism":
				WeaponModels.aim(m, _squad_at, 1.0)
		elif view in ["lineup", "machine", "ranks"] and kind in ["mortar", "railgun", "gatling", "laser", "cannon", "rockets", "ballista"]:
			pass
		var k := float(_fire.get(m, 0.0))
		_fire[m] = maxf(k - delta * 2.5, 0.0)
		var f := k
		if kind == "laser" or kind == "gatling":
			f = 1.0 if view in ["run", "fire"] or args.has("firing") else 0.0
		if kind == "railgun":
			WeaponModels.set_charge(m, fposmod(_t, 2.0) / 2.0 if view in ["run", "fire"] or args.has("firing") else 0.6)
		WeaponModels.animate(m, _t, f)
	for c in _caches:
		CacheModels.animate(c, _t)
	for cb in _anim_extra:
		cb.call()
	if view in ["run", "fire"]:
		_shoot()
	if _t >= _shot_at and not _done:
		_done = true
		_save()


var _next := 0.0
var _rail_t := -1.0


func _shoot() -> void:
	for m in _machines:
		var kind := str(m.get_meta("kind"))
		var mz := (m.get_meta("muzzle") as Node3D).global_position
		var tgt := _squad_at + Vector3(0.2, 0.0, 0.3)
		match kind:
			"laser":
				fx.beam(m.get_instance_id(), mz, tgt, WeaponModels.glow_color("laser"), _t > 0.3)
			"gatling":
				fx.stream(m.get_instance_id(), mz, tgt, WeaponModels.glow_color("gatling"), _t > 0.2)
			"railgun":
				var ch := fposmod(_t, 2.0) / 2.0
				var dir := Vector3(0, 0, -1)
				if ch > 0.8:
					fx.rail_telegraph(m.get_instance_id(), Vector3(mz.x, 0.0, mz.z), dir, 22.0, WeaponModels.glow_color("railgun"), true)
				if fposmod(_t, 2.0) < fposmod(_t - 0.016, 2.0) and _t > 0.5:
					fx.rail_fire(mz, mz + dir * 22.0, WeaponModels.glow_color("railgun"))
					_fire[m] = 1.0
	if _t < _next:
		return
	_next = _t + 0.5
	for m in _machines:
		var kind := str(m.get_meta("kind"))
		if kind in ["laser", "gatling", "railgun", "prism"]:
			continue
		var mz := (m.get_meta("muzzle") as Node3D).global_position
		var target := _squad_at + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-0.8, 0.8))
		if kind == "mortar":
			var land := Vector3(_hero.position.x, 0.0, _hero.position.z - 12.0)
			fx.telegraph_ring(land, 1.6, WeaponModels.glow_color("mortar"), 0.8)
			fx.projectile(mz, land, "shell_arc", 0.8, Callable())
		else:
			var pk := Effects.shot_kind(kind)
			fx.projectile(mz, target, pk, mz.distance_to(target) / 16.0, Callable())
		fx.muzzle(mz, WeaponModels.glow_color(kind), (target - mz).normalized())
		_fire[m] = 1.0


# ------------------------------------------------------------------ fx views

func _fxlab() -> void:
	_run_camera()
	var kinds := ["bolt", "orb", "missile_trail", "tracer_dot", "shell_arc", "tracer"]
	for i in kinds.size():
		var x := -2.5 + i * 1.0
		fx.projectile(Vector3(x, 0.5, -_d + 1.0), Vector3(x, 0.5, -_d - 9.0), kinds[i], 3.0, Callable())
		fx.projectile(Vector3(x, 0.5, -_d + 1.0), Vector3(x, 0.5, -_d - 9.0), kinds[i], 4.5, Callable())
	_anim_extra.append(func() -> void:
		fx.stream(1, Vector3(-2.8, 0.6, -_d + 2.0), Vector3(-2.2, 0.4, -_d - 7.0), WeaponModels.glow_color("gatling"), true)
		fx.beam(2, Vector3(2.9, 0.6, -_d + 2.0), Vector3(2.5, 0.3, -_d - 8.0), WeaponModels.glow_color("laser"), true)
		if _once("rails", 0.6):
			fx.rail_telegraph(3, Vector3(1.6, 0.0, -_d + 1.0), Vector3(0, 0, -1), 14.0, WeaponModels.glow_color("railgun"), true)
		if _once("rail", 1.35):
			fx.rail_fire(Vector3(0.6, 0.6, -_d + 1.0), Vector3(0.6, 0.6, -_d - 14.0), WeaponModels.glow_color("railgun"))
		if _once("ring", 0.3):
			fx.telegraph_ring(Vector3(-1.2, 0.0, -_d - 6.0), 1.6, WeaponModels.glow_color("mortar"), 3.0)
			fx.telegraph_enemy(Vector3(1.6, 0.0, -_d - 7.0), 1.4, 3.0)
		if _once("prism", 1.4):
			fx.prism_flash(Vector3(0.0, 1.1, -_d - 3.0), WeaponModels.glow_color("prism"), Vector3(0, 0, -1), 3)
		if _once("boom", 1.45):
			fx.shell_impact(Vector3(-0.2, 0.0, -_d - 9.5), 1.6, WeaponModels.glow_color("mortar")))


func _status() -> void:
	_run_camera()
	var sts := ["stagger", "jolt", "chill", "burn", "mark", "seal"]
	for i in sts.size():
		var p := Vector3(-1.6 + (i % 3) * 1.6, 0.0, -_d - 3.0 - (i / 3) * 3.2)
		var rm := MultiMesh.new()
		rm.transform_format = MultiMesh.TRANSFORM_3D
		rm.mesh = Models.raider_mesh()
		rm.instance_count = 9
		for k in 9:
			rm.set_instance_transform(k, Transform3D(Basis.IDENTITY, p + Vector3((k % 3 - 1) * 0.4, 0, (k / 3 - 1) * 0.4)))
		var rmi := MultiMeshInstance3D.new()
		rmi.multimesh = rm
		rmi.material_override = Mats.vertex_colored(0.8)
		add_child(rmi)
		var st: String = sts[i]
		var id := 100 + i
		_anim_extra.append(func() -> void:
			fx.status(id, p, 0.85, st, 3 if st == "chill" or st == "jolt" else 1, true)
			if _once("pop" + st, 0.4):
				fx.status_pop(p + Vector3(0, 0.6, 0), st))


func _once(key: String, at: float) -> bool:
	if _t >= at and not _done_once.has(key):
		_done_once[key] = true
		return true
	return false


# ------------------------------------------------------------------ caches and altar

func _cache_stages() -> void:
	var type := str(args.get("type", "stone"))
	var rar := ["R", "E", "L", "L"]
	for i in 4:
		var c := CacheModels.cache(type)
		c.position = _origin + Vector3((i % 2) * 2.0 - 1.0, 0, -(i / 2) * 2.4)
		add_child(c)
		CacheModels.set_tell(c, str(args.get("rarity", rar[i])))
		CacheModels.set_crack(c, i)
		_caches.append(c)
	_studio_cam(Vector3(0, 3.4, 4.6), Vector3(0, 0.6, -1.2), 46.0)


func _cache_rarity() -> void:
	var rs := ["C", "R", "E", "L"]
	for i in 4:
		for j in 2:
			var c := CacheModels.cache("stone" if j == 0 else "world")
			c.position = _origin + Vector3((i % 2) * 1.9 - 0.95, 0, -(i / 2) * 2.3 - j * 4.6)
			add_child(c)
			CacheModels.set_tell(c, rs[i])
			CacheModels.set_crack(c, 1)
			_caches.append(c)
	_studio_cam(Vector3(0, 5.8, 5.0), Vector3(0, 0.4, -3.4), 50.0)


func _altar() -> void:
	var a := CacheModels.altar()
	a.position = _origin
	add_child(a)
	_caches.append(a)
	var c := CacheModels.cache(str(args.get("type", "world")))
	add_child(c)
	CacheModels.place_on_altar(a, c)
	var stage := int(args.get("stage", "0"))
	CacheModels.set_tell(c, str(args.get("rarity", "L")))
	CacheModels.set_crack(c, stage)
	CacheModels.altar_light(a, 1.0 if stage > 0 else 0.4, ArsenalData.RARITIES[str(args.get("rarity", "L"))]["ui_color"] if stage > 0 else Color(0.5, 0.8, 1.0))
	_caches.append(c)
	var hero := HeroModels.hero("bolt")
	hero.position = _origin + Vector3(-1.5, 0, 1.3)
	hero.rotation.y = deg_to_rad(150)
	add_child(hero)
	_studio_cam(Vector3(0.6, 2.6, 5.4), Vector3(0, 1.2, 0), 50.0)


func _crates() -> void:
	var specs := [["ballista", 12, {"rarity": "C"}], ["mortar", 18, {"rarity": "R"}], ["railgun", 30, {"rarity": "E", "bonus": 18}],
		["prism", 40, {"rarity": "L"}], ["gatling", 14, {"new": true, "badge": Loc.t("NEW_WEAPON")}], ["deck", 16, {}]]
	for i in specs.size():
		var s: Array = specs[i]
		var c := WeaponModels.crate(s[0], s[1], s[2])
		c.position = _origin + Vector3((i % 3 - 1) * 1.7, 0, -(i / 3) * 2.8)
		add_child(c)
		if s[2].has("bonus"):
			WeaponModels.crate_bonus(c, 0.42)
		_anim_extra.append(func() -> void: WeaponModels.animate(c, _t, 0.0))
	_studio_cam(Vector3(0, 4.4, 5.6), Vector3(0, 0.9, -1.6), 50.0)


func _dock() -> void:
	var us := [0.0, 0.3, 0.55, 0.8, 1.0]
	for i in us.size():
		var m := _place(str(args.get("id", "gatling")), Vector3((i - 2) * 1.25, 0, 0), {"rank": 1})
		m.rotation.y = deg_to_rad(-25)
		var u: float = us[i]
		_anim_extra.append(func() -> void: WeaponModels.dock(m, u))
	_studio_cam(Vector3(0, 3.0, 5.0), Vector3(0, 0.4, 0), 44.0)


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir + "/" + str(args.get("name", "meta_" + view)) + ".png"
	img.save_png(path)
	print("SAVED ", path, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit(0)
