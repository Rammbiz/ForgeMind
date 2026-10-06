extends Node
## «Емаль і золото» home. The hero is a collectible die-cast figure standing on a white-enamel
## KIT STAND (gold band, ice inlay ring, rivets) on the crystal bridge, with its enamel name
## label fixed to the front of the stand. Above: the riveted gold nameplate rail and the
## world's hanging title plate. Below: the level path as a toy RAIL TRACK (stations are enamel
## tokens; the boss is a red-enamel fortress token), the big ice-enamel LAUNCH KEY in its gold
## guard frame, and the navy kit tray of plate-keys.

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")
const I := preload("res://scripts/ui/skins/enamel/enamel_icons.gd")
const C := preload("res://scripts/ui/skins/enamel/enamel_chrome.gd")

const HERO_POS := Vector3(0.0, 0.0, -5.6)
const STAND_H := 0.42

var _cam: Camera3D
var _hero: Node3D
var _machines: Array[Node3D] = []
var _t := 0.0
var _ui: CanvasLayer
var _root: Control


func _ready() -> void:
	var w: Dictionary = Worlds.LIST["space"]
	Models.use_world(w)
	var track := Track.new()
	add_child(track)
	track.build(60.0, true, w)
	add_child(_stand(HERO_POS))
	_hero = HeroModels.hero("bolt")
	_hero.position = HERO_POS + Vector3(0, STAND_H, 0)
	_hero.rotation.y = 0.28
	_hero.scale = Vector3.ONE * 1.12
	add_child(_hero)
	var slots := [["mortar", Vector3(1.75, 0, -7.6), PI + 0.6], ["ballista", Vector3(-1.85, 0, -8.0), PI - 0.55]]
	for s: Array in slots:
		var m := WeaponModels.machine(s[0], {"rank": 1, "crew": true})
		HubShowcase.hide_rank_marks(m)
		m.position = s[1]
		m.rotation.y = s[2]
		m.scale = Vector3.ONE * 0.95
		add_child(m)
		_machines.append(m)
	var gate := Models.gate(4.0)
	gate.position = Vector3(0, 0, -15.0)
	add_child(gate)
	Models.gate_style(gate, "", "", "good")
	for k in ["label", "sub"]:
		var lbl := gate.get_meta(k, null) as Label3D
		if lbl:
			lbl.visible = false
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 38.0
	add_child(_cam)
	_cam.make_current()
	_cam.position = Vector3(0.0, 2.3, -2.4)
	_cam.look_at(Vector3(0.0, -0.54, -9.0))
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)


