class_name DeckEditor
extends VBoxContainer
## Deck editor (arsenal_design.md §3.1, §7.2; Meta-1: 3 slots): the machines crates may hold.
## Slot 1 is the Lead slot (crown; a Lv5+ machine there is fielded at Rank I from the start).
## Tap a machine below to add it, × on a slot removes it, the crown button moves a machine to
## the Lead slot. Auto-deck fills the strongest owned machines. Before the Deck unlock (after
## L10) the deck builds itself and the editor is read-only. Every change saves at once.

var hub: Hub
var _slots: HBoxContainer
var _list: GridContainer
var _hint: Label
var _auto: Button


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = UIKit.heading("", 22, UIKit.TEXT_DIM, 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 14)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto = UIKit.button(Loc.t("AUTO_DECK"), false, 300.0)
	_auto.custom_minimum_size.y = 64
	_auto.add_theme_font_size_override("font_size", 24)
	_auto.icon = null
	_auto.pressed.connect(func():
		var d := Meta.auto_deck()
		if Meta.set_deck(d):
			UIJuice.haptic("THUD", 0.6)
			Audio.play("upgrade", -6.0)
			refresh()
			for s in _slots.get_children():
				UIJuice.punch(s, 1.08, 0.25))
	arow.add_child(_auto)
	add_child(arow)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 20)
	cc.add_child(pad)
	_list = GridContainer.new()
	_list.columns = 4
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 10)
	pad.add_child(_list)
	refresh()


func _editable() -> bool:
	return Meta.is_unlocked("deck")


func refresh() -> void:
	if not is_node_ready():
		return
	var d := Meta.deck()
	var editable := _editable()
	if editable:
		_hint.text = Loc.t("DECK_HINT")
	else:
		_hint.text = Loc.f("DECK_AUTO_INFO", [int(EconData.unlock_entry("deck").get("after_win", 10)) + 1])
	_auto.visible = editable
	for c in _slots.get_children():
		c.queue_free()
	for i in Meta.deck_slots():
		_slots.add_child(_slot(i, d[i] if i < d.size() else "", editable))
	for c in _list.get_children():
		c.queue_free()
	if not editable:
		return
	for id in Meta.owned_ids():
		if not ArsenalData.is_live(id):
			continue
		var card := Meta.machine_card(id)
		card["badge"] = ""
		var mc := MachineCard.new(card)
		mc.compact = true
		mc.custom_minimum_size = Vector2(160, 214)
		mc.modulate = Color(1, 1, 1, 0.45) if d.has(id) else Color.WHITE
		mc.pressed.connect(func(mid: String): _toggle(mid))
		_list.add_child(mc)


func _slot(i: int, id: String, editable: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.custom_minimum_size = Vector2(0, 34)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i == 0:
		head.add_child(Icons.make("crown", 30.0))
		var lead_ok := id != "" and Meta.machine_level(id) >= ArsenalData.LEAD_LEVEL
		var t := Loc.t("LEAD") if lead_ok else Loc.f("LEAD_AT", [ArsenalData.LEAD_LEVEL])
		head.add_child(UIKit.heading(t, 20, UIKit.GOLD if lead_ok else UIKit.TEXT_DIM, 5))
	else:
		head.add_child(UIKit.heading("%d" % (i + 1), 22, UIKit.TEXT_DIM, 5))
	box.add_child(head)
	if id == "":
		var empty := EmptySlot.new()
		empty.custom_minimum_size = Vector2(196, 262)
		box.add_child(empty)
		return box
	var card := Meta.machine_card(id)
	card["badge"] = ""
	var mc := MachineCard.new(card)
	mc.custom_minimum_size = Vector2(196, 262)
	mc.selected = i == 0 and Meta.lead() == id
	mc.pressed.connect(func(mid: String): hub.open_machine(mid))
	box.add_child(mc)
	if editable:
		var tools := HBoxContainer.new()
		tools.alignment = BoxContainer.ALIGNMENT_CENTER
		tools.add_theme_constant_override("separation", 10)
		tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i > 0:
			var up := RoundButton.new(24.0)
			up.icon_kind = "crown"
			up.pressed.connect(func(): _make_lead(id))
			tools.add_child(up)
		var rm := RoundButton.new(24.0)
		rm.icon_kind = "close"
		rm.ring_color = Color(0.85, 0.4, 0.35)
		rm.pressed.connect(func(): _remove(id))
		tools.add_child(rm)
		box.add_child(tools)
	return box


func _toggle(id: String) -> void:
	var d := Meta.deck()
	if d.has(id):
		_remove(id)
		return
	if d.size() >= Meta.deck_slots():
		hub.toast(Loc.t("DECK_FULL"), "deck")
		Audio.play("error", -6.0)
		return
	d.append(id)
	_apply(d)


func _remove(id: String) -> void:
	var d := Meta.deck()
	d.erase(id)
	_apply(d)


func _make_lead(id: String) -> void:
	var d := Meta.deck()
	d.erase(id)
	d.insert(0, id)
	_apply(d)


func _apply(d: Array) -> void:
	if Meta.set_deck(d):
		UIJuice.haptic("CLICK", 0.6)
		Audio.play("build", -8.0)
		refresh()
		if _slots.get_child_count() > 0:
			UIJuice.punch(_slots.get_child(0), 1.04, 0.2)
	else:
		Audio.play("error", -6.0)


## A dashed empty deck slot with a "+".
class EmptySlot extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(6, 10), size - Vector2(12, 16))
		draw_style_box(UIKit.box(Color(0.03, 0.04, 0.1, 0.6), Color(0, 0, 0, 0), 22, 0, 0, Vector2.ZERO), r)
		var per := 2.0 * (r.size.x + r.size.y)
		var d := 0.0
		while d < per:
			var a := MachineCard._perimeter(r, d)
			var b := MachineCard._perimeter(r, minf(d + 14.0, per - 0.1))
			if a.distance_to(b) < 20.0:
				draw_line(a, b, Color(1, 0.85, 0.5, 0.45), 3.0, true)
			d += 26.0
		var c := r.get_center()
		Icons.draw_icon(self, "plus", Rect2(c - Vector2(22, 32), Vector2(44, 44)), Color(1, 0.9, 0.6, 0.6))
		var f := UIKit.font(true)
		var t := Loc.t("DECK_EMPTY_SLOT")
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, Vector2(c.x - tw * 0.5, c.y + 40), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.7, 0.6))
