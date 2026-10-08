class_name KitCurrencyPlate
extends Control
## UI v2 currency plate (top bar): a porcelain chamfered plate (lux "plate"), the painted
## currency icon overlapping its left end, a Bold tabular value and an optional "+" disc.
## `value_label` is a real Label, so odometers / count-ups can drive it.
## Bitmap overrides: plate.png (nine-patch via lux), icon_<kind>.png for the icon.

signal plus_pressed
signal pressed

var icon := "coin":
	set(v):
		icon = v
		queue_redraw()
var value := "0":
	set(v):
		value = v
		if value_label:
			value_label.text = v
var plus := false:
	set(v):
		plus = v
		_layout()
		queue_redraw()
var value_label: Label
var _plus_down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	value_label = UIKit.label(value, 24, UIKit.INK, true)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(value_label)
	resized.connect(_layout)
	_layout()


func _icon_size() -> float:
	return size.y * 0.92


func _layout() -> void:
	if value_label == null:
		return
	var ic := _icon_size()
	var x0 := ic * 0.62
	var x1 := size.x - (size.y * 0.7 if plus else 12.0)
	value_label.position = Vector2(x0, 0)
	value_label.size = Vector2(maxf(x1 - x0, 10.0), size.y)


func _gui_input(e: InputEvent) -> void:
	if UIJuice.is_tap(e):
		var p := (e as InputEventMouseButton).position
		if plus and p.x > size.x - size.y:
			plus_pressed.emit()
		else:
			pressed.emit()


func _draw() -> void:
	var ic := _icon_size()
	var plate := Rect2(Vector2(ic * 0.38, size.y * 0.1), Vector2(size.x - ic * 0.38, size.y * 0.8))
	draw_style_box(UIKit.lux("plate"), plate)
	if plus:
		var pc := Vector2(size.x - size.y * 0.42, size.y * 0.5)
		var pr := size.y * 0.27
		draw_circle(pc, pr, UITokens.PAPER_2)
		draw_arc(pc, pr - 0.5, 0, TAU, 32, UITokens.HAIRLINE, 1.2, true)
		var k := pr * 0.5
		draw_line(pc - Vector2(k, 0), pc + Vector2(k, 0), UITokens.GOLD_TEXT, 2.2, true)
		draw_line(pc - Vector2(0, k), pc + Vector2(0, k), UITokens.GOLD_TEXT, 2.2, true)
	Icons.draw_icon(self, icon, Rect2(Vector2(0, (size.y - ic) * 0.5), Vector2(ic, ic)))
