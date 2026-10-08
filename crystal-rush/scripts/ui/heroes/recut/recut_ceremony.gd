class_name HeroesRecutCeremony
extends Control
## The Recut ceremony (heroes_design.md §3.2, §9.4: 3.0 s, Fast ceremonies 1.5 s, Reduce Motion
## 0.6 s; part U §3.7 beats). The grant is already saved when this starts (the screen calls
## HeroesUIModel.recut() first, §9.5 row 5), so a skip never aborts anything.
##   0.00  the stone rises to the centre on a bright sky of its gem
##   0.30  the old stone turns; a wireframe of the NEW cut draws over it, edge by edge
##   0.70  laser-cut: sparks run along the new edges, facet lines light from the table out
##   1.30  colour flows up from the pavilion: the crown takes the new gem, the pavilion keeps the
##         native gem (the doublet, rule #3), a gold seam
##   1.80  the new cut lands (a small settle), chips of the old cut fall away
##   2.10  one soft bloom (peak <= 55 % white, a single flash) and the sky re-tints to the new gem
##   2.40  «Огранено: Сапфір», «Корінний Кварц · зараз Сапфір», five fresh facet seats, «Далі»
## Everything is a pure function of t (apply(t)), so the gallery can seek any frame. Tap skips to
## the end state from CeremonyData.SKIP_FROM. Reduce Motion: a cross-fade of the stones + text.
##   var c := HeroesRecutCeremony.make("arin", "C", "R", "C"); add_child(c)
##   c.finished.connect(...)        # «Далі» pressed

signal finished

var hero_id := ""
var old_gem := "C"
var new_gem := "R"
var native := "C"
var length := 3.0
var reduced := false
var t := 0.0
var _playing := true
var _done_shown := false

var _sky_old: HeroShowcaseBackdrop
var _sky_new: HeroShowcaseBackdrop
var _back: _Fx
var _old: _Gem
var _new: _Gem
var _front: _Fx
var _title: Label
var _name: Label
var _sub: Label
var _note: Label
var _pips: HeroFacetPips
var _next: Button
var _skip: Label

## Beat times on the 3.0 s master timeline (scaled to `length`).
const B_RISE := 0.30
const B_WIRE := 0.70
const B_FLOW := 1.30
const B_LAND := 1.80
const B_BLOOM := 2.10
const B_TEXT := 2.40
const MASTER := 3.0


static func make(p_id: String, p_old: String, p_new: String, p_native: String) -> HeroesRecutCeremony:
	var c := HeroesRecutCeremony.new()
	c.hero_id = p_id
	c.old_gem = p_old
	c.new_gem = p_new
	c.native = p_native
	c.reduced = UITokens.reduce_motion()
	var fast := bool(UITokens._setting("fast_ceremonies", false))
	if c.reduced:
		c.length = float(CeremonyData.CEREMONY_REDUCED["recut"])
	elif fast:
		c.length = float(CeremonyData.CEREMONY_FAST["recut"])
	else:
		c.length = float(CeremonyData.CEREMONY["recut"])
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var el := ""
	if HeroData.HEROES.has(hero_id):
		el = str(HeroData.HEROES[hero_id].get("element", ""))
	_sky_old = HeroShowcaseBackdrop.make(old_gem, el)
	_sky_new = HeroShowcaseBackdrop.make(new_gem, el)
	for s: HeroShowcaseBackdrop in [_sky_old, _sky_new]:
		s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.halo = false
		s.focus = Vector2(0.5, 0.4)
		add_child(s)
	_back = _Fx.new()
	_back.back = true
	_old = _Gem.new()
	_old.gem = old_gem
	_new = _Gem.new()
	_new.gem = new_gem
	_new.nat = native if native != new_gem else ""
	_front = _Fx.new()
	for n: Control in [_back, _old, _new, _front]:
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.set("cer", self)
		add_child(n)
	_title = UIKit.gradient_heading(HeroesText.t("CER_RECUT", [HeroesText.gem_name(new_gem)]), 56)
	_name = UIKit.label(HeroesText.name_of(hero_id), 30, UITokens.INK, true)
	_sub = UIKit.label(HeroesText.t("RECUT_DOUBLET", [HeroesText.gem_name(native), HeroesText.gem_name(new_gem)]), 24, UITokens.GOLD_TEXT, true)
	_note = UIKit.label(HeroesText.t("RECUT_NO_DROP"), 22, UITokens.INK_DIM)
	for l: Label in [_title, _name, _sub, _note]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	_pips = HeroFacetPips.make(new_gem, 0, 26.0)
	_pips.bed = true
	add_child(_pips)
	_next = UIKit.secondary_button(HeroesText.t("RECUT_CONTINUE"), "", Vector2(320, 88), 28)
	_next.pressed.connect(func(): finished.emit())
	add_child(_next)
	_skip = UIKit.label(HeroesText.t("RECUT_SKIP_HINT"), 22, UITokens.INK_SOFT)
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip)
	resized.connect(_layout)
	_layout()
	apply(0.0)
	Audio.play("click", -6.0)
	UIJuice.haptic("CLICK", 0.6)


