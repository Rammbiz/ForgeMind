class_name UIKit
## Shared UI theme, fonts, colours and widget factories ("heavy luxe" look).
## Panels and buttons are nine-patch StyleBoxTextures painted in code once (dark glass, gold
## frames, soft drop shadows, glossy gradients) and cached. Also: gold gradient text, light
## rays, shine sweeps, count-up numbers and staggered pop-ins.

const TEXT := Color(1.0, 0.97, 0.9)
const TEXT_DIM := Color(0.74, 0.78, 0.9)
const GOLD := Color(1.0, 0.8, 0.32)
const GOLD_LIGHT := Color(1.0, 0.95, 0.72)
const GOLD_DARK := Color(0.72, 0.46, 0.14)
const PANEL := Color(0.075, 0.09, 0.16, 0.9)
const PANEL_LIGHT := Color(0.13, 0.16, 0.27, 0.95)
const NAVY := Color(0.05, 0.07, 0.15)
const INK := Color(0.02, 0.025, 0.07, 0.95)
const RED := Color(1.0, 0.36, 0.36)
const GREEN := Color(0.45, 0.92, 0.5)
const ICE := Color(0.45, 0.85, 1.0)
const VIOLET := Color(0.78, 0.55, 1.0)
const PRIMARY := Color(0.98, 0.6, 0.2)
const PRIMARY_DARK := Color(0.68, 0.3, 0.08)
const BROWN := Color(0.24, 0.1, 0.02)

const SHINE_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float progress = -1.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float radius = 20.0;
uniform float width = 0.16;
uniform float strength = 0.55;
float rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 px = UV * rect_size;
	float inside = 1.0 - smoothstep(-1.0, 0.5, rbox(px - rect_size * 0.5, rect_size * 0.5, radius));
	float s = UV.x + UV.y * 0.45 * rect_size.y / max(rect_size.x, 1.0);
	float c = progress * 1.7 - 0.35;
	float band = 1.0 - smoothstep(0.0, width, abs(s - c));
	float core = 1.0 - smoothstep(0.0, width * 0.25, abs(s - c));
	COLOR = vec4(vec3(1.0, 0.97, 0.88) * (band * 0.6 + core * 0.4) * strength * inside, 1.0);
}
"""

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
	// Only the glyph fill (font colour is white); outlines and shadows keep their colour.
	if (vcol.r > 0.6 && vcol.g > 0.6 && vcol.b > 0.6) {
		float t = clamp((ly - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(top_color.rgb, mid_color.rgb, t * 2.0) : mix(mid_color.rgb, bottom_color.rgb, t * 2.0 - 1.0);
		// A thin bright line across the upper third reads as polished metal.
		g += vec3(0.18) * (1.0 - smoothstep(0.0, 0.05, abs(t - 0.36)));
		COLOR.rgb = g * vcol.rgb;
	}
}
"""

static var _theme: Theme
static var _font_regular: Font
static var _font_bold: Font
static var _styles := {}
static var _textures := {}
static var _shine_shader: Shader
static var _text_shader: Shader


static func font(bold := false) -> Font:
	if bold:
		if _font_bold == null:
			_font_bold = _load_font("res://assets/fonts/Rubik-ExtraBold.ttf")
		return _font_bold
	if _font_regular == null:
		_font_regular = _load_font("res://assets/fonts/Rubik-Medium.ttf")
	return _font_regular


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


