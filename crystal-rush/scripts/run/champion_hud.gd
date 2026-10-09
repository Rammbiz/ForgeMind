class_name ChampionHud
extends Node
## The champions' part of the run HUD (heroes design §10.5): the medallions (HP ring, action
## glyph, gem pip) stacked above the ult button and the start banner with the team's synergy
## icons, both built by the HUD workstream (ChampionMedallions, TeamBanner) and driven from here:
## setup at the start, place() after every layout, refresh() every frame, the rules' champ_* fx,
## the avoid rects (the next gate row's and the hostiles' labels on screen, so a medallion over a
## label fades), and the banner while the run waits at READY. Everything is mouse-transparent and
## lives on HudView.champion_layer().
##
## The run's HUD is found through the play holder (main.make_play sets its "hud" meta); without
## one (galleries, benches) nothing is built. The two HUD classes are looked up by name in the
## global class list, so the run works headless before (and without) them.

const MEDALLIONS_CLASS := "ChampionMedallions"
const BANNER_CLASS := "TeamBanner"
const BANNER_S := 1.2
## Labels farther ahead than this never sit near the bottom-right medallions.
const AVOID_REACH := 34.0
## Frames to wait for the HUD to be built before giving up (no HUD in this scene).
const LINK_FRAMES := 30

## Tests and dev tools only: class name -> Script used instead of the global class (stand-ins).
static var override_classes := {}

var run: Run
var members: Array = []
var medallions: Control
var banner: Control
var _view: HudView
var _linked := false
var _frames := 0
var _banner_shown := false
var _items: Array = []
var _rects: Array = []
var _can_avoid := false
var _can_fx := false


func setup(p_run: Run) -> void:
	run = p_run
	members = run.champions.members


func _process(_delta: float) -> void:
	if not _linked:
		if _frames > LINK_FRAMES:
			return
		_frames += 1
		_link()
		if not _linked:
			return
	if medallions:
		medallions.call("refresh", members)
		if _can_avoid:
			_avoid()


## The rules' champ_* events (champ_hit, champ_down, champ_revive, champ_block, champ_mend,
## champ_heal, champ_leap, champ_shot, champ_spell).
func on_fx(event: StringName, data: Dictionary) -> void:
	if medallions and _can_fx:
		medallions.call("on_fx", event, data)


func _link() -> void:
	var holder := run.get_parent()
	if holder == null or not holder.has_meta("hud"):
		return
	var hud: Variant = holder.get_meta("hud")
	if not hud is Object or not is_instance_valid(hud):
		return
	var v: Variant = (hud as Object).get("view")
	if not v is HudView or not (v as HudView).is_node_ready():
		return
	_view = v
	_linked = true
	var layer := _view.champion_layer()
	medallions = _make(MEDALLIONS_CLASS, ["setup", "refresh", "place"])
	if medallions:
		medallions.name = "Medallions"
		layer.add_child(medallions)
		_can_avoid = medallions.has_method("set_avoid_rects")
		_can_fx = medallions.has_method("on_fx")
		medallions.call("setup", members)
		_place()
		get_viewport().size_changed.connect(_place)
	banner = _make(BANNER_CLASS, ["show_team"])
	if banner:
		banner.name = "TeamBanner"
		layer.add_child(banner)
		if run.state == Run.State.READY and not _banner_shown:
			_banner_shown = true
			var team: Dictionary = run.profile.get("team", {}) if run.profile.get("team") is Dictionary else {}
			var syn: Array = team.get("synergy_ids", []) if team.get("synergy_ids") is Array else []
			banner.call("show_team", members, syn, BANNER_S)


## Stacks the medallions above the ult button (HudView coordinates).
func _place() -> void:
	if medallions and is_instance_valid(_view):
		medallions.call("place", _view.ult_rect())


## Screen rects of the next gate row's labels and of the hostiles' counters ahead.
func _avoid() -> void:
	run.hud_label_items(AVOID_REACH, _items)
	_rects.clear()
	var cam := run.cam
	if cam == null:
		medallions.call("set_avoid_rects", _rects)
		return
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	for it: Dictionary in _items:
		var l: Variant = it.get("label")
		if not l is Label3D or not is_instance_valid(l) or not (l as Label3D).is_visible_in_tree():
			continue
		var p := (l as Label3D).global_position
		if cam.is_position_behind(p):
			continue
		var hw := float(it.get("w", 2.0)) * 0.5 if str(it["kind"]) == "gate" else 0.55
		var c := cam.unproject_position(p)
		var e := cam.unproject_position(p + right * hw + up * 0.42)
		var half := (e - c).abs()
		_rects.append(Rect2(c - half, half * 2.0))
	medallions.call("set_avoid_rects", _rects)


## A new instance of the global script class `cls` (a Control with every method in `needs`), or
## null when it does not exist.
static func _make(cls: String, needs: Array) -> Control:
	if override_classes.has(cls):
		return _instance(override_classes[cls] as Script, needs)
	for row: Dictionary in ProjectSettings.get_global_class_list():
		if str(row.get("class", "")) != cls:
			continue
		return _instance(load(str(row.get("path", ""))) as Script, needs)
	return null


static func _instance(scr: Script, needs: Array) -> Control:
	if scr == null or not scr.can_instantiate():
		return null
	var o: Object = scr.call("new")
	var ok := o is Control
	for f: String in needs:
		ok = ok and o.has_method(f)
	if ok:
		(o as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return o as Control
	if o is Node:
		(o as Node).queue_free()
	return null
