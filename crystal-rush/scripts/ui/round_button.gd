class_name RoundButton
extends Control
## Circular touch button with an icon (texture or vector), optional caption and badges.
## Reacts to real touches of any finger (InputEventScreenTouch, so a second finger can tap it
## while the first one steers) and to a real mouse; emulated events are ignored so one tap
## never fires twice.
## UI v2 look: a cream disc with ONE thin gold ring and a line icon (ink) - the round "edge
## button" of the home rails, close / back / info / pause. `base_color` is ignored in v2 (the
## face is always cream); `ring_color` other than UIKit.GOLD tints the ring (e.g. remove = red).
## Badges are gold notify discs; captions are porcelain chips. Bitmap override: edge_button.png.
## `ult_style` turns it into the ultimate button: the hero portrait in a gold ring on a cream
## face, a cream charge track with an amber fill (`progress`), and a warm topaz glow with
## refraction glints while `highlight` (ready) is on.

signal pressed

var icon_texture: Texture2D:
	set(v):
		icon_texture = v
		_wake()
var icon_kind := "":
	set(v):
		icon_kind = v
		_wake()
var icon_tint := Color.WHITE:
	set(v):
		icon_tint = v
		_wake()
var caption := "":
	set(v):
		caption = v
		_wake()
var caption_color := UIKit.TEXT:
	set(v):
		caption_color = v
		_wake()
var caption_icon := "":  # e.g. "coin" drawn before caption text
	set(v):
		caption_icon = v
		_wake()
var badge := "":  # small text in the top-right corner
	set(v):
		badge = v
		_wake()
var badge_icon := "":  # small vector icon in a gold coin at the top-right (ult style)
	set(v):
		badge_icon = v
		_wake()
var radius := 44.0:
	set(v):
		radius = v
		_wake()
var base_color := Color(0.1, 0.12, 0.2, 0.92):
	set(v):
		base_color = v
		_wake()
var ring_color := UIKit.GOLD:
	set(v):
		ring_color = v
		_wake()
var glow_color := Color(1.0, 0.6, 0.95):
	set(v):
		glow_color = v
		_wake()
var ready_color := Color(1.0, 0.78, 0.3):  # ult style: halo and ring once charged (gold reads on any world)
	set(v):
		ready_color = v
		_wake()
var disabled := false:
	set(v):
		disabled = v
		_wake()
var armed := false:  # waiting for a confirming second tap
	set(v):
		armed = v
		_wake()
var highlight := false:  # pulsing outer glow in the ring colour (keeps the icon)
	set(v):
		highlight = v
		_wake()
var progress := -1.0:  # 0..1 draws an arc around the button
	set(v):
		progress = v
		_wake()
var progress_color := UIKit.GOLD:
	set(v):
		progress_color = v
		_wake()
var pulse := false:
	set(v):
		pulse = v
		_wake()
var ult_style := false:
	set(v):
		ult_style = v
		_wake()
## On the Portal night: an ink-glass disc with one 1 dpx grey-blue ring and a warm-white icon, so
## the porcelain key button stays the one light, filled control on the dark screen.
var night := false:
	set(v):
		night = v
		_wake()
var _press_scale := 1.0
var _down := false
var _touch := -1                # finger index holding the button, -1 none
var _shown_progress := 0.0
var _t := 0.0
var _last_emit := -10.0
var _pop := 0.0                 # 1 → 0 after becoming ready (burst ring)


