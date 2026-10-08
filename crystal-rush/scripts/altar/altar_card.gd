class_name AltarCard
extends Control
## One Cache card of the opening ceremony (arsenal_design.md §5.6 Fan-out / Flips / Sparks, §5.7
## rarity language). Face-down it shows the rarity card back (card_rarity.gdshader mode 0: navy
## lattice, rarity glow, the colour-blind gem cut). flip() turns it (Common 0.25 s, Rare 0.35,
## Epic 0.5, Legendary / Mythic longer, EconData.REVEAL.flip) to its face: the rarity frame
## (gradient + the animated mode-1 frame), the machine render (MachineThumbs) on a family-accent
## glow, the name, the blueprint count and the machine's blueprint bar. sparks() then flies
## blueprint sparks from the card into its bar, which counts up from bp_before to bp_after and
## turns green with an arrow when the machine is upgradable. New machines wear a NEW ribbon.
##
##   var c := AltarCard.new(card)          # card = one entry of a §6.6 reveal bundle
##   c.size = Vector2(170, 240)
##   await c.flip()                        # returns after the turn
##   c.sparks()

signal flipped

const CARD_SHADER := preload("res://shaders/card_rarity.gdshader")

var data: Dictionary = {}
var face_up := false
## 0..1 how far the bar shows bp_after (sparks() animates it).
var bar_k := 0.0
var glow := 1.0

var _back: ColorRect
var _frame: ColorRect
var _over: Control
var _tex: Texture2D
var _flash := 0.0
var _sparks: Array[Dictionary] = []
var _tw: Tween
var _t := 0.0
var _bar_hit := 0.0


func _init(p_data: Dictionary = {}) -> void:
	data = p_data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 240)


func _ready() -> void:
	resized.connect(_layout)
	# v2 draws its own porcelain back and gem-ground face (the shader rects stay for API
	# compatibility, hidden).
	_back = _shader_rect(0)
	_back.visible = false
	add_child(_back)
	_frame = _shader_rect(1)
	_frame.visible = false
	add_child(_frame)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	var id := str(data.get("id", ""))
	if id != "":
		_tex = MachineThumbs.get_thumb(self, id, false)
		if _tex == null and DisplayServer.get_name() != "headless":
			MachineThumbs.service(get_tree()).rendered.connect(_on_thumb)
	_layout()


func _on_thumb(key: String, tex: Texture2D) -> void:
	if key == MachineThumbs.key_of(str(data.get("id", "")), false) and is_instance_valid(self):
		_tex = tex
		queue_redraw()


func rarity() -> String:
	return str(data.get("rarity", "C"))


func color() -> Color:
	return UITokens.rarity(rarity())


## Walkout cards play the machine on the Altar: a NEW machine, or any Legendary+ card.
func is_walkout() -> bool:
	return bool(data.get("new", false)) or (rarity() in ["L", "M"] and str(data.get("id", "")) != "")


## Flip time of this card's rarity (EconData.REVEAL.flip, scaled by `speed`).
func flip_time(speed := 1.0) -> float:
	var f: Dictionary = EconData.REVEAL["flip"]
	return float(f.get(rarity(), 0.3)) * speed


func _shader_rect(mode: int) -> ColorRect:
	var cr := ColorRect.new()
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color.WHITE
	var m := ShaderMaterial.new()
	m.shader = CARD_SHADER
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("tier", CacheModels.tier(rarity()))
	m.set_shader_parameter("rarity_color", color())
	m.set_shader_parameter("radius_px", 20.0)
	m.set_shader_parameter("border_px", 6.0 if mode == 0 else 5.0)
	cr.material = m
	return cr


func _layout() -> void:
	pivot_offset = size * 0.5
	if _over:
		_over.size = size
	for cr: ColorRect in [_back, _frame]:
		if cr == null:
			continue
		cr.position = Vector2(4, 6)
		cr.size = size - Vector2(8, 12)
		(cr.material as ShaderMaterial).set_shader_parameter("size", cr.size)


