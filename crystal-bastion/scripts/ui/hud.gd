class_name Hud
extends CanvasLayer
## In-game interface: resources bar, wave button, radial menus, banners, pause & results.

var game: Game
var root: Control
var overlay: WorldOverlay
var _catcher: Control
var _lives_label: Label
var _gold_label: Label
var _wave_label: Label
var _wave_btn: RoundButton
var _wave_hint: Label
var _speed_btn: RoundButton
var _pause_btn: RoundButton
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _toast: Label
var _toast_tween: Tween
var _hint: PanelContainer
var _vignette: ColorRect
var _menu: Control
var _modal: Control
var _modal_kind := ""          # "pause", "settings" or "result"
var _hint_label: Label
var _safe_check := 0.0
var _last_safe_area := Rect2i()
var _icons := {}
var _press_pos := Vector2.ZERO
var _last_drag := Vector2.ZERO
var _dragging := false
var _pressing := false
var _touches := {}
var _pinch_dist := 0.0
var _pinching := false
var _suppress_tap := false   # the gesture became a pinch: its final release is not a tap
var _gold_shown := 0.0
var _preview: VBoxContainer
var _preview_key := ""
var _enemy_icons := {}
var _hero_btns := {}           # Hero -> RoundButton (portrait: select, ring = health)
var _ability_btns := {}        # Hero -> RoundButton (super ability, ring = cooldown)
var _ult_btns := {}            # Hero -> RoundButton (ultimate, ring = charge)
var _hero_icons := {}


func bind(g: Game) -> void:
	game = g
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_catcher()
	overlay = WorldOverlay.new()
	overlay.game = game
	root.add_child(overlay)
	_build_vignette()
	_build_top_bar()
	_build_controls()
	_build_hero_bar()
	_build_banner()
	_build_toast()
	_build_hint()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	Loc.language_changed.connect(_on_language_changed)
	game.gold_changed.connect(_on_gold_changed)
	game.lives_changed.connect(_on_lives_changed)
	game.wave_changed.connect(_on_wave_changed)
	_gold_shown = game.gold
	_lives_label.text = str(game.lives)
	_wave_label.text = Loc.f("WAVE_FMT", [0, game.waves.size()])
	_render_tower_icons()


func _on_gold_changed(_v: int) -> void:
	_pulse(_gold_label)


func _on_lives_changed(v: int) -> void:
	_lives_label.text = str(v)
	_pulse(_lives_label, UIKit.RED)


func _on_wave_changed(c: int, t: int) -> void:
	_wave_label.text = Loc.f("WAVE_FMT", [c, t])
	_pulse(_wave_label)


# ------------------------------------------------------------------ layout pieces

func _build_catcher() -> void:
	_catcher = Control.new()
	_catcher.name = "InputCatcher"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_world_input)
	root.add_child(_catcher)


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float v = smoothstep(0.55, 1.35, length(p * vec2(0.85, 1.0)));
	COLOR = vec4(0.9, 0.05, 0.1, v * amount);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vignette.material = m
	root.add_child(_vignette)


func _resource_chip(icon: String, text: String) -> Array:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "HudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	h.add_child(Icons.make(icon, 34))
	var l := UIKit.label(text, 30, UIKit.TEXT, true, 6)
	l.custom_minimum_size.x = 56
	h.add_child(l)
	return [panel, l]


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.add_theme_constant_override("separation", 10)
	bar.position = Vector2(14, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var lives := _resource_chip("heart", "20")
	bar.add_child(lives[0])
	_lives_label = lives[1]
	var gold := _resource_chip("coin", "0")
	bar.add_child(gold[0])
	_gold_label = gold[1]
	_gold_label.custom_minimum_size.x = 80
	var wave := _resource_chip("skull", "")
	bar.add_child(wave[0])
	_wave_label = wave[1]
	_wave_label.add_theme_font_size_override("font_size", 26)
	_wave_label.custom_minimum_size.x = 150


func _build_controls() -> void:
	_pause_btn = RoundButton.new(32.0)
	_pause_btn.icon_kind = "pause"
	_pause_btn.ring_color = Color(1, 1, 1, 0.5)
	_pause_btn.pressed.connect(open_pause)
	root.add_child(_pause_btn)
	_speed_btn = RoundButton.new(32.0)
	_speed_btn.icon_kind = "fast"
	_speed_btn.ring_color = Color(1, 1, 1, 0.5)
	_speed_btn.badge = "x1"
	_speed_btn.pressed.connect(_on_speed)
	root.add_child(_speed_btn)
	_wave_btn = RoundButton.new(52.0)
	_wave_btn.icon_kind = "swords"
	_wave_btn.base_color = Color(0.45, 0.12, 0.14, 0.95)
	_wave_btn.ring_color = UIKit.GOLD
	_wave_btn.pulse = true
	_wave_btn.caption = Loc.t("START")
	_wave_btn.pressed.connect(_on_wave_pressed)
	root.add_child(_wave_btn)
	_wave_hint = UIKit.label("", 22, UIKit.GOLD, true, 6)
	_wave_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wave_hint)
	_preview = VBoxContainer.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_theme_constant_override("separation", 6)
	_preview.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_preview)


