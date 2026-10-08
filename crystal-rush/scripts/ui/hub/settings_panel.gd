class_name SettingsPanel
extends Control
## Settings (UI v2, Genshin settings rows): a cream modal with a quiet ink title and a close
## disc, engraved section titles, and flat rows (line icon in a thin gold ring, ink label, a
## chamfered toggle or a gold value) separated by hairlines - no boxes. Sound and screen
## (music, sounds, vibration, graphics, language) are kept on Save, the gameplay settings of
## the account (Reduce Motion, Fast ceremonies, Quick reveal, Caches to Vault,
## Reinforcements) through Meta.set_setting(). The version label exports the local telemetry
## after 7 taps (user://telemetry.json).

var hub: Hub
var _panel: PanelContainer
var _taps := 0
var _list: VBoxContainer
var _sc: ScrollContainer


func setup(p_hub: Hub, _a: Variant = null) -> void:
	hub = p_hub


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	UIKit.frost_into(_panel, "modal", Vector2(30, 24))
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins := hub.insets()
	_panel.offset_left = 28 + ins.x
	_panel.offset_right = -28 - ins.z
	_panel.offset_top = ins.y + 84
	_panel.offset_bottom = -ins.w - 84
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var t := UIKit.heading(Loc.t("SETTINGS"), 36, UIKit.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)
	var x := UIKit.edge_button("close", 26.0)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(func(): hub.close_modal(self))
	head.add_child(x)
	col.add_child(head)
	var div := UIKit.divider(560.0)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(div)
	var sc := ScrollContainer.new()
	_sc = sc
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	UIKit.scroll_fade(sc, Color("#F8F3E9"), 48.0, 18.0)
	var list := VBoxContainer.new()
	_list = list
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	sc.add_child(list)
	list.add_child(_header("SET_AUDIO"))
	list.add_child(_row("MUSIC", "music", func() -> bool: return Save.music_volume > 0.0, func(v: bool):
		Save.music_volume = 0.7 if v else 0.0
		_save_legacy()))
	list.add_child(_row("SOUND", "sound", func() -> bool: return Save.sfx_volume > 0.0, func(v: bool):
		Save.sfx_volume = 0.85 if v else 0.0
		_save_legacy()))
	list.add_child(_row("VIBRATION", "vibrate", func() -> bool: return Save.vibration, func(v: bool):
		Save.vibration = v
		_save_legacy()))
	list.add_child(_row("GRAPHICS", "settings", func() -> bool: return Save.quality == "high", func(v: bool):
		Save.quality = "high" if v else "low"
		_save_legacy(), "QUALITY_HIGH", "QUALITY_LOW"))
	list.add_child(_row("LANGUAGE", "globe", func() -> bool: return Loc.lang == "uk", func(_v: bool):
		hub.pop_modal()
		Loc.set_language(Loc.next_language()), "LANG_NAME", "LANG_NAME"))
	list.add_child(_header("SET_GAMEPLAY"))
	for row: Array in [["SET_REDUCE_MOTION", "reduce_motion", "pause"], ["SET_FAST_CEREMONIES", "fast_ceremonies", "fast"],
			["SET_QUICK_REVEAL", "quick_reveal", "chest"], ["SET_CACHES_TO_VAULT", "caches_to_vault", "gift"],
			["SET_REINFORCEMENTS", "reinforcements", "team"]]:
		var key := str(row[1])
		list.add_child(_row(str(row[0]), str(row[2]), func() -> bool: return bool(Meta.setting(key, key == "reinforcements")), func(v: bool):
			Meta.set_setting(key, v)))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	var ver := UIKit.label(Loc.f("VERSION", [str(ProjectSettings.get_setting("application/config/version", "1.0"))]), 18, UITokens.INK_SOFT)
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			_taps += 1
			if _taps >= 7:
				_taps = 0
				if Meta.export_telemetry() != "":
					hub.toast(Loc.t("TELEMETRY_SAVED"), "check"))
	foot.add_child(ver)
	var close := UIKit.secondary_button(Loc.t("CLOSE"), "", Vector2(240, 68), 24)
	close.pressed.connect(func(): hub.close_modal(self))
	foot.add_child(close)
	col.add_child(foot)
	_fit_height()
	UIJuice.soft_in(_panel, Vector2(0, 28))


