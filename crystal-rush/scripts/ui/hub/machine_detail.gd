class_name MachineDetail
extends Control
## Machine detail (arsenal_design.md §7.2, card §6.2, upgrade §6.3), UI v2: the Genshin
## character-screen analogue in portrait (fusion §2.11 / §6.8, ui_v2_contract). The top band is
## a soft stage in the machine's gem colour (gradient, light pool, that gem's fracture planes)
## with the machine on the 3D turntable, its name in warm white with a soft shadow, porcelain
## chips (gem-cut rarity mark, family socket, verb) and the level. Below, the frosted bottom sheet
## (v3.1: straight fading top rule, text bed under the rows) carries Genshin underline tabs - Характеристики (hairline stat rows with
## line icons and +deltas, no boxes; status chips; Cache Focus), Віхи (the Lv1-15 facet track
## and the beat list), Таланти (Talents I/II as choice cards, free swap) - and a fixed dock: the
## blueprint bar (own share amber, Wild share amethyst) and the cost chip + the amber
## «Покращити» CTA. Two-tap upgrade: tap 1 arms ("Підтвердити · 1 260" + "використає N
## диких"), tap 2 runs the ceremony sized by the beat (standard 1.2 s, full ≤ 3 s). Unowned
## machines show where they are found instead of the CTA.

const STAT_ROWS := [
	["damage", "STAT_DAMAGE", "cls_warrior"], ["rate", "STAT_RATE", "auto"], ["range", "STAT_RANGE", "target"],
	["pierce", "STAT_PIERCE", "el_kinetic"], ["bolts", "STAT_BOLTS", "cls_ranger"], ["splash", "STAT_SPLASH", "el_plasma"],
	["radius", "STAT_RADIUS", "portal"], ["volley", "STAT_VOLLEY", "sort"], ["drones", "STAT_DRONES", "el_tech"],
	["charge", "STAT_CHARGE", "el_volt"], ["amp", "STAT_AMP", "plus"],
]
## Beat -> line icon (crown is the painted one).
const BEAT_ICONS := {"talent1": "quests", "lead": "crown", "talent2": "quests", "ascension": "fac_stoneheart",
		"talent3": "quests", "apex": "target", "prestige": "fac_dawn", "mastered": "trophy"}
const SHEET_H := 700.0
## Strings this screen needs that Loc does not have yet (requested from the Loc owner); the
## Loc key wins as soon as it exists.
const FALLBACK := {
	"TALENTS": ["Таланти", "Talents"],
	"TAB_BEATS": ["Віхи", "Milestones"],
	"FOUND_AT": ["Де знайти: %s", "Found at: %s"],
	"LV_NOW": ["Рів. %d → %d", "Lv %d → %d"],
	"BEAT_DONE": ["Отримано", "Reached"],
	"BEAT_IN": ["через %d рів.", "in %d lv"],
}

var hub: Hub
var id := ""
var _stage: _GemStage
var _head: Control
var _sheet: KitSheet
var _show: HubShowcase
var _lv_lbl: Label
var _lv_word: Label
var _lv_max: Label
var _tabs: KitTabs
var _tab := "stats"
var _pages := {}
var _scroll: ScrollContainer
var _body: VBoxContainer
var _dock: VBoxContainer
var _bp: BpBar
var _cost: KitCurrencyPlate
var _upgrade_btn: KitCTA
var _armed := false
var _arm_timer: SceneTreeTimer
var _talent_box: Control
var _busy := false


func setup(p_hub: Hub, p_id: Variant = "") -> void:
	hub = p_hub
	id = str(p_id)


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = FALLBACK.get(key, [key, key])
	return str(row[0] if Loc.lang == "uk" else row[1])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Meta.machine_changed.connect(_on_machine_changed)
	Meta.wallet_changed.connect(func(_c: String, _v: int): _refresh_upgrade())
	Meta.focus_changed.connect(func(_f: String): _rebuild_body())
	await get_tree().process_frame
	UIJuice.soft_in(_head, Vector2(0, -12))
	UIJuice.sheet_in(_sheet)


func play_exit() -> Tween:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_property(_sheet, "position:y", _sheet.position.y + UITokens.MENU_SLIDE, UITokens.MENU_OUT)
	return tw


func _on_machine_changed(mid: String) -> void:
	if mid == id and not _busy:
		_rebuild_body()


