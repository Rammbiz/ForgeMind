class_name HeroesTeamScreen
extends Control
## «Команда / Team» (heroes_design.md §4.2, §5.5, §9.2, §9.3, §11.3; part U §2.7). Route
## "team[/roster|/hero|/auto]" (HeroesNav, host "screen": full screen over the hub chrome, as §9.2
## lists it). AFK Journey formation × Genshin light:
##   backdrop   the bright painted sky of the team hero's gem (HeroShowcaseBackdrop, no halo)
##   header     «Команда» · «?» Codex · presets «Набір 1 / 2 / 3» (tap = load, hold = save) ·
##              «Підібрати» (Auto-team: shown as ghosts with Застосувати / Скасувати, never silent)
##   stage      HeroesTeamStage: the hero at the dais centre, champions standing on their run
##              slots (ChampionKinds.slot_offset front / left / right / rear), the role line first
##              under every champion; an empty open slot = a dashed seat «Додати»; the 3rd slot
##              before L40 = a closed seat «Після рівня 40»
##   sheet      cream sheet: synergy (simple mode one line per active bonus until L20, the full
##              three-column panel after; HeroesTeamSynergy) and the dock ‹ · «Грати» (amber)
## Tap a champion / an empty seat = the roster sheet for that slot (delta badges); tap the hero =
## the hero roster. «Грати» plays the team-ready beat (0.4 s, CeremonyData.TEAM_READY) and starts
## the run (hub.play). Reduce Motion: no entrance motion, no beat.

signal closed

var hub: Hub
var _start := ""
var _ins := Vector4.ZERO
var _team: Dictionary = {}
var _preview: Dictionary = {}       ## Auto-team ghost preview ({} = none)
var _dirty := false
var _launching := false

var _bg: HeroShowcaseBackdrop
var _stage: HeroesTeamStage
var _header: HBoxContainer
var _presets: HBoxContainer
var _sheet: KitSheet
var _sheet_box: VBoxContainer
var _auto_info: Dictionary = {}    ## auto_team() result while the preview is open
var _overlay: Control
var _member_nodes: Array[Control] = []
var _press_ms := {}

const CARD_S := Vector2(124, 186)
const CARD_M := Vector2(156, 208)


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0:
		_start = str(args[0])


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ins = hub.insets() if hub else Vector4.ZERO
	_team = HeroesUIModel.team()
	var h := HeroesUIModel.hero(str(_team["hero"]))
	_bg = HeroShowcaseBackdrop.make(str(h.get("gem", "L")), str(h.get("element", "")))
	_bg.halo = false
	_bg.focus = Vector2(0.5, 0.2)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_stage = HeroesTeamStage.new()
	add_child(_stage)
	_build_header()
	_sheet = UIKit.sheet(Vector2(UITokens.GUTTER, 22.0))
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_sheet)
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 14)
	_sheet.add_child(_sheet_box)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_rebuild(true)
	resized.connect(_layout)
	HeroesUIModel.bus().changed.connect(_on_model)
	match _start:
		"roster": (func(): _open_roster(0)).call_deferred()
		"hero": (func(): _open_roster(-1)).call_deferred()
		"auto": (func(): _auto()).call_deferred()


func _on_model(what: String) -> void:
	if _dirty or not (what in ["team", "state", "heroes", "champions"]):
		return
	_dirty = true
	(func():
		_dirty = false
		if is_instance_valid(self) and is_inside_tree():
			refresh()).call_deferred()


func refresh() -> void:
	_team = HeroesUIModel.team()
	_rebuild(false)


# ------------------------------------------------------------------ build

func _build_header() -> void:
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	add_child(_header)
	var t := UIKit.gradient_heading(HeroesText.t("TEAM_TITLE"), 44)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(t)
	_presets = HBoxContainer.new()
	_presets.add_theme_constant_override("separation", 8)
	_header.add_child(_presets)
	var cx := UIKit.edge_button("help", 34.0)
	cx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cx.pressed.connect(_open_codex)
	_header.add_child(cx)


