class_name Hub
extends Node3D
## The home screen of the meta (arsenal_design.md §7; replaces Menu). UI v3.1 "porcelain glass"
## (ui_v3_spec.md): the bright 3D Home stage behind the Play tab (HubStage), the frosted Home still
## behind the other tabs (KitGlass; re-shot on arriving at / leaving Play, on a world, hero or
## Deck change and on app resume), the top bar, the frosted bottom nav (Магазин · Арсенал ·
## Грати · Герої · Казарми), soft tab cross-fades, and a modal layer for sheets (machine detail,
## vault, odds, settings, unlock cards) over a 0.42 slate scrim (ceremonies 0.56) with the frost
## leaning toward the page colour (§4.6).
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
var _last_pop_ms := -10000
var _back_ms := -10000
var _still_key := ""             ## world | hero | Deck the frost still was shot with (§4.1 refresh)


func _init(p_start_tab := "play") -> void:
	start_tab = p_start_tab if p_start_tab in TABS else "play"


func _ready() -> void:
	stage = HubStage.new()
	add_child(stage)
	# UI v3 glass: a blurred 1/10-res still of the Home world for the frosted surfaces (KitGlass).
	KitGlass.attach_world(self, stage.camera(), stage, stage.world)
	KitGlass.set_page_tint(Color.WHITE)
	_still_key = _world_key()
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
	# §4.1: no flat-to-frost pop. The cream tabs draw flat until the still exists, then the world
	# cross-fades in (KitGlass.world_alpha) while KitGlass reports changes.
	KitGlass.on_change(backdrop, backdrop.queue_redraw)
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
	top_bar.avatar_pressed.connect(open_profile)
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
	# v3 glass (§4.1): re-shoot the world still on arriving at Play (hero and Deck in place) and
	# on leaving it, while the Home 3D is still on (before _set_3d turns it off); the other tabs
	# keep that still.
	if id == "play" or prev == "play":
		_refresh_still()
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
	KitGlass.set_page_tint(Color.WHITE)


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
	_refresh_still_if_changed()


func _on_hero() -> void:
	stage.refresh()
	top_bar.hero_changed()
	_refresh_pages(["heroes", "play"])
	_refresh_still_if_changed()


## What the frost still shows: the world (sky / biome), the hero's accent and the Deck.
func _world_key() -> String:
	return "%d|%s|%s" % [ArsenalData.world_of(Meta.level()), Meta.hero(), ",".join(Meta.deck())]


func _refresh_still() -> void:
	_still_key = _world_key()
	KitGlass.refresh_world()


## §4.1 refresh triggers inside the hub: a world change (Світ N -> N+1), a hero swap or a Deck
## swap re-shoots the still (KitGlass queues a refresh that arrives mid-render).
func _refresh_still_if_changed() -> void:
	if _world_key() != _still_key:
		_refresh_still()


func _refresh_locks() -> void:
	for tab: String in TAB_UNLOCK:
		var uid: String = TAB_UNLOCK[tab]
		if Meta.is_unlocked(uid):
			tab_bar.set_locked(tab, 0)
		else:
			var e := EconData.unlock_entry(uid)
			tab_bar.set_locked(tab, int(e.get("after_win", 0)) + 1)


## Tab badges (§7.4: only the Best upgrade and Deck machines, claimables); the nav draws
## both kinds as a small gold gem.
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
## `centered` wraps `c` in a full-screen CenterContainer (cards that size themselves), and
## `ceremony` (reveals) uses a deeper scrim and also fades the nav out. While any modal is up the
## Home chrome (PLAY, level path, rails, tags) fades out so only the modal's jewel shows.
func push_modal(c: Control, sticky := false, centered := false, ceremony := false) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_host.add_child(holder)
	var dim := ColorRect.new()
	dim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", UITokens.SCRIM_CEREMONY if ceremony else UITokens.SCRIM_MODAL, UITokens.MENU_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not sticky:
		dim.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				pop_modal(holder))
	if centered:
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cc)
		cc.add_child(c)
	else:
		holder.add_child(c)
	holder.set_meta("content", c)
	holder.set_meta("ceremony", ceremony)
	_modals.append(holder)
	_page_tint()
	_chrome_for_modals()


