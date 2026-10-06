extends Node
## «Кришталева кузня» level-up modal over the Arsenal: the machine stands on the owner's
## amethyst rune altar (the forge) and breaks out of the top of a big glass shard; the new
## level is cut in crystal type, stats show old -> new, one talent unlocks, and the two prisms
## (amethyst "again", ice "great") close it.

var _under: CanvasLayer
var _layer: CanvasLayer
var _root: Control
var _vp: SubViewport
var _altar: Node3D
var _machine: Node3D
var _t := 0.0


func _ready() -> void:
	_under = (load("res://scripts/ui/skins/forge/forge_arsenal.gd") as GDScript).new()
	add_child(_under)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	_build_stage()


func _process(delta: float) -> void:
	_t += delta
	if _altar:
		CacheModels.animate(_altar, _t)
	if _machine:
		_machine.rotation.y = PI - 0.75 + sin(_t * 0.5) * 0.08
		WeaponModels.animate(_machine, _t, 0.0, 0.0)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(680, 600)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 1.0)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.96, 0.9)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 160, 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.7, 0.5, 1.0)
	_vp.add_child(rim)
	_altar = CacheModels.altar()
	_vp.add_child(_altar)
	CacheModels.altar_light(_altar, 1.0, Color(0.68, 0.42, 1.0))
	var socket := _altar.get_meta("socket", null) as Node3D
	var top := socket.position.y if socket else 0.7
	_machine = WeaponModels.machine("mortar", {"rank": 1, "crew": true})
	HubShowcase.hide_rank_marks(_machine)
	_machine.position = Vector3(0, top + 0.02, 0)
	_machine.scale = Vector3.ONE * 1.55
	_vp.add_child(_machine)
	# The forge beam: a soft additive light column rising off the altar.
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.1
	cm.height = 3.2
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	var sh := Shader.new()
	sh.code = HubShowcase.BEAM_SHADER
	var bm := ShaderMaterial.new()
	bm.shader = sh
	bm.set_shader_parameter("color", Color(0.62, 0.86, 1.0))
	bm.set_shader_parameter("strength", 0.5)
	beam.material_override = bm
	beam.position = Vector3(0, top + 1.5, 0)
	_vp.add_child(beam)
	var cam := Camera3D.new()
	cam.fov = 31.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, top + 1.9, 9.6), Vector3(0, top + 0.75, 0))


