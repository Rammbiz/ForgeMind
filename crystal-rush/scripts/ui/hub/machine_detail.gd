class_name MachineDetail
extends Control
## Machine detail sheet (arsenal_design.md §7.2, card §6.2, upgrade §6.3): the machine on a
## turntable, rarity / family / verb, the two-tap upgrade (tap 1 morphs in 150 ms into
## "Підтвердити · 1 260" (+ "використає N дикі"), tap 2 runs the ceremony sized by the beat:
## standard 1.2 s, full ≤ 3 s on Lv3/5/6/8/10/12/15), the blueprint bar with the Wild hint,
## stats with green deltas for the next level, the beat track Lv1-15, Talents I/II (two cards
## per tier, free swap), and the Cache Focus toggle. Unowned machines show where they are found.

const STAT_ROWS := [
	["damage", "STAT_DAMAGE", "dmg"], ["rate", "STAT_RATE", "rate"], ["range", "STAT_RANGE", "target"],
	["pierce", "STAT_PIERCE", "multi"], ["bolts", "STAT_BOLTS", "ballista"], ["splash", "STAT_SPLASH", "fam_plasma"],
	["radius", "STAT_RADIUS", "fam_plasma"], ["volley", "STAT_VOLLEY", "rockets"], ["drones", "STAT_DRONES", "drone"],
	["charge", "STAT_CHARGE", "railgun"], ["amp", "STAT_AMP", "prism"],
]
const BEAT_ICONS := {"talent1": "laurel", "lead": "crown", "talent2": "laurel", "ascension": "crystal",
		"talent3": "laurel", "apex": "focus", "prestige": "star", "mastered": "star"}

var hub: Hub
var id := ""
var _sheet: PanelContainer
var _body: VBoxContainer
var _show: HubShowcase
var _lv_lbl: Label
var _upgrade_btn: Button
var _btn_lbl: Label
var _btn_sub: Label
var _btn_coin: Icons
var _armed := false
var _arm_timer: SceneTreeTimer
var _scroll: ScrollContainer
var _talent_box: Control
var _busy := false


func setup(p_hub: Hub, p_id: Variant = "") -> void:
	hub = p_hub
	id = str(p_id)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UIKit.lux("sheet", Vector2(18, 16)))
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.offset_left = 10 + ins.x
	_sheet.offset_right = -10 - ins.z
	_sheet.offset_top = ins.y + 14
	_sheet.offset_bottom = -ins.w - 10
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_build()
	Meta.machine_changed.connect(_on_machine_changed)
	Meta.wallet_changed.connect(func(_c: String, _v: int): _refresh_upgrade())
	Meta.focus_changed.connect(func(_f: String): _rebuild_body())
	await get_tree().process_frame
	UIJuice.slide_in(_sheet, Vector2(0, 260), 0.0, UITokens.ENTER)


func play_exit() -> Tween:
	return UIJuice.slide_out(_sheet, Vector2(0, 300))


func _on_machine_changed(mid: String) -> void:
	if mid == id and not _busy:
		_rebuild_body()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_sheet.add_child(col)
	var c := Meta.machine_card(id)
	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var back := RoundButton.new(28.0)
	back.icon_kind = "back"
	back.pressed.connect(func(): hub.pop_modal())
	head.add_child(back)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	var title := UIKit.gradient_heading(Loc.t(str(c["name"])), 44)
	title.add_theme_font_size_override("font_size", UIKit.fit_size(title.text, 420.0, 44, 28))
	tv.add_child(title)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	pills.add_child(_pill(Loc.t(str((ArsenalData.RARITIES[str(c["rarity"])] as Dictionary)["name"])), "", UITokens.rarity(str(c["rarity"]))))
	pills.add_child(_pill(Loc.t(str((ArsenalData.FAMILIES[str(c["family"])] as Dictionary)["name"])), "fam_" + str(c["family"]), UITokens.family(str(c["family"]))))
	pills.add_child(_pill(Loc.t(str((ArsenalData.VERBS[str(c["verb"])] as Dictionary)["name"])), "", Color(0.75, 0.85, 1.0)))
	tv.add_child(pills)
	head.add_child(tv)
	_lv_lbl = UIKit.heading("", 34, UIKit.GOLD_LIGHT, 7)
	_lv_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(_lv_lbl)
	col.add_child(head)
	# Showcase
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 320)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show = HubShowcase.new("machine")
	_show.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(_show)
	col.add_child(strip)
	_show.show_machine(id, int(c["lvl"]), str(c["locked"]) != "")
	# Body
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)
	_rebuild_body()