## Flat rounded box (kept for small widgets and backwards compatibility).
static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 18, border_w := 0, shadow := 0, pad := Vector2(18, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s


# ------------------------------------------------------------------ painted styles

## Premium nine-patch styles, painted once and cached. Kinds:
##   "panel"    modal glass panel, double gold frame, deep shadow
##   "card"     glass card with a thin gold rim; "card_sel" bright gold frame + glow
##   "card_dim" glass card with a cool steel rim
##   "pill"     HUD pill (dark glass, thin gold rim, small shadow)
##   "pill_dark" HUD pill without the rim
##   "button" / "button_pressed" / "button_disabled"  secondary navy glass buttons
##   "primary" / "primary_pressed" / "primary_disabled" glossy gold-orange buttons
##   "green" / "green_pressed"  glossy emerald buttons
##   "banner"   tutorial hint banner (glass, gold frame, inner glow)
## `pad` sets the content margins.
static func lux(kind: String, pad := Vector2(-1, -1)) -> StyleBoxTexture:
	var key := "%s_%d_%d" % [kind, int(pad.x), int(pad.y)]
	if _styles.has(key):
		return _styles[key]
	var spec := _spec(kind)
	var tex: Texture2D = _textures.get(kind)
	if tex == null:
		tex = ImageTexture.create_from_image(_cached_paint(kind, spec))
		_textures[kind] = tex
	var s := StyleBoxTexture.new()
	s.texture = tex
	var sh: float = spec["shadow"]
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
	s.content_margin_left = p.x
	s.content_margin_right = p.x
	s.content_margin_top = p.y
	s.content_margin_bottom = p.y + float(spec.get("lip", 0.0))
	_styles[key] = s
	return s


static func _spec(kind: String) -> Dictionary:
	var glass_top := Color(0.13, 0.16, 0.3, 0.96)
	var glass_bot := Color(0.035, 0.045, 0.1, 0.97)
	match kind:
		"panel":
			return {"rad": 34.0, "shadow": 26.0, "pad": Vector2(40, 34), "layers": [
				{"inset": 0.0, "top": Color(1.0, 0.93, 0.62), "bot": Color(0.66, 0.38, 0.1)},
				{"inset": 4.0, "top": Color(0.2, 0.12, 0.04), "bot": Color(0.12, 0.06, 0.02)},
				{"inset": 6.0, "top": Color(0.98, 0.78, 0.36), "bot": Color(0.6, 0.34, 0.1)},
				{"inset": 8.0, "top": glass_top, "bot": glass_bot},
				{"inset": 8.0, "sheen": 0.11},
				{"inset": 12.0, "ring": 1.5, "top": Color(1, 0.85, 0.5, 0.22), "bot": Color(1, 0.85, 0.5, 0.06)},
			]}
		"card":
			return {"rad": 26.0, "shadow": 16.0, "pad": Vector2(16, 14), "layers": [
				{"inset": 0.0, "top": Color(0.98, 0.8, 0.42, 0.9), "bot": Color(0.5, 0.3, 0.1, 0.9)},
				{"inset": 3.0, "top": Color(0.12, 0.15, 0.29, 0.94), "bot": Color(0.04, 0.05, 0.11, 0.95)},
				{"inset": 3.0, "sheen": 0.09},
			]}
		"card_sel":
			return {"rad": 26.0, "shadow": 22.0, "glow": Color(1.0, 0.78, 0.3, 0.75), "pad": Vector2(16, 14), "layers": [
				{"inset": 0.0, "top": Color(1.0, 0.97, 0.74), "bot": Color(0.86, 0.5, 0.12)},
				{"inset": 5.0, "top": Color(0.18, 0.2, 0.36, 0.96), "bot": Color(0.06, 0.07, 0.15, 0.97)},
				{"inset": 5.0, "sheen": 0.13},
				{"inset": 8.0, "ring": 1.5, "top": Color(1, 0.9, 0.55, 0.35), "bot": Color(1, 0.9, 0.55, 0.05)},
			]}
		"card_dim":
			return {"rad": 26.0, "shadow": 14.0, "pad": Vector2(16, 14), "layers": [
				{"inset": 0.0, "top": Color(0.55, 0.62, 0.8, 0.7), "bot": Color(0.2, 0.24, 0.36, 0.7)},
				{"inset": 2.5, "top": Color(0.1, 0.12, 0.23, 0.9), "bot": Color(0.035, 0.045, 0.1, 0.92)},
				{"inset": 2.5, "sheen": 0.07},
			]}
		"pill":
			return {"rad": 26.0, "shadow": 10.0, "pad": Vector2(18, 6), "layers": [
				{"inset": 0.0, "top": Color(1.0, 0.86, 0.5, 0.85), "bot": Color(0.55, 0.32, 0.1, 0.85)},
				{"inset": 2.5, "top": Color(0.1, 0.13, 0.25, 0.9), "bot": Color(0.03, 0.04, 0.09, 0.92)},
				{"inset": 2.5, "sheen": 0.1},
			]}
		"pill_dark":
			return {"rad": 26.0, "shadow": 10.0, "pad": Vector2(18, 6), "layers": [
				{"inset": 0.0, "top": Color(0.1, 0.13, 0.25, 0.86), "bot": Color(0.03, 0.04, 0.09, 0.9)},
				{"inset": 0.0, "sheen": 0.09},
				{"inset": 1.0, "ring": 1.2, "top": Color(1, 1, 1, 0.16), "bot": Color(1, 1, 1, 0.03)},
			]}
		"banner":
			return {"rad": 30.0, "shadow": 18.0, "glow": Color(0.45, 0.75, 1.0, 0.35), "pad": Vector2(26, 14), "layers": [
				{"inset": 0.0, "top": Color(1.0, 0.94, 0.66), "bot": Color(0.72, 0.42, 0.12)},
				{"inset": 3.0, "top": Color(0.14, 0.2, 0.4, 0.95), "bot": Color(0.04, 0.06, 0.14, 0.96)},
				{"inset": 3.0, "sheen": 0.13},
				{"inset": 6.0, "ring": 1.5, "top": Color(0.6, 0.85, 1.0, 0.3), "bot": Color(0.6, 0.85, 1.0, 0.04)},
			]}
		"button":
			return {"rad": 24.0, "shadow": 12.0, "lip": 5.0, "pad": Vector2(28, 12), "layers": [
				{"inset": 0.0, "top": Color(0.62, 0.42, 0.14), "bot": Color(0.36, 0.2, 0.06)},
				{"inset": 0.0, "lip": 5.0, "top": Color(1.0, 0.9, 0.58), "bot": Color(0.78, 0.5, 0.16)},
				{"inset": 2.5, "lip": 5.0, "top": Color(0.2, 0.25, 0.44), "bot": Color(0.07, 0.09, 0.2)},
				{"inset": 2.5, "lip": 5.0, "sheen": 0.14},
			]}
		"button_pressed":
			return {"rad": 24.0, "shadow": 8.0, "lip": 1.5, "pad": Vector2(28, 15), "layers": [
				{"inset": 0.0, "top": Color(0.5, 0.32, 0.1), "bot": Color(0.3, 0.16, 0.05)},
				{"inset": 0.0, "lip": 1.5, "top": Color(0.9, 0.72, 0.4), "bot": Color(0.6, 0.38, 0.12)},
				{"inset": 2.5, "lip": 1.5, "top": Color(0.08, 0.1, 0.2), "bot": Color(0.12, 0.15, 0.3)},
			]}
		"button_disabled":
			return {"rad": 24.0, "shadow": 8.0, "lip": 4.0, "pad": Vector2(28, 12), "layers": [
				{"inset": 0.0, "top": Color(0.2, 0.21, 0.26, 0.9), "bot": Color(0.12, 0.13, 0.17, 0.9)},
				{"inset": 0.0, "lip": 4.0, "top": Color(0.42, 0.44, 0.5, 0.9), "bot": Color(0.28, 0.3, 0.36, 0.9)},
				{"inset": 2.5, "lip": 4.0, "top": Color(0.17, 0.18, 0.24, 0.92), "bot": Color(0.1, 0.11, 0.15, 0.92)},
			]}
		"primary":
			return {"rad": 30.0, "shadow": 16.0, "lip": 7.0, "pad": Vector2(32, 14), "layers": [
				{"inset": 0.0, "top": Color(0.62, 0.26, 0.04), "bot": Color(0.42, 0.15, 0.02)},
				{"inset": 0.0, "lip": 7.0, "top": Color(1.0, 0.98, 0.8), "bot": Color(0.95, 0.62, 0.2)},
				{"inset": 2.5, "lip": 7.0, "top": Color(1.0, 0.86, 0.36), "bot": Color(0.98, 0.5, 0.1)},
				{"inset": 2.5, "lip": 7.0, "sheen": 0.32},
			]}
		"primary_pressed":
			return {"rad": 30.0, "shadow": 10.0, "lip": 2.0, "pad": Vector2(32, 18), "layers": [
				{"inset": 0.0, "top": Color(0.55, 0.22, 0.03), "bot": Color(0.38, 0.13, 0.02)},
				{"inset": 0.0, "lip": 2.0, "top": Color(0.98, 0.86, 0.6), "bot": Color(0.85, 0.5, 0.15)},
				{"inset": 2.5, "lip": 2.0, "top": Color(0.95, 0.66, 0.2), "bot": Color(0.96, 0.52, 0.12)},
			]}
		"primary_disabled":
			return _spec("button_disabled")
		"green":
			return {"rad": 30.0, "shadow": 16.0, "lip": 7.0, "pad": Vector2(32, 14), "layers": [
				{"inset": 0.0, "top": Color(0.06, 0.36, 0.14), "bot": Color(0.03, 0.22, 0.08)},
				{"inset": 0.0, "lip": 7.0, "top": Color(0.85, 1.0, 0.8), "bot": Color(0.25, 0.75, 0.3)},
				{"inset": 2.5, "lip": 7.0, "top": Color(0.55, 0.95, 0.45), "bot": Color(0.16, 0.66, 0.26)},
				{"inset": 2.5, "lip": 7.0, "sheen": 0.3},
			]}
		"green_pressed":
			return {"rad": 30.0, "shadow": 10.0, "lip": 2.0, "pad": Vector2(32, 18), "layers": [
				{"inset": 0.0, "top": Color(0.05, 0.3, 0.12), "bot": Color(0.03, 0.2, 0.07)},
				{"inset": 0.0, "lip": 2.0, "top": Color(0.7, 0.95, 0.65), "bot": Color(0.2, 0.6, 0.25)},
				{"inset": 2.5, "lip": 2.0, "top": Color(0.3, 0.8, 0.35), "bot": Color(0.18, 0.62, 0.25)},
			]}
	return _spec("card")


## Painting in GDScript costs ~0.1-0.3 s per style, so painted images are cached as PNGs in
## user://ui_cache (keyed by a hash of the spec); later launches load them instantly.
static func _cached_paint(kind: String, spec: Dictionary) -> Image:
	var path := "user://ui_cache/%s_%x.png" % [kind, str(spec).hash()]
	if FileAccess.file_exists(path):
		var cached := Image.load_from_file(path)
		if cached and not cached.is_empty():
			return cached
	var img := _paint(spec)
	DirAccess.make_dir_recursive_absolute("user://ui_cache")
	img.save_png(path)
	return img


static func _margin(spec: Dictionary) -> float:
	return ceilf(float(spec["shadow"]) + float(spec["rad"]) + 6.0)


static func _rbox(p: Vector2, center: Vector2, half: Vector2, r: float) -> float:
	var q := (p - center).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## Paints a nine-patch image from a layer spec: an outer drop shadow (and optional glow), then
## rounded-rect layers (vertical gradients, rings, glossy sheen), with 1 px anti-aliasing.
static func _paint(spec: Dictionary) -> Image:
	var rad: float = spec["rad"]
	var sh: float = spec["shadow"]
	var lip: float = spec.get("lip", 0.0)
	var margin := _margin(spec)
	var w := int(margin * 2.0 + 8.0)
	var h := int(margin * 2.0 + 40.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := Rect2(sh, sh, w - sh * 2.0, h - sh * 2.0)
	var glow: Color = spec.get("glow", Color(0, 0, 0, 0))
	var layers: Array = spec["layers"]
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			if sh > 0.0:
				# Soft drop shadow, offset down, and an optional coloured glow all around.
				var ds := _rbox(p, body.get_center() + Vector2(0, sh * 0.32), body.size * 0.5 - Vector2(sh * 0.15, sh * 0.15), rad)
				var a := 1.0 - smoothstep(-sh * 0.5, sh * 0.9, ds)
				col = Color(0.0, 0.0, 0.02, 0.55 * a * a)
				if glow.a > 0.0:
					var dg := _rbox(p, body.get_center(), body.size * 0.5, rad)
					var ga := (1.0 - smoothstep(-2.0, sh, dg)) * glow.a
					col = _over(col, Color(glow.r, glow.g, glow.b, ga * ga))
			for L: Dictionary in layers:
				var inset: float = L.get("inset", 0.0)
				var llip: float = L.get("lip", 0.0)
				var lr := Rect2(body.position + Vector2(inset, inset), body.size - Vector2(inset, inset) * 2.0 - Vector2(0, llip))
				var lrad := maxf(rad - inset, 2.0)
				var d := _rbox(p, lr.get_center(), lr.size * 0.5, lrad)
				var cov := clampf(0.5 - d, 0.0, 1.0)
				if cov <= 0.0:
					continue
				var t := clampf((p.y - lr.position.y) / maxf(lr.size.y, 1.0), 0.0, 1.0)
				if L.has("sheen"):
					# Glossy upper half: bright near the top edge, fading to nothing at ~45 %.
					var ty := (p.y - lr.position.y)
					var s: float = L["sheen"]
					var fall := 1.0 - smoothstep(0.0, minf(lr.size.y * 0.45, 46.0), ty)
					var top_hi := 1.0 - smoothstep(0.0, 3.0, ty)
					var a2 := (fall * s + top_hi * s * 1.2) * cov
					col = _over(col, Color(1, 1, 1, clampf(a2, 0.0, 1.0)))
					continue
				var c: Color = (L["top"] as Color).lerp(L["bot"], t)
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


## A 4-point sparkle sprite for particles.
static func sparkle_texture() -> Texture2D:
	if _textures.has("_sparkle"):
		return _textures["_sparkle"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var star := maxf(0.0, 1.0 - absf(p.x) * 8.0 - absf(p.y) * 1.1) + maxf(0.0, 1.0 - absf(p.y) * 8.0 - absf(p.x) * 1.1)
			var core := maxf(0.0, 1.0 - p.length() * 2.6)
			var a := clampf(star + core * core, 0.0, 1.0)
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
	t.default_font_size = 26
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.03, 0.08, 0.9))
	t.set_constant("outline_size", "Label", 0)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0.03, 0.0))
	# Buttons
	t.set_stylebox("normal", "Button", lux("button"))
	t.set_stylebox("hover", "Button", lux("button"))
	t.set_stylebox("pressed", "Button", lux("button_pressed"))
	t.set_stylebox("hover_pressed", "Button", lux("button_pressed"))
	t.set_stylebox("disabled", "Button", lux("button_disabled"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font(true))
	t.set_font_size("font_size", "Button", 28)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.57, 0.63))
	t.set_color("font_outline_color", "Button", Color(0.01, 0.02, 0.06, 0.85))
	t.set_constant("outline_size", "Button", 6)
	t.set_constant("h_separation", "Button", 12)
	# Primary (gold) and green button variations
	for v: String in ["PrimaryButton", "GreenButton"]:
		var base := "primary" if v == "PrimaryButton" else "green"
		t.set_type_variation(v, "Button")
		t.set_stylebox("normal", v, lux(base))
		t.set_stylebox("hover", v, lux(base))
		t.set_stylebox("pressed", v, lux(base + "_pressed"))
		t.set_stylebox("hover_pressed", v, lux(base + "_pressed"))
		t.set_stylebox("disabled", v, lux("primary_disabled"))
		t.set_font_size("font_size", v, 34)
		t.set_constant("outline_size", v, 0)
	t.set_color("font_color", "PrimaryButton", BROWN)
	t.set_color("font_hover_color", "PrimaryButton", Color(0.18, 0.07, 0.0))
	t.set_color("font_pressed_color", "PrimaryButton", Color(0.18, 0.07, 0.0))
	t.set_color("font_hover_pressed_color", "PrimaryButton", Color(0.18, 0.07, 0.0))
	t.set_color("font_color", "GreenButton", Color(1, 1, 1))
	t.set_color("font_hover_color", "GreenButton", Color(1, 1, 1))
	t.set_color("font_pressed_color", "GreenButton", Color(0.92, 1, 0.9))
	t.set_color("font_hover_pressed_color", "GreenButton", Color(0.92, 1, 0.9))
	t.set_color("font_outline_color", "GreenButton", Color(0.02, 0.24, 0.08, 1.0))
	t.set_constant("outline_size", "GreenButton", 8)
	# Panels
	t.set_stylebox("panel", "PanelContainer", lux("panel"))
	t.set_stylebox("panel", "Panel", lux("panel"))
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", lux("pill"))
	t.set_type_variation("TipPanel", "PanelContainer")
	t.set_stylebox("panel", "TipPanel", lux("banner"))
	# Sliders
	var track := box(Color(0.2, 0.22, 0.32), Color(0, 0, 0, 0), 8, 0, 0, Vector2(0, 6))
	var fill := box(GOLD, Color(0, 0, 0, 0), 8, 0, 0, Vector2(0, 6))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_tex(34, Color(1, 0.95, 0.85)))
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(34, Color(1, 1, 1)))
	_theme = t
	return t


