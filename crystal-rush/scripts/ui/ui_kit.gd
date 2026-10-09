class_name UIKit
## UI v3.1 "porcelain glass" (binding spec docs/design/ui_v3_spec.md, on top of the v2 Genshin x AFK
## Journey system): surfaces are translucent cream glass (the frosted 3D world glows through, see
## KitGlass), every frame is ONE 1-device-px gold hairline with a 1 px inner light line (KitBox
## paints at device resolution; 1.25 dpx at 540-class densities, line_px()), shadows are soft and
## never show through a translucent body, body text on frost always sits on a 94 % cream text
## bed (TextBed), modals carry restrained top-corner flourishes, type is a weight lighter
## (Medium / Bold; ExtraBold only for numbers >= 40 px). Everything below keeps the v2 API.
## v2 notes (contract: scratchpad/uiv2/ui_v2_contract.md):
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
## v3.1: nearly every surface is glass now, so the kit's secondary ink is the glass-safe taupe
## (UITokens.INK_DIM_GLASS, >= 4.5:1 on the worst frost); UITokens.INK_DIM stays for opaque cream.
const INK_DIM := UITokens.INK_DIM_GLASS   ## taupe labels on glass / cream
const INK_SOFT := UITokens.INK_SOFT       ## small labels (18 px)
const ON_SCENE := UITokens.ON_SCENE       ## warm white on 3D / art (always soft_shadow())
const PAPER_0 := UITokens.PAPER_0
const CREAM := UITokens.PAPER_1
const CREAM_2 := UITokens.PAPER_2
const CREAM_3 := UITokens.PAPER_3
const HAIRLINE := UITokens.HAIRLINE
const GOLD_HI := UITokens.GOLD_HI
const GOLD_TEXT := UITokens.GOLD_TEXT
const GOLD_TEXT_GLASS := UITokens.GOLD_TEXT_GLASS
const INK_DIM_GLASS := UITokens.INK_DIM_GLASS
const CTA_HI := UITokens.CTA_HI
const CTA := UITokens.CTA
const CTA_LO := UITokens.CTA_LO
const CTA_RIM := UITokens.CTA_RIM
const CTA_TEXT := Color("#5A3212")        ## label on the amber CTA: deep amber-brown ink (~5:1), no emboss
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
	fv.base_font = font_w("medium")
	fv.spacing_glyph = maxi(1, int(round(size * 0.08)))
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
	# Without a kit.json entry: a third of the shorter side (safe for chamfered corners).
	var dm := floorf(minf(tex.get_width(), tex.get_height()) / 3.0)
	var m: Array = js.get("margins", [dm, dm, dm, dm])
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

# ------------------------------------------------------------------ device pixels (v3)

## Canvas -> device scale of the root viewport (1.0 at 720 wide, 1.5 on 1080p, 0.75 at 540).
static func ui_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	var sc := tree.root.get_final_transform().get_scale().x
	return clampf(sc, 0.5, 4.0) if sc > 0.0 else 1.0


## `n` DEVICE pixels in canvas units: draw_line(a, b, col, UIKit.px(1)) is one crisp device px.
static func px(n := 1.0) -> float:
	return n / ui_scale()


## Spec §1.1a: a gold line of `n` device px on a frosted surface, in canvas units, with the
## low-density floor (x1.25 when the device scale is < 0.9, so 540-class lines stay >= 0.8 alpha).
static func line_px(n := 1.0) -> float:
	var sc := ui_scale()
	return n * (UITokens.LOW_DENSITY_LINE if sc < 0.9 else 1.0) / sc


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
	var sc := ui_scale()
	var key := "%s_%d_%d_%.3f" % [kind, int(pad.x), int(pad.y), sc]
	if kind.begins_with("button") or kind.begins_with("primary") or kind == "green" or kind.begins_with("green"):
		key += "_" + UITokens.cta_style
	if _styles.has(key):
		return _styles[key]
	var ov := _kit_style(kind, pad)
	if ov:
		_styles[key] = ov
		return ov
	var spec := _spec(kind)
	# v3: painted at DEVICE resolution (rings are device px), drawn through a 1/s transform.
	var dspec := _device_spec(spec, sc)
	var tkey := str(dspec).md5_text()
	var tex: Texture2D = _textures.get(tkey)
	if tex == null:
		tex = ImageTexture.create_from_image(_cached_paint(kind, dspec))
		_textures[tkey] = tex
	var s := KitBox.new()
	s.tex = tex
	s.s = sc
	s.margin_dev = _margin(dspec)
	s.shadow_dev = _shadow_room(dspec)
	s.cham = float(spec.get("cham", 0.0))
	if spec.has("flourish"):
		s.flourish = spec["flourish"]
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


## A canvas-unit spec scaled to device px: chamfers, blurs, offsets and insets x s; rings and line
## widths are already device px (1.0 = one device pixel); `inset_px` is a device-px inset.
static func _device_spec(spec: Dictionary, sc: float) -> Dictionary:
	var d := spec.duplicate(true)
	for k: String in ["cham", "blur", "sh_dy"]:
		if d.has(k):
			d[k] = float(d[k]) * sc
	var layers: Array = []
	var ld := UITokens.LOW_DENSITY_LINE if sc < 0.9 else 1.0
	for L: Dictionary in spec["layers"]:
		var l2 := L.duplicate()
		# §1.1a: gold rings (not the inner light line) thicken a quarter at 540-class densities.
		if l2.has("ring") and not l2.has("inset_px") and ld > 1.0:
			l2["ring"] = float(l2["ring"]) * ld
		if l2.has("w") and ld > 1.0:
			l2["w"] = float(l2["w"]) * ld
		if l2.has("inset"):
			l2["inset"] = float(l2["inset"]) * sc
		if l2.has("inset_px"):
			l2["inset"] = float(l2.get("inset", 0.0)) + float(l2["inset_px"])
			l2.erase("inset_px")
		for k2: String in ["y", "inset_x"]:
			if l2.has(k2):
				l2[k2] = float(l2[k2]) * sc
		layers.append(l2)
	d["layers"] = layers
	d["dev"] = sc
	if d.has("feather"):
		d["feather"] = float(d["feather"]) * sc
	d.erase("flourish")
	return d


