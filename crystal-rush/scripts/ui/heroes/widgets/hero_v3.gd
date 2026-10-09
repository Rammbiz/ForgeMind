class_name HeroV3
## UI v3.1 "porcelain glass" drawing helpers for the Heroes / Summon custom-drawn widgets (spec
## ui_v3_spec.md §3, §4.3, §7.3-§7.5): the same materials the kit paints through KitBox, for the
## widgets that draw their own polygons (chips, tags, discs, plates on the art).
##  * every frame is ONE 1 dpx gold line (UIKit.line_px: 1.25 dpx at 540-class densities) with a
##    1 dpx light line directly inside it (never a second gold band, never a dark outline);
##  * bodies are translucent cream (flat glass); text sits on >= 0.94 (GLASS_TEXT_A);
##  * one soft halo instead of stacked drop polygons, and none under small translucent chips;
##  * 45-degree chamfers, never pills; amber only on the key verbs (KitCTA).
##   HeroV3.glass(self, rect, 8.0)                      # a glass plate with its 1 dpx frame
##   HeroV3.glass(self, rect, 8.0, 0.94, HeroV3.DEEP)   # a text plate with a deep-gold edge
##   HeroV3.disc(self, c, 22.0)                         # a glass disc with one 1 dpx ring

const GOLD := Color(0.788, 0.659, 0.416)          ## LINE_GOLD (#C9A86A)
const DEEP := Color(0.659, 0.514, 0.247)          ## LINE_GOLD_DEEP (#A8833F)


static func lp(n := 1.0) -> float:
	return UIKit.line_px(n)


static func a(c: Color, al: float) -> Color:
	return Color(c.r, c.g, c.b, al)


## Closed 1 dpx line along `pts` (antialiased: chamfers are diagonals).
static func frame(ci: CanvasItem, pts: PackedVector2Array, col: Color, w_dpx := 1.0) -> void:
	GemDraw.outline(ci, pts, col, lp(w_dpx))


## The 1 dpx inner light line of a chamfered box: bright along the top, fading down the sides.
static func light_line(ci: CanvasItem, rect: Rect2, cham: float, top_a := 0.62) -> void:
	if top_a <= 0.0:
		return
	var d := UIKit.px(1.0) + lp(1.0) * 0.5
	var r := rect.grow(-d)
	var pts := GemDraw.chamfer_rect(r, maxf(cham - d * 0.6, 0.0))
	var loop := pts.duplicate()
	loop.append(pts[0])
	var cols := PackedColorArray()
	for p in loop:
		var t := clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)
		cols.append(Color(1, 1, 1, top_a * lerpf(1.0, 0.22, t)))
	ci.draw_polyline_colors(loop, cols, UIKit.px(1.0), true)


## A flat glass body: translucent cream (`fill_a` at the top, a touch more at the bottom), one 1 dpx
## line in `line` (alpha `line_a`; 0 = frameless) and the inner light line. `halo` > 0 adds one soft
## shadow under it (knocked out under the body: only its rim shows around a translucent box).
static func glass(ci: CanvasItem, rect: Rect2, cham := 8.0, fill_a := 0.84, line := GOLD, line_a := 0.78,
		light_a := 0.62, halo := 0.0, tint := UITokens.PAPER_0) -> PackedVector2Array:
	var pts := GemDraw.chamfer_rect(rect, cham)
	if halo > 0.0:
		shadow(ci, rect, halo)
	var bot := tint.lerp(UITokens.PAPER_1, 0.6)
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
		cols.append(a(tint.lerp(bot, t), minf(1.0, fill_a + 0.04 * t)))
	ci.draw_polygon(pts, cols)
	light_line(ci, rect, cham, light_a)
	if line_a > 0.0:
		frame(ci, pts, a(line, line_a))
	return pts


## One soft slate halo under `rect` (UIKit.glow_texture), offset a little down. Quiet (<= 0.14).
static func shadow(ci: CanvasItem, rect: Rect2, strength := 0.1) -> void:
	var g := rect.grow_individual(rect.size.x * 0.06 + 6.0, 2.0, rect.size.x * 0.06 + 6.0, 10.0)
	g.position.y += 3.0
	var s := UITokens.SCRIM
	ci.draw_texture_rect(UIKit.glow_texture(), g, false, Color(s.r, s.g, s.b, strength))


