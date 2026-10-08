class_name KitBox
extends StyleBox
## UI v3.1 "porcelain glass" StyleBox: the UIKit painted nine-patch, painted at DEVICE resolution
## (s = the canvas stretch scale, 1.5 on a 1080p phone) and drawn through a 1/s transform, so a
## ring of 1.0 is exactly one device pixel and nothing is bilinearly magnified (the v2 boxes were
## painted at 1x and stretched: 2-3 px soft gold bands). The device rect is snapped to whole
## pixels BEFORE the shadow room is added, so the 1 px ring lands on a pixel row.
## Optional corner flourishes (spec §3.4; modals: the two top corners, the selected card: a
## diagonal pair) are drawn as vector polylines in device space on top: a 1 device px inner
## bracket that follows the 45-degree chamfer, inset 6 px, a small curl at each arm end and a
## tiny lozenge on the cut pointing inwards. Skipped on boxes smaller than 80 x 56 px.
## Same batching as a StyleBoxTexture (one texture, one nine-patch; +2 calls per flourish).
## UIKit.lux() builds and caches these; never create one inside _draw().

@export var tex: Texture2D
@export var margin_dev := 0.0     ## nine-patch margin, device px
@export var shadow_dev := 0.0     ## shadow room around the body, device px (drawn outside the rect)
@export var s := 1.0              ## canvas -> device scale the texture was painted for
@export var cham := 0.0           ## body chamfer, canvas px (the flourish bracket follows it)
## {"corners": "top" | "diag" | "all", "len": arm length (canvas px), "inset": canvas px, "col": Color}
@export var flourish := {}


func _draw(ci: RID, rect: Rect2) -> void:
	if tex == null:
		return
	var inv := 1.0 / s
	var p := (rect.position * s).round()
	var e := (rect.end * s).round()
	var p0 := p - Vector2(shadow_dev, shadow_dev)
	var sz := e + Vector2(shadow_dev, shadow_dev) - p0
	# Too small for the nine-patch corners: shrink the margins (keeps the chamfer readable).
	var m := minf(margin_dev, floorf(minf(sz.x, sz.y) * 0.5))
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(inv, inv), 0.0, Vector2.ZERO))
	RenderingServer.canvas_item_add_nine_patch(ci, Rect2(p0, sz), Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(),
			Vector2(m, m), Vector2(m, m))
	if not flourish.is_empty() and (e - p).x >= 80.0 * s and (e - p).y >= 56.0 * s:
		_flourishes(ci, Rect2(p, e - p))
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(shadow_dev / s)


## Corner flourishes in device space (2 canvas calls per corner: the bracket polyline + the lozenge).
func _flourishes(ci: RID, r: Rect2) -> void:
	var col: Color = flourish.get("col", Color(UITokens.LINE_GOLD_DEEP.r, UITokens.LINE_GOLD_DEEP.g, UITokens.LINE_GOLD_DEEP.b, 0.8))
	var inset := roundf(float(flourish.get("inset", 6.0)) * s)
	var arm := float(flourish.get("len", 20.0)) * s
	var ch := maxf(cham * s - inset * 0.41, 3.0 * s)
	var lw := UITokens.LOW_DENSITY_LINE if s < 0.9 else 1.0
	var corners: Array = []
	var tl := [r.position, Vector2(1, 0), Vector2(0, 1)]
	var tr := [Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)]
	var bl := [Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)]
	var br := [r.end, Vector2(-1, 0), Vector2(0, -1)]
	match str(flourish.get("corners", "top")):
		"all": corners = [tl, tr, bl, br]
		"diag": corners = [tl, br]
		_: corners = [tl, tr]
	for c: Array in corners:
		var o: Vector2 = c[0]
		var dx: Vector2 = c[1]
		var dy: Vector2 = c[2]
		# Pixel-centre the straight arms (a 1 px line on a pixel row / column).
		var base := o + dx * inset + dy * inset + (dx + dy) * 0.5
		var pts := PackedVector2Array()
		# Curl at the end of the vertical arm (spirals inward), up the arm, across the chamfer,
		# along the horizontal arm, and a curl at its end.
		var rc := 2.6 * s
		var a_end := base + dy * (ch + arm)
		var cc := a_end + dx * rc
		for i in range(10, -1, -1):
			var t := float(i) / 10.0
			var ang := PI - t * PI * 1.35
			var rr := rc * (1.0 - t * 0.45)
			pts.append(cc + (dx * cos(ang) + dy * sin(ang)) * rr)
		pts.append(base + dy * ch)
		pts.append(base + dx * ch)
		var b_end := base + dx * (ch + arm)
		var cc2 := b_end + dy * rc
		for i in 11:
			var t := float(i) / 10.0
			var ang := -PI * 0.5 + t * PI * 1.35
			var rr := rc * (1.0 - t * 0.45)
			pts.append(cc2 + (dx * cos(ang) + dy * sin(ang)) * rr)
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_polyline(ci, pts, cols, lw, true)
		# A tiny lozenge on the cut, pointing into the box.
		var n := (dx + dy).normalized()
		var mpt := base + (dx + dy) * (ch * 0.5) + n * 4.0 * s
		var k := 2.2 * s * 0.5
		var t2 := Vector2(-n.y, n.x)
		var dia := PackedVector2Array([mpt + n * k * 1.6, mpt + t2 * k, mpt - n * k * 1.6, mpt - t2 * k])
		RenderingServer.canvas_item_add_polygon(ci, dia, PackedColorArray([col]), PackedVector2Array(), RID())