func _rebuild_body() -> void:
	if not is_instance_valid(_body):
		return
	for ch in _body.get_children():
		ch.queue_free()
	_upgrade_btn = null
	var c := Meta.machine_card(id)
	_lv_lbl.text = Loc.f("LV", [int(c["lvl"])]) if bool(c["owned"]) else ""
	var desc := UIKit.label(Loc.t(str(c["desc"])), 24, UIKit.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(desc)
	if str(c["locked"]) == "phase":
		_body.add_child(_info_card("lock", Loc.t("LOCKED_SOON")))
		return
	if not bool(c["owned"]):
		var home := int(c["home_level"])
		_body.add_child(_info_card("lock", Loc.f("LOCKED_WORLD", [ArsenalData.world_of(home), ArsenalData.level_in_world(home)]) if home > 0 else Loc.t("LOCKED_SOON")))
		_body.add_child(_stats_card(c))
		return
	_body.add_child(_upgrade_card(c))
	_body.add_child(_stats_card(c))
	_body.add_child(_beats_card(c))
	_talent_box = _talents_card(c)
	_body.add_child(_talent_box)
	_body.add_child(_focus_card(c))
	_body.add_child(UIKit.gap(10))


# ------------------------------------------------------------------ blocks

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("card", Vector2(18, 14)))
	return p


func _section_title(text: String, icon := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		row.add_child(Icons.make(icon, 30.0))
	row.add_child(UIKit.heading(text.to_upper(), 22, UIKit.GOLD, 5))
	return row


func _info_card(icon: String, text: String) -> Control:
	var p := _panel()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(Icons.make(icon, 40.0))
	row.add_child(UIKit.heading(text, 28, UIKit.TEXT, 6))
	p.add_child(row)
	return p


func _upgrade_card(c: Dictionary) -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var maxed := int(c["lvl"]) >= ArsenalData.MAX_LEVEL
	if not maxed:
		var bar := BpBar.new()
		bar.custom_minimum_size = Vector2(0, 46)
		bar.have = int(c["bp"])
		bar.need = int(c["bp_need"])
		bar.wild = int(c["wild"])
		bar.rarity = str(c["rarity"])
		v.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_upgrade_btn = UIKit.styled_button("", "green", Vector2(560, 104))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_bottom = -7
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", -4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_lbl = UIKit.heading("", 34, Color(1, 1, 1), 8)
	_btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_btn_lbl)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_coin = Icons.make("coin", 26.0)
	line.add_child(_btn_coin)
	_btn_sub = UIKit.heading("", 24, Color(0.92, 1.0, 0.9), 5)
	line.add_child(_btn_sub)
	inner.add_child(line)
	_upgrade_btn.add_child(inner)
	_upgrade_btn.pressed.connect(press_upgrade)
	row.add_child(_upgrade_btn)
	_armed = false
	_refresh_upgrade()
	return p


