class_name EnamelKit
## «Емаль і золото» (UI direction C, dev mockup): the hub is built from the same stuff as the
## owner's war machines - WHITE ENAMEL plates, GOLD trim, ICE-CRYSTAL inlays and RIVETS.
## It inverts the generic dark game panel: dark navy ink stamped into white enamel.
## One owned shape at every scale: the MACHINED PLATE (top-left and bottom-right corners cut
## at 45 deg, the other two with a small radius). Buttons are physical KEYS with a skirt,
## tabs are toggle keys, counters are mechanical ODOMETER rollers, panels hang on a gold rail.

const PLATE_SHADER := preload("res://assets/ui/skins/enamel/enamel_plate.gdshader")
const BACKDROP_SHADER := preload("res://assets/ui/skins/enamel/enamel_backdrop.gdshader")
const NOISE_TEX := preload("res://assets/textures/cloud_noise.png")

# ------------------------------------------------------------------ palette
const ENAMEL := Color("F4F1EA")
const ENAMEL_SHADE := Color("E3DDD0")
const SKIRT := Color("9E9481")
const INK := Color("1B2147")
const INK_DIM := Color("5A6188")
const GOLD := Color("E2B04A")
const GOLD_LIGHT := Color("FFE7A3")
const GOLD_MID := Color("B17F2A")
const GOLD_DARK := Color("7A4E12")
const ICE := Color("8FEAFF")
const ICE_WHITE := Color("E9FBFF")
const ICE_DEEP := Color("33B6F0")
const CTA := Color("3CB8FF")
const CTA_SKIRT := Color("1F6FA8")
const RED := Color("C8322B")
const VOID := Color("0A0B1F")
const NEBULA := Color("2A1450")
const WINDOW := Color("10163A")
const WHITE := Color("FFFFFF")

## Plate materials: face [top, mid, bottom], skirt [top, bottom], trim [dark, mid, light], ink.
const MATS := {
	"enamel": {"face": [Color("FFFFFF"), Color("F4F1EA"), Color("E3DDD0")], "skirt": [Color("C9C0AE"), Color("9E9481")],
		"trim": [GOLD_DARK, GOLD, GOLD_LIGHT], "ink": INK, "outline": Color(0.04, 0.05, 0.14, 0.8)},
	"ice": {"face": [Color("A8E6FF"), Color("4CC0FF"), Color("2A9BE6")], "skirt": [Color("1F6FA8"), Color("123F6E")],
		"trim": [GOLD_DARK, GOLD, GOLD_LIGHT], "ink": WHITE, "outline": Color(0.03, 0.06, 0.16, 0.85)},
	"red": {"face": [Color("F06A5C"), Color("C8322B"), Color("A0231E")], "skirt": [Color("6E1612"), Color("3E0A08")],
		"trim": [Color("0C0C10"), Color("2A2A30"), Color("6A6A74")], "ink": WHITE, "outline": Color(0.05, 0.02, 0.03, 0.85)},
	"navy": {"face": [Color("2C366E"), Color("1E2656"), Color("161C44")], "skirt": [Color("0E1232"), Color("070A1E")],
		"trim": [GOLD_DARK, GOLD, GOLD_LIGHT], "ink": ENAMEL, "outline": Color(0.0, 0.0, 0.05, 0.85)},
	"gold": {"face": [Color("FFF1C4"), Color("F2C766"), Color("D69E36")], "skirt": [Color("9A6A1C"), Color("5E3C0A")],
		"trim": [Color("6A420C"), Color("B17F2A"), Color("FFE7A3")], "ink": Color("3A2206"), "outline": Color(0.12, 0.07, 0.0, 0.8)},
	"disabled": {"face": [Color("D9D6D0"), Color("C9C5BD"), Color("B9B4AA")], "skirt": [Color("8F897E"), Color("6E695F")],
		"trim": [Color("6E6A64"), Color("A29E96"), Color("D4D0C8")], "ink": Color("8A8780"), "outline": Color(0.05, 0.05, 0.1, 0.6)},
	# Sunk trays and windows.
	"tray": {"face": [Color("D8D1C2"), Color("E1DBCE"), Color("EAE5DA")], "skirt": [Color("C9C0AE"), Color("9E9481")],
		"trim": [GOLD_DARK, GOLD, GOLD_LIGHT], "ink": INK, "outline": Color(1, 1, 1, 0.0)},
	"window": {"face": [Color("1A2152"), Color("141A44"), Color("0C1030")], "skirt": [Color("0E1232"), Color("070A1E")],
		"trim": [Color("1F6FA8"), Color("33B6F0"), Color("E9FBFF")], "ink": ENAMEL, "outline": Color(1, 1, 1, 0.0)},
}