func _build_hero_bar() -> void:
	for h: Hero in game.heroes:
		var b := RoundButton.new(36.0)
		b.base_color = Color(0.08, 0.1, 0.18, 0.92)
		b.ring_color = h.color
		b.progress_color = UIKit.GREEN
		b.pressed.connect(_on_hero_pressed.bind(h))
		root.add_child(b)
		_hero_btns[h] = b
		var a := RoundButton.new(26.0)
		a.icon_kind = str(h.ability["icon"])
		a.icon_tint = h.color.lightened(0.45)
		a.base_color = h.color.darkened(0.65)
		a.ring_color = UIKit.GOLD
		a.progress_color = h.color.lightened(0.3)
		a.pressed.connect(_on_ability_pressed.bind(h))
		root.add_child(a)
		_ability_btns[h] = a
		var u := RoundButton.new(26.0)
		u.icon_kind = str(h.ult["icon"])
		u.icon_tint = Color(1.0, 0.9, 0.55)
		u.base_color = Color(0.22, 0.08, 0.3, 0.95)
		u.ring_color = Color(1.0, 0.55, 0.95)
		u.progress_color = Color(1.0, 0.6, 0.95)
		u.pressed.connect(_on_ult_pressed.bind(h))
		root.add_child(u)
		_ult_btns[h] = u


func _on_hero_pressed(h: Hero) -> void:
	_hide_hint()
	if game.selected_hero == h:
		game.deselect_hero()
	elif h.alive:
		game.select_hero(h)
	else:
		toast(Loc.f("HERO_RESPAWN", [Loc.t(h.def["name"]), int(ceil(h.respawn_left))]), h.color.lightened(0.3))
		Audio.play("error")


func _on_ability_pressed(h: Hero) -> void:
	_hide_hint()
	game.use_hero_ability(h)


func _on_ult_pressed(h: Hero) -> void:
	_hide_hint()
	game.use_hero_ult(h)


