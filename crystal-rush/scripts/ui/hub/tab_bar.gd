class_name HubTabBar
extends Control
## Hub bottom navigation, UI v3.1 "porcelain glass" (binding spec ui_v3_spec.md §6): one frosted
## cream strip (KitNav.Strip under KitGlass.frost_nav(): its tint ramps 0.20 -> 0.38 -> 0.80 -> 0.88 from
## the hairline down, so the world ghosts through the upper third on Play) whose ONLY line is a
## gently arched engraved hairline (1 dpx deep gold + 1 dpx light, fading to the sides); five
## monoline gold glyphs of one family (KitIcons.nav, 48 px, 2.0 px) with 22 px Medium labels:
## Магазин · Арсенал · Грати · Герої · Казарми. Грати is a topaz set into the hairline inside a
## slender double ring, always lit (quiet at 72 % value, 0.85 alpha, ring 0.70 when another tab is active).
## The active tab (§6.4) wins at arm's length: a 1.5 dpx amber underline with facet ends under
## the label, a topaz diamond riding the hairline with a 52 px amber glint, a soft gold-leaf wash
## behind the glyph (a glow, never a tile), the glyph in deep gold with a 40 % duotone, the label
## in clear burnt amber (NAV_LABEL_ON). Same label size and weight in both states. No medallion, nothing breathes.
## Motion (§6.7): the marker glides 180 ms cubic ease-out, glyph colours cross-fade in 120 ms, a
## press flashes the wash (no scale); Reduce Motion snaps. The bar redraws only while moving.
## Locked tabs (UnlockQueue) keep their name, fade (glyph 36 %, label 50 %) and carry a 16 px line
## lock; the level needed is in the tap toast. Badges are 9 px amber diamonds (never numbers).
## anchor(id) returns an invisible Control on a tab glyph (RewardFly target).
## Layout (720 canvas, control 720 x TAB_BAR_H + safe inset): hairline apex y 10 (sides y 15),
## Play ring centre y 30 (r 30: it rises 10 px above the hairline), glyph boxes y 20..68, label
## baseline 16 px above the strip bottom, underline 8 px under the baseline, 5 x 144 px slots.
## Bitmap overrides via the kit: nav_bar.png, nav_medallion.png, icon_tab_*.png, badge_gem.png.

signal tab_pressed(id: String)
signal locked_pressed(id: String)

const TABS: Array[String] = ["shop", "arsenal", "play", "heroes", "barracks"]
const LABELS := {"shop": "TAB_SHOP", "arsenal": "TAB_ARSENAL", "play": "NAV_PLAY", "heroes": "TAB_HEROES", "barracks": "TAB_BARRACKS"}
const ICONS := {"shop": "tab_shop", "arsenal": "tab_arsenal", "play": "tab_play", "heroes": "tab_heroes", "barracks": "tab_barracks"}
const MED_R := UITokens.NAV_PLAY_R   ## legacy name: the Play ring radius
const GLYPH_Y := 10.0                ## glyph top below the hairline apex (box y 20..68)
const LABEL_BASE := 16.0             ## label baseline above the strip bottom (inset excluded)
const UNDERLINE_DY := 8.0            ## underline below the label baseline
const GLIDE := 0.18
const COLOR_FADE := 0.12
const FLASH_TIME := 0.25

var selected := "play"
var bottom_inset := 0.0:
	set(v):
		bottom_inset = v
		if _strip:
			_strip.label_y = _label_cap_y()
		queue_redraw()
var _locked := {}          ## id -> level number it opens after (0 = open)
var _badges := {}          ## id -> "" | "arrow" | "!"
var _anchors := {}         ## id -> Control
var _sel_x := -1.0         ## marker x (animated)
var _from_x := -1.0
var _glide_t := 1.0
var _on := {}              ## id -> 0..1 glyph / label colour (cross-fades)
var _press := ""
var _flash := {}           ## id -> 0..1 (the wash flash on a press, an unlock or a reward)
var _strip: KitNav.Strip
static var _label_font: FontVariation


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_strip = KitNav.Strip.new()
	_strip.top = _bar_top()
	_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_strip)
	for id in TABS:
		var a := Control.new()
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.size = Vector2(56, 56)
		add_child(a)
		_anchors[id] = a
		_on[id] = 1.0 if id == selected else 0.0
	set_process(false)


func _ready() -> void:
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_strip.ring_c = _play_center()
	_strip.ring_r = MED_R
	_strip.ring_on = float(_on.get("play", 0.0))
	_strip.label_y = _label_cap_y()
	_strip.queue_redraw()
	if _glide_t >= 1.0 and size.x > 0.0:
		_sel_x = _slot_center_x(TABS.find(selected))
	_place_anchors()
	queue_redraw()


func set_selected(id: String) -> void:
	if id == selected:
		return
	selected = id
	if size.x > 0.0:
		var target := _slot_center_x(TABS.find(id))
		if UITokens.reduce_motion() or _sel_x < 0.0:
			_sel_x = target
			_glide_t = 1.0
			for t in TABS:
				_on[t] = 1.0 if t == id else 0.0
			_strip.ring_on = float(_on["play"])
		else:
			_from_x = _sel_x
			_glide_t = 0.0
			set_process(true)
	queue_redraw()


