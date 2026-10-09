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
	_coins_lbl = UIKit.number(str(Save.coins), 30, false, UIKit.INK)
	coins_row.add_child(_coins_lbl)
	pill.add_child(coins_row)
	top.add_child(pill)
	# Title, fitted to the column width (the Ukrainian title is long).
	var width := get_viewport().get_visible_rect().size.x - COL_MARGIN * 2.0 - ins.x - ins.z
	var title_text := Loc.t("GAME_TITLE")
	var fs := 72
	while fs > 36 and UIKit.font(true).get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0 > width:
		fs -= 2
	# v3.1: warm white into soft gold, the soft scene shadow only (no extruded drop).
	var title := UIKit.gradient_heading(title_text, fs, UIKit.ON_SCENE, Color("#FFF1D2"), UIKit.GOLD_HI)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var world := HBoxContainer.new()
	world.alignment = BoxContainer.ALIGNMENT_CENTER
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wp := UIKit.pill()
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrow.add_child(Icons.make("crystal", 24.0))
	var wl := UIKit.caps(Loc.t("WORLD_SPACE"), 22, UIKit.GOLD_TEXT_GLASS)
	wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrow.add_child(wl)
	wp.add_child(wrow)
	world.add_child(wp)
	col.add_child(world)
	var tag := UIKit.scene_label(Loc.t("GAME_TAGLINE"), 26, false)
	UIKit.scene_halo(tag, 1.0)
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
	var choose := UIKit.scene_label(Loc.t("CHOOSE_HERO"), 28, false)
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
	_desc_lbl = UIKit.scene_label("", 24, false)
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
	# v3.1: the name in ink Medium on the card glass (the hero colour lives in the medallion).
	var name_lbl := UIKit.label(Loc.t(def["name"]), 28, UIKit.INK)
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
	v.add_child(UIKit.label(Loc.t(key), 26, UIKit.INK))
	v.add_child(UIKit.label(Loc.t(key + "_DESC"), 22, UIKit.INK_DIM))
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
	var price := UIKit.number("", 28, false, UIKit.GOLD_TEXT_GLASS)
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
		card.self_modulate = Color.WHITE
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
		price.add_theme_color_override("font_color", UIKit.GOLD_TEXT_GLASS if not b.disabled else UIKit.INK_DIM)
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
	# §1.2: the modal dim (slate @ SCRIM_MODAL), flat 0.97 modal (no world still outside the hub).
	var dim := ColorRect.new()
	dim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, UITokens.SCRIM_MODAL)
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
	panel.add_theme_stylebox_override("panel", UIKit.lux("modal", Vector2(40, 34)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var t := UIKit.heading(Loc.t("SETTINGS"), 40, UIKit.INK)
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
	var lv := UIKit.label(Loc.t("LANG_NAME"), 24, UIKit.GOLD_TEXT_GLASS)
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
	var ic := Icons.make(icon, 36.0, UIKit.GOLD_TEXT_GLASS)
	ic.position = Vector2(24, 16)
	b.add_child(ic)
	box.add_child(b)
	return b


## A settings row: icon, name, and on the right either a switch (on/off) or a gold value.
func _toggle(box: Control, key: String, icon: String, get_on: Callable, flip: Callable, on_key := "", off_key := "") -> void:
	var b := _setting_button(box, icon)
	b.text = Loc.t(key)
	var sw := Switch.new()
	var val := UIKit.label("", 24, UIKit.GOLD_TEXT_GLASS)
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
		# v3.1: chamfered glass planks in a 1 dpx hairline; the reached ones flat amber with a
		# 1 dpx table light (no gloss slab, no dark sockets).
		var lw := UIKit.line_px(1.0)
		for i in max_level:
			var r := Rect2(Vector2(i * (w + gap), 3), Vector2(w, size.y - 6))
			var pts := GemDraw.chamfer_rect(r, 2.5)
			if i < level:
				var cols := PackedColorArray()
				for q in pts:
					cols.append(UITokens.CTA_HI.lerp(UITokens.CTA_LO, (q.y - r.position.y) / maxf(r.size.y, 1.0)))
				draw_polygon(pts, cols)
				draw_line(r.position + Vector2(2, 1.0), Vector2(r.end.x - 2, r.position.y + 1.0), Color(1.0, 0.98, 0.9, 0.85), UIKit.px(1.0))
				GemDraw.outline(self, pts, Color(UITokens.CTA_RIM.r, UITokens.CTA_RIM.g, UITokens.CTA_RIM.b, 0.6), lw)
			else:
				draw_colored_polygon(pts, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.5))
				GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.7), lw)


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
		# v3.1 porcelain medallion: one halo, a cream glass ring, a 1 dpx gold line (1.5 dpx deep
		# gold when selected), the portrait on a soft disc of the hero colour (no dark rims).
		var sc := UITokens.SCRIM
		var tex2 := UIKit.glow_texture()
		if selected:
			draw_texture_rect(tex2, Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(color.r, color.g, color.b, 0.45))
		draw_texture_rect(tex2, Rect2(c - Vector2(r * 1.3, r * 1.15) + Vector2(0, 4), Vector2(r * 2.6, r * 2.6)), false, Color(sc.r, sc.g, sc.b, 0.22))
		var p0 := UITokens.PAPER_0
		draw_circle(c, r, Color(p0.r, p0.g, p0.b, 0.92), true, -1.0, true)
		var face := r - 6.0
		draw_circle(c, face, color.lightened(0.55), true, -1.0, true)
		draw_texture_rect(tex2, Rect2(c - Vector2(face, face), Vector2(face, face) * 2.0), false, Color(color.r, color.g, color.b, 0.55))
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
		var lw := UIKit.px(1.5) if selected else UIKit.line_px(1.0)
		draw_arc(c, face, 0, TAU, 64, Color(1, 1, 1, 0.7), UIKit.px(1.0), true)
		draw_arc(c, r - lw * 0.5, 0, TAU, 72, UITokens.LINE_GOLD_DEEP if selected else UITokens.LINE_GOLD, lw, true)
		draw_arc(c, r - UIKit.px(2.0), PI * 1.05, PI * 1.7, 24, Color(1, 1, 1, 0.8), UIKit.px(1.0), true)


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
		# v3.1 (§7.8): the slim kit toggle (56 x 28 track, 22 px knob, 1 dpx lines).
		KitToggle.draw_toggle(self, Rect2(Vector2.ZERO, size), _k)
