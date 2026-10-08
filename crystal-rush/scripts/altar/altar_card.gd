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
	return roundf(_body().size.y * (0.34 if not _is_wild() else 0.2))


func _is_wild() -> bool:
	return bool(data.get("wild", false)) or str(data.get("id", "")) == ""


var _name_two := false


func _bar_rect() -> Rect2:
	var b := _body()
	var seam := b.end.y - _foot_h()
	# The bar shares its row with the "n/need" count (right), on every card: a two-line name
	# no longer drops the count.
	var w := b.size.x - 28.0 - _count_w() - 8.0
	return Rect2(Vector2(b.position.x + 14, seam + _foot_h() * (0.66 if _name_two else 0.62) - 4.5), Vector2(w, 9))


const COUNT_FS := 15


func _count_w() -> float:
	if _is_wild():
		return 0.0
	var need := maxi(int(data.get("bp_need", 0)), 1)
	return UIKit.font_w("bold").get_string_size("%d/%d" % [need, need], HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FS).x


func _draw() -> void:
	var gk := _gem()
	var g: Dictionary = UITokens.gem(gk)
	var rc: Color = g["rim"]
	var body := _body()
	var pulse := 0.85 + 0.15 * sin(_t * 3.0)
	if glow > 0.0:
		var ga := (0.3 if not face_up else 0.4) * glow * pulse * (1.4 if rarity() in ["L", "M"] else 1.0)
		draw_texture_rect(UIKit.glow_texture(), body.grow(30 + CacheModels.tier(rarity()) * 6), false, Color(rc.r, rc.g, rc.b, ga))
	var pts := GemDraw.chamfer_rect(body, 10.0)
	for i in 4:
		var sp := PackedVector2Array()
		for q in pts:
			sp.append(q + Vector2(0, 2.0 + i * 1.6))
		draw_colored_polygon(sp, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.08))
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
		draw_line(Vector2(x, body.position.y + 8), Vector2(x + body.size.y * 0.5, body.end.y - 8), lat, 1.0, true)
		draw_line(Vector2(x + body.size.y * 0.5, body.position.y + 8), Vector2(x, body.end.y - 8), lat, 1.0, true)
	var inner := GemDraw.chamfer_rect(body.grow(-8.0), 7.0)
	draw_colored_polygon(GemDraw.chamfer_rect(Rect2(c - Vector2(36, 36), Vector2(72, 72)), 18.0), Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.95))
	var rim: Color = g["rim"]
	draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(70, 70), Vector2(140, 140)), false, Color(rim.r, rim.g, rim.b, 0.45))
	GemDraw.draw_mark(self, gk, c, minf(body.size.x * 0.3, 46.0))
	GemDraw.outline(self, inner, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.7), 1.0)
	GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)


