class_name SettingsPanel
extends Control
## Settings sheet (arsenal_design.md §7.2): sound and screen (music, sounds, vibration,
## graphics, language) kept on Save, and the gameplay settings of the account (Reduce Motion,
## Fast ceremonies, Quick reveal, Caches to Vault, Reinforcements) through Meta.set_setting().
## The version label exports the local telemetry after 7 taps (user://telemetry.json).

var hub: Hub
var _panel: PanelContainer
var _taps := 0


func setup(p_hub: Hub, _a: Variant = null) -> void:
	hub = p_hub


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(30, 28)))
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins := hub.insets()
	_panel.offset_left = 26 + ins.x
	_panel.offset_right = -26 - ins.z
	_panel.offset_top = ins.y + 70
	_panel.offset_bottom = -ins.w - 60
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var t := UIKit.gradient_heading(Loc.t("SETTINGS"), 50)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(UIKit.divider(500.0))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	sc.add_child(list)
	list.add_child(_header("SET_AUDIO"))
	list.add_child(_row("MUSIC", "music", func() -> bool: return Save.music_volume > 0.0, func(v: bool):
		Save.music_volume = 0.7 if v else 0.0
		_save_legacy()))
	list.add_child(_row("SOUND", "sound", func() -> bool: return Save.sfx_volume > 0.0, func(v: bool):
		Save.sfx_volume = 0.85 if v else 0.0
		_save_legacy()))
	list.add_child(_row("VIBRATION", "bolt", func() -> bool: return Save.vibration, func(v: bool):
		Save.vibration = v
		_save_legacy()))
	list.add_child(_row("GRAPHICS", "crystal", func() -> bool: return Save.quality == "high", func(v: bool):
		Save.quality = "high" if v else "low"
		_save_legacy(), "QUALITY_HIGH", "QUALITY_LOW"))
	var lang := _row("LANGUAGE", "globe", func() -> bool: return Loc.lang == "uk", func(_v: bool):
		hub.pop_modal()
		Loc.set_language(Loc.next_language()), "LANG_NAME", "LANG_NAME")
	list.add_child(lang)
	list.add_child(_header("SET_GAMEPLAY"))
	for row: Array in [["SET_REDUCE_MOTION", "reduce_motion", "wing"], ["SET_FAST_CEREMONIES", "fast_ceremonies", "fast"],
			["SET_QUICK_REVEAL", "quick_reveal", "cache_stone"], ["SET_CACHES_TO_VAULT", "caches_to_vault", "cache_world"],
			["SET_REINFORCEMENTS", "reinforcements", "plus"]]:
		var key := str(row[1])
		list.add_child(_row(str(row[0]), str(row[2]), func() -> bool: return bool(Meta.setting(key, key == "reinforcements")), func(v: bool):
			Meta.set_setting(key, v)))
	var ver := UIKit.label(Loc.f("VERSION", [str(ProjectSettings.get_setting("application/config/version", "1.0"))]), 20, UIKit.TEXT_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			_taps += 1
			if _taps >= 7:
				_taps = 0
				if Meta.export_telemetry() != "":
					hub.toast(Loc.t("TELEMETRY_SAVED"), "check"))
	col.add_child(ver)
	var close := UIKit.button(Loc.t("CLOSE"), true, 420.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): hub.pop_modal())
	col.add_child(close)
	UIJuice.pop(_panel, 0.0, UITokens.SLOW)


func play_exit() -> Tween:
	var tw := _panel.create_tween().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, UITokens.EXIT)
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.94, UITokens.EXIT)
	return tw


func _save_legacy() -> void:
	Save.apply_settings()
	Save.save_data()


func _header(key: String) -> Control:
	var l := UIKit.heading(Loc.t(key).to_upper(), 22, UIKit.GOLD, 5)
	l.custom_minimum_size.y = 40
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


## A settings row: icon, name, and a Toggle (or a gold value text when on_key/off_key are set;
## then a tap flips it).
func _row(key: String, icon: String, get_on: Callable, set_on: Callable, on_key := "", off_key := "") -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(16, 8)))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(Icons.make(icon, 38.0, UIKit.GOLD))
	var l := UIKit.heading(Loc.t(key), 26, UIKit.TEXT, 5)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if on_key != "":
		var val := UIKit.heading("", 24, UIKit.GOLD, 5)
		row.add_child(val)
		val.text = Loc.t(on_key if bool(get_on.call()) else off_key)
		p.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				Audio.play("click", -6.0)
				set_on.call(not bool(get_on.call()))
				if is_instance_valid(val):
					val.text = Loc.t(on_key if bool(get_on.call()) else off_key))
	else:
		var tg := Toggle.new()
		tg.on = bool(get_on.call())
		tg.custom_minimum_size = Vector2(86, 46)
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tg.toggled.connect(func(v: bool):
			Audio.play("click", -6.0)
			set_on.call(v))
		row.add_child(tg)
	return p


## Animated on/off switch (emerald when on).
class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var _k := -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e):
			on = not on
			UIJuice.haptic("CLICK", 0.4)
			toggled.emit(on)
			accept_event()

	func _process(delta: float) -> void:
		var t := 1.0 if on else 0.0
		if _k < 0.0:
			_k = t
			queue_redraw()
		if not is_equal_approx(_k, t):
			_k = move_toward(_k, t, delta * 7.0)
			queue_redraw()

	func _draw() -> void:
		var k := maxf(_k, 0.0)
		var r := Rect2(Vector2.ZERO, size)
		var rad := int(size.y * 0.5)
		draw_style_box(UIKit.box(Color(0, 0, 0.03, 0.5), Color(0, 0, 0, 0), rad, 0, 0, Vector2.ZERO), Rect2(r.position + Vector2(0, 3), r.size))
		var bg := Color(0.16, 0.18, 0.28).lerp(Color(0.22, 0.72, 0.36), k)
		draw_style_box(UIKit.box(bg, Color(1, 0.85, 0.5, 0.6), rad, 2, 0, Vector2.ZERO), r)
		var kr := size.y * 0.5 - 5.0
		var kc := Vector2(lerpf(size.y * 0.5, size.x - size.y * 0.5, k), size.y * 0.5)
		draw_circle(kc + Vector2(0, 2), kr, Color(0, 0, 0, 0.35))
		draw_circle(kc, kr, Color(0.98, 0.96, 0.9))
		draw_arc(kc, kr * 0.6, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.9), 2.0, true)
