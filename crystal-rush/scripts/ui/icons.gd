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


static func _pts(r: Rect2, xy: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i + 1 < xy.size():
		out.append(_p(r, xy[i], xy[i + 1]))
		i += 2
	return out


static func _star_points(r: Rect2, inner := 0.42) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center() + Vector2(0, r.size.y * 0.04)
	var R := r.size.x * 0.5
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := R if i % 2 == 0 else R * inner
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


## Ink colour for sticker-style outlines (alpha follows the tint of the icon being drawn).
const INK_BASE := Color(0.04, 0.05, 0.12, 1.0)
static var INK := INK_BASE

static var _sb: StyleBoxFlat


## Filled rounded rect (radius in px).
static func _rr(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
		_sb.corner_detail = 8
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) * 0.5)))
	ci.draw_style_box(_sb, rect)


## Polygon with a cartoon outline straddling its edge.
static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ow: float) -> void:
	var ink := INK
	if ow > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, ow * 2.0, true)
		for p in pts:
			ci.draw_circle(p, ow, ink)
	ci.draw_colored_polygon(pts, fill)


## Thick capsule line with an ink outline (outline pass and fill pass are separate so several
## strokes can share one outline: call with fill=false first for all, then fill=true).
static func _stroke(ci: CanvasItem, a: Vector2, b: Vector2, width: float, col: Color, ow: float, fill := true) -> void:
	if not fill:
		ci.draw_line(a, b, INK, width + ow * 2.0)
		ci.draw_circle(a, width * 0.5 + ow, INK)
		ci.draw_circle(b, width * 0.5 + ow, INK)
		return
	ci.draw_line(a, b, col, width)
	ci.draw_circle(a, width * 0.5, col)
	ci.draw_circle(b, width * 0.5, col)


static func _disc(ci: CanvasItem, c: Vector2, rad: float, col: Color, ow: float) -> void:
	if ow > 0.0:
		ci.draw_circle(c, rad + ow, INK)
	ci.draw_circle(c, rad, col)