static func _circle_tex(size: int, c: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var edge := d > r - 3.0
			img.set_pixel(x, y, Color(c.r * (0.75 if edge else 1.0), c.g * (0.6 if edge else 1.0), c.b * (0.4 if edge else 1.0), a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ factories

static func label(text: String, size := 26, color := TEXT, bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.95))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bold label with a dark outline and a soft drop shadow: the standard for numbers and titles.
static func heading(text: String, size := 40, color := TEXT, outline := 8) -> Label:
	var l := label(text, size, color, true, outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0.04, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 14))
	l.add_theme_constant_override("shadow_outline_size", outline + 4)
	return l


## Heading with a metallic vertical gradient fill (gold by default). The gradient follows the
## label's glyph box, so it stays correct when the label is resized or scaled.
static func gradient_heading(text: String, size := 64, top := Color(1.0, 0.98, 0.8), mid := Color(1.0, 0.8, 0.3), bottom := Color(0.86, 0.46, 0.1), outline := 12) -> Label:
	var l := heading(text, size, Color.WHITE, outline)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02, 1.0))
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
		# Cap height of Rubik is ~0.7 em; glyph box per line ~ [0.22, 0.95] of the line height.
		var y0 := top_y + line_h * 0.5 - fs * 0.42
		var y1 := top_y + total - line_h * 0.5 + fs * 0.36
		m.set_shader_parameter("y0", y0)
		m.set_shader_parameter("y1", y1)
	l.resized.connect(fit)
	l.ready.connect(fit)
	return l


