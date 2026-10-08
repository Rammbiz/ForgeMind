class_name KitGemCard
extends Control
## UI v3.1 rarity card (spec §7.3: opaque gem ground for identity, a 1 dpx frame, two faint
## shadow layers, a glass footer and pip bed at 0.94, Medium footer text >= 22 px; the strip
## grows upward when the title + footer need it, and a long "a · b" footer takes 2 lines).
## UI v2 rarity card (Genshin construction, our marks): a gem-coloured vertical gradient ground
## with that gem's faint fracture pattern (quartz 60/120 planes, sapphire 12-degree grid,
## amethyst triangles, topaz 5 rays, opal conchoidal arcs + play-of-colour flecks), the art in
## the middle (clipped to the chamfered card), a cream footer strip with title + footer text,
## a row of rhombus facet pips on the seam, the gem-cut mark top-left (colour-blind code), a
## thin gold frame with an inner 1 px rim in the gem's light tone. Optional NEW tag, badges.
##   var c := UIKit.gem_card("L", Vector2(216, 300)); c.title = "Веста"; c.footer = "Рів. 23"
##   c.art.texture = splash; c.pips = 3
## Bitmap overrides: card_<gem>.png (ground, stretched), card_frame.png (nine-patch frame).

var gem := "quartz":
	set(v):
		gem = UITokens.gem_of(v)
		_sync_opal()
		queue_redraw()
var title := "":
	set(v):
		title = v
		_redraw_all()
		if is_inside_tree():
			_layout()
var footer := "":
	set(v):
		footer = v
		_redraw_all()
		if is_inside_tree():
			_layout()
var pips := -1:                ## lit facet pips (0..pip_count); -1 hides the row
	set(v):
		pips = v
		_redraw_all()
var pip_count := 5
var show_mark := true
var new_tag := false:
	set(v):
		new_tag = v
		_redraw_all()
var dim := false:              ## unowned / locked: desaturated ground, art at 18 %
	set(v):
		dim = v
		if art:
			art.modulate = Color(0.3, 0.32, 0.38, 0.35) if v else Color.WHITE
		_redraw_all()
var footer_ratio := 0.21       ## footer strip height / card height (grown for 22 px text)
const MIN_TEXT := 22             ## footer title / line floor (MF-15)
const FOOT_A := 0.94             ## glass footer + pip bed alpha (INK / INK_DIM_GLASS stay >= 4.5:1)
var art: TextureRect           ## the painted bust / 3D thumb
var content: Control           ## extra children over the art (clipped to the card)
var _clip: Control
var _over: Control
var _opal: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_clip = _ClipMask.new()
	_clip.card = self
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_clip)
	_opal = ColorRect.new()
	_opal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opal.visible = false
	_opal.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ui/opal.gdshader") as Shader
	_opal.material = m
	_clip.add_child(_opal)
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(art)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(content)
	_over = _Overlay.new()
	_over.card = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	resized.connect(_layout)


func _ready() -> void:
	_sync_opal()
	_layout()


func _layout() -> void:
	if _opal and _opal.material:
		(_opal.material as ShaderMaterial).set_shader_parameter("rect_size", size)
		(_opal.material as ShaderMaterial).set_shader_parameter("chamfer_px", _cham())
	var fh := _footer_h()
	art.offset_bottom = -fh * 0.5
	content.offset_bottom = -fh


## The footer strip: footer_ratio of the card, grown upward when the title + footer lines need
## more room at the 22 px floor (MF-15: footer text is never below 22 px).
func _footer_h() -> float:
	var fh := roundf(size.y * footer_ratio)
	if title == "" and footer == "":
		return fh
	var f := UIKit.font_w("medium")
	var need := (8.0 if pips >= 0 else 0.0) + 2.0 + 6.0
	if title != "":
		need += f.get_ascent(MIN_TEXT) + f.get_descent(MIN_TEXT) * 0.5
	for ln in _footer_lines(MIN_TEXT):
		need += f.get_ascent(MIN_TEXT) + f.get_descent(MIN_TEXT) * 0.5
	return maxf(fh, ceilf(need))


## The footer text as 1 line, or split at " · " into 2 lines when it does not fit at `fs`.
func _footer_lines(fs: int) -> Array[String]:
	var out: Array[String] = []
	if footer == "":
		return out
	var f := UIKit.font_w("medium")
	if f.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= size.x - 12.0 or not footer.contains(" · "):
		out.append(footer)
		return out
	var i := footer.find(" · ")
	out.append(footer.substr(0, i))
	out.append(footer.substr(i + 3))
	return out


func _sync_opal() -> void:
	if _opal:
		_opal.visible = gem == "opal" and UIKit.kit_texture("card_opal") == null