## The kit stand: navy plinth with a gold band, a white enamel disc with riveted side and
## an ice inlay ring that glows.
func _stand(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color("F4F1EA")
	enamel.roughness = 0.22
	enamel.metallic_specular = 0.8
	var navy := StandardMaterial3D.new()
	navy.albedo_color = Color("1E2656")
	navy.roughness = 0.3
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("E2B04A")
	gold.metallic = 1.0
	gold.roughness = 0.28
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color("8FEAFF")
	ice.emission_enabled = true
	ice.emission = Color("8FEAFF")
	ice.emission_energy_multiplier = 2.2
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.22
	pm.bottom_radius = 1.3
	pm.height = 0.16
	pm.radial_segments = 64
	plinth.mesh = pm
	plinth.material_override = navy
	plinth.position.y = 0.08
	root.add_child(plinth)
	var band := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 1.2
	bm.outer_radius = 1.29
	bm.rings = 64
	band.mesh = bm
	band.material_override = gold
	band.position.y = 0.16
	root.add_child(band)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.02
	dm.bottom_radius = 1.08
	dm.height = 0.26
	dm.radial_segments = 64
	disc.mesh = dm
	disc.material_override = enamel
	disc.position.y = 0.16 + 0.13
	root.add_child(disc)
	var lip := MeshInstance3D.new()
	var lm := TorusMesh.new()
	lm.inner_radius = 0.98
	lm.outer_radius = 1.05
	lm.rings = 64
	lip.mesh = lm
	lip.material_override = gold
	lip.position.y = STAND_H
	root.add_child(lip)
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.7
	rm.outer_radius = 0.76
	rm.rings = 64
	ring.mesh = rm
	ring.material_override = ice
	ring.position.y = STAND_H - 0.012
	ring.scale = Vector3(1, 0.35, 1)
	root.add_child(ring)
	for i in 12:
		var a := TAU * i / 12.0
		var rv := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		rv.mesh = sm
		rv.material_override = gold
		rv.position = Vector3(cos(a) * 1.06, 0.29, sin(a) * 1.06)
		root.add_child(rv)
	return root


func _process(delta: float) -> void:
	_t += delta
	if _hero:
		HeroModels.animate_hero(_hero, _t, false, 0.0)
	for i in _machines.size():
		WeaponModels.animate(_machines[i], _t + i * 0.7, 0.0, 0.0)


func _px(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)


func _build_ui() -> void:
	# Quiet the space under the chrome so the white plates sit on dark.
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var top := Color(0.03, 0.03, 0.1, 0.8)
		var clear := Color(0.03, 0.03, 0.1, 0.0)
		ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, 250), Vector2(0, 250)]), PackedColorArray([top, top, clear, clear]))
		var bot := Color(0.03, 0.03, 0.1, 0.9)
		ci.draw_polygon(PackedVector2Array([Vector2(0, 820), Vector2(720, 820), Vector2(720, 900), Vector2(0, 900)]), PackedColorArray([clear, clear, bot, bot]))
		ci.draw_rect(Rect2(0, 900, 720, 380), bot))
	C.top_bar(_root, {"level": "14", "coins": "2 590", "gems": "40", "crowns": "26"})
	# The world's title plate hangs from the rail on two gold rods.
	var tp := C.nameplate(_root, Vector2(16, 150), "Орбітальна траса", "СВІТ 1 · РІВЕНЬ 14 / 25", {"size": 44, "h": 78.0})
	# Vault plate (right): a geode cache ready to open.
	var vr := Rect2(480, 262, 224, 76)
	K.plate(_root, vr, {"ch": 12.0, "trim": 3.0, "shadow": 0.55, "rivet": 3.4})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		I.draw(ci, "geode", Rect2(vr.position.x + 14.0, vr.position.y + 13.0, 50, 50), K.INK, Color("F1EDE4"))
		K.text_l(ci, "Сховище", "display", 26, Vector2(vr.position.x + 74.0, vr.position.y + 26.0), K.INK)
		K.text_l(ci, "2 готові", "bold", 26, Vector2(vr.position.x + 74.0, vr.position.y + 54.0), Color("6A2FC8"))
		K.stud(ci, Vector2(vr.end.x - 4.0, vr.position.y + 2.0), "2", 16.0))
	# The figure's label plate, screwed to the front of the stand.
	var front := _px(HERO_POS + Vector3(0, 0.2, 1.1))
	var lw := 300.0
	var lr := Rect2(front.x - lw * 0.5, minf(front.y - 30.0, 788.0), lw, 74)
	K.plate(_root, lr, {"ch": 12.0, "trim": 3.0, "rivet": 3.6, "shadow": 0.6})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		K.text_c(ci, "Блискавка", "display", 30, Vector2(lr.get_center().x, lr.position.y + 25.0), K.INK)
		K.text_c(ci, "Громовий лис · рів. 5", "bold", 26, Vector2(lr.get_center().x, lr.position.y + 53.0), K.INK_DIM))
	_track(Rect2(0, 866, 720, 80))
	_launch_key(Rect2(40, 978, 640, 120))
	C.nav(_root, "play", {"arsenal": "2", "shop": "1"})


