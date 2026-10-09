class_name HeroesHall
extends Control
## «Зала героїв / Hall of Heroes» (heroes_design.md §9.2, §9.3, §11.3; part U §2.1), hosted by
## tab_heroes.gd while HeroesUIModel.enabled(). Reads data only through HeroesUIModel, copy only
## through HeroesText, art only through HeroCard / HeroArt; opens screens through HeroesNav.
##
##   header   title «Зала героїв» + «6 / 10» + the Codex «?» (88 px)
##   plates   Portal plate (L20; frosted two levels before; hidden earlier) and Workshop plate
##            (L32; same rule). The Portal plate never has a badge.
##   sub-tabs Герої · Чемпіони (L14) · Подвиги
##   filters  engraved cartouche chips (Усі · five gem cuts · five classes), once there is
##            something to filter (>= 6 listed heroes)
##   grid     gem-ground cards sorted owned first, then gem (Опал first), then level; unowned
##            cards are dimmed with «Де знайти»; the Champions page adds the shared Champion
##            Level row; Подвиги lists HeroData.FEATS with honest counters.
##
## Hall contract (tab_heroes.gd): setup(hub, args) before it enters the tree, refresh(),
## on_show(), on_hide(), show_sub(id) ("heroes" | "champions" | "feats"), show_hero(id).

const SUBS: Array[String] = ["heroes", "champions", "feats"]

var hub: Hub
var _sub := "heroes"
var _filter := "all"
var _col: VBoxContainer
var _title: Label
var _count: Label
var _codex: Control
var _plates: HBoxContainer
var _seg_host: MarginContainer
var _seg: PanelContainer
var _seg_key := ""
var _chips_sc: ScrollContainer
var _chips_fade: HeroHScrollFade
var _chips: HBoxContainer
var _sc: ScrollContainer
var _pad: MarginContainer
var _page: VBoxContainer
var _cards: Array = []
var _dirty := false
var _stale := false
var _shown_once := false


func setup(p_hub: Hub, args: PackedStringArray) -> void:
	hub = p_hub
	if args.size() > 0 and str(args[0]) in SUBS:
		_sub = str(args[0])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_col = VBoxContainer.new()
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_col.offset_left = UITokens.GUTTER
	_col.offset_right = -UITokens.GUTTER
	_col.add_theme_constant_override("separation", 12)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	# Header: title + count + Codex.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_col.add_child(head)
	_title = UIKit.gradient_heading(HeroesText.t("HALL_TITLE"), 40)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_count = UIKit.label("", 24, UITokens.INK_DIM_GLASS, true)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	head.add_child(UIKit.spacer())
	var cx := UIKit.edge_button("help", 34.0)
	cx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cx.pressed.connect(_open_codex)
	head.add_child(cx)
	_codex = cx
	_plates = HBoxContainer.new()
	_plates.add_theme_constant_override("separation", UITokens.GAP)
	_col.add_child(_plates)
	_seg_host = MarginContainer.new()
	_col.add_child(_seg_host)
	_chips_sc = ScrollContainer.new()
	_chips_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chips_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chips_sc.custom_minimum_size = Vector2(0, UITokens.MIN_TOUCH)
	_col.add_child(_chips_sc)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	_chips_sc.add_child(_chips)
	# The chip row scrolls sideways: the chips themselves dissolve at both ends (an alpha mask,
	# no paint over the glass), which says "more", never a chip cut mid-glyph at the screen edge.
	_chips_fade = HeroHScrollFade.attach(_chips_sc, UITokens.PAPER_1, 72.0)
	_sc = ScrollContainer.new()
	_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_col.add_child(_sc)
	_pad = MarginContainer.new()
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.add_theme_constant_override("margin_top", 6)
	_pad.add_theme_constant_override("margin_bottom", 28)
	_sc.add_child(_pad)
	UIKit.scroll_fade(_sc)
	HeroesUIModel.bus().changed.connect(_on_model)
	refresh()


