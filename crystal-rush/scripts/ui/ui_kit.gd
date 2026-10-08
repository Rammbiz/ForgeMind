class_name UIKit
## UI v2 design system ("Genshin x AFK Journey", contract: scratchpad/uiv2/ui_v2_contract.md).
## Light warm cream surfaces, ONE thin gold hairline, soft shadows, small 45-degree chamfered
## corners (gem-girdle cut), M PLUS Rounded 1c, no text outlines. The amber jewel CTA is the
## only loud element.
## Surfaces are nine-patch StyleBoxTextures painted in code once (cached in user://ui_cache).
## Bitmap override hook: when res://assets/ui/kit/<name>.png exists it replaces the painted
## style / icon / gem (nine-patch margins from res://assets/ui/kit/kit.json).
## The legacy API (lux kinds, button(), heading(), TEXT, GOLD ...) keeps working and is remapped
## to the v2 look; see the contract for the semantic tokens to use in new code.

# ------------------------------------------------------------------ v2 semantic tokens
const INK := UITokens.INK                 ## text on cream
const INK_DIM := UITokens.INK_DIM         ## taupe labels on cream
const INK_SOFT := UITokens.INK_SOFT       ## small labels (18 px)
const ON_SCENE := UITokens.ON_SCENE       ## warm white on 3D / art (always soft_shadow())
const PAPER_0 := UITokens.PAPER_0
const CREAM := UITokens.PAPER_1
const CREAM_2 := UITokens.PAPER_2
const CREAM_3 := UITokens.PAPER_3
const HAIRLINE := UITokens.HAIRLINE
const GOLD_HI := UITokens.GOLD_HI
const GOLD_TEXT := UITokens.GOLD_TEXT
const CTA_HI := UITokens.CTA_HI
const CTA := UITokens.CTA
const CTA_LO := UITokens.CTA_LO
const CTA_RIM := UITokens.CTA_RIM
const CTA_TEXT := Color("#FFFDF6")        ## label on the amber CTA (with a soft amber shadow)
const SCRIM := UITokens.SCRIM
const PLUS := UITokens.PLUS
const ALERT := UITokens.ALERT

# ------------------------------------------------------------------ legacy names (remapped)
## TEXT used to be light-on-dark; v2 surfaces are cream, so TEXT is now ink. Text that sits
## directly on a 3D scene or art must use ON_SCENE (+ soft_shadow) instead.
const TEXT := INK
const TEXT_DIM := INK_DIM
## Honey gold: readable on cream (3.5:1 at >= 20 px bold) and as a fill.
const GOLD := Color("#B07A26")
## Light gold: glows, sparkles and text ON SCENES only (invisible on cream).
const GOLD_LIGHT := Color("#F6DC9A")
const GOLD_DARK := GOLD_TEXT
const PANEL := Color(0.969, 0.945, 0.902, 0.94)
const PANEL_LIGHT := PAPER_0
const NAVY := UITokens.SOCKET
const RED := UITokens.ALERT_FILL
const GREEN := PLUS
const ICE := Color("#3FA9FF")
const VIOLET := Color("#B06CFF")
const PRIMARY := CTA
const PRIMARY_DARK := CTA_RIM
const BROWN := Color("#5A3210")            ## deep brown text on amber / gold fills

const KIT_DIR := "res://assets/ui/kit/"

const SHINE_SHADER_PATH := "res://shaders/ui/sweep.gdshader"

const GRADIENT_TEXT_SHADER := """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(1.0, 0.97, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.88, 0.5, 0.12, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 64.0;
varying float ly;
varying vec4 vcol;
void vertex() {
	ly = VERTEX.y;
	vcol = COLOR;
}
void fragment() {
	// Only the glyph fill (font colour is white); shadows keep their colour.
	if (vcol.r > 0.6 && vcol.g > 0.6 && vcol.b > 0.6) {
		float t = clamp((ly - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(top_color.rgb, mid_color.rgb, t * 2.0) : mix(mid_color.rgb, bottom_color.rgb, t * 2.0 - 1.0);
		COLOR.rgb = g * vcol.rgb;
	}
}
"""

static var _theme: Theme
static var _fonts := {}
static var _styles := {}
static var _textures := {}
static var _shine_shader: Shader
static var _text_shader: Shader
static var _kit_json: Dictionary = {}
static var _kit_json_loaded := false
static var _kit_tex := {}
## Set false to ignore owner bitmaps (specimen comparisons).
static var kit_enabled := true


# ------------------------------------------------------------------ fonts

## M PLUS Rounded 1c. `bold` = Bold (titles, buttons); else Medium (body).
static func font(bold := false) -> Font:
	return font_w("bold" if bold else "medium")


## Weight: "regular" | "medium" | "bold" | "extrabold" (display numbers, CTA labels).
static func font_w(weight := "medium") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var file := {"regular": "Regular", "medium": "Medium", "bold": "Bold", "extrabold": "ExtraBold"}.get(weight, "Medium") as String
	var f := _load_font("res://assets/fonts/MPLUSRounded1c-%s.ttf" % file)
	_fonts[weight] = f
	return f


