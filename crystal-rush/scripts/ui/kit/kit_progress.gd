class_name KitProgress
extends Control
## UI v3.1 progress bar (§7.5): a 1 dpx hairline frame, a glass track, an amber fill with a 1 dpx
## table light; no end ticks: a 9 px topaz diamond lights at the end when full. `tiles` > 0 draws it as
## bridge tiles (chamfered crystal planks that light up one by one). Value changes animate.
## Optional `text` is drawn to the right ("12 / 40").

var max_value := 1.0
var value := 0.0:
	set(v):
		value = v
		set_process(true)
var tiles := 0
var bar_h := 12.0
var fill_color := UITokens.bar_fill()
var text := "":
	set(v):
		text = v
		queue_redraw()
var _shown := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shown < 0.0:
		_shown = _frac()


func _frac() -> float:
	return clampf(value / maxf(max_value, 0.0001), 0.0, 1.0)


func _process(delta: float) -> void:
	var t := _frac()
	if _shown < 0.0:
		_shown = t
	_shown = lerpf(_shown, t, minf(1.0, delta * 9.0))
	if absf(_shown - t) < 0.001:
		_shown = t
		set_process(false)
	queue_redraw()


## The neutral ink bar (porcelain): the fill is the token, not a gem colour the caller chose.
func _ink() -> bool:
	return UITokens.calm_cta() and fill_color == UITokens.BAR_INK


func _draw() -> void:
	var tw := 0.0
	var f := UIKit.font_w("medium")
	var fs := int(clampf(bar_h * 1.6, 16.0, 22.0))
	if text != "":
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
	var tick := bar_h * 1.15
	var r := Rect2(Vector2(tick * 0.5, (size.y - bar_h) * 0.5), Vector2(size.x - tw - tick, bar_h))
	var ch := minf(bar_h * 0.5, 5.0)
	var frac := clampf(_shown if _shown >= 0.0 else _frac(), 0.0, 1.0)
	if tiles > 0:
		var gap := 3.0
		var tw1 := (r.size.x - gap * (tiles - 1)) / tiles
		var lit := frac * tiles
		for i in tiles:
			var tr := Rect2(Vector2(r.position.x + i * (tw1 + gap), r.position.y), Vector2(tw1, bar_h))
			var pts := GemDraw.chamfer_rect(tr, minf(ch, tw1 * 0.3))
			var k := clampf(lit - i, 0.0, 1.0)
			draw_colored_polygon(pts, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.55))
			if k > 0.0:
				var on := UITokens.PAPER_3.lerp(fill_color, k)
				var cols := PackedColorArray()
				for p in pts:
					cols.append(on.lightened(0.28 * (1.0 - (p.y - tr.position.y) / bar_h)))
				draw_polygon(pts, cols)
				draw_line(tr.position + Vector2(3, bar_h * 0.32), Vector2(tr.end.x - 3, tr.position.y + bar_h * 0.32), Color(1, 1, 1, 0.5 * k), UIKit.px(1.0), true)
			GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.7), UIKit.line_px(1.0))
	else:
		# v3.1 (§7.5): a 1 dpx hairline frame around a glass track (2 px inside it), an amber
		# fill with a 1 dpx table light.
		var pts := GemDraw.chamfer_rect(r, ch)
		var p0 := UITokens.PAPER_0
		draw_colored_polygon(pts, Color(p0.r, p0.g, p0.b, 0.5))
		var tr := r.grow(-2.0)
		var tch := minf(ch, tr.size.y * 0.5)
		draw_colored_polygon(GemDraw.chamfer_rect(tr, tch), Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.45))
		if frac > 0.002:
			var fr := Rect2(tr.position, Vector2(maxf(tr.size.x * frac, tch * 2.0), tr.size.y))
			var fp := GemDraw.chamfer_rect(fr, tch)
			var cols := PackedColorArray()
			var ink := _ink()
			for p in fp:
				var t := (p.y - fr.position.y) / maxf(fr.size.y, 1.0)
				if ink:
					cols.append(UITokens.bar_hi().lerp(UITokens.bar_lo(), t))
				else:
					cols.append(fill_color.lightened(0.3).lerp(fill_color.darkened(0.06), t))
			draw_polygon(fp, cols)
			if fr.size.y >= 5.0:
				var ly := GemDraw.pixel_y(self, fr.position.y + 1.0)
				draw_line(Vector2(fr.position.x + tch, ly), Vector2(fr.end.x - tch, ly), Color(1, 0.98, 0.9, 0.22 if ink else 0.6), -1.0)
			if ink and frac < 0.999:
				# The 1 dpx deep-gold cap tick at the fill's end.
				var cx := roundf(fr.end.x) - UIKit.px(0.5)
				draw_line(Vector2(cx, fr.position.y), Vector2(cx, fr.end.y), UITokens.LINE_GOLD_DEEP, UIKit.px(1.0))
		GemDraw.outline(self, pts, Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.8), UIKit.line_px(1.0))
	# v3: no crystal ticks on the ends (ornament only where it means something): a full bar
	# earns one small topaz diamond at its end.
	if frac >= 0.999:
		GemDraw.draw_diamond(self, Vector2(r.end.x, r.get_center().y), 9.0, UITokens.key_gem(), UITokens.key_gem_edge())
	if text != "":
		draw_string(f, Vector2(r.end.x + tick * 0.5 + 8.0, size.y * 0.5 + f.get_ascent(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITokens.INK)
