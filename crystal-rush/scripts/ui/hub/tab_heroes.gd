extends Control
## Герої tab (arsenal_design.md §4.1, §7.1; UI v2 "hero showcase", fusion §6.8 #3 / Genshin
## character screen): the hero big in 3D on a stage in its gem colour (Руді sapphire, Горан
## quartz, Мейра amethyst), the name and title as on-scene text (no outlines), the gem chip and
## the class / element / faction sockets (line icons in thin gold rings), a portrait rail on the
## right (tap or swipe to switch), then the cream bottom sheet with the arched top: text tabs
## Атрибути (level to the world cap + the three bonuses with the next level's gain, hairline
## rows) · Ульта (rank, milestone track Ult ranks 5/15/25 + Awakenings 10/20/30 in Meta-2) ·
## Аспекти (the three aspects, Lv1/10/20), and the dock: the coin plate + the amber
## «Покращити» (two taps: arm, confirm). Level-ups are micro ceremonies (flare, glints, a spin);
## an Ult rank is a toast. Locked heroes show their gem and when they join.

const HEROES: Array[String] = Balance.HERO_ORDER
const SHEET_H := 468.0          ## the sheet's content height (from its arched top to the page bottom)

## Hero identity (heroes_design.md §6 roster table): gem, class, element, faction, title.
const INFO := {
	"titan": {"gem": "quartz", "cls": "guardian", "el": "kinetic", "fac": "stoneheart", "title": ["Кам’яний велет", "The Stone Titan"]},
	"bolt": {"gem": "sapphire", "cls": "ranger", "el": "volt", "fac": "wildfang", "title": ["Громовий лис", "Thunder Fox"]},
	"seer": {"gem": "amethyst", "cls": "mage", "el": "rune", "fac": "wildfang", "title": ["Рись-містик", "Lynx Mystic"]},
}
## Strings this screen needs that Loc does not have yet (uk, en).
const T := {
	"GEM_QUARTZ": ["Кварц", "Quartz"], "GEM_SAPPHIRE": ["Сапфір", "Sapphire"], "GEM_AMETHYST": ["Аметист", "Amethyst"],
	"GEM_TOPAZ": ["Топаз", "Topaz"], "GEM_OPAL": ["Опал", "Opal"],
	"CLS_WARRIOR": ["Воїн", "Warrior"], "CLS_RANGER": ["Стрілець", "Ranger"], "CLS_MAGE": ["Маг", "Mage"],
	"CLS_GUARDIAN": ["Страж", "Guardian"], "CLS_HEALER": ["Цілитель", "Healer"],
	"FAC_DAWN": ["Орден Світанку", "Dawn Order"], "FAC_WILDFANG": ["Дикі Ікла", "Wildfang"],
	"FAC_STONEHEART": ["Кам’яне Серце", "Stoneheart"], "FAC_CELESTIAL": ["Небожителі", "Celestials"],
	"H_CLASS": ["Клас", "Class"], "H_ELEMENT": ["Стихія", "Element"], "H_FACTION": ["Фракція", "Faction"],
	"H_TAB_ATTR": ["Атрибути", "Attributes"], "H_TAB_ULT": ["Ульта", "Ultimate"], "H_TAB_ASPECT": ["Аспекти", "Aspects"],
	"H_LEVEL": ["Рів.", "Lv"], "H_CAP": ["Межа світу", "World cap"],
	"H_DMG": ["Шкода героя", "Hero damage"], "H_HP": ["Стійкість", "Toughness"], "H_ULT": ["Ранг ульти", "Ult rank"],
	"H_ULT_EFFECT": ["Сила ульти +%d%%", "Ult power +%d%%"], "H_MILESTONES": ["Віхи", "Milestones"],
	"H_ASPECT_ON": ["Активний", "Active"], "H_ASPECT_AT": ["Рів. %d · скоро", "Lv %d · soon"],
	"H_UPGRADE": ["Покращити", "Upgrade"], "H_CONFIRM": ["Підтвердити", "Confirm"],
	"H_NEXT": ["Рів. %d → %d", "Lv %d → %d"], "H_SELECT": ["Обрати", "Select"],
	"ASP_FORKED_FOX": ["Розгалужений лис", "Forked Fox"], "ASP_RAILSHOT": ["Рейковий постріл", "Railshot"],
	"ASP_STORM_FOX": ["Грозовий лис", "Storm Fox"], "ASP_BULWARK": ["Бастіон", "Bulwark"],
	"ASP_SEISMIC": ["Сейсміка", "Seismic"], "ASP_CRYSTAL_COLOSSUS": ["Кришталевий колос", "Crystal Colossus"],
	"ASP_FORESIGHT": ["Передбачення", "Foresight"], "ASP_STARWEAVE": ["Зоряне плетиво", "Starweave"],
	"ASP_ECLIPSE": ["Затемнення", "Eclipse"],
	"ASPD_RAILSHOT": ["Удари пронизують коридор: −30% темпу, +80% шкоди", "Hits pierce the corridor: −30% rate, +80% damage"],
	"ASPD_STORM_FOX": ["Кожен 6-й удар кличе малу бурю", "Every 6th hit calls a small storm"],
	"ASPD_SEISMIC": ["Удар посилає хвилю, що спиняє загін", "Each hit sends a staggering wave"],
	"ASPD_CRYSTAL_COLOSSUS": ["Удари лишають кришталеві шипи на 3 с", "Hits leave crystal spikes for 3 s"],
	"ASPD_STARWEAVE": ["Сфери сплітаються в зоряну сітку", "The orbs weave a star net"],
	"ASPD_ECLIPSE": ["Розлом затьмарює все попереду", "The rift darkens everything ahead"],
}