## v3 porcelain glass body: translucent cream fill, ONE 1 px gold hairline, a 1 px inner light
## line just inside it (bright at the top, fading down), a quiet shadow.
static func _glass(cham: float, top: Color, bot: Color, line_a: float, light: float, blur: float, sh_a: float,
		sh_dy: float, pad: Vector2, line := HAIRLINE) -> Dictionary:
	var layers: Array = [{"top": top, "bot": bot}]
	if line_a > 0.0:
		layers.append({"ring": UITokens.HAIRLINE_PX, "top": _a(line, line_a), "bot": _a(line, line_a * 0.82)})
	if light > 0.0:
		layers.append({"inset_px": 1.0 if line_a > 0.0 else 0.0, "ring": 1.0, "top": Color(1, 1, 1, light), "bot": Color(1, 1, 1, light * 0.22)})
	return {"cham": cham, "blur": blur, "sh_a": sh_a, "sh_dy": sh_dy, "pad": pad, "layers": layers}


## CTA study (refined ink / porcelain): the painted primary fallback matches KitCTA (near-flat
## enamel, ONE gold hairline, a 2 dpx slate contact shadow; no glow, no table light).
static func _calm_primary(kind: String) -> Dictionary:
	var ink := UITokens.cta_style == "ink"
	var pr := kind.ends_with("_pressed")
	var t0 := (Color("#1F2342") if pr else UITokens.KEY_INK) if ink else (Color("#EFE5D2") if pr else Color("#FFFDF8"))
	var t1 := (Color("#1C203D") if pr else UITokens.KEY_INK_LO) if ink else (Color("#E9DECA") if pr else Color("#F6EEDF"))
	var rim := UITokens.KEY_GOLD if ink else Color("#9A7436")
	var ps := {"cham": 12.0, "blur": 0.0, "sh_a": 0.0 if pr else (0.18 if ink else 0.14), "sh_dy": 2.0, "sh_col": Color(0.12, 0.13, 0.2),
			"pad": Vector2(36, 10), "layers": [
		{"top": t0, "bot": t1},
		{"ring": 1.0, "top": rim, "bot": rim},
	]}
	if pr:
		ps["shift"] = 1.0
	return ps


