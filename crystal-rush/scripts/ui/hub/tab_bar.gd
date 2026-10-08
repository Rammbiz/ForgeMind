class_name HubTabBar
extends Control
## Hub bottom navigation, UI v3 "porcelain glass" (direction A): a slim frosted cream-glass strip
## (KitNav.Strip: the blurred world glows through) edged by ONE fading 1-device-px gold hairline
## with a light line under it; five monoline gold glyphs of one family (KitIcons.nav) with small
## Medium labels: Магазин · Арсенал · Грати · Герої · Казарми. ГРАТИ is a slender raised ring (a
## fine double gold ring around a faceted topaz crystal) set into the hairline like a stone.
## The active tab is marked by light, not mass: a small cut-gem diamond riding the hairline with a
## short 2 px amber glint, a soft warm light wash behind the glyph, the glyph in deep gold with a
## thin amber duotone, the label in ink. No medallion, no bounce, nothing breathes.
## Locked tabs (UnlockQueue) keep their name, fade, and carry a tiny line lock; the level needed
## is in the tap toast. Badges are 8 px amber diamonds (never numbers, never red dots).
## anchor(id) returns an invisible Control on a tab glyph (RewardFly target).
## Bitmap overrides via the kit: nav_bar.png, nav_medallion.png, icon_tab_*.png.

signal tab_pressed(id: String)
signal locked_pressed(id: String)

const TABS: Array[String] = ["shop", "arsenal", "play", "heroes", "barracks"]
const LABELS := {"shop": "TAB_SHOP", "arsenal": "TAB_ARSENAL", "play": "NAV_PLAY", "heroes": "TAB_HEROES", "barracks": "TAB_BARRACKS"}
const ICONS := {"shop": "tab_shop", "arsenal": "tab_arsenal", "play": "tab_play", "heroes": "tab_heroes", "barracks": "tab_barracks"}
const MED_R := UITokens.NAV_PLAY_R   ## legacy name: the Play ring radius
const GLYPH_Y := 9.0                 ## glyph top below the strip's hairline
const LABEL_BASE := 18.0             ## label baseline above the strip bottom (inset excluded)

var selected := "play"
var bottom_inset := 0.0
var _locked := {}          ## id -> level number it opens after (0 = open)
var _badges := {}          ## id -> "" | "arrow" | "!"
var _anchors := {}         ## id -> Control
var _sel_x := -1.0
var _press := ""
var _pop := {}             ## id -> 0..1 (a soft light flash, no scale bounce)
var _strip: KitNav.Strip
static var _label_fonts := {}


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


func _ready() -> void:
	resized.connect(_place_ring)
	_place_ring()


func _place_ring() -> void:
	var i := TABS.find("play")
	_strip.ring_c = _play_center()
	_strip.ring_r = MED_R if i >= 0 else 0.0
	_strip.queue_redraw()


func set_selected(id: String) -> void:
	selected = id
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
	_pop[id] = 1.0
	set_process(true)


func anchor(id: String) -> Control:
	return _anchors.get(id)


## Top of the strip (its hairline). Only the Play ring rises above it.
func _bar_top() -> float:
	return UITokens.NAV_RISE


func _slot_rect(i: int) -> Rect2:
	var w := size.x / TABS.size()
	var top := _bar_top()
	return Rect2(Vector2(i * w, top), Vector2(w, size.y - bottom_inset - top))


func _play_center() -> Vector2:
	var r := _slot_rect(TABS.find("play"))
	return Vector2(r.get_center().x, MED_R)


func _glyph_rect(i: int) -> Rect2:
	var r := _slot_rect(i)
	var g := UITokens.NAV_GLYPH
	return Rect2(Vector2(r.get_center().x - g * 0.5, r.position.y + GLYPH_Y), Vector2(g, g))


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return
	var target := _slot_rect(TABS.find(selected)).get_center().x
	if _sel_x < 0.0:
		_sel_x = target
	# The marker glides (ease-out, ~200 ms) and the bar only redraws while something moves.
	var k := 1.0 - exp(-delta / 0.05)
	var nx := lerpf(_sel_x, target, k)
	var changed := absf(nx - _sel_x) > 0.05
	_sel_x = nx if changed else target
	for id in _pop.keys():
		_pop[id] = maxf(0.0, float(_pop[id]) - delta * 2.0)
		changed = true
		if float(_pop[id]) <= 0.0:
			_pop.erase(id)
	if changed:
		queue_redraw()
	for i in TABS.size():
		var gr := _glyph_rect(i)
		var a: Control = _anchors[TABS[i]]
		var c := _play_center() if TABS[i] == "play" else gr.get_center()
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
					tab_pressed.emit(id)
			_press = ""
			queue_redraw()
		accept_event()


## Labels: Regular (inactive) / Medium (active), +1 px tracking.
static func _lfont(weight := "regular") -> Font:
	if not _label_fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = UIKit.font_w(weight)
		fv.spacing_glyph = 1
		_label_fonts[weight] = fv
	return _label_fonts[weight]


