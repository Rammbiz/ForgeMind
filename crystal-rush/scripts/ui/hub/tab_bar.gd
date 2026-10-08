class_name HubTabBar
extends Control
## Hub bottom navigation (UI v2, AFK Journey style): a light translucent cream bar with an
## arched gold hairline top edge and a crystal keystone (KitNav.draw_bar), five painted icons
## with taupe labels: Магазин · Арсенал · Грати · Герої · Казарми. The active tab rises on a
## round amber medallion (KitNav.draw_medallion) that glides between the slots; its label
## turns warm amber. Locked tabs (UnlockQueue) are faded with a small lock socket and
## "Рівень N". Badges are small gold gems (an upgrade waits / a claimable): never numbers,
## never red dots. anchor(id) returns an invisible Control on a tab icon (RewardFly target).
## Bitmap overrides via the kit: nav_bar.png, nav_medallion.png, icon_tab_*.png.

signal tab_pressed(id: String)
signal locked_pressed(id: String)

const TABS: Array[String] = ["shop", "arsenal", "play", "heroes", "barracks"]
const LABELS := {"shop": "TAB_SHOP", "arsenal": "TAB_ARSENAL", "play": "NAV_PLAY", "heroes": "TAB_HEROES", "barracks": "TAB_BARRACKS"}
const ICONS := {"shop": "tab_shop", "arsenal": "tab_arsenal", "play": "tab_play", "heroes": "tab_heroes", "barracks": "tab_barracks"}
const MED_R := 46.0

var selected := "play"
var bottom_inset := 0.0
var _locked := {}          ## id -> level number it opens after (0 = open)
var _badges := {}          ## id -> "" | "arrow" | "!"
var _anchors := {}         ## id -> Control
var _sel_x := -1.0
var _rise := 1.0           ## medallion rise 0..1 (dips while it glides)
var _t := 0.0
var _press := ""
var _pop := {}             ## id -> 0..1 punch


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in TABS:
		var a := Control.new()
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.size = Vector2(56, 56)
		add_child(a)
		_anchors[id] = a


func set_selected(id: String) -> void:
	if id != selected:
		_rise = 0.0
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


## Punches a tab (it just unlocked, or a reward landed on it).
func pop(id: String) -> void:
	_pop[id] = 1.0


func anchor(id: String) -> Control:
	return _anchors.get(id)


## Top of the bar body (the arch rises 8 px above it; the medallion above that).
func _bar_top() -> float:
	return UITokens.NAV_RISE


func _slot_rect(i: int) -> Rect2:
	var w := size.x / TABS.size()
	var top := _bar_top()
	return Rect2(Vector2(i * w, top), Vector2(w, size.y - bottom_inset - top))


func _process(delta: float) -> void:
	_t += delta
	if size.x <= 0.0:
		return
	var target := _slot_rect(TABS.find(selected)).get_center().x
	if _sel_x < 0.0:
		_sel_x = target
	var k := 1.0 - exp(-delta / 0.06)
	var nx := lerpf(_sel_x, target, k)
	var changed := absf(nx - _sel_x) > 0.05
	_sel_x = nx
	if _rise < 1.0:
		_rise = minf(1.0, _rise + delta / 0.26)
		changed = true
	for id in _pop.keys():
		_pop[id] = maxf(0.0, float(_pop[id]) - delta * 2.5)
		changed = true
		if float(_pop[id]) <= 0.0:
			_pop.erase(id)
	if changed or not _badges.is_empty():
		queue_redraw()
	for i in TABS.size():
		var r := _slot_rect(i)
		var a: Control = _anchors[TABS[i]]
		a.position = Vector2(r.get_center().x - 28, r.position.y + (2.0 if TABS[i] == selected else 10.0))


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