func _update_hero_bar() -> void:
	for h: Hero in _hero_btns:
		var b: RoundButton = _hero_btns[h]
		var a: RoundButton = _ability_btns[h]
		var tex: Texture2D = _hero_icons.get(h.type, null)
		b.icon_texture = tex
		if tex == null:
			b.icon_kind = "star"
		b.icon_tint = Color.WHITE if tex else h.color
		b.highlight = h.selected
		if h.alive:
			var ratio := clampf(h.hp / h.max_hp, 0.0, 1.0)
			b.progress = ratio
			b.progress_color = UIKit.GREEN.lerp(UIKit.RED, clampf((0.6 - ratio) / 0.5, 0.0, 1.0))
			b.caption = ""
			b.disabled = false
		else:
			b.progress = 1.0 - h.respawn_left / float(h.def["respawn"])
			b.progress_color = Color(0.6, 0.62, 0.7)
			b.caption = "%d" % int(ceil(h.respawn_left))
			b.disabled = true
		var cd := float(h.ability["cooldown"])
		a.disabled = not h.can_use_ability()
		a.progress = 1.0 - h.cooldown / cd if h.cooldown > 0.0 else -1.0
		a.pulse = h.can_use_ability()
		var u: RoundButton = _ult_btns[h]
		var ucd := float(h.ult["cooldown"])
		u.disabled = not h.can_use_ult()
		u.progress = 1.0 - h.ult_cooldown / ucd if h.ult_cooldown > 0.0 else -1.0
		u.highlight = h.can_use_ult()
		var running := game.is_running()
		b.visible = running
		a.visible = running
		u.visible = running


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_title = UIKit.label("", 64, UIKit.GOLD, true, 12)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub = UIKit.label("", 30, UIKit.TEXT, true, 8)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_sub)
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _build_toast() -> void:
	_toast = UIKit.label("", 28, UIKit.RED, true, 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.theme_type_variation = "TipPanel"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = UIKit.label(_hint_text(), 22, UIKit.TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(_hint_label)
	root.add_child(_hint)
	if game.level_index > 0:
		_hint.visible = false


func _on_language_changed() -> void:
	_wave_label.text = Loc.f("WAVE_FMT", [game.wave, game.waves.size()])
	_hint_label.text = _hint_text()
	_preview_key = ""


var _safe := Rect2()
func _apply_safe_area() -> void:
	_last_safe_area = DisplayServer.get_display_safe_area()
	var vp := root.get_viewport_rect().size
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(Vector2.ZERO, vp)
	if OS.has_feature("mobile") and screen.x > 0 and screen.y > 0:
		var sa := Rect2(DisplayServer.get_display_safe_area())
		var k := vp / screen
		safe = Rect2(sa.position * k, sa.size * k)
	_safe = safe
	var bar := root.get_node("TopBar") as Control
	bar.position = safe.position + Vector2(14, 12)


func _layout_controls() -> void:
	var vp := root.get_viewport_rect().size
	var right := minf(_safe.end.x, vp.x) if _safe.size.x > 0 else vp.x
	var bottom := minf(_safe.end.y, vp.y) if _safe.size.y > 0 else vp.y
	var top := _safe.position.y
	_pause_btn.position = Vector2(right - 88, top + 6)
	_speed_btn.position = Vector2(right - 170, top + 6)
	_wave_btn.position = Vector2(right - 140, bottom - 166)
	_preview.reset_size()
	_preview.position = Vector2(right - 150 - _preview.size.x, bottom - 50 - _preview.size.y)
	_wave_hint.reset_size()
	_wave_hint.position = Vector2(right - 84 - _wave_hint.size.x * 0.5, bottom - 196)
	_banner.reset_size()
	_banner.position = Vector2((vp.x - _banner.size.x) * 0.5, vp.y * 0.16)
	_toast.reset_size()
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y * 0.72)
	_hint.reset_size()
	_hint.position = Vector2((vp.x - _hint.size.x) * 0.5, bottom - _hint.size.y - 18)
	var left := _safe.position.x
	var i := 0
	for h: Hero in _hero_btns:
		var b: RoundButton = _hero_btns[h]
		var a: RoundButton = _ability_btns[h]
		var x := left + 14.0 + i * 150.0
		b.position = Vector2(x, bottom - 118)
		a.position = Vector2(x + 84.0, bottom - 70)
		# Far enough above the ability that the two touch circles (radius + 10) never overlap.
		(_ult_btns[h] as RoundButton).position = Vector2(x + 84.0, bottom - 146)
		i += 1


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if game == null:
		return
	# A 180° flip (sensor landscape) moves the notch without resizing the viewport.
	_safe_check -= delta
	if _safe_check <= 0.0:
		_safe_check = 0.5
		if OS.has_feature("mobile") and DisplayServer.get_display_safe_area() != _last_safe_area:
			_apply_safe_area()
	_layout_controls()
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_gold_shown = move_toward(_gold_shown, game.gold, maxf(absf(game.gold - _gold_shown) * real_delta * 8.0, real_delta * 30.0))
	_gold_label.text = str(int(round(_gold_shown)))
	# Wave button state.
	var can := game.can_call_wave()
	_wave_btn.disabled = not can
	if game.wave == 0:
		_wave_btn.caption = Loc.t("START")
		_wave_btn.progress = -1.0
		_wave_btn.pulse = true
		_wave_hint.text = ""
	elif can:
		var secs := int(ceil(game.next_wave_timer))
		_wave_btn.caption = "%d" % secs
		_wave_btn.progress = game.next_wave_timer / Game.WAVE_COUNTDOWN
		_wave_btn.pulse = false
		var bonus := GameData.wave_bonus(game.wave - 1) + secs
		_wave_hint.text = "+%d" % bonus
	else:
		_wave_btn.caption = "%d/%d" % [game.wave, game.waves.size()]
		_wave_btn.progress = -1.0
		_wave_btn.pulse = false
		_wave_hint.text = ""
	_wave_btn.visible = game.is_running() and game.wave < game.waves.size()
	_update_preview(can)
	_update_hero_bar()


## Shows the composition of the next wave next to the wave button.
func _update_preview(can_call: bool) -> void:
	var show := can_call and game.wave < game.waves.size() and _modal == null
	var key := "%d|%s|%d" % [game.wave, show, _enemy_icons.size()]
	if key == _preview_key:
		return
	_preview_key = key
	for c in _preview.get_children():
		c.queue_free()
	_preview.visible = show
	if not show:
		return
	var counts := {}
	var order: Array[String] = []
	for g: Array in game.waves[game.wave]:
		var t: String = g[0]
		if not counts.has(t):
			order.append(t)
			counts[t] = 0
		counts[t] += int(g[1])
	for t in order:
		var chip := PanelContainer.new()
		chip.theme_type_variation = "HudPanel"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		chip.add_child(h)
		var tex: Texture2D = _enemy_icons.get(t, null)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(40, 40)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.add_child(tr)
		else:
			var dot := Icons.make("skull", 32, GameData.ENEMIES[t]["color"])
			h.add_child(dot)
		var def: Dictionary = GameData.ENEMIES[t]
		if def.get("flying", false):
			h.add_child(Icons.make("wing", 24, Color(0.8, 0.85, 1.0)))
		if def.get("boss", false):
			h.add_child(Icons.make("skull", 24, UIKit.RED))
		var l := UIKit.label("×%d" % counts[t], 24, UIKit.TEXT, true, 5)
		h.add_child(l)
		_preview.add_child(chip)


func _pulse(l: Label, flash := UIKit.GOLD) -> void:
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	l.scale = Vector2(1.25, 1.25)
	l.add_theme_color_override("font_color", flash)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): l.add_theme_color_override("font_color", UIKit.TEXT))


