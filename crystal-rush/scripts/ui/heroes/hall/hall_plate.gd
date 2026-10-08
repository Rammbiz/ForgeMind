class_name HeroesHallPlate
extends Control
## A Hall header plate (heroes_design.md §9.2): the Portal plate (L20) and the Workshop plate
## (L32). A cream card with one gold hairline and, at its left, a small chamfered "window" into
## the place it opens: the Portal's night sky with its ring (the one place dark is allowed), the
## Workshop's warm forge light with a Star Ore crystal. `frosted` = the teaser state two levels
## before the unlock (dimmed, a lock, «Майстерня · після рівня 32»). The Portal plate never has
## a badge (§9.2).
##   var p := HeroesHallPlate.make("portal", "Портал", "7 маяків · Топаз або краще ≤ 18")
##   p.pressed.connect(func(): HeroesNav.open(hub, "portal"))

signal pressed

const H := 104.0

var kind := "portal"
var frosted := false
## Two plates side by side: a narrower window, no chevron (the whole plate is the button).
var compact := false
var _title: Label
var _sub: Label
var _down := false


static func make(p_kind: String, title: String, sub: String, p_frosted := false) -> HeroesHallPlate:
	var p := HeroesHallPlate.new()
	p.kind = p_kind
	p.frosted = p_frosted
	p._title.text = title
	p._sub.text = sub
	return p


func _init() -> void:
	custom_minimum_size = Vector2(0, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	_title = UIKit.label("", 28, UITokens.INK, true)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_title)
	_sub = UIKit.label("", 22, UITokens.INK_DIM)
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_sub)
	resized.connect(_layout)


func _ready() -> void:
	_layout()
	if frosted:
		_title.add_theme_color_override("font_color", UITokens.INK_DIM)


func _win() -> Rect2:
	return Rect2(Vector2(10, 10), Vector2(76.0 if compact else H - 20.0, size.y - 20.0))


func _layout() -> void:
	var col := get_child(0) as Control
	var x := _win().end.x + (12.0 if compact else 16.0)
	custom_minimum_size.y = maxf(H, col.get_combined_minimum_size().y + 18.0)
	col.position = Vector2(x, 0)
	col.size = Vector2(maxf(10.0, size.x - x - (12.0 if compact and not frosted else 40.0)), size.y)
	if compact:
		_title.add_theme_font_size_override("font_size", 26)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_down = e.pressed
		queue_redraw()
	if UIJuice.is_tap(e):
		UIJuice.press(self)
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _down:
		r.position.y += 1.0
	draw_style_box(UIKit.lux("card"), r)
	var w := _win()
	w.position.y += r.position.y
	var pts := GemDraw.chamfer_rect(w, UITokens.CHAMFER_S)
	var cols := PackedColorArray()
	var a := 0.55 if frosted else 1.0
	for p in pts:
		var t := (p.y - w.position.y) / w.size.y
		if kind == "portal":
			cols.append(Color("#1A1530").lerp(Color("#3A2D63"), t) * Color(1, 1, 1, a))
		else:
			cols.append(Color("#FBE3BC").lerp(Color("#E8AE5C"), t) * Color(1, 1, 1, a))
	draw_polygon(pts, cols)
	var c := w.get_center()
	var isz := minf(60.0, w.size.x * 0.72)
	if kind == "portal":
		# A few still glints of the night sky (never stars as rarity), the ring's soft violet bloom.
		var g := UIKit.glow_texture()
		draw_texture_rect(g, Rect2(c - w.size * 0.55, w.size * 1.1), false, Color(0.69, 0.42, 1.0, 0.45 * a))
		for gp: Vector2 in [Vector2(0.2, 0.22), Vector2(0.78, 0.3), Vector2(0.3, 0.8), Vector2(0.84, 0.74)]:
			GemDraw.draw_glint(self, w.position + w.size * gp, 7.0, Color(1, 0.97, 0.9, 0.75 * a))
		Icons.line(self, "portal", Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, a))
	else:
		var g2 := UIKit.glow_texture()
		draw_texture_rect(g2, Rect2(c - w.size * 0.5, w.size), false, Color(1.0, 0.95, 0.8, 0.7 * a))
		HeroIcons.paint(self, "ore", Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), Color(1, 1, 1, a))
	GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)
	var inner := GemDraw.chamfer_rect(w.grow(-3.0), UITokens.CHAMFER_S - 1.5)
	GemDraw.outline(self, inner, Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.4 * a), 1.0)
	# Right end: a chevron (open) or a lock (frosted teaser).
	var ic := Rect2(Vector2(size.x - 40.0, r.position.y + size.y * 0.5 - 13.0), Vector2(26, 26))
	if frosted:
		Icons.draw_icon(self, "lock", ic, UITokens.INK_DIM)
	elif not compact:
		Icons.line(self, "chevron", ic, UITokens.GOLD_TEXT)