static func _spec(kind: String) -> Dictionary:
	if UITokens.calm_cta() and kind in ["primary", "green", "primary_compact", "primary_pressed", "green_pressed"]:
		return _calm_primary(kind)
	var G0 := UITokens.GLASS_TOP
	var G1 := UITokens.GLASS_BOT
	var sa := UITokens.SHADOW_A
	var TA := UITokens.GLASS_TEXT_A
	var deep := UITokens.LINE_GOLD_DEEP
	match kind:
		"panel", "cream", "parch":
			return _glass(12.0, G0, G1, 0.78, 0.62, 22.0, sa * 0.8, 6.0, Vector2(36, 30))
		"modal":
			# Flat fallback (no world snapshot; run HUD, results, menus): text-heavy, 0.97.
			# Same frame as the frosted modal's line overlay (deep gold @ 0.85), so a flat modal's
			# edge reaches the §14.2 peak (>= 0.8) instead of HAIRLINE @ 0.8 (measured 0.73).
			var mf := _glass(12.0, _a(G0, 0.97), _a(G1, 0.97), 0.85, 0.7, 30.0, sa * 1.4, 10.0, Vector2(36, 32), UITokens.LINE_GOLD_DEEP.lerp(HAIRLINE, 0.5))
			mf["flourish"] = _flourish("top")
			return mf
		"modal_frost", "panel_frost":
			# Opaque-painted body for the KitGlass frost material (the shader mixes the world in).
			# No lines here: the frame is drawn by the TextBed overlay ("<kind>_lines"), outside the
			# material, so the gold stays pure gold instead of 38 % world.
			return _glass(12.0, _a(G0, 1.0), _a(G1, 1.0), 0.0, 0.0, 30.0, sa * 1.4, 10.0, Vector2(36, 32) if kind == "modal_frost" else Vector2(36, 30))
		"modal_lines", "panel_lines":
			var fl := _glass(12.0, Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0.85, 0.75, 0.0, 0.0, 0.0, Vector2(36, 32) if kind == "modal_lines" else Vector2(36, 30), UITokens.LINE_GOLD_DEEP.lerp(HAIRLINE, 0.5))
			if kind == "modal_lines":
				fl["flourish"] = _flourish("top")
			return fl
		"text_bed":
			# §4.3: the cream bed under body text on frost (94 %), no line, no shadow, edges
			# feathered over 28 px (TextBed draws it into the panel's content rect, grown).
			return {"cham": 12.0, "blur": 0.0, "feather": 28.0, "pad": Vector2.ZERO, "layers": [
				{"top": _a(PAPER_0, TA), "bot": _a(PAPER_0, TA)},
			]}
		"text_bed_modal":
			# Modals / panels: a short 12 px feather, so the frost band around the bed reads as a
			# crisp rim of glass instead of a milky grey inner shadow.
			return {"cham": 10.0, "blur": 0.0, "feather": UITokens.BED_FEATHER_MODAL, "pad": Vector2.ZERO, "layers": [
				{"top": _a(PAPER_0, TA), "bot": _a(PAPER_0, TA)},
			]}
		"cream_glass", "glass":
			return _glass(10.0, _a(G0, 0.62), _a(G1, 0.7), 0.72, 0.6, 16.0, sa * 0.7, 4.0, Vector2(22, 14))
		"sheet":
			return _glass(12.0, _a(UITokens.SHEET_FILL, 0.9), _a(UITokens.SHEET_FILL, 0.94), 0.0, 0.0, 24.0, sa * 0.6, -3.0, Vector2(26, 28))
		"sheet_frost":
			return _glass(12.0, _a(PAPER_0, 1.0), _a(UITokens.SHEET_FILL, 1.0), 0.0, 0.0, 24.0, sa * 0.6, -3.0, Vector2(26, 28))
		"card", "parch_card":
			return _glass(10.0, _a(PAPER_0, 0.86), _a(CREAM, 0.88), 0.62, 0.55, 12.0, sa * 0.7, 3.0, Vector2(16, 14))
		"card_sel":
			# §7.3: 1.5 dpx deep-gold frame + the diagonal flourish pair; no glow slab.
			var cs := _glass(10.0, _a(PAPER_0, 0.92), _a(PAPER_0, 0.92), 0.0, 0.7, 12.0, sa * 0.9, 3.0, Vector2(16, 14))
			(cs["layers"] as Array).insert(1, {"ring": UITokens.SELECT_PX, "top": _a(deep, 0.95), "bot": _a(deep, 0.85)})
			cs["flourish"] = _flourish("diag", 12.0)
			return cs
		"card_dim":
			return _glass(10.0, _a(CREAM_3, 0.6), _a(Color("#DCCFB8"), 0.66), 0.42, 0.35, 0.0, 0.0, 0.0, Vector2(16, 14))
		"pill", "plate":
			return _glass(8.0, _a(PAPER_0, UITokens.GLASS_THIN_A + 0.1), _a(CREAM, UITokens.GLASS_THIN_A + 0.14), 0.8, 0.7, 10.0, sa * 0.8, 2.0, Vector2(16, 6))
		"pill_dark":
			return _glass(8.0, _a(PAPER_0, UITokens.GLASS_THIN_A + 0.08), _a(CREAM, UITokens.GLASS_THIN_A + 0.12), 0.0, 0.75, 10.0, sa * 0.7, 2.0, Vector2(16, 6))
		"chip":
			return _glass(6.0, _a(PAPER_0, 0.82), _a(CREAM, 0.86), 0.72, 0.6, 6.0, sa * 0.6, 1.5, Vector2(14, 4))
		"banner", "toast":
			# §7.11: flat glass at the text alpha (body text sits on it), 1 dpx gold line.
			return _glass(10.0, _a(G0, TA), _a(G1, TA + 0.02), 0.8, 0.7, 18.0, sa * 1.1, 5.0, Vector2(26, 14))
		"row":
			# §9: list rows at the text alpha (Shop, Barracks): no frame, a faint light line.
			return _glass(8.0, _a(PAPER_0, TA), _a(CREAM, TA), 0.5, 0.6, 8.0, sa * 0.6, 2.0, Vector2(18, 10))
		"ribbon":
			return _glass(8.0, _a(PAPER_0, UITokens.GLASS_THIN_A + 0.1), _a(CREAM, UITokens.GLASS_THIN_A + 0.14), 0.75, 0.7, 8.0, sa * 0.7, 2.0, Vector2(30, 6))
		"button":
			if UITokens.cta_style == "porcelain":
				# CTA study, porcelain: secondaries demote to ghost glass (a 1 dpx slate hairline, no
				# gold, no shadow), so the porcelain CTA is the one filled enamel in an action row.
				return _glass(8.0, _a(PAPER_0, 0.5), _a(PAPER_0, 0.42), 0.35, 0.0, 0.0, 0.0, 0.0, Vector2(28, 10), UITokens.INK)
			return _glass(8.0, _a(PAPER_0, 0.86), _a(CREAM_2, 0.86), 0.72, 0.7, 8.0, sa * 0.8, 2.0, Vector2(28, 10))
		"button_pressed":
			if UITokens.cta_style == "porcelain":
				var gq := _glass(8.0, _a(PAPER_0, 0.66), _a(PAPER_0, 0.6), 0.45, 0.0, 0.0, 0.0, 0.0, Vector2(28, 10), UITokens.INK)
				gq["shift"] = 2.0
				return gq
			var bp := _glass(8.0, _a(CREAM_3, 0.9), _a(Color("#E8DECC"), 0.9), 0.8, 0.3, 4.0, sa * 0.5, 1.0, Vector2(28, 10))
			bp["shift"] = 2.0
			return bp
		"button_disabled":
			if UITokens.cta_style == "porcelain":
				return _glass(8.0, _a(PAPER_0, 0.3), _a(PAPER_0, 0.26), 0.22, 0.0, 0.0, 0.0, 0.0, Vector2(28, 10), UITokens.INK)
			return _glass(8.0, _a(CREAM_2, 0.5), _a(CREAM_3, 0.5), 0.4, 0.3, 0.0, 0.0, 0.0, Vector2(28, 10))
		"ghost":
			return _glass(8.0, _a(PAPER_0, 0.16), _a(PAPER_0, 0.08), 0.85, 0.35, 0.0, 0.0, 0.0, Vector2(24, 8))
		"ghost_pressed":
			var gp := _glass(8.0, _a(PAPER_0, 0.42), _a(PAPER_0, 0.32), 0.95, 0.3, 0.0, 0.0, 0.0, Vector2(24, 8))
			gp["shift"] = 2.0
			return gp
		"text", "text_pressed":
			return {"cham": 6.0, "blur": 0.0, "pad": Vector2(14, 6), "layers": [
				{"top": _a(CREAM_3, 0.0 if kind == "text" else 0.45), "bot": _a(CREAM_3, 0.0 if kind == "text" else 0.45)},
			]}
		"primary", "green", "primary_compact":
			# The painted fallback of the CTA body (KitCTA draws its own vector cut gem; this is
			# for old callers that style a plain Button "PrimaryButton"): flat amber in 3 stops,
			# a 1 dpx table light and ONE 1 dpx rim, a soft warm glow (no brown drop, no sheen).
			return {"cham": 12.0, "blur": 16.0, "sh_a": 0.18, "sh_dy": 4.0, "sh_col": Color(0.6, 0.38, 0.15),
					"pad": Vector2(36, 10), "layers": [
				{"top": Color("#FFD98A"), "mid": CTA, "bot": Color("#E8963A")},
				{"ring": 1.0, "top": _a(CTA_RIM, 0.7), "bot": _a(CTA_RIM, 0.7)},
				{"line": "top", "y": 1.0, "w": 1.0, "inset_x": 12.0, "col": Color(1.0, 0.98, 0.9, 0.9)},
			]}
		"primary_pressed", "green_pressed":
			return {"cham": 12.0, "blur": 8.0, "sh_a": 0.10, "sh_dy": 2.0, "sh_col": Color(0.6, 0.38, 0.15), "shift": 1.0,
					"pad": Vector2(36, 10), "layers": [
				{"top": Color("#F9C76A"), "mid": Color("#EEA23E"), "bot": Color("#DC8A32")},
				{"ring": 1.0, "top": _a(CTA_RIM, 0.7), "bot": _a(CTA_RIM, 0.7)},
				{"line": "top", "y": 1.0, "w": 1.0, "inset_x": 12.0, "col": Color(1.0, 0.98, 0.9, 0.6)},
			]}
		"primary_disabled":
			return _glass(12.0, _a(PAPER_0, 0.9), _a(CREAM_2, 0.88), 0.6, 0.5, 0.0, 0.0, 0.0, Vector2(36, 10))
		"parch_well", "well":
			return _glass(6.0, _a(CREAM_3, 0.5), _a(CREAM_2, 0.45), 0.45, 0.0, 0.0, 0.0, 0.0, Vector2(12, 8))
		"seg":
			return _glass(8.0, _a(CREAM_3, 0.32), _a(CREAM_2, 0.36), 0.55, 0.0, 0.0, 0.0, 0.0, Vector2(4, 4))
		"seg_sel":
			# §7.5: the selected segment = cream 0.92 with a 1 dpx gold line (no underline).
			return _glass(6.0, _a(PAPER_0, 0.92), _a(PAPER_0, 0.92), 0.8, 0.7, 6.0, sa * 0.7, 1.5, Vector2(18, 6))
		"tab_track":
			return {"cham": 0.0, "blur": 0.0, "pad": Vector2(8, 6), "layers": [
				{"line": "bottom", "y": 0.0, "w": 1.0, "inset_x": 0.0, "col": _a(HAIRLINE, 0.55)},
			]}
		"tabbar", "nav_bar":
			return {"cham": 0.0, "blur": 0.0, "pad": Vector2(8, 8), "layers": [
				{"top": _a(PAPER_0, 0.84), "bot": _a(CREAM, 0.92)},
				{"line": "top", "y": 0.0, "w": 1.0, "inset_x": 0.0, "col": _a(deep, 0.85)},
				{"line": "top", "y": 1.0, "w": 1.0, "inset_x": 0.0, "col": Color(1, 1, 1, 0.62)},
			]}
		"tab_sel":
			var ts := _glass(10.0, _a(PAPER_0, 0.9), _a(CREAM, 0.9), 0.78, 0.7, 10.0, sa * 0.8, 3.0, Vector2(8, 8))
			(ts["layers"] as Array).append({"line": "bottom", "y": 5.0, "w": UITokens.SELECT_PX, "inset_x": 18.0, "col": CTA_LO})
			return ts
		"band_amber":
			# §7.10: 1 dpx rules (the result title band); the centre diamonds are drawn by band().
			return {"cham": 0.0, "blur": 16.0, "sh_a": 0.14, "sh_dy": 4.0, "sh_col": Color(0.6, 0.38, 0.15), "pad": Vector2(24, 12), "layers": [
				{"top": Color("#FFE1A0"), "mid": CTA, "bot": Color("#E8963A")},
				{"line": "top", "y": 6.0, "w": 1.0, "inset_x": 0.0, "col": Color(1, 0.97, 0.86, 0.85)},
				{"line": "bottom", "y": 6.0, "w": 1.0, "inset_x": 0.0, "col": Color(1, 0.95, 0.8, 0.65)},
			]}
		"band_cool":
			return {"cham": 0.0, "blur": 16.0, "sh_a": 0.10, "sh_dy": 4.0, "pad": Vector2(24, 12), "layers": [
				{"top": _a(PAPER_0, 0.94), "bot": _a(CREAM, 0.94)},
				{"line": "top", "y": 6.0, "w": 1.0, "inset_x": 0.0, "col": _a(HAIRLINE, 0.8)},
				{"line": "bottom", "y": 6.0, "w": 1.0, "inset_x": 0.0, "col": _a(HAIRLINE, 0.8)},
			]}
		"tag_new":
			return {"cham": 5.0, "blur": 3.0, "sh_a": 0.10, "sh_dy": 1.0, "pad": Vector2(8, 1), "layers": [
				{"top": Color("#FFDD6E"), "bot": UITokens.NEW_TAG},
				{"ring": 1.0, "top": Color("#C99A2A"), "bot": Color("#B5861E")},
			]}
	return _spec("card")