func _build() -> void:
	var ins := hub.insets()
	var c := Meta.machine_card(id)
	# Stage (full screen behind everything).
	_stage = _GemStage.new()
	_stage.gem = UITokens.gem_of(str(c["rarity"]))
	_stage.sheet_h = SHEET_H + ins.w
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	# The machine on the turntable: from under the header down into the sheet's arch.
	_show = HubShowcase.new("machine")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	_show.offset_top = ins.y + 110.0
	_show.offset_bottom = -(SHEET_H + ins.w) + 46.0
	_show.offset_left = 40.0
	_show.offset_right = -40.0
	add_child(_show)
	_show.show_machine(id, int(c["lvl"]), str(c["locked"]) != "")
	# Header: back, name, chips, level.
	_head = Control.new()
	_head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_head.offset_top = ins.y
	_head.offset_left = ins.x
	_head.offset_right = -ins.z
	_head.offset_bottom = ins.y + 180.0
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head)
	var back := UIKit.edge_button("back", 30.0)
	back.position = Vector2(UITokens.GUTTER - 4.0, 16.0)
	back.pressed.connect(func(): hub.pop_modal())
	_head.add_child(back)
	var tv := VBoxContainer.new()
	tv.position = Vector2(UITokens.GUTTER, 88.0)
	tv.add_theme_constant_override("separation", 6)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(tv)
	var title := UIKit.scene_label(Loc.t(str(c["name"])), 44)
	title.add_theme_font_size_override("font_size", UIKit.fit_size(title.text, 470.0, 44, 30))
	tv.add_child(title)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(rarity_chip(str(c["rarity"])))
	chips.add_child(family_chip(str(c["family"])))
	chips.add_child(text_chip(Loc.t(str((ArsenalData.VERBS[str(c["verb"])] as Dictionary)["name"]))))
	tv.add_child(chips)
	var lv := HBoxContainer.new()
	lv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lv.position = Vector2(-UITokens.GUTTER - 260.0, 10.0)
	lv.size = Vector2(260, 76)
	lv.alignment = BoxContainer.ALIGNMENT_END
	lv.add_theme_constant_override("separation", 6)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(lv)
	var lw := UIKit.label(Loc.t("LV").replace("%d", "").strip_edges(), 22, UIKit.GOLD_HI, true)
	UIKit.soft_shadow(lw)
	lw.size_flags_vertical = Control.SIZE_SHRINK_END
	lw.custom_minimum_size.y = 44
	lv.add_child(lw)
	_lv_lbl = UIKit.number("", 60, true)
	_lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lv_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	lv.add_child(_lv_lbl)
	var mx := UIKit.label("/%d" % ArsenalData.MAX_LEVEL, 22, UIKit.GOLD_HI, true)
	UIKit.soft_shadow(mx)
	mx.size_flags_vertical = Control.SIZE_SHRINK_END
	mx.custom_minimum_size.y = 44
	lv.add_child(mx)
	_lv_word = lw
	_lv_max = mx
	# The cream sheet.
	_sheet = UIKit.sheet(Vector2(UITokens.GUTTER, 10))
	_sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sheet.offset_top = -(SHEET_H + ins.w)
	_sheet.offset_bottom = 0.0
	_sheet.offset_left = -2.0
	_sheet.offset_right = 2.0
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_sheet.add_child(col)
	_tabs = UIKit.tabs([["stats", Loc.t("STATS")], ["beats", tr2("TAB_BEATS")], ["talents", tr2("TALENTS")]], _tab, _on_tab, 24)
	col.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_scroll)
	UIKit.scroll_fade(_scroll, UIKit.CREAM, 36.0, 18.0)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	_scroll.add_child(_body)
	_dock = VBoxContainer.new()
	_dock.add_theme_constant_override("separation", 10)
	col.add_child(_dock)
	col.add_child(UIKit.gap(ins.w + 6.0))
	_rebuild_body()


## §4.6: the frosted sheet leans toward this machine's gem light (hub._page_tint).
func page_tint() -> Color:
	return UITokens.gem(UITokens.gem_of(str(Meta.machine_card(id)["rarity"])))["light"]


func _set_level(lvl: int) -> void:
	_lv_lbl.text = str(lvl) if lvl > 0 else ""
	_lv_word.visible = lvl > 0
	_lv_max.visible = lvl > 0


func _on_tab(t: String) -> void:
	var old: Control = _pages.get(_tab)
	_tab = t
	var incoming: Control = _pages.get(t)
	if old == incoming:
		return
	if old:
		old.visible = false
	UIJuice.cross_fade(null, incoming)
	_scroll.scroll_vertical = 0


func _rebuild_body() -> void:
	if not is_instance_valid(_body):
		return
	for ch in _body.get_children():
		ch.queue_free()
	for ch in _dock.get_children():
		ch.queue_free()
	_pages.clear()
	_upgrade_btn = null
	_bp = null
	_cost = null
	var c := Meta.machine_card(id)
	_set_level(int(c["lvl"]) if bool(c["owned"]) else 0)
	_pages["stats"] = _stats_page(c)
	_pages["beats"] = _beats_page(c)
	_talent_box = _talents_page(c)
	_pages["talents"] = _talent_box
	for k: String in ["stats", "beats", "talents"]:
		var p: Control = _pages[k]
		p.visible = k == _tab
		_body.add_child(p)
	_build_dock(c)


# ------------------------------------------------------------------ dock (bp bar + CTA)

func _build_dock(c: Dictionary) -> void:
	_dock.add_child(UIKit.hairline())
	var locked := str(c["locked"])
	if locked != "" or not bool(c["owned"]):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size.y = 96
		var s := UIKit.socket("lock", 52.0)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(s)
		var txt := Loc.t("LOCKED_SOON")
		if locked != "phase":
			var home := int(c["home_level"])
			if home > 0:
				txt = tr2("FOUND_AT") % Loc.f("LOCKED_WORLD", [ArsenalData.world_of(home), ArsenalData.level_in_world(home)])
		var l := UIKit.label(txt, 26, UIKit.INK, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		_dock.add_child(row)
		return
	var maxed := int(c["lvl"]) >= ArsenalData.MAX_LEVEL
	if not maxed:
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 10)
		var bi := Icons.make("blueprint", 40.0)
		bi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		brow.add_child(bi)
		_bp = BpBar.new()
		_bp.custom_minimum_size = Vector2(0, 40)
		_bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bp.have = maxi(int(c["bp"]), 0)
		_bp.need = int(c["bp_need"])
		_bp.wild = int(c["wild"])
		_bp.rarity = str(c["rarity"])
		brow.add_child(_bp)
		_dock.add_child(brow)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	_cost = UIKit.currency_plate("coin", "0", false, 186)
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(_cost)
	_upgrade_btn = UIKit.cta_button(Loc.t("UPGRADE"), "", Vector2(440, 100), 38)
	_upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_btn.sub_size = 22
	_upgrade_btn.pressed.connect(press_upgrade)
	_upgrade_btn.gui_input.connect(func(e: InputEvent):
		if _upgrade_btn.disabled and UIJuice.is_tap(e):
			press_upgrade())
	row2.add_child(_upgrade_btn)
	_dock.add_child(row2)
	_armed = false
	_refresh_upgrade()