## Sized to its content and centred (tall phones get no empty cream inside the modal); it
## scrolls only when the content is taller than the screen allows.
func _fit_height() -> void:
	var ins := hub.insets()
	var vp := get_viewport_rect().size
	# The modal sits between the top bar and the nav's rising medallion (never over it); when
	# the content is taller it may cover the top bar, still clear of the medallion.
	var lo := vp.y - ins.w - UITokens.TAB_BAR_H - 56.0
	var hi := ins.y + 84.0
	var avail := lo - hi
	# Measured from the rows themselves (an autowrapped label can report a huge minimum height
	# before its first layout): section headers ~50 px, rows ROW_H + 4 plus the hairline.
	var list_h := 0.0
	for c in _list.get_children():
		list_h += 50.0 if c is MarginContainer else UITokens.ROW_H + 6.0
	var chrome := 36.0 + 10.0 + 18.0 + 10.0 + 76.0 + 10.0 * 2.0 + 48.0
	var h := minf(list_h + chrome, avail)
	_sc.custom_minimum_size.y = maxf(120.0, h - chrome)
	if list_h + chrome > avail:
		hi = ins.y + 24.0
		avail = lo - hi
		h = minf(list_h + chrome, avail)
		_sc.custom_minimum_size.y = maxf(120.0, h - chrome)
	var top := hi + (avail - h) * 0.5
	_panel.offset_top = top
	_panel.offset_bottom = -(vp.y - top - h)


func play_exit() -> Tween:
	return UIJuice.soft_out(_panel, Vector2(0, 20))


func _save_legacy() -> void:
	Save.apply_settings()
	Save.save_data()


func _header(key: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 4)
	m.add_child(UIKit.section(Loc.t(key)))
	return m


## A settings row: a line icon in a thin gold ring, the ink label, and a chamfered Toggle (or a
## gold value + chevron when on_key / off_key are set; then a tap flips it). Hairline under it.
func _row(key: String, icon: String, get_on: Callable, set_on: Callable, on_key := "", off_key := "") -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = UITokens.ROW_H + 4.0
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(row)
	var ic := UIKit.socket(icon, 42.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := UIKit.label(Loc.t(key), 24, UIKit.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	if on_key != "":
		var val := UIKit.label("", 22, UITokens.GOLD_TEXT, true)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val)
		var chev := Icons.make("chevron", 22.0, UITokens.GOLD_TEXT)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chev)
		val.text = Loc.t(on_key if bool(get_on.call()) else off_key)
		row.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				Audio.play("click", -6.0)
				UIJuice.haptic("CLICK", 0.4)
				set_on.call(not bool(get_on.call()))
				if is_instance_valid(val):
					val.text = Loc.t(on_key if bool(get_on.call()) else off_key))
	else:
		var tg := Toggle.new()
		tg.on = bool(get_on.call())
		tg.custom_minimum_size = Vector2(78, 40)
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tg.toggled.connect(func(v: bool):
			Audio.play("click", -6.0)
			set_on.call(v))
		row.add_child(tg)
		# The whole row flips the toggle (a bigger target than the switch).
		row.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e) and is_instance_valid(tg):
				tg.flip())
	wrap.add_child(UIKit.hairline())
	return wrap


## Chamfered on/off switch (UI v2): a cream track with a gold hairline (off) that fills with the
## amber CTA gradient (on); a porcelain knob with a hairline and a soft shadow glides across.
class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var _k := -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func flip() -> void:
		on = not on
		UIJuice.haptic("CLICK", 0.4)
		toggled.emit(on)

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e):
			flip()
			accept_event()

	func _process(delta: float) -> void:
		var t := 1.0 if on else 0.0
		if _k < 0.0:
			_k = t
			queue_redraw()
		if not is_equal_approx(_k, t):
			_k = move_toward(_k, t, delta / 0.16)
			queue_redraw()

	func _draw() -> void:
		var k := ease(maxf(_k, 0.0), -1.8)
		var r := Rect2(Vector2(0, 2), Vector2(size.x, size.y - 4))
		var ch := r.size.y * 0.32
		var track := GemDraw.chamfer_rect(r, ch)
		draw_colored_polygon(track, UITokens.PAPER_3)
		if k > 0.01:
			# Amber fill grows from the left with the knob.
			var fr := Rect2(r.position, Vector2(lerpf(r.size.y, r.size.x, k), r.size.y))
			var fill := GemDraw.chamfer_rect(fr, ch)
			var cols := PackedColorArray()
			for p in fill:
				var ty := (p.y - fr.position.y) / fr.size.y
				cols.append(UITokens.CTA_HI.lerp(UITokens.CTA, smoothstep(0.0, 0.5, ty)).lerp(UITokens.CTA_LO, smoothstep(0.5, 1.0, ty)))
			draw_polygon(fill, cols)
		GemDraw.outline(self, track, UITokens.HAIRLINE, 1.5)
		var kr := r.size.y * 0.5 - 4.0
		var kc := Vector2(lerpf(r.position.x + r.size.y * 0.5, r.end.x - r.size.y * 0.5, k), r.get_center().y)
		var sc := UITokens.SCRIM
		draw_circle(kc + Vector2(0, 2), kr + 1.0, Color(sc.r, sc.g, sc.b, 0.18))
		draw_circle(kc, kr, UITokens.PAPER_0)
		draw_arc(kc, kr - 0.6, 0, TAU, 32, UITokens.HAIRLINE, 1.2, true)
		draw_arc(kc, kr * 0.62, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.9), 1.5, true)
