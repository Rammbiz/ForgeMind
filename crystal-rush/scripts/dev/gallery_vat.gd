extends Node3D
## Dev preview for the baked knight crowd (tools/bake_vat.gd, shaders/crowd_vat.gdshader,
## scripts/run/vat_clip.gd): a 220-knight blob running toward -Z from the game camera, the old
## procedural soldiers in the same shot, clip sheets (every clip at six moments, side and back
## views), a 220-knight attack clash, a victory spin and a check of the GPU decode against the
## Godot-skinned source. Saves PNGs and quits:
##   xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --rendering-driver opengl3 \
##       --resolution 720x1280 res://scenes/dev/gallery_vat.tscn [-- --out=DIR] [--shots=a,b] [--bench]

const VatClipScript := preload("res://scripts/run/vat_clip.gd")
const BASE := "res://assets/units/knight/knight"
const ARMY := 220
const BLOB_R := 2.2
const BLOB_STRETCH := 1.15
const ARMY_Z := 0.9 + BLOB_R * BLOB_STRETCH
const MARCH := 6.5                 # march speed (u/s) the run playback rate is matched against
const RUN_RATE := 1.35             # playback rate of the run clip in the game shots
const SHEET := Vector3(60, 0, 0)   # where the clip sheets stand, away from the crowd
const ALL_SHOTS := ["run", "compare", "close", "sheets", "clash", "victory", "verify"]

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var cam: Camera3D
var _args := {}
var _slots := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _labels: Array[Node] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out_dir = str(_args.get("out", out_dir))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_rng.seed = 42
	_build_world()
	for i in ARMY:
		var r := BLOB_R * sqrt((i + 0.5) / ARMY)
		var a := i * 2.39996
		var p := Vector3(r * cos(a), 0, r * sin(a) * BLOB_STRETCH + ARMY_Z)
		_slots.append(p + Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04)))
	if _args.has("bench"):
		await _bench()
	else:
		var shots: Array = str(_args["shots"]).split(",") if _args.has("shots") else ALL_SHOTS
		for s in shots:
			await call("_shot_" + s)
	get_tree().quit(0)


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
	# Dark blue plane with a faint stone pattern (shows where the feet stand).
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://assets/textures/stone_floor.png")
	floor_mat.albedo_color = Color(0.13, 0.19, 0.38)
	floor_mat.uv1_scale = Vector3(30, 30, 1)
	floor_mat.roughness = 0.75
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = floor_mat
	ground.position = Vector3(30, 0, -20)
	add_child(ground)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 200.0
	add_child(cam)
	_place_cam("game")
	cam.make_current()


func _place_cam(kind: String, at := Vector3.ZERO) -> void:
	match kind:
		"close":
			cam.fov = 50.0
			cam.position = at + Vector3(1.6, 3.6, 4.6)
			cam.look_at(at + Vector3(0.0, 0.3, 0.6))
		"clash_close":
			cam.fov = 45.0
			cam.position = at + Vector3(3.0, 2.6, 0.8)
			cam.look_at(at + Vector3(-0.3, 0.25, -2.2))
		"victory":
			cam.fov = 50.0
			cam.position = at + Vector3(0.0, 6.4, 8.4)
			cam.look_at(at + Vector3(0.0, 0.3, 2.6))
		_:
			cam.fov = 66.0
			cam.position = at + Vector3(0, 11.2, 8.8)
			cam.look_at(at + Vector3(0, 0, -3.2))


func _new_vat() -> VatClipScript:
	var v: VatClipScript = VatClipScript.create(BASE)
	assert(v != null, "bake the knight first: tools/bake_vat.gd")
	return v


## A CrowdView of `n` knights on the VAT material, playing `clip` (clock at `t`).
func _knights(n: int, clip: String, t: float, rate := 1.0) -> Array:
	var v := _new_vat()
	var cv := CrowdView.new()
	add_child(cv)
	cv.setup(v.mesh, n)
	v.attach(cv)
	cv.set_tint(Color.WHITE)
	cv.set_edge(Color(0.55, 0.8, 1.0), 0.35)
	v.play(clip, 0.0, true, rate)
	v.seek(t)
	return [cv, v]


func _blob(offset := Vector3.ZERO) -> PackedVector3Array:
	var p := PackedVector3Array()
	for s in _slots:
		p.append(s + offset)
	return p


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


# ------------------------------------------------------------------------------------- shots