# ------------------------------------------------------------------ input

func _on_world_input(event: InputEvent) -> void:
	if _modal:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			game.cam.zoom_by(0.9)
			close_menus()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			game.cam.zoom_by(1.1)
			close_menus()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
				_last_drag = mb.position
				_suppress_tap = _touches.size() > 1
			else:
				if _pressing and not _dragging and not _pinching and not _suppress_tap:
					_hide_hint()
					game.world_tap(mb.position)
				_pressing = false
				_dragging = false
	elif event is InputEventMouseMotion and _pressing and not _pinching:
		var mm := event as InputEventMouseMotion
		if not _dragging and mm.position.distance_to(_press_pos) > 18.0:
			_dragging = true
			_last_drag = mm.position
			close_menus()
		if _dragging:
			game.cam.pan_screen(_last_drag, mm.position)
			_last_drag = mm.position


func _input(event: InputEvent) -> void:
	# Two-finger pinch zoom (raw touch events).
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() >= 2:
			_pinching = true
			_suppress_tap = true
			_pinch_dist = _touch_spread()
			close_menus()
		elif _touches.is_empty():
			_pinching = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_dist > 0.0 and _modal == null:
			var d := _touch_spread()
			if d > 1.0:
				game.cam.zoom_by(_pinch_dist / d)
				_pinch_dist = d


func _touch_spread() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Phone call / app switch: never let the horde run unattended.
		if game and game.is_running() and _modal == null and game.wave > 0 and OS.has_feature("mobile"):
			open_pause()


func _on_back() -> void:
	if game.selected_hero:
		game.deselect_hero()
	elif _menu:
		close_menus()
	elif _modal and _modal_kind == "settings":
		_back_to_pause()
	elif _modal and game.is_running():
		_resume()
	elif game.is_running():
		open_pause()


func _on_speed() -> void:
	var s := game.speed % 3 + 1
	game.set_speed(s)
	_speed_btn.badge = "x%d" % s
	Audio.play("click", -4.0)


func _on_wave_pressed() -> void:
	if not game.can_call_wave():
		Audio.play("error")
		return
	_hide_hint()
	close_menus()
	game.start_next_wave()


func _hint_text() -> String:
	return Loc.t("HINT_BUILD") + "\n" + Loc.t("HINT_HEROES") + "\n" + Loc.t("HINT_START")


func _hide_hint() -> void:
	if _hint.visible:
		var tw := _hint.create_tween()
		tw.tween_property(_hint, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _hint.visible = false)


# ------------------------------------------------------------------ menus

func open_build_menu(c: Vector2i) -> void:
	close_menus()
	var m := BuildMenu.new()
	root.add_child(m)
	m.open(self, c)
	_menu = m


