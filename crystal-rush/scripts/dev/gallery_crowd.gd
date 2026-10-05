extends Node3D
## Dev preview for CrowdView / UnitFx: a 220-unit army blob behind the hero, a red enemy squad,
## grey recruits, continuous deaths with puffs and debris, and the emerald overlay.
## Saves a few frames and quits:
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_crowd.tscn
##       [-- --out=DIR] [--bench]
## `--bench` (works headless) times CrowdView.draw() and UnitFx for 220 units instead.

const ARMY := 220
const SQUAD := 48
const RECRUITS := 7
const BLOB_R := 2.2
const BLOB_STRETCH := 1.15
const ARMY_Z := 0.9 + BLOB_R * BLOB_STRETCH     # blob centre behind the hero at z = 0
const SQUAD_Z := -7.5
const SHOTS := [
	{"t": 1.10, "name": "crowd_a", "cam": "game"},
	{"t": 1.17, "name": "crowd_b", "cam": "game"},
	{"t": 1.70, "name": "crowd_c", "cam": "game", "overlay": true},
	{"t": 2.05, "name": "crowd_close", "cam": "close"},
	{"t": 2.30, "name": "crowd_close2", "cam": "close2"},
]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var army: CrowdView
var squad: CrowdView
var recruits: CrowdView
var fx: UnitFx
var cam: Camera3D
var hero: Node3D
var _slots := PackedVector3Array()
var _pos := PackedVector3Array()
var _squad_slots := PackedVector3Array()
var _squad_pos := PackedVector3Array()
var _rec_pos := PackedVector3Array()
var _t := 0.0
var _shot := 0
var _next_death := 0.0
var _next_flash := 0.0
var _busy := false
var _dbg := 0
var _meshy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(args.get("out", out_dir))
	_dbg = int(args.get("dbg", "0"))
	_meshy = args.has("meshy")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_rng.seed = 42
	if args.has("bench"):
		_bench()
		get_tree().quit(0)
		return
	_build_world()
	_build_crowds()


func _build_world() -> void:
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
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.05
	add_child(sun)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://assets/textures/stone_floor.png")
	floor_mat.albedo_color = Color(0.2, 0.3, 0.55)
	floor_mat.uv1_scale = Vector3(4, 8, 1)
	floor_mat.roughness = 0.7
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, 80.0)
	var road := MeshInstance3D.new()
	road.mesh = plane
	road.material_override = floor_mat
	road.position = Vector3(0, 0, -20)
	add_child(road)
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.03, 0.05, 0.12)
	var under := PlaneMesh.new()
	under.size = Vector2(60, 120)
	var deep := MeshInstance3D.new()
	deep.mesh = under
	deep.material_override = void_mat
	deep.position = Vector3(0, -0.6, -20)
	add_child(deep)
	for sgn in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.35, 80)
		rail.mesh = bm
		rail.material_override = Mats.solid(Color(0.75, 0.8, 0.95), 0.4, 0.5)
		rail.position = Vector3(3.62 * sgn, 0.17, -20)
		add_child(rail)
	hero = HeroModels.hero("bolt")
	hero.rotation.y = PI
	add_child(hero)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 66.0
	cam.far = 200.0
	add_child(cam)
	_place_cam("game")
	cam.make_current()


func _place_cam(kind: String) -> void:
	match kind:
		"close":
			cam.fov = 50.0
			cam.position = Vector3(1.6, 3.6, 4.6)
			cam.look_at(Vector3(0.0, 0.3, 0.6))
		"close2":
			cam.fov = 45.0
			cam.position = Vector3(3.3, 2.4, -0.6)
			cam.look_at(Vector3(-0.2, 0.2, -4.6))
		_:
			cam.fov = 66.0
			cam.position = Vector3(0, 11.2, 8.8)
			cam.look_at(Vector3(0, 0, -3.2))


func _build_crowds() -> void:
	army = CrowdView.new()
	army.name = "Army"
	add_child(army)
	army.setup(Models.soldier_mesh(), ARMY)
	army.set_tint(Color.WHITE)
	army.set_edge(Color(0.55, 0.8, 1.0), 0.35)
	squad = CrowdView.new()
	squad.name = "Squad"
	add_child(squad)
	squad.setup(Models.raider_mesh(), 64)
	squad.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	squad.set_gait(14.0)
	recruits = CrowdView.new()
	recruits.name = "Recruits"
	add_child(recruits)
	if _meshy:
		# Stand-in for a textured Meshy GLB: no vertex colours, an albedo texture.
		var cap := CapsuleMesh.new()
		cap.radius = 0.18
		cap.height = 0.7
		recruits.setup(cap, 16, load("res://assets/models/heroes/bolt_albedo.jpg"))
		recruits.position.y = 0.35
	else:
		recruits.setup(Models.soldier_mesh(), 16)
		recruits.set_saturation(0.0)
		recruits.set_tint(Color(0.8, 0.82, 0.86))
	fx = UnitFx.new()
	fx.name = "UnitFx"
	add_child(fx)
	fx.setup(Models.soldier_mesh(), Models.raider_mesh())
	# Army: sunflower blob in an ellipse, stretched backwards, front rank first.
	for i in ARMY:
		var r := BLOB_R * sqrt((i + 0.5) / ARMY)
		var a := i * 2.39996
		var p := Vector3(r * cos(a), 0, r * sin(a) * BLOB_STRETCH + ARMY_Z)
		p += Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))
		_slots.append(p)
	_pos = _slots.duplicate()
	var per_row := 8
	for i in SQUAD:
		var row := i / per_row
		var col := i % per_row
		_squad_slots.append(Vector3((col - (per_row - 1) * 0.5) * 0.44 + (0.12 if row % 2 == 1 else 0.0), 0, SQUAD_Z - row * 0.46))
	_squad_pos = _squad_slots.duplicate()
	for i in RECRUITS:
		var a := i * 2.39996
		var r := 0.32 * sqrt(i + 0.5)
		_rec_pos.append(Vector3(2.4 + r * cos(a), 0, -3.6 + r * sin(a)))
	# Pre-roll some deaths so debris is already lying on the road.
	for i in 14:
		var p := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-6.0, -1.0))
		fx.debris(p + Vector3(0, 0.3, 0), (UnitFx.DEBRIS_COLORS[i % 2] as Array)[i % 3], 2)


