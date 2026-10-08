class_name KitTabs
extends Control
## UI v2 text tabs (Genshin underline style, no boxes): taupe labels; the active one is ink with
## an amber underline that carries a small crystal keystone and slides between tabs
## (UITokens.TAB_FADE). A faint gold hairline runs under the whole row.
##   var t := UIKit.tabs([["attr", "Атрибути"], ["skills", "Навички"]], "attr", _on_tab)

signal changed(id: String)

var options: Array = []
var selected := ""
var font_size := 26
var _row: HBoxContainer
var _ux := 0.0         ## underline centre x (animated)
var _uw := 0.0         ## underline width (animated)
var _ready_done := false


func setup(p_options: Array, p_selected: String, p_font_size := 26) -> void:
	options = p_options
	selected = p_selected
	font_size = p_font_size
	custom_minimum_size.y = font_size + 34.0


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", 0)
	add_child(_row)
	for o: Array in options:
		var b := Button.new()
		b.text = str(o[1])
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", font_size)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.set_meta("id", str(o[0]))
		b.pressed.connect(func(): select(str(o[0]), true))
		_row.add_child(b)
	_restyle()
	resized.connect(func(): _snap.call_deferred())
	_snap.call_deferred()
	_ready_done = true


func select(id: String, emit := false) -> void:
	if id == selected and _ready_done:
		return
	selected = id
	_restyle()
	var target := _target()
	if is_inside_tree() and not UITokens.reduce_motion():
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_ux, _ux, target.x, UITokens.TAB_FADE + 0.06)
		tw.tween_method(_set_uw, _uw, target.y, UITokens.TAB_FADE + 0.06)
	else:
		_ux = target.x
		_uw = target.y
		queue_redraw()
	if emit:
		Audio.play("click", -8.0)
		changed.emit(id)


func _set_ux(v: float) -> void:
	_ux = v
	queue_redraw()


func _set_uw(v: float) -> void:
	_uw = v
	queue_redraw()


func _restyle() -> void:
	if _row == null:
		return
	for b: Button in _row.get_children():
		var on := str(b.get_meta("id")) == selected
		var c := UITokens.INK if on else UITokens.INK_DIM
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, c)
		b.add_theme_font_override("font", UIKit.font_w("bold" if on else "medium"))


## Vector2(centre x, underline width) of the selected tab.
func _target() -> Vector2:
	if _row == null:
		return Vector2.ZERO
	for b: Button in _row.get_children():
		if str(b.get_meta("id")) == selected:
			var f := UIKit.font_w("bold")
			var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			return Vector2(b.position.x + b.size.x * 0.5, tw + 12.0)
	return Vector2.ZERO


func _snap() -> void:
	var t := _target()
	_ux = t.x
	_uw = t.y
	queue_redraw()


func _draw() -> void:
	var y := size.y - 1.0
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.6), 1.0, true)
	if _uw <= 0.0:
		return
	var uy := size.y - 4.0
	draw_line(Vector2(_ux - _uw * 0.5, uy), Vector2(_ux + _uw * 0.5, uy), UITokens.CTA_LO, 2.5, true)
	GemDraw.draw_keystone(self, Vector2(_ux, uy), 12.0, 1.0, Color(1.0, 0.9, 0.6))
