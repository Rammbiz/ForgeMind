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
	_back = _shader_rect(0)
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
	_frame.visible = true
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


func _bar_rect() -> Rect2:
	return Rect2(Vector2(18, size.y - 40), Vector2(size.x - 36, 18))


func _draw() -> void:
	var r := rarity()
	var rc := color()
	var body := Rect2(Vector2(4, 6), size - Vector2(8, 12))
	var pulse := 0.85 + 0.15 * sin(_t * 3.0)
	if glow > 0.0:
		var ga := (0.32 if not face_up else 0.42) * glow * pulse * (1.4 if r in ["L", "M"] else 1.0)
		draw_texture_rect(UIKit.glow_texture(), body.grow(34 + CacheModels.tier(r) * 6), false, Color(rc.r, rc.g, rc.b, ga))
	if not face_up:
		return
	_draw_face(body, rc, r)


## Over the animated frame: the flip flash, the NEW ribbon and the blueprint sparks.
func _draw_over() -> void:
	if not face_up:
		return
	var body := Rect2(Vector2(4, 6), size - Vector2(8, 12))
	var f := UIKit.font(true)
	if _flash > 0.0:
		_over.draw_style_box(UIKit.box(Color(1, 1, 1, _flash * 0.85), Color(0, 0, 0, 0), 20, 0, 0, Vector2.ZERO), body)
	if bool(data.get("new", false)):
		var tag := Loc.t("REVEAL_NEW")
		var nw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var tr := Rect2(Vector2(body.get_center().x - nw * 0.5 - 12, body.position.y - 12), Vector2(nw + 24, 30))
		_over.draw_style_box(UIKit.box(Color(1.0, 0.34, 0.3), Color(1, 0.92, 0.7), 13, 2, 3, Vector2.ZERO), tr)
		_over.draw_string(f, tr.position + Vector2(12, 22), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1))
	for s in _sparks:
		if float(s["t"]) < 0.0:
			continue
		var k := clampf(float(s["t"]) / 0.4, 0.0, 1.0)
		var a: Vector2 = s["from"]
		var b: Vector2 = s["to"]
		var mid := (a + b) * 0.5 + Vector2(float(s["bend"]), -40.0)
		var p := a.lerp(mid, k).lerp(mid.lerp(b, k), k)
		var sz := 16.0 * (1.0 - k * 0.5)
		_over.draw_texture_rect(UIKit.glow_texture(), Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), false, Color(0.55, 0.85, 1.0, 0.9))
		_over.draw_circle(p, 3.0, Color(1, 1, 1))


func _draw_face(body: Rect2, rc: Color, _r: String) -> void:
	var f := UIKit.font(true)
	MachineCard.grad_box(self, body, rc.lightened(0.35), rc.darkened(0.5), 20)
	var inner := body.grow(-5)
	MachineCard.grad_box(self, inner, rc.darkened(0.45).lerp(Color(0.1, 0.12, 0.28), 0.4), Color(0.025, 0.03, 0.08), 16)
	var id := str(data.get("id", ""))
	var wild := bool(data.get("wild", false)) or id == ""
	# Art window: a family-accent glow behind the machine render.
	var acc := UITokens.family(ArsenalData.family_of(id)) if not wild else Color(0.75, 0.5, 1.0)
	var aw := inner.size.x - 20
	var art := Rect2(inner.position + Vector2(10, 12), Vector2(aw, aw * 0.86))
	draw_texture_rect(UIKit.glow_texture(), art.grow(10), false, Color(acc.r, acc.g, acc.b, 0.5))
	if wild:
		Icons.draw_icon(self, "wild", art.grow(-aw * 0.16))
	elif _tex:
		var s := art.size.x * 1.12
		draw_texture_rect(_tex, Rect2(art.get_center() - Vector2(s, s) * 0.5 + Vector2(0, 2), Vector2(s, s)), false)
	else:
		Icons.draw_icon(self, id, art.grow(-aw * 0.14))
	# Name.
	var nm := Loc.t(str((ArsenalData.MACHINES[id] as Dictionary)["name"])) if ArsenalData.MACHINES.has(id) else Loc.t("CUR_WILD")
	var fs := UIKit.fit_size(nm, inner.size.x - 14, 22, 17)
	var ny := art.end.y + 26
	if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > inner.size.x - 14 and nm.contains(" "):
		# Two lines (Плазмова / гармата) rather than a clipped name.
		var cut := nm.find(" ", nm.length() / 2 - 2)
		cut = cut if cut > 0 else nm.find(" ")
		var l1 := nm.substr(0, cut)
		var l2 := nm.substr(cut + 1)
		var f2 := mini(UIKit.fit_size(l1, inner.size.x - 14, 20, 14), UIKit.fit_size(l2, inner.size.x - 14, 20, 14))
		_text_c(f, l1, Vector2(inner.get_center().x, ny - 12), f2, Color(1, 1, 1), 5)
		_text_c(f, l2, Vector2(inner.get_center().x, ny + 7), f2, Color(1, 1, 1), 5)
		ny += 12
	else:
		_text_c(f, nm, Vector2(inner.get_center().x, ny), fs, Color(1, 1, 1), 5)
	# Count.
	var cnt := "×%d" % int(data.get("count", 1))
	_text_c(f, cnt, Vector2(inner.get_center().x, ny + 30), 28 if ny > art.end.y + 30 else 30, rc.lightened(0.45), 6)
	# Blueprint bar.
	if not wild:
		var br := _bar_rect()
		var need := maxi(int(data.get("bp_need", 0)), 1)
		var before := int(data.get("bp_before", 0))
		var after := int(data.get("bp_after", before))
		var shown := lerpf(float(before), float(after), bar_k)
		var up := bool(data.get("upgradable", false)) and bar_k >= 1.0
		draw_style_box(UIKit.box(Color(0.0, 0.0, 0.03, 0.9), Color(1, 1, 1, 0.18), 9, 2, 0, Vector2.ZERO), br)
		var fk := clampf(shown / float(need), 0.0, 1.0)
		if fk > 0.0:
			var top := Color(0.55, 1.0, 0.5) if up else Color(0.5, 0.82, 1.0)
			var bot := Color(0.2, 0.7, 0.25) if up else Color(0.15, 0.45, 0.95)
			MachineCard.grad_box(self, Rect2(br.position + Vector2(2, 2), Vector2((br.size.x - 4) * fk, br.size.y - 4)), top, bot, 7)
		if _bar_hit > 0.0:
			draw_texture_rect(UIKit.glow_texture(), br.grow(12), false, Color(0.6, 0.9, 1.0, _bar_hit * 0.7))
		var bt := "%d/%d" % [int(round(shown)), need]
		_text_c(f, bt, Vector2(br.get_center().x, br.end.y - 2), 15, Color(1, 1, 1), 4)
		if up:
			Icons.draw_icon(self, "arrow_up", Rect2(Vector2(br.end.x - 8, br.position.y - 14), Vector2(28, 28)))


func _text_c(f: Font, s: String, at: Vector2, fs: int, col: Color, ol: int) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(at.x - w * 0.5, at.y)
	draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color(0, 0.01, 0.05))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
