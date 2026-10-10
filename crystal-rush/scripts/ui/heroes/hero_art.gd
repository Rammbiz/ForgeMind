class_name HeroArt
extends RefCounted
## Art of heroes and champions in the meta UI (heroes_design.md §9.6, §12.2 HeroArt) with the
## failure-path ladder: splash -> card crop -> live 3D (starters) -> silhouette -> class placeholder.
## Files live in res://assets/heroes/<id>/ : splash.png (full-bleed cut-out, transparent ground),
## card.png (optional dedicated card crop), silhouette.png (optional). Missing or corrupt files
## never crash: the next state down is used.
##
##   HeroArt.state("vesta")                 # "splash"
##   card.art.texture = HeroArt.card_texture("vesta")          # AtlasTexture crop of the splash
##   var tex := await HeroArt.live_portrait(self, "bolt", 256) # starters: one baked render, cached
##   HeroArt.draw_placeholder(self, rect, "warrior", "topaz")  # engraved class emblem on a gem ground
##
## Live 3D portraits: one SubViewport renders once (UIKit.render_portrait, UPDATE_ONCE) and is
## freed; the texture is cached per (id, px) for the session, so a grid of cards costs one
## render per hero, never one viewport per card or per frame.

const DIR := "res://assets/heroes/"
const STATES: Array[String] = ["splash", "card", "live3d", "silhouette", "placeholder"]

## Per-character framing (normalised to the splash): `crop` = the card crop (x, y, w, h),
## `eye` = the eye line (Showcase placement), `focus_x` = where the body sits horizontally,
## optional `scale` (Showcase art size, 1 = full height), `veil` (cream veil behind the info column, 0.5),
## `eye_x` (screen x of the eyes, 0.64) and `max_left` (how far right the art may start, 40 px).
## Update when the owner's final splash lands (assets/heroes/<id>/README.md).
const META := {
	"vesta": {"crop": Rect2(0.33, 0.19, 0.58, 0.40), "eye": Vector2(0.61, 0.315), "focus_x": 0.66},
	# Owner's splashes 2026-10-08 (1K sources in art_src/, empty top band cropped so the eyes sit at ~30 %).
	"titan": {"crop": Rect2(0.30, 0.10, 0.60, 0.54), "eye": Vector2(0.61, 0.30), "focus_x": 0.56, "scale": 0.8, "veil": 0.74},
	"bolt": {"crop": Rect2(0.10, 0.08, 0.60, 0.51), "eye": Vector2(0.40, 0.30), "focus_x": 0.55},
	"seer": {"crop": Rect2(0.29, 0.14, 0.60, 0.44), "eye": Vector2(0.59, 0.30), "focus_x": 0.6, "eye_x": 0.72, "max_left": 120.0, "veil": 0.7},
	"lumen": {"crop": Rect2(0.36, 0.08, 0.60, 0.41), "eye": Vector2(0.67, 0.29), "focus_x": 0.62, "eye_x": 0.74, "max_left": 120.0, "veil": 0.7},
	"arin": {"crop": Rect2(0.40, 0.20, 0.60, 0.37), "eye": Vector2(0.77, 0.30), "focus_x": 0.74},
	"eira": {"crop": Rect2(0.34, 0.20, 0.60, 0.41), "eye": Vector2(0.64, 0.30), "focus_x": 0.62},
	"iskar": {"crop": Rect2(0.38, 0.12, 0.60, 0.44), "eye": Vector2(0.69, 0.30), "focus_x": 0.66, "veil": 0.62},
	"vartan": {"crop": Rect2(0.36, 0.16, 0.60, 0.41), "eye": Vector2(0.65, 0.31), "focus_x": 0.66, "eye_x": 0.70},
	"pava": {"crop": Rect2(0.25, 0.14, 0.60, 0.41), "eye": Vector2(0.55, 0.30), "focus_x": 0.6, "veil": 0.6},
	"sirko": {"crop": Rect2(0.33, 0.15, 0.62, 0.54), "eye": Vector2(0.635, 0.28), "focus_x": 0.62, "eye_x": 0.75, "max_left": 160.0, "veil": 0.76},
	"olha": {"crop": Rect2(0.30, 0.14, 0.62, 0.43), "eye": Vector2(0.52, 0.293), "focus_x": 0.5},
	# Champions (card.png = the 3:4 card; splash.png = the full 9:16 art for cameos)
	"otto": {"crop": Rect2(0.0, 0.17, 1.0, 0.744), "eye": Vector2(0.43, 0.335), "focus_x": 0.55},
	"alba": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.51, 0.33), "focus_x": 0.52},
	"mila": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.58, 0.30), "focus_x": 0.55},
	"ivo": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.57, 0.32), "focus_x": 0.55},
	"borko": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.47, 0.30), "focus_x": 0.55},
	"taya": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.46, 0.39), "focus_x": 0.6},
	"taras": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.58, 0.25), "focus_x": 0.56},
	"snaryad": {"crop": Rect2(0.116, 0.027, 0.866, 0.862), "eye": Vector2(0.50, 0.22), "focus_x": 0.55},
	"dovbush": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.52, 0.21), "focus_x": 0.5},
	"brant": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.58, 0.21), "focus_x": 0.56},
	"teo": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.52, 0.30), "focus_x": 0.52},
	"olena": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.49, 0.29), "focus_x": 0.5},
	"nimb": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.57, 0.27), "focus_x": 0.55},
	"dara": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.55, 0.31), "focus_x": 0.55},
	"menhir": {"crop": Rect2(0.0, 0.0, 1.0, 1.0), "eye": Vector2(0.50, 0.27), "focus_x": 0.52},
}

