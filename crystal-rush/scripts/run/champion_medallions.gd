class_name ChampionMedallions
extends Control
## The run's champion medallions (heroes design §10.5, §4.2): one 72 px medallion per member, stacked
## above the ult button bottom-right (place), or a bottom row at y >= H - 240 (use_bottom_row). UI v3
## porcelain glass (ui_v3_spec §3, §4.3, §7.10): a 45-degree chamfered glass plate with ONE 1 dpx gold
## line and its inner light line, an HP ring (ink track, deep-gold fill, ALERT_FILL below 30 %), the
## class glyph (the same KitIcons cls_* line glyphs as the Heroes screens, §5.1) and the 10 px gem pip
## on the lower edge (the only gem colour the run may show, §10.3).
## States: full · hurt (the ring) · hit (a 0.15 s scale nudge, no glow) · action (a 1 dpx gold line
## pulse on the frame) · fallen (a crack across, desaturated, ring empty; stays) · revived (normal again
## with a pulse). Champions take no input (§4.2): this node and every child is MOUSE_FILTER_IGNORE.
##
## The run owner (HUD space: add it as a child of HudView, it fills its parent):
##   setup(members)            once, Champions.members (ChampionKinds.member rows)
##   place(ult_btn.get_rect()) after every HUD layout (stack above the ult; the row when use_bottom_row)
##   refresh(members)          every frame: redraws only what changed, allocates nothing
##   on_fx(event, data)        the KindView fx events (champ_hit, champ_down, champ_revive, champ_block,
##                             champ_mend, champ_heal, champ_leap, champ_shot, champ_spell)
##   set_avoid_rects(rects)    every frame: the next gate / hazard label rects in viewport canvas space
##                             (Camera3D.unproject_position space); a medallion over one fades to 0.5

## Medallion side at the 720 x 1280 canvas (the HUD does not scale beyond the canvas stretch; the ult
## button is a fixed 120 px ring the same way). `size_px` overrides it.
const SIZE := 72.0
## Stack pitch (the machine column's SLOT_GAP) and the gap above the ult rect (clear of the bright
## half of the ult's ready waves).
const GAP := 10.0
const ULT_GAP := 22.0
## Fallback layout (§10.5): a bottom row inside the lowest 240 px, left of the ult button.
const ROW_BAND := 240.0
const ROW_GAP := 12.0
const CHAMFER := 16.0
const RING_R := 27.0
const RING_W := 3.5
const GLYPH := 30.0
const PIP := 10.0
## Below this HP share the ring fill turns to the alert token.
const LOW := 0.3
const NUDGE := 1.08
const NUDGE_TIME := 0.15
const PULSE_TIME := 0.32
const FADE_A := 0.5
## fx events that pulse the acting champion's frame (champ_heal also pulses the healed one).
const ACTION_FX: Array[StringName] = [&"champ_block", &"champ_mend", &"champ_heal", &"champ_leap", &"champ_shot",
		&"champ_spell"]

## The fallback layout (§10.5): a row at y >= H - 240 instead of the stack above the ult.
var use_bottom_row := false:
	set(v):
		use_bottom_row = v
		_layout()
## Medallion side in canvas px (SIZE at the 720 canvas).
var size_px := SIZE:
	set(v):
		size_px = maxf(v, 24.0)
		_layout()

