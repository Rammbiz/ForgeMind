class_name HeroEngravedBar
extends Control
## The progress bar of §9.1 (fragments, pity, Champion Level, Seals), drawn to UI v3.1 §7.5: a 1 dpx
## hairline frame around a glass track, filled flat with the gem's UI hex (opal = a soft spectrum),
## 1 dpx facet notches, a 9 px diamond at the end when full, an optional diamond marker above
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
var label_color := UITokens.INK_DIM_GLASS   ## INK on glass over the night (the label carries data)
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
		"C": return Color("#8196AD")   # fixer: a slate-silver table, so a full quartz bar reads on the track (>= 1.6:1)
		"R": return Color("#3FA9FF")
		"E": return Color("#9B5BEA")
		"L": return Color("#FFB52E")
		"M": return Color("#B48CFF")
		"N": return UITokens.BAR_INK
	return UITokens.bar_fill()


## "N" = the neutral bar (Champion Level, the pity countdown): ink navy with a deep-gold cap tick
## under the porcelain key style (amber only under --cta=amber).
static func neutral() -> String:
	return "N" if UITokens.calm_cta() else "L"


func _draw() -> void:
	var y := 0.0
	if label != "" or value_text != "":
		var fm := UIKit.font_w("medium")
		var fb := UIKit.font_w("bold")
		var base := label_size * 1.05
		if label != "":
			draw_string(fm, Vector2(0, base), label, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.72, label_size, label_color)
		if value_text != "":
			var vw := fb.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			draw_string(fb, Vector2(size.x - vw, base), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, UITokens.INK)
		y = label_size * 1.45
	# v3.1 progress (§7.5): a 1 dpx hairline frame, a glass track 2 px inside it, a flat gem fill
	# (gem identity; 2 stops) with a 1 dpx table light, 45-degree chamfered ends (never a pill),
	# 1 dpx facet notches; a full bar lights one 9 px diamond at its end.
	var top := y + 7.0
	var r := Rect2(Vector2(2, top), Vector2(size.x - 4, channel_h))
	# 45-degree ends never melt into a pill at small heights: the frame chamfer stays >= 3 px.
	var ch := clampf(channel_h * 0.5, 3.0, 4.0)
	var pts := GemDraw.chamfer_rect(r, ch)
	draw_colored_polygon(pts, HeroV3.a(UITokens.PAPER_0, 0.5))
	var tr := r.grow(-2.0)
	var tch := clampf(ch - 1.0, minf(2.0, tr.size.y * 0.5), tr.size.y * 0.5)
	draw_colored_polygon(GemDraw.chamfer_rect(tr, tch), HeroV3.a(UITokens.PAPER_3, 0.5))
	var frac := clampf(_shown if _shown >= 0.0 else _frac(), 0.0, 1.0)
	if frac > 0.002:
		var fr := Rect2(tr.position, Vector2(maxf(tr.size.x * frac, tch * 2.0 + 1.0), tr.size.y))
		var fp := GemDraw.chamfer_rect(fr, tch)
		var cols := PackedColorArray()
		var gl := HeroesText.gem_letter(gem)
		var fl: Array = UITokens.gem("opal")["flecks"]
		for p in fp:
			var ty := (p.y - fr.position.y) / maxf(fr.size.y, 1.0)
			var base := fill_color(gem)
			if gl == "M":
				var tx := clampf((p.x - fr.position.x) / maxf(tr.size.x, 1.0), 0.0, 1.0) * (fl.size() - 1)
				var i0 := int(floor(tx))
				# The pastel spectrum, a step deeper so it reads on the cream track.
				base = (fl[i0] as Color).lerp(fl[mini(i0 + 1, fl.size() - 1)], tx - i0).darkened(0.16)
			if gl == "N":
				cols.append(UITokens.bar_hi().lerp(UITokens.bar_lo(), ty))
			else:
				cols.append(base.lightened(0.18).lerp(base.darkened(0.04), ty))
		draw_polygon(fp, cols)
		if fr.size.y >= 5.0:
			var ly := GemDraw.pixel_y(self, fr.position.y + 1.0)
			draw_line(Vector2(fr.position.x + tch, ly), Vector2(fr.end.x - tch, ly), Color(1, 0.98, 0.92, 0.22 if gl == "N" else 0.6), -1.0)
		if gl == "N" and frac < 0.999:
			var cx := roundf(fr.end.x) - UIKit.px(0.5)
			draw_line(Vector2(cx, fr.position.y), Vector2(cx, fr.end.y), UITokens.LINE_GOLD_DEEP, UIKit.px(1.0))
	# Facet notches: 1 dpx light cuts across the fill, hairline cuts across the empty track.
	var tk: Array = ticks.duplicate()
	if tick_every > 0.0 and max_value / tick_every <= 40.0:
		var v := tick_every
		while v < max_value - 0.001:
			tk.append(v)
			v += tick_every
	var cy := r.get_center().y
	var nh := channel_h * 0.5 - 1.0
	var lw := UIKit.px(1.0)
	for tv in tk:
		var x := roundf(tr.position.x + tr.size.x * clampf(float(tv) / max_value, 0.0, 1.0)) + lw * 0.5
		var on := float(tv) <= value
		draw_line(Vector2(x, cy - nh), Vector2(x, cy + nh), Color(1, 1, 1, 0.7) if on else HeroV3.a(UITokens.HAIRLINE, 0.6), lw)
	HeroV3.frame(self, pts, HeroV3.a(UITokens.HAIRLINE, 0.8))
	if frac >= 0.999:
		if HeroesText.gem_letter(gem) == "N":
			GemDraw.draw_diamond(self, Vector2(r.end.x, cy), 9.0, UITokens.KEY_INK, UITokens.KEY_GOLD)
		else:
			GemDraw.draw_diamond(self, Vector2(r.end.x, cy), 9.0, fill_color(gem), fill_color(gem).darkened(0.35))
	if marker >= 0.0:
		# The keystone is SEATED on the bar: a 1 dpx deep-gold notch through the channel and a 7 px
		# diamond centred on the frame's top line (never floating above it as a stray glyph).
		var mx := roundf(r.position.x + r.size.x * clampf(marker / max_value, 0.0, 1.0)) + lw * 0.5
		mx = clampf(mx, r.position.x + ch + 3.0, r.end.x - ch - 3.0)
		draw_line(Vector2(mx, r.position.y), Vector2(mx, r.end.y), HeroV3.a(HeroV3.DEEP, 0.9), lw)
		GemDraw.draw_diamond(self, Vector2(mx, r.position.y), 7.0, UITokens.PAPER_0, HeroV3.DEEP)
