class_name HeroesRecutScreen
extends Control
## «Огранка / Recut» (heroes_design.md §2.2-§2.4, §3.2, §9.3, §9.5 row 6; part U §2.5): the one
## place where rule #3 is explained. Route "recut/<id>[/ceremony]" (HeroesNav, host "screen").
## Heroes and champions alike (a champion swaps the skill rows for «Ярус дії»).
##   header   «Огранка» · «Арін · Кварц → Сапфір» · «?» Codex
##   lead     «ВІДКРИВАЄ»: what the recut unlocks, first (+1 межа навичок · +3,65% до показників ·
##            Пробудження · 5 нових граней), all generated from Ladder (never a form: the ult form
##            is capped by the native gem, so a recut never unlocks one - honestly absent)
##   stones   the current Living Gem (Full facets) → the NEXT doublet emblem (crown in the new gem,
##            pavilion in the native gem, rule #3 visible) + the five-gem path with
##            «корінний» / «зараз» / «далі»
##   table    the honesty table Зараз · Після огранки · Корінний <gem> (Міць, Показники, Межа
##            рангу, Форма ульти, Пробудження / Ярус дії), «→» = the value at Full facets; the
##            honest lines under it. Never collapsed.
##   ceiling  the native-ceiling bar (a native's Full facets = 100 %, your ceiling tick ≤ 96 %)
##   cost     fragments only, an engraved bar «44 / 40»
##   dock     ‹ · «Огранити» (amber; two taps: «Підтвердити» then the ceremony) or the disabled
##            reason («Ще 2 грані до Повних граней», «Бракує 16 фрагм.»)
## The grant happens on the second tap, BEFORE the ceremony (§9.5 row 5); «Далі» closes the screen
## and the Showcase below re-enters with the new gem.

signal closed

var hub: Hub
var char_id := "arin"
var _start_ceremony := false
var _ins := Vector4.ZERO
var _d: Dictionary = {}
var _p: Dictionary = {}
var _armed := false
var _arm_id := 0

var _bg: HeroShowcaseBackdrop
var _veil: ColorRect
var _frost: HeroFrost
var _header: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _dock: HBoxContainer
var _cta: Button
var _cer: HeroesRecutCeremony
var _sheet: Control
var _fade: Control


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0:
		char_id = str(args[0])
	_start_ceremony = "ceremony" in args


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ins = hub.insets() if hub else Vector4.ZERO
	_load()
	var nxt := str(_p["next"]) if str(_p["next"]) != "" else str(_d["gem"])
	_bg = HeroShowcaseBackdrop.make(nxt, str(_d.get("element", "")))
	_bg.focus = Vector2(0.5, 0.3)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	# UI v3.1: the panels frost this screen's own sky (HeroFrost), body text on the 94 % bed.
	_frost = HeroFrost.attach(self)
	_bg.baked.connect(func(): _frost.set_layers([{"tex": _bg.baked_texture(), "rect": Rect2(Vector2.ZERO, size)}]))
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_fade = UIKit.scroll_fade(_scroll, UITokens.PAPER_1)
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 12)
	add_child(_dock)
	_build()
	resized.connect(_layout)
	_layout()
	if not UITokens.reduce_motion():
		UIJuice.soft_in(_header, Vector2(0, -12))
		var i := 0
		for c in _body.get_children():
			UIJuice.soft_in(c, Vector2(0, 20), 0.05 + 0.04 * i)
			i += 1
		UIJuice.soft_in(_dock, Vector2(0, 20), 0.16)
	if _start_ceremony:
		(func(): _run_ceremony()).call_deferred()


func _load() -> void:
	_d = HeroesUIModel.hero(char_id) if HeroData.HEROES.has(char_id) else HeroesUIModel.champion(char_id)
	_p = HeroesRecutPreview.of(_d)


func refresh() -> void:
	if _cer:
		return
	_load()
	_build()
	_layout()


# ------------------------------------------------------------------ build