static func button(text: String, primary := false, min_width := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 84 if primary else 72)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", -4.0))
	b.button_down.connect(func(): _press_bounce(b, true))
	b.button_up.connect(func(): _press_bounce(b, false))
	return b


static func _press_bounce(b: Control, down: bool) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2(0.95, 0.95) if down else Vector2.ONE, 0.12 if down else 0.25)


## Pill-shaped HUD container (`dark` drops the gold rim).
static func pill(dark := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", lux("pill_dark" if dark else "pill"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## Thin gold divider line that fades out at both ends.
static func divider(width := 420.0) -> Control:
	var d := Divider.new()
	d.custom_minimum_size = Vector2(width, 10)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


# ------------------------------------------------------------------ motion

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


## Quick scale punch (1 → s → 1) around the centre.
static func punch(c: Control, s := 1.25, duration := 0.32) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Adds a diagonal light sweep across `target` (clipped to its rounded rect). Plays once after
## `delay`, then every `every` seconds if > 0.
static func add_shine(target: Control, radius := 26.0, delay := 0.35, every := 0.0, strength := 0.55) -> ColorRect:
	if _shine_shader == null:
		_shine_shader = Shader.new()
		_shine_shader.code = SHINE_SHADER
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _shine_shader
	m.set_shader_parameter("radius", radius)
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
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): m.set_shader_parameter("progress", -1.0))
	if every > 0.0:
		tw.tween_interval(every)
	return r