## Two-tap upgrade: first tap arms ("Підтвердити · price"), second buys.
func press_upgrade() -> void:
	if _upgrade_btn == null or _busy:
		return
	var cost := Meta.upgrade_cost(id)
	if not bool(cost["can"]):
		Audio.play("error", -6.0)
		UIJuice.wobble(_upgrade_btn, 0.3, 0.3)
		if _bp and str(cost["reason"]) == "blueprints":
			UIJuice.punch(_bp, 1.04, 0.25)
		elif _cost and str(cost["reason"]) == "coins":
			UIJuice.chip_hit(_cost)
		return
	if not _armed:
		_armed = true
		UIJuice.haptic("CLICK", 0.5)
		_refresh_upgrade()
		_upgrade_btn.pivot_offset = _upgrade_btn.size * 0.5
		var tw := _upgrade_btn.create_tween()
		tw.tween_property(_upgrade_btn, "scale", Vector2(1.05, 0.92), 0.06)
		tw.tween_property(_upgrade_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_arm_timer = get_tree().create_timer(3.0)
		_arm_timer.timeout.connect(func():
			if is_instance_valid(self) and _armed and not _busy:
				_armed = false
				_refresh_upgrade())
		return
	_armed = false
	_do_upgrade()


func _refresh_upgrade() -> void:
	if _upgrade_btn == null or not is_instance_valid(_upgrade_btn):
		return
	var c := Meta.upgrade_cost(id)
	var can := bool(c["can"])
	var reason := str(c["reason"])
	var coins := int(c["coins"])
	_cost.visible = reason != "max"
	_cost.value = Loc.num(coins) if coins > 0 else Loc.t("FREE")
	if _cost.value_label:
		_cost.value_label.add_theme_color_override("font_color", UIKit.ALERT if reason == "coins" else UIKit.INK)
	if reason == "max":
		_upgrade_btn.text = Loc.t("LV_MAX")
		_upgrade_btn.sub = ""
		_upgrade_btn.disabled = true
		return
	_upgrade_btn.disabled = not can
	var lvl := Meta.machine_level(id)
	if _armed and can:
		_upgrade_btn.text = Loc.f("CONFIRM_COST", [Loc.num(coins)]) if coins > 0 else Loc.f("CONFIRM_COST", [Loc.t("FREE")])
		_upgrade_btn.sub = Loc.f("USES_WILD", [int(c["wild_use"])]) if int(c["wild_use"]) > 0 else tr2("LV_NOW") % [lvl, int(c["to_lvl"])]
		return
	_upgrade_btn.text = Loc.t("UPGRADE")
	var sub := tr2("LV_NOW") % [lvl, int(c["to_lvl"])]
	match reason:
		"blueprints":
			sub = Loc.f("NEED_BP", [maxi(0, int(c["bp_need"]) - int(c["bp_have"]) - Meta.wild(ArsenalData.rarity_of(id)))])
		"coins":
			sub = Loc.t("NEED_COINS")
		"locked":
			sub = Loc.f("TAB_LOCKED", [int(EconData.unlock_entry("arsenal").get("after_win", 3)) + 1])
	var beat := str(c["beat"])
	if can and beat != "":
		sub += "  ·  " + Loc.t("BEAT_" + beat.to_upper())
	_upgrade_btn.sub = sub


func _do_upgrade() -> void:
	var before := Meta.machine_card(id)
	var stats_before := Meta.stats(id)
	var res := Meta.upgrade(id)
	if not bool(res.get("ok", false)):
		Audio.play("error", -6.0)
		_refresh_upgrade()
		return
	_busy = true
	var beat := str(res.get("beat", ""))
	var tier := UITokens.upgrade_tier(beat)
	Audio.play("upgrade")
	var g: Dictionary = UITokens.gem(str(before["rarity"]))
	var center := _show.get_global_rect().get_center() - global_position
	# Everything stays on the stage: a clip host over the stage band (never over the sheet).
	var clip := _stage_clip()
	var flash_at := UIJuice.flare(clip, center, (g["light"] as Color).lerp(UITokens.TOPAZ_HI, 0.35), tier, 150.0)
	_show.celebrate(1.0 if tier == "full" else 0.6)
	UIKit.sparkles(clip, center, (g["light"] as Color).lerp(Color.WHITE, 0.3), 30 if tier == "full" else 18, 260.0)
	get_tree().create_timer(flash_at).timeout.connect(func():
		if not is_instance_valid(clip):
			return
		# Juicy even without a beat: a 120 ms white-gold flash on the stage + gem motes.
		var fl := ColorRect.new()
		fl.color = Color(1.0, 0.96, 0.84, 0.55)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fl.size = clip.size
		clip.add_child(fl)
		var ft := fl.create_tween()
		ft.tween_property(fl, "color:a", 0.0, 0.12)
		ft.tween_callback(fl.queue_free)
		UIKit.sparkles(clip, center, g["rim"] as Color, 18, 220.0))
	get_tree().create_timer(UITokens.ceremony(tier) + 0.6).timeout.connect(func():
		if is_instance_valid(clip):
			clip.queue_free())
	await get_tree().create_timer(flash_at).timeout
	if not is_instance_valid(self):
		return
	var asc_now := int(res["lvl"]) >= ArsenalData.ASCENSION_LEVEL
	var asc_before := int(before["lvl"]) >= ArsenalData.ASCENSION_LEVEL
	if asc_now != asc_before:
		_show.show_machine(id, int(res["lvl"]), false)
	_set_level(int(res["lvl"]))
	_lv_lbl.pivot_offset = _lv_lbl.size * 0.5
	UIJuice.punch(_lv_lbl, 1.35 if tier == "full" else 1.12, 0.4 if tier == "full" else 0.28)
	Meta.note("upgrade_ceremony", {"id": id, "tier": tier})
	_busy = false
	_rebuild_body()
	await get_tree().process_frame
	_count_stats(stats_before)
	if beat != "":
		_beat_banner(beat)
		if beat in ["talent1", "talent2"] and is_instance_valid(_talent_box):
			await get_tree().create_timer(0.4).timeout
			if is_instance_valid(_talent_box):
				_tabs.select("talents", true)
				UIJuice.punch(_talent_box, 1.03, 0.35)


## A clip host over the stage band (clip_contents, ends at the sheet's top) for ceremony FX.
func _stage_clip() -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.clip_contents = true
	host.size = Vector2(size.x, _sheet.position.y - 8.0)
	add_child(host)
	return host


## Full ceremony (a beat level): soft shafts, a 40 % dim and the Genshin level-up band in the
## machine's gem colour (§6.7 "Level-up: gem colour") with the beat's icon and name.
func _beat_banner(beat: String) -> void:
	var host := _stage_clip()
	var c := _show.get_global_rect().get_center() - global_position
	c.y = minf(c.y, host.size.y - 90.0)
	var dim := ColorRect.new()
	dim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.4)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = host.size
	host.add_child(dim)
	UIJuice.fade_in(dim, 0.0, UITokens.FAST)
	var gk := UITokens.gem_of(str(Meta.machine_card(id)["rarity"]))
	var rays := UIKit.Rays.new()
	rays.color = Color(UITokens.gem(gk)["light"], 0.3)
	rays.gem = gk
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.position = c - Vector2(380, 380)
	rays.size = Vector2(760, 760)
	host.add_child(rays)
	var band := GemBand.new()
	band.gem = gk
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := UIKit.number(Loc.t("BEAT_" + beat.to_upper()), UIKit.fit_size(Loc.t("BEAT_" + beat.to_upper()), size.x - 260.0, 52, 30), true)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ic := Icons.make(str(BEAT_ICONS.get(beat, "trophy")), 56.0, UIKit.ON_SCENE)
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, c.y - 65.0)
	row.size = Vector2(size.x, 130.0)
	host.add_child(row)
	band.size = row.size
	row.add_child(band)
	bl.size = row.size
	row.add_child(bl)
	var fw := UIKit.font_w("extrabold").get_string_size(bl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bl.get_theme_font_size("font_size")).x
	ic.position = Vector2((size.x - fw) * 0.5 - 76.0, 37.0)
	ic.size = Vector2(56, 56)
	row.add_child(ic)
	UIJuice.pop(row, 0.0, UITokens.SLOW, 0.85)
	UIJuice.fade_in(rays, 0.0, UITokens.FAST)
	UIKit.sparkles(host, c, UIKit.GOLD_LIGHT, 34, 320.0)
	UIJuice.haptic_pattern("upgrade")
	Audio.play("weapon_get", -2.0)
	var tw := host.create_tween()
	tw.tween_interval(UITokens.ceremony("full") * 0.55)
	tw.tween_property(host, "modulate:a", 0.0, UITokens.SLOW)
	tw.tween_callback(host.queue_free)


