extends CanvasLayer
## «Емаль і золото» reward modal (after a won level), over the dimmed Arsenal. The panel is a
## big enamel plate that HANGS from a gold rail on two rods (the kit's signature mount);
## ПЕРЕМОГА is set in Oi like poured enamel; rewards sit in a sunk tray, counted on odometer
## rollers; the machine whose blueprints were won shows in its rarity-rimmed window.
## Primary: the ice launch-key (double for an ad), secondary: a white enamel key.

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")
const I := preload("res://scripts/ui/skins/enamel/enamel_icons.gd")
const C := preload("res://scripts/ui/skins/enamel/enamel_chrome.gd")
const ARSENAL := preload("res://scripts/ui/skins/enamel/enamel_arsenal.gd")

var _under: CanvasLayer
var _layer: CanvasLayer
var _root: Control


func _ready() -> void:
	_under = ARSENAL.new()
	add_child(_under)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)


func _build() -> void:
	K.canvas(_root, func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.02, 0.08, 0.78)))
	var pr := Rect2(28, 236, 664, 820)
	# The rail and the two rods it hangs from.
	K.canvas(_root, func(ci: CanvasItem) -> void:
		for x in [pr.position.x + 120.0, pr.end.x - 120.0]:
			var rod := Rect2(x - 5.0, 150.0, 10.0, pr.position.y - 150.0 + 14.0)
			ci.draw_rect(Rect2(rod.position + Vector2(3, 0), rod.size), Color(0, 0, 0.05, 0.4))
			ci.draw_polygon(PackedVector2Array([rod.position, Vector2(rod.end.x, rod.position.y), rod.end, Vector2(rod.position.x, rod.end.y)]),
				PackedColorArray([K.GOLD_LIGHT, K.GOLD_DARK, K.GOLD_DARK, K.GOLD_LIGHT]))
		K.rail(ci, Vector2(0, 150), Vector2(720, 150), 14.0, false)
		for x in [pr.position.x + 120.0, pr.end.x - 120.0]:
			K.rivet(ci, Vector2(x, 150), 6.0))
	K.plate(_root, pr, {"ch": 40.0, "rad": 12.0, "trim": 5.0, "inset": 5.0, "rivet": 6.0, "rivet_every": 150.0, "shadow": 0.8, "shadow_off": Vector2(0, 14), "spec": 0.6, "edge": 10.0})
	var cx := pr.get_center().x
	# Header: ПЕРЕМОГА in Oi, the level beneath.
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var s := K.fit_size("ПЕРЕМОГА!", "logo", 76, pr.size.x - 96.0, 56)
		K.text_c(ci, "ПЕРЕМОГА!", "logo", s, Vector2(cx, pr.position.y + 82.0), K.INK)
		K.text_c(ci, "Рівень 14 · Орбітальна траса", "bold", 28, Vector2(cx, pr.position.y + 142.0), K.INK_DIM)
		K.glint(ci, Vector2(pr.position.x + 92.0, pr.position.y + 56.0), 16.0)
		K.glint(ci, Vector2(pr.end.x - 64.0, pr.position.y + 108.0), 10.0))
	# Reward tray: three sunk slots.
	var tr := Rect2(pr.position.x + 30.0, pr.position.y + 176.0, pr.size.x - 60.0, 132.0)
	K.plate(_root, tr, {"mat": "tray", "recess": true, "ch": 18.0, "trim": 0.0, "shadow": 0.0, "outline_w": 0.0, "pad": 6.0})
	var slots := [["coin", "240", "монети"], ["crystal", "5", "кристали"], ["crest", "1", "корона"]]
	var sw := (tr.size.x - 24.0 - 16.0) / 3.0
	for i in 3:
		var sr := Rect2(tr.position.x + 12.0 + i * (sw + 8.0), tr.position.y + 12.0, sw, tr.size.y - 24.0)
		K.plate(_root, sr, {"ch": 12.0, "trim": 0.0, "shadow": 0.45, "pad": 12.0, "spec": 0.5})
		var d: Array = slots[i]
		K.canvas(_root, func(ci: CanvasItem) -> void:
			var c := sr.get_center()
			I.draw(ci, d[0], Rect2(sr.position.x + 12.0, c.y - 40.0, 48, 48))
			K.text_l(ci, "+", "num", 28, Vector2(sr.position.x + 66.0, c.y - 16.0), K.INK)
			K.odometer(ci, d[1], 28, Vector2(sr.position.x + 88.0, c.y - 16.0))
			K.text_c(ci, d[2], "bold", 26, Vector2(c.x, c.y + 32.0), K.INK_DIM))
	# The machine: window + blueprints won.
	var mr := Rect2(pr.position.x + 30.0, pr.position.y + 330.0, pr.size.x - 60.0, 206.0)
	var rar: Array = K.RARITY["R"]
	K.plate(_root, mr, {"mat": "window", "recess": true, "ch": 22.0, "rad": 6.0, "trim": 4.0, "inset": 1.0, "trim_cols": [Color(rar[2]).darkened(0.2), rar[1], rar[0]], "shadow": 0.0, "outline_w": 0.0, "pad": 6.0})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var wc := Vector2(mr.position.x + 146.0, mr.get_center().y + 10.0)
		for k in 7:
			var t := 1.0 - k / 7.0
			ci.draw_circle(wc, 30.0 + k * 13.0, Color(rar[1], 0.07 * t + 0.02), true, -1.0, true)
		ci.draw_set_transform(wc + Vector2(0, 58), 0.0, Vector2(1.0, 0.22))
		ci.draw_circle(Vector2.ZERO, 100.0, Color(rar[0], 0.2), true, -1.0, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tex := MachineThumbs.get_thumb(_root, "mortar", false)
		if tex:
			ci.draw_texture_rect(tex, Rect2(wc.x - 128.0, mr.end.y - 230.0, 256, 256), false)
		var x := mr.position.x + 286.0
		K.draw_inlay(ci, Vector2(mr.end.x - 30.0, mr.position.y + 34.0), Vector2(26, 40), [rar[0], rar[1], rar[2]])
		K.text_l(ci, "Креслення", "caps", 26, Vector2(x, mr.position.y + 40.0), K.ICE, "plain")
		K.text_l(ci, "Облогова", "display", 30, Vector2(x, mr.position.y + 82.0), K.ENAMEL, "plain")
		K.text_l(ci, "мортира", "display", 30, Vector2(x, mr.position.y + 118.0), K.ENAMEL, "plain")
		var w := K.text_l(ci, "+3", "num", 30, Vector2(x, mr.position.y + 164.0), K.ICE, "plain")
		K.text_l(ci, "· 8/8 готово!", "bold", 26, Vector2(x + w + 8.0, mr.position.y + 164.0), Color("C9D2F0"), "plain"))
	# Keys.
	var kr := Rect2(pr.position.x + 30.0, pr.position.y + 566.0, pr.size.x - 60.0, 112.0)
	var gr := kr.grow(8.0)
	K.plate(_root, gr, {"mat": "gold", "ch": 28.0, "rad": 9.0, "trim": 0.0, "shadow": 0.5, "rivet": 4.5, "spec": 0.7, "bevel_w": 5.0, "bevel": 0.3})
	K.plate(_root, kr.grow(1.0), {"mat": "window", "recess": true, "ch": 22.0, "rad": 7.0, "trim": 0.0, "shadow": 0.0, "outline_w": 0.0, "pad": 4.0})
	var inner := Rect2(kr.position.x + 5.0, kr.position.y + 4.0, kr.size.x - 10.0, kr.size.y - 8.0)
	K.key(_root, inner, "ЗАБРАТИ ×2", {"mat": "ice", "depth": 14.0, "ch": 20.0, "rad": 7.0, "size": 44, "sub": "переглянути рекламу",
		"shadow": 0.4, "spec": 0.75, "bevel_w": 9.0, "bevel": 0.28,
		"icon": func(ci: CanvasItem, fr: Rect2) -> float:
			I.draw(ci, "ad", Rect2(fr.position.x + 28.0, fr.get_center().y - 26.0, 56, 52), K.WHITE, Color("3FB0F4"), "raised")
			return fr.position.x + 92.0})
	K.key(_root, Rect2(pr.position.x + 120.0, pr.position.y + 704.0, pr.size.x - 240.0, 80.0), "", {"depth": 10.0, "size": 30,
		"icon": func(ci: CanvasItem, fr: Rect2) -> float:
			var w1 := K.text_w("Забрати", "display", 30)
			var w2 := K.text_w("240", "num", 30)
			var x := fr.get_center().x - (w1 + 12.0 + 34.0 + 8.0 + w2) * 0.5
			var cy := fr.get_center().y
			K.text_l(ci, "Забрати", "display", 30, Vector2(x, cy), K.INK)
			I.draw(ci, "coin", Rect2(x + w1 + 12.0, cy - 17.0, 34, 34))
			K.text_l(ci, "240", "num", 30, Vector2(x + w1 + 54.0, cy), K.INK)
			return fr.end.x})


func prepared() -> void:
	await _under.prepared()
	_build()
	MachineThumbs.get_thumb(_root, "mortar", false)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await get_tree().process_frame
	for c in _root.get_children():
		if c is CanvasItem:
			(c as CanvasItem).queue_redraw()
	for i in 4:
		await get_tree().process_frame