func _init(p_radius := 44.0) -> void:
	radius = p_radius
	custom_minimum_size = Vector2(radius * 2.0 + 8.0, radius * 2.0 + 8.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	size = custom_minimum_size
	_wake()


## Redraw now and run _process until the press scale, the progress lerp and the pop settle
## (v3.1: nothing pulses, so a settled button costs no per-frame redraw). The ult keeps
## processing while its ready juice or its charging liquid moves.
func _wake() -> void:
	queue_redraw()
	if is_inside_tree():
		set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var target := 0.9 if _down else 1.0
	_press_scale = lerpf(_press_scale, target, minf(1.0, delta * 18.0))
	var want := clampf(progress, 0.0, 1.0)
	_shown_progress = lerpf(_shown_progress, want, minf(1.0, delta * 8.0))
	_pop = maxf(0.0, _pop - delta * 1.6)
	queue_redraw()
	var settled := absf(_press_scale - target) < 0.002 and absf(_shown_progress - want) < 0.002 and _pop <= 0.0
	if settled and not _ult_moving():
		_press_scale = target
		_shown_progress = want
		set_process(false)


## The ult's own motion: the ready halo / waves / glints, or the charging liquid surface.
func _ult_moving() -> bool:
	if not ult_style or not is_visible_in_tree():
		return false
	if highlight and not disabled:
		return true
	return progress >= 0.0 and _shown_progress > 0.02 and _shown_progress < 0.985


## Plays the "just became ready" burst (ult style).
func burst() -> void:
	_pop = 1.0
	_wake()


func _has_point(point: Vector2) -> bool:
	var c := _circle_center()
	if point.distance_to(c) <= maxf(radius + 12.0, 44.0):  # >= 88 px touch target
		return true
	# The caption pill under the circle is part of the button too.
	if caption != "":
		var w := UIKit.font(true).get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + (26.0 if caption_icon != "" else 0.0) + 24.0
		return Rect2(Vector2(c.x - w * 0.5, c.y + radius), Vector2(w, 36.0)).has_point(point)
	return false


func _circle_center() -> Vector2:
	return Vector2(size.x * 0.5, radius + 4.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if st.pressed:
			if _touch == -1:
				_touch = st.index
				_down = true
				_wake()
			accept_event()
		elif st.index == _touch:
			_touch = -1
			_release(st.position, st.canceled)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			_wake()
			accept_event()
		elif _down and _touch == -1:
			_release(mb.position, false)
			accept_event()


func _release(pos: Vector2, canceled: bool) -> void:
	if not _down:
		return
	_down = false
	_wake()
	if canceled or not _has_point(pos):
		return
	# Debounce: never fire twice for one physical tap, whatever the platform emulates.
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_emit < 0.12:
		return
	_last_emit = now
	pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _touch == -1:
		_down = false
		_wake()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_down = false
			_touch = -1
		_wake()


func _draw() -> void:
	if ult_style:
		_draw_ult()
		return
	var c := _circle_center()
	# v3.1: nothing pulses (`pulse` is kept for callers and ignored).
	var s := _press_scale
	var r := radius * s
	var dim := 0.5 if disabled else 1.0
	# v3.1 edge button (§7.9): a glass disc @ 0.72 with ONE 1 dpx gold ring and a 1 dpx light arc
	# on its lit upper edge; one soft halo. "Ready" (highlight) = a static 1.5 dpx amber ring.
	var tex := UIKit.kit_texture("edge_button")
	draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.32 + Vector2(0, 3), Vector2(r, r) * 2.64), false,
			Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.12))
	var ring := UITokens.HAIRLINE if ring_color == UIKit.GOLD else ring_color
	if disabled:
		ring = Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5)
	if night:
		var ng := UITokens.NIGHT_GLASS_DOWN if _down else UITokens.NIGHT_GLASS
		draw_circle(c, r, ng, true, -1.0, true)
		var nl := UITokens.NIGHT_LINE
		draw_arc(c, r - UIKit.px(0.5), 0, TAU, 72, Color(nl.r, nl.g, nl.b, nl.a * dim), UIKit.line_px(1.0), true)
	elif tex:
		draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(dim, dim, dim, 1.0))
	else:
		var face := UITokens.PAPER_0 if not disabled else UITokens.PAPER_3
		draw_circle(c, r, Color(face.r, face.g, face.b, 0.72), true, -1.0, true)
		var lw := UIKit.line_px(1.0)
		draw_arc(c, r - lw * 0.5, 0, TAU, 72, Color(ring.r, ring.g, ring.b, ring.a * 0.85), lw, true)
		draw_arc(c, r - lw * 1.5, PI * 1.05, PI * 1.75, 32, Color(1, 1, 1, 0.75), UIKit.px(1.0), true)
	if armed:
		draw_arc(c, r + 4.0, 0, TAU, 72, Color(UIKit.PLUS.r, UIKit.PLUS.g, UIKit.PLUS.b, 0.8), UIKit.line_px(1.5), true)
	if highlight and not armed:
		# "Ready": one static 1.5 dpx ring in the key line (deep gold; amber only under --cta=amber).
		var kl := UITokens.key_line()
		draw_arc(c, r + 3.0, 0, TAU, 72, Color(kl.r, kl.g, kl.b, 0.95), UIKit.line_px(1.5), true)
	if progress >= 0.0:
		# A 2 dpx key-line arc on a 1 dpx gold track.
		var pc := progress_color if progress_color != UIKit.GOLD else UITokens.key_line()
		var hl := UITokens.HAIRLINE
		draw_arc(c, r + 4.0, 0, TAU, 72, Color(hl.r, hl.g, hl.b, 0.8), UIKit.line_px(1.0), true)
		draw_arc(c, r + 4.0, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 72, pc, UIKit.line_px(2.0), true)
	var icon_size := r * 1.12
	var icon_rect := Rect2(c - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	if armed:
		Icons.draw_icon(self, "check", icon_rect.grow(-icon_size * 0.08), UIKit.PLUS)
	elif icon_texture:
		_draw_disc_texture(icon_texture, c, r - 4.0, Color(dim, dim, dim, 1.0) * icon_tint)
		draw_arc(c, r - 3.5, 0, TAU, 64, ring, UIKit.line_px(1.0), true)
	elif icon_kind != "":
		# Line icons take ink on the cream disc unless the caller tinted them.
		var col := icon_tint
		if icon_tint == Color.WHITE:
			col = UITokens.INK if KitIcons.has_line(icon_kind) else Color.WHITE
			if night:
				col = UITokens.ON_SCENE
		Icons.draw_icon(self, icon_kind, icon_rect.grow(-icon_size * 0.04), Color(col.r, col.g, col.b, col.a * (0.55 if disabled else 1.0)))
	_draw_badge(c, r)
	_draw_caption(c, r, dim)


func _gloss(c: Vector2, r: float) -> void:
	# Upper crescent highlight: a lighter disc clipped by drawing the face again below it.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 28
	for i in n + 1:
		var a := PI + PI * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
		cols.append(Color(1, 1, 1, 0.16))
	for i in n + 1:
		var a := TAU - PI * float(i) / n
		pts.append(c + Vector2(cos(a) * r * 0.86, -r * 0.05 + sin(a) * r * 0.25))
		cols.append(Color(1, 1, 1, 0.0))
	draw_polygon(pts, cols)


## Draws a texture clipped to a circle (polygon with UVs).
func _draw_disc_texture(tex: Texture2D, c: Vector2, r: float, mod: Color, zoom := 1.0, offset := Vector2.ZERO) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 48
	for i in n:
		var a := TAU * i / n
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + offset + d * 0.5 / zoom)
		cols.append(mod)
	draw_polygon(pts, cols, uvs, tex)


