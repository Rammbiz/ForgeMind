class_name Hub
extends Node3D
## The home screen of the meta (arsenal_design.md §7; replaces Menu): the 3D world behind the
## Play tab, a top bar with currency chips, five tabs (Магазин · Арсенал · ГРА · Герої ·
## Казарми) and a modal layer for sheets (machine detail, vault, odds, settings, unlock cards).
## Reads only Meta (and ArsenalData / EconData constants); refreshes on Meta signals.
##
##   var hub := Hub.new("arsenal")      # start tab (default "play")
##   hub.play.connect(start_run)
##   hub.open_altar.connect(func(i): ...)   # WS5: World Cache on the Altar (else a built-in reveal)
##
## Android back closes the top sheet, then returns to ГРА, then quits.

signal play
## A Vault Cache should be opened on the Altar (index into Meta.vault()). When nothing is
## connected the hub opens it itself with VaultView's inline reveal.
signal open_altar(index: int)

const TABS: Array[String] = ["shop", "arsenal", "play", "heroes", "barracks"]
const PAGE_SCRIPTS := {
	"shop": preload("res://scripts/ui/hub/tab_shop.gd"),
	"arsenal": preload("res://scripts/ui/hub/tab_arsenal.gd"),
	"play": preload("res://scripts/ui/hub/tab_play.gd"),
	"heroes": preload("res://scripts/ui/hub/tab_heroes.gd"),
	"barracks": preload("res://scripts/ui/hub/tab_barracks.gd"),
}
## Tab id -> UnlockQueue id (shop is a placeholder and always open in Meta-1).
const TAB_UNLOCK := {"arsenal": "arsenal", "heroes": "heroes", "barracks": "barracks"}

var start_tab := "play"
var current := ""
var stage: HubStage
var ui: Control
var top_bar: HubTopBar
var tab_bar: HubTabBar
var backdrop: Backdrop
var pages := {}                 ## tab id -> page Control (built on first visit)
var _page_host: Control
var _modal_host: Control
var _modals: Array[Control] = []
var _toast: Control
var _insets := Vector4.ZERO
var _unlock_shown := false


func _init(p_start_tab := "play") -> void:
	start_tab = p_start_tab if p_start_tab in TABS else "play"


func _ready() -> void:
	stage = HubStage.new()
	add_child(stage)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	ui = Control.new()
	ui.theme = UIKit.theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_build()
	Meta.wallet_changed.connect(func(_c: String, _v: int): _on_wallet())
	Meta.machine_changed.connect(func(_id: String): _on_arsenal())
	Meta.deck_changed.connect(_on_arsenal)
	Meta.focus_changed.connect(func(_id: String): _on_arsenal())
	Meta.hero_changed.connect(func(_id: String): _on_hero())
	Meta.barracks_changed.connect(func(_t: String): _refresh_pages(["barracks", "play"]))
	Meta.cache_added.connect(func(_t: String): _refresh_pages(["play", "shop"]))
	Meta.unlocked.connect(func(_k: String, _id: String): _refresh_locks())
	Loc.language_changed.connect(_rebuild)
	Audio.play_music("menu")
	select_tab(start_tab, false)
	_refresh_locks()
	_refresh_badges()
	get_tree().create_timer(0.6).timeout.connect(_show_pending_unlocks)


func _build() -> void:
	_insets = UIKit.safe_insets(get_viewport())
	backdrop = Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(backdrop)
	_page_host = Control.new()
	_page_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_host.offset_top = _insets.y + UITokens.TOP_BAR_H + 8.0
	_page_host.offset_bottom = -(UITokens.TAB_BAR_H + _insets.w) - 34.0
	_page_host.offset_left = _insets.x
	_page_host.offset_right = -_insets.z
	_page_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_page_host)
	top_bar = HubTopBar.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = _insets.x
	top_bar.offset_right = -_insets.z
	top_bar.offset_top = _insets.y
	top_bar.offset_bottom = _insets.y + UITokens.TOP_BAR_H
	top_bar.settings_pressed.connect(open_settings)
	top_bar.shop_pressed.connect(func(): select_tab("shop"))
	top_bar.avatar_pressed.connect(func(): select_tab("heroes") if not tab_bar.is_locked("heroes") else null)
	ui.add_child(top_bar)
	tab_bar = HubTabBar.new()
	tab_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tab_bar.offset_top = -(UITokens.TAB_BAR_H + _insets.w)
	tab_bar.bottom_inset = _insets.w
	tab_bar.tab_pressed.connect(func(id: String): select_tab(id))
	tab_bar.locked_pressed.connect(func(id: String):
		Audio.play("error", -6.0)
		toast(Loc.f("TAB_LOCKED", [tab_bar.locked_level(id)]), "lock"))
	ui.add_child(tab_bar)
	_modal_host = Control.new()
	_modal_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_modal_host)