func _redraw_all() -> void:
	queue_redraw()
	if _over:
		_over.queue_redraw()


func _cham() -> float:
	return clampf(minf(size.x, size.y) * 0.05, 6.0, 12.0)


func _shape() -> PackedVector2Array:
	return GemDraw.chamfer_rect(Rect2(Vector2.ZERO, size), _cham())


func _draw() -> void:
	var pts := _shape()
	# v3.1: two faint shadow layers (not four).
	for i in 2:
		var o := Vector2(0, 2.0 + i * 2.4)
		var sp := PackedVector2Array()
		for p in pts:
			sp.append(p + o)
		draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))


## Ground + fracture pattern, drawn by the clip mask (so art and pattern share the clip).
func draw_ground(ci: CanvasItem) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var pts := _shape()
	var tex := UIKit.kit_texture("card_" + gem)
	if tex:
		ci.draw_colored_polygon(pts, Color.WHITE)
		ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	var top: Color = g["top"]
	var bot: Color = g["bot"]
	if dim:
		top = UITokens.PAPER_3.darkened(0.08)
		bot = UITokens.PAPER_3
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, p.y / maxf(size.y, 1.0)))
	ci.draw_polygon(pts, cols)
	if dim:
		return
	# A soft light pool behind the bust (upper middle).
	var lc: Color = g["light"]
	var R := size.x * 0.75
	# Cut to the card rect geometrically (also correct where clip_children is unavailable, e.g.
	# the MachineCard bake viewport).
	glow_in(ci, Rect2(Vector2(size.x * 0.5 - R, size.y * 0.36 - R), Vector2(R, R) * 2.0), Rect2(Vector2.ZERO, size), Color(lc.r, lc.g, lc.b, 0.22))
	if gem == "quartz":
		# Crafted rock crystal: a frosted diagonal sheen (brushed light) over the planes.
		ci.draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.1), Vector2(size.x * 0.55, 0), Vector2(size.x, 0), Vector2(size.x, size.y * 0.12), Vector2(0, size.y * 0.62)]),
				PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)]))
	_draw_fracture(ci, gem, Rect2(Vector2.ZERO, size), pts)


## The soft glow texture in `dest`, cut to `bounds` (texture region maps the cut exactly).
static func glow_in(ci: CanvasItem, dest: Rect2, bounds: Rect2, col: Color) -> void:
	var cut := dest.intersection(bounds)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return
	var tex := UIKit.glow_texture()
	var ts := tex.get_size()
	var src := Rect2((cut.position - dest.position) / dest.size * ts, cut.size / dest.size * ts)
	ci.draw_texture_rect_region(tex, cut, src, col)


## The gem's faint fracture pattern in `r`, clipped to `clip` (the card shape) when given, all
## segments batched into one draw_multiline call.
static func _draw_fracture(ci: CanvasItem, gk: String, r: Rect2, clip := PackedVector2Array()) -> void:
	var a := 0.08 if gk != "quartz" else 0.12
	var col := Color(1, 1, 1, a)
	var w := r.size.x
	var h := r.size.y
	var c := r.get_center()
	var lines := PackedVector2Array()
	match gk:
		"quartz":
			# Frosted 60/120-degree planes.
			var step := w * 0.32
			for i in range(-6, 7):
				var o := c + Vector2(i * step, 0)
				for ang: float in [PI / 3.0, 2.0 * PI / 3.0]:
					var d := Vector2(cos(ang), sin(ang)) * h
					lines.append_array([o - d, o + d])
		"sapphire":
			var step := w * 0.2
			var rot := deg_to_rad(12.0)
			var ux := Vector2(cos(rot), sin(rot))
			var uy := Vector2(-ux.y, ux.x)
			for i in range(-8, 9):
				lines.append_array([c + ux * i * step - uy * h, c + ux * i * step + uy * h])
				lines.append_array([c + uy * i * step - ux * h, c + uy * i * step + ux * h])
		"amethyst":
			var step := w * 0.34
			for ang: float in [PI / 6.0, PI / 2.0, 5.0 * PI / 6.0]:
				var d := Vector2(cos(ang), sin(ang))
				var n := Vector2(-d.y, d.x)
				for i in range(-5, 6):
					lines.append_array([c + n * i * step - d * h, c + n * i * step + d * h])
		"topaz":
			var o := Vector2(c.x, r.position.y + h * 0.3)
			for i in 5:
				var ang := -PI / 2.0 + TAU * i / 5.0
				var d := Vector2(cos(ang), sin(ang))
				var n := Vector2(-d.y, d.x) * w * 0.05
				var tri := PackedVector2Array([o, o + d * h + n, o + d * h - n])
				if not clip.is_empty():
					for q in Geometry2D.intersect_polygons(tri, clip):
						if (q as PackedVector2Array).size() >= 3:
							ci.draw_colored_polygon(q, Color(1, 0.95, 0.8, 0.08))
				else:
					ci.draw_colored_polygon(tri, Color(1, 0.95, 0.8, 0.08))
				lines.append_array([o, o + d * h])
			col = Color(1, 0.96, 0.85, 0.14)
		"opal":
			for i in 5:
				var cc := Vector2(r.position.x + w * (0.2 + 0.15 * i), r.position.y + h * (0.9 - 0.12 * i))
				var rad := w * (0.35 + 0.1 * i)
				var prev := cc + Vector2(cos(PI * 1.1), sin(PI * 1.1)) * rad
				for k in range(1, 25):
					var t := PI * 1.1 + PI * 0.8 * k / 24.0
					var q := cc + Vector2(cos(t), sin(t)) * rad
					lines.append_array([prev, q])
					prev = q
			col = Color(0.85, 0.8, 1.0, 0.12)
	if lines.is_empty():
		return
	if not clip.is_empty():
		var cut := PackedVector2Array()
		var i := 0
		while i + 1 < lines.size():
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([lines[i], lines[i + 1]]), clip):
				var sg := seg as PackedVector2Array
				for j in sg.size() - 1:
					cut.append_array([sg[j], sg[j + 1]])
			i += 2
		lines = cut
	if lines.size() >= 2:
		ci.draw_multiline(lines, col, 1.0, true)