func _rebuild(entrance: bool) -> void:
	_team = HeroesUIModel.team()
	var shown := _shown_team()
	var h := HeroesUIModel.hero(str(shown["hero"]))
	_bg.gem = str(h.get("gem", "L"))
	_bg.element = str(h.get("element", ""))
	_stage.gem = str(h.get("gem", "C"))
	_fill_presets()
	# Stage members.
	for n in _member_nodes:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
	_member_nodes.clear()
	var seats := HeroesTeamLogic.slot_layout(shown)
	_stage.seats = seats
	var ghost := not _preview.is_empty()
	var items: Array = []
	items.append({"kind": "hero", "slot": &"hero", "id": str(shown["hero"]), "index": -1})
	for s: Dictionary in seats:
		items.append({"kind": str(s["state"]), "slot": s["slot"], "id": str(s["id"]), "index": int(s["index"])})
	items.sort_custom(func(a, b): return _stage.floor_point(a["slot"]).y < _stage.floor_point(b["slot"]).y)
	for it: Dictionary in items:
		var node := _member(it, ghost)
		if node:
			_stage.add_child(node)
			_member_nodes.append(node)
	# Role chips go on top of every card (the role line first, §11.3).
	for n in _member_nodes.duplicate():
		if n.has_meta("role_node"):
			var rc: Control = n.get_meta("role_node")
			_stage.add_child(rc)
			_member_nodes.append(rc)
	# Sheet: synergy + dock.
	_clear(_sheet_box)
	var inner := _vp().x - UITokens.GUTTER * 2.0 - 4.0
	if ghost:
		# The suggestion REPLACES the synergy block (never laid over it): what changes, why, and
		# the two choices; the dock stays below.
		var blk := _auto_block(inner)
		_sheet_box.add_child(blk)
		if not UITokens.reduce_motion():
			UIJuice.soft_in(blk, Vector2(0, 16))
	else:
		_sheet_box.add_child(HeroesTeamSynergy.make(_team, inner))
	_sheet_box.add_child(_dock())
	_layout()
	(func(): _layout()).call_deferred()
	if entrance and not UITokens.reduce_motion():
		UIJuice.soft_in(_header, Vector2(0, -12), 0.04)
		UIJuice.cards_in(_member_nodes.duplicate(), 0.1)
		UIJuice.sheet_in(_sheet, 0.06)


## The team the stage shows: the Auto-team preview while it is open, else the real team.
func _shown_team() -> Dictionary:
	if _preview.is_empty():
		return _team
	var t := _team.duplicate(true)
	t["hero"] = str(_preview["hero"])
	var champs: Array = (_preview["champions"] as Array).duplicate()
	while champs.size() < int(_team["slots"]):
		champs.append("")
	t["champions"] = champs
	var syn := _team["synergy"] as Dictionary
	t["synergy"] = syn
	return t


func _member(it: Dictionary, ghost: bool) -> Control:
	var kind := str(it["kind"])
	var slot: StringName = it["slot"]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("slot", slot)
	var sz := CARD_M if kind == "hero" else CARD_S
	holder.size = sz
	holder.custom_minimum_size = sz
	match kind:
		"hero":
			var hd := HeroesUIModel.hero(str(it["id"]))
			var card := HeroCard.make(hd, "M")
			card.pressed.connect(func(_i): _open_roster(-1))
			holder.add_child(card)
			if ghost:
				card.modulate.a = 0.82
		"champion":
			var cd := HeroesUIModel.champion(str(it["id"]))
			var card := HeroCard.make(cd, "S")
			card.show_role = false
			card.footer_mode = "name"
			var idx := int(it["index"])
			card.pressed.connect(func(_i): _open_roster(idx))
			holder.add_child(card)
			if ghost:
				card.modulate.a = 0.82
			var role := _role_chip(str(cd["role"]))
			role.set_meta("is_role", true)
			role.set_meta("slot", slot)
			holder.set_meta("role_node", role)
		"empty":
			var g := _Seat.new()
			g.locked = false
			g.text = HeroesText.t("TEAM_SLOT_ADD")
			g.size = sz
			var idx2 := int(it["index"])
			g.tapped.connect(func(): _open_roster(idx2))
			holder.add_child(g)
		"locked":
			var g2 := _Seat.new()
			g2.locked = true
			g2.text = HeroesText.t("TEAM_SLOT_LOCKED", [HeroesTeamLogic.seat_unlock_level(int(it["index"]))])
			g2.size = sz
			holder.add_child(g2)
		_:
			return null
	return holder