## Turns the card face-up over `dur` (default: its rarity's flip time). Returns when done.
func flip(dur := -1.0) -> void:
	if face_up:
		return
	if dur < 0.0:
		dur = flip_time()
	dur = maxf(dur, 0.12)
	var r := rarity()
	pivot_offset = size * 0.5
	var tw := create_tween()
	_tw = tw
	# Epic+ lift and glow before they turn (anticipation, no suspense: the tell already showed it).
	if r in ["E", "L", "M"]:
		tw.tween_property(self, "scale", Vector2(1.1, 1.1), dur * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale:x", 0.0, dur * (0.25 if r in ["E", "L", "M"] else 0.45)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_show_face)
	tw.tween_property(self, "scale", Vector2.ONE * (1.08 if r != "C" else 1.0), dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, dur * 0.15)
	await tw.finished
	flipped.emit()


## Shows the face at once (skip / summary / reduce motion).
func show_face_now() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	scale = Vector2.ONE
	_show_face()
	bar_k = 1.0
	queue_redraw()


func _show_face() -> void:
	if face_up:
		return
	face_up = true
	_back.visible = false
	_frame.visible = false
	_flash = 1.0
	var r := rarity()
	_stinger(r)
	queue_redraw()


## Per-rarity stinger (§5.7): tick / chime / arpeggio / clang + choir; haptics by pattern.
func _stinger(r: String) -> void:
	match r:
		"C":
			Audio.note(9, -14.0)
		"R":
			Audio.note(11, -10.0)
			UIJuice.haptic("TICK", 0.5)
		"E":
			Audio.note(10, -9.0)
			Audio.note(12, -10.0)
			UIJuice.haptic_pattern("rarity_E")
		"L", "M":
			Audio.chord(7, true, -6.0)
			Audio.play("weapon_get", -6.0)
			UIJuice.haptic_pattern("rarity_" + r)


## Blueprint sparks fly from the card's art into its bar; the bar then counts up. Duplicates
## only (a NEW machine's card and Wild cards just light their bar).
func sparks() -> void:
	if not face_up:
		_show_face()
	var n := clampi(int(data.get("count", 1)) * 2 + 4, 6, 14)
	var from := Vector2(size.x * 0.5, size.y * 0.36)
	var to := _bar_rect().get_center()
	for i in n:
		_sparks.append({"t": -i * 0.035, "from": from + Vector2(randf_range(-26, 26), randf_range(-26, 26)),
				"to": to + Vector2(randf_range(-20, 20), 0), "bend": randf_range(-60.0, 60.0)})
	var tw := create_tween()
	tw.tween_interval(0.28)
	tw.tween_property(self, "bar_k", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_bar_hit = 1.0
		if bool(data.get("upgradable", false)):
			Audio.note(12, -10.0))


func _process(delta: float) -> void:
	_t = fmod(_t + delta, 1000.0)
	var busy := false
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		busy = true
	if _bar_hit > 0.0:
		_bar_hit = maxf(0.0, _bar_hit - delta * 2.5)
		busy = true
	if not _sparks.is_empty():
		var keep: Array[Dictionary] = []
		for s in _sparks:
			s["t"] = float(s["t"]) + delta
			if float(s["t"]) < 0.4:
				keep.append(s)
			else:
				Audio.note(5 + randi() % 5, -18.0)
		_sparks = keep
		busy = true
	if busy or face_up or glow > 0.0:
		queue_redraw()
		if _over:
			_over.queue_redraw()


func _gem() -> String:
	return UITokens.gem_of(rarity())


func _body() -> Rect2:
	return Rect2(Vector2(4, 6), size - Vector2(8, 12))


func _foot_h() -> float:
	var b := _body()
	if _is_wild():
		return roundf(b.size.y * 0.2)
	# v3.1: sized to its text stack (name 1-2 lines, then the bar / count row), never overlapping.
	var nl := _name_layout()
	var fs: int = nl[1]
	var lines := _name_rows()
	var need := 8.0 + fs * lines + 4.0 * (lines - 1) + 6.0 + _count_fs() + 8.0
	return roundf(maxf(need, b.size.y * 0.34))


func _is_wild() -> bool:
	return bool(data.get("wild", false)) or str(data.get("id", "")) == ""


var _name_two := false
var _nl_cache: Array = []
var _nl_key := ""


## [lines, font size] of the name on the footer: Medium 22 (20 on narrow cards), wrapped to at
## most two lines; a very long word drops to 18.
func _name_layout() -> Array:
	var b := _body()
	var id := str(data.get("id", ""))
	var key := "%s_%d" % [id, int(b.size.x)]
	if key == _nl_key:
		return _nl_cache
	var nm := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else Loc.t("CUR_WILD")
	var f := UIKit.font_w("medium")
	var max_w := b.size.x - 12.0
	var fs0 := _count_fs()
	var lines := MachineCard._name_lines(nm, f, fs0, max_w)
	var fs := fs0
	for ln in lines:
		fs = mini(fs, UIKit.fit_size(ln, max_w, fs0, 18, false))
	_nl_cache = [lines, fs]
	_nl_key = key
	return _nl_cache


## Rows the name block takes: always two, so a row of cards keeps one footer height (a one-line
## name is centred in the block).
func _name_rows() -> int:
	return 2


## Footer text size: 22 px (§5), 20 on the narrow summary / inline cards.
func _count_fs() -> int:
	return NAME_FS if _body().size.x >= 160.0 else NAME_FS - 2


func _bar_rect() -> Rect2:
	var b := _body()
	var seam := b.end.y - _foot_h()
	var nl := _name_layout()
	var lines := _name_rows()
	var fs: int = nl[1]
	# The bar shares its row with the "n/need" count (right), under the name block.
	var w := b.size.x - 24.0 - _count_w() - 8.0
	var cy := seam + 8.0 + fs * lines + 4.0 * (lines - 1) + 6.0 + _count_fs() * 0.5
	return Rect2(Vector2(b.position.x + 12, cy - 4.0), Vector2(w, 8))


## v3.1: footer text >= 22 px on glass (§5, MF-15); 20 on the narrow summary / inline cards.
const NAME_FS := 22


func _count_w() -> float:
	if _is_wild():
		return 0.0
	var need := maxi(int(data.get("bp_need", 0)), 1)
	return UIKit.font_w("medium").get_string_size("%d/%d" % [need, need], HORIZONTAL_ALIGNMENT_LEFT, -1, _count_fs()).x


func _draw() -> void:
	var gk := _gem()
	var g: Dictionary = UITokens.gem(gk)
	var rc: Color = g["rim"]
	var body := _body()
	# v3.1: a static rarity glow (nothing breathes) and ONE soft halo shadow (no stacked slabs).
	if glow > 0.0:
		var ga := (0.3 if not face_up else 0.4) * glow * (1.4 if rarity() in ["L", "M"] else 1.0)
		draw_texture_rect(UIKit.glow_texture(), body.grow(30 + CacheModels.tier(rarity()) * 6), false, Color(rc.r, rc.g, rc.b, ga))
	var pts := GemDraw.chamfer_rect(body, 10.0)
	var sc := UITokens.SCRIM
	draw_texture_rect(UIKit.glow_texture(), Rect2(body.position + Vector2(-14, -2), body.size + Vector2(28, 24)), false, Color(sc.r, sc.g, sc.b, 0.24))
	if not face_up:
		_draw_back(body, pts, gk, g)
		return
	_draw_face(body, pts, gk, g)


## Porcelain back: cream with a faint facet lattice, a double gold frame and the honest tell -
## the rarity's gem mark in the middle on a soft glow of its colour.
func _draw_back(body: Rect2, pts: PackedVector2Array, gk: String, g: Dictionary) -> void:
	var cols := PackedColorArray()
	for q in pts:
		cols.append(UITokens.PAPER_0.lerp(UITokens.PAPER_2, (q.y - body.position.y) / body.size.y))
	draw_polygon(pts, cols)
	var c := body.get_center()
	var lat := Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.22)
	var step := body.size.x / 4.0
	for i in range(-4, 9):
		var x := body.position.x + i * step
		draw_line(Vector2(x, body.position.y + 8), Vector2(x + body.size.y * 0.5, body.end.y - 8), lat, UIKit.px(1.0), true)
		draw_line(Vector2(x + body.size.y * 0.5, body.position.y + 8), Vector2(x, body.end.y - 8), lat, UIKit.px(1.0), true)
	var inner := GemDraw.chamfer_rect(body.grow(-8.0), 7.0)
	draw_colored_polygon(GemDraw.chamfer_rect(Rect2(c - Vector2(36, 36), Vector2(72, 72)), 18.0), Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.95))
	var rim: Color = g["rim"]
	draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(70, 70), Vector2(140, 140)), false, Color(rim.r, rim.g, rim.b, 0.45))
	GemDraw.draw_mark(self, gk, c, minf(body.size.x * 0.3, 46.0))
	# v3.1 frame: the inner line is light (never a second gold frame), ONE 1 dpx gold line outside.
	GemDraw.outline(self, inner, Color(1, 1, 1, 0.7), UIKit.px(1.0))
	GemDraw.outline(self, pts, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0))


