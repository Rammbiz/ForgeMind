class_name OddsView
extends Control
## Odds and guarantees (arsenal_design.md §5.4-5.5, §6.7; the (i) screen): for the player's
## CURRENT pool, per Cache type - every rarity present with its chance per card and as the best
## card, the guaranteed last card, blueprints per card, the Wild chance, Focus and Deck weights,
## duplicate protection, the Epic pity and the Legendary pity bar. Exact numbers from Meta.odds().

var hub: Hub
var type := "stone"
var _sheet: PanelContainer
var _body: VBoxContainer


func setup(p_hub: Hub, p_type: Variant = "stone") -> void:
	hub = p_hub
	type = str(p_type) if EconData.CACHES.has(str(p_type)) else "stone"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(26, 26)))
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 18 + ins.x
	_sheet.offset_right = -18 - ins.z
	_sheet.offset_top = ins.y + 60
	_sheet.offset_bottom = -ins.w - 60
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_sheet.add_child(col)
	var t := UIKit.gradient_heading(Loc.t("ODDS_TITLE"), 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var sub := UIKit.label(Loc.t("ODDS_POOL"), 20, UIKit.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var seg := UIKit.segmented([["stone", Loc.t("CACHE_STONE")], ["world", Loc.t("CACHE_WORLD")]], type, func(id: String):
		type = id
		_fill(), 60.0, 22)
	col.add_child(seg)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(sc)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	sc.add_child(_body)
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
		c.queue_free()
	var o := Meta.odds(type)
	var present: Array = o.get("present", [])
	# Header row
	var head := HBoxContainer.new()
	var h0 := UIKit.label(Loc.t("RARITY"), 19, UIKit.TEXT_DIM, true)
	h0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h0)
	for k in ["ODDS_PER_CARD", "ODDS_BEST"]:
		var hl := UIKit.label(Loc.t(k), 19, UIKit.TEXT_DIM, true)
		hl.custom_minimum_size = Vector2(170, 0)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(hl)
	_body.add_child(head)
	var per: Dictionary = o.get("per_card", {})
	var best: Dictionary = o.get("best", {})
	for r in ArsenalData.RARITY_ORDER:
		if not present.has(r):
			continue
		var p := PanelContainer.new()
		var rc := UITokens.rarity(r)
		p.add_theme_stylebox_override("panel", UIKit.box(Color(rc.r * 0.14, rc.g * 0.14, rc.b * 0.2, 0.9), Color(rc.r, rc.g, rc.b, 0.65), 16, 2, 0, Vector2(14, 8)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var gem := Control.new()
		gem.custom_minimum_size = Vector2(26, 26)
		gem.draw.connect(func():
			var c := Vector2(13, 13)
			gem.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, 0), c + Vector2(0, 12), c + Vector2(-10, 0)]), rc))
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(gem)
		var n := UIKit.heading(Loc.t(str((ArsenalData.RARITIES[r] as Dictionary)["name"])), 26, rc.lightened(0.3), 5)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		for v: float in [float(per.get(r, 0.0)), float(best.get(r, 0.0))]:
			var l := UIKit.heading(pct(v), 26, UIKit.TEXT, 5)
			l.custom_minimum_size = Vector2(150, 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(l)
		p.add_child(row)
		_body.add_child(p)
	# Rules
	var guar: Dictionary = o.get("guaranteed", {})
	var gmin := ""
	for r2 in ArsenalData.RARITY_ORDER:
		if float(guar.get(r2, 0.0)) > 0.0:
			gmin = r2
			break
	var rules: Array = []
	if gmin != "":
		rules.append(["star", Loc.f("ODDS_GUARANTEED", [Loc.t(str((ArsenalData.RARITIES[gmin] as Dictionary)["name"]))])])
	var stack: Dictionary = o.get("stack", {})
	var st_txt: Array[String] = []
	for r3 in present:
		var sv: Array = stack.get(r3, [1, 1])
		st_txt.append("%s %s" % [Loc.t(str((ArsenalData.RARITIES[r3] as Dictionary)["name"])), ("%d" % int(sv[0])) if int(sv[0]) == int(sv[1]) else "%d-%d" % [int(sv[0]), int(sv[1])]])
	rules.append(["blueprint", Loc.f("ODDS_STACK", [", ".join(st_txt)])])
	rules.append(["wild", Loc.t("ODDS_WILD")])
	rules.append(["focus", Loc.t("ODDS_FOCUS")])
	rules.append(["deck", Loc.t("ODDS_DECK")])
	rules.append(["crown", Loc.t("ODDS_DUPES")])
	rules.append(["laurel", Loc.t("PITY_EPIC")])
	rules.append(["coin", "%s %s" % [Loc.f("ODDS_SLOTS", [int(o.get("slots", 3))]), Loc.t("ODDS_COINS")]])
	_body.add_child(UIKit.gap(6))
	for rr: Array in rules:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 12)
		row2.add_child(Icons.make(str(rr[0]), 30.0))
		var l2 := UIKit.label(str(rr[1]), 21, UIKit.TEXT, false)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(l2)
		_body.add_child(row2)
	_body.add_child(UIKit.gap(6))
	_body.add_child(VaultView.PityBar.make())
