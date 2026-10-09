class_name HeroesTeamSynergy
extends VBoxContainer
## The synergy block of the Team screen (heroes_design.md §5.5 display contract, §11.3):
##  * simple mode (before the Portal, L20): one plain line per ACTIVE bonus, no columns;
##  * full mode: three columns Клас · Стихія · Фракція of engraved tag cartouches («Дикі Ікла»
##    + «2 / 4» + faction tier pips; class «2» + a check at the pair; element «×2»), tags one
##    member short of a bonus at 40 % alpha (possible tags), then ≤ 5 effect lines (≤ 2 faction,
##    ≤ 2 class, 1 Affinity), all Loc templates filled by HeroesUIModel.team().synergy.
## Counts are of the team as set (native-blind and gem-blind).
##   var s := HeroesTeamSynergy.make(HeroesUIModel.team(), 672.0)

var team: Dictionary = {}
var width := 672.0

const COL_GAP := 16.0


static func make(p_team: Dictionary, p_width := 672.0) -> HeroesTeamSynergy:
	var s := HeroesTeamSynergy.new()
	s.team = p_team
	s.width = p_width
	s.add_theme_constant_override("separation", 8)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s._build()
	return s


func _build() -> void:
	var syn: Dictionary = team["synergy"]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UIKit.section(HeroesText.t("TEAM_SYNERGY")))
	add_child(head)
	var lines: Array = _pick_lines(syn["lines"])
	if str(syn["mode"]) == "full":
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", int(COL_GAP))
		var cw := (width - COL_GAP * 2.0) / 3.0
		cols.add_child(_column(HeroesText.t("CLASS"), "class", syn["classes"], cw))
		cols.add_child(_column(HeroesText.t("ELEMENT"), "element", syn["elements"], cw))
		cols.add_child(_column(HeroesText.t("FACTION"), "faction", syn["factions"], cw))
		add_child(cols)
	if lines.is_empty():
		var none := UIKit.label(HeroesText.t("SYN_NONE"), 22, UITokens.INK_DIM_GLASS)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(width, 0)
		add_child(none)
	for ln: Dictionary in lines:
		add_child(_line(ln))
	# Elements with no live machine yet say so (§5.2).
	for e: String in (syn["elements"] as Dictionary):
		if not HeroesTeamLogic.element_has_machine(e):
			var l := UIKit.label(HeroesText.t("TEAM_NO_MACHINE", [HeroesText.element_label(e)]), 22, UITokens.INK_DIM_GLASS)
			add_child(l)
	if str(syn["mode"]) != "full":
		var note := UIKit.label(HeroesText.t("TEAM_SYN_SIMPLE_NOTE"), 22, UITokens.INK_DIM_GLASS)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(width, 0)
		add_child(note)


## ≤ 2 faction, ≤ 2 class and the best Affinity line (§5.5).
func _pick_lines(all: Array) -> Array:
	var fac: Array = []
	var cls: Array = []
	var aff: Array = []
	for ln: Dictionary in all:
		var k := str(ln["key"])
		if k.begins_with("SYN_PAIR_"):
			cls.append(ln)
		elif k == "SYN_AFFINITY":
			aff.append(ln)
		else:
			fac.append(ln)
	var out: Array = fac.slice(0, 2) + cls.slice(0, 2)
	if not aff.is_empty():
		var best: Dictionary = aff[0]
		var els: Dictionary = (team["synergy"] as Dictionary)["elements"]
		var best_n := -1
		for ln: Dictionary in aff:
			var name := str((ln["args"] as Array)[0])
			for e: String in els:
				if HeroesText.element_label(e) == name and int(els[e]) > best_n:
					best_n = int(els[e])
					best = ln
		out.append(best)
	return out