var _meds: Array[_Medallion] = []
## members index (setup order) -> medallion; refresh() walks it, so no lookups per frame.
var _src: Array[_Medallion] = []
var _by_id := {}
var _ult := Rect2()
var _placed := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Re-lays out on entering the tree and on a resize (against the last place() rect, or HudView's
## default ult rect before the first place()).
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED:
		_layout()


## Builds one medallion per member (§10.5), in slot order (ordered()). Replaces any previous set.
func setup(members: Array) -> void:
	for m in _meds:
		remove_child(m)
		m.queue_free()
	_meds.clear()
	_src.clear()
	_by_id.clear()
	for row: Dictionary in ordered(members):
		var md := _Medallion.new()
		md.id = str(row.get("id", ""))
		md.cls = str(row.get("class", ""))
		md.gem = UITokens.gem_of(str(row.get("gem", row.get("native", "C"))))
		md.slot = StringName(str(row.get("slot", "")))
		md.ratio = _ratio(row)
		md.alive_seen = bool(row.get("alive", true))
		md.fallen = not md.alive_seen
		add_child(md)
		_meds.append(md)
		_by_id[md.id] = md
	for m: Variant in members:
		_src.append(_by_id.get(str((m as Dictionary).get("id", "")), null) if m is Dictionary else null)
	visible = not _meds.is_empty()
	_layout()


## Per-frame sync with Champions.members: the HP ring and a fall the fx may have missed. Cheap: a
## medallion redraws only when its HP share or its life changed; nothing is allocated.
func refresh(members: Array) -> void:
	var n := mini(members.size(), _src.size())
	for i in n:
		var md := _src[i]
		var row: Dictionary = members[i]
		if md == null or row.get("id", "") != md.id:
			md = _by_id.get(row.get("id", ""), null)
			if md == null:
				continue
		var alive := bool(row.get("alive", true))
		if alive != md.alive_seen:
			# The data itself flipped: follow it (a fall without its fx, or a revive).
			md.alive_seen = alive
			md.set_fallen(not alive, alive)
		if not md.fallen:
			md.set_ratio(_ratio(row))


## The KindView fx events (ChampionKinds.FX): hit nudges, down cracks, revive restores, actions pulse.
func on_fx(event: StringName, data: Dictionary) -> void:
	var md: _Medallion = _by_id.get(str(data.get("id", "")), null)
	if md == null:
		return
	match event:
		&"champ_hit":
			if data.has("hp_max") and float(data["hp_max"]) > 0.0:
				md.set_ratio(clampf(float(data.get("hp", 0.0)) / float(data["hp_max"]), 0.0, 1.0))
			md.nudge()
		&"champ_down":
			md.set_ratio(0.0)
			md.set_fallen(true, false)
		&"champ_revive":
			md.set_fallen(false, true)
		_:
			if event in ACTION_FX:
				md.pulse()
				if event == &"champ_heal":
					var tgt: _Medallion = _by_id.get(str(data.get("target", "")), null)
					if tgt != null and tgt != md:
						tgt.pulse()


## Lays the medallions out against the ult button rect `ult_rect` (HUD coordinates = this node's, it
## fills its parent): a column centred on the ult, the first slot on top (front), the last ULT_GAP
## above the ult rect; or, with use_bottom_row, a row ending ROW_GAP left of the ult inside the lowest
## ROW_BAND px. Call it again after every HUD layout.
func place(ult_rect: Rect2) -> void:
	_ult = ult_rect
	_placed = true
	_layout()


## Viewport canvas rects of the next gate row / hazard labels (§10.5, critique X43): a medallion that
## intersects one fades to FADE_A in 0.15 s and back to 1 when clear. Call it every frame; it tweens
## only on a change.
func set_avoid_rects(rects: Array) -> void:
	var xf := get_global_transform_with_canvas()
	for md in _meds:
		var gr := xf * Rect2(md.position, md.size)
		var hit := false
		for r: Variant in rects:
			if r is Rect2 and (r as Rect2).intersects(gr):
				hit = true
				break
		if hit != md.faded:
			md.fade(hit)


# ------------------------------------------------------------------ queries (tests, the preview)

func count() -> int:
	return _meds.size()


## Layout rects of the medallions (this node's coordinates, slot order, no nudge scale).
func rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for md in _meds:
		out.append(Rect2(md.position, md.size))
	return out


func medallion_of(id: String) -> Control:
	return _by_id.get(id, null)


func ids() -> Array[String]:
	var out: Array[String] = []
	for md in _meds:
		out.append(md.id)
	return out


func ratio_of(id: String) -> float:
	var md: _Medallion = _by_id.get(id, null)
	return md.ratio if md else -1.0


func fallen_of(id: String) -> bool:
	var md: _Medallion = _by_id.get(id, null)
	return md != null and md.fallen


func faded_of(id: String) -> bool:
	var md: _Medallion = _by_id.get(id, null)
	return md != null and md.faded


## Change-driven redraw requests so far (all medallions): refresh() with unchanged data adds none.
func redraws() -> int:
	var n := 0
	for md in _meds:
		n += md.redraws
	return n


## `members` sorted into slot order for the HUD (§4.2 ABSORB_ORDER: front, left, right, rear = the
## order they take the clash once the army is gone; top of the stack / left of the banner first).
## Unknown slots keep their team order after the known ones.
static func ordered(members: Array) -> Array:
	var out: Array = []
	for sl: StringName in ChampionKinds.ABSORB_ORDER:
		for m: Variant in members:
			if m is Dictionary and StringName(str((m as Dictionary).get("slot", ""))) == sl:
				out.append(m)
	for m: Variant in members:
		if m is Dictionary and not out.has(m):
			out.append(m)
	return out


static func _ratio(row: Dictionary) -> float:
	var mx := float(row.get("hp_max", 0.0))
	if mx <= 0.0:
		return 0.0
	return clampf(float(row.get("hp", 0.0)) / mx, 0.0, 1.0)


## This node's size (it fills its parent), else the parent area, else the 720 x 1280 canvas.
func _area() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	if is_inside_tree():
		var a := get_parent_area_size()
		if a.x > 1.0 and a.y > 1.0:
			return a
	return Vector2(720, 1280)


## HudView._layout's ult rect, for a layout before place() was called.
func _default_ult(area: Vector2) -> Rect2:
	var w := HudView.ULT_RADIUS * 2.0 + 60.0
	var h := HudView.ULT_RADIUS * 2.0 + 48.0
	return Rect2(Vector2(area.x - w - 26.0, area.y - h - 56.0), Vector2(w, h))


func _layout() -> void:
	if _meds.is_empty() or not is_inside_tree():
		return
	var area := _area()
	var ult := _ult if _placed else _default_ult(area)
	var s := size_px
	var n := _meds.size()
	for i in n:
		var md := _meds[i]
		var p := Vector2.ZERO
		if use_bottom_row:
			var row_w := n * s + (n - 1) * ROW_GAP
			var x0 := ult.position.x - ROW_GAP - row_w
			x0 = clampf(x0, 8.0, maxf(8.0, area.x - row_w - 8.0))
			# Level with the ult ring, never above the band nor off the bottom edge.
			var y := clampf(ult.position.y + HudView.ULT_RADIUS + 4.0 - s * 0.5, area.y - ROW_BAND, area.y - s - 8.0)
			p = Vector2(x0 + i * (s + ROW_GAP), y)
		else:
			var cx := ult.get_center().x
			var bottom := ult.position.y - ULT_GAP
			var y2 := bottom - (n - i) * s - (n - 1 - i) * GAP
			p = Vector2(clampf(cx - s * 0.5, 8.0, area.x - s - 8.0), maxf(y2, 8.0 + i * (s + GAP)))
		md.position = p
		md.size = Vector2(s, s)
		md.pivot_offset = md.size * 0.5
		md.queue_redraw()


## One medallion (drawn in _draw; a redraw only on a change or during the 0.32 s pulse).
class _Medallion extends Control:
	var id := ""
	var cls := ""
	var gem := "quartz"
	var slot := &""
	var ratio := 1.0
	var fallen := false
	var faded := false
	## The last `alive` refresh() saw in the data (a flip there is followed; the fx path stands alone).
	var alive_seen := true
	var redraws := 0
	var _pulse := 0.0
	var _nudge_tw: Tween
	var _fade_tw: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	func set_ratio(r: float) -> void:
		if r == ratio:
			return
		ratio = r
		_dirty()

	func set_fallen(on: bool, with_pulse: bool) -> void:
		if on == fallen:
			return
		fallen = on
		if on:
			ratio = 0.0
			_pulse = 0.0
		_dirty()
		if with_pulse:
			pulse()

	## The action beat: one 1 dpx deep-gold line leaves the frame and fades (no glow, no fill).
	func pulse() -> void:
		if fallen or UITokens.reduce_motion():
			return
		_pulse = 1.0
		set_process(true)

	## Hit: a 0.15 s scale nudge (1.0 -> 1.08 -> 1.0), nothing lights up.
	func nudge() -> void:
		if UITokens.reduce_motion() or not is_inside_tree():
			return
		if _nudge_tw:
			_nudge_tw.kill()
		scale = Vector2.ONE
		_nudge_tw = create_tween()
		_nudge_tw.tween_property(self, "scale", Vector2(NUDGE, NUDGE), NUDGE_TIME * 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_nudge_tw.tween_property(self, "scale", Vector2.ONE, NUDGE_TIME * 0.65) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	## Over a gate / hazard label: alpha FADE_A in 0.15 s, back to 1 the same way.
	func fade(on: bool) -> void:
		faded = on
		if _fade_tw:
			_fade_tw.kill()
		var want := FADE_A if on else 1.0
		if not is_inside_tree():
			modulate.a = want
			return
		_fade_tw = create_tween()
		_fade_tw.tween_property(self, "modulate:a", want, UITokens.FAST)

	func _dirty() -> void:
		redraws += 1
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse = maxf(0.0, _pulse - delta / PULSE_TIME)
		queue_redraw()
		if _pulse <= 0.0:
			set_process(false)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var k := size.x / SIZE
		var c := r.get_center()
		var ch := CHAMFER * k
		# Plate: one soft slate halo, flat cream glass, the 1 dpx light line and ONE 1 dpx gold line.
		# Fallen: the well tone, a quiet taupe line, no light line (desaturated, §4.2 "cracks").
		if fallen:
			HeroV3.glass(self, r, ch, 0.72, UITokens.INK_DIM_GLASS, 0.45, 0.0, 0.06, UITokens.PAPER_3)
		else:
			HeroV3.glass(self, r, ch, 0.86, HeroV3.GOLD, 0.78, 0.62, 0.1)
		# HP ring: an ink track and the deep-gold share from 12 o'clock clockwise (alert below LOW).
		var rr := RING_R * k
		var rw := RING_W * k
		var ink := UITokens.INK
		draw_arc(c, rr, 0.0, TAU, 56, Color(ink.r, ink.g, ink.b, 0.1 if fallen else 0.16), rw, true)
		if not fallen and ratio > 0.0:
			var fc := UITokens.ALERT_FILL if ratio < LOW else UITokens.LINE_GOLD_DEEP
			var a0 := -PI * 0.5
			draw_arc(c, rr, a0, a0 + TAU * ratio, maxi(4, int(56.0 * ratio)), Color(fc.r, fc.g, fc.b, 1.0), rw, true)
		# The class glyph (KitIcons cls_* line icon, ink on cream).
		var gs := GLYPH * k
		var dim := UITokens.INK_DIM_GLASS
		var gc := ink if not fallen else Color(dim.r, dim.g, dim.b, 0.55)
		Icons.draw_icon(self, "cls_" + cls, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), gc)
		# The 10 px gem pip set on the lower edge (fallen: its cut in grey, no gem colour).
		var pc := Vector2(c.x, r.end.y - 1.0)
		if fallen:
			var cut := str(UITokens.gem(gem)["cut"])
			var sil := GemDraw.cut_points(cut, pc, PIP * k * 1.16)
			draw_colored_polygon(sil, UITokens.PAPER_3)
			GemDraw.outline(self, sil, Color(dim.r, dim.g, dim.b, 0.6), UIKit.px(1.0))
			_draw_crack(r)
		else:
			GemDraw.draw_mark(self, gem, pc, PIP * k)
		# Action pulse: the frame's line steps out 0 -> 6 px and fades (parallel chamfer, 1 dpx).
		if _pulse > 0.0:
			var g := (1.0 - _pulse) * 6.0 * k
			var lg := UITokens.LINE_GOLD_DEEP
			GemDraw.outline(self, GemDraw.chamfer_rect(r.grow(g), ch + g * 0.586),
					Color(lg.r, lg.g, lg.b, lg.a * _pulse), UIKit.line_px(1.0))

	## A crack across the plate, top edge to bottom edge, with two short branches: an ink line and a
	## 1 dpx light line beside it (light catching the broken edge; no dark outline round anything).
	func _draw_crack(r: Rect2) -> void:
		var main := PackedVector2Array([_q(r, 0.70, 0.0), _q(r, 0.60, 0.26), _q(r, 0.68, 0.40), _q(r, 0.46, 0.58),
				_q(r, 0.50, 0.70), _q(r, 0.31, 1.0)])
		var b1 := PackedVector2Array([_q(r, 0.60, 0.26), _q(r, 0.45, 0.31)])
		var b2 := PackedVector2Array([_q(r, 0.46, 0.58), _q(r, 0.35, 0.53)])
		var o := Vector2(UIKit.px(1.0), UIKit.px(1.0))
		var lite := Color(1, 1, 1, 0.7)
		var ink := Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.85)
		for line: PackedVector2Array in [main, b1, b2]:
			var shifted := PackedVector2Array()
			for p in line:
				shifted.append(p + o)
			draw_polyline(shifted, lite, UIKit.px(1.0), true)
			draw_polyline(line, ink, UIKit.line_px(1.5), true)

	static func _q(r: Rect2, x: float, y: float) -> Vector2:
		return r.position + Vector2(x * r.size.x, y * r.size.y)