## Stat values count up from the previous level after an upgrade (70 ms stagger).
func _count_stats(before: Dictionary) -> void:
	var i := 0
	for lbl in get_tree().get_nodes_in_group("md_stat_" + str(get_instance_id())):
		var key := str(lbl.get_meta("key"))
		var old: float = _stat_value(before, key)
		var now: float = float(lbl.get_meta("value"))
		if key == "amp":
			old *= 100.0
		if absf(now - old) < 0.001:
			continue
		var l := lbl as Label
		var fmt := str(lbl.get_meta("fmt"))
		var tw := l.create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_method(func(v: float): l.text = fmt % v, old, now, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): UIJuice.punch(l, 1.2, 0.25))
		i += 1


static func _dps(ms: Dictionary) -> float:
	var s: Dictionary = ms["stats"]
	var b2 := 1.0 + float(ms.get("add", 0.0))
	var dmg := float(s.get("damage", 0.0)) * b2
	var per := 1.0
	for k in ["bolts", "drones"]:
		if s.has(k):
			per *= float(s[k])
	if s.has("dps"):
		return float(s["dps"]) * b2
	if s.has("rate"):
		return dmg * float(s["rate"]) * per
	if s.has("period"):
		return dmg * float(s.get("volley", 1)) / maxf(float(s["period"]), 0.01)
	if s.has("charge"):
		return dmg / maxf(float(s["charge"]), 0.01)
	return 0.0


static func _stat_value(ms: Dictionary, key: String) -> float:
	if key == "dps":
		return _dps(ms)
	var s: Dictionary = ms["stats"]
	return float(s.get(key, 0.0)) * (1.0 + float(ms.get("add", 0.0)) if key == "damage" else 1.0)


# ------------------------------------------------------------------ pages

func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	return v


