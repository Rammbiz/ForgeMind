extends Control
## Казарми tab (arsenal_design.md §4.2, §7.1; UI v2): the Crystal Knights in formation on the
## ivory dais in a sunlit hall (warm haze, a sunbeam, a soft floor), the screen title and the
## world cap chip, then the cream sheet with the arched top: the five tracks (Новобранці,
## Резерв, Обережність, Муштра, Залпи) as clean list rows with hairlines - a line icon in a
## thin gold ring, the name and level, bridge-tile progress up to the world cap, the effect now
## and the next level's gain, and a cream price button. The one amber jewel is «Покращити все»
## (buys the cheapest affordable levels in one go). Buying is a micro ceremony (glints on the
## row, the knights cheer).

const STRIP_H := 330.0          ## the army stage at H 1280 (grows on tall phones)
const ICONS := {"recruits": "team", "reserves": "helmet", "scrape_guard": "cls_guardian", "drill": "target", "volleys": "cls_ranger"}
const T := {
	"BAR_SECTION": ["Муштра армії", "Army training"],
}

var hub: Hub
var _stage: _HallStage
var _strip: Control
var _show: HubShowcase
var _cap_lbl: Label
var _sheet: KitSheet
var _list: VBoxContainer
var _all_btn: KitCTA
var _all_armed := false
var _all_total := 0


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = T.get(key, [key, key])
	return str(row[0] if Loc.lang == "uk" else row[1])


func setup(p_hub: Hub) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = _HallStage.new()
	_stage.page = self
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_show = HubShowcase.new("army")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.offset_top = 40.0
	_show.offset_bottom = 70.0
	_strip.add_child(_show)
	var title := UIKit.gradient_heading(Loc.t("TAB_BARRACKS"), 40)
	title.position = Vector2(UITokens.GUTTER, 4)
	_strip.add_child(title)
	var cap := UIKit.glass_panel(Vector2(14, 6))
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cap.position = Vector2(-UITokens.GUTTER, 12)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ci := Icons.make("tab_barracks", 28.0)
	ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(ci)
	_cap_lbl = UIKit.label("", 22, UIKit.INK)
	crow.add_child(_cap_lbl)
	cap.add_child(crow)
	_strip.add_child(cap)
	_cap_chip = cap
	# The cream sheet (placed by hand: it runs under the nav, the content stops at the page bottom).
	_sheet = UIKit.sheet(Vector2(UITokens.GUTTER, 12))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_sheet.add_child(col)
	col.add_child(UIKit.gap(4))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_list)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.custom_minimum_size.y = 100
	_all_btn = UIKit.cta_button(Loc.t("BAR_ALL"), "", Vector2(440, 88), 32)
	_all_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_all_btn.pressed.connect(_buy_all)
	arow.add_child(_all_btn)
	col.add_child(arow)
	var foot := UIKit.gap(0)
	foot.name = "Foot"
	col.add_child(foot)
	resized.connect(_layout)
	_sheet.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	_layout()
	_layout.call_deferred()
	refresh()
	UIJuice.sheet_in(_sheet)


var _cap_chip: PanelContainer


func _layout() -> void:
	var below := _below_page()
	# Tall phones: the hall grows (the sheet keeps its chrome).
	var strip_h := STRIP_H + maxf(0.0, size.y - 994.0)
	_strip.position = Vector2.ZERO
	_strip.size = Vector2(size.x, strip_h)
	_sheet.position = Vector2(-2.0, strip_h)
	_sheet.size = Vector2(size.x + 4.0, size.y - strip_h + below)
	var foot := _sheet.get_child(0).get_node_or_null("Foot") as Control
	if foot:
		foot.custom_minimum_size.y = maxf(0.0, below - 10.0)
	_stage.floor_y = strip_h
	_stage.queue_redraw()


func _below_page() -> float:
	if not is_inside_tree():
		return UITokens.TAB_BAR_H + 34.0
	var vp := get_viewport().get_visible_rect().size
	return maxf(0.0, vp.y - get_global_rect().end.y)


func on_show() -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var cap := Meta.barracks_cap()
	_cap_lbl.text = Loc.f("BAR_CAP", [cap])
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var any := false
	for t in EconData.BARRACKS_ORDER:
		_list.add_child(_row(t, cap))
		any = any or Meta.can_buy_barracks(t)
	_all_btn.disabled = not any
	_all_total = _buy_all_total()
	_all_armed = false
	_all_btn.text = Loc.t("BAR_ALL")
	_all_btn.sub = Loc.f("COINS_SHORT", [Loc.num(_all_total)]) if any else ""