func _build() -> void:
	_clear(_header)
	_clear(_body)
	_clear(_dock)
	var gem := str(_d["gem"])
	var nxt := str(_p["next"])
	# Header.
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_child(UIKit.gradient_heading(HeroesText.t("RECUT_TITLE"), 44))
	var sub := HeroesText.t("RECUT_HEAD", [str(_d["name"]), HeroesText.gem_name(gem), HeroesText.gem_name(nxt)]) if nxt != "" \
			else str(_d["name"]) + " · " + HeroesText.gem_name(gem)
	tcol.add_child(UIKit.label(sub, 26, UITokens.GOLD_TEXT_GLASS, true))
	_header.add_child(tcol)
	var cx := UIKit.edge_button("help", 34.0)
	cx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cx.pressed.connect(_open_codex)
	_header.add_child(cx)
	var inner := _inner_w()
	if bool(_p["at_max"]):
		var st := _stones()
		st.custom_minimum_size = Vector2(0, 250)
		_body.add_child(st)
		_body.add_child(_path())
		_body.add_child(_top_status(inner))
	else:
		# Order (§9.3): what it unlocks, the stones + path on one compact band, the honesty table
		# and the native-ceiling bar (both above the fold at 720 x 1280), the honest lines, cost.
		_body.add_child(_unlocks(inner))
		_body.add_child(_stones())
		_body.add_child(_path())
		_body.add_child(_table(inner))
		_body.add_child(_ceiling(inner))
		_body.add_child(_cost(inner))
	_body.add_child(UIKit.gap(8))
	# Dock.
	var back := UIKit.edge_button("back", 38.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	_dock.add_child(back)
	if not bool(_p["at_max"]):
		_cta = UIKit.cta_button(HeroesText.t("RECUT_CTA"), "", Vector2(0, 88), 32)
		_cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cta.pressed.connect(_on_cta)
		_dock.add_child(_cta)
		_sync_cta()
	elif HeroData.HEROES.has(char_id):
		# The highest cut: «Далі ростуть грані й навички» leads straight to the hero's facets page.
		var fb := UIKit.secondary_button(HeroesText.t("MANAGE_TAB_FACETS"), "", Vector2(0, 88), 28)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func(): HeroesNav.open(hub, "hero/" + char_id + "/manage/facets"))
		_dock.add_child(fb)


## A frosted glass panel over this screen (text on the 94 % bed), or the flat text glass.
func _glass_panel() -> PanelContainer:
	var p := PanelContainer.new()
	# The kit card's pad (16, 14): the rows size themselves to it (inner - 48).
	if not HeroFrost.frost_panel(p, "panel", Vector2(16, 14), _frost):
		p.add_theme_stylebox_override("panel", UIKit.lux("banner", Vector2(16, 14)))
	return p


func _inner_w() -> float:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	return W - UITokens.GUTTER * 2.0


