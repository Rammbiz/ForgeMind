extends SceneTree
## Renders the app icon and the Android launcher icons from the game's own
## procedural pieces: LevelMap terrain + crystal, a Models tower, Mats materials.
##
## Needs a real GL context (not --headless). From the repo root:
##   xvfb-run -a -s "-screen 0 1280x1024x24" godot --path crystal-bastion \
##       --rendering-driver opengl3 --audio-driver Dummy --script res://tools/render_icons.gd
## The result is deterministic (seeded level generator), so re-running only changes the
## PNGs when the models/materials or this script change. Run `godot --headless --import`
## afterwards so the .import files are refreshed.
## Optional user args (after `--`):
##   --out=/abs/dir   write the files under another directory (previews)
##   --debug          also save the raw transparent subject render
##
## Outputs (relative to the project root / --out):
##   icon.png                                  512x512 opaque, project + store icon
##   assets/icons/android_main_192.png         192x192 legacy launcher icon (rounded square)
##   assets/icons/android_adaptive_fg_432.png  432x432 transparent foreground layer
##   assets/icons/android_adaptive_bg_432.png  432x432 gradient background layer
##   assets/icons/android_monochrome_432.png   432x432 white-on-transparent (themed icons)

const RENDER_SIZE := 1024
const GLOW_COLOR := Color(0.35, 0.95, 1.0)
const BG_TOP := Color(0.2, 0.1, 0.42)
const BG_MID := Color(0.08, 0.17, 0.45)
const BG_BOTTOM := Color(0.02, 0.33, 0.45)
## Adaptive icons: everything important must stay inside the 66dp circle of the
## 108dp canvas (radius 0.3056 of the width). A little margin is kept for the glow.
const ADAPTIVE_SAFE_RADIUS := 0.295

var _out_dir := "res://"
var _debug := false
## Projected centre of the crystal inside the cropped subject image (pixels).
var _crystal_px := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		match kv[0]:
			"out":
				_out_dir = kv[1].trim_suffix("/") + "/"
			"debug":
				_debug = true
	_run.call_deferred()


func _run() -> void:
	var subject := await _render_subject()
	if _debug:
		subject.save_png(_path("debug_subject_raw.png"))
	var used := subject.get_used_rect()
	var crop := subject.get_region(used)
	_crystal_px -= Vector2(used.position)

	# Opaque square app icon (store listing, desktop builds, legacy fallback).
	_save(_compose(512, crop, _box_scale(crop, 512, 0.86), true), "icon.png")
	# Legacy (pre-Android 8) launcher icon: same art inside a rounded square.
	var legacy := _compose(192, crop, _box_scale(crop, 192, 0.8), true)
	_round_corners(legacy, 0.2)
	_save(legacy, "assets/icons/android_main_192.png")
	# Adaptive icon layers: the subject is fitted into the safe-zone circle.
	var k := _circle_scale(crop, 432, ADAPTIVE_SAFE_RADIUS)
	_save(_background(432, _crystal_uv(crop, 432, k)), "assets/icons/android_adaptive_bg_432.png")
	_save(_compose(432, crop, k, false), "assets/icons/android_adaptive_fg_432.png")
	_save(_monochrome(_place(432, crop, k)), "assets/icons/android_monochrome_432.png")
	print("ICONS done -> ", _path(""))
	quit(0)


func _path(rel: String) -> String:
	var p := _out_dir + rel
	if p.begins_with("res://") or p.begins_with("user://"):
		p = ProjectSettings.globalize_path(p)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	return p


func _save(img: Image, rel: String) -> void:
	var err := img.save_png(_path(rel))
	print("ICON ", rel, " ", img.get_size(), " err=", err)
	if err != OK:
		push_error("Could not save " + rel)


# ------------------------------------------------------------------ 3D scene