func _layout() -> void:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	var H := size.y if size.y > 1.0 else get_viewport_rect().size.y
	var cy := H * 0.4
	var y := cy + stone_px() * 0.86 + 30.0
	for l: Label in [_title, _name, _sub, _note]:
		l.size = Vector2(W - 48.0, l.get_combined_minimum_size().y)
		l.position = Vector2(24, y)
		y += l.size.y + (6.0 if l != _title else 2.0)
	_pips.position = Vector2((W - _pips.get_combined_minimum_size().x) * 0.5, y + 12.0)
	_next.size = Vector2(320, 88)
	_next.position = Vector2((W - 320.0) * 0.5, H - 88.0 - 64.0)
	_skip.size = Vector2(W, 30)
	_skip.position = Vector2(0, H - 70.0)


## Master-timeline time (0..3) of the current t.
func _m() -> float:
	return t / maxf(length, 0.01) * MASTER


func _process(delta: float) -> void:
	if not _playing:
		return
	t = minf(t + delta, length)
	apply(t)
	if t >= length:
		_playing = false


## Puts every element at time `p_t` (seconds into this ceremony).
func apply(p_t: float) -> void:
	t = clampf(p_t, 0.0, length)
	var m := _m()
	if reduced:
		m = MASTER * clampf(t / maxf(length, 0.01), 0.0, 1.0)
	# Sky: the old gem, re-tinted to the new one at the bloom.
	_sky_new.modulate.a = _ramp(m, B_BLOOM, B_BLOOM + 0.4)
	_sky_old.modulate.a = 1.0
	modulate.a = _ramp(m, 0.0, 0.22) if not reduced else _ramp(m, 0.0, 0.6)
	var tx := _ramp(m, B_TEXT, B_TEXT + 0.35)
	for l: Label in [_title, _name, _sub, _note]:
		l.modulate.a = tx
	_pips.modulate.a = _ramp(m, B_TEXT + 0.15, B_TEXT + 0.5)
	_next.visible = t >= length - 0.001
	_next.modulate.a = 1.0
	_skip.visible = not _next.visible and t >= CeremonyData.SKIP_FROM
	if _next.visible and not _done_shown:
		_done_shown = true
		UIJuice.haptic("THUD", 0.8)
		if not reduced:
			UIJuice.soft_in(_next, Vector2(0, 16))
	_stage_gems(m)
	_back.queue_redraw()
	_front.queue_redraw()
	if absf(m - B_BLOOM) < 0.04 and not reduced:
		UIJuice.haptic("CLICK", 0.7)


## Stone centre and full size.
func centre() -> Vector2:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	var H := size.y if size.y > 1.0 else get_viewport_rect().size.y
	return Vector2(W * 0.5, H * 0.4)


func stone_px() -> float:
	var W := size.x if size.x > 1.0 else get_viewport_rect().size.x
	return minf(W * 0.42, 300.0)


## Master time with Reduce Motion folded in.
func master() -> float:
	if reduced:
		return MASTER * clampf(t / maxf(length, 0.01), 0.0, 1.0)
	return _m()


func _stage_gems(m: float) -> void:
	var c := centre()
	var S := stone_px()
	for g: _Gem in [_old, _new]:
		g.c = c
	if reduced:
		var k := _ramp(m, 0.6, 2.2)
		_old.s = S
		_new.s = S
		_old.sx = 1.0
		_new.sx = 1.0
		_old.modulate.a = 1.0 - k
		_new.modulate.a = k
	else:
		var rise := _ramp(m, 0.0, B_RISE)
		var s := S * lerpf(0.6, 1.0, 1.0 - pow(1.0 - rise, 3.0))
		var flow := _ramp(m, B_FLOW, B_LAND)
		var turn := _ramp(m, B_RISE, B_LAND)
		var ang := (1.0 - pow(1.0 - turn, 2.2)) * TAU * 2.0
		var sx := cos(ang)
		sx = (1.0 if sx >= 0.0 else -1.0) * maxf(absf(sx), 0.08)
		if m < B_LAND:
			_old.s = s
			_new.s = s
			_old.sx = sx
			_new.sx = sx
			_old.modulate.a = 1.0 - flow
			_new.modulate.a = flow
		else:
			var land := _ramp(m, B_LAND, B_LAND + 0.3)
			_new.s = S * (1.0 + 0.07 * sin(land * PI) * (1.0 - land))
			_new.sx = 1.0
			_old.modulate.a = 0.0
			_new.modulate.a = 1.0
	_old.queue_redraw()
	_new.queue_redraw()


