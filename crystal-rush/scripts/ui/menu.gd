class_name Menu
extends Node3D
## Title screen: the chosen hero on the bridge behind the UI, hero choice, upgrades bought
## with coins, settings, and the button that starts the next level.

signal play

var _hero_node: Node3D
var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _coins_lbl: Label
var _play_btn: Button
var _cards := {}           # hero type -> PanelContainer
var _upgrade_btns := {}    # kind -> Button
var _upgrade_lvls := {}    # kind -> Label
var _portraits := {}       # hero type -> TextureRect
var _settings: Control


func _ready() -> void:
	var track := Track.new()
	add_child(track)
	track.build(40.0, Save.quality == "high")
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = 50.0
	add_child(_cam)
	_cam.make_current()
	_show_hero()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UIKit.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_build_ui()
	Save.coins_changed.connect(func(_c: int): _refresh())
	Loc.language_changed.connect(_rebuild)
	Audio.play_music("menu")
	_render_portraits()


func _show_hero() -> void:
	if _hero_node:
		_hero_node.queue_free()
	_hero_node = HeroModels.hero(Save.hero)
	_hero_node.position = Vector3(0, 0, -6.0)
	add_child(_hero_node)


func _process(delta: float) -> void:
	_t += delta
	if _hero_node:
		HeroModels.animate_hero(_hero_node, _t, false, 0.0)
		_hero_node.rotation.y = sin(_t * 0.4) * 0.35
	var a := sin(_t * 0.15) * 0.3
	_cam.position = Vector3(sin(a) * 4.6, 1.6, -6.0 + cos(a) * 4.6)
	# Aim below the hero so it stands in the open middle of the screen, above the cards.
	_cam.look_at(Vector3(0, 0.15, -6.0))


func _rebuild() -> void:
	for c in _ui.get_children():
		c.queue_free()
	_cards.clear()
	_upgrade_btns.clear()
	_upgrade_lvls.clear()
	_portraits.clear()
	_build_ui()
	_render_portraits()


func _build_ui() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = 26
	col.offset_bottom = -34
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var gear := RoundButton.new(30.0)
	gear.icon_kind = "gear"
	gear.pressed.connect(_open_settings)
	top.add_child(gear)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.08, 0.18, 0.8), Color(0, 0, 0, 0), 22, 0, 0, Vector2(20, 8)))
	var coins_row := HBoxContainer.new()
	coins_row.add_theme_constant_override("separation", 8)
	var coin_icon := Icons.make("coin", 34.0)
	coins_row.add_child(coin_icon)
	_coins_lbl = UIKit.label(str(Save.coins), 32, UIKit.GOLD, true)
	coins_row.add_child(_coins_lbl)
	pill.add_child(coins_row)
	top.add_child(pill)
	var title := UIKit.label(Loc.t("GAME_TITLE"), 64, UIKit.GOLD, true, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var tag := UIKit.label(Loc.t("GAME_TAGLINE"), 26, UIKit.TEXT, false, 6)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tag)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var choose := UIKit.label(Loc.t("CHOOSE_HERO"), 30, UIKit.TEXT, true, 6)
	choose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(choose)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards)
	for type: String in ["bolt", "titan"]:
		cards.add_child(_hero_card(type))
	for kind: String in ["army", "power"]:
		col.add_child(_upgrade_row(kind))
	_play_btn = UIKit.button(Loc.f("PLAY_LEVEL", [Save.level]), true, 460.0)
	_play_btn.custom_minimum_size.y = 96
	_play_btn.add_theme_font_size_override("font_size", 40)
	_play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_btn.pressed.connect(func(): Audio.play("click"); play.emit())
	col.add_child(_play_btn)
	_refresh()


func _hero_card(type: String) -> Control:
	var def: Dictionary = Balance.HEROES[type]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(120, 120)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	_portraits[type] = pic
	var name_lbl := UIKit.label(Loc.t(def["name"]), 32, (def["color"] as Color).lightened(0.35), true, 6)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)
	var desc := UIKit.label(Loc.t(def["desc"]), 20, UIKit.TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(260, 0)
	v.add_child(desc)
	card.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_pick(type))
	_cards[type] = card
	return card