func _render_subject() -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var gd: GDScript = load("res://scripts/autoload/game_data.gd")
	var theme: Dictionary = (gd.LEVELS[0]["theme"] as Dictionary).duplicate()
	theme["grass_a"] = Color(0.36, 0.74, 0.22)
	theme["grass_b"] = Color(0.31, 0.68, 0.2)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 1.0)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.35
	env.adjustment_contrast = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 15.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 20.0
	sun.shadow_opacity = 0.65
	vp.add_child(sun)
	# Cool rim light from behind for crisp silhouettes against the dark background.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10.0, 215.0, 0.0)
	rim.light_color = Color(0.45, 0.7, 1.0)
	rim.light_energy = 0.45
	vp.add_child(rim)

	# A small floating island made by the real level generator.
	# T = plain grass (tower / crystal footprint), C = crystal, t = tree, r = rocks, . = lawn.
	var lm := LevelMap.new()
	vp.add_child(lm)
	lm.build({
		"id": "icon",
		"map": [
			"x.tx",
			".TTt",
			"TTCr",
			"x..x",
		],
		"theme": theme,
	}, true)
	lm.set_process(false)
	for c in lm._clouds:
		c.free()
	var amb := lm.get_node_or_null("Ambient")
	if amb:
		amb.free()
	# Deeper stepped rock "root" so the chunk reads as floating even at 48 px.
	var void_dist: Dictionary = lm._distance_to_void()
	for c: Vector2i in lm.depth:
		var inner := int(void_dist[c]) > 0
		lm.depth[c] = -2.2 if inner else -0.85 - 0.14 * float((c.x * 7 + c.y * 3) % 3)
	lm.get_node("Terrain").free()
	lm._build_terrain()
	# ...ending in a faceted rock spike under the 2x2 core.
	var deep: Color = theme["deep"]
	Mats.part(lm, Mats.cone(1.414, 1.3, 4), Mats.solid(deep.darkened(0.08), 0.95), Vector3(0, -2.2 - 0.65, 0), Vector3(180, 45, 0))

	# The crystal is the hero: centred on the island, bigger, floating over its pedestal.
	var crystal := lm.crystal
	for ch in crystal.get_children():
		if ch is CPUParticles3D:
			ch.free()
	crystal.position = Vector3(0.0, -0.06, 0.0)
	crystal.scale = Vector3.ONE * 1.6
	var glow_light := crystal.get_meta("light") as OmniLight3D
	glow_light.light_energy = 2.6
	glow_light.omni_range = 4.5
	var core := lm.crystal_core
	core.scale = Vector3.ONE * 1.5
	core.position.y = 1.12
	core.rotation_degrees.y = 20.0
	var core_mat := core.material_override as StandardMaterial3D
	core_mat.albedo_color = Color(0.3, 0.9, 1.0)
	core_mat.emission = Color(0.05, 0.6, 0.9)
	core_mat.emission_energy_multiplier = 0.9
	core_mat.roughness = 0.08
	core_mat.metallic = 0.35
	core_mat.rim = 0.7
	core_mat.rim_tint = 0.2

	# A few hand-placed flowers on the front lawn for colour at store-listing size.
	var stem := Mats.solid((theme["grass_b"] as Color).darkened(0.18), 0.9)
	var flowers: Array = theme["flowers"]
	var spots := [Vector3(-0.85, 0, 1.25), Vector3(-0.45, 0, 1.7), Vector3(0.35, 0, 1.45), Vector3(0.75, 0, 1.15), Vector3(1.6, 0, 0.9)]
	for i in spots.size():
		var p: Vector3 = spots[i] + Vector3(0, 0.03, 0)
		Mats.part(lm, Mats.cyl(0.012, 0.012, 0.16, 3), stem, p + Vector3(0, 0.08, 0), Vector3.ZERO, Vector3.ONE, false)
		Mats.part(lm, Mats.sphere(0.06, -1, 6, 3), Mats.solid(flowers[i % flowers.size()], 0.6), p + Vector3(0, 0.17, 0), Vector3.ZERO, Vector3.ONE, false)

	# One upgraded arrow tower guarding it.
	var tower := Models.tower("arrow", 2)
	tower.position = lm.cell_to_world(Vector2i(0, 2))
	tower.rotation_degrees.y = 60.0
	tower.scale = Vector3.ONE * 1.1
	lm.add_child(tower)

	var cam := Camera3D.new()
	cam.fov = 30.0
	var target := Vector3(0.0, -0.35, 0.0)
	var yaw := deg_to_rad(45.0)
	var pitch := deg_to_rad(24.0)
	cam.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 12.5
	vp.add_child(cam)
	cam.look_at(target)
	cam.current = true

	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	_crystal_px = cam.unproject_position(core.global_position)
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img