func _stats_page(c: Dictionary) -> Control:
	var v := _page()
	var desc := UIKit.label(Loc.t(str(c["desc"])), 22, UIKit.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 34
	v.add_child(UIKit.gap(6))
	v.add_child(desc)
	v.add_child(UIKit.gap(6))
	var ms: Dictionary = c["stats"]
	var nxt := {}
	var lvl := int(c["lvl"])
	if bool(c["owned"]) and lvl < ArsenalData.MAX_LEVEL:
		nxt = ArsenalData.machine_stats(id, lvl + 1, 1, ms.get("talents", []), str(ms.get("branch", "")))
	var rows: Array = [["dps", "STAT_DPS", "fast"]] if _dps(ms) > 0.001 else []
	var s: Dictionary = ms["stats"]
	for r: Array in STAT_ROWS:
		if s.has(r[0]) and float(s[r[0]]) < 90.0:
			rows.append(r)
	rows = rows.slice(0, 6)
	for r: Array in rows:
		var key := str(r[0])
		var val := _stat_value(ms, key)
		var fmt := "%.0f" if (val >= 10.0 or key in ["pierce", "bolts", "volley", "drones", "splash"]) else "%.1f"
		if key == "amp":
			fmt = "+%.0f%%"
			val *= 100.0
		var row := UIKit.list_row(Loc.t(str(r[1])), fmt % val, str(r[2]))
		row.custom_minimum_size.y = 50
		var vl: Label = row.get_meta("value")
		vl.add_theme_font_override("font", UIKit.font_w("extrabold"))
		vl.add_theme_font_size_override("font_size", 26)
		# Fixed right-aligned value column + a fixed delta column (empty when no delta).
		vl.custom_minimum_size.x = 112
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.set_meta("key", key)
		vl.set_meta("value", val)
		vl.set_meta("fmt", fmt)
		vl.add_to_group("md_stat_" + str(get_instance_id()))
		var dl := UIKit.label("", 22, UIKit.PLUS)
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dl.size_flags_vertical = Control.SIZE_FILL
		dl.custom_minimum_size.x = 92
		dl.clip_text = true
		if not nxt.is_empty():
			var nval := _stat_value(nxt, key) * (100.0 if key == "amp" else 1.0)
			if nval - val > 0.005:
				dl.text = ("+%.0f" if fmt.begins_with("%.0") or key == "amp" else "+%.2f") % (nval - val)
		row.add_child(dl)
		v.add_child(row)
	# Status and flags chips.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	var st := str(ms.get("status", ""))
	if st != "" and ArsenalData.STATUSES.has(st):
		chips.add_child(flat_chip(Loc.t(str((ArsenalData.STATUSES[st] as Dictionary)["name"])), "el_" + str(c["family"])))
	var flags: Dictionary = c.get("flags", {})
	if bool(flags.get("hits_flying", false)):
		chips.add_child(flat_chip(Loc.t("FLAG_FLYING"), "arrow_up"))
	if bool(flags.get("bypass_shield", false)):
		chips.add_child(flat_chip(Loc.t("FLAG_BEAM"), "cls_guardian"))
	if bool(flags.get("ground_only", false)):
		chips.add_child(flat_chip(Loc.t("FLAG_GROUND"), "chevron_down"))
	if chips.get_child_count() > 0:
		v.add_child(UIKit.gap(8))
		v.add_child(chips)
	if bool(c["owned"]) and str(c["locked"]) == "":
		v.add_child(UIKit.gap(8))
		v.add_child(_focus_row(c))
	# Rows at 50 and short gaps: the page fits the sheet at 720, so the Focus row's second line
	# ends above the scroll fade's zone (the fade only shows when the page really overflows).
	v.add_child(UIKit.gap(8))
	return v


func _beats_page(c: Dictionary) -> Control:
	var v := _page()
	v.add_child(UIKit.gap(8))
	var tr := BeatTrack.new()
	tr.lvl = int(c["lvl"]) if bool(c["owned"]) else 0
	tr.custom_minimum_size = Vector2(0, 64)
	v.add_child(tr)
	v.add_child(UIKit.gap(4))
	var lvl := int(c["lvl"]) if bool(c["owned"]) else 0
	var asc := ArsenalData.ascension_of(id, "a")
	for l in range(1, ArsenalData.MAX_LEVEL + 1):
		var beat := Meta.beat_at(l)
		if beat == "":
			continue
		var live := BeatTrack._live(beat)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size.y = 62
		var node := _BeatNode.new()
		node.icon = str(BEAT_ICONS.get(beat, "trophy"))
		node.state = ("done" if l <= lvl else "next") if live else "off"
		node.custom_minimum_size = Vector2(44, 44)
		node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(node)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", -2)
		var name := Loc.t("BEAT_" + beat.to_upper())
		if beat == "ascension" and not asc.is_empty() and asc.has("id"):
			name += ": " + Loc.t("ASC_" + str(asc["id"]).to_upper())
		tv.add_child(UIKit.label(name, 24, UIKit.INK if live else UIKit.INK_DIM))
		tv.add_child(UIKit.label(Loc.f("LV", [l]), 22, UIKit.INK_DIM))
		row.add_child(tv)
		var stx := Loc.t("SOON")
		var scol := UIKit.INK_DIM
		if live:
			if l <= lvl:
				stx = tr2("BEAT_DONE")
				scol = UIKit.PLUS
			else:
				stx = tr2("BEAT_IN") % (l - lvl) if lvl > 0 else Loc.f("TALENT_LOCKED", [l])
				scol = UIKit.GOLD_TEXT_GLASS
		var sl := UIKit.label(stx, 22, scol)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sl)
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 0)
		wrap.add_child(row)
		wrap.add_child(UIKit.hairline())
		v.add_child(wrap)
	v.add_child(UIKit.gap(12))
	return v


func _talents_page(c: Dictionary) -> Control:
	var v := _page()
	v.add_theme_constant_override("separation", 10)
	v.add_child(UIKit.gap(4))
	var lvl := int(c["lvl"]) if bool(c["owned"]) else 0
	var chosen: Array = c["talents"]
	var opts_all: Array = c["talent_options"]
	for tier in 2:
		var need: int = ArsenalData.TALENT_LEVELS[tier]
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var sec := UIKit.section(Loc.t("BEAT_TALENT%d" % (tier + 1)), 20)
		sec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(sec)
		head.add_child(UIKit.spacer())
		var cur := str(chosen[tier]) if tier < chosen.size() else ""
		var hl: Label
		if lvl < need:
			hl = UIKit.label(Loc.f("TALENT_LOCKED", [need]), 22, UIKit.INK_DIM)
		elif cur == "":
			hl = UIKit.label(Loc.t("TALENT_PICK"), 22, UIKit.GOLD_TEXT_GLASS)
		else:
			hl = UIKit.label(Loc.t("TALENT_RESPEC"), 22, UIKit.INK_DIM)
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(hl)
		v.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var opts: Array = opts_all[tier] if tier < opts_all.size() else []
		for o: Dictionary in opts:
			var tid := str(o["id"])
			var tc := TalentCard.new()
			tc.talent = tid
			tc.state = "locked" if lvl < need else ("chosen" if cur == tid else ("pick" if cur == "" else "other"))
			tc.custom_minimum_size = Vector2(0, 140)
			tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tc.tapped.connect(_pick_talent.bind(tier, tid, tc))
			row.add_child(tc)
		v.add_child(row)
		v.add_child(UIKit.gap(6))
	return v


func _pick_talent(tier: int, tid: String, card: Control) -> void:
	var cur := str((Meta.machine_state(id).get("talents", ["", "", ""]) as Array)[tier])
	if cur == tid:
		return
	if Meta.set_talent(id, tier, tid):
		Audio.play("weapon_get", -6.0)
		var center := card.get_global_rect().get_center() - global_position
		UIJuice.flare(self, center, UITokens.TOPAZ_HI, "micro", 90.0)
	else:
		Audio.play("error", -6.0)


