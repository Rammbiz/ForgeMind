class_name HeroSkillPlate
extends Control
## A skill plate (heroes_design.md §9.3, fusion §6.8 #3): an octagonal cut-gem plate of cream enamel
## with gold walls and the skill glyph engraved in it; a bezel stone on the top edge in the gem of
## the CURRENT ult form (Ult only; a recut hero's stone can never pass its native gem - rule #3
## visible on the plate); a hallmark tag on the bottom edge ("3 / 5" or МАКС); the skill name
## under it. Locked: the enamel greys and a small lock sits on the glyph (Awakening locked = a
## sealed geode). `note` prints the native ceiling under the name («Ранг 9 — лише для корінних Топазів»).
## Give it >= 150 px of width when a note is shown (names and notes wrap to 2 / 3 lines).
##   var p := HeroSkillPlate.make("ult", "Сонцесходження", 3, 9, "E")
##   p.pressed.connect(...)

signal pressed

var skill := "ult":
	set(v):
		skill = v
		queue_redraw()
var title := "":
	set(v):
		title = v
		_resize()
var rank := 1:
	set(v):
		rank = v
		queue_redraw()
var cap := 1:
	set(v):
		cap = v
		queue_redraw()
var form_gem := "":              ## bezel stone ("" = none)
	set(v):
		form_gem = v
		queue_redraw()
var locked := false:
	set(v):
		locked = v
		queue_redraw()
var born := false                ## born-awakened: a topaz keystone on the hallmark
var note := "":
	set(v):
		note = v
		_resize()
var plate := 120.0:
	set(v):
		plate = v
		_resize()
var _down := false


static func make(p_skill: String, p_title: String, p_rank := 1, p_cap := 1, p_form_gem := "", px := 120.0) -> HeroSkillPlate:
	var p := HeroSkillPlate.new()
	p.skill = p_skill
	p.title = p_title
	p.rank = p_rank
	p.cap = p_cap
	p.form_gem = p_form_gem
	p.plate = px
	return p


## Builds a plate from a HeroesUIModel hero skill row (hero(id).skills[skill]).
static func from_model(h: Dictionary, s: String, px := 120.0) -> HeroSkillPlate:
	var row: Dictionary = (h["skills"] as Dictionary)[s]
	var p := make(s, HeroesText.skill_name(str(h["id"]), s), int(row["rank"]), int(row["cap"]),
			str(row.get("form_gem", "")) if s == "ult" else "", px)
	p.locked = bool(row.get("locked", false)) if s != "awakened" else not bool(row.get("open", false))
	p.born = bool(row.get("born", false))
	if int(row["cap"]) < int(row["cap_native"]) and not p.locked:
		p.note = HeroesText.t("SKL_NATIVE_ONLY", [int(row["cap_native"]), HeroesText.gem_name(str(h["gem"]), "PL")])
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_resize()


func _resize() -> void:
	var lines := 0
	if title != "":
		lines += 2
	if note != "":
		lines += 3
	custom_minimum_size = Vector2(maxf(plate + 16.0, UITokens.MIN_TOUCH), plate + 18.0 + lines * 22.0)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_down = e.pressed
		queue_redraw()
	if UIJuice.is_tap(e):
		pressed.emit()


func _oct(c: Vector2, s: float) -> PackedVector2Array:
	return GemDraw.chamfer_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), s * 0.27)