# ------------------------------------------------------------------ layout

## Scale that makes the subject's bounding box fill `fill` of the canvas.
func _box_scale(crop: Image, size: int, fill: float) -> float:
	var cs := crop.get_size()
	return fill * size / float(maxi(cs.x, cs.y))


## Scale that keeps every visible pixel inside a centred circle of radius `radius` * size.
func _circle_scale(crop: Image, size: int, radius: float) -> float:
	var cs := crop.get_size()
	var centre := Vector2(cs) * 0.5
	var r_max := 1.0
	for y in range(0, cs.y, 2):
		for x in range(0, cs.x, 2):
			if crop.get_pixel(x, y).a > 0.05:
				r_max = maxf(r_max, (Vector2(x, y) - centre).length())
	return radius * size / r_max


## Crystal position on a `size` canvas (0..1) for a subject placed with scale `k`.
func _crystal_uv(crop: Image, size: int, k: float) -> Vector2:
	var cs := Vector2(crop.get_size()) * k
	var origin := (Vector2(size, size) - cs) * 0.5
	return (origin + _crystal_px * k) / float(size)


## Scales the subject by `k` and centres it on a transparent square canvas.
func _place(size: int, crop: Image, k: float) -> Image:
	var cs := crop.get_size()
	var w := maxi(1, roundi(cs.x * k))
	var h := maxi(1, roundi(cs.y * k))
	var scaled := crop.duplicate() as Image
	scaled.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i((size - w) / 2, (size - h) / 2))
	return canvas


# ------------------------------------------------------------------ painting

func _background(size: int, glow_uv: Vector2) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := float(size)
	for y in size:
		for x in size:
			var u := (x + 0.5) / s
			var v := (y + 0.5) / s
			var t := clampf(v * 0.85 + (1.0 - u) * 0.15, 0.0, 1.0)
			var col := BG_TOP.lerp(BG_MID, smoothstep(0.0, 0.55, t)).lerp(BG_BOTTOM, smoothstep(0.45, 1.0, t))
			# Wide soft cyan halo behind the crystal plus a tighter, brighter core.
			var d := Vector2(u - glow_uv.x, (v - glow_uv.y) * 0.9).length()
			col += GLOW_COLOR * (exp(-d * d / 0.06) * 0.26 + exp(-d * d / 0.008) * 0.18)
			# Vignette.
			var vd := Vector2(u - 0.5, v - 0.5).length()
			col = col.darkened(smoothstep(0.42, 0.8, vd) * 0.45)
			col.a = 1.0
			img.set_pixel(x, y, col)
	# A few faint background stars.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 26:
		var p := Vector2(rng.randf(), rng.randf() * 0.55)
		if p.distance_to(glow_uv) < 0.18:
			continue
		_star(img, p * s, s * rng.randf_range(0.004, 0.009), rng.randf_range(0.25, 0.6), true, false)
	return img


func _compose(size: int, crop: Image, k: float, opaque: bool) -> Image:
	var subject := _place(size, crop, k)
	var glow := _bloom(subject)
	var out: Image
	if opaque:
		out = _background(size, _crystal_uv(crop, size, k))
		_add_glow(out, glow, 1.0)
		out.blend_rect(subject, Rect2i(Vector2i.ZERO, subject.get_size()), Vector2i.ZERO)
		_add_glow(out, glow, 0.35)
	else:
		# Transparent layer: the bloom becomes a translucent cyan halo under the subject.
		out = Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var g := glow.get_pixel(x, y).r
				if g > 0.002:
					out.set_pixel(x, y, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, clampf(g * 0.85, 0.0, 1.0)))
		out.blend_rect(subject, Rect2i(Vector2i.ZERO, subject.get_size()), Vector2i.ZERO)
	_sparkles(out, crop, size, k, opaque)
	return out


