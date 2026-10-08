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
## `eye` = the eye line (Showcase placement), `focus_x` = where the body sits horizontally.
## Update when the owner's final splash lands (assets/heroes/<id>/README.md).
const META := {
	"vesta": {"crop": Rect2(0.33, 0.19, 0.58, 0.40), "eye": Vector2(0.61, 0.315), "focus_x": 0.66},
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


## The "unknown hero" card art (Genshin-like): an engraved class emblem in a thin double ring
## with marquise terminals, in the gem's light tone over the gem ground the card already draws.
static func draw_placeholder(ci: CanvasItem, rect: Rect2, cls: String, gem: String, alpha := 1.0) -> void:
	var g: Dictionary = UITokens.gem(gem)
	var light: Color = g["light"]
	var deep: Color = g["deep"]
	var c := rect.get_center() + Vector2(0, -rect.size.y * 0.02)
	var R := minf(rect.size.x, rect.size.y) * 0.34
	var la := 0.55 * alpha
	# Soft light pool behind the emblem.
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 1.5, Vector2(R, R) * 3.0), false, Color(light.r, light.g, light.b, 0.22 * alpha))
	# Double ring (engraved: a deep line under a light line).
	for k: float in [1.0, 0.86]:
		ci.draw_arc(c + Vector2(0, 1.2), R * k, 0, TAU, 72, Color(deep.r, deep.g, deep.b, 0.35 * alpha), 1.4, true)
		ci.draw_arc(c, R * k, 0, TAU, 72, Color(light.r, light.g, light.b, la), 1.2, true)
	# Marquise terminals at the four cardinal points.
	for i in 4:
		var d := Vector2.from_angle(i * PI * 0.5 - PI * 0.5)
		GemDraw.draw_marquise(ci, c + d * R * 1.08, d, R * 0.16, Color(light.r, light.g, light.b, 0.7 * alpha))
	# Engraved class glyph: a deep offset stroke under a light stroke.
	var gs := R * 1.12
	var gr := Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs))
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
