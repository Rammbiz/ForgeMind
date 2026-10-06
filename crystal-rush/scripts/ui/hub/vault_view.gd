class_name VaultView
extends Control
## Cache Vault sheet (arsenal_design.md §5.2, §7.2): every waiting Cache with its look, where it
## came from and an open button (World Caches: "Відкрити на вівтарі" - the Altar; Stone: "Відкрити"),
## the empty state, the Legendary pity bar and the odds (i) entry. Opening goes through
## Hub.open_cache() (the Altar when WS5 listens, else the inline Reveal below; the result is
## rolled, granted and saved by Meta before anything animates).

var hub: Hub
var _sheet: PanelContainer
var _list: VBoxContainer


func setup(p_hub: Hub, _a: Variant = null) -> void:
	hub = p_hub


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(26, 26)))
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 22 + ins.x
	_sheet.offset_right = -22 - ins.z
	_sheet.offset_top = ins.y + 110
	_sheet.offset_bottom = -ins.w - 120
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_sheet.add_child(col)
	var head := HBoxContainer.new()
	var t := UIKit.gradient_heading(Loc.t("VAULT"), 50)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var info := RoundButton.new(26.0)
	info.icon_kind = "info"
	info.pressed.connect(func(): hub.open_odds("world" if _has("world") else "stone"))
	head.add_child(info)
	col.add_child(head)
	col.add_child(UIKit.divider(560.0))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	col.add_child(PityBar.make())
	var close := UIKit.button(Loc.t("CLOSE"), true, 380.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): hub.pop_modal())
	col.add_child(close)
	_fill()
	UIJuice.pop(_sheet, 0.0, UITokens.SLOW)


func play_exit() -> Tween:
	var tw := _sheet.create_tween().set_parallel(true)
	tw.tween_property(_sheet, "modulate:a", 0.0, UITokens.EXIT)
	tw.tween_property(_sheet, "scale", Vector2.ONE * 0.94, UITokens.EXIT)
	return tw


func _has(type: String) -> bool:
	for c in Meta.vault():
		if str((c as Dictionary).get("type", "")) == type:
			return true
	return false


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var v := Meta.vault()
	if v.is_empty():
		var e := UIKit.heading(Loc.t("VAULT_EMPTY"), 26, UIKit.TEXT_DIM, 6)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.custom_minimum_size = Vector2(0, 220)
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(e)
		return
	for i in v.size():
		var cd: Dictionary = v[i]
		var type := str(cd.get("type", "stone"))
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(14, 10)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		p.add_child(row)
		var ic := Icons.make("cache_" + type if type in ["stone", "world"] else "cache_world", 84.0)
		row.add_child(ic)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.alignment = BoxContainer.ALIGNMENT_CENTER
		vv.add_child(UIKit.heading(Loc.t(str((EconData.CACHES[type] as Dictionary)["name"])), 28, UIKit.TEXT, 6))
		var slots := int((EconData.CACHES[type] as Dictionary).get("slots", 3))
		vv.add_child(UIKit.label("%s · %s" % [Loc.f("ODDS_SLOTS", [slots]), Loc.f("LEVEL", [int(cd.get("level", 1))])], 20, UIKit.TEXT_DIM))
		row.add_child(vv)
		var altar := bool((EconData.CACHES[type] as Dictionary).get("altar", false))
		var b := UIKit.styled_button(Loc.t("OPEN"), "green" if not altar else "primary", Vector2(170, 70), 26)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var idx := i
		b.pressed.connect(func():
			hub.pop_modal()
			hub.open_cache(idx))
		row.add_child(b)
		_list.add_child(p)
	UIJuice.stagger(_list.get_children(), 0.1, 0.06)


## Legendary pity: "Легендарна гарантовано ≤ N" with a bar, or the World 3 note.
class PityBar extends VBoxContainer:
	static func make() -> PityBar:
		var p := PityBar.new()
		p.add_theme_constant_override("separation", 4)
		var left := Meta.pity_left()
		var t := UIKit.heading(Loc.f("PITY_LEG", [left]) if left >= 0 else Loc.t("PITY_LEG_LOCKED"), 22, UITokens.rarity("L") if left >= 0 else UIKit.TEXT_DIM, 5)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(t)
		if left >= 0:
			var bar := Bar.new()
			bar.k = 1.0 - float(left) / float(EconData.PITY["leg_hard"])
			bar.custom_minimum_size = Vector2(0, 26)
			p.add_child(bar)
		return p

	class Bar extends Control:
		var k := 0.0

		func _draw() -> void:
			var r := Rect2(Vector2(20, 2), Vector2(size.x - 40, size.y - 4))
			draw_style_box(UIKit.box(Color(0.02, 0.02, 0.05, 0.95), Color(1, 0.8, 0.4, 0.4), 11, 2, 0, Vector2.ZERO), r)
			if k > 0.0:
				MachineCard.grad_box(self, Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * clampf(k, 0.0, 1.0), r.size.y - 6)), Color(1.0, 0.85, 0.4), Color(0.95, 0.55, 0.1), 8)


