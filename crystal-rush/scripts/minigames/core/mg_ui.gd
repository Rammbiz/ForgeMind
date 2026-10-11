class_name MinigameUI
## Shared drawing for the Fair's mini-games (porcelain and gold, ui_v3_spec.md): the still backdrop, the three
## result stars, porcelain plates and the card back. Code art only; nothing here animates on its own (the hub
## does not "breathe"): the only motion is a one-time 0.35 s pop when something appears.

const STAR_FILL := Color("#D9AE57")         ## matte gold: an earned star (flat, one lit facet, no gloss)
const STAR_EMPTY := Color("#EFE9DE")        ## pale porcelain: a star not earned (a hairline outline only)
const POP := 0.35                           ## the one quick moment (seconds)


## A full-rect still backdrop: warm porcelain light from the top, a faint gold rule band near the top and a
## quiet lattice of 1 px diamonds at the bottom edge (our own pattern). Static, drawn once.
static func backdrop() -> Control:
	return _Backdrop.new()


## Three stars (`stars` lit of 3). `pop` = the lit stars appear one after another (0.35 s each, once).
static func stars(n: int, size := 64.0, pop := true) -> Stars:
	var s := Stars.new()
	s.custom_minimum_size = Vector2(size * 3.0 + size * 0.5, size)
	s.star_px = size
	s.lit = clampi(n, 0, 3)
	s.animate = pop
	return s


## A five-point star (outer radius r) at `c`: matte fill + 1 dpx gold line.
static func draw_star(ci: CanvasItem, c: Vector2, r: float, filled: bool, alpha := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + float(i) * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.47
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var fill := STAR_FILL if filled else STAR_EMPTY
	ci.draw_colored_polygon(pts, Color(fill.r, fill.g, fill.b, alpha))
	var line := UITokens.LINE_GOLD_DEEP if filled else Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.85)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(line.r, line.g, line.b, line.a * alpha), UIKit.line_px(1.0), true)
	if filled:
		# One flat lit facet (upper-left half of the top point), no gloss.
		ci.draw_colored_polygon(PackedVector2Array([c, pts[9], pts[0]]), Color(1, 1, 1, 0.16 * alpha))


