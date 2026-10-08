class_name HeroWaxSeal
extends Control
## The «НОВИЙ» wax-seal stamp (heroes_design.md §9.1: NEW is a wax seal, never a red dot or a
## numeric badge): a pressed disc of honey-amber wax with soft irregular drips, an embossed inner
## ring and the word pressed into it, tilted a few degrees. `stamp()` plays the juicy press
## (drops in from 1.5x, squash, settle; Reduce Motion: a 0.2 s fade).
##   var s := HeroWaxSeal.make(64)          # text = HeroesText "HALL_NEW"
##   card.add_child(s); s.position = ...; s.stamp()

var text := "":
	set(v):
		text = v
		queue_redraw()
var tilt := -0.2
const WAX_HI := Color("#F2B35A")
const WAX := Color("#D27F2C")
const WAX_LO := Color("#9A5418")


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
	scale = Vector2(1.5, 1.5)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(0.9, 0.9), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var R := s * 0.44
	draw_set_transform(c, tilt, Vector2.ONE)
	# Wax blob: an irregular circle with three soft drips.
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + 0.045 * sin(a * 5.0 + 0.7) + 0.03 * sin(a * 9.0 + 2.1)
		pts.append(Vector2(cos(a), sin(a)) * R * k)
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(s * 0.02, s * 0.05))
	draw_colored_polygon(sh, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.26))
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y + R) / (2.0 * R), 0.0, 1.0)
		cols.append(WAX_HI.lerp(WAX, smoothstep(0.0, 0.6, t)).lerp(WAX_LO, smoothstep(0.55, 1.0, t)))
	draw_polygon(pts, cols)
	for d: Vector2 in [Vector2(0.62, 0.66), Vector2(-0.74, 0.5), Vector2(0.1, 0.92)]:
		draw_circle(d * R, R * 0.13, WAX.lerp(WAX_LO, 0.4), true, -1.0, true)
	GemDraw.outline(self, pts, Color(WAX_LO.r * 0.8, WAX_LO.g * 0.8, WAX_LO.b * 0.8, 0.7), 1.0)
	# Embossed inner ring (a dark groove under a light lip).
	draw_arc(Vector2(0, 1.0), R * 0.74, 0, TAU, 48, Color(0.4, 0.18, 0.04, 0.45), maxf(1.0, s * 0.03), true)
	draw_arc(Vector2.ZERO, R * 0.74, 0, TAU, 48, Color(1.0, 0.86, 0.62, 0.7), maxf(1.0, s * 0.018), true)
	# Wax sheen.
	draw_arc(Vector2.ZERO, R * 0.9, PI * 1.1, PI * 1.55, 16, Color(1, 0.95, 0.85, 0.55), maxf(1.0, s * 0.03), true)
	# The word, pressed in (dark groove offset under a light face).
	if text != "":
		var f := UIKit.font_w("extrabold")
		var fs := int(s * 0.2)
		while fs > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > R * 1.36:
			fs -= 1
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := Vector2(-tw * 0.5, f.get_ascent(fs) * 0.36)
		draw_string(f, base + Vector2(0, 1.2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.36, 0.16, 0.03, 0.7))
		draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#FFF1D6"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
