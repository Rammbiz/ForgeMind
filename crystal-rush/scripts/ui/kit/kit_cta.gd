class_name KitCTA
extends Button
## The amber jewel CTA (UI v2): amber gradient body with a fine rim (lux "primary"), a cut topaz
## in a gold bezel at the left end, deep amber-brown ExtraBold label with a light emboss (no
## stroke, ~5:1), an optional second line, a light sweep every UITokens.CTA_SWEEP_EVERY seconds and
## a juicy press (squash 0.97 + topaz flash). Only for key actions: ГРАТИ, Призвати,
## Покращити, Забрати, Далі.
## Bitmap overrides: assets/ui/kit/primary*.png (body), cta_topaz.png (the gem).
## `text` / `icon` work like a normal Button (the Button's own text is hidden and redrawn).

var sub := "":
	set(v):
		sub = v
		queue_redraw()
var label_size := 40:
	set(v):
		label_size = v
		add_theme_font_size_override("font_size", v)
		queue_redraw()
var sub_size := 20
var topaz := true:
	set(v):
		topaz = v
		_apply_pad()
		queue_redraw()
var sweep := true
var _flash := 0.0
var _sweep_rect: ColorRect
var _sweep_mat: ShaderMaterial


func _init() -> void:
	theme_type_variation = "PrimaryButton"
	focus_mode = Control.FOCUS_NONE
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(k, Color(0, 0, 0, 0))
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		add_theme_color_override(k, Color(0, 0, 0, 0))
	add_theme_constant_override("outline_size", 0)
	add_theme_font_override("font", UIKit.font_w("extrabold"))
	pressed.connect(func(): Audio.play("click", -4.0))
	button_down.connect(_down)
	button_up.connect(_up)


func _ready() -> void:
	_apply_pad()
	if sweep and not UITokens.reduce_motion():
		_sweep_rect = ColorRect.new()
		_sweep_rect.color = Color.WHITE
		_sweep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sweep_mat = ShaderMaterial.new()
		_sweep_mat.shader = load(UIKit.SHINE_SHADER_PATH) as Shader
		_sweep_mat.set_shader_parameter("chamfer", 12.0)
		_sweep_mat.set_shader_parameter("strength", 0.26)
		_sweep_rect.material = _sweep_mat
		_sweep_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_sweep_rect)
		_sweep_rect.resized.connect(func(): _sweep_mat.set_shader_parameter("rect_size", _sweep_rect.size))
		var tw := _sweep_rect.create_tween().set_loops()
		tw.tween_interval(1.2)
		tw.tween_method(func(v: float): _sweep_mat.set_shader_parameter("progress", v if not disabled else -1.0), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func(): _sweep_mat.set_shader_parameter("progress", -1.0))
		tw.tween_interval(maxf(0.1, UITokens.CTA_SWEEP_EVERY - 2.2))


func _apply_pad() -> void:
	# Hidden Button text still sizes the control; keep room for the topaz on the left.
	if topaz and custom_minimum_size.x < 200.0:
		custom_minimum_size.x = 200.0


func _gem_zone() -> float:
	if not topaz:
		return 0.0
	return clampf(size.y * 0.62, 36.0, 76.0) + 16.0


func _down() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.97, 0.97), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash = 1.0
	UIJuice.haptic("CLICK", 0.6)


func _up() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.02, 1.02), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var down := is_pressed() and not disabled
	var dy := 2.0 if down else 0.0
	var h := size.y
	var dis := disabled
	var gem_w := _gem_zone()
	# Topaz in a gold bezel at the left end.
	if topaz and gem_w > 0.0:
		var gs := clampf(h * 0.62, 36.0, 76.0)
		var gc := Vector2(14.0 + gs * 0.5 * 0.74 + 4.0, h * 0.5 + dy - 1.0)
		var tex := UIKit.kit_texture("cta_topaz")
		if tex:
			var ts := Vector2(gs, gs) * Vector2(float(tex.get_width()) / maxf(1.0, float(tex.get_height())), 1.0)
			draw_texture_rect(tex, Rect2(gc - ts * 0.5, ts), false, Color(1, 1, 1, 0.55 if dis else 1.0))
		else:
			# Bezel: a thin dark-gold seat with a light rim, then the cut topaz.
			var bez := GemDraw.cut_points("cushion", gc, gs * 1.14)
			draw_colored_polygon(bez, Color("#B9772A") if not dis else Color("#B8AA92"))
			GemDraw.outline(self, bez, Color(1.0, 0.93, 0.74, 0.9) if not dis else Color(1, 1, 1, 0.5), 1.2)
			if dis:
				GemDraw.draw_gem(self, "cushion", gc, gs, Color("#D9CDB8"), Color("#F2EDE4"), Color("#AFA28B"), false)
			else:
				GemDraw.draw_gem(self, "cushion", gc, gs, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"), true)
		if _flash > 0.0:
			var fr := gs * (0.9 + 0.8 * (1.0 - _flash))
			draw_texture_rect(UIKit.glow_texture(), Rect2(gc - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 0.95, 0.75, _flash * 0.9))
	# Label (+ optional icon and second line), centred in the area right of the gem.
	if text == "" and sub == "":
		return
	var f := UIKit.font_w("extrabold")
	var fs := label_size
	var area_x0 := gem_w + (6.0 if topaz else 18.0)
	var area_x1 := size.x - (22.0 if topaz else 18.0)
	var avail := area_x1 - area_x0
	var ico_w := 0.0
	if icon:
		ico_w = fs * 0.9 + 8.0
	while fs > 18 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + ico_w > avail:
		fs -= 1
		ico_w = (fs * 0.9 + 8.0) if icon else 0.0
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := tw + ico_w
	var x := area_x0 + (avail - total) * 0.5
	var fsub := UIKit.font_w("bold")
	var has_sub := sub != ""
	var asc := f.get_ascent(fs)
	var desc := f.get_descent(fs)
	var line_h := asc + desc
	var sub_h := (fsub.get_ascent(sub_size) + fsub.get_descent(sub_size) - 2.0) if has_sub else 0.0
	var block := line_h * 0.86 + sub_h
	var top := (h - block) * 0.5 + dy - 1.0
	var base_y := top + asc * 0.93
	var col := UIKit.CTA_TEXT if not dis else UIKit.INK_DIM
	if icon:
		var isz := fs * 0.9
		draw_texture_rect(icon, Rect2(Vector2(x, base_y - asc * 0.78), Vector2(isz, isz)), false, Color(1, 1, 1, 0.6 if dis else 1.0))
		x += ico_w
	if not dis:
		# Engraved ink: a 1 px light emboss under the deep amber-brown label (no stroke, ~5:1).
		draw_string(f, Vector2(x, base_y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.902, 0.639, 0.5))
	draw_string(f, Vector2(x, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if has_sub:
		var sw := fsub.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
		var sx := area_x0 + (avail - sw) * 0.5
		var sy := base_y + desc + fsub.get_ascent(sub_size) - 2.0
		if not dis:
			draw_string(fsub, Vector2(sx, sy + 1.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(1.0, 0.902, 0.639, 0.4))
		draw_string(fsub, Vector2(sx, sy), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color("#6E3A0F") if not dis else UIKit.INK_DIM)