func _draw() -> void:
	if _sel_x < 0.0 and size.x > 0.0:
		_sel_x = _slot_rect(TABS.find(selected)).get_center().x
	var top := _bar_top()
	var body := Rect2(Vector2(0, top), Vector2(size.x, size.y - top))
	KitNav.draw_bar(self, body, 8.0)
	var label_y := size.y - bottom_inset - 16.0
	# The medallion: glides to the selected slot; it dips while moving and rises back
	# (ease-out), its glow breathing softly.
	var travel := absf(_sel_x - _slot_rect(TABS.find(selected)).get_center().x)
	var lift := ease(_rise, 0.4) * (1.0 - clampf(travel / 120.0, 0.0, 0.6))
	var mc := Vector2(_sel_x, top + 18.0 + (1.0 - lift) * 14.0)
	var breathe := 0.5 + 0.5 * sin(fmod(_t, 200.0 * PI) * TAU / UITokens.GLOW_PERIOD)
	var glow := 0.55 + 0.35 * breathe if selected == "play" else 0.4 + 0.2 * breathe
	KitNav.draw_medallion(self, mc, MED_R, glow)
	var f_med := UIKit.font_w("medium")
	var f_bold := UIKit.font_w("bold")
	for i in TABS.size():
		var id := TABS[i]
		var r := _slot_rect(i)
		var cx := r.get_center().x
		var sel := id == selected
		var locked := is_locked(id)
		var pk := float(_pop.get(id, 0.0))
		var pscale := 1.0 + 0.22 * sin(pk * PI) + (-0.06 if _press == id else 0.0)
		var label := HomeText.t(LABELS[id]) if not locked else Loc.f("TAB_LOCKED", [locked_level(id)])
		var ir: Rect2
		if sel:
			var isz := 64.0 * pscale
			ir = Rect2(Vector2(cx - isz * 0.5, mc.y - isz * 0.54), Vector2(isz, isz))
			# Fade the icon in on the medallion once it has arrived.
			var a := clampf(1.0 - absf(_sel_x - cx) / 40.0, 0.0, 1.0)
			Icons.draw_icon(self, ICONS[id], ir, Color(1, 1, 1, a))
		else:
			var isz2 := 54.0 * pscale
			ir = Rect2(Vector2(cx - isz2 * 0.5, r.position.y + 8.0), Vector2(isz2, isz2))
			var near := clampf(absf(_sel_x - cx) / 50.0, 0.0, 1.0)
			Icons.draw_icon(self, ICONS[id], ir, Color(1, 1, 1, (0.42 if locked else 1.0) * near))
		var fs := UIKit.fit_size(label, r.size.x - 8.0, 18 if sel else 17, 13)
		var f := f_bold if sel else f_med
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := UITokens.CTA_LO.darkened(0.18) if sel else (UITokens.INK_DIM if not locked else Color(UITokens.INK_DIM.r, UITokens.INK_DIM.g, UITokens.INK_DIM.b, 0.7))
		draw_string(f, Vector2(cx - tw * 0.5, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if locked:
			var lc := Vector2(cx + 16.0, r.position.y + 46.0)
			draw_circle(lc + Vector2(0, 1), 12.0, Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.15))
			draw_circle(lc, 11.0, UITokens.PAPER_0)
			draw_arc(lc, 10.5, 0, TAU, 24, UITokens.HAIRLINE, 1.2, true)
			Icons.line(self, "lock", Rect2(lc - Vector2(7, 7), Vector2(14, 14)), UITokens.INK_DIM)
		_draw_badge(id, Vector2(ir.end.x - 8.0, ir.position.y + 8.0))


## A small gold gem (topaz cushion) with a soft glow: something waits on this tab.
func _draw_badge(id: String, at: Vector2) -> void:
	var b := str(_badges.get(id, ""))
	if b == "" or is_locked(id):
		return
	var breathe := 0.5 + 0.5 * sin(fmod(_t, 200.0 * PI) * TAU / UITokens.GLOW_PERIOD)
	var tex := UIKit.kit_texture("badge_gem")
	draw_texture_rect(UIKit.glow_texture(), Rect2(at - Vector2(16, 16), Vector2(32, 32)), false, Color(1.0, 0.8, 0.4, 0.35 + 0.25 * breathe))
	if tex:
		draw_texture_rect(tex, Rect2(at - Vector2(10, 10), Vector2(20, 20)), false)
		return
	GemDraw.draw_gem(self, "diamond", at, 18.0, UITokens.TOPAZ, Color("#FFF0C2"), Color("#C2620E"), false)