## §4.6 frost coherence: while a modal is up over a cream tab, the frost leans toward that page's
## dominant colour (mixed 75 % toward white); on Play, and with no modal, it stays white. A
## modal that has its own stage (MachineDetail.page_tint) names its colour itself.
func _page_tint() -> void:
	var col := Color.WHITE
	var top: Control = _modals.back().get_meta("content") if not _modals.is_empty() else null
	if top and top.has_method("page_tint"):
		# A full-screen modal with its own stage (MachineDetail) names its own colour.
		col = top.call("page_tint")
	elif top and current != "play":
		var p: Control = pages.get(current)
		if p and p.has_method("page_tint"):
			col = p.call("page_tint")
		else:
			col = UITokens.PAPER_1
	KitGlass.set_page_tint(col)


## Fades the page chrome under the modal stack: the Home page (and the nav for ceremonies)
## goes to 0 so two amber jewels never show at once; other pages stay (the scrim covers them).
func _chrome_for_modals() -> void:
	var any := not _modals.is_empty()
	var cer := false
	for h in _modals:
		if bool(h.get_meta("ceremony", false)):
			cer = true
	var page_a := 0.0 if (any and current == "play") else 1.0
	var nav_a := 0.0 if cer else 1.0
	for pair: Array in [[_page_host, page_a], [tab_bar, nav_a]]:
		var n := pair[0] as Control
		if n == null or not is_instance_valid(n):
			continue
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", float(pair[1]), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# An opaque full-screen modal (MachineDetail) covers the page: its 3D showcases stop
	# rendering until the modal closes (no second 3D pass under the detail).
	var covered := any and _modals.back().get_meta("content") is MachineDetail
	for p: Control in pages.values():
		_pause_showcases(p, covered)


func _pause_showcases(n: Node, paused: bool) -> void:
	for c in n.get_children():
		if c is HubShowcase:
			(c as HubShowcase).set_paused(paused)
		elif c is Control:
			_pause_showcases(c, paused)


