extends Node
## Hero art model preview (HeroModels.art: the Meshy model, its clips and props), one sheet of poses:
##   godot --path crystal-rush --resolution 640x480 res://scenes/dev/art_preview.tscn -- --autotest
##         --hero=olha --out=<png> --poses=idle:1.0:0,attack_a:2.0:30   (clip:seconds:yaw, yaw 0 = front)
## Needs a real renderer (run it on a hidden desktop, muted). Phase-free: it only builds the model.

const W := 400
const H := 600


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var hero := str(args.get("hero", "olha"))
	var out := str(args.get("out", "user://art_preview.png"))
	var poses: PackedStringArray = str(args.get("poses", "idle:1.0:0,idle:1.0:90,run:0.3:180")).split(",")
	if not ResourceLoader.exists(HeroModels.ART_DIR % hero):
		print("ART_PREVIEW no art model for ", hero)
		get_tree().quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	var model := HeroModels.art(hero)
	pivot.add_child(model)
	if args.has("bones"):
		# Bone frames for tuning ART_PROPS: each listed bone's global basis in model units.
		await get_tree().process_frame
		var sk := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for bn in str(args["bones"]).split(","):
			var i := sk.find_bone(bn)
			if i >= 0:
				var g := sk.global_transform * sk.get_bone_global_pose(i)
				print("BONE %s origin %s x %s y %s z %s" % [bn, g.origin, g.basis.x.normalized(), g.basis.y.normalized(),
						g.basis.z.normalized()])
	var cam := Camera3D.new()
	cam.fov = 32
	vp.add_child(cam)
	await get_tree().process_frame
	var hh := float(model.get_meta("bar_y", 1.5))
	cam.look_at_from_position(Vector3(0, hh * 0.5, hh * 2.4), Vector3(0, hh * 0.48, 0))
	var ap: AnimationPlayer = model.get_meta("player")
	var sheet := Image.create(W * poses.size(), H, false, Image.FORMAT_RGBA8)
	for i in poses.size():
		var parts := poses[i].split(":")
		pivot.rotation_degrees.y = float(parts[2]) if parts.size() > 2 else 0.0
		ap.play(parts[0])
		ap.seek(float(parts[1]) if parts.size() > 1 else 0.0, true)
		ap.pause()
		for p: Array in model.get_meta("props", []):
			(p[0] as Node3D).visible = (p[1] as Array).is_empty() or (p[1] as Array).has(parts[0])
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * i, 0))
	sheet.save_png(out)
	print("ART_PREVIEW saved ", out)
	get_tree().quit(0)