## Rarity = the colour of the ice inlay set into the plate. [light, mid, deep, name, ink-on-white]
const RARITY := {
	"C": [Color("FFFFFF"), Color("C9D2E0"), Color("7A869C"), "Звичайна", Color("5E687E")],
	"R": [Color("E9FBFF"), Color("4CC0FF"), Color("1A6FC0"), "Рідкісна", Color("1A6FC0")],
	"E": [Color("F0E2FF"), Color("A66BFF"), Color("5A26B8"), "Епічна", Color("6A2FC8")],
	"L": [Color("FFF4C8"), Color("FFC23C"), Color("B06C10"), "Легендарна", Color("9A5C08")],
	"M": [Color("FFE0D4"), Color("FF6A4A"), Color("A82410"), "Міфічна", Color("B02A14")],
}

# ------------------------------------------------------------------ type
## [file, axes, extra px per glyph, OpenType features]
const FONT_SPECS := {
	# Dela Gothic One: heavy, squarish counters, Japanese-gothic proportions. Titles, keys.
	"display": ["res://assets/fonts/DelaGothicOne-Regular.ttf", {}, 0, {}],
	# Tracked caps labels (+ ~6 %).
	"caps": ["res://assets/fonts/DelaGothicOne-Regular.ttf", {}, 2, {}],
	# Counters: Dela with tabular figures.
	"num": ["res://assets/fonts/DelaGothicOne-Regular.ttf", {}, 0, {"tnum": 1}],
	# Oi: poured-enamel blobs. Logo, ПЕРЕМОГА and the ×N gate badges only (>= 56 px).
	"logo": ["res://assets/fonts/Oi-Regular.ttf", {}, 0, {}],
	# Podkova: slab serifs like rivets. Body and small labels.
	"body": ["res://assets/fonts/Podkova-VF.ttf", {"wght": 700}, 0, {}],
	"bold": ["res://assets/fonts/Podkova-VF.ttf", {"wght": 800}, 0, {}],
}

static var _fonts := {}


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
	if not va.is_empty():
		fv.variation_opentype = va
	fv.spacing_glyph = int(spec[2])
	var feats := {}
	for tag: String in spec[3]:
		feats[ts.name_to_tag(tag)] = spec[3][tag]
	if not feats.is_empty():
		fv.opentype_features = feats
	_fonts[key] = fv
	return fv


static func text_w(text: String, key: String, size: int) -> float:
	return font(key).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Largest size <= `size` (and >= `min_size`) at which `text` fits `max_w`.
static func fit_size(text: String, key: String, size: int, max_w: float, min_size := 26) -> int:
	var s := size
	while s > min_size and text_w(text, key, s) > max_w:
		s -= 1
	return s


## Text styles: "deboss" = ink stamped into enamel (white lip under the letters),
## "raised" = light ink on a coloured key (soft dark drop under), "plain".
static func _draw_styled(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, col: Color, style: String) -> void:
	match style:
		"deboss":
			ci.draw_string(f, pos + Vector2(0, 1.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.9))
			ci.draw_string(f, pos + Vector2(0, -0.8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0.05, 0.25))
		"raised":
			ci.draw_string(f, pos + Vector2(0, 2.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.02, 0.06, 0.2, 0.45))
		"shadow":
			ci.draw_string_outline(f, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.0, 0.0, 0.06, 0.55))
			ci.draw_string(f, pos + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.06, 0.75))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Cap-height centred on c (left edge at c.x). Returns width.
