class_name Menu
extends Node3D
## Title screen with a slowly orbiting 3D diorama, level select and settings.

var _ui: Control
var _page: Control
var _cam: Camera3D
var _t := 0.0
var _map: LevelMap
var start_page := "main"
var _page_name := ""


func _ready() -> void:
	var idx := clampi(Save.unlocked - 1, 0, GameData.level_count() - 1)
	var level := Arena.prepare_level(GameData.get_level(idx))
	var high := Save.quality == "high"
	add_child(WorldEnv.make_environment(level["theme"], high))
	add_child(WorldEnv.make_sun(level["theme"], high))
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	_map = LevelMap.new()
	add_child(_map)
	_map.build(level, high)
	_decorate(level)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_update_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UIKit.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float v = smoothstep(0.0, 0.7, 1.0 - UV.x);
	COLOR = vec4(0.02, 0.03, 0.08, 0.62 * v);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	shade.material = m
	_ui.add_child(shade)
	Audio.play_music("menu")
	match start_page:
		"levels":
			show_levels()
		_:
			show_main()


func _decorate(level: Dictionary) -> void:
	# A few showcase towers on the island.
	var types: Array = level["towers"]
	var placed := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cells: Array = []
	for c: Vector2i in _map.cells:
		if _map.is_buildable(c):
			var near_path := false
			for n in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
				if _map.is_path(n):
					near_path = true
			if near_path:
				cells.append(c)
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return hash(a) < hash(b))
	for c: Vector2i in cells:
		if placed >= 6:
			break
		if rng.randf() < 0.5:
			continue
		var t := Models.tower(types[placed % types.size()], placed % 3)
		t.position = _map.cell_to_world(c)
		t.rotation.y = rng.randf() * TAU
		add_child(t)
		_map.hide_deco(c)
		placed += 1


func _process(delta: float) -> void:
	_t += delta
	_update_camera()


func _update_camera() -> void:
	var a := _t * 0.06 + 0.4
	var r := 13.5
	_cam.position = Vector3(sin(a) * r, 8.2, cos(a) * r)
	_cam.look_at(Vector3(0, -0.6, 0), Vector3.UP)


func _clear_page() -> void:
	if _page and is_instance_valid(_page):
		_page.queue_free()
	_page = null


func _set_page(p: Control, page_name: String) -> void:
	_clear_page()
	_page = p
	_page_name = page_name
	_ui.add_child(p)


# ------------------------------------------------------------------ pages

func show_main() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_page(page, "main")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(v)
	var crest := Icons.make("crystal", 72)
	v.add_child(crest)
	var title := UIKit.label(Loc.t("GAME_TITLE"), 72, UIKit.GOLD, true, 14)
	v.add_child(title)
	var tag := UIKit.label(Loc.t("GAME_TAGLINE"), 28, UIKit.TEXT, false, 6)
	v.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	v.add_child(spacer)
	var play := UIKit.button(Loc.t("PLAY"), true, 360)
	play.pressed.connect(show_levels)
	v.add_child(play)
	var settings := UIKit.button(Loc.t("SETTINGS"), false, 360)
	settings.pressed.connect(show_settings)
	v.add_child(settings)
	if not OS.has_feature("web"):
		var quit := UIKit.button(Loc.t("QUIT"), false, 360)
		quit.pressed.connect(func(): get_tree().quit())
		v.add_child(quit)
	for b in v.get_children():
		if b is Button:
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 80)
	var stars := UIKit.label(Loc.f("STARS_TOTAL", [Save.total_stars(), GameData.level_count() * 3]), 24, UIKit.TEXT_DIM, false, 4)
	page.add_child(stars)
	stars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 40)
	stars.position.x = 80
	var ver := UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 18, UIKit.TEXT_DIM)
	# Hidden shortcut: five quick taps on the version number open every level.
	ver.custom_minimum_size = Vector2(140, 44)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_on_version_input.bind(ver))
	page.add_child(ver)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	var i := 0
	for c in v.get_children():
		if c is Control:
			_slide_in(c, i * 0.06)
			i += 1