func _rebuild() -> void:
	for m in _modals:
		m.queue_free()
	_modals.clear()
	for c in ui.get_children():
		c.queue_free()
	pages.clear()
	var keep := current
	current = ""
	_build()
	select_tab(keep, false)
	_refresh_locks()
	_refresh_badges()


# ------------------------------------------------------------------ tabs

## Shows tab `id` (slides the pages; ignores a locked tab).
func select_tab(id: String, animate := true) -> void:
	if id == current or not id in TABS:
		return
	if tab_bar.is_locked(id):
		return
	var old: Control = pages.get(current)
	var dir := signf(TABS.find(id) - TABS.find(current)) if current != "" else 0.0
	var page := _page(id)
	var prev := current
	current = id
	tab_bar.set_selected(id)
	top_bar.set_tab(id)
	backdrop.set_tab(id, animate)
	stage.active = id == "play"
	_set_3d(id == "play", animate)
	if animate:
		UIJuice.haptic("TICK", 0.4)
		Audio.play("click", -10.0)
	# Soft tab change (Genshin): the old page fades out drifting 24 px, the new one fades in
	# drifting from the other side; no overshoot.
	if old and old != page:
		if old.has_method("on_hide"):
			old.call("on_hide")
		if animate and not UITokens.reduce_motion():
			var tw := UIJuice.soft_out(old, Vector2(-24.0 * dir, 0))
			tw.finished.connect(func():
				if current != prev:
					old.visible = false
					old.position = Vector2.ZERO
					old.modulate.a = 1.0)
		else:
			old.visible = false
	page.visible = true
	page.position = Vector2.ZERO
	if page.has_method("on_show"):
		page.call("on_show")
	if animate and not UITokens.reduce_motion():
		UIJuice.soft_in(page, Vector2(32.0 * dir, 0), UITokens.TAB_FADE * 0.4)
	else:
		page.modulate.a = 1.0


## The road behind the Play tab is the only 3D of the root viewport: other tabs cover it with an
## opaque backdrop, so 3D rendering is switched off there (after the backdrop has faded in).
func _set_3d(on: bool, animate: bool) -> void:
	var vp := get_viewport()
	if on:
		vp.disable_3d = false
		return
	if not animate:
		vp.disable_3d = true
		return
	get_tree().create_timer(UITokens.STD + 0.05).timeout.connect(func():
		if is_instance_valid(self) and current != "play":
			vp.disable_3d = true)


func _exit_tree() -> void:
	get_viewport().disable_3d = false


func _page(id: String) -> Control:
	if pages.has(id):
		return pages[id]
	var p: Control = (PAGE_SCRIPTS[id] as GDScript).new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.visible = false
	if p.has_method("setup"):
		p.call("setup", self)
	_page_host.add_child(p)
	pages[id] = p
	return p


func _refresh_pages(ids: Array) -> void:
	for id in ids:
		var p: Control = pages.get(id)
		if p and p.has_method("refresh"):
			p.call("refresh")
	_refresh_badges()


func _on_wallet() -> void:
	top_bar.refresh(true)
	_refresh_pages(["arsenal", "heroes", "barracks", "play"])


func _on_arsenal() -> void:
	stage.refresh()
	_refresh_pages(["arsenal", "play"])


func _on_hero() -> void:
	stage.refresh()
	top_bar.hero_changed()
	_refresh_pages(["heroes", "play"])


func _refresh_locks() -> void:
	for tab: String in TAB_UNLOCK:
		var uid: String = TAB_UNLOCK[tab]
		if Meta.is_unlocked(uid):
			tab_bar.set_locked(tab, 0)
		else:
			var e := EconData.unlock_entry(uid)
			tab_bar.set_locked(tab, int(e.get("after_win", 0)) + 1)


## Green arrow / gold "!" per tab (§7.4: only the Best upgrade and Deck machines, claimables).
func _refresh_badges() -> void:
	var best := Meta.best_upgrade()
	var kind := str(best.get("kind", ""))
	var arsenal := ""
	for c in Meta.machine_cards("owned"):
		var b := str((c as Dictionary).get("badge", ""))
		if b == "arrow":
			arsenal = "arrow"
			break
		if b == "!" and arsenal == "":
			arsenal = "!"
	tab_bar.set_badge("arsenal", arsenal)
	tab_bar.set_badge("heroes", "arrow" if kind == "hero" else "")
	tab_bar.set_badge("barracks", "arrow" if kind == "barracks" else "")


