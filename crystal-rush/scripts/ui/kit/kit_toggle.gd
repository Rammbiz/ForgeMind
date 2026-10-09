class_name KitToggle
## UI v3.1 slim settings toggle (spec §7.8): a 56 x 28 track with 6 px 45-degree chamfers and a
## 1 dpx line; off = glass @ 0.5 with a 1 dpx HAIRLINE @ 0.7; on = a thinner amber fill (CTA @
## 0.92, inset 3 px from the line) with a 1 dpx CTA_LO line; the knob is a 22 px #FFFDF8 disc with a
## 1 dpx LINE_GOLD edge and a soft shadow @ 0.12. Travel TRAVEL s ease-out (the caller animates
## `k`). Hit area: the caller's whole row.
##   KitToggle.draw_toggle(self, Rect2(Vector2.ZERO, size), k)   # k 0 = off .. 1 = on

const SIZE := Vector2(56, 28)
const TRAVEL := 0.12


## Draws the toggle at `k` (0..1), right-aligned and vertically centred in `r`. `alpha` dims it.
static func draw_toggle(ci: CanvasItem, r: Rect2, k: float, alpha := 1.0) -> void:
	k = clampf(k, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var tr := Rect2(Vector2(r.end.x - SIZE.x, r.position.y + roundf((r.size.y - SIZE.y) * 0.5)), SIZE)
	var track := GemDraw.chamfer_rect(tr, 6.0)
	var off_fill := Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.5 * alpha)
	ci.draw_colored_polygon(track, off_fill)
	if e > 0.01:
		var c := UITokens.CTA if not UITokens.calm_cta() else UITokens.KEY_INK
		var fr := tr.grow(-3.0)
		ci.draw_colored_polygon(GemDraw.chamfer_rect(fr, 4.0), Color(c.r, c.g, c.b, 0.92 * e * alpha))
	var hl := UITokens.HAIRLINE
	var on_line := UITokens.CTA_LO if not UITokens.calm_cta() else UITokens.KEY_INK
	var line := Color(hl.r, hl.g, hl.b, 0.7).lerp(Color(on_line.r, on_line.g, on_line.b, 1.0), e)
	line.a *= alpha
	GemDraw.outline(ci, track, line, UIKit.line_px(1.0))
	var kr := 11.0
	var kc := Vector2(lerpf(tr.position.x + 3.0 + kr, tr.end.x - 3.0 - kr, e), tr.get_center().y)
	var sc := UITokens.SCRIM
	ci.draw_texture_rect(UIKit.glow_texture(), Rect2(kc - Vector2(kr, kr) * 1.5 + Vector2(0, 2), Vector2(kr, kr) * 3.0), false, Color(sc.r, sc.g, sc.b, 0.12 * alpha))
	ci.draw_circle(kc, kr, Color(1.0, 0.992, 0.973, alpha), true, -1.0, true)
	var lg := UITokens.LINE_GOLD
	ci.draw_arc(kc, kr - UIKit.px(0.5), 0, TAU, 40, Color(lg.r, lg.g, lg.b, lg.a * alpha), UIKit.line_px(1.0), true)
