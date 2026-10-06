class_name ForgeKit
## «Кришталева кузня» (UI direction B, dev mockup): the hub is cut from the bridge's crystal.
## One owned motif at every scale: the SHARD, a rectangle with one or two corners cleaved at
## 14/22/33 degrees (never 45) and one long edge skewed a few degrees, seeded by the element's
## id so no two panels are alike. Panels are dark glass shards, buttons are extruded crystal
## PRISMS lit from the top-left, numbers sit on CUT GEMS, headlines are CLEAVED crystal type.
## Everything here draws onto a CanvasItem (immediate mode) so the screens stay small.

const GLASS_SHADER := preload("res://assets/ui/skins/forge/forge_glass.gdshader")
const CLEAVE_SHADER := preload("res://assets/ui/skins/forge/forge_cleave.gdshader")
const BACKDROP_SHADER := preload("res://assets/ui/skins/forge/forge_backdrop.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

# ------------------------------------------------------------------ palette
const VOID := Color("0A0820")
const NEBULA := Color("2B1257")
const DECK_ICE := Color("7FE3FF")
const CORE := Color("3CB8FF")
const RIM := Color("E9FBFF")
const AMETHYST := Color("9B5CFF")
const EMBER := Color("FF6A3D")
const GOLD := Color("FFD27A")
const TEXT := Color("EAF6FF")
const DIM := Color("8FA6C9")
const INK := Color("0A1736")
const SHADOW := Color(0.0, 0.0, 0.04, 0.42)
## Direction TO the light (top-left), screen space.
const LIGHT := Vector2(-0.55, -0.835)

## Prism materials: top face [light, mid, deep], front face [lit, shade], rim, ink (label colour).
const PRISMS := {
	"primary": {"top": [Color("FFFFFF"), Color("CDF5FF"), Color("8FE6FF")], "front": [Color("41B6FF"), Color("1A5FB8")],
		"rim": Color("FFFFFF"), "ink": INK, "glow": Color("8FEAFF")},
	"secondary": {"top": [Color("C9A4FF"), Color("9B62FA"), Color("7438E0")], "front": [Color("5A26B8"), Color("2E1070")],
		"rim": Color("EEDDFF"), "ink": Color("FFFFFF"), "glow": Color("B98CFF")},
	"danger": {"top": [Color("FFB28C"), Color("FF7A47"), Color("E8501F")], "front": [Color("B33416"), Color("6C160A")],
		"rim": Color("FFE6D8"), "ink": Color("FFFFFF"), "glow": Color("FF8A5C")},
	"disabled": {"top": [Color("4A5478"), Color("3C4568"), Color("323A5A")], "front": [Color("232A46"), Color("161B30")],
		"rim": Color("6C779C"), "ink": Color("8E99BC"), "glow": Color(0, 0, 0, 0)},
	"glass": {"top": [Color("2A3468"), Color("1C2350"), Color("141A3C")], "front": [Color("0E1534"), Color("060918")],
		"rim": Color("9FE6FF"), "ink": TEXT, "glow": Color("8FEAFF")},
	"gold": {"top": [Color("FFF1C4"), Color("FFD27A"), Color("E9A93A")], "front": [Color("B77A1E"), Color("6E440C")],
		"rim": Color("FFFBEA"), "ink": Color("3A2206"), "glow": Color("FFD27A")},
}

## Rarity = crystal species. [light, mid, dark, name key, cut-gem sides]
const RARITY := {
	"C": [Color("F2F5FA"), Color("B9C3D3"), Color("6E7A90"), "Звичайна", 4],
	"R": [Color("C8F2FF"), Color("3CB8FF"), Color("1A5BB0"), "Рідкісна", 4],
	"E": [Color("E2CCFF"), Color("A66BFF"), Color("5A26B8"), "Епічна", 3],
	"L": [Color("FFF0BE"), Color("FFC042"), Color("B06C10"), "Легендарна", 6],
	"M": [Color("FFD6C4"), Color("FF6A3D"), Color("9C2410"), "Міфічна", 5],
}

# ------------------------------------------------------------------ type
## [file, axes, extra px per glyph, OpenType features]
const FONT_SPECS := {
	# Science Gothic ultra-wide: the triangular Д/Л read as facets. Display only (big words).
	"display": ["res://assets/fonts/ScienceGothic-VF.ttf", {"wght": 820, "wdth": 200, "CTRS": 0}, 1, {}],
	"display_mid": ["res://assets/fonts/ScienceGothic-VF.ttf", {"wght": 760, "wdth": 150, "CTRS": 0}, 1, {}],
	# Unbounded: buttons and tracked caps labels.
	"button": ["res://assets/fonts/Unbounded-VF.ttf", {"wght": 800}, 1, {}],
	"label": ["res://assets/fonts/Unbounded-VF.ttf", {"wght": 640}, 2, {}],
	# Geologica with the sharpness axis at 100: literally cut corners on every stroke.
	"body": ["res://assets/fonts/Geologica-VF.ttf", {"wght": 500, "SHRP": 100}, 0, {}],
	"bold": ["res://assets/fonts/Geologica-VF.ttf", {"wght": 720, "SHRP": 100}, 0, {}],
	"num": ["res://assets/fonts/Geologica-VF.ttf", {"wght": 820, "SHRP": 100}, 0, {"tnum": 1}],
}

static var _fonts := {}
static var _noise: Texture2D


static func font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var spec: Array = FONT_SPECS[key]
	var fv := FontVariation.new()
	fv.base_font = load(spec[0])
	var ts := TextServerManager.get_primary_interface()
	var va := {}
	for tag: String in spec[1]:
		va[ts.name_to_tag(tag)] = spec[1][tag]
	fv.variation_opentype = va
	fv.spacing_glyph = int(spec[2])
	var feats := {}
	for tag: String in spec[3]:
		feats[ts.name_to_tag(tag)] = spec[3][tag]
	if not feats.is_empty():
		fv.opentype_features = feats
	_fonts[key] = fv
	return fv


## Largest size <= `size` (and >= `min_size`) at which `text` fits `max_w`.
static func fit_size(text: String, key: String, size: int, max_w: float, min_size := 26) -> int:
	var f := font(key)
	var s := size
	while s > min_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s


static func text_w(text: String, key: String, size: int) -> float:
	return font(key).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Draws `text` with its visual box centred on `c` (cap-height centring).
static func draw_text_c(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color, max_w := -1.0) -> void:
	var s := size if max_w <= 0.0 else fit_size(text, key, size, max_w, mini(size, 22))
	var f := font(key)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var asc := f.get_ascent(s)
	var cap := asc * 0.72
	ci.draw_string(f, Vector2(c.x - w * 0.5, c.y + cap * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


## Draws `text` left-aligned with its cap line centred on y = c.y, starting at c.x. Returns width.
static func draw_text_l(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color) -> float:
	var f := font(key)
	var asc := f.get_ascent(size)
	ci.draw_string(f, Vector2(c.x, c.y + asc * 0.72 * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func draw_text_r(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color) -> float:
	var w := text_w(text, key, size)
	draw_text_l(ci, text, key, size, Vector2(c.x - w, c.y), col)
	return w


# ------------------------------------------------------------------ shard geometry

## A seeded convex shard inside `r` (clockwise from top-left). Options:
##   cuts: {corner: Vector2(horizontal leg, vertical leg)}  (0 TL, 1 TR, 2 BR, 3 BL) - forced cuts
##   n_cuts (1-2), min_cut / max_cut (long leg, px), skew (deg, 0 = none, default 2-3),
##   skew_edge "top" / "bottom" (default random).
## The long leg follows the longer side so the cut reads as a cleave, not a bevel.
static func shard(r: Rect2, seed: int, o := {}) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed * 7919 + 17)
	var cuts: Dictionary = o.get("cuts", {})
	if not o.has("cuts"):
		cuts = {}
		var n := int(o.get("n_cuts", rng.randi_range(1, 2)))
		var first := rng.randi_range(0, 3)
		var order := [first, (first + 2) % 4, (first + 1) % 4]
		for i in n:
			var ang := deg_to_rad([14.0, 22.0, 33.0][rng.randi_range(0, 2)])
			var long := rng.randf_range(float(o.get("min_cut", 14.0)), float(o.get("max_cut", 34.0)))
			var short := long * tan(ang)
			cuts[order[i]] = Vector2(long, short) if r.size.x >= r.size.y else Vector2(short, long)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var p := PackedVector2Array()
	var c0: Vector2 = cuts.get(0, Vector2.ZERO)
	var c1: Vector2 = cuts.get(1, Vector2.ZERO)
	var c2: Vector2 = cuts.get(2, Vector2.ZERO)
	var c3: Vector2 = cuts.get(3, Vector2.ZERO)
	if c0 != Vector2.ZERO:
		p.append(Vector2(x0, y0 + c0.y))
		p.append(Vector2(x0 + c0.x, y0))
	else:
		p.append(Vector2(x0, y0))
	if c1 != Vector2.ZERO:
		p.append(Vector2(x1 - c1.x, y0))
		p.append(Vector2(x1, y0 + c1.y))
	else:
		p.append(Vector2(x1, y0))
	if c2 != Vector2.ZERO:
		p.append(Vector2(x1, y1 - c2.y))
		p.append(Vector2(x1 - c2.x, y1))
	else:
		p.append(Vector2(x1, y1))
	if c3 != Vector2.ZERO:
		p.append(Vector2(x0 + c3.x, y1))
		p.append(Vector2(x0, y1 - c3.y))
	else:
		p.append(Vector2(x0, y1))
	# One long edge skewed inward (a bilinear nudge keeps every edge straight enough).
	var skew_deg := float(o.get("skew", rng.randf_range(2.0, 3.0)))
	if skew_deg > 0.0:
		var edge := str(o.get("skew_edge", "top" if rng.randf() < 0.5 else "bottom"))
		var rise := tan(deg_to_rad(skew_deg)) * r.size.x
		rise = minf(rise, r.size.y * 0.16)
		var to_right := rng.randf() < 0.5 if not o.has("skew_right") else bool(o["skew_right"])
		for i in p.size():
			var q := p[i]
			var tx := (q.x - x0) / r.size.x
			var a := rise * (tx if to_right else 1.0 - tx)
			if edge == "top":
				q.y += a * (1.0 - (q.y - y0) / r.size.y)
			else:
				q.y -= a * ((q.y - y0) / r.size.y)
			p[i] = q
	return p


static func moved(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + off
	return out


static func grown(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(pts, d, Geometry2D.JOIN_MITER)
	return res[0] if not res.is_empty() else pts


static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r


## Outward normal of edge a->b of a clockwise (screen) polygon.
static func edge_normal(a: Vector2, b: Vector2) -> Vector2:
	var e := (b - a).normalized()
	return Vector2(e.y, -e.x)


## Per-vertex colours of a linear gradient across `r` (diagonal, lit top-left).
static func grad_cols(pts: PackedVector2Array, r: Rect2, a: Color, b: Color, slant := 0.3) -> PackedColorArray:
	var cols := PackedColorArray()
	for q in pts:
		var t := ((q.y - r.position.y) / maxf(r.size.y, 1.0)) * (1.0 - slant) + ((q.x - r.position.x) / maxf(r.size.x, 1.0)) * slant
		cols.append(a.lerp(b, clampf(t, 0.0, 1.0)))
	return cols


## The polygon split by the line through p and q: [left/upper part, right/lower part].
static func split(pts: PackedVector2Array, p: Vector2, q: Vector2) -> Array:
	var d := (q - p).normalized()
	var n := Vector2(-d.y, d.x)
	var far := 4000.0
	var half_a := PackedVector2Array([p - d * far, q + d * far, q + d * far + n * far, p - d * far + n * far])
	var half_b := PackedVector2Array([p - d * far, p - d * far - n * far, q + d * far - n * far, q + d * far])
	var a := Geometry2D.intersect_polygons(pts, half_a)
	var b := Geometry2D.intersect_polygons(pts, half_b)
	return [a[0] if not a.is_empty() else PackedVector2Array(), b[0] if not b.is_empty() else PackedVector2Array()]


# ------------------------------------------------------------------ drawing: rims and glass

## Crystal rim: ice-white on edges facing the light (brightest at the end nearer the light,
## fading along the edge), 1 px void on the others, plus a faint inner hairline (the glass
## has thickness).
static func draw_rim(ci: CanvasItem, pts: PackedVector2Array, lit := RIM, shade := Color("05061A"), lit_w := 2.0, inner := 0.14) -> void:
	var n := pts.size()
	var r := bounds(pts)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var k := edge_normal(a, b).dot(LIGHT)
		if k > 0.05:
			var c := lit
			var base := clampf(0.25 + k * 0.45, 0.0, 1.0) * lit.a
			# Fade towards the far (bottom-right) end of the panel.
			var fa := 1.0 - 0.75 * clampf(((a - r.position) / r.size).dot(Vector2(0.6, 0.4)), 0.0, 1.0)
			var fb := 1.0 - 0.75 * clampf(((b - r.position) / r.size).dot(Vector2(0.6, 0.4)), 0.0, 1.0)
			var ca := c
			ca.a = base * fa
			var cb := c
			cb.a = base * fb
			ci.draw_polyline_colors(PackedVector2Array([a, b]), PackedColorArray([ca, cb]), lit_w, true)
		else:
			ci.draw_line(a, b, shade, 1.2, true)
	if inner > 0.0:
		var ins := grown(pts, -6.0)
		var c2 := lit
		c2.a = inner
		var closed := ins.duplicate()
		closed.append(ins[0])
		ci.draw_polyline(closed, c2, 1.0, true)


## Polished chamfer facets on every cut (diagonal) edge: a trapezoid between the cut and a
## parallel line `w` inside it, bounded by the neighbouring edges. Facets facing the light
## glint ice-white, the others sink to deep crystal blue. This is the panel's signature glint.
static func draw_chamfers(ci: CanvasItem, pts: PackedVector2Array, w := 9.0, glint := 1.0) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var e := b - a
		if absf(e.x) < 3.0 or absf(e.y) < 3.0:
			continue
		var prev := pts[(i - 1 + n) % n]
		var nxt := pts[(i + 2) % n]
		var inward := -edge_normal(a, b)
		var da := (prev - a).normalized()
		var db := (nxt - b).normalized()
		var sa := w / maxf(absf(da.dot(inward)), 0.25)
		var sb := w / maxf(absf(db.dot(inward)), 0.25)
		var a2 := a + da * sa
		var b2 := b + db * sb
		var k := edge_normal(a, b).dot(LIGHT)
		var c_out: Color
		var c_in: Color
		if k > -0.2:
			c_out = Color(1.0, 1.0, 1.0, 0.95 * glint)
			c_in = Color(0.56, 0.9, 1.0, 0.55 * glint)
		else:
			c_out = Color(0.24, 0.55, 1.0, 0.75 * glint)
			c_in = Color(0.06, 0.12, 0.36, 0.6 * glint)
		ci.draw_polygon(PackedVector2Array([a, b, b2, a2]), PackedColorArray([c_out, c_out.lerp(c_in, 0.3), c_in, c_in]))
		ci.draw_line(a2, b2, Color(1, 1, 1, 0.35 * glint), 1.0, true)


## The panel interior split by its cleave into two facets of slightly different light.
static func draw_facet_split(ci: CanvasItem, pts: PackedVector2Array, seed: int, k := 0.05) -> void:
	var r := bounds(pts)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed * 31 + 5)
	var p := Vector2(r.position.x + r.size.x * rng.randf_range(0.48, 0.78), r.position.y - 4.0)
	var q := Vector2(r.position.x + r.size.x * rng.randf_range(0.15, 0.4), r.end.y + 4.0)
	var parts := split(pts, p, q)
	var b_pts: PackedVector2Array = parts[1]
	if b_pts.size() >= 3:
		ci.draw_colored_polygon(b_pts, Color(0.0, 0.0, 0.05, k * 1.6))
	var a_pts: PackedVector2Array = parts[0]
	if a_pts.size() >= 3:
		ci.draw_colored_polygon(a_pts, Color(0.6, 0.85, 1.0, k * 0.5))
	ci.draw_line(p, q, Color(0.7, 0.92, 1.0, 0.1), 1.0, true)


## Inset of a convex clockwise polygon by `d` px (vertex-matched).
static func inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var n0 := -edge_normal(p0, p1)
		var n1 := -edge_normal(p1, p2)
		var l0a := p0 + n0 * d
		var l0b := p1 + n0 * d
		var l1a := p1 + n1 * d
		var l1b := p2 + n1 * d
		var x: Variant = Geometry2D.line_intersects_line(l0a, l0b - l0a, l1a, l1b - l1a)
		out.append(x if x != null else p1 + (n0 + n1).normalized() * d)
	return out


## A facet hairline from the middle of the first cut edge (the longest diagonal edge) into
## the interior: the shard looks cleaved.
static func draw_cleave(ci: CanvasItem, pts: PackedVector2Array, col := Color(0.75, 0.93, 1.0, 0.16), reach := 0.42) -> void:
	var best := -1
	var best_len := 0.0
	var n := pts.size()
	for i in n:
		var e := pts[(i + 1) % n] - pts[i]
		if absf(e.x) > 2.0 and absf(e.y) > 2.0 and e.length() > best_len:
			best = i
			best_len = e.length()
	if best < 0:
		return
	var a := pts[best]
	var b := pts[(best + 1) % n]
	var m := (a + b) * 0.5
	var r := bounds(pts)
	var inward := -edge_normal(a, b)
	# Bend the line a little off the normal so it is not symmetric.
	var dir := inward.rotated(0.38).normalized()
	var length := r.size.length() * reach
	var end := m + dir * length
	end.x = clampf(end.x, r.position.x + 8.0, r.end.x - 8.0)
	end.y = clampf(end.y, r.position.y + 8.0, r.end.y - 8.0)
	ci.draw_line(m, end, col, 1.0, true)
	var c2 := col
	c2.a *= 0.5
	ci.draw_line(m.lerp(end, 0.55), m.lerp(end, 0.55) + dir.rotated(-0.9) * length * 0.32, c2, 1.0, true)


## Glass fill: a Polygon2D child of `parent` with the refractive glass shader.
static func add_glass(parent: Node, pts: PackedVector2Array, o := {}) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = pts
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	var r := bounds(pts)
	m.set_shader_parameter("box_pos", r.position)
	m.set_shader_parameter("box_size", r.size)
	m.set_shader_parameter("tint", o.get("tint", Color("0C1030")))
	m.set_shader_parameter("tint_top", o.get("tint_top", Color("1C2252")))
	m.set_shader_parameter("tint_k", float(o.get("tint_k", 0.86)))
	m.set_shader_parameter("streak_k", float(o.get("streak_k", 1.0)))
	poly.material = m
	parent.add_child(poly)
	return poly


## Cut-shaped hard shadow under an element (two steps, no blur: crystal casts crisp shadows).
static func draw_drop(ci: CanvasItem, pts: PackedVector2Array, d := 8.0, a := 0.42) -> void:
	ci.draw_colored_polygon(moved(pts, Vector2(d * 0.35, d * 1.6)), Color(0.0, 0.0, 0.04, a * 0.45))
	ci.draw_colored_polygon(moved(pts, Vector2(0, d)), Color(0.0, 0.0, 0.04, a))


static func draw_glow(ci: CanvasItem, pts: PackedVector2Array, col: Color, k := 1.0, steps := 4, step_px := 4.0) -> void:
	for i in range(steps, 0, -1):
		var g := grown(pts, step_px * i)
		var c := col
		c.a = 0.07 * k * (1.0 + float(steps - i) * 0.6)
		ci.draw_colored_polygon(g, c)


# ------------------------------------------------------------------ drawing: prisms

## An extruded crystal prism. `pts` is the top face at rest (clockwise); the front face hangs
## `depth` px below it. press 0..1 collapses the extrusion to 2 px (the top moves down).
## Returns the pressed top face polygon (for placing the label).
static func draw_prism(ci: CanvasItem, pts: PackedVector2Array, style: Dictionary, depth := 8.0, press := 0.0, glow := 0.0, cleave := true) -> PackedVector2Array:
	var d := lerpf(depth, 2.0, press)
	var top := moved(pts, Vector2(0, depth - d))
	var tops: Array = style["top"]
	var fronts: Array = style["front"]
	if glow > 0.0:
		draw_glow(ci, moved(pts, Vector2(0, depth * 0.5)), style["glow"], glow, 5, 4.0)
	draw_drop(ci, moved(pts, Vector2(0, depth)), 6.0 if press < 0.5 else 3.0, 0.5)
	# Front (extrusion) faces: every edge that faces down, shaded by its direction.
	var n := top.size()
	var down := Vector2(0, d)
	for i in n:
		var a := top[i]
		var b := top[(i + 1) % n]
		var nr := edge_normal(a, b)
		if nr.y > 0.02:
			var lit := clampf(0.5 - nr.x * 0.55, 0.0, 1.0)
			var col: Color = (fronts[1] as Color).lerp(fronts[0], lit)
			ci.draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), col)
	# Top face, split by one cleave into two facets of slightly different light.
	var r := bounds(top)
	if cleave:
		var p := Vector2(r.position.x + r.size.x * 0.64, r.position.y - 2.0)
		var q := Vector2(r.position.x + r.size.x * 0.47, r.end.y + 2.0)
		var parts := split(top, p, q)
		var a_pts: PackedVector2Array = parts[0]
		var b_pts: PackedVector2Array = parts[1]
		if a_pts.size() >= 3:
			ci.draw_polygon(a_pts, grad_cols(a_pts, r, tops[0], tops[1], 0.25))
		if b_pts.size() >= 3:
			var deep: Color = (tops[2] as Color)
			ci.draw_polygon(b_pts, grad_cols(b_pts, r, (tops[1] as Color).lerp(tops[2], 0.35), deep, 0.25))
		var lc: Color = style["rim"]
		lc.a = 0.55
		ci.draw_line(p.lerp(q, 0.03), p.lerp(q, 0.97), lc, 1.0, true)
	else:
		ci.draw_polygon(top, grad_cols(top, r, tops[0], tops[2], 0.25))
	# Rims: bright on lit edges, a highlight band just inside them.
	for i in n:
		var a := top[i]
		var b := top[(i + 1) % n]
		var k := edge_normal(a, b).dot(LIGHT)
		if k > 0.05:
			var c: Color = style["rim"]
			c.a = clampf(0.55 + k * 0.6, 0.0, 1.0)
			ci.draw_line(a, b, c, 2.0, true)
		else:
			var c2: Color = fronts[1]
			c2.a = 0.85
			ci.draw_line(a, b, c2, 1.0, true)
	draw_chamfers(ci, top, 4.0, 0.7)
	if press > 0.5:
		# Refraction flash.
		ci.draw_colored_polygon(grown(top, -3.0), Color(1, 1, 1, 0.16))
	return top


## A prism button with a centred label (and an optional icon before it).
static func draw_button(ci: CanvasItem, pts: PackedVector2Array, variant: String, label: String, o := {}) -> void:
	var state := str(o.get("state", "normal"))
	var style: Dictionary = PRISMS["disabled" if state == "disabled" else variant]
	var depth := float(o.get("depth", 8.0))
	var top := draw_prism(ci, pts, style, depth, 1.0 if state == "pressed" else 0.0, float(o.get("glow", 0.0)))
	var r := bounds(top)
	var key := str(o.get("font", "button"))
	var size := int(o.get("size", 30))
	var ink: Color = style["ink"]
	var icon := str(o.get("icon", ""))
	var sub := str(o.get("sub", ""))
	var max_w := r.size.x - 36.0 - (float(o.get("icon_px", 40.0)) + 10.0 if icon != "" else 0.0)
	var s := fit_size(label, key, size, max_w, 22)
	var tw := text_w(label, key, s)
	var icon_px := float(o.get("icon_px", 40.0))
	var total := tw + (icon_px + 10.0 if icon != "" else 0.0)
	var cy := r.get_center().y + float(o.get("dy", 0.0)) - (12.0 if sub != "" else 0.0)
	var x := r.get_center().x - total * 0.5 + float(o.get("dx", 0.0))
	if icon != "":
		ForgeIcons.draw(ci, icon, Rect2(x, cy - icon_px * 0.5, icon_px, icon_px), state == "disabled")
		x += icon_px + 10.0
	draw_text_l(ci, label, key, s, Vector2(x, cy), ink)
	if sub != "":
		var sc := ink
		sc.a = 0.72
		draw_text_c(ci, sub, "bold", int(o.get("sub_size", 24)), Vector2(r.get_center().x, cy + s * 0.5 + 18.0), sc, r.size.x - 30.0)


# ------------------------------------------------------------------ drawing: cut gems

## A cut gem: `sides`-gon with a flat table and bevel facets lit from the top-left.
## pal = [light, mid, dark]. Returns the table polygon.
static func draw_gem(ci: CanvasItem, c: Vector2, r: float, sides: int, pal: Array, rot := 0.0, table_k := 0.6, shadow := true) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in sides:
		var a := rot + TAU * float(i) / float(sides) - PI * 0.5
		outer.append(c + Vector2(cos(a), sin(a)) * r)
		inner.append(c + Vector2(cos(a), sin(a)) * r * table_k + Vector2(-0.04, -0.06) * r)
	if shadow:
		ci.draw_colored_polygon(moved(outer, Vector2(0, r * 0.14)), Color(0, 0, 0.04, 0.45))
	for i in sides:
		var a := outer[i]
		var b := outer[(i + 1) % sides]
		var ia := inner[i]
		var ib := inner[(i + 1) % sides]
		var nr := ((a + b) * 0.5 - c).normalized()
		var lit := nr.dot(LIGHT)
		var col: Color
		if lit > 0.0:
			col = (pal[1] as Color).lerp(pal[0], lit)
		else:
			col = (pal[1] as Color).lerp(pal[2], -lit)
		ci.draw_colored_polygon(PackedVector2Array([a, b, ib, ia]), col)
	var tr := bounds(inner)
	ci.draw_polygon(inner, grad_cols(inner, tr, (pal[0] as Color).lerp(pal[1], 0.25), (pal[1] as Color).lerp(pal[0], 0.15), 0.35))
	# Specular sliver on the top-left facet.
	var s0 := outer[sides - 1] if sides > 3 else outer[0]
	var s1 := outer[0]
	var hl := Color(1, 1, 1, 0.55)
	ci.draw_line(s0.lerp(s1, 0.18), s0.lerp(s1, 0.82), hl, 1.6, true)
	return inner


## The level gem: a pointy hexagon of ice with the number on its table.
static func draw_level_gem(ci: CanvasItem, c: Vector2, r: float, text: String, pal: Array = [], ink := INK) -> void:
	var p := pal if not pal.is_empty() else [Color("FFFFFF"), Color("9EE9FF"), Color("2D86D8")]
	draw_gem(ci, c, r, 6, p, 0.0, 0.66)
	var size := int(r * 0.78)
	var s := fit_size(text, "num", size, r * 1.15, 14)
	draw_text_c(ci, text, "num", s, c + Vector2(-1, 0), ink)


# ------------------------------------------------------------------ nodes

## A Control that calls `painter(ci)` in _draw (immediate-mode element).
static func canvas(parent: Node, painter: Callable, rect := Rect2(0, 0, 720, 1280)) -> Control:
	var c := ForgeCanvas.new()
	c.painter = painter
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## A full-screen backdrop (void, nebula, faint geode facets, dust).
static func backdrop(parent: Node, glow_at := Vector2(0.5, 0.18)) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(720, 1280)
	var m := ShaderMaterial.new()
	m.shader = BACKDROP_SHADER
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	m.set_shader_parameter("glow_at", glow_at)
	bg.material = m
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


## A glass shard panel: glass fill + rim + cleave hairline. Returns the polygon.
static func panel(parent: Node, r: Rect2, seed: int, o := {}) -> PackedVector2Array:
	if not o.has("cuts") and not o.has("min_cut"):
		o = o.duplicate()
		var m := minf(r.size.x, r.size.y)
		o["min_cut"] = clampf(m * 0.14, 14.0, 44.0)
		o["max_cut"] = clampf(m * 0.32, 26.0, 96.0)
	var pts := shard(r, seed, o)
	if bool(o.get("drop", true)):
		canvas(parent, func(ci: CanvasItem) -> void: draw_drop(ci, pts, 10.0, 0.38))
	add_glass(parent, pts, o)
	var lit: Color = o.get("rim", RIM)
	canvas(parent, func(ci: CanvasItem) -> void:
		if bool(o.get("facets", true)):
			draw_facet_split(ci, pts, seed)
		if bool(o.get("cleave", true)):
			draw_cleave(ci, pts)
		draw_chamfers(ci, pts, float(o.get("chamfer", 9.0)), float(o.get("glint", 1.0)))
		draw_rim(ci, pts, lit, Color("05061A"), float(o.get("rim_w", 2.0))))
	return pts


## Cleaved crystal headline: extruded (the same depth language as the prisms) and split by a
## slanted cleave, upper facet ice-white, lower facet crystal cyan. Left-aligned at `pos`
## (top-left of the text box); `align` 0 left, 1 centre, 2 right (pos.x is then centre/right).
static func headline(parent: Node, text: String, pos: Vector2, size: int, o := {}) -> Control:
	var key := str(o.get("font", "display"))
	var max_w := float(o.get("max_w", 680.0))
	var s := fit_size(text, key, size, max_w, int(o.get("min", 30)))
	var f := font(key)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var h := f.get_height(s)
	var align := int(o.get("align", 0))
	var x := pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	var depth := int(o.get("depth", maxi(3, s / 14)))
	var asc := f.get_ascent(s)
	var ext_a: Color = o.get("ext_a", Color("1E5CB0"))
	var ext_b: Color = o.get("ext_b", Color("0A1640"))
	var holder := Control.new()
	holder.position = Vector2(x, pos.y)
	holder.size = Vector2(w + 4, h + depth + 4)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	canvas(holder, func(ci: CanvasItem) -> void:
		ci.draw_string(f, Vector2(2, asc + depth + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(0, 0, 0.05, 0.5))
		for i in range(depth, 0, -1):
			var c := ext_b.lerp(ext_a, 1.0 - float(i) / float(depth))
			ci.draw_string(f, Vector2(0, asc + i), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, c), Rect2(Vector2.ZERO, holder.size))
	var face := canvas(holder, func(ci: CanvasItem) -> void:
		ci.draw_string(f, Vector2(0, asc), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color.WHITE), Rect2(Vector2.ZERO, holder.size))
	var m := ShaderMaterial.new()
	m.shader = CLEAVE_SHADER
	m.set_shader_parameter("box_pos", Vector2(0, asc - f.get_ascent(s) * 0.72))
	m.set_shader_parameter("box_size", Vector2(w, f.get_ascent(s) * 0.72))
	for k in ["hi_a", "hi_b", "lo_a", "lo_b"]:
		if o.has(k):
			m.set_shader_parameter(k, o[k])
	m.set_shader_parameter("cleave_y", float(o.get("cleave_y", 0.52)))
	face.material = m
	holder.set_meta("w", w)
	holder.set_meta("size", s)
	return holder


## Wrapped paragraph drawn with draw_multiline_string (deterministic layout). Returns the node.
static func para(parent: Node, text: String, key: String, size: int, col: Color, r: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT, max_lines := -1) -> Control:
	var f := font(key)
	return canvas(parent, func(ci: CanvasItem) -> void:
		ci.draw_multiline_string(f, Vector2(0, f.get_ascent(size)), text, align, r.size.x, size, max_lines, col, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND, TextServer.JUSTIFICATION_NONE), r)


## Text with a dark outline (for text over busy fills), centred on c.
static func draw_text_oc(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color, outline := Color("05061A"), ow := 6) -> void:
	var f := font(key)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(c.x - w * 0.5, c.y + f.get_ascent(size) * 0.72 * 0.5)
	ci.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ow, outline)
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A plain label node (single line).
static func label(parent: Node, text: String, key: String, size: int, col: Color, r: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font(key))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("line_spacing", -2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = not wrap
	parent.add_child(l)
	l.custom_minimum_size = Vector2(r.size.x, 0)
	l.position = r.position
	l.size = r.size
	return l


# ------------------------------------------------------------------ drawing: floating crystals

## A hexagonal crystal (pointed top and bottom) `w` x `h` centred on `c`, tilted `tilt` rad.
static func crystal_pts(c: Vector2, w: float, h: float, tilt := 0.0, lean := 0.08) -> PackedVector2Array:
	var t := h * 0.2
	var hw := w * 0.5
	var p := PackedVector2Array([
		Vector2(w * lean, -h * 0.5), Vector2(hw, -h * 0.5 + t), Vector2(hw, h * 0.5 - t),
		Vector2(-w * lean, h * 0.5), Vector2(-hw, h * 0.5 - t), Vector2(-hw, -h * 0.5 + t)])
	for i in p.size():
		p[i] = c + p[i].rotated(tilt)
	return p


## A floating crystal: lit left half, shaded right half split through the apexes, a polished
## termination facet, rims, a soft floor shadow (it hovers) and an optional glow.
static func draw_crystal(ci: CanvasItem, pts: PackedVector2Array, style: Dictionary, glow := 0.0, hover := 12.0) -> void:
	var tops: Array = style["top"]
	var fronts: Array = style["front"]
	var r := bounds(pts)
	if glow > 0.0:
		draw_glow(ci, pts, style["glow"], glow, 5, 5.0)
	# Floor shadow: a flat ellipse-ish cut polygon under it.
	var sc := Vector2(r.get_center().x, r.end.y + hover)
	var sh := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		sh.append(sc + Vector2(cos(a) * r.size.x * 0.42, sin(a) * 5.0))
	ci.draw_colored_polygon(sh, Color(0, 0, 0.04, 0.4))
	var top := pts[0]
	var bot := pts[3]
	var left := PackedVector2Array([pts[0], pts[3], pts[4], pts[5]])
	var right := PackedVector2Array([pts[0], pts[1], pts[2], pts[3]])
	ci.draw_polygon(left, grad_cols(left, r, tops[0], tops[1], 0.2))
	ci.draw_polygon(right, grad_cols(right, r, (tops[1] as Color).lerp(tops[2], 0.4), fronts[0], 0.2))
	# Termination facets (top lit, bottom deep).
	var mid_l := pts[5].lerp(pts[0], 0.5) + Vector2(r.size.x * 0.12, r.size.y * 0.06)
	ci.draw_colored_polygon(PackedVector2Array([pts[5], pts[0], mid_l]), Color(1, 1, 1, 0.28))
	var mid_b := pts[2].lerp(pts[3], 0.5) + Vector2(-r.size.x * 0.12, -r.size.y * 0.06)
	ci.draw_colored_polygon(PackedVector2Array([pts[2], pts[3], mid_b]), Color(0, 0, 0.1, 0.3))
	var lc: Color = style["rim"]
	lc.a = 0.5
	ci.draw_line(top, bot, lc, 1.0, true)
	draw_rim(ci, pts, style["rim"], fronts[1], 2.0, 0.0)