func _role_chip(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UIKit.cbox(UITokens.PAPER_0, int(UITokens.CHAMFER_XS), UITokens.HAIRLINE, 1, Vector2(10, 3)))
	var l := UIKit.label(text, 22, UITokens.INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _fill_presets() -> void:
	_clear(_presets)
	var active := HeroesTeamLogic.active_preset()
	var ps := HeroesTeamLogic.presets()
	for i in ps.size():
		var p: Dictionary = ps[i]
		var key := _PresetKey.new()
		key.num = i + 1
		key.gem = str(HeroesUIModel.hero(str(p["hero"]))["gem"]) if not p.is_empty() else ""
		key.active = i == active
		key.tooltip_text = HeroesText.t("TEAM_PRESET_HINT")
		key.button_down.connect(func(): _press_ms[i] = Time.get_ticks_msec())
		key.pressed.connect(func(): _on_preset(i))
		_presets.add_child(key)


func _dock() -> Control:
	var d := HBoxContainer.new()
	d.add_theme_constant_override("separation", 12)
	var back := UIKit.secondary_button("", "back", Vector2(96, 88))
	back.pressed.connect(_back)
	d.add_child(back)
	if _has_champions():
		var auto := UIKit.secondary_button(HeroesText.t("TEAM_AUTO"), "auto", Vector2(196, 88), 24)
		auto.pressed.connect(_auto)
		d.add_child(auto)
	var lvl := int(HeroesUIModel.unlocks()["level"]) + 1
	var play := UIKit.cta_button(HeroesText.t("TEAM_PLAY"), HeroesText.t("TEAM_PLAY_SUB", [lvl]), Vector2(0, 88), 32)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_play)
	d.add_child(play)
	return d


## Auto-team needs at least one open seat and one owned champion (before L14 there is nothing
## to pick, so «Підібрати» is not shown).
func _has_champions() -> bool:
	if int(_team["slots"]) <= 0:
		return false
	for c: Dictionary in HeroesUIModel.champions():
		if bool(c["owned"]):
			return true
	return false


# ------------------------------------------------------------------ layout

func _vp() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


func _layout() -> void:
	if _sheet == null:
		return
	var vp := _vp()
	var W := vp.x
	var H := vp.y
	var y0 := _ins.y + 22.0
	_header.position = Vector2(UITokens.GUTTER, y0)
	_header.size = Vector2(W - UITokens.GUTTER * 2.0, 88)
	var sh := _sheet.get_combined_minimum_size().y + _ins.w
	_sheet.position = Vector2(0, H - sh)
	_sheet.size = Vector2(W, sh)
	var top := y0 + 98.0
	_stage.position = Vector2(0, top)
	_stage.size = Vector2(W, maxf(420.0, H - sh - top + 12.0))
	for n in _member_nodes:
		if not is_instance_valid(n):
			continue
		var slot: StringName = n.get_meta("slot")
		var fp := _stage.floor_point(slot)
		if n.has_meta("is_role"):
			n.size = n.get_combined_minimum_size()
			n.position = fp + Vector2(-n.size.x * 0.5, 2.0)
			# A chip that would land on the hero card goes above its own card instead.
			var hc := _stage.floor_point(&"hero")
			var hh := 208.0 * _stage.depth(&"hero")
			var hero_r := Rect2(hc - Vector2(78.0 * _stage.depth(&"hero"), hh), Vector2(156.0 * _stage.depth(&"hero"), hh))
			if hero_r.intersects(Rect2(n.position, n.size)):
				n.position.y = fp.y - 186.0 * _stage.depth(slot) - n.size.y + 4.0
			n.position.y = minf(n.position.y, _stage.size.y - n.size.y - 2.0)
			continue
		var k := _stage.depth(slot)
		n.scale = Vector2(k, k)
		n.pivot_offset = Vector2(n.size.x * 0.5, n.size.y)
		n.position = fp - Vector2(n.size.x * 0.5, n.size.y - 8.0)


# ------------------------------------------------------------------ actions

func _on_preset(i: int) -> void:
	var held: int = Time.get_ticks_msec() - int(_press_ms.get(i, Time.get_ticks_msec()))
	var name := HeroesText.t("TEAM_PRESET", [i + 1])
	var empty := (HeroesTeamLogic.presets()[i] as Dictionary).is_empty()
	if held >= 500 or empty:
		HeroesTeamLogic.save_preset(i)
		UIKit.toast(self, HeroesText.t("TEAM_PRESET_SAVED", [name]), "check")
		_fill_presets()
		return
	if HeroesTeamLogic.load_preset(i):
		UIKit.toast(self, HeroesText.t("TEAM_PRESET_LOADED", [name]), "team")