func _draw() -> void:
	if _sel_x < 0.0 and size.x > 0.0:
		_sel_x = _slot_rect(TABS.find(selected)).get_center().x
	var top := _bar_top()
	var pc := _play_center()
	var tex := UIKit.kit_texture("nav_bar")
	if tex:
		draw_style_box(UIKit.lux("nav_bar"), Rect2(Vector2(0, top), Vector2(size.x, size.y - top)))
	# The only line: the hairline, open where the Play ring is set into it.
	KitNav.draw_top_line(self, top, 0.0, size.x, Vector2(pc.x - MED_R - 3.0, pc.x + MED_R + 3.0))
	var sel_i := TABS.find(selected)
	var near_play := clampf(1.0 - absf(_sel_x - pc.x) / 60.0, 0.0, 1.0)
	# Light wash behind the active glyph (warm, soft; it travels with the marker).
	var wash_c := Vector2(_sel_x, top + GLYPH_Y + UITokens.NAV_GLYPH * 0.5)
	wash_c.y = lerpf(wash_c.y, pc.y, near_play)
	draw_texture_rect(UIKit.glow_texture(), Rect2(wash_c - Vector2(78, 46), Vector2(156, 92)), false, Color(1.0, 0.93, 0.76, 0.55))
	draw_texture_rect(UIKit.glow_texture(), Rect2(wash_c - Vector2(40, 26), Vector2(80, 52)), false, Color(1.0, 1.0, 1.0, 0.5))
	var label_y := size.y - bottom_inset - LABEL_BASE
	for i in TABS.size():
		var id := TABS[i]
		var r := _slot_rect(i)
		var cx := r.get_center().x
		var sel := id == selected
		var locked := is_locked(id)
		var on := clampf(1.0 - absf(_sel_x - cx) / 72.0, 0.0, 1.0) if sel else 0.0
		var flash := float(_pop.get(id, 0.0))
		var dim := 0.36 if locked else 1.0
		var gr := _glyph_rect(i)
		if _press == id:
			gr = gr.grow(-1.0)
		if id == "play":
			KitNav.draw_play_ring(self, pc, MED_R, sel, dim)
		else:
			var ov := UIKit.kit_texture("icon_" + ICONS[id])
			var col := UITokens.NAV_GOLD.lerp(UITokens.NAV_GOLD_ON, on)
			col.a = dim
			if ov:
				draw_texture_rect(ov, gr, false, Color(1, 1, 1, dim))
			else:
				KitIcons.nav(self, id, gr, col, 0.22 * on)
		if flash > 0.0:
			var fc := (pc if id == "play" else gr.get_center())
			draw_texture_rect(UIKit.glow_texture(), Rect2(fc - Vector2(44, 44), Vector2(88, 88)), false, Color(1.0, 0.9, 0.62, 0.6 * flash))
		var label := HomeText.t(LABELS[id])
		var f := _lfont("medium" if sel else "regular")
		var fs := UITokens.NAV_LABEL
		while fs > 18 and f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 10.0:
			fs -= 1
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lc := UITokens.INK_DIM.lerp(UITokens.INK, on)
		lc.a = (0.92 if not locked else 0.5)
		draw_string(f, Vector2(roundf(cx - tw * 0.5), label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		if locked:
			var lk := Rect2(gr.end - Vector2(12, 14), Vector2(16, 16))
			if id == "play":
				lk = Rect2(pc + Vector2(MED_R * 0.5, MED_R * 0.3), Vector2(16, 16))
			Icons.line(self, "lock", lk, Color(UITokens.INK.r, UITokens.INK.g, UITokens.INK.b, 0.7))
		var bpos := Vector2(gr.end.x + 6.0, gr.position.y + 2.0)
		if id == "play":
			bpos = pc + Vector2(MED_R * 0.72, -MED_R * 0.72)
		_draw_badge(id, bpos)
	# The active marker: a small cut-gem diamond riding the hairline with a short amber glint
	# (2 device px, fading out). Over the Play ring it sits on the ring's crown.
	var my := lerpf(GemDraw.pixel_y(self, top), 0.0, near_play)
	var gw := 26.0
	var glint := Color(UITokens.CTA_LO.r, UITokens.CTA_LO.g, UITokens.CTA_LO.b, 0.95 * (1.0 - near_play))
	var g0 := Color(glint.r, glint.g, glint.b, 0.0)
	if glint.a > 0.01:
		draw_polyline_colors(PackedVector2Array([Vector2(_sel_x - gw, my), Vector2(_sel_x, my), Vector2(_sel_x + gw, my)]),
				PackedColorArray([g0, glint, g0]), UIKit.px(UITokens.SELECT_PX))
	if sel_i >= 0:
		GemDraw.draw_diamond(self, Vector2(_sel_x, my), 12.0, UITokens.TOPAZ, Color("#A8662A"))


## Something waits on this tab: an 8 px amber diamond with a 1 px cream edge (no glow, no pulse).
func _draw_badge(id: String, at: Vector2) -> void:
	var b := str(_badges.get(id, ""))
	if b == "" or is_locked(id):
		return
	var tex := UIKit.kit_texture("badge_gem")
	if tex:
		draw_texture_rect(tex, Rect2(at - Vector2(7, 7), Vector2(14, 14)), false)
		return
	var h := 5.5
	var pts := PackedVector2Array([at + Vector2(0, -h - 1.0), at + Vector2(h, 0), at + Vector2(0, h + 1.0), at + Vector2(-h, 0)])
	draw_colored_polygon(pts, Color(1.0, 0.98, 0.92, 0.95))
	GemDraw.draw_diamond(self, at, 9.0, Color("#EE9B2E"), Color("#B5651F"))
