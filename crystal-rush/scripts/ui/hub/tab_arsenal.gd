extends Control
## Арсенал tab (arsenal_design.md §7.1-7.2; UI v2: fusion §6.8 "5. Arsenal", ui_v2_contract):
## a sunlit workshop stage on top (warm haze, a soft light pool in the selected machine's gem
## colour, the machine on the 3D turntable; its name in ink, a gem-cut rarity chip, a family
## socket chip, the level, the next milestone on a porcelain chip), then a cream sheet with an
## arched top (the bridge span + keystone) holding the sub-tabs Машини · Колода, the filters as
## Genshin underline tabs, and the 4-column grid of rarity cards (MachineCard; tap opens
## MachineDetail). The Best-upgrade plate is pinned at the bottom (one pre-selected upgrade; the
## compact amber CTA opens its two-tap confirm; never spent automatically).

const FILTERS := [["all", "FILTER_ALL"], ["owned", "FILTER_OWNED"], ["upgradable", "FILTER_UPGRADABLE"]]
const STRIP_H := 300.0
const COLS := 4
const CARD := Vector2(156, 200)

var hub: Hub
var selected_id := ""
var _sub := "machines"
var _filter := "all"
var _stage: _Stage
var _strip: Control
var _show: HubShowcase
var _name: Label
var _meta_row: HBoxContainer
var _lv: Label
var _milestone: PanelContainer
var _milestone_lbl: Label
var _seg: PanelContainer
var _machines_view: VBoxContainer
var _filters: KitTabs
var _grid: GridContainer
var _count_lbl: Label
var _scroll: ScrollContainer
var _deck: DeckEditor
var _best: PanelContainer
var _best_wrap: MarginContainer
var _cards := {}             ## id -> MachineCard
var _info: VBoxContainer
var _first_fill := true


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = _Stage.new()
	_stage.page = self
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# Showcase strip (the art band: grows a little on tall phones, the chrome does not).
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(0, STRIP_H)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_strip)
	_show = HubShowcase.new("machine")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.offset_top = -4
	_show.offset_bottom = 10
	_show.tapped.connect(func():
		if selected_id != "":
			hub.open_machine(selected_id))
	_strip.add_child(_show)
	var info := VBoxContainer.new()
	_info = info
	info.position = Vector2(UITokens.GUTTER, 2)
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(info)
	_name = UIKit.gradient_heading("", 40)
	info.add_child(_name)
	_meta_row = HBoxContainer.new()
	_meta_row.add_theme_constant_override("separation", 8)
	_meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_meta_row)
	_lv = UIKit.number("", 34)
	_lv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lv.position = Vector2(-UITokens.GUTTER - 150, 6)
	_lv.size = Vector2(150, 44)
	_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_strip.add_child(_lv)
	_milestone = UIKit.glass_panel(Vector2(18, 7))
	_milestone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mi := Icons.make("events", 24.0, UIKit.GOLD_TEXT)
	mi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mrow.add_child(mi)
	_milestone_lbl = UIKit.label("", 20, UIKit.INK)
	mrow.add_child(_milestone_lbl)
	_milestone.add_child(mrow)
	_strip.add_child(_milestone)
	# Sub-tabs on the cream sheet (the sheet's arched top is painted by _Stage).
	var seg_row := HBoxContainer.new()
	seg_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seg_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg_row.custom_minimum_size.y = 58
	_seg = UIKit.segmented([["machines", Loc.t("SUB_MACHINES")], ["deck", Loc.t("SUB_DECK")]], _sub, func(id: String): show_sub(id), 56.0, 24)
	_seg.custom_minimum_size = Vector2(420, 0)
	_seg.size_flags_vertical = Control.SIZE_SHRINK_END
	seg_row.add_child(_seg)
	col.add_child(seg_row)
	# Machines view
	_machines_view = VBoxContainer.new()
	_machines_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_machines_view.add_theme_constant_override("separation", 0)
	_machines_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_machines_view)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	frow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frow.add_child(UIKit.gap(UITokens.GUTTER - 12))
	var opts: Array = []
	for o: Array in FILTERS:
		opts.append([o[0], Loc.t(o[1])])
	_filters = UIKit.tabs(opts, _filter, func(id: String):
		_filter = id
		_fill_grid()
		_scroll.scroll_vertical = 0, 22)
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(_filters)
	frow.add_child(UIKit.gap(8))
	_count_lbl = UIKit.label("", 20, UIKit.INK_DIM, true)
	_count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frow.add_child(_count_lbl)
	frow.add_child(UIKit.gap(UITokens.GUTTER - 12))
	_machines_view.add_child(frow)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_machines_view.add_child(_scroll)
	UIKit.scroll_fade(_scroll, Color("#F2EBDF"), 30.0, 16.0)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 22)
	cc.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 26)
	pad.add_child(_grid)
	# Deck view
	_deck = DeckEditor.new()
	_deck.setup(hub)
	_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck.visible = false
	col.add_child(_deck)
	# Best upgrade plate
	_best = UIKit.panel("plate", Vector2(16, 10))
	_best_wrap = MarginContainer.new()
	_best_wrap.add_theme_constant_override("margin_left", UITokens.GUTTER - 8)
	_best_wrap.add_theme_constant_override("margin_right", UITokens.GUTTER - 8)
	_best_wrap.add_theme_constant_override("margin_bottom", 2)
	_best_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_best_wrap.add_child(_best)
	col.add_child(_best_wrap)
	resized.connect(_on_resized)
	_on_resized()
	refresh()