func _upgrade_row(kind: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.08, 0.18, 0.82), Color(0, 0, 0, 0), 22, 0, 0, Vector2(20, 10)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(Icons.make("swords" if kind == "army" else "bolt", 44.0, UIKit.GOLD))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var key := "UPGRADE_ARMY" if kind == "army" else "UPGRADE_POWER"
	var n := UIKit.label(Loc.t(key), 28, UIKit.TEXT, true)
	v.add_child(n)
	var dsc := UIKit.label(Loc.t(key + "_DESC"), 20, UIKit.TEXT_DIM)
	v.add_child(dsc)
	var lvl := UIKit.label("", 26, UIKit.GOLD, true)
	h.add_child(lvl)
	_upgrade_lvls[kind] = lvl
	var b := UIKit.button("", false, 150.0)
	b.pressed.connect(func():
		if Save.buy_upgrade(kind):
			Audio.play("upgrade")
			_refresh()
		else:
			Audio.play("error"))
	h.add_child(b)
	_upgrade_btns[kind] = b
	return p


func _pick(type: String) -> void:
	if Save.hero == type:
		return
	Save.set_hero(type)
	Audio.play("click")
	_show_hero()
	_refresh()


func _refresh() -> void:
	_coins_lbl.text = str(Save.coins)
	for type: String in _cards:
		var sel := Save.hero == type
		var col: Color = Balance.HEROES[type]["color"]
		(_cards[type] as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(
			Color(0.06, 0.1, 0.22, 0.9) if sel else Color(0.05, 0.07, 0.14, 0.75),
			UIKit.GOLD if sel else col.darkened(0.4), 24, 4 if sel else 2, 8 if sel else 0, Vector2(14, 12)))
	for kind: String in _upgrade_btns:
		var lv := int(Save.upgrades[kind])
		(_upgrade_lvls[kind] as Label).text = "%d/%d" % [lv, Balance.MAX_UPGRADE]
		var b := _upgrade_btns[kind] as Button
		if lv >= Balance.MAX_UPGRADE:
			b.text = Loc.t("MAX")
			b.disabled = true
		else:
			b.text = "%d" % Save.upgrade_cost(kind)
			b.disabled = not Save.can_upgrade(kind)
	_play_btn.text = Loc.f("PLAY_LEVEL", [Save.level])


func _render_portraits() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for type: String in ["bolt", "titan"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(200, 200)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.8, 0.85, 1.0)
		env.ambient_light_energy = 0.6
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-30, 30, 0)
		vp.add_child(sun)
		var m := HeroModels.hero(type)
		m.rotation_degrees.y = 18.0
		vp.add_child(m)
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		var frame: Array = m.get_meta("portrait")
		cam.look_at_from_position(frame[0], frame[1])
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img and not img.is_empty() and _portraits.has(type):
			(_portraits[type] as TextureRect).texture = ImageTexture.create_from_image(img)
		vp.queue_free()


# ------------------------------------------------------------------ settings

func _open_settings() -> void:
	if _settings:
		return
	Audio.play("click")
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_settings)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, UIKit.GOLD.darkened(0.2), 28, 3, 10, Vector2(36, 28)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := UIKit.label(Loc.t("SETTINGS"), 46, UIKit.GOLD, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	_toggle(box, "MUSIC", func(): return Save.music_volume > 0.0, func():
		Save.music_volume = 0.0 if Save.music_volume > 0.0 else 0.7)
	_toggle(box, "SOUND", func(): return Save.sfx_volume > 0.0, func():
		Save.sfx_volume = 0.0 if Save.sfx_volume > 0.0 else 0.85)
	_toggle(box, "VIBRATION", func(): return Save.vibration, func():
		Save.vibration = not Save.vibration)
	_toggle(box, "GRAPHICS", func(): return Save.quality == "high", func():
		Save.quality = "low" if Save.quality == "high" else "high", "QUALITY_HIGH", "QUALITY_LOW")
	var lang := UIKit.button(Loc.t("LANGUAGE") + ": " + Loc.t("LANG_NAME"), false, 420.0)
	lang.pressed.connect(func():
		_close_settings()
		Loc.set_language(Loc.next_language()))
	box.add_child(lang)
	var close := UIKit.button(Loc.t("CLOSE"), true, 420.0)
	close.pressed.connect(_close_settings)
	box.add_child(close)
	UIKit.pop_in(panel)


func _toggle(box: Control, key: String, get_on: Callable, flip: Callable, on_key := "ON", off_key := "OFF") -> void:
	var b := UIKit.button("", false, 420.0)
	var paint := func(): b.text = Loc.t(key) + ": " + Loc.t(on_key if get_on.call() else off_key)
	paint.call()
	b.pressed.connect(func():
		flip.call()
		Save.apply_settings()
		Audio.play("click")
		paint.call())
	box.add_child(b)


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
