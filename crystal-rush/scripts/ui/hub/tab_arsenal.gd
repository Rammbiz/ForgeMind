extends Control
## Арсенал tab (arsenal_design.md §7.1-7.2): the 3D showcase strip (the selected machine on a
## navy spotlight pedestal, its name, rarity, family and level, and the next milestone), the
## sub-tabs Машини · Колода, filter chips and the 3-column card grid (MachineCard; tap opens
## MachineDetail), and the Best-upgrade row pinned at the bottom (one pre-selected upgrade, one
## tap opens its two-tap confirm; never spent automatically).

const FILTERS := [["all", "FILTER_ALL"], ["owned", "FILTER_OWNED"], ["upgradable", "FILTER_UPGRADABLE"]]

var hub: Hub
var selected_id := ""
var _sub := "machines"
var _filter := "all"
var _show: HubShowcase
var _name: Label
var _meta_row: HBoxContainer
var _lv: Label
var _milestone: PanelContainer
var _milestone_lbl: Label
var _seg: PanelContainer
var _machines_view: VBoxContainer
var _filters: PanelContainer
var _grid: GridContainer
var _count_lbl: Label
var _scroll: ScrollContainer
var _deck: DeckEditor
var _best: PanelContainer
var _cards := {}             ## id -> MachineCard


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# Showcase strip
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 300)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)
	_show = HubShowcase.new("machine")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.offset_top = -8
	_show.tapped.connect(func():
		if selected_id != "":
			hub.open_machine(selected_id))
	strip.add_child(_show)
	var info := VBoxContainer.new()
	info.position = Vector2(UITokens.GUTTER, 6)
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(info)
	_name = UIKit.gradient_heading("", 42)
	info.add_child(_name)
	_meta_row = HBoxContainer.new()
	_meta_row.add_theme_constant_override("separation", 8)
	_meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_meta_row)
	_lv = UIKit.heading("", 30, UIKit.GOLD_LIGHT, 7)
	_lv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lv.position = Vector2(-UITokens.GUTTER - 150, 10)
	_lv.size = Vector2(150, 40)
	_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strip.add_child(_lv)
	_milestone = PanelContainer.new()
	_milestone.add_theme_stylebox_override("panel", UIKit.lux("glass", Vector2(18, 6)))
	_milestone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_child(Icons.make("laurel", 26.0))
	_milestone_lbl = UIKit.heading("", 21, UIKit.TEXT, 5)
	mrow.add_child(_milestone_lbl)
	_milestone.add_child(mrow)
	strip.add_child(_milestone)
	# Sub-tabs
	var seg_row := HBoxContainer.new()
	seg_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seg_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seg = UIKit.segmented([["machines", Loc.t("SUB_MACHINES")], ["deck", Loc.t("SUB_DECK")]], _sub, func(id: String): show_sub(id))
	_seg.custom_minimum_size = Vector2(440, 0)
	seg_row.add_child(_seg)
	col.add_child(seg_row)
	# Machines view
	_machines_view = VBoxContainer.new()
	_machines_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_machines_view.add_theme_constant_override("separation", 8)
	_machines_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_machines_view)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 10)
	frow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl := HBoxContainer.new()
	fl.custom_minimum_size = Vector2(UITokens.GUTTER - 10, 0)
	frow.add_child(fl)
	var opts: Array = []
	for o: Array in FILTERS:
		opts.append([o[0], Loc.t(o[1])])
	_filters = UIKit.segmented(opts, _filter, func(id: String):
		_filter = id
		_fill_grid(), 52.0, 20)
	_filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(_filters)
	_count_lbl = UIKit.heading("", 22, UIKit.TEXT_DIM, 5)
	_count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frow.add_child(_count_lbl)
	frow.add_child(UIKit.gap(UITokens.GUTTER - 10))
	_machines_view.add_child(frow)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_machines_view.add_child(_scroll)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(cc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 24)
	cc.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 12)
	pad.add_child(_grid)
	# Deck view
	_deck = DeckEditor.new()
	_deck.setup(hub)
	_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck.visible = false
	col.add_child(_deck)
	# Best upgrade row
	_best = PanelContainer.new()
	_best.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(14, 10)))
	var brow := HBoxContainer.new()
	brow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_best.add_child(brow)
	var bwrap := MarginContainer.new()
	bwrap.add_theme_constant_override("margin_left", UITokens.GUTTER - 6)
	bwrap.add_theme_constant_override("margin_right", UITokens.GUTTER - 6)
	bwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bwrap.add_child(_best)
	col.add_child(bwrap)
	refresh()


func on_show() -> void:
	refresh()


func on_hide() -> void:
	pass