func _slide_in(c: Control, delay: float) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(delay)


func show_levels() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_page(page, "levels")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 26)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(v)
	var title := UIKit.label(Loc.t("SELECT_LEVEL"), 54, UIKit.GOLD, true, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	v.add_child(row)
	for i in GameData.level_count():
		var card := _level_card(i)
		row.add_child(card)
		UIKit.pop_in(card, 0.08 * i, 0.4)
	var back := UIKit.button(Loc.t("BACK"), false, 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_main)
	v.add_child(back)


var _version_taps: Array[int] = []


func _on_version_input(ev: InputEvent, ver: Label) -> void:
	# Phones deliver taps as emulated mouse clicks too, so only mouse buttons are counted.
	var click := ev as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var now := Time.get_ticks_msec()
	_version_taps.append(now)
	while _version_taps.size() > 0 and now - _version_taps[0] > 2500:
		_version_taps.pop_front()
	if _version_taps.size() < 5:
		return
	_version_taps.clear()
	Save.unlock_all()
	Audio.play("upgrade")
	Save.vibrate(40)
	ver.text = Loc.t("ALL_UNLOCKED")
	ver.add_theme_color_override("font_color", UIKit.GOLD)
	UIKit.pop_in(ver)


func _level_card(i: int) -> Control:
	var level := GameData.get_level(i)
	var theme_d: Dictionary = level["theme"]
	var locked := i >= Save.unlocked
	var card := Button.new()
	card.custom_minimum_size = Vector2(330, 380)
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = locked
	var top: Color = theme_d["sky_top"]
	var hor: Color = theme_d["sky_horizon"]
	var normal := UIKit.box(top.lerp(Color(0.05, 0.06, 0.12), 0.35), hor, 26, 4, 12)
	var hover := UIKit.box(top.lerp(Color(0.05, 0.06, 0.12), 0.2), UIKit.GOLD, 26, 4, 14)
	var dis := UIKit.box(Color(0.1, 0.11, 0.16, 0.92), Color(0.3, 0.32, 0.38), 26, 4, 6)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("hover_pressed", hover)
	card.add_theme_stylebox_override("disabled", dis)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 22
	v.offset_right = -22
	v.offset_top = 20
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	# Thumbnail: theme gradient with grass strip and a crystal.
	var thumb := LevelThumb.new()
	thumb.theme_colors = theme_d
	thumb.locked = locked
	thumb.custom_minimum_size = Vector2(0, 130)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(thumb)
	var num := UIKit.label("%d" % (i + 1), 22, UIKit.GOLD, true)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := UIKit.label(Loc.t(level["name"]), 28, UIKit.TEXT if not locked else UIKit.TEXT_DIM, true, 6)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 280
	v.add_child(name_l)
	var sub := UIKit.label(Loc.t(level["subtitle"]) if not locked else Loc.t("LOCKED_HINT"), 20, UIKit.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.y = 52
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	v.add_child(bottom)
	for s in 3:
		var st := Icons.make("star", 36)
		st.filled = s < Save.stars[i]
		bottom.add_child(st)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sp)
	var waves := UIKit.label(Loc.f("WAVES_N", [level["waves"].size()]), 20, UIKit.TEXT_DIM)
	waves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(waves)
	card.pressed.connect(func(): _start(i))
	return card


func _start(i: int) -> void:
	Audio.play("click", -2.0)
	get_parent().call("start_level", i)


func show_settings() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_set_page(page, "settings")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var s := SettingsPanel.new()
	s.closed.connect(show_main)
	panel.add_child(s)
	UIKit.pop_in(panel)


func handle_back() -> void:
	if _page_name != "main":
		show_main()
	else:
		get_tree().quit()
