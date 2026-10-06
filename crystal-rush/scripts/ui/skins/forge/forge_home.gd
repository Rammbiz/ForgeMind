extends Node
## «Кришталева кузня» home: no menu over a picture - the screen IS the bridge. The hero waits on
## the owner's dais, the crystal gate stands across the bridge with the current level's gem
## in its field (the gate is PLAY), the levels ahead are gems laid on the bridge itself and the
## boss gem burns ember at the far end. 2D chrome is reduced to glass shards and one prism.

const HERO_POS := Vector3(-0.35, 0.0, -5.4)
const GATE_Z := -10.0
const PATH_Z := [-16.5, -25.0, -39.0]

var _cam: Camera3D
var _hero: Node3D
var _machines: Array[Node3D] = []
var _gate: Node3D
var _dais_mat: ShaderMaterial
var _t := 0.0
var _ui: CanvasLayer
var _root: Control


func _ready() -> void:
	var w: Dictionary = Worlds.LIST["space"]
	Models.use_world(w)
	var track := Track.new()
	add_child(track)
	track.build(60.0, true, w)
	var dais := HubShowcase.owner_dais(1.6)
	var hero_y := 0.0
	if not dais.is_empty():
		hero_y = float(dais["depth"])
		var dn: Node3D = dais["node"]
		dn.position = HERO_POS + Vector3(0, dn.position.y + hero_y, 0)
		add_child(dn)
		_dais_mat = dais["mat"]
	_hero = HeroModels.hero("bolt")
	_hero.position = HERO_POS + Vector3(0, hero_y, 0)
	_hero.rotation.y = 0.32
	add_child(_hero)
	var slots := [["mortar", Vector3(1.7, 0, -7.0), PI + 0.5], ["ballista", Vector3(-2.2, 0, -7.9), PI - 0.45]]
	for s: Array in slots:
		var m := WeaponModels.machine(s[0], {"rank": 1, "crew": true})
		HubShowcase.hide_rank_marks(m)
		m.position = s[1]
		m.rotation.y = s[2]
		m.scale = Vector3.ONE * 0.95
		add_child(m)
		_machines.append(m)
	_gate = Models.gate(4.0)
	_gate.position = Vector3(0, 0, GATE_Z)
	add_child(_gate)
	Models.gate_style(_gate, "", "", "good")
	var lbl := _gate.get_meta("label", null) as Label3D
	if lbl:
		lbl.visible = false
	var sub := _gate.get_meta("sub", null) as Label3D
	if sub:
		sub.visible = false
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 40.0
	add_child(_cam)
	_cam.make_current()
	_cam.position = Vector3(0.3, 4.0, 0.2)
	_cam.look_at(Vector3(0.0, -0.35, -10.5))
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)


func _process(delta: float) -> void:
	_t += delta
	if _hero:
		HeroModels.animate_hero(_hero, _t, false, 0.0)
	for i in _machines.size():
		WeaponModels.animate(_machines[i], _t + i * 0.7, 0.0, 0.0)
	if _dais_mat:
		_dais_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 2.2))


func _px(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)


