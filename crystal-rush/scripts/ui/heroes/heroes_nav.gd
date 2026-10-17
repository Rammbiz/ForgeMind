class_name HeroesNav
extends RefCounted
## The router of the Heroes meta UI (part U §1.3 URIs, the subset H3a builds). A screen is opened by
## URI; the first segment picks the route, the rest is passed to the screen as `args`:
##
##   HeroesNav.open(hub, "hero/vesta")            # Hero Showcase of Веста
##   HeroesNav.open(hub, "hero/vesta/manage")     # ... with the Manage sheet open
##   HeroesNav.open(hub, "portal")                # Portal
##   HeroesNav.open(hub, "summon/x10")            # the summon ceremony (runs HeroesUIModel.summon)
##   HeroesNav.back(screen)                       # closes `screen` (a screen may also emit `closed`)
##
## SCREEN CONTRACT (every script in ROUTES): `extends Control`, built in code, and
##   func setup(hub: Hub, args: PackedStringArray) -> void   # called before it enters the tree; hub may be null
##   signal closed                                           # optional: emit to close yourself
##   func gallery_seek(t: float) -> void                     # optional: jump a ceremony to t seconds (dev shots)
##   func refresh() -> void                                  # optional: called on HeroesUIModel changes
## Hosts: "tab" = the Heroes tab page (the Hall; tab_heroes.gd hosts it), "page" = the hub content
## area with the top bar and the nav visible (Team), "screen" = full screen over the hub chrome
## (Showcase, Portal, Recut), "modal" = Hub.push_modal (sheets), "ceremony" = full screen above
## everything, nav hidden (walkouts, x10 summary).
## A route whose script does not exist yet opens a quiet placeholder (never a crash).
## LOCKS (§9.2 "Locked routes return false and show the lock line"): a route before its unlock
## level does not open; open() returns null and shows a cream toast «Відкриється після рівня N».
## `force = true` skips the gate (the dev gallery shoots locked screens on purpose).
## MODALS over a full screen: a "modal" route opened while a "screen" / "ceremony" is up goes to
## HeroesNav's own modal layer (CanvasLayer LAYER_MODAL, above the screens) with its own scrim, so
## a sheet never opens behind the screen that asked for it (the hub's modal layer sits under the
## screen layer). From the Hall (no screen up) modals still use Hub.push_modal.

const ROUTES := {
	"hall": {"script": "res://scripts/ui/heroes/hall/heroes_hall.gd", "host": "tab"},
	"hero": {"script": "res://scripts/ui/heroes/showcase/hero_showcase.gd", "host": "screen"},
	"champion": {"script": "res://scripts/ui/heroes/champion/champion_showcase.gd", "host": "screen"},
	"manage": {"script": "res://scripts/ui/heroes/showcase/manage_sheet.gd", "host": "modal"},
	"recut": {"script": "res://scripts/ui/heroes/recut/recut_screen.gd", "host": "screen"},
	"team": {"script": "res://scripts/ui/heroes/team/team_screen.gd", "host": "screen"},
	"portal": {"script": "res://scripts/ui/summon/portal_screen.gd", "host": "screen"},
	"odds": {"script": "res://scripts/ui/summon/odds_sheet.gd", "host": "modal"},
	"seals": {"script": "res://scripts/ui/summon/seal_shop.gd", "host": "modal"},
	"summon": {"script": "res://scripts/ui/summon/summon_ceremony.gd", "host": "ceremony"},
	"codex": {"script": "res://scripts/ui/heroes/hall/codex_sheet.gd", "host": "modal"},
}
## Route -> HeroesUIModel.unlocks() key that gates it (levels in HeroData.UNLOCK_AT).
const LOCKS := {"team": "champions", "champion": "champions", "portal": "portal", "odds": "portal",
		"seals": "portal", "summon": "portal", "workshop": "workshop", "chronicle": "skills"}
const LAYER_SCREEN := 4
const LAYER_MODAL := 5
const LAYER_CEREMONY := 6

