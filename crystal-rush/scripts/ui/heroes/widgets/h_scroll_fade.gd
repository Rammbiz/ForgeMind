class_name HeroHScrollFade
extends Control
## Soft edge fades over a scrolling ScrollContainer: the CONTENT dissolves into the edge (an alpha
## mask, never paint laid over it), so a chip or card is never cut flat and the fade itself says
## "more this way". Each edge fades only when there is content past it.
##  * horizontal (attach): the LEFT / RIGHT ends of a chip rail (the Hall's filter chips);
##  * vertical (attach_v): the TOP / BOTTOM of a sheet's list (the summon sheets' Opal cards).
## The fade is a clip_children mask: this Control wraps the ScrollContainer (it takes the scroll's
## place in its parent), draws a white ramp that is never shown, and its alpha multiplies every
## descendant. No paint over the translucent backdrop, so no box can show. The mask covers exactly
## this rect (a clip_children capture outside the item's rect is not defined in gl_compatibility).
##   HeroHScrollFade.attach(chip_scroll, UITokens.PAPER_1, 72.0)   # once chip_scroll is parented
##   HeroHScrollFade.attach_v(list_scroll, 64.0, 22.0)

var width := 56.0                ## horizontal: fade length at each end
var vertical := false
var bottom_h := 64.0             ## vertical: fade length at the bottom / top edge
var top_h := 22.0
var _sc: ScrollContainer


## Wraps `sc` (already added to its parent) in the horizontal fade mask. `_p_color` is unused
## (kept for the older call sites); `p_width` is the fade length at each end.
static func attach(sc: ScrollContainer, _p_color := Color.WHITE, p_width := 56.0) -> HeroHScrollFade:
	var f := HeroHScrollFade.new()
	f.width = p_width
	f._wrap(sc)
	return f


## Wraps `sc` in the vertical fade mask (`p_bottom` / `p_top` fade lengths).
static func attach_v(sc: ScrollContainer, p_bottom := 64.0, p_top := 22.0) -> HeroHScrollFade:
	var f := HeroHScrollFade.new()
	f.vertical = true
	f.bottom_h = p_bottom
	f.top_h = p_top
	f._wrap(sc)
	return f


func _wrap(sc: ScrollContainer) -> void:
	_sc = sc
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	size_flags_horizontal = sc.size_flags_horizontal
	size_flags_vertical = sc.size_flags_vertical
	size_flags_stretch_ratio = sc.size_flags_stretch_ratio
	var parent := sc.get_parent()
	if parent:
		var idx := sc.get_index()
		parent.remove_child(sc)
		parent.add_child(self)
		parent.move_child(self, idx)
	add_child(sc)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for b: ScrollBar in [sc.get_h_scroll_bar(), sc.get_v_scroll_bar()]:
		b.value_changed.connect(func(_v: float): queue_redraw())
		b.changed.connect(queue_redraw)
	sc.sort_children.connect(queue_redraw)
	resized.connect(queue_redraw)
	# The wrapper's minimum size is the scroll's (it may change later: a sheet sizing its list).
	sc.minimum_size_changed.connect(update_minimum_size)
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	return _sc.get_combined_minimum_size() if _sc else Vector2.ZERO