func _process(delta: float) -> void:
	if army == null or _busy:
		return
	_t += minf(delta, 1.0 / 30.0)
	# Gentle drift of the slots, like units springing around their places.
	for i in ARMY:
		var s := _slots[i]
		_pos[i] = s + Vector3(sin(_t * 1.7 + i) * 0.03, 0, cos(_t * 1.3 + i * 0.7) * 0.03)
	army.draw(_pos, ARMY, PI, 0.08, 0.08)
	var charge := clampf(_t * 0.6, 0.0, 1.0)
	for i in SQUAD:
		_squad_pos[i] = _squad_slots[i] + Vector3(0, 0, charge * (0.8 + 0.2 * (i % 3)))
	squad.draw(_squad_pos, SQUAD, 0.0, 0.07, 0.1)
	recruits.draw(_rec_pos, RECRUITS, 0.0, 0.015, 0.03)
	fx.set_blob(Vector3(0, 0, ARMY_Z), BLOB_R)
	if hero:
		HeroModels.animate_hero(hero, _t, true, 0.0)
	# The clash line: army front and squad front lose units continuously.
	if _t >= _next_death:
		_next_death = _t + 0.05
		var front := Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, -0.6))
		fx.die(front, 0, Vector3(_rng.randf_range(-1.5, 1.5), 0, 1.5))
		var enemy := Vector3(_rng.randf_range(-1.8, 1.8), 0, SQUAD_Z + 1.0 + _rng.randf_range(-0.4, 0.4))
		fx.die(enemy, 1, Vector3(_rng.randf_range(-1.5, 1.5), 0, -1.5))
		if _rng.randf() < 0.15:
			fx.die(_rec_pos[_rng.randi() % RECRUITS] + Vector3(0.4, 0, 0.3), 2, Vector3(1.5, 0, 0))
	if _t >= _next_flash:
		_next_flash = _t + 0.25
		var idx := PackedInt32Array()
		for k in 6:
			idx.append(_rng.randi() % 40)
		army.flash_units(idx)
	if _shot < SHOTS.size() and _t >= float(SHOTS[_shot]["t"]):
		_capture(SHOTS[_shot])
		_shot += 1


func _capture(s: Dictionary) -> void:
	_busy = true
	army.set_overlay(Color(0.18, 1.0, 0.55), 0.85 if s.get("overlay", false) else 0.0)
	_place_cam(str(s["cam"]))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(str(s["name"]) + ".png")
	img.save_png(path)
	print("SHOT ", path, " dying=", fx.dying_count(), " debris=", fx.debris_count(),
		" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" fps=", Engine.get_frames_per_second())
	_busy = false
	if _shot >= SHOTS.size() or (_dbg > 0 and _shot >= 1):
		get_tree().quit(0)


## Times draw() for a full 220-unit army and a UnitFx tick with many deaths in flight.
func _bench() -> void:
	var cv := CrowdView.new()
	add_child(cv)
	cv.setup(Models.soldier_mesh(), ARMY)
	var pos := PackedVector3Array()
	for i in ARMY:
		pos.append(Vector3(randf_range(-2, 2), 0, randf_range(0, 4)))
	for i in 20:
		cv.draw(pos, ARMY, PI, 0.08, 0.08)
	var n := 2000
	var t0 := Time.get_ticks_usec()
	for i in n:
		cv.draw(pos, ARMY, PI, 0.08, 0.08)
	var per := float(Time.get_ticks_usec() - t0) / n
	var f := UnitFx.new()
	add_child(f)
	f.setup(Models.soldier_mesh(), Models.raider_mesh())
	for i in 60:
		f.die(Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), i % 3, Vector3(0, 0, 1))
	var t1 := Time.get_ticks_usec()
	var m := 200
	for i in m:
		f._process(1.0 / 600.0)
	var per_fx := float(Time.get_ticks_usec() - t1) / m
	print("BENCH CrowdView.draw(220): %.3f ms/call; UnitFx tick (%d dying, %d motes, %d shards): %.3f ms" % [per / 1000.0, f.dying_count(), f._puffs.size() + f._sparks.size(), f.debris_count(), per_fx / 1000.0])
