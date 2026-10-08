class_name DeckEditor
extends VBoxContainer
## Deck editor (arsenal_design.md §3.1, §7.2; Meta-1: 3 slots): the machines crates may hold.
## Slot 1 is the Lead slot (crown; a Lv5+ machine there is fielded at Rank I from the start).
## Tap a machine below to add it, × on a slot removes it, the crown button moves a machine to
## the Lead slot. Auto-deck fills the strongest owned machines. Before the Deck unlock (after
## L10) the deck builds itself and the editor is read-only. Every change saves at once.
## UI v2: light and quiet - the slots are cream wells with an open gold setting (prongs) when
## empty, the cards are the rarity gem cards, the list below a 4-column grid of compact cards
## (cards already in the deck dimmed with a check), Auto-deck a cream secondary button.

const SLOT := Vector2(180, 232)

var hub: Hub
var _slots: HBoxContainer
var _list: GridContainer
var _hint: Label
var _auto: Button
var _sc: ScrollContainer
var _undo: Control
## The hint + Auto-deck row (the Arsenal tab lays a text bed under it on the frosted sheet).
var header: Control


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UIKit.gap(UITokens.GUTTER - 12))
	header = top
	_hint = UIKit.label("", 22, UIKit.INK_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_hint)
	_auto = UIKit.secondary_button(Loc.t("AUTO_DECK"), "auto", Vector2(236, 60), 22)
	_auto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_auto.pressed.connect(func():
		var d := Meta.auto_deck()
		if Meta.set_deck(d):
			UIJuice.haptic("THUD", 0.6)
			Audio.play("upgrade", -6.0)
			refresh()
			for s in _slots.get_children():
				UIJuice.punch(s, 1.08, 0.25))
	top.add_child(_auto)
	top.add_child(UIKit.gap(UITokens.GUTTER - 12))
	add_child(top)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 16)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots)
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drow.add_child(UIKit.divider(560.0))
	add_child(drow)
	# The list scrolls in a frame with a 24 px cream fade at its bottom edge, and snaps so a
	# row never ends cut at the seam.
	var frame := Control.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	add_child(frame)
	var sc := ScrollContainer.new()
	_sc = sc
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.scroll_ended.connect(_snap)
	frame.add_child(sc)
	var fade := Control.new()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -24
	fade.draw.connect(func():
		var p0 := UITokens.PAPER_1
		fade.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(fade.size.x, 0), fade.size, Vector2(0, fade.size.y)]),
				PackedColorArray([Color(p0, 0.0), Color(p0, 0.0), Color(p0, 0.95), Color(p0, 0.95)])))
	frame.add_child(fade)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 22)
	pad.add_theme_constant_override("margin_bottom", 20)
	cc.add_child(pad)
	_list = GridContainer.new()
	_list.columns = 4
	_list.add_theme_constant_override("h_separation", 12)
	_list.add_theme_constant_override("v_separation", 24)
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
		mc.custom_minimum_size = MachineCard.SIZE
		mc.picked = d.has(id)
		mc.pressed.connect(func(mid: String): _toggle(mid))
		_list.add_child(mc)