## A porcelain plate (the kit "plate" lux) holding one label; `size` = font size. `width` > 0 = the plate is that
## wide and the text wraps inside it (never cut); 0 = one line, as wide as the text.
static func plate(text: String, size := 24, color := UITokens.INK, width := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lux("plate", Vector2(18, 8)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 36.0, 0)
	p.add_child(l)
	p.set_meta("label", l)
	return p


## The display name of a hero or champion id (Loc HERO_<ID> / CHAMP_<ID>; the id itself when unknown).
static func char_name(id: String) -> String:
	var kind := Roster.kind_of(id)
	if kind == Roster.KIND_HERO:
		return Loc.t("HERO_" + id.to_upper())
	if kind == Roster.KIND_CHAMPION:
		return Loc.t("CHAMP_" + id.to_upper())
	return id


## The native gem letter of a hero or champion ("C" when unknown).
static func char_gem(id: String) -> String:
	return Roster.native(id) if Roster.kind_of(id) != "" else "C"


## A wrapped body label (never cut, never «…»).
static func body(text: String, size := 24, color := UITokens.INK, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.custom_minimum_size = Vector2(10, 0)
	return l


## The shared card back (porcelain with a gold chamfer frame and our own diamond lattice) in `rect`.
static func draw_card_back(ci: CanvasItem, rect: Rect2, alpha := 1.0) -> void:
	var ch := clampf(minf(rect.size.x, rect.size.y) * 0.06, 6.0, 12.0)
	var pts := GemDraw.chamfer_rect(rect, ch)
	var cols := PackedColorArray()
	for p in pts:
		var t := (p.y - rect.position.y) / maxf(rect.size.y, 1.0)
		var c := UITokens.PAPER_0.lerp(UITokens.PAPER_2, t)
		cols.append(Color(c.r, c.g, c.b, alpha))
	ci.draw_polygon(pts, cols)
	var gold := UITokens.LINE_GOLD_DEEP
	GemDraw.outline(ci, pts, Color(gold.r, gold.g, gold.b, gold.a * alpha), UIKit.line_px(1.0))
	var inner := GemDraw.chamfer_rect(rect.grow(-7.0), maxf(2.0, ch - 3.0))
	GemDraw.outline(ci, inner, Color(1, 1, 1, 0.55 * alpha), UIKit.line_px(1.0))
	# A rhombus lattice of fine gold lines inside the inner frame, clipped by construction.
	var r := rect.grow(-16.0)
	var c0 := r.get_center()
	var half := Vector2(r.size.x * 0.5, r.size.y * 0.5)
	var lc := Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.42 * alpha)
	for k in [0.33, 0.66, 1.0]:
		var hx: float = half.x * k
		var hy: float = half.y * k
		var d := PackedVector2Array([c0 + Vector2(0, -hy), c0 + Vector2(hx, 0), c0 + Vector2(0, hy), c0 + Vector2(-hx, 0), c0 + Vector2(0, -hy)])
		ci.draw_polyline(d, lc, UIKit.line_px(1.0), true)
	GemDraw.draw_diamond(ci, c0, clampf(rect.size.x * 0.11, 9.0, 18.0), UITokens.TOPAZ, gold, alpha)


class _Backdrop:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top := Color("#FBF7EF")
		var mid := Color("#F4EEE3")
		var bot := Color("#E9E3D6")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.55), Vector2(0, h * 0.55)]),
				PackedColorArray([top, top, mid, mid]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.55), Vector2(w, h * 0.55), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([mid, mid, bot, bot]))
		# Soft top light (one halo texture, no rays).
		draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(w * 0.5 - w * 0.7, -h * 0.28), Vector2(w * 1.4, h * 0.62)), false,
				Color(1.0, 0.99, 0.95, 0.55))
		# A fading gold rule with a centre diamond near the bottom, and a quiet diamond row along the edge.
		var y := h - 64.0
		GemDraw.draw_hairline(self, Vector2(w * 0.12, y), Vector2(w * 0.88, y), Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g,
				UITokens.HAIRLINE.b, 0.5), UIKit.line_px(1.0), true, true)
		var lc := Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.22)
		var step := 36.0
		var x := fmod(w * 0.5, step) - step
		while x < w + step:
			var c := Vector2(x, h - 26.0)
			draw_polyline(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0),
					c + Vector2(0, -9)]), lc, UIKit.line_px(1.0), true)
			x += step


## Three result stars; the lit ones pop in once (0.35 s each, staggered).
class Stars:
	extends Control
	var lit := 0
	var star_px := 64.0
	var animate := true
	var _k: Array[float] = [1.0, 1.0, 1.0]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if animate and lit > 0:
			for i in lit:
				_k[i] = 0.0
			for i2 in lit:
				var tw := create_tween()
				tw.tween_interval(0.12 + POP * float(i2))
				tw.tween_method(func(v: float) -> void:
					_k[i2] = v
					queue_redraw(), 0.0, 1.0, POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var r := star_px * 0.5
		var gap := star_px * 0.25
		var total := star_px * 3.0 + gap * 2.0
		var x0 := (size.x - total) * 0.5 + r
		for i in 3:
			var c := Vector2(x0 + float(i) * (star_px + gap), size.y * 0.5)
			var big := i == 1
			var rr := r * (1.0 if big else 0.86)
			MinigameUI.draw_star(self, c, rr, false)
			if i < lit and _k[i] > 0.0:
				MinigameUI.draw_star(self, c, rr * clampf(_k[i], 0.0, 1.15), true, clampf(_k[i] * 1.4, 0.0, 1.0))
