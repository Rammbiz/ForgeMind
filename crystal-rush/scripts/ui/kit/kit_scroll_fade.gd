class_name KitScrollFade
extends Control
## Soft edge fades over a ScrollContainer: the surface colour melts the content into the
## top / bottom edge instead of a hard crop through a row. Each fade shows only when there is
## content past that edge. Added as an INTERNAL child of the ScrollContainer, so it draws over
## the content, is never laid out as content and needs no wrapper.
##   UIKit.scroll_fade(sc, UIKit.CREAM)

var color := UITokens.PAPER_1
var bottom_h := 44.0
var top_h := 22.0
var _sc: ScrollContainer


static func attach(sc: ScrollContainer, p_color: Color, p_bottom := 44.0, p_top := 22.0) -> KitScrollFade:
	var f := KitScrollFade.new()
	f.color = p_color
	f.bottom_h = p_bottom
	f.top_h = p_top
	f._sc = sc
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.add_child(f, false, Node.INTERNAL_MODE_BACK)
	var bar := sc.get_v_scroll_bar()
	sc.sort_children.connect(f.queue_redraw)
	bar.value_changed.connect(func(_v: float): f.queue_redraw())
	bar.changed.connect(f.queue_redraw)
	sc.resized.connect(f.queue_redraw)
	return f


func _draw() -> void:
	if _sc == null:
		return
	var bar := _sc.get_v_scroll_bar()
	var over := bar.max_value - bar.page
	if over <= 1.0:
		return
	# Draw in the ScrollContainer's own space, whatever rect the container gave this node.
	draw_set_transform_matrix(get_transform().affine_inverse())
	var w := _sc.size.x
	var h := _sc.size.y
	var v := bar.value
	# Fade strength ramps in over the first / last 24 px of travel.
	var a_top := clampf(v / 24.0, 0.0, 1.0)
	var a_bot := clampf((over - v) / 24.0, 0.0, 1.0)
	var clear := Color(color, 0.0)
	if a_bot > 0.0 and bottom_h > 0.0:
		var c := Color(color, a_bot * 0.94)
		var y0 := h - bottom_h
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([clear, clear, c, c]))
	if a_top > 0.0 and top_h > 0.0:
		var c2 := Color(color, a_top)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, top_h), Vector2(0, top_h)]),
			PackedColorArray([c2, c2, clear, clear]))