func _open_roster(slot_index: int) -> void:
	if _launching or not _preview.is_empty():
		return
	var slot_name: StringName = &"hero"
	for s: Dictionary in HeroesTeamLogic.slot_layout(_team):
		if int(s["index"]) == slot_index:
			slot_name = s["slot"]
	if slot_index >= int(_team["slots"]):
		return
	_stage.focus_slot = slot_name if slot_index >= 0 else &""
	var r := HeroesTeamRoster.make(hub, slot_index, slot_name)
	r.placed.connect(func(id: String): _place(slot_index, id))
	r.closed.connect(func():
		_stage.focus_slot = &""
		r.queue_free())
	_overlay.add_child(r)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _place(slot_index: int, id: String) -> void:
	var champs: Array = (_team["champions"] as Array).duplicate()
	var hero_id := str(_team["hero"])
	if slot_index < 0:
		if id != "":
			hero_id = id
	else:
		var j := champs.find(id)
		if j >= 0 and id != "":
			champs[j] = champs[slot_index] if slot_index < champs.size() else ""
		while champs.size() <= slot_index:
			champs.append("")
		champs[slot_index] = id
	UIJuice.haptic("CLICK", 0.5)
	Audio.play("click", -8.0)
	HeroesUIModel.set_team(hero_id, champs)


func _auto() -> void:
	if not _preview.is_empty():
		_close_auto()
		return
	var best := HeroesTeamLogic.auto_team()
	if str(best["reason"]) == "same" or (str(best["hero"]) == str(_team["hero"]) and HeroesTeamLogic._same(best["champions"], _team["champions"])):
		UIKit.toast(self, HeroesText.t("TEAM_AUTO_SAME"), "check")
		return
	_auto_info = best
	_preview = best
	_rebuild(false)


## The suggestion block shown in the sheet in place of the synergy panel.
func _auto_block(inner: float) -> Control:
	var best := _auto_info
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UIKit.section(HeroesText.t("TEAM_AUTO_TITLE")))
	var names: Array[String] = [HeroesText.hero_name(str(best["hero"]))]
	for c in best["champions"]:
		names.append(HeroesText.champ_name(str(c)))
	var l := UIKit.label(" · ".join(names), 24, UITokens.INK, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(inner, 0)
	v.add_child(l)
	# Why: the synergy change, then (when the synergy does not rise) the power reason.
	var why := HBoxContainer.new()
	why.add_theme_constant_override("separation", 14)
	why.add_child(UIKit.label(HeroesText.t("TEAM_AUTO_GAINS", [int(best["syn_now"]), int(best["syn"])]), 22, UITokens.INK_DIM))
	var cur := HeroesTeamLogic.score(str(_team["hero"]), _team["champions"])
	var nxt := HeroesTeamLogic.score(str(best["hero"]), best["champions"])
	for k: String in ["faction", "class", "element"]:
		var d := int(nxt[k]) - int(cur[k])
		if d != 0:
			why.add_child(_delta_tag(HeroesText.t("TEAM_DELTA_" + k.to_upper() + ("" if d > 0 else "_LOSS")), d > 0))
	v.add_child(why)
	var reason := str(best["reason"])
	if reason != "synergy":
		var r := UIKit.label(HeroesText.t("TEAM_AUTO_WHY_POWER" if reason == "power" else "TEAM_AUTO_WHY_POWER_OVER"), 22, UITokens.INK)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(inner, 0)
		v.add_child(r)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var no := UIKit.secondary_button(HeroesText.t("TEAM_AUTO_CANCEL"), "close", Vector2(0, 88), 24)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_close_auto)
	row.add_child(no)
	var yes := UIKit.secondary_button(HeroesText.t("TEAM_AUTO_APPLY"), "check", Vector2(0, 88), 24)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		var b := _preview
		_preview = {}
		_auto_info = {}
		HeroesUIModel.set_team(str(b["hero"]), b["champions"]))
	row.add_child(yes)
	v.add_child(row)
	return v


## An inline synergy delta tag (no box, so it never reads as a button): a small gem-tinted
## rhombus + 20 px text, gains in PLUS, losses in INK_DIM.
static func _delta_tag(text: String, gain: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := _Dot.new()
	dot.gain = gain
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UIKit.label(text, 20, UITokens.PLUS if gain else UITokens.INK_DIM, gain))
	return h


func _close_auto() -> void:
	_preview = {}
	_auto_info = {}
	_rebuild(false)


func _open_codex() -> void:
	var c := HeroesCodexSheet.make(hub, true)
	_overlay.add_child(c)
	c.closed.connect(func(): c.queue_free())