func set_locked(id: String, after_level: int) -> void:
	_locked[id] = after_level
	queue_redraw()


func set_badge(id: String, badge: String) -> void:
	if str(_badges.get(id, "")) != badge:
		_badges[id] = badge
		queue_redraw()


func is_locked(id: String) -> bool:
	return int(_locked.get(id, 0)) > 0


func locked_level(id: String) -> int:
	return int(_locked.get(id, 0))


## Flashes a tab (it just unlocked, or a reward landed on it): a soft light, no bounce.
func pop(id: String) -> void:
	_flash[id] = 1.0
	set_process(true)


func anchor(id: String) -> Control:
	return _anchors.get(id)


## y of the hairline apex. Only the Play ring rises above it.
func _bar_top() -> float:
	return UITokens.NAV_RISE


func _slot_rect(i: int) -> Rect2:
	var w := size.x / TABS.size()
	var top := _bar_top()
	return Rect2(Vector2(i * w, top), Vector2(w, size.y - bottom_inset - top))


func _slot_center_x(i: int) -> float:
	return (i + 0.5) * size.x / TABS.size()


func _play_center() -> Vector2:
	return Vector2(_slot_center_x(TABS.find("play")), _bar_top() + MED_R - UITokens.NAV_RISE)


func _glyph_rect(i: int) -> Rect2:
	var g := UITokens.NAV_GLYPH
	return Rect2(Vector2(_slot_center_x(i) - g * 0.5, _bar_top() + GLYPH_Y), Vector2(g, g))


func _label_y() -> float:
	return size.y - bottom_inset - LABEL_BASE


func _label_cap_y() -> float:
	return _label_y() - 24.0


func _hairline_y(x: float) -> float:
	return KitNav.arch_y(x, size.x, _bar_top())


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return
	var moving := false
	var target := _slot_center_x(TABS.find(selected))
	if _glide_t < 1.0:
		_glide_t = minf(1.0, _glide_t + delta / GLIDE)
		var e := 1.0 - pow(1.0 - _glide_t, 3.0)
		_sel_x = lerpf(_from_x, target, e)
		moving = true
	else:
		_sel_x = target
	for id in TABS:
		var want := 1.0 if id == selected else 0.0
		var cur := float(_on[id])
		if not is_equal_approx(cur, want):
			_on[id] = move_toward(cur, want, delta / COLOR_FADE)
			moving = true
	_strip.ring_on = float(_on["play"])
	for id in _flash.keys():
		_flash[id] = maxf(0.0, float(_flash[id]) - delta / FLASH_TIME)
		moving = true
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
	queue_redraw()
	if not moving:
		set_process(false)


func _place_anchors() -> void:
	for i in TABS.size():
		var a: Control = _anchors[TABS[i]]
		var c := _play_center() if TABS[i] == "play" else _glyph_rect(i).get_center()
		a.position = c - Vector2(28, 28)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := clampi(int(event.position.x / (size.x / TABS.size())), 0, TABS.size() - 1)
		var id := TABS[i]
		if event.pressed:
			_press = id
			queue_redraw()
		else:
			if _press == id:
				if is_locked(id):
					locked_pressed.emit(id)
				else:
					# The press answer: a short wash flash (0.25 s), no scale.
					if not UITokens.reduce_motion():
						_flash[id] = 1.0
						set_process(true)
					tab_pressed.emit(id)
			_press = ""
			queue_redraw()
		accept_event()


## Labels: Medium, +1 px tracking, in both states (no size or weight jump).
static func _lfont() -> Font:
	if _label_font == null:
		_label_font = FontVariation.new()
		_label_font.base_font = UIKit.font_w("medium")
		_label_font.spacing_glyph = 1
	return _label_font


func _label_w(id: String, r: Rect2) -> Vector2:
	var label := HomeText.t(LABELS[id])
	var f := _lfont()
	var fs := UITokens.NAV_LABEL
	while fs > 20 and f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 10.0:
		fs -= 1
	return Vector2(f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, fs)


