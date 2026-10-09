class_name PortalScreen
extends Control
## «Портал / Portal» (heroes_design.md §7.1-§7.3, §9.3 Portal row, §9.5; part U §2.8; fusion §6.8 #4).
## The one dark screen of the game: the Portal night sky with a big gold Portal ring on a crystal
## dais. Top bar = Beacons only (no shop link, no "+"). Pool carousel «Хто може з’явитися» with each
## hero's current chance under the card (generated, §9.5 row 3). One frosted glass panel holds the
## pity bar «Топаз або краще ≤ N» with the engraved «Аметист+ ≤ N» label and the Seals bar + «Вибір».
## Chips Фокус / Історія / Шанси. Dock: back · ×1 · ×10 (the amber jewel goes to the summon you can
## afford; ×10 first). Welcome state: one free ×10 under «Серед десяти — щонайменше Топаз».
## Never here: timers, banners, offers, a shop link, a price in money (§9.5 rows 1 and 4).
## Every number is read from HeroesUIModel (which reads PortalData); copy via HeroesText.
## Route "portal" (HeroesNav, host "screen"); args "seals" | "odds" | "history" | "focus" open that
## sheet over the Portal at once (part U §1.3 portal[/seals|/odds|/history|/focus]).

signal closed

var hub: Hub
var _open_sheet := ""
var _sky: PortalSky
var _ring: PortalRing
var _root: Control
var _title: Label
var _beacons: HeroCurrencyChip
var _pool_label: Label
var _pool_scroll: ScrollContainer
var _pool_row: HBoxContainer
var _panel: PanelContainer
var _pity: HeroEngravedBar
var _seals: HeroEngravedBar
var _seal_btn: Button
var _seals_label: Label
var _hint: Label
var _chips: HBoxContainer
var _rule: PanelContainer
var _dock: Control
var _back: Control
var _x1: Button
var _x10: Button
var _overlay: Control
var _sheet: Control
var _frost: HeroFrost
var _busy := false


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0:
		_open_sheet = str(args[0])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()
	_sky = PortalSky.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sky)
	# UI v3.1: the Portal's glass frosts the Portal night (its sky + the ring's light), not the hub.
	_frost = HeroFrost.attach(self)
	_ring = PortalRing.new()
	add_child(_ring)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	resized.connect(_layout)
	HeroesUIModel.bus().changed.connect(_on_changed)
	refresh()
	_layout()
	if not UITokens.reduce_motion():
		UIJuice.soft_in(_root, Vector2(0, 18))
	if _open_sheet != "":
		open_sheet.call_deferred(_open_sheet)


func _exit_tree() -> void:
	if HeroesUIModel.bus().changed.is_connected(_on_changed):
		HeroesUIModel.bus().changed.disconnect(_on_changed)


func _on_changed(what: String) -> void:
	if what in ["portal", "state", "heroes"] and is_inside_tree():
		refresh()


# ------------------------------------------------------------------ build

func _build() -> void:
	_title = UIKit.scene_label(HeroesText.t("PORTAL_TITLE"), 44)
	_root.add_child(_title)
	_beacons = HeroCurrencyChip.make("beacons", "0", 150)
	_beacons.tooltip_text = HeroesText.t("CUR_BEACON_NOTE")
	_root.add_child(_beacons)
	_pool_label = UIKit.scene_label(HeroesText.t("PORTAL_POOL"), 24)
	_root.add_child(_pool_label)
	_pool_scroll = ScrollContainer.new()
	_pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pool_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_pool_scroll)
	_pool_row = HBoxContainer.new()
	_pool_row.add_theme_constant_override("separation", 12)
	_pool_scroll.add_child(_pool_row)
	# The document panel: pity + Seals.
	# v3.1: frosted glass (the night glows through the rim), the pity / Seals rows on the text bed.
	_panel = PanelContainer.new()
	if not HeroFrost.frost_panel(_panel, "panel", Vector2(26, 18), _frost):
		_panel.free()
		_panel = UIKit.panel("banner", Vector2(26, 18))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_pity = HeroEngravedBar.make("L", 0, 30, 600)
	_pity.tick_every = 1.0
	col.add_child(_pity)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 14)
	col.add_child(srow)
	var sic := HeroIcons.make("seal", 44.0)
	sic.custom_minimum_size = Vector2(44, 44)
	sic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(sic)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(sv)
	_seals_label = UIKit.label("", 22, UITokens.INK_DIM_GLASS)
	_seals_label.clip_text = true
	_seals_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sv.add_child(_seals_label)
	_seals = HeroEngravedBar.make("E", 0, 40, 300)
	_seals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(_seals)
	_seal_btn = UIKit.button(HeroesText.t("PORTAL_SEALS_PICK"), false, 150)
	_seal_btn.custom_minimum_size = Vector2(150, 88)
	_seal_btn.pressed.connect(func(): open_sheet("seals"))
	srow.add_child(_seal_btn)
	# Out of Beacons: one quiet line on where they come from (never a shop link).
	_hint = UIKit.label(HeroesText.t("CUR_BEACON_NOTE"), 22, UITokens.INK_DIM_GLASS)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 300
	col.add_child(_hint)
	# Chips.
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 14)
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_chips)
	for c: Array in [["PORTAL_FOCUS", "target", "focus"], ["PORTAL_HISTORY", "calendar", "history"], ["PORTAL_ODDS", "odds", "odds"]]:
		var chip := HeroChip.make(HeroesText.t(str(c[0])), str(c[1]))
		chip.on_art = true
		var which := str(c[2])
		chip.pressed.connect(func(): open_sheet(which))
		_chips.add_child(chip)
	# Welcome rule slip (shown only in the welcome state).
	_rule = UIKit.panel("banner", Vector2(22, 10))
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 12)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	_rule.add_child(rr)
	var mark := _GemMark.new()
	mark.gem = "L"
	mark.custom_minimum_size = Vector2(40, 40)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rr.add_child(mark)
	var rl := UIKit.label(HeroesText.t("PORTAL_WELCOME_RULE"), 26, UITokens.INK, true)
	rr.add_child(rl)
	_root.add_child(_rule)
	# Dock.
	_dock = Control.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dock)
	# v3.1 (§7.9): back is a glass edge disc with one 1 dpx ring.
	_back = UIKit.edge_button("back", 38.0)
	_back.pressed.connect(close)
	_dock.add_child(_back)


