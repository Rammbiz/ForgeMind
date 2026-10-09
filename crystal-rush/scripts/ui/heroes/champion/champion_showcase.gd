class_name HeroesChampionShowcase
extends Control
## «Вітрина чемпіона / Champion Showcase» (heroes_design.md §4, §9.2, §9.3, §11.3; part U §2.6).
## Route "champion/<id>" (HeroesNav, host "screen"). The Hero Showcase template, lighter:
##   backdrop  the bright painted sky of the champion's gem (HeroShowcaseBackdrop)
##   art       right of the column (HeroesChampionParts.CardArt): the painted 3:4 card in a frame, or,
##             until art exists, the class sigil in relief straight on the gem sky (no empty card)
##   left      gem emblem (a doublet for a recut champion) · the ROLE LINE FIRST («Повертає
##             полеглих», §11.3) · name · title · class / element / faction badges · facets +
##             fragments · the shared Champion Level («спільний для всіх чемпіонів») · formation slot
##   plates    top-aligned, independent heights. ДІЯ: class Action + the twist name, then the tier
##             pips I-IV each in its gem and «Ярус IV — лише для корінних Топазів» / «Ярус IV —
##             найвищий: корінний Топаз» (rule #3, above the fold), the live main number, the rule
##             text last · АУРА: class hook, the live effect at the slot share, «діє на солдатів у
##             колі», «Місце в строю» with a mini formation map
##   relic     the relic socket (Workshop; locked before it opens)
##   run       «У забігу»: the run diagram (HeroesChampionParts.RunDemo) until the 3D demo exists
##   dock      ‹ · «До команди» · «Огранити» (amber, only when a recut is ready)
## Numbers: HeroesChampionNumbers (ChampionData × Ladder × Champion Level), never hand-typed.

signal closed

var hub: Hub
var champ_id := "mila"
var _ins := Vector4.ZERO
var _c: Dictionary = {}
var _dirty := false

var _frost: HeroFrost
var _bg: HeroShowcaseBackdrop
var _art: HeroesChampionParts.CardArt
var _scroll: ScrollContainer
var _body: VBoxContainer
var _left: VBoxContainer
var _dock: HBoxContainer
var _codex: Control
var _sheet: Control

const COL_W := 352.0
## Clear space kept between the column's text and the art.
const COL_PAD := 16.0


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0 and ChampionData.CHAMPIONS.has(str(args[0])):
		champ_id = str(args[0])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ins = hub.insets() if hub else Vector4.ZERO
	_c = HeroesUIModel.champion(champ_id)
	_bg = HeroShowcaseBackdrop.make(str(_c["gem"]), str(_c["element"]))
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.focus = Vector2(0.72, 0.24)
	add_child(_bg)
	# UI v3.1: the plates frost this screen's own sky (HeroFrost), body text on the 94 % bed.
	_frost = HeroFrost.attach(self)
	_bg.baked.connect(func(): _frost.set_layers([{"tex": _bg.baked_texture(), "rect": Rect2(Vector2.ZERO, size)}]))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)
	UIKit.scroll_fade(_scroll, UITokens.PAPER_1)
	_dock = HBoxContainer.new()
	_dock.add_theme_constant_override("separation", 12)
	add_child(_dock)
	var cx := UIKit.edge_button("help", 34.0)
	cx.pressed.connect(_open_codex)
	add_child(cx)
	_codex = cx
	_build()
	resized.connect(_layout)
	_layout()
	HeroesUIModel.bus().changed.connect(_on_model)
	if not UITokens.reduce_motion():
		UIJuice.fade_in(_art.get_parent() as Control, 0.06, 0.36)
		var i := 0
		for c in _left.get_children():
			UIJuice.soft_in(c, Vector2(-18, 0), 0.08 + 0.035 * i)
			i += 1
		UIJuice.soft_in(_dock, Vector2(0, 20), 0.2)


func _on_model(_what: String) -> void:
	if _dirty:
		return
	_dirty = true
	(func():
		_dirty = false
		if is_instance_valid(self) and is_inside_tree():
			refresh()).call_deferred()