func _on_resized() -> void:
	# Tall phones: the stage grows a little (up to +120 px); the sheet keeps its chrome.
	var extra := clampf((size.y - 994.0) * 0.4, 0.0, 120.0)
	# Deck mode: the slots already show the machines, so the stage folds to a short strip and
	# the list gets the room (two full rows at 720).
	_strip.custom_minimum_size.y = (24.0 + extra * 0.3) if _sub == "deck" else STRIP_H + extra
	for n: Control in [_show, _info, _lv]:
		if n:
			n.visible = _sub != "deck"
	_place_milestone()
	_stage.queue_redraw()


func on_show() -> void:
	refresh()


func on_hide() -> void:
	pass


## Machines or Deck sub-tab.
func show_sub(id: String) -> void:
	var old: Control = _deck if _sub == "deck" else _machines_view
	_sub = id
	if _seg:
		UIKit.segmented_select(_seg, id)
	var incoming: Control = _deck if id == "deck" else _machines_view
	_best_wrap.visible = id == "machines"
	_on_resized()
	_milestone.visible = id != "deck" and not Meta.next_milestone().is_empty()
	if id == "deck":
		_deck.refresh()
	if old != incoming:
		old.visible = false
		UIJuice.cross_fade(null, incoming)
	else:
		incoming.visible = true


func refresh() -> void:
	if not is_node_ready():
		return
	if selected_id == "" or not Meta.owned(selected_id):
		selected_id = Meta.lead() if Meta.lead() != "" else (Meta.deck()[0] if not Meta.deck().is_empty() else "drone")
	_show_selected()
	_fill_grid()
	_fill_best()
	if _deck.visible:
		_deck.refresh()


func select(id: String) -> void:
	selected_id = id
	_show_selected()
	for k: String in _cards:
		(_cards[k] as MachineCard).selected = k == id


func _show_selected() -> void:
	var c := Meta.machine_card(selected_id)
	_show.show_machine(selected_id, int(c["lvl"]), str(c["locked"]) != "")
	_stage.gem = UITokens.gem_of(str(c["rarity"]))
	_stage.queue_redraw()
	_name.text = Loc.t(str(c["name"]))
	_name.add_theme_font_size_override("font_size", UIKit.fit_size(_name.text, 470.0, 40, 28))
	for ch in _meta_row.get_children():
		ch.queue_free()
	_meta_row.add_child(MachineDetail.rarity_chip(str(c["rarity"])))
	_meta_row.add_child(MachineDetail.family_chip(str(c["family"])))
	_lv.text = Loc.f("LV", [int(c["lvl"])]) if bool(c["owned"]) else ""
	var ms := Meta.next_milestone()
	_milestone.visible = not ms.is_empty() and _sub != "deck"
	if not ms.is_empty():
		var mname := Loc.t(str((ArsenalData.MACHINES[str(ms["id"])] as Dictionary)["name"]))
		# "Ще 2 рів. до віхи «Лідер»" (quotes avoid case agreement); the machine's name only
		# when the milestone belongs to another machine than the one on the stage.
		var line := Loc.f("BEAT_NEXT", [int(ms["levels_left"]), Loc.t("BEAT_" + str(ms["beat"]).to_upper())])
		_milestone_lbl.text = line if str(ms["id"]) == selected_id else "%s: %s" % [mname, line.substr(0, 1).to_lower() + line.substr(1)]
		await get_tree().process_frame
		_place_milestone()


func _place_milestone() -> void:
	if is_instance_valid(_milestone) and _milestone.visible:
		_milestone.size = _milestone.get_combined_minimum_size()
		_milestone.position = Vector2((size.x - _milestone.size.x) * 0.5, _strip.custom_minimum_size.y - _milestone.size.y - 14.0)