static func text_l(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color, style := "deboss") -> float:
	var f := font(key)
	var cap := f.get_ascent(size) * (0.70 if key != "body" and key != "bold" else 0.66)
	_draw_styled(ci, f, Vector2(c.x, c.y + cap * 0.5), text, size, col, style)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text_c(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color, style := "deboss", max_w := -1.0) -> float:
	var s := size if max_w <= 0.0 else fit_size(text, key, size, max_w, mini(size, 26))
	var w := text_w(text, key, s)
	text_l(ci, text, key, s, Vector2(c.x - w * 0.5, c.y), col, style)
	return w


static func text_r(ci: CanvasItem, text: String, key: String, size: int, c: Vector2, col: Color, style := "deboss") -> float:
	var w := text_w(text, key, size)
	text_l(ci, text, key, size, Vector2(c.x - w, c.y), col, style)
	return w


# ------------------------------------------------------------------ nodes

static func canvas(parent: Node, painter: Callable) -> EnamelCanvas:
	var c := EnamelCanvas.new()
	c.size = Vector2(720, 1280)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.painter = painter
	parent.add_child(c)
	return c


static func backdrop(parent: Node, glow_at := Vector2(0.7, 0.25), dim := 0.0) -> ColorRect:
	var cr := ColorRect.new()
	cr.size = Vector2(720, 1280)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = BACKDROP_SHADER
	m.set_shader_parameter("noise_tex", NOISE_TEX)
	m.set_shader_parameter("glow_at", glow_at)
	m.set_shader_parameter("dim", dim)
	cr.material = m
	parent.add_child(cr)
	return cr


## A machined enamel plate occupying `r` (face + skirt). Options:
##   mat (MATS key), ch (chamfer leg, default by height), rad (small radius), corners
##   ("tlbr" default, "trbl" mirrored, "all", "none"), depth (skirt px), press (0..1),
##   recess (bool), trim (px, 0 = none), inset, rivet (radius), rivet_every, glow (Color),
##   glow_r, shadow (0..1), spec, bevel, outline_w.
static func plate(parent: Node, r: Rect2, o := {}) -> ColorRect:
	var pad := float(o.get("pad", 22.0))
	var cr := ColorRect.new()
	cr.position = r.position - Vector2(pad, pad)
	cr.size = r.size + Vector2(pad, pad) * 2.0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: Dictionary = MATS[o.get("mat", "enamel")]
	var m := ShaderMaterial.new()
	m.shader = PLATE_SHADER
	m.set_shader_parameter("size", cr.size)
	m.set_shader_parameter("pad", pad)
	var h := r.size.y - float(o.get("depth", 0.0))
	var ch := float(o.get("ch", 16.0 if h > 90.0 else (10.0 if h > 44.0 else 6.0)))
	var rad := float(o.get("rad", 6.0 if h > 44.0 else 4.0))
	var cmap := {
		"tlbr": [Vector4(ch, 0, ch, 0), Vector4(0, rad, 0, rad)],
		"trbl": [Vector4(0, ch, 0, ch), Vector4(rad, 0, rad, 0)],
		"all": [Vector4(ch, ch, ch, ch), Vector4.ZERO],
		"none": [Vector4.ZERO, Vector4(rad, rad, rad, rad)],
		"tl": [Vector4(ch, 0, 0, 0), Vector4(0, rad, rad, rad)],
		"br": [Vector4(0, 0, ch, 0), Vector4(rad, rad, 0, rad)],
	}
	var cc: Array = cmap[o.get("corners", "tlbr")]
	m.set_shader_parameter("chamfers", cc[0])
	m.set_shader_parameter("radii", cc[1])
	m.set_shader_parameter("depth", float(o.get("depth", 0.0)))
	m.set_shader_parameter("press", float(o.get("press", 0.0)))
	m.set_shader_parameter("recess", 1.0 if o.get("recess", false) else 0.0)
	var face: Array = mat["face"]
	m.set_shader_parameter("face_top", face[0])
	m.set_shader_parameter("face_mid", face[1])
	m.set_shader_parameter("face_bot", face[2])
	var sk: Array = mat["skirt"]
	m.set_shader_parameter("skirt_top", sk[0])
	m.set_shader_parameter("skirt_bot", sk[1])
	var tr: Array = o.get("trim_cols", mat["trim"])
	m.set_shader_parameter("trim_dark", tr[0])
	m.set_shader_parameter("trim_mid", tr[1])
	m.set_shader_parameter("trim_light", tr[2])
	m.set_shader_parameter("outline", o.get("outline", mat["outline"]))
	m.set_shader_parameter("outline_w", float(o.get("outline_w", 1.6)))
	m.set_shader_parameter("trim_w", float(o.get("trim", 4.0 if h > 44.0 else 3.0)))
	m.set_shader_parameter("trim_inset", float(o.get("inset", 3.0)))
	m.set_shader_parameter("rivet_r", float(o.get("rivet", 0.0)))
	m.set_shader_parameter("rivet_every", float(o.get("rivet_every", 0.0)))
	m.set_shader_parameter("spec_k", float(o.get("spec", 0.55)))
	m.set_shader_parameter("bevel_k", float(o.get("bevel", 0.22)))
	m.set_shader_parameter("bevel_w", float(o.get("bevel_w", 7.0)))
	m.set_shader_parameter("shadow_k", float(o.get("shadow", 0.45)))
	m.set_shader_parameter("shadow_off", o.get("shadow_off", Vector2(0, 7)))
	var g: Color = o.get("glow", Color(0, 0, 0, 0))
	m.set_shader_parameter("glow", g)
	m.set_shader_parameter("glow_r", float(o.get("glow_r", 14.0)))
	cr.material = m
	parent.add_child(cr)
	return cr