## Machines or Deck sub-tab.
func show_sub(id: String) -> void:
	_sub = id
	if _seg:
		UIKit.segmented_select(_seg, id)
	_machines_view.visible = id == "machines"
	_deck.visible = id == "deck"
	_best.get_parent().visible = id == "machines"
	if id == "deck":
		_deck.refresh()
		UIJuice.fade_in(_deck, 0.0, UITokens.FAST)
	else:
		UIJuice.fade_in(_machines_view, 0.0, UITokens.FAST)


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
	_name.text = Loc.t(str(c["name"]))
	_name.add_theme_font_size_override("font_size", UIKit.fit_size(_name.text, 470.0, 42, 28))
	for ch in _meta_row.get_children():
		ch.queue_free()
	_meta_row.add_child(_rarity_pill(str(c["rarity"])))
	_meta_row.add_child(_family_pill(str(c["family"])))
	_lv.text = Loc.f("LV", [int(c["lvl"])]) if bool(c["owned"]) else ""
	var ms := Meta.next_milestone()
	_milestone.visible = not ms.is_empty()
	if not ms.is_empty():
		var mname := Loc.t(str((ArsenalData.MACHINES[str(ms["id"])] as Dictionary)["name"]))
		_milestone_lbl.text = Loc.f("MILESTONE", [Loc.t("BEAT_" + str(ms["beat"]).to_upper()), mname, int(ms["levels_left"])])
		await get_tree().process_frame
		if is_instance_valid(_milestone):
			_milestone.position = Vector2((size.x - _milestone.size.x) * 0.5, 300 - _milestone.size.y - 4)


static func _rarity_pill(r: String) -> Control:
	var p := PanelContainer.new()
	var rc := UITokens.rarity(r)
	p.add_theme_stylebox_override("panel", UIKit.box(Color(rc.r * 0.25, rc.g * 0.25, rc.b * 0.3, 0.92), rc, 14, 2, 0, Vector2(12, 3)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UIKit.heading(Loc.t(str((ArsenalData.RARITIES[r] as Dictionary)["name"])), 20, rc.lightened(0.3), 4))
	return p


static func _family_pill(fam: String) -> Control:
	var p := PanelContainer.new()
	var fc := UITokens.family(fam)
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.03, 0.08, 0.85), Color(fc.r, fc.g, fc.b, 0.7), 14, 2, 0, Vector2(10, 3)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icons.make("fam_" + fam, 22.0))
	row.add_child(UIKit.heading(Loc.t(str((ArsenalData.FAMILIES[fam] as Dictionary)["name"])), 20, fc.lightened(0.2), 4))
	p.add_child(row)
	return p


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
	for o: Array in order:
		var c: Dictionary = list[o[1]]
		var id := str(c["id"])
		keep[id] = true
		var mc: MachineCard = _cards.get(id)
		if mc == null:
			mc = MachineCard.new(c)
			mc.pressed.connect(func(mid: String):
				select(mid)
				hub.open_machine(mid))
			_grid.add_child(mc)
			_cards[id] = mc
		else:
			mc.set_card(c)
		mc.selected = id == selected_id
		_grid.move_child(mc, idx)
		idx += 1
	for id: String in _cards.keys():
		if not keep.has(id):
			(_cards[id] as Node).queue_free()
			_cards.erase(id)
	var owned := Meta.owned_ids().size()
	_count_lbl.text = "%d/%d" % [owned, ArsenalData.live_ids().size()]


func _fill_best() -> void:
	for ch in _best.get_children():
		ch.queue_free()
	var b := Meta.best_upgrade()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_best.add_child(row)
	if b.is_empty():
		var l := UIKit.heading(Loc.t("NOTHING_TO_UPGRADE"), 22, UIKit.TEXT_DIM, 5)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.y = 56
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		return
	var kind := str(b["kind"])
	var id := str(b["id"])
	var icon := id if kind == "machine" else ("tab_heroes" if kind == "hero" else str((EconData.BARRACKS[id] as Dictionary).get("icon", "soldier")))
	var medal := Control.new()
	medal.custom_minimum_size = Vector2(64, 64)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icons.make(icon if icon in ["recruits", "reserves", "shield", "drill", "volley", "tab_heroes"] or WeaponModels.KINDS.has(icon) else "soldier", 58.0)
	ic.position = Vector2(3, 3)
	medal.add_child(ic)
	row.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.heading(Loc.t("BEST_UPGRADE").to_upper(), 18, UIKit.GOLD, 4))
	var title := "%s · %s" % [Loc.t(str(b["label"])), Loc.f("LV", [int(b["to_lvl"])])]
	var tl := UIKit.heading(title, UIKit.fit_size(title, 330.0, 26, 18), UIKit.TEXT, 5)
	v.add_child(tl)
	row.add_child(v)
	var btn := UIKit.styled_button("", "green", Vector2(170, 70))
	var cc := HBoxContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_bottom = -6
	cc.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_theme_constant_override("separation", 6)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(Icons.make("coin", 32.0))
	cc.add_child(UIKit.heading(Loc.num(int(b["cost"])), 28, Color(1, 1, 1), 7))
	btn.add_child(cc)
	btn.pressed.connect(_go_best.bind(kind, id))
	row.add_child(btn)
	UIJuice.breathe(btn, 0.03, 1.6)


func _go_best(kind: String, id: String) -> void:
	match kind:
		"machine":
			select(id)
			hub.open_machine(id)
		"hero":
			hub.select_tab("heroes")
		"barracks":
			hub.select_tab("barracks")
