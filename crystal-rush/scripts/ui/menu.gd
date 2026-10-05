class_name Menu
extends Node3D
## Title screen: the chosen hero on the bridge behind the UI, hero choice, upgrades bought
## with coins, settings, and the button that starts the next level.
## Android back closes the settings panel, or quits from the main screen.

signal play

const COL_MARGIN := 28.0

var _hero_node: Node3D
var _cam: Camera3D
var _t := 0.0
var _ui: Control
var _coins_lbl: Label
var _play_btn: Button
var _cards := {}           # hero type -> PanelContainer
var _upgrade_btns := {}    # kind -> Button
var _upgrade_price := {}   # kind -> Label
var _upgrade_lvls := {}    # kind -> LevelPips
var _portraits := {}       # hero type -> HeroMedallion
var _portrait_tex := {}    # hero type -> Texture2D (survives rebuilds)
var _settings: Control
var _desc_lbl: Label


func _ready() -> void:
	var track := Track.new()
	add_child(track)
	track.build(40.0, Save.quality == "high", Worlds.for_level(Save.level))
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
	_cam.look_at(Vector3(0, -0.38, -6.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if _settings:
			_close_settings()
		else:
			get_tree().quit()


func _rebuild() -> void:
	_settings = null
	for c in _ui.get_children():
		c.queue_free()
	_cards.clear()
	_upgrade_btns.clear()
	_upgrade_price.clear()
	_upgrade_lvls.clear()
	_portraits.clear()
	_build_ui()
	for type: String in _portrait_tex:
		if _portraits.has(type):
			(_portraits[type] as HeroMedallion).set_texture(_portrait_tex[type])


func _build_ui() -> void:
	var ins := UIKit.safe_insets(get_viewport())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = COL_MARGIN + ins.x
	col.offset_right = -COL_MARGIN - ins.z
	col.offset_top = 22 + ins.y
	col.offset_bottom = -30 - ins.w
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(col)
	# Top bar
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var gear := RoundButton.new(30.0)
	gear.icon_kind = "gear"
	gear.pressed.connect(_open_settings)
	top.add_child(gear)
	top.add_child(UIKit.spacer())
	var pill := UIKit.pill()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coins_row := HBoxContainer.new()
	coins_row.add_theme_constant_override("separation", 8)
	coins_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_row.add_child(Icons.make("coin", 36.0))
	_coins_lbl = UIKit.heading(str(Save.coins), 32, UIKit.GOLD, 6)
	coins_row.add_child(_coins_lbl)
	pill.add_child(coins_row)
	top.add_child(pill)
	# Title, fitted to the column width (the Ukrainian title is long).
	var width := get_viewport().get_visible_rect().size.x - COL_MARGIN * 2.0 - ins.x - ins.z
	var title_text := Loc.t("GAME_TITLE")
	var fs := 72
	while fs > 36 and UIKit.font(true).get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0 > width:
		fs -= 2
	var title := UIKit.gradient_heading(title_text, fs, Color(1, 1, 0.9), Color(1.0, 0.82, 0.32), Color(0.9, 0.45, 0.08), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("shadow_offset_y", 6)
	col.add_child(title)
	var world := HBoxContainer.new()
	world.alignment = BoxContainer.ALIGNMENT_CENTER
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wp := UIKit.pill(true)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrow.add_child(Icons.make("crystal", 24.0))
	wrow.add_child(UIKit.heading(Loc.t("WORLD_SPACE").to_upper(), 20, Color(0.7, 0.9, 1.0), 4))
	wp.add_child(wrow)
	world.add_child(wp)
	col.add_child(world)
	var tag := UIKit.heading(Loc.t("GAME_TAGLINE"), 26, UIKit.TEXT, 6)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tag)
	col.add_child(UIKit.spacer(false))
	# Hero choice
	var choose_row := HBoxContainer.new()
	choose_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choose_row.add_theme_constant_override("separation", 14)
	choose_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choose_row.add_child(UIKit.divider(110.0))
	var choose := UIKit.heading(Loc.t("CHOOSE_HERO"), 30, UIKit.TEXT, 7)
	choose_row.add_child(choose)
	choose_row.add_child(UIKit.divider(110.0))
	for d in [choose_row.get_child(0), choose_row.get_child(2)]:
		(d as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(choose_row)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cards)
	for type: String in ["bolt", "titan"]:
		cards.add_child(_hero_card(type))
	_desc_lbl = UIKit.heading("", 22, Color(0.86, 0.9, 1.0), 7)
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_desc_lbl)
	col.add_child(UIKit.gap(2))
	for kind: String in ["army", "power"]:
		col.add_child(_upgrade_row(kind))
	col.add_child(UIKit.gap(4))
	_play_btn = UIKit.button(Loc.f("PLAY_LEVEL", [Save.level]), true, 480.0)
	_play_btn.custom_minimum_size.y = 104
	_play_btn.add_theme_font_size_override("font_size", 44)
	_play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_btn.pressed.connect(func(): play.emit())
	col.add_child(_play_btn)
	UIKit.add_shine(_play_btn, 30.0, 1.0, 3.0, 0.5)
	_refresh()
	UIKit.stagger([title, world, tag], 0.05, 0.08, 0.45)
	UIKit.stagger([cards.get_child(0), cards.get_child(1)], 0.2, 0.08, 0.4)
	UIKit.pop_in(_play_btn, 0.45, 0.45)


func _hero_card(type: String) -> Control:
	var def: Dictionary = Balance.HEROES[type]
	var hc: Color = def["color"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var medal := HeroMedallion.new()
	medal.color = hc
	medal.custom_minimum_size = Vector2(124, 124)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(medal)
	_portraits[type] = medal
	var name_lbl := UIKit.gradient_heading(Loc.t(def["name"]), 34, hc.lightened(0.75), hc.lightened(0.3), hc.darkened(0.15), 8)
	name_lbl.add_theme_color_override("font_outline_color", hc.darkened(0.85))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_lbl)
	card.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_pick(type))
	_cards[type] = card
	return card


