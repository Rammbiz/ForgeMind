extends CanvasLayer
## «Емаль і золото» Arsenal: every machine is a die-cast DATA PLATE - white enamel, gold trim,
## two screws at the cut corners, the real machine render inside a sunk navy WINDOW whose
## rim is the rarity's inlay colour (with the rarity lozenge set at its corner), the level
## stamped on a gold coin, the name debossed in navy ink and the blueprints on a slotted
## channel. The card that can upgrade swaps its channel for an ice key.

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")
const I := preload("res://scripts/ui/skins/enamel/enamel_icons.gd")
const C := preload("res://scripts/ui/skins/enamel/enamel_chrome.gd")

## id, name, rarity, family, level, have, need, state ("", "upgrade", "locked")
const CARDS := [
	["mortar", "Облогова мортира", "R", "Кінетика", "6", 8, 8, "upgrade"],
	["prism", "Призма", "L", "Плазма", "4", 2, 12, ""],
	["railgun", "Рейкова гармата", "E", "Вольт", "3", 5, 10, ""],
	["laser", "Лазер", "R", "Плазма", "5", 6, 8, ""],
	["cannon", "Плазмова гармата", "C", "Плазма", "5", 3, 8, ""],
	["gatling", "Гатлінг", "C", "Кінетика", "1", 0, 0, "locked"],
]

var _root: Control


func _ready() -> void:
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	K.backdrop(_root, Vector2(0.75, 0.2))


func build() -> void:
	C.top_bar(_root, {"level": "14", "coins": "2 590", "gems": "40", "crowns": "26"})
	C.nameplate(_root, Vector2(16, 150), "Арсенал", "МАШИНИ · 8 / 9", {"size": 44, "h": 78.0})
	K.key(_root, Rect2(424, 152, 280, 84), "Колода 3/3", {"mat": "navy", "depth": 10.0, "size": 30, "inlay": [Color("F0E2FF"), Color("A66BFF"), Color("5A26B8")]})
	C.tabs(_root, Rect2(16, 256, 688, 68), ["Усі · 9", "Мої · 8", "Можна покращити · 2"], 0)
	for i in CARDS.size():
		var col := i % 2
		var row := i / 2
		_card(Rect2(16 + col * 352, 342 + row * 254, 336, 240), CARDS[i])
	C.nav(_root, "arsenal", {"arsenal": "2", "shop": "1"})