## Face: the gem-ground card (Genshin construction): gradient + light pool, the machine render
## on a family-accent glow, the count on a cream chip, a cream footer with the name and the
## blueprint bar (cream track, amber fill, gold "!" when upgradable), inner rim, gold hairline
## and the gem-cut mark.
func _draw_face(body: Rect2, pts: PackedVector2Array, gk: String, g: Dictionary) -> void:
	var f := UIKit.font_w("medium")
	var top: Color = g["top"]
	var bot: Color = g["bot"]
	var cols := PackedColorArray()
	for q in pts:
		cols.append(top.lerp(bot, (q.y - body.position.y) / body.size.y))
	draw_polygon(pts, cols)
	if gk == "opal":
		var fl: Array = g["flecks"]
		for i in 14:
			var fp := body.position + Vector2(fposmod(i * 37.3, body.size.x - 16) + 8, fposmod(i * 53.7, body.size.y * 0.6) + 10)
			var fc: Color = fl[i % fl.size()]
			draw_circle(fp, 1.6 + (i % 3), Color(fc.r, fc.g, fc.b, 0.5 + 0.3 * sin(_t * 2.0 + i)))
	var lc: Color = g["light"]
	var fh := _foot_h()
	var seam := body.end.y - fh
	var id := str(data.get("id", ""))
	var wild := _is_wild()
	var cx := body.get_center().x
	var art := Rect2(Vector2(body.position.x + 6, body.position.y + 8), Vector2(body.size.x - 12, seam - body.position.y - 10))
	var acc := UITokens.family(ArsenalData.family_of(id)) if not wild else Color(0.75, 0.5, 1.0)
	draw_texture_rect(UIKit.glow_texture(), art.grow(16), false, Color(lc.r, lc.g, lc.b, 0.32))
	draw_texture_rect(UIKit.glow_texture(), art.grow(-art.size.x * 0.08), false, Color(acc.r, acc.g, acc.b, 0.3))
	var side := minf(art.size.x, art.size.y)
	if wild:
		Icons.draw_icon(self, "wild", Rect2(art.get_center() - Vector2(side, side) * 0.36, Vector2(side, side) * 0.72))
	elif _tex:
		var sz := side * 1.6
		draw_texture_rect(_tex, Rect2(art.get_center() - Vector2(sz, sz) * 0.5 + Vector2(0, 4), Vector2(sz, sz)), false)
	else:
		Icons.draw_icon(self, id, Rect2(art.get_center() - Vector2(side, side) * 0.38, Vector2(side, side) * 0.76))
	# Footer strip.
	var foot := PackedVector2Array([Vector2(body.position.x, seam), Vector2(body.end.x, seam), Vector2(body.end.x, body.end.y - 10.0),
			Vector2(body.end.x - 10.0, body.end.y), Vector2(body.position.x + 10.0, body.end.y), Vector2(body.position.x, body.end.y - 10.0)])
	# §7.3: a glass footer at 0.86 under a 1 dpx seam.
	draw_colored_polygon(foot, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.9))
	var sy := GemDraw.pixel_y(self, seam)
	draw_line(Vector2(body.position.x, sy), Vector2(body.end.x, sy), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), -1.0)
	# Name: 22 px Medium (20 for a very long single word), a long name wraps to two lines.
	var nl := _name_layout()
	var lines: PackedStringArray = nl[0]
	var fs: int = nl[1]
	_name_two = lines.size() == 2 and not wild
	if wild:
		_text_c(f, lines[0], Vector2(cx, seam + fh * 0.5 + fs * 0.36), fs, UITokens.INK)
	else:
		# Baselines: cap height ~0.72 fs under the line top (8 px under the seam, 4 px leading).
		var off := (_name_rows() - lines.size()) * (fs + 4.0) * 0.5
		for i in lines.size():
			_text_c(f, lines[i], Vector2(cx, seam + 8.0 + off + fs * 0.8 + i * (fs + 4.0)), fs, UITokens.INK)
	# Count chip (top-right of the art): glass, one 1 dpx line, Bold 22.
	var ct := "×%d" % int(data.get("count", 1))
	var cf := UIKit.font_w("bold")
	var cfs := 22
	var cw := cf.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x + 14.0
	var cr := Rect2(Vector2(body.end.x - cw - 6.0, seam - cfs - 16.0), Vector2(cw, cfs + 8.0))
	var cp := GemDraw.chamfer_rect(cr, 5.0)
	draw_colored_polygon(cp, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.92))
	GemDraw.outline(self, cp, UITokens.LINE_GOLD, UIKit.line_px(1.0))
	draw_string(cf, Vector2(cr.position.x + 7.0, cr.end.y - 6.5), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, UITokens.GOLD_TEXT_GLASS)
	if not wild:
		var br := _bar_rect()
		var need := maxi(int(data.get("bp_need", 0)), 1)
		var before := int(data.get("bp_before", 0))
		var after := int(data.get("bp_after", before))
		var shown := lerpf(float(before), float(after), bar_k)
		var up := bool(data.get("upgradable", false)) and bar_k >= 1.0
		# §7.5: a 1 dpx hairline frame round a glass track, a flat amber fill with a table light.
		var tp := GemDraw.chamfer_rect(br, 3.0)
		draw_colored_polygon(tp, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.6))
		var tr := br.grow(-2.0)
		draw_colored_polygon(GemDraw.chamfer_rect(tr, 1.5), Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.55))
		var fk := clampf(shown / float(need), 0.0, 1.0)
		if fk > 0.0:
			var fr := Rect2(tr.position, Vector2(maxf(tr.size.x * fk, 3.0), tr.size.y))
			var fp := GemDraw.chamfer_rect(fr, 1.5)
			var fc := PackedColorArray()
			for q in fp:
				fc.append(UITokens.CTA_HI.lerp(UITokens.CTA_LO, (q.y - fr.position.y) / fr.size.y))
			draw_polygon(fp, fc)
		GemDraw.outline(self, tp, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), UIKit.line_px(1.0))
		if _bar_hit > 0.0:
			draw_texture_rect(UIKit.glow_texture(), br.grow(12), false, Color(1.0, 0.82, 0.45, _bar_hit * 0.7))
		draw_string(UIKit.font_w("medium"), Vector2(body.end.x - 12.0 - _count_w(), br.get_center().y + _count_fs() * 0.36), "%d/%d" % [int(round(shown)), need],
				HORIZONTAL_ALIGNMENT_RIGHT, _count_w(), _count_fs(), UITokens.GOLD_TEXT_GLASS if up else UITokens.INK_DIM_GLASS)
		if up:
			# §7.11 notify badge in the card's top-right corner over the art: a 28 px amber disc,
			# a 1 dpx cream ring, one halo; never on the name / bar row.
			var bc := Vector2(body.end.x - 18.0, body.position.y + 18.0)
			draw_texture_rect(UIKit.glow_texture(), Rect2(bc - Vector2(20, 18), Vector2(40, 40)), false, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.25))
			draw_circle(bc, 14.0, UITokens.NOTIFY, true, -1.0, true)
			draw_arc(bc, 14.0 - UIKit.px(0.5), 0, TAU, 40, Color(1, 0.98, 0.92, 0.95), UIKit.line_px(1.0), true)
			_text_c(UIKit.font_w("bold"), "!", bc + Vector2(0, 7.5), 22, UIKit.BROWN)
	# Frame: the gem's light rim 1 dpx inside, ONE 1 dpx gold line outside.
	var rim: Color = g["rim"]
	GemDraw.outline(self, GemDraw.chamfer_rect(body.grow(-2.5), 9.0), Color(rim.r, rim.g, rim.b, 0.6), UIKit.px(1.0))
	GemDraw.outline(self, pts, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0))
	var ms := clampf(body.size.x * 0.15, 18.0, 28.0)
	GemDraw.draw_mark(self, gk, body.position + Vector2(10.0 + ms * 0.5, 10.0 + ms * 0.5), ms)