func _upgrade_row(kind: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(16, 10)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var medal := HudView.IconBadge.new()
	medal.custom_minimum_size = Vector2(64, 64)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.icon = "soldier" if kind == "army" else "rate"
	medal.icon_scale = 0.74
	h.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var key := "UPGRADE_ARMY" if kind == "army" else "UPGRADE_POWER"
	v.add_child(UIKit.heading(Loc.t(key), 28, UIKit.TEXT, 5))
	v.add_child(UIKit.label(Loc.t(key + "_DESC"), 20, UIKit.TEXT_DIM))
	var pips := LevelPips.new()
	pips.custom_minimum_size = Vector2(200, 14)
	v.add_child(pips)
	_upgrade_lvls[kind] = pips
	var b := UIKit.button("", false, 168.0)
	b.custom_minimum_size.y = 74
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -5
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := Icons.make("coin", 30.0)
	pc.name = "Coin"
	prow.add_child(pc)
	var price := UIKit.heading("", 30, UIKit.GOLD, 6)
	prow.add_child(price)
	cc.add_child(prow)
	b.add_child(cc)
	_upgrade_price[kind] = price
	b.pressed.connect(func():
		if Save.buy_upgrade(kind):
			Audio.play("upgrade")
			UIKit.punch(medal, 1.25)
			UIKit.sparkles(_ui, medal.global_position - _ui.global_position + medal.size * 0.5, UIKit.GOLD_LIGHT, 18, 200.0)
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
	UIKit.punch(_cards[type], 1.05, 0.3)


func _refresh() -> void:
	_coins_lbl.text = str(Save.coins)
	for type: String in _cards:
		var sel := Save.hero == type
		var card := _cards[type] as PanelContainer
		card.add_theme_stylebox_override("panel", UIKit.lux("card_sel" if sel else "card_dim", Vector2(14, 12)))
		card.self_modulate = Color.WHITE if sel else Color(0.85, 0.87, 0.95)
		var medal := _portraits.get(type) as HeroMedallion
		if medal:
			medal.selected = sel
			medal.queue_redraw()
	for kind: String in _upgrade_btns:
		var lv := int(Save.upgrades[kind])
		(_upgrade_lvls[kind] as LevelPips).set_level(lv, Balance.MAX_UPGRADE)
		var b := _upgrade_btns[kind] as Button
		var price := _upgrade_price[kind] as Label
		var coin := price.get_parent().get_node("Coin") as Control
		if lv >= Balance.MAX_UPGRADE:
			price.text = Loc.t("MAX")
			coin.visible = false
			b.disabled = true
		else:
			price.text = "%d" % Save.upgrade_cost(kind)
			coin.visible = true
			b.disabled = not Save.can_upgrade(kind)
		price.add_theme_color_override("font_color", UIKit.GOLD if not b.disabled else Color(0.6, 0.62, 0.68))
		coin.modulate = Color.WHITE if not b.disabled else Color(0.6, 0.6, 0.65)
	_play_btn.text = Loc.f("PLAY_LEVEL", [Save.level])
	_desc_lbl.text = Loc.t(Balance.HEROES[Save.hero]["desc"])


func _render_portraits() -> void:
	for type: String in ["bolt", "titan"]:
		var tex := await UIKit.render_portrait(self, type, 220)
		if tex == null:
			continue
		_portrait_tex[type] = tex
		if _portraits.has(type):
			(_portraits[type] as HeroMedallion).set_texture(tex)


# ------------------------------------------------------------------ settings

func _open_settings() -> void:
	if _settings:
		return
	Audio.play("click")
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_settings)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_settings())
	_settings.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(40, 34)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := UIKit.gradient_heading(Loc.t("SETTINGS"), 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(UIKit.divider(420.0))
	_toggle(box, "MUSIC", "music", func(): return Save.music_volume > 0.0, func():
		Save.music_volume = 0.0 if Save.music_volume > 0.0 else 0.7)
	_toggle(box, "SOUND", "sound", func(): return Save.sfx_volume > 0.0, func():
		Save.sfx_volume = 0.0 if Save.sfx_volume > 0.0 else 0.85)
	_toggle(box, "VIBRATION", "bolt", func(): return Save.vibration, func():
		Save.vibration = not Save.vibration)
	_toggle(box, "GRAPHICS", "crystal", func(): return Save.quality == "high", func():
		Save.quality = "low" if Save.quality == "high" else "high", "QUALITY_HIGH", "QUALITY_LOW")
	var lang := _setting_button(box, "globe")
	lang.text = Loc.t("LANGUAGE")
	var lv := UIKit.heading(Loc.t("LANG_NAME"), 24, UIKit.GOLD, 5)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.size = Vector2(220, 60)
	lv.position = Vector2(440 - 220 - 24, 4)
	lang.add_child(lv)
	lang.pressed.connect(func():
		_close_settings()
		Loc.set_language(Loc.next_language()))
	box.add_child(UIKit.gap(4))
	var close := UIKit.button(Loc.t("CLOSE"), true, 440.0)
	close.pressed.connect(_close_settings)
	box.add_child(close)
	UIKit.pop_in(panel, 0.0, 0.4)


func _setting_button(box: Control, icon: String) -> Button:
	var b := UIKit.button("", false, 440.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var base := UIKit.lux("button_pressed" if st.ends_with("pressed") else "button").duplicate() as StyleBox
		base.content_margin_left = 76
		b.add_theme_stylebox_override(st, base)
	var ic := Icons.make(icon, 36.0, UIKit.GOLD)
	ic.position = Vector2(24, 16)
	b.add_child(ic)
	box.add_child(b)
	return b


## A settings row: icon, name, and on the right either a switch (on/off) or a gold value.
func _toggle(box: Control, key: String, icon: String, get_on: Callable, flip: Callable, on_key := "", off_key := "") -> void:
	var b := _setting_button(box, icon)
	b.text = Loc.t(key)
	var sw := Switch.new()
	var val := UIKit.heading("", 24, UIKit.GOLD, 5)
	if on_key == "":
		sw.custom_minimum_size = Vector2(76, 40)
		sw.size = sw.custom_minimum_size
		sw.position = Vector2(440 - 76 - 22, 14)
		b.add_child(sw)
	else:
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.size = Vector2(200, 60)
		val.position = Vector2(440 - 200 - 24, 4)
		b.add_child(val)
	var paint := func(animate: bool):
		var on: bool = get_on.call()
		sw.set_on(on, animate)
		val.text = Loc.t(on_key if on else off_key) if on_key != "" else ""
	paint.call(false)
	b.pressed.connect(func():
		flip.call()
		Save.apply_settings()
		paint.call(true))


func _close_settings() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null


## Segmented upgrade level bar (gold pips with a glossy top).
class LevelPips extends Control:
	var level := 0
	var max_level := 10

	func set_level(l: int, m: int) -> void:
		level = l
		max_level = maxi(1, m)
		queue_redraw()

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (max_level - 1)) / max_level
		for i in max_level:
			var r := Rect2(Vector2(i * (w + gap), 2), Vector2(w, size.y - 4))
			if i < level:
				draw_style_box(UIKit.box(Color(1.0, 0.72, 0.22), Color(0.5, 0.26, 0.04), 4, 1, 0, Vector2.ZERO), r)
				draw_rect(Rect2(r.position + Vector2(2, 1.5), Vector2(r.size.x - 4, r.size.y * 0.35)), Color(1, 1, 0.85, 0.6))
			else:
				draw_style_box(UIKit.box(Color(0.03, 0.04, 0.1, 0.8), Color(1, 1, 1, 0.12), 4, 1, 0, Vector2.ZERO), r)


## Hero portrait in a round gold medallion (clipped to the circle, hero-coloured backdrop).
class HeroMedallion extends Control:
	var color := Color(0.4, 0.7, 1.0)
	var selected := false
	var tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_texture(t: Texture2D) -> void:
		tex = t
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 6.0
		if selected:
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), false, Color(color.r, color.g, color.b, 0.6))
		draw_circle(c + Vector2(0, 4), r + 2.0, Color(0, 0, 0.02, 0.45))
		var rim_hi := Color(1.0, 0.9, 0.55) if selected else Color(0.66, 0.72, 0.86)
		var rim_lo := Color(0.62, 0.36, 0.08) if selected else Color(0.24, 0.27, 0.38)
		draw_circle(c, r, rim_lo.darkened(0.4))
		draw_circle(c + Vector2(0, -1.2), r - 1.2, rim_hi)
		draw_circle(c + Vector2(0, 1.5), r - 4.0, rim_lo)
		var face := r - 6.0
		for i in 6:
			var k := 1.0 - i * 0.13
			draw_circle(c - Vector2(0, face * 0.05 * i), face * k, Color(0.04, 0.05, 0.12).lerp(color.darkened(0.15), 0.12 + i * 0.12))
		if tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var n := 48
			for i in n:
				var a := TAU * i / n
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * face)
				uvs.append(Vector2(0.5, 0.47) + d * 0.5 / 1.08)
			var m := 1.0 if selected else 0.62
			draw_polygon(pts, PackedColorArray([Color(m, m, m * 1.05)]), uvs, tex)
		# Glass gloss on top.
		draw_arc(c, face - 1.0, PI * 1.08, PI * 1.92, 28, Color(1, 1, 1, 0.3), 2.5, true)
		draw_arc(c, face - 0.5, 0, TAU, 64, Color(0, 0, 0, 0.35), 1.5, true)