## Corner flourish parameters (§3.4): "top" corners of a modal (arms 20 px) or the "diag" pair
## of the selected card (arms 12 px); 1 dpx LINE_GOLD_DEEP @ 0.8, inset 6 px.
static func _flourish(corners := "top", arm := 20.0) -> Dictionary:
	var d := UITokens.LINE_GOLD_DEEP
	return {"corners": corners, "len": arm, "inset": 6.0, "col": Color(d.r, d.g, d.b, 0.8)}


## Painting in GDScript costs a few ms per style, so painted images are cached as PNGs in
## user://ui_cache (keyed by a hash of the spec); later launches load them instantly.
static func _cached_paint(kind: String, spec: Dictionary) -> Image:
	var path := "user://ui_cache/v31_%s_%s.png" % [kind, str(spec).md5_text().substr(0, 10)]
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
	return ceilf(_shadow_room(spec) + float(spec.get("cham", 0.0)) + float(spec.get("feather", 0.0)) + 8.0)


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
	var feather: float = spec.get("feather", 0.0)
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
			if d0 <= 0.5:
				# v3.1 knock-out (B): the body replaces the shadow under it, so a translucent
				# panel never shows its own shadow through itself.
				col = Color(col.r, col.g, col.b, col.a * clampf(d0 + 0.5, 0.0, 1.0))
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
				if feather > 0.0:
					cov = smoothstep(0.0, feather, -d)
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
	t.set_font("font", "Button", font_w("medium"))
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
		t.set_font("font", v, font_w("bold"))
		t.set_font_size("font_size", v, 30)
		for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(k, v, CTA_TEXT if not UITokens.calm_cta() else (Color("#F7F1E6") if UITokens.cta_style == "ink" else UITokens.KEY_LABEL_DARK))
		t.set_color("font_disabled_color", v, INK_DIM)
		# v3: no outline or halo at all (no text outlines).
		t.set_color("font_outline_color", v, Color(0, 0, 0, 0))
		t.set_constant("outline_size", v, 0)
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
	var track := cbox(_a(CREAM_3, 0.7), 4, _a(HAIRLINE, 0.7), 1, Vector2(0, 3))
	var fill := cbox(CTA, 4, CTA_LO, 1, Vector2(0, 4))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _disc_tex(34, PAPER_0, HAIRLINE))
	t.set_icon("grabber_highlight", "HSlider", _disc_tex(34, Color.WHITE, CTA_LO))
	# Progress bars
	t.set_stylebox("background", "ProgressBar", cbox(_a(CREAM_3, 0.7), 3, _a(HAIRLINE, 0.7), 1, Vector2.ZERO))
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
	if size < 30:
		# v3: small titles a weight lighter (Medium); size and space carry them.
		l.add_theme_font_override("font", font_w("medium"))
	if _is_light(color):
		soft_shadow(l, size)
	return l