func _summon_button(count: int, amber: bool, can: bool, cost: int, have: int, welcome: bool) -> Button:
	var label := HeroesText.t("PORTAL_X10" if count == PortalData.X10_SUMMONS else "PORTAL_X1")
	var sub := HeroesText.t("PORTAL_FREE") if welcome else (HeroesText.count(cost, "beacon") if can else HeroesText.t("PORTAL_NEED", [cost, have]))
	var b: Button
	if amber:
		var cta := UIKit.cta_button(label, sub, Vector2(160, 104), 30)
		cta.sub_size = 22
		cta.topaz = count == PortalData.X10_SUMMONS or welcome
		b = cta
	else:
		b = UIKit.button(label + "\n" + sub, false, 160)
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(160, 104)
	b.disabled = not can
	b.pressed.connect(func(): _summon(count))
	return b


# ------------------------------------------------------------------ data

func refresh() -> void:
	var ps := HeroesUIModel.portal_state()
	var welcome := bool(ps["welcome"])
	_beacons.value = HeroesText.num(int(ps["beacons"]))
	_sky.set_pool(ps["pool"])
	# Pool carousel: gem high -> low, then collector order; the current chance under each card.
	for ch in _pool_row.get_children():
		ch.queue_free()
	var odds := HeroesUIModel.odds_rows("portal")
	var pct := {}
	for r: Dictionary in odds["heroes"]:
		pct[str(r["id"])] = float(r["pct"])
	var pool: Array = (ps["pool"] as Array).duplicate()
	pool.sort_custom(func(a, b):
		var ga := Ladder.gem_index(HeroData.native(str(a)))
		var gb := Ladder.gem_index(HeroData.native(str(b)))
		if ga != gb:
			return ga > gb
		return int(HeroData.HEROES[str(a)]["no"]) < int(HeroData.HEROES[str(b)]["no"]))
	for id in pool:
		_pool_row.add_child(_pool_cell(str(id), float(pct.get(str(id), 0.0)), _first_of(str(id), pool)))
	# Pity: one bar, Topaz-or-better countdown; the Amethyst+ countdown engraved on the right.
	_pity.gem = "L"
	_pity.max_value = float(ps["pity_l_hard"])
	_pity.value = float(ps["since_l"])
	_pity.marker = float(ps["pity_l_soft"]) - 1.0
	_pity.label = HeroesText.t("PORTAL_PITY_L", [int(ps["pity_l_left"])])
	_pity.value_text = HeroesText.t("PORTAL_PITY_E", [int(ps["pity_e_left"])])
	# Seals: the next tier above the current count; "Вибір" lit whenever any tier is affordable.
	var seals := int(ps["seals"])
	var tgt: Dictionary = ps["seal_target"]
	var tg := str(tgt["gem"])
	var price := int(tgt["price"])
	_seals.gem = tg
	_seals.max_value = float(price)
	_seals.value = float(mini(seals, price))
	if seals >= PortalData.seal_price("M"):
		_seals_label.text = HeroesText.t("PORTAL_SEALS_ALL", [seals, HeroesText.gem_name("M")])
	else:
		_seals_label.text = HeroesText.t("PORTAL_SEALS", [seals, price, HeroesText.gem_name(tg)])
	var any := false
	for r: Dictionary in HeroesUIModel.seal_shop():
		if bool(r["affordable"]):
			any = true
	_seal_btn.disabled = not any
	# Dock buttons.
	for b in [_x1, _x10]:
		if b and is_instance_valid(b):
			b.queue_free()
	_x1 = null
	_x10 = null
	var have := int(ps["beacons"])
	var c1 := int(ps["cost_x1"])
	var c10 := int(ps["cost_x10"])
	if welcome:
		_x10 = _summon_button(PortalData.X10_SUMMONS, true, true, 0, have, true)
		_dock.add_child(_x10)
	else:
		var can10 := have >= c10
		var can1 := have >= c1
		_x1 = _summon_button(1, can1 and not can10, can1, c1, have, false)
		_x10 = _summon_button(PortalData.X10_SUMMONS, can10 or not can1, can10, c10, have, false)
		_dock.add_child(_x1)
		_dock.add_child(_x10)
	_rule.visible = welcome
	_hint.visible = not welcome and have < c1
	_panel.visible = true
	if is_node_ready():
		_layout()