## Animated on/off switch for settings rows.
class Switch extends Control:
	var on := true
	var _k := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool, animate := true) -> void:
		on = v
		if not animate:
			_k = 1.0 if v else 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		var t := 1.0 if on else 0.0
		if not is_equal_approx(_k, t):
			_k = move_toward(_k, t, delta * 6.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := int(size.y * 0.5)
		var bg := Color(0.16, 0.18, 0.28).lerp(Color(0.22, 0.72, 0.36), _k)
		draw_style_box(UIKit.box(Color(0, 0, 0.03, 0.5), Color(0, 0, 0, 0), rad, 0, 0, Vector2.ZERO), Rect2(r.position + Vector2(0, 2), r.size))
		draw_style_box(UIKit.box(bg, Color(1, 0.85, 0.5, 0.55), rad, 2, 0, Vector2.ZERO), r)
		var kr := size.y * 0.5 - 4.0
		var kx := lerpf(size.y * 0.5, size.x - size.y * 0.5, _k)
		var kc := Vector2(kx, size.y * 0.5)
		draw_circle(kc + Vector2(0, 2), kr, Color(0, 0, 0, 0.35))
		draw_circle(kc, kr, Color(0.98, 0.96, 0.9))
		draw_arc(kc, kr * 0.6, PI * 1.1, PI * 1.9, 12, Color(1, 1, 1, 0.9), 2.0, true)
