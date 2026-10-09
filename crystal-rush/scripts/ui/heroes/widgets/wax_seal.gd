class_name HeroWaxSeal
extends Control
## The «НОВИЙ» mark (heroes_design.md §9.1: never a red dot or a numeric badge), UI v3.1: from
## 76 px a chamfered glass tag (cream 0.95, one 1 dpx deep-gold line, the word in 22 px deep-gold
## caps after a small amber diamond), centred on the control; under 76 px only the §7.11 notify
## badge (the amber cut diamond on a cream disc). The class keeps its old name (call sites).
## `stamp()` plays a quiet press-in (from 1.25x, no squash; Reduce Motion: a 0.2 s fade).
##   var s := HeroWaxSeal.make(64)          # text = HeroesText "HALL_NEW"
##   card.add_child(s); s.position = ...; s.stamp()

var text := "":
	set(v):
		text = v
		queue_redraw()
var tilt := 0.0


static func make(px := 64.0, p_text := "") -> HeroWaxSeal:
	var s := HeroWaxSeal.new()
	s.text = p_text if p_text != "" else HeroesText.t("HALL_NEW")
	s.custom_minimum_size = Vector2(px, px)
	s.size = Vector2(px, px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## The press-in beat.
func stamp(delay := 0.0) -> void:
	pivot_offset = size * 0.5
	if UITokens.reduce_motion():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)
		return
	scale = Vector2(1.25, 1.25)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The drawn mark's size (the tag is wider than the square control; the badge smaller): callers
## that align it to an edge use this.
func drawn_size() -> Vector2:
	var s := minf(size.x, size.y)
	if s < 76.0 or text == "":
		var d := clampf(s * 0.42, 18.0, 30.0)
		return Vector2(d, d) * 1.24
	var f := UIKit.font_w("medium")
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 2.0 * maxi(text.length() - 1, 0)
	return Vector2(tw + 12.0 + 10.0 + 28.0, 36.0)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	if tilt != 0.0:
		draw_set_transform(c, tilt, Vector2.ONE)
		c = Vector2.ZERO
	# UI v3.1: no wax, no orange. Small sizes (cards S / M, history rows) carry the notify badge of
	# §7.11 (an amber cut diamond); from 64 px a glass tag with the word in deep-gold caps (22 px),
	# one 1 dpx deep-gold line and the same amber diamond as its key.
	var f := UIKit.font_w("medium")
	var fs := 22
	var track := 2
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + track * maxi(text.length() - 1, 0)
	if s < 76.0 or text == "":
		var d := clampf(s * 0.42, 18.0, 30.0)
		draw_circle(c, d * 0.62, HeroV3.a(UITokens.PAPER_0, 0.9), true, -1.0, true)
		draw_arc(c, d * 0.62, 0, TAU, 40, HeroV3.a(HeroV3.DEEP, 0.6), HeroV3.lp(1.0), true)
		GemDraw.draw_diamond(self, c, d * 0.78, UITokens.key_gem(), UITokens.key_gem_edge())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var h := 36.0
	var dz := 12.0
	var w := tw + dz + 10.0 + 28.0
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	HeroV3.glass(self, r, UITokens.CHAMFER_XS, 0.95, HeroV3.DEEP, 0.9, 0.7, 0.12)
	GemDraw.draw_diamond(self, Vector2(r.position.x + 14.0 + dz * 0.5, r.get_center().y), dz, UITokens.key_gem(), UITokens.key_gem_edge())
	var x := r.position.x + 14.0 + dz + 10.0
	var y := r.get_center().y + f.get_ascent(fs) * 0.36
	for ch in text:
		draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.GOLD_TEXT_GLASS)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + track
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
