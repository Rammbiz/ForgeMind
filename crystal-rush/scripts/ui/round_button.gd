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

var icon_texture: Texture2D
var icon_kind := ""
var icon_tint := Color.WHITE
var caption := ""
var caption_color := UIKit.TEXT
var caption_icon := ""          # e.g. "coin" drawn before caption text
var badge := ""                 # small text in the top-right corner
var badge_icon := ""            # small vector icon in a gold coin at the top-right (ult style)
var radius := 44.0
var base_color := Color(0.1, 0.12, 0.2, 0.92)
var ring_color := UIKit.GOLD
var glow_color := Color(1.0, 0.6, 0.95)
var ready_color := Color(1.0, 0.78, 0.3)   # ult style: halo and ring once charged (gold reads on any world)
var disabled := false
var armed := false              # waiting for a confirming second tap
var highlight := false          # pulsing outer glow in the ring colour (keeps the icon)
var progress := -1.0            # 0..1 draws an arc around the button
var progress_color := UIKit.GOLD
var pulse := false
var ult_style := false
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


func _process(delta: float) -> void:
	_t += delta
	var target := 0.9 if _down else 1.0
	_press_scale = lerpf(_press_scale, target, minf(1.0, delta * 18.0))
	_shown_progress = lerpf(_shown_progress, clampf(progress, 0.0, 1.0), minf(1.0, delta * 8.0))
	_pop = maxf(0.0, _pop - delta * 1.6)
	queue_redraw()


## Plays the "just became ready" burst (ult style).
func burst() -> void:
	_pop = 1.0


func _has_point(point: Vector2) -> bool:
	var c := _circle_center()
	if point.distance_to(c) <= radius + 12.0:
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
			accept_event()
		elif _down and _touch == -1:
			_release(mb.position, false)
			accept_event()


func _release(pos: Vector2, canceled: bool) -> void:
	if not _down:
		return
	_down = false
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
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_down = false
		_touch = -1


