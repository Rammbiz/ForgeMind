class_name Jw
## «Ювелірна майстерня» (Celestial Jeweller) UI direction: palette, type and the jeweller's
## drawing kit. Everything is painted in code from three materials only:
##   navy guilloché enamel (shader), engraved gold (bevelled mouldings, milgrain, prongs)
##   and cut gems (flat-shaded facets: emerald cut, brilliant, marquise, octagon).
## Shapes are never plain rounded rectangles: panels are prong-set plates (concave corner
## notches, each holding a gem in 3 claws), buttons are emerald-cut gems in a gold bezel,
## secondary actions are navette (pointed) cabochon bars in a rope border, badges are lozenges.
## All functions are static and draw into the CanvasItem passed in (call from _draw()).

# --- palette ---------------------------------------------------------------------------
const ENAMEL := Color("101634")
const ENAMEL_LINE := Color("1c2552")
const DEEP := Color("070a1c")
const IVORY := Color("f6ebd3")
const DIM := Color("9aa3c7")
const ICE := Color("8feaff")
const BRIDGE := Color("3cb8ff")
const ICE_WHITE := Color("e9fbff")
const AMETHYST := Color("9b5cff")
const RUBY := Color("d2334a")
const EMERALD := Color("3fcb8a")
const GOLD := Color("e2b04a")
const GOLD_LIGHT := Color("ffe7a3")
const GOLD_DARK := Color("8a5a17")
const GOLD_INK := Color("2a1606")
const NAVY_INK := Color("0a1a3a")

## Light comes from the top-left; `TO_LIGHT` is the unit vector pointing at it (y down).
const TO_LIGHT := Vector2(-0.42, -0.91)

## Lit gold: 0 = facing away from the light, 1 = full specular.
const GOLD_LIT := [
	[0.0, Color("3a2205")], [0.22, Color("6b420f")], [0.42, Color("a8721f")],
	[0.6, Color("e2b04a")], [0.78, Color("ffe7a3")], [0.92, Color("fff6dc")], [1.0, Color("ffffff")],
]
## Polished band across a shape (dark-light-dark), the brief's 5-stop ramp.
const GOLD_BAND := [
	[0.0, Color("8a5a17")], [0.3, Color("e2b04a")], [0.48, Color("ffe7a3")],
	[0.62, Color("c98e2e")], [1.0, Color("6b420f")],
]

## Gem ramps by name (0 = deep facet, 1 = glint). Rarity: quartz < sapphire < amethyst < citrine.
const GEMS := {
	"ice": [[0.0, Color("0b2f6e")], [0.3, Color("1873cf")], [0.55, Color("3cb8ff")], [0.78, Color("8feaff")], [1.0, Color("f2fdff")]],
	"quartz": [[0.0, Color("2f3046")], [0.3, Color("6a6c86")], [0.6, Color("b5b8cc")], [0.82, Color("e3e5f0")], [1.0, Color("ffffff")]],
	"sapphire": [[0.0, Color("06124a")], [0.3, Color("0f2f9a")], [0.55, Color("2f62e6")], [0.8, Color("86aaff")], [1.0, Color("eef3ff")]],
	"amethyst": [[0.0, Color("1e0848")], [0.3, Color("4b1aa0")], [0.55, Color("8a4cf0")], [0.8, Color("c9a6ff")], [1.0, Color("fbf4ff")]],
	"citrine": [[0.0, Color("4a2104")], [0.3, Color("a85a0c")], [0.55, Color("f0a42a")], [0.8, Color("ffd978")], [1.0, Color("fffbe8")]],
	"emerald": [[0.0, Color("03311d")], [0.3, Color("0b7a47")], [0.55, Color("2fc07c")], [0.8, Color("98f0c4")], [1.0, Color("f0fff7")]],
	"ruby": [[0.0, Color("3d0410")], [0.3, Color("8c0f2a")], [0.55, Color("d2334a")], [0.8, Color("ff9aa8")], [1.0, Color("fff2f4")]],
	"smoke": [[0.0, Color("15161f")], [0.3, Color("2c2e3d")], [0.55, Color("4b4e62")], [0.8, Color("7d8096")], [1.0, Color("b8bacb")]],
}
const RARITY_GEM := {"C": "quartz", "R": "sapphire", "E": "amethyst", "L": "citrine", "M": "ruby"}
const RARITY_NAME := {"C": "Звичайна", "R": "Рідкісна", "E": "Епічна", "L": "Легендарна", "M": "Міфічна"}

