extends Node3D
## Dev preview for the baked knight crowd (tools/bake_vat.gd, shaders/crowd_vat.gdshader,
## scripts/run/vat_clip.gd) in the real game setting: the space Track (its sky, light, haze and
## road), the hero, the real Army node (sunflower blob, springs, UnitFx contact shadow) and the
## run camera framing for a 220-unit army. Shots: the running blob at two moments, the old
## procedural soldiers in the same frame, a close 3/4 back view, the READY idle, a clash with a
## raider squad (front knights dying), the victory cheer, grey recruits, clip sheets (every clip at six moments) and a
## check of the GPU decode against the Godot-skinned source. Saves PNGs and quits:
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://scenes/dev/gallery_vat.tscn [-- --out=DIR] [--shots=a,b] [--bench]

const VatClipScript := preload("res://scripts/run/vat_clip.gd")
const BASE := "res://assets/units/knight/knight"
const ARMY := 220
const D0 := 40.0                   # distance the army stands at when a shot starts
const SHEET := Vector3(0, 0, -150) # where the clip sheets stand, past the shots on the road
const CAM_HFOV := 40.0             # Run.CAM_HFOV
const ALL_SHOTS := ["run", "compare", "close", "ready", "clash", "victory", "recruits", "sheets", "verify"]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var cam: Camera3D
var track: Track
var hero: RunHero
var fx: UnitFx
var d := D0
var hx := 0.0
var _args := {}
var _labels: Array[Node] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(_args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_world()
	if _args.has("bench"):
		await _bench()
	else:
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
	# Dying knights: the VAT mesh's rest pose with crowd.gdshader (vat_report.md, step 6).
	var kv := _new_vat()
	fx.setup(kv.mesh, Models.raider_mesh(), kv.albedo)
	hero = RunHero.new()
	add_child(hero)
	hero.setup("bolt")
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 300.0
	add_child(cam)
	cam.make_current()


## Run's framing for an army of blob radius `r` (Run._camera_goal while RUNNING / CLASH).
func _game_cam(r: float, clash := false) -> void:
	var rear := Balance.HERO_GAP + 2.0 * r * Balance.BLOB_STRETCH + 0.5
	var k := clampf((rear - 2.5) / 4.0, 0.0, 1.25)
	var h := lerpf(7.6, 10.4, k)
	var back := lerpf(7.0, 12.2, k)
	var ahead := lerpf(2.6, 0.0, k)
	var size := get_viewport().get_visible_rect().size
	var vfov := rad_to_deg(2.0 * atan(tan(deg_to_rad(CAM_HFOV * 0.5)) / (size.x / maxf(size.y, 1.0))))
	cam.fov = clampf(vfov, 50.0, 66.0) - (5.0 if clash else 0.0)
	cam.position = Vector3(hx * 0.35, h, -d + back)
	cam.look_at(Vector3(hx * 0.55, 0.0, -d - ahead))


func _center(r: float) -> Vector3:
	return Vector3(hx, 0.0, -d + Balance.HERO_GAP + r * Balance.BLOB_STRETCH)


func _new_vat() -> VatClipScript:
	var v: VatClipScript = VatClipScript.create(str(_args.get("base", BASE)))
	assert(v != null, "bake the knight first: tools/bake_vat.gd")
	# --set=name:value;name:value overrides shader uniforms (look tuning).
	for kv in str(_args.get("set", "")).split(";", false):
		var p := kv.split(":")
		v.material.set_shader_parameter(p[0], float(p[1]))
	return v


## Re-applies --set overrides after attach() copied the old material's uniforms.
func _reapply(v: VatClipScript) -> void:
	for kv in str(_args.get("set", "")).split(";", false):
		var p := kv.split(":")
		v.material.set_shader_parameter(p[0], float(p[1]))


## A real Army of `n` units: baked knights (VAT, returns [army, VatClip]) or the old procedural
## soldiers ([army, null]), spawned at their slots behind the hero.
func _army(knights: bool, n := ARMY) -> Array:
	var a := Army.new()
	add_child(a)
	var v: VatClipScript = null
	if knights:
		v = _new_vat()
		a.setup(fx, n, v.mesh)
		v.attach(a.view)
		v.set_unit_scale(VatClipScript.crowd_scale(n))
		_reapply(v)
	else:
		a.setup(fx, n, Models.soldier_mesh(0))
	a.radius = Balance.blob_radius(float(n))
	a.center = _center(a.radius)
	a.spawn(n)
	return [a, v]


## Advances the army `seconds` at 60 steps a second as Run does (running = marching to −Z at
## RUN_SPEED), then draws it, places the hero and frames the game camera.
func _sim(a: Army, v: VatClipScript, seconds: float, running := true, clash := false) -> void:
	var dt := 1.0 / 60.0
	for i in roundi(seconds * 60.0):
		var adv := 0.0
		if running:
			d += Balance.RUN_SPEED * dt
			adv = -Balance.RUN_SPEED * dt
		a.marching = running
		if a.mode == Army.Mode.FOLLOW:
			a.center = _center(a.radius)
		a.step(dt, adv)
		if v:
			v.tick(dt)
	a.draw()
	hero.position = Vector3(hx, 0.0, -d)
	hero.running = running
	_game_cam(a.radius, clash)


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


## Side by side crops of several captures (same rect), saved as one PNG.
func _side_by_side(file: String, imgs: Array, crop: Rect2i) -> void:
	var a: Image = imgs[0]
	var sheet := Image.create(crop.size.x * imgs.size() + 12 * (imgs.size() - 1), crop.size.y, false, a.get_format())
	sheet.fill(Color(0.05, 0.06, 0.1))
	for i in imgs.size():
		sheet.blit_rect(imgs[i] as Image, crop, Vector2i(i * (crop.size.x + 12), 0))
	sheet.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", out_dir.path_join(file + ".png"))


# ------------------------------------------------------------------------------------- shots

## 220 knights running toward −Z behind the hero, game camera, two moments 0.1 s apart.
func _shot_run() -> void:
	var k := _army(true)
	var a: Army = k[0]
	var v: VatClipScript = k[1]
	v.play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
	await _sim(a, v, 1.2)
	var i1 := await _capture("vat_run")
	await _sim(a, v, 0.1)
	var i2 := await _capture("vat_run_b")
	_side_by_side("vat_run_ab", [i1, i2], Rect2i(150, 600, 420, 420))
	await _clear([a])


## Old procedural soldiers vs the knights, same framing, side by side.
func _shot_compare() -> void:
	var k := _army(false)
	await _sim(k[0], null, 1.2)
	var i1 := await _capture("vat_old_run")
	await _clear([k[0]])
	d = D0
	k = _army(true)
	(k[1] as VatClipScript).play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
	await _sim(k[0], k[1], 1.2)
	var i2 := await _capture("vat_new_run")
	_side_by_side("vat_compare", [i1, i2], Rect2i(60, 480, 600, 760))
	await _clear([k[0]])


## Close 3/4 back view of the running blob, the hero ahead.
func _shot_close() -> void:
	var k := _army(true)
	var a: Army = k[0]
	(k[1] as VatClipScript).play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
	await _sim(a, k[1], 1.0)
	cam.fov = 45.0
	var c := a.center
	cam.position = c + Vector3(2.2, 3.1, 4.6)
	cam.look_at(c + Vector3(0.0, 0.3, -0.8))
	await _capture("vat_run_close")
	await _sim(a, k[1], 0.11)
	cam.fov = 45.0
	c = a.center
	cam.position = c + Vector3(2.2, 3.1, 4.6)
	cam.look_at(c + Vector3(0.0, 0.3, -0.8))
	await _capture("vat_run_close_b")
	# Hero height: the soldiers' heads against the hero's.
	cam.fov = 40.0
	cam.position = Vector3(hx + 2.4, 1.3, -d + 2.0)
	cam.look_at(Vector3(hx - 0.2, 0.5, -d + 1.4))
	await _capture("vat_run_low")
	await _clear([a])


## READY: the army waits at the start line, idling.
func _shot_ready() -> void:
	var k := _army(true)
	(k[1] as VatClipScript).play("idle", 0.0)
	await _sim(k[0], k[1], 0.8, false)
	await _capture("vat_ready")
	await _clear([k[0]])


## CLASH: the blob charges a raider squad and stabs at it.
func _shot_clash() -> void:
	var k := _army(true)
	var a: Army = k[0]
	var v: VatClipScript = k[1]
	v.play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
	await _sim(a, v, 0.6)
	var squad := CrowdView.new()
	add_child(squad)
	squad.setup(Models.raider_mesh(), 64)
	squad.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	squad.set_gait(14.0)
	var sp := PackedVector3Array()
	for i in 56:
		var row := i / 8
		var col := i % 8
		sp.append(Vector3((col - 3.5) * 0.42 + (0.1 if row % 2 == 1 else 0.0), 0, -d - 0.75 - row * 0.42))
	squad.draw(sp, sp.size(), 0.0, 0.08, 0.06)
	a.mode = Army.Mode.CHARGE
	a.charge_z = -d - 0.2
	a.charge_x = 0.0
	a.charge_half = 2.2
	v.play("attack", 0.2)
	await _sim(a, v, 0.55, false, true)
	a.kill_front(6)
	await _sim(a, v, 0.12, false, true)
	await _capture("vat_clash")
	cam.fov = 42.0
	cam.position = Vector3(3.2, 2.4, -d + 2.6)
	cam.look_at(Vector3(-0.2, 0.35, -d - 0.4))
	await _capture("vat_clash_close")
	await _clear([a, squad])


## WON: the whole army cheers with the spin jump, staggered.
func _shot_victory() -> void:
	var k := _army(true)
	var a: Army = k[0]
	var v: VatClipScript = k[1]
	v.play("victory", 0.0)
	await _sim(a, v, 1.0, false)
	await _capture("vat_victory_game")
	cam.fov = 45.0
	cam.position = a.center + Vector3(4.2, 4.0, 6.0)
	cam.look_at(a.center + Vector3(0.0, 0.4, -0.3))
	await _capture("vat_victory")
	await _clear([a])


## Grey recruits (same mesh and clips, saturation 0) waiting beside the road as the army runs by.
func _shot_recruits() -> void:
	var k := _army(true, 60)
	var a: Army = k[0]
	(k[1] as VatClipScript).play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
	await _sim(a, k[1], 1.0)
	var rv := _new_vat()
	var rec := CrowdView.new()
	add_child(rec)
	rec.setup(rv.mesh, 8)
	rv.attach(rec)
	rec.set_saturation(0.0)
	rec.set_tint(Color(0.8, 0.82, 0.86))
	rv.play("idle", 0.0)
	rv.seek(0.6)
	var rp := PackedVector3Array()
	for i in 7:
		var ang := i * 2.39996
		var rr := 0.42 * sqrt((i + 0.5) / 7.0)
		rp.append(Vector3(1.9 + cos(ang) * rr, 0.0, -d - 3.2 + sin(ang) * rr))
	rec.draw(rp, rp.size(), 0.0, 0.015, 0.03)
	await _capture("vat_recruits")
	await _clear([a, rec])


## Each clip at six evenly spaced moments: a profile row (facing +X) and a 3/4 back row (as the
## game camera sees the army), in a wide sub-viewport.
func _shot_sheets() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := Camera3D.new()
	c.fov = 26.0
	vp.add_child(c)
	c.position = SHEET + Vector3(0.0, 1.35, 5.1)
	c.look_at(SHEET + Vector3(0.0, 0.4, 0.0))
	c.make_current()
	hero.position = SHEET + Vector3(0, 0, 40)
	for clip in ["run", "walk", "attack", "idle", "victory", "spin"]:
		# One material per column: every unit of a material plays the same clock, so each column
		# is its own moment of the clip (phase 0, no scramble).
		var v := _new_vat()
		var n := 6
		var cols: Array = []
		for col in n:
			var cv := _new_vat()
			var cmm := MultiMesh.new()
			cmm.transform_format = MultiMesh.TRANSFORM_3D
			cmm.use_colors = true
			cmm.use_custom_data = true
			cmm.mesh = cv.mesh
			cmm.instance_count = 2
			for row in 2:
				var yaw := PI * 0.5 if row == 0 else PI + 0.55
				var pos := SHEET + Vector3((col - (n - 1) * 0.5) * 0.72, 0.0, 0.55 if row == 0 else -0.7)
				cmm.set_instance_transform(row, Transform3D(Basis(Vector3.UP, yaw), pos))
				cmm.set_instance_color(row, Color.WHITE)
				cmm.set_instance_custom_data(row, Color(0.0, 0.0, 0.0, 0.0))
			var cmi := MultiMeshInstance3D.new()
			cmi.multimesh = cmm
			add_child(cmi)
			cv.attach(cmi)
			cv.material.set_shader_parameter("sway_scale", 0.0)
			cv.material.set_shader_parameter("phase_scramble", 0.0)
			cv.material.set_shader_parameter("edge_color", Color(0.55, 0.8, 1.0))
			cv.material.set_shader_parameter("edge_amount", 0.35)
			cv.play(clip, 0.0, true, 1.0, 0)
			cv.seek(cv.length(clip) * col / n)
			cols.append(cmi)
		var title := _label(SHEET + Vector3(-1.95, 1.18, 0.55), "%s  (%d frames, %.2f s, %.1f fps)" % [
			clip, int(v.clips[clip]["frames"]), v.length(clip), float(v.clips[clip]["fps"])], 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for col in n:
			_label(SHEET + Vector3((col - (n - 1) * 0.5) * 0.72, 1.02, 0.55), "%.2f s" % (v.length(clip) * col / n), 26)
		await _capture("vat_clip_" + clip, vp)
		await _clear(cols)
	vp.queue_free()
	cam.make_current()


## Correctness: (left) the source GLB skinned by Godot with the raw Running clip, (middle) the
## VAT on the GPU at the same moment, (right) the same frame decoded on the CPU from the texture.
## Middle and right must match; left shows what the bake fixed (right foot through the floor,
## spear weighted to the head and toes, shield to the thigh).
func _shot_verify() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 700)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Its own still world: the road's pulsing veins would spoil the pixel comparison.
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.75)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.22, 0.42)
	floor_mi.material_override = fm
	vp.add_child(floor_mi)
	var c := Camera3D.new()
	c.fov = 28.0
	vp.add_child(c)
	var at := SHEET + Vector3(0, 0, 8)
	floor_mi.position = at
	c.position = at + Vector3(0.25, 0.75, 4.2)
	c.look_at(at + Vector3(0.0, 0.36, 0.0))
	c.make_current()
	hero.position = SHEET + Vector3(0, 0, 40)
	var nodes := []
	var v := _new_vat()
	var frame := 9
	var t: float = frame / float(v.clips["run"]["fps"])
	# Left: Godot skinning of the source GLB, scaled like the bake.
	var meta: Dictionary = v.mesh.get_meta("vat")
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(str(meta["source"])), st) == OK:
		var src := doc.generate_scene(st) as Node3D
		var holder := Node3D.new()
		vp.add_child(holder)
		holder.add_child(src)
		var s := float(meta["scale"])
		var o: Array = meta["origin"]
		holder.transform = Transform3D(Basis.from_scale(Vector3.ONE * s).rotated(Vector3.UP, PI * 0.5), Vector3.ZERO)
		holder.position = at + Vector3(-1.1, 0, 0) - holder.basis * Vector3(o[0], o[1], o[2])
		var ap := src.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var lib := load(BASE + "_anims.res") as AnimationLibrary
		if lib:
			ap.add_animation_library("vat", lib)
			ap.play("vat/Running")
			ap.seek(t, true)
			ap.pause()
		nodes.append(holder)
	# Middle: the VAT on the GPU, one instance, phase 0.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = v.mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, PI * 0.5), at))
	mm.set_instance_color(0, Color.WHITE)
	mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	vp.add_child(mmi)
	v.attach(mmi)
	v.material.set_shader_parameter("sway_scale", 0.0)
	v.material.set_shader_parameter("ao_strength", 0.0)
	v.material.set_shader_parameter("phase_scramble", 0.0)
	v.play("run", 0.0)
	v.seek(t)
	nodes.append(mmi)
	# Right: the same frame rebuilt on the CPU from the position/normal textures.
	var pos_img := (load(BASE + "_vat_pos.res") as Texture2D).get_image()
	var nrm_img := (load(BASE + "_vat_nrm.res") as Texture2D).get_image()
	var arr := v.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var w := int(meta["width"])
	var rpf := int(meta["rows_per_frame"])
	var f := int(v.clips["run"]["frame"]) + frame
	for i in verts.size():
		var px := pos_img.get_pixel(i % w, f * rpf + i / w)
		var nx := nrm_img.get_pixel(i % w, f * rpf + i / w)
		var r := Basis(Vector3.UP, px.a)
		verts[i] = r * Vector3(px.r, px.g, px.b)
		norms[i] = r * Vector3(nx.r, nx.g, nx.b)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var cpu := ArrayMesh.new()
	cpu.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cpu
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = v.albedo
	sm.roughness = 0.8
	sm.metallic_specular = 0.4
	sm.rim_enabled = true
	sm.rim = 0.35
	sm.rim_tint = 0.6
	cmi.material_override = sm
	vp.add_child(cmi)
	cmi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3(1.1, 0, 0))
	nodes.append(cmi)
	# Exact GPU-vs-CPU check: the same spot, one at a time, silhouettes compared pixel by pixel.
	var keep := cmi.transform
	cmi.transform = mmi.multimesh.get_instance_transform(0)
	(nodes[0] as Node3D).visible = false
	cmi.visible = false
	var gpu := await _capture_raw(vp)
	mmi.visible = false
	cmi.visible = true
	var cpu_img := await _capture_raw(vp)
	var bg := await _bg(vp, cmi)
	var diff := 0
	var cnt := 0
	for y in range(0, gpu.get_height(), 2):
		for x in range(0, gpu.get_width(), 2):
			var ga := _cdist(gpu.get_pixel(x, y), bg.get_pixel(x, y)) > 0.02
			var ca := _cdist(cpu_img.get_pixel(x, y), bg.get_pixel(x, y)) > 0.02
			if ga or ca:
				cnt += 1
				if ga != ca:
					diff += 1
	print("VERIFY GPU VAT vs CPU decode of the same frame: %d of %d covered pixels differ in coverage (%.3f%%)" % [diff, cnt, 100.0 * diff / maxf(cnt, 1)])
	cmi.transform = keep
	mmi.visible = true
	(nodes[0] as Node3D).visible = true
	for l in [_label(at + Vector3(-1.1, 0.95, 0), "Godot skinning, raw clip", 30), _label(at + Vector3(0, 0.95, 0), "VAT on GPU", 30), _label(at + Vector3(1.1, 0.95, 0), "VAT decoded on CPU", 30)]:
		(l as Node).reparent(vp)
	await _capture("vat_verify", vp)
	_labels.clear()
	vp.queue_free()
	await get_tree().process_frame
	cam.make_current()


