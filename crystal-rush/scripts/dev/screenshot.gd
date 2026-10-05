extends Node
## Renders a screenshot for visual checks.
## Usage: godot --rendering-driver opengl3 -- --shot=out.png [--screen=menu|run|portraits]
##        [--level=N] [--hero=bolt|titan] [--frames=N]
## Run setup (applied in this order):
##   --army=N          start with N soldiers
##   --weapons=a,b     grant war machines (ballista,cannon,laser,rockets,drone); repeat a kind to level it
##   --arm=T           army weapon tier (1 crossbows, 2 blasters)
##   --skip=D          jump the run to distance D
##   --state=S         siege (walk up to the fortress), stairs (break the fortress, climb),
##                     result (play to the end and show the result panel)
##   --x=X             hold the hero at x (else the bot steers)
##   --play=SECONDS    game seconds to play before the shot (bot or --x)
##   --until=D         play until the hero reaches distance D (instead of / before --play)
##   --ult             fire the ult as soon as it is ready; --ult_now fills it and fires at once
##   --charge          fill the ult (no fire)
##   --hide_hud        hide the HUD layer
##   --pause           open the pause panel before the shot
##   --lang=uk|en      language (read by Loc)

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
		await _run_setup(main)
	var frames := int(args.get("frames", "12"))
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png(out)
	print("SHOT saved ", out, " ", img2.get_size(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0)


func _run_setup(main: Node) -> void:
	Save.readonly = true
	var holder: Node = main.call("make_play", int(args.get("level", "1")), str(args.get("hero", "bolt")))
	main.call("set_scene_now", holder)
	await get_tree().process_frame
	var run: Run = holder.get_meta("run")
	if args.has("hide_hud"):
		(holder.get_meta("hud") as CanvasLayer).visible = false
	if args.has("army"):
		run.set_army(int(args["army"]))
	if args.has("arm"):
		run.arm_tier = int(args["arm"])
		run.show_arm_tier()
		run.power_changed.emit("arm", float(run.arm_tier))
	if args.has("weapons"):
		for k: String in str(args["weapons"]).split(","):
			if k != "":
				run.give_weapon(k)
	if args.has("skip"):
		run.skip_to(float(args["skip"]))
	if args.has("charge") or args.has("ult_now"):
		run.ult_points = float(run.ult["charge"])
		if not args.has("ult_now"):
			run._emit_ult()       # (--ult_now fires at once: no "ult ready" toast over the shot)
	var bot := Bot.new()
	bot.skill = float(args.get("skill", "1.0"))
	var hold := args.has("x")
	var hx := float(args.get("x", "0"))
	if hold:
		run.steer_to(hx)
		run.hx = hx
	var st := str(args.get("state", ""))
	if st == "siege" or st == "stairs" or st == "result":
		run.skip_to(maxf(run.d, run.length - 9.0))
		await _play(run, bot, hold, hx, 30.0, func() -> bool: return run.state != Run.State.RUNNING)
		if st == "stairs" or st == "result":
			await _play(run, bot, hold, hx, 0.6, Callable())
			var f: Dictionary = run._fortress
			if f["alive"]:
				run.hurt(f, float(f["hp"]) + 1.0)
			await _play(run, bot, hold, hx, 30.0, func() -> bool: return run._stair_phase >= 2 or run.state == Run.State.WON)
		if st == "result":
			await _play(run, bot, hold, hx, 60.0, func() -> bool: return run.state == Run.State.WON or run.state == Run.State.LOST)
			for i in 90:
				await get_tree().process_frame
	if args.has("ult_now"):
		run.start()
		run.use_ult()
	if args.has("until"):
		var to := float(args["until"])
		await _play(run, bot, hold, hx, 120.0, func() -> bool: return run.d >= to)
	var play := float(args.get("play", "0"))
	if play > 0.0:
		await _play(run, bot, hold, hx, play, Callable())
	if args.has("dbg"):
		var fl := run._fortress["label"] as Label3D
		print("DBG fort label vis=", fl.is_visible_in_tree(), " pos=", fl.global_position, " text=", fl.text, " scale=", fl.scale, " mod=", fl.modulate, " px=", fl.pixel_size)
		print("DBG state=", run.state, " army=", run.army, " label=", run._army_label.global_position, " vis=", run._army_label.visible, " bounds=", run.army_view.bounds(), " d=", run.d)
	if args.has("pause"):
		(holder.get_meta("hud") as RunHud).pause()


## Plays up to `seconds` of game time (or until `stop` returns true).
func _play(run: Run, bot: Bot, hold: bool, hx: float, seconds: float, stop: Callable) -> void:
	var t := 0.0
	run.start()
	while t < seconds and run.state != Run.State.WON and run.state != Run.State.LOST:
		if stop.is_valid() and stop.call():
			return
		if hold:
			run.steer_to(hx)
		else:
			bot.think(run)
		if args.has("ult") and run.ult_ready():
			run.use_ult()
		await get_tree().process_frame
		t += minf(get_process_delta_time(), Run.MAX_FRAME)


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