func _line(ln: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := str(ln["key"])
	var icon := "check"
	if k.begins_with("SYN_PAIR_"):
		icon = "cls_" + k.trim_prefix("SYN_PAIR_").to_lower()
	elif k == "SYN_AFFINITY":
		icon = "odds"
	else:
		var f := k.trim_prefix("SYN_").to_lower()
		icon = "fac_" + f
	var ic := Icons.make(icon, 30.0, UITokens.GOLD_TEXT_GLASS)
	ic.custom_minimum_size = Vector2(30, 30)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := UIKit.label(str(ln["text"]), 22, UITokens.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width - 40.0, 0)
	row.add_child(l)
	return row


func _column(title: String, kind: String, counts: Dictionary, cw: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(cw, 0)
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return _rank(kind, str(a), int(counts[a])) > _rank(kind, str(b), int(counts[b])) \
			or (_rank(kind, str(a), int(counts[a])) == _rank(kind, str(b), int(counts[b])) and str(a) < str(b)))
	# The «+N more» count sits right after ITS OWN header («КЛАС +1»), never at the column's right
	# end where it read as the next header's prefix («+1 СТИХІЯ»).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UIKit.caps(title, 20, UITokens.INK_DIM_GLASS))
	if keys.size() > 1:
		head.add_child(UIKit.caps("+%d" % (keys.size() - 1), 20, UITokens.GOLD_TEXT_GLASS))
	col.add_child(head)
	if not keys.is_empty():
		col.add_child(_TagChip.make(kind, str(keys[0]), int(counts[keys[0]]), cw))
	return col


## Sort key: active tags first, then by count.
static func _rank(kind: String, tag: String, n: int) -> int:
	var act := false
	match kind:
		"faction": act = HeroesTeamLogic.faction_tier(n) > 0
		"class": act = n >= HeroesTeamLogic.PAIR
		_: act = HeroesTeamLogic.element_has_machine(tag)
	return (100 if act else 0) + n


## An engraved tag cartouche: glyph socket + name, and the count line with tier pips.
class _TagChip extends Control:
	var kind := "faction"
	var tag := ""
	var n := 1
	var active := false

	static func make(p_kind: String, p_tag: String, p_n: int, w: float) -> _TagChip:
		var c := _TagChip.new()
		c.kind = p_kind
		c.tag = p_tag
		c.n = p_n
		match p_kind:
			"faction": c.active = HeroesTeamLogic.faction_tier(p_n) > 0
			"class": c.active = p_n >= HeroesTeamLogic.PAIR
			_: c.active = HeroesTeamLogic.element_has_machine(p_tag)
		c.custom_minimum_size = Vector2(w, 66)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.modulate.a = 1.0 if c.active else 0.4
		return c

	func _name() -> String:
		match kind:
			"faction": return HeroesText.faction_label(tag)
			"class": return HeroesText.class_label(tag)
		return HeroesText.element_label(tag)

	func _icon() -> String:
		match kind:
			"faction": return "fac_" + tag
			"class": return "cls_" + tag
		return "el_" + tag

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pts := GemDraw.chamfer_rect(r, UITokens.CHAMFER_XS)
		# v3.1 (§3.2: no borders on chips inside a card): frameless glass, an active tag lifted
		# to white with its 1 dpx light line, an idle one a quiet well.
		if active:
			HeroV3.glass(self, r, UITokens.CHAMFER_XS, 0.78, HeroV3.GOLD, 0.0, 0.8, 0.0, Color.WHITE)
		else:
			draw_colored_polygon(pts, HeroV3.a(UITokens.PAPER_3, 0.42))
		var f := UIKit.font(true)
		var fm := UIKit.font(false)
		var x := 10.0
		var name := _name()
		var fs := 22
		while fs > 18 and f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 20.0:
			fs -= 1
		draw_string(f, Vector2(x, 27), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, fs, UITokens.INK)
		var ic := Rect2(Vector2(x, 36), Vector2(24, 24))
		Icons.draw_icon(self, _icon(), ic, UITokens.GOLD_TEXT_GLASS)
		var tx := x + 30.0
		var line := ""
		match kind:
			"faction":
				line = "%d / %d" % [n, TeamData.FACTION_MEMBERS_FOR_TIER[TeamData.FACTION_MEMBERS_FOR_TIER.size() - 1]]
			"class":
				line = "%d / %d" % [n, HeroesTeamLogic.PAIR]
			_:
				line = "×%d" % n
		draw_string(fm, Vector2(tx, 56), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UITokens.INK)
		var lw := fm.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var px := tx + lw + 14.0
		if kind == "faction":
			var tier := HeroesTeamLogic.faction_tier(n)
			for i in TeamData.FACTION_MEMBERS_FOR_TIER.size() - 1:
				GemDraw.draw_pip(self, Vector2(px + i * 15.0, 48), 16.0, i < tier, UITokens.TOPAZ)
		elif kind == "class" and n >= HeroesTeamLogic.PAIR:
			Icons.draw_icon(self, "check", Rect2(Vector2(px - 2, 36), Vector2(24, 24)), UITokens.PLUS)