## Soft shadow for text on a scene: v3.1 a FEATHERED slate halo behind the glyphs (scene_halo),
## never a font shadow (its hard outline at fs/7 read as a 2010 text outline at 1080). Calling it
## again on the same label only re-tunes the halo. Big text (>= 60 px) gets a lighter, tighter halo.
static func soft_shadow(l: Label, size := 0, strength := 1.0) -> Label:
	var fs := size if size > 0 else l.get_theme_font_size("font_size")
	l.add_theme_color_override("font_shadow_color", Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.0))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 0)
	var big := fs >= 60
	var k := strength * (0.42 if big else 0.75)
	var g: TextureRect = l.get_meta("_soft_halo") if l.has_meta("_soft_halo") else null
	if g != null and is_instance_valid(g):
		g.modulate = Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.3 * k)
		return l
	g = scene_halo(l, k, 1.12 if big else 1.35)
	l.set_meta("_soft_halo", g)
	return l


## A soft slate glow behind on-scene text / numerals so warm-white text reads even over bright
## sky or marble (no panel, no stroke). Added as a child drawn behind `target`.
static func scene_halo(target: Control, strength := 1.0, scale := 1.5) -> TextureRect:
	var g := TextureRect.new()
	g.texture = glow_texture()
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.modulate = Color(SCRIM.r, SCRIM.g, SCRIM.b, 0.3 * strength)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	target.add_child(g)
	# Sized to the glyphs (not the Label rect, which a container may stretch): no smear.
	var fit := func():
		var box := Rect2(Vector2.ZERO, target.size)
		if target is Label:
			var l := target as Label
			var fs := l.get_theme_font_size("font_size")
			var tw := minf(l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, target.size.x)
			var x0 := 0.0
			if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x0 = (target.size.x - tw) * 0.5
			elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x0 = target.size.x - tw
			box = Rect2(Vector2(x0, 0), Vector2(tw, target.size.y))
		var s := box.size * Vector2(scale, scale * 1.25)
		g.size = s
		g.position = box.position + (box.size - s) * 0.5
	target.resized.connect(fit)
	if target is Label:
		target.draw.connect(func(): fit.call_deferred())
	fit.call()
	return g


## Text that sits on a 3D scene / art: warm white + soft shadow.
static func scene_label(text: String, size := 24, bold := true) -> Label:
	var l := label(text, size, ON_SCENE, bold)
	soft_shadow(l, size)
	return l


## Small caps label (taupe, tracked): section labels, stat names.
static func caps(text: String, size := 22, color := INK_DIM_GLASS) -> Label:
	var l := label(text.to_upper(), size, color)
	l.add_theme_font_override("font", font_caps(size))
	return l


## Engraved section title (tracked caps): v3.1 in the glass-safe amber ink (GOLD_TEXT_GLASS,
## >= 4.6:1 on the worst frost; reads as the same engraved gold on cream).
static func section(text: String, size := 22) -> Label:
	return caps(text, size, GOLD_TEXT_GLASS)


## Big number (ExtraBold, tabular digits): ink on cream or warm white on scenes.
static func number(text: String, size := 48, on_scene := false, color := Color(0, 0, 0, 0)) -> Label:
	var col := color if color.a > 0.0 else (ON_SCENE if on_scene else INK)
	var l := label(text, size, col, true)
	# v3: ExtraBold only for the big numbers of a screen (>= 40 px); smaller numbers are Bold.
	l.add_theme_font_override("font", font_w("extrabold" if size >= 40 else "bold"))
	if on_scene:
		soft_shadow(l, size)
	return l