## Level path as a toy rail track: gold rails on navy ties, enamel station tokens.
func _track(r: Rect2) -> void:
	var cy := r.get_center().y
	var xs: Array[float] = [58.0, 160.0, 284.0, 410.0, 520.0, 642.0]
	var labels := ["12", "13", "14", "15", "16", "17"]
	K.canvas(_root, func(ci: CanvasItem) -> void:
		# ties
		var x := 6.0
		while x < 716.0:
			var done := x < xs[2]
			ci.draw_rect(Rect2(x, cy - 15.0, 9.0, 30.0), Color("0E1232") if done else Color(0.06, 0.07, 0.18, 0.85))
			ci.draw_rect(Rect2(x, cy - 15.0, 9.0, 3.0), Color(1, 1, 1, 0.12))
			x += 22.0
		# rails: bright gold behind the hero's progress, darker gold ahead
		for dy in [-9.0, 9.0]:
			var a := Rect2(0, cy + dy - 3.0, xs[2], 6.0)
			var b := Rect2(xs[2], cy + dy - 3.0, 720.0 - xs[2], 6.0)
			ci.draw_rect(Rect2(a.position + Vector2(0, 2), a.size), Color(0, 0, 0.05, 0.5))
			K.vgrad(ci, a, [K.GOLD_LIGHT, K.GOLD, K.GOLD_DARK])
			ci.draw_rect(Rect2(b.position + Vector2(0, 2), b.size), Color(0, 0, 0.05, 0.5))
			K.vgrad(ci, b, [Color("B9A57A"), Color("8A7448"), Color("4E3E1C")]))
	for i in xs.size():
		var c := Vector2(xs[i], cy)
		var cur := i == 2
		var done := i < 2
		var boss := i == xs.size() - 1
		var machine := i == 4
		var sz := 92.0 if cur else (74.0 if boss else 62.0)
		var depth := 9.0 if cur else 6.0
		var tr := Rect2(c.x - sz * 0.5, c.y - sz * 0.5 - depth * 0.5, sz, sz + depth)
		var mat := "ice" if cur else ("red" if boss else ("enamel" if not done else "enamel"))
		K.plate(_root, tr, {"mat": mat, "depth": depth, "ch": 14.0 if sz > 70.0 else 10.0, "rad": 5.0, "trim": 3.0 if (cur or boss) else 0.0,
			"shadow": 0.6, "pad": 18.0, "glow": Color(0.56, 0.92, 1.0, 0.45) if cur else Color(0, 0, 0, 0), "glow_r": 9.0,
			"rivet": 3.2 if cur else 0.0, "spec": 0.5})
		var fr := K.face_of(tr, depth)
		var lbl: String = labels[i]
		K.canvas(_root, func(ci: CanvasItem) -> void:
			var fc := fr.get_center()
			if cur:
				K.text_c(ci, lbl, "num", 40, fc + Vector2(0, 1), K.WHITE, "raised")
			elif boss:
				I.draw(ci, "horns", Rect2(fc - Vector2(19, 26), Vector2(38, 34)), K.WHITE, K.RED, "raised")
				K.text_c(ci, lbl, "num", 22, fc + Vector2(0, 21), K.WHITE, "raised")
			elif machine:
				I.draw(ci, "cannon", Rect2(fc - Vector2(17, 22), Vector2(34, 30)), K.INK, Color("F1EDE4"))
				K.text_c(ci, lbl, "num", 20, fc + Vector2(0, 17), K.INK)
			else:
				K.text_c(ci, lbl, "num", 28, fc + Vector2(0, 1), K.INK if not done else K.INK_DIM)
			if done:
				var cc := Vector2(fr.end.x - 4.0, fr.position.y + 4.0)
				ci.draw_circle(cc, 13.0, Color("0E1232"), true, -1.0, true)
				ci.draw_circle(cc, 11.5, Color("2E8F5A"), true, -1.0, true)
				I.draw(ci, "check", Rect2(cc - Vector2(8, 8), Vector2(16, 16)), K.WHITE, K.WHITE, "plain"))
	K.canvas(_root, func(ci: CanvasItem) -> void:
		K.text_c(ci, "БОС", "caps", 22, Vector2(xs[5], cy - 64.0), Color("FFB4A8"), "shadow")
		K.text_c(ci, "нова машина", "bold", 22, Vector2(xs[4], cy - 58.0), K.ICE, "shadow"))


## The launch key: ice enamel with a deep skirt, set inside a riveted gold guard frame.
func _launch_key(r: Rect2) -> void:
	# Guard frame: a gold plate slightly larger than the key, the key sits in its window.
	var gr := r.grow(10.0)
	gr.size.y += 4.0
	K.plate(_root, gr, {"mat": "gold", "ch": 30.0, "rad": 10.0, "trim": 0.0, "shadow": 0.7, "rivet": 5.0, "spec": 0.7, "bevel_w": 6.0, "bevel": 0.3})
	var wr := r.grow(1.0)
	K.plate(_root, wr, {"mat": "window", "recess": true, "ch": 24.0, "rad": 8.0, "trim": 0.0, "shadow": 0.0, "outline_w": 0.0, "pad": 4.0})
	var depth := 16.0
	var kr := Rect2(r.position.x + 6.0, r.position.y + 4.0, r.size.x - 12.0, r.size.y - 8.0)
	K.plate(_root, kr, {"mat": "ice", "depth": depth, "ch": 22.0, "rad": 7.0, "trim": 0.0, "shadow": 0.5, "spec": 0.75, "bevel_w": 9.0, "bevel": 0.28})
	var fr := K.face_of(kr, depth)
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var cy := fr.get_center().y
		K.draw_inlay(ci, Vector2(fr.position.x + 62.0, cy), Vector2(52, 74), [K.ICE_WHITE, Color("BDF3FF"), Color("1A6FC0")])
		var x0 := fr.position.x + 108.0
		var x1 := fr.end.x - 24.0
		var tw := K.text_l(ci, "ГРАТИ", "display", 58, Vector2(x0, cy - 14.0), K.WHITE, "raised")
		# gold underline under the word
		var ul := Rect2(x0 + 2.0, cy + 18.0, tw - 4.0, 4.0)
		K.vgrad(ci, ul, [K.GOLD_LIGHT, K.GOLD, K.GOLD_DARK])
		K.text_l(ci, "Рівень 14 · ще 3 до боса", "bold", 26, Vector2(x0, cy + 40.0), Color("E9FBFF"), "raised")
		# ×2 gate badge on the right: the gate reward of this level, in Oi.
		var bc := Vector2(x1 - 58.0, cy - 2.0)
		K.text_c(ci, "×2", "logo", 56, bc, K.WHITE, "raised")
		K.text_c(ci, "брама", "bold", 22, bc + Vector2(0, 38.0), Color("E9FBFF"), "raised"))


func prepared() -> void:
	for i in 3:
		await get_tree().process_frame
	_build_ui()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
	for i in 4:
		await get_tree().process_frame