## 220 knights running toward -Z, game camera, two moments.
func _shot_run() -> void:
	var k := _knights(ARMY, "run", 0.0, RUN_RATE)
	var cv: CrowdView = k[0]
	cv.draw(_blob(), ARMY, PI, 0.08, 0.08)
	_place_cam("game")
	(k[1] as VatClipScript).seek(0.40)
	await _capture("vat_run")
	(k[1] as VatClipScript).seek(0.52)
	await _capture("vat_run_b")
	await _clear([cv])


## Old procedural soldiers vs the knights, same framing, side by side.
func _shot_compare() -> void:
	var old := CrowdView.new()
	add_child(old)
	old.setup(Models.soldier_mesh(), ARMY)
	old.set_tint(Color.WHITE)
	old.set_edge(Color(0.55, 0.8, 1.0), 0.35)
	old.draw(_blob(), ARMY, PI, 0.08, 0.08)
	_place_cam("game")
	var a := await _capture("vat_old_run")
	await _clear([old])
	var k := _knights(ARMY, "run", 0.40, RUN_RATE)
	(k[0] as CrowdView).draw(_blob(), ARMY, PI, 0.08, 0.08)
	var b := await _capture("vat_new_run")
	await _clear([k[0]])
	# Crop the blob region of both and put them side by side.
	var crop := Rect2i(60, 360, 600, 760)
	var sheet := Image.create(crop.size.x * 2 + 12, crop.size.y, false, a.get_format())
	sheet.fill(Color(0.05, 0.06, 0.1))
	sheet.blit_rect(a, crop, Vector2i.ZERO)
	sheet.blit_rect(b, crop, Vector2i(crop.size.x + 12, 0))
	sheet.save_png(out_dir.path_join("vat_compare.png"))
	print("SHOT ", out_dir.path_join("vat_compare.png"), "  (left: old procedural soldiers, right: baked knights)")


## Close-up of the running blob from the 3/4 back view.
func _shot_close() -> void:
	var k := _knights(ARMY, "run", 0.31, RUN_RATE)
	(k[0] as CrowdView).draw(_blob(), ARMY, PI, 0.08, 0.08)
	_place_cam("close")
	await _capture("vat_run_close")
	await _clear([k[0]])