func _pool_cell(id: String, p: float, first: String) -> Control:
	var h := HeroesUIModel.hero(id)
	var d := h.duplicate()
	# The Portal shows who CAN appear: never a lock disc here (unowned = what a summon brings).
	d["owned"] = true
	d["is_new"] = false
	d["facets"] = 0
	d["frags"] = 0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var card := HeroCard.make(d, "S")
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	# No 14 px footer sub-line on the S card: what a summon gives moves to the 22 px lines below.
	SummonFx.card_footer(card, "")
	card.pressed.connect(func(_id): open_sheet("odds"))
	box.add_child(card)
	var l := UIKit.scene_label(HeroesText.pct(p), 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var what := ""
	if p <= 0.0 and first != "":
		# Correct but reads like a bug without the rule: unowned heroes of a gem come first.
		what = HeroesText.t("PORTAL_POOL_FIRST", [HeroesText.hero_name(first)])
	elif bool(h["owned"]):
		what = HeroesText.t("SUMMON_FRAGS", [HeroData.dup_frags(HeroData.native(id))])
	else:
		what = HeroesText.t("PORTAL_POOL_NEW")
	# v3.1: warm white on the night for every line (amber is for the key verbs, never a label).
	var w := UIKit.label(what, 22, UITokens.ON_SCENE, not bool(h["owned"]))
	UIKit.soft_shadow(w, 22)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.custom_minimum_size.x = HeroCard.SIZES["S"].x
	box.add_child(w)
	return box


## The unowned hero of the same native gem that the Portal brings first (or "").
func _first_of(id: String, pool: Array) -> String:
	var g := HeroData.native(id)
	for o in pool:
		if HeroData.native(str(o)) == g and not bool(HeroesUIModel.hero(str(o))["owned"]):
			return str(o)
	return ""


# ------------------------------------------------------------------ layout

func _layout() -> void:
	var W := size.x
	var H := size.y
	if W < 10.0:
		return
	var ins := UIKit.safe_insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	var g := UITokens.GUTTER
	var top := ins.y
	_title.position = Vector2(g, top + 18)
	_beacons.size = _beacons.custom_minimum_size
	_beacons.position = Vector2(W - 14.0 - _beacons.size.x - ins.z, top + 22)
	_pool_label.position = Vector2(g, top + 100)
	_pool_scroll.position = Vector2(0, top + 136)
	_pool_scroll.size = Vector2(W, 186 + 64)
	_pool_row.add_theme_constant_override("separation", 12)
	_pool_scroll.get_h_scroll_bar().visible = false
	# Margins inside the carousel (gutter left and right).
	_pool_row.custom_minimum_size.x = 0
	if _pool_row.get_child_count() > 0 and not _pool_row.has_meta("pad"):
		_pool_row.set_meta("pad", true)
	_pool_scroll.position.x = g
	_pool_scroll.size.x = W - g
	var pool_bottom := _pool_scroll.position.y + _pool_scroll.size.y
	# Bottom up: dock, chips, panel.
	var dock_h := 104.0
	var dock_y := H - ins.w - 28.0 - dock_h
	_dock.position = Vector2(g, dock_y)
	_dock.size = Vector2(W - 2.0 * g, dock_h)
	_back.size = _back.get_combined_minimum_size()
	_back.position = Vector2((96.0 - _back.size.x) * 0.5, (dock_h - _back.size.y) * 0.5)
	var avail := _dock.size.x - 96.0 - 12.0
	if _x1 and _x10:
		# The amber jewel (the summon you can afford) gets the larger share.
		var w1 := roundf(avail * (0.42 if _x10 is KitCTA else 0.56))
		_x1.position = Vector2(108, 0)
		_x1.size = Vector2(w1 - 6.0, dock_h)
		_x10.position = Vector2(108 + w1 + 6.0, 0)
		_x10.size = Vector2(avail - w1 - 6.0, dock_h)
	elif _x10:
		_x10.position = Vector2(108, 0)
		_x10.size = Vector2(avail, dock_h)
	var chips_h := 88.0
	var chips_y := dock_y - 14.0 - chips_h
	_chips.position = Vector2(g, chips_y)
	_chips.size = Vector2(W - 2.0 * g, chips_h)
	_panel.size = Vector2(W - 2.0 * g, 0)
	_panel.reset_size()
	_panel.size.x = W - 2.0 * g
	var ph := _panel.get_combined_minimum_size().y
	var panel_y := chips_y - 10.0 - ph
	_panel.position = Vector2(g, panel_y)
	# The ring takes the band between the pool and the panel (it grows on tall phones).
	var band_top := pool_bottom + 8.0
	var band_bot := panel_y - 6.0
	if _rule.visible:
		var rs := _rule.get_combined_minimum_size()
		_rule.size = rs
		_rule.position = Vector2((W - rs.x) * 0.5, panel_y - 14.0 - rs.y)
		band_bot = _rule.position.y - 4.0
	var band := maxf(band_bot - band_top, 200.0)
	var D := minf(W * 0.76, band * 1.0)
	_ring.size = Vector2(D, D)
	_ring.position = Vector2((W - D) * 0.5, band_top + (band - D * 1.02) * 0.5 - D * 0.02)
	if _frost:
		var rr := Rect2(_ring.position - Vector2(D, D) * 0.25, Vector2(D, D) * 1.5)
		_frost.set_layers([{"mat": _sky.material, "rect": Rect2(Vector2.ZERO, Vector2(W, H))},
				{"tex": UIKit.glow_texture(), "rect": rr, "mod": Color(0.86, 0.72, 0.5, 0.55)}])


# ------------------------------------------------------------------ actions

func _summon(count: int) -> void:
	if _busy:
		return
	_busy = true
	UIJuice.haptic("CLICK", 0.6)
	var c := HeroesNav.open(hub, "summon/x10" if count == PortalData.X10_SUMMONS else "summon/x1", self)
	if c and c.has_signal("closed"):
		c.closed.connect(func(): _busy = false)
	else:
		_busy = false


## Opens a sheet over the Portal (inside this screen, above the ring; the hub's modal layer sits
## under full screens): "odds" | "seals" | "history" | "focus".
func open_sheet(which: String) -> void:
	if _sheet and is_instance_valid(_sheet):
		return
	var path := str({"odds": "res://scripts/ui/summon/odds_sheet.gd", "seals": "res://scripts/ui/summon/seal_shop.gd",
			"history": "res://scripts/ui/summon/history_sheet.gd", "focus": "res://scripts/ui/summon/focus_sheet.gd"}.get(which, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var s: Control = (load(path) as GDScript).new()
	if s.has_method("setup"):
		s.call("setup", hub, PackedStringArray(["embedded"]))
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(holder)
	var dim := ColorRect.new()
	dim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", UITokens.SCRIM_MODAL, UITokens.MENU_IN)
	dim.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			_close_sheet())
	holder.add_child(s)
	_sheet = holder
	if s.has_signal("closed"):
		s.connect("closed", _close_sheet)
	if s.has_signal("picked"):
		s.connect("picked", _on_seal_picked)


func _close_sheet() -> void:
	if _sheet and is_instance_valid(_sheet):
		var h := _sheet
		_sheet = null
		h.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		var tw := h.create_tween()
		tw.tween_property(h, "modulate:a", 0.0, UITokens.MENU_OUT)
		tw.tween_callback(h.queue_free)


func _on_seal_picked(id: String) -> void:
	_close_sheet()
	HeroesNav.open(hub, "summon/seal/" + id, self)


func close() -> void:
	closed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and HeroesNav.top() == self:
		if _sheet and is_instance_valid(_sheet):
			_close_sheet()
		else:
			close()


## A gem-cut mark (GemDraw.draw_mark) as a Control.
class _GemMark extends Control:
	var gem := "L"

	func _draw() -> void:
		GemDraw.draw_mark(self, UITokens.gem_of(gem), size * 0.5, minf(size.x, size.y) * 0.62)