func _draw() -> void:
	var s := plate
	var c := Vector2(size.x * 0.5, 12.0 + s * 0.5 + (1.0 if _down else 0.0))
	var oct := _oct(c, s)
	var sh := PackedVector2Array()
	for p in oct:
		sh.append(p + Vector2(0, 4))
	draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.14))
	var geode := locked and skill == "awakened"
	var cols := PackedColorArray()
	for p in oct:
		var t := (p.y - (c.y - s * 0.5)) / s
		if geode:
			cols.append(Color("#8E8AA6").lerp(Color("#5C5874"), t))
		elif locked:
			cols.append(UITokens.PAPER_2.lerp(UITokens.PAPER_3, t))
		else:
			cols.append(UITokens.PAPER_0.lerp(UITokens.PAPER_2, t * 0.9))
	draw_polygon(oct, cols)
	# Gold walls: outer hairline + an inner wall 6 px in.
	GemDraw.outline(self, oct, UITokens.HAIRLINE, 2.0)
	GemDraw.outline(self, _oct(c, s - 12.0), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.55), 1.0)
	if geode:
		# A sealed geode: a crack and a hint of crystal inside.
		draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.12), c + Vector2(-s * 0.08, 0), c + Vector2(0.04 * s, -s * 0.1), c + Vector2(s * 0.3, s * 0.06)]), Color("#E8DFFF"), 1.6, true)
		GemDraw.draw_gem(self, "triangle", c + Vector2(0, s * 0.08), s * 0.2, Color("#B06CFF"), Color("#E7D2FF"), Color("#5E2BA8"), false, 0.8)
	# Engraved glyph: a light lip under an ink stroke.
	var gs := s * 0.5
	var gr := Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs))
	var icon := str(HeroIcons.SKILL_ICON.get(skill, "sk_relic"))
	if not geode:
		var ink := UITokens.GOLD_TEXT if not locked else Color(UITokens.INK_DIM.r, UITokens.INK_DIM.g, UITokens.INK_DIM.b, 0.45)
		HeroIcons.line(self, icon, Rect2(gr.position + Vector2(0, 1.5), gr.size), Color(1, 1, 1, 0.9))
		HeroIcons.line(self, icon, gr, ink)
	if locked:
		var lr := Rect2(c + Vector2(s * 0.14, s * 0.1), Vector2(s * 0.26, s * 0.26))
		draw_circle(lr.get_center(), lr.size.x * 0.62, UITokens.PAPER_0)
		draw_arc(lr.get_center(), lr.size.x * 0.62, 0, TAU, 32, UITokens.HAIRLINE, 1.2, true)
		Icons.draw_icon(self, "lock", lr.grow(-lr.size.x * 0.12), UITokens.INK)
	# Bezel stone (the current ult form's gem) on the top edge.
	if form_gem != "" and not locked:
		GemDraw.draw_mark(self, UITokens.gem_of(form_gem), Vector2(c.x, c.y - s * 0.5), s * 0.22)
	# Hallmark tag on the bottom edge.
	if not locked:
		var maxed := rank >= cap
		var txt := HeroesText.t("SKL_MAX") if maxed else HeroesText.t("SKL_RANK_SHORT", [rank, cap])
		var f := UIKit.font_w("extrabold")
		var fs := 20
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tr := Rect2(Vector2(c.x - tw * 0.5 - 12.0, c.y + s * 0.5 - 15.0), Vector2(tw + 24.0, 30.0))
		var tp := GemDraw.chamfer_rect(tr, 6.0)
		if maxed:
			var tc := PackedColorArray()
			for p in tp:
				tc.append(Color("#F3D89A").lerp(Color("#D9AE5A"), (p.y - tr.position.y) / tr.size.y))
			draw_polygon(tp, tc)
		else:
			draw_colored_polygon(tp, UITokens.PAPER_0)
		GemDraw.outline(self, tp, UITokens.HAIRLINE, 1.2)
		draw_string(f, Vector2(tr.get_center().x - tw * 0.5, tr.get_center().y + f.get_ascent(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.BROWN if maxed else UITokens.INK)
		if born:
			GemDraw.draw_keystone(self, Vector2(tr.end.x + 2.0, tr.position.y + 2.0), 13.0, 1.0, Color(1.0, 0.86, 0.5))
	# Name and the native-ceiling note under the plate (centred, two lines max each).
	var y := c.y + s * 0.5 + 24.0
	if title != "":
		y = _text_block(title, y, 22, UITokens.INK, "bold", 2)
	if note != "":
		_text_block(note, y, 20, UITokens.INK_SOFT, "medium")


func _text_block(txt: String, y: float, fs0: int, col: Color, weight: String, max_lines := 3) -> float:
	var f := UIKit.font_w(weight)
	var w := size.x
	# Shrink (down to 18 px) until the longest single word fits the plate width.
	var fs := fs0
	var longest := ""
	for word in txt.split(" "):
		if word.length() > longest.length():
			longest = word
	while fs > 18 and f.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	var lines := PackedStringArray()
	var cur := ""
	for word in txt.split(" "):
		var t2 := word if cur == "" else cur + " " + word
		if f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = t2
	if cur != "":
		lines.append(cur)
	for i in mini(lines.size(), max_lines):
		var lw := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((w - lw) * 0.5, y + f.get_ascent(fs)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		y += fs * 1.2
	return y + 2.0