## Soft additive-looking glow made of stacked translucent discs.
static func _glow(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	for i in 5:
		var k := 1.0 - i * 0.18
		ci.draw_circle(c, rad * k, Color(col.r, col.g, col.b, col.a * 0.22))


## A rocket from `tail` towards `dir` (pixels), body width `bw`.
static func _rocket(ci: CanvasItem, tail: Vector2, dir: Vector2, length: float, bw: float, body: Color, nose: Color, ow: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	var nose_at := tail + dir * length
	var neck := tail + dir * length * 0.66
	# Flame
	var fl := PackedVector2Array([tail + n * bw * 0.35, tail - dir * bw * 1.6, tail - n * bw * 0.35])
	ci.draw_colored_polygon(PackedVector2Array([tail + n * bw * 0.55, tail - dir * bw * 2.3, tail - n * bw * 0.55]), Color(1.0, 0.45, 0.1, 0.85))
	ci.draw_colored_polygon(fl, Color(1.0, 0.92, 0.5))
	# Fins
	var fin1 := PackedVector2Array([tail + dir * bw * 1.1 + n * bw * 0.5, tail + n * bw * 1.15 - dir * bw * 0.1, tail + n * bw * 0.5])
	var fin2 := PackedVector2Array([tail + dir * bw * 1.1 - n * bw * 0.5, tail - n * bw * 0.5, tail - n * bw * 1.15 - dir * bw * 0.1])
	_poly(ci, fin1, nose.darkened(0.15), ow)
	_poly(ci, fin2, nose.darkened(0.15), ow)
	# Body + nose
	var bpts := PackedVector2Array([tail + n * bw * 0.5, neck + n * bw * 0.5, nose_at, neck - n * bw * 0.5, tail - n * bw * 0.5])
	_poly(ci, bpts, body, ow)
	ci.draw_colored_polygon(PackedVector2Array([neck + n * bw * 0.5, nose_at, neck - n * bw * 0.5]), nose)
	ci.draw_line(neck + n * bw * 0.5, neck - n * bw * 0.5, INK, maxf(1.0, ow * 0.8))
	ci.draw_line(tail + n * bw * 0.2 + dir * bw * 0.4, neck + n * bw * 0.2, Color(1, 1, 1, 0.55), bw * 0.16)


static func draw_icon(ci: CanvasItem, k: String, r: Rect2, tint := Color.WHITE, filled := true) -> void:
	INK = Color(INK_BASE.r, INK_BASE.g, INK_BASE.b, tint.a)
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
				if w >= 20.0:
					var ol := pts.duplicate()
					ol.append(pts[0])
					ci.draw_polyline(ol, Color(0.45, 0.22, 0.02, 0.9) * tint, maxf(1.0, w * 0.04), true)
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
		"storm":
			# A lightning bolt inside a swirling vortex.
			for arm in 3:
				var a0 := arm * TAU / 3.0
				ci.draw_arc(c, w * (0.44 - arm * 0.03), a0, a0 + 1.6, 12, tint, w * 0.07)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.56, 0.2), _p(r, 0.34, 0.54), _p(r, 0.49, 0.54), _p(r, 0.43, 0.8), _p(r, 0.67, 0.45), _p(r, 0.52, 0.45)]), tint)
		"quake":
			# Crystal spikes bursting out of a cracked ground line.
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.38, 0.78), _p(r, 0.5, 0.1), _p(r, 0.62, 0.78)]), tint)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.12, 0.78), _p(r, 0.25, 0.36), _p(r, 0.36, 0.78)]), tint)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.64, 0.78), _p(r, 0.76, 0.3), _p(r, 0.88, 0.78)]), tint)
			ci.draw_line(_p(r, 0.04, 0.84), _p(r, 0.96, 0.84), tint, w * 0.07)
		"wing":
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.08, 0.3), _p(r, 0.5, 0.55), _p(r, 0.92, 0.3), _p(r, 0.78, 0.7), _p(r, 0.62, 0.6), _p(r, 0.5, 0.78), _p(r, 0.38, 0.6), _p(r, 0.22, 0.7)]), tint)
		"ballista":
			var ow := maxf(1.2, w * 0.035)
			var gold := Color(1.0, 0.8, 0.34) * tint
			var navy := Color(0.24, 0.3, 0.52) * tint
			var steel := Color(0.92, 0.95, 1.0) * tint
			_poly(ci, _pts(r, [0.3, 0.64, 0.7, 0.64, 0.82, 0.84, 0.18, 0.84]), navy, ow)
			ci.draw_line(_p(r, 0.3, 0.665), _p(r, 0.7, 0.665), gold, w * 0.03)
			for wx in [0.26, 0.74]:
				_disc(ci, _p(r, wx, 0.84), w * 0.11, Color(0.15, 0.18, 0.32) * tint, ow)
				ci.draw_arc(_p(r, wx, 0.84), w * 0.075, 0, TAU, 16, gold, w * 0.035, true)
				ci.draw_circle(_p(r, wx, 0.84), w * 0.03, gold)
			var bc := _p(r, 0.5, 0.8)
			ci.draw_arc(bc, w * 0.44, PI * 1.12, PI * 1.88, 28, INK, w * 0.12 + ow * 2.0, true)
			var a0 := bc + Vector2(cos(PI * 1.12), sin(PI * 1.12)) * w * 0.44
			var a1 := bc + Vector2(cos(PI * 1.88), sin(PI * 1.88)) * w * 0.44
			ci.draw_line(a0, _p(r, 0.5, 0.58), steel.darkened(0.25), maxf(1.0, w * 0.025), true)
			ci.draw_line(a1, _p(r, 0.5, 0.58), steel.darkened(0.25), maxf(1.0, w * 0.025), true)
			ci.draw_arc(bc, w * 0.44, PI * 1.12, PI * 1.88, 28, gold, w * 0.12, true)
			ci.draw_arc(bc, w * 0.465, PI * 1.2, PI * 1.8, 20, Color(1, 1, 0.85, 0.75) * tint, w * 0.03, true)
			_stroke(ci, _p(r, 0.5, 0.7), _p(r, 0.5, 0.2), w * 0.07, steel, ow, false)
			_poly(ci, _pts(r, [0.5, 0.04, 0.6, 0.2, 0.4, 0.2]), Color(0.55, 0.88, 1.0) * tint, ow)
			_stroke(ci, _p(r, 0.5, 0.7), _p(r, 0.5, 0.2), w * 0.07, steel, ow)
			_poly(ci, _pts(r, [0.5, 0.62, 0.6, 0.74, 0.5, 0.7, 0.4, 0.74]), gold, ow * 0.6)
		"crossbow":
			var ow := maxf(1.2, w * 0.035)
			var gold := Color(1.0, 0.8, 0.34) * tint
			var wood := Color(0.62, 0.38, 0.2) * tint
			var steel := Color(0.92, 0.95, 1.0) * tint
			_stroke(ci, _p(r, 0.5, 0.42), _p(r, 0.5, 0.86), w * 0.13, wood, ow, false)
			_stroke(ci, _p(r, 0.5, 0.42), _p(r, 0.5, 0.86), w * 0.13, wood, ow)
			ci.draw_line(_p(r, 0.47, 0.46), _p(r, 0.47, 0.82), Color(1, 0.85, 0.65, 0.5) * tint, w * 0.03)
			_rr(ci, Rect2(_p(r, 0.43, 0.66), Vector2(w * 0.14, w * 0.07)), w * 0.03, gold)
			var bc := _p(r, 0.5, 0.66)
			var a0 := bc + Vector2(cos(PI * 1.16), sin(PI * 1.16)) * w * 0.42
			var a1 := bc + Vector2(cos(PI * 1.84), sin(PI * 1.84)) * w * 0.42
			ci.draw_arc(bc, w * 0.42, PI * 1.16, PI * 1.84, 28, INK, w * 0.1 + ow * 2.0, true)
			ci.draw_line(a0, _p(r, 0.5, 0.5), steel.darkened(0.3), maxf(1.0, w * 0.025), true)
			ci.draw_line(a1, _p(r, 0.5, 0.5), steel.darkened(0.3), maxf(1.0, w * 0.025), true)
			ci.draw_arc(bc, w * 0.42, PI * 1.16, PI * 1.84, 28, Color(0.3, 0.36, 0.6) * tint, w * 0.1, true)
			ci.draw_arc(bc, w * 0.44, PI * 1.24, PI * 1.76, 20, gold, w * 0.03, true)
			_stroke(ci, _p(r, 0.5, 0.56), _p(r, 0.5, 0.18), w * 0.06, steel, ow, false)
			_poly(ci, _pts(r, [0.5, 0.05, 0.59, 0.2, 0.41, 0.2]), Color(0.55, 0.88, 1.0) * tint, ow)
			_stroke(ci, _p(r, 0.5, 0.56), _p(r, 0.5, 0.18), w * 0.06, steel, ow)
		"cannon":
			var ow := maxf(1.2, w * 0.035)
			var a := _p(r, 0.3, 0.66)
			var b := _p(r, 0.7, 0.3)
			var gold := Color(1.0, 0.8, 0.34) * tint
			var violet := Color(0.7, 0.55, 1.0) * tint
			_stroke(ci, a, b, w * 0.25, Color.WHITE, ow, false)
			_stroke(ci, a, b, w * 0.25, Color(0.9, 0.92, 0.98) * tint, ow)
			var dir := (b - a).normalized()
			var n := Vector2(-dir.y, dir.x)
			ci.draw_line(a + n * w * 0.06 - dir * w * 0.02, b + n * w * 0.06, Color(1, 1, 1, 0.8) * tint, w * 0.04)
			ci.draw_line(a - n * w * 0.08, b - n * w * 0.08, Color(0.6, 0.64, 0.8) * tint, w * 0.045)
			for t in [0.45, 0.82]:
				var m := a.lerp(b, t)
				ci.draw_line(m + n * w * 0.14, m - n * w * 0.14, INK, w * 0.09)
				ci.draw_line(m + n * w * 0.13, m - n * w * 0.13, gold, w * 0.055)
			_glow(ci, _p(r, 0.76, 0.24), w * 0.26, Color(0.75, 0.55, 1.0, 0.9) * tint)
			_disc(ci, _p(r, 0.76, 0.24), w * 0.1, violet, ow)
			ci.draw_circle(_p(r, 0.75, 0.23), w * 0.055, Color(1, 0.95, 1.0) * tint)
			_disc(ci, _p(r, 0.32, 0.76), w * 0.18, Color(0.17, 0.2, 0.36) * tint, ow)
			ci.draw_arc(_p(r, 0.32, 0.76), w * 0.125, 0, TAU, 24, gold, w * 0.045, true)
			for i in 6:
				var aa := TAU * i / 6.0
				ci.draw_line(_p(r, 0.32, 0.76), _p(r, 0.32, 0.76) + Vector2(cos(aa), sin(aa)) * w * 0.11, gold.darkened(0.3), w * 0.025)
			ci.draw_circle(_p(r, 0.32, 0.76), w * 0.045, gold)
		"laser":
			var ow := maxf(1.2, w * 0.035)
			var gold := Color(1.0, 0.8, 0.34) * tint
			var cyan := Color(0.35, 0.95, 1.0) * tint
			_poly(ci, _pts(r, [0.12, 0.62, 0.58, 0.62, 0.66, 0.9, 0.04, 0.9]), Color(0.22, 0.28, 0.5) * tint, ow)
			ci.draw_line(_p(r, 0.13, 0.65), _p(r, 0.57, 0.65), gold, w * 0.035)
			_disc(ci, _p(r, 0.35, 0.56), w * 0.17, Color(0.92, 0.94, 1.0) * tint, ow)
			ci.draw_arc(_p(r, 0.35, 0.56), w * 0.11, PI, TAU, 16, Color(0.7, 0.74, 0.86) * tint, w * 0.03, true)
			var from := _p(r, 0.44, 0.47)
			var to := _p(r, 0.97, 0.03)
			ci.draw_line(from, to, Color(0.35, 0.9, 1.0, 0.18) * tint, w * 0.26)
			ci.draw_line(from, to, Color(0.35, 0.9, 1.0, 0.4) * tint, w * 0.14)
			ci.draw_line(from, to, cyan, w * 0.07)
			ci.draw_line(from, to, Color(0.9, 1.0, 1.0) * tint, w * 0.03)
			_glow(ci, from, w * 0.2, Color(0.4, 0.95, 1.0, 0.9) * tint)
			_poly(ci, PackedVector2Array([from + Vector2(0, -w * 0.08), from + Vector2(w * 0.07, 0), from + Vector2(0, w * 0.08), from + Vector2(-w * 0.07, 0)]), Color(0.75, 1.0, 1.0) * tint, ow * 0.7)
		"rockets":
			var ow := maxf(1.2, w * 0.035)
			var dir := Vector2(0.55, -0.83).normalized()
			_rocket(ci, _p(r, 0.24, 0.8), dir, w * 0.6, w * 0.16, Color(0.95, 0.96, 1.0) * tint, Color(1.0, 0.42, 0.22) * tint, ow)
			_rocket(ci, _p(r, 0.56, 0.9), dir, w * 0.55, w * 0.16, Color(0.95, 0.96, 1.0) * tint, Color(1.0, 0.68, 0.22) * tint, ow)
		"drone":
			var ow := maxf(1.2, w * 0.035)
			var c0 := _p(r, 0.5, 0.52)
			var corners := [_p(r, 0.2, 0.22), _p(r, 0.8, 0.22), _p(r, 0.2, 0.82), _p(r, 0.8, 0.82)]
			for q: Vector2 in corners:
				_stroke(ci, c0, q, w * 0.08, Color.WHITE, ow, false)
			for q: Vector2 in corners:
				_stroke(ci, c0, q, w * 0.08, Color(0.82, 0.86, 0.96) * tint, ow)
			for q: Vector2 in corners:
				ci.draw_circle(q, w * 0.17, Color(0.6, 0.95, 0.85, 0.28) * tint)
				ci.draw_arc(q, w * 0.17, 0, TAU, 24, INK, ow * 1.6, true)
				ci.draw_arc(q, w * 0.145, -0.6, 1.2, 10, Color(1, 1, 1, 0.75) * tint, w * 0.025, true)
				_disc(ci, q, w * 0.045, Color(1.0, 0.8, 0.34) * tint, ow * 0.6)
			_disc(ci, c0, w * 0.19, Color(0.95, 0.96, 1.0) * tint, ow)
			ci.draw_arc(c0, w * 0.15, 0, TAU, 24, Color(1.0, 0.8, 0.34) * tint, w * 0.035, true)
			_glow(ci, c0, w * 0.12, Color(0.4, 1.0, 0.65, 0.9) * tint)
			ci.draw_circle(c0, w * 0.065, Color(0.35, 1.0, 0.6) * tint)
			ci.draw_circle(c0 + Vector2(-w * 0.02, -w * 0.02), w * 0.022, Color(1, 1, 1, 0.9))
		"blaster":
			var ow := maxf(1.2, w * 0.035)
			var gold := Color(1.0, 0.8, 0.34) * tint
			_poly(ci, _pts(r, [0.26, 0.5, 0.48, 0.5, 0.42, 0.86, 0.2, 0.86]), Color(0.24, 0.3, 0.52) * tint, ow)
			_poly(ci, _pts(r, [0.08, 0.3, 0.74, 0.3, 0.84, 0.38, 0.84, 0.52, 0.08, 0.56]), Color(0.93, 0.95, 1.0) * tint, ow)
			_rr(ci, Rect2(_p(r, 0.8, 0.36), Vector2(w * 0.14, w * 0.12)), w * 0.03, INK)
			_rr(ci, Rect2(_p(r, 0.81, 0.375), Vector2(w * 0.11, w * 0.09)), w * 0.025, Color(0.6, 0.64, 0.8) * tint)
			ci.draw_line(_p(r, 0.1, 0.34), _p(r, 0.72, 0.34), Color(1, 1, 1, 0.9) * tint, w * 0.03)
			_rr(ci, Rect2(_p(r, 0.22, 0.39), Vector2(w * 0.4, w * 0.1)), w * 0.04, INK)
			_rr(ci, Rect2(_p(r, 0.23, 0.4), Vector2(w * 0.38, w * 0.08)), w * 0.035, Color(0.35, 0.95, 1.0) * tint)
			ci.draw_line(_p(r, 0.25, 0.42), _p(r, 0.58, 0.42), Color(0.9, 1, 1, 0.8) * tint, w * 0.02)
			ci.draw_line(_p(r, 0.3, 0.6), _p(r, 0.36, 0.6), gold, w * 0.04)
			_glow(ci, _p(r, 0.96, 0.44), w * 0.14, Color(0.4, 0.95, 1.0, 0.8) * tint)
		"spear":
			var ow := maxf(1.2, w * 0.035)
			_stroke(ci, _p(r, 0.16, 0.86), _p(r, 0.66, 0.36), w * 0.07, Color.WHITE, ow, false)
			_stroke(ci, _p(r, 0.16, 0.86), _p(r, 0.66, 0.36), w * 0.07, Color(0.62, 0.38, 0.2) * tint, ow)
			_poly(ci, _pts(r, [0.88, 0.12, 0.76, 0.42, 0.68, 0.38, 0.62, 0.32, 0.58, 0.24]), Color(0.9, 0.94, 1.0) * tint, ow)
			_rr(ci, Rect2(_p(r, 0.56, 0.38), Vector2(w * 0.12, w * 0.06)), w * 0.03, Color(1.0, 0.8, 0.34) * tint)
		"rate":
			var ow := maxf(1.2, w * 0.035)
			var gold := Color(1.0, 0.82, 0.32) * tint
			for i in 3:
				var y := 0.32 + i * 0.18
				var x0 := 0.06 + absf(i - 1) * 0.1
				_stroke(ci, _p(r, x0, y), _p(r, 0.4, y), w * 0.065, Color.WHITE, ow, false)
				_stroke(ci, _p(r, x0, y), _p(r, 0.4, y), w * 0.065, Color(1.0, 0.95, 0.8) * tint, ow)
			_poly(ci, _pts(r, [0.4, 0.28, 0.66, 0.28, 0.9, 0.5, 0.66, 0.72, 0.4, 0.72]), gold, ow)
			_poly(ci, _pts(r, [0.42, 0.31, 0.65, 0.31, 0.84, 0.48, 0.42, 0.48]), Color(1.0, 0.95, 0.7) * tint, 0.0)
			ci.draw_line(_p(r, 0.48, 0.3), _p(r, 0.48, 0.7), Color(0.75, 0.45, 0.1) * tint, w * 0.035)
		"dmg":
			var ow := maxf(1.2, w * 0.035)
			var burst := PackedVector2Array()
			for i in 16:
				var aa := -PI / 2.0 + i * PI / 8.0
				var rr := w * (0.48 if i % 2 == 0 else 0.3)
				burst.append(c + Vector2(cos(aa), sin(aa)) * rr)
			_poly(ci, burst, Color(1.0, 0.36, 0.22) * tint, ow)
			var inner := PackedVector2Array()
			for p2 in burst:
				inner.append(c + (p2 - c) * 0.7)
			ci.draw_colored_polygon(inner, Color(1.0, 0.62, 0.25) * tint)
			_poly(ci, _pts(r, [0.5, 0.06, 0.59, 0.16, 0.59, 0.64, 0.41, 0.64, 0.41, 0.16]), Color(0.93, 0.95, 1.0) * tint, ow)
			ci.draw_line(_p(r, 0.5, 0.14), _p(r, 0.5, 0.62), Color(0.65, 0.7, 0.85) * tint, w * 0.025)
			_rr(ci, Rect2(_p(r, 0.26, 0.63) - Vector2(ow, ow), Vector2(w * 0.48, w * 0.09) + Vector2(ow, ow) * 2.0), w * 0.04, INK)
			_rr(ci, Rect2(_p(r, 0.26, 0.63), Vector2(w * 0.48, w * 0.09)), w * 0.04, Color(1.0, 0.8, 0.34) * tint)
			_rr(ci, Rect2(_p(r, 0.44, 0.72) - Vector2(ow, 0), Vector2(w * 0.12 + ow * 2.0, w * 0.16)), w * 0.03, INK)
			_rr(ci, Rect2(_p(r, 0.44, 0.72), Vector2(w * 0.12, w * 0.15)), w * 0.03, Color(0.5, 0.3, 0.16) * tint)
			_disc(ci, _p(r, 0.5, 0.9), w * 0.06, Color(1.0, 0.8, 0.34) * tint, ow)
		"multi":
			var ow := maxf(1.2, w * 0.035)
			var base := _p(r, 0.5, 0.92)
			var tips: Array[Vector2] = []
			for deg in [-30.0, 0.0, 30.0]:
				var aa := deg_to_rad(deg) - PI / 2.0
				tips.append(base + Vector2(cos(aa), sin(aa)) * w * 0.7)
			for tp: Vector2 in tips:
				_stroke(ci, base, tp, w * 0.06, Color.WHITE, ow, false)
			for tp: Vector2 in tips:
				_stroke(ci, base, tp, w * 0.06, Color(0.92, 0.95, 1.0) * tint, ow)
			for tp: Vector2 in tips:
				var dd := (tp - base).normalized()
				var nn := Vector2(-dd.y, dd.x)
				_poly(ci, PackedVector2Array([tp + dd * w * 0.12, tp + nn * w * 0.09 - dd * w * 0.02, tp - nn * w * 0.09 - dd * w * 0.02]), Color(0.45, 0.88, 1.0) * tint, ow)
			_disc(ci, base, w * 0.07, Color(1.0, 0.8, 0.34) * tint, ow)
		"hand":
			var ow := maxf(1.5, w * 0.045)
			var parts := [
				[0.40, 0.04, 0.17, 0.6, 0.085], [0.55, 0.38, 0.15, 0.24, 0.07], [0.66, 0.44, 0.14, 0.24, 0.07],
				[0.76, 0.5, 0.12, 0.22, 0.06], [0.34, 0.48, 0.5, 0.4, 0.16], [0.17, 0.46, 0.18, 0.28, 0.08]]
			for pr: Array in parts:
				var rc := Rect2(_p(r, pr[0], pr[1]), Vector2(pr[2], pr[3]) * w)
				_rr(ci, rc.grow(ow), pr[4] * w + ow, INK)
			_rr(ci, Rect2(_p(r, 0.34, 0.84), Vector2(0.5, 0.14) * w).grow(ow), w * 0.05, INK)
			for pr: Array in parts:
				_rr(ci, Rect2(_p(r, pr[0], pr[1]), Vector2(pr[2], pr[3]) * w), pr[4] * w, Color(1.0, 0.98, 0.95) * tint)
			_rr(ci, Rect2(_p(r, 0.42, 0.08), Vector2(0.05, 0.4) * w), w * 0.025, Color(1, 1, 1, 0.9) * tint)
			ci.draw_line(_p(r, 0.57, 0.6), _p(r, 0.57, 0.66), Color(0.6, 0.64, 0.75) * tint, maxf(1.0, w * 0.02))
			ci.draw_line(_p(r, 0.68, 0.64), _p(r, 0.68, 0.69), Color(0.6, 0.64, 0.75) * tint, maxf(1.0, w * 0.02))
			_rr(ci, Rect2(_p(r, 0.34, 0.84), Vector2(0.5, 0.14) * w), w * 0.05, Color(1.0, 0.78, 0.3) * tint)
			ci.draw_line(_p(r, 0.36, 0.87), _p(r, 0.82, 0.87), Color(1, 0.95, 0.7, 0.9) * tint, maxf(1.0, w * 0.02))
		"shield":
			var ow := maxf(1.2, w * 0.035)
			var sp := _pts(r, [0.5, 0.06, 0.86, 0.18, 0.82, 0.56, 0.5, 0.94, 0.18, 0.56, 0.14, 0.18])
			_poly(ci, sp, Color(0.2, 0.8, 0.5) * tint, ow)
			var inner := PackedVector2Array()
			for p2 in sp:
				inner.append(c + (p2 - c) * 0.72 + Vector2(0, w * 0.02))
			ci.draw_colored_polygon(inner, Color(0.45, 1.0, 0.68) * tint)
			ci.draw_colored_polygon(_pts(r, [0.5, 0.18, 0.5, 0.82, 0.28, 0.54, 0.26, 0.26]), Color(0.75, 1.0, 0.85, 0.6) * tint)
		"crate":
			var ow := maxf(1.2, w * 0.035)
			_rr(ci, Rect2(_p(r, 0.1, 0.18), Vector2(0.8, 0.7) * w).grow(ow), w * 0.12 + ow, INK)
			_rr(ci, Rect2(_p(r, 0.1, 0.18), Vector2(0.8, 0.7) * w), w * 0.12, Color(0.93, 0.95, 1.0) * tint)
			_rr(ci, Rect2(_p(r, 0.1, 0.62), Vector2(0.8, 0.26) * w), w * 0.1, Color(0.7, 0.75, 0.9) * tint)
			_rr(ci, Rect2(_p(r, 0.24, 0.3), Vector2(0.52, 0.36) * w).grow(ow * 0.6), w * 0.08, INK)
			_rr(ci, Rect2(_p(r, 0.24, 0.3), Vector2(0.52, 0.36) * w), w * 0.08, Color(0.3, 0.85, 1.0) * tint)
			_glow(ci, _p(r, 0.5, 0.48), w * 0.2, Color(0.7, 1.0, 1.0, 0.9) * tint)
			for q in [Vector2(0.16, 0.24), Vector2(0.84, 0.24), Vector2(0.16, 0.82), Vector2(0.84, 0.82)]:
				ci.draw_circle(_p(r, q.x, q.y), w * 0.05, Color(1.0, 0.8, 0.34) * tint)
		"spikes":
			var ow := maxf(1.2, w * 0.035)
			for i in 4:
				var x0 := 0.08 + i * 0.22
				_poly(ci, _pts(r, [x0, 0.7, x0 + 0.1, 0.16, x0 + 0.2, 0.7]), Color(0.9, 0.92, 1.0) * tint, ow)
				ci.draw_colored_polygon(_pts(r, [x0 + 0.1, 0.16, x0 + 0.2, 0.7, x0 + 0.12, 0.7]), Color(0.62, 0.66, 0.8) * tint)
			_rr(ci, Rect2(_p(r, 0.04, 0.66), Vector2(0.92, 0.2) * w).grow(ow), w * 0.06, INK)
			_rr(ci, Rect2(_p(r, 0.04, 0.66), Vector2(0.92, 0.2) * w), w * 0.06, Color(0.85, 0.22, 0.2) * tint)
			ci.draw_line(_p(r, 0.08, 0.7), _p(r, 0.92, 0.7), Color(1, 0.6, 0.5, 0.8) * tint, w * 0.03)
		"blade":
			var ow := maxf(1.2, w * 0.035)
			for i in 3:
				var aa := TAU * i / 3.0 - PI / 2.0
				var d0 := Vector2(cos(aa), sin(aa))
				var n0 := Vector2(-d0.y, d0.x)
				_poly(ci, PackedVector2Array([c + n0 * w * 0.08, c + d0 * w * 0.46 + n0 * w * 0.1, c + d0 * w * 0.48 - n0 * w * 0.04, c - n0 * w * 0.08]), Color(0.9, 0.93, 1.0) * tint, ow)
			_disc(ci, c, w * 0.13, Color(0.85, 0.22, 0.2) * tint, ow)
			ci.draw_circle(c, w * 0.05, Color(1.0, 0.8, 0.34) * tint)
		"turret":
			var ow := maxf(1.2, w * 0.035)
			_stroke(ci, _p(r, 0.5, 0.48), _p(r, 0.88, 0.2), w * 0.12, Color.WHITE, ow, false)
			_stroke(ci, _p(r, 0.5, 0.48), _p(r, 0.88, 0.2), w * 0.12, Color(0.3, 0.32, 0.4) * tint, ow)
			_poly(ci, _pts(r, [0.16, 0.9, 0.84, 0.9, 0.76, 0.66, 0.24, 0.66]), Color(0.3, 0.32, 0.42) * tint, ow)
			_disc(ci, _p(r, 0.5, 0.6), w * 0.24, Color(0.9, 0.3, 0.22) * tint, ow)
			ci.draw_arc(_p(r, 0.5, 0.6), w * 0.17, PI * 1.1, PI * 1.6, 12, Color(1, 0.7, 0.6, 0.8) * tint, w * 0.04, true)
			_glow(ci, _p(r, 0.5, 0.6), w * 0.08, Color(1.0, 0.8, 0.3, 1.0) * tint)
		"geode":
			var ow := maxf(1.2, w * 0.035)
			var shards := [[0.5, 0.06, 0.66, 0.5, 0.5, 0.9, 0.34, 0.5], [0.24, 0.3, 0.36, 0.62, 0.26, 0.9, 0.1, 0.62], [0.78, 0.26, 0.92, 0.6, 0.76, 0.9, 0.64, 0.6]]
			for sh: Array in shards:
				_poly(ci, _pts(r, sh), Color(0.66, 0.42, 1.0) * tint, ow)
			for sh: Array in shards:
				ci.draw_colored_polygon(_pts(r, [sh[0], sh[1], sh[4], sh[5], sh[6], sh[7]]), Color(0.86, 0.72, 1.0) * tint)
			_rr(ci, Rect2(_p(r, 0.08, 0.84), Vector2(0.84, 0.1) * w).grow(ow), w * 0.05, INK)
			_rr(ci, Rect2(_p(r, 0.08, 0.84), Vector2(0.84, 0.1) * w), w * 0.05, Color(0.32, 0.3, 0.42) * tint)
		"gate":
			var ow := maxf(1.2, w * 0.035)
			_rr(ci, Rect2(_p(r, 0.18, 0.2), Vector2(0.64, 0.66) * w), w * 0.04, Color(0.3, 0.7, 1.0, 0.45) * tint)
			for x0 in [0.08, 0.8]:
				_rr(ci, Rect2(_p(r, x0, 0.14), Vector2(0.12, 0.8) * w).grow(ow), w * 0.04, INK)
				_rr(ci, Rect2(_p(r, x0, 0.14), Vector2(0.12, 0.8) * w), w * 0.04, Color(0.93, 0.95, 1.0) * tint)
			_rr(ci, Rect2(_p(r, 0.04, 0.08), Vector2(0.92, 0.12) * w).grow(ow), w * 0.04, INK)
			_rr(ci, Rect2(_p(r, 0.04, 0.08), Vector2(0.92, 0.12) * w), w * 0.04, Color(1.0, 0.8, 0.34) * tint)
			_stroke(ci, _p(r, 0.5, 0.36), _p(r, 0.5, 0.7), w * 0.1, Color.WHITE, ow, false)
			_stroke(ci, _p(r, 0.33, 0.53), _p(r, 0.67, 0.53), w * 0.1, Color.WHITE, ow, false)
			_stroke(ci, _p(r, 0.5, 0.36), _p(r, 0.5, 0.7), w * 0.1, Color.WHITE * tint, ow)
			_stroke(ci, _p(r, 0.33, 0.53), _p(r, 0.67, 0.53), w * 0.1, Color.WHITE * tint, ow)
		"soldier":
			var ow := maxf(1.2, w * 0.035)
			_poly(ci, _pts(r, [0.5, 0.06, 0.8, 0.22, 0.84, 0.66, 0.66, 0.92, 0.34, 0.92, 0.16, 0.66, 0.2, 0.22]), Color(0.93, 0.95, 1.0) * tint, ow)
			_rr(ci, Rect2(_p(r, 0.24, 0.44), Vector2(0.52, 0.1) * w), w * 0.04, INK)
			_rr(ci, Rect2(_p(r, 0.47, 0.54), Vector2(0.06, 0.28) * w), w * 0.03, INK)
			ci.draw_colored_polygon(_pts(r, [0.5, 0.06, 0.56, 0.06, 0.56, 0.44, 0.44, 0.44, 0.44, 0.06]), Color(1.0, 0.8, 0.34) * tint)
			ci.draw_colored_polygon(_pts(r, [0.24, 0.24, 0.4, 0.14, 0.36, 0.4, 0.24, 0.4]), Color(1, 1, 1, 0.6) * tint)
		_:
			ci.draw_circle(c, w * 0.4, tint)