func _capture_raw(vp: Viewport) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _bg(vp: Viewport, hide: Node3D) -> Image:
	hide.visible = false
	var img := await _capture_raw(vp)
	hide.visible = true
	return img


static func _cdist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _label(p: Vector3, text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = Color(0.92, 0.96, 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = p
	add_child(l)
	_labels.append(l)
	return l


# ------------------------------------------------------------------------------------- bench

## Rough frame cost of 220 units in the game setting: average frame and render times over a few
## hundred frames with no army, the old soldiers, the VAT knights (run clip, ticking) and the
## knights mid cross-fade (two clips sampled per vertex). The army is stepped and drawn every
## frame as in a run.
func _bench() -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for mode in ["empty", "old", "vat", "vat_fade"]:
		d = D0
		var a: Army = null
		var v: VatClipScript = null
		if mode == "old":
			a = _army(false)[0]
		elif mode.begins_with("vat"):
			var k := _army(true)
			a = k[0]
			v = k[1]
			v.play("run", 0.0, true, VatClipScript.run_rate(Balance.RUN_SPEED))
			if mode == "vat_fade":
				v.play("attack", 1000.0)
		for i in 10:
			await get_tree().process_frame
		var n := int(_args.get("frames", "240"))
		var cpu := 0.0
		var gpu := 0.0
		var t0 := Time.get_ticks_usec()
		var sim_us := 0
		for i in n:
			var s0 := Time.get_ticks_usec()
			if a:
				await _sim(a, v, 1.0 / 60.0)
			else:
				d += Balance.RUN_SPEED / 60.0
				_game_cam(2.2)
			sim_us += Time.get_ticks_usec() - s0
			await RenderingServer.frame_post_draw
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("BENCH %-8s frame %.2f ms  step+draw %.3f ms  render cpu %.2f ms  gpu %.2f ms  primitives %d" % [
			mode, wall, sim_us / 1000.0 / n, cpu / n, gpu / n, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		if a:
			a.queue_free()
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	var tv := _new_vat()
	tv.play("run")
	for i in 10000:
		tv.tick(0.016)
	print("BENCH VatClip.tick: %.4f ms/call" % ((Time.get_ticks_usec() - t1) / 1000.0 / 10000.0))