## Closes the top modal (exit animation is the content's own: it may implement `play_exit()`
## returning a Tween). With `only` set, closes only when that holder is still the top one (a
## scrim tap never closes the modal underneath). A closing modal stops taking input at once.
func pop_modal(only: Control = null) -> void:
	if _modals.is_empty():
		return
	if only != null and _modals.back() != only:
		return
	# Double taps: a second tap within 250 ms of a close never closes the next modal down.
	if only != null and Time.get_ticks_msec() - _last_pop_ms < 250:
		return
	var top: Control = _modals.back()
	var top_c: Control = top.get_meta("content")
	# Closing an unlock card (Android back) still counts as seen: ack it through its own path.
	if top_c is UnlockCard and not bool(top_c.get_meta("acked", false)):
		top_c.set_meta("acked", true)
		(top_c as UnlockCard).done.emit()
		return
	var holder: Control = _modals.pop_back()
	_last_pop_ms = Time.get_ticks_msec()
	_page_tint()
	holder.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	(holder.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome_for_modals()
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


## Closes the modal whose content is `c`, only while it is the top one (close buttons).
func close_modal(c: Control) -> void:
	if _modals.is_empty() or _modals.back().get_meta("content") != c:
		return
	pop_modal(_modals.back())


func has_modal() -> bool:
	return not _modals.is_empty()


## The pages' content area in UI coordinates (between the bars).
func content_rect() -> Rect2:
	return _page_host.get_global_rect()


## Safe-area insets (left, top, right, bottom) in canvas px.
func insets() -> Vector4:
	return _insets


## The portrait tap menu: name, world, level, Heroes, Settings, language.
func open_profile() -> void:
	if has_modal():
		return
	var p := ProfileCard.new()
	p.setup(self)
	push_modal(p)


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
	push_modal(r, true, false, true)


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


## A short message chip under the top bar / world ribbon (UI v2, Genshin: cream-glass chip, ink
## text, an icon; soft in, hold, soft out), clear of PLAY and the nav. `color` is kept for old
## callers and ignored (text is always ink).
func toast(text: String, icon := "", _color := UIKit.GOLD_LIGHT) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = UIKit.toast(ui, text, icon, 1.8, _insets.y + UITokens.RIBBON_Y + 60.0)


# ------------------------------------------------------------------ unlock queue (§4.6)

func _show_pending_unlocks() -> void:
	if not is_inside_tree() or _unlock_shown:
		return
	# Let the coins from the result / altar land first: the card never sits under a reward fly.
	if RewardFly.layer(get_tree()).is_busy() or has_modal():
		get_tree().create_timer(0.3).timeout.connect(_show_pending_unlocks)
		return
	var list := Meta.pending_unlocks()
	# A feature the player already used needs no tutorial card: ack it quietly.
	while not list.is_empty() and _already_used(str(list[0].get("id", ""))):
		Meta.ack_unlock(str(list[0].get("id", "")))
		list = Meta.pending_unlocks()
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
	push_modal(card, true, true)


## True when the player already met the unlocked feature before its card could show (the
## altar after a boss cache was cracked on it).
func _already_used(id: String) -> bool:
	match id:
		"altar":
			return int((Meta.account.get("counters", {}) as Dictionary).get("caches_opened", 0)) > 0
	return false


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
		elif Time.get_ticks_msec() - _back_ms < 2000:
			get_tree().quit()
		else:
			_back_ms = Time.get_ticks_msec()
			toast(Loc.t("BACK_TO_QUIT"), "")


# ------------------------------------------------------------------ inner widgets

## Full-screen backdrop per tab. Play = clear (the 3D Home) with a whisper of slate under the
## top plates, a warm floor fade under the nav and soft light shafts from the sun side. The cream
## tabs (UI v3.1 §4.3 "frosted backdrop") = the blurred Home still (KitGlass) under the cream
## BACKDROP_VEIL, cross-faded in when the still is ready; the painted v2 looks (ivory gallery,
## parchment haze with a spotlight) remain only as the no-snapshot fallback.
class Backdrop extends Control:
	var _from := {}
	var _to := {}
	var _k := 1.0
	var _t := 0.0
	var _shafts: Shafts
	var _world: _WorldLayer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_to = _look("play")
		_from = _to
		# The frosted world sits BEHIND this control's own veil draw (show_behind_parent), drawn
		# through the frost's milk transform so the floor never reads as a dark blotch.
		_world = _WorldLayer.new()
		_world.show_behind_parent = true
		_world.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_world)
		_shafts = Shafts.new()
		_shafts.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_shafts)

	## v0/v1/v2 = the cream veil over the world (top / mid / bottom alpha; §1.2 BACKDROP_VEIL),
	## milk = how much of the frost's milk transform the world gets (1 = the modal frost recipe).
	## Arsenal / Heroes open the top band (veil 0.30, a lighter milk) so the islands and clouds
	## read through the glass above their sheets; Shop / Barracks keep a full milk and a denser
	## mid / low veil where their rows and notes sit (no "dirty window" floor).
	static func _look(tab: String) -> Dictionary:
		var sc := UITokens.SCRIM
		var v: Array = UITokens.BACKDROP_VEIL
		match tab:
			"play":
				return {"top": Color(sc.r, sc.g, sc.b, 0.16), "mid": Color(sc.r, sc.g, sc.b, 0.0), "bot": Color(0.55, 0.42, 0.3, 0.22),
						"spot": Color(1, 1, 1, 0.0), "spot_y": 0.3, "vig": 0.0, "shafts": 1.0, "world": 0.0,
						"v0": float(v[0]), "v1": float(v[1]), "v2": float(v[2]), "milk": 1.0}
			"arsenal":
				return {"top": Color("#F1ECE2"), "mid": Color("#E4DDD0"), "bot": Color("#CFC5B4"), "spot": Color(1.0, 0.99, 0.96, 0.75),
						"spot_y": 0.22, "vig": 0.16, "shafts": 0.0, "world": 1.0,
						"v0": 0.30, "v1": 0.40, "v2": float(v[2]), "milk": 0.45}
			"heroes":
				return {"top": Color("#F4ECDD"), "mid": UITokens.STAGE_TOP, "bot": UITokens.STAGE_BOTTOM, "spot": Color(1.0, 0.93, 0.78, 0.7),
						"spot_y": 0.2, "vig": 0.18, "shafts": 0.0, "world": 1.0,
						"v0": 0.30, "v1": 0.40, "v2": float(v[2]), "milk": 0.45}
			_:
				return {"top": Color("#F4ECDD"), "mid": UITokens.STAGE_TOP, "bot": UITokens.STAGE_BOTTOM, "spot": Color(1.0, 0.93, 0.78, 0.7),
						"spot_y": 0.2, "vig": 0.18, "shafts": 0.0, "world": 1.0,
						"v0": float(v[0]), "v1": 0.62, "v2": 0.70, "milk": 1.0}

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
		# UI v3 porcelain glass (§4.3 "frosted backdrop"): where 3D is off the backdrop is the
		# frosted world itself (the blurred Home still) under the cream BACKDROP_VEIL, so every
		# glass surface has a world behind; no spot, rays or vignette. Until the still exists the
		# tab draws flat cream, and the world cross-fades in over 180 ms (never a one-frame pop).
		var wk := float(L.get("world", 0.0))
		_world.alpha = 0.0
		if wk > 0.01 and KitGlass.attached():
			var wt := KitGlass.world_texture()
			var wa := KitGlass.world_alpha() if wt else 0.0
			_world.alpha = wk * wa
			_world.milk = float(L["milk"])
			_world.queue_redraw()
			var p0 := UITokens.PAPER_0
			var p1 := UITokens.PAPER_1
			# Flat cream before the still (opaque), the veil once it is in.
			var k := wk * wa
			top = top.lerp(Color(p0.r, p0.g, p0.b, lerpf(1.0, float(L["v0"]), k)), wk)
			mid = mid.lerp(Color(p0.r, p0.g, p0.b, lerpf(1.0, float(L["v1"]), k)), wk)
			bot = bot.lerp(Color(p1.r, p1.g, p1.b, lerpf(1.0, float(L["v2"]), k)), wk)
			L["spot"] = Color(1, 1, 1, 0.0)
			L["vig"] = 0.0
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


