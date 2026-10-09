class_name HeroGemEmblem
extends Control
## The gem emblem of a hero / champion (heroes_design.md §2.1): the stone in its cut (Кварц round,
## Сапфір square, Аметист triangle, Топаз star, Опал eye), set in its metal with the right prongs
## (steel 4 claws · white gold 4 double claws · yellow gold 3 V-prongs · gold filigree 5 prongs ·
## gold + a 12-diamond halo), a girdle highlight on the lit edge, and for a black opal the play of
## colour. Rule #3 made visible: a recut character (`native` != `gem`) gets the DOUBLET stone -
## the crown in the current gem, the pavilion in the native gem, a gold seam and a small chip of
## the native cut on the bottom prong. Optional engraved name plate under the stone.
##
##   var e := HeroGemEmblem.make("L", 120)            # Топаз
##   e.native = "E"                                   # recut from Аметист -> doublet
##   e.show_name = true                               # «ТОПАЗ» plate below (adds 26 % height)
## HeroLivingGem (living_gem.gd) adds the facet engrave lines.

var gem := "L":
	set(v):
		gem = HeroesText.gem_letter(v)
		queue_redraw()
var native := "":                ## "" = same as gem; a lower gem draws the doublet
	set(v):
		native = HeroesText.gem_letter(v) if v != "" else ""
		queue_redraw()
var show_setting := true
var show_name := false:
	set(v):
		show_name = v
		queue_redraw()
var live := false:               ## animates the opal fire / a slow glint (off with Reduce Motion)
	set(v):
		live = v
		set_process(v and not UITokens.reduce_motion())
var facets := -1:                ## Living Gem: engraved facet lines 0..5 (-1 = none)
	set(v):
		facets = v
		queue_redraw()
var _t := 0.0

const BODY := {"C": Color("#D6DEE6"), "R": Color("#3FA9FF"), "E": Color("#7A35D6"), "L": Color("#FFB52E"), "M": Color("#1A1530")}
const PRONGS := {"C": 4, "R": 4, "E": 3, "L": 5, "M": 2}


static func make(p_gem: String, px := 96.0, p_native := "") -> HeroGemEmblem:
	var e := HeroGemEmblem.new()
	e.gem = p_gem
	e.native = p_native
	e.custom_minimum_size = Vector2(px, px)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _ready() -> void:
	set_process(live and not UITokens.reduce_motion())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _key(g: String) -> String:
	return UITokens.gem_of(g)


## The stone's box (square) inside the control.
func stone_rect() -> Rect2:
	var name_h := size.y * 0.21 if show_name else 0.0
	var s := minf(size.x, size.y - name_h)
	return Rect2(Vector2((size.x - s) * 0.5, 0.0), Vector2(s, s))


func _draw() -> void:
	var sr := stone_rect()
	var c := sr.get_center()
	var s := sr.size.x * 0.78
	draw_emblem(self, gem, native, c, s, show_setting, _t if live else 0.0)
	if facets >= 0:
		draw_facets(self, gem, c, s, facets, _t if live else 0.0)
	if show_name:
		_draw_name_plate(Rect2(Vector2(0, sr.end.y + size.y * 0.02), Vector2(size.x, size.y * 0.17)))


## The whole emblem centred on `c`, stone size `s`. Static so cards and screens can draw it inline.
static func draw_emblem(ci: CanvasItem, g: String, nat: String, c: Vector2, s: float, setting := true, t := 0.0) -> void:
	var key := UITokens.gem_of(g)
	var spec: Dictionary = UITokens.gem(key)
	var cut: String = spec["cut"]
	var metal: Color = spec["metal"]
	# Soft contact shadow.
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c + Vector2(-s * 0.55, s * 0.18), Vector2(s * 1.1, s * 0.6)), false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.28))
	if setting:
		_draw_setting(ci, g, cut, c, s, metal)
	var body: Color = BODY.get(g, spec["rim"])
	var light: Color = spec["light"]
	var deep: Color = spec["deep"]
	if g == "C":
		deep = Color("#7C8A99")
	GemDraw.draw_gem(ci, cut, c, s, body, light, deep, s >= 30.0)
	if g == "M":
		_draw_opal_fire(ci, c, s, t)
	if nat != "" and nat != g:
		_draw_doublet(ci, g, nat, cut, c, s)
	if s >= 60.0:
		# Large stones: the kit's dark girdle rim reads as a clip-art outline at this size. Cover
		# it with the setting's metal and let a fine gold hairline carry the edge.
		var outer := GemDraw.cut_points(cut, c, s)
		var cover: Color = metal if setting else Color(spec["rim"]).lerp(Color.WHITE, 0.3)
		GemDraw.outline(ci, outer, cover, s * 0.032)
		GemDraw.outline(ci, outer, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.95), maxf(1.5, s * 0.008))
	_draw_girdle_light(ci, cut, c, s)


