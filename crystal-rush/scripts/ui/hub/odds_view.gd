class_name OddsView
extends Control
## Odds and guarantees (arsenal_design.md §5.4-5.5, §6.7; the (i) screen; UI v2): a cream
## modal with the title and close disc, the pool note, the Cache segmented control, then a
## refined table - taupe caps header, one hairline row per rarity present (gem-cut mark + name
## in ink, tabular percentages: chance per card and as the best card) - the rules as quiet
## icon rows (guaranteed last card, blueprints per card, the Wild chance, Focus and Deck
## weights, duplicate protection, the Epic pity, cards + coins) and the Legendary pity bar.
## Exact numbers from Meta.odds().

const COL_W := 150.0

var hub: Hub
var type := "stone"
var _sheet: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer


func setup(p_hub: Hub, p_type: Variant = "stone") -> void:
	hub = p_hub
	type = str(p_type) if EconData.CACHES.has(str(p_type)) else "stone"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	# Centred between the top bar and the nav; its height follows the content (scrolls when
	# the content is taller than the room).
	_sheet = UIKit.panel("modal", Vector2(28, 24))
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	var half_w := 360.0 - UITokens.GUTTER
	_sheet.offset_left = -half_w + (ins.x - ins.z) * 0.5
	_sheet.offset_right = half_w + (ins.x - ins.z) * 0.5
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_sheet.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.heading(Loc.t("ODDS_TITLE"), 34, UIKit.INK))
	tv.add_child(UIKit.label(Loc.t("ODDS_POOL"), 19, UIKit.INK_DIM))
	head.add_child(tv)
	var close := UIKit.edge_button("close", 26.0)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): hub.close_modal(self))
	head.add_child(close)
	col.add_child(head)
	col.add_child(UIKit.divider(560.0))
	var seg := UIKit.segmented([["stone", Loc.t("CACHE_STONE")], ["world", Loc.t("CACHE_WORLD")]], type, func(id: String):
		type = id
		_fill()
		UIJuice.cross_fade(null, _body), 58.0, 22)
	col.add_child(seg)
	var sc := ScrollContainer.new()
	_scroll = sc
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	sc.add_child(_body)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	var done := UIKit.button(Loc.t("CLOSE"), false, 300.0)
	done.custom_minimum_size.y = 68
	done.pressed.connect(func(): hub.close_modal(self))
	crow.add_child(done)
	col.add_child(crow)
	_fill()
	_body.minimum_size_changed.connect(_center, CONNECT_DEFERRED)
	_sheet.minimum_size_changed.connect(_center, CONNECT_DEFERRED)
	_center()
	UIJuice.soft_in(_sheet, Vector2(0, 28))


## Fits the scroll area to the table (up to the room between the bars) and centres the modal.
func _center() -> void:
	var ins := hub.insets()
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)
	var room := vp.y - ins.y - ins.w - UITokens.TOP_BAR_H - UITokens.TAB_BAR_H - 24.0
	var chrome := _sheet.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y, 200.0, maxf(200.0, room - chrome))
	var mid := (ins.y + UITokens.TOP_BAR_H - ins.w - UITokens.TAB_BAR_H) * 0.5
	var h := _sheet.get_combined_minimum_size().y
	_sheet.offset_top = mid - h * 0.5
	_sheet.offset_bottom = mid + h * 0.5


func play_exit() -> Tween:
	return UIJuice.soft_out(_sheet, Vector2(0, 20))


static func pct(p: float) -> String:
	if p < 0.00005:
		return "—"
	var v := p * 100.0
	var s := ("%.2f" % v) if v < 10.0 else ("%.1f" % v)
	if Loc.lang == "uk":
		s = s.replace(".", ",")
	return s + "%"