func open_tower_panel(t: Tower) -> void:
	close_menus()
	var p := TowerPanel.new()
	root.add_child(p)
	p.open(self, t)
	_menu = p


func close_menus() -> void:
	if _menu and is_instance_valid(_menu):
		_menu.call("close")
	_menu = null
	if game:
		game.clear_selection()


# ------------------------------------------------------------------ feedback

func float_text(world_pos: Vector3, text: String, color: Color, life := 1.0, big := false) -> void:
	overlay.add_text(world_pos, text, color, life, big)


func float_text_screen(screen_pos: Vector2, text: String, color: Color) -> void:
	overlay.add_screen_text(screen_pos, text, color)


func next_wave_center() -> Vector2:
	return _wave_btn.position + Vector2(_wave_btn.size.x * 0.5, -10)


func show_banner(title: String, sub := "") -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	_banner.reset_size()
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.8, 0.8)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_tween = _banner.create_tween()
	_banner_tween.set_ignore_time_scale(true)
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(1.4)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


func toast(text: String, color := UIKit.RED, hold := 1.0) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = _toast.create_tween()
	_toast_tween.set_ignore_time_scale(true)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## Fades the toast out early, but only if it still shows `text` (so newer messages stay).
func hide_toast_text(text: String) -> void:
	if text == "" or _toast.text != text or _toast.modulate.a <= 0.0:
		return
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = _toast.create_tween()
	_toast_tween.set_ignore_time_scale(true)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.15)


func damage_flash() -> void:
	var m := _vignette.material as ShaderMaterial
	var tw := _vignette.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(func(v: float): m.set_shader_parameter("amount", v), 0.85, 0.0, 0.6)


# ------------------------------------------------------------------ tower icons

func tower_icon(type: String) -> Texture2D:
	return _icons.get(type, null)


func _render_tower_icons() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vps := {}
	for type: String in GameData.TOWER_ORDER:
		var vp := _icon_viewport(160)
		var model := Models.tower(type, 1)
		model.rotation_degrees.y = -30.0
		vp.add_child(model)
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		cam.look_at_from_position(Vector3(0, 1.75, 2.9), Vector3(0, 0.55, 0))
		vps[type] = vp
	for etype: String in GameData.ENEMIES:
		var def: Dictionary = GameData.ENEMIES[etype]
		var size: float = def["size"]
		var vp2 := _icon_viewport(96)
		var em := Models.enemy(etype, def["color"], size)
		em.rotation_degrees.y = 35.0
		vp2.add_child(em)
		var cam2 := Camera3D.new()
		cam2.fov = 30.0
		vp2.add_child(cam2)
		var h := size * (1.2 if etype != "golem" else 2.2)
		cam2.look_at_from_position(Vector3(0, h + size * 1.6 + 0.2, size * 4.2 + 0.5), Vector3(0, h * 0.55, 0))
		vps["enemy:" + etype] = vp2
	for htype: String in GameData.HERO_ORDER:
		var vp3 := _icon_viewport(128)
		var hm := Models.hero(htype)
		hm.rotation_degrees.y = 18.0
		vp3.add_child(hm)
		var cam3 := Camera3D.new()
		cam3.fov = 30.0
		vp3.add_child(cam3)
		# Head-and-shoulders framing reads best at button size.
		var frame: Array = hm.get_meta("portrait")
		cam3.look_at_from_position(frame[0], frame[1])
		vps["hero:" + htype] = vp3
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for type: String in vps:
		var vp: SubViewport = vps[type]
		var img := vp.get_texture().get_image()
		if img and not img.is_empty():
			if type.begins_with("enemy:"):
				_enemy_icons[type.trim_prefix("enemy:")] = ImageTexture.create_from_image(img)
			elif type.begins_with("hero:"):
				_hero_icons[type.trim_prefix("hero:")] = ImageTexture.create_from_image(img)
			else:
				_icons[type] = ImageTexture.create_from_image(img)
		vp.queue_free()


func _icon_viewport(px: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -40, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	return vp


# ------------------------------------------------------------------ modals

func _make_modal() -> PanelContainer:
	_close_modal()
	close_menus()
	game.deselect_hero()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_modal)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	return panel


func _close_modal() -> void:
	if _modal and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_modal_kind = ""