## Title with a quiet vertical gradient. Default = ink (titles on cream). Passing light
## colours (on-scene titles) adds the soft shadow. `outline` is ignored (no strokes in v2).
static func gradient_heading(text: String, size := 64, top := Color("#5D6A80"), mid := INK, bottom := Color("#3C4557"), outline := 0) -> Label:
	var l := label(text, size, Color.WHITE, true, 0)
	l.add_theme_font_override("font", font_w("bold"))
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
		# Icon and label read as one centred group: the label's box is shifted right by half
		# the icon slot and the icon sits just before the label (never stranded at the edge).
		var slot := 44.0
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var kind := "button" if st in ["normal", "hover"] else ("button_disabled" if st == "disabled" else "button_pressed")
			var sb: StyleBox = lux(kind, Vector2(20, 10)).duplicate()
			sb.content_margin_left = 20.0 + slot
			sb.content_margin_right = 20.0
			b.add_theme_stylebox_override(st, sb)
		var ic := Icons.make(icon, 34.0, INK)
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_top = -17.0
		ic.offset_bottom = 17.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var place := func() -> void:
			var tw := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			var x0 := roundf(b.size.x * 0.5 - minf(tw, b.size.x - 40.0 - slot) * 0.5 - slot * 0.5)
			if not is_equal_approx(ic.offset_left, x0):
				ic.offset_left = x0
				ic.offset_right = x0 + 34.0
		b.draw.connect(place)
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
## v3: "modal" panels are frosted cream glass (+ text bed + top-corner flourishes) when the hub's
## world snapshot exists (KitGlass); flat 0.97 cream with the same lines and flourishes otherwise.
static func panel(kind := "panel", pad := Vector2(-1, -1)) -> PanelContainer:
	var p := PanelContainer.new()
	if kind == "modal" and frost_into(p, kind, pad):
		return p
	p.add_theme_stylebox_override("panel", lux(kind, pad))
	return p


## Gives an existing PanelContainer the frosted `kind` body ("modal" | "panel"): the opaque-painted
## `<kind>_frost` style + the KitGlass frost material at UITokens.FROST_MODAL_TINT (0.72), and the 94 %
## cream text bed under its content (§4.3: frost shows only in the rim band and the margins).
## Returns false (and sets the flat `kind`) when there is no world snapshot.
static func frost_into(p: PanelContainer, kind := "modal", pad := Vector2(-1, -1)) -> bool:
	var m := KitGlass.frost(UITokens.FROST_MODAL_TINT)
	if m == null:
		p.add_theme_stylebox_override("panel", lux(kind, pad))
		return false
	p.add_theme_stylebox_override("panel", lux(kind + "_frost", pad))
	p.material = m
	var bed := text_bed(p)
	bed.frame_kind = kind + "_lines"
	return true


## Adds (once) the §4.3 text bed to a frosted container: a feathered 94 % cream bed over its
## content rect (grown into the padding), drawn behind the content. It is an INTERNAL child, so
## get_child(0) and the container layout are unchanged. `top_frac` leaves the top share of the
## box as frost (sheets: 0.2, the frost ramp above the first row). Returns the bed.
static func text_bed(p: Control, top_frac := 0.0) -> TextBed:
	for c in p.get_children(true):
		if c is TextBed:
			(c as TextBed).top_frac = top_frac
			return c
	var bed := TextBed.new()
	bed.top_frac = top_frac
	p.add_child(bed, false, Node.INTERNAL_MODE_FRONT)
	return bed


## The text bed of a frosted container, or null (flat fallback: no bed).
static func text_bed_of(p: Control) -> TextBed:
	for c in p.get_children(true):
		if c is TextBed:
			return c
	return null


## Translucent cream over 3D (porcelain), one hairline.
static func glass_panel(pad := Vector2(-1, -1)) -> PanelContainer:
	return panel("cream_glass", pad)


## v3 frosted panel: with the hub's world snapshot (KitGlass) the body is frosted cream glass
## (the blurred world glows through the rim at UITokens.FROST_MODAL_TINT, body text sits on the
## text bed); without it, the flat translucent `kind` ("modal" | "panel").
static func frost_panel(kind := "modal", pad := Vector2(-1, -1)) -> PanelContainer:
	var p := PanelContainer.new()
	frost_into(p, kind, pad)
	return p


## Bottom sheet: frosted cream glass (flat SHEET_FILL without a snapshot), a straight fading top
## rule with a small centre diamond (KitSheet), the text bed below the top 20 % frost ramp.
static func sheet(pad := Vector2(-1, -1)) -> KitSheet:
	var s := KitSheet.new()
	var m := KitGlass.frost(UITokens.FROST_RIM_TINT)
	if m:
		s.add_theme_stylebox_override("panel", lux("sheet_frost", pad))
		s.material = m
		text_bed(s, 0.2).sheet_top = true
	else:
		s.add_theme_stylebox_override("panel", lux("sheet", pad))
	return s


## Modal frame: frosted panel (text bed, top-corner flourishes), title 40 Bold ink, a 1 dpx ring
## close disc, a fading header rule with a diamond centre. Body content goes into
## modal.get_meta("body") (a VBoxContainer). `on_close` runs on the close disc.
static func modal(title: String, on_close := Callable(), width := 600.0) -> PanelContainer:
	var p := frost_panel("modal")
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var tl := heading(title, 40, INK)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size_flags_vertical = Control.SIZE_FILL
	head.add_child(tl)
	if on_close.is_valid():
		var x := edge_button("close", 26.0)
		x.pressed.connect(on_close)
		head.add_child(x)
	v.add_child(divider(width - 72.0))
	# The bed starts under the header rule (TextBed finds the Divider after the header row).
	for c in p.get_children(true):
		if c is TextBed:
			(c as TextBed).header = head
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
	var l := label(text, 24, INK)
	row.add_child(l)
	host.add_child(p)
	var ms := p.get_combined_minimum_size()
	p.size = ms
	var vw := host.size.x if host.size.x > 0.0 else 720.0
	p.position = Vector2((vw - ms.x) * 0.5, y)
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
		# v3.1: no emboss / shadow on the label (no text outlines anywhere).
		l = number(text, 56, false, CTA_TEXT)
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
## Soft surface-coloured fades at a ScrollContainer's edges (only while content runs past them),
## so a list melts into its frame instead of being cut through a row.
static func scroll_fade(sc: ScrollContainer, color := CREAM, bottom := 44.0, top := 22.0) -> KitScrollFade:
	return KitScrollFade.attach(sc, color, bottom, top)


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
## A burst of soft round motes in `color` (additive, bloom falloff). No 4-point sparkles: the
## signature glint (sparkle_texture) is kept for rare single accents.
static func sparkles(parent: Control, pos: Vector2, color := GOLD_LIGHT, amount := 26, spread := 260.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = glow_texture()
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
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.15
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1).lerp(Color(color.r, color.g, color.b, 1.0), 0.35))
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

