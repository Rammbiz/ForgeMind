class_name HubTabBar
extends Control
## Hub tab bar (arsenal_design.md §7.1, 88-100 %): five labelled tabs Магазин · Арсенал ·
## ГРА · Герої · Казарми. ГРА is the raised gold medallion in the middle; the selected tab gets
## a lit tile that glides between slots. Locked tabs (UnlockQueue) are greyed with a lock and
## "Рівень N". Badges follow the notification discipline (§7.4): a green arrow (best upgrade /
## affordable Deck machine) or a gold "!" (a claimable: talent pick) - never numbers.
## anchor(id) returns an invisible Control on a tab icon (RewardFly target).

signal tab_pressed(id: String)
signal locked_pressed(id: String)

const TABS: Array[String] = ["shop", "arsenal", "play", "heroes", "barracks"]
const LABELS := {"shop": "TAB_SHOP", "arsenal": "TAB_ARSENAL", "play": "TAB_PLAY", "heroes": "TAB_HEROES", "barracks": "TAB_BARRACKS"}
const ICONS := {"shop": "tab_shop", "arsenal": "tab_arsenal", "play": "tab_play", "heroes": "tab_heroes", "barracks": "tab_barracks"}

var selected := "play"
var bottom_inset := 0.0
var _locked := {}          ## id -> level number it opens after (0 = open)
var _badges := {}          ## id -> "" | "arrow" | "!"
var _anchors := {}         ## id -> Control
var _sel_x := -1.0
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


func _slot_rect(i: int) -> Rect2:
	var w := size.x / TABS.size()
	return Rect2(Vector2(i * w, 0), Vector2(w, size.y - bottom_inset))