## What "Покращити все" would spend (simulated on a copy of the account: cheapest first).
func _buy_all_total() -> int:
	var acc: Dictionary = Meta.account.duplicate(true)
	var before := MetaAcc.amount(acc, "coins")
	for _i in 60:
		var best := ""
		var best_cost := 1 << 30
		for t in EconData.BARRACKS_ORDER:
			if Barracks.can_buy(acc, t) and Barracks.cost(acc, t) < best_cost:
				best = t
				best_cost = Barracks.cost(acc, t)
		if best == "" or not bool(Barracks.buy(acc, best).get("ok", false)):
			break
	return before - MetaAcc.amount(acc, "coins")


## The effect number alone ("+2", "+6%", "+1,5") for the "Далі" line.
static func value_short(track: String, lvl: int) -> String:
	var v := EconData.barracks_value(track, lvl)
	if track in ["drill", "volleys"]:
		return "+%d%%" % int(round(v * 100.0))
	return "+" + _num(v)


static func value_text(track: String, lvl: int) -> String:
	var v := EconData.barracks_value(track, lvl)
	var def: Dictionary = EconData.BARRACKS[track]
	match track:
		"drill", "volleys":
			return Loc.f(str(def["desc"]), [int(round(v * 100.0))])
	if not is_equal_approx(v, round(v)):
		return Loc.f("BAR_RECRUITS_DESC_F", [_num(v)])
	return Loc.f(str(def["desc"]), [int(round(v))])


## 2 -> "2", 1.5 -> "1,5" (uk) / "1.5" (en).
static func _num(v: float) -> String:
	if is_equal_approx(v, round(v)):
		return str(int(round(v)))
	var s := "%.1f" % v
	return s.replace(".", ",") if Loc.lang == "uk" else s


## One track as a list row: socket · name + level, tiles to the cap, effect now / next · price.
func _row(track: String, cap: int) -> Control:
	var def: Dictionary = EconData.BARRACKS[track]
	var lvl := Meta.barracks_level(track)
	var r := UIKit.KitRow.new()
	r.custom_minimum_size = Vector2(0, 104)
	r.add_theme_constant_override("separation", 14)
	var sock := UIKit.socket(str(ICONS.get(track, "team")), 56.0)
	sock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(sock)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	# v3 (§5, MF-15): every line >= 22 px on the glass. Name + level and the next level's gain
	# share the first line; the tiles; the effect now (wraps).
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UIKit.label(Loc.t(str(def["name"])), 24, UIKit.INK))
	var lv := UIKit.label("%d / %d" % [lvl, cap], 22, UIKit.INK_DIM)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(lv)
	if lvl > 0 and lvl < cap:
		name_row.add_child(UIKit.spacer())
		var nx := UIKit.label(Loc.f("BAR_NEXT", [value_short(track, lvl + 1)]), 22, UIKit.PLUS)
		nx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(nx)
	v.add_child(name_row)
	var bar := UIKit.progress(lvl, cap, 300.0, 7.0, cap)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(bar)
	var eff := UIKit.label(value_text(track, maxi(lvl, 1)), 22, UIKit.INK_DIM)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.custom_minimum_size.x = 300.0
	v.add_child(eff)
	r.add_child(v)
	var can := Meta.can_buy_barracks(track)
	var btn := UIKit.button("", false, 132.0)
	btn.custom_minimum_size = Vector2(132, 72)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bc := HBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bc.alignment = BoxContainer.ALIGNMENT_CENTER
	bc.add_theme_constant_override("separation", 6)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lvl >= cap:
		bc.add_child(UIKit.label(Loc.t("MAX"), 22, UIKit.INK_DIM, true))
		btn.disabled = true
	else:
		var coin := Icons.make("coin", 28.0)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.modulate = Color.WHITE if can else Color(1, 1, 1, 0.55)
		bc.add_child(coin)
		var cost := Meta.barracks_cost(track)
		var pl := UIKit.label(Loc.num(cost), 22, UIKit.INK if can else (UIKit.ALERT if cost > Meta.currency("coins") else UIKit.INK_DIM), true)
		bc.add_child(pl)
	btn.add_child(bc)
	btn.pressed.connect(func(): _buy(track, sock, bar))
	r.add_child(btn)
	return r


## Dev tools / screenshots: buys the first affordable track.
func buy_first() -> void:
	for i in EconData.BARRACKS_ORDER.size():
		var t: String = EconData.BARRACKS_ORDER[i]
		if Meta.can_buy_barracks(t):
			var row := _list.get_child(i)
			_buy(t, row.get_child(0) as Control, null)
			return