var hub: Hub
var _idx := 0
var _stage: _HeroStage
var _show: HubShowcase
var _head: VBoxContainer
var _gem_chip: PanelContainer
var _name: Label
var _title: Label
var _sockets: HBoxContainer
var _pick_row: HBoxContainer
var _rail: VBoxContainer
var _sheet: KitSheet
var _tabs: KitTabs
var _tab := "attr"
var _pages_box: Control
var _pages := {}
var _dock: HBoxContainer
var _armed := false
var _lvl_btn: KitCTA
var _cost: KitCurrencyPlate
var _lv_num: Label
var _drag_x := -1.0
static var _portraits := {}     ## hero id -> Texture2D (rendered once per session)


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = T.get(key, [key, key])
	return str(row[0] if Loc.lang == "uk" else row[1])


static func info(id: String) -> Dictionary:
	return INFO.get(id, {"gem": "quartz", "cls": "warrior", "el": "kinetic", "fac": "dawn", "title": ["", ""]})


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idx = maxi(0, HEROES.find(Meta.hero()))
	# The stage paints the whole screen behind the page (under the top bar and the nav too).
	_stage = _HeroStage.new()
	_stage.page = self
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	# The hero on the dais: big, centred a little left of the rail.
	# Framed by height (Genshin: the character fills the art band), pushed to x ~60 % so the
	# name block keeps its left column.
	_show = HubShowcase.new("hero")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.offset_top = -40.0
	_show.offset_left = 170.0
	_show.offset_right = -20.0
	_show.gui_input.connect(_swipe)
	add_child(_show)
	# Name block (top left, on the scene).
	_head = VBoxContainer.new()
	_head.position = Vector2(UITokens.GUTTER, 4)
	_head.add_theme_constant_override("separation", 4)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head)
	_gem_chip = PanelContainer.new()
	_gem_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_head.add_child(_gem_chip)
	_name = UIKit.scene_label("", 56)
	UIKit.scene_halo(_name, 0.45, 1.15)
	_head.add_child(_name)
	# The title in warm white on the scene (gold caps were 1.2-2.2:1 on quartz / sapphire).
	_title = UIKit.label("", 22, UIKit.ON_SCENE, true)
	_title.add_theme_font_override("font", UIKit.font_caps(22))
	UIKit.soft_shadow(_title, 22, 1.6)
	UIKit.scene_halo(_title, 0.7, 1.1)
	_head.add_child(_title)
	_head.add_child(UIKit.gap(6))
	_sockets = HBoxContainer.new()
	_sockets.add_theme_constant_override("separation", 10)
	_head.add_child(_sockets)
	_head.add_child(UIKit.gap(8))
	_pick_row = HBoxContainer.new()
	_pick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_pick_row)
	# Portrait rail (right edge).
	_rail = VBoxContainer.new()
	_rail.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rail.position = Vector2(-UITokens.GUTTER - 76.0, 12.0)
	_rail.add_theme_constant_override("separation", 14)
	add_child(_rail)
	for i in HEROES.size():
		var it := _RailItem.new()
		it.hero = HEROES[i]
		it.gem = str(info(HEROES[i])["gem"])
		it.tex = _portraits.get(HEROES[i])
		it.custom_minimum_size = Vector2(76, 76)
		it.pressed.connect(func(): _goto(i))
		_rail.add_child(it)
	# The cream sheet: from its arched top down to the screen bottom (behind the nav); the
	# content stops at the page bottom.
	_sheet = UIKit.sheet(Vector2(UITokens.GUTTER, 14))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_sheet.add_child(col)
	_tabs = UIKit.tabs([["attr", tr2("H_TAB_ATTR")], ["ult", tr2("H_TAB_ULT")], ["aspect", tr2("H_TAB_ASPECT")]], _tab, _on_tab, 24)
	col.add_child(_tabs)
	_pages_box = Control.new()
	_pages_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_pages_box)
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 14)
	_dock.custom_minimum_size.y = 96
	col.add_child(_dock)
	var foot := UIKit.gap(0)
	foot.name = "Foot"
	col.add_child(foot)
	resized.connect(_layout)
	_layout()
	_layout.call_deferred()
	_load_portraits()
	refresh()
	UIJuice.sheet_in(_sheet)