func _build_ui() -> void:
	# Frosted veil over the Arsenal: the glass shader, full screen, heavier tint.
	var veil := PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 1280), Vector2(0, 1280)])
	ForgeKit.add_glass(_root, veil, {"tint": Color("05041A"), "tint_top": Color("170C3A"), "tint_k": 0.72, "streak_k": 0.0})
	# The big shard.
	var pr := Rect2(28, 388, 664, 760)
	ForgeKit.panel(_root, pr, 8801, {"cuts": {0: Vector2(96, 40), 2: Vector2(36, 92)}, "skew": 2.0, "skew_edge": "bottom", "tint_k": 0.88, "chamfer": 12.0})
	# Rune halo behind the altar (amethyst facets), then the 3D stage breaking out of the top.
	var stage_c := Vector2(360, 300)
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		var core := PackedVector2Array()
		for k in 24:
			var a := TAU * float(k) / 24.0
			core.append(stage_c + Vector2(cos(a), sin(a)) * 210.0)
		ci.draw_polygon(core, PackedColorArray(Array(range(24)).map(func(_k: int) -> Color: return Color(0.55, 0.35, 1.0, 0.0))))
		for ring in 6:
			var rad := 40.0 + ring * 34.0
			var cc := PackedVector2Array()
			for k in 24:
				var a := TAU * float(k) / 24.0
				cc.append(stage_c + Vector2(cos(a), sin(a)) * rad)
			ci.draw_colored_polygon(cc, Color(0.6, 0.42, 1.0, 0.05))
		for k in 18:
			var a0 := TAU * float(k) / 18.0
			var a1 := TAU * float(k + 1) / 18.0
			var rr := 300.0 if k % 2 == 0 else 220.0
			var c := Color(0.66, 0.44, 1.0, 0.2) if k % 2 == 0 else Color(0.5, 0.85, 1.0, 0.1)
			ci.draw_colored_polygon(PackedVector2Array([stage_c, stage_c + Vector2(cos(a0), sin(a0)) * rr, stage_c + Vector2(cos(a1), sin(a1)) * rr * 0.9]), c))
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.position = Vector2(20, 18)
	tr.size = Vector2(680, 600)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tr)
	# Title.
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		ForgeKit.draw_text_c(ci, "ПОКРАЩЕННЯ ЗАВЕРШЕНО", "label", 24, Vector2(360, 596), Color("C9A8FF")))
	var h := ForgeKit.headline(_root, "РІВЕНЬ 7", Vector2(360, 614), 76, {"align": 1, "max_w": 560})
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		ForgeKit.draw_text_c(ci, "Облогова мортира стала сильнішою", "bold", 30, Vector2(360, 724), ForgeKit.TEXT, 600.0)
		# Stat rows: icon, name, old -> new, gain.
		var rows := [["sword", "Шкода за удар", "6,4", "6,8", "+0,37"], ["bolt", "Шкода за секунду", "2,9", "3,1", "+0,17"], ["range", "Радіус вибуху", "1,6", "1,7", "+0,1"]]
		var y := 778.0
		for i in rows.size():
			var row: Array = rows[i]
			var rr := Rect2(60, y - 26, 600, 52)
			var rp := ForgeKit.shard(rr, 8900 + i, {"cuts": {0: Vector2(14, 8), 2: Vector2(8, 14)}, "skew": 0.0})
			ci.draw_colored_polygon(rp, Color(0.6, 0.85, 1.0, 0.05 if i % 2 == 0 else 0.0))
			ForgeIcons.draw(ci, row[0], Rect2(70, y - 21, 42, 42))
			ForgeKit.draw_text_l(ci, row[1], "body", 27, Vector2(124, y), Color("C9D8F0"))
			var x := 640.0
			x -= ForgeKit.draw_text_r(ci, row[4], "num", 28, Vector2(x, y), Color("7FE3FF")) + 18.0
			x -= ForgeKit.draw_text_r(ci, row[3], "num", 30, Vector2(x, y), Color.WHITE) + 10.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y - 8), Vector2(x - 2, y), Vector2(x - 14, y + 8)]), Color("8FEAFF"))
			x -= 22.0
			ForgeKit.draw_text_r(ci, row[2], "num", 26, Vector2(x, y), ForgeKit.DIM)
			y += 58.0
		# Unlocked talent: an amethyst shard row.
		var ur := Rect2(60, 948, 600, 84)
		var up := ForgeKit.shard(ur, 8950, {"cuts": {1: Vector2(26, 12), 3: Vector2(12, 26)}, "skew": 0.0})
		ci.draw_colored_polygon(up, Color(0.36, 0.16, 0.7, 0.42))
		ForgeKit.draw_chamfers(ci, up, 6.0, 0.8)
		ForgeKit.draw_rim(ci, up, Color("D9C2FF"), Color("05061A"), 2.0, 0.0)
		ForgeKit.draw_gem(ci, Vector2(104, 990), 26.0, 3, [Color("E2CCFF"), Color("A66BFF"), Color("5A26B8")], 0.0, 0.55)
		ForgeKit.draw_text_l(ci, "НОВИЙ ТАЛАНТ", "label", 22, Vector2(146, 972), Color("D9C2FF"))
		ForgeKit.draw_text_l(ci, "Уламкові снаряди: +2 осколки", "bold", 28, Vector2(146, 1008), Color.WHITE)
		# Buttons.
		var sp := ForgeKit.shard(Rect2(56, 1060, 268, 70), 8960, {"cuts": {0: Vector2(22, 10), 2: Vector2(10, 24)}, "skew": 0.0})
		ForgeKit.draw_button(ci, sp, "secondary", "ЩЕ · 620", {"size": 26, "icon": "coin", "icon_px": 32})
		var pp := ForgeKit.shard(Rect2(344, 1052, 322, 80), 8961, {"cuts": {0: Vector2(30, 12), 2: Vector2(14, 34)}, "skew": 0.0})
		ForgeKit.draw_button(ci, pp, "primary", "ЧУДОВО", {"size": 32, "glow": 1.0, "depth": 10.0}))


func prepared() -> void:
	await _under.prepared()
	_build_ui()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		await get_tree().process_frame