func _on_model(_what: String) -> void:
	# A screen covers the Hall (Showcase, Portal, a ceremony): rebuild once it is back on top,
	# not on every level_up / facet_up fired from the screen above.
	if HeroesNav.top() != null or not is_visible_in_tree():
		_stale = true
		set_process(true)
		return
	# Coalesce bursts of change signals (a summon emits several) into one rebuild.
	if _dirty:
		return
	_dirty = true
	(func():
		_dirty = false
		if is_instance_valid(self) and is_inside_tree():
			refresh()).call_deferred()


func _process(_d: float) -> void:
	if not _stale:
		set_process(false)
		return
	if HeroesNav.top() == null and is_visible_in_tree():
		_stale = false
		set_process(false)
		refresh()


# ------------------------------------------------------------------ contract

func show_sub(id: String) -> void:
	if not id in SUBS:
		return
	if id == "champions" and not bool(HeroesUIModel.unlocks()["champions"]):
		id = "heroes"
	_sub = id
	_filter = "all"
	refresh()
	_play_cards_in()


func show_hero(id: String) -> void:
	if HeroData.HEROES.has(id):
		HeroesNav.open(hub, "hero/" + id)


func on_show() -> void:
	refresh()
	_play_cards_in()
	if not _shown_once and not UITokens.reduce_motion():
		_shown_once = true
		UIJuice.soft_in(_col.get_child(0), Vector2(0, 16))


func on_hide() -> void:
	pass


func refresh() -> void:
	if _col == null:
		return
	_stale = false
	var un := HeroesUIModel.unlocks()
	if _sub == "champions" and not bool(un["champions"]):
		_sub = "heroes"
	_build_count()
	_build_plates(un)
	_build_seg(un)
	_build_chips()
	_build_page()


# ------------------------------------------------------------------ header

func _build_count() -> void:
	var rows: Array[Dictionary] = HeroesUIModel.champions() if _sub == "champions" else HeroesUIModel.heroes()
	var owned := 0
	for d in rows:
		if bool(d["owned"]):
			owned += 1
	_count.text = HeroesText.t("HALL_COUNT", [owned, rows.size()])
	_count.visible = _sub != "feats"


func _build_plates(un: Dictionary) -> void:
	for ch in _plates.get_children():
		ch.queue_free()
	var cur := HeroesUIModel.currencies()
	var both := bool(un["portal_teaser"]) and bool(un["workshop_teaser"])
	if bool(un["portal_teaser"]):
		var p: HeroesHallPlate
		if bool(un["portal"]):
			var ps := HeroesUIModel.portal_state()
			var sub := HeroesText.t("HALL_PORTAL_WELCOME") if bool(ps["welcome"]) else \
					HeroesText.t("HALL_PORTAL_SUB", [HeroesText.count(int(cur["beacons"]), "beacon"), int(ps["pity_l_left"])])
			if both and not bool(ps["welcome"]):
				# Two plates side by side: the pity goes on its own line.
				sub = HeroesText.count(int(cur["beacons"]), "beacon") + "\n" + HeroesText.t("HALL_PITY_SHORT", [int(ps["pity_l_left"])])
			p = HeroesHallPlate.make("portal", HeroesText.t("HALL_PLATE_PORTAL"), sub)
			p.pressed.connect(func(): HeroesNav.open(hub, "portal"))
		else:
			p = HeroesHallPlate.make("portal", HeroesText.t("HALL_PLATE_PORTAL"),
					HeroesText.t("HALL_PLATE_LOCKED", [HeroesText.t("HALL_TEASER"), int(HeroData.UNLOCK_AT["portal"])]), true)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.compact = both
		_plates.add_child(p)
	if bool(un["workshop_teaser"]):
		var w: HeroesHallPlate
		if bool(un["workshop"]):
			w = HeroesHallPlate.make("workshop", HeroesText.t("HALL_PLATE_WORKSHOP"), HeroesText.count(int(cur["ore"]), "ore") + "\n" + HeroesText.t("HALL_TEASER_NORANDOM"))
			w.pressed.connect(func(): HeroesNav.open(hub, "workshop"))
		else:
			w = HeroesHallPlate.make("workshop", HeroesText.t("HALL_PLATE_WORKSHOP"),
					HeroesText.t("HALL_PLATE_LOCKED", [HeroesText.t("HALL_TEASER"), int(HeroData.UNLOCK_AT["workshop"])]), true)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.compact = both
		_plates.add_child(w)
	_plates.visible = bool(un["portal_teaser"]) or bool(un["workshop_teaser"])


