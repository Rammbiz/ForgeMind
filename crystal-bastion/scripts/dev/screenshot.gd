extends Node
## Renders a screenshot of a screen for visual checks.
## Usage: godot --rendering-driver opengl3 -- --shot=out.png --screen=game --level=1 --play=40 [--ui=build|tower|hero|pause|result]
##        [--zoom=f] [--focus=x,z] [--hero_focus=i] [--spawn=type:count[:seconds]]
##        [--ult=seconds | --ability=seconds]

var args := {}


func _ready() -> void:
	var main := get_parent()
	var screen := str(args.get("screen", "game"))
	var out := str(args.get("shot", "user://shot.png"))
	match screen:
		"menu":
			main.call("set_scene_now", Menu.new())
		"levels":
			var m := Menu.new()
			m.start_page = "levels"
			main.call("set_scene_now", m)
		"settings":
			var m2 := Menu.new()
			main.call("set_scene_now", m2)
			await get_tree().process_frame
			m2.show_settings()
		_:
			var g := Game.new()
			g.setup(int(args.get("level", "1")) - 1)
			main.call("set_scene_now", g)
			await get_tree().process_frame
			if not args.has("hint"):
				g.hud._hint.visible = false
			var play := float(args.get("play", "0"))
			if play > 0.0:
				var bot := Bot.new()
				bot.skill = float(args.get("skill", "1.0"))
				var t := 0.0
				var think := 0.0
				Engine.time_scale = 3.0
				while t < play and g.is_running():
					await get_tree().process_frame
					var d := get_process_delta_time()
					t += d
					think -= d
					if think <= 0.0:
						think = 0.5
						bot.think(g)
				Engine.time_scale = 1.0
			if args.has("zoom"):
				g.cam.zoom_by(float(args["zoom"]))
				g.cam.dist = g.cam._target_dist
			if args.has("focus"):
				var f := str(args["focus"]).split(",")
				g.cam._target_focus = Vector3(float(f[0]), 0, float(f[1]))
				g.cam.focus = g.cam._target_focus
			if args.has("spawn"):
				# --spawn=type:count[:seconds] drops enemies just before the heroes and lets the
				# fight run for a while (game time).
				var sp := str(args["spawn"]).split(":")
				var curve: Curve3D = g.map.curves[0]
				for i in int(sp[1]):
					g.spawn_enemy(sp[0], 0, 1.0, maxf(curve.get_baked_length() - 3.5 - i * 0.45, 0.0))
				var fight := float(sp[2]) if sp.size() > 2 else 1.0
				var ran := 0.0
				while ran < fight:
					await get_tree().process_frame
					ran += Game.step(get_process_delta_time())
			if args.has("hero_focus") and not g.heroes.is_empty():
				var hp := (g.heroes[int(args["hero_focus"])] as Hero).global_position
				g.cam._target_focus = Vector3(hp.x, 0, hp.z)
				g.cam.focus = g.cam._target_focus
			if args.has("ult") or args.has("ability"):
				# Fire the heroes' moves and catch them mid-flight.
				for h: Hero in g.heroes:
					if args.has("ult"):
						h.ult_cooldown = 0.0
						g.use_hero_ult(h)
					else:
						h.cooldown = 0.0
						h.use_ability()
				# Wait in game time: software-rendered frames are slow and Game.step clamps them.
				var want := float(args.get("ult", args.get("ability", "0.3")))
				var waited := 0.0
				while waited < want:
					await get_tree().process_frame
					waited += Game.step(get_process_delta_time())
			var ui := str(args.get("ui", ""))
			match ui:
				"build":
					var bot2 := Bot.new()
					var c := bot2.best_cell(g, "arrow")
					g.hud.open_build_menu(c)
					await get_tree().process_frame
					var bm := g.hud._menu as BuildMenu
					if bm:
						bm._on_pick(g.level["towers"][0])
				"tower":
					if not g.towers.is_empty():
						g.hud.open_tower_panel(g.towers.values()[0])
				"hero":
					if not g.heroes.is_empty():
						g.select_hero(g.heroes[0])
				"pause":
					g.hud.open_pause()
				"result":
					g._finish(true)
	if args.has("icons") and screen == "game":
		await get_tree().create_timer(1.0).timeout
		var hud: Hud = (main.get("current") as Game).hud
		var dir := str(args["icons"])
		DirAccess.make_dir_recursive_absolute(dir)
		for k in hud._icons:
			(hud._icons[k] as Texture2D).get_image().save_png("%s/tower_%s.png" % [dir, k])
		for k in hud._enemy_icons:
			(hud._enemy_icons[k] as Texture2D).get_image().save_png("%s/enemy_%s.png" % [dir, k])
		for k in hud._hero_icons:
			(hud._hero_icons[k] as Texture2D).get_image().save_png("%s/hero_%s.png" % [dir, k])
		print("ICONS saved to ", dir)
	var frames := int(args.get("frames", "40"))
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("SHOT saved ", out, " ", img.get_size(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit(0)
