class_name HeroChip
extends Button
## Engraved cartouche chip (heroes_design.md §9.1: filter / Focus / History / Odds chips): a 56 px
## visual inside an 88 px hit area, 45-degree chamfer 6, cream with a gold hairline and an inner
## hairline 3 px in; active = gold fill + dark text. Optional leading icon (line icon, painted
## icon via HeroIcons, or a gem-cut mark with `gem`).
##   var c := HeroChip.make("Шанси", "odds")
##   c.pressed.connect(_open_odds)
##   var f := HeroChip.make("Топаз", "", "L"); f.active = true      # a gem filter chip

var label := "":
	set(v):
		label = v
		_resize()
var icon_kind := "":
	set(v):
		icon_kind = v
		_resize()
var gem := "":                   ## gem key: draws its cut mark as the icon
	set(v):
		gem = v
		_resize()
var active := false:
	set(v):
		active = v
		queue_redraw()
var label_size := 22
var visual_h := 56.0


static func make(p_label: String, p_icon := "", p_gem := "") -> HeroChip:
	var c := HeroChip.new()
	c.label = p_label
	c.icon_kind = p_icon
	c.gem = p_gem
	return c


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button_down.connect(func(): queue_redraw())
	button_up.connect(func(): queue_redraw())


func _ready() -> void:
	_resize()


func _icon_w() -> float:
	return visual_h * 0.56 if (icon_kind != "" or gem != "") else 0.0


func _resize() -> void:
	var f := UIKit.font_w("bold")
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x if label != "" else 0.0
	var iw := _icon_w()
	var w := tw + iw + (10.0 if iw > 0.0 and tw > 0.0 else 0.0) + 40.0
	custom_minimum_size = Vector2(maxf(w, UITokens.MIN_TOUCH), UITokens.MIN_TOUCH)
	queue_redraw()


func _draw() -> void:
	var vr := Rect2(Vector2(0, (size.y - visual_h) * 0.5), Vector2(size.x, visual_h))
	if is_pressed() or button_pressed and toggle_mode:
		vr.position.y += 1.0
	var pts := GemDraw.chamfer_rect(vr, UITokens.CHAMFER_XS)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 2))
	draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.1))
	if active:
		var cols := PackedColorArray()
		for p in pts:
			var t := (p.y - vr.position.y) / vr.size.y
			cols.append(Color("#F3D89A").lerp(Color("#D9AE5A"), t))
		draw_polygon(pts, cols)
	else:
		draw_colored_polygon(pts, UITokens.PAPER_3 if is_pressed() else UITokens.PAPER_0)
	GemDraw.outline(self, pts, UITokens.HAIRLINE if not active else Color("#A87A2C"), 1.5)
	var inner := GemDraw.chamfer_rect(vr.grow(-3.0), UITokens.CHAMFER_XS - 1.5)
	GemDraw.outline(self, inner, Color(1, 1, 1, 0.55) if active else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.35), 1.0)
	var f := UIKit.font_w("bold")
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x if label != "" else 0.0
	var iw := _icon_w()
	var gapw := 10.0 if iw > 0.0 and tw > 0.0 else 0.0
	var x := (size.x - (tw + iw + gapw)) * 0.5
	var cy := vr.get_center().y
	var ink := UIKit.BROWN if active else UITokens.INK
	if gem != "":
		GemDraw.draw_mark(self, UITokens.gem_of(gem), Vector2(x + iw * 0.5, cy), iw * 0.78)
	elif icon_kind != "":
		HeroIcons.paint(self, icon_kind, Rect2(Vector2(x, cy - iw * 0.5), Vector2(iw, iw)), ink)
	if label != "":
		draw_string(f, Vector2(x + iw + gapw, cy + f.get_ascent(label_size) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, ink)