func _card(r: Rect2, d: Array) -> void:
	var id: String = d[0]
	var rar: Array = K.RARITY[d[2]]
	var state: String = d[7]
	var locked := state == "locked"
	var ready := state == "upgrade"
	K.plate(_root, r, {"mat": "disabled" if locked else "enamel", "ch": 22.0, "trim": 4.0, "rivet": 4.6, "shadow": 0.6,
		"glow": Color(0.56, 0.92, 1.0, 0.8) if ready else Color(0, 0, 0, 0), "glow_r": 12.0})
	# Window: sunk navy, rimmed in the rarity colour.
	var wr := Rect2(r.position.x + 14.0, r.position.y + 14.0, r.size.x - 28.0, 104.0)
	var rim: Array = [Color(rar[2]).darkened(0.2), rar[1], rar[0]] if not locked else [Color("4A4A52"), Color("77757A"), Color("A8A6A8")]
	K.plate(_root, wr, {"mat": "window", "recess": true, "ch": 16.0, "rad": 5.0, "trim": 4.0, "inset": 1.0, "trim_cols": rim, "shadow": 0.0, "outline_w": 0.0, "pad": 6.0})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var wc := wr.get_center() + Vector2(0, 4)
		if not locked:
			# rarity light pooled behind the machine
			for k in 6:
				var t := 1.0 - k / 6.0
				ci.draw_circle(wc + Vector2(0, 12), 22.0 + k * 11.0, Color(rar[1], 0.07 * t + 0.02), true, -1.0, true)
			ci.draw_set_transform(wc + Vector2(0, 40), 0.0, Vector2(1.0, 0.22))
			ci.draw_circle(Vector2.ZERO, 70.0, Color(rar[0], 0.18), true, -1.0, true)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tex := MachineThumbs.get_thumb(_root, id, false)
		if tex:
			# The render breaks out of its window: wheels inside, the top over the rim.
			var ts := 196.0
			ci.draw_texture_rect(tex, Rect2(wc.x - ts * 0.5, wr.end.y - ts * 0.86, ts, ts), false, Color(0.05, 0.06, 0.12, 0.92) if locked else Color.WHITE)
		if locked:
			I.draw(ci, "lock", Rect2(wc - Vector2(20, 26), Vector2(40, 46)), Color("C9C5BD"), Color("1A1E3A"), "plain")
		else:
			# level coin, stamped
			var lc := Vector2(wr.position.x + 26.0, wr.position.y + 26.0)
			ci.draw_circle(lc + Vector2(0, 2.5), 21.0, Color(0, 0, 0.05, 0.5), true, -1.0, true)
			ci.draw_circle(lc, 21.0, K.GOLD_DARK, true, -1.0, true)
			ci.draw_circle(lc + Vector2(-0.5, -0.8), 19.0, K.GOLD, true, -1.0, true)
			ci.draw_circle(lc + Vector2(-2, -3), 12.0, K.GOLD_LIGHT.lerp(K.GOLD, 0.4), true, -1.0, true)
			K.text_c(ci, d[4], "num", 24, lc + Vector2(0, 0.5), Color("3A2206"), "plain")
			# rarity lozenge at the window's cut corner
			K.draw_inlay(ci, Vector2(wr.end.x - 24.0, wr.position.y + 26.0), Vector2(24, 36), [rar[0], rar[1], rar[2]]))
	var ink := Color("6E6A64") if locked else K.INK
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var x := r.position.x + 20.0
		var nm: String = d[1]
		var s := K.fit_size(nm, "display", 28, r.size.x - 40.0, 24)
		K.text_l(ci, nm, "display", s, Vector2(x, r.position.y + 142.0), ink)
		if locked:
			K.text_l(ci, "Відкриється на рівні 18", "bold", 26, Vector2(x, r.position.y + 180.0), Color("6E6A64"))
			return
		var rw := K.text_l(ci, rar[3], "bold", 26, Vector2(x, r.position.y + 175.0), rar[4])
		K.text_l(ci, " · " + str(d[3]), "bold", 26, Vector2(x + rw, r.position.y + 175.0), K.INK_DIM))
	if locked:
		return
	if ready:
		var kr := Rect2(r.position.x + 14.0, r.end.y - 52.0, r.size.x - 28.0, 46.0)
		K.key(_root, kr, "", {"mat": "ice", "depth": 7.0, "ch": 10.0, "rad": 4.0, "shadow": 0.45, "pad": 14.0, "bevel_w": 5.0,
			"icon": func(ci: CanvasItem, fr: Rect2) -> float:
				var cy := fr.get_center().y
				var pw := K.text_w("540", "num", 26)
				var px := fr.end.x - 14.0 - pw
				K.text_l(ci, "540", "num", 26, Vector2(px, cy), K.WHITE, "raised")
				I.draw(ci, "coin", Rect2(px - 36.0, cy - 15.0, 30, 30))
				var lw := px - 46.0 - (fr.position.x + 14.0)
				var ls := K.fit_size("Покращити", "display", 26, lw, 22)
				K.text_l(ci, "Покращити", "display", ls, Vector2(fr.position.x + 14.0, cy), K.WHITE, "raised")
				return fr.end.x})
		return
	# Blueprint channel: a sunk slot with one enamel pip per blueprint.
	var have: int = d[5]
	var need: int = d[6]
	var cr := Rect2(r.position.x + 48.0, r.end.y - 48.0, r.size.x - 152.0, 32.0)
	K.plate(_root, cr, {"mat": "tray", "recess": true, "ch": 8.0, "rad": 4.0, "trim": 0.0, "shadow": 0.0, "outline_w": 0.0, "pad": 4.0, "bevel_w": 4.0})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var n := need
		var gap := 3.0
		var pw := (cr.size.x - 10.0 - gap * (n - 1)) / n
		for k in n:
			var pr := Rect2(cr.position.x + 5.0 + k * (pw + gap), cr.position.y + 7.0, pw, cr.size.y - 13.0)
			if k < have:
				ci.draw_rect(Rect2(pr.position + Vector2(0, 2), pr.size), Color(0, 0, 0.1, 0.35))
				K.vgrad(ci, pr, [K.ICE_WHITE, K.ICE, K.ICE_DEEP])
			else:
				ci.draw_rect(pr, Color(0.1, 0.1, 0.2, 0.08))
		I.draw(ci, "blueprint", Rect2(r.position.x + 18.0, cr.position.y + 2.0, 24, 28), K.INK_DIM, Color("F1EDE4"))
		K.text_r(ci, "%d/%d" % [have, need], "num", 26, Vector2(r.end.x - 16.0, cr.get_center().y + 1.0), K.INK))


func prepared() -> void:
	for i in 2:
		await get_tree().process_frame
	build()
	for c in CARDS:
		MachineThumbs.get_thumb(_root, c[0], false)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
	for c in _root.get_children():
		if c is CanvasItem:
			(c as CanvasItem).queue_redraw()
	for i in 4:
		await get_tree().process_frame