static func _draw_setting(ci: CanvasItem, g: String, cut: String, c: Vector2, s: float, metal: Color) -> void:
	var bez := GemDraw.cut_points(cut, c, s * 1.13)
	var dark := metal.darkened(0.42)
	var cols := PackedColorArray()
	for p in bez:
		cols.append(metal.lightened(0.25).lerp(metal.darkened(0.12), clampf((p.y - c.y + s * 0.6) / (s * 1.2), 0.0, 1.0)))
	ci.draw_polygon(bez, cols)
	GemDraw.outline(ci, bez, Color(dark.r, dark.g, dark.b, 0.5), clampf(s * 0.01, 1.0, 1.8))
	var outer := GemDraw.cut_points(cut, c, s * 1.0)
	var n := int(PRONGS.get(g, 4))
	var tips := _prong_points(cut, outer, n, c)
	for p in tips:
		var d := (p - c).normalized()
		var w := s * (0.075 if g != "R" else 0.05)
		var L := s * 0.11
		var claw := PackedVector2Array([p - d * L * 0.5 + Vector2(-d.y, d.x) * w, p + d * L * 0.55, p - d * L * 0.5 - Vector2(-d.y, d.x) * w])
		ci.draw_colored_polygon(claw, metal.lightened(0.15))
		GemDraw.outline(ci, claw, Color(dark.r, dark.g, dark.b, 0.7), 1.0)
		if g == "R":
			var off := Vector2(-d.y, d.x) * w * 2.1
			var claw2 := PackedVector2Array([claw[0] + off, claw[1] + off, claw[2] + off])
			ci.draw_colored_polygon(claw2, metal.lightened(0.15))
			GemDraw.outline(ci, claw2, Color(dark.r, dark.g, dark.b, 0.7), 1.0)
	if g == "M":
		# The 12-diamond halo around the black opal.
		for i in 12:
			var a := TAU * i / 12.0
			var p := c + Vector2(cos(a) * s * 0.66, sin(a) * s * 0.44)
			GemDraw.draw_gem(ci, "diamond", p, s * 0.1, Color("#F4F7FF"), Color.WHITE, Color("#9AA6C4"), false)


## Where the prongs sit for each cut.
static func _prong_points(cut: String, outer: PackedVector2Array, n: int, c: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	match cut:
		"star":
			for i in 5:
				out.append(outer[i * 2])
		"triangle":
			for i in 3:
				out.append((outer[i * 2] + outer[i * 2 + 1]) * 0.5)
		"eye":
			out.append(outer[0])
			out.append(outer[12])
		"square":
			for i in 4:
				out.append((outer[i * 2 + 1] + outer[(i * 2 + 2) % 8]) * 0.5)
		_:
			for i in n:
				var a := PI / 4.0 + TAU * i / n
				out.append(c + Vector2(cos(a), sin(a)) * (outer[0] - c).length())
	return out


## Black opal play of colour: soft patches of the four fleck colours + a few sharp sparks.
static func _draw_opal_fire(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var fl: Array = UITokens.gem("opal")["flecks"]
	var glow := UIKit.glow_texture()
	for i in 6:
		var ang := float(i) * 2.1 + t * 0.35
		var rr := s * (0.08 + 0.05 * (i % 3))
		var p := c + Vector2(cos(ang) * s * 0.17, sin(ang * 1.3) * s * 0.1)
		var col: Color = fl[(i + int(t * 0.5)) % fl.size()]
		var k := 0.5 + 0.5 * sin(t * 1.4 + i)
		ci.draw_texture_rect(glow, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col.r, col.g, col.b, 0.42 + 0.25 * k))
	for i in 5:
		var ang := float(i) * 2.4 + 0.6
		var p := c + Vector2(cos(ang), sin(ang) * 0.6) * s * (0.12 + 0.05 * (i % 3))
		var col: Color = fl[i % fl.size()]
		var h := s * 0.035
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -h), p + Vector2(h * 0.7, 0), p + Vector2(0, h), p + Vector2(-h * 0.7, 0)]), Color(col.r, col.g, col.b, 0.9))