## The frosted world still behind the Backdrop's veil, through the frost's milk transform
## (§4.2: desat 0.45, contrast 0.55 toward 0.80, lift 0.14, warm), `milk` 0..1 of it. One quad.
class _WorldLayer extends Control:
	const MILK := """shader_type canvas_item;
uniform float milk = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 b = mix(c.rgb, vec3(l), 0.45);
	b = vec3(0.80) + (b - vec3(0.80)) * 0.55;
	b = b * 0.86 + 0.14;
	b *= vec3(1.0, 0.976, 0.93);
	COLOR = vec4(mix(c.rgb, b, milk), c.a) * COLOR;
}"""
	static var _shader: Shader
	var alpha := 0.0:
		set(v):
			if not is_equal_approx(v, alpha):
				alpha = v
				queue_redraw()
	var milk := 1.0:
		set(v):
			if not is_equal_approx(v, milk):
				milk = v
				(material as ShaderMaterial).set_shader_parameter("milk", v)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _shader == null:
			_shader = Shader.new()
			_shader.code = MILK
		var m := ShaderMaterial.new()
		m.shader = _shader
		material = m

	func _draw() -> void:
		var wt := KitGlass.world_texture()
		if wt and alpha > 0.0:
			draw_texture_rect(wt, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, alpha))


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
		# v3.1: a modal (frosted + text bed + top-corner flourishes; flat 0.97 without a still).
		UIKit.frost_into(self, "modal", Vector2(40, 34))
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		rays.color = Color(1.0, 0.82, 0.4, 0.5)
		rays.on_light = true
		halo.add_child(rays)
		var ic := Icons.make(_icon(), 128.0)
		ic.position = Vector2(220 - 64, 21)
		halo.add_child(ic)
		v.add_child(halo)
		var t := UIKit.gradient_heading(_title(), 46)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		# The real unlock path passes EconData.UNLOCKS "line" keys (UNL_*, all in Loc; test_loc
		# checks them). A key Loc does not know is never shown raw: the line is left out.
		var lk := str(entry.get("line", ""))
		var line := UIKit.label(Loc.t(lk) if Loc.STRINGS.has(lk) else "", 26, UIKit.INK)
		line.visible = line.text != ""
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(440, 0)
		v.add_child(line)
		var b := UIKit.button(Loc.t("NEXT"), true, 380.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): done.emit())
		v.add_child(b)
		await get_tree().process_frame
		pivot_offset = size * 0.5
		UIJuice.pop(self, 0.0, UITokens.SLOW)
		UIJuice.haptic("THUD", 0.8)
		Audio.play("weapon_get", -4.0)

	## "Відкрито: Вівтар" (the feature's name), or the plain "Відкрито!" when it has none.
	func _title() -> String:
		var id := str(entry.get("id", ""))
		var key := ""
		match id:
			"arsenal": key = "TAB_ARSENAL"
			"heroes": key = "TAB_HEROES"
			"barracks": key = "TAB_BARRACKS"
			_: key = "UNF_" + id.to_upper()
		if Loc.STRINGS.has(key) and Loc.STRINGS.has("UNLOCK_NAMED"):
			return Loc.f("UNLOCK_NAMED", [Loc.t(key)])
		return Loc.t("UNLOCK_TITLE")

	func _icon() -> String:
		match str(entry.get("id", "")):
			"arsenal": return "tab_arsenal"
			"heroes", "titan": return "tab_heroes"
			"barracks": return "tab_barracks"
			"deck": return "deck"
			"stone_cache": return "cache_stone"
			"altar": return "cache_world"
			"talents": return "laurel"
			"pairs": return "chest"
			"rank_gates": return "chevron"
			"drag": return "swipe"
			"migration": return "crown"
		return "crystal"
