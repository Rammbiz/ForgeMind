extends CanvasLayer
## «Емаль і золото» specimen: the kit laid out on one sheet - keys in every state, type,
## odometer counters, currency plates, rarity inlays, toggle tabs and the kit tray.

const K := preload("res://scripts/ui/skins/enamel/enamel_kit.gd")
const I := preload("res://scripts/ui/skins/enamel/enamel_icons.gd")
const C := preload("res://scripts/ui/skins/enamel/enamel_chrome.gd")

var _root: Control


func _ready() -> void:
	_root = Control.new()
	_root.size = Vector2(720, 1280)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	K.backdrop(_root, Vector2(0.3, 0.3))


func _section(y: float, text: String) -> void:
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var w := K.text_l(ci, text, "caps", 22, Vector2(26, y), K.GOLD_LIGHT, "plain")
		ci.draw_line(Vector2(38 + w, y), Vector2(694, y), Color(K.GOLD, 0.55), 2.0, true)
		K.rivet(ci, Vector2(698, y), 3.5))


func _build() -> void:
	C.nameplate(_root, Vector2(16, 44), "Емаль і золото", "НАПРЯМ C · КИТ-НАБІР", {"size": 46})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		K.text_l(ci, "Dela Gothic One · Podkova · Oi", "bold", 26, Vector2(20, 158), Color("C9CFF0"), "plain"))

	# --- keys
	_section(198, "КЛАВІШІ")
	K.key(_root, Rect2(18, 222, 336, 104), "ГРАТИ", {"mat": "ice", "depth": 12.0, "size": 46, "sub": "Рівень 14", "inlay": [K.ICE_WHITE, K.ICE, K.ICE_DEEP], "rivet": 4.0})
	K.key(_root, Rect2(366, 222, 336, 104), "ГРАТИ", {"mat": "ice", "depth": 12.0, "size": 46, "sub": "натиснуто", "state": "pressed", "inlay": [K.ICE_WHITE, K.ICE, K.ICE_DEEP], "rivet": 4.0})
	K.key(_root, Rect2(18, 346, 220, 78), "Покращити", {"depth": 10.0, "size": 28, "font": "display"})
	K.key(_root, Rect2(250, 346, 220, 78), "Покращити", {"depth": 10.0, "size": 28, "font": "display", "state": "pressed"})
	K.key(_root, Rect2(482, 346, 220, 78), "Покращити", {"depth": 10.0, "size": 28, "font": "display", "state": "disabled"})
	K.key(_root, Rect2(18, 440, 330, 78), "Відмовитися", {"mat": "red", "depth": 10.0, "size": 30})
	K.key(_root, Rect2(360, 440, 342, 78), "Колода 3/3", {"mat": "navy", "depth": 10.0, "size": 30, "inlay": [Color("F0E2FF"), Color("A66BFF"), Color("5A26B8")]})

	# --- type
	_section(552, "ШРИФТИ І ЦИФРИ")
	var tp := Rect2(16, 576, 688, 262)
	K.plate(_root, tp, {"ch": 18.0, "trim": 4.0, "rivet": 4.2, "rivet_every": 160.0, "shadow": 0.55})
	K.canvas(_root, func(ci: CanvasItem) -> void:
		var x := tp.position.x + 28.0
		K.text_l(ci, "ПЕРЕМОГА!", "logo", 60, Vector2(x, tp.position.y + 52.0), K.INK, "deboss")
		K.text_l(ci, "×2", "logo", 60, Vector2(tp.end.x - 120.0, tp.position.y + 52.0), Color("1A6FC0"), "deboss")
		K.text_l(ci, "Кришталевий Ривок", "display", 40, Vector2(x, tp.position.y + 112.0), K.INK, "deboss")
		K.text_l(ci, "СВІТ 1 · РІВЕНЬ 14 / 25", "caps", 26, Vector2(x, tp.position.y + 156.0), Color("1A6FC0"), "deboss")
		K.text_l(ci, "Снаряд падає за 12 кроків перед героєм —", "body", 27, Vector2(x, tp.position.y + 194.0), K.INK, "deboss")
		K.text_l(ci, "наведи кільце. Ґанок, їжак, є’, №7.", "body", 27, Vector2(x, tp.position.y + 226.0), K.INK_DIM, "deboss"))

	# --- counters / currencies
	_section(872, "ЛІЧИЛЬНИКИ")
	C.currency(_root, 18, 896, "coin", "2 590")
	C.currency(_root, 240, 896, "crystal", "40", true)
	C.currency(_root, 462, 896, "crest", "26")

	# --- rarity inlays
	var rx := 18.0
	for rk: String in ["C", "R", "E", "L"]:
		var rar: Array = K.RARITY[rk]
		var w := K.text_w(rar[3], "bold", 26) + 44.0
		var rr := Rect2(rx, 978, w, 50)
		K.plate(_root, rr, {"ch": 8.0, "rad": 4.0, "trim": 0.0, "shadow": 0.45, "pad": 12.0, "bevel_w": 5.0})
		K.canvas(_root, func(ci: CanvasItem) -> void:
			K.draw_inlay(ci, Vector2(rr.position.x + 18.0, rr.get_center().y), Vector2(16, 26), [rar[0], rar[1], rar[2]], false)
			K.text_l(ci, rar[3], "bold", 26, Vector2(rr.position.x + 33.0, rr.get_center().y), rar[4], "deboss"))
		rx += w + 6.0

	# --- tabs
	C.tabs(_root, Rect2(16, 1048, 688, 66), ["Усі · 9", "Мої · 8", "Можна покращити · 2"], 0)
	C.nav(_root, "play", {"arsenal": "2", "shop": "1"})


func prepared() -> void:
	for i in 2:
		await get_tree().process_frame
	_build()
	for i in 6:
		await get_tree().process_frame