## Caps label font: Medium with +6 % tracking (FontVariation), cached per size bucket.
static func font_caps(size := 20) -> Font:
	var key := "caps_%d" % size
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = font_w("bold")
	fv.spacing_glyph = maxi(1, int(round(size * 0.06)))
	_fonts[key] = fv
	return fv


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f is FontFile:
			(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			(f as FontFile).generate_mipmaps = true
			(f as FontFile).hinting = TextServer.HINTING_LIGHT
			(f as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		return f
	return ThemeDB.fallback_font


# ------------------------------------------------------------------ bitmap override hook

## The owner's bitmap res://assets/ui/kit/<name>.png, or null (procedural fallback).
static func kit_texture(name: String) -> Texture2D:
	if not kit_enabled:
		return null
	if _kit_tex.has(name):
		return _kit_tex[name]
	var path := KIT_DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_kit_tex[name] = tex
	return tex


## kit.json entry of `name` ({margins:[l,t,r,b], pad:[x,y], expand:[l,t,r,b]}), or {}.
static func kit_spec(name: String) -> Dictionary:
	if not _kit_json_loaded:
		_kit_json_loaded = true
		var p := KIT_DIR + "kit.json"
		if FileAccess.file_exists(p):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_kit_json = d
	return _kit_json.get(name, {}) as Dictionary


## Drops cached styles / bitmaps (after assets change at runtime, or kit_enabled toggles).
static func reload_kit() -> void:
	_kit_tex.clear()
	_kit_json_loaded = false
	_kit_json = {}
	_styles.clear()
	_theme = null


static func _kit_style(kind: String, pad: Vector2) -> StyleBoxTexture:
	var tex := kit_texture(kind)
	if tex == null:
		return null
	var js := kit_spec(kind)
	var s := StyleBoxTexture.new()
	s.texture = tex
	var m: Array = js.get("margins", [24, 24, 24, 24])
	s.texture_margin_left = float(m[0])
	s.texture_margin_top = float(m[1])
	s.texture_margin_right = float(m[2])
	s.texture_margin_bottom = float(m[3])
	var e: Array = js.get("expand", [0, 0, 0, 0])
	s.expand_margin_left = float(e[0])
	s.expand_margin_top = float(e[1])
	s.expand_margin_right = float(e[2])
	s.expand_margin_bottom = float(e[3])
	var spec := _spec(kind)
	var p: Vector2 = spec.get("pad", Vector2(16, 10)) if pad.x < 0.0 else pad
	if js.has("pad"):
		p = Vector2(float(js["pad"][0]), float(js["pad"][1]))
	s.content_margin_left = p.x
	s.content_margin_right = p.x
	s.content_margin_top = p.y
	s.content_margin_bottom = p.y
	return s


# ------------------------------------------------------------------ flat box (legacy)

## Flat box for small drawn widgets. v2: corners are 45-degree chamfers (corner_detail 1),
## capped at 12 px (never pills), shadows are soft slate.
static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 18, border_w := 0, shadow := 0, pad := Vector2(18, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(mini(radius, 12))
	s.corner_detail = 1
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.2)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.4)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s


## Chamfered flat box in v2 colours: `bg` fill, optional gold hairline.
static func cbox(bg: Color, chamfer := 8, line := HAIRLINE, line_w := 0, pad := Vector2(12, 6)) -> StyleBoxFlat:
	var s := box(bg, line, chamfer, line_w, 0, pad)
	return s


# ------------------------------------------------------------------ painted styles

## Nine-patch styles, painted once and cached (or the owner's bitmap of the same name).
## v2 kinds:
##   "panel" / "cream" / "parch"     cream document panel, outer hairline + inner hairline
##   "cream_glass"                   translucent cream over 3D (porcelain), one hairline
##   "sheet"                         cream sheet body (KitSheet adds the arched top)
##   "modal"                         panel with a deeper shadow
##   "card" / "parch_card"           cream card; "card_sel" amber double line + glow; "card_dim" unowned
##   "pill" / "plate" / "chip"       porcelain HUD plate / currency plate / small chip; "pill_dark" no line
##   "button" (+_pressed/_disabled)  secondary cream button
##   "primary" (+_pressed/_disabled) amber jewel CTA body ("green" maps here: no green CTAs)
##   "primary_compact"               CTA body for narrow price buttons (no topaz room)
##   "ghost"                         transparent with a hairline; "text" tertiary (no surface)
##   "seg" / "seg_sel"               segmented track / raised chip with an amber underline
##   "tab_track"                     underline-tab rail (bottom hairline only)
##   "tabbar" / "tab_sel"            bottom nav bar body / raised selected tab chip
##   "banner" / "toast"              tutorial hint / toast (cream glass, hairline)
##   "ribbon"                        title plate body; "well" / "parch_well" inset well
##   "band_amber" / "band_cool"      full-width result bands; "tag_new" NEW tag
## `pad` sets the content margins.
static func lux(kind: String, pad := Vector2(-1, -1)) -> StyleBox:
	var key := "%s_%d_%d" % [kind, int(pad.x), int(pad.y)]
	if _styles.has(key):
		return _styles[key]
	var ov := _kit_style(kind, pad)
	if ov:
		_styles[key] = ov
		return ov
	var spec := _spec(kind)
	var tkey := str(spec).md5_text()
	var tex: Texture2D = _textures.get(tkey)
	if tex == null:
		tex = ImageTexture.create_from_image(_cached_paint(kind, spec))
		_textures[tkey] = tex
	var s := StyleBoxTexture.new()
	s.texture = tex
	var sh := _shadow_room(spec)
	var m := _margin(spec)
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.expand_margin_left = sh
	s.expand_margin_right = sh
	s.expand_margin_top = sh
	s.expand_margin_bottom = sh
	var p: Vector2 = spec["pad"] if pad.x < 0.0 else pad
	var shift: float = spec.get("shift", 0.0)
	s.content_margin_left = p.x
	s.content_margin_right = p.x
	s.content_margin_top = p.y + shift
	s.content_margin_bottom = maxf(0.0, p.y - shift)
	_styles[key] = s
	return s


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func _spec(kind: String) -> Dictionary:
	var line := {"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE}
	match kind:
		"panel", "cream", "parch":
			return {"cham": 12.0, "blur": 16.0, "sh_a": 0.2, "sh_dy": 5.0, "pad": Vector2(36, 30), "layers": [
				{"top": PAPER_0, "bot": CREAM},
				{"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE},
				{"inset": 5.0, "ring": 1.0, "top": _a(HAIRLINE, 0.55), "bot": _a(HAIRLINE, 0.4)},
			]}
		"modal":
			return {"cham": 12.0, "blur": 24.0, "sh_a": 0.3, "sh_dy": 8.0, "pad": Vector2(36, 32), "layers": [
				{"top": PAPER_0, "bot": CREAM},
				{"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE},
				{"inset": 5.0, "ring": 1.0, "top": _a(HAIRLINE, 0.55), "bot": _a(HAIRLINE, 0.4)},
			]}
		"cream_glass", "glass":
			return {"cham": 10.0, "blur": 14.0, "sh_a": 0.18, "sh_dy": 4.0, "pad": Vector2(22, 14), "layers": [
				{"top": _a(PAPER_0, 0.9), "bot": _a(CREAM, 0.84)},
				{"ring": 1.5, "top": _a(HAIRLINE, 0.95), "bot": _a(HAIRLINE, 0.85)},
			]}
		"sheet":
			return {"cham": 12.0, "blur": 20.0, "sh_a": 0.18, "sh_dy": -2.0, "pad": Vector2(26, 28), "layers": [
				{"top": CREAM, "bot": CREAM},
				{"ring": 2.0, "top": HAIRLINE, "bot": HAIRLINE},
				{"inset": 5.0, "ring": 1.0, "top": _a(HAIRLINE, 0.5), "bot": _a(HAIRLINE, 0.35)},
			]}
		"card", "parch_card":
			return {"cham": 10.0, "blur": 10.0, "sh_a": 0.16, "sh_dy": 3.0, "pad": Vector2(16, 14), "layers": [
				{"top": PAPER_0, "bot": CREAM},
				line,
			]}
		"card_sel":
			return {"cham": 10.0, "blur": 14.0, "sh_a": 0.2, "sh_dy": 3.0, "glow": _a(CTA, 0.5), "pad": Vector2(16, 14), "layers": [
				{"top": PAPER_0, "bot": PAPER_0},
				{"ring": 2.0, "top": Color("#D9A74A"), "bot": Color("#C98F36")},
				{"inset": 4.0, "ring": 1.0, "top": _a(CTA, 0.9), "bot": _a(CTA_LO, 0.7)},
			]}
		"card_dim":
			return {"cham": 10.0, "blur": 6.0, "sh_a": 0.1, "sh_dy": 2.0, "pad": Vector2(16, 14), "layers": [
				{"top": CREAM_3, "bot": Color("#DCCFB8")},
				{"ring": 1.5, "top": _a(HAIRLINE, 0.6), "bot": _a(HAIRLINE, 0.5)},
			]}
		"pill", "plate":
			return {"cham": 8.0, "blur": 8.0, "sh_a": 0.25, "sh_dy": 2.0, "pad": Vector2(16, 6), "layers": [
				{"top": _a(PAPER_0, 0.94), "bot": _a(CREAM, 0.92)},
				line,
			]}
		"pill_dark":
			return {"cham": 8.0, "blur": 8.0, "sh_a": 0.22, "sh_dy": 2.0, "pad": Vector2(16, 6), "layers": [
				{"top": _a(PAPER_0, 0.9), "bot": _a(CREAM, 0.88)},
				{"ring": 1.0, "top": _a(CREAM_3, 0.9), "bot": _a(CREAM_3, 0.9)},
			]}
		"chip":
			return {"cham": 6.0, "blur": 5.0, "sh_a": 0.16, "sh_dy": 1.5, "pad": Vector2(14, 4), "layers": [
				{"top": _a(PAPER_0, 0.96), "bot": _a(CREAM, 0.95)},
				{"ring": 1.2, "top": HAIRLINE, "bot": HAIRLINE},
			]}
		"banner", "toast":
			return {"cham": 10.0, "blur": 14.0, "sh_a": 0.24, "sh_dy": 4.0, "pad": Vector2(26, 14), "layers": [
				{"top": _a(PAPER_0, 0.95), "bot": _a(CREAM, 0.93)},
				{"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE},
				{"inset": 4.0, "ring": 1.0, "top": _a(HAIRLINE, 0.45), "bot": _a(HAIRLINE, 0.3)},
			]}
		"ribbon":
			return {"cham": 8.0, "blur": 8.0, "sh_a": 0.18, "sh_dy": 2.0, "pad": Vector2(30, 6), "layers": [
				{"top": _a(PAPER_0, 0.94), "bot": _a(CREAM, 0.92)},
				{"ring": 1.2, "top": HAIRLINE, "bot": HAIRLINE},
			]}
		"button":
			return {"cham": 8.0, "blur": 6.0, "sh_a": 0.16, "sh_dy": 2.0, "pad": Vector2(28, 10), "layers": [
				{"top": Color("#F3EDE2"), "bot": CREAM_2},
				line,
			]}
		"button_pressed":
			return {"cham": 8.0, "blur": 3.0, "sh_a": 0.1, "sh_dy": 1.0, "shift": 2.0, "pad": Vector2(28, 10), "layers": [
				{"top": CREAM_3, "bot": Color("#E8DECC")},
				line,
			]}
		"button_disabled":
			return {"cham": 8.0, "blur": 0.0, "pad": Vector2(28, 10), "layers": [
				{"top": _a(CREAM_2, 0.75), "bot": _a(CREAM_3, 0.7)},
				{"ring": 1.2, "top": _a(HAIRLINE, 0.45), "bot": _a(HAIRLINE, 0.45)},
			]}
		"ghost":
			return {"cham": 8.0, "blur": 0.0, "pad": Vector2(24, 8), "layers": [
				{"top": _a(PAPER_0, 0.18), "bot": _a(PAPER_0, 0.1)},
				{"ring": 1.5, "top": _a(HAIRLINE, 0.9), "bot": _a(HAIRLINE, 0.9)},
			]}
		"ghost_pressed":
			return {"cham": 8.0, "blur": 0.0, "shift": 2.0, "pad": Vector2(24, 8), "layers": [
				{"top": _a(PAPER_0, 0.45), "bot": _a(PAPER_0, 0.35)},
				{"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE},
			]}
		"text", "text_pressed":
			return {"cham": 6.0, "blur": 0.0, "pad": Vector2(14, 6), "layers": [
				{"top": _a(CREAM_3, 0.0 if kind == "text" else 0.45), "bot": _a(CREAM_3, 0.0 if kind == "text" else 0.45)},
			]}
		"primary", "green", "primary_compact":
			return {"cham": 12.0, "blur": 12.0, "sh_a": 0.3, "sh_dy": 4.0, "sh_col": Color("#7A3E10"),
					"pad": Vector2(36, 10), "layers": [
				{"top": Color("#C98536"), "bot": CTA_RIM},
				{"inset": 1.5, "top": CTA_HI, "mid": CTA, "bot": CTA_LO},
				{"inset": 1.5, "sheen": 0.16},
				{"inset": 3.5, "ring": 1.0, "top": Color(1, 0.98, 0.88, 0.7), "bot": Color(1, 0.9, 0.7, 0.18)},
			]}
		"primary_pressed", "green_pressed":
			return {"cham": 12.0, "blur": 6.0, "sh_a": 0.24, "sh_dy": 2.0, "sh_col": Color("#7A3E10"), "shift": 2.0,
					"pad": Vector2(36, 10), "layers": [
				{"top": Color("#B8742A"), "bot": CTA_RIM},
				{"inset": 1.5, "top": Color("#FFD98A"), "mid": Color("#EC9F3A"), "bot": Color("#CC7426")},
				{"inset": 3.5, "ring": 1.0, "top": Color(1, 0.95, 0.8, 0.45), "bot": Color(1, 0.9, 0.7, 0.1)},
			]}
		"primary_disabled":
			return {"cham": 12.0, "blur": 0.0, "pad": Vector2(36, 10), "layers": [
				{"top": Color("#CDBFA6"), "bot": Color("#B9AA8F")},
				{"inset": 1.5, "top": Color("#EFE6D6"), "bot": Color("#DDD0BA")},
			]}
		"parch_well", "well":
			return {"cham": 6.0, "blur": 0.0, "pad": Vector2(12, 8), "layers": [
				{"top": _a(CREAM_3, 0.85), "bot": _a(CREAM_2, 0.8)},
				{"ring": 1.0, "top": _a(HAIRLINE, 0.5), "bot": _a(HAIRLINE, 0.3)},
			]}
		"seg":
			return {"cham": 8.0, "blur": 0.0, "pad": Vector2(4, 4), "layers": [
				{"top": _a(CREAM_3, 0.7), "bot": _a(CREAM_2, 0.75)},
				{"ring": 1.0, "top": _a(HAIRLINE, 0.7), "bot": _a(HAIRLINE, 0.7)},
			]}
		"seg_sel":
			return {"cham": 6.0, "blur": 5.0, "sh_a": 0.16, "sh_dy": 1.5, "pad": Vector2(18, 6), "layers": [
				{"top": PAPER_0, "bot": PAPER_0},
				{"ring": 1.2, "top": HAIRLINE, "bot": HAIRLINE},
				{"line": "bottom", "y": 4.0, "w": 2.0, "inset_x": 16.0, "col": CTA_LO},
			]}
		"tab_track":
			return {"cham": 0.0, "blur": 0.0, "pad": Vector2(8, 6), "layers": [
				{"line": "bottom", "y": 0.0, "w": 1.0, "inset_x": 0.0, "col": _a(HAIRLINE, 0.8)},
			]}
		"tabbar":
			return {"cham": 0.0, "blur": 14.0, "sh_a": 0.14, "sh_dy": -3.0, "pad": Vector2(8, 8), "layers": [
				{"top": _a(PAPER_0, 0.96), "bot": _a(CREAM, 0.96)},
				{"line": "top", "y": 0.0, "w": 1.5, "inset_x": 0.0, "col": HAIRLINE},
			]}
		"tab_sel":
			return {"cham": 10.0, "blur": 10.0, "sh_a": 0.18, "sh_dy": 3.0, "pad": Vector2(8, 8), "layers": [
				{"top": PAPER_0, "bot": CREAM},
				{"ring": 1.5, "top": HAIRLINE, "bot": HAIRLINE},
				{"line": "bottom", "y": 5.0, "w": 2.0, "inset_x": 18.0, "col": CTA_LO},
			]}
		"band_amber":
			return {"cham": 0.0, "blur": 16.0, "sh_a": 0.22, "sh_dy": 4.0, "pad": Vector2(24, 12), "layers": [
				{"top": Color("#FFE1A0"), "mid": CTA, "bot": Color("#E3913A")},
				{"line": "top", "y": 5.0, "w": 1.5, "inset_x": 0.0, "col": Color(1, 0.97, 0.86, 0.8)},
				{"line": "bottom", "y": 5.0, "w": 1.5, "inset_x": 0.0, "col": Color(1, 0.95, 0.8, 0.6)},
			]}
		"band_cool":
			return {"cham": 0.0, "blur": 16.0, "sh_a": 0.2, "sh_dy": 4.0, "pad": Vector2(24, 12), "layers": [
				{"top": CREAM, "bot": CREAM_2},
				{"line": "top", "y": 5.0, "w": 1.5, "inset_x": 0.0, "col": Color("#8E98AA")},
				{"line": "bottom", "y": 5.0, "w": 1.5, "inset_x": 0.0, "col": Color("#8E98AA")},
			]}
		"tag_new":
			return {"cham": 5.0, "blur": 3.0, "sh_a": 0.18, "sh_dy": 1.0, "pad": Vector2(8, 1), "layers": [
				{"top": Color("#FFDD6E"), "bot": UITokens.NEW_TAG},
				{"ring": 1.0, "top": Color("#C99A2A"), "bot": Color("#B5861E")},
			]}
	return _spec("card")


## Painting in GDScript costs a few ms per style, so painted images are cached as PNGs in
## user://ui_cache (keyed by a hash of the spec); later launches load them instantly.
static func _cached_paint(kind: String, spec: Dictionary) -> Image:
	var path := "user://ui_cache/v2_%s_%s.png" % [kind, str(spec).md5_text().substr(0, 10)]
	if FileAccess.file_exists(path):
		var cached := Image.load_from_file(path)
		if cached and not cached.is_empty():
			return cached
	var img := _paint(spec)
	DirAccess.make_dir_recursive_absolute("user://ui_cache")
	img.save_png(path)
	return img


static func _shadow_room(spec: Dictionary) -> float:
	var blur: float = spec.get("blur", 0.0)
	if blur <= 0.0 and not spec.has("glow"):
		return 0.0
	return ceilf(maxf(blur, 8.0 if spec.has("glow") else 0.0) + absf(float(spec.get("sh_dy", 0.0))))


static func _margin(spec: Dictionary) -> float:
	return ceilf(_shadow_room(spec) + float(spec.get("cham", 0.0)) + 8.0)


## Signed distance to a box (centre, half size) with 45-degree corner chamfers `ch`.
static func _sd(p: Vector2, center: Vector2, half: Vector2, ch: float) -> float:
	var q := (p - center).abs() - half
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	if ch > 0.0:
		d = maxf(d, (q.x + q.y + ch) * 0.70710678)
	return d


## Paints a nine-patch image from a layer spec: a soft drop shadow (and optional glow), then
## chamfered layers: fills (2-3 stop vertical gradients), hairline rings, sheen, straight lines.
static func _paint(spec: Dictionary) -> Image:
	var ch: float = spec.get("cham", 0.0)
	var sh := _shadow_room(spec)
	var blur: float = spec.get("blur", 0.0)
	var sh_a: float = spec.get("sh_a", 0.0)
	var sh_dy: float = spec.get("sh_dy", 0.0)
	var sh_col: Color = spec.get("sh_col", SCRIM)
	var margin := _margin(spec)
	var w := int(margin * 2.0 + 8.0)
	var h := int(margin * 2.0 + 24.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Rect2(sh, sh, w - sh * 2.0, h - sh * 2.0)
	var center := body.get_center()
	var half := body.size * 0.5
	var glow: Color = spec.get("glow", Color(0, 0, 0, 0))
	var layers: Array = spec["layers"]
	var sig := maxf(blur / 2.4, 0.5)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			if blur > 0.0 and sh_a > 0.0:
				var ds := _sd(p, center + Vector2(0, sh_dy), half - Vector2(1, 1), ch)
				var a := sh_a if ds <= 0.0 else sh_a * exp(-(ds * ds) / (2.0 * sig * sig))
				col = Color(sh_col.r, sh_col.g, sh_col.b, a)
			if glow.a > 0.0:
				var dg := _sd(p, center, half, ch)
				if dg > 0.0:
					var ga := glow.a * exp(-(dg * dg) / (2.0 * 16.0))
					col = _over(col, Color(glow.r, glow.g, glow.b, ga))
			var d0 := _sd(p, center, half, ch)
			for L: Dictionary in layers:
				if L.has("line"):
					var lw: float = L["w"]
					var ix: float = L.get("inset_x", 0.0)
					var ly: float = body.position.y + float(L.get("y", 0.0)) if str(L["line"]) == "top" else body.end.y - float(L.get("y", 0.0)) - lw
					if p.x < body.position.x + ix or p.x > body.end.x - ix or d0 > 0.0:
						continue
					var cov_y := clampf(minf(p.y - ly + 0.5, ly + lw - p.y + 0.5), 0.0, 1.0)
					if cov_y <= 0.0:
						continue
					var lc: Color = L["col"]
					col = _over(col, Color(lc.r, lc.g, lc.b, lc.a * cov_y))
					continue
				var inset: float = L.get("inset", 0.0)
				var d := d0 + inset
				var cov := clampf(0.5 - d, 0.0, 1.0)
				if cov <= 0.0:
					continue
				var top_y := body.position.y + inset
				var t := clampf((p.y - top_y) / maxf(body.size.y - inset * 2.0, 1.0), 0.0, 1.0)
				if L.has("sheen"):
					var ty := p.y - top_y
					var s: float = L["sheen"]
					var fall := 1.0 - smoothstep(0.0, minf((body.size.y - inset * 2.0) * 0.5, 30.0), ty)
					col = _over(col, Color(1, 1, 1, clampf(fall * s * cov, 0.0, 1.0)))
					continue
				var c: Color
				if L.has("mid"):
					c = (L["top"] as Color).lerp(L["mid"], t * 2.0) if t < 0.5 else (L["mid"] as Color).lerp(L["bot"], t * 2.0 - 1.0)
				else:
					c = (L["top"] as Color).lerp(L["bot"], t)
				if L.has("ring"):
					var rw: float = L["ring"]
					cov *= 1.0 - clampf(0.5 - (d + rw), 0.0, 1.0)
				col = _over(col, Color(c.r, c.g, c.b, c.a * cov))
			img.set_pixel(x, y, col)
	return img


static func _over(dst: Color, src: Color) -> Color:
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	var r := (src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / a
	var g := (src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / a
	var b := (src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / a
	return Color(r, g, b, a)


## A soft round glow sprite (white, alpha falls off), for halos behind icons and numbers.
static func glow_texture() -> Texture2D:
	if _textures.has("_glow"):
		return _textures["_glow"]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	var tex := ImageTexture.create_from_image(img)
	_textures["_glow"] = tex
	return tex


## Particle sprite: our refraction glint (4 rays, one long, soft core). No 4-point sparkles.
static func sparkle_texture() -> Texture2D:
	if _textures.has("_sparkle"):
		return _textures["_sparkle"]
	var ov := kit_texture("fx_glint")
	if ov:
		_textures["_sparkle"] = ov
		return ov
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rot := -0.35
	var cr := cos(rot)
	var sr := sin(rot)
	for y in n:
		for x in n:
			var p0 := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var p := Vector2(p0.x * cr - p0.y * sr, p0.x * sr + p0.y * cr)
			# Ray lengths: right 0.62, left 0.42, up 0.4, down 1.0 (the long streak).
			var lx := 0.62 if p.x > 0.0 else 0.42
			var ly := 1.0 if p.y > 0.0 else 0.4
			var rx := maxf(0.0, 1.0 - absf(p.y) * 14.0 - absf(p.x) / lx)
			var ry := maxf(0.0, 1.0 - absf(p.x) * 14.0 - absf(p.y) / ly)
			var core := maxf(0.0, 1.0 - p.length() * 3.2)
			var a := clampf(rx + ry + core * core * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures["_sparkle"] = tex
	return tex


# ------------------------------------------------------------------ theme

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(false)
	t.default_font_size = 24
	# Labels: ink on cream, no outline, no shadow.
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 2)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", font(false))
	t.set_font("bold_font", "RichTextLabel", font(true))
	# Secondary buttons: cream with a gold hairline.
	t.set_stylebox("normal", "Button", lux("button"))
	t.set_stylebox("hover", "Button", lux("button"))
	t.set_stylebox("pressed", "Button", lux("button_pressed"))
	t.set_stylebox("hover_pressed", "Button", lux("button_pressed"))
	t.set_stylebox("disabled", "Button", lux("button_disabled"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font(true))
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", _a(INK_DIM, 0.75))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 10)
	t.set_color("icon_normal_color", "Button", INK)
	t.set_color("icon_hover_color", "Button", INK)
	t.set_color("icon_pressed_color", "Button", INK)
	# Key actions: the amber jewel (Green maps to it: our CTA pair is cream + amber).
	for v: String in ["PrimaryButton", "GreenButton"]:
		t.set_type_variation(v, "Button")
		t.set_stylebox("normal", v, lux("primary"))
		t.set_stylebox("hover", v, lux("primary"))
		t.set_stylebox("pressed", v, lux("primary_pressed"))
		t.set_stylebox("hover_pressed", v, lux("primary_pressed"))
		t.set_stylebox("disabled", v, lux("primary_disabled"))
		t.set_font("font", v, font_w("extrabold"))
		t.set_font_size("font_size", v, 32)
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(k, v, CTA_TEXT)
		t.set_color("font_disabled_color", v, INK_DIM)
		# A faint warm halo (alpha 0.3) instead of a stroke: Button has no text shadow.
		t.set_color("font_outline_color", v, Color(0.55, 0.27, 0.05, 0.3))
		t.set_constant("outline_size", v, 6)
	# Panels
	t.set_stylebox("panel", "PanelContainer", lux("panel"))
	t.set_stylebox("panel", "Panel", lux("panel"))
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", lux("pill"))
	t.set_type_variation("TipPanel", "PanelContainer")
	t.set_stylebox("panel", "TipPanel", lux("banner"))
	t.set_type_variation("GlassPanel", "PanelContainer")
	t.set_stylebox("panel", "GlassPanel", lux("cream_glass"))
	# Sliders: thin cream track, amber fill, cream disc grabber with a gold ring.
	var track := cbox(CREAM_3, 4, HAIRLINE, 1, Vector2(0, 4))
	var fill := cbox(CTA, 4, CTA_LO, 1, Vector2(0, 4))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _disc_tex(34, PAPER_0, HAIRLINE))
	t.set_icon("grabber_highlight", "HSlider", _disc_tex(34, Color.WHITE, CTA_LO))
	# Progress bars
	t.set_stylebox("background", "ProgressBar", cbox(CREAM_3, 3, HAIRLINE, 1, Vector2.ZERO))
	t.set_stylebox("fill", "ProgressBar", cbox(CTA, 3, CTA_LO, 0, Vector2.ZERO))
	t.set_color("font_color", "ProgressBar", INK)
	# Thin scrollbars (cream grabber, no track).
	for sb: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, StyleBoxEmpty.new())
		t.set_stylebox("scroll_focus", sb, StyleBoxEmpty.new())
		var g := cbox(_a(HAIRLINE, 0.55), 3, HAIRLINE, 0, Vector2(3, 3))
		t.set_stylebox("grabber", sb, g)
		t.set_stylebox("grabber_highlight", sb, cbox(_a(HAIRLINE, 0.8), 3, HAIRLINE, 0, Vector2(3, 3)))
		t.set_stylebox("grabber_pressed", sb, cbox(HAIRLINE, 3, HAIRLINE, 0, Vector2(3, 3)))
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", lux("toast", Vector2(14, 8)))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t


static func _disc_tex(size: int, fill: Color, ring: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var body := clampf(r - 2.0 - d, 0.0, 1.0)
			var sh := clampf(r - d, 0.0, 1.0) * 0.18
			var c := Color(SCRIM.r, SCRIM.g, SCRIM.b, sh)
			c = _over(c, Color(fill.r, fill.g, fill.b, body))
			var ring_a := clampf(1.0 - absf(d - (r - 3.0)) / 1.0, 0.0, 1.0)
			c = _over(c, Color(ring.r, ring.g, ring.b, ring_a))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Legacy name (sliders used it): a cream disc with a gold ring.
static func _circle_tex(size: int, c: Color) -> Texture2D:
	return _disc_tex(size, c, HAIRLINE)


# ------------------------------------------------------------------ text

static func _is_light(c: Color) -> bool:
	return c.get_luminance() > 0.62


## Label. v2: never outlined (`outline` is ignored). Light colours get a soft shadow
## automatically (they only appear on scenes); ink colours get none.
static func label(text: String, size := 24, color := TEXT, bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	l.add_theme_constant_override("outline_size", 0)
	if _is_light(color) and outline > 0:
		soft_shadow(l)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bold title / number. No outline (the param is kept for old call sites and ignored). Light
## colours get the soft scene shadow; >= 44 px uses ExtraBold.
static func heading(text: String, size := 40, color := TEXT, outline := 0) -> Label:
	var l := label(text, size, color, true, 0)
	if size >= 44:
		l.add_theme_font_override("font", font_w("extrabold"))
	if _is_light(color):
		soft_shadow(l, size)
	return l


## Soft shadow for text on a scene (no stroke): slate 40 %, 2-3 px down, a little spread.
static func soft_shadow(l: Label, size := 0, strength := 1.0) -> Label:
	var fs := size if size > 0 else l.get_theme_font_size("font_size")
	l.add_theme_color_override("font_shadow_color", Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.42 * strength))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", clampi(fs / 18, 1, 4))
	l.add_theme_constant_override("shadow_outline_size", clampi(fs / 9, 2, 8))
	return l


## Text that sits on a 3D scene / art: warm white + soft shadow.
static func scene_label(text: String, size := 24, bold := true) -> Label:
	var l := label(text, size, ON_SCENE, bold)
	if bold and size >= 44:
		l.add_theme_font_override("font", font_w("extrabold"))
	soft_shadow(l, size)
	return l


## Small caps label (taupe, tracked): section labels, stat names.
static func caps(text: String, size := 20, color := INK_DIM) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", font_caps(size))
	return l


## Engraved section title on cream (gold_text, tracked caps).
static func section(text: String, size := 22) -> Label:
	return caps(text, size, GOLD_TEXT)


## Big number (ExtraBold, tabular digits): ink on cream or warm white on scenes.
static func number(text: String, size := 48, on_scene := false, color := Color(0, 0, 0, 0)) -> Label:
	var col := color if color.a > 0.0 else (ON_SCENE if on_scene else INK)
	var l := label(text, size, col, true)
	l.add_theme_font_override("font", font_w("extrabold"))
	if on_scene:
		soft_shadow(l, size)
	return l


## Title with a quiet vertical gradient. Default = ink (titles on cream). Passing light
## colours (on-scene titles) adds the soft shadow. `outline` is ignored (no strokes in v2).
static func gradient_heading(text: String, size := 64, top := Color("#5D6A80"), mid := INK, bottom := Color("#3C4557"), outline := 0) -> Label:
	var l := label(text, size, Color.WHITE, true, 0)
	l.add_theme_font_override("font", font_w("extrabold" if size >= 44 else "bold"))
	if _is_light(mid):
		soft_shadow(l, size)
	if _text_shader == null:
		_text_shader = Shader.new()
		_text_shader.code = GRADIENT_TEXT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _text_shader
	m.set_shader_parameter("top_color", top)
	m.set_shader_parameter("mid_color", mid)
	m.set_shader_parameter("bottom_color", bottom)
	l.material = m
	var fit := func():
		var fs := float(l.get_theme_font_size("font_size"))
		var lines := maxi(1, l.get_line_count())
		var line_h := l.get_line_height()
		var total := line_h * lines
		var top_y := (l.size.y - total) * 0.5
		if l.vertical_alignment == VERTICAL_ALIGNMENT_TOP:
			top_y = 0.0
		var y0 := top_y + line_h * 0.5 - fs * 0.42
		var y1 := top_y + total - line_h * 0.5 + fs * 0.36
		m.set_shader_parameter("y0", y0)
		m.set_shader_parameter("y1", y1)
	l.resized.connect(fit)
	l.ready.connect(fit)
	return l


## Largest font size <= `start` (down to `min_size`) at which `text` fits in `max_w` px.
static func fit_size(text: String, max_w: float, start: int, min_size := 18, bold := true) -> int:
	var fs := start
	var f := font(bold)
	while fs > min_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs


# ------------------------------------------------------------------ buttons

## A Button with a painted style kind. "green" / "primary" return the amber jewel (KitCTA,
## topaz only when wide enough); "button" = secondary cream; "ghost"; "text" (tertiary).
static func styled_button(text: String, kind: String, min_size := Vector2(200, 72), font_size := 28) -> Button:
	if kind in ["primary", "green"]:
		var cta := cta_button(text, "", min_size, font_size)
		cta.topaz = min_size.x >= 240.0
		return cta
	var b := button(text, false, min_size.x)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var pressed_kind := kind + "_pressed" if kind in ["button", "ghost", "text"] else kind
	for st: String in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, lux(kind))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", lux(pressed_kind))
	b.add_theme_stylebox_override("hover_pressed", lux(pressed_kind))
	b.add_theme_stylebox_override("disabled", lux("button_disabled") if kind == "button" else lux(kind))
	if kind == "text":
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, GOLD_TEXT)
	return b


## Button factory. primary=true -> the amber jewel CTA (KitCTA: topaz, light sweep, squash);
## else the secondary cream button (theme default).
static func button(text: String, primary := false, min_width := 280.0) -> Button:
	if primary:
		var cta := cta_button(text, "", Vector2(min_width, 88), 32)
		cta.topaz = min_width >= 240.0
		return cta
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", -4.0))
	b.button_down.connect(func(): _press_bounce(b, true))
	b.button_up.connect(func(): _press_bounce(b, false))
	return b


## Secondary cream button with an optional line icon at the left.
static func secondary_button(text: String, icon := "", min_size := Vector2(240, 72), font_size := 26) -> Button:
	var b := styled_button(text, "button", min_size, font_size)
	if icon != "":
		# The line icon sits in the (widened) left margin; text stays centred.
		var pad := Vector2(64, 10)
		for st: String in ["normal", "hover"]:
			b.add_theme_stylebox_override(st, lux("button", pad))
		b.add_theme_stylebox_override("pressed", lux("button_pressed", pad))
		b.add_theme_stylebox_override("hover_pressed", lux("button_pressed", pad))
		b.add_theme_stylebox_override("disabled", lux("button_disabled", pad))
		var ic := Icons.make(icon, 34.0, INK)
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ic.position = Vector2(20, (min_size.y - 34.0) * 0.5)
		b.add_child(ic)
	return b


## Tertiary text button (no surface, gold_text label).
static func text_button(text: String, min_size := Vector2(0, 56), font_size := 24) -> Button:
	return styled_button(text, "text", min_size, font_size)


## Ghost button (transparent, hairline) - quiet actions over scenes and art.
static func ghost_button(text: String, min_size := Vector2(200, 64), font_size := 24, on_scene := false) -> Button:
	var b := styled_button(text, "ghost", min_size, font_size)
	if on_scene:
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, ON_SCENE)
	return b


## The amber jewel CTA (ГРАТИ, Призвати, Покращити, Забрати). `sub` = a small second line.
static func cta_button(text: String, sub := "", min_size := Vector2(448, 104), font_size := 40) -> KitCTA:
	var b := KitCTA.new()
	b.text = text
	b.sub = sub
	b.custom_minimum_size = min_size
	b.label_size = font_size
	return b


static func _press_bounce(b: Control, down: bool) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(0.96, 0.96) if down else Vector2.ONE, 0.1 if down else 0.22)


## Round edge button: cream disc, thin gold ring, line icon (home rails, close, back).
static func edge_button(icon: String, radius := 38.0, badge := "") -> RoundButton:
	var b := RoundButton.new(radius)
	b.icon_kind = icon
	b.badge = badge
	return b


# ------------------------------------------------------------------ tabs

## Segmented control: a cream track with a raised paper chip + amber underline for the
## selected option. `options` = [[id, label], ...]. Calls `on_change(id)` on a change.
static func segmented(options: Array, selected: String, on_change: Callable, height := 62.0, font_size := 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", lux("seg"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	p.add_child(row)
	for o: Array in options:
		var b := Button.new()
		b.text = str(o[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, height - 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", font_size)
		b.set_meta("id", str(o[0]))
		b.pressed.connect(func():
			if str(p.get_meta("selected", "")) == str(o[0]):
				return
			segmented_select(p, str(o[0]))
			Audio.play("click", -8.0)
			on_change.call(str(o[0])))
		row.add_child(b)
	segmented_select(p, selected)
	return p


static func segmented_select(seg: PanelContainer, id: String) -> void:
	seg.set_meta("selected", id)
	var row := seg.get_child(0)
	for b: Button in row.get_children():
		var on := str(b.get_meta("id")) == id
		var st: StyleBox = lux("seg_sel") if on else StyleBoxEmpty.new()
		for k: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		var c := INK if on else INK_DIM
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, c)
		b.add_theme_constant_override("outline_size", 0)


## Genshin-style text tabs (no boxes): taupe labels, the active one ink + an amber underline
## with a crystal keystone that slides between tabs. Returns KitTabs (signal `changed(id)`).
static func tabs(options: Array, selected: String, on_change := Callable(), font_size := 26) -> KitTabs:
	var t := KitTabs.new()
	t.setup(options, selected, font_size)
	if on_change.is_valid():
		t.changed.connect(on_change)
	return t


# ------------------------------------------------------------------ containers

## Cream document panel (kind: "panel" | "cream_glass" | "card" | "card_sel" | "card_dim" | "modal" ...).
static func panel(kind := "panel", pad := Vector2(-1, -1)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", lux(kind, pad))
	return p


## Translucent cream over 3D (porcelain), one hairline.
static func glass_panel(pad := Vector2(-1, -1)) -> PanelContainer:
	return panel("cream_glass", pad)


## Bottom sheet: cream body with an arched top hairline and a crystal keystone.
static func sheet(pad := Vector2(-1, -1)) -> KitSheet:
	var s := KitSheet.new()
	s.add_theme_stylebox_override("panel", lux("sheet", pad))
	return s


## Modal frame: cream panel, title plate, close disc. Body content goes into
## modal.get_meta("body") (a VBoxContainer). `on_close` runs on the close disc.
static func modal(title: String, on_close := Callable(), width := 600.0) -> PanelContainer:
	var p := panel("modal")
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var tl := heading(title, 34, INK)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if on_close.is_valid():
		var x := edge_button("close", 26.0)
		x.pressed.connect(on_close)
		head.add_child(x)
	v.add_child(divider(width - 72.0))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	v.add_child(body)
	p.set_meta("body", body)
	return p


## Pill-shaped HUD container: v2 porcelain plate (`dark` drops the gold line).
static func pill(dark := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", lux("pill_dark" if dark else "pill"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Currency plate: porcelain chip, painted icon overlapping the left end, Bold tabular value,
## optional "+" disc. Value label: plate.value_label.
static func currency_plate(icon: String, value: String, plus := false, width := 172.0) -> KitCurrencyPlate:
	var c := KitCurrencyPlate.new()
	c.icon = icon
	c.value = value
	c.plus = plus
	c.custom_minimum_size = Vector2(width, 52)
	return c


## Title / world ribbon: a slim cream plate with marquise terminals ("Світ 2 · Луки · Рівень 14").
static func title_plate(text: String, width := 380.0, on_scene := true) -> KitTitlePlate:
	var t := KitTitlePlate.new()
	t.text = text
	t.custom_minimum_size = Vector2(width, 44)
	t.on_scene = on_scene
	return t


## Round socket: a disc (cream, or slate for family glyphs) with a thin gold ring + line icon.
static func socket(icon: String, size := 56.0, slate := false, color := Color(0, 0, 0, 0)) -> KitSocket:
	var s := KitSocket.new()
	s.icon = icon
	s.slate = slate
	s.icon_color = color
	s.custom_minimum_size = Vector2(size, size)
	return s


## Gold notify badge ("!" or a count): 28 px gold disc, ink glyph. Add it as a child and
## position it at the parent's top-right.
static func notify_badge(text := "!", size := 28.0) -> KitSocket:
	var s := KitSocket.new()
	s.badge_text = text
	s.custom_minimum_size = Vector2(size, size)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Thin progress bar: cream track, amber fill, crystal ticks at both ends. `tiles` > 0 draws
## it as bridge tiles (segmented crystal planks).
static func progress(value := 0.0, max_value := 1.0, width := 300.0, height := 12.0, tiles := 0) -> KitProgress:
	var p := KitProgress.new()
	p.max_value = max_value
	p.value = value
	p.tiles = tiles
	p.custom_minimum_size = Vector2(width, height + 8.0)
	p.bar_h = height
	return p


## Gem-ground card frame for a rarity ("C".."M" or "quartz".."opal"). Put art in card.art
## (a TextureRect) or add children to card.content; set card.title / card.footer / card.pips.
static func gem_card(rarity: String, size := Vector2(216, 300)) -> KitGemCard:
	var c := KitGemCard.new()
	c.gem = UITokens.gem_of(rarity)
	c.custom_minimum_size = size
	return c


## List row without a box: [icon] label ......... value, hairline divider underneath.
static func list_row(text: String, value := "", icon := "", value_color := INK) -> HBoxContainer:
	var r := KitRow.new()
	r.custom_minimum_size = Vector2(0, UITokens.ROW_H)
	r.add_theme_constant_override("separation", 12)
	if icon != "":
		var ic := Icons.make(icon, 32.0, INK_DIM)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(ic)
	var l := label(text, 24, INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	r.add_child(l)
	if value != "":
		var v := label(value, 26, value_color, true)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.size_flags_vertical = Control.SIZE_FILL
		r.add_child(v)
		r.set_meta("value", v)
	r.set_meta("label", l)
	return r


## Toast: a cream-glass chip with a hairline, optional icon. Caller positions it; it fades in,
## holds `hold` s and fades out (soft menu motion), then frees itself.
static func toast(host: Control, text: String, icon := "", hold := 1.6, y := 180.0) -> PanelContainer:
	var p := panel("toast", Vector2(22, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	if icon != "":
		row.add_child(Icons.make(icon, 32.0, INK))
	var l := label(text, 24, INK, true)
	row.add_child(l)
	host.add_child(p)
	p.reset_size()
	var vw := host.size.x if host.size.x > 0.0 else 720.0
	p.position = Vector2((vw - p.size.x) * 0.5, y)
	UIJuice.soft_in(p, Vector2(0, -16))
	var tw := p.create_tween()
	tw.tween_interval(UITokens.MENU_IN + hold)
	tw.tween_property(p, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_callback(p.queue_free)
	return p


## Full-width result band (Genshin level-up / victory): "amber" or "cool". Title centred.
static func band(text: String, style := "amber", height := 140.0) -> PanelContainer:
	var p := panel("band_amber" if style == "amber" else "band_cool")
	p.custom_minimum_size = Vector2(0, height)
	var l: Label
	if style == "amber":
		l = number(text, 56, false, CTA_TEXT)
		l.add_theme_color_override("font_shadow_color", Color(0.55, 0.27, 0.05, 0.45))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 6)
	else:
		l = number(text, 52, false, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## NEW tag (yellow, chamfered, brown ink).
static func new_tag(text := "NEW") -> PanelContainer:
	var p := panel("tag_new")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text.to_upper(), 16, UITokens.NEW_INK, true)
	l.add_theme_font_override("font", font_w("extrabold"))
	p.add_child(l)
	return p


static func spacer(expand_h := true, min_size := Vector2.ZERO) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fixed-size gap for containers (does not expand).
static func gap(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Gold hairline divider with marquise terminals and a crystal keystone at the centre.
static func divider(width := 420.0, keystone := true) -> Control:
	var d := Divider.new()
	d.keystone = keystone
	d.custom_minimum_size = Vector2(width, 14)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## Plain hairline (list separators): full width, no ornaments.
static func hairline(width := 0.0, color := Color(0.788, 0.659, 0.416, 0.55)) -> Control:
	var d := Divider.new()
	d.plain = true
	d.color = color
	d.custom_minimum_size = Vector2(width, 3)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width <= 0.0 else Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


# ------------------------------------------------------------------ motion (legacy helpers)

## Pops a control in (scale + fade).
static func pop_in(c: Control, delay := 0.0, duration := 0.35) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.85, 0.85)
	var go := func():
		c.pivot_offset = c.size * 0.5
	if c.is_inside_tree():
		go.call()
	else:
		c.ready.connect(go, CONNECT_ONE_SHOT)
	c.resized.connect(go)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops several controls in one after another.
static func stagger(controls: Array, delay := 0.1, step := 0.08, duration := 0.4) -> void:
	var i := 0
	for c: Control in controls:
		pop_in(c, delay + step * i, duration)
		i += 1


## Rolls a label's number from `from` to `to` (ease-out). `fmt` gets the int; optional rising
## pentatonic ticks while it counts.
static func count_up(lbl: Label, from: int, to: int, duration := 0.9, delay := 0.0, fmt := "%d", ticks := true) -> Tween:
	lbl.text = fmt % from
	var last := [from]
	var tw := lbl.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float):
		var n := int(round(v))
		if n == last[0]:
			return
		last[0] = n
		lbl.text = fmt % n
		if ticks and to != from:
			var k := clampi(int(float(n - from) / float(to - from) * 10.0), 0, 10)
			Audio.note(k + 2, -18.0), float(from), float(to), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		lbl.text = fmt % to
		punch(lbl, 1.18))
	return tw


## Quick scale punch (1 -> s -> 1) around the centre.
static func punch(c: Control, s := 1.25, duration := 0.32) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Diagonal light sweep across `target`, clipped to its chamfered rect (`radius` = chamfer).
## Plays once after `delay`, then every `every` seconds if > 0. A KitCTA already sweeps,
## so it is skipped there (returns a hidden rect).
static func add_shine(target: Control, radius := 12.0, delay := 0.35, every := 0.0, strength := 0.45) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if target is KitCTA:
		r.visible = false
		target.add_child(r)
		return r
	if _shine_shader == null:
		_shine_shader = load(SHINE_SHADER_PATH) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shine_shader
	m.set_shader_parameter("chamfer", minf(radius, 14.0))
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("progress", -1.0)
	r.material = m
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	target.add_child(r)
	var sync := func(): m.set_shader_parameter("rect_size", r.size)
	r.resized.connect(sync)
	var tw := r.create_tween()
	if every > 0.0:
		tw.set_loops()
	tw.tween_interval(delay)
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): m.set_shader_parameter("progress", -1.0))
	if every > 0.0:
		tw.tween_interval(every)
	return r


## Glint burst (CPU particles) centred on `pos` inside `parent` (juicy rewards only).
static func sparkles(parent: Control, pos: Vector2, color := GOLD_LIGHT, amount := 26, spread := 260.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = sparkle_texture()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 1.1
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = spread * 0.35
	p.initial_velocity_max = spread
	p.gravity = Vector2(0, 220)
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Renders a hero close-up into a transparent texture (async; null in headless).
static func render_portrait(host: Node, type: String, px := 200) -> Texture2D:
	if DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.86)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_color = Color(1.0, 0.86, 0.66)
	rim.light_energy = 0.7
	vp.add_child(rim)
	var m := HeroModels.hero(type)
	m.rotation_degrees.y = 18.0
	vp.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var frame: Array = m.get_meta("portrait")
	cam.look_at_from_position(frame[0], frame[1])
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Safe-area insets in canvas units: Vector4(left, top, right, bottom).
static func safe_insets(vp: Viewport) -> Vector4:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var vis := vp.get_visible_rect().size
	var sx := vis.x / float(win.x)
	var sy := vis.y / float(win.y)
	var screen := DisplayServer.screen_get_size()
	# On desktop the safe area is the whole screen, not the window: ignore it there.
	if not OS.has_feature("mobile") and screen != win:
		return Vector4.ZERO
	return Vector4(
		maxf(0.0, safe.position.x * sx),
		maxf(0.0, safe.position.y * sy),
		maxf(0.0, (win.x - safe.end.x) * sx),
		maxf(0.0, (win.y - safe.end.y) * sy))


# ------------------------------------------------------------------ drawn widgets

## Gold hairline divider: marquise terminals + crystal keystone (or a plain hairline).
class Divider extends Control:
	var keystone := true
	var plain := false
	var color := UITokens.HAIRLINE

	func _draw() -> void:
		var y := size.y * 0.5
		if plain:
			draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0, true)
			return
		GemDraw.draw_hairline(self, Vector2(0, y), Vector2(size.x, y), color, 1.5, keystone, true)


## Slowly rotating light rays (victory sunburst / reward halo). Soft and warm in v2.
class Rays extends Control:
	var color := Color(1.0, 0.86, 0.55, 0.28)
	var count := 14
	var speed := 0.12
	var inner := 0.0
	var _a := 0.0

	func _process(delta: float) -> void:
		_a += delta * speed
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		var half := PI / count * 0.42
		var mid := Color(color.r, color.g, color.b, color.a * 0.7)
		var edge := Color(color.r, color.g, color.b, 0.0)
		for i in count:
			var a := _a + TAU * i / count
			var d0 := Vector2(cos(a - half * 0.25), sin(a - half * 0.25))
			var d1 := Vector2(cos(a + half * 0.25), sin(a + half * 0.25))
			var e0 := Vector2(cos(a - half), sin(a - half))
			var e1 := Vector2(cos(a + half), sin(a + half))
			var m0 := d0.lerp(e0, 0.6).normalized()
			var m1 := d1.lerp(e1, 0.6).normalized()
			var rin := maxf(R * inner, 2.0)
			draw_polygon(PackedVector2Array([c + d0 * rin, c + m0 * R * 0.6, c + m1 * R * 0.6, c + d1 * rin]), PackedColorArray([color, mid, mid, color]))
			draw_polygon(PackedVector2Array([c + m0 * R * 0.6, c + e0 * R, c + e1 * R, c + m1 * R * 0.6]), PackedColorArray([mid, edge, edge, mid]))
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 0.62, Vector2(R, R) * 1.24), false, Color(color.r, color.g, color.b, minf(1.0, color.a * 1.6)))


## Title ribbon (victory / result band): a band with V-notched, chamfered ends, a quiet
## vertical gradient, inner hairlines and marquise terminals. Default = amber (victory);
## set_palette(top, bottom, line) for other moods (e.g. a cool slate defeat).
class Ribbon extends Control:
	var top := Color("#FFE1A0")
	var bottom := Color("#EFA448")
	var fold := Color(1.0, 0.96, 0.84, 0.85)

	func set_palette(t: Color, b: Color, f: Color) -> void:
		# Old callers pass dark slates for a loss: lift them into the cool cream band.
		if t.get_luminance() < 0.75:
			top = UITokens.PAPER_0
			bottom = UITokens.PAPER_2
			fold = Color("#8E98AA")
		else:
			top = t
			bottom = b
			fold = f
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var notch := h * 0.28
		var cut := h * 0.22
		var pts := PackedVector2Array([
			Vector2(cut, 0), Vector2(w - cut, 0), Vector2(w, cut), Vector2(w - notch, h * 0.5), Vector2(w, h - cut),
			Vector2(w - cut, h), Vector2(cut, h), Vector2(0, h - cut), Vector2(notch, h * 0.5), Vector2(0, cut)])
		# Soft shadow
		for i in 4:
			var o := Vector2(0, 3.0 + i * 1.5)
			var sp := PackedVector2Array()
			for p in pts:
				sp.append(p + o)
			draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, p.y / maxf(h, 1.0)))
		draw_polygon(pts, cols)
		var lc := fold
		draw_line(Vector2(cut + notch, 5), Vector2(w - cut - notch, 5), lc, 1.5, true)
		draw_line(Vector2(cut + notch, h - 5), Vector2(w - cut - notch, h - 5), lc, 1.5, true)
		GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), 1.5)
		GemDraw.draw_keystone(self, Vector2(notch + 14.0, h * 0.5), 16.0)
		GemDraw.draw_keystone(self, Vector2(w - notch - 14.0, h * 0.5), 16.0)


## HBox list row that draws a hairline under itself (no boxes).
class KitRow extends HBoxContainer:
	func _draw() -> void:
		var y := size.y - 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5), 1.0, true)
