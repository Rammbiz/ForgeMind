class_name PortalRing
extends Control
## The Portal ring (heroes_design.md §9.3 Portal; fusion §6.8 #4): a gold torus with a swirling
## starlit interior (shaders/heroes/portal_ring.gdshader), five inset gem sockets - one per tier,
## each in its own cut and setting (Кварц round, Сапфір square, Аметист triangle, Топаз star, Опал
## eye) - standing on a crystal dais with a light pool. Budget: one shader quad + a few polygons.
## The ceremony drives `t`, `tint`, `charge`, `pulse`, `opal`, `open` and `lit` (the told gem);
## on the Portal screen it idles on its own clock.
##   var ring := PortalRing.new(); ring.size = Vector2(520, 520)

const SHADER := preload("res://shaders/heroes/portal_ring.gdshader")
## Socket order round the ring from the top, clockwise (72 degrees apart).
const SOCKETS: Array[String] = ["M", "L", "E", "R", "C"]
const RING_R := 0.78
const TUBE_W := 0.07

var driven := false
var t := 0.0:
	set(v):
		t = v
		_mat.set_shader_parameter("t", v)
		_over.queue_redraw()
var charge := 0.0:
	set(v):
		charge = v
		_mat.set_shader_parameter("charge", v)
var pulse := -1.0:
	set(v):
		pulse = v
		_mat.set_shader_parameter("pulse", v)
var opal := 0.0:
	set(v):
		opal = v
		_mat.set_shader_parameter("opal", v)
var open := 0.0:
	set(v):
		open = v
		_mat.set_shader_parameter("open", v)
var lit := "":                    ## the socket that answers the tell ("" = none)
	set(v):
		lit = v
		_over.queue_redraw()
var lit_k := 0.0:
	set(v):
		lit_k = v
		_over.queue_redraw()
var crawl := 0.0:                 ## Topaz+ pre-sting: gold glints crawl the ring (0..1)
	set(v):
		crawl = v
		_over.queue_redraw()
var dais := true
var _mat: ShaderMaterial
var _quad: ColorRect
var _over: _Over


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad = ColorRect.new()
	_quad.color = Color.WHITE
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("ring_r", RING_R)
	_mat.set_shader_parameter("tube_w", TUBE_W)
	_quad.material = _mat
	add_child(_quad)
	_over = _Over.new()
	_over.ring = self
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	set_tint(Color("#A88CFF"), Color("#FFE6A3"))


func _ready() -> void:
	set_process(not driven)


func _process(delta: float) -> void:
	if not driven:
		t += delta * (0.3 if UITokens.reduce_motion() else 1.0)


func set_tint(col: Color, hi := Color("#FFE6A3")) -> void:
	_mat.set_shader_parameter("tint", col)
	_mat.set_shader_parameter("tint_hi", hi)


## Ring centre and tube radius in this control's coordinates.
func centre() -> Vector2:
	return size * 0.5


func radius() -> float:
	return minf(size.x, size.y) * 0.5 * RING_R


## Inner (open) radius of the portal.
func inner_radius() -> float:
	return minf(size.x, size.y) * 0.5 * (RING_R - TUBE_W)


func socket_pos(g: String) -> Vector2:
	var i := SOCKETS.find(g)
	var a := -PI / 2.0 + TAU * float(maxi(i, 0)) / SOCKETS.size()
	return centre() + Vector2(cos(a), sin(a)) * radius()


func _draw() -> void:
	if not dais:
		return
	# The crystal dais under the ring: an elliptical platform, gold rim, and the portal's light pool.
	var c := centre()
	var R := radius()
	var dc := c + Vector2(0, R * 1.16)
	var rx := R * 1.28
	var ry := R * 0.2
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 48:
		var a := TAU * float(i) / 48.0
		var p := dc + Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(p)
		var k := 0.5 + 0.5 * sin(a)
		cols.append(Color(0.42, 0.4, 0.68, 0.55).lerp(Color(0.86, 0.88, 1.0, 0.75), 1.0 - k))
	# Platform side (a thin band below the top surface).
	var side := PackedVector2Array()
	for i in 25:
		var a := PI * float(i) / 24.0
		side.append(dc + Vector2(cos(a) * rx, sin(a) * ry + R * 0.07))
	for i in 25:
		var a := PI - PI * float(i) / 24.0
		side.append(dc + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(side, Color(0.22, 0.2, 0.42, 0.85))
	draw_polygon(pts, cols)
	var light := UIKit.glow_texture()
	draw_texture_rect(light, Rect2(dc - Vector2(rx * 0.8, ry * 1.6), Vector2(rx * 1.6, ry * 3.2)), false, Color(1.0, 0.9, 0.7, 0.32 + 0.3 * charge))
	var rim := PackedVector2Array(pts)
	rim.append(pts[0])
	draw_polyline(rim, Color(UITokens.GOLD_HI.r, UITokens.GOLD_HI.g, UITokens.GOLD_HI.b, 0.85), 1.6, true)
	# Inner engraved ring on the dais.
	var inner := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		inner.append(dc + Vector2(cos(a) * rx * 0.72, sin(a) * ry * 0.72))
	draw_polyline(inner, Color(1.0, 0.92, 0.7, 0.35), 1.2, true)


## Sockets, glints and the pre-sting crawl, drawn over the shader quad.
class _Over extends Control:
	var ring: PortalRing

	func _draw() -> void:
		if ring == null:
			return
		var s := minf(size.x, size.y) * 0.088
		for g: String in SOCKETS:
			var p := ring.socket_pos(g)
			if g == ring.lit and ring.lit_k > 0.0:
				var col := SummonFx.hex(g)
				SummonFx.draw_glow(self, p, s * (1.6 + 0.6 * ring.lit_k), col, 0.75 * ring.lit_k)
			HeroGemEmblem.draw_emblem(self, g, "", p, s, true, ring.t)
			if g == "C" and not (g == ring.lit and ring.lit_k > 0.0):
				# Quartz is near-white: settle it to the other sockets' level (rim #D6DEE6) so it
				# never reads as a button on the ring.
				var qc := Color("#8E9BAD")
				draw_colored_polygon(GemDraw.cut_points("round", p, s * 0.98), Color(qc.r, qc.g, qc.b, 0.32))
				GemDraw.outline(self, GemDraw.cut_points("round", p, s * 0.98), Color("#D6DEE6"), 1.4)
		if ring.crawl > 0.0:
			var c := ring.centre()
			var R := ring.radius()
			for i in 6:
				var a := -PI / 2.0 + TAU * (ring.crawl * 0.9 + float(i) / 6.0)
				var p := c + Vector2(cos(a), sin(a)) * R
				GemDraw.draw_glint(self, p, 26.0 + 10.0 * sin(ring.t * 9.0 + i), Color(1.0, 0.92, 0.6, 0.9 * sin(PI * clampf(ring.crawl, 0.0, 1.0))))