# ------------------------------------------------------------------ modals

## Puts `c` on the modal layer above a dimmer; tapping the dimmer closes it (unless `sticky`).
func push_modal(c: Control, sticky := false) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_host.add_child(holder)
	var dim := ColorRect.new()
	dim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.38, UITokens.MENU_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not sticky:
		dim.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				pop_modal())
	holder.add_child(c)
	holder.set_meta("content", c)
	_modals.append(holder)


## Closes the top modal (exit animation is the content's own: it may implement `play_exit()`
## returning a Tween).
func pop_modal() -> void:
	if _modals.is_empty():
		return
	var top: Control = _modals.back()
	var top_c: Control = top.get_meta("content")
	# Closing an unlock card (Android back) still counts as seen: ack it through its own path.
	if top_c is UnlockCard and not bool(top_c.get_meta("acked", false)):
		top_c.set_meta("acked", true)
		(top_c as UnlockCard).done.emit()
		return
	var holder: Control = _modals.pop_back()
	var c: Control = holder.get_meta("content")
	var tw: Tween = null
	if c.has_method("play_exit"):
		tw = c.call("play_exit")
	var dim := holder.get_child(0) as ColorRect
	dim.create_tween().tween_property(dim, "color:a", 0.0, UITokens.MENU_OUT)
	if tw:
		tw.finished.connect(holder.queue_free)
	else:
		holder.queue_free()
	Audio.play("click", -12.0)


func has_modal() -> bool:
	return not _modals.is_empty()


## The pages' content area in UI coordinates (between the bars).
func content_rect() -> Rect2:
	return _page_host.get_global_rect()


## Safe-area insets (left, top, right, bottom) in canvas px.
func insets() -> Vector4:
	return _insets


func open_settings() -> void:
	var p := SettingsPanel.new()
	p.setup(self)
	push_modal(p)


func open_machine(id: String) -> void:
	var d := MachineDetail.new()
	d.setup(self, id)
	push_modal(d, true)


func open_vault() -> void:
	var v := VaultView.new()
	v.setup(self)
	push_modal(v)


func open_odds(type := "stone") -> void:
	var o := OddsView.new()
	o.setup(self, type)
	push_modal(o)


## Opens the Vault Cache `index`: on the Altar when someone listens to open_altar, else the
## built-in reveal (rolled, granted and saved by Meta before anything animates).
func open_cache(index: int) -> void:
	if open_altar.get_connections().size() > 0:
		open_altar.emit(index)
		return
	var rev := Meta.open_cache(index)
	if rev.is_empty():
		return
	var r := VaultView.Reveal.new()
	r.setup(self, rev)
	push_modal(r, true)


## Shows the Deck editor (Arsenal tab, Колода).
func open_deck() -> void:
	if tab_bar.is_locked("arsenal"):
		return
	select_tab("arsenal")
	var a: Control = pages.get("arsenal")
	if a and a.has_method("show_sub"):
		a.call("show_sub", "deck")


# ------------------------------------------------------------------ rewards and toasts

## Flies `amount` of `cur` from `from` (canvas px) to its chip (coins, gems, crowns, wild_*) or
## to a tab ("bp" -> the Arsenal tab). Returns the RewardFly job signal.
func fly_reward(cur: String, amount: int, from: Vector2) -> Signal:
	var target := reward_target(cur)
	if target == null:
		target = top_bar
	top_bar.expect_fly(cur)
	return RewardFly.layer(get_tree()).fly(from, cur, amount, target)


## The control a currency or reward flies to (WS5 result flow uses it too).
func reward_target(cur: String) -> Control:
	if cur == "bp" or cur == "blueprints":
		return tab_bar.anchor("arsenal")
	var c := top_bar.chip(cur)
	if c and c.is_visible_in_tree():
		return c
	return top_bar.chip("coins")


## A short message chip above the bottom nav (UI v2: cream-glass chip, ink text, a line icon;
## soft in, hold, soft out). `color` is kept for old callers and ignored (text is always ink).
func toast(text: String, icon := "", _color := UIKit.GOLD_LIGHT) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	var vs := ui.size if ui.size.y > 0.0 else Vector2(720, 1280)
	var y := vs.y - UITokens.TAB_BAR_H - _insets.w - 96.0
	_toast = UIKit.toast(ui, text, icon, 1.8, y)


# ------------------------------------------------------------------ unlock queue (§4.6)