func _slot(i: int, id: String, editable: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.custom_minimum_size = Vector2(0, 34)
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if i == 0:
		head.add_child(Icons.make("crown", 30.0))
		var lead_ok := id != "" and Meta.machine_level(id) >= ArsenalData.LEAD_LEVEL
		var t := Loc.t("LEAD") if lead_ok else Loc.f("LEAD_AT", [ArsenalData.LEAD_LEVEL])
		head.add_child(UIKit.caps(t, 20, UIKit.GOLD_TEXT_GLASS if lead_ok else UIKit.INK_DIM))
	else:
		head.add_child(UIKit.caps("%d" % (i + 1), 22, UIKit.INK_DIM))
	box.add_child(head)
	if id == "":
		var empty := EmptySlot.new()
		empty.custom_minimum_size = SLOT
		box.add_child(empty)
		return box
	var card := Meta.machine_card(id)
	card["badge"] = ""
	card["is_lead"] = false     # the slot header carries the crown
	var mc := MachineCard.new(card)
	mc.custom_minimum_size = SLOT
	mc.selected = i == 0 and Meta.lead() == id
	mc.pressed.connect(func(mid: String): hub.open_machine(mid))
	box.add_child(mc)
	if editable:
		# Cream sockets with a gold ring: "make Lead" (crown) and "remove" (an ink minus), at
		# least 96 px apart so their 88 px touch targets never overlap.
		var tools := HBoxContainer.new()
		tools.alignment = BoxContainer.ALIGNMENT_CENTER
		tools.add_theme_constant_override("separation", 52)
		tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i > 0:
			var up := UIKit.edge_button("crown", 22.0)
			up.pressed.connect(func(): _make_lead(id))
			tools.add_child(up)
		var rm := UIKit.edge_button("minus", 22.0)
		rm.pressed.connect(func(): _remove(id, true))
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


func _remove(id: String, offer_undo := false) -> void:
	var before := Meta.deck()
	var d := before.duplicate()
	d.erase(id)
	_apply(d)
	if offer_undo:
		_show_undo(id, before)


## A short cream chip under the slots: "<name> - прибрано з колоди  [Повернути]" (3.5 s).
func _show_undo(id: String, before: Array) -> void:
	if is_instance_valid(_undo):
		_undo.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("toast", Vector2(16, 4)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var l := UIKit.label(Loc.f("DECK_REMOVED", [Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"]))]), 22, UIKit.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	var b := UIKit.text_button(Loc.t("UNDO"), Vector2(0, 72), 22)
	b.pressed.connect(func():
		if Meta.set_deck(before):
			Audio.play("build", -8.0)
			refresh()
		if is_instance_valid(p):
			p.queue_free())
	row.add_child(b)
	p.top_level = true
	add_child(p)
	_undo = p
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.size = p.get_combined_minimum_size()
	var sr := _slots.get_global_rect()
	p.global_position = Vector2(sr.get_center().x - p.size.x * 0.5, sr.end.y - p.size.y * 0.5)
	UIJuice.fade_in(p, 0.0, 0.18)
	var tw := p.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


## Snaps the list so rows end on a card bottom (no card cut at the seam).
func _snap() -> void:
	var pitch := MachineCard.SIZE.y + 24.0
	var target := roundf(_sc.scroll_vertical / pitch) * pitch
	var tw := _sc.create_tween()
	tw.tween_property(_sc, "scroll_vertical", int(target), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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


## An empty deck slot: a cream well with an open gold setting (four prongs waiting for a
## gem), a "+" line icon and "Порожньо".
class EmptySlot extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_style_box(UIKit.lux("well"), r)
		var c := r.get_center() + Vector2(0, -12)
		var R := minf(r.size.x, r.size.y) * 0.2
		# Open setting: a thin gold bezel ring and four prongs leaning outwards.
		draw_arc(c, R, 0, TAU, 64, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), UIKit.line_px(1.0), true)
		draw_arc(c, R - 5.0, 0, TAU, 64, Color(1, 1, 1, 0.55), UIKit.px(1.0), true)
		for k in 4:
			var a := PI * 0.25 + k * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var p0 := c + d * R
			var p1 := c + d * (R + 14.0) + Vector2(-d.y, d.x) * 3.0
			draw_line(p0, p1, UITokens.HAIRLINE, UIKit.line_px(1.5), true)
			draw_circle(p1, 2.0, UITokens.GOLD_HI)
		Icons.line(self, "plus", Rect2(c - Vector2(16, 16), Vector2(32, 32)), UITokens.GOLD_TEXT)
		var f := UIKit.font_w("medium")
		var t := Loc.t("DECK_EMPTY_SLOT")
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(c.x - tw * 0.5, c.y + R + 44.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.INK_DIM)