func _layout() -> void:
	# The sheet keeps its chrome; tall phones give the extra height to the stage. Placed by hand
	# (not anchored) so an early zero-size layout cannot grow its offsets.
	var below := _below_page()
	_sheet.position = Vector2(-2.0, size.y - SHEET_H)
	_sheet.size = Vector2(size.x + 4.0, SHEET_H + below)
	var foot := _sheet.get_child(0).get_node_or_null("Foot") as Control
	if foot:
		foot.custom_minimum_size.y = maxf(0.0, below - 12.0)
	_show.offset_bottom = -SHEET_H + 78.0
	# Tall phones: the art band grows and the hero (framed by height) grows with it.
	_show.offset_top = 60.0
	_stage.queue_redraw()


## Canvas px between the page bottom and the screen bottom (the nav zone).
func _below_page() -> float:
	if not is_inside_tree():
		return UITokens.TAB_BAR_H + 34.0
	var vp := get_viewport().get_visible_rect().size
	return maxf(0.0, vp.y - get_global_rect().end.y)


func on_show() -> void:
	refresh()


func _load_portraits() -> void:
	for id in HEROES:
		if _portraits.has(id):
			continue
		_render_portrait(id)


func _render_portrait(id: String) -> void:
	var tex := await UIKit.render_portrait(self, id, 160)
	if tex == null or not is_instance_valid(self):
		return
	_portraits[id] = tex
	for it in _rail.get_children():
		if (it as _RailItem).hero == id:
			(it as _RailItem).tex = tex
			(it as _RailItem).queue_redraw()


func _swipe(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag_x = e.position.x
		elif _drag_x >= 0.0:
			var dx: float = e.position.x - _drag_x
			_drag_x = -1.0
			if absf(dx) > 70.0:
				_step(-1 if dx > 0 else 1)


func _step(d: int) -> void:
	_goto(posmod(_idx + d, HEROES.size()))


func _goto(i: int) -> void:
	if i == _idx:
		return
	_idx = i
	_armed = false
	Audio.play("click", -6.0)
	UIJuice.haptic("TICK", 0.4)
	refresh()
	UIJuice.soft_in(_head, Vector2(-16, 0))
	UIJuice.cross_fade(null, _pages_box)


## Shows hero `id` (dev tools / screenshots).
func show_hero(id: String) -> void:
	var i := HEROES.find(id)
	if i >= 0:
		_idx = i
		refresh()


## Selects a sheet tab ("attr" | "ult" | "aspect") (dev tools / screenshots).
func show_tab(t: String) -> void:
	_tabs.select(t, true)


func _on_tab(t: String) -> void:
	if t == _tab:
		return
	var old: Control = _pages.get(_tab)
	_tab = t
	var incoming: Control = _pages.get(t)
	if old:
		old.visible = false
	if incoming:
		UIJuice.cross_fade(null, incoming)


func refresh() -> void:
	if not is_node_ready():
		return
	var id := HEROES[_idx]
	var def: Dictionary = Balance.HEROES[id]
	var inf := info(id)
	var unlocked := Meta.hero_unlocked(id)
	var chosen := Meta.hero() == id
	_show.show_hero(id)
	# The dais crystals and the floor ring glow in the hero's gem, as on Home.
	_show.set_accent((UITokens.gem(str(inf["gem"]))["rim"] as Color))
	_stage.gem = str(inf["gem"])
	_stage.queue_redraw()
	# Head
	_clear(_gem_chip)
	_gem_chip.add_theme_stylebox_override("panel", UIKit.lux("chip", Vector2(10, 3)))
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 6)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gr.add_child(_GemMark.make(str(inf["gem"]), 24.0))
	gr.add_child(UIKit.label(tr2("GEM_" + str(inf["gem"]).to_upper()), 22, UIKit.INK))
	gr.add_child(UIKit.gap(2))
	_gem_chip.add_child(gr)
	var nm := Loc.t(str(def["name"]))
	_name.text = nm
	_name.add_theme_font_size_override("font_size", UIKit.fit_size(nm, 420.0, 56, 36))
	var ttl: Array = inf["title"]
	var title := str(ttl[0] if Loc.lang == "uk" else ttl[1])
	_title.text = title.to_upper() if title != nm else ""
	_title.visible = _title.text != ""
	_clear(_sockets)
	_sockets.add_child(_socket("cls_" + str(inf["cls"]), false, tr2("H_CLASS") + " · " + tr2("CLS_" + str(inf["cls"]).to_upper())))
	_sockets.add_child(_socket("el_" + str(inf["el"]), false, tr2("H_ELEMENT") + " · " + Loc.t("FAM_" + str(inf["el"]).to_upper())))
	_sockets.add_child(_socket("fac_" + str(inf["fac"]), false, tr2("H_FACTION") + " · " + tr2("FAC_" + str(inf["fac"]).to_upper())))
	# Lead chip / select button
	_clear(_pick_row)
	if chosen:
		var chip := UIKit.glass_panel(Vector2(14, 6))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 8)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ci := Icons.make("crown", 28.0)
		ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cr.add_child(ci)
		cr.add_child(UIKit.label(Loc.t("HERO_SELECTED"), 22, UIKit.INK))
		chip.add_child(cr)
		_pick_row.add_child(chip)
	elif unlocked:
		var sel := UIKit.secondary_button(tr2("H_SELECT"), "check", Vector2(186, 72), 22)
		sel.pressed.connect(func():
			Meta.set_hero(HEROES[_idx])
			UIJuice.haptic("THUD", 0.6)
			Audio.play("weapon_get", -6.0)
			_show.celebrate(0.6)
			UIKit.sparkles(self, _hero_center(), UITokens.gem(info(HEROES[_idx])["gem"])["light"], 18, 200.0)
			refresh())
		_pick_row.add_child(sel)
	# Rail
	for it in _rail.get_children():
		var ri := it as _RailItem
		ri.selected = ri.hero == id
		ri.locked = not Meta.hero_unlocked(ri.hero)
		ri.chosen = Meta.hero() == ri.hero
		ri.queue_redraw()
	_fill_sheet(id, unlocked)