## «ВІДКРИВАЄ»: the gains of this recut, as engraved cartouches (the lead block, §9.3).
func _unlocks(inner: float) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UIKit.section(HeroesText.t("RECUT_UNLOCKS")))
	var note := UIKit.label(HeroesText.t("RECUT_UNLOCK_NOTE"), 22, UITokens.INK_DIM_GLASS)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(note)
	v.add_child(head)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.custom_minimum_size = Vector2(inner - 48.0, 0)
	v.add_child(flow)
	var first := true
	for u: String in _p["unlocks"]:
		var c := PanelContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# v3.1: the lead gain is the selected-segment glass (cream 0.92 + one 1 dpx gold line, deep-gold
		# ink), the rest frameless wells (§3.2: no borders on chips inside a card; amber only on verbs).
		c.add_theme_stylebox_override("panel", UIKit.lux("seg_sel" if first else "well", Vector2(12, 3)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := Icons.make("arrow_up", 22.0, UITokens.GOLD_TEXT_GLASS)
		ic.custom_minimum_size = Vector2(22, 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(UIKit.label(u, 24, UITokens.GOLD_TEXT_GLASS if first else UITokens.INK, true))
		c.add_child(h)
		flow.add_child(c)
		first = false
	return p


## The current stone → the next doublet stone.
func _stones() -> Control:
	var row := _Stones.new()
	row.gem = str(_d["gem"])
	row.native = str(_d["native"])
	row.next = str(_p["next"])
	row.facets = int(_d["facets"])
	row.custom_minimum_size = Vector2(0, 150)
	return row


## The five-gem path: native · now · next · beyond (champions stop at Топаз).
func _path() -> Control:
	var p := _Path.new()
	p.native = str(_d["native"])
	p.gem = str(_d["gem"])
	p.next = str(_p["next"])
	p.max_gem = Ladder.HERO_MAX_GEM if str(_d.get("kind", "hero")) == "hero" else Ladder.CHAMPION_MAX_GEM
	p.custom_minimum_size = Vector2(0, 112 if p.native == p.gem else 92)
	return p


func _table(inner: float) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var w := inner - 40.0
	var lw := 168.0
	var cw := (w - lw) / 3.0
	var nxt := str(_p["next"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.add_child(_cell("", lw, 20, UITokens.INK_DIM_GLASS, false, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(_cell(HeroesText.t("RECUT_COL_NOW"), cw, 20, UITokens.INK_DIM_GLASS, true))
	head.add_child(_cell(HeroesText.t("RECUT_COL_AFTER"), cw, 20, UITokens.GOLD_TEXT_GLASS, true))
	head.add_child(_cell(HeroesText.t("RECUT_COL_NATIVE", [HeroesText.gem_name(nxt)]), cw, 20, UITokens.INK_DIM_GLASS, true))
	v.add_child(head)
	v.add_child(UIKit.hairline())
	for r: Dictionary in _p["rows"]:
		var row := _TableRow.new()
		row.label = HeroesText.t(str(r["key"]))
		row.now = str(r["now"])
		row.after = str(r["after"])
		row.after_full = str(r["after_full"])
		row.native = str(r["native"])
		row.native_full = str(r["native_full"])
		row.gem = nxt
		row.lw = lw
		row.cw = cw
		row.custom_minimum_size = Vector2(w, 56)
		v.add_child(row)
	v.add_child(UIKit.gap(6))
	var leg := UIKit.label(HeroesText.t("RECUT_AT_FULL"), 22, UITokens.INK_DIM_GLASS)
	v.add_child(leg)
	v.add_child(UIKit.gap(4))
	return p


## The top-gem state (§9.3): the stone's status instead of an empty screen.
func _top_status(inner: float) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var gem := str(_d["gem"])
	var nat := str(_d["native"])
	var hero := str(_d.get("kind", "hero")) == "hero"
	var top_key := "RECUT_TOP_NATIVE" if nat == gem else "RECUT_TOP_RECUT"
	var top_arg := HeroesText.gem_name(gem) if nat == gem else HeroesText.gem_name(nat, "GEN")
	v.add_child(UIKit.label(HeroesText.t(top_key, [top_arg]), 26, UITokens.INK, true))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	r.add_child(HeroFacetPips.make(gem, int(_d["facets"]), 24.0))
	var fm := int(_d.get("facets_max", Ladder.FACETS_PER_GEM))
	var ft := HeroesText.t("FACET_COUNT", [int(_d["facets"]), fm])
	if bool(_d.get("full", false)):
		ft += " · " + HeroesText.t("RECUT_TOP_FULL")
	r.add_child(UIKit.label(ft, 24, UITokens.INK, true))
	v.add_child(r)
	if hero:
		var awk: Dictionary = (_d["skills"] as Dictionary).get("awakened", {})
		if bool(awk.get("open", false)) or bool(awk.get("born", false)):
			v.add_child(UIKit.label(HeroesText.t("RECUT_TOP_AWAKEN", [int(awk.get("rank", 0)), int(awk.get("cap", 0))]), 24, UITokens.INK))
	v.add_child(UIKit.hairline())
	var l := UIKit.label(HeroesText.t("RECUT_AT_MAX"), 22, UITokens.INK_DIM_GLASS)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(inner - 48.0, 0)
	v.add_child(l)
	if not hero:
		v.add_child(UIKit.label(HeroesText.t("RECUT_OPAL_HEROES"), 22, UITokens.INK_DIM_GLASS))
	return p


func _cell(text: String, w: float, fs: int, col: Color, bold: bool, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UIKit.label(text, fs, col, bold)
	l.custom_minimum_size = Vector2(w, 40)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The native-ceiling bar: a native's Full facets in the next gem = 100 %; the recut's ceiling
## tick (≤ 96 %, Ladder.CEILING); never collapsed.
func _ceiling(inner: float) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.section(HeroesText.t("RECUT_CEILING_TITLE")))
	var bar := _CeilingBar.new()
	bar.gem = str(_p["next"])
	bar.bar = _p["bar"]
	bar.custom_minimum_size = Vector2(inner - 48.0, 84)
	v.add_child(bar)
	var l := UIKit.label(HeroesText.t("RECUT_CEILING_LINE", [HeroesText.gem_name(str(_p["next"])), HeroesText.pct(float(_p["ceiling"]), 1)]), 22, UITokens.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(inner - 48.0, 0)
	v.add_child(l)
	# The honest lines (rule #3 in words), under the bar they explain.
	var w := inner - 48.0
	var nxt := str(_p["next"])
	var honest := UIKit.label(HeroesText.t("RECUT_HONEST", [HeroesText.gem_name(nxt), HeroesText.gem_name(nxt)]), 22, UITokens.INK)
	honest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	honest.custom_minimum_size = Vector2(w, 0)
	v.add_child(honest)
	var eq := UIKit.label(HeroesText.t("RECUT_EQUAL", [HeroesText.gem_name(nxt), HeroesText.pct(float(_p["equal_gap"]), 1)]), 22, UITokens.INK_DIM_GLASS)
	eq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eq.custom_minimum_size = Vector2(w, 0)
	v.add_child(eq)
	if bool(_p["first_recut"]):
		var ex := UIKit.label(HeroesText.t("RECUT_NATIVE_EXPLAIN"), 22, UITokens.INK_DIM_GLASS)
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ex.custom_minimum_size = Vector2(w, 0)
		v.add_child(ex)
	return p


func _cost(inner: float) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UIKit.section(HeroesText.t("RECUT_COST_TITLE")))
	v.add_child(head)
	if int(_p["need_facets"]) > 0:
		var pip := HeroFacetPips.make(str(_d["gem"]), int(_d["facets"]), 24.0)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		r.add_child(pip)
		r.add_child(UIKit.label(HeroesText.t("FACET_COUNT", [int(_d["facets"]), int(_p["facets_max"])]), 24, UITokens.INK, true))
		v.add_child(r)
	var have := int(_p["have"])
	var cost := int(_p["cost"])
	var bar := HeroEngravedBar.make(str(_d["gem"]), minf(have, cost), cost, inner - 48.0)
	bar.label = HeroesText.t("CUR_FRAGS")
	bar.value_text = "%s / %s" % [HeroesText.num(have), HeroesText.num(cost)]
	bar.label_size = 24
	v.add_child(bar)
	v.add_child(UIKit.label(HeroesText.t("RECUT_COST_ONLY"), 22, UITokens.INK_DIM_GLASS))
	if int(_p["short"]) > 0:
		var src := UIKit.label(HeroesText.t("MANAGE_FACET_SOURCES"), 22, UITokens.INK_DIM_GLASS)
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src.custom_minimum_size = Vector2(inner - 48.0, 0)
		v.add_child(src)
	return p


func _sync_cta() -> void:
	if _cta == null:
		return
	var k := _cta as KitCTA
	var st := str(_p["state"])
	var arrow := HeroesText.gem_name(str(_d["gem"])) + " → " + HeroesText.gem_name(str(_p["next"]))
	match st:
		"ready":
			_cta.disabled = false
			_cta.text = HeroesText.t("RECUT_CONFIRM") if _armed else HeroesText.t("RECUT_CTA")
			k.sub = HeroesText.t("RECUT_CONFIRM_SUB") if _armed else arrow
		"facets":
			_cta.disabled = true
			_cta.text = HeroesText.t("RECUT_CTA")
			k.sub = HeroesText.t("RECUT_NEED_FACETS", [HeroesText.count(int(_p["need_facets"]), "facet")])
		"frags":
			_cta.disabled = true
			_cta.text = HeroesText.t("RECUT_CTA")
			k.sub = HeroesText.t("RECUT_SHORT", [HeroesText.count(int(_p["short"]), "frag")])
		_:
			_cta.disabled = true
			_cta.text = HeroesText.t("RECUT_CTA")
			k.sub = ""


# ------------------------------------------------------------------ layout

func _layout() -> void:
	if _header == null:
		return
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	var H := size.y if size.y > 1.0 else get_viewport_rect().size.y
	var y0 := _ins.y + 22.0
	_header.position = Vector2(UITokens.GUTTER, y0)
	_header.size = Vector2(W - UITokens.GUTTER * 2.0, 88)
	var dock_y := H - _ins.w - 22.0 - 88.0
	_dock.position = Vector2(UITokens.GUTTER, dock_y)
	_dock.size = Vector2(W - UITokens.GUTTER * 2.0, 88)
	var top := y0 + 100.0
	_scroll.position = Vector2(UITokens.GUTTER, top)
	_scroll.size = Vector2(W - UITokens.GUTTER * 2.0, dock_y - 14.0 - top)
	_body.custom_minimum_size = Vector2(W - UITokens.GUTTER * 2.0, 0)


# ------------------------------------------------------------------ actions

func _on_cta() -> void:
	if str(_p["state"]) != "ready" or _cer:
		return
	if not _armed:
		_armed = true
		_arm_id += 1
		var my := _arm_id
		UIJuice.haptic("CLICK", 0.5)
		_sync_cta()
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(self) and _arm_id == my and _armed and _cer == null:
				_armed = false
				_sync_cta())
		return
	_run_ceremony()


## Second tap: the grant FIRST (HeroesUIModel.recut), then the ceremony over the screen.
func _run_ceremony() -> void:
	if _cer:
		return
	var old := str(_d["gem"])
	var nxt := str(_p["next"])
	var nat := str(_d["native"])
	if nxt == "" or not HeroesUIModel.recut(char_id):
		_armed = false
		_sync_cta()
		return
	_armed = false
	_cer = HeroesRecutCeremony.make(char_id, old, nxt, nat)
	_cer.finished.connect(_after_ceremony)
	add_child(_cer)
	# Once the ceremony's own sky covers the screen (its 0.22 s fade-in), stop this screen's
	# backdrop: no second full-screen sky redrawing underneath.
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(_bg):
			_bg.visible = false
			_bg.process_mode = Node.PROCESS_MODE_DISABLED)


func _after_ceremony() -> void:
	closed.emit()


## Dev shots: run (or keep) the ceremony at `t` seconds; t <= 0 leaves the screen as is.
func gallery_seek(t: float) -> void:
	if _cer and t > 0.0:
		_cer.seek(t)


func _open_codex() -> void:
	if _sheet and is_instance_valid(_sheet):
		return
	var c := HeroesCodexSheet.make(hub, true)
	_sheet = c
	add_child(c)
	c.closed.connect(func():
		c.queue_free()
		_sheet = null)


func _back() -> void:
	Audio.play("click", -8.0)
	if UITokens.reduce_motion():
		closed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_callback(func(): closed.emit())


# ------------------------------------------------------------------ drawn parts

## Current Living Gem → next doublet, joined by an engraved arrow.
class _Stones extends Control:
	var gem := "C"
	var native := "C"
	var next := "R"
	var facets := 5
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not UITokens.reduce_motion())

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		# A compact band (§9.3 after the critic pass): the current stone (92 px) → the next
		# doublet (128 px), the arrow inline between them, the new gem's name beside it.
		var W := size.x
		var glow := UIKit.glow_texture()
		if next == "":
			var c0 := Vector2(W * 0.5, size.y * 0.46)
			var sp := minf(176.0, size.y * 0.72)
			draw_texture_rect(glow, Rect2(c0 - Vector2(sp, sp), Vector2(sp, sp) * 2.0), false, Color(1, 1, 1, 0.7))
			HeroGemEmblem.draw_emblem(self, gem, native if native != gem else "", c0, sp, true, _t)
			HeroGemEmblem.draw_facets(self, gem, c0, sp, facets, _t)
			return
		var cy := size.y * 0.42
		var a := Vector2(W * 0.2, cy)
		var b := Vector2(W * 0.58, cy)
		draw_texture_rect(glow, Rect2(b - Vector2(130, 130), Vector2(260, 260)), false, Color(1, 1, 1, 0.75))
		var old_nat := native if native != gem else ""
		HeroGemEmblem.draw_emblem(self, gem, old_nat, a, 92.0, true, _t)
		HeroGemEmblem.draw_facets(self, gem, a, 92.0, facets, _t)
		HeroGemEmblem.draw_emblem(self, next, native, b, 128.0, true, _t)
		# Engraved arrow with a keystone.
		var p0 := a + Vector2(64, 0)
		var p1 := b - Vector2(86, 0)
		var hl := UITokens.HAIRLINE
		draw_line(p0, p1, hl, 2.0, true)
		draw_line(p1, p1 + Vector2(-12, -9), hl, 2.0, true)
		draw_line(p1, p1 + Vector2(-12, 9), hl, 2.0, true)
		GemDraw.draw_keystone(self, (p0 + p1) * 0.5, 16.0)
		var f := UIKit.font(true)
		# Under the old stone (lower when it carries a native bezel); the new name clears the
		# new stone's widest cut (the opal eye is wider than it is tall).
		draw_string(f, Vector2(a.x - 100, cy + (90.0 if old_nat != "" else 76.0)), HeroesText.gem_name(gem), HORIZONTAL_ALIGNMENT_CENTER, 200, 22, UITokens.INK)
		var wide := 1.4 if str(UITokens.gem(next)["cut"]) == "eye" else 1.0
		var nx := b.x + 84.0 * wide
		draw_string(f, Vector2(nx, cy - 4.0), HeroesText.gem_name(next), HORIZONTAL_ALIGNMENT_LEFT, W - nx, 30, UITokens.INK)
		var fm := UIKit.font(false)
		draw_string(fm, Vector2(nx, cy + 26.0), HeroesText.t("RECUT_STONE_NATIVE", [HeroesText.gem_name(native)]), HORIZONTAL_ALIGNMENT_LEFT, W - nx, 22, UITokens.GOLD_TEXT_GLASS)


## The five-gem path: each cut 30 px with its name; native = «корінний», current = a ring
## «зараз», next = lit «далі», beyond the kind's max = engraved outline only.
class _Path extends Control:
	var native := "C"
	var gem := "C"
	var next := "R"
	var max_gem := "M"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var W := size.x
		var n := Ladder.GEMS.size()
		var step := W / n
		var y := 24.0
		var hl := UITokens.HAIRLINE
		HeroV3.rule(self, step * 0.5 - 20.0, W - step * 0.5 + 20.0, y, hl, 0.7)
		var f := UIKit.font(false)
		var fb := UIKit.font(true)
		var ni := Ladder.gem_index(native)
		var gi := Ladder.gem_index(gem)
		var xi := Ladder.gem_index(next) if next != "" else -1
		var mi := Ladder.gem_index(max_gem)
		for i in n:
			var g := Ladder.GEMS[i]
			var c := Vector2(step * (i + 0.5), y)
			var beyond := i > mi
			var alpha := 0.35 if (beyond or i < ni) else 1.0
			if i == gi:
				HeroV3.disc(self, c, 22.0, 0.94, HeroV3.DEEP, 0.9)
			if i == xi:
				draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(40, 40), Vector2(80, 80)), false, Color(1, 0.93, 0.7, 0.9))
			if beyond:
				HeroV3.frame(self, GemDraw.cut_points(str(UITokens.gem(g)["cut"]), c, 24.0), Color(hl.r, hl.g, hl.b, 0.8))
			else:
				GemDraw.draw_mark(self, g, c, 20.0, alpha)
			var name := HeroesText.gem_name(g)
			draw_string(fb if i == xi or i == gi else f, Vector2(c.x - step * 0.5, y + 46.0), name, HORIZONTAL_ALIGNMENT_CENTER, step, 22,
					Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 1.0 if alpha > 0.5 else 0.55))
			var tag := ""
			var tcol := UITokens.INK_DIM_GLASS
			if i == ni:
				tag = HeroesText.t("RECUT_PATH_NATIVE")
				tcol = UITokens.GOLD_TEXT_GLASS
			if i == gi and i != ni:
				tag = HeroesText.t("RECUT_PATH_NOW")
			if i == xi:
				tag = HeroesText.t("RECUT_PATH_NEXT")
				tcol = UITokens.GOLD_TEXT_GLASS
			if tag != "":
				draw_string(fb, Vector2(c.x - step * 0.5 - 6.0, y + 68.0), tag, HORIZONTAL_ALIGNMENT_CENTER, step + 12.0, 20, tcol)
			if i == gi and i == ni:
				draw_string(fb, Vector2(c.x - step * 0.5 - 6.0, y + 88.0), HeroesText.t("RECUT_PATH_NOW"), HORIZONTAL_ALIGNMENT_CENTER, step + 12.0, 20, UITokens.INK_DIM_GLASS)


## One honesty-table row: label · now · after (→ at Full facets) · native (→ at Full facets).
class _TableRow extends Control:
	var label := ""
	var now := ""
	var after := ""
	var after_full := ""
	var native := ""
	var native_full := ""
	var gem := "R"
	var lw := 168.0
	var cw := 160.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var hl := UITokens.HAIRLINE
		# The native column sits on a faint wash of the next gem (the ceiling it names).
		var rim: Color = UITokens.gem(gem)["light"]
		draw_rect(Rect2(Vector2(lw + cw * 2.0 + 4.0, 0), Vector2(cw - 4.0, h)), Color(rim.r, rim.g, rim.b, 0.35))
		draw_rect(Rect2(Vector2(lw + cw + 2.0, 0), Vector2(cw - 4.0, h)), Color(HeroV3.GOLD.r, HeroV3.GOLD.g, HeroV3.GOLD.b, 0.14))
		HeroV3.rule(self, 0.0, size.x, h - 0.5, hl, 0.5)
		var f := UIKit.font(false)
		var fb := UIKit.font(true)
		draw_string(f, Vector2(0, h * 0.5 + 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, lw - 8.0, 22, UITokens.INK_DIM_GLASS)
		_cell(lw, now, "", fb, f)
		_cell(lw + cw, after, after_full, fb, f)
		_cell(lw + cw * 2.0, native, native_full, fb, f)

	func _cell(x: float, main: String, full: String, fb: Font, f: Font) -> void:
		var h := size.y
		var fs := 24
		while fs > 20 and fb.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > cw - 10.0:
			fs -= 1
		if full == "":
			if fb.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > cw - 10.0 and " · " in main:
				# Two lines («ранг 4» / «від народження») instead of clipping.
				var parts := main.split(" · ", false, 1)
				draw_string(fb, Vector2(x, h * 0.5 - 3.0), parts[0], HORIZONTAL_ALIGNMENT_CENTER, cw, fs, UITokens.INK)
				draw_string(f, Vector2(x, h * 0.5 + 22.0), parts[1], HORIZONTAL_ALIGNMENT_CENTER, cw, 20, UITokens.INK_DIM_GLASS)
				return
			draw_string(fb, Vector2(x, h * 0.5 + 9.0), main, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, UITokens.INK)
			return
		draw_string(fb, Vector2(x, h * 0.5 - 3.0), main, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, UITokens.INK)
		draw_string(fb, Vector2(x, h * 0.5 + 24.0), "→ " + full, HORIZONTAL_ALIGNMENT_CENTER, cw, 22, UITokens.GOLD_TEXT_GLASS)


## The native-ceiling bar: track = a native's Full facets in the next gem (100 %); fill = where you
## are now; a lighter run to your own ceiling; a gold keystone tick «твоя межа»; «корінний» at the end.
class _CeilingBar extends Control:
	var gem := "R"
	var bar: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if bar.is_empty():
			return
		var W := size.x
		var y := 34.0
		var hch := 14.0
		var x0 := 4.0
		var x1 := W - 4.0
		var track := Rect2(Vector2(x0, y), Vector2(x1 - x0, hch))
		var pts := GemDraw.chamfer_rect(track, 4.0)
		draw_colored_polygon(pts, HeroV3.a(UITokens.PAPER_3, 0.5))
		var fill := HeroEngravedBar.fill_color(gem)
		var xf := lerpf(x0, x1, float(bar["full"]))
		var xn := lerpf(x0, x1, float(bar["now"]))
		draw_colored_polygon(GemDraw.chamfer_rect(Rect2(Vector2(x0, y), Vector2(xf - x0, hch)), 4.0), Color(fill.r, fill.g, fill.b, 0.38))
		draw_colored_polygon(GemDraw.chamfer_rect(Rect2(Vector2(x0, y), Vector2(xn - x0, hch)), 4.0), fill)
		# The gap a recut can never close (hatched).
		var hl := UITokens.HAIRLINE
		var x := xf + 4.0
		while x < x1 - 2.0:
			draw_line(Vector2(x, y + hch - 2.0), Vector2(minf(x + 8.0, x1 - 2.0), y + 2.0), Color(hl.r, hl.g, hl.b, 0.7), UIKit.px(1.0), true)
			x += 7.0
		HeroV3.frame(self, pts, Color(hl.r, hl.g, hl.b, 0.85))
		# Marks (1.5 dpx: nothing heavier, §1.1).
		draw_line(Vector2(xf, y - 6.0), Vector2(xf, y + hch + 8.0), UITokens.GOLD_TEXT_GLASS, UIKit.line_px(1.5), true)
		# The ceiling diamond hangs under the bar (the native label owns the space above it).
		GemDraw.draw_diamond(self, Vector2(xf, y + hch + 12.0), 10.0, UITokens.PAPER_0, HeroV3.DEEP)
		draw_line(Vector2(x1 - 1.0, y - 8.0), Vector2(x1 - 1.0, y + hch + 8.0), UITokens.INK, UIKit.line_px(1.5), true)
		var f := UIKit.font(true)
		var fm := UIKit.font(false)
		var you := HeroesText.t("RECUT_CEILING_YOU") + " " + HeroesText.pct(float(bar["full"]), 1)
		var yw := fm.get_string_size(you, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(maxf(0.0, xf - yw - 16.0), y + hch + 30.0), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.GOLD_TEXT_GLASS)
		var nat := HeroesText.t("RECUT_CEILING_NATIVE") + " " + HeroesText.pct(1.0, 0)
		var nw := f.get_string_size(nat, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(W - nw, y - 14.0), nat, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK)
		var nowt := HeroesText.t("RECUT_COL_NOW") + " " + HeroesText.pct(float(bar["now"]), 1)
		draw_string(fm, Vector2(0, y - 14.0), nowt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK_DIM_GLASS)


## Removes every child at once (queue_free alone leaves them in the layout until the frame ends).
static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