## Two-tap upgrade: first tap arms ("Підтвердити · price"), second buys.
func press_upgrade() -> void:
	if _upgrade_btn == null or _busy:
		return
	var cost := Meta.upgrade_cost(id)
	if not bool(cost["can"]):
		Audio.play("error", -6.0)
		UIJuice.wobble(_upgrade_btn, 0.3, 0.3)
		return
	if not _armed:
		_armed = true
		UIJuice.haptic("CLICK", 0.5)
		_refresh_upgrade()
		_upgrade_btn.pivot_offset = _upgrade_btn.size * 0.5
		var tw := _upgrade_btn.create_tween()
		tw.tween_property(_upgrade_btn, "scale", Vector2(1.06, 0.9), 0.06)
		tw.tween_property(_upgrade_btn, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	_btn_sub.visible = false
	_btn_coin.visible = false
	if reason == "max":
		_btn_lbl.text = Loc.t("LV_MAX")
		_upgrade_btn.disabled = true
		return
	_upgrade_btn.disabled = false
	if _armed and can:
		for st: String in ["normal", "hover"]:
			_upgrade_btn.add_theme_stylebox_override(st, UIKit.lux("primary"))
		_upgrade_btn.add_theme_stylebox_override("pressed", UIKit.lux("primary_pressed"))
		_btn_lbl.text = Loc.f("CONFIRM_COST", [Loc.num(int(c["coins"]))]) if int(c["coins"]) > 0 else Loc.f("CONFIRM_COST", [Loc.t("FREE")])
		_btn_lbl.add_theme_color_override("font_color", UIKit.BROWN)
		_btn_lbl.add_theme_constant_override("outline_size", 0)
		if int(c["wild_use"]) > 0:
			_btn_sub.visible = true
			_btn_sub.text = Loc.f("USES_WILD", [int(c["wild_use"])])
			_btn_sub.add_theme_color_override("font_color", Color(0.4, 0.15, 0.55))
		return
	var kind := "green" if can else "button"
	for st: String in ["normal", "hover"]:
		_upgrade_btn.add_theme_stylebox_override(st, UIKit.lux(kind))
	_upgrade_btn.add_theme_stylebox_override("pressed", UIKit.lux(kind + "_pressed"))
	_btn_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_btn_lbl.add_theme_constant_override("outline_size", 8)
	_btn_lbl.text = Loc.f("UPGRADE_TO", [int(c["to_lvl"])])
	_btn_sub.visible = true
	_btn_sub.add_theme_color_override("font_color", Color(0.92, 1.0, 0.9) if can else UIKit.TEXT_DIM)
	_btn_coin.visible = int(c["coins"]) > 0 and reason in ["", "coins"]
	_btn_sub.text = Loc.num(int(c["coins"])) if int(c["coins"]) > 0 else Loc.t("FREE")
	match reason:
		"blueprints":
			_btn_sub.text = Loc.f("NEED_BP", [maxi(0, int(c["bp_need"]) - int(c["bp_have"]) - Meta.wild(ArsenalData.rarity_of(id)))])
		"coins":
			_btn_sub.text = Loc.num(int(c["coins"])) + " · " + Loc.t("NEED_COINS")
		"locked":
			_btn_sub.text = Loc.f("TAB_LOCKED", [int(EconData.unlock_entry("arsenal").get("after_win", 3)) + 1])
	var beat := str(c["beat"])
	if can and beat != "":
		_btn_sub.text += "  ·  " + Loc.t("BEAT_" + beat.to_upper())


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
	var center := _show.get_global_rect().get_center() - global_position
	var flash_at := UIJuice.flare(self, center, UITokens.family(ArsenalData.family_of(id)).lerp(UIKit.GOLD_LIGHT, 0.4), tier, 150.0)
	_show.celebrate(1.0 if tier == "full" else 0.6)
	await get_tree().create_timer(flash_at).timeout
	if not is_instance_valid(self):
		return
	var asc_now := int(res["lvl"]) >= ArsenalData.ASCENSION_LEVEL
	var asc_before := int(before["lvl"]) >= ArsenalData.ASCENSION_LEVEL
	if asc_now != asc_before:
		_show.show_machine(id, int(res["lvl"]), false)
	_lv_lbl.text = Loc.f("LV", [int(res["lvl"])])
	UIJuice.punch(_lv_lbl, 1.45, 0.4)
	Meta.note("upgrade_ceremony", {"id": id, "tier": tier})
	_busy = false
	_rebuild_body()
	await get_tree().process_frame
	_count_stats(stats_before)
	if beat != "":
		hub.toast(Loc.t("BEAT_" + beat.to_upper()) + "!", str(BEAT_ICONS.get(beat, "star")))
		if beat in ["talent1", "talent2"] and is_instance_valid(_talent_box):
			await get_tree().create_timer(0.4).timeout
			if is_instance_valid(_talent_box):
				_scroll.ensure_control_visible(_talent_box)
				UIJuice.punch(_talent_box, 1.04, 0.35)


## Stat values count up from the previous level after an upgrade (70 ms stagger).
func _count_stats(before: Dictionary) -> void:
	var i := 0
	for lbl in get_tree().get_nodes_in_group("md_stat_" + str(get_instance_id())):
		var key := str(lbl.get_meta("key"))
		var old: float = _stat_value(before, key)
		var now: float = float(lbl.get_meta("value"))
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


func _stats_card(c: Dictionary) -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_section_title(Loc.t("STATS"), "dmg"))
	var ms: Dictionary = c["stats"]
	var nxt := {}
	var lvl := int(c["lvl"])
	if bool(c["owned"]) and lvl < ArsenalData.MAX_LEVEL:
		nxt = ArsenalData.machine_stats(id, lvl + 1, 1, ms.get("talents", []), str(ms.get("branch", "")))
	var rows: Array = [["dps", "STAT_DPS", "rate"]]
	var s: Dictionary = ms["stats"]
	for r: Array in STAT_ROWS:
		if s.has(r[0]) and float(s[r[0]]) < 90.0:
			rows.append(r)
	rows = rows.slice(0, 6)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for r: Array in rows:
		var key := str(r[0])
		var val := _stat_value(ms, key)
		var fmt := "%.0f" if (val >= 10.0 or key in ["pierce", "bolts", "volley", "drones", "splash"]) else "%.1f"
		if key == "amp":
			fmt = "+%.0f%%"
			val *= 100.0
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(Icons.make(str(r[2]), 34.0))
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", -6)
		nv.add_child(UIKit.label(Loc.t(str(r[1])), 19, UIKit.TEXT_DIM))
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 8)
		var vl := UIKit.heading(fmt % val, 28, UIKit.TEXT, 6)
		vl.set_meta("key", key)
		vl.set_meta("value", val)
		vl.set_meta("fmt", fmt)
		vl.add_to_group("md_stat_" + str(get_instance_id()))
		vrow.add_child(vl)
		if not nxt.is_empty():
			var nval := _stat_value(nxt, key) * (100.0 if key == "amp" else 1.0)
			if nval - val > 0.005:
				var dl := UIKit.heading(("+%.0f" if fmt.begins_with("%.0") or key == "amp" else "+%.2f") % (nval - val), 22, UITokens.READY, 5)
				dl.size_flags_vertical = Control.SIZE_SHRINK_END
				vrow.add_child(dl)
		nv.add_child(vrow)
		cell.add_child(nv)
		grid.add_child(cell)
	# Status and flags chips.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	var st := str(ms.get("status", ""))
	if st != "" and ArsenalData.STATUSES.has(st):
		chips.add_child(_pill(Loc.t(str((ArsenalData.STATUSES[st] as Dictionary)["name"])), "st_" + st, Color(1.0, 0.85, 0.6)))
	var flags: Dictionary = c.get("flags", {})
	if bool(flags.get("hits_flying", false)):
		chips.add_child(_pill(Loc.t("FLAG_FLYING"), "wing", Color(0.7, 0.9, 1.0)))
	if bool(flags.get("bypass_shield", false)):
		chips.add_child(_pill(Loc.t("FLAG_BEAM"), "shield", Color(0.7, 1.0, 0.8)))
	if bool(flags.get("ground_only", false)):
		chips.add_child(_pill(Loc.t("FLAG_GROUND"), "", Color(0.9, 0.8, 0.7)))
	if chips.get_child_count() > 0:
		v.add_child(chips)
	return p


