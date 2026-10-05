class_name RoundButton
extends Control
## Circular touch button with an icon (texture or vector), optional caption and badges.
## Reacts to real touches of any finger (InputEventScreenTouch, so a second finger can tap it
## while the first one steers) and to a real mouse; emulated events are ignored so one tap
## never fires twice.
## `ult_style` turns it into the premium ultimate button: the hero portrait clipped to the
## disc, a gold bezel, a charge ring that fills with `progress`, and a pulsing glow with
## orbiting sparkles while `highlight` (ready) is on.

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
		s *= 1.0 + sin(_t * 5.0) * 0.04
	var r := radius * s
	var dim := 0.45 if disabled else 1.0
	# Shadow
	draw_circle(c + Vector2(0, 5), r + 1.0, Color(0, 0, 0.02, 0.4))
	# Gold bezel with a light top edge.
	var ring := ring_color if not disabled else Color(0.4, 0.42, 0.48)
	draw_circle(c, r, ring.darkened(0.45))
	draw_circle(c + Vector2(0, -1.0), r - 1.0, ring)
	draw_circle(c + Vector2(0, 1.0), r - 3.5, ring.darkened(0.35))
	# Glass face
	draw_circle(c, r - 4.5, base_color.darkened(0.25 if disabled else 0.0))
	draw_circle(c + Vector2(0, -r * 0.1), r * 0.8, base_color.lightened(0.07))
	_gloss(c, r - 4.5)
	if armed:
		ring = UIKit.GREEN
		draw_arc(c, r + 5.0, 0, TAU, 48, Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.35 + 0.25 * sin(_t * 8.0)), 6.0, true)
	if highlight and not armed:
		# Outside the progress arc so both stay readable.
		draw_arc(c, r + 13.0, 0, TAU, 48, Color(ring.r, ring.g, ring.b, 0.45 + 0.35 * sin(_t * 8.0)), 5.0, true)
	if progress >= 0.0:
		draw_arc(c, r + 6.0, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 48, progress_color, 5.0, true)
	var icon_size := r * 1.2
	var icon_rect := Rect2(c - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	var mod := Color(dim, dim, dim, 1.0) * icon_tint
	if armed:
		Icons.draw_icon(self, "check", icon_rect.grow(-icon_size * 0.1), UIKit.GREEN)
	elif icon_texture:
		_draw_disc_texture(icon_texture, c, r - 5.0, mod)
	elif icon_kind != "":
		# Soft dark under-print keeps white icons crisp on the glass.
		Icons.draw_icon(self, icon_kind, Rect2(icon_rect.position + Vector2(0, 2), icon_rect.size).grow(-icon_size * 0.06), Color(0, 0, 0.05, 0.45 * dim))
		Icons.draw_icon(self, icon_kind, icon_rect.grow(-icon_size * 0.06), mod)
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
	var f := UIKit.font(true)
	var bs := 20
	var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x + 14.0
	var br := Rect2(c + Vector2(r * 0.45, -r - 2.0), Vector2(maxf(bw, 28.0), 28.0))
	draw_style_box(UIKit.box(UIKit.PRIMARY, UIKit.PRIMARY_DARK, 14, 2, 0, Vector2.ZERO), br)
	draw_string(f, br.position + Vector2(7, 21), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(0.2, 0.08, 0.02))


func _draw_caption(c: Vector2, r: float, dim: float) -> void:
	if caption == "":
		return
	var f2 := UIKit.font(true)
	var fs := 22
	var tw := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var iw := 22.0 if caption_icon != "" else 0.0
	var total := tw + iw + (4.0 if iw > 0.0 else 0.0)
	var cap_y := c.y + r + 4.0
	var pill := Rect2(Vector2(c.x - total * 0.5 - 12.0, cap_y - 2.0), Vector2(total + 24.0, 30.0))
	draw_style_box(UIKit.box(Color(0.03, 0.04, 0.09, 0.88), UIKit.GOLD.darkened(0.3), 15, 1, 0, Vector2.ZERO), pill)
	var x := c.x - total * 0.5
	if iw > 0.0:
		Icons.draw_icon(self, caption_icon, Rect2(Vector2(x, cap_y + 2.0), Vector2(iw, iw)), Color(1, 1, 1, dim))
		x += iw + 4.0
	draw_string_outline(f2, Vector2(x, cap_y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(f2, Vector2(x, cap_y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, caption_color * Color(1, 1, 1, 1.0 if not disabled else 0.8))


# ------------------------------------------------------------------ ult style

func _draw_ult() -> void:
	var c := _circle_center()
	var ready := highlight and not disabled
	var s := _press_scale
	if ready:
		s *= 1.0 + 0.045 * sin(_t * 6.0)
	s *= 1.0 + 0.18 * _pop * _pop
	var r := radius * s
	var gc := glow_color
	# Ready glow: soft halo + breathing ring.
	if ready:
		gc = ready_color
		var k := 0.6 + 0.4 * sin(_t * 6.0)
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 2.4, Vector2(r, r) * 4.8), false, Color(gc.r, gc.g, gc.b, 0.75 + 0.25 * k))
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.5, Vector2(r, r) * 3.0), false, Color(1, 1, 1, 0.18 + 0.12 * k))
		for w in 2:
			var wave := fmod(_t * 0.9 + w * 0.5, 1.0)
			draw_arc(c, r + 12.0 + wave * 34.0, 0, TAU, 64, Color(gc.r, gc.g, gc.b, 0.85 * (1.0 - wave)), 5.0 * (1.0 - wave) + 1.0, true)
	if _pop > 0.0:
		draw_arc(c, r + 8.0 + (1.0 - _pop) * 70.0, 0, TAU, 64, Color(1, 1, 1, _pop * 0.9), 8.0 * _pop + 1.0, true)
	# Shadow
	draw_circle(c + Vector2(0, 6), r + 10.0, Color(0, 0, 0.02, 0.5))
	# Charge track and ring (outside the bezel).
	var ring_r := r + 6.0
	draw_arc(c, ring_r, 0, TAU, 72, Color(0.02, 0.03, 0.08, 0.92), 13.0, true)
	var p := 1.0 if ready else _shown_progress
	if p > 0.002:
		var segs := maxi(3, int(72 * p))
		var a0 := -PI / 2.0
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var col := progress_color.lerp(gc.lightened(0.2), t1 * p)
			if ready:
				# A bright highlight runs around the full ring.
				var ang := fposmod(t0 * TAU - _t * 3.0, TAU)
				col = gc.lerp(Color.WHITE, clampf(1.0 - ang / 1.4, 0.0, 1.0) * 0.85)
			draw_arc(c, ring_r, a0 + TAU * p * t0, a0 + TAU * p * t1 + 0.012, 3, col, 9.0, true)
		if not ready:
			var head := c + Vector2(cos(a0 + TAU * p), sin(a0 + TAU * p)) * ring_r
			draw_texture_rect(UIKit.glow_texture(), Rect2(head - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, 0.95))
	# Gold bezel
	draw_circle(c, r, Color(0.45, 0.24, 0.05))
	draw_circle(c + Vector2(0, -1.2), r - 1.2, Color(1.0, 0.86, 0.45))
	draw_circle(c + Vector2(0, 1.5), r - 4.0, Color(0.8, 0.5, 0.14))
	draw_circle(c, r - 6.0, Color(0.2, 0.1, 0.03))
	# Face: deep radial gradient
	var face := r - 7.0
	for i in 6:
		var k2 := 1.0 - i * 0.12
		draw_circle(c + Vector2(0, -face * 0.08 * i / 5.0), face * k2, base_color.lerp(gc.darkened(0.35), i * 0.09))
	var gray := 1.0 if ready else 0.5
	if icon_texture:
		_draw_disc_texture(icon_texture, c, face, Color(gray, gray, gray * 1.05, 1.0), 1.06, Vector2(0, -0.04))
	elif icon_kind != "":
		var isz := face * 1.3
		Icons.draw_icon(self, icon_kind, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), Color(gray, gray, gray, 1.0) * icon_tint)
	if not ready and progress >= 0.0:
		# Charge fill rising from the bottom as a translucent violet tide.
		var h := clampf(1.0 - 2.0 * _shown_progress, -0.97, 0.97)   # surface height, -1 top .. 1 bottom
		if h < 0.95:
			# Arc of the disc below the surface (screen y grows down), then a gently waving surface.
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
				var wave := sin(_t * 4.0 + x * 0.09) * 2.2 * (1.0 - absf(x) / maxf(half, 1.0))
				pts.append(c + Vector2(x, h * face + wave))
			draw_colored_polygon(pts, Color(gc.r, gc.g, gc.b, 0.22))
	_gloss(c, face)
	# Inner rim light
	draw_arc(c, face - 0.5, 0, TAU, 64, Color(1, 1, 1, 0.18), 1.5, true)
	# Orbiting sparkles while ready.
	if ready:
		var spk := UIKit.sparkle_texture()
		for i in 3:
			var a := _t * 2.2 + TAU * i / 3.0
			var q := c + Vector2(cos(a), sin(a)) * ring_r
			var sz := 26.0 + 8.0 * sin(_t * 9.0 + i)
			draw_texture_rect(spk, Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, 0.95))
	# Ability badge (top-right gold coin with the ult icon).
	if badge_icon != "":
		var bc := c + Vector2(r * 0.72, -r * 0.72)
		var br := r * 0.3
		draw_circle(bc + Vector2(0, 2), br + 3.0, Color(0, 0, 0, 0.35))
		draw_circle(bc, br + 2.5, Color(0.42, 0.22, 0.04))
		draw_circle(bc, br + 1.0, Color(1.0, 0.86, 0.42))
		draw_circle(bc, br - 2.0, Color(0.12, 0.08, 0.2))
		var isz2 := br * 1.5
		Icons.draw_icon(self, badge_icon, Rect2(bc - Vector2(isz2, isz2) * 0.5, Vector2(isz2, isz2)), Color(1.0, 0.92, 0.6) if ready else Color(0.7, 0.7, 0.75))
	# Caption chip ("УЛЬТА" / percentage) under the button.
	if caption != "":
		var f := UIKit.font(true)
		var fs := 20
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var chip := Rect2(Vector2(c.x - tw * 0.5 - 14.0, c.y + r - 8.0), Vector2(tw + 28.0, 28.0))
		var sb := UIKit.box(Color(0.95, 0.62, 0.18) if ready else Color(0.06, 0.07, 0.14, 0.95), Color(1.0, 0.92, 0.6) if ready else UIKit.GOLD.darkened(0.3), 14, 2, 0, Vector2.ZERO)
		draw_style_box(sb, chip)
		var tc := Color(0.24, 0.1, 0.02) if ready else UIKit.TEXT
		draw_string(f, Vector2(c.x - tw * 0.5, chip.position.y + 21.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
