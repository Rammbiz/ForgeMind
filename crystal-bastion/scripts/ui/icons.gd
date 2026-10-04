class_name Icons
extends Control
## Vector icons drawn with CanvasItem primitives (no image assets needed).
## Use as a Control (set `kind`) or call Icons.draw_icon() from any _draw().

@export var kind := "coin"
@export var tint := Color.WHITE
@export var filled := true


static func make(p_kind: String, px := 36.0, p_tint := Color.WHITE) -> Icons:
	var i := Icons.new()
	i.kind = p_kind
	i.tint = p_tint
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s := minf(size.x, size.y)
	var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	draw_icon(self, kind, r, tint, filled)


func set_kind(k: String) -> void:
	kind = k
	queue_redraw()


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func _star_points(r: Rect2, inner := 0.42) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center() + Vector2(0, r.size.y * 0.04)
	var R := r.size.x * 0.5
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := R if i % 2 == 0 else R * inner
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func draw_icon(ci: CanvasItem, k: String, r: Rect2, tint := Color.WHITE, filled := true) -> void:
	var w := r.size.x
	var c := r.get_center()
	match k:
		"coin":
			ci.draw_circle(c + Vector2(0, w * 0.04), w * 0.46, Color(0.62, 0.36, 0.08) * tint)
			ci.draw_circle(c, w * 0.46, Color(1.0, 0.78, 0.25) * tint)
			ci.draw_circle(c, w * 0.33, Color(0.93, 0.62, 0.15) * tint)
			ci.draw_circle(c, w * 0.27, Color(1.0, 0.82, 0.3) * tint)
			ci.draw_rect(Rect2(c - Vector2(w * 0.05, w * 0.16), Vector2(w * 0.1, w * 0.32)), Color(0.93, 0.62, 0.15) * tint)
			ci.draw_circle(c + Vector2(-w * 0.2, -w * 0.22), w * 0.07, Color(1, 1, 0.85, 0.85) * tint)
		"heart":
			var col := Color(1.0, 0.3, 0.38) * tint
			var dark := Color(0.7, 0.1, 0.2) * tint
			for off in [Vector2(0, w * 0.04)]:
				ci.draw_circle(_p(r, 0.3, 0.36) + off, w * 0.24, dark)
				ci.draw_circle(_p(r, 0.7, 0.36) + off, w * 0.24, dark)
				ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.08, 0.46) + off, _p(r, 0.92, 0.46) + off, _p(r, 0.5, 0.94) + off]), dark)
			ci.draw_circle(_p(r, 0.3, 0.36), w * 0.24, col)
			ci.draw_circle(_p(r, 0.7, 0.36), w * 0.24, col)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.07, 0.43), _p(r, 0.93, 0.43), _p(r, 0.5, 0.9)]), col)
			ci.draw_circle(_p(r, 0.28, 0.3), w * 0.07, Color(1, 0.85, 0.88, 0.9) * tint)
		"swords":
			var blade := Color(0.88, 0.92, 1.0) * tint
			var hilt := Color(1.0, 0.75, 0.3) * tint
			for sgn in [-1.0, 1.0]:
				var a := _p(r, 0.5 - 0.36 * sgn, 0.14)
				var b := _p(r, 0.5 + 0.26 * sgn, 0.76)
				ci.draw_line(a, b, blade, w * 0.11, true)
				var g := _p(r, 0.5 + 0.2 * sgn, 0.66)
				var perp := Vector2(0.7, 0.7 * sgn) * w * 0.15
				ci.draw_line(g - perp, g + perp, hilt, w * 0.09, true)
				ci.draw_line(_p(r, 0.5 + 0.27 * sgn, 0.78), _p(r, 0.5 + 0.38 * sgn, 0.92), hilt.darkened(0.2), w * 0.1, true)
		"pause":
			ci.draw_rect(Rect2(_p(r, 0.24, 0.18), Vector2(w * 0.18, w * 0.64)), tint)
			ci.draw_rect(Rect2(_p(r, 0.58, 0.18), Vector2(w * 0.18, w * 0.64)), tint)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.28, 0.16), _p(r, 0.84, 0.5), _p(r, 0.28, 0.84)]), tint)
		"fast":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.1, 0.2), _p(r, 0.5, 0.5), _p(r, 0.1, 0.8)]), tint)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.48, 0.2), _p(r, 0.88, 0.5), _p(r, 0.48, 0.8)]), tint)
		"star":
			var pts := _star_points(r)
			if filled:
				ci.draw_colored_polygon(_star_points(Rect2(r.position + Vector2(0, w * 0.05), r.size)), Color(0.65, 0.38, 0.05) * tint)
				ci.draw_colored_polygon(pts, Color(1.0, 0.82, 0.25) * tint)
				ci.draw_colored_polygon(_star_points(r.grow(-w * 0.18), 0.42), Color(1.0, 0.9, 0.45) * tint)
			else:
				ci.draw_colored_polygon(pts, Color(0.2, 0.22, 0.3, 0.9) * tint)
				var outline := pts.duplicate()
				outline.append(pts[0])
				ci.draw_polyline(outline, Color(0.45, 0.48, 0.58) * tint, maxf(2.0, w * 0.05), true)
		"lock":
			ci.draw_arc(_p(r, 0.5, 0.42), w * 0.2, PI, TAU, 16, tint, w * 0.09, true)
			ci.draw_line(_p(r, 0.3, 0.42), _p(r, 0.3, 0.5), tint, w * 0.09)
			ci.draw_line(_p(r, 0.7, 0.42), _p(r, 0.7, 0.5), tint, w * 0.09)
			var body := Rect2(_p(r, 0.2, 0.48), Vector2(w * 0.6, w * 0.42))
			ci.draw_rect(body, tint)
			ci.draw_circle(_p(r, 0.5, 0.66), w * 0.06, Color(0.1, 0.1, 0.15))
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(c + dir * w * 0.28, c + dir * w * 0.46, tint, w * 0.16)
			ci.draw_circle(c, w * 0.32, tint)
			ci.draw_circle(c, w * 0.13, Color(0.08, 0.09, 0.16))
		"home":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.5, 0.1), _p(r, 0.92, 0.5), _p(r, 0.08, 0.5)]), tint)
			ci.draw_rect(Rect2(_p(r, 0.2, 0.46), Vector2(w * 0.6, w * 0.42)), tint)
			ci.draw_rect(Rect2(_p(r, 0.42, 0.62), Vector2(w * 0.16, w * 0.26)), Color(0.08, 0.09, 0.16))
		"restart":
			ci.draw_arc(c, w * 0.32, -PI * 0.15, PI * 1.45, 24, tint, w * 0.11, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * w * 0.32
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-w * 0.2, -w * 0.02), tip + Vector2(w * 0.12, -w * 0.06), tip + Vector2(-w * 0.02, w * 0.2)]), tint)
		"back":
			ci.draw_line(_p(r, 0.85, 0.5), _p(r, 0.25, 0.5), tint, w * 0.12, true)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.1, 0.5), _p(r, 0.42, 0.22), _p(r, 0.42, 0.78)]), tint)
		"check":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.18, 0.52), _p(r, 0.42, 0.76), _p(r, 0.84, 0.26)]), tint, w * 0.14, true)
		"close":
			ci.draw_line(_p(r, 0.22, 0.22), _p(r, 0.78, 0.78), tint, w * 0.13, true)
			ci.draw_line(_p(r, 0.78, 0.22), _p(r, 0.22, 0.78), tint, w * 0.13, true)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.5, 0.1), _p(r, 0.88, 0.5), _p(r, 0.64, 0.5), _p(r, 0.64, 0.88), _p(r, 0.36, 0.88), _p(r, 0.36, 0.5), _p(r, 0.12, 0.5)]), tint)
		"target":
			ci.draw_arc(c, w * 0.32, 0, TAU, 24, tint, w * 0.08, true)
			ci.draw_circle(c, w * 0.08, tint)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * w * 0.2, c + d * w * 0.48, tint, w * 0.08)
		"music":
			ci.draw_line(_p(r, 0.42, 0.72), _p(r, 0.42, 0.16), tint, w * 0.08)
			ci.draw_line(_p(r, 0.42, 0.16), _p(r, 0.8, 0.26), tint, w * 0.1)
			ci.draw_line(_p(r, 0.8, 0.26), _p(r, 0.8, 0.62), tint, w * 0.08)
			ci.draw_circle(_p(r, 0.32, 0.74), w * 0.13, tint)
			ci.draw_circle(_p(r, 0.7, 0.64), w * 0.13, tint)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.12, 0.36), _p(r, 0.3, 0.36), _p(r, 0.52, 0.16), _p(r, 0.52, 0.84), _p(r, 0.3, 0.64), _p(r, 0.12, 0.64)]), tint)
			ci.draw_arc(_p(r, 0.52, 0.5), w * 0.2, -PI / 3, PI / 3, 12, tint, w * 0.07, true)
			ci.draw_arc(_p(r, 0.52, 0.5), w * 0.36, -PI / 3, PI / 3, 12, tint, w * 0.07, true)
		"globe":
			ci.draw_arc(c, w * 0.4, 0, TAU, 28, tint, w * 0.07, true)
			ci.draw_line(_p(r, 0.1, 0.5), _p(r, 0.9, 0.5), tint, w * 0.06)
			ci.draw_line(_p(r, 0.5, 0.1), _p(r, 0.5, 0.9), tint, w * 0.06)
			ci.draw_arc(c, w * 0.4, -PI / 2, PI / 2, 16, tint, w * 0.05, true)
		"crystal":
			var pts := PackedVector2Array([_p(r, 0.5, 0.04), _p(r, 0.8, 0.4), _p(r, 0.5, 0.96), _p(r, 0.2, 0.4)])
			ci.draw_colored_polygon(pts, Color(0.35, 0.85, 1.0) * tint)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.5, 0.04), _p(r, 0.5, 0.96), _p(r, 0.2, 0.4)]), Color(0.65, 0.95, 1.0) * tint)
		"skull":
			ci.draw_circle(_p(r, 0.5, 0.42), w * 0.34, tint)
			ci.draw_rect(Rect2(_p(r, 0.3, 0.58), Vector2(w * 0.4, w * 0.28)), tint)
			ci.draw_circle(_p(r, 0.36, 0.44), w * 0.1, Color(0.08, 0.09, 0.16))
			ci.draw_circle(_p(r, 0.64, 0.44), w * 0.1, Color(0.08, 0.09, 0.16))
			for i in 3:
				ci.draw_line(_p(r, 0.38 + i * 0.12, 0.72), _p(r, 0.38 + i * 0.12, 0.86), Color(0.08, 0.09, 0.16), w * 0.04)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.58, 0.05), _p(r, 0.22, 0.55), _p(r, 0.48, 0.55), _p(r, 0.38, 0.95), _p(r, 0.8, 0.4), _p(r, 0.52, 0.4)]), tint)
		"slam":
			# A fist pounding the ground with impact lines.
			ci.draw_rect(Rect2(_p(r, 0.3, 0.08), Vector2(w * 0.4, w * 0.36)), tint)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.3, 0.44), _p(r, 0.7, 0.44), _p(r, 0.5, 0.6)]), tint)
			ci.draw_line(_p(r, 0.06, 0.86), _p(r, 0.94, 0.86), tint, w * 0.08)
			for sgn in [-1.0, 1.0]:
				ci.draw_line(_p(r, 0.5 + 0.2 * sgn, 0.72), _p(r, 0.5 + 0.36 * sgn, 0.6), tint, w * 0.06)
				ci.draw_line(_p(r, 0.5 + 0.12 * sgn, 0.7), _p(r, 0.5 + 0.18 * sgn, 0.56), tint, w * 0.05)
		"wing":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.08, 0.3), _p(r, 0.5, 0.55), _p(r, 0.92, 0.3), _p(r, 0.78, 0.7), _p(r, 0.62, 0.6), _p(r, 0.5, 0.78), _p(r, 0.38, 0.6), _p(r, 0.22, 0.7)]), tint)
		_:
			ci.draw_circle(c, w * 0.4, tint)