static var _open: Array[Control] = []


## True when the route of `uri` has its screen script.
static func available(uri: String) -> bool:
	var r: Dictionary = ROUTES.get(uri.get_slice("/", 0), {})
	return not r.is_empty() and ResourceLoader.exists(str(r["script"]))


## "" when `uri` may open now, else the lock line («Відкриється після рівня 20»).
static func locked_reason(uri: String) -> String:
	var key := uri.get_slice("/", 0)
	var gate := str(LOCKS.get(key, ""))
	if gate == "":
		return ""
	var un := HeroesUIModel.unlocks()
	if bool(un.get(gate, true)):
		return ""
	return HeroesText.t("UI_ROUTE_LOCKED", [int(HeroData.UNLOCK_AT.get(gate, 0))])


## Opens `uri` and returns the screen Control (a placeholder when the script is missing; null
## when the route is locked - a toast shows the lock line). `host_node` is used when there is no
## hub (standalone dev shots); `force` skips the level gate (dev gallery).
static func open(hub: Hub, uri: String, host_node: Node = null, force := false) -> Control:
	var parts := uri.split("/", false)
	if parts.is_empty():
		return null
	var why := "" if force else locked_reason(uri)
	if why != "":
		var th: Control = hub.ui if hub and hub.get("ui") is Control else (host_node as Control)
		if th:
			UIKit.toast(th, why, "lock")
		return null
	var key := parts[0]
	var args := parts.slice(1)
	var route: Dictionary = ROUTES.get(key, {})
	var c: Control
	if not route.is_empty() and ResourceLoader.exists(str(route["script"])):
		c = (load(str(route["script"])) as GDScript).new()
	else:
		c = _Placeholder.new()
		(c as _Placeholder).what = uri
	if c.has_method("setup"):
		c.call("setup", hub, args)
	var host := str(route.get("host", "screen"))
	# Registered before it enters the tree: a screen that opens a sheet in its own _ready()
	# already counts as "a screen is up" (the sheet then goes above it).
	c.set_meta("heroes_host", host)
	_open.append(c)
	_attach(c, hub, host, host_node)
	if c.has_signal("closed"):
		c.connect("closed", func(): back(c))
	return c


## Closes `c` (and its layer); safe to call twice. `animate = false` skips the exit motion of a
## sheet on HeroesNav's modal layer (close_all).
static func back(c: Control, animate := true) -> void:
	_open.erase(c)
	if not is_instance_valid(c):
		return
	var holder: Node = c.get_meta("heroes_holder") if c.has_meta("heroes_holder") else null
	var hub: Hub = c.get_meta("heroes_hub") if c.has_meta("heroes_hub") else null
	if bool(c.get_meta("heroes_layer_modal", false)):
		if c.get_meta("heroes_closing", false):
			return
		c.set_meta("heroes_closing", true)
		var tw: Tween = null
		if animate and not UITokens.reduce_motion() and c.has_method("play_exit"):
			tw = c.call("play_exit")
		var scrim: ColorRect = c.get_meta("heroes_scrim") if c.has_meta("heroes_scrim") else null
		if scrim and is_instance_valid(scrim):
			scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if tw:
				scrim.create_tween().tween_property(scrim, "color:a", 0.0, UITokens.MENU_OUT)
		if tw:
			tw.finished.connect(func():
				if holder and is_instance_valid(holder):
					holder.queue_free())
		elif holder and is_instance_valid(holder):
			holder.queue_free()
		return
	if hub and is_instance_valid(hub) and str(c.get_meta("heroes_host", "")) == "modal":
		hub.close_modal(c)
		return
	if holder and is_instance_valid(holder):
		holder.queue_free()
	else:
		c.queue_free()


## Closes every screen opened through HeroesNav.
static func close_all() -> void:
	for c in _open.duplicate():
		back(c, false)
	_open.clear()