## The face rectangle of a key `r` with skirt `depth`, pressed by `press`.
static func face_of(r: Rect2, depth: float, press := 0.0) -> Rect2:
	var sink := press * maxf(depth - 3.0, 0.0)
	return Rect2(r.position.x, r.position.y + sink, r.size.x, r.size.y - depth)


## A physical key: plate with skirt + centred label (+ optional sub line). Options as plate()
## plus: label size `size`, font `font`, `sub`, `sub_size`, `icon` (Callable(ci, face_rect)),
## `state` ("", "pressed", "disabled"), `inlay` (Color list for an ice lozenge at the left).
static func key(parent: Node, r: Rect2, label: String, o := {}) -> Rect2:
	var state: String = o.get("state", "")
	var po := o.duplicate()
	var depth := float(o.get("depth", 10.0))
	po["depth"] = depth
	if state == "pressed":
		po["press"] = 1.0
	if state == "disabled":
		po["mat"] = "disabled"
		po["shadow"] = 0.25
	plate(parent, r, po)
	var fr := face_of(r, depth, 1.0 if state == "pressed" else 0.0)
	var mat: Dictionary = MATS[po.get("mat", "enamel")]
	var ink: Color = o.get("ink", mat["ink"])
	var style := "deboss" if ink.get_luminance() < 0.5 else "raised"
	if state == "disabled":
		style = "deboss"
	canvas(parent, func(ci: CanvasItem) -> void:
		var x0 := fr.position.x
		var x1 := fr.end.x
		if o.has("inlay"):
			var ih := minf(fr.size.y * 0.62, 46.0)
			var ic := Vector2(x0 + 18.0 + ih * 0.42, fr.get_center().y)
			draw_inlay(ci, ic, Vector2(ih * 0.84, ih), o["inlay"])
			x0 = ic.x + ih * 0.42 + 4.0
		if o.has("icon"):
			var cb: Callable = o["icon"]
			x0 = cb.call(ci, fr)
		var fkey: String = o.get("font", "display")
		var size := int(o.get("size", 34))
		var cy := fr.get_center().y
		var sub: String = o.get("sub", "")
		if sub != "":
			cy -= float(o.get("sub_size", 26)) * 0.52
		var w := x1 - x0 - 24.0
		var s := fit_size(label, fkey, size, w, mini(size, 26))
		text_c(ci, label, fkey, s, Vector2((x0 + x1) * 0.5, cy), ink, style)
		if sub != "":
			var ss := int(o.get("sub_size", 26))
			var scol: Color = o.get("sub_ink", Color(ink, 0.82))
			text_c(ci, sub, "bold", fit_size(sub, "bold", ss, w, 22), Vector2((x0 + x1) * 0.5, cy + ss * 1.12), scol, style))
	return fr