## Rule #3 doublet: the lower half (pavilion) in the native gem, a gold seam, a native chip.
static func _draw_doublet(ci: CanvasItem, g: String, nat: String, cut: String, c: Vector2, s: float) -> void:
	var stone := GemDraw.cut_points(cut, c, s)
	var low := PackedVector2Array([c + Vector2(-s, s * 0.06), c + Vector2(s, s * 0.06), c + Vector2(s, s), c + Vector2(-s, s)])
	var nspec: Dictionary = UITokens.gem(nat)
	var nb: Color = BODY.get(nat, nspec["rim"])
	for part in Geometry2D.intersect_polygons(stone, low):
		var poly := part as PackedVector2Array
		if poly.size() < 3:
			continue
		# Pavilion facets: a fan from the culet, alternating lit and shaded (reads as a cut stone).
		var culet := Vector2(c.x, 0.0)
		for p in poly:
			culet.y = maxf(culet.y, p.y)
		culet.y = lerpf(c.y, culet.y, 0.72)
		var ndeep: Color = nspec["deep"]
		var nlight: Color = nspec["light"]
		var n := poly.size()
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var mid := ((a + b) * 0.5 - culet).normalized()
			var lam := clampf(mid.dot(GemDraw.LIGHT_DIR) * 0.5 + 0.5, 0.0, 1.0)
			var col := ndeep.lerp(nb, smoothstep(0.0, 0.6, lam)).lerp(nlight, smoothstep(0.6, 1.0, lam) * 0.6)
			if i % 2 == 1:
				col = col.lightened(0.07)
			ci.draw_colored_polygon(PackedVector2Array([a, b, culet]), col)
		GemDraw.outline(ci, poly, Color(ndeep.r * 0.7, ndeep.g * 0.7, ndeep.b * 0.7, 0.8), maxf(1.0, s * 0.02))
	# Gold seam across the girdle line of the doublet.
	var seam := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([c + Vector2(-s, s * 0.06), c + Vector2(s, s * 0.06)]), stone)
	for sg in seam:
		var line := sg as PackedVector2Array
		if line.size() >= 2:
			ci.draw_line(line[0], line[line.size() - 1], UITokens.GOLD_HI, 1.5 + s * 0.012, true)
			ci.draw_line(line[0] + Vector2(0, 1.2), line[line.size() - 1] + Vector2(0, 1.2), Color(0.45, 0.3, 0.1, 0.5), 1.0, true)
	# Chip of the native cut on the bottom prong.
	var bottom := c + Vector2(0, s * 0.56)
	# The native chip reads at a glance: 30 px on large emblems, in its own gold bezel.
	GemDraw.draw_mark(ci, UITokens.gem_of(nat), bottom, maxf(s * 0.2, minf(30.0, s * 0.3)))


## A thin light rim along the lit (upper-left) girdle edges.
static func _draw_girdle_light(ci: CanvasItem, cut: String, c: Vector2, s: float) -> void:
	var outer := GemDraw.cut_points(cut, c, s)
	var n := outer.size()
	for i in n:
		var a := outer[i]
		var b := outer[(i + 1) % n]
		var mid := ((a + b) * 0.5 - c).normalized()
		var k := mid.dot(GemDraw.LIGHT_DIR)
		if k > 0.25:
			ci.draw_line(a.lerp(c, 0.03), b.lerp(c, 0.03), Color(1, 1, 1, 0.55 * (k - 0.25) / 0.75), maxf(1.0, s * 0.02), true)


## Living Gem facet lines: five engraved lines from the table to the girdle; lit ones glow in
## the gem's light tone with a glint at the girdle; 5 / 5 adds a full light girdle ring.
static func draw_facets(ci: CanvasItem, g: String, c: Vector2, s: float, lit: int, t := 0.0) -> void:
	var spec: Dictionary = UITokens.gem(g)
	var cut: String = spec["cut"]
	var light: Color = spec["light"]
	var outer := GemDraw.cut_points(cut, c, s)
	var tc := c + Vector2(0, -s * 0.03)
	var n := outer.size()
	for i in Ladder.FACETS_PER_GEM:
		var idx := int(roundf(float(i) * n / Ladder.FACETS_PER_GEM + n * 0.1)) % n
		var end := outer[idx].lerp(c, 0.06)
		var start := tc.lerp(end, 0.28)
		if i < lit:
			ci.draw_line(start, end, Color(light.r, light.g, light.b, 0.95), maxf(1.4, s * 0.024), true)
			ci.draw_line(start, end, Color(1, 1, 1, 0.55), maxf(0.8, s * 0.01), true)
			GemDraw.draw_glint(ci, end, s * 0.16, Color(1, 1, 1, 0.85))
		else:
			ci.draw_line(start, end, Color(0.1, 0.08, 0.15, 0.22), maxf(1.0, s * 0.014), true)
			ci.draw_line(start + Vector2(0, 1), end + Vector2(0, 1), Color(1, 1, 1, 0.16), maxf(1.0, s * 0.012), true)
	if lit >= Ladder.FACETS_PER_GEM:
		var k := 0.75 + 0.25 * sin(t * 2.0)
		GemDraw.outline(ci, outer, Color(light.r, light.g, light.b, 0.9 * k), maxf(1.5, s * 0.03))


func _draw_name_plate(r: Rect2) -> void:
	var f := UIKit.font_caps(int(clampf(r.size.y * 0.62, 16.0, 24.0)))
	var fs := int(clampf(r.size.y * 0.62, 16.0, 24.0))
	var txt := HeroesText.gem_name(gem).to_upper()
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pw := minf(r.size.x, tw + r.size.y * 1.6)
	var pr := Rect2(Vector2(r.position.x + (r.size.x - pw) * 0.5, r.position.y), Vector2(pw, r.size.y))
	var pts := GemDraw.chamfer_rect(pr, minf(8.0, r.size.y * 0.3))
	draw_colored_polygon(pts, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.94))
	GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.2)
	GemDraw.draw_marquise(self, Vector2(pr.position.x - 6.0, pr.get_center().y), Vector2.RIGHT, 9.0)
	GemDraw.draw_marquise(self, Vector2(pr.end.x + 6.0, pr.get_center().y), Vector2.RIGHT, 9.0)
	draw_string(f, Vector2(pr.get_center().x - tw * 0.5, pr.get_center().y + f.get_ascent(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.GOLD_TEXT)