func _focus_row(c: Dictionary) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(UIKit.hairline())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var s := UIKit.socket("target", 48.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(UIKit.label(Loc.t("FOCUS_ON"), 24, UIKit.INK))
	var d := UIKit.label(Loc.t("FOCUS_DESC"), 22, UITokens.INK_DIM_GLASS)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wraps inside its column with air before the toggle (never runs into it).
	d.custom_minimum_size.x = 300.0
	v.add_child(d)
	row.add_child(v)
	row.add_child(UIKit.gap(6))
	var t := SettingsPanel.Toggle.new()
	t.on = bool(c["is_focus"])
	t.custom_minimum_size = Vector2(86, 46)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The Lead is the focus by default: turning it "off" would fall straight back to it, so the
	# switch shows on, disabled, with the reason - only an explicit choice is a real toggle.
	var explicit := str((Meta.account.get("arsenal", {}) as Dictionary).get("focus", "")) != ""
	if bool(c["is_focus"]) and not explicit:
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.modulate.a = 0.55
		d.text = Loc.t("FOCUS_DEFAULT")
	t.toggled.connect(func(v2: bool):
		Meta.set_focus(id if v2 else "")
		UIJuice.haptic("CLICK", 0.5))
	row.add_child(t)
	wrap.add_child(row)
	return wrap


# ------------------------------------------------------------------ chips (shared with the Arsenal tab)

## v3: a flat glass chip (lux "chip": 1 dpx gold + 1 dpx light, chamfer 6).
static func _chip_panel(pad: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("chip", pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Rarity chip: the gem-cut mark + the rarity name (ink on a porcelain chip).
static func rarity_chip(r: String) -> Control:
	var p := _chip_panel(Vector2(8, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(GemMark.make(r, 24.0))
	row.add_child(UIKit.label(Loc.t(str((ArsenalData.RARITIES[r] as Dictionary)["name"])), 22, UIKit.INK))
	row.add_child(UIKit.gap(2))
	p.add_child(row)
	return p


## Family chip: the family glyph in a slate socket + the family name.
static func family_chip(fam: String) -> Control:
	var p := _chip_panel(Vector2(5, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UIKit.socket("el_" + fam, 26.0, true)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	row.add_child(UIKit.label(Loc.t(str((ArsenalData.FAMILIES[fam] as Dictionary)["name"])), 22, UIKit.INK))
	row.add_child(UIKit.gap(4))
	p.add_child(row)
	return p


## §3.2: a chip INSIDE a card or sheet has no frame: a flat 45-degree chamfered tint (gold-leaf
## wash on the bed) with an optional line icon and Medium ink.
static func flat_chip(text: String, icon := "") -> Control:
	var p := _FlatChip.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		var ic := Icons.make(icon, 22.0, UITokens.INK_DIM_GLASS)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	row.add_child(UIKit.label(text, 22, UIKit.INK))
	p.add_child(row)
	return p


class _FlatChip extends PanelContainer:
	func _draw() -> void:
		var h := UITokens.HAIRLINE
		draw_colored_polygon(GemDraw.chamfer_rect(Rect2(Vector2.ZERO, size), UITokens.CHAMFER_XS), Color(h.r, h.g, h.b, 0.2))


## Plain porcelain chip with an optional line icon.
static func text_chip(text: String, icon := "") -> Control:
	var p := _chip_panel(Vector2(10, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		var ic := Icons.make(icon, 22.0, UIKit.INK_DIM)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	row.add_child(UIKit.label(text, 22, UIKit.INK))
	p.add_child(row)
	return p


# ------------------------------------------------------------------ widgets

## A gem-cut rarity mark as a Control (GemDraw.draw_mark in a gold bezel).
class GemMark extends Control:
	var gem := "quartz"

	static func make(r: String, px: float) -> GemMark:
		var m := GemMark.new()
		m.gem = UITokens.gem_of(r)
		m.custom_minimum_size = Vector2(px, px)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return m

	func _draw() -> void:
		var s := minf(size.x, size.y)
		GemDraw.draw_mark(self, gem, size * 0.5, s * 0.82)


## The detail's stage: a soft field in the machine's gem colour (ground gradient lifted toward
## light, a light pool behind the machine, that gem's fracture planes, a gentle floor glow
## where the turntable stands). Opal keeps its night-sky ground with flecks.
class _GemStage extends Control:
	var gem := "quartz"
	var sheet_h := 700.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var g: Dictionary = UITokens.gem(gem)
		var top: Color = g["top"]
		var bot: Color = g["bot"]
		var lc: Color = g["light"]
		var h := size.y
		var w := size.x
		var sheet_y := h - sheet_h
		var c_top := top.lerp(bot, 0.15).lerp(UITokens.SCRIM, 0.06)
		var c_mid := top.lerp(bot, 0.65)
		var c_low := bot.lerp(lc, 0.35)
		if gem == "opal":
			c_top = top
			c_mid = bot
			c_low = bot.lerp(Color("#6B5AA6"), 0.4)
		var ym := sheet_y * 0.45
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, ym), Vector2(0, ym)]), PackedColorArray([c_top, c_top, c_mid, c_mid]))
		draw_polygon(PackedVector2Array([Vector2(0, ym), Vector2(w, ym), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c_mid, c_mid, c_low, c_low]))
		# Light pool behind the machine and a soft top light.
		var cy := lerpf(170.0, sheet_y, 0.55)
		var R := w * 0.62
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(w * 0.5 - R, cy - R), Vector2(R, R) * 2.0), false, Color(lc.r, lc.g, lc.b, 0.5))
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(w * 0.5 - R * 0.5, cy - R * 0.4), Vector2(R, R * 0.8)), false, Color(1, 1, 1, 0.22))
		KitGemCard.draw_stage_fracture(self, gem, Rect2(Vector2.ZERO, Vector2(w, sheet_y + 20.0)))
		if gem == "opal":
			var fl: Array = g["flecks"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 46:
				var p := Vector2(rng.randf() * w, rng.randf() * sheet_y)
				var fc: Color = fl[i % fl.size()]
				var rr := rng.randf_range(3.0, 9.0)
				draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(rr, rr) * 2.0, Vector2(rr, rr) * 4.0), false, Color(fc.r, fc.g, fc.b, 0.35))
		# Side vignette (very soft) so the edges settle.
		var vg := Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.16)
		var cl := Color(vg.r, vg.g, vg.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(70, 0), Vector2(70, h), Vector2(0, h)]), PackedColorArray([vg, cl, cl, vg]))
		draw_polygon(PackedVector2Array([Vector2(w - 70, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - 70, h)]), PackedColorArray([cl, vg, vg, cl]))
		# Top scrim under the header text (0 -> 22 %).
		var sc := Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.2)
		var sc0 := Color(sc.r, sc.g, sc.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 220), Vector2(0, 220)]), PackedColorArray([sc, sc, sc0, sc0]))


