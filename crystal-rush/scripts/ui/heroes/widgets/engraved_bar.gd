class_name HeroEngravedBar
extends Control
## The engraved channel bar of §9.1 (fragments, pity, Champion Level, Seals): a 10 px channel cut
## into the cream (dark top lip, light bottom lip, gold hairline), filled with the gem's UI hex
## (opal = a soft spectrum), facet tick marks across the channel, an optional keystone marker
## (e.g. the pity's soft start) and an optional label row above (caption left, value right).
## Value changes animate (ease-out); Reduce Motion snaps.
##   var b := HeroEngravedBar.make("L", 12, 30, 420)       # pity: 12 of 30, Топаз fill
##   b.label = "Топаз або краще ≤ 18"; b.value_text = "12 / 30"
##   b.ticks = [10.0, 20.0]; b.marker = 20.0                # tick marks + the soft-start keystone
##   b.tick_every = 1                                       # one notch per unit (fragment / facet bars)

var gem := "L":
	set(v):
		gem = HeroesText.gem_letter(v)
		queue_redraw()
var max_value := 1.0:
	set(v):
		max_value = maxf(v, 0.0001)
		queue_redraw()
var value := 0.0:
	set(v):
		value = v
		set_process(true)
var channel_h := 10.0
var ticks: Array = []            ## tick positions in value units
var tick_every := 0.0            ## > 0: a tick at every multiple (skipped when they would crowd)
var marker := -1.0               ## keystone above the channel at this value (-1 = none)
var label := "":
	set(v):
		label = v
		_resize()
var value_text := "":
	set(v):
		value_text = v
		_resize()
var label_size := 22
var _shown := -1.0


static func make(p_gem: String, p_value: float, p_max: float, width := 360.0) -> HeroEngravedBar:
	var b := HeroEngravedBar.new()
	b.gem = p_gem
	b.max_value = p_max
	b.value = p_value
	b.custom_minimum_size = Vector2(width, 0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._resize()
	return b


func _ready() -> void:
	_resize()
	if _shown < 0.0:
		_shown = _frac()


func _resize() -> void:
	var h := channel_h + 14.0
	if label != "" or value_text != "":
		h += label_size * 1.45
	custom_minimum_size.y = h
	queue_redraw()


func _frac() -> float:
	return clampf(value / max_value, 0.0, 1.0)


func _process(delta: float) -> void:
	var t := _frac()
	if _shown < 0.0 or UITokens.reduce_motion():
		_shown = t
	_shown = lerpf(_shown, t, minf(1.0, delta * 8.0))
	if absf(_shown - t) < 0.001:
		_shown = t
		set_process(false)
	queue_redraw()


## Fill colour of a gem bar (the UI hex, §2.1).
static func fill_color(g: String) -> Color:
	match HeroesText.gem_letter(g):
		"C": return Color("#A9B7C6")
		"R": return Color("#3FA9FF")
		"E": return Color("#9B5BEA")
		"L": return Color("#FFB52E")
		"M": return Color("#B48CFF")
	return UITokens.CTA


func _draw() -> void:
	var y := 0.0
	if label != "" or value_text != "":
		var fm := UIKit.font_w("medium")
		var fb := UIKit.font_w("bold")
		var base := label_size * 1.05
		if label != "":
			draw_string(fm, Vector2(0, base), label, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.72, label_size, UITokens.INK_DIM)
		if value_text != "":
			var vw := fb.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			draw_string(fb, Vector2(size.x - vw, base), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, UITokens.INK)
		y = label_size * 1.45
	var top := y + 7.0
	var r := Rect2(Vector2(2, top), Vector2(size.x - 4, channel_h))
	var ch := minf(channel_h * 0.5, 4.0)
	var pts := GemDraw.chamfer_rect(r, ch)
	# Channel: recessed cream with a dark upper lip and a light lower lip.
	draw_colored_polygon(pts, UITokens.PAPER_3)
	draw_line(Vector2(r.position.x + ch, r.position.y + 1.0), Vector2(r.end.x - ch, r.position.y + 1.0), Color(0.35, 0.26, 0.14, 0.28), 1.5, true)
	draw_line(Vector2(r.position.x + ch, r.end.y + 1.0), Vector2(r.end.x - ch, r.end.y + 1.0), Color(1, 1, 1, 0.85), 1.0, true)
	var frac := clampf(_shown if _shown >= 0.0 else _frac(), 0.0, 1.0)
	if frac > 0.002:
		var fr := Rect2(r.position + Vector2(1, 1.5), Vector2(maxf((r.size.x - 2) * frac, ch * 2.0), r.size.y - 3.0))
		var fp := GemDraw.chamfer_rect(fr, maxf(ch - 1.0, 1.0))
		var cols := PackedColorArray()
		var gl := HeroesText.gem_letter(gem)
		var fl: Array = UITokens.gem("opal")["flecks"]
		for p in fp:
			var ty := (p.y - fr.position.y) / maxf(fr.size.y, 1.0)
			var base := fill_color(gem)
			if gl == "M":
				var tx := clampf((p.x - fr.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0) * (fl.size() - 1)
				var i0 := int(floor(tx))
				base = (fl[i0] as Color).lerp(fl[mini(i0 + 1, fl.size() - 1)], tx - i0)
			cols.append(base.lightened(0.3).lerp(base.darkened(0.06), ty))
		draw_polygon(fp, cols)
		draw_line(fr.position + Vector2(ch, fr.size.y * 0.32), Vector2(fr.end.x - ch, fr.position.y + fr.size.y * 0.32), Color(1, 1, 1, 0.5), 1.0, true)
	# Facet tick marks (small rhombi cut across the channel).
	var tk: Array = ticks.duplicate()
	if tick_every > 0.0 and max_value / tick_every <= 40.0:
		var v := tick_every
		while v < max_value - 0.001:
			tk.append(v)
			v += tick_every
	for tv in tk:
		var x := r.position.x + r.size.x * clampf(float(tv) / max_value, 0.0, 1.0)
		var on := float(tv) <= value
		var h := channel_h * 0.62
		var w := 2.6
		var rh := PackedVector2Array([Vector2(x, r.get_center().y - h), Vector2(x + w, r.get_center().y), Vector2(x, r.get_center().y + h), Vector2(x - w, r.get_center().y)])
		draw_colored_polygon(rh, Color(1, 1, 1, 0.75) if on else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.9))
	GemDraw.outline(self, pts, UITokens.HAIRLINE, 1.2)
	if marker >= 0.0:
		var mx := r.position.x + r.size.x * clampf(marker / max_value, 0.0, 1.0)
		GemDraw.draw_keystone(self, Vector2(mx, r.position.y - 3.0), 11.0, 1.0, Color(1.0, 0.88, 0.6))