## Frees `n`'s children now (detached first, so containers do not measure them meanwhile).
static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _socket(icon: String, slate: bool, tip: String) -> Control:
	var s := UIKit.socket(icon, 52.0, slate)
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	s.tooltip_text = tip
	s.pressed.connect(func():
		Audio.play("click", -10.0)
		hub.toast(tip))
	return s


## §4.6: the frost behind a modal over this tab leans toward the hero's gem light.
func page_tint() -> Color:
	return UITokens.gem(str(info(HEROES[_idx])["gem"]))["light"]


func _hero_center() -> Vector2:
	return _show.get_global_rect().get_center() - global_position + Vector2(0, -30)


# ------------------------------------------------------------------ sheet

func _fill_sheet(id: String, unlocked: bool) -> void:
	_clear(_pages_box)
	_pages.clear()
	_clear(_dock)
	_lvl_btn = null
	_cost = null
	_lv_num = null
	_pages["attr"] = _attr_page(id, unlocked)
	_pages["ult"] = _ult_page(id, unlocked)
	_pages["aspect"] = _aspect_page(id, unlocked)
	for k: String in ["attr", "ult", "aspect"]:
		var p: Control = _pages[k]
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = k == _tab
		_pages_box.add_child(p)
	_build_dock(id, unlocked)


