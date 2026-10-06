extends Control
## Казарми tab (arsenal_design.md §4.2, §7.1): the Crystal Knights in formation on a stone dais,
## the world cap, and a parchment list of the five tracks (Новобранці, Резерв, Обережність,
## Муштра, Залпи): icon, level pips up to the world cap, the effect now and after the next level,
## and the price. Buying is a micro ceremony (the knights cheer); "Покращити все" buys the
## cheapest affordable levels in one go.

var hub: Hub
var _show: HubShowcase
var _cap_lbl: Label
var _list: VBoxContainer
var _all_btn: Button


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 250)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)
	_show = HubShowcase.new("army")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(_show)
	var title := UIKit.gradient_heading(Loc.t("TAB_BARRACKS"), 52)
	title.position = Vector2(UITokens.GUTTER, 0)
	strip.add_child(title)
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", UIKit.lux("pill", Vector2(16, 6)))
	cap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cap.position = Vector2(-UITokens.GUTTER - 230, 12)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	crow.add_child(Icons.make("tab_barracks", 28.0))
	_cap_lbl = UIKit.heading("", 22, UIKit.GOLD_LIGHT, 5)
	crow.add_child(_cap_lbl)
	cap.add_child(crow)
	strip.add_child(cap)
	var pwrap := MarginContainer.new()
	pwrap.add_theme_constant_override("margin_left", 12)
	pwrap.add_theme_constant_override("margin_right", 12)
	pwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.lux("parch", Vector2(18, 18)))
	pwrap.add_child(panel)
	col.add_child(pwrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	v.add_child(_list)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	_all_btn = UIKit.styled_button(Loc.t("BAR_ALL"), "green", Vector2(380, 74), 28)
	_all_btn.pressed.connect(_buy_all)
	arow.add_child(_all_btn)
	v.add_child(arow)
	refresh()


func on_show() -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var cap := Meta.barracks_cap()
	_cap_lbl.text = Loc.f("BAR_CAP", [cap])
	for c in _list.get_children():
		c.queue_free()
	var any := false
	for t in EconData.BARRACKS_ORDER:
		_list.add_child(_row(t, cap))
		any = any or Meta.can_buy_barracks(t)
	_all_btn.disabled = not any
	_all_btn.modulate = Color.WHITE if any else Color(1, 1, 1, 0.6)


## The effect number alone ("+2", "+6%") for the "Далі" line.
static func value_short(track: String, lvl: int) -> String:
	var v := EconData.barracks_value(track, lvl)
	if track in ["drill", "volleys"]:
		return "+%d%%" % int(round(v * 100.0))
	return "+%d" % int(round(v))


static func value_text(track: String, lvl: int) -> String:
	var v := EconData.barracks_value(track, lvl)
	var def: Dictionary = EconData.BARRACKS[track]
	match track:
		"drill", "volleys":
			return Loc.f(str(def["desc"]), [int(round(v * 100.0))])
	return Loc.f(str(def["desc"]), [int(round(v))])


func _row(track: String, cap: int) -> Control:
	var def: Dictionary = EconData.BARRACKS[track]
	var lvl := Meta.barracks_level(track)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("parch_card", Vector2(12, 8)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var medal := Medal.new()
	medal.icon = {"recruits": "recruits", "reserves": "reserves", "scrape_guard": "shield", "drill": "drill", "volleys": "volley"}.get(track, "soldier")
	medal.custom_minimum_size = Vector2(72, 72)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UIKit.label(Loc.t(str(def["name"])), 26, UITokens.PARCH_INK, true))
	var pips := Pips.new()
	pips.lvl = lvl
	pips.cap = cap
	pips.custom_minimum_size = Vector2(16 * cap, 22)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(pips)
	v.add_child(name_row)
	var eff := lvl if lvl > 0 else 1
	var now := UIKit.label(value_text(track, eff) if lvl > 0 else value_text(track, 1), 19, UITokens.PARCH_INK_DIM, false)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if lvl == 0:
		now.text = value_text(track, 1)
	v.add_child(now)
	if lvl > 0 and lvl < cap:
		var nx := UIKit.label(Loc.f("BAR_NEXT", [value_short(track, lvl + 1)]), 19, Color(0.12, 0.5, 0.16), true)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nx)
	row.add_child(v)
	var can := Meta.can_buy_barracks(track)
	var btn := UIKit.styled_button("", "green" if can else "button", Vector2(150, 70))
	var bc := HBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bc.offset_bottom = -6
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.add_theme_constant_override("separation", 5)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lvl >= cap:
		bc.add_child(UIKit.heading(Loc.t("MAX"), 24, UIKit.TEXT_DIM, 5))
		btn.disabled = true
	else:
		bc.add_child(Icons.make("coin", 28.0))
		bc.add_child(UIKit.heading(Loc.num(Meta.barracks_cost(track)), 24, Color(1, 1, 1) if can else UIKit.TEXT_DIM, 6))
	btn.add_child(bc)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): _buy(track, medal))
	row.add_child(btn)
	return p


func _buy(track: String, medal: Control) -> void:
	var res := Meta.buy_barracks(track)
	if not bool(res.get("ok", false)):
		Audio.play("error", -6.0)
		return
	_celebrate(medal)
	refresh()


func _buy_all() -> void:
	var bought := 0
	for _i in 60:
		var best := ""
		var best_cost := 1 << 30
		for t in EconData.BARRACKS_ORDER:
			if Meta.can_buy_barracks(t) and Meta.barracks_cost(t) < best_cost:
				best = t
				best_cost = Meta.barracks_cost(t)
		if best == "":
			break
		if not bool(Meta.buy_barracks(best).get("ok", false)):
			break
		bought += 1
	if bought > 0:
		_celebrate(_all_btn)
		refresh()
	else:
		Audio.play("error", -6.0)


func _celebrate(at: Control) -> void:
	Audio.play("upgrade", -3.0)
	if is_instance_valid(at):
		UIJuice.flare(self, at.get_global_rect().get_center() - global_position, UIKit.GOLD_LIGHT, "micro", 80.0)
	_show.cheer()


## Round gold medallion with a track icon.
class Medal extends Control:
	var icon := "soldier"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c + Vector2(0, 3), r, Color(0.3, 0.15, 0.03, 0.4))
		draw_circle(c, r, Color(0.55, 0.3, 0.08))
		draw_circle(c + Vector2(0, -1), r - 2.0, Color(1.0, 0.86, 0.45))
		draw_circle(c, r - 5.0, Color(0.2, 0.24, 0.42))
		draw_circle(c + Vector2(0, -r * 0.15), r * 0.62, Color(0.28, 0.34, 0.58))
		Icons.draw_icon(self, icon, Rect2(c - Vector2(r, r) * 0.66, Vector2(r, r) * 1.32))


## Level pips up to the world cap (gold filled, cream empty).
class Pips extends Control:
	var lvl := 0
	var cap := 4

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in cap:
			var c := Vector2(8 + i * 16, size.y * 0.5)
			var dm := PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
			draw_colored_polygon(dm, Color(0.42, 0.24, 0.08))
			var dm2 := PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, 0), c + Vector2(0, 6), c + Vector2(-4.5, 0)])
			draw_colored_polygon(dm2, Color(1.0, 0.75, 0.25) if i < lvl else Color(0.95, 0.88, 0.72))