func _fill() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var o := Meta.odds(type)
	var present: Array = o.get("present", [])
	# Header row (taupe tracked caps).
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 40
	head.add_theme_constant_override("separation", 8)
	var h0 := UIKit.caps(Loc.t("RARITY"), 17, UIKit.INK_SOFT)
	h0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	head.add_child(h0)
	for k in ["ODDS_PER_CARD", "ODDS_BEST"]:
		var hl := UIKit.caps(Loc.t(k), 15, UIKit.INK_SOFT)
		hl.custom_minimum_size = Vector2(COL_W, 0)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(hl)
	_body.add_child(head)
	_body.add_child(UIKit.hairline(0.0, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9)))
	var per: Dictionary = o.get("per_card", {})
	var best: Dictionary = o.get("best", {})
	for r in ArsenalData.RARITY_ORDER:
		if not present.has(r):
			continue
		var row := _TintRow.new()
		row.gem = UITokens.gem_of(r)
		row.custom_minimum_size = Vector2(0, 62)
		row.add_theme_constant_override("separation", 8)
		var mark := _Mark.new()
		mark.gem = UITokens.gem_of(r)
		mark.custom_minimum_size = Vector2(34, 34)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		row.add_child(UIKit.gap(4))
		var n := UIKit.label(Loc.t(str((ArsenalData.RARITIES[r] as Dictionary)["name"])), 24, UIKit.INK, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.size_flags_vertical = Control.SIZE_FILL
		row.add_child(n)
		var vals: Array[float] = [float(per.get(r, 0.0)), float(best.get(r, 0.0))]
		for v: float in vals:
			var l := UIKit.number(pct(v), 26)
			l.add_theme_color_override("font_color", UIKit.INK if v > 0.00005 else UIKit.INK_DIM)
			l.custom_minimum_size = Vector2(COL_W, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.size_flags_vertical = Control.SIZE_FILL
			row.add_child(l)
		_body.add_child(row)
	# Rules
	var guar: Dictionary = o.get("guaranteed", {})
	var gmin := ""
	for r2 in ArsenalData.RARITY_ORDER:
		if float(guar.get(r2, 0.0)) > 0.0:
			gmin = r2
			break
	var rules: Array = []
	if gmin != "":
		rules.append(["check", Loc.f("ODDS_GUARANTEED", [Loc.t(str((ArsenalData.RARITIES[gmin] as Dictionary)["name"]))])])
	var stack: Dictionary = o.get("stack", {})
	var st_txt: Array[String] = []
	for r3 in present:
		var sv: Array = stack.get(r3, [1, 1])
		st_txt.append("%s %s" % [Loc.t(str((ArsenalData.RARITIES[r3] as Dictionary)["name"])), ("%d" % int(sv[0])) if int(sv[0]) == int(sv[1]) else "%d–%d" % [int(sv[0]), int(sv[1])]])
	rules.append(["blueprint", Loc.f("ODDS_STACK", [", ".join(st_txt)])])
	rules.append(["auto", Loc.t("ODDS_WILD")])
	rules.append(["target", Loc.t("ODDS_FOCUS")])
	rules.append(["deck", Loc.t("ODDS_DECK")])
	rules.append(["swap", Loc.t("ODDS_DUPES")])
	rules.append(["trophy", Loc.t("PITY_EPIC")])
	rules.append(["coin", "%s %s" % [Loc.f("ODDS_SLOTS", [int(o.get("slots", 3))]), Loc.t("ODDS_COINS")]])
	_body.add_child(UIKit.gap(18))
	var sec := UIKit.section("Гарантії та правила" if Loc.lang == "uk" else "Guarantees and rules", 18)
	_body.add_child(sec)
	_body.add_child(UIKit.gap(4))
	for rr: Array in rules:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 14)
		row2.custom_minimum_size.y = 44
		var ik := str(rr[0])
		var ic := Icons.make(ik, 28.0, Color.WHITE if KitIcons.has_painted(ik) else UIKit.INK_DIM)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row2.add_child(ic)
		var l2 := UIKit.label(str(rr[1]), 20, UIKit.INK, false)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l2.custom_minimum_size.x = 420.0
		row2.add_child(l2)
		_body.add_child(row2)
	_body.add_child(UIKit.gap(14))
	_body.add_child(UIKit.hairline())
	_body.add_child(UIKit.gap(12))
	_body.add_child(VaultView.PityBar.make())


## A table row: a faint wash of the gem's light from the left (Genshin rarity tint, no box)
## and the hairline under it.
class _TintRow extends HBoxContainer:
	var gem := "quartz"

	func _draw() -> void:
		var lc: Color = UITokens.gem(gem)["rim"]
		var a := Color(lc.r, lc.g, lc.b, 0.14)
		var z := Color(lc.r, lc.g, lc.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 2), Vector2(size.x * 0.6, 2), Vector2(size.x * 0.6, size.y - 2), Vector2(0, size.y - 2)]),
				PackedColorArray([a, z, z, a]))
		var y := size.y - 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5), 1.0, true)


class _Mark extends Control:
	var gem := "quartz"

	func _draw() -> void:
		GemDraw.draw_mark(self, gem, size * 0.5, minf(size.x, size.y) * 0.86)