static var _tex: Dictionary = {}          ## path -> Texture2D (or null when missing)
static var _portraits: Dictionary = {}    ## "id:px" -> Texture2D
static var _pending: Dictionary = {}


## The best art state available for `id` (hero or champion).
static func state(id: String) -> String:
	if _load(DIR + id + "/splash.png") != null:
		return "splash"
	if _load(DIR + id + "/card.png") != null:
		return "card"
	if has_live3d(id):
		return "live3d"
	if _load(DIR + id + "/silhouette.png") != null:
		return "silhouette"
	return "placeholder"


## True for the three starters (HeroModels has a rigged 3D model).
static func has_live3d(id: String) -> bool:
	return HeroModels.HERO_HEIGHT.has(id)


## The full splash (null when missing).
static func splash(id: String) -> Texture2D:
	return _load(DIR + id + "/splash.png")


## An optional alternate splash for a signature walkout beat (Мейра: "eyes_closed" -> the eyes
## open last), pixel-aligned with splash.png; null when the hero has none.
static func splash_variant(id: String, variant: String) -> Texture2D:
	return _load(DIR + id + "/splash_" + variant + ".png")


## The card art: card.png, else a crop of the splash (META crop), else null.
static func card_texture(id: String) -> Texture2D:
	var c := _load(DIR + id + "/card.png")
	if c:
		return c
	var s := splash(id)
	if s == null:
		return null
	var key := "crop:" + id
	if _tex.has(key):
		return _tex[key]
	var r: Rect2 = (META.get(id, {}) as Dictionary).get("crop", Rect2(0.2, 0.1, 0.6, 0.45))
	var sz := Vector2(s.get_width(), s.get_height())
	var at := AtlasTexture.new()
	at.atlas = s
	at.region = Rect2(r.position * sz, r.size * sz)
	_tex[key] = at
	return at


static func silhouette(id: String) -> Texture2D:
	return _load(DIR + id + "/silhouette.png")


## Framing metadata for `id` ({} when none).
static func meta(id: String) -> Dictionary:
	return META.get(id, {})


## A baked live-3D bust of a starter (async; null in headless or for non-starters). Cached per
## (id, px); concurrent callers wait for the one render.
static func live_portrait(host: Node, id: String, px := 256) -> Texture2D:
	if not has_live3d(id) or host == null or not host.is_inside_tree():
		return null
	var key := "%s:%d" % [id, px]
	if _portraits.has(key):
		return _portraits[key]
	var tree := host.get_tree()
	if _pending.has(key):
		while _pending.has(key):
			await tree.process_frame
		return _portraits.get(key)
	_pending[key] = true
	# Render under the tree root, not under the asking card: a card rebuilt mid-render (a grid
	# refresh) must not kill the shared bake.
	await tree.process_frame
	var tex: Texture2D = await UIKit.render_portrait(tree.root, id, px)
	_pending.erase(key)
	if tex:
		_portraits[key] = tex
	return tex


## The cached live portrait if it has been rendered already (no render).
static func cached_portrait(id: String, px := 256) -> Texture2D:
	return _portraits.get("%s:%d" % [id, px])


## The "unknown hero" card art (Genshin-like). Small rects (< RELIEF_MIN px on the short side:
## S cards, chips) get the engraved class emblem in a thin double ring with marquise terminals;
## larger ones (Hall L, champion M, the walkout plate, Team) get the RELIEF mode: the class sigil
## as embossed metal (light top lip, deep lower edge, drop shadow) at about half the art height,
## a large faint cut silhouette of the gem behind it and a gem-light pool. `t` >= 0 adds a slow
## light sweep (pass the owner's clock; leave -1 for a still card).
const RELIEF_MIN := 140.0