func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _attr_page(id: String, unlocked: bool) -> Control:
	var v := _page()
	var lvl := Meta.hero_level(id)
	var cap := Meta.hero_cap()
	if not unlocked:
		v.add_child(UIKit.gap(18))
		var at := int(EconData.HERO_UNLOCK.get(id, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var s := UIKit.socket("lock", 56.0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(s)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l1 := UIKit.label(Loc.f("HERO_LOCKED", [at]), 24, UIKit.INK, true)
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(l1)
		var l2 := UIKit.label(Loc.t(str(Balance.HEROES[id]["desc"])), 22, UIKit.INK_DIM)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(l2)
		row.add_child(tv)
		v.add_child(row)
		return v
	# Level: «Рів. 5 / 12» and the bar to the world cap.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.custom_minimum_size.y = 72
	var lw := UIKit.label(tr2("H_LEVEL"), 22, UIKit.INK_DIM, true)
	lw.size_flags_vertical = Control.SIZE_SHRINK_END
	lw.custom_minimum_size.y = 50
	top.add_child(lw)
	_lv_num = UIKit.number(str(lvl), 52)
	_lv_num.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_lv_num)
	var cw := UIKit.label("/ %d" % cap, 24, UIKit.INK_DIM, true)
	cw.size_flags_vertical = Control.SIZE_SHRINK_END
	cw.custom_minimum_size.y = 50
	top.add_child(cw)
	top.add_child(UIKit.spacer())
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	var cl := UIKit.caps("%s · %d" % [tr2("H_CAP"), cap], 20, UIKit.INK_DIM)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cl)
	var bar := UIKit.progress(lvl, cap, 290.0, 10.0)
	right.add_child(bar)
	top.add_child(right)
	v.add_child(top)
	v.add_child(UIKit.hairline())
	# Bonuses now and at the next level.
	var now := EconData.hero_mults(lvl)
	var nxt := EconData.hero_mults(lvl + 1) if lvl < cap else {}
	var ult_rank := int(now["ult_rank"])
	var dmg := int(round((float(now["dmg_mult"]) - 1.0) * 100.0))
	var hp := int(round((float(now["hp_mult"]) - 1.0) * 100.0))
	v.add_child(_stat_row("cls_warrior", tr2("H_DMG"), "+%d%%" % dmg, float(nxt.get("dmg_mult", 0.0)) - float(now["dmg_mult"])))
	v.add_child(_stat_row("cls_guardian", tr2("H_HP"), "+%d%%" % hp, float(nxt.get("hp_mult", 0.0)) - float(now["hp_mult"])))
	var nr := int(nxt.get("ult_rank", ult_rank))
	v.add_child(_stat_row("el_" + str(info(id)["el"]), tr2("H_ULT"), _roman(ult_rank), 0.0, _roman(nr) if nr > ult_rank else ""))
	return v


## A list row (no box, hairline under it): line icon, name, value and the next level's gain.
func _stat_row(icon: String, text: String, value: String, delta: float, delta_text := "") -> Control:
	var r := UIKit.list_row(text, value, icon)
	r.custom_minimum_size.y = 60
	var dt := delta_text
	if dt == "" and delta > 0.0005:
		dt = "+%d%%" % int(round(delta * 100.0))
	var d := UIKit.label(("→ " + dt) if delta_text != "" else dt, 22, UIKit.PLUS)
	d.custom_minimum_size.x = 76
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_FILL
	d.visible = dt != ""
	r.add_child(d)
	if not d.visible:
		r.add_child(UIKit.gap(76))
	return r


func _ult_page(id: String, unlocked: bool) -> Control:
	var v := _page()
	var def: Dictionary = Balance.HEROES[id]
	var u: Dictionary = def["ult"]
	var lvl := Meta.hero_level(id) if unlocked else 0
	var rank := EconData.hero_ult_rank(maxi(lvl, 1))
	v.add_child(UIKit.gap(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var s := UIKit.socket("el_" + str(info(id)["el"]), 60.0, true)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.label(Loc.t(str(u["name"])).trim_suffix("!"), 26, UIKit.INK, true))
	var bonus := int(round(float(EconData.HERO["ult_rank_bonus"]) * 100.0 * (rank - 1)))
	var sub := Loc.f("ULT_RANK", [_roman(rank)])
	if bonus > 0:
		sub += " · " + tr2("H_ULT_EFFECT") % bonus
	tv.add_child(UIKit.label(sub, 22, UIKit.INK_DIM))
	row.add_child(tv)
	v.add_child(row)
	v.add_child(UIKit.gap(10))
	v.add_child(UIKit.hairline())
	v.add_child(UIKit.gap(12))
	v.add_child(UIKit.section(tr2("H_MILESTONES"), 20))
	var ms := _Milestones.new()
	ms.lvl = lvl
	ms.custom_minimum_size = Vector2(0, 96)
	v.add_child(ms)
	return v


func _aspect_page(id: String, unlocked: bool) -> Control:
	var v := _page()
	var list: Array = EconData.HERO_ASPECTS.get(id, [])
	var at: Array = EconData.HERO["aspect_at"]
	for i in list.size():
		var a := str(list[i])
		var on := i == 0 and unlocked
		var r := UIKit.KitRow.new()
		r.custom_minimum_size = Vector2(0, 80)
		r.add_theme_constant_override("separation", 14)
		var s := UIKit.socket("el_" + str(info(id)["el"]) if i == 0 else "lock", 48.0, i == 0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.modulate = Color.WHITE if i == 0 else Color(1, 1, 1, 0.7)
		r.add_child(s)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(tr2("ASP_" + a.to_upper()), 24, UIKit.INK if i == 0 else UIKit.INK_DIM, true))
		var desc := Loc.t(str(Balance.HEROES[id]["desc"])) if i == 0 else tr2("ASPD_" + a.to_upper())
		var dl := UIKit.label(desc, 22, UIKit.INK_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(dl)
		r.add_child(tv)
		var tag := UIKit.label(tr2("H_ASPECT_ON") if on else tr2("H_ASPECT_AT") % int(at[i] if i < at.size() else 1), 22, UIKit.PLUS if on else UIKit.INK_DIM)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(tag)
		v.add_child(r)
	return v


func _build_dock(id: String, unlocked: bool) -> void:
	if not unlocked:
		var lbl := UIKit.label(Loc.f("HERO_LOCKED", [int(EconData.HERO_UNLOCK.get(id, 0))]), 22, UIKit.INK_DIM, true)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_FILL
		_dock.add_child(lbl)
		return
	var lvl := Meta.hero_level(id)
	var cap := Meta.hero_cap()
	var cost := Meta.hero_cost(id)
	var can := Meta.can_level_hero(id)
	_cost = UIKit.currency_plate("coin", Loc.num(cost) if cost > 0 else Loc.t("FREE"), false, 186.0)
	_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_cost)
	_lvl_btn = UIKit.cta_button(tr2("H_UPGRADE"), "", Vector2(0, 92), 34)
	_lvl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lvl_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dock.add_child(_lvl_btn)
	if lvl >= cap:
		_cost.visible = false
		_lvl_btn.text = Loc.t("LV_MAX")
		_lvl_btn.sub = Loc.t("HERO_MAX_WORLD")
		_lvl_btn.sub_size = 17
		_lvl_btn.disabled = true
	else:
		_lvl_btn.sub = tr2("H_NEXT") % [lvl, lvl + 1] if cost > 0 else Loc.t("HERO_FREE_LEVEL")
		if _armed and can:
			_lvl_btn.text = tr2("H_CONFIRM")
		if not can and cost > Meta.currency("coins"):
			var plate := _cost
			plate.ready.connect(func(): plate.value_label.add_theme_color_override("font_color", UIKit.ALERT))
			_lvl_btn.sub = Loc.t("NEED_COINS")
	_lvl_btn.pressed.connect(_press_level.bind(id))


## The dock's upgrade press (dev tools / screenshots call it too).
func press_upgrade() -> void:
	if is_instance_valid(_lvl_btn) and not _lvl_btn.disabled:
		_press_level(HEROES[_idx])


func _press_level(id: String) -> void:
	if not Meta.can_level_hero(id):
		Audio.play("error", -6.0)
		UIJuice.wobble(_lvl_btn, 0.3, 0.3)
		if is_instance_valid(_cost):
			UIJuice.chip_hit(_cost)
		return
	if not _armed:
		_armed = true
		UIJuice.haptic("CLICK", 0.5)
		_lvl_btn.text = tr2("H_CONFIRM")
		UIJuice.punch(_lvl_btn, 1.04, 0.18)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(self) and _armed:
				_armed = false
				if is_instance_valid(_lvl_btn):
					_lvl_btn.text = tr2("H_UPGRADE"))
		return
	_armed = false
	var res := Meta.level_hero(id)
	if not bool(res.get("ok", false)):
		Audio.play("error", -6.0)
		return
	var ms := str(res.get("milestone", ""))
	var tier := "full" if ms != "" else "micro"
	Audio.play("upgrade", -2.0)
	var center := _hero_center()
	var g: Dictionary = UITokens.gem(info(id)["gem"])
	UIJuice.flare(self, center, Color(1.0, 0.8, 0.42), tier, 140.0)
	UIKit.sparkles(self, center, g["light"], 26 if tier == "full" else 14, 240.0)
	_show.celebrate(0.8)
	if ms == "ult_rank":
		hub.toast(Loc.f("ULT_RANK", [_roman(int(EconData.hero_ult_rank(int(res["lvl"]))))]) + "!", "arrow_up")
	refresh()
	if is_instance_valid(_lv_num):
		var n := _lv_num
		n.resized.connect(func(): n.pivot_offset = n.size * 0.5, CONNECT_ONE_SHOT)
		UIJuice.punch(n, 1.25, 0.22)


static func _roman(n: int) -> String:
	return ["I", "II", "III", "IV", "V"][clampi(n - 1, 0, 4)]


# ------------------------------------------------------------------ widgets

## The page backdrop: a stage in the hero's gem colour (the ground gradient lifted toward the
## gem's light, a light pool behind the hero, that gem's fracture planes, a soft warm floor
## under the dais), a slate whisper under the top plates. Paints the whole screen behind the
## page; the cream sheet (KitSheet) covers the lower part.
class _HeroStage extends Control:
	const HAZE := 0.55
	var page: Control
	var gem := "sapphire"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var vp := get_viewport().get_visible_rect().size
		var gp := get_global_rect().position
		var full := Rect2(-gp, vp)
		var g: Dictionary = UITokens.gem(gem)
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		var lc: Color = g["light"]
		var w := full.size.x
		var x0 := full.position.x
		var y0 := full.position.y
		var sheet_y := size.y - SHEET_H
		# Airy gem ground: the gem's own gradient, lifted toward its light low on the stage.
		# Quartz is a pale stone: lift it further so the stage stays airy, not concrete grey.
		var lift := 0.3 if gem == "quartz" else 0.0
		var c_top := top.lerp(bot, 0.2).lerp(lc, lift * 0.6)
		var c_mid := top.lerp(bot, 0.75).lerp(lc, 0.12 + lift)
		var c_low := bot.lerp(lc, 0.45 + lift * 0.5)
		if gem == "opal":
			c_top = top
			c_mid = bot
			c_low = bot.lerp(Color("#6B5AA6"), 0.4)
		# v3.1 (§4.5): the haze alphas x 0.55, so the hub's frosted world shows through the stage.
		c_top.a *= HAZE
		c_mid.a *= HAZE
		c_low.a *= HAZE
		var ym := lerpf(y0, sheet_y, 0.5)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, ym), Vector2(x0, ym)]), PackedColorArray([c_top, c_top, c_mid, c_mid]))
		draw_polygon(PackedVector2Array([Vector2(x0, ym), Vector2(x0 + w, ym), Vector2(x0 + w, size.y + 40.0), Vector2(x0, size.y + 40.0)]), PackedColorArray([c_mid, c_mid, c_low, c_low]))
		# Light pool behind the hero + a soft top light.
		var cx := size.x * 0.56
		var cy := lerpf(60.0, sheet_y, 0.5)
		var R := w * 0.6
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - R, cy - R), Vector2(R, R) * 2.0), false, Color(lc.r, lc.g, lc.b, 0.55))
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - R * 0.45, cy - R * 0.55), Vector2(R * 0.9, R * 0.9)), false, Color(1, 1, 1, 0.25))
		KitGemCard.draw_stage_fracture(self, gem, Rect2(Vector2(x0, y0), Vector2(w, sheet_y - y0 + 20.0)))
		if gem == "opal":
			var fl: Array = g["flecks"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in 40:
				var p := Vector2(x0 + rng.randf() * w, y0 + rng.randf() * (sheet_y - y0))
				var fc: Color = fl[i % fl.size()]
				var rr := rng.randf_range(3.0, 9.0)
				draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(rr, rr) * 2.0, Vector2(rr, rr) * 4.0), false, Color(fc.r, fc.g, fc.b, 0.35))
		# A warm floor glow where the dais stands.
		var fy := sheet_y - 40.0
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - w * 0.42, fy - 70.0), Vector2(w * 0.84, 140.0)), false, Color(1.0, 0.96, 0.86, 0.35))
		# Soft side vignette and a slate whisper under the top plates (header text sits there).
		var vg := Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.14)
		var cl := Color(vg.r, vg.g, vg.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + 70, y0), Vector2(x0 + 70, size.y), Vector2(x0, size.y)]), PackedColorArray([vg, cl, cl, vg]))
		draw_polygon(PackedVector2Array([Vector2(x0 + w - 70, y0), Vector2(x0 + w, y0), Vector2(x0 + w, size.y), Vector2(x0 + w - 70, size.y)]), PackedColorArray([cl, vg, vg, cl]))
		var sc := Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.2)
		var sc0 := Color(sc.r, sc.g, sc.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, 200.0), Vector2(x0, 200.0)]), PackedColorArray([sc, sc, sc0, sc0]))