func _draw_badge(c: Vector2, r: float) -> void:
	if badge == "":
		return
	# v3.1 (§7.11): a flat 28 px amber disc with a 1 dpx cream ring ("!" or a count, brown glyph),
	# one soft halo; no red dots, no gloss.
	var f := UIKit.font_w("extrabold")
	var bs := 17
	var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
	var br := maxf(14.0, bw * 0.5 + 7.0)
	var bc := c + Vector2(r * 0.72, -r * 0.72)
	var sc := UITokens.SCRIM
	var cream := Color(1, 0.98, 0.92, 0.95)
	draw_texture_rect(UIKit.glow_texture(), Rect2(bc - Vector2(br, 14.0) * 1.4 + Vector2(0, 1.5), Vector2(br, 14.0) * 2.8), false, Color(sc.r, sc.g, sc.b, 0.14))
	# Porcelain: an ink disc with ONE 1 dpx gold ring and a cream glyph (no amber on the key path).
	var calm := UITokens.calm_cta()
	var fill := UITokens.KEY_INK if calm else UITokens.NAV_BADGE
	var edge := UITokens.KEY_GOLD if calm else cream
	if badge.length() > 1:
		var rr := Rect2(bc - Vector2(br, 14.0), Vector2(br * 2.0, 28.0))
		var pts := GemDraw.chamfer_rect(rr, 6.0)
		draw_colored_polygon(pts, fill)
		GemDraw.outline(self, pts, edge, UIKit.line_px(1.0))
	else:
		draw_circle(bc, 14.0, fill, true, -1.0, true)
		draw_arc(bc, 14.0 - UIKit.px(0.5), 0, TAU, 40, edge, UIKit.line_px(1.0), true)
	draw_string(f, Vector2(bc.x - bw * 0.5, bc.y + f.get_ascent(bs) * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, UITokens.PAPER_0 if calm else UIKit.BROWN)


func _draw_caption(c: Vector2, r: float, dim: float) -> void:
	if caption == "":
		return
	# A glass chip under the disc, 22 px Medium ink label (it usually floats over a 3D scene).
	var f2 := UIKit.font_w("medium")
	var fs := 22
	var tw := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var iw := 22.0 if caption_icon != "" else 0.0
	var total := tw + iw + (4.0 if iw > 0.0 else 0.0)
	var cap_y := c.y + r + 4.0
	var pill := Rect2(Vector2(c.x - total * 0.5 - 12.0, cap_y - 2.0), Vector2(total + 24.0, 32.0))
	draw_style_box(UIKit.lux("chip", Vector2.ZERO), pill)
	var x := c.x - total * 0.5
	if iw > 0.0:
		Icons.draw_icon(self, caption_icon, Rect2(Vector2(x, cap_y + 2.0), Vector2(iw, iw)), Color(1, 1, 1, dim))
		x += iw + 4.0
	var cc := caption_color if caption_color != UIKit.TEXT else UITokens.INK
	draw_string(f2, Vector2(x, cap_y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc * Color(1, 1, 1, 1.0 if not disabled else 0.6))


# ------------------------------------------------------------------ ult style

func _draw_ult() -> void:
	# v2 ult: the hero portrait in a gold ring on a cream face; a cream charge track with an
	# amber fill around it; warm topaz glow + glints when ready. Light, readable on any world.
	var c := _circle_center()
	var ready := highlight and not disabled
	var s := _press_scale
	if ready:
		s *= 1.0 + 0.03 * sin(_t * 5.0)
	s *= 1.0 + 0.16 * _pop * _pop
	var r := radius * s
	var gc := ready_color if ready else glow_color
	var sc := UITokens.SCRIM
	# Porcelain: the ult's ready state is the key action of the run, so it speaks the key-button
	# language: no warm glow halo, no amber; two thin key-gold rings travel out (motion, not heat).
	var calm := UITokens.calm_cta()
	if ready:
		var k := 0.6 + 0.4 * sin(_t * 5.0)
		if not calm:
			draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(1.0, 0.78, 0.38, 0.5 + 0.2 * k))
		for w in 2:
			var wave := fmod(_t * 0.8 + w * 0.5, 1.0)
			var wc := Color(UITokens.KEY_GOLD.r, UITokens.KEY_GOLD.g, UITokens.KEY_GOLD.b, 0.8 * (1.0 - wave)) if calm else Color(1.0, 0.86, 0.52, 0.7 * (1.0 - wave))
			draw_arc(c, r + 12.0 + wave * 30.0, 0, TAU, 64, wc, (1.5 if calm else 2.5) * (1.0 - wave) + 0.8, true)
	if _pop > 0.0:
		draw_arc(c, r + 8.0 + (1.0 - _pop) * 64.0, 0, TAU, 64, Color(1, 0.97, 0.88, _pop * 0.9), 5.0 * _pop + 1.0, true)
	# v3.1 (§7.10): one glow shadow (a halo, not stacked discs), a 4 px glass charge track inside
	# ONE 1 dpx gold ring, a 1.5 dpx bezel around the face; the ready juice stays.
	draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.45 + Vector2(0, 4), Vector2(r, r) * 2.9), false, Color(sc.r, sc.g, sc.b, 0.16))
	var ring_r := r + 4.0
	draw_arc(c, ring_r, 0, TAU, 72, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.6), 4.0, true)
	draw_arc(c, ring_r + 2.0 + UIKit.px(0.5), 0, TAU, 96, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0), true)
	var p := 1.0 if ready else _shown_progress
	if p > 0.002:
		var segs := maxi(3, int(72 * p))
		var a0 := -PI / 2.0
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var col := UITokens.CTA_LO.lerp(UITokens.CTA_HI, t1 * p)
			if calm:
				col = UITokens.LINE_GOLD_DEEP.lerp(UITokens.KEY_GOLD, t1 * p)
				col.a = 1.0
			if ready:
				var ang := fposmod(t0 * TAU - _t * 2.6, TAU)
				var base := UITokens.KEY_GOLD if calm else UITokens.CTA
				col = base.lerp(Color(1, 0.98, 0.9), clampf(1.0 - ang / 1.3, 0.0, 1.0) * 0.8)
			draw_arc(c, ring_r, a0 + TAU * p * t0, a0 + TAU * p * t1 + 0.012, 3, col, 4.0, true)
		if not ready:
			var head := c + Vector2(cos(a0 + TAU * p), sin(a0 + TAU * p)) * ring_r
			draw_texture_rect(UIKit.glow_texture(), Rect2(head - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 0.95, 0.8, 0.9))
	# Bezel: one 1.5 dpx deep-gold ring around the cream face.
	var face := r - 2.0
	draw_circle(c, face, UITokens.PAPER_0, true, -1.0, true)
	draw_arc(c, r - UIKit.px(0.75), 0, TAU, 96, Color("#B98A3E"), UIKit.line_px(1.5), true)
	if not calm:
		draw_circle(c + Vector2(0, face * 0.25), face * 0.8, Color(1.0, 0.86, 0.6, 0.22 if ready else 0.12), true, -1.0, true)
	var gray := 1.0 if ready else 0.66
	if icon_texture:
		_draw_disc_texture(icon_texture, c, face, Color(gray, gray, gray * 1.02, 1.0), 1.06, Vector2(0, -0.04))
	elif icon_kind != "":
		var isz := face * 1.2
		Icons.draw_icon(self, icon_kind, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), Color(gray, gray, gray, 1.0) * icon_tint)
	if not ready and progress >= 0.0 and not calm:
		var h := clampf(1.0 - 2.0 * _shown_progress, -0.97, 0.97)
		if h < 0.95:
			var a0 := asin(h)
			var a1 := PI - a0
			var pts := PackedVector2Array()
			var n := 32
			for i in n + 1:
				var a := lerpf(a0, a1, float(i) / n)
				pts.append(c + Vector2(cos(a), sin(a)) * face)
			var half := cos(a0) * face
			var m := 10
			for i in range(1, m):
				var x := lerpf(-half, half, float(i) / m)
				var wave := sin(_t * 4.0 + x * 0.09) * 2.0 * (1.0 - absf(x) / maxf(half, 1.0))
				pts.append(c + Vector2(x, h * face + wave))
			draw_colored_polygon(pts, Color(UITokens.CTA.r, UITokens.CTA.g, UITokens.CTA.b, 0.22))
	draw_arc(c, face - 0.5, 0, TAU, 64, Color(1, 1, 1, 0.5), UIKit.px(1.0), true)
	if ready and not calm:
		var spk := UIKit.sparkle_texture()
		for i in 2:
			var a := _t * 1.6 + PI * i
			var q := c + Vector2(cos(a), sin(a)) * ring_r
			var sz := 22.0 + 6.0 * sin(_t * 7.0 + i)
			draw_texture_rect(spk, Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 0.98, 0.9, 0.95))
	# Ability badge: a small gold-ringed cream socket with the ult line icon.
	if badge_icon != "":
		var bc := c + Vector2(r * 0.74, -r * 0.74)
		var br := r * 0.3
		draw_texture_rect(UIKit.glow_texture(), Rect2(bc - Vector2(br, br) * 1.5 + Vector2(0, 2), Vector2(br, br) * 3.0), false, Color(sc.r, sc.g, sc.b, 0.16))
		draw_circle(bc, br, UITokens.PAPER_0, true, -1.0, true)
		draw_arc(bc, br - UIKit.px(0.5), 0, TAU, 48, UITokens.LINE_GOLD_DEEP, UIKit.line_px(1.0), true)
		var isz2 := br * 1.5
		# Ink glyph on cream (CTA rim amber when ready), never white on cream.
		Icons.draw_icon(self, badge_icon, Rect2(bc - Vector2(isz2, isz2) * 0.5, Vector2(isz2, isz2)), (UITokens.KEY_INK if calm else UITokens.CTA_RIM) if ready else Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.75))
	# Caption chip under the button: amber when ready, porcelain while charging.
	if caption != "":
		var f := UIKit.font_w("bold")
		var fs := 22
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(c.x - tw * 0.5 - 14.0, c.y + r - 6.0), Vector2(tw + 28.0, 32.0))
		if ready and calm:
			# A mini porcelain chip: white enamel, ONE 1 dpx deep-gold rim, a 1 dpx slate contact
			# shadow, the ink Bold label (the key button in small).
			var pts := GemDraw.chamfer_rect(chip, 6.0)
			var d1 := UIKit.px(1.0)
			var sh := PackedVector2Array()
			for q in pts:
				sh.append(q + Vector2(0, d1 * 1.5))
			draw_colored_polygon(sh, Color(0.12, 0.13, 0.2, 0.22))
			var cols := PackedColorArray()
			for q in pts:
				cols.append(Color("#FFFDF8").lerp(Color("#F1E9DA"), clampf((q.y - chip.position.y) / chip.size.y, 0.0, 1.0)))
			draw_polygon(pts, cols)
			GemDraw.outline(self, pts, Color("#9A7436"), UIKit.line_px(1.0))
		elif ready:
			var pts := GemDraw.chamfer_rect(chip, 6.0)
			draw_colored_polygon(pts, UITokens.CTA)
			GemDraw.outline(self, pts, Color(UITokens.CTA_RIM.r, UITokens.CTA_RIM.g, UITokens.CTA_RIM.b, 0.7), UIKit.line_px(1.0))
		else:
			draw_style_box(UIKit.lux("chip", Vector2.ZERO), chip)
		var tc := (UITokens.KEY_LABEL_DARK if calm else UIKit.CTA_TEXT) if ready else UITokens.INK
		draw_string(f, Vector2(c.x - tw * 0.5, chip.position.y + 23.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
