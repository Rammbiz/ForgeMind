class_name HeroHScrollFade
extends Control
## Soft LEFT / RIGHT edge fades over a horizontally scrolling ScrollContainer (the Hall's filter
## chips, any chip rail): the surface colour melts the row into the edge, so a chip is never cut
## mid-glyph and the fade itself says "more this way". Each side shows only when there is content
## past it. The horizontal twin of the kit's KitScrollFade (which fades top / bottom); added as an
## INTERNAL child, so it draws over the content and is never laid out.
##   HeroHScrollFade.attach(chip_scroll, UITokens.PAPER_1)

var color := UITokens.PAPER_1
var width := 56.0
var _sc: ScrollContainer


static func attach(sc: ScrollContainer, p_color: Color, p_width := 56.0) -> HeroHScrollFade:
	var f := HeroHScrollFade.new()
	f.color = p_color
	f.width = p_width
	f._sc = sc
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.add_child(f, false, Node.INTERNAL_MODE_BACK)
	var bar := sc.get_h_scroll_bar()
	sc.sort_children.connect(f.queue_redraw)
	bar.value_changed.connect(func(_v: float): f.queue_redraw())
	bar.changed.connect(f.queue_redraw)
	sc.resized.connect(f.queue_redraw)
	return f


func _draw() -> void:
	if _sc == null:
		return
	var bar := _sc.get_h_scroll_bar()
	var over := bar.max_value - bar.page
	if over <= 1.0:
		return
	draw_set_transform_matrix(get_transform().affine_inverse())
	var w := _sc.size.x
	var h := _sc.size.y
	var v := bar.value
	var a_l := clampf(v / 24.0, 0.0, 1.0)
	var a_r := clampf((over - v) / 24.0, 0.0, 1.0)
	var clear := Color(color, 0.0)
	if a_r > 0.0:
		var c := Color(color, a_r)
		var x0 := w - width
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(w, 0), Vector2(w, h), Vector2(x0, h)]),
			PackedColorArray([clear, c, c, clear]))
	if a_l > 0.0:
		var c2 := Color(color, a_l)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, h), Vector2(0, h)]),
			PackedColorArray([c2, clear, clear, c2]))