func _fill_grid() -> void:
	var list := Meta.machine_cards(_filter)
	# Deck first, then owned, then the ones to find, then Meta-2 ("Скоро").
	var rank := func(c: Dictionary) -> int:
		if bool(c["in_deck"]):
			return 0
		if bool(c["owned"]):
			return 1
		return 2 if str(c["locked"]) == "world" else 3
	var order: Array = []
	for i in list.size():
		order.append([rank.call(list[i]), i])
	order.sort()
	var keep := {}
	var idx := 0
	var fresh: Array = []
	for o: Array in order:
		var c: Dictionary = list[o[1]]
		var id := str(c["id"])
		keep[id] = true
		var mc: MachineCard = _cards.get(id)
		if mc == null:
			mc = MachineCard.new(c)
			mc.custom_minimum_size = CARD
			mc.pressed.connect(func(mid: String):
				select(mid)
				hub.open_machine(mid))
			_grid.add_child(mc)
			_cards[id] = mc
			fresh.append(mc)
		else:
			mc.set_card(c)
		mc.selected = id == selected_id
		_grid.move_child(mc, idx)
		idx += 1
	for id: String in _cards.keys():
		if not keep.has(id):
			(_cards[id] as Node).queue_free()
			_cards.erase(id)
	if not fresh.is_empty() and is_visible_in_tree():
		UIJuice.cards_in(fresh, 0.05 if _first_fill else 0.0)
	_first_fill = false
	var owned := Meta.owned_ids().size()
	_count_lbl.text = Loc.f("OWNED_COUNT", [owned, ArsenalData.live_ids().size()])


func _fill_best() -> void:
	for ch in _best.get_children():
		ch.queue_free()
	var b := Meta.best_upgrade()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_best.add_child(row)
	if b.is_empty():
		var l := UIKit.label(Loc.t("NOTHING_TO_UPGRADE"), 22, UIKit.INK_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.y = 64
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		return
	var kind := str(b["kind"])
	var id := str(b["id"])
	var medal := _BestMedal.new()
	medal.kind = kind
	medal.id = id
	medal.custom_minimum_size = Vector2(68, 68)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.section(Loc.t("BEST_UPGRADE"), 18))
	var title := "%s · %s" % [Loc.t(str(b["label"])), Loc.f("LV", [int(b["to_lvl"])])]
	v.add_child(UIKit.label(title, UIKit.fit_size(title, 300.0, 24, 18), UIKit.INK, true))
	row.add_child(v)
	var btn := UIKit.cta_button("", "", Vector2(176, 72), 28)
	btn.topaz = false
	var cc := HBoxContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_theme_constant_override("separation", 6)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := Icons.make("coin", 32.0)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.add_child(coin)
	var cl := UIKit.number(Loc.num(int(b["cost"])), 28, false, UIKit.CTA_TEXT)
	cl.add_theme_color_override("font_shadow_color", Color(0.52, 0.24, 0.03, 0.45))
	cl.add_theme_constant_override("shadow_offset_y", 2)
	cl.add_theme_constant_override("shadow_outline_size", 4)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.add_child(cl)
	btn.add_child(cc)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_go_best.bind(kind, id))
	row.add_child(btn)


func _go_best(kind: String, id: String) -> void:
	match kind:
		"machine":
			select(id)
			hub.open_machine(id)
		"hero":
			hub.select_tab("heroes")
		"barracks":
			hub.select_tab("barracks")


# ------------------------------------------------------------------ widgets

