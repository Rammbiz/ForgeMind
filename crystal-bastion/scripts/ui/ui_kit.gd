class_name UIKit
## Shared UI theme, fonts, colors and widget factories.

const TEXT := Color(1.0, 0.97, 0.9)
const TEXT_DIM := Color(0.78, 0.8, 0.9)
const GOLD := Color(1.0, 0.8, 0.32)
const GOLD_DARK := Color(0.72, 0.46, 0.14)
const PANEL := Color(0.075, 0.09, 0.16, 0.9)
const PANEL_LIGHT := Color(0.13, 0.16, 0.27, 0.95)
const RED := Color(1.0, 0.36, 0.36)
const GREEN := Color(0.45, 0.92, 0.5)
const PRIMARY := Color(0.98, 0.6, 0.2)
const PRIMARY_DARK := Color(0.68, 0.3, 0.08)

static var _theme: Theme
static var _font_regular: Font
static var _font_bold: Font


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
		return f
	return ThemeDB.fallback_font


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 18, border_w := 0, shadow := 0, pad := Vector2(18, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
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
	# Buttons
	var normal := box(PANEL_LIGHT, GOLD.darkened(0.15), 20, 3, 6, Vector2(26, 12))
	var hover := box(PANEL_LIGHT.lightened(0.08), GOLD, 20, 3, 6, Vector2(26, 12))
	var pressed := box(PANEL_LIGHT.darkened(0.2), GOLD.darkened(0.3), 20, 3, 2, Vector2(26, 12))
	var disabled := box(Color(0.15, 0.16, 0.2, 0.8), Color(0.35, 0.36, 0.4), 20, 3, 0, Vector2(26, 12))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", font(true))
	t.set_font_size("font_size", "Button", 28)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.56, 0.6))
	t.set_constant("h_separation", "Button", 12)
	# Primary button variation
	t.set_type_variation("PrimaryButton", "Button")
	var pn := box(PRIMARY, PRIMARY_DARK, 22, 0, 6, Vector2(30, 14))
	pn.border_width_bottom = 6
	pn.border_color = PRIMARY_DARK
	var ph := pn.duplicate() as StyleBoxFlat
	ph.bg_color = PRIMARY.lightened(0.12)
	var pp := pn.duplicate() as StyleBoxFlat
	pp.bg_color = PRIMARY.darkened(0.1)
	pp.border_width_bottom = 2
	pp.content_margin_top = 18
	t.set_stylebox("normal", "PrimaryButton", pn)
	t.set_stylebox("hover", "PrimaryButton", ph)
	t.set_stylebox("pressed", "PrimaryButton", pp)
	t.set_stylebox("hover_pressed", "PrimaryButton", pp)
	t.set_color("font_color", "PrimaryButton", Color(0.2, 0.08, 0.02))
	t.set_color("font_hover_color", "PrimaryButton", Color(0.15, 0.05, 0.0))
	t.set_color("font_pressed_color", "PrimaryButton", Color(0.15, 0.05, 0.0))
	t.set_font_size("font_size", "PrimaryButton", 32)
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, GOLD.darkened(0.35), 26, 3, 14, Vector2(32, 26)))
	t.set_stylebox("panel", "Panel", box(PANEL, GOLD.darkened(0.35), 26, 3, 14))
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", box(Color(0.06, 0.07, 0.13, 0.78), Color(1, 1, 1, 0.08), 18, 2, 4, Vector2(16, 6)))
	t.set_type_variation("TipPanel", "PanelContainer")
	t.set_stylebox("panel", "TipPanel", box(Color(0.06, 0.07, 0.13, 0.92), GOLD.darkened(0.3), 16, 2, 6, Vector2(16, 10)))
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
	return l


static func button(text: String, primary := false, min_width := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72 if primary else 64)
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", -4.0))
	return b


## Pops a control in (scale + fade).
static func pop_in(c: Control, delay := 0.0, duration := 0.35) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(0.85, 0.85)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_delay(delay)