func _build_seg(un: Dictionary) -> void:
	var opts: Array = [["heroes", HeroesText.t("HALL_TAB_HEROES")]]
	if bool(un["champions"]):
		opts.append(["champions", HeroesText.t("HALL_TAB_CHAMPIONS")])
	opts.append(["feats", HeroesText.t("HALL_TAB_FEATS")])
	var key := str(opts.size()) + HeroesText.lang()
	if _seg == null or key != _seg_key:
		if _seg:
			_seg.queue_free()
		_seg = UIKit.segmented(opts, _sub, func(id: String):
			_sub = id
			_filter = "all"
			refresh()
			_play_cards_in())
		_seg_host.add_child(_seg)
		_seg_key = key
	else:
		UIKit.segmented_select(_seg, _sub)


func _build_chips() -> void:
	for ch in _chips.get_children():
		ch.queue_free()
	var listed := 0
	for d: Dictionary in HeroesUIModel.heroes():
		if bool(d["listed"]):
			listed += 1
	var on := _sub == "heroes" and listed >= 6
	_chips_sc.visible = on
	_chips_fade.visible = on
	if not on:
		_filter = "all"
		return
	var all := HeroChip.make(HeroesText.t("HALL_FILTER_ALL"))
	all.active = _filter == "all"
	all.pressed.connect(func(): _set_filter("all"))
	_chips.add_child(all)
	for g: String in ["M", "L", "E", "R", "C"]:
		var c := HeroChip.make("", "", g)
		c.active = _filter == "gem:" + g
		c.tooltip_text = HeroesText.gem_name(g)
		c.pressed.connect(func(): _set_filter("gem:" + g))
		_chips.add_child(c)
	_chips.add_child(_ChipGap.new())
	for cl: String in TeamData.CLASSES:
		var c2 := HeroChip.make("", "cls_" + cl)
		c2.active = _filter == "cls:" + cl
		c2.tooltip_text = HeroesText.class_label(cl)
		c2.pressed.connect(func(): _set_filter("cls:" + cl))
		_chips.add_child(c2)


func _set_filter(f: String) -> void:
	_filter = "all" if f == _filter else f
	Audio.play("click", -10.0)
	_build_chips()
	_build_page()
	_play_cards_in()


# ------------------------------------------------------------------ pages

func _build_page() -> void:
	if _page:
		_pad.remove_child(_page)
		_page.queue_free()
	_cards.clear()
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 16)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pad.add_child(_page)
	match _sub:
		"champions": _build_champions()
		"feats": _build_feats()
		_: _build_heroes()


static func sort_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out := rows.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := bool(a["owned"])
		var ob := bool(b["owned"])
		if oa != ob:
			return oa
		var ga := Ladder.gem_index(str(a["gem"]))
		var gb := Ladder.gem_index(str(b["gem"]))
		if ga != gb:
			return ga > gb
		# Within a gem tier, characters with art (splash, card, live 3D) lead, so the first row
		# of the Hall is never all placeholders.
		var aa := HeroArt.state(str(a["id"])) != "placeholder"
		var ab := HeroArt.state(str(b["id"])) != "placeholder"
		if aa != ab:
			return aa
		var la := int(a.get("eff_level", a.get("level", 0)))
		var lb := int(b.get("eff_level", b.get("level", 0)))
		if la != lb:
			return la > lb
		return int(a["no"]) < int(b["no"]))
	return out


func _pass(d: Dictionary) -> bool:
	if _filter == "all":
		return true
	if _filter.begins_with("gem:"):
		return str(d["gem"]) == _filter.substr(4)
	if _filter.begins_with("cls:"):
		return str(d["class"]) == _filter.substr(4)
	return true


