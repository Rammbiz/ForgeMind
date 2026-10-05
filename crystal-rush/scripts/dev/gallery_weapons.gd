extends Node3D
## Dev preview for the WEAPONS + EFFECTS + WORLD role: the space track seen from the run
## camera, the war machines and weapon crates, and the projectile / beam effects.
## Saves a PNG and quits:
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_weapons.tscn
##       -- [--view=track|machines|back|crate|game|fx] [--name=FILE] [--noglow] [--d=DIST]
##          [--t=SECONDS] [--h=CAM_HEIGHT] [--side]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var args := {}
var view := "track"
var track: Track
var fx: Effects
var cam: Camera3D
var _t := 0.0
var _shot_at := 1.0
var _done := false
var _d := 20.0
var _machines: Array[Node3D] = []
var _crates: Array[Node3D] = []
var _fire := {}            # machine -> kick 0..1
var _next_fire := 0.0
var _squad_at := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_rng.seed = 7
	seed(7)
	view = str(args.get("view", "track"))
	_d = float(args.get("d", "20"))
	_shot_at = float(args.get("t", "1.0" if view == "track" else "1.6"))
	track = Track.new()
	add_child(track)
	track.build(160.0, true, Worlds.LIST["space"])
	var env := track.environment
	if args.has("noglow") and env:
		env.glow_enabled = false
	if args.has("tonemap") and env:
		env.tonemap_mode = int(args["tonemap"]) as Environment.ToneMapper
		env.tonemap_exposure = float(args.get("exposure", "1.0"))
	if args.has("glow_thr") and env:
		env.glow_hdr_threshold = float(args["glow_thr"])
	fx = Effects.new()
	add_child(fx)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 400.0
	add_child(cam)
	_run_camera()
	cam.make_current()
	match view:
		"machines":
			_build_showcase()
		"back":
			_build_showcase()
			cam.position = Vector3(0, 3.6, -_d + 2.8)
			cam.look_at(Vector3(0, 0.3, -_d - 2.6))
		"crate":
			_build_crates()
		"game", "fx":
			_build_game()
		"lab":
			_build_lab()


func _run_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	cam.fov = clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(20.0)) / aspect)), 50.0, 66.0)
	var h := float(args.get("h", "8.6"))
	var back := 6.0 + (h - 8.6) * 0.8
	cam.position = Vector3(float(args.get("cx", "0")), h, -_d + back)
	cam.look_at(Vector3(0, 0, -_d - 3.2))
	if args.has("side"):
		cam.position = Vector3(-6, 3.0, -_d + 4.0)
		cam.look_at(Vector3(30, -12, -_d - 30.0))


## Close studio view: the five machines (levels 1-3) and a crate, turned three-quarters.
func _build_showcase() -> void:
	var z0 := -_d - 2.0
	var spots := [
		["ballista", Vector3(-1.1, 0, z0), 1], ["cannon", Vector3(0.0, 0, z0 + 0.15), 2], ["laser", Vector3(1.1, 0, z0), 3],
		["rockets", Vector3(-1.1, 0, z0 - 1.8), 2], ["drone", Vector3(0.0, 0, z0 - 1.6), 1],
	]
	for s: Array in spots:
		var m := WeaponModels.machine(s[0])
		m.position = s[1]
		add_child(m)
		WeaponModels.set_level(m, s[2])
		_machines.append(m)
	var c := WeaponModels.crate("cannon", 12)
	c.position = Vector3(1.15, 0, z0 - 1.9)
	add_child(c)
	_crates.append(c)
	cam.fov = 50.0
	cam.position = Vector3(0.0, 4.6, z0 + 5.0)
	cam.look_at(Vector3(0.0, 0.25, z0 - 0.8))
	if view == "machines":
		for m in _machines:
			WeaponModels.aim(m, cam.global_position + Vector3(2.5, 0, 0))


func _build_crates() -> void:
	var z0 := -_d - 2.0
	var kinds := ["ballista", "laser", "rockets", "drone"]
	for i in kinds.size():
		var c := WeaponModels.crate(kinds[i], [8, 15, 23, 6][i])
		c.position = Vector3(-1.0 + (i % 2) * 2.0, 0, z0 - (i / 2) * 2.2)
		add_child(c)
		_crates.append(c)
	WeaponModels.crate_damage(_crates[1], 0.7, 0.0)
	cam.fov = 50.0
	cam.position = Vector3(0, 3.0, -_d + 2.6)
	cam.look_at(Vector3(0, 0.6, z0 - 1.2))


