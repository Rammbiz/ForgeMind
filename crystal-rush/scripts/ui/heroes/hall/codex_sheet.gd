class_name HeroesCodexSheet
extends HeroesBottomSheet
## «Довідник / Codex» (heroes_design.md §11.3): the five-row explainer behind the 88 px «?» on the
## Hall and the Showcase. Rows: Самоцвіт · Клас · Стихія · Фракція · Огранка, each a glyph, two
## lines of copy and «де це видно». A row appears only once its system is unlocked (faction from
## the Champions unlock, element from the Portal, recut from the first Full facets / recut).
## Never a coach mark.
##   var c := HeroesCodexSheet.make(hub); hub.push_modal(c)          # Hall
##   var c := HeroesCodexSheet.make(null, true); layer.add_child(c)    # inside a screen

static func make(p_hub: Hub, p_own_scrim := false) -> HeroesCodexSheet:
	var c := HeroesCodexSheet.new()
	c.hub = p_hub
	c.own_scrim = p_own_scrim
	c.hub_modal = not p_own_scrim and p_hub != null
	return c


func _ready() -> void:
	title = HeroesText.t("CODEX_TITLE")
	var sub := UIKit.label(HeroesText.t("CODEX_SUB"), 22, UITokens.INK_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(600, 0)
	body.add_child(sub)
	body.add_child(UIKit.divider(600))
	var un := HeroesUIModel.unlocks()
	var recut_seen := false
	for h: Dictionary in HeroesUIModel.heroes():
		if bool(h["owned"]) and (bool(h["full"]) or bool(h["is_recut"])):
			recut_seen = true
	var rows: Array = [["GEM", true], ["CLASS", true], ["ELEMENT", bool(un["portal"])],
			["FACTION", bool(un["champions"])], ["RECUT", recut_seen]]
	for r: Array in rows:
		if bool(r[1]):
			body.add_child(_row(str(r[0])))
	super._ready()


func _row(k: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var glyph := _Glyph.new()
	glyph.kind = k
	glyph.custom_minimum_size = Vector2(72, 72)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(glyph)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var head := HeroesText.t("CODEX_" + k + "_T")
	col.add_child(UIKit.label(head, 26, UITokens.INK, true))
	# The Loc row starts with its own title («Самоцвіт: ...»); the bold title already says it.
	var body_text := HeroesText.t("CODEX_" + k)
	if body_text.begins_with(head + ":"):
		body_text = body_text.substr(head.length() + 1).strip_edges()
		body_text = body_text.left(1).to_upper() + body_text.substr(1)
	var txt := UIKit.label(body_text, 22, UITokens.INK)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(540, 0)
	col.add_child(txt)
	var where := UIKit.label(HeroesText.t("CODEX_WHERE", [HeroesText.t("CODEX_" + k + "_WHERE")]), 22, UITokens.GOLD_TEXT)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size = Vector2(540, 0)
	col.add_child(where)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10)
	wrap.add_child(row)
	wrap.add_child(UIKit.hairline())
	return wrap


## The row glyph: a gem mark, a class / faction line icon in a cream socket, an element in a
## slate socket, or the recut doublet.
class _Glyph extends Control:
	var kind := "GEM"

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		match kind:
			"GEM":
				GemDraw.draw_mark(self, "topaz", c, R * 1.3)
			"RECUT":
				HeroGemEmblem.draw_emblem(self, "R", "C", c, R * 1.2, true)
			_:
				var slate := kind == "ELEMENT"
				draw_circle(c + Vector2(0, 2), R - 2.0, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
				draw_circle(c, R - 2.0, UITokens.SOCKET if slate else UITokens.PAPER_0)
				draw_arc(c, R - 2.75, 0, TAU, 48, UITokens.HAIRLINE, 1.5, true)
				var ic: String = {"CLASS": "cls_warrior", "ELEMENT": "el_plasma", "FACTION": "fac_dawn"}[kind]
				var s := R * 1.1
				Icons.line(self, ic, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), UITokens.GOLD_HI if slate else UITokens.INK)
