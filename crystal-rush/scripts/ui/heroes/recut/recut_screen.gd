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
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
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
	tcol.add_child(UIKit.label(sub, 26, UITokens.GOLD_TEXT, true))
	_header.add_child(tcol)
	var cx := UIKit.edge_button("help", 34.0)
	cx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cx.pressed.connect(_open_codex)
	_header.add_child(cx)
	var inner := _inner_w()
	if bool(_p["at_max"]):
		_body.add_child(_stones())
		_body.add_child(_path())
		var p := UIKit.panel("card")
		var l := UIKit.label(HeroesText.t("RECUT_AT_MAX"), 24, UITokens.INK, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(inner - 48.0, 0)
		p.add_child(l)
		_body.add_child(p)
		if str(_d.get("kind", "")) == "champion":
			_body.add_child(UIKit.label(HeroesText.t("RECUT_OPAL_HEROES"), 22, UITokens.INK_DIM))
	else:
		_body.add_child(_unlocks(inner))
		_body.add_child(_stones())
		_body.add_child(_path())
		_body.add_child(_table(inner))
		_body.add_child(_ceiling(inner))
		_body.add_child(_cost(inner))
	_body.add_child(UIKit.gap(8))
	# Dock.
	var back := UIKit.secondary_button("", "back", Vector2(96, 88))
	back.pressed.connect(_back)
	_dock.add_child(back)
	if not bool(_p["at_max"]):
		_cta = UIKit.cta_button(HeroesText.t("RECUT_CTA"), "", Vector2(0, 88), 32)
		_cta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cta.pressed.connect(_on_cta)
		_dock.add_child(_cta)
		_sync_cta()


func _inner_w() -> float:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	return W - UITokens.GUTTER * 2.0


## «ВІДКРИВАЄ»: the gains of this recut, as engraved cartouches (the lead block, §9.3).
func _unlocks(inner: float) -> Control:
	var p := UIKit.panel("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UIKit.section(HeroesText.t("RECUT_UNLOCKS")))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	flow.custom_minimum_size = Vector2(inner - 48.0, 0)
	v.add_child(flow)
	var first := true
	for u: String in _p["unlocks"]:
		var c := PanelContainer.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := UITokens.CTA_HI if first else UITokens.PAPER_0
		c.add_theme_stylebox_override("panel", UIKit.cbox(fill, int(UITokens.CHAMFER_XS), UITokens.HAIRLINE, 1, Vector2(14, 6)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := Icons.make("arrow_up", 22.0, UIKit.BROWN if first else UITokens.GOLD_TEXT)
		ic.custom_minimum_size = Vector2(22, 22)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(UIKit.label(u, 26, UIKit.BROWN if first else UITokens.INK, true))
		c.add_child(h)
		flow.add_child(c)
		first = false
	var note := UIKit.label(HeroesText.t("RECUT_UNLOCK_NOTE"), 22, UITokens.INK_DIM)
	v.add_child(note)
	return p


## The current stone → the next doublet stone.
func _stones() -> Control:
	var row := _Stones.new()
	row.gem = str(_d["gem"])
	row.native = str(_d["native"])
	row.next = str(_p["next"])
	row.facets = int(_d["facets"])
	row.custom_minimum_size = Vector2(0, 290)
	return row


## The five-gem path: native · now · next · beyond (champions stop at Топаз).
func _path() -> Control:
	var p := _Path.new()
	p.native = str(_d["native"])
	p.gem = str(_d["gem"])
	p.next = str(_p["next"])
	p.max_gem = Ladder.HERO_MAX_GEM if str(_d.get("kind", "hero")) == "hero" else Ladder.CHAMPION_MAX_GEM
	p.custom_minimum_size = Vector2(0, 122)
	return p


func _table(inner: float) -> Control:
	var p := UIKit.panel("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var w := inner - 40.0
	var lw := 168.0
	var cw := (w - lw) / 3.0
	var nxt := str(_p["next"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.add_child(_cell("", lw, 20, UITokens.INK_SOFT, false, HORIZONTAL_ALIGNMENT_LEFT))
	head.add_child(_cell(HeroesText.t("RECUT_COL_NOW"), cw, 20, UITokens.INK_SOFT, true))
	head.add_child(_cell(HeroesText.t("RECUT_COL_AFTER"), cw, 20, UITokens.GOLD_TEXT, true))
	head.add_child(_cell(HeroesText.t("RECUT_COL_NATIVE", [HeroesText.gem_name(nxt)]), cw, 20, UITokens.INK_SOFT, true))
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
		row.custom_minimum_size = Vector2(w, 68)
		v.add_child(row)
	v.add_child(UIKit.gap(6))
	var leg := UIKit.label(HeroesText.t("RECUT_AT_FULL"), 22, UITokens.INK_SOFT)
	v.add_child(leg)
	v.add_child(UIKit.gap(4))
	var honest := UIKit.label(HeroesText.t("RECUT_HONEST", [HeroesText.gem_name(nxt), HeroesText.gem_name(nxt)]), 22, UITokens.INK)
	honest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	honest.custom_minimum_size = Vector2(w, 0)
	v.add_child(honest)
	var eq := UIKit.label(HeroesText.t("RECUT_EQUAL", [HeroesText.gem_name(nxt), HeroesText.pct(float(_p["equal_gap"]), 1)]), 22, UITokens.INK_DIM)
	eq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eq.custom_minimum_size = Vector2(w, 0)
	v.add_child(eq)
	if bool(_p["first_recut"]):
		var ex := UIKit.label(HeroesText.t("RECUT_NATIVE_EXPLAIN"), 22, UITokens.INK_DIM)
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ex.custom_minimum_size = Vector2(w, 0)
		v.add_child(ex)
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
	var p := UIKit.panel("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UIKit.section(HeroesText.t("RECUT_CEILING_TITLE")))
	var bar := _CeilingBar.new()
	bar.gem = str(_p["next"])
	bar.bar = _p["bar"]
	bar.custom_minimum_size = Vector2(inner - 48.0, 96)
	v.add_child(bar)
	var l := UIKit.label(HeroesText.t("RECUT_CEILING_LINE", [HeroesText.gem_name(str(_p["next"])), HeroesText.pct(float(_p["ceiling"]), 1)]), 22, UITokens.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(inner - 48.0, 0)
	v.add_child(l)
	return p


func _cost(inner: float) -> Control:
	var p := UIKit.panel("card")
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
	v.add_child(UIKit.label(HeroesText.t("RECUT_COST_ONLY"), 22, UITokens.INK_DIM))
	if int(_p["short"]) > 0:
		var src := UIKit.label(HeroesText.t("MANAGE_FACET_SOURCES"), 22, UITokens.INK_DIM)
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
		var W := size.x
		var cy := size.y * 0.42
		var a := Vector2(W * 0.24, cy)
		var b := Vector2(W * 0.7, cy)
		var glow := UIKit.glow_texture()
		draw_texture_rect(glow, Rect2(b - Vector2(190, 190), Vector2(380, 380)), false, Color(1, 1, 1, 0.75))
		if next == "":
			HeroGemEmblem.draw_emblem(self, gem, native if native != gem else "", Vector2(W * 0.5, cy), 190.0, true, _t)
			return
		var old_nat := native if native != gem else ""
		HeroGemEmblem.draw_emblem(self, gem, old_nat, a, 128.0, true, _t)
		HeroGemEmblem.draw_facets(self, gem, a, 128.0, facets, _t)
		HeroGemEmblem.draw_emblem(self, next, native, b, 196.0, true, _t)
		# Engraved arrow with a keystone and two marquise terminals.
		var p0 := a + Vector2(92, 0)
		var p1 := b - Vector2(128, 0)
		var hl := UITokens.HAIRLINE
		draw_line(p0, p1, hl, 2.0, true)
		draw_line(p1, p1 + Vector2(-14, -10), hl, 2.0, true)
		draw_line(p1, p1 + Vector2(-14, 10), hl, 2.0, true)
		GemDraw.draw_keystone(self, (p0 + p1) * 0.5, 18.0)
		var f := UIKit.font(true)
		var lbl_a := HeroesText.gem_name(gem)
		var lbl_b := HeroesText.gem_name(next)
		draw_string(f, Vector2(a.x - 100, cy + 104), lbl_a, HORIZONTAL_ALIGNMENT_CENTER, 200, 24, UITokens.INK)
		draw_string(f, Vector2(b.x - 130, cy + 160), lbl_b, HORIZONTAL_ALIGNMENT_CENTER, 260, 28, UITokens.INK)


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
		var y := 34.0
		var hl := UITokens.HAIRLINE
		draw_line(Vector2(step * 0.5, y), Vector2(W - step * 0.5, y), Color(hl.r, hl.g, hl.b, 0.6), 1.5, true)
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
				draw_circle(c, 31.0, UITokens.PAPER_0)
				draw_arc(c, 31.0, 0, TAU, 48, hl, 2.0, true)
			if i == xi:
				draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(48, 48), Vector2(96, 96)), false, Color(1, 0.93, 0.7, 0.9))
			if beyond:
				GemDraw.outline(self, GemDraw.cut_points(str(UITokens.gem(g)["cut"]), c, 30.0), Color(hl.r, hl.g, hl.b, 0.8), 1.2)
			else:
				GemDraw.draw_mark(self, g, c, 24.0, alpha)
			var name := HeroesText.gem_name(g)
			draw_string(fb if i == xi or i == gi else f, Vector2(c.x - step * 0.5, y + 56.0), name, HORIZONTAL_ALIGNMENT_CENTER, step, 22,
					Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 1.0 if alpha > 0.5 else 0.55))
			var tag := ""
			var tcol := UITokens.INK_SOFT
			if i == ni:
				tag = HeroesText.t("RECUT_PATH_NATIVE")
				tcol = UITokens.GOLD_TEXT
			if i == gi and i != ni:
				tag = HeroesText.t("RECUT_PATH_NOW")
			if i == xi:
				tag = HeroesText.t("RECUT_PATH_NEXT")
				tcol = UITokens.CTA_RIM
			if tag != "":
				draw_string(fb, Vector2(c.x - step * 0.5 - 6.0, y + 82.0), tag, HORIZONTAL_ALIGNMENT_CENTER, step + 12.0, 20, tcol)
			if i == gi and i == ni:
				draw_string(fb, Vector2(c.x - step * 0.5 - 6.0, y + 106.0), HeroesText.t("RECUT_PATH_NOW"), HORIZONTAL_ALIGNMENT_CENTER, step + 12.0, 20, UITokens.INK_SOFT)


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
		draw_rect(Rect2(Vector2(lw + cw + 2.0, 0), Vector2(cw - 4.0, h)), Color(UITokens.CTA_HI.r, UITokens.CTA_HI.g, UITokens.CTA_HI.b, 0.28))
		draw_line(Vector2(0, h - 0.5), Vector2(size.x, h - 0.5), Color(hl.r, hl.g, hl.b, 0.45), 1.0)
		var f := UIKit.font(false)
		var fb := UIKit.font(true)
		draw_string(f, Vector2(0, h * 0.5 + 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, lw - 8.0, 22, UITokens.INK_DIM)
		_cell(lw, now, "", fb, f)
		_cell(lw + cw, after, after_full, fb, f)
		_cell(lw + cw * 2.0, native, native_full, fb, f)

	func _cell(x: float, main: String, full: String, fb: Font, f: Font) -> void:
		var h := size.y
		var fs := 24
		while fs > 20 and fb.get_string_size(main, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > cw - 10.0:
			fs -= 1
		if full == "":
			draw_string(fb, Vector2(x, h * 0.5 + 9.0), main, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, UITokens.INK)
			return
		draw_string(fb, Vector2(x, h * 0.5 - 3.0), main, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, UITokens.INK)
		draw_string(fb, Vector2(x, h * 0.5 + 24.0), "→ " + full, HORIZONTAL_ALIGNMENT_CENTER, cw, 22, UITokens.GOLD_TEXT)


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
		var y := 40.0
		var hch := 14.0
		var x0 := 4.0
		var x1 := W - 4.0
		var track := Rect2(Vector2(x0, y), Vector2(x1 - x0, hch))
		var pts := GemDraw.chamfer_rect(track, 4.0)
		draw_colored_polygon(pts, UITokens.PAPER_3)
		draw_line(Vector2(x0 + 4, y + 1), Vector2(x1 - 4, y + 1), Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.18), 1.0)
		var fill := HeroEngravedBar.fill_color(gem)
		var xf := lerpf(x0, x1, float(bar["full"]))
		var xn := lerpf(x0, x1, float(bar["now"]))
		draw_colored_polygon(GemDraw.chamfer_rect(Rect2(Vector2(x0, y), Vector2(xf - x0, hch)), 4.0), Color(fill.r, fill.g, fill.b, 0.38))
		draw_colored_polygon(GemDraw.chamfer_rect(Rect2(Vector2(x0, y), Vector2(xn - x0, hch)), 4.0), fill)
		# The gap a recut can never close (hatched).
		var hl := UITokens.HAIRLINE
		var x := xf + 4.0
		while x < x1 - 2.0:
			draw_line(Vector2(x, y + hch - 2.0), Vector2(minf(x + 8.0, x1 - 2.0), y + 2.0), Color(hl.r, hl.g, hl.b, 0.7), 1.2, true)
			x += 7.0
		GemDraw.outline(self, pts, hl, 1.5)
		# Marks.
		draw_line(Vector2(xf, y - 8.0), Vector2(xf, y + hch + 8.0), UITokens.GOLD_TEXT, 2.0, true)
		GemDraw.draw_keystone(self, Vector2(xf, y - 14.0), 16.0)
		draw_line(Vector2(x1 - 1.0, y - 8.0), Vector2(x1 - 1.0, y + hch + 8.0), UITokens.INK, 2.0, true)
		var f := UIKit.font(true)
		var fm := UIKit.font(false)
		var you := HeroesText.t("RECUT_CEILING_YOU") + " " + HeroesText.pct(float(bar["full"]), 1)
		var yw := fm.get_string_size(you, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(clampf(xf - yw * 0.5, 0.0, W - yw - 120.0), y + hch + 34.0), you, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.GOLD_TEXT)
		var nat := HeroesText.t("RECUT_CEILING_NATIVE") + " " + HeroesText.pct(1.0, 0)
		var nw := f.get_string_size(nat, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2(W - nw, y - 14.0), nat, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK)
		var nowt := HeroesText.t("RECUT_COL_NOW") + " " + HeroesText.pct(float(bar["now"]), 1)
		draw_string(fm, Vector2(0, y - 14.0), nowt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK_DIM)


## Removes every child at once (queue_free alone leaves them in the layout until the frame ends).
static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
