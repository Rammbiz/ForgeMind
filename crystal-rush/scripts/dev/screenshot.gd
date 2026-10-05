extends Node
## Renders a screenshot for visual checks.
## Usage: godot --rendering-driver opengl3 -- --shot=out.png [--screen=menu|run] [--level=N]
##        [--hero=bolt|titan] [--play=seconds of game time] [--ult] [--frames=N]

var args := {}


func _ready() -> void:
	var main := get_parent()
	var screen := str(args.get("screen", "run"))
	var out := str(args.get("shot", "user://shot.png"))
	if screen == "portraits":
		# Hero close-ups for the app icon (tools/make_icons.py), saved next to --shot.
		for type: String in ["bolt", "titan"]:
			var img := await _portrait(type, 512)
			img.save_png(out.get_basename() + "_" + type + ".png")
		print("SHOT portraits saved")
		get_tree().quit(0)
		return
	if screen == "menu":
		main.call("set_scene_now", Menu.new())
	else:
		var holder: Node = main.call("make_play", int(args.get("level", "1")), str(args.get("hero", "bolt")))
		main.call("set_scene_now", holder)
		await get_tree().process_frame
		var run: Run = holder.get_meta("run")
		var play := float(args.get("play", "0"))
		if play > 0.0:
			var bot := Bot.new()
			bot.skill = float(args.get("skill", "1.0"))
			var t := 0.0
			while t < play and run.state != Run.State.WON and run.state != Run.State.LOST:
				bot.think(run)
				await get_tree().process_frame
				t += minf(get_process_delta_time(), 0.1)
				if args.has("ult") and run.ult_ready():
					run.use_ult()
	var frames := int(args.get("frames", "20"))
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0)


func _portrait(type: String, px: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	vp.add_child(sun)
	var m := HeroModels.hero(type)
	m.rotation_degrees.y = 14.0
	vp.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var frame: Array = m.get_meta("portrait")
	cam.look_at_from_position(frame[0], frame[1])
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