# ------------------------------------------------------------------ immediate-mode parts

## Polygon fill + 1 px anti-aliased edge in the same colour (soft edges without MSAA).
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, 1.0, true)


## Vertical gradient rect through `cols` at even stops.
static func vgrad(ci: CanvasItem, r: Rect2, cols: Array) -> void:
	var n := cols.size() - 1
	for i in n:
		var y0 := r.position.y + r.size.y * float(i) / n
		var y1 := r.position.y + r.size.y * float(i + 1) / n
		ci.draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0), Vector2(r.end.x, y1), Vector2(r.position.x, y1)]),
			PackedColorArray([cols[i], cols[i], cols[i + 1], cols[i + 1]]))


## The owned plate outline as a polygon (for small canvas-drawn tokens and chips).
static func plate_pts(r: Rect2, ch: float, rad := 3.0, corners := "tlbr") -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tl := corners in ["tlbr", "all", "tl"]
	var tr := corners in ["trbl", "all"]
	var br := corners in ["tlbr", "all", "br"]
	var bl := corners in ["trbl", "all"]
	var cs := [[r.position, tl, Vector2(0, 1), Vector2(1, 0), 180.0], [Vector2(r.end.x, r.position.y), tr, Vector2(-1, 0), Vector2(0, 1), 270.0],
		[r.end, br, Vector2(0, -1), Vector2(-1, 0), 0.0], [Vector2(r.position.x, r.end.y), bl, Vector2(1, 0), Vector2(0, -1), 90.0]]
	for c: Array in cs:
		var p: Vector2 = c[0]
		if c[1]:
			pts.append(p + c[2] * ch)
			pts.append(p + c[3] * ch)
		else:
			# small radius arc
			var ctr := p + (c[2] + c[3]) * rad
			for k in 4:
				var a := deg_to_rad(float(c[4]) + 90.0 * k / 3.0)
				pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
	return pts


## Faceted ice (or rarity) lozenge set into the enamel: 4 facets in 3 tones + a glint.
## cols = [light, mid, deep].
static func draw_inlay(ci: CanvasItem, c: Vector2, sz: Vector2, cols: Array, glint := true) -> void:
	var hw := sz.x * 0.5
	var hh := sz.y * 0.5
	var t := c + Vector2(0, -hh)
	var rr := c + Vector2(hw, 0)
	var b := c + Vector2(0, hh)
	var l := c + Vector2(-hw, 0)
	# gold seat
	var seat := PackedVector2Array([t + Vector2(0, -3.5), rr + Vector2(3.5, 0), b + Vector2(0, 3.5), l + Vector2(-3.5, 0)])
	poly(ci, seat, GOLD_DARK)
	var seat2 := PackedVector2Array([t + Vector2(0, -2.2), rr + Vector2(2.2, 0), b + Vector2(0, 2.2), l + Vector2(-2.2, 0)])
	poly(ci, seat2, GOLD)
	var m := c + Vector2(-hw * 0.12, -hh * 0.12)
	poly(ci, PackedVector2Array([t, m, l]), cols[0])
	poly(ci, PackedVector2Array([t, rr, m]), (cols[0] as Color).lerp(cols[1], 0.55))
	poly(ci, PackedVector2Array([l, m, b]), cols[1])
	poly(ci, PackedVector2Array([m, rr, b]), cols[2])
	# table facet
	var tb := PackedVector2Array([m + Vector2(0, -hh * 0.38), m + Vector2(hw * 0.38, 0), m + Vector2(0, hh * 0.38), m + Vector2(-hw * 0.38, 0)])
	poly(ci, tb, Color(cols[1]).lerp(Color.WHITE, 0.35))
	if glint:
		star(ci, t.lerp(l, 0.35) + Vector2(2, 2), maxf(sz.y * 0.22, 5.0), Color(1, 1, 1, 0.95))


## 4-point glint star.
static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w := r * 0.22
	poly(ci, PackedVector2Array([c + Vector2(0, -r), c + Vector2(w, -w), c + Vector2(r, 0), c + Vector2(w, w),
		c + Vector2(0, r), c + Vector2(-w, w), c + Vector2(-r, 0), c + Vector2(-w, -w)]), col)