func _draw() -> void:
	if size.x <= 0.0:
		return
	if _sel_x < 0.0:
		_sel_x = _slot_center_x(TABS.find(selected))
	var top := _bar_top()
	var pc := _play_center()
	var tex := UIKit.kit_texture("nav_bar")
	if tex:
		draw_style_box(UIKit.lux("nav_bar"), Rect2(Vector2(0, top), Vector2(size.x, size.y - top)))
	# The only line: the arched hairline, open where the Play stone is set into it.
	KitNav.draw_top_line(self, top, 0.0, size.x, Vector2(pc.x - MED_R - 3.0, pc.x + MED_R + 3.0), UITokens.NAV_SAG)
	var label_y := _label_y()
	var sel_i := TABS.find(selected)
	# The active state travels as one: wash (on the glyph), underline (under the label), diamond
	# (on the hairline; on the Play ring's crown when Play is active).
	var near_play := clampf(1.0 - absf(_sel_x - pc.x) / (size.x / TABS.size()), 0.0, 1.0)
	near_play = near_play * near_play * (3.0 - 2.0 * near_play)
	var glyph_cy := top + GLYPH_Y + UITokens.NAV_GLYPH * 0.5
	var wash_c := Vector2(_sel_x, lerpf(glyph_cy, pc.y, near_play))
	if sel_i >= 0:
		var flash_here := float(_flash.get(selected, 0.0))
		KitNav.draw_wash(self, wash_c, 1.0 + 0.8 * flash_here)
	# Flash on a tab that is not the selected one (an unlock, a reward landing).
	for id: String in _flash.keys():
		if id != selected:
			var fi := TABS.find(id)
			var fc := pc if id == "play" else _glyph_rect(fi).get_center()
			KitNav.draw_wash(self, fc, 0.8 * float(_flash[id]))
	for i in TABS.size():
		var id := TABS[i]
		var r := _slot_rect(i)
		var cx := r.get_center().x
		var on := float(_on.get(id, 0.0))
		var locked := is_locked(id)
		var dim := 0.36 if locked else 1.0
		var gr := _glyph_rect(i)
		if id == "play":
			KitNav.draw_play_ring(self, pc, MED_R, on, dim)
		else:
			var ov := UIKit.kit_texture("icon_" + ICONS[id])
			var col := UITokens.NAV_GOLD.lerp(UITokens.NAV_GOLD_ON, on)
			col.a = dim
			if ov:
				draw_texture_rect(ov, gr, false, Color(1, 1, 1, dim))
			else:
				KitIcons.nav(self, id, gr, col, UITokens.NAV_DUOTONE * on, UITokens.CTA_HI)
		var label := HomeText.t(LABELS[id])
		var lw := _label_w(id, r)
		var lc := UITokens.INK_DIM_GLASS.lerp(UITokens.NAV_LABEL_ON, on)
		lc.a = 0.5 if locked else 1.0
		draw_string(_lfont(), Vector2(roundf(cx - lw.x * 0.5), roundf(label_y)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(lw.y), lc)
		if locked:
			var lk := Rect2(gr.end - Vector2(12, 14), Vector2(16, 16))
			if id == "play":
				lk = Rect2(pc + Vector2(MED_R * 0.45, MED_R * 0.3), Vector2(16, 16))
			Icons.line(self, "lock", lk, Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.7))
		var bpos := Vector2(gr.end.x + 7.0, gr.position.y + 3.0)
		if id == "play":
			bpos = pc + Vector2(MED_R * 0.74, -MED_R * 0.62)
		# The active tab already carries the amber diamond on the hairline: no badge beside it.
		if on < 0.5:
			_draw_badge(id, bpos)
	if sel_i < 0:
		return
	# Underline width = the label width (interpolated while gliding) + 16, clamped 56..120.
	var uw := 0.0
	var wsum := 0.0
	for i in TABS.size():
		var k := clampf(1.0 - absf(_sel_x - _slot_center_x(i)) / (size.x / TABS.size()), 0.0, 1.0)
		uw += (_label_w(TABS[i], _slot_rect(i)).x + 16.0) * k
		wsum += k
	uw = clampf(uw / maxf(wsum, 0.001), 56.0, 120.0)
	var line_x := _sel_x
	var line_p := Vector2(line_x, GemDraw.pixel_y(self, _hairline_y(line_x)))
	var slope := 2.0 * UITokens.NAV_SAG * (line_x - size.x * 0.5) / pow(size.x * 0.5, 2.0)
	# Over the Play ring the diamond climbs onto the ring's crown (its glint fades out there).
	line_p.y = lerpf(line_p.y, pc.y - MED_R, near_play)
	KitNav.draw_indicator(self, Vector2(_sel_x, label_y + UNDERLINE_DY), uw, 1.0)
	if near_play < 0.98:
		KitNav.draw_line_gem(self, line_p, 1.0, slope * (1.0 - near_play))
	else:
		GemDraw.draw_diamond(self, line_p, 12.0, UITokens.TOPAZ, Color("#A8662A"))


## Something waits on this tab: a 9 px amber diamond with a 1 px cream edge (no glow, no pulse).
func _draw_badge(id: String, at: Vector2) -> void:
	var b := str(_badges.get(id, ""))
	if b == "" or is_locked(id):
		return
	var tex := UIKit.kit_texture("badge_gem")
	if tex:
		draw_texture_rect(tex, Rect2(at - Vector2(7, 7), Vector2(14, 14)), false)
		return
	var h := 4.5 + UIKit.px(1.0)
	var hw := h * 0.75
	var pts := PackedVector2Array([at + Vector2(0, -h - 1.0), at + Vector2(hw + 1.0, 0), at + Vector2(0, h + 1.0), at + Vector2(-hw - 1.0, 0)])
	draw_colored_polygon(pts, Color(1.0, 0.98, 0.92, 0.95))
	GemDraw.draw_diamond(self, at, 9.0, UITokens.NAV_BADGE, Color("#B5651F"))
