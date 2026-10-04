class_name RoundButton
extends Control
## Circular touch button with an icon (texture or vector), optional caption and badges.

signal pressed

var icon_texture: Texture2D
var icon_kind := ""
var icon_tint := Color.WHITE
var caption := ""
var caption_color := UIKit.TEXT
var caption_icon := ""          # e.g. "coin" drawn before caption text
var badge := ""                 # small text in the top-right corner
var radius := 44.0
var base_color := Color(0.1, 0.12, 0.2, 0.92)
var ring_color := UIKit.GOLD
var disabled := false
var armed := false              # waiting for a confirming second tap
var highlight := false          # pulsing outer glow in the ring colour (keeps the icon)
var progress := -1.0            # 0..1 draws an arc around the button
var progress_color := UIKit.GOLD
var pulse := false
var _press_scale := 1.0
var _down := false
var _t := 0.0


func _init(p_radius := 44.0) -> void:
	radius = p_radius
	custom_minimum_size = Vector2(radius * 2.0 + 8.0, radius * 2.0 + 8.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	var target := 0.9 if _down else 1.0
	_press_scale = lerpf(_press_scale, target, minf(1.0, delta * 18.0))
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	var c := _circle_center()
	if point.distance_to(c) <= radius + 10.0:
		return true
	# The caption pill under the circle is part of the button too.
	if caption != "":
		var w := UIKit.font(true).get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + (26.0 if caption_icon != "" else 0.0) + 24.0
		return Rect2(Vector2(c.x - w * 0.5, c.y + radius), Vector2(w, 36.0)).has_point(point)
	return false


func _circle_center() -> Vector2:
	return Vector2(size.x * 0.5, radius + 4.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			accept_event()
		elif _down:
			_down = false
			accept_event()
			if _has_point(event.position):
				pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_down = false


func _draw() -> void:
	var c := _circle_center()
	var s := _press_scale
	if pulse and not disabled:
		s *= 1.0 + sin(_t * 5.0) * 0.04
	var r := radius * s
	var dim := 0.45 if disabled else 1.0
	# Shadow
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, base_color.darkened(0.25 if disabled else 0.0))
	draw_circle(c + Vector2(0, -r * 0.12), r * 0.86, base_color.lightened(0.06))
	var ring := ring_color if not disabled else Color(0.4, 0.42, 0.48)
	if armed:
		ring = UIKit.GREEN
		draw_arc(c, r + 5.0, 0, TAU, 48, Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.35 + 0.25 * sin(_t * 8.0)), 6.0, true)
	if highlight and not armed:
		draw_arc(c, r + 5.0, 0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.35 + 0.3 * sin(_t * 8.0)), 6.0, true)
	draw_arc(c, r - 1.5, 0, TAU, 48, ring, 3.0, true)
	if progress >= 0.0:
		draw_arc(c, r + 6.0, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 48, progress_color, 5.0, true)
	var icon_size := r * 1.25
	var icon_rect := Rect2(c - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	var mod := Color(dim, dim, dim, 1.0) * icon_tint
	if armed:
		Icons.draw_icon(self, "check", icon_rect.grow(-icon_size * 0.1), UIKit.GREEN)
	elif icon_texture:
		var tex_rect := Rect2(c - Vector2(r, r) * 0.92, Vector2(r, r) * 1.84)
		draw_texture_rect(icon_texture, tex_rect, false, mod)
	elif icon_kind != "":
		Icons.draw_icon(self, icon_kind, icon_rect, mod)
	if badge != "":
		var f := UIKit.font(true)
		var bs := 20
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x + 14.0
		var br := Rect2(c + Vector2(r * 0.45, -r - 2.0), Vector2(maxf(bw, 28.0), 28.0))
		draw_style_box(UIKit.box(UIKit.PRIMARY, UIKit.PRIMARY_DARK, 14, 2, 0, Vector2.ZERO), br)
		draw_string(f, br.position + Vector2(7, 21), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(0.2, 0.08, 0.02))
	if caption != "":
		var f2 := UIKit.font(true)
		var fs := 22
		var tw := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var iw := 22.0 if caption_icon != "" else 0.0
		var total := tw + iw + (4.0 if iw > 0.0 else 0.0)
		var cap_y := c.y + r + 4.0
		var pill := Rect2(Vector2(c.x - total * 0.5 - 10.0, cap_y - 2.0), Vector2(total + 20.0, 30.0))
		draw_style_box(UIKit.box(Color(0.04, 0.05, 0.1, 0.85), Color(0, 0, 0, 0), 15, 0, 0, Vector2.ZERO), pill)
		var x := c.x - total * 0.5
		if iw > 0.0:
			Icons.draw_icon(self, caption_icon, Rect2(Vector2(x, cap_y + 2.0), Vector2(iw, iw)), Color(1, 1, 1, dim))
			x += iw + 4.0
		draw_string_outline(f2, Vector2(x, cap_y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(f2, Vector2(x, cap_y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, caption_color * Color(1, 1, 1, 1.0 if not disabled else 0.8))