## Grey-scale bloom built from the cyan, emissive-looking pixels of the placed subject.
func _bloom(subject: Image) -> Image:
	var size := subject.get_width()
	var mask := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var c := subject.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var m := smoothstep(0.18, 0.45, minf(c.g, c.b) - c.r) * smoothstep(0.55, 0.75, c.g) * c.a
			if m > 0.0:
				mask.set_pixel(x, y, Color(m, m, m, 1.0))
	var acc := PackedFloat32Array()
	acc.resize(size * size)
	for level in [[8, 0.9], [20, 0.75], [44, 0.6]]:
		var small := mask.duplicate() as Image
		var w := maxi(2, size / int(level[0]))
		small.resize(w, w, Image.INTERPOLATE_BILINEAR)
		small.resize(size, size, Image.INTERPOLATE_CUBIC)
		var weight: float = level[1]
		for i in size * size:
			acc[i] += small.get_pixel(i % size, i / size).r * weight
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for i in size * size:
		var v := clampf(acc[i] * 1.6, 0.0, 1.0)
		out.set_pixel(i % size, i / size, Color(v, v, v, 1.0))
	return out


func _add_glow(img: Image, glow: Image, strength: float) -> void:
	var size := img.get_width()
	for y in size:
		for x in size:
			var g := glow.get_pixel(x, y).r * strength * 0.55
			if g > 0.001:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(c.r + GLOW_COLOR.r * g, 1.0), minf(c.g + GLOW_COLOR.g * g, 1.0), minf(c.b + GLOW_COLOR.b * g, 1.0), c.a))


## Four-point twinkles around the crystal.
func _sparkles(img: Image, crop: Image, size: int, k: float, opaque: bool) -> void:
	var c := _crystal_uv(crop, size, k) * size
	var unit := crop.get_width() * k
	for sp in [[-0.2, -0.08, 0.05], [0.17, -0.2, 0.036], [0.21, 0.02, 0.026], [-0.1, -0.27, 0.024]]:
		_star(img, c + Vector2(sp[0], sp[1]) * unit, float(sp[2]) * unit, 1.0, opaque, true)


func _star(img: Image, p: Vector2, r: float, strength: float, opaque: bool, cross: bool) -> void:
	var size := img.get_width()
	var sc := Color(0.85, 1.0, 1.0)
	for y in range(maxi(0, floori(p.y - r)), mini(size - 1, ceili(p.y + r)) + 1):
		for x in range(maxi(0, floori(p.x - r)), mini(size - 1, ceili(p.x + r)) + 1):
			var dx := absf(x + 0.5 - p.x) / r
			var dy := absf(y + 0.5 - p.y) / r
			var s := exp(-(dx * dx + dy * dy) * 30.0)
			if cross:
				s = maxf(s, maxf(maxf(0.0, 1.0 - dx) * exp(-dy * dy * 220.0), maxf(0.0, 1.0 - dy) * exp(-dx * dx * 220.0)))
			s *= strength
			if s <= 0.003:
				continue
			var c := img.get_pixel(x, y)
			if opaque:
				c = Color(minf(c.r + sc.r * s, 1.0), minf(c.g + sc.g * s, 1.0), minf(c.b + sc.b * s, 1.0), 1.0)
			else:
				c = Color(lerpf(c.r, sc.r, s), lerpf(c.g, sc.g, s), lerpf(c.b, sc.b, s), maxf(c.a, s))
			img.set_pixel(x, y, c)


func _round_corners(img: Image, radius_frac: float) -> void:
	var size := img.get_width()
	var r := radius_frac * size
	for y in size:
		for x in size:
			var px := x + 0.5
			var py := y + 0.5
			var d := Vector2(px - clampf(px, r, size - r), py - clampf(py, r, size - r)).length()
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a < 1.0:
				var c := img.get_pixel(x, y)
				c.a *= a
				img.set_pixel(x, y, c)


## Themed-icon layer: white, alpha from the subject; darker faces become translucent
## so the island, tower and crystal stay readable as separate shapes.
func _monochrome(subject: Image) -> Image:
	var size := subject.get_width()
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var c := subject.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var lum := c.r * 0.3 + c.g * 0.55 + c.b * 0.15
			out.set_pixel(x, y, Color(1, 1, 1, c.a * lerpf(0.5, 1.0, smoothstep(0.36, 0.46, lum))))
	return out
