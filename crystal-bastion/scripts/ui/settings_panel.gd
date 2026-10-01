class_name SettingsPanel
extends VBoxContainer
## Volume, language, graphics and progress settings.

signal closed

var _reset_armed := false
var _reset_btn: Button
var _lang_btn: Button
var _quality_btn: Button
var _damage_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size.x = 560
	var title := UIKit.label(Loc.t("SETTINGS"), 44, UIKit.GOLD, true, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	add_child(_slider_row("music", Loc.t("MUSIC"), Save.music_volume, _on_music))
	add_child(_slider_row("sound", Loc.t("SOUNDS"), Save.sfx_volume, _on_sfx))
	_lang_btn = _toggle_row("globe", Loc.t("LANGUAGE"), Loc.t("LANG_NAME"), _on_lang)
	_quality_btn = _toggle_row("gear", Loc.t("GRAPHICS"), Loc.t("QUALITY_HIGH") if Save.quality == "high" else Loc.t("QUALITY_LOW"), _on_quality)
	_damage_btn = _toggle_row("target", Loc.t("DAMAGE_NUMBERS"), Loc.t("ON") if Save.show_damage else Loc.t("OFF"), _on_damage)
	_reset_btn = UIKit.button(Loc.t("RESET_PROGRESS"), false, 300)
	_reset_btn.add_theme_color_override("font_color", UIKit.RED)
	_reset_btn.pressed.connect(_on_reset)
	add_child(_reset_btn)
	var close := UIKit.button(Loc.t("CLOSE"), true, 300)
	close.pressed.connect(_on_close)
	add_child(close)
	_reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _slider_row(icon: String, text: String, value: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(Icons.make(icon, 34, UIKit.GOLD))
	var l := UIKit.label(text, 26)
	l.custom_minimum_size.x = 170
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	s.drag_ended.connect(func(_c: bool): Save.save_data())
	h.add_child(s)
	return h


func _toggle_row(icon: String, text: String, value: String, cb: Callable) -> Button:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(Icons.make(icon, 34, UIKit.GOLD))
	var l := UIKit.label(text, 26)
	l.custom_minimum_size.x = 170
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := UIKit.button(value, false, 250)
	b.custom_minimum_size.y = 56
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	h.add_child(b)
	add_child(h)
	return b


func _on_music(v: float) -> void:
	Save.music_volume = v
	Audio.apply_volumes()


func _on_sfx(v: float) -> void:
	Save.sfx_volume = v
	Audio.apply_volumes()
	Audio.play("coin", -6.0)


func _on_lang() -> void:
	Loc.set_language(Loc.next_language())
	# Rebuild with the new language.
	for c in get_children():
		c.queue_free()
	_ready()


func _on_quality() -> void:
	Save.quality = "low" if Save.quality == "high" else "high"
	_quality_btn.text = Loc.t("QUALITY_HIGH") if Save.quality == "high" else Loc.t("QUALITY_LOW")
	Save.apply_settings()


func _on_damage() -> void:
	Save.show_damage = not Save.show_damage
	_damage_btn.text = Loc.t("ON") if Save.show_damage else Loc.t("OFF")
	Save.apply_settings()


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = Loc.t("RESET_CONFIRM")
		return
	Save.reset_progress()
	_reset_btn.text = Loc.t("RESET_DONE")
	_reset_btn.disabled = true


func _on_close() -> void:
	Save.save_data()
	closed.emit()