func open_pause() -> void:
	if not game.is_running():
		return
	Audio.play("click", -4.0)
	get_tree().paused = true
	var panel := _make_modal()
	_modal_kind = "pause"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := UIKit.label(Loc.t("PAUSED"), 48, UIKit.GOLD, true, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := UIKit.button(Loc.t("RESUME"), true, 340)
	resume.pressed.connect(_resume)
	v.add_child(resume)
	var settings := UIKit.button(Loc.t("SETTINGS"), false, 340)
	settings.pressed.connect(_open_settings_from_pause)
	v.add_child(settings)
	var restart := UIKit.button(Loc.t("RESTART"), false, 340)
	restart.pressed.connect(func(): game.restart())
	v.add_child(restart)
	var menu := UIKit.button(Loc.t("MAIN_MENU"), false, 340)
	menu.pressed.connect(func(): game.quit_to_menu())
	v.add_child(menu)
	UIKit.pop_in(panel)


func _resume() -> void:
	_close_modal()
	get_tree().paused = false


func _back_to_pause() -> void:
	_close_modal()
	get_tree().paused = false
	open_pause()


func _open_settings_from_pause() -> void:
	var panel := _make_modal()
	_modal_kind = "settings"
	var s := SettingsPanel.new()
	s.closed.connect(_back_to_pause)
	panel.add_child(s)
	UIKit.pop_in(panel)


func show_result(won: bool, stars: int) -> void:
	close_menus()
	await get_tree().create_timer(1.2, true, false, true).timeout
	if not is_instance_valid(self):
		return
	var panel := _make_modal()
	_modal_kind = "result"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size.x = 520
	panel.add_child(v)
	var title := UIKit.label(Loc.t("VICTORY") if won else Loc.t("DEFEAT"), 56, UIKit.GOLD if won else UIKit.RED, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var level_name := UIKit.label(Loc.t(game.level["name"]), 26, UIKit.TEXT_DIM)
	level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(level_name)
	if won:
		var star_row := HBoxContainer.new()
		star_row.alignment = BoxContainer.ALIGNMENT_CENTER
		star_row.add_theme_constant_override("separation", 12)
		v.add_child(star_row)
		for i in 3:
			var st := Icons.make("star", 84)
			st.filled = i < stars
			star_row.add_child(st)
			if i < stars:
				UIKit.pop_in(st, 0.25 + i * 0.25, 0.45)
				get_tree().create_timer(0.25 + i * 0.25, true, false, true).timeout.connect(func(): Audio.play("coin", -2.0, 0.0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for row in [["STAT_KILLS", game.stats["kills"]], ["STAT_LIVES", "%d/%d" % [game.lives, game.lives_max]], ["STAT_GOLD", game.stats["gold_earned"]]]:
		grid.add_child(UIKit.label(Loc.t(row[0]), 24, UIKit.TEXT_DIM))
		var val := UIKit.label(str(row[1]), 24, UIKit.TEXT, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
	var is_last := game.level_index >= GameData.level_count() - 1
	if won and is_last:
		var done := UIKit.label(Loc.t("ALL_CLEAR"), 22, UIKit.GOLD)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(done)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	v.add_child(buttons)
	var menu := UIKit.button(Loc.t("LEVELS"), false, 170)
	menu.pressed.connect(func(): game.get_parent().call("show_levels"))
	buttons.add_child(menu)
	var retry := UIKit.button(Loc.t("RETRY"), not won, 170)
	retry.pressed.connect(func(): game.restart())
	buttons.add_child(retry)
	if won and not is_last:
		var nxt := UIKit.button(Loc.t("NEXT_LEVEL"), true, 170)
		nxt.pressed.connect(func(): game.get_parent().call("start_level", game.level_index + 1))
		buttons.add_child(nxt)
	UIKit.pop_in(panel)


static func stats_line(type: String, lvl: int) -> String:
	var s := GameData.tower_stats(type, lvl)
	var parts: Array[String] = []
	if s.has("damage"):
		parts.append("%s %d" % [Loc.t("DAMAGE"), int(s["damage"])])
	if s.has("dps"):
		parts.append("%s %d" % [Loc.t("DPS"), int(s["dps"])])
	parts.append("%s %.1f" % [Loc.t("RANGE"), float(s["range"])])
	if s.has("rate"):
		parts.append("%s %.1f%s" % [Loc.t("RATE"), float(s["rate"]), Loc.t("PER_SEC")])
	return "   ".join(parts)