## The stage-scale version (detail / Arsenal / Heroes stages): 4 long, very soft refraction
## planes (6-10 %, varying width, fading mid-line) and a large soft caustic - the dense card
## grid would read as graph paper at full-screen size.
static func draw_stage_fracture(ci: CanvasItem, gk: String, r: Rect2) -> void:
	var lc: Color = UITokens.gem(gk)["light"]
	var w := r.size.x
	var h := r.size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(gk)
	for i in 4:
		var a := deg_to_rad(rng.randf_range(-35.0, 35.0) + (60.0 if i % 2 == 1 else -20.0))
		var d := Vector2(cos(a), sin(a))
		var o := r.position + Vector2(w * rng.randf_range(0.15, 0.85), h * rng.randf_range(0.2, 0.75))
		var L := w * 0.9
		var n := 10
		for k in n:
			var t0 := float(k) / n
			var t1 := float(k + 1) / n
			var fade := sin(PI * (t0 + t1) * 0.5) * (0.55 + 0.45 * absf(cos(PI * (t0 + t1) * 1.5)))
			var pa := o + d * L * (t0 - 0.5)
			var pb := o + d * L * (t1 - 0.5)
			# No facet edge behind the header text (canvas y 0-160): fade them out above 200.
			fade *= smoothstep(110.0, 200.0, minf(pa.y, pb.y))
			if fade > 0.01:
				ci.draw_line(pa, pb, Color(lc.r, lc.g, lc.b, 0.09 * fade), 1.0 + 2.5 * fade, true)
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(r.position + Vector2(w * 0.08, h * 0.05), Vector2(w * 0.7, h * 0.55)), false, Color(lc.r, lc.g, lc.b, 0.16))