## True when a "screen" / "ceremony" opened after the screen that holds `c` is still up (`c` is
## under it: animated backdrops stop redrawing).
static func covered(c: Node) -> bool:
	var mine := -1
	for i in _open.size():
		var o := _open[i]
		if is_instance_valid(o) and (o == c or o.is_ancestor_of(c)):
			mine = i
	if mine < 0:
		return false
	for j in range(mine + 1, _open.size()):
		var o2 := _open[j]
		if is_instance_valid(o2) and str(o2.get_meta("heroes_host", "")) in ["screen", "ceremony"]:
			return true
	return false


## The topmost open screen (null when none).
static func top() -> Control:
	for i in range(_open.size() - 1, -1, -1):
		if is_instance_valid(_open[i]):
			return _open[i]
	return null


## True while a full screen or a ceremony opened through HeroesNav is up.
static func screen_open(except: Control = null) -> bool:
	for o in _open:
		if o != except and is_instance_valid(o) and str(o.get_meta("heroes_host", "")) in ["screen", "ceremony"]:
			return true
	return false


static func _attach(c: Control, hub: Hub, host: String, host_node: Node) -> void:
	var over_screen := host == "modal" and (screen_open(c) or hub == null)
	c.set_meta("heroes_host", host)
	if hub:
		c.set_meta("heroes_hub", hub)
	if hub and host == "modal" and not over_screen:
		hub.push_modal(c)
		return
	if over_screen:
		_attach_modal_layer(c, hub, host_node)
		return
	if hub and host == "page":
		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var page_host: Control = hub.get("_page_host")
		holder.offset_top = page_host.offset_top
		holder.offset_bottom = page_host.offset_bottom
		holder.offset_left = page_host.offset_left
		holder.offset_right = page_host.offset_right
		hub.ui.add_child(holder)
		hub.ui.move_child(holder, page_host.get_index() + 1)
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(c)
		c.set_meta("heroes_holder", holder)
		return
	# "screen" / "ceremony" / "tab" without a hub: a CanvasLayer of its own.
	var layer := CanvasLayer.new()
	layer.layer = LAYER_CEREMONY if host == "ceremony" else LAYER_SCREEN
	var parent: Node = hub if hub else host_node
	if parent == null:
		parent = (Engine.get_main_loop() as SceneTree).current_scene
	parent.add_child(layer)
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	c.set_meta("heroes_holder", layer)


## A modal over a full screen: CanvasLayer LAYER_MODAL with a scrim (a HeroesBottomSheet draws
## its own, warm or slate); a tap on the scrim closes the sheet.
static func _attach_modal_layer(c: Control, hub: Hub, host_node: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER_MODAL
	var parent: Node = hub if hub else host_node
	if parent == null:
		parent = (Engine.get_main_loop() as SceneTree).current_scene
	parent.add_child(layer)
	var root := Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	c.set_meta("heroes_holder", layer)
	c.set_meta("heroes_layer_modal", true)
	if c is HeroesBottomSheet:
		(c as HeroesBottomSheet).own_scrim = true
	else:
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(UITokens.SCRIM.r, UITokens.SCRIM.g, UITokens.SCRIM.b, 0.0)
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(scrim)
		scrim.create_tween().tween_property(scrim, "color:a", 0.5, UITokens.MENU_IN)
		scrim.gui_input.connect(func(e: InputEvent):
			if UIJuice.is_tap(e):
				back(c))
		c.set_meta("heroes_scrim", scrim)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)


## Shown for a route whose screen is not built yet: a cream panel with the URI.
class _Placeholder extends Control:
	signal closed
	var what := ""

	func setup(_hub: Hub, _args: PackedStringArray) -> void:
		pass

	func _ready() -> void:
		var bg := ColorRect.new()
		bg.color = UITokens.PAPER_1
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(cc)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 18)
		cc.add_child(col)
		var l := UIKit.label(HeroesText.t("UI_NOT_BUILT", [what]), 26, UITokens.INK_DIM_GLASS)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var b := UIKit.button(HeroesText.t("UI_BACK"), false, 240)
		b.pressed.connect(func(): closed.emit())
		col.add_child(b)