## Built-in Cache reveal (fallback when no Altar is connected): the cards fan out sorted by
## rarity (§6.6), each in its rarity frame with the machine, the count and NEW; then coins fly
## to the chip. The bundle was granted and saved before this opens.
class Reveal extends Control:
	var hub: Hub
	var rev: Dictionary = {}
	var _cards: Array[Control] = []

	func setup(p_hub: Hub, p_rev: Dictionary) -> void:
		hub = p_hub
		rev = p_rev

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var best := str(rev.get("best", "C"))
		var bc := UITokens.rarity(best)
		var shade := ColorRect.new()
		shade.color = Color(0.01, 0.01, 0.04, 0.55)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		var rays := UIKit.Rays.new()
		rays.color = Color(bc.r, bc.g, bc.b, 0.4)
		rays.set_anchors_preset(Control.PRESET_CENTER)
		rays.offset_left = -480
		rays.offset_right = 480
		rays.offset_top = -600
		rays.offset_bottom = 360
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rays)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 24)
		add_child(col)
		var t := UIKit.gradient_heading(Loc.t(str((EconData.CACHES[str(rev.get("type", "stone"))] as Dictionary)["name"])), 50)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
		var fan := HFlowContainer.new()
		fan.alignment = FlowContainer.ALIGNMENT_CENTER
		fan.add_theme_constant_override("h_separation", 12)
		fan.add_theme_constant_override("v_separation", 12)
		col.add_child(fan)
		for cd: Dictionary in rev.get("cards", []):
			var card := RevealCard.new()
			card.data = cd
			card.custom_minimum_size = Vector2(200, 270)
			fan.add_child(card)
			_cards.append(card)
		var coins := int(rev.get("coins", 0))
		var crow := HBoxContainer.new()
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		crow.add_theme_constant_override("separation", 8)
		if coins > 0:
			crow.add_child(Icons.make("coin", 44.0))
			crow.add_child(UIKit.heading("+" + Loc.num(coins), 40, UIKit.GOLD_LIGHT, 8))
		col.add_child(crow)
		var b := UIKit.button(Loc.t("DONE"), true, 380.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func():
			if coins > 0:
				hub.fly_reward("coins", coins, crow.get_global_rect().get_center())
			hub.pop_modal())
		col.add_child(b)
		var flip: Dictionary = EconData.REVEAL["flip"]
		var delay := 0.15
		for i in _cards.size():
			UIJuice.pop(_cards[i], delay, UITokens.SLOW, 0.4)
			var r := str((_cards[i] as RevealCard).data.get("rarity", "C"))
			delay += float(EconData.REVEAL["fan_stagger"]) + float(flip.get(r, 0.3)) * 0.4
			if r in ["E", "L", "M"]:
				var cref := _cards[i]
				get_tree().create_timer(delay).timeout.connect(func():
					if is_instance_valid(cref):
						UIKit.sparkles(self, cref.get_global_rect().get_center() - global_position, UITokens.rarity(r).lightened(0.3), 40, 300.0)
						UIJuice.haptic_pattern("rarity_" + r))
		UIJuice.pop(b, delay + 0.2)
		Audio.play("crate_open", -2.0)

	func play_exit() -> Tween:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, UITokens.EXIT)
		return tw


class RevealCard extends Control:
	var data: Dictionary = {}
	var _tex: Texture2D

	func _ready() -> void:
		var id := str(data.get("id", ""))
		if id != "":
			_tex = MachineThumbs.get_thumb(self, id, false)

	func _draw() -> void:
		var f := UIKit.font(true)
		var r := str(data.get("rarity", "C"))
		var rc := UITokens.rarity(r)
		var body := Rect2(Vector2(4, 6), size - Vector2(8, 12))
		draw_texture_rect(UIKit.glow_texture(), body.grow(30), false, Color(rc.r, rc.g, rc.b, 0.45))
		MachineCard.grad_box(self, body, rc.lightened(0.3), rc.darkened(0.45), 22)
		var inner := body.grow(-5)
		MachineCard.grad_box(self, inner, rc.darkened(0.35), Color(0.03, 0.04, 0.1), 18)
		var id := str(data.get("id", ""))
		var ir := Rect2(inner.position + Vector2(14, 14), Vector2(inner.size.x - 28, inner.size.x - 28))
		if bool(data.get("wild", false)) or id == "":
			Icons.draw_icon(self, "wild", ir.grow(-16))
		elif _tex:
			draw_texture_rect(_tex, ir.grow(10), false)
		else:
			Icons.draw_icon(self, id, ir.grow(-10))
		var name := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else Loc.t("CUR_WILD")
		var fs := UIKit.fit_size(name, inner.size.x - 16, 22, 14)
		var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, Vector2(inner.get_center().x - tw * 0.5, inner.end.y - 54), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0.01, 0.05))
		draw_string(f, Vector2(inner.get_center().x - tw * 0.5, inner.end.y - 54), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
		var cnt := "×%d" % int(data.get("count", 1))
		var cw := f.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string_outline(f, Vector2(inner.get_center().x - cw * 0.5, inner.end.y - 16), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0.01, 0.05))
		draw_string(f, Vector2(inner.get_center().x - cw * 0.5, inner.end.y - 16), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, rc.lightened(0.4))
		if bool(data.get("new", false)):
			var tag := Loc.t("REVEAL_NEW")
			var nw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var tr := Rect2(Vector2(body.get_center().x - nw * 0.5 - 10, body.position.y - 8), Vector2(nw + 20, 28))
			draw_style_box(UIKit.box(Color(1.0, 0.36, 0.3), Color(1, 0.9, 0.7), 12, 2, 0, Vector2.ZERO), tr)
			draw_string(f, tr.position + Vector2(10, 21), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
