extends Node3D
## Dev preview for Juice popups and the army counter on the real level-1 road (role JUICE).
##   godot --path . --rendering-driver opengl3 --resolution 720x1280 res://scenes/dev/gallery_juice.tscn [-- --out=DIR]
## Saves juice_gain.png (gate pass: "+12", "×2", tile "+1", counter flashing green mid-roll),
## juice_loss.png (spikes "-5", counter flashing red) and juice_close.png (typography close-up).

const ARMY := 90

var out_dir := "/tmp/claude-0/-home-user-ForgeMind/aefe1e02-146d-51a2-95d9-fb60d101a978/scratchpad/rshots"
var juice: Juice
var cam: Camera3D
var counter: Label3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var track := Track.new()
	add_child(track)
	track.build(160.0, true, Worlds.for_level(1))
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 260.0
	cam.fov = 62.0
	add_child(cam)
	cam.position = Vector3(0, 8.6, 6.0)
	cam.look_at(Vector3(0, 0, -3.2))
	cam.make_current()
	_build_army()
	juice = Juice.new()
	add_child(juice)
	counter = Models.label("30", 100, Color.WHITE, true)
	counter.position = Vector3(0, 1.9, 1.2)
	counter.no_depth_test = true
	counter.render_priority = 10
	add_child(counter)
	await _frames(30)
	# --- gain moment
	juice.counter(counter, 47)
	juice.popup("+12", Vector3(-1.1, 2.0, -3.0), Color(0.35, 1.0, 0.5), 1.35)
	juice.popup("×2", Vector3(1.6, 2.3, -6.0), Color(1.0, 0.82, 0.3), 1.2)
	juice.popup("+1", Vector3(-2.3, 0.9, -0.6), Color.WHITE, 0.7)
	juice.popup("+1", Vector3(2.2, 0.9, -1.4), Color.WHITE, 0.7)
	juice.popup("+3", Vector3(1.0, 1.1, 0.2), Color(1.0, 0.85, 0.35), 0.8)
	await _shoot_after(0.16, "juice_gain")
	await _wait_real(0.8)
	# --- loss moment
	juice.counter(counter, 35)
	juice.popup("-5", Vector3(-1.4, 1.6, -1.6), Color(1.0, 0.33, 0.3), 1.1)
	juice.popup("-8", Vector3(0.9, 1.8, -4.0), Color(1.0, 0.33, 0.3), 1.25)
	juice.popup("+20% швидкість", Vector3(0.0, 2.6, -7.0), Color(1.0, 0.8, 0.3), 0.8)
	await _shoot_after(0.12, "juice_loss")
	await _wait_real(0.8)
	# --- typography close-up
	cam.position = Vector3(0, 3.2, 3.6)
	cam.look_at(Vector3(0, 1.5, -1.0))
	juice.counter(counter, 128)
	juice.popup("+81", Vector3(-1.0, 1.4, -1.0), Color(0.35, 1.0, 0.5), 1.0)
	juice.popup("-12", Vector3(1.2, 1.6, -1.6), Color(1.0, 0.33, 0.3), 1.0)
	await _shoot_after(0.22, "juice_close")
	get_tree().quit(0)


func _build_army() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.soldier_mesh()
	mm.instance_count = ARMY
	var golden := PI * (3.0 - sqrt(5.0))
	for i in ARMY:
		var r := 1.5 * sqrt((i + 0.5) / ARMY)
		var a := i * golden
		var p := Vector3(cos(a) * r, 0, 2.2 + sin(a) * r * 1.15)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, PI), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Models.vertex_material()
	add_child(mmi)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_real(sec: float) -> void:
	var t := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t < int(sec * 1e6):
		await get_tree().process_frame


## Software GL frames are slow, so the animation is stepped in place: Juice is advanced on real
## time in small sleeps up to `sec`, then frozen while the frame renders.
func _shoot_after(sec: float, shot_name: String) -> void:
	juice.set_process(false)
	var steps := ceili(sec / 0.05)
	for i in steps:
		OS.delay_usec(int(sec / steps * 1e6))
		juice._process(0.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("SHOT ", path, " counter=", counter.text, " scale=", counter.scale.x)
	juice.set_process(true)