func refresh() -> void:
	_c = HeroesUIModel.champion(champ_id)
	_build()
	_layout()


# ------------------------------------------------------------------ build

func _build() -> void:
	_clear(_body)
	_clear(_dock)
	var owned := bool(_c["owned"])
	var gem := str(_c["gem"])
	var team := HeroesUIModel.team()
	var slot := str(_c["slot"])
	for s: Dictionary in HeroesTeamLogic.slot_layout(team):
		if str(s["id"]) == champ_id:
			slot = str(s["slot"])
	var nums := HeroesChampionNumbers.of(_c, slot)
	var inner := _inner_w()
	# Top: the left column + the 3:4 card.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 0)
	_body.add_child(top)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_left.custom_minimum_size = Vector2(COL_W, 0)
	top.add_child(_left)
	var em := HeroGemEmblem.make(gem, 132, str(_c["native"]) if bool(_c["is_recut"]) else "")
	em.live = true
	em.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(em)
	_left.add_child(_role_line(str(_c["role"])))
	var nm := UIKit.heading(str(_c["name"]), 62, UITokens.INK)
	_left.add_child(nm)
	_left.add_child(UIKit.label(str(_c["title"]), 26, UITokens.GOLD_TEXT_GLASS, true))
	if bool(_c["is_recut"]):
		_left.add_child(UIKit.label(HeroesText.t("RECUT_FROM", [HeroesText.gem_name(str(_c["native"]), "GEN")]), 22, UITokens.INK_DIM_GLASS))
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 8)
	badges.add_child(UIKit.socket("cls_" + str(_c["class"]), 52))
	badges.add_child(UIKit.socket("el_" + str(_c["element"]), 52, true))
	badges.add_child(UIKit.socket("fac_" + str(_c["faction"]), 52))
	_left.add_child(UIKit.gap(4))
	_left.add_child(badges)
	var tags := UIKit.label(HeroesText.t("SHOW_TAGS", [HeroesText.class_label(str(_c["class"])), HeroesText.element_label(str(_c["element"]))]) + " · " + HeroesText.faction_label(str(_c["faction"])), 22, UITokens.INK)
	tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags.custom_minimum_size = Vector2(COL_W - COL_PAD, 0)
	_left.add_child(tags)
	if owned:
		_left.add_child(UIKit.gap(6))
		_left.add_child(_facets_row())
		var cl := HeroesUIModel.champion_level()
		var lvl_key := "CHAMP_UI_LEVEL_CAP" if int(cl["level"]) >= int(cl["cap"]) and int(cl["cap"]) < int(cl["max"]) else "CHAMP_UI_SHARED_LEVEL"
		var lvl_args := [int(cl["level"]), int(cl["cap"]), int(cl["next_world"])] if lvl_key == "CHAMP_UI_LEVEL_CAP" else [int(cl["level"]), int(cl["cap"])]
		var lv := UIKit.label(HeroesText.t(lvl_key, lvl_args), 24, UITokens.INK, true)
		lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv.custom_minimum_size = Vector2(COL_W - COL_PAD, 0)
		_left.add_child(lv)
		_left.add_child(UIKit.label(HeroesText.t("CHAMP_UI_SHARED"), 22, UITokens.INK_DIM_GLASS))
		if bool(_c["in_team"]):
			var it := UIKit.label(HeroesText.t("SHOW_IN_TEAM") + " · " + HeroesTeamLogic.slot_label(StringName(slot)), 22, UITokens.PLUS, true)
			_left.add_child(it)
	else:
		_left.add_child(UIKit.gap(6))
		_left.add_child(UIKit.label(HeroesText.t("SHOW_NOT_OWNED"), 24, UITokens.INK, true))
		_left.add_child(UIKit.label(HeroesText.t("SHOW_FROM_CHEST"), 22, UITokens.INK_DIM_GLASS))
	var art_holder := Control.new()
	art_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(art_holder)
	_art = HeroesChampionParts.CardArt.new()
	_art.id = champ_id
	_art.gem = gem
	_art.cls = str(_c["class"])
	_art.dim = not owned
	art_holder.add_child(_art)
	art_holder.set_meta("art", true)
	if bool(_c["is_new"]) and owned:
		var seal := HeroWaxSeal.make(76)
		art_holder.add_child(seal)
		art_holder.set_meta("seal", seal)
	# Plates.
	var plates := HBoxContainer.new()
	plates.add_theme_constant_override("separation", 14)
	var pw := (inner - 14.0) / 2.0
	var ap := _action_plate(nums, pw)
	var up := _aura_plate(nums, pw)
	for pl: Control in [ap, up]:
		pl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		plates.add_child(pl)
	_body.add_child(plates)
	_body.add_child(_run_panel(inner, slot))
	_body.add_child(_relic_row(inner))
	_body.add_child(UIKit.gap(6))
	# Dock.
	var back := UIKit.edge_button("back", 38.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	_dock.add_child(back)
	var to_team := UIKit.secondary_button(HeroesText.t("CHAMP_UI_TO_TEAM"), "team", Vector2(0, 88), 26)
	to_team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_team.disabled = not bool(HeroesUIModel.unlocks()["champions"])
	to_team.pressed.connect(func(): HeroesNav.open(hub, "team"))
	_dock.add_child(to_team)
	var rp := HeroesRecutPreview.of(_c)
	if str(rp["state"]) == "ready":
		var rc := UIKit.cta_button(HeroesText.t("RECUT_CTA"), HeroesText.t("RECUT_TO", [HeroesText.gem_name(str(rp["next"]))]), Vector2(0, 88), 30)
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rc.pressed.connect(func(): HeroesNav.open(hub, "recut/" + champ_id))
		_dock.add_child(rc)


## A frosted glass panel over this screen (text on the 94 % bed), or the flat text glass.
func _glass_panel() -> PanelContainer:
	var p := PanelContainer.new()
	# The kit card's pad (16, 14): the plates size their text columns to it (w - 36).
	if not HeroFrost.frost_panel(p, "panel", Vector2(16, 14), _frost):
		p.add_theme_stylebox_override("panel", UIKit.lux("banner", Vector2(16, 14)))
	return p


func _inner_w() -> float:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	return W - UITokens.GUTTER * 2.0


## The role line, first and prominent (§11.3): a cream cartouche with a gold rule.
func _role_line(text: String) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_theme_stylebox_override("panel", UIKit.lux("banner", Vector2(14, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := Icons.make("cls_" + str(_c["class"]), 26.0, UITokens.GOLD_TEXT_GLASS)
	ic.custom_minimum_size = Vector2(26, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(UIKit.label(text, UIKit.fit_size(text, COL_W - COL_PAD - 70.0, 26, 22), UITokens.INK, true))
	p.add_child(h)
	return p


func _facets_row() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(HeroFacetPips.make(str(_c["gem"]), int(_c["facets"]), 22.0))
	var need := int(_c["frags_need"])
	var txt := HeroesText.t("FACET_COUNT", [int(_c["facets"]), Ladder.FACETS_PER_GEM])
	h.add_child(UIKit.label(txt, 24, UITokens.INK, true))
	v.add_child(h)
	if need > 0:
		var bar := HeroEngravedBar.make(str(_c["gem"]), minf(int(_c["frags"]), need), need, COL_W - COL_PAD - 8.0)
		bar.value_text = HeroesText.t("FACET_FRAGS", [int(_c["frags"]), need])
		bar.label = HeroesText.t("CUR_FRAGS")
		v.add_child(bar)
	return v


func _plate_shell(title: String, w: float) -> Array:
	var p := _glass_panel()
	p.custom_minimum_size = Vector2(w, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UIKit.section(title))
	return [p, v]


func _action_plate(n: Dictionary, w: float) -> Control:
	var cls := str(_c["class"])
	var sh := _plate_shell(HeroesText.t("CHAMP_UI_ACTION") + " · " + HeroesText.t("ACT_" + cls.to_upper()), w)
	var v: VBoxContainer = sh[1]
	var tw := w - 36.0
	v.add_child(_wrap(HeroesText.t("ACT_" + champ_id.to_upper()), 26, UITokens.INK, true, tw))
	# Tier first (rule #3 visible on first view), then the live number, then the rule text.
	var tier := int(n["tier"])
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	var pips := HeroesChampionParts.TierPips.new()
	pips.tier = tier
	tr.add_child(pips)
	var tl := UIKit.label(HeroesText.t("CHAMP_UI_TIER", [HeroesText.roman(tier)]), 24, UITokens.INK, true)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(tl)
	v.add_child(tr)
	var note := ""
	var top := Ladder.gem_index(Ladder.CHAMPION_MAX_GEM) + 1
	if tier >= top:
		note = HeroesText.t("CHAMP_UI_TIER_HAVE", [HeroesText.roman(top), HeroesText.gem_name(Ladder.CHAMPION_MAX_GEM)])
	else:
		note = HeroesText.t("CHAMP_UI_TIER_NATIVE", [HeroesText.roman(top), HeroesText.gem_name(Ladder.CHAMPION_MAX_GEM, "PL")])
	v.add_child(_wrap(note, 22, UITokens.GOLD_TEXT_GLASS, true, tw))
	if bool(_c["is_recut"]):
		v.add_child(_wrap(HeroesText.t("CHAMP_UI_TIER_KEPT", [HeroesText.roman(tier)]), 22, UITokens.INK_DIM_GLASS, false, tw))
	v.add_child(UIKit.hairline())
	v.add_child(_wrap(str(n["action_text"]), 22, UITokens.INK, true, tw))
	v.add_child(_wrap(HeroesText.t("ACT_" + champ_id.to_upper() + "_DESC"), 22, UITokens.INK_DIM_GLASS, false, tw))
	return sh[0]


func _aura_plate(n: Dictionary, w: float) -> Control:
	var cls := str(_c["class"])
	var sh := _plate_shell(HeroesText.t("CHAMP_UI_AURA"), w)
	var v: VBoxContainer = sh[1]
	var tw := w - 36.0
	v.add_child(_wrap(HeroesText.t("AURA_" + cls.to_upper()), 26, UITokens.INK, true, tw))
	var val := UIKit.number(str(n["aura_text"]).split(" ")[0], 44)
	v.add_child(val)
	v.add_child(_wrap(HeroesText.t("CHAMP_UI_AURA_NOTE"), 22, UITokens.INK_DIM_GLASS, false, tw))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 10)
	var map := HeroesChampionParts.SlotMap.new()
	map.slot = str(n["slot"])
	map.gem = str(_c["gem"])
	map.custom_minimum_size = Vector2(110, 76)
	sr.add_child(map)
	var sl := _wrap(HeroesText.t("CHAMP_UI_SLOT", [HeroesTeamLogic.slot_label(StringName(str(n["slot"])))]), 22, UITokens.INK, false, tw - 120.0)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sr.add_child(sl)
	v.add_child(sr)
	return sh[0]


func _wrap(text: String, fs: int, col: Color, bold: bool, w: float) -> Label:
	var l := UIKit.label(text, fs, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _relic_row(inner: float) -> Control:
	var p := _glass_panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var open := bool(HeroesUIModel.unlocks()["workshop"])
	var sock := HeroesChampionParts.RelicSocket.new()
	sock.custom_minimum_size = Vector2(72, 72)
	sock.modulate.a = 1.0 if open else 0.5
	sock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sock)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.caps(HeroesText.t("SKL_RELIC"), 20, UITokens.INK_DIM_GLASS))
	v.add_child(UIKit.label(HeroesText.t("RELIC_" + champ_id.to_upper()), 26, UITokens.INK, true))
	var line := HeroesText.t("CHAMP_UI_RELIC_RANK", [0]) if open else HeroesText.t("CHAMP_UI_RELIC_LOCKED", [int(HeroData.UNLOCK_AT["workshop"])])
	# The line's width leaves room for the pad (2 x 16), the socket (72 + 16) and, when locked, the
	# lock (16 + 30): it was inner - 140 and pushed the locked row 26 px past the screen.
	v.add_child(_wrap(line, 22, UITokens.INK_DIM_GLASS, false, inner - 124.0 - (0.0 if open else 46.0)))
	h.add_child(v)
	if not open:
		var lk := Icons.make("lock", 30.0, UITokens.INK_DIM_GLASS)
		lk.custom_minimum_size = Vector2(30, 30)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lk)
	return p


func _run_panel(inner: float, slot: String) -> Control:
	var p := _glass_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UIKit.section(HeroesText.t("CHAMP_UI_RUN")))
	v.add_child(head)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var demo := HeroesChampionParts.RunDemo.new()
	demo.cls = str(_c["class"])
	demo.gem = str(_c["gem"])
	demo.slot = slot
	demo.custom_minimum_size = Vector2(300, 170)
	h.add_child(demo)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(_wrap(str(_c["role"]), 24, UITokens.INK, true, inner - 360.0))
	t.add_child(_wrap(HeroesText.t("CHAMP_UI_RUN_SOON"), 22, UITokens.INK_DIM_GLASS, false, inner - 360.0))
	h.add_child(t)
	return p


# ------------------------------------------------------------------ layout

func _layout() -> void:
	if _dock == null:
		return
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	var H := size.y if size.y > 1.0 else get_viewport_rect().size.y
	var y0 := _ins.y + 22.0
	var dock_y := H - _ins.w - 22.0 - 88.0
	_dock.position = Vector2(UITokens.GUTTER, dock_y)
	_dock.size = Vector2(W - UITokens.GUTTER * 2.0, 88)
	_scroll.position = Vector2(UITokens.GUTTER, y0)
	_scroll.size = Vector2(W - UITokens.GUTTER * 2.0, dock_y - 12.0 - y0)
	_body.custom_minimum_size = Vector2(W - UITokens.GUTTER * 2.0, 0)
	_codex.position = Vector2(W - UITokens.GUTTER - 76.0, y0)
	(func(): _place_art()).call_deferred()


## The card fills the right of the top row (3:4), under the «?».
func _place_art() -> void:
	if _art == null or not is_instance_valid(_art):
		return
	var holder := _art.get_parent() as Control
	var W := holder.size.x
	if not _art.has_art():
		# The relief sigil fills the space right of the column (no card): from under the «?» to
		# about the column's facets row.
		var col_h := _left.get_combined_minimum_size().y if is_instance_valid(_left) else 0.0
		var rh := clampf(maxf(W * 1.3, col_h - 80.0), 260.0, 640.0)
		_art.size = Vector2(W, rh)
		_art.position = Vector2(0, 70.0)
		holder.custom_minimum_size = Vector2(0, rh + 70.0)
	else:
		var cw := minf(W - COL_PAD * 0.5, 330.0)
		var ch := cw * 4.0 / 3.0
		_art.size = Vector2(cw, ch)
		_art.position = Vector2(W - cw, 96.0)
		holder.custom_minimum_size = Vector2(0, ch + 100.0)
	if holder.has_meta("seal"):
		var seal: Control = holder.get_meta("seal")
		# The «НОВИЙ» tag sits inside the card's top-right corner, on its top edge.
		seal.position = Vector2(W - 6.0 - 70.0 - seal.size.x * 0.5, 96.0 - seal.size.y * 0.5)


# ------------------------------------------------------------------ actions

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
	if bool(_c.get("is_new", false)):
		HeroesUIModel.mark_seen(champ_id)
	Audio.play("click", -8.0)
	if UITokens.reduce_motion():
		closed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, UITokens.MENU_OUT)
	tw.tween_callback(func(): closed.emit())


## Removes every child at once (queue_free alone leaves them in the layout until the frame ends).
static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