func _beats_card(c: Dictionary) -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_section_title(Loc.t("BEATS"), "laurel"))
	var tr := BeatTrack.new()
	tr.lvl = int(c["lvl"])
	tr.custom_minimum_size = Vector2(0, 120)
	v.add_child(tr)
	var asc := ArsenalData.ascension_of(id, "a")
	if not asc.is_empty() and asc.has("id"):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Icons.make("crystal", 28.0))
		var got := int(c["lvl"]) >= ArsenalData.ASCENSION_LEVEL
		row.add_child(UIKit.heading("%s: %s" % [Loc.t("ASCENSION"), Loc.t("ASC_" + str(asc["id"]).to_upper())], 22, UIKit.GOLD_LIGHT if got else UIKit.TEXT_DIM, 5))
		if not got:
			row.add_child(UIKit.label(Loc.f("TALENT_LOCKED", [ArsenalData.ASCENSION_LEVEL]), 19, UIKit.TEXT_DIM))
		v.add_child(row)
	return p


func _talents_card(c: Dictionary) -> Control:
	var p := _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var lvl := int(c["lvl"])
	var chosen: Array = c["talents"]
	var opts_all: Array = c["talent_options"]
	for tier in 2:
		var need: int = ArsenalData.TALENT_LEVELS[tier]
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(UIKit.heading(Loc.t("BEAT_TALENT%d" % (tier + 1)).to_upper(), 22, UIKit.GOLD, 5))
		var cur := str(chosen[tier]) if tier < chosen.size() else ""
		if lvl < need:
			head.add_child(UIKit.label(Loc.f("TALENT_LOCKED", [need]), 19, UIKit.TEXT_DIM))
		elif cur == "":
			head.add_child(UIKit.heading(Loc.t("TALENT_PICK"), 20, UITokens.CLAIM, 5))
		else:
			head.add_child(UIKit.label(Loc.t("TALENT_RESPEC"), 19, UIKit.TEXT_DIM))
		v.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var opts: Array = opts_all[tier] if tier < opts_all.size() else []
		for o: Dictionary in opts:
			var tid := str(o["id"])
			var tc := TalentCard.new()
			tc.talent = tid
			tc.state = "locked" if lvl < need else ("chosen" if cur == tid else ("pick" if cur == "" else "other"))
			tc.custom_minimum_size = Vector2(0, 118)
			tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tc.tapped.connect(_pick_talent.bind(tier, tid, tc))
			row.add_child(tc)
		v.add_child(row)
	return p