# --- type --------------------------------------------------------------------------------
const FONT_DIR := "res://assets/fonts/"
static var _fonts := {}


## Yeseva One: fat-face Didone for big words only (titles, ГРАТИ, hero names).
static func display() -> Font:
	return _font("display", "YesevaOne-Regular.ttf", {}, {}, 0)


## Vollkorn SC Black: small caps labels, tabs, buttons; +6% tracking.
static func label() -> Font:
	return _font("label", "VollkornSC-Black.ttf", {}, {}, 2)


## Commissioner, flared (FLAR 100): body copy that reads as engraved plate.
static func body() -> Font:
	return _font("body", "Commissioner-VF.ttf", {"wght": 640, "FLAR": 100, "VOLM": 0}, {}, 0)


## Bona Nova SC Bold with lining tabular figures: every counter.
static func num() -> Font:
	return _font("num", "BonaNovaSC-Bold.ttf", {}, {"tnum": 1, "lnum": 1}, 0)


static func _font(key: String, file: String, axes: Dictionary, feats: Dictionary, track: int) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var ts := TextServerManager.get_primary_interface()
	var fv := FontVariation.new()
	fv.base_font = load(FONT_DIR + file)
	var va := {}
	for t in axes:
		va[ts.name_to_tag(t)] = axes[t]
	if not va.is_empty():
		fv.variation_opentype = va
	var of := {}
	for t in feats:
		of[ts.name_to_tag(t)] = feats[t]
	if not of.is_empty():
		fv.opentype_features = of
	fv.spacing_glyph = track
	_fonts[key] = fv
	return fv