## Sparkle burst (CPU particles) centred on `pos` inside `parent`.
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
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
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
	env.ambient_light_color = Color(0.82, 0.86, 1.0)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_color = Color(0.6, 0.8, 1.0)
	rim.light_energy = 0.8
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

## Fading gold divider.
class Divider extends Control:
	func _draw() -> void:
		var y := size.y * 0.5
		var n := 24
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var a := 1.0 - absf((t0 + t1) - 1.0)
			draw_line(Vector2(size.x * t0, y), Vector2(size.x * t1, y), Color(1.0, 0.82, 0.4, 0.75 * a), 2.0, true)
		var c := Vector2(size.x * 0.5, y)
		var dpts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(6, 0), c + Vector2(0, 5), c + Vector2(-6, 0)])
		draw_colored_polygon(dpts, Color(1.0, 0.86, 0.45))


## Slowly rotating light rays (victory sunburst / reward halo).
class Rays extends Control:
	var color := Color(1.0, 0.85, 0.45, 0.35)
	var count := 14
	var speed := 0.18
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


## Title ribbon: a gold banner with folded tails, drawn behind a heading.
class Ribbon extends Control:
	var top := Color(1.0, 0.86, 0.4)
	var bottom := Color(0.86, 0.46, 0.1)
	var fold := Color(0.5, 0.22, 0.05)

	func set_palette(t: Color, b: Color, f: Color) -> void:
		top = t
		bottom = b
		fold = f
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var tail := h * 0.55
		var drop := h * 0.22
		# Tails (behind), folded down.
		for sgn: float in [-1.0, 1.0]:
			var x0 := w * 0.5 + sgn * (w * 0.5 - tail * 0.6)
			var x1 := w * 0.5 + sgn * (w * 0.5 + tail * 0.45)
			var tp := PackedVector2Array([
				Vector2(x0, drop), Vector2(x1, drop), Vector2(x1 - sgn * tail * 0.32, drop + h * 0.5),
				Vector2(x1, h + drop), Vector2(x0, h + drop)])
			draw_colored_polygon(tp, bottom.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([Vector2(x0, h), Vector2(x0 + sgn * tail * 0.6, h), Vector2(x0, h + drop)]), fold)
		# Shadow under the band.
		draw_rect(Rect2(Vector2(tail * 0.6 - 2, 6), Vector2(w - tail * 1.2 + 4, h)), Color(0, 0, 0, 0.3))
		# Main band with a vertical gradient.
		var x0b := tail * 0.6
		var x1b := w - tail * 0.6
		var pts := PackedVector2Array([Vector2(x0b, 0), Vector2(x1b, 0), Vector2(x1b, h), Vector2(x0b, h)])
		draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
		draw_rect(Rect2(Vector2(x0b, 0), Vector2(x1b - x0b, 3)), Color(1, 1, 0.9, 0.7))
		draw_rect(Rect2(Vector2(x0b, h - 3), Vector2(x1b - x0b, 3)), fold)
		draw_rect(Rect2(Vector2(x0b, h * 0.08), Vector2(x1b - x0b, h * 0.32)), Color(1, 1, 1, 0.14))