## Big blueprint bar (UI v3.1 §7.5): a slim chamfered glass track in a 1 dpx gold frame, the own
## share in flat amber with a 1 dpx table light, the Wild share in pale amber (no hatching), a
## small cut-gem diamond lit at the end when full, and the count to the right
## ("3 / 8 · +2 дикі"), all >= 22 px.
class BpBar extends Control:
	var have := 0
	var need := 1
	var wild := 0
	var rarity := "C"

	func _draw() -> void:
		var f := UIKit.font_w("bold")
		var fm := UIKit.font_w("medium")
		var fs := 22
		var txt := "%d / %d" % [have, need]
		var extra := ""
		if wild > 0 and have < need:
			extra = " · " + (Loc.f("WILD_SHARE", [mini(wild, need - have)]) if Loc.STRINGS.has("WILD_SHARE") else "+%d" % mini(wild, need - have))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fm.get_string_size(extra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bh := 8.0
		var y0 := roundf((size.y - bh) * 0.5)
		var r := Rect2(Vector2(8, y0), Vector2(size.x - tw - 34.0, bh))
		var ch := 3.0
		var pts := GemDraw.chamfer_rect(r, ch)
		draw_colored_polygon(pts, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.5))
		var k := clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0)
		var kw := clampf(float(have + wild) / float(maxi(need, 1)), 0.0, 1.0)
		if kw > k:
			# The Wild share: pale amber (never another rarity's colour).
			var wr := Rect2(r.position, Vector2(maxf(r.size.x * kw, ch * 2.0), bh))
			draw_colored_polygon(GemDraw.chamfer_rect(wr, ch), Color(UITokens.PIP_WALKED, 0.85) if UITokens.calm_cta() else Color(UITokens.CTA_HI.r, UITokens.CTA_HI.g, UITokens.CTA_HI.b, 0.7))
		if k > 0.0:
			var fr := Rect2(r.position, Vector2(maxf(r.size.x * k, ch * 2.0), bh))
			var fp := GemDraw.chamfer_rect(fr, ch)
			var cols := PackedColorArray()
			for p in fp:
				cols.append(UITokens.bar_hi().lerp(UITokens.bar_lo(), (p.y - fr.position.y) / bh))
			draw_polygon(fp, cols)
			var ly := GemDraw.pixel_y(self, fr.position.y + 1.5)
			draw_line(Vector2(fr.position.x + ch, ly), Vector2(fr.end.x - ch, ly), Color(1.0, 0.98, 0.9, 0.85), UIKit.px(1.0))
		GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85), UIKit.line_px(1.0))
		if k >= 0.999:
			GemDraw.draw_diamond(self, Vector2(r.end.x + 2.0, r.get_center().y), 11.0, UITokens.key_gem(), UITokens.LINE_GOLD_DEEP)
		var x := r.end.x + 18.0
		var y := roundf(size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
		draw_string(f, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
		if extra != "":
			draw_string(fm, Vector2(x + f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DIM)


## Lv1-15 facet track: a gold hairline with a rhombus pip per level (lit up to the current
## level), beat levels as larger keystones, "Рів. 6 / 15" at the left.
class BeatTrack extends Control:
	var lvl := 1

	func _draw() -> void:
		var f := UIKit.font_w("medium")
		var n := ArsenalData.MAX_LEVEL
		var y := GemDraw.pixel_y(self, size.y * 0.58)
		var lab := Loc.f("LV", [maxi(lvl, 0)]) + " / %d" % n
		var lw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(0, roundf(y + 8)), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK)
		var x0 := lw + 26.0
		var x1 := size.x - 10.0
		GemDraw.draw_hairline(self, Vector2(x0 - 8, y), Vector2(x1 + 8, y), UITokens.HAIRLINE, 1.0, false)
		var xl := lerpf(x0, x1, float(clampi(lvl, 1, n) - 1) / float(n - 1))
		if lvl >= 1:
			draw_line(Vector2(x0, y), Vector2(xl, y), Color(UITokens.key_line(), 0.9), UIKit.line_px(1.5))
		for l in range(1, n + 1):
			var x := lerpf(x0, x1, float(l - 1) / float(n - 1))
			var beat := Meta.beat_at(l)
			var done := l <= lvl
			if beat != "" and _live(beat):
				GemDraw.draw_pip(self, Vector2(x, y), 22.0, done, UITokens.key_gem())
			else:
				GemDraw.draw_pip(self, Vector2(x, y), 13.0, done, UITokens.pip_walked(), 1.0 if beat == "" or done else 0.5)

	static func _live(beat: String) -> bool:
		match beat:
			"talent1", "talent2": return bool(ArsenalData.FEATURES["talents12"])
			"talent3": return bool(ArsenalData.FEATURES["talent3"])
			"lead": return bool(ArsenalData.FEATURES["lead"])
			"ascension": return bool(ArsenalData.FEATURES["ascension"])
			"apex": return bool(ArsenalData.FEATURES["apex"])
			"prestige", "mastered": return bool(ArsenalData.FEATURES["prestige_frames"])
		return false


## A beat node of the milestone list: a socket with the beat's line icon - reached (amber
## ring, warm fill), next (cream, gold ring), off (Meta-1-off: faded well).
class _BeatNode extends Control:
	var icon := "trophy"
	var state := "next"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# v3: a glass disc with ONE 1 dpx ring (1.5 dpx amber when reached), no stacked shadows.
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		match state:
			"done":
				draw_circle(c, r, UITokens.PAPER_0 if UITokens.calm_cta() else UITokens.CTA_HI.lerp(Color.WHITE, 0.35))
				draw_arc(c, r - UIKit.px(0.75), 0, TAU, 64, UITokens.key_line(), UIKit.line_px(1.5), true)
			"next":
				draw_circle(c, r, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.9))
				draw_arc(c, r - UIKit.px(0.5), 0, TAU, 64, UITokens.HAIRLINE, UIKit.line_px(1.0), true)
			_:
				draw_circle(c, r, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.6))
				draw_arc(c, r - UIKit.px(0.5), 0, TAU, 64, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5), UIKit.line_px(1.0), true)
		var isz := r * 1.15
		var col := UITokens.INK if state != "off" else UITokens.INK_DIM
		if state == "done":
			col = UITokens.KEY_INK if UITokens.calm_cta() else UITokens.CTA_RIM
		Icons.draw_icon(self, icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), col if KitIcons.has_line(icon) else Color(1, 1, 1, 1.0 if state != "off" else 0.5))