## Each clip at six evenly spaced moments: a profile row (facing +X) and a back row (facing -Z,
## as the game camera sees the army), in a wide sub-viewport.
func _shot_sheets() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 760)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := Camera3D.new()
	c.fov = 30.0
	vp.add_child(c)
	c.position = SHEET + Vector3(0.0, 2.3, 7.4)
	c.look_at(SHEET + Vector3(0.0, 0.42, 0.0))
	c.make_current()
	for clip in ["run", "walk", "attack", "idle", "victory"]:
		var v := _new_vat()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = v.mesh
		mm.instance_count = 12
		var n := 6
		for i in 12:
			var row := i / n
			var col := i % n
			var yaw := PI * 0.5 if row == 0 else PI
			var pos := SHEET + Vector3((col - (n - 1) * 0.5) * 0.95, 0.0, 0.55 if row == 0 else -0.75)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), pos))
			mm.set_instance_color(i, Color.WHITE)
			# phase i/6 of the loop: six moments of the same clip
			mm.set_instance_custom_data(i, Color(TAU * col / n, 0.0, 0.0, 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		v.attach(mmi)
		v.material.set_shader_parameter("sway_scale", 0.0)
		v.material.set_shader_parameter("edge_color", Color(0.55, 0.8, 1.0))
		v.material.set_shader_parameter("edge_amount", 0.35)
		v.play(clip, 0.0)
		v.seek(0.0)
		var title := _label(SHEET + Vector3(-2.75, 1.45, 0.55), "%s  (%d frames, %.2f s, %.1f fps)" % [
			clip, int(v.clips[clip]["frames"]), v.length(clip), float(v.clips[clip]["fps"])], 64)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for col in n:
			_label(SHEET + Vector3((col - (n - 1) * 0.5) * 0.95, 1.12, 0.55), "t = %.2f s" % (v.length(clip) * col / n), 40)
		await _capture("vat_clip_" + clip, vp)
		await _clear([mmi])
	vp.queue_free()
	cam.make_current()


## 220 knights stabbing at a red raider squad at the clash line.
func _shot_clash() -> void:
	var k := _knights(ARMY, "attack", 0.0)
	var cv: CrowdView = k[0]
	var front := _blob(Vector3(0, 0, -2.6))
	cv.draw(front, ARMY, PI, 0.0, 0.08)
	var squad := CrowdView.new()
	add_child(squad)
	squad.setup(Models.raider_mesh(), 64)
	squad.set_edge(Color(1.0, 0.4, 0.15), 0.4)
	var sp := PackedVector3Array()
	for i in 48:
		var row := i / 8
		var col := i % 8
		sp.append(Vector3((col - 3.5) * 0.44 + (0.12 if row % 2 == 1 else 0.0), 0, -1.75 - row * 0.46))
	squad.draw(sp, 48, 0.0, 0.07, 0.1)
	_place_cam("game")
	(k[1] as VatClipScript).seek(0.35)
	await _capture("vat_clash")
	_place_cam("clash_close")
	(k[1] as VatClipScript).seek(0.62)
	await _capture("vat_clash_close")
	await _clear([cv, squad])


## Victory: every knight doing the spin jump, staggered by its phase.
func _shot_victory() -> void:
	var k := _knights(ARMY, "victory", 0.0)
	(k[0] as CrowdView).draw(_blob(), ARMY, PI, 0.0, 0.05)
	_place_cam("victory")
	(k[1] as VatClipScript).seek(0.9)
	await _capture("vat_victory")
	_place_cam("game")
	await _capture("vat_victory_game")
	await _clear([k[0]])


## Correctness: (left) the source GLB skinned by Godot with the raw Running clip, (middle) the
## VAT on the GPU at the same moment, (right) the same frame decoded on the CPU from the texture.
## Middle and right must match; left shows what the bake fixed (right foot through the floor,
## spear weighted to the head and toes, shield to the thigh).
func _shot_verify() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 700)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := Camera3D.new()
	c.fov = 28.0
	vp.add_child(c)
	var at := SHEET + Vector3(0, 0, 8)
	c.position = at + Vector3(0.25, 0.75, 4.2)
	c.look_at(at + Vector3(0.0, 0.36, 0.0))
	c.make_current()
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
		add_child(holder)
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
	add_child(mmi)
	v.attach(mmi)
	v.material.set_shader_parameter("sway_scale", 0.0)
	v.material.set_shader_parameter("ao_strength", 0.0)
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
	add_child(cmi)
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
	_label(at + Vector3(-1.1, 0.95, 0), "Godot skinning, raw clip", 40)
	_label(at + Vector3(0, 0.95, 0), "VAT on GPU", 40)
	_label(at + Vector3(1.1, 0.95, 0), "VAT decoded on CPU", 40)
	await _capture("vat_verify", vp)
	await _clear(nodes)
	vp.queue_free()
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

## Rough render cost of 220 units: average frame times over a few hundred frames with nothing,
## the old soldiers, and the VAT knights (run clip, ticking).
func _bench() -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	_place_cam("game")
	var results := {}
	for mode in ["empty", "old", "vat", "vat_fade"]:
		var nodes := []
		var v: VatClipScript = null
		if mode == "old":
			var old := CrowdView.new()
			add_child(old)
			old.setup(Models.soldier_mesh(), ARMY)
			nodes.append(old)
		elif mode.begins_with("vat"):
			var k := _knights(ARMY, "run", 0.0, RUN_RATE)
			nodes.append(k[0])
			v = k[1]
			if mode == "vat_fade":
				v.play("attack", 1000.0)
		for i in 30:
			await get_tree().process_frame
		var n := 240
		var cpu := 0.0
		var gpu := 0.0
		var t0 := Time.get_ticks_usec()
		for i in n:
			for cv in nodes:
				(cv as CrowdView).draw(_blob(), ARMY, PI, 0.08, 0.08)
			if v:
				v.tick(1.0 / 60.0)
			await RenderingServer.frame_post_draw
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
		results[mode] = [wall, cpu / n, gpu / n]
		print("BENCH %-8s frame %.2f ms  render cpu %.2f ms  gpu %.2f ms  primitives %d" % [
			mode, wall, cpu / n, gpu / n, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		for nd in nodes:
			nd.queue_free()
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	var tv := _new_vat()
	tv.play("run")
	for i in 10000:
		tv.tick(0.016)
	print("BENCH VatClip.tick: %.4f ms/call" % ((Time.get_ticks_usec() - t1) / 1000.0 / 10000.0))