func _build_ui() -> void:
	# Soft void falloff behind the top strip and the bottom chrome so the 3D stays the hero.
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 240), Vector2(0, 240)]),
			PackedColorArray([Color(0.02, 0.02, 0.09, 0.85), Color(0.02, 0.02, 0.09, 0.85), Color(0.02, 0.02, 0.09, 0.0), Color(0.02, 0.02, 0.09, 0.0)]))
		ci.draw_polygon(PackedVector2Array([Vector2(0, 860), Vector2(720, 860), Vector2(720, 1280), Vector2(0, 1280)]),
			PackedColorArray([Color(0.02, 0.02, 0.09, 0.0), Color(0.02, 0.02, 0.09, 0.0), Color(0.02, 0.02, 0.1, 0.92), Color(0.02, 0.02, 0.1, 0.92)])))
	ForgeChrome.top_bar(_root, {"level": "14", "coins": "2 590", "gems": "40"})
	# World title.
	ForgeKit.label(_root, "СВІТ 1 · РІВЕНЬ 14 З 25", "label", 24, Color("8FEAFF"), Rect2(24, 100, 680, 32), HORIZONTAL_ALIGNMENT_LEFT, false)
	ForgeKit.headline(_root, "ОРБІТАЛЬНА ТРАСА", Vector2(22, 130), 52, {"max_w": 676, "font": "display_mid"})
	# The path on the bridge: the levels ahead are gems laid on the bridge beyond the gate,
	# the boss gem burns ember at the far end.
	var path_pts: Array[Vector2] = []
	path_pts.append(_px(Vector3(0, 0.05, GATE_Z)))
	for z: float in PATH_Z:
		path_pts.append(_px(Vector3(0, 0.05, z)))
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		for i in path_pts.size() - 1:
			var a: Vector2 = path_pts[i]
			var b: Vector2 = path_pts[i + 1]
			var segs := 6
			for j in segs:
				var p0 := a.lerp(b, (float(j) + 0.15) / segs)
				var p1 := a.lerp(b, (float(j) + 0.6) / segs)
				ci.draw_line(p0, p1, Color(0.7, 0.95, 1.0, 0.75 - i * 0.18), maxf(1.5, 4.0 - i * 1.0), true)
		var labels := ["15", "16", "17"]
		for i in PATH_Z.size():
			var p: Vector2 = path_pts[i + 1]
			var r := 25.0 - i * 4.0
			var boss := i == PATH_Z.size() - 1
			var c := p + Vector2(0, -r * 0.95)
			# A short light post from the bridge to the gem.
			ci.draw_line(p, c + Vector2(0, r * 0.6), Color(0.7, 0.95, 1.0, 0.5), 2.0, true)
			if boss:
				ForgeKit.draw_glow(ci, ForgeKit.crystal_pts(c, r * 1.8, r * 2.0), Color("FF6A3D"), 1.0, 4, 4.0)
				ForgeKit.draw_gem(ci, c, r, 6, [Color("FFD0B8"), Color("FF6A3D"), Color("8E1F12")], 0.0, 0.62)
				ForgeKit.draw_text_c(ci, labels[i], "num", int(r * 0.85), c, Color.WHITE)
				ForgeKit.draw_text_oc(ci, "БОС", "label", 22, c + Vector2(r + 34, 0), Color("FFB08A"), Color("1A0610"), 6)
			else:
				ForgeKit.draw_gem(ci, c, r, 6, [Color("D6E6F8"), Color("6F8CC0"), Color("2A3A66")], 0.0, 0.62)
				ForgeKit.draw_text_c(ci, labels[i], "num", int(r * 0.85), c, ForgeKit.INK))
	# Vault shard (right): two caches ready.
	var vr := Rect2(488, 228, 216, 92)
	ForgeKit.panel(_root, vr, 404, {"cuts": {0: Vector2(26, 12), 2: Vector2(14, 30)}, "tint_k": 0.8, "cleave": false, "facets": false})
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		ForgeIcons.draw(ci, "geode", Rect2(vr.position.x + 8, vr.position.y + 10, 70, 70))
		ForgeKit.draw_text_l(ci, "Сховище", "bold", 26, Vector2(vr.position.x + 84, vr.position.y + 32), ForgeKit.TEXT)
		ForgeKit.draw_text_l(ci, "2 готові", "bold", 26, Vector2(vr.position.x + 84, vr.position.y + 63), Color("C9A8FF"))
		ForgeKit.draw_gem(ci, Vector2(vr.end.x - 8, vr.position.y + 2), 16.0, 4, [Color("FFC7A8"), Color("FF6A3D"), Color("9C2410")], PI / 4.0, 0.62)
		ForgeKit.draw_text_c(ci, "2", "num", 20, Vector2(vr.end.x - 8, vr.position.y + 2), Color.WHITE))
	# Hero tag: a small glass shard floating beside the hero, a hairline leader to the dais.
	var anchor := _px(HERO_POS + Vector3(-0.3, 1.25, 0))
	var hr := Rect2(16, anchor.y - 190, 250, 92)
	ForgeKit.panel(_root, hr, 405, {"cuts": {1: Vector2(30, 14), 3: Vector2(12, 26)}, "tint_k": 0.82, "cleave": false, "facets": false})
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		var from := Vector2(hr.position.x + 150, hr.end.y + 2)
		ci.draw_line(from, anchor, Color(0.75, 0.95, 1.0, 0.7), 1.5, true)
		ci.draw_colored_polygon(PackedVector2Array([anchor + Vector2(0, -5), anchor + Vector2(4, 0), anchor + Vector2(0, 5), anchor + Vector2(-4, 0)]), Color("E9FBFF"))
		ForgeIcons.draw(ci, "fox", Rect2(hr.position.x + 10, hr.position.y + 14, 64, 64))
		ForgeKit.draw_text_l(ci, "Блискавка", "bold", 30, Vector2(hr.position.x + 84, hr.position.y + 32), ForgeKit.TEXT)
		ForgeKit.draw_text_l(ci, "Рів. 5 · лис", "body", 26, Vector2(hr.position.x + 84, hr.position.y + 66), ForgeKit.DIM))
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		ForgeKit.draw_text_oc(ci, "КОЛОДА", "label", 22, Vector2(78, 924), ForgeKit.RIM, Color("05061A"), 6)
		ForgeKit.draw_text_oc(ci, "3/3", "num", 26, Vector2(78, 954), ForgeKit.DIM, Color("05061A"), 6))
	var ids := ["mortar", "ballista", "drone"]
	var lv := ["6", "5", "6"]
	for i in 3:
		var c := Vector2(206 + i * 108, 930)
		var id: String = ids[i]
		var lvl: String = lv[i]
		ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
			var cp := ForgeKit.shard(Rect2(c.x - 46, c.y - 40, 92, 78), 700 + i, {"min_cut": 12, "max_cut": 22, "skew": 0.0})
			ForgeKit.draw_prism(ci, cp, ForgeKit.PRISMS["glass"], 6.0, 0.0, 0.0, false)
			ForgeKit.draw_chamfers(ci, cp, 5.0, 0.8)
			var tex := MachineThumbs.get_thumb(_root, id, false)
			if tex:
				ci.draw_texture_rect(tex, Rect2(c.x - 46, c.y - 48, 92, 92), false)
			ForgeKit.draw_level_gem(ci, c + Vector2(36, 30), 16.0, lvl))
	# PLAY prism: [level gem] ГРАТИ, and a faceted double chevron (the dash) at the far end.
	var pr := Rect2(30, 992, 660, 106)
	var pp := ForgeKit.shard(pr, 999, {"cuts": {0: Vector2(64, 24), 2: Vector2(28, 62)}, "skew": 2.5, "skew_edge": "bottom", "skew_right": false})
	ForgeKit.canvas(_root, func(ci: CanvasItem) -> void:
		var top := ForgeKit.draw_prism(ci, pp, ForgeKit.PRISMS["primary"], 12.0, 0.0, 1.4)
		var r := ForgeKit.bounds(top)
		var cy := r.position.y + 50.0
		ForgeKit.draw_level_gem(ci, Vector2(r.position.x + 104, cy), 40.0, "14", [Color("4FA6F0"), Color("1A5FB8"), Color("0A2A66")], Color.WHITE)
		var tw := ForgeKit.draw_text_l(ci, "ГРАТИ", "display", 58, Vector2(r.position.x + 166, cy - 6), ForgeKit.INK)
		ForgeKit.draw_text_l(ci, "3 рівні до боса · ворота ×2", "bold", 26, Vector2(r.position.x + 170, cy + 34), Color(0.04, 0.1, 0.26, 0.72))
		var ax := maxf(r.position.x + 166 + tw + 30.0, r.end.x - 100.0)
		for k in 2:
			var x0 := ax + k * 30.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, cy - 26), Vector2(x0 + 26, cy), Vector2(x0 + 12, cy), Vector2(x0 - 14, cy - 26)]), Color("1A5FB8").lerp(Color("0A1736"), k * 0.4))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 12, cy), Vector2(x0 + 26, cy), Vector2(x0, cy + 26), Vector2(x0 - 14, cy + 26)]), Color("0F3D85").lerp(Color("0A1736"), k * 0.4)))
	ForgeChrome.nav(_root, "gate", {"arsenal": 2, "vault": 2})


func prepared() -> void:
	for i in 3:
		await get_tree().process_frame
	_build_ui()
	for id in ["mortar", "ballista", "drone"]:
		MachineThumbs.get_thumb(_root, id, false)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
	for c in _root.get_children():
		if c is CanvasItem:
			(c as CanvasItem).queue_redraw()
	for i in 4:
		await get_tree().process_frame