func _pick_talent(tier: int, tid: String, card: Control) -> void:
	var cur := str((Meta.machine_state(id).get("talents", ["", "", ""]) as Array)[tier])
	if cur == tid:
		return
	if Meta.set_talent(id, tier, tid):
		Audio.play("weapon_get", -6.0)
		var center := card.get_global_rect().get_center() - global_position
		UIJuice.flare(self, center, UIKit.GOLD_LIGHT, "micro", 90.0)
	else:
		Audio.play("error", -6.0)


func _focus_card(c: Dictionary) -> Control:
	var p := _panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	row.add_child(Icons.make("focus", 44.0))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(UIKit.heading(Loc.t("FOCUS_ON"), 26, UIKit.TEXT, 6))
	var d := UIKit.label(Loc.t("FOCUS_DESC"), 19, UIKit.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	row.add_child(v)
	var on := bool(c["is_focus"])
	var t := SettingsPanel.Toggle.new()
	t.on = on
	t.custom_minimum_size = Vector2(86, 46)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.toggled.connect(func(v2: bool):
		Meta.set_focus(id if v2 else "")
		UIJuice.haptic("CLICK", 0.5))
	row.add_child(t)
	return p


func _pill(text: String, icon: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.03, 0.08, 0.85), Color(col.r, col.g, col.b, 0.75), 14, 2, 0, Vector2(10, 3)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		row.add_child(Icons.make(icon, 22.0))
	row.add_child(UIKit.heading(text, 19, col.lightened(0.2), 4))
	p.add_child(row)
	return p


# ------------------------------------------------------------------ widgets

## Big blueprint bar: own blueprints (blue), the Wild share (violet), the count and the rarity.
class BpBar extends Control:
	var have := 0
	var need := 1
	var wild := 0
	var rarity := "C"

	func _draw() -> void:
		var f := UIKit.font(true)
		var r := Rect2(Vector2(40, 6), Vector2(size.x - 40, size.y - 12))
		draw_style_box(UIKit.box(Color(0.01, 0.015, 0.04, 0.95), Color(1, 1, 1, 0.14), 14, 2, 0, Vector2.ZERO), r)
		var k := clampf(float(have) / float(maxi(need, 1)), 0.0, 1.0)
		var kw := clampf(float(have + wild) / float(maxi(need, 1)), 0.0, 1.0)
		var inner := r.grow(-3)
		if kw > k:
			MachineCard.grad_box(self, Rect2(inner.position, Vector2(inner.size.x * kw, inner.size.y)), Color(0.8, 0.55, 1.0), Color(0.5, 0.25, 0.85), 11)
		if k > 0.0:
			var c1 := Color(0.45, 0.95, 0.4) if have >= need else Color(0.35, 0.65, 1.0)
			MachineCard.grad_box(self, Rect2(inner.position, Vector2(inner.size.x * k, inner.size.y)), c1.lightened(0.25), c1.darkened(0.2), 11)
			draw_rect(Rect2(inner.position + Vector2(6, 3), Vector2(inner.size.x * k - 12, 5)), Color(1, 1, 1, 0.3))
		var txt := "%s  %d/%d" % [Loc.t("CUR_BP"), have, need]
		if wild > 0 and have < need:
			txt += "  (+%d)" % mini(wild, need - have)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var tp := Vector2(r.get_center().x - tw * 0.5, r.get_center().y + 8)
		draw_string_outline(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0.02, 0.06))
		draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))
		Icons.draw_icon(self, "blueprint" if wild <= 0 or have >= need else "wild", Rect2(Vector2(0, 0), Vector2(size.y, size.y)))