# --- ramps -------------------------------------------------------------------------------
static func ramp(stops: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var a: Array = stops[i - 1]
			var b: Array = stops[i]
			return (a[1] as Color).lerp(b[1], (t - a[0]) / maxf(b[0] - a[0], 0.0001))
	return stops[stops.size() - 1][1]


static func gem(kind: String, t: float) -> Color:
	return ramp(GEMS.get(kind, GEMS["ice"]), t)


static func gold(t: float) -> Color:
	return ramp(GOLD_LIT, t)


## Brightness of a face whose outward normal is `n` (0..1, 0.5 = edge-on to the light).
static func lit(n: Vector2) -> float:
	return 0.5 + 0.5 * n.normalized().dot(TO_LIGHT)


static var _tex := {}


## A 256x1 texture of a ramp (for UV-mapped fills).
static func ramp_tex(key: String, stops: Array) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in 256:
		img.set_pixel(x, 0, ramp(stops, x / 255.0))
	_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


# --- shapes ------------------------------------------------------------------------------
static func arc(c: Vector2, r: float, a0: float, a1: float, seg: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg + 1:
		var a := lerpf(a0, a1, float(i) / seg)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func ellipse(c: Vector2, rx: float, ry: float, seg := 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg:
		var a := -PI * 0.5 + TAU * i / seg
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Prong-set plate: a rectangle whose four corners are concave quarter-circle notches of
## radius `n` (clockwise from the top edge). Inset with notched(r.grow(-d), n + d): same count.
static func notched(r: Rect2, n: float, seg := 7) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	p.append_array(arc(Vector2(x1, y0), n, PI, PI * 0.5, seg))
	p.append_array(arc(Vector2(x1, y1), n, PI * 1.5, PI, seg))
	p.append_array(arc(Vector2(x0, y1), n, TAU, PI * 1.5, seg))
	p.append_array(arc(Vector2(x0, y0), n, PI * 0.5, 0.0, seg))
	return p


## Octagon with 45° chamfers `c` (emerald-cut girdle), clockwise from the top edge.
## Inset by d: chamfer(r.grow(-d), c - d * 0.4142).
static func chamfer(r: Rect2, c: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])


static func chamfer_in(r: Rect2, c: float, d: float) -> PackedVector2Array:
	return chamfer(r.grow(-d), maxf(c - d * 0.4142, 0.5))


## Navette bar: straight top and bottom, each end drawn to a point by two curves that leave
## the straight edges tangentially (a marquise stretched into a bar). `tip` = end length.
static func navette(r: Rect2, tip: float, seg := 10) -> PackedVector2Array:
	var h := r.size.y * 0.5
	var cy := r.position.y + h
	var y0 := r.position.y
	var y1 := r.end.y
	var xl := r.position.x + tip
	var xr := r.end.x - tip
	var p := PackedVector2Array()
	for k in seg + 1:
		var s := float(k) / seg
		p.append(Vector2(xr + tip * s, y0 + h * pow(s, 1.7)))
	for k in range(seg - 1, -1, -1):
		var s := float(k) / seg
		p.append(Vector2(xr + tip * s, y1 - h * pow(s, 1.7)))
	for k in range(1, seg + 1):
		var s := float(k) / seg
		p.append(Vector2(xl - tip * s, y1 - h * pow(s, 1.7)))
	for k in range(seg - 1, 0, -1):
		var s := float(k) / seg
		p.append(Vector2(xl - tip * s, y0 + h * pow(s, 1.7)))
	return p


## Lozenge cartouche: a long hexagon with pointed left/right ends.
static func lozenge(r: Rect2, tip: float) -> PackedVector2Array:
	var cy := r.get_center().y
	return PackedVector2Array([
		Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y), Vector2(r.end.x, cy),
		Vector2(r.end.x - tip, r.end.y), Vector2(r.position.x + tip, r.end.y), Vector2(r.position.x, cy)])


## Shield cartouche (for card level badges): flat top, pointed bottom.
static func shield(r: Rect2) -> PackedVector2Array:
	var p := PackedVector2Array()
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	p.append(Vector2(x0, y0))
	p.append(Vector2(x1, y0))
	p.append(Vector2(x1, y0 + h * 0.48))
	p.append_array(arc(Vector2(x1 - w * 0.5 - w * 0.1, y0 + h * 0.48), w * 0.6, 0.0, PI * 0.38, 6).slice(1))
	p.append(Vector2(x0 + w * 0.5, y0 + h))
	p.append_array(arc(Vector2(x0 + w * 0.5 + w * 0.1, y0 + h * 0.48), w * 0.6, PI * 0.62, PI, 6).slice(0, 6))
	p.append(Vector2(x0, y0 + h * 0.48))
	return p


static func regular(c: Vector2, r: float, n: int, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := rot - PI * 0.5 + TAU * i / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func centroid(p: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for v in p:
		s += v
	return s / maxf(p.size(), 1)


## Outward normal at each vertex of a clockwise (screen) closed path.
static func normals(p: PackedVector2Array) -> PackedVector2Array:
	var n := PackedVector2Array()
	var c := p.size()
	for i in c:
		var a := p[(i - 1 + c) % c]
		var b := p[i]
		var d := p[(i + 1) % c]
		var e1 := (b - a).normalized()
		var e2 := (d - b).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var n2 := Vector2(e2.y, -e2.x)
		var s := n1 + n2
		n.append(s.normalized() if s.length() > 0.001 else n1)
	return n


## Resample a path at roughly even `step` spacing (for milgrain and ticks).
static func resample(p: PackedVector2Array, step: float, closed := true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pts := p.duplicate()
	if closed:
		pts.append(p[0])
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var L := a.distance_to(b)
		var t := carry
		while t <= L:
			out.append(a.lerp(b, t / maxf(L, 0.0001)))
			t += step
		carry = t - L
	return out


# --- low-level fills ---------------------------------------------------------------------
static func tris(ci: CanvasItem, pts: PackedVector2Array, idx: PackedInt32Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func fill(ci: CanvasItem, p: PackedVector2Array, col: Color) -> void:
	if p.size() >= 3:
		ci.draw_colored_polygon(p, col)


## Fill with a vertical (or along `axis`) ramp texture mapped across the polygon bounds.
static func fill_ramp(ci: CanvasItem, p: PackedVector2Array, tex: Texture2D, axis := Vector2(0, 1), modulate := Color.WHITE) -> void:
	var lo := INF
	var hi := -INF
	for v in p:
		var d := v.dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var uvs := PackedVector2Array()
	for v in p:
		uvs.append(Vector2((v.dot(axis) - lo) / maxf(hi - lo, 0.001), 0.5))
	var cols := PackedColorArray()
	cols.resize(p.size())
	cols.fill(modulate)
	ci.draw_polygon(p, cols, uvs, tex)


## Strip between two closed paths of equal length (outer, inner) with per-vertex colours.
static func band(ci: CanvasItem, o: PackedVector2Array, i_: PackedVector2Array, co: PackedColorArray, cin: PackedColorArray) -> void:
	var n := o.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append_array(o)
	pts.append_array(i_)
	cols.append_array(co)
	cols.append_array(cin)
	for k in n:
		var k2 := (k + 1) % n
		idx.append_array([k, k2, n + k, k2, n + k2, n + k])
	tris(ci, pts, idx, cols)


## Thin anti-aliased outline.
static func line(ci: CanvasItem, p: PackedVector2Array, col: Color, w := 1.0, closed := true) -> void:
	var q := p.duplicate()
	if closed and q.size() > 0:
		q.append(q[0])
	ci.draw_polyline(q, col, w, true)


# --- engraved gold -----------------------------------------------------------------------
## A bevelled gold moulding between closed paths `o` (outer) and `i_` (inner): the outer slope
## faces out, the inner slope faces in, the ridge between them catches the light.
## `ridge` 0..1 = where the ridge sits across the band; `gain` scales the light contrast.
static func gold_moulding(ci: CanvasItem, o: PackedVector2Array, i_: PackedVector2Array, ridge := 0.42, gain := 1.0, dark_edge := true) -> void:
	var n := normals(o)
	var m := PackedVector2Array()
	var co := PackedColorArray()
	var cm := PackedColorArray()
	var cin := PackedColorArray()
	for k in o.size():
		m.append(o[k].lerp(i_[k], ridge))
		var l := n[k].dot(TO_LIGHT) * gain
		co.append(gold(0.42 + 0.34 * l))
		cm.append(gold(0.8 + 0.2 * l))
		cin.append(gold(0.4 - 0.3 * l))
	band(ci, o, m, co, cm)
	band(ci, m, i_, cm, cin)
	if dark_edge:
		line(ci, o, Color(GOLD_INK, 0.85), 1.2)
		line(ci, i_, Color(GOLD_INK, 0.7), 1.0)


## Bevelled gold rule along an open path (width `w`, centred on the path).
static func gold_rule(ci: CanvasItem, path: PackedVector2Array, w := 6.0, gain := 1.0) -> void:
	var n := path.size()
	if n < 2:
		return
	var o := PackedVector2Array()
	var m := PackedVector2Array()
	var i_ := PackedVector2Array()
	var co := PackedColorArray()
	var cm := PackedColorArray()
	var cin := PackedColorArray()
	for k in n:
		var a := path[maxi(k - 1, 0)]
		var b := path[mini(k + 1, n - 1)]
		var d := (b - a).normalized()
		var nr := Vector2(d.y, -d.x)
		o.append(path[k] + nr * w * 0.5)
		m.append(path[k] + nr * w * 0.08)
		i_.append(path[k] - nr * w * 0.5)
		var l := nr.dot(TO_LIGHT) * gain
		co.append(gold(0.42 + 0.34 * l))
		cm.append(gold(0.82 + 0.18 * l))
		cin.append(gold(0.4 - 0.3 * l))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for strip in [[o, m, co, cm], [m, i_, cm, cin]]:
		var base := pts.size()
		pts.append_array(strip[0])
		pts.append_array(strip[1])
		cols.append_array(strip[2])
		cols.append_array(strip[3])
		for k in n - 1:
			idx.append_array([base + k, base + k + 1, base + n + k, base + k + 1, base + n + k + 1, base + n + k])
	tris(ci, pts, idx, cols)
	ci.draw_polyline(o, Color(GOLD_INK, 0.8), 1.1, true)
	ci.draw_polyline(i_, Color(GOLD_INK, 0.8), 1.1, true)


## Flat polished gold fill with the dark-light-dark band ramp.
static func gold_fill(ci: CanvasItem, p: PackedVector2Array, axis := Vector2(0.18, 1.0)) -> void:
	fill_ramp(ci, p, ramp_tex("gold_band", GOLD_BAND), axis.normalized())


## Hairline gold rule with beads (milgrain) along a path.
static func milgrain(ci: CanvasItem, p: PackedVector2Array, step := 6.0, r := 1.5, closed := true) -> void:
	for v in resample(p, step, closed):
		ci.draw_circle(v + Vector2(0, 0.6), r, Color(GOLD_INK, 0.6), true, -1.0, true)
		ci.draw_circle(v, r, gold(0.62), true, -1.0, true)
		ci.draw_circle(v + Vector2(-0.4, -0.5), r * 0.45, gold(0.95), true, -1.0, true)


## A gold claw prong: a teardrop from `base` towards `tip`, lit by its direction.
static func prong(ci: CanvasItem, base: Vector2, tip: Vector2, w := 5.0) -> void:
	var d := (tip - base)
	var L := d.length()
	if L < 0.5:
		return
	var u := d / L
	var s := Vector2(-u.y, u.x)
	var pts := PackedVector2Array()
	var seg := 9
	for k in seg + 1:
		var a := PI * k / seg
		pts.append(base + s * cos(a) * w * 0.5 + u * (-sin(a) * w * 0.35))
	pts.append(tip + s * (-w * 0.12))
	pts.append(tip + u * 1.2)
	pts.append(tip + s * (w * 0.12))
	fill(ci, pts, gold(0.5 + 0.25 * u.dot(-TO_LIGHT)))
	# highlight spine
	ci.draw_line(base + s * (-w * 0.12) + u * 0.5, tip - u * 1.5, gold(0.92), maxf(w * 0.22, 1.0), true)
	line(ci, pts, Color(GOLD_INK, 0.75), 0.9)


# --- gems ----------------------------------------------------------------------------------
## Facet shading: brightness of a facet with outward normal `n` on step `ring` (step cuts
## alternate light/dark, the emerald-cut "hall of mirrors").
static func _facet_t(n: Vector2, ring: int, pressed: bool) -> float:
	var l := n.normalized().dot(TO_LIGHT)
	if pressed:
		l = -l
	var t := 0.5 + 0.36 * l
	if ring % 2 == 1:
		t = 1.0 - t * 0.9 - 0.02
	return clampf(t, 0.04, 0.96)


## Emerald-cut gem in `r` with chamfer `c`: girdle → 2 step rings → table. Returns the table
## rect (for text). `kind` picks the ramp; `pressed` swaps the facet lighting.
static func emerald_cut(ci: CanvasItem, r: Rect2, c: float, kind := "ice", pressed := false, steps := PackedFloat32Array([0.0, 0.09, 0.17])) -> Rect2:
	var minor := minf(r.size.x, r.size.y)
	var rings: Array[PackedVector2Array] = []
	for s in steps:
		rings.append(chamfer_in(r, c, s * minor))
	var tb := r.grow(-0.25 * minor)
	var table := chamfer_in(r, c, 0.25 * minor)
	rings.append(table)
	for k in rings.size() - 1:
		var o: PackedVector2Array = rings[k]
		var i_: PackedVector2Array = rings[k + 1]
		for e in 8:
			var e2 := (e + 1) % 8
			var quad := PackedVector2Array([o[e], o[e2], i_[e2], i_[e]])
			var mid := (o[e] + o[e2]) * 0.5
			var nrm := (mid - r.get_center())
			# use the edge normal, not the radial direction
			var ed := (o[e2] - o[e]).normalized()
			nrm = Vector2(ed.y, -ed.x)
			fill(ci, quad, gem(kind, _facet_t(nrm, k, pressed)))
	# table: diagonal light across, darker at the bottom right
	var axis := Vector2(0.55, 1.0).normalized()
	var tex := ramp_tex("table_" + kind + ("_p" if pressed else ""), [
		[0.0, gem(kind, 0.86 if not pressed else 0.5)], [0.35, gem(kind, 0.74 if not pressed else 0.62)],
		[0.62, gem(kind, 0.62)], [1.0, gem(kind, 0.48 if not pressed else 0.8)]])
	fill_ramp(ci, table, tex, axis)
	# facet edges: hairlines of the cut
	var edge := Color(gem(kind, 1.0), 0.35)
	for k in rings.size():
		line(ci, rings[k], edge, 1.0)
	for e in 8:
		ci.draw_line(rings[0][e], rings[rings.size() - 1][e], Color(edge, 0.3), 1.0, true)
	# a soft reflected streak across the table
	var t0 := tb.position
	var streak := PackedVector2Array([
		t0 + Vector2(tb.size.x * 0.08, 0), t0 + Vector2(tb.size.x * 0.3, 0),
		t0 + Vector2(tb.size.x * 0.16, tb.size.y), t0 + Vector2(-tb.size.x * 0.06, tb.size.y)])
	var clip := Geometry2D.intersect_polygons(streak, table)
	for poly in clip:
		fill(ci, poly, Color(1, 1, 1, 0.08 if not pressed else 0.03))
	return tb


## Thick gold bezel around an emerald cut, with 4 claw prongs on the chamfers.
static func bezel(ci: CanvasItem, r: Rect2, c: float, w := 5.0, prongs := true) -> void:
	var o := chamfer(r.grow(w), c + w * 0.4142)
	var i_ := chamfer(r, c)
	# drop shadow under the setting
	fill(ci, chamfer(r.grow(w + 1.5).grow_individual(0, -2, 0, 4), c + w), Color(0, 0, 0, 0.45))
	gold_moulding(ci, o, i_, 0.45, 1.0)
	if prongs:
		var cs := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
		var ctr := r.get_center()
		for k in 4:
			var corner: Vector2 = cs[k]
			var dir := (ctr - corner).normalized()
			var mid := corner + Vector2(signf(ctr.x - corner.x), signf(ctr.y - corner.y)) * c * 0.5
			prong(ci, mid - dir * (w + 3.0), mid + dir * (c * 0.55 + 3.0), 9.0)


## Octagonal "chip" gem (10–24 px) seen from the top: table + 8 crown facets.
static func octagem(ci: CanvasItem, c: Vector2, rad: float, kind := "ice") -> void:
	var o := regular(c, rad, 8, PI / 8)
	var t := regular(c + Vector2(-0.06, -0.08) * rad, rad * 0.52, 8, PI / 8)
	for e in 8:
		var e2 := (e + 1) % 8
		var mid := (o[e] + o[e2]) * 0.5 - c
		fill(ci, PackedVector2Array([o[e], o[e2], t[e2], t[e]]), gem(kind, _facet_t(mid, 0, false)))
	fill(ci, t, gem(kind, 0.78))
	line(ci, o, Color(gem(kind, 0.1), 0.9), 1.0)
	ci.draw_circle(c + Vector2(-0.25, -0.3) * rad, rad * 0.16, Color(1, 1, 1, 0.85), true, -1.0, true)


## Round brilliant seen from the top (currency gem, rarity gem, stars).
static func brilliant(ci: CanvasItem, c: Vector2, rad: float, kind := "ice", rot := 0.0) -> void:
	var g := regular(c, rad, 16, rot)
	var mid := regular(c, rad * 0.78, 8, rot + PI / 8)
	var tb := regular(c, rad * 0.5, 8, rot)
	fill(ci, regular(c + Vector2(0, rad * 0.08), rad * 1.04, 16, rot), Color(0, 0, 0, 0.35))
	# girdle triangles (16)
	for e in 16:
		var e2 := (e + 1) % 16
		var m := mid[(e / 2) % 8] if e % 2 == 0 else mid[((e + 1) / 2) % 8]
		var nrm := (g[e] + g[e2]) * 0.5 - c
		var t := _facet_t(nrm, e % 2, false)
		fill(ci, PackedVector2Array([g[e], g[e2], m]), gem(kind, t))
	# kite/bezel facets (8) between table corners and mid points
	for e in 8:
		var a := tb[e]
		var b := mid[e]
		var d := tb[(e + 1) % 8]
		var gpt := g[(2 * e + 1) % 16]
		var nrm := b - c
		fill(ci, PackedVector2Array([a, b, d]), gem(kind, _facet_t(nrm, 1, false) * 0.9 + 0.08))
		fill(ci, PackedVector2Array([b, gpt, d]), gem(kind, _facet_t(nrm, 0, false)))
	fill(ci, tb, gem(kind, 0.7))
	# star facets inside the table edge
	for e in 8:
		var a := tb[e]
		var d := tb[(e + 1) % 8]
		var nrm := (a + d) * 0.5 - c
		fill(ci, PackedVector2Array([a, d, c + ((a + d) * 0.5 - c) * 0.55]), gem(kind, 0.55 + 0.3 * nrm.normalized().dot(TO_LIGHT)))
	line(ci, g, Color(gem(kind, 0.05), 0.95), 1.1)
	line(ci, tb, Color(gem(kind, 1.0), 0.25), 1.0)
	# fire: a cyan and a violet fleck, plus a white glint
	ci.draw_circle(c + Vector2(rad * 0.38, rad * 0.22), rad * 0.07, Color(0.6, 1.0, 1.0, 0.7), true, -1.0, true)
	ci.draw_circle(c + Vector2(-rad * 0.2, rad * 0.42), rad * 0.06, Color(0.85, 0.6, 1.0, 0.6), true, -1.0, true)
	ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.32), rad * 0.11, Color(1, 1, 1, 0.9), true, -1.0, true)


## Marquise (navette) gem along `axis` angle, length `L`, width `w`.
static func marquise(ci: CanvasItem, c: Vector2, L: float, w: float, angle := 0.0, kind := "ice") -> void:
	var u := Vector2(cos(angle), sin(angle))
	var s := Vector2(-u.y, u.x)
	var o := PackedVector2Array()
	var seg := 10
	var R := (L * L * 0.25 + w * w * 0.25) / w
	for k in seg + 1:
		var t := float(k) / seg
		var x := lerpf(-L * 0.5, L * 0.5, t)
		var y := sqrt(maxf(R * R - x * x, 0.0)) - (R - w * 0.5)
		o.append(c + u * x - s * y)
	for k in range(seg - 1, 0, -1):
		var t := float(k) / seg
		var x := lerpf(-L * 0.5, L * 0.5, t)
		var y := sqrt(maxf(R * R - x * x, 0.0)) - (R - w * 0.5)
		o.append(c + u * x + s * y)
	fill(ci, o, gem(kind, 0.35))
	var n := o.size()
	for k in n:
		var a := o[k]
		var b := o[(k + 1) % n]
		var mid := (a + b) * 0.5 - c
		fill(ci, PackedVector2Array([a, b, c + (mid) * 0.35]), gem(kind, _facet_t(mid, k % 2, false)))
	line(ci, o, Color(gem(kind, 0.05), 0.9), 1.0)
	ci.draw_circle(c - u * L * 0.12 - s * w * 0.1, w * 0.09, Color(1, 1, 1, 0.9), true, -1.0, true)


## 4-point star glint (additive look without blend: white core + soft halo).
static func glint(ci: CanvasItem, c: Vector2, size: float, col := Color(1, 1, 1), rot := 0.0) -> void:
	ci.draw_circle(c, size * 0.42, Color(col, 0.12), true, -1.0, true)
	ci.draw_circle(c, size * 0.2, Color(col, 0.25), true, -1.0, true)
	for k in 4:
		var a := rot + PI * 0.5 * k
		var u := Vector2(cos(a), sin(a))
		var s := Vector2(-u.y, u.x)
		var L := size if k % 2 == 0 else size * 0.72
		fill(ci, PackedVector2Array([c + s * size * 0.07, c + u * L, c - s * size * 0.07]), Color(col, 0.95))
	ci.draw_circle(c, size * 0.09, Color(1, 1, 1), true, -1.0, true)


## A gem set in a round collet: gold ring + 3 or 4 prongs + the brilliant.
static func collet(ci: CanvasItem, c: Vector2, rad: float, kind := "ice", n_prongs := 4) -> void:
	ci.draw_circle(c + Vector2(0, rad * 0.12), rad * 1.24, Color(0, 0, 0, 0.45), true, -1.0, true)
	gold_moulding(ci, regular(c, rad * 1.2, 32), regular(c, rad * 0.98, 32), 0.45)
	brilliant(ci, c, rad, kind)
	for k in n_prongs:
		var a := -PI * 0.5 + TAU * k / n_prongs + (PI / n_prongs if n_prongs == 4 else 0.0)
		var u := Vector2(cos(a), sin(a))
		prong(ci, c + u * rad * 1.16, c + u * rad * 0.8, maxf(rad * 0.42, 4.0))


# --- composite ornaments -----------------------------------------------------------------
## Prong-set plate frame (no fill): bevelled outer rule, gap, milgrain inner rule and a gem
## in 3 claws in every concave corner notch. `n` = notch radius.
static func plate_frame(ci: CanvasItem, r: Rect2, n := 22.0, w := 5.0, corner_gem := "ice", milg := true) -> void:
	var o := notched(r, n)
	var i_ := notched(r.grow(-w), n + w)
	gold_moulding(ci, o, i_, 0.4)
	var ir := r.grow(-(w + 4.0))
	var inner := notched(ir, n + w + 4.0)
	line(ci, inner, Color(GOLD_INK, 0.6), 2.2)
	line(ci, inner, gold(0.66), 1.1)
	if milg:
		milgrain(ci, notched(r.grow(-(w + 9.0)), n + w + 9.0), 7.0, 1.25)
	if corner_gem != "":
		var cs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var ctr := r.get_center()
		for k in 4:
			var corner: Vector2 = cs[k]
			var dir := Vector2(signf(ctr.x - corner.x), signf(ctr.y - corner.y)).normalized()
			var gc := corner + dir * n * 0.22
			var gr := n * 0.48
			corner_setting(ci, gc, gr, corner_gem, dir)


## A small gem in a gold collar with three short claws (plate corners).
static func corner_setting(ci: CanvasItem, gc: Vector2, gr: float, kind: String, dir: Vector2) -> void:
	ci.draw_circle(gc + Vector2(0, 2), gr + 5, Color(0, 0, 0, 0.5), true, -1.0, true)
	gold_moulding(ci, regular(gc, gr + 4.0, 24), regular(gc, gr, 24), 0.45)
	octagem(ci, gc, gr, kind)
	for a in [-PI * 0.5, PI * 0.5, PI]:
		var u := dir.rotated(a + PI * 0.25)
		prong(ci, gc + u * (gr + 4.5), gc + u * (gr * 0.62), maxf(gr * 0.55, 4.0))


## Enamel fill colour for plain (non-shader) areas.
static func enamel_fill(ci: CanvasItem, p: PackedVector2Array, a := 1.0) -> void:
	var tex := ramp_tex("enamel_v", [[0.0, Color("18204a")], [0.5, ENAMEL], [1.0, Color("0b1028")]])
	fill_ramp(ci, p, tex, Vector2(0, 1), Color(1, 1, 1, a))


## Text helper: draws `s` centred at `c` (baseline computed from the font's ascent).
static func text_c(ci: CanvasItem, font: Font, s: String, c: Vector2, size: int, col: Color, outline := 0, ocol := Color.BLACK) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var pos := Vector2(c.x - w * 0.5, c.y + (asc - desc) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Engraved text: dark cut line above, light lip below, fill on top.
static func text_engraved(ci: CanvasItem, font: Font, s: String, c: Vector2, size: int, col: Color, dark := Color(0, 0, 0, 0.55), light := Color(1, 1, 1, 0.18)) -> void:
	text_c(ci, font, s, c + Vector2(0, 1.5), size, light)
	text_c(ci, font, s, c + Vector2(0, -1.0), size, dark)
	text_c(ci, font, s, c, size, col)


static func text_w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
