extends Node3D
## Dev preview of the enemy crowd: the owner's Emberhorn Sentinel baked to VAT
## (tools/bake_vat.gd profile "emberhorn", assets/units/emberhorn/*). Shots:
##   src     the source GLB as Godot skins it (rest pose and its Running clip), orthographic with
##           a 0.1 grid, to place the spear and the glow region of the bake profile
##   sheets  every baked clip at six moments (profile row and the game camera's front row)
##   squad   an idle Emberhorn squad waiting on the road, close and from the game camera
##   charge  a squad charging: the back ranks run, the front rank stabs (zone clip)
##   deaths  Emberhorns dying (UnitFx enemy pool: recoil, fall, embers) at three moments
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
const ALL_SHOTS := ["src", "sheets", "squad", "charge", "deaths"]

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