static func draw_placeholder(ci: CanvasItem, rect: Rect2, cls: String, gem: String, alpha := 1.0, t := -1.0) -> void:
	if minf(rect.size.x, rect.size.y) >= RELIEF_MIN:
		var cut := str(UITokens.gem(gem)["cut"])
		var c := rect.get_center() + Vector2(0, -rect.size.y * 0.03)
		var gs := minf(rect.size.x, rect.size.y) * (0.5 if cut in ["round", "square"] else 0.46)
		draw_relief(ci, c, gs, cls, gem, alpha, t, minf(rect.size.x, rect.size.y) * 0.8)
		return
	_draw_engraved(ci, rect, cls, gem, alpha)


## The relief sigil centred on `c`: class glyph `glyph_px` wide in embossed pale gold, over a
## gem-light pool and (cut_px > 0) a faint filled silhouette of the gem's cut `cut_px` wide.
static func draw_relief(ci: CanvasItem, c: Vector2, glyph_px: float, cls: String, gem: String, alpha := 1.0,
		t := -1.0, cut_px := 0.0) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var light: Color = g["light"]
	var deep: Color = g["deep"]
	var cut: String = g["cut"]
	var glow := UIKit.glow_texture()
	var pool := maxf(cut_px, glyph_px * 1.5)
	# Gem-light pool + a soft white core: the sigil sits in light, never on a flat ground.
	ci.draw_texture_rect(glow, Rect2(c - Vector2(pool, pool) * 0.85, Vector2(pool, pool) * 1.7), false, Color(light.r, light.g, light.b, 0.34 * alpha))
	ci.draw_texture_rect(glow, Rect2(c - Vector2(glyph_px, glyph_px) * 0.75, Vector2(glyph_px, glyph_px) * 1.5), false, Color(1, 1, 1, 0.2 * alpha))
	if cut_px > 0.0:
		# The cut, large and faint: a filled silhouette with a double-stroked rim (deep groove
		# under a light lip), so the card still names its rarity by shape.
		var pts := GemDraw.cut_points(cut, c + Vector2(0, glyph_px * 0.04), cut_px * 0.5)
		ci.draw_colored_polygon(pts, Color(light.r, light.g, light.b, 0.1 * alpha))
		for k: float in [1.0, 0.9]:
			var pk := GemDraw.cut_points(cut, c + Vector2(0, glyph_px * 0.04), cut_px * 0.5 * k)
			var sh := PackedVector2Array()
			for p in pk:
				sh.append(p + Vector2(0, 1.6))
			GemDraw.outline(ci, sh, Color(deep.r, deep.g, deep.b, 0.25 * alpha), 2.0)
			GemDraw.outline(ci, pk, Color(light.r, light.g, light.b, (0.42 if k == 1.0 else 0.22) * alpha), 1.6)
		for sx: float in [-1.0, 1.0]:
			var d := Vector2(sx, 0)
			GemDraw.draw_marquise(ci, c + d * (cut_px * 0.5 + glyph_px * 0.08), d, glyph_px * 0.12, Color(light.r, light.g, light.b, 0.6 * alpha))
	# The sigil: embossed metal in five passes (soft shadow, deep lower edge, gold body, a lighter
	# bevel on the upper half of the stroke, a white top lip).
	var gr := Rect2(c - Vector2(glyph_px, glyph_px) * 0.5, Vector2(glyph_px, glyph_px))
	var w := clampf(glyph_px * 0.058, 3.0, 15.0)
	var body := Color("#E2BC6A").lerp(light, 0.18)
	var bevel := Color("#F6DFA4").lerp(light, 0.25)
	var edge := Color("#7A5A22").lerp(deep, 0.2)
	var sc := UITokens.SCRIM
	_sigil(ci, cls, Rect2(gr.position + Vector2(w * 0.25, w * 1.0), gr.size), Color(sc.r, sc.g, sc.b, 0.07 * alpha), w * 2.0)
	_sigil(ci, cls, Rect2(gr.position + Vector2(w * 0.15, w * 0.7), gr.size), Color(sc.r, sc.g, sc.b, 0.12 * alpha), w * 1.3)
	_sigil(ci, cls, Rect2(gr.position + Vector2(0, w * 0.42), gr.size), Color(edge.r, edge.g, edge.b, 0.95 * alpha), w * 1.1)
	_sigil(ci, cls, gr, Color(body.r, body.g, body.b, alpha), w)
	_sigil(ci, cls, Rect2(gr.position + Vector2(0, -w * 0.14), gr.size), Color(bevel.r, bevel.g, bevel.b, alpha), w * 0.62)
	_sigil(ci, cls, Rect2(gr.position + Vector2(0, -w * 0.3), gr.size), Color(1, 1, 1, 0.7 * alpha), w * 0.26)
	# A slow light sweep: a glint travelling across the sigil every ~7 s.
	if t >= 0.0:
		var ph := fposmod(t / 7.0, 1.0) * 1.6 - 0.3
		if ph > 0.0 and ph < 1.0:
			var k2 := sin(ph * PI)
			var p2 := gr.position + Vector2(gr.size.x * ph, gr.size.y * (1.0 - ph))
			ci.draw_texture_rect(glow, Rect2(p2 - Vector2(glyph_px, glyph_px) * 0.22, Vector2(glyph_px, glyph_px) * 0.44), false, Color(1, 1, 1, 0.22 * k2 * alpha))
			GemDraw.draw_glint(ci, p2, glyph_px * 0.16, Color(1, 1, 1, 0.8 * k2 * alpha))