## A gold rivet dome drawn on the canvas (for elements without the plate shader).
static func rivet(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0.8, 1.4), r * 1.05, Color(0, 0, 0.05, 0.4), true, -1.0, true)
	ci.draw_circle(c, r, GOLD_DARK, true, -1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.08, -r * 0.1), r * 0.82, GOLD, true, -1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.45, GOLD_LIGHT, true, -1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.36), r * 0.16, Color.WHITE, true, -1.0, true)


## Mechanical ODOMETER counter: every digit sits on its own roller in a recessed navy window
## framed in gold; spaces become a thin gold divider. Cap-centred on c.y from c.x. Returns width.
static func odometer(ci: CanvasItem, text: String, size: int, c: Vector2, o := {}) -> float:
	var f := font("num")
	var cw := float(o.get("cell_w", round(size * 0.86)))
	var ch := float(o.get("cell_h", round(size * 1.34)))
	var gap := 2.0
	var x := c.x
	var y0 := c.y - ch * 0.5
	var digit_col: Color = o.get("ink", ENAMEL)
	var total := 0.0
	for i in text.length():
		var s := text[i]
		total += (cw + gap) if s != " " else 5.0
	total -= gap
	# Gold frame round the whole strip.
	var fr := Rect2(x - 3.0, y0 - 3.0, total + 6.0, ch + 6.0)
	ci.draw_rect(Rect2(fr.position + Vector2(0, 2), fr.size), Color(0, 0, 0.05, 0.35))
	vgrad(ci, fr, [GOLD_LIGHT, GOLD, GOLD_MID, GOLD_DARK])
	for i in text.length():
		var s := text[i]
		if s == " ":
			x += 5.0
			continue
		var cell := Rect2(x, y0, cw, ch)
		# Roller: dark at the top and bottom, lit across the middle (a cylinder).
		vgrad(ci, cell, [Color("05071A"), Color("1C2350"), Color("2A3266"), Color("1C2350"), Color("05071A")])
		var gw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var cap := f.get_ascent(size) * 0.70
		ci.draw_string(f, Vector2(x + (cw - gw) * 0.5, c.y + cap * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, digit_col)
		# glass glint across the top of the window
		ci.draw_rect(Rect2(x + 1, y0 + ch * 0.18, cw - 2, 1.5), Color(1, 1, 1, 0.13))
		x += cw + gap
	return total


# ------------------------------------------------------------------ chrome helpers

## A short horizontal gold bar (rail) with rivets at the ends.
static func rail(ci: CanvasItem, a: Vector2, b: Vector2, h := 10.0, rivets := true) -> void:
	var r := Rect2(a.x, a.y - h * 0.5, b.x - a.x, h)
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0.05, 0.45))
	vgrad(ci, r, [GOLD_LIGHT, GOLD, GOLD_MID, GOLD_DARK])
	ci.draw_line(r.position + Vector2(0, 1), Vector2(r.end.x, r.position.y + 1), Color(1, 1, 0.9, 0.6), 1.0)
	if rivets:
		rivet(ci, Vector2(a.x + h * 0.8, a.y), h * 0.36)
		rivet(ci, Vector2(b.x - h * 0.8, a.y), h * 0.36)


## Red-enamel notification stud with a white number.
static func stud(ci: CanvasItem, c: Vector2, n: String, r := 17.0) -> void:
	ci.draw_circle(c + Vector2(0, 2.5), r + 1.5, Color(0, 0, 0.05, 0.4), true, -1.0, true)
	ci.draw_circle(c, r + 1.5, Color("2A0806"), true, -1.0, true)
	ci.draw_circle(c, r, Color("A0231E"), true, -1.0, true)
	ci.draw_circle(c + Vector2(0, -1.5), r - 2.0, RED, true, -1.0, true)
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.4), r * 0.3, Color(1, 0.75, 0.7, 0.55), true, -1.0, true)
	text_c(ci, n, "num", int(r * 1.15), c + Vector2(0, -0.5), WHITE, "raised")