## A glass disc: cream at `fill_a`, one 1 dpx gold ring and a 1 dpx light arc on the lit side.
static func disc(ci: CanvasItem, c: Vector2, R: float, fill_a := 0.86, ring := GOLD, ring_a := 0.8, halo := 0.0) -> void:
	if halo > 0.0:
		shadow(ci, Rect2(c - Vector2(R, R), Vector2(R, R) * 2.0), halo)
	ci.draw_circle(c, R, a(UITokens.PAPER_0, fill_a), true, -1.0, true)
	var lw := lp(1.0)
	ci.draw_arc(c, R - UIKit.px(1.0) - lw * 0.5, PI * 1.05, PI * 1.95, 24, Color(1, 1, 1, 0.7), UIKit.px(1.0), true)
	ci.draw_arc(c, R - lw * 0.5, 0, TAU, 56, a(ring, ring_a), lw, true)


## A fading straight 1 dpx rule (outer 24 % fades out) with an optional 9 px centre diamond.
static func rule(ci: CanvasItem, x0: float, x1: float, y: float, col := GOLD, al := 0.55, diamond := false) -> void:
	var py := GemDraw.pixel_y(ci, y)
	var w := x1 - x0
	var pts := PackedVector2Array([Vector2(x0, py), Vector2(x0 + w * 0.24, py), Vector2(x1 - w * 0.24, py), Vector2(x1, py)])
	var cols := PackedColorArray([a(col, 0.0), a(col, al), a(col, al), a(col, 0.0)])
	ci.draw_polyline_colors(pts, cols, lp(1.0))
	if diamond:
		GemDraw.draw_diamond(ci, Vector2((x0 + x1) * 0.5, py), 9.0, UITokens.TOPAZ, Color("#A8662A"))


## Text drawn centred in `r` (no outline, no emboss), shrunk to fit down to `min_fs`.
static func text_in(ci: CanvasItem, r: Rect2, txt: String, fs: int, col: Color, weight := "medium", min_fs := 18, tracking := 0) -> void:
	var f := UIKit.font_w(weight)
	var s := fs
	while s > min_fs and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + tracking * txt.length() > r.size.x:
		s -= 1
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + tracking * maxi(txt.length() - 1, 0)
	var y := r.get_center().y + f.get_ascent(s) * 0.36
	if tracking <= 0:
		ci.draw_string(f, Vector2(r.get_center().x - tw * 0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
		return
	var x := r.get_center().x - tw * 0.5
	for ch in txt:
		ci.draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + tracking


## A single word wider than `w` at `fs` px (bold font `f`), broken once with a hyphen at a syllable
## edge (after a vowel, before a consonant; the left part >= 4 letters) so it keeps the 22 px type
## floor instead of shrinking: «Сонцесходження» -> «Сонце-» / «сходження». Returns [word] when it
## fits (a 6 px tolerance) or no break fits; else [left + "-", right].
static func hyphen_split(word: String, f: Font, fs: int, w: float) -> PackedStringArray:
	if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w + 6.0:
		return PackedStringArray([word])
	const V := "аеєиіїоуюяАЕЄИІЇОУЮЯaeiouy"
	var best := PackedStringArray([word])
	var best_w := INF
	for i in range(4, word.length() - 3):
		if not (V.contains(word[i - 1]) and not V.contains(word[i]) and word[i].to_lower() != word[i].to_upper()):
			continue
		var a := word.substr(0, i) + "-"
		var b := word.substr(i)
		var wa := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wb := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if wa <= w + 6.0 and wb <= w + 6.0:
			# The first (leftmost) break that fits: compounds split at their seam (Сонце-сходження).
			return PackedStringArray([a, b])
		if maxf(wa, wb) < best_w:
			best_w = maxf(wa, wb)
			best = PackedStringArray([a, b])
	return best