## One pass of the class sigil. The large mage sigil is drawn here (a closed ring, the orb and a
## four-point star above it): the kit's small `cls_mage` (an open ring with a stem) reads as a
## power symbol at relief size. Every other class uses the kit's line glyph.
static func _sigil(ci: CanvasItem, cls: String, r: Rect2, col: Color, w: float) -> void:
	if cls != "mage":
		KitIcons.line(ci, "cls_" + cls, r, col, w)
		return
	var s := r.size.x
	var c := r.position + Vector2(s * 0.5, s * 0.56)
	ci.draw_arc(c, s * 0.3, 0.0, TAU, 64, col, w, true)
	ci.draw_arc(c, s * 0.12, 0.0, TAU, 40, col, w, true)
	ci.draw_circle(c + Vector2(-s * 0.035, -s * 0.035), w * 0.55, col, true, -1.0, true)
	# Four-point star above the ring.
	var st := r.position + Vector2(s * 0.5, s * 0.12)
	var a := s * 0.1
	var b := s * 0.028
	var star := PackedVector2Array([st + Vector2(0, -a), st + Vector2(b, -b), st + Vector2(a, 0), st + Vector2(b, b),
			st + Vector2(0, a), st + Vector2(-b, b), st + Vector2(-a, 0), st + Vector2(-b, -b), st + Vector2(0, -a)])
	ci.draw_polyline(star, col, w * 0.7, true)
	# Two short rays from the ring.
	for sx: float in [-1.0, 1.0]:
		var d := Vector2(sx * 0.7071, -0.7071)
		ci.draw_line(c + d * s * 0.36, c + d * s * 0.45, col, w * 0.8, true)


## The small "unknown hero" mark: an engraved class emblem in a thin double ring with marquise
## terminals, in the gem's light tone over the gem ground the card already draws.
static func _draw_engraved(ci: CanvasItem, rect: Rect2, cls: String, gem: String, alpha := 1.0) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var light: Color = g["light"]
	var deep: Color = g["deep"]
	var cut: String = g["cut"]
	var c := rect.get_center() + Vector2(0, -rect.size.y * 0.02)
	var R := minf(rect.size.x, rect.size.y) * 0.34
	var la := 0.6 * alpha
	# Soft light pool behind the emblem.
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 1.5, Vector2(R, R) * 3.0), false, Color(light.r, light.g, light.b, 0.24 * alpha))
	# The gem's own cut, engraved large and faint (double line: a deep groove under a light lip),
	# so the "unknown" card still names its rarity by shape.
	var fit := {"round": [2.05, 0.0, 1.0], "square": [2.0, 0.0, 0.95], "triangle": [2.35, 0.1, 0.72],
			"star": [2.45, 0.06, 0.66], "eye": [2.5, 0.0, 0.6]}
	var fk: Array = fit.get(cut, [2.0, 0.0, 1.0])
	var cc := c + Vector2(0, R * float(fk[1]))
	for k: float in [1.0, 0.88]:
		var pts := GemDraw.cut_points(cut, cc, R * float(fk[0]) * k)
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 1.2))
		GemDraw.outline(ci, sh, Color(deep.r, deep.g, deep.b, 0.32 * alpha), 1.4)
		GemDraw.outline(ci, pts, Color(light.r, light.g, light.b, la * (1.0 if k == 1.0 else 0.6)), 1.2)
	# Marquise terminals left and right of the cut.
	for sx: float in [-1.0, 1.0]:
		var d := Vector2(sx, 0)
		GemDraw.draw_marquise(ci, cc + d * R * (float(fk[0]) * 0.5 + 0.16), d, R * 0.18, Color(light.r, light.g, light.b, 0.7 * alpha))
	# Engraved class glyph: a deep offset stroke under a light stroke.
	var gs := R * 1.12 * float(fk[2])
	var gr := Rect2(cc - Vector2(gs, gs) * 0.5, Vector2(gs, gs))
	var w := clampf(gs * 0.05, 1.6, 4.0)
	KitIcons.line(ci, "cls_" + cls, Rect2(gr.position + Vector2(0, w * 0.7), gr.size), Color(deep.r, deep.g, deep.b, 0.45 * alpha), w)
	KitIcons.line(ci, "cls_" + cls, gr, Color(light.r, light.g, light.b, 0.92 * alpha), w)


static func _load(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex[path] = t
	return t