## Lv1-15 track with the beat icons at 3/5/6/8/10/12/13-15 (Meta-1-off beats dimmed).
class BeatTrack extends Control:
	var lvl := 1

	func _draw() -> void:
		var f := UIKit.font(true)
		var n := ArsenalData.MAX_LEVEL
		var y := 46.0
		var x0 := 18.0
		var x1 := size.x - 18.0
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.02, 0.03, 0.08), 12.0, true)
		var xl := lerpf(x0, x1, float(clampi(lvl, 1, n) - 1) / float(n - 1))
		draw_line(Vector2(x0, y), Vector2(xl, y), Color(1.0, 0.78, 0.3), 6.0, true)
		var row := 0
		for l in range(1, n + 1):
			var x := lerpf(x0, x1, float(l - 1) / float(n - 1))
			var beat := Meta.beat_at(l)
			var live := beat != "" and _live(beat)
			var done := l <= lvl
			if beat == "":
				draw_circle(Vector2(x, y), 6.0, Color(1.0, 0.82, 0.4) if done else Color(0.3, 0.33, 0.45))
				continue
			var r := 17.0
			draw_circle(Vector2(x, y), r + 2.0, Color(0.02, 0.03, 0.08))
			draw_circle(Vector2(x, y), r, (Color(1.0, 0.8, 0.3) if done else Color(0.2, 0.24, 0.38)) if live else Color(0.14, 0.15, 0.2))
			var ic := str(MachineDetail.BEAT_ICONS.get(beat, "star"))
			Icons.draw_icon(self, ic, Rect2(Vector2(x, y) - Vector2(12, 12), Vector2(24, 24)), Color.WHITE if live else Color(0.45, 0.45, 0.5))
			var lt := str(l)
			var lw := f.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(f, Vector2(x - lw * 0.5, y - 24), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.GOLD_LIGHT if done else UIKit.TEXT_DIM)
			if beat in ["prestige"] and l == 14:
				continue
			var bt := Loc.t("BEAT_" + beat.to_upper()) if live else Loc.t("SOON")
			var fs := 15
			var bw := f.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var by := y + 38.0 + (18.0 if row % 2 == 1 else 0.0)
			var bx := clampf(x - bw * 0.5, 0.0, size.x - bw)
			draw_string_outline(f, Vector2(bx, by), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0.01, 0.05))
			draw_string(f, Vector2(bx, by), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (UIKit.TEXT if done else UIKit.TEXT_DIM) if live else Color(0.45, 0.47, 0.55))
			row += 1

	static func _live(beat: String) -> bool:
		match beat:
			"talent1", "talent2": return bool(ArsenalData.FEATURES["talents12"])
			"talent3": return bool(ArsenalData.FEATURES["talent3"])
			"lead": return bool(ArsenalData.FEATURES["lead"])
			"ascension": return bool(ArsenalData.FEATURES["ascension"])
			"apex": return bool(ArsenalData.FEATURES["apex"])
			"prestige", "mastered": return bool(ArsenalData.FEATURES["prestige_frames"])
		return false