func _draw_over(ci: CanvasItem) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var pts := _shape()
	var fh := _footer_h()
	var seam := size.y - fh
	# Footer strip (cream) with title and footer text.
	var foot := PackedVector2Array()
	var ch := _cham()
	foot.append(Vector2(0, seam))
	foot.append(Vector2(size.x, seam))
	foot.append(Vector2(size.x, size.y - ch))
	foot.append(Vector2(size.x - ch, size.y))
	foot.append(Vector2(ch, size.y))
	foot.append(Vector2(0, size.y - ch))
	# v3.1: a glass footer (cream @ 0.94 over the ground: the gem tint barely shows, the text
	# keeps >= 4.5:1 on the worst 5 %), a 1 dpx seam rule.
	var p0 := UITokens.PAPER_0
	ci.draw_colored_polygon(foot, Color(p0.r, p0.g, p0.b, FOOT_A) if not dim else UITokens.PAPER_3)
	var sy := GemDraw.pixel_y(ci, seam)
	ci.draw_line(Vector2(0, sy), Vector2(size.x, sy), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), -1.0)
	var f := UIKit.font_w("medium")
	var fm := UIKit.font_w("medium")
	var ts := int(clampf(fh * 0.38, MIN_TEXT, 26.0))
	var ss := int(clampf(fh * 0.34, MIN_TEXT, 24.0))
	var pip_room := 8.0 if pips >= 0 else 0.0
	# Title over footer, stacked by their real ascents (no overlap at any card size).
	var top := seam + pip_room + 2.0
	var avail := size.y - 4.0 - top
	var fs := ts
	if title != "":
		# Width fit: down to the 22 px floor (20 only for a name that cannot fit otherwise).
		while fs > MIN_TEXT and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16.0:
			fs -= 1
		while fs > 20 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 8.0:
			fs -= 1
	while ss > MIN_TEXT and footer != "" and fm.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x > size.x - 12.0:
		ss -= 1
	var lines := _footer_lines(ss)
	var lh := fm.get_ascent(ss) + fm.get_descent(ss) * 0.5
	var th := (f.get_ascent(fs) + f.get_descent(fs) * 0.5) if title != "" else 0.0
	var sh2 := lh * lines.size()
	while th + sh2 > avail and (fs > MIN_TEXT or ss > MIN_TEXT):
		if fs > ss:
			fs -= 1
		else:
			ss -= 1
		lh = fm.get_ascent(ss) + fm.get_descent(ss) * 0.5
		th = (f.get_ascent(fs) + f.get_descent(fs) * 0.5) if title != "" else 0.0
		sh2 = lh * lines.size()
	var y0 := top + maxf(0.0, (avail - th - sh2) * 0.5)
	if title != "":
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, Vector2(roundf((size.x - tw) * 0.5), roundf(y0 + f.get_ascent(fs))), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK if not dim else UITokens.INK_DIM_GLASS)
	var ly := y0 + th
	for ln: String in lines:
		var fw := fm.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		ci.draw_string(fm, Vector2(roundf((size.x - fw) * 0.5), roundf(ly + fm.get_ascent(ss))), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UITokens.INK_DIM_GLASS)
		ly += lh
	# Frame: inner 1 px rim in the gem's light tone, outer gold hairline.
	var inner := GemDraw.chamfer_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), maxf(ch - 1.5, 1.0))
	var rim: Color = g["rim"] if not dim else UITokens.PAPER_3
	ci.draw_polyline(_open_top(inner, seam), Color(rim.r, rim.g, rim.b, 0.75), UIKit.px(1.0), true)
	var ftex := UIKit.kit_texture("card_frame")
	if ftex:
		ci.draw_style_box(UIKit.lux("card_frame"), Rect2(Vector2.ZERO, size))
	else:
		GemDraw.outline(ci, pts, UITokens.HAIRLINE, UIKit.line_px(1.0))
	# Facet pips on the seam.
	if pips >= 0 and pip_count > 0:
		var ps := clampf(size.x * 0.07, 10.0, 16.0)
		var gapx := ps * 0.95
		var total := gapx * (pip_count - 1)
		var light: Color = g["rim"] if gem != "opal" else Color("#E8D8FF")
		# Cream bed behind the pips so they read on any ground.
		var bed := Rect2(Vector2((size.x - total) * 0.5 - ps * 0.7, seam - ps * 0.55), Vector2(total + ps * 1.4, ps * 1.1))
		ci.draw_colored_polygon(GemDraw.chamfer_rect(bed, ps * 0.5), Color(p0.r, p0.g, p0.b, FOOT_A) if not dim else UITokens.PAPER_3)
		for i in pip_count:
			GemDraw.draw_pip(ci, Vector2((size.x - total) * 0.5 + i * gapx, seam), ps, i < pips, light)
	# Gem-cut mark top-left.
	if show_mark:
		var ms := clampf(size.x * 0.15, 18.0, 40.0)
		GemDraw.draw_mark(ci, gem, Vector2(ch + ms * 0.5 + 2.0, ch + ms * 0.5 + 2.0), ms, 0.45 if dim else 1.0)
	if new_tag:
		var nf := UIKit.font_w("extrabold")
		var nt := "NEW"
		var nw := nf.get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14.0
		var nr := Rect2(Vector2(size.x - nw - 4.0, -6.0), Vector2(nw, 22.0))
		ci.draw_style_box(UIKit.lux("tag_new"), nr)
		ci.draw_string(nf, Vector2(nr.position.x + 7.0, nr.position.y + 16.5), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITokens.NEW_INK)


## The inner rim above the seam only (open at the bottom), as a polyline.
func _open_top(inner: PackedVector2Array, seam: float) -> PackedVector2Array:
	# inner = 8 points clockwise from the top-left chamfer: keep from left side up, across, down right.
	var out := PackedVector2Array()
	out.append(Vector2(inner[7].x, seam - 1.0))
	out.append(inner[7])
	out.append(inner[0])
	out.append(inner[1])
	out.append(inner[2])
	out.append(Vector2(inner[2].x, seam - 1.0))
	return out


class _ClipMask extends Control:
	var card: KitGemCard

	func _draw() -> void:
		card.draw_ground(self)


class _Overlay extends Control:
	var card: KitGemCard

	func _draw() -> void:
		card._draw_over(self)