func _build_heroes() -> void:
	var rows: Array[Dictionary] = []
	for d: Dictionary in HeroesUIModel.heroes():
		if bool(d["listed"]) and _pass(d):
			rows.append(d)
	# First weeks (fewer than 6 listed): two columns of large cards, so the art fills the page.
	var few := rows.size() < 6 and _filter == "all"
	_grid(sort_rows(rows), "XL" if few else "L", 2 if few else 3)
	if few:
		# First weeks (§11.4 first visit): one quiet slip, never a blocking coach mark.
		var slip := UIKit.panel("banner", Vector2(22, 16))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 14)
		slip.add_child(r)
		var ic := Icons.make("info", 34.0, UITokens.GOLD_TEXT_GLASS)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(ic)
		var l := UIKit.label(HeroesText.t("TUT_HALL_CARD"), 22, UITokens.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		_page.add_child(slip)


func _build_champions() -> void:
	var owned := 0
	for d: Dictionary in HeroesUIModel.champions():
		if bool(d["owned"]):
			owned += 1
	if owned >= 2:
		_page.add_child(_champion_level_row())
	var hint := UIKit.label(HeroesText.t("HALL_CHAMP_ROLE_HINT"), 22, UITokens.INK_DIM_GLASS)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(hint)
	var owned_rows: Array[Dictionary] = []
	var other: Array[Dictionary] = []
	for d: Dictionary in HeroesUIModel.champions():
		if bool(d["listed"]):
			(owned_rows if bool(d["owned"]) else other).append(d)
	_grid(sort_rows(owned_rows), "M", 4)
	if not other.is_empty():
		# One section header for the unowned group (the lock sits on each card; the Champion
		# Showcase explains the source on tap), not a «Де знайти» on every card.
		_page.add_child(UIKit.section(HeroesText.t("SHOW_NOT_OWNED")))
		_grid(sort_rows(other), "M", 4)


func _grid(rows: Array[Dictionary], kind: String, cols: int) -> void:
	if rows.is_empty():
		var empty := VBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.add_theme_constant_override("separation", 14)
		empty.custom_minimum_size = Vector2(0, 320)
		var l := UIKit.label(HeroesText.t("HALL_FILTER_EMPTY"), 24, UITokens.INK_DIM_GLASS)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(l)
		var b := UIKit.text_button(HeroesText.t("HALL_FILTER_RESET"))
		b.pressed.connect(func(): _set_filter("all"))
		empty.add_child(b)
		_page.add_child(empty)
		return
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", UITokens.GAP)
	g.add_theme_constant_override("v_separation", UITokens.GAP + 6)
	_page.add_child(g)
	var champs := kind == "M"
	var avail := _vp_w() - UITokens.GUTTER * 2.0
	for d in rows:
		var c := HeroCard.make(d, kind)
		if kind == "XL":
			# Scale the large card to the column (2 columns, 3:4.16).
			var cw := floorf((avail - UITokens.GAP) * 0.5)
			c.custom_minimum_size = Vector2(cw, roundf(cw * HeroCard.SIZES["XL"].y / HeroCard.SIZES["XL"].x))
			c.size = c.custom_minimum_size
		c.pressed.connect(_open)
		if not bool(d["owned"]) and not champs:
			var tag := _WhereTag.new()
			tag.text = HeroesText.t("HALL_WHERE")
			c.add_child(tag)
		_cards.append(c)
		if champs:
			# Champions: the name in the card, the role line (or the source) under it at 20 px,
			# never the kit's 14 px footer.
			c.footer_mode = "name"
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			cell.add_child(c)
			var sub := str(d.get("role", "")) if bool(d["owned"]) else HeroesText.t("HALL_SRC_CHEST")
			var rl := UIKit.label(sub, 20, UITokens.INK_DIM_GLASS)
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size = Vector2(c.custom_minimum_size.x, 0)
			rl.max_lines_visible = 2
			cell.add_child(rl)
			g.add_child(cell)
		else:
			g.add_child(c)


func _vp_w() -> float:
	return size.x if size.x > 1.0 else get_viewport_rect().size.x


func _champion_level_row() -> Control:
	var cl := HeroesUIModel.champion_level()
	var lv := int(cl["level"])
	var cap := int(cl["cap"])
	var p := UIKit.panel("banner", Vector2(20, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	var s := UIKit.socket("team", 56)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var at_cap := lv >= cap and cap < int(cl["max"])
	var head := UIKit.label(HeroesText.t("CHAMP_UI_SHARED_LEVEL", [lv, cap]), 24, UITokens.INK, true)
	col.add_child(head)
	var bar := HeroEngravedBar.make(HeroEngravedBar.neutral(), lv, cap, 420)
	bar.tick_every = 1
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bar)
	var note := HeroesText.t("CHAMP_UI_LEVEL_CAP", [lv, cap, int(cl["next_world"])]) if at_cap else HeroesText.t("HALL_CHAMP_LEVEL_NOTE")
	var nl := UIKit.label(note, 22, UITokens.INK_DIM_GLASS)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nl)
	return p


## Hero Feats (§3.6, HeroData.FEATS): one engraved row per feat with its current tier. The
## counters are derived from HeroesUIModel's characters (H3b: read Meta's feat counters).
func _build_feats() -> void:
	var un := HeroesUIModel.unlocks()
	var head := UIKit.section(HeroesText.t("HALL_FEATS_TITLE"))
	_page.add_child(head)
	var note := UIKit.label(HeroesText.t("HALL_FEATS_NOTE"), 22, UITokens.INK_DIM_GLASS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(note)
	var counts := _feat_counters()
	var any := false
	for fid: String in HeroData.FEATS:
		var f: Dictionary = HeroData.FEATS[fid]
		var counter := str(f["counter"])
		if counter.begins_with("champion") and not bool(un["champions"]):
			continue
		if counter == "skill_ranks" and not bool(un["skills_teaser"]):
			continue
		any = true
		_page.add_child(_feat_row(fid, f, int(counts.get(counter, 0))))
	if not any:
		_page.add_child(UIKit.label(HeroesText.t("HALL_FEATS_EMPTY"), 24, UITokens.INK_DIM_GLASS))


func _feat_counters() -> Dictionary:
	var c := {"heroes_owned": 0, "champions_owned": 0, "recuts": 0, "full_cuts": 0, "skill_ranks": 0,
			"awakenings": 0, "champion_level": int(HeroesUIModel.champion_level()["level"])}
	for h: Dictionary in HeroesUIModel.heroes():
		if not bool(h["owned"]):
			continue
		c["heroes_owned"] += 1
		var steps := Ladder.gem_index(str(h["gem"])) - Ladder.gem_index(str(h["native"]))
		c["recuts"] += steps
		c["full_cuts"] += steps + (1 if bool(h["full"]) else 0)
		var sk: Dictionary = h["skills"]
		for s: String in ["ult", "attack", "rally"]:
			c["skill_ranks"] += maxi(0, int(sk[s]["rank"]) - 1)
		if int(sk["awakened"]["rank"]) > 0:
			c["awakenings"] += 1
	for ch: Dictionary in HeroesUIModel.champions():
		if not bool(ch["owned"]):
			continue
		c["champions_owned"] += 1
		var st := Ladder.gem_index(str(ch["gem"])) - Ladder.gem_index(str(ch["native"]))
		c["recuts"] += st
		c["full_cuts"] += st + (1 if bool(ch["full"]) else 0)
	return c


func _feat_row(fid: String, f: Dictionary, value: int) -> Control:
	var tiers: Array = f["tiers"]
	var reward: Array = f["reward"]
	var tier := 0
	while tier < tiers.size() and value >= int(tiers[tier]):
		tier += 1
	var done := tier >= tiers.size()
	var next := int(tiers[mini(tier, tiers.size() - 1)])
	# [medallion: the gem cut of the reached tier] [name · tier pips · bar] [reward: tome + N]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var med := _FeatMedal.new()
	med.tier = tier
	med.custom_minimum_size = Vector2(56, 56)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var nm := UIKit.label(HeroesText.t("FEAT_" + fid), 24, UITokens.INK, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(UIKit.label(HeroesText.t("SKL_RANK_SHORT", [mini(value, next), next]), 22, UITokens.INK_DIM_GLASS, true))
	var bar := HeroEngravedBar.make(_FeatMedal.gem_of(tier + (0 if done else 1)), mini(value, next), next, 420)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(bar)
	var pips := HeroFacetPips.make("L", tier, 18, tiers.size())
	pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(pips)
	# Reward of the next tier: a tome and the number (a quiet tick once every tier is done).
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 6)
	rw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rw)
	if done:
		rw.add_child(Icons.make("check", 30.0, UITokens.GOLD_TEXT_GLASS))
	else:
		var amounts: Array = reward[1]
		var icon := "tome" if str(reward[0]) == "tomes" else "ore"
		rw.add_child(HeroIcons.make(icon, 36.0, Color.WHITE))
		var n := UIKit.label("+" + HeroesText.num(int(amounts[tier])), 26, UITokens.INK, true)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rw.add_child(n)
	box.add_child(UIKit.hairline())
	return box


# ------------------------------------------------------------------ actions

func _open(id: String) -> void:
	Audio.play("click", -8.0)
	HeroesNav.open(hub, ("hero/" if HeroData.HEROES.has(id) else "champion/") + id)


func _open_codex() -> void:
	HeroesNav.open(hub, "codex", self)


func _play_cards_in() -> void:
	if UITokens.reduce_motion() or _cards.is_empty():
		return
	var list: Array = []
	for c in _cards:
		if is_instance_valid(c):
			list.append(c)
	UIJuice.cards_in(list.slice(0, 12))


## «Де знайти» on an unowned card: a porcelain cartouche low on the art (the card stays one
## 88+ px tap target; the Showcase explains the sources).
class _WhereTag extends Control:
	var text := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := get_parent() as Control
		if p:
			p.resized.connect(_fit)
		_fit()

	func _fit() -> void:
		var p := get_parent() as Control
		if p == null:
			return
		var ps := p.size if p.size.x > 1.0 else p.custom_minimum_size
		var f := UIKit.font_w("bold")
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		size = Vector2(minf(tw + 26.0, ps.x - 12.0), 36)
		var kind := str((p as HeroCard).size_kind) if p is HeroCard else "L"
		var foot := roundf(ps.y * ((p as HeroCard)._footer_ratio() if p is HeroCard else 0.22))
		position = Vector2((ps.x - size.x) * 0.5, ps.y - foot - size.y - 12.0)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		HeroV3.glass(self, r, UITokens.CHAMFER_XS, 0.94, HeroV3.GOLD, 0.8, 0.6)
		HeroV3.text_in(self, r.grow_individual(-8, 0, -8, 0), text, 22, UITokens.INK, "medium")


## A thin engraved divider between the gem and the class chips.
class _ChipGap extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(14, UITokens.MIN_TOUCH)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := size.x * 0.5
		var lw := UIKit.px(1.0)
		x = roundf(x) + lw * 0.5
		draw_polyline_colors(PackedVector2Array([Vector2(x, size.y * 0.26), Vector2(x, size.y * 0.5), Vector2(x, size.y * 0.74)]),
				PackedColorArray([HeroV3.a(UITokens.HAIRLINE, 0.0), HeroV3.a(UITokens.HAIRLINE, 0.8), HeroV3.a(UITokens.HAIRLINE, 0.0)]), lw)


## A feat medallion: an engraved cream socket holding the gem cut of the reached tier
## (tier 1 Сапфір, 2 Аметист, 3 Топаз); an empty engraved cut before the first tier.
class _FeatMedal extends Control:
	var tier := 0

	static func gem_of(t: int) -> String:
		return ["quartz", "sapphire", "amethyst", "topaz"][clampi(t, 0, 3)]

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		HeroV3.disc(self, c, R - 1.0, 0.86)
		if tier <= 0:
			var pts := GemDraw.cut_points("round", c, R * 0.9)
			HeroV3.frame(self, pts, HeroV3.a(UITokens.INK_DIM_GLASS, 0.5))
		else:
			GemDraw.draw_mark(self, gem_of(tier), c, R * 0.95)