## Team-ready (0.4 s, §9.4): every member card glints in sequence, then the run starts.
func _play() -> void:
	if _launching:
		return
	_launching = true
	UIJuice.haptic("THUD", 0.7)
	var go := func():
		_launching = false
		if hub and is_instance_valid(hub):
			hub.play.emit()
	if UITokens.reduce_motion():
		go.call()
		return
	var step := CeremonyData.TEAM_READY / maxf(1.0, _member_nodes.size())
	var i := 0
	for n in _member_nodes:
		if is_instance_valid(n) and not n.has_meta("is_role") and n.get_child_count() > 0:
			var c := n.get_child(0) as Control
			if c:
				c.pivot_offset = c.size * 0.5
				var tw := c.create_tween()
				tw.tween_interval(step * i)
				tw.tween_property(c, "scale", Vector2(1.04, 1.04), step * 0.5).set_trans(Tween.TRANS_SINE)
				tw.tween_property(c, "scale", Vector2.ONE, step * 0.5).set_trans(Tween.TRANS_SINE)
			i += 1
	get_tree().create_timer(CeremonyData.TEAM_READY).timeout.connect(go)


func _back() -> void:
	Audio.play("click", -8.0)
	if UITokens.reduce_motion():
		closed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_callback(func(): closed.emit())


## A seat card: an open slot (dashed, «+», «Додати») or the locked third slot (closed, lock).
class _Seat extends Control:
	signal tapped
	var locked := false
	var text := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if not locked and UIJuice.is_tap(e):
			tapped.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pts := GemDraw.chamfer_rect(r, UITokens.CHAMFER)
		var hl := UITokens.HAIRLINE
		draw_colored_polygon(pts, Color(1, 1, 1, 0.42 if not locked else 0.3))
		if locked:
			GemDraw.outline(self, pts, Color(hl.r, hl.g, hl.b, 0.7), 1.5)
		else:
			for i in pts.size():
				var a := pts[i]
				var b := pts[(i + 1) % pts.size()]
				var L := a.distance_to(b)
				var n := int(L / 12.0)
				for k in n:
					if k % 2 == 0:
						draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), hl, 2.0, true)
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		draw_circle(c, 30.0, UITokens.PAPER_0)
		draw_arc(c, 29.0, 0, TAU, 40, hl, 1.5, true)
		Icons.draw_icon(self, "lock" if locked else "plus", Rect2(c - Vector2(18, 18), Vector2(36, 36)), UITokens.INK_DIM if locked else UITokens.GOLD_TEXT)
		var f := UIKit.font(true)
		var fs := 22
		while fs > 18 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > size.x - 10.0:
			fs -= 1
		var lines := [text]
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > size.x - 10.0:
			# Two lines at the full 22 px (shrink only if a single word still does not fit).
			lines = text.split(" ", false, 1)
			fs = 22
			for ln: String in lines:
				while fs > 18 and f.get_string_size(ln, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x > size.x - 10.0:
					fs -= 1
		var y := size.y * 0.42 + 62.0
		for ln: String in lines:
			draw_string(f, Vector2(5, y), ln, HORIZONTAL_ALIGNMENT_CENTER, size.x - 10.0, fs, UITokens.INK_DIM if locked else UITokens.INK)
			y += fs + 4.0


## A preset key (part U §2.7: 88 x 88, the preset hero's gem): numeral + the hero's gem-cut mark;
## active (the current team) = gold fill. Tap loads, hold saves.
class _PresetKey extends Button:
	var num := 1
	var gem := ""
	var active := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(88, 88)
		for st: String in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2(2, 6), Vector2(size.x - 4.0, size.y - 12.0))
		if button_pressed:
			r = r.grow(-1.5)
		var pts := GemDraw.chamfer_rect(r, UITokens.CHAMFER_XS)
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 3))
		draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
		draw_colored_polygon(pts, UITokens.CTA_HI if active else (UITokens.PAPER_0 if gem != "" else UITokens.PAPER_2))
		GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)
		GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(-3.0), 4.0), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.4), 1.0)
		var f := UIKit.font_w("extrabold")
		var ink := UIKit.BROWN if active else (UITokens.INK if gem != "" else UITokens.INK_DIM)
		if gem != "":
			# The preset hero's gem (22 px) left of the numeral, on one line.
			var cy := r.get_center().y
			GemDraw.draw_mark(self, gem, Vector2(size.x * 0.5 - 15.0, cy), 22.0)
			draw_string(f, Vector2(size.x * 0.5 + 2.0, cy + 10.0), str(num), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
		else:
			draw_string(f, Vector2(0, r.get_center().y + 10.0), str(num), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, ink)


## The rhombus of an inline delta tag: gold for a gain, an engraved outline for a loss.
class _Dot extends Control:
	var gain := true

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.72, 0), c + Vector2(0, r), c + Vector2(-r * 0.72, 0)])
		if gain:
			draw_colored_polygon(pts, UITokens.GOLD_HI)
			GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.0)
		else:
			GemDraw.outline(self, pts, UITokens.INK_DIM, 1.2)


## Removes every child at once (queue_free alone leaves them in the layout until the frame ends).
static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
