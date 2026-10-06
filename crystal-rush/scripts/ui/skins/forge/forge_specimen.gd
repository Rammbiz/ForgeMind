extends CanvasLayer
## «Кришталева кузня» specimen sheet: type ramp, prism buttons in every state, currency
## shards, rarity gems, the cut progress bar, level gems and the station shards.




func _ready() -> void:
	var root := Control.new()
	root.size = Vector2(720, 1280)
	add_child(root)
	ForgeKit.backdrop(root, Vector2(0.3, 0.1))
	ForgeKit.label(root, "НАБІР ЕЛЕМЕНТІВ · НАПРЯМ B", "label", 26, ForgeKit.DIM, Rect2(24, 20, 680, 36), HORIZONTAL_ALIGNMENT_LEFT, false)
	ForgeKit.headline(root, "КРИШТАЛЕВА", Vector2(22, 58), 64, {"max_w": 676})
	ForgeKit.headline(root, "КУЗНЯ", Vector2(22, 118), 64, {"max_w": 676})

	# --- type ramp
	ForgeKit.panel(root, Rect2(16, 192, 688, 312), 11, {"cuts": {1: Vector2(64, 26), 3: Vector2(18, 44)}})
	ForgeKit.label(root, "ТИПОГРАФІКА", "label", 26, Color("7FE3FF"), Rect2(40, 206, 400, 36), HORIZONTAL_ALIGNMENT_LEFT, false)
	ForgeKit.headline(root, "АРСЕНАЛ", Vector2(38, 242), 60, {"max_w": 420})
	ForgeKit.label(root, "Облогова мортира", "bold", 40, ForgeKit.TEXT, Rect2(40, 308, 640, 50), HORIZONTAL_ALIGNMENT_LEFT, false)
	ForgeKit.para(root, "Снаряд падає за 12 кроків перед героєм — наведи кільце на ворогів і тримай їх у ньому.", "body", 28, Color("C9D8F0"), Rect2(40, 356, 640, 76))
	ForgeKit.canvas(root, func(ci: CanvasItem) -> void:
		var x := 40.0
		x += ForgeKit.draw_text_l(ci, "2 590", "num", 40, Vector2(x, 466), ForgeKit.GOLD) + 28.0
		x += ForgeKit.draw_text_l(ci, "×2,5", "num", 40, Vector2(x, 466), ForgeKit.RIM) + 28.0
		x += ForgeKit.draw_text_l(ci, "+0,37", "num", 40, Vector2(x, 466), Color("7FE3FF")) + 28.0
		ForgeKit.draw_text_l(ci, "14/20", "num", 40, Vector2(x, 466), ForgeKit.TEXT))

	# --- buttons
	ForgeKit.panel(root, Rect2(16, 518, 688, 292), 12, {"cuts": {0: Vector2(26, 58), 2: Vector2(44, 16)}})
	var cols := [["ЗВИЧАЙНА", "normal"], ["НАТИСНУТА", "pressed"], ["ВИМКНЕНА", "disabled"]]
	var rows := [["primary", "ГРАТИ", ""], ["secondary", "ЩЕ РАЗ", "coin"], ["danger", "ЗДАТИСЯ", ""]]
	var cx := [134.0, 360.0, 586.0]
	for i in 3:
		ForgeKit.label(root, cols[i][0], "label", 22, ForgeKit.DIM, Rect2(cx[i] - 110, 530, 220, 32), HORIZONTAL_ALIGNMENT_CENTER, false)
	ForgeKit.canvas(root, func(ci: CanvasItem) -> void:
		for j in rows.size():
			for i in 3:
				var r := Rect2(cx[i] - 100, 572 + j * 76, 200, 58)
				var p := ForgeKit.shard(r, 40 + j, {"cuts": {0: Vector2(24, 10), 2: Vector2(12, 26)}, "skew": 0.0})
				ForgeKit.draw_button(ci, p, rows[j][0], rows[j][1], {"state": cols[i][1], "size": 26, "icon": rows[j][2], "icon_px": 30}))

	# --- currencies, rarity, bars, gems
	ForgeKit.panel(root, Rect2(16, 824, 688, 262), 13, {"cuts": {1: Vector2(20, 48)}})
	ForgeChrome.currency(root, Rect2(48, 842, 150, 54), "gem", "40", 61, true)
	ForgeChrome.currency(root, Rect2(226, 842, 196, 54), "coin", "2 590", 62)
	ForgeChrome.currency(root, Rect2(450, 842, 120, 54), "blueprint", "9", 63)
	ForgeKit.canvas(root, func(ci: CanvasItem) -> void:
		ForgeKit.draw_level_gem(ci, Vector2(640, 868), 32.0, "14")
		var x := 40.0
		var y := 934.0
		for key in ["C", "R", "E", "L", "M"]:
			var rr: Array = ForgeKit.RARITY[key]
			var nm := str(rr[3])
			var w := ForgeKit.text_w(nm, "bold", 26) + 52.0
			if x + w > 690.0:
				x = 40.0
				y += 52.0
			var cp := ForgeKit.shard(Rect2(x, y - 21, w, 42), hash(key), {"cuts": {0: Vector2(12, 8), 2: Vector2(8, 12)}, "skew": 0.0})
			ci.draw_colored_polygon(cp, Color(0.03, 0.04, 0.14, 0.85))
			ForgeKit.draw_rim(ci, cp, rr[1], Color("05061A"), 1.5, 0.0)
			var sides := int(rr[4])
			ForgeKit.draw_gem(ci, Vector2(x + 22, y), 13.0, sides, [rr[0], rr[1], rr[2]], PI / 4.0 if sides == 4 else 0.0, 0.55, false)
			ForgeKit.draw_text_l(ci, nm, "bold", 26, Vector2(x + 42, y), rr[0])
			x += w + 12.0
		ForgeChrome.draw_bar(ci, Rect2(40, 1034, 300, 36), 0.62, "5/8")
		ForgeChrome.draw_bar(ci, Rect2(372, 1034, 300, 36), 1.0, "8/8", true))
	ForgeChrome.nav(root, "arsenal", {"arsenal": 2})


func prepared() -> void:
	for i in 4:
		await get_tree().process_frame