## Over the face: the flip flash, the NEW tag and the blueprint sparks.
func _draw_over() -> void:
	if not face_up:
		return
	var body := _body()
	if _flash > 0.0:
		_over.draw_colored_polygon(GemDraw.chamfer_rect(body, 10.0), Color(1, 0.99, 0.94, _flash * 0.85))
	if bool(data.get("new", false)):
		var nf := UIKit.font_caps(20)
		var tag := Loc.t("REVEAL_NEW").to_upper()
		var nw := nf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var tr := Rect2(Vector2(body.get_center().x - nw * 0.5 - 11, body.position.y - 14), Vector2(nw + 22, 28))
		_over.draw_style_box(UIKit.lux("tag_new"), tr)
		_over.draw_string(nf, tr.position + Vector2(11, 21.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UITokens.NEW_INK)
	for sp in _sparks:
		if float(sp["t"]) < 0.0:
			continue
		var k := clampf(float(sp["t"]) / 0.4, 0.0, 1.0)
		var a: Vector2 = sp["from"]
		var b: Vector2 = sp["to"]
		var mid := (a + b) * 0.5 + Vector2(float(sp["bend"]), -40.0)
		var p := a.lerp(mid, k).lerp(mid.lerp(b, k), k)
		var sz := 15.0 * (1.0 - k * 0.5)
		_over.draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), false, Color(1.0, 0.82, 0.45, 0.9))
		GemDraw.draw_glint(_over, p, sz * 1.2, Color(1, 1, 0.95, 0.95))


func _text_c(f: Font, s: String, at: Vector2, fs: int, col: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(at.x - w * 0.5, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