## One talent option: name, effect, state (locked | pick | chosen | other).
class TalentCard extends Control:
	signal tapped
	var talent := ""
	var state := "pick"
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _ready() -> void:
		UIJuice.press(self)

	func _process(delta: float) -> void:
		if state == "pick" or state == "chosen":
			_t += delta
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if UIJuice.is_tap(e) and state != "locked":
			tapped.emit()

	func _draw() -> void:
		var f := UIKit.font(true)
		var r := Rect2(Vector2(2, 4), size - Vector2(4, 8))
		var chosen := state == "chosen"
		var locked := state == "locked"
		if chosen:
			draw_texture_rect(UIKit.glow_texture(), r.grow(18), false, Color(1.0, 0.75, 0.3, 0.35 + 0.1 * sin(fmod(_t, 100.0) * 3.0)))
		var rim := Color(1.0, 0.82, 0.38) if chosen else (Color(1.0, 0.8, 0.3, 0.55 + 0.35 * sin(fmod(_t, 100.0) * 4.0)) if state == "pick" else Color(0.4, 0.44, 0.58))
		draw_style_box(UIKit.box(Color(0.1, 0.12, 0.25) if not locked else Color(0.06, 0.07, 0.12), rim, 18, 3 if chosen else 2, 0, Vector2.ZERO), r)
		var name := Loc.t("TAL_" + talent.to_upper())
		var desc := Loc.t("TAL_" + talent.to_upper() + "_DESC")
		var fs := UIKit.fit_size(name, r.size.x - 56, 24, 16)
		var col := Color(1, 1, 1) if not locked else Color(0.5, 0.52, 0.6)
		draw_string_outline(f, r.position + Vector2(14, 34), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0.01, 0.05))
		draw_string(f, r.position + Vector2(14, 34), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		var fr := UIKit.font(false)
		var lines := _wrap(desc, r.size.x - 28, 19, fr)
		for i in mini(lines.size(), 3):
			draw_string(fr, r.position + Vector2(14, 62 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UIKit.TEXT_DIM if not locked else Color(0.42, 0.44, 0.52))
		var ic := Rect2(Vector2(r.end.x - 40, r.position.y + 10), Vector2(30, 30))
		if chosen:
			draw_circle(ic.get_center(), 16, Color(0.2, 0.6, 0.25))
			Icons.draw_icon(self, "check", ic.grow(-4), Color.WHITE)
		elif locked:
			Icons.draw_icon(self, "lock", ic.grow(-4), Color(0.6, 0.62, 0.7))

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