## A portrait on the right rail: the hero's painted close-up in a disc on its gem ground, a
## thin gold ring (two rings + a keystone when it is the one shown), the crown when it leads
## the army, a lock when it has not joined yet.
class _RailItem extends Control:
	signal pressed
	var hero := "bolt"
	var gem := "sapphire"
	var tex: Texture2D
	var selected := false
	var locked := false
	var chosen := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e):
			pressed.emit()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var g: Dictionary = UITokens.gem(gem)
		for i in 3:
			draw_circle(c + Vector2(0, 2.0 + i), r + i, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.07))
		draw_circle(c, r, UITokens.PAPER_1)
		var ir := r - 4.0
		draw_circle(c, ir, (g["top"] as Color).lerp(g["bot"], 0.6))
		var lc: Color = g["light"]
		draw_circle(c + Vector2(0, ir * 0.35), ir * 0.7, Color(lc.r, lc.g, lc.b, 0.35))
		if tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * ir)
				uvs.append(Vector2(0.5, 0.5) + d * 0.5 * 0.86 + Vector2(0, -0.02))
			var tint := Color(0.5, 0.52, 0.58, 0.85) if locked else Color.WHITE
			draw_colored_polygon(pts, tint, uvs, tex)
		# v3 lines: a 1 dpx gold ring (1.5 dpx deep gold when shown), a light line inside.
		var ring := UITokens.HAIRLINE if not selected else UITokens.LINE_GOLD_DEEP
		draw_arc(c, r - 0.75, 0, TAU, 64, ring, UIKit.line_px(1.5 if selected else 1.0), true)
		draw_arc(c, ir, 0, TAU, 64, Color(1, 1, 1, 0.6), UIKit.px(1.0), true)
		if selected:
			draw_arc(c, r + 3.0, 0, TAU, 64, Color(1.0, 0.97, 0.88, 0.9), UIKit.px(1.0), true)
			GemDraw.draw_keystone(self, Vector2(c.x - r - 6.0, c.y), 9.0)
		else:
			draw_circle(c, r, Color(UITokens.PAPER_1.r, UITokens.PAPER_1.g, UITokens.PAPER_1.b, 0.18))
		if locked:
			var lc2 := c + Vector2(r * 0.62, r * 0.62)
			draw_circle(lc2, 13.0, UITokens.PAPER_0)
			draw_arc(lc2, 12.5, 0, TAU, 40, UITokens.HAIRLINE, UIKit.line_px(1.0), true)
			Icons.line(self, "lock", Rect2(lc2 - Vector2(8, 8), Vector2(16, 16)), UITokens.INK)
		elif chosen:
			var cc := c + Vector2(r * 0.66, -r * 0.66)
			draw_circle(cc, 14.0, UITokens.PAPER_0)
			draw_arc(cc, 13.5, 0, TAU, 40, UITokens.HAIRLINE, UIKit.line_px(1.0), true)
			Icons.draw_icon(self, "crown", Rect2(cc - Vector2(10, 10), Vector2(20, 20)))