## One talent option (a choice card on glass): name, effect, state (locked | pick | chosen |
## other). v3: chosen = the selected card (1.5 dpx deep gold + the diagonal flourish pair) and a
## check; pick = a static 1.5 dpx amber line (nothing breathes).
class TalentCard extends Control:
	signal tapped
	var talent := ""
	var state := "pick"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _ready() -> void:
		UIJuice.press(self)

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e) and state != "locked":
			tapped.emit()

	func _draw() -> void:
		var f := UIKit.font_w("medium")
		var fr := UIKit.font_w("regular")
		var r := Rect2(Vector2(2, 4), size - Vector2(4, 8))
		var chosen := state == "chosen"
		var locked := state == "locked"
		draw_style_box(UIKit.lux("card_sel" if chosen else ("card_dim" if locked else "card")), r)
		if state == "pick":
			GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(-UIKit.px(1.0)), 10.0), Color(UITokens.key_line(), 0.85), UIKit.line_px(1.5))
		var name := Loc.t("TAL_" + talent.to_upper())
		var desc := Loc.t("TAL_" + talent.to_upper() + "_DESC")
		var fs := UIKit.fit_size(name, r.size.x - 64, 24, 22)
		var col := UITokens.INK if not locked else UIKit.INK_DIM
		draw_string(f, r.position + Vector2(16, 38), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var lines := _wrap(desc, r.size.x - 32, 22, fr)
		for i in mini(lines.size(), 3):
			draw_string(fr, r.position + Vector2(16, 70 + i * 27), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.INK_DIM)
		var ic := Rect2(Vector2(r.end.x - 42, r.position.y + 12), Vector2(30, 30))
		if chosen:
			var calm := UITokens.calm_cta()
			draw_circle(ic.get_center(), 15, UITokens.KEY_INK if calm else UITokens.CTA)
			draw_arc(ic.get_center(), 15, 0, TAU, 48, UITokens.KEY_GOLD if calm else UITokens.CTA_RIM, UIKit.line_px(1.0), true)
			Icons.line(self, "check", ic.grow(-6), UITokens.PAPER_0 if calm else UIKit.CTA_TEXT)
		elif locked:
			Icons.line(self, "lock", ic.grow(-4), UITokens.INK_DIM)

	static func _wrap(text: String, w: float, fs: int, f: Font) -> PackedStringArray:
		var out := PackedStringArray()
		var line := ""
		for word in text.split(" "):
			var cand := word if line == "" else line + " " + word
			if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and line != "":
				out.append(line)
				line = word
			else:
				line = cand
		if line != "":
			out.append(line)
		return out


## The level-up band in a gem colour: a horizontal gradient whose alpha fades to 0 over the
## outer 18 % at each side, 1 dpx gold hairlines top and bottom with marquise terminals.
class GemBand extends Control:
	var gem := "topaz"

	func _draw() -> void:
		var g: Dictionary = UITokens.gem(gem)
		var w := size.x
		var h := size.y
		var xs := [0.0, w * 0.18, w * 0.82, w]
		var ax := [0.0, 1.0, 1.0, 0.0]
		var top: Color = (g["rim"] as Color).lerp(g["light"] as Color, 0.25)
		var bot: Color = g["deep"]
		for i in 3:
			draw_polygon(PackedVector2Array([Vector2(xs[i], 6), Vector2(xs[i + 1], 6), Vector2(xs[i + 1], h - 6), Vector2(xs[i], h - 6)]),
					PackedColorArray([Color(top, 0.92 * ax[i]), Color(top, 0.92 * ax[i + 1]), Color(bot, 0.92 * ax[i + 1]), Color(bot, 0.92 * ax[i])]))
		var gl := UITokens.GOLD_HI
		for y: float in [3.0, h - 3.0]:
			for i in 3:
				var hw := UIKit.line_px(1.0) * 0.5
				draw_polygon(PackedVector2Array([Vector2(xs[i], y - hw), Vector2(xs[i + 1], y - hw), Vector2(xs[i + 1], y + hw), Vector2(xs[i], y + hw)]),
						PackedColorArray([Color(gl, ax[i]), Color(gl, ax[i + 1]), Color(gl, ax[i + 1]), Color(gl, ax[i])]))
			for x: float in [xs[1], xs[2]]:
				GemDraw.draw_gem(self, "eye", Vector2(x, y), 22.0, UITokens.GOLD_HI, Color(1, 0.96, 0.84), UITokens.HAIRLINE, false)