func _show_pending_unlocks() -> void:
	if not is_inside_tree() or _unlock_shown:
		return
	var list := Meta.pending_unlocks()
	if list.is_empty():
		return
	_unlock_shown = true
	var u: Dictionary = list[0]
	var card := UnlockCard.new(u)
	card.done.connect(func():
		card.set_meta("acked", true)
		Meta.ack_unlock(str(u.get("id", "")))
		pop_modal()
		_refresh_locks()
		var tab := _tab_of(str(u.get("id", "")))
		if tab != "":
			tab_bar.pop(tab)
			select_tab(tab)
		_unlock_shown = false
		get_tree().create_timer(0.5).timeout.connect(_show_pending_unlocks))
	push_modal(card, true)


func _tab_of(unlock_id: String) -> String:
	for tab: String in TAB_UNLOCK:
		if TAB_UNLOCK[tab] == unlock_id:
			return tab
	match unlock_id:
		"deck", "talents", "stone_cache": return "arsenal"
		"titan": return "heroes"
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if has_modal():
			pop_modal()
		elif current != "play":
			select_tab("play")
		else:
			get_tree().quit()


# ------------------------------------------------------------------ inner widgets

## Full-screen painted backdrop per tab (UI v2: light and warm everywhere). Play = clear (the
## 3D Home) with a whisper of slate under the top plates, a warm floor fade under the nav and
## soft light shafts from the sun side; Arsenal = a pale ivory gallery with a cool-white
## spotlight; Heroes / Barracks / Shop = a warm parchment haze with a golden spotlight.
class Backdrop extends Control:
	var _from := {}
	var _to := {}
	var _k := 1.0
	var _t := 0.0
	var _shafts: Shafts

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_to = _look("play")
		_from = _to
		_shafts = Shafts.new()
		_shafts.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_shafts)

	static func _look(tab: String) -> Dictionary:
		var sc := UITokens.SCRIM
		match tab:
			"play":
				return {"top": Color(sc.r, sc.g, sc.b, 0.16), "mid": Color(sc.r, sc.g, sc.b, 0.0), "bot": Color(0.55, 0.42, 0.3, 0.16),
						"spot": Color(1, 1, 1, 0.0), "spot_y": 0.3, "vig": 0.0, "shafts": 1.0}
			"arsenal":
				return {"top": Color("#F1ECE2"), "mid": Color("#E4DDD0"), "bot": Color("#CFC5B4"), "spot": Color(1.0, 0.99, 0.96, 0.75),
						"spot_y": 0.22, "vig": 0.16, "shafts": 0.0}
			_:
				return {"top": Color("#F4ECDD"), "mid": UITokens.STAGE_TOP, "bot": UITokens.STAGE_BOTTOM, "spot": Color(1.0, 0.93, 0.78, 0.7),
						"spot_y": 0.2, "vig": 0.18, "shafts": 0.0}

	func set_tab(tab: String, animate := true) -> void:
		_from = _cur()
		_to = _look(tab)
		_k = 0.0 if animate else 1.0
		queue_redraw()

	func _cur() -> Dictionary:
		var out := {}
		for key in _to:
			var a: Variant = _from.get(key, _to[key])
			var b: Variant = _to[key]
			out[key] = (a as Color).lerp(b, _k) if b is Color else lerpf(float(a), float(b), _k)
		return out

	func _process(delta: float) -> void:
		_t += delta
		if _k < 1.0:
			_k = minf(1.0, _k + delta / UITokens.STD)
			queue_redraw()
		_shafts.strength = float(_cur()["shafts"])
		_shafts.visible = _shafts.strength > 0.01

	func _draw() -> void:
		var L := _cur()
		var h := size.y
		var w := size.x
		var top: Color = L["top"]
		var mid: Color = L["mid"]
		var bot: Color = L["bot"]
		var play_like := float(L["shafts"]) > 0.5
		# Play: the slate whisper only covers the top band and the warm fade the bottom band.
		var y1 := h * (0.2 if play_like else 0.45)
		var y2 := h * (0.72 if play_like else 0.45)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([top, top, mid, mid]))
		draw_rect(Rect2(Vector2(0, y1), Vector2(w, y2 - y1)), mid)
		draw_polygon(PackedVector2Array([Vector2(0, y2), Vector2(w, y2), Vector2(w, h), Vector2(0, h)]), PackedColorArray([mid, mid, bot, bot]))
		var spot: Color = L["spot"]
		if spot.a > 0.01:
			var cy: float = h * float(L["spot_y"])
			var r := w * 0.95
			draw_texture_rect(UIKit.glow_texture(), Rect2(Vector2(w * 0.5 - r, cy - r * 0.8), Vector2(r * 2.0, r * 1.6)), false, spot)
			# Faint light rays fanning down from the top.
			for i in 7:
				var x := w * (0.5 + (i - 3) * 0.13)
				var bw := w * 0.05
				var a := spot.a * 0.22 * (1.0 - absf(i - 3) / 4.0)
				draw_polygon(PackedVector2Array([Vector2(w * 0.5 - 6, -10), Vector2(w * 0.5 + 6, -10), Vector2(x + bw, cy * 2.4), Vector2(x - bw, cy * 2.4)]),
						PackedColorArray([Color(1, 1, 1, a), Color(1, 1, 1, a), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
		var vk := float(L["vig"])
		if vk > 0.01:
			var vg := Color(0.45, 0.36, 0.28, vk)
			var clear := Color(0.45, 0.36, 0.28, 0.0)
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(70, 0), Vector2(70, h), Vector2(0, h)]), PackedColorArray([vg, clear, clear, vg]))
			draw_polygon(PackedVector2Array([Vector2(w - 70, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - 70, h)]), PackedColorArray([clear, vg, vg, clear]))