## A gem-cut rarity mark (GemDraw.draw_mark in a gold bezel) as a Control.
class _GemMark extends Control:
	var gem := "quartz"

	static func make(g: String, px: float) -> _GemMark:
		var m := _GemMark.new()
		m.gem = UITokens.gem_of(g)
		m.custom_minimum_size = Vector2(px, px)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return m

	func _draw() -> void:
		GemDraw.draw_mark(self, gem, size * 0.5, minf(size.x, size.y) * 0.82)


## Ult ranks (Lv5/15/25) and Awakenings (10/20/30, Meta-2) on a fine track: a gold hairline
## with the reached part in amber, rhombus pips for ranks (lit topaz when reached), crystal
## keystones for Awakenings (dim, «Скоро»), ink labels and taupe level numbers.
class _Milestones extends Control:
	var lvl := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fm := UIKit.font_w("medium")
		var x0 := 34.0
		var x1 := size.x - 34.0
		var y := 30.0
		var mx := float(EconData.HERO["max"])
		y = GemDraw.pixel_y(self, y)
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), UIKit.line_px(1.0))
		var xl := lerpf(x0, x1, clampf(float(lvl - 1) / (mx - 1.0), 0.0, 1.0))
		if lvl > 1:
			draw_line(Vector2(x0, y), Vector2(xl, y), Color(UITokens.CTA_LO.r, UITokens.CTA_LO.g, UITokens.CTA_LO.b, 0.9), UIKit.line_px(1.5))
		GemDraw.draw_marquise(self, Vector2(x0 - 4.0, y), Vector2(-1, 0), 10.0)
		GemDraw.draw_marquise(self, Vector2(x1 + 4.0, y), Vector2(1, 0), 10.0)
		var marks: Array = []
		var ranks: Array = EconData.HERO["ult_rank_at"]
		for i in ranks.size():
			if int(ranks[i]) > 1:
				marks.append([int(ranks[i]), Loc.f("MS_ULT", [["I", "II", "III", "IV", "V"][clampi(i, 0, 4)]]), true])
		var aw: Array = EconData.HERO["awakening_at"]
		for j in aw.size():
			marks.append([int(aw[j]), Loc.t("SOON"), false])
		# Labels only on the next two ult ranks (no "Скоро" chatter); the rest are quiet pips.
		var labelled := 0
		for m: Array in marks:
			if bool(m[2]) and lvl < int(m[0]) and labelled < 2:
				m.append(true)
				labelled += 1
		for m: Array in marks:
			var l := int(m[0])
			var x := lerpf(x0, x1, float(l - 1) / (mx - 1.0))
			var done := lvl >= l
			var live := bool(m[2])
			var p := Vector2(x, y)
			if live:
				draw_circle(p, 13.0, UITokens.PAPER_1)
				GemDraw.draw_pip(self, p, 22.0, done, UITokens.TOPAZ)
			else:
				draw_circle(p, 11.0, UITokens.PAPER_1)
				GemDraw.draw_keystone(self, p, 16.0, 0.55)
			if m.size() < 4:
				continue
			var t := str(m[1])
			var fs := 22
			var tw := fm.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(fm, Vector2(clampf(x - tw * 0.5, 0, size.x - tw), y + 40), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
			var lt := Loc.f("LV", [l])
			var lw := fm.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(fm, Vector2(clampf(x - lw * 0.5, 0, size.x - lw), y + 66), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DIM)
