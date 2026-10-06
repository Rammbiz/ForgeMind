extends Node3D
## Dev preview of the enemy crowd: the owner's Emberhorn Sentinel baked to VAT
## (tools/bake_vat.gd profile "emberhorn", assets/units/emberhorn/*). Shots:
##   src     the source GLB as Godot skins it (rest pose and its Running clip), orthographic with
##           a 0.1 grid, to place the spear and the glow region of the bake profile
##   sheets  every baked clip at six moments (profile row and the game camera's front row)
##   squad   an idle Emberhorn squad waiting on the road, close and from the game camera
##   charge  a squad charging: the back ranks run, the front rank stabs (zone clip)
##   deaths  Emberhorns dying (UnitFx enemy pool: recoil, fall, embers) at four moments
##   clash   the knights' blob (real Army) stabbing into an Emberhorn squad, both sides falling
## Saves PNGs and quits:
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://scenes/dev/gallery_enemy.tscn [-- --out=DIR] [--shots=a,b]
## Clash from the real game camera: scripts/dev/screenshot.gd (--shot=... --level=N --until=D).

const SRC := "res://assets/units/emberhorn/emberhorn_src.glb"
const BASE := "res://assets/units/emberhorn/emberhorn"
const KNIGHT := "res://assets/units/knight/knight"
const D0 := 40.0
const SHEET := Vector3(0, 0, -150)
const CAM_HFOV := 40.0
const ALL_SHOTS := ["src", "sheets", "squad", "charge", "deaths", "clash"]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var cam: Camera3D
var track: Track
var hero: RunHero
var fx: UnitFx
var d := D0
var _args := {}
var _labels: Array[Node] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(_args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_world()
	var shots: Array = str(_args["shots"]).split(",") if _args.has("shots") else ALL_SHOTS
	for s in shots:
		d = D0
		await call("_shot_" + s)
	get_tree().quit(0)


func _build_world() -> void:
	var world := Worlds.for_level(1)
	Models.use_world(world)
	track = Track.new()
	add_child(track)
	track.build(180.0, true, world)
	fx = UnitFx.new()
	add_child(fx)
	var kv := VatClip.create(KNIGHT)
	fx.setup(kv.mesh, Models.raider_mesh(), kv.albedo, Models.asset_texture("raider"))
	if ResourceLoader.exists(BASE + "_vat_mesh.res") and fx.has_method("set_enemy_vat"):
		fx.call("set_enemy_vat", VatClip.create(BASE))
	hero = RunHero.new()
	add_child(hero)
	hero.setup("bolt")
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 300.0
	add_child(cam)
	cam.make_current()


func _capture(file: String, vp: Viewport = null) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := (vp if vp else get_viewport()).get_texture().get_image()
	var path := out_dir.path_join(file + ".png")
	img.save_png(path)
	print("SHOT ", path, "  draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"  primitives ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	return img


func _clear(nodes: Array) -> void:
	for n in nodes:
		if n is Node:
			(n as Node).queue_free()
	for l in _labels:
		l.queue_free()
	_labels.clear()
	await get_tree().process_frame


func _label(at: Vector3, text: String, size: int, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0025
	l.outline_size = 8
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	(parent if parent else self).add_child(l)
	_labels.append(l)
	return l


## A still sub-viewport studio: plain backdrop, sun with shadows, a floor.
func _studio(size: Vector2i, bg := Color(0.1, 0.12, 0.2)) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 25, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	return vp


# ------------------------------------------------------------------------------------- shots

## The source GLB skinned by Godot: rest pose front and side, and its Running clip at 3 moments
## (side), on a 0.1 grid in model units (y up, +Z forward, +X the unit's left).
func _shot_src() -> void:
	var vp := _studio(Vector2i(1600, 900), Color(0.16, 0.17, 0.22))
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 2.0
	vp.add_child(c)
	c.position = Vector3(0, 0.85, 10)
	c.look_at(Vector3(0, 0.85, 0))
	c.make_current()
	var views := [[-2.6, 0.0, -1.0], [-1.3, PI * 0.5, -1.0], [0.0, PI * 0.5, 0.1], [1.3, PI * 0.5, 0.3], [2.6, PI * 0.5, 0.5]]
	for i in views.size():
		var vw: Array = views[i]
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(SRC), st) != OK:
			push_error("gallery_enemy: cannot read " + SRC)
			return
		var src := doc.generate_scene(st) as Node3D
		var holder := Node3D.new()
		vp.add_child(holder)
		holder.add_child(src)
		holder.position = Vector3(float(vw[0]), 0, 0)
		holder.rotation.y = float(vw[1])
		var ap := src.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0 and float(vw[2]) >= 0.0:
			var p := ap[0] as AnimationPlayer
			p.play(p.get_animation_list()[0])
			p.seek(float(vw[2]), true)
			p.pause()
		_grid(vp, Vector3(float(vw[0]), 0, -0.6))
		_label(Vector3(float(vw[0]), 1.82, 0), ["rest front", "rest side", "Running 0.1", "Running 0.3", "Running 0.5"][i], 40, vp)
	c.size = 3.7
	c.position = Vector3(0, 1.0, 10)
	await _capture("ember_src", vp)
	# Close-up of the rest pose, front and side, for the spear line and the glow region.
	c.size = 1.9
	c.position = Vector3(-1.95, 0.9, 10)
	await _capture("ember_src_rest", vp)
	vp.queue_free()
	_labels.clear()


func _grid(parent: Node, at: Vector3) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 19:
		var y := k * 0.1
		im.surface_add_vertex(Vector3(-0.65, y, 0))
		im.surface_add_vertex(Vector3(0.65, y, 0))
	for k in 14:
		var x := -0.6 + k * 0.1
		im.surface_add_vertex(Vector3(x, 0, 0))
		im.surface_add_vertex(Vector3(x, 1.8, 0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)


## Each baked clip at six moments: a profile row (facing +X) and a front row turned a little,
## as the game camera sees a squad (enemies face +Z, towards the army).
func _shot_sheets() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := Camera3D.new()
	c.fov = 26.0
	vp.add_child(c)
	c.position = SHEET + Vector3(0.0, 1.45, 5.3)
	c.look_at(SHEET + Vector3(0.0, 0.42, 0.0))
	c.make_current()
	hero.position = SHEET + Vector3(0, 0, 40)
	var ref := VatClip.create(BASE)
	for clip in ["run", "attack", "idle", "death"]:
		var n := 6
		var cols: Array = []
		for col in n:
			var cv := VatClip.create(BASE)
			var cmm := MultiMesh.new()
			cmm.transform_format = MultiMesh.TRANSFORM_3D
			cmm.use_colors = true
			cmm.use_custom_data = true
			cmm.mesh = cv.mesh
			cmm.instance_count = 2
			for row in 2:
				var yaw := PI * 0.5 if row == 0 else 0.45
				var pos := SHEET + Vector3((col - (n - 1) * 0.5) * 0.74, 0.0, 0.55 if row == 0 else -0.75)
				cmm.set_instance_transform(row, Transform3D(Basis(Vector3.UP, yaw), pos))
				cmm.set_instance_color(row, Color.WHITE)
				cmm.set_instance_custom_data(row, Color(0.0, 0.0, 0.0, 0.0))
			var cmi := MultiMeshInstance3D.new()
			cmi.multimesh = cmm
			add_child(cmi)
			cv.attach(cmi)
			cv.material.set_shader_parameter("sway_scale", 0.0)
			cv.material.set_shader_parameter("phase_scramble", 0.0)
			cv.material.set_shader_parameter("oneshot_jitter", 0.0)
			cv.material.set_shader_parameter("edge_amount", 0.4)
			cv.play(clip, 0.0, true, 1.0, 0)
			var looping: bool = cv.clips[clip]["loop"]
			cv.seek(cv.length(clip) * col / (n if looping else n - 1))
			cols.append(cmi)
		var title := _label(SHEET + Vector3(-2.0, 1.22, 0.55), "%s  (%d frames, %.2f s, %.1f fps)" % [
			clip, int(ref.clips[clip]["frames"]), ref.length(clip), float(ref.clips[clip]["fps"])], 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		await _capture("ember_clip_" + clip, vp)
		await _clear(cols)
	vp.queue_free()
	cam.make_current()


## A staged squad: the real CrowdView + VatClip as Hazards builds it (n units in SQUAD_DX x
## SQUAD_DZ rows), `clip` playing, optional zone line.
func _squad(n: int, per_row: int, front_z: float, clip: String) -> Array:
	var v := VatClip.create(BASE)
	var view := CrowdView.new()
	add_child(view)
	view.setup(v.mesh, n)
	view.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	v.attach(view)
	v.play(clip, 0.0)
	var pts := PackedVector3Array()
	for k in n:
		var row := k / per_row
		var col := k % per_row
		var in_row := mini(per_row, n - row * per_row)
		pts.append(Vector3((col - (in_row - 1) * 0.5) * Balance.SQUAD_DX + (0.1 if row % 2 == 1 else 0.0), 0.0, front_z - row * Balance.SQUAD_DZ))
	return [view, v, pts]


func _tick_squad(sq: Array, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		(sq[1] as VatClip).tick(1.0 / 60.0)
	(sq[0] as CrowdView).draw(sq[2], (sq[2] as PackedVector3Array).size(), 0.0, 0.015, 0.03)


## Waiting squad (guard idle): game camera from behind the army's place, then close.
func _shot_squad() -> void:
	var sq := _squad(40, 8, -d - 6.0, "idle")
	await _tick_squad(sq, 0.7)
	hero.position = Vector3(0, 0, -d)
	cam.fov = 58.0
	cam.position = Vector3(0.0, 8.6, -d + 8.5)
	cam.look_at(Vector3(0.0, 0.0, -d - 3.0))
	await _capture("ember_squad_game")
	cam.fov = 34.0
	cam.position = Vector3(1.6, 1.7, -d - 2.4)
	cam.look_at(Vector3(-0.2, 0.45, -d - 6.6))
	await _capture("ember_squad_close")
	await _tick_squad(sq, 0.9)
	await _capture("ember_squad_close_b")
	await _clear([sq[0]])


## Charging squad: back ranks run (main clip), the front rank beyond the line stabs (zone).
func _shot_charge() -> void:
	var line := -d - 0.75
	var sq := _squad(40, 8, line - 0.05, "run")
	var v: VatClip = sq[1]
	v.play("run", 0.0, true, 1.25)
	v.set_zone("attack", line - 0.1, 0.12, 1.2)
	# Ranks behind still closing in: stagger them a little towards the line.
	var pts: PackedVector3Array = sq[2]
	for k in pts.size():
		pts[k].z += 0.12 * (k / 8)
	sq[2] = pts
	await _tick_squad(sq, 0.5)
	hero.position = Vector3(0, 0, -d + 2.0)
	cam.fov = 36.0
	cam.position = Vector3(2.4, 1.9, line + 3.0)
	cam.look_at(Vector3(-0.2, 0.4, line - 1.0))
	await _capture("ember_charge_close")
	await _clear([sq[0]])


## Deaths: a line of Emberhorns dying at once (UnitFx enemy pool), three moments.
func _shot_deaths() -> void:
	hero.position = Vector3(0, 0, -d + 6.0)
	var z := -d - 2.0
	for i in 7:
		fx.die(Vector3((i - 3) * 0.55, 0.0, z - (i % 2) * 0.4), 1, Vector3((i - 3) * 0.2, 0, -1.6))
	cam.fov = 36.0
	cam.position = Vector3(2.6, 2.0, z + 3.4)
	cam.look_at(Vector3(-0.1, 0.35, z - 0.4))
	var shots := [[0.12, "ember_death_a"], [0.3, "ember_death_b"], [0.45, "ember_death_c"], [0.25, "ember_death_d"]]
	for s in shots:
		var t := 0.0
		while t < float(s[0]):
			await get_tree().process_frame
			t += get_process_delta_time()
		await _capture(str(s[1]))


## Knights vs Emberhorns: the real Army charging (knight VAT attack) into a staged squad whose
## front rank stabs back (zone clip), units dying on both sides; close 3/4 and game framing.
func _shot_clash() -> void:
	var n := 120
	var a := Army.new()
	add_child(a)
	var kv := VatClip.create(KNIGHT)
	a.setup(fx, n, kv.mesh)
	kv.attach(a.view)
	kv.set_unit_scale(VatClip.crowd_scale(n))
	a.radius = Balance.blob_radius(float(n))
	a.center = Vector3(0.0, 0.0, -d + Balance.HERO_GAP + a.radius * Balance.BLOB_STRETCH)
	a.spawn(n)
	kv.play("run", 0.0, true, VatClip.run_rate(Balance.RUN_SPEED))
	var line := -d - 0.75
	var sq := _squad(48, 8, line - 0.05, "run")
	var v: VatClip = sq[1]
	v.play("idle", 0.0)
	v.set_zone("attack", line - 0.1, 0.12, 1.2)
	a.mode = Army.Mode.CHARGE
	a.charge_z = -d - 0.2
	a.charge_x = 0.0
	a.charge_half = 2.0
	kv.play("attack", 0.2, true, 1.15)
	var pts: PackedVector3Array = sq[2]
	var dt := 1.0 / 60.0
	for i in 50:
		a.step(dt, 0.0)
		kv.tick(dt)
		if i % 12 == 0 and pts.size() > 8:
			# The front-most Emberhorn falls; the one behind steps up.
			var best := 0
			for k in pts.size():
				if pts[k].z > pts[best].z:
					best = k
			fx.die(pts[best], 1, Vector3(randf_range(-0.6, 0.6), 0, -1.6))
			pts.remove_at(best)
		if i % 16 == 0:
			a.kill_front(1)
		await get_tree().process_frame
	sq[2] = pts
	await _tick_squad(sq, 0.1)
	a.draw()
	hero.position = Vector3(0, 0, -d)
	hero.fighting = true
	cam.fov = 40.0
	cam.position = Vector3(3.0, 2.6, -d + 2.4)
	cam.look_at(Vector3(-0.3, 0.3, line - 0.4))
	await _capture("ember_clash_close")
	cam.fov = 34.0
	cam.position = Vector3(-2.6, 1.9, line + 2.6)
	cam.look_at(Vector3(0.3, 0.4, line - 0.5))
	await _capture("ember_clash_low")
	await _clear([a, sq[0]])
