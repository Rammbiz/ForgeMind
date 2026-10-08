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

const ROUTES := {
	"hall": {"script": "res://scripts/ui/heroes/hall/heroes_hall.gd", "host": "tab"},
	"hero": {"script": "res://scripts/ui/heroes/showcase/hero_showcase.gd", "host": "screen"},
	"champion": {"script": "res://scripts/ui/heroes/showcase/champion_showcase.gd", "host": "screen"},
	"manage": {"script": "res://scripts/ui/heroes/showcase/manage_sheet.gd", "host": "modal"},
	"recut": {"script": "res://scripts/ui/heroes/recut/recut_screen.gd", "host": "screen"},
	"team": {"script": "res://scripts/ui/heroes/team/team_screen.gd", "host": "page"},
	"portal": {"script": "res://scripts/ui/summon/portal_screen.gd", "host": "screen"},
	"odds": {"script": "res://scripts/ui/summon/odds_sheet.gd", "host": "modal"},
	"seals": {"script": "res://scripts/ui/summon/seal_shop.gd", "host": "modal"},
	"summon": {"script": "res://scripts/ui/summon/summon_ceremony.gd", "host": "ceremony"},
}
const LAYER_SCREEN := 4
const LAYER_CEREMONY := 6

static var _open: Array[Control] = []


## True when the route of `uri` has its screen script.
static func available(uri: String) -> bool:
	var r: Dictionary = ROUTES.get(uri.get_slice("/", 0), {})
	return not r.is_empty() and ResourceLoader.exists(str(r["script"]))


## Opens `uri` and returns the screen Control (a placeholder when the script is missing).
## `host_node` is used when there is no hub (standalone dev shots).
static func open(hub: Hub, uri: String, host_node: Node = null) -> Control:
	var parts := uri.split("/", false)
	if parts.is_empty():
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
	_attach(c, hub, host, host_node)
	if c.has_signal("closed"):
		c.connect("closed", func(): back(c))
	_open.append(c)
	return c


## Closes `c` (and its layer); safe to call twice.
static func back(c: Control) -> void:
	_open.erase(c)
	if not is_instance_valid(c):
		return
	var holder: Node = c.get_meta("heroes_holder") if c.has_meta("heroes_holder") else null
	var hub: Hub = c.get_meta("heroes_hub") if c.has_meta("heroes_hub") else null
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
		back(c)
	_open.clear()


## The topmost open screen (null when none).
static func top() -> Control:
	for i in range(_open.size() - 1, -1, -1):
		if is_instance_valid(_open[i]):
			return _open[i]
	return null


static func _attach(c: Control, hub: Hub, host: String, host_node: Node) -> void:
	c.set_meta("heroes_host", host)
	if hub:
		c.set_meta("heroes_hub", hub)
	if hub and host == "modal":
		hub.push_modal(c)
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
		var l := UIKit.label(HeroesText.t("UI_NOT_BUILT", [what]), 26, UITokens.INK_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var b := UIKit.button(HeroesText.t("UI_BACK"), false, 240)
		b.pressed.connect(func(): closed.emit())
		col.add_child(b)