## The run view: hero, army blob, three machines on the flanks, a drone, a crate ahead and an
## enemy squad that the machines are shooting.
func _build_game() -> void:
	var hz := -_d
	var hero := HeroModels.hero("bolt")
	hero.position = Vector3(0, 0, hz)
	hero.rotation.y = PI
	add_child(hero)
	var mesh := Models.soldier_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var n := 70
	mm.instance_count = n
	for i in n:
		var r := sqrt((i + 0.5) / n) * 1.55
		var a := i * 2.39996
		var p := Vector3(cos(a) * r, 0, hz + 0.6 + 1.55 * 1.15 + sin(a) * r * 1.15)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI + randf_range(-0.2, 0.2)), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.vertex_colored(0.8)
	add_child(mmi)
	# Enemy squad ahead.
	_squad_at = Vector3(0.6, 0.4, hz - 9.0)
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = Models.raider_mesh()
	rm.instance_count = 30
	for i in 30:
		var p := Vector3(0.6 + (i % 6 - 2.5) * 0.42, 0, hz - 9.0 - (i / 6) * 0.42)
		rm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rm
	rmi.material_override = Mats.vertex_colored(0.8)
	add_child(rmi)
	var spots := [["ballista", Vector3(-2.35, 0, hz + 1.7), 2], ["cannon", Vector3(2.35, 0, hz + 1.7), 1],
		["rockets", Vector3(-2.3, 0, hz + 3.6), 3], ["drone", Vector3(1.4, 0, hz + 0.4), 1], ["laser", Vector3(2.4, 0, hz + 3.7), 2]]
	for s: Array in spots:
		var m := WeaponModels.machine(s[0])
		m.position = s[1]
		add_child(m)
		WeaponModels.set_level(m, s[2])
		_machines.append(m)
		_fire[m] = 0.0
	var c := WeaponModels.crate("rockets", 18)
	c.position = Vector3(-1.6, 0, hz - 6.5)
	add_child(c)
	_crates.append(c)


## Effects lab: one lane per projectile kind, slow enough to be mid-flight at the shot, plus a
## beam, a muzzle flash, a shockwave and an explosion.
func _build_lab() -> void:
	var kinds := ["bolt", "plasma", "rocket", "drone", "volley", "turret"]
	for i in kinds.size():
		var x := -2.5 + i * 1.0
		var from := Vector3(x, 0.5, -_d + 1.0)
		var to := Vector3(x, 0.5, -_d - 9.0)
		fx.projectile(from, to, kinds[i], 3.0, Callable())
		fx.projectile(from, to, kinds[i], 4.5, Callable())


func _process(delta: float) -> void:
	_t += delta
	for m in _machines:
		if view in ["game", "fx"]:
			WeaponModels.aim(m, _squad_at, 1.0)
		var k := float(_fire.get(m, 0.0))
		_fire[m] = maxf(k - delta * 2.5, 0.0)
		WeaponModels.animate(m, _t, k if str(m.get_meta("kind")) != "laser" else 1.0)
	for c in _crates:
		WeaponModels.animate(c, _t, 0.0)
	if view in ["game", "fx"]:
		_shoot(delta)
	if view == "lab":
		fx.beam(1, Vector3(3.0, 0.6, -_d + 1.5), Vector3(2.4, 0.3, -_d - 8.0), Color(0.3, 0.9, 1.0), true)
		if _once("muzzle", 1.48):
			fx.muzzle(Vector3(-2.5, 0.6, -_d + 1.0), Color(1.0, 0.8, 0.4), Vector3.FORWARD)
		if _once("boom", 1.3):
			fx.explosion(Vector3(0.0, 0.3, -_d - 6.0), 1.3)
			fx.shockwave(Vector3(-1.5, 0.0, -_d - 3.0), Color(0.6, 0.5, 1.0), 1.6)
	if _t >= _shot_at and not _done:
		_done = true
		_save()


func _shoot(_delta: float) -> void:
	for m in _machines:
		var kind := str(m.get_meta("kind"))
		var mz := (m.get_meta("muzzle") as Node3D).global_position
		if kind == "laser":
			fx.beam(m.get_instance_id(), mz, _squad_at + Vector3(0.4, 0.1, 0.3), WeaponModels.icon_color("laser"), _t > 0.3)
	if _t < _next_fire:
		return
	_next_fire = _t + 0.22
	for m in _machines:
		var kind := str(m.get_meta("kind"))
		if kind == "laser" or _rng.randf() < 0.45:
			continue
		var mz := (m.get_meta("muzzle") as Node3D).global_position
		var target := _squad_at + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-0.8, 0.8))
		var pk := {"ballista": "bolt", "cannon": "plasma", "rockets": "rocket", "drone": "drone"}[kind] as String
		var dist := mz.distance_to(target)
		var speed := {"bolt": 22.0, "plasma": 13.0, "rocket": 9.0, "drone": 18.0}[pk] as float
		fx.projectile(mz, target, pk, dist / speed * float(args.get("slow", "1")), Callable())
		fx.muzzle(mz, WeaponModels.icon_color(kind), (target - mz).normalized())
		_fire[m] = 1.0
	# Army volley and an enemy turret shot.
	if _rng.randf() < 0.5:
		fx.projectile(Vector3(0, 0.6, -_d + 2.0), _squad_at, "volley", 0.45, Callable())
	if _rng.randf() < 0.3:
		fx.projectile(_squad_at + Vector3(-1.5, 0.8, -1.0), Vector3(-0.5, 0.4, -_d + 2.5), "turret", 0.5, Callable())
	if view == "fx" and _once("wave", 1.2):
		fx.shockwave(Vector3(-0.8, 0.0, -_d - 4.0), Color(0.45, 0.85, 1.0), 2.5)


var _done_once := {}


func _once(key: String, at: float) -> bool:
	if _t >= at and not _done_once.has(key):
		_done_once[key] = true
		return true
	return false


func _save() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir + "/" + str(args.get("name", "wfx_" + view)) + ".png"
	img.save_png(path)
	print("SAVED ", path, " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit(0)
