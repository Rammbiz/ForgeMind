class_name KitGemCard
extends Control
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
var footer := "":
	set(v):
		footer = v
		_redraw_all()
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
var footer_ratio := 0.21       ## footer strip height / card height
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
	var fh := _footer_h()
	art.offset_bottom = -fh * 0.5
	content.offset_bottom = -fh


func _footer_h() -> float:
	return roundf(size.y * footer_ratio)


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
	# Soft shadow under the card.
	for i in 4:
		var o := Vector2(0, 2.0 + i * 1.6)
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
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(size.x * 0.5 - R, size.y * 0.36 - R), Vector2(R, R) * 2.0), false, Color(lc.r, lc.g, lc.b, 0.22))
	_draw_fracture(ci, gem, Rect2(Vector2.ZERO, size))


static func _draw_fracture(ci: CanvasItem, gk: String, r: Rect2) -> void:
	var a := 0.11
	var col := Color(1, 1, 1, a)
	var w := r.size.x
	var h := r.size.y
	var c := r.get_center()
	match gk:
		"quartz":
			var step := w * 0.32
			for i in range(-6, 7):
				var o := c + Vector2(i * step, 0)
				for ang: float in [PI / 3.0, 2.0 * PI / 3.0]:
					var d := Vector2(cos(ang), sin(ang)) * h
					ci.draw_line(o - d, o + d, col, 1.0, true)
		"sapphire":
			var step := w * 0.2
			var rot := deg_to_rad(12.0)
			var ux := Vector2(cos(rot), sin(rot))
			var uy := Vector2(-ux.y, ux.x)
			for i in range(-8, 9):
				ci.draw_line(c + ux * i * step - uy * h, c + ux * i * step + uy * h, col, 1.0, true)
				ci.draw_line(c + uy * i * step - ux * h, c + uy * i * step + ux * h, col, 1.0, true)
		"amethyst":
			var step := w * 0.34
			for ang: float in [PI / 6.0, PI / 2.0, 5.0 * PI / 6.0]:
				var d := Vector2(cos(ang), sin(ang))
				var n := Vector2(-d.y, d.x)
				for i in range(-5, 6):
					ci.draw_line(c + n * i * step - d * h, c + n * i * step + d * h, col, 1.0, true)
		"topaz":
			var o := Vector2(c.x, r.position.y + h * 0.3)
			for i in 5:
				var ang := -PI / 2.0 + TAU * i / 5.0
				var d := Vector2(cos(ang), sin(ang))
				var n := Vector2(-d.y, d.x) * w * 0.05
				ci.draw_colored_polygon(PackedVector2Array([o, o + d * h + n, o + d * h - n]), Color(1, 0.95, 0.8, 0.08))
				ci.draw_line(o, o + d * h, Color(1, 0.96, 0.85, 0.14), 1.0, true)
		"opal":
			for i in 5:
				var cc := Vector2(r.position.x + w * (0.2 + 0.15 * i), r.position.y + h * (0.9 - 0.12 * i))
				ci.draw_arc(cc, w * (0.35 + 0.1 * i), PI * 1.1, PI * 1.9, 24, Color(0.85, 0.8, 1.0, 0.12), 1.0, true)


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
	ci.draw_colored_polygon(foot, UITokens.PAPER_2 if not dim else UITokens.PAPER_3)
	ci.draw_line(Vector2(0, seam), Vector2(size.x, seam), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), 1.0, true)
	var f := UIKit.font_w("bold")
	var fm := UIKit.font_w("medium")
	var ts := int(clampf(fh * 0.36, 16.0, 26.0))
	var ss := int(clampf(fh * 0.27, 14.0, 20.0))
	var pip_room := 8.0 if pips >= 0 else 0.0
	if title != "":
		var fs := ts
		while fs > 13 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16.0:
			fs -= 1
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ty := seam + pip_room + (fh - pip_room) * (0.48 if footer != "" else 0.62)
		ci.draw_string(f, Vector2((size.x - tw) * 0.5, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK if not dim else UITokens.INK_DIM)
	if footer != "":
		var fw := fm.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
		var fy := size.y - fh * 0.14
		ci.draw_string(fm, Vector2((size.x - fw) * 0.5, fy), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, UITokens.INK_DIM)
	# Frame: inner 1 px rim in the gem's light tone, outer gold hairline.
	var inner := GemDraw.chamfer_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), maxf(ch - 1.5, 1.0))
	var rim: Color = g["rim"] if not dim else UITokens.PAPER_3
	ci.draw_polyline(_open_top(inner, seam), Color(rim.r, rim.g, rim.b, 0.75), 1.0, true)
	var ftex := UIKit.kit_texture("card_frame")
	if ftex:
		ci.draw_style_box(UIKit.lux("card_frame"), Rect2(Vector2.ZERO, size))
	else:
		GemDraw.outline(ci, pts, UITokens.HAIRLINE, 1.5)
	# Facet pips on the seam.
	if pips >= 0 and pip_count > 0:
		var ps := clampf(size.x * 0.07, 10.0, 16.0)
		var gapx := ps * 0.95
		var total := gapx * (pip_count - 1)
		var light: Color = g["rim"] if gem != "opal" else Color("#E8D8FF")
		# Cream bed behind the pips so they read on any ground.
		var bed := Rect2(Vector2((size.x - total) * 0.5 - ps * 0.7, seam - ps * 0.55), Vector2(total + ps * 1.4, ps * 1.1))
		ci.draw_colored_polygon(GemDraw.chamfer_rect(bed, ps * 0.5), UITokens.PAPER_2 if not dim else UITokens.PAPER_3)
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