## Gold hairline divider (§3.2): 1 dpx, fading over its outer quarter, marquise terminals and a
## small cut-gem diamond at the centre (or a plain fading list rule).
class Divider extends Control:
	var keystone := true
	var plain := false
	var color := UITokens.HAIRLINE

	func _draw() -> void:
		var y := GemDraw.pixel_y(self, size.y * 0.5)
		if plain:
			var c0 := Color(color.r, color.g, color.b, 0.0)
			draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(size.x * 0.22, y), Vector2(size.x * 0.78, y), Vector2(size.x, y)]),
					PackedColorArray([c0, color, color, c0]), -1.0)
			return
		GemDraw.draw_hairline(self, Vector2(0, y), Vector2(size.x, y), Color(color.r, color.g, color.b, color.a * 0.85), 1.0, keystone, true)


## §4.3 text bed: a feathered 94 % cream bed (lux "text_bed") over the parent container's
## content rect, grown 22 px into the padding, so body text on a frosted modal / sheet never
## sits on the moving world (luma SD <= 4 in the text column). An INTERNAL child (drawn before
## the content; invisible to get_child() and to the container layout). `top_frac` leaves the top
## share of the parent as plain frost (the sheet's frost ramp).
## It also carries the frosted box's FRAME (`frame_kind`, a lines-only lux kind) and the sheet's
## top rule (`sheet_top`), drawn outside the frost material so the gold stays pure gold.
class TextBed extends Control:
	const GROW := 20.0
	var top_frac := 0.0
	var frame_kind := ""
	var sheet_top := false
	var bed := true
	## Optional: the header row of the box (a modal's title). The bed starts under it, so the title
	## sits on the frost ramp and only the body column is bedded.
	var header: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var p := get_parent() as Control
		if p:
			p.resized.connect(queue_redraw)
			p.sort_children.connect(queue_redraw)

	func _draw() -> void:
		var p := get_parent() as Control
		if p == null:
			return
		# The container may lay this child out in its content rect: draw in the PARENT's space.
		var o := -position
		var ps := p.size
		var sb := p.get_theme_stylebox("panel")
		var m := Vector4(24, 24, 24, 24)
		if sb:
			m = Vector4(sb.content_margin_left, sb.content_margin_top, sb.content_margin_right, sb.content_margin_bottom)
		var framed := frame_kind != ""
		var r: Rect2
		if framed:
			# Modal / panel: the bed's full-strength edge meets the content margin, its 12 px
			# feather runs outward, and a clean band of frost (>= 16 px, 24-32 px on modal()) stays
			# between it and the frame: the glass reads as glass, the text column stays even.
			var fe := UITokens.BED_FEATHER_MODAL
			var ix := clampf(minf(m.x, m.z) - fe, 16.0, 32.0)
			var iy := clampf(m.w - fe, 14.0, 32.0)
			r = Rect2(Vector2(ix, iy), ps - Vector2(ix * 2.0, iy * 2.0))
		else:
			var g := GROW
			r = Rect2(Vector2(m.x - g, m.y - g), ps - Vector2(m.x + m.z - g * 2.0, m.y + m.w - g * 2.0))
			# Keep a frost rim of at least 8 px inside the frame.
			r = r.intersection(Rect2(Vector2(8, 8), ps - Vector2(16, 16)))
		var t := r.position.y
		if top_frac > 0.0:
			t = maxf(t, ps.y * top_frac)
		var hdr := _header_end()
		if hdr and is_instance_valid(hdr) and hdr.is_visible_in_tree():
			var hb := p.get_global_transform().affine_inverse() * hdr.get_global_rect().end
			t = maxf(t, hb.y + (2.0 if framed else 4.0))
		if t > r.position.y:
			r = Rect2(Vector2(r.position.x, t), Vector2(r.size.x, r.end.y - t))
		if bed and r.size.x >= 8.0 and r.size.y >= 8.0:
			draw_style_box(UIKit.lux("text_bed_modal" if framed else "text_bed"), Rect2(r.position + o, r.size))
		if framed:
			draw_style_box(UIKit.lux(frame_kind), Rect2(o, ps))
			_specular(o, ps)
		if sheet_top:
			KitNav.draw_arch_top(self, Rect2(o, ps), 0.0, UITokens.CHAMFER_L, UITokens.SHEET_FILL, true)

	## The header band's last control: the header row, or the divider right under it (the bed
	## starts below the header rule, so the title AND its rule sit on the frost).
	func _header_end() -> Control:
		if header == null or not is_instance_valid(header):
			return null
		var hp := header.get_parent()
		if hp is BoxContainer:
			var i := header.get_index()
			if i + 1 < hp.get_child_count():
				var nx := hp.get_child(i + 1)
				if nx is Divider and (nx as Control).visible:
					return nx
		return header

	## A 1 dpx white specular line along the inside top edge (glass catching the light), between
	## the top-corner flourishes, fading out at both ends.
	func _specular(o: Vector2, ps: Vector2) -> void:
		var cham := 12.0
		var y := GemDraw.pixel_y(self, o.y + 3.0)
		var x0 := o.x + cham + 34.0
		var x1 := o.x + ps.x - cham - 34.0
		if x1 - x0 < 40.0:
			return
		var w := x1 - x0
		var c := Color(1, 1, 1, 0.9)
		var c0 := Color(1, 1, 1, 0.0)
		draw_polyline_colors(PackedVector2Array([Vector2(x0, y), Vector2(x0 + w * 0.25, y), Vector2(x1 - w * 0.25, y), Vector2(x1, y)]),
				PackedColorArray([c0, c, c, c0]), -1.0 if UIKit.ui_scale() >= 0.9 else UIKit.px(1.0))


