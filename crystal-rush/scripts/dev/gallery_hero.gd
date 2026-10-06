extends Node3D
## Hero animation sheet (dev): one hero driven exactly as RunHero drives it, sampled over a
## script of states (idle, run, casts while running, the ult) from a 3/4 front camera.
## Usage: godot --rendering-driver opengl3 --resolution 360x460 res://scenes/dev/gallery_hero.tscn
##        -- --hero=seer --out=/path/sheet.png [--view=front|back|side] [--cols=8]

const STEP := 1.0 / 30.0

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_go.call_deferred()


func _go() -> void:
	if args.has("probe"):
		# Prints the hero / army / assist blocks the run would read (WS2b hooks) per level.
		for lvl in range(1, int(args.get("to", "20")) + 1):
			Meta.account = Meta.synthetic_account(lvl, str(args.get("profile", "expected")))
			var p := Meta.run_profile(lvl)
			print("PROBE L%d hero=%s army=%s assist=%s" % [lvl, str(p.get("hero")), str(p.get("army")), str(p.get("assist"))])
		get_tree().quit(0)
		return
	var type := str(args.get("hero", "seer"))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.15, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = Mats.quad(Vector2(6, 6))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.4, 0.8)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var m := HeroModels.hero(type)
	add_child(m)
	if m.has_meta("tree"):
		(m.get_meta("tree") as AnimationTree).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var cam := Camera3D.new()
	add_child(cam)
	var view := str(args.get("view", "front"))
	var eye := {"front": Vector3(1.4, 1.3, 3.0), "back": Vector3(0.6, 3.2, -4.0), "side": Vector3(3.4, 1.0, 0.0)}[view] as Vector3
	cam.look_at_from_position(eye, Vector3(0, 0.75, 0))
	cam.fov = 38.0
	cam.make_current()
	# State script: [seconds, moving, strike at start, ult at start, label]
	var plan := [[0.6, false, false, false], [0.5, true, false, false], [0.6, true, true, false], [0.6, true, true, false],
		[3.6, true, false, true], [0.5, false, true, false]]
	var cols := int(args.get("cols", "8"))
	var every := float(args.get("every", "0.2"))
	var shots: Array[Image] = []
	var t := 0.0
	var attack := 0.0
	var ult := 0.0
	var next_shot := 0.0
	var rig := HeroModels.rig(type)
	for st: Array in plan:
		var dur: float = st[0]
		if st[2]:
			attack = 1.0
		if st[3]:
			ult = 1.0
		var e := 0.0
		while e < dur:
			e += STEP
			t += STEP
			attack = maxf(attack - STEP * float(rig["attack_decay"]), 0.0)
			ult = maxf(ult - STEP / 4.0, 0.0)
			HeroModels.animate_hero(m, t, bool(st[1]), attack, 0.0, ult, false, false, float(rig["pace"]))
			m.position.y = float(m.get_meta("float", 0.0))
			var tree: Variant = m.get_meta("tree") if m.has_meta("tree") else null
			if tree:
				(tree as AnimationTree).advance(STEP)
			if t >= next_shot:
				next_shot += every
				await RenderingServer.frame_post_draw
				shots.append(get_viewport().get_texture().get_image())
			else:
				await get_tree().process_frame
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var rows := ceili(float(shots.size()) / cols)
	var sheet := Image.create(w * cols, h * rows, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(str(args.get("out", "user://hero_sheet.png")))
	print("SHEET ", shots.size(), " frames -> ", args.get("out", ""))
	get_tree().quit(0)