func _process(delta: float) -> void:
	_t += delta
	var target := _slot_rect(TABS.find(selected)).get_center().x
	if _sel_x < 0.0:
		_sel_x = target
	var nx := lerpf(_sel_x, target, minf(1.0, delta * 14.0))
	var changed := absf(nx - _sel_x) > 0.05
	_sel_x = nx
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
		a.position = Vector2(r.get_center().x - 28, 30 if TABS[i] != "play" else 4)


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
	var f := UIKit.font(true)
	var bar := Rect2(Vector2(-30, 26), Vector2(size.x + 60, size.y + 40))
	draw_style_box(UIKit.lux("tabbar"), bar)
	# Gold hairline glow along the top edge.
	draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(size.x * 0.1, 8), Vector2(size.x * 0.8, 40)), false, Color(1.0, 0.8, 0.4, 0.12))
	# Selected tile (not under ГРА, which has its own medallion).
	if selected != "play":
		var w := size.x / TABS.size()
		var tile := Rect2(Vector2(_sel_x - w * 0.5 + 6, 14), Vector2(w - 12, size.y - bottom_inset - 20))
		draw_style_box(UIKit.lux("tab_sel"), tile)
	for i in TABS.size():
		var id := TABS[i]
		var r := _slot_rect(i)
		var cx := r.get_center().x
		var sel := id == selected
		var locked := is_locked(id)
		var pk := float(_pop.get(id, 0.0))
		var pscale := 1.0 + 0.25 * sin(pk * PI) + (-0.06 if _press == id else 0.0)
		if id == "play":
			_draw_play(cx, sel, pscale)
			continue
		var isz := (62.0 if sel else 50.0) * pscale
		var iy := (30.0 if sel else 38.0)
		var ir := Rect2(Vector2(cx - isz * 0.5, iy + (52.0 - isz) * 0.5), Vector2(isz, isz))
		var tint := Color.WHITE if not locked else Color(0.45, 0.47, 0.55, 0.85)
		if not sel and not locked:
			tint = Color(0.82, 0.85, 0.95)
		Icons.draw_icon(self, ICONS[id], Rect2(ir.position + Vector2(0, 3), ir.size), Color(0, 0, 0.05, 0.4 * tint.a))
		Icons.draw_icon(self, ICONS[id], ir, tint)
		var label := Loc.t(LABELS[id]) if not locked else Loc.f("TAB_LOCKED", [locked_level(id)])
		var fs := UIKit.fit_size(label, r.size.x - 10, 22 if sel else 19, 14)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ly := r.size.y - 14.0
		var col := UIKit.GOLD_LIGHT if sel else (UIKit.TEXT_DIM if not locked else Color(0.55, 0.57, 0.65))
		draw_string_outline(f, Vector2(cx - tw * 0.5, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.01, 0.02, 0.06, 0.9))
		draw_string(f, Vector2(cx - tw * 0.5, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if locked:
			var lr := Rect2(Vector2(cx + 8, iy + 26), Vector2(28, 28))
			draw_circle(lr.get_center(), 15, Color(0.05, 0.06, 0.12))
			draw_circle(lr.get_center(), 13, Color(0.32, 0.34, 0.42))
			Icons.draw_icon(self, "lock", lr.grow(-5), Color(0.9, 0.92, 1.0))
		_draw_badge(id, Vector2(cx + isz * 0.42, iy + 4))


func _draw_play(cx: float, sel: bool, pscale: float) -> void:
	var f := UIKit.font(true)
	var c := Vector2(cx, 46)
	var r := 54.0 * pscale * (1.0 + (0.03 * sin(fmod(_t, 100.0) * 3.0) if sel else 0.0))
	if sel:
		draw_texture_rect(UIKit.glow_texture(), Rect2(c - Vector2(r, r) * 1.9, Vector2(r, r) * 3.8), false, Color(1.0, 0.7, 0.25, 0.55))
	draw_circle(c + Vector2(0, 6), r + 3.0, Color(0, 0, 0.03, 0.5))
	draw_circle(c, r + 2.0, Color(0.42, 0.2, 0.03))
	draw_circle(c + Vector2(0, -1.5), r, Color(1.0, 0.95, 0.72))
	draw_circle(c + Vector2(0, 2.0), r - 4.0, Color(0.85, 0.42, 0.06))
	draw_circle(c, r - 7.0, Color(1.0, 0.62, 0.16) if sel else Color(0.8, 0.5, 0.18))
	draw_circle(c + Vector2(0, -r * 0.18), r * 0.72, Color(1.0, 0.76, 0.3) if sel else Color(0.88, 0.62, 0.3))
	# Gloss
	draw_arc(c, r - 10.0, PI * 1.12, PI * 1.88, 24, Color(1, 1, 0.9, 0.55), 4.0, true)
	# Deep inner well so the swords read on the gold.
	draw_circle(c + Vector2(0, 2), r * 0.66, Color(0.42, 0.14, 0.02))
	draw_circle(c, r * 0.62, Color(0.16, 0.08, 0.2) if sel else Color(0.12, 0.08, 0.14))
	draw_circle(c + Vector2(0, -r * 0.12), r * 0.46, Color(0.3, 0.16, 0.36) if sel else Color(0.2, 0.14, 0.24))
	var isz := r * 0.98
	Icons.draw_icon(self, "swords", Rect2(c - Vector2(isz, isz) * 0.5 + Vector2(0, 3), Vector2(isz, isz)), Color(0, 0, 0.05, 0.6))
	Icons.draw_icon(self, "swords", Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)))
	draw_arc(c, r * 0.62, PI * 1.15, PI * 1.85, 20, Color(1, 1, 1, 0.25), 2.0, true)
	var label := Loc.t("TAB_PLAY")
	var fs := 26
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ly := size.y - bottom_inset - 14.0
	draw_string_outline(f, Vector2(cx - tw * 0.5, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.3, 0.12, 0.0))
	draw_string(f, Vector2(cx - tw * 0.5, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.6) if sel else UIKit.TEXT)


func _draw_badge(id: String, at: Vector2) -> void:
	var b := str(_badges.get(id, ""))
	if b == "" or is_locked(id):
		return
	var bob := sin(fmod(_t, 100.0) * 4.0) * 2.5
	var c := at + Vector2(0, bob)
	if b == "arrow":
		draw_circle(c + Vector2(0, 2), 15, Color(0, 0, 0, 0.4))
		draw_circle(c, 15, Color(0.05, 0.3, 0.08))
		draw_circle(c, 13, Color(0.32, 0.85, 0.32))
		Icons.draw_icon(self, "arrow_up", Rect2(c - Vector2(10, 11), Vector2(20, 20)), Color(1, 1, 1))
	else:
		draw_circle(c + Vector2(0, 2), 15, Color(0, 0, 0, 0.4))
		draw_circle(c, 15, Color(0.5, 0.25, 0.02))
		draw_circle(c, 13, Color(1.0, 0.78, 0.22))
		var f := UIKit.font(true)
		draw_string(f, c + Vector2(-4, 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.3, 0.12, 0.0))
