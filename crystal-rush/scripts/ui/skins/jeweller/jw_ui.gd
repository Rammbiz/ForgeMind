class_name JwUi
## «Ювелірна майстерня» widgets (mock-up quality, drawn with Jw). Inner classes:
##   Layer (callable painter, optional material), GoldLabel, GemButton (emerald cut, primary),
##   Cabochon (navette bar in rope, secondary), Tabs (engraved words, marquise on a rail),
##   Plate (prong-set enamel plate), Lozenge (chip), Baguettes (progress in a gem channel).

const GUILLOCHE := preload("res://assets/ui/skins/jeweller/guilloche.gdshader")
const GOLD_TEXT := preload("res://assets/ui/skins/jeweller/gold_text.gdshader")

const TITLE_RAMP := [
	[0.0, Color("fff4cf")], [0.38, Color("ffe08a")], [0.52, Color("e2a93e")], [0.7, Color("c98e2e")],
	[0.86, Color("f2c766")], [1.0, Color("a8721f")]]


static func enamel_mat(center: Vector2, rect: Rect2, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GUILLOCHE
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	m.set_shader_parameter("light_pos", opts.get("light", rect.position + rect.size * Vector2(0.3, 0.15)))
	m.set_shader_parameter("light_r", opts.get("light_r", maxf(rect.size.x, rect.size.y) * 0.9))
	for k in ["spacing", "waves", "amp", "rays", "line_alpha", "vignette"]:
		if opts.has(k):
			m.set_shader_parameter(k, opts[k])
	for k in ["base", "line_col", "deep", "glow_col"]:
		if opts.has(k):
			m.set_shader_parameter(k, opts[k])
	return m


static func gold_mat(y0: float, y1: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GOLD_TEXT
	m.set_shader_parameter("ramp", Jw.ramp_tex("title", TITLE_RAMP))
	m.set_shader_parameter("y0", y0)
	m.set_shader_parameter("y1", y1)
	return m


## A Control whose _draw calls `painter.call(self)`.
class Layer extends Control:
	var painter: Callable

	func _init(p: Callable = Callable(), mat: Material = null) -> void:
		painter = p
		material = mat
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## Gold display lettering (Yeseva by default): white glyphs through the gold ramp shader,
## a thin ink outline and a dark drop shadow; no thick outline.
class GoldLabel extends Label:
	func _init(t: String, size := 56, font: Font = null, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
		text = t
		var f := font if font else Jw.display()
		add_theme_font_override("font", f)
		add_theme_font_size_override("font_size", size)
		add_theme_color_override("font_color", Color.WHITE)
		add_theme_color_override("font_outline_color", Color(Jw.GOLD_INK, 0.9))
		add_theme_constant_override("outline_size", maxi(2, size / 18))
		add_theme_color_override("font_shadow_color", Color(0.01, 0.01, 0.05, 0.75))
		add_theme_constant_override("shadow_offset_x", 0)
		add_theme_constant_override("shadow_offset_y", maxi(2, size / 16))
		add_theme_constant_override("shadow_outline_size", maxi(3, size / 12))
		horizontal_alignment = align
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_fit)

	func _fit() -> void:
		var f := get_theme_font("font")
		var s := get_theme_font_size("font_size")
		var lh := f.get_height(s)
		var top := (size.y - lh) * 0.5
		var asc := f.get_ascent(s)
		# ramp from the cap-height to the baseline
		material = JwUi.gold_mat(top + asc * 0.28, top + asc * 1.02)


static func label(t: String, size: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else Jw.label())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0.04, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Primary action: an emerald-cut gem in a gold bezel with 4 claw prongs.
## state: "normal" | "pressed" | "disabled".
class GemButton extends Control:
	var text := "ГРАТИ"
	var sub := ""
	var kind := "ice"
	var state := "normal"
	var chamfer := 22.0
	var text_size := 56
	var font: Font
	var icon := ""          # "coin" draws a coin medallion before the text
	var glints: Array = []  # [Vector2 (0..1 in rect), size]

	func _init(t := "ГРАТИ", k := "ice") -> void:
		text = t
		kind = k
		font = Jw.display()
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		var press := state == "pressed"
		var k := "smoke" if state == "disabled" else kind
		Jw.bezel(self, r, chamfer, 6.0)
		var gr := r.grow(-1.0)
		if press:
			gr.position.y += 2.0
		var table := Jw.emerald_cut(self, gr, chamfer - 1.0, k, press)
		if press:
			# sunk into the bezel: a shadow falls over the top facets, the whole stone dims
			Jw.fill(self, Jw.chamfer(gr, chamfer - 1.0), Color(0.0, 0.02, 0.1, 0.28))
			var top := Jw.chamfer(Rect2(gr.position, Vector2(gr.size.x, gr.size.y * 0.3)), minf(chamfer - 1.0, gr.size.y * 0.3))
			var clip := Geometry2D.intersect_polygons(top, Jw.chamfer(gr, chamfer - 1.0))
			for poly in clip:
				Jw.fill(self, poly, Color(0.0, 0.02, 0.1, 0.25))
		var ink := Jw.NAVY_INK if k != "smoke" else Color("8a8da3")
		if k == "citrine":
			ink = Color("3a1a02")
		if k == "smoke":
			ink = Color("1b1c27")
		var c := gr.get_center() + Vector2(0, -2)
		var sz := text_size
		if sub != "":
			c.y -= text_size * 0.2
		var tw := Jw.text_w(font, text, sz)
		var ic := 0.0
		if icon == "coin":
			ic = sz * 0.95
		var cap_max := table.size.y * (0.92 if sub == "" else 0.62)
		while (tw + ic > table.size.x + 10 or font.get_ascent(sz) * 0.72 > cap_max) and sz > 26:
			sz -= 2
			tw = Jw.text_w(font, text, sz)
			ic = sz * 0.95 if icon == "coin" else 0.0
		var tc := c + Vector2(ic * 0.5, 0)
		if icon == "coin":
			JwArt.coin(self, Vector2(tc.x - tw * 0.5 - ic * 0.55, c.y + 1), sz * 0.44)
		var lip := Color(1, 1, 1, 0.55) if k != "smoke" else Color(1, 1, 1, 0.12)
		Jw.text_c(self, font, text, tc + Vector2(0, 2), sz, lip)
		Jw.text_c(self, font, text, tc, sz, ink if state != "disabled" else Color("3a3c4c"))
		if sub != "":
			var sf := Jw.label()
			Jw.text_c(self, sf, sub, c + Vector2(0, text_size * 0.62 + 1), 26, lip)
			Jw.text_c(self, sf, sub, c + Vector2(0, text_size * 0.62), 26, Color(ink, 0.82))
		if state == "normal":
			for g in glints:
				Jw.glint(self, gr.position + gr.size * (g[0] as Vector2), g[1])


## Secondary action: a navette (pointed) cabochon bar of domed enamel in a twisted gold rope.
class Cabochon extends Control:
	var text := ""
	var state := "normal"
	var text_size := 30
	var tint := Color("1a2458")

	func _init(t := "") -> void:
		text = t
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var tip := r.size.y * 0.42
		var press := state == "pressed"
		var dis := state == "disabled"
		Jw.fill(self, Jw.navette(r.grow(2).grow_individual(0, -2, 0, 3), tip + 2), Color(0, 0, 0, 0.45))
		var o := Jw.navette(r, tip)
		var i_ := Jw.navette(r.grow(-6), tip - 2.4)
		# rope: twisted strands = alternating lit/dark slanted segments on a moulding
		Jw.gold_moulding(self, o, i_, 0.5, 1.0 if not dis else 0.3)
		var mid := PackedVector2Array()
		for k in o.size():
			mid.append(o[k].lerp(i_[k], 0.5))
		var pts := Jw.resample(mid, 6.0)
		var nr := Jw.normals(mid)
		for k in pts.size():
			var p := pts[k]
			var j := 0
			var best := 1e9
			for q in mid.size():
				var d := mid[q].distance_squared_to(p)
				if d < best:
					best = d
					j = q
			var n := nr[j]
			var t := Vector2(-n.y, n.x)
			var a := p + n * 2.6 + t * 1.6
			var b := p - n * 2.6 - t * 1.6
			draw_line(a, b, Color(Jw.GOLD_INK, 0.55 if not dis else 0.3), 1.4, true)
		# domed enamel
		var dome := i_
		var ramp := Jw.ramp_tex("dome", [[0.0, Color("3a4a9a")], [0.35, Color("22306e")], [0.75, Color("141c48")], [1.0, Color("0a0f2a")]])
		if press:
			ramp = Jw.ramp_tex("dome_p", [[0.0, Color("0c1230")], [0.5, Color("141c48")], [1.0, Color("26347a")]])
		if dis:
			ramp = Jw.ramp_tex("dome_d", [[0.0, Color("2a2c3a")], [1.0, Color("16171f")]])
		Jw.fill_ramp(self, dome, ramp, Vector2(0, 1))
		# dome highlight: a soft lens on the upper third
		if not press and not dis:
			var hl := Jw.navette(Rect2(r.position + Vector2(r.size.x * 0.12, 9), Vector2(r.size.x * 0.76, r.size.y * 0.22)), r.size.y * 0.1)
			Jw.fill(self, hl, Color(0.75, 0.85, 1.0, 0.1))
		var f := Jw.label()
		var sz := text_size
		while Jw.text_w(f, text, sz) > r.size.x - tip * 2 - 8 and sz > 24:
			sz -= 1
		var c := r.get_center() + Vector2(0, 1 + (1.5 if press else 0.0))
		var col := Jw.IVORY if not dis else Color("6c6f82")
		Jw.text_c(self, f, text, c + Vector2(0, 2), sz, Color(0, 0, 0, 0.6))
		Jw.text_c(self, f, text, c, sz, col)


## Tabs: engraved small-caps words on enamel; a marquise gem marks the selected one on a
## gold rail with lozenge terminals.
class Tabs extends Control:
	var items: Array = []
	var selected := 0
	var text_size := 30
	var badges := {}   # index -> gem kind dot

	func _draw() -> void:
		var f := Jw.label()
		var n := items.size()
		var w := size.x / n
		var rail_y := size.y - 12.0
		# rail
		draw_line(Vector2(14, rail_y + 1.5), Vector2(size.x - 14, rail_y + 1.5), Color(Jw.GOLD_INK, 0.8), 3.0, true)
		draw_line(Vector2(14, rail_y), Vector2(size.x - 14, rail_y), Jw.gold(0.7), 1.6, true)
		for x in [10.0, size.x - 10.0]:
			Jw.fill(self, Jw.lozenge(Rect2(x - 8, rail_y - 4, 16, 8), 8), Jw.gold(0.75))
		for i in n:
			var c := Vector2(w * (i + 0.5), (size.y - 22) * 0.5)
			var s: String = items[i]
			if i == selected:
				Jw.text_engraved(self, f, s, c, text_size + 2, Jw.GOLD_LIGHT, Color(0, 0, 0, 0.7), Color(1, 0.9, 0.6, 0.18))
				var tw := Jw.text_w(f, s, text_size + 2)
				for sx in [-1.0, 1.0]:
					var ex: float = c.x + sx * (tw * 0.5 + 16)
					Jw.fill(self, Jw.regular(Vector2(ex, c.y + 1), 4.5, 4), Jw.gold(0.85))
				Jw.marquise(self, Vector2(c.x, rail_y), 54, 14, 0.0, "ice")
				Jw.prong(self, Vector2(c.x - 33, rail_y), Vector2(c.x - 22, rail_y), 5)
				Jw.prong(self, Vector2(c.x + 33, rail_y), Vector2(c.x + 22, rail_y), 5)
				Jw.glint(self, Vector2(c.x - 9, rail_y - 3), 9)
			else:
				Jw.text_engraved(self, f, s, c, text_size, Color("b98b3c"), Color(0, 0, 0, 0.7), Color(1, 0.9, 0.6, 0.08))
			if badges.has(i):
				var tw2 := Jw.text_w(f, s, text_size)
				Jw.octagem(self, c + Vector2(tw2 * 0.5 + 14, -12), 6.5, badges[i])


## Prong-set plate: guilloché enamel inside a gold frame with corner gems.
class Plate extends Control:
	var notch := 22.0
	var frame_w := 6.0
	var corner_gem := "ice"
	var enamel_opts := {}
	var _en: Layer

	func _init(n := 22.0, gem_kind := "ice", opts := {}) -> void:
		notch = n
		corner_gem = gem_kind
		enamel_opts = opts
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_en = Layer.new(_paint_enamel)
		_en.show_behind_parent = true
		add_child(_en)
		resized.connect(_on_resized)

	func _on_resized() -> void:
		_en.size = size
		var r := Rect2(Vector2.ZERO, size)
		_en.material = JwUi.enamel_mat(enamel_opts.get("center", Vector2(size.x * 0.5, -size.y * 0.25)), r, enamel_opts)
		_en.queue_redraw()
		queue_redraw()

	func _paint_enamel(ci: CanvasItem) -> void:
		var r := Rect2(Vector2.ZERO, size)
		# soft drop shadow first (plain fill so the shader tints it: use a separate shadow below)
		Jw.fill(ci, Jw.notched(r.grow(-3), notch + 3), Color.WHITE)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Jw.plate_frame(self, r, notch, frame_w, corner_gem)


## Shadow under a plate (add before the plate).
static func plate_shadow(parent: Control, r: Rect2, notch: float, spread := 10.0) -> Layer:
	var l := Layer.new(func(ci: CanvasItem) -> void:
		for k in 5:
			var g := spread * (1.0 - k / 5.0)
			Jw.fill(ci, Jw.notched(r.grow(g).grow_individual(0, -2, 0, 6), notch + g), Color(0, 0, 0.02, 0.09))
	)
	l.size = parent.size
	parent.add_child(l)
	return l


## Lozenge chip with gold rim and enamel fill (rarity, tags, small badges).
class Lozenge extends Control:
	var text := ""
	var kind := "sapphire"
	var text_size := 26

	func _init(t := "", k := "sapphire") -> void:
		text = t
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var tip := r.size.y * 0.5
		Jw.fill(self, Jw.lozenge(r.grow_individual(0, -1, 0, 3), tip), Color(0, 0, 0, 0.45))
		Jw.gold_moulding(self, Jw.lozenge(r, tip), Jw.lozenge(r.grow(-3.5), tip - 1.5), 0.45)
		var inner := Jw.lozenge(r.grow(-3.5), tip - 1.5)
		var tex := Jw.ramp_tex("loz_" + kind, [[0.0, Jw.gem(kind, 0.42)], [0.55, Jw.gem(kind, 0.22)], [1.0, Jw.gem(kind, 0.1)]])
		Jw.fill_ramp(self, inner, tex, Vector2(0, 1))
		Jw.octagem(self, Vector2(r.position.x + tip + 6, r.get_center().y), r.size.y * 0.22, kind)
		var f := Jw.label()
		var c := r.get_center() + Vector2(tip * 0.5 - 2, 0)
		Jw.text_c(self, f, text, c + Vector2(0, 1.5), text_size, Color(0, 0, 0, 0.6))
		Jw.text_c(self, f, text, c, text_size, Jw.IVORY)


## Progress as baguette-cut gems set in a gold channel: `filled` of `total` lit.
class Baguettes extends Control:
	var filled := 3
	var total := 5
	var kind := "ice"
	var label := ""

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		Jw.fill(self, Jw.chamfer(r.grow_individual(0, -1, 0, 3), 4), Color(0, 0, 0, 0.5))
		Jw.gold_moulding(self, Jw.chamfer(r, 5), Jw.chamfer(r.grow(-3), 3.8), 0.45)
		var inner := r.grow(-4)
		Jw.fill(self, Jw.chamfer(inner, 3), Color("070a1c"))
		var n := total
		var gap := 3.0
		var bw := (inner.size.x - gap * (n + 1)) / n
		for i in n:
			var br := Rect2(inner.position + Vector2(gap + i * (bw + gap), 3), Vector2(bw, inner.size.y - 6))
			if i < filled:
				Jw.emerald_cut(self, br, 2.0, kind, false, PackedFloat32Array([0.0, 0.22]))
			else:
				Jw.fill(self, Jw.chamfer(br, 2.0), Color("151a36"))
				Jw.line(self, Jw.chamfer(br, 2.0), Color("2a3160"), 1.0)
		if label != "":
			var f := Jw.num()
			var c := r.get_center()
			Jw.text_c(self, f, label, c, 26, Color(0, 0, 0, 0.0), 6, Color(0.02, 0.03, 0.08, 0.85))
			Jw.text_c(self, f, label, c, 26, Jw.IVORY)