func _draw() -> void:
	if ult_style:
		_draw_ult()
		return
	var c := _circle_center()
	var s := _press_scale
	if pulse and not disabled:
		s *= 1.0 + sin(_t * 4.0) * 0.03
	var r := radius * s
	var dim := 0.5 if disabled else 1.0
	# v2 edge button: soft shadow, cream disc, ONE thin gold ring (+ a faint inner ring).
	var tex := UIKit.kit_texture("edge_button")
	for i in 4:
		draw_circle(c + Vector2(0, 2.0 + i * 1.2), r + i * 0.8, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.055), true, -1.0, true)
	var ring := UITokens.HAIRLINE if ring_color == UIKit.GOLD else ring_color
	if disabled:
		ring = Color(UITokens.HAIRLINE.r, UITokens.HAIRLINE.g, UITokens.HAIRLINE.b, 0.5)
	if highlight and not armed:
		var k := 0.5 + 0.5 * sin(_t * TAU / UITokens.GLOW_PERIOD)
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), false, Color(1.0, 0.78, 0.4, 0.28 + 0.22 * k))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(dim, dim, dim, 1.0))
	else:
		draw_circle(c, r, UITokens.PAPER_1 if not disabled else UITokens.PAPER_3, true, -1.0, true)
		draw_circle(c + Vector2(0, -r * 0.1), r * 0.86, UITokens.PAPER_0 if not disabled else UITokens.PAPER_3, true, -1.0, true)
		draw_arc(c, r - 0.75, 0, TAU, 64, ring, 1.6, true)
		draw_arc(c, r - 4.5, 0, TAU, 64, Color(ring.r, ring.g, ring.b, 0.38), 1.0, true)
	if armed:
		draw_arc(c, r + 5.0, 0, TAU, 64, Color(UIKit.PLUS.r, UIKit.PLUS.g, UIKit.PLUS.b, 0.45 + 0.25 * sin(_t * 8.0)), 3.0, true)
	if highlight and not armed:
		draw_arc(c, r + 4.0, 0, TAU, 64, Color(UITokens.CTA.r, UITokens.CTA.g, UITokens.CTA.b, 0.55 + 0.3 * sin(_t * TAU / UITokens.GLOW_PERIOD)), 2.0, true)
	if progress >= 0.0:
		var pc := progress_color if progress_color != UIKit.GOLD else UITokens.CTA
		draw_arc(c, r + 5.0, 0, TAU, 64, Color(UITokens.PAPER_3.r, UITokens.PAPER_3.g, UITokens.PAPER_3.b, 0.9), 4.0, true)
		draw_arc(c, r + 5.0, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 64, pc, 4.0, true)
	var icon_size := r * 1.12
	var icon_rect := Rect2(c - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	if armed:
		Icons.draw_icon(self, "check", icon_rect.grow(-icon_size * 0.08), UIKit.PLUS)
	elif icon_texture:
		_draw_disc_texture(icon_texture, c, r - 4.0, Color(dim, dim, dim, 1.0) * icon_tint)
		draw_arc(c, r - 3.5, 0, TAU, 64, ring, 1.5, true)
	elif icon_kind != "":
		# Line icons take ink on the cream disc unless the caller tinted them.
		var col := icon_tint
		if icon_tint == Color.WHITE:
			col = UITokens.INK if KitIcons.has_line(icon_kind) else Color.WHITE
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
	# Gold notify disc ("!" or a count) with a brown glyph: no red dots in v2.
	var f := UIKit.font_w("extrabold")
	var bs := 17
	var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
	var br := maxf(13.0, bw * 0.5 + 7.0)
	var bc := c + Vector2(r * 0.72, -r * 0.72)
	if badge.length() > 1:
		var rr := Rect2(bc - Vector2(br, 13.0), Vector2(br * 2.0, 26.0))
		draw_style_box(UIKit.cbox(UITokens.NOTIFY, 8, Color(1, 0.97, 0.9), 2, Vector2.ZERO), rr)
	else:
		draw_circle(bc + Vector2(0, 1.5), 14.0, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.2), true, -1.0, true)
		draw_circle(bc, 14.0, Color(1, 0.98, 0.92), true, -1.0, true)
		draw_circle(bc, 12.5, UITokens.NOTIFY, true, -1.0, true)
	draw_string(f, Vector2(bc.x - bw * 0.5, bc.y + f.get_ascent(bs) * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, UIKit.BROWN)


func _draw_caption(c: Vector2, r: float, dim: float) -> void:
	if caption == "":
		return
	# Porcelain chip under the disc, ink label (it usually floats over a 3D scene).
	var f2 := UIKit.font(true)
	var fs := 20
	var tw := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var iw := 22.0 if caption_icon != "" else 0.0
	var total := tw + iw + (4.0 if iw > 0.0 else 0.0)
	var cap_y := c.y + r + 4.0
	var pill := Rect2(Vector2(c.x - total * 0.5 - 12.0, cap_y - 2.0), Vector2(total + 24.0, 30.0))
	draw_style_box(UIKit.lux("chip", Vector2.ZERO), pill)
	var x := c.x - total * 0.5
	if iw > 0.0:
		Icons.draw_icon(self, caption_icon, Rect2(Vector2(x, cap_y + 2.0), Vector2(iw, iw)), Color(1, 1, 1, dim))
		x += iw + 4.0
	var cc := caption_color if caption_color != UIKit.TEXT else UITokens.INK
	draw_string(f2, Vector2(x, cap_y + 20.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc * Color(1, 1, 1, 1.0 if not disabled else 0.6))


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
	if ready:
		var k := 0.6 + 0.4 * sin(_t * 5.0)
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 2.2, Vector2(r, r) * 4.4), false, Color(1.0, 0.78, 0.38, 0.5 + 0.2 * k))
		for w in 2:
			var wave := fmod(_t * 0.8 + w * 0.5, 1.0)
			draw_arc(c, r + 12.0 + wave * 30.0, 0, TAU, 64, Color(1.0, 0.86, 0.52, 0.7 * (1.0 - wave)), 2.5 * (1.0 - wave) + 0.8, true)
	if _pop > 0.0:
		draw_arc(c, r + 8.0 + (1.0 - _pop) * 64.0, 0, TAU, 64, Color(1, 0.97, 0.88, _pop * 0.9), 5.0 * _pop + 1.0, true)
	for i in 5:
		draw_circle(c + Vector2(0, 3.0 + i * 1.4), r + 9.0 + i, Color(sc.r, sc.g, sc.b, 0.05), true, -1.0, true)
	# Charge track (cream) with hairline edges and an amber fill.
	var ring_r := r + 6.0
	draw_arc(c, ring_r, 0, TAU, 72, Color(UITokens.PAPER_0.r, UITokens.PAPER_0.g, UITokens.PAPER_0.b, 0.96), 11.0, true)
	draw_arc(c, ring_r + 5.5, 0, TAU, 72, UITokens.HAIRLINE, 1.2, true)
	var p := 1.0 if ready else _shown_progress
	if p > 0.002:
		var segs := maxi(3, int(72 * p))
		var a0 := -PI / 2.0
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var col := UITokens.CTA_LO.lerp(UITokens.CTA_HI, t1 * p)
			if ready:
				var ang := fposmod(t0 * TAU - _t * 2.6, TAU)
				col = UITokens.CTA.lerp(Color(1, 0.98, 0.9), clampf(1.0 - ang / 1.3, 0.0, 1.0) * 0.8)
			draw_arc(c, ring_r, a0 + TAU * p * t0, a0 + TAU * p * t1 + 0.012, 3, col, 7.0, true)
		if not ready:
			var head := c + Vector2(cos(a0 + TAU * p), sin(a0 + TAU * p)) * ring_r
			draw_texture_rect(UIKit.glow_texture(), Rect2(head - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 0.95, 0.8, 0.9))
	# Gold bezel: dark seat, light rim, hairline.
	draw_circle(c, r, Color("#B98A3E"), true, -1.0, true)
	draw_circle(c, r - 1.4, UITokens.GOLD_HI, true, -1.0, true)
	draw_circle(c, r - 3.2, Color("#C9A86A"), true, -1.0, true)
	var face := r - 4.5
	draw_circle(c, face, UITokens.PAPER_0, true, -1.0, true)
	draw_circle(c + Vector2(0, face * 0.25), face * 0.8, Color(gc.r, gc.g, gc.b, 0.16), true, -1.0, true)
	var gray := 1.0 if ready else 0.66
	if icon_texture:
		_draw_disc_texture(icon_texture, c, face, Color(gray, gray, gray * 1.02, 1.0), 1.06, Vector2(0, -0.04))
	elif icon_kind != "":
		var isz := face * 1.2
		Icons.draw_icon(self, icon_kind, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), Color(gray, gray, gray, 1.0) * icon_tint)
	if not ready and progress >= 0.0:
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
	draw_arc(c, face - 0.5, 0, TAU, 64, Color(1, 1, 1, 0.5), 1.2, true)
	if ready:
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
		draw_circle(bc + Vector2(0, 2), br + 2.5, Color(sc.r, sc.g, sc.b, 0.22), true, -1.0, true)
		draw_circle(bc, br + 2.0, Color("#C9A86A"), true, -1.0, true)
		draw_circle(bc, br, UITokens.PAPER_0, true, -1.0, true)
		var isz2 := br * 1.5
		Icons.draw_icon(self, badge_icon, Rect2(bc - Vector2(isz2, isz2) * 0.5, Vector2(isz2, isz2)), Color.WHITE if ready else Color(0.75, 0.75, 0.78))
	# Caption chip under the button: amber when ready, porcelain while charging.
	if caption != "":
		var f := UIKit.font_w("extrabold")
		var fs := 19
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(c.x - tw * 0.5 - 14.0, c.y + r - 6.0), Vector2(tw + 28.0, 28.0))
		if ready:
			draw_style_box(UIKit.cbox(UITokens.CTA, 7, Color("#FFF0C8"), 2, Vector2.ZERO), chip)
		else:
			draw_style_box(UIKit.lux("chip", Vector2.ZERO), chip)
		var tc := UIKit.CTA_TEXT if ready else UITokens.INK
		if ready:
			draw_string(f, Vector2(c.x - tw * 0.5, chip.position.y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.5, 0.22, 0.02, 0.45))
		draw_string(f, Vector2(c.x - tw * 0.5, chip.position.y + 20.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