## Face: the gem-ground card (Genshin construction): gradient + light pool, the machine render
## on a family-accent glow, the count on a cream chip, a cream footer with the name and the
## blueprint bar (cream track, amber fill, gold "!" when upgradable), inner rim, gold hairline
## and the gem-cut mark.
func _draw_face(body: Rect2, pts: PackedVector2Array, gk: String, g: Dictionary) -> void:
	var f := UIKit.font_w("bold")
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
	draw_colored_polygon(foot, UITokens.PAPER_1)
	draw_line(Vector2(body.position.x, seam), Vector2(body.end.x, seam), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9), 1.0, true)
	var nm := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else Loc.t("CUR_WILD")
	# Name: 16-19 px, a long name wraps to two lines (never shrunk to 13 px or clipped).
	var max_w := body.size.x - 14.0
	var fs := UIKit.fit_size(nm, max_w, 19, 16)
	var lines := MachineCard._name_lines(nm, f, fs, max_w)
	_name_two = lines.size() == 2 and not wild
	if _name_two:
		_text_c(f, lines[0], Vector2(cx, seam + 19.0), fs, UITokens.INK)
		_text_c(f, lines[1], Vector2(cx, seam + 19.0 + fs + 1.0), fs, UITokens.INK)
	else:
		var name_y := seam + (fh * 0.40 if not wild else fh * 0.62)
		_text_c(f, lines[0], Vector2(cx, name_y), fs, UITokens.INK)
	# Count chip (top-right of the art).
	var ct := "×%d" % int(data.get("count", 1))
	var cf := UIKit.font_w("extrabold")
	var cfs := 22 if body.size.x > 160.0 else 19
	var cw := cf.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x + 14.0
	var cr := Rect2(Vector2(body.end.x - cw - 6.0, seam - cfs - 16.0), Vector2(cw, cfs + 8.0))
	var cp := GemDraw.chamfer_rect(cr, 5.0)
	draw_colored_polygon(cp, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.94))
	GemDraw.outline(self, cp, UITokens.HAIRLINE, 1.0)
	draw_string(cf, Vector2(cr.position.x + 7.0, cr.end.y - 6.0), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, UITokens.GOLD_TEXT)
	if not wild:
		var br := _bar_rect()
		var need := maxi(int(data.get("bp_need", 0)), 1)
		var before := int(data.get("bp_before", 0))
		var after := int(data.get("bp_after", before))
		var shown := lerpf(float(before), float(after), bar_k)
		var up := bool(data.get("upgradable", false)) and bar_k >= 1.0
		var tp := GemDraw.chamfer_rect(br, 3.0)
		draw_colored_polygon(tp, UITokens.PAPER_3)
		var fk := clampf(shown / float(need), 0.0, 1.0)
		if fk > 0.0:
			var fr := Rect2(br.position, Vector2(maxf(br.size.x * fk, 6.0), br.size.y))
			var fp := GemDraw.chamfer_rect(fr, 3.0)
			var fc := PackedColorArray()
			for q in fp:
				fc.append(UITokens.CTA_HI.lerp(UITokens.CTA, (q.y - fr.position.y) / fr.size.y))
			draw_polygon(fp, fc)
		GemDraw.outline(self, tp, UITokens.HAIRLINE, 1.0)
		if _bar_hit > 0.0:
			draw_texture_rect(UIKit.glow_texture(), br.grow(12), false, Color(1.0, 0.82, 0.45, _bar_hit * 0.7))
		draw_string(UIKit.font_w("bold"), Vector2(body.end.x - 14.0 - _count_w(), br.get_center().y + 5.5), "%d/%d" % [int(round(shown)), need],
				HORIZONTAL_ALIGNMENT_RIGHT, _count_w(), COUNT_FS, UITokens.GOLD_TEXT if up else UITokens.INK_DIM)
		if up:
			# The gold "!" sits in the card's top-right corner over the art (as on the Arsenal),
			# never on the name / bar row.
			var bc := Vector2(body.end.x - 18.0, body.position.y + 18.0)
			draw_circle(bc + Vector2(0, 1.5), 14.0, Color(0.3, 0.18, 0.05, 0.25), true, -1.0, true)
			draw_circle(bc, 14.0, Color(1, 0.98, 0.92), true, -1.0, true)
			draw_circle(bc, 12.5, UITokens.NOTIFY, true, -1.0, true)
			_text_c(cf, "!", bc + Vector2(0, 7.0), 19, UIKit.BROWN)
	# Frame.
	var rim: Color = g["rim"]
	GemDraw.outline(self, GemDraw.chamfer_rect(body.grow(-3.0), 8.5), Color(rim.r, rim.g, rim.b, 0.7), 1.0)
	GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.5)
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
		var nf := UIKit.font_w("extrabold")
		var tag := Loc.t("REVEAL_NEW").to_upper()
		var nw := nf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var tr := Rect2(Vector2(body.get_center().x - nw * 0.5 - 10, body.position.y - 11), Vector2(nw + 20, 24))
		_over.draw_style_box(UIKit.lux("tag_new"), tr)
		_over.draw_string(nf, tr.position + Vector2(10, 17.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITokens.NEW_INK)
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