## The Best-upgrade medal: the machine render (or icon) in a cream socket with a gold ring.
class _BestMedal extends Control:
	var kind := "machine"
	var id := ""
	var _tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind == "machine":
			_tex = MachineThumbs.get_thumb(self, id, Meta.machine_level(id) >= ArsenalData.ASCENSION_LEVEL)
			if _tex == null and WeaponModels.KINDS.has(id):
				MachineThumbs.service(get_tree()).rendered.connect(func(key: String, tex: Texture2D):
					if key == MachineThumbs.key_of(id, Meta.machine_level(id) >= ArsenalData.ASCENSION_LEVEL):
						_tex = tex
						queue_redraw())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var g: Dictionary = UITokens.gem(ArsenalData.rarity_of(id) if kind == "machine" else "topaz")
		for i in 3:
			draw_circle(c + Vector2(0, 1.5 + i), r - 1.0 + i, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.06))
		draw_circle(c, r, UITokens.PAPER_2)
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		draw_circle(c, r - 3.0, top.lerp(bot, 0.6))
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 0.25))
		draw_arc(c, r - 0.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
		var ir := Rect2(c - Vector2(r, r) * 0.95, Vector2(r, r) * 1.9)
		if _tex:
			draw_texture_rect(_tex, ir, false)
		elif kind == "machine":
			Icons.draw_icon(self, id, ir.grow(-r * 0.25))
		else:
			var ik := "tab_heroes" if kind == "hero" else "tab_barracks"
			Icons.draw_icon(self, ik, ir.grow(-r * 0.3))


## The page backdrop: a sunlit workshop stage (warm haze, a sunbeam, a light pool in the
## selected machine's gem colour, faint gem fracture planes, a soft floor) behind the
## showcase, and the cream sheet with an arched top (bridge span + keystone) under the tabs
## and the grid. Paints the whole screen behind the page (top bar and nav included), so the
## tab reads light whatever the hub backdrop is.
class _Stage extends Control:
	var page: Control
	var gem := "quartz"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var vp := get_viewport().get_visible_rect().size
		var gp := get_global_rect().position
		var full := Rect2(-gp, vp)
		var g: Dictionary = UITokens.gem(gem)
		var lc: Color = g["light"]
		var gt: Color = g["bot"]
		var strip_h: float = (page.get("_strip") as Control).custom_minimum_size.y
		var floor_y := strip_h - 6.0
		# Haze: warm paper at the top, a breath of the gem's colour, the warm stage tone low.
		var top := UITokens.PAPER_0.lerp(Color("#F3E6CF"), 0.5)
		var mid := Color("#EADBC0").lerp(gt, 0.12)
		var low := UITokens.STAGE_TOP.lerp(gt, 0.1)
		var y0 := full.position.y
		var y1 := floor_y
		var ym := lerpf(y0, y1, 0.55)
		draw_polygon(PackedVector2Array([Vector2(full.position.x, y0), Vector2(full.end.x, y0), Vector2(full.end.x, ym), Vector2(full.position.x, ym)]),
				PackedColorArray([top, top, mid, mid]))
		draw_polygon(PackedVector2Array([Vector2(full.position.x, ym), Vector2(full.end.x, ym), Vector2(full.end.x, y1 + 40.0), Vector2(full.position.x, y1 + 40.0)]),
				PackedColorArray([mid, mid, low, low]))
		# Sunbeam from the upper left.
		var sun := Color(UITokens.SUN.r, UITokens.SUN.g, UITokens.SUN.b, 0.22)
		var clear := Color(sun.r, sun.g, sun.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(-40, y0), Vector2(220, y0), Vector2(size.x * 0.78, y1), Vector2(size.x * 0.28, y1)]),
				PackedColorArray([sun, sun, clear, clear]))
		# Gem light pool behind the machine + faint fracture planes of that gem.
		var cx := size.x * 0.5
		var cy := strip_h * 0.52
		var R := size.x * 0.52
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - R, cy - R * 0.85), Vector2(R * 2.0, R * 1.7)), false, Color(lc.r, lc.g, lc.b, 0.55))
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - R * 0.6, cy - R * 0.5), Vector2(R * 1.2, R)), false, Color(1, 1, 1, 0.35))
		KitGemCard.draw_stage_fracture(self, gem, Rect2(Vector2(0, y0), Vector2(size.x, y1 - y0)))
		# Soft floor: a darker warm band with a gentle shadow pool under the turntable.
		var fl := UITokens.STAGE_BOTTOM.lerp(gt, 0.08)
		var fl0 := Color(fl.r, fl.g, fl.b, 0.0)
		var fy := floor_y - 70.0
		draw_polygon(PackedVector2Array([Vector2(full.position.x, fy), Vector2(full.end.x, fy), Vector2(full.end.x, floor_y + 30.0), Vector2(full.position.x, floor_y + 30.0)]),
				PackedColorArray([fl0, fl0, Color(fl.r, fl.g, fl.b, 0.55), Color(fl.r, fl.g, fl.b, 0.55)]))
		# The cream sheet with the arched top (the bridge span + crystal keystone).
		var sheet := Rect2(Vector2(full.position.x - 2.0, floor_y), Vector2(full.size.x + 4.0, full.end.y - floor_y + 2.0))
		for i in 4:
			var sp := KitNav._arch_points(Rect2(sheet.position + Vector2(0, -2.0 - i * 2.0), sheet.size), 10.0, 0.0, 32)
			sp.append(Vector2(sheet.end.x, sheet.position.y + 24.0))
			sp.append(Vector2(sheet.position.x, sheet.position.y + 24.0))
			draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.035))
		draw_rect(sheet, UITokens.SHEET_FILL)
		KitNav.draw_arch_top(self, sheet, 10.0, 0.0, UITokens.SHEET_FILL, true, UITokens.HAIRLINE, 1.5)
		# A faint paper gradient down the sheet.
		var p2 := Color(UITokens.PAPER_2.r, UITokens.PAPER_2.g, UITokens.PAPER_2.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(full.position.x, floor_y + 160.0), Vector2(full.end.x, floor_y + 160.0), Vector2(full.end.x, full.end.y), Vector2(full.position.x, full.end.y)]),
				PackedColorArray([p2, p2, UITokens.PAPER_2, UITokens.PAPER_2]))