## Slowly rotating light rays (victory sunburst / reward halo). Soft and warm in v2.
class Rays extends Control:
	## Soft light shafts for reward moments (fusion §6.6): 5-7 tapered shafts with feathered
	## sides whose alpha rises from 0 at the root to a peak (~18 %) and fades to 0 at the tip,
	## turning slowly over a radial bloom in the gem colour, plus a whisper of the gem's
	## fracture lines. No hard wedges. `on_light` (a cream sheet): only the bloom + motes.
	var color := Color(1.0, 0.86, 0.55, 0.28)
	var count := 6
	var speed := 0.05
	var inner := 0.0
	var gem := ""
	var on_light := false
	var _a := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _ready() -> void:
		if on_light:
			material = null

	func _process(delta: float) -> void:
		_a += delta * minf(speed, 0.06)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		var cc := Color(color.r, color.g, color.b, 1.0)
		if on_light:
			# Cream sheet: a soft radial glow only (never saturated wedges on cream).
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R), Vector2(R, R) * 2.0), false, Color(cc.r, cc.g, cc.b, minf(0.55, color.a * 1.2)))
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 0.5, Vector2(R, R)), false, Color(1, 1, 1, 0.35))
			return
		# Bloom.
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(R, R) * 0.9, Vector2(R, R) * 1.8), false, Color(cc.r, cc.g, cc.b, minf(0.7, color.a * 1.5)))
		var n := clampi(count, 5, 7)
		var peak := minf(color.a * 1.1, 0.2)
		var rin := maxf(R * inner, R * 0.08)
		var radial := [rin, R * 0.42, R]
		var ra := [0.0, 1.0, 0.0]
		for i in n:
			# Uneven spacing and widths so it reads as light, not a sunburst.
			var ang := _a + TAU * (float(i) + 0.18 * sin(i * 2.3)) / n
			var w_tip := (0.11 + 0.05 * sin(i * 1.7 + 0.5)) * PI / n * 2.2
			var amp := peak * (0.75 + 0.25 * sin(i * 3.1 + _a * 3.0))
			var grid: Array = []
			for k in 3:
				var row: Array = []
				var r: float = radial[k]
				var hw := w_tip * (0.25 + 0.75 * r / R)
				for j in 3:
					var aa: float = ang + (float(j) - 1.0) * hw
					var al: float = amp * float(ra[k]) * (1.0 if j == 1 else 0.0)
					row.append([c + Vector2(cos(aa), sin(aa)) * r, Color(cc.r, cc.g, cc.b, al)])
				grid.append(row)
			for k in 2:
				for j in 2:
					var p00: Array = grid[k][j]
					var p01: Array = grid[k][j + 1]
					var p11: Array = grid[k + 1][j + 1]
					var p10: Array = grid[k + 1][j]
					draw_polygon(PackedVector2Array([p00[0], p01[0], p11[0], p10[0]]), PackedColorArray([p00[1], p01[1], p11[1], p10[1]]))
		# The gem's fracture whisper (8-12 %): a few long, faint refraction lines.
		if gem != "":
			var g := UITokens.gem(gem)
			var lc: Color = g["light"]
			for i in 4:
				var la := _a * 0.5 + i * 0.83 + (0.4 if gem == "sapphire" else 0.0)
				var d := Vector2(cos(la), sin(la))
				var o := Vector2(-d.y, d.x) * R * (0.18 * (i - 1.5))
				draw_line(c + o - d * R * 0.85, c + o + d * R * 0.85, Color(lc.r, lc.g, lc.b, 0.1), 1.5, true)


## Title ribbon (victory / result band): a band with V-notched, chamfered ends, a quiet
## vertical gradient, inner hairlines and marquise terminals. Default = amber (victory);
## set_palette(top, bottom, line) for other moods (e.g. a cool slate defeat).
class Ribbon extends Control:
	# CTA study (calm): a porcelain plate with a gold hairline instead of the honey band.
	var top := Color("#FFE1A0") if not UITokens.calm_cta() else Color("#FFFDF8")
	var bottom := Color("#EFA448") if not UITokens.calm_cta() else Color("#F1E8D6")
	var fold := Color(1.0, 0.96, 0.84, 0.85) if not UITokens.calm_cta() else Color(UITokens.HAIRLINE, 0.9)

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
		# Soft shadow: one halo (no stacked discs).
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(-w * 0.04, h * 0.25), Vector2(w * 1.08, h * 1.0)), false,
				Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, p.y / maxf(h, 1.0)))
		draw_polygon(pts, cols)
		# v3.1 (§7.10): 1 dpx rules with a diamond centre, a 1 dpx frame, diamonds at the notches.
		var lc := fold
		var y0 := GemDraw.pixel_y(self, 5.0)
		var y1 := GemDraw.pixel_y(self, h - 5.0)
		draw_line(Vector2(cut + notch, y0), Vector2(w - cut - notch, y0), lc, -1.0)
		draw_line(Vector2(cut + notch, y1), Vector2(w - cut - notch, y1), lc, -1.0)
		GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), UIKit.line_px(1.0))
		GemDraw.draw_diamond(self, Vector2(w * 0.5, y0), 9.0, Color("#F3E2B8"), UITokens.LINE_GOLD_DEEP)
		GemDraw.draw_diamond(self, Vector2(notch + 14.0, h * 0.5), 12.0, Color("#F3E2B8"), UITokens.LINE_GOLD_DEEP)
		GemDraw.draw_diamond(self, Vector2(w - notch - 14.0, h * 0.5), 12.0, Color("#F3E2B8"), UITokens.LINE_GOLD_DEEP)


## HBox list row that draws a hairline under itself (no boxes): 1 dpx HAIRLINE @ 0.55 fading
## over the outer 22 % (§3.1).
class KitRow extends HBoxContainer:
	func _draw() -> void:
		var y := GemDraw.pixel_y(self, size.y - UIKit.px(0.5))
		var c := Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.55)
		var c0 := Color(c.r, c.g, c.b, 0.0)
		draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(size.x * 0.22, y), Vector2(size.x * 0.78, y), Vector2(size.x, y)]),
				PackedColorArray([c0, c, c, c0]), -1.0)
