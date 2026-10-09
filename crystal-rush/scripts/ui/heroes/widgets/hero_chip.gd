class_name HeroChip
extends Button
## Glass chip (heroes_design.md §9.1: filter / Focus / History / Odds chips; UI v3.1 §7.4): a 56 px
## visual inside an 88 px hit area, 45-degree chamfer 6, frameless translucent cream with a 1 dpx
## light line; active = cream 0.94 with one 1 dpx deep-gold line and deep-gold Medium ink. Optional leading icon (line icon, painted
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
## Over painted art (the Showcase dock): the inactive chip is real glass (0.84 with its 1 dpx
## gold line) instead of the frameless page chip, so its label keeps >= 4.5:1 on any art.
var on_art := false
## On the Portal night (porcelain): ink glass with one 1 dpx grey-blue line, warm-white label and
## icon (never a light chip competing with the porcelain key button on the dark screen).
var on_night := false


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
	var f := UIKit.font_w("medium")
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x if label != "" else 0.0
	var iw := _icon_w()
	var w := tw + iw + (10.0 if iw > 0.0 and tw > 0.0 else 0.0) + 40.0
	custom_minimum_size = Vector2(maxf(w, UITokens.MIN_TOUCH), UITokens.MIN_TOUCH)
	queue_redraw()


func _draw() -> void:
	# v3.1 (§7.4, §3.2): a frameless glass chip (translucent cream, a 1 dpx inner light line, no
	# gold frame, no drop shadow); active = the selected-segment idiom: cream 0.94 with ONE 1 dpx
	# deep-gold line and deep-gold ink (never an amber fill: amber is for the key verbs only).
	var vr := Rect2(Vector2(0, (size.y - visual_h) * 0.5), Vector2(size.x, visual_h))
	var down := is_pressed() or (button_pressed and toggle_mode)
	if on_night and not active:
		var pts := GemDraw.chamfer_rect(vr, UITokens.CHAMFER_XS)
		draw_colored_polygon(pts, UITokens.NIGHT_GLASS_DOWN if down else UITokens.NIGHT_GLASS)
		HeroV3.frame(self, pts, UITokens.NIGHT_LINE)
	elif active:
		HeroV3.glass(self, vr, UITokens.CHAMFER_XS, 0.94, HeroV3.DEEP, 0.9, 0.7)
	elif on_art:
		HeroV3.glass(self, vr, UITokens.CHAMFER_XS, 0.9 if down else 0.84, HeroV3.GOLD, 0.8, 0.62, 0.08,
				UITokens.PAPER_3 if down else UITokens.PAPER_0)
	else:
		# A quiet frameless well: reads as a tappable tile on the frosted page AND on a text bed.
		HeroV3.glass(self, vr, UITokens.CHAMFER_XS, 0.62 if down else 0.42, HeroV3.GOLD, 0.0, 0.55,
				0.0, UITokens.PAPER_3)
	var f := UIKit.font_w("medium")
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x if label != "" else 0.0
	var iw := _icon_w()
	var gapw := 10.0 if iw > 0.0 and tw > 0.0 else 0.0
	var x := (size.x - (tw + iw + gapw)) * 0.5
	var cy := vr.get_center().y
	var ink := UITokens.GOLD_TEXT_GLASS if active else (UITokens.ON_SCENE if on_night else UITokens.INK)
	if gem != "":
		GemDraw.draw_mark(self, UITokens.gem_of(gem), Vector2(x + iw * 0.5, cy), iw * 0.78, 1.0 if active else 0.92)
	elif icon_kind != "":
		HeroIcons.paint(self, icon_kind, Rect2(Vector2(x, cy - iw * 0.5), Vector2(iw, iw)), ink)
	if label != "":
		draw_string(f, Vector2(x + iw + gapw, cy + f.get_ascent(label_size) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, ink)