func _buy(track: String, at: Control, bar: Control) -> void:
	var res := Meta.buy_barracks(track)
	if not bool(res.get("ok", false)):
		Audio.play("error", -6.0)
		return
	var pos := at.get_global_rect().get_center() - global_position if is_instance_valid(at) else size * 0.5
	refresh()
	_celebrate(pos)
	# Punch the new row's tiles.
	var i := EconData.BARRACKS_ORDER.find(track)
	if i >= 0 and i < _list.get_child_count():
		var row := _list.get_child(i)
		var s := row.get_child(0) as Control
		s.pivot_offset = Vector2(28, 28)
		UIJuice.punch(s, 1.18, 0.2)


func _buy_all() -> void:
	# Two taps, like every other upgrade: the first shows the total ("Підтвердити · 2 320").
	if not _all_armed and Meta.can_buy_barracks(_cheapest()):
		_all_armed = true
		_all_btn.text = Loc.f("BUY_ALL_CONFIRM", [Loc.num(_all_total)])
		_all_btn.sub = ""
		UIJuice.punch(_all_btn, 1.04, 0.2)
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(self) and _all_armed:
				refresh())
		return
	_all_armed = false
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
		var pos := _all_btn.get_global_rect().get_center() - global_position
		refresh()
		_celebrate(pos)
		_celebrate(_show.get_global_rect().get_center() - global_position)
	else:
		Audio.play("error", -6.0)
		UIJuice.wobble(_all_btn, 0.3, 0.3)


func _cheapest() -> String:
	var best := ""
	var best_cost := 1 << 30
	for t in EconData.BARRACKS_ORDER:
		if Meta.can_buy_barracks(t) and Meta.barracks_cost(t) < best_cost:
			best = t
			best_cost = Meta.barracks_cost(t)
	return best


func _celebrate(pos: Vector2) -> void:
	Audio.play("upgrade", -3.0)
	UIJuice.flare(self, pos, Color(1.0, 0.82, 0.45), "micro", 80.0)
	UIKit.sparkles(self, pos, UITokens.CTA_HI, 12, 160.0)
	UIJuice.haptic("CLICK", 0.6)
	_show.cheer()


## The page backdrop: a sunlit hall (warm paper haze, a sunbeam from the upper left, a soft
## warm light pool behind the formation, a gentle floor band). v3.1 (§4.5): the haze alphas
## are x 0.55 and there is no vignette, so the hub's frosted world shows through the hall.
class _HallStage extends Control:
	const HAZE := 0.55
	var page: Control
	var floor_y := 330.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var vp := get_viewport().get_visible_rect().size
		var gp := get_global_rect().position
		var full := Rect2(-gp, vp)
		var x0 := full.position.x
		var x1 := full.end.x
		var y0 := full.position.y
		var y1 := floor_y
		var top := UITokens.PAPER_0.lerp(Color("#F3E6CF"), 0.45)
		var mid := Color("#EEDFC4")
		var low := UITokens.STAGE_TOP
		top.a = HAZE
		mid.a = HAZE
		low.a = HAZE
		var ym := lerpf(y0, y1, 0.55)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, ym), Vector2(x0, ym)]), PackedColorArray([top, top, mid, mid]))
		draw_polygon(PackedVector2Array([Vector2(x0, ym), Vector2(x1, ym), Vector2(x1, y1 + 60.0), Vector2(x0, y1 + 60.0)]), PackedColorArray([mid, mid, low, low]))
		# Sunbeam from the upper left.
		var sun := Color(UITokens.SUN.r, UITokens.SUN.g, UITokens.SUN.b, 0.24 * HAZE)
		var clear := Color(sun.r, sun.g, sun.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(-40, y0), Vector2(240, y0), Vector2(size.x * 0.8, y1), Vector2(size.x * 0.3, y1)]),
				PackedColorArray([sun, sun, clear, clear]))
		# Warm light pool behind the formation.
		var cx := size.x * 0.5
		var cy := y1 * 0.6
		var R := size.x * 0.55
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(cx - R, cy - R * 0.7), Vector2(R * 2.0, R * 1.4)), false, Color(1.0, 0.93, 0.75, 0.6 * HAZE))
		# Soft floor band where the dais stands.
		var fl := UITokens.STAGE_BOTTOM
		var fl0 := Color(fl.r, fl.g, fl.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, y1 - 80.0), Vector2(x1, y1 - 80.0), Vector2(x1, y1 + 20.0), Vector2(x0, y1 + 20.0)]),
				PackedColorArray([fl0, fl0, Color(fl.r, fl.g, fl.b, 0.5 * HAZE), Color(fl.r, fl.g, fl.b, 0.5 * HAZE)]))