static func _ramp(x: float, a: float, b: float) -> float:
	return clampf((x - a) / maxf(b - a, 0.0001), 0.0, 1.0)


## Dev shots: put the ceremony at `p_t` seconds and hold it there.
func seek(p_t: float) -> void:
	_playing = false
	apply(p_t)


func _gui_input(e: InputEvent) -> void:
	if UIJuice.is_tap(e) and _playing and t >= CeremonyData.SKIP_FROM:
		_playing = false
		apply(length)


## One stone (old or new), drawn with a vertical-axis turn (sx) at c; alpha via modulate.
class _Gem extends Control:
	var cer: HeroesRecutCeremony
	var gem := "C"
	var nat := ""
	var c := Vector2.ZERO
	var s := 200.0
	var sx := 1.0

	func _draw() -> void:
		if modulate.a <= 0.001:
			return
		draw_set_transform(c, 0.0, Vector2(sx, 1.0))
		HeroGemEmblem.draw_emblem(self, gem, nat, Vector2.ZERO, s, true, cer.t if cer else 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Light behind the stone (back) or the wireframe, laser, chips, bloom and ring (front).
class _Fx extends Control:
	var cer: HeroesRecutCeremony
	var back := false

	func _draw() -> void:
		if cer == null:
			return
		var W := size.x
		var m := cer.master()
		var c := cer.centre()
		var S := cer.stone_px()
		var g_new: Dictionary = UITokens.gem(cer.new_gem)
		var g_old: Dictionary = UITokens.gem(cer.old_gem)
		var light_new: Color = g_new["light"]
		var rim_new: Color = g_new["rim"]
		var glow := UIKit.glow_texture()
		if back:
			var pool := 0.35 + 0.4 * HeroesRecutCeremony._ramp(m, 0.3, 1.8)
			draw_texture_rect(glow, Rect2(c - Vector2(S, S) * 1.6, Vector2(S, S) * 3.2), false, Color(1, 1, 1, 0.6 * pool))
			draw_texture_rect(glow, Rect2(c - Vector2(S, S) * 1.1, Vector2(S, S) * 2.2), false, Color(rim_new.r, rim_new.g, rim_new.b, 0.28 * pool))
			# The new cut engraved large behind the stone (the old cut fades out as it arrives).
			var cut_new := str(g_new["cut"])
			var cut_old := str(g_old["cut"])
			var arrive := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_WIRE, HeroesRecutCeremony.B_LAND)
			var rot := 0.0 if cer.reduced else m * 0.05
			for k: Array in [[1.55, 0.7, 2.0], [1.95, 0.4, 1.4], [2.45, 0.22, 1.2]]:
				var po := Transform2D(rot * float(k[0]), c) * GemDraw.cut_points(cut_old, Vector2.ZERO, S * float(k[0]))
				GemDraw.outline(self, po, Color(1, 1, 1, float(k[1]) * (1.0 - arrive)), float(k[2]))
				var pn := Transform2D(-rot * float(k[0]), c) * GemDraw.cut_points(cut_new, Vector2.ZERO, S * float(k[0]))
				GemDraw.outline(self, pn, Color(1, 1, 1, float(k[1]) * arrive), float(k[2]))
				GemDraw.outline(self, pn, Color(rim_new.r, rim_new.g, rim_new.b, 0.3 * float(k[1]) * arrive), float(k[2]) + 2.0)
			# Slow light rays behind the stone (static under Reduce Motion).
			var n := 12
			var L := maxf(W, size.y)
			for i in n:
				var a0 := TAU * i / n + (0.0 if cer.reduced else m * 0.12)
				var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * L, c + Vector2(cos(a0 + 0.07), sin(a0 + 0.07)) * L])
				draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.16 * pool), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
			return
		if cer.reduced:
			return
		var rise := HeroesRecutCeremony._ramp(m, 0.0, HeroesRecutCeremony.B_RISE)
		var s := S * lerpf(0.6, 1.0, 1.0 - pow(1.0 - rise, 3.0))
		# Colour front climbing from the pavilion to the crown.
		var flow := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_FLOW, HeroesRecutCeremony.B_LAND)
		if flow > 0.0 and flow < 1.0:
			var fy := c.y + s * 0.5 - flow * s
			draw_texture_rect(glow, Rect2(Vector2(c.x - s * 0.7, fy - 30.0), Vector2(s * 1.4, 60.0)), false, Color(light_new.r, light_new.g, light_new.b, 0.75 * (1.0 - absf(flow - 0.5) * 1.4)))
		# Wireframe of the new cut, edge by edge; then the laser runs along it.
		var wire := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_RISE, HeroesRecutCeremony.B_WIRE)
		var wire_out := 1.0 - HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_LAND, HeroesRecutCeremony.B_LAND + 0.3)
		if wire > 0.0 and wire_out > 0.0:
			var cut := str(g_new["cut"])
			var pts := GemDraw.cut_points(cut, c, s * 1.04)
			_partial(pts, wire, Color(rim_new.r, rim_new.g, rim_new.b, 0.5 * wire_out), 6.0)
			_partial(pts, wire, Color(1, 1, 1, 0.95 * wire_out), 2.4)
			var laser := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_WIRE, HeroesRecutCeremony.B_FLOW)
			var n := pts.size()
			for i in n:
				var li := clampf(laser * n - i, 0.0, 1.0)
				if li > 0.0:
					draw_line(c, c.lerp(pts[i], li), Color(1, 1, 1, 0.75 * wire_out), 1.8, true)
			if laser > 0.0 and laser < 1.0:
				var head := _along(pts, laser)
				draw_texture_rect(glow, Rect2(head - Vector2(44, 44), Vector2(88, 88)), false, Color(1, 0.97, 0.85, 0.9))
				GemDraw.draw_glint(self, head, 36.0, Color(1, 1, 1, 0.95))
				for k in 7:
					var a := TAU * k / 7.0 + m * 9.0
					var r := 14.0 + 26.0 * fposmod(m * 7.0 + k * 0.37, 1.0)
					draw_circle(head + Vector2(cos(a), sin(a)) * r, 2.4, Color(1, 0.9, 0.62, 0.95))
		# Chips of the old cut fall away as the new one lands.
		var chips := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_LAND, HeroesRecutCeremony.B_LAND + 0.7)
		if chips > 0.0 and chips < 1.0:
			var oc: Color = g_old["rim"]
			var ol: Color = g_old["deep"]
			for k in 10:
				var a := TAU * k / 10.0 + 0.3
				var d := Vector2(cos(a), sin(a))
				var p := c + d * (S * 0.45 + chips * 170.0) + Vector2(0, chips * chips * 130.0)
				var z := 13.0 * (1.0 - chips * 0.6)
				var tri := PackedVector2Array([p + d * z, p + d.rotated(2.3) * z * 0.7, p + d.rotated(-2.3) * z * 0.7])
				draw_colored_polygon(tri, Color(oc.r, oc.g, oc.b, 0.9 * (1.0 - chips)))
				GemDraw.outline(self, tri, Color(ol.r, ol.g, ol.b, 0.8 * (1.0 - chips)), 1.0)
		# One soft bloom at the landing (photosensitivity: a single flash, <= 55 % white).
		var bloom := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_BLOOM - 0.05, HeroesRecutCeremony.B_BLOOM + 0.08) * (1.0 - HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_BLOOM + 0.08, HeroesRecutCeremony.B_BLOOM + 0.45))
		if bloom > 0.0:
			draw_texture_rect(glow, Rect2(c - Vector2(W, W) * 0.9, Vector2(W, W) * 1.8), false, Color(1, 1, 1, 0.55 * bloom))
		# A gold ring engraves around the landed stone, keystones at the quarters.
		var ring := HeroesRecutCeremony._ramp(m, HeroesRecutCeremony.B_LAND, HeroesRecutCeremony.B_TEXT)
		if ring > 0.0:
			var hi := UITokens.GOLD_HI
			var hl := UITokens.HAIRLINE
			draw_arc(c, S * 0.8, -PI * 0.5, -PI * 0.5 + TAU * ring, 80, Color(hl.r, hl.g, hl.b, 0.95), 2.2, true)
			draw_arc(c, S * 0.86, -PI * 0.5, -PI * 0.5 + TAU * ring, 80, Color(hi.r, hi.g, hi.b, 0.7), 1.2, true)
			if ring >= 1.0:
				for k in 4:
					var a := PI * 0.5 * k - PI * 0.5
					GemDraw.draw_keystone(self, c + Vector2(cos(a), sin(a)) * S * 0.8, 18.0)

	func _partial(pts: PackedVector2Array, frac: float, col: Color, w: float) -> void:
		var total := 0.0
		for i in pts.size():
			total += pts[i].distance_to(pts[(i + 1) % pts.size()])
		var left := total * frac
		for i in pts.size():
			if left <= 0.0:
				break
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var L := a.distance_to(b)
			draw_line(a, a.lerp(b, minf(1.0, left / maxf(L, 0.001))), col, w, true)
			left -= L

	func _along(pts: PackedVector2Array, frac: float) -> Vector2:
		var total := 0.0
		for i in pts.size():
			total += pts[i].distance_to(pts[(i + 1) % pts.size()])
		var left := total * frac
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var L := a.distance_to(b)
			if left <= L:
				return a.lerp(b, left / maxf(L, 0.001))
			left -= L
		return pts[0]