## Soft additive light shafts from the sun (upper right) over the Home stage; they drift a
## little and breathe so the morning light feels alive.
class Shafts extends Control:
	var strength := 1.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m

	func _process(delta: float) -> void:
		_t += delta
		if visible:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var src := Vector2(w * 0.92, -h * 0.08)
		var beams := [[0.18, 0.16, 0.05], [0.34, 0.1, 0.035], [0.5, 0.2, 0.045], [0.68, 0.12, 0.03], [0.84, 0.15, 0.04]]
		for i in beams.size():
			var b: Array = beams[i]
			var sway := sin(_t * 0.25 + i * 1.3) * 0.015
			var tx := w * (float(b[0]) + sway) - w * 0.25
			var end := Vector2(tx, h * 0.78)
			var half := w * float(b[1]) * 0.5
			var a := float(b[2]) * strength * (0.8 + 0.2 * sin(_t * 0.6 + i))
			var c0 := Color(1.0, 0.93, 0.78, a)
			var c1 := Color(1.0, 0.93, 0.78, 0.0)
			draw_polygon(PackedVector2Array([src + Vector2(-8, 0), src + Vector2(8, 0), end + Vector2(half, 0), end - Vector2(half, 0)]),
					PackedColorArray([c0, c0, c1, c1]))
		# Sun bloom in the corner.
		var r := w * 0.55
		draw_texture_rect(UIKit.glow_texture(), Rect2(src - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.9, 0.7, 0.22 * strength))


## A newly opened system (UnlockQueue line): icon in a halo, "Відкрито!", the line, "Далі".
class UnlockCard extends PanelContainer:
	signal done
	var entry := {}

	func _init(u: Dictionary) -> void:
		entry = u

	func _ready() -> void:
		add_theme_stylebox_override("panel", UIKit.lux("panel", Vector2(40, 34)))
		set_anchors_preset(Control.PRESET_CENTER)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(v)
		var halo := Control.new()
		halo.custom_minimum_size = Vector2(440, 170)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rays := UIKit.Rays.new()
		rays.set_anchors_preset(Control.PRESET_FULL_RECT)
		rays.offset_top = -60
		rays.offset_bottom = 60
		rays.color = Color(1.0, 0.82, 0.4, 0.4)
		halo.add_child(rays)
		var ic := Icons.make(_icon(), 128.0)
		ic.position = Vector2(220 - 64, 21)
		halo.add_child(ic)
		v.add_child(halo)
		var t := UIKit.gradient_heading(Loc.t("UNLOCK_TITLE"), 52)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var line := UIKit.heading(Loc.t(str(entry.get("line", ""))), 30, UIKit.TEXT, 6)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(440, 0)
		v.add_child(line)
		var b := UIKit.button(Loc.t("NEXT"), true, 380.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): done.emit())
		v.add_child(b)
		UIKit.add_shine(b, 30.0, 0.8, 2.5, 0.5)
		await get_tree().process_frame
		position = (get_parent_area_size() - size) * 0.5
		UIJuice.pop(self, 0.0, UITokens.SLOW)
		UIJuice.haptic("THUD", 0.8)
		Audio.play("weapon_get", -4.0)

	func _icon() -> String:
		match str(entry.get("id", "")):
			"arsenal": return "tab_arsenal"
			"heroes", "titan": return "tab_heroes"
			"barracks": return "tab_barracks"
			"deck": return "deck"
			"stone_cache": return "cache_stone"
			"altar": return "cache_world"
			"talents": return "laurel"
			"pairs": return "crate"
			"rank_gates": return "chevron"
			"drag": return "hand"
			"migration": return "crown"
		return "crystal"