static func _ss(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _draw() -> void:
	# Edge alphas: 1 = opaque (no fade), 0 = the content fully dissolves at that edge.
	var a0 := 1.0
	var a1 := 1.0
	if _sc:
		var bar: ScrollBar = _sc.get_v_scroll_bar() if vertical else _sc.get_h_scroll_bar()
		var over := bar.max_value - bar.page
		if over > 1.0:
			var v := bar.value
			a0 = 1.0 - clampf(v / 24.0, 0.0, 1.0)
			a1 = 1.0 - clampf((over - v) / 24.0, 0.0, 1.0)
	var L := size.y if vertical else size.x
	var f0 := minf(top_h if vertical else width, L * 0.3)
	var f1 := minf(bottom_h if vertical else width, L * 0.3)
	# Stops along the scroll axis: a smoothstep ramp at each edge (5 steps), opaque between.
	var st := PackedFloat32Array()
	var al := PackedFloat32Array()
	var n := 5
	for i in n + 1:
		var t := float(i) / n
		st.append(f0 * t)
		al.append(lerpf(a0, 1.0, _ss(t)))
	for i in n + 1:
		var t := float(i) / n
		st.append(L - f1 + f1 * t)
		al.append(lerpf(1.0, a1, _ss(t)))
	var cross := size.x if vertical else size.y
	for i in st.size() - 1:
		var c0 := Color(1, 1, 1, al[i])
		var c1 := Color(1, 1, 1, al[i + 1])
		if vertical:
			draw_polygon(PackedVector2Array([Vector2(0, st[i]), Vector2(cross, st[i]), Vector2(cross, st[i + 1]), Vector2(0, st[i + 1])]),
				PackedColorArray([c0, c0, c1, c1]))
		else:
			draw_polygon(PackedVector2Array([Vector2(st[i], 0), Vector2(st[i + 1], 0), Vector2(st[i + 1], cross), Vector2(st[i], cross)]),
				PackedColorArray([c0, c1, c1, c0]))


## A PAINTED vertical fade for lists whose content already clips itself (cards use clip_children,
## and nested clip groups do not compose in gl_compatibility): the bed colour ramps (smoothstep) to
## FULL strength and holds it for the last `hold` px, so the content never meets the edge as a flat
## crop (the kit's KitScrollFade stops at 0.94 at the very edge). Internal child of the scroll.
##   HeroHScrollFade.paint_v(list_scroll, UITokens.PAPER_0, 88.0, 22.0)
static func paint_v(sc: ScrollContainer, color := UITokens.PAPER_0, p_bottom := 88.0, p_top := 22.0, hold := 12.0) -> Control:
	var f := _PaintV.new()
	f.color = color
	f.bottom_h = p_bottom
	f.top_h = p_top
	f.hold = hold
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


class _PaintV extends Control:
	var color := UITokens.PAPER_0
	var bottom_h := 88.0
	var top_h := 22.0
	var hold := 12.0
	var _sc: ScrollContainer

	func _draw() -> void:
		if _sc == null:
			return
		var bar := _sc.get_v_scroll_bar()
		var over := bar.max_value - bar.page
		if over <= 1.0:
			return
		draw_set_transform_matrix(get_transform().affine_inverse())
		var w := _sc.size.x
		var h := _sc.size.y
		var v := bar.value
		var a_top := clampf(v / 24.0, 0.0, 1.0)
		var a_bot := clampf((over - v) / 24.0, 0.0, 1.0)
		var n := 6
		if a_bot > 0.0:
			var y0 := h - bottom_h
			var ramp := bottom_h - hold
			for i in n:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				var c0 := Color(color, a_bot * HeroHScrollFade._ss(t0))
				var c1 := Color(color, a_bot * HeroHScrollFade._ss(t1))
				draw_polygon(PackedVector2Array([Vector2(0, y0 + ramp * t0), Vector2(w, y0 + ramp * t0), Vector2(w, y0 + ramp * t1), Vector2(0, y0 + ramp * t1)]),
					PackedColorArray([c0, c0, c1, c1]))
			draw_rect(Rect2(0, h - hold, w, hold), Color(color, a_bot))
		if a_top > 0.0:
			for i in n:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				var c0 := Color(color, a_top * (1.0 - HeroHScrollFade._ss(t0)))
				var c1 := Color(color, a_top * (1.0 - HeroHScrollFade._ss(t1)))
				draw_polygon(PackedVector2Array([Vector2(0, top_h * t0), Vector2(w, top_h * t0), Vector2(w, top_h * t1), Vector2(0, top_h * t1)]),
					PackedColorArray([c0, c0, c1, c1]))
