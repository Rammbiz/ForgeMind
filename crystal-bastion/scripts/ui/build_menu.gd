class_name BuildMenu
extends Control
## Radial tower picker shown around an empty tile. Tap once to preview, again to build.

var hud: Hud
var game: Game
var cell := Vector2i.ZERO
var armed_type := ""
var _buttons := {}
var _anchor := Vector3.ZERO
var _tip: PanelContainer
var _tip_title: Label
var _tip_desc: Label
var _tip_stats: Label
const RADIUS_PX := 112.0


func open(p_hud: Hud, p_cell: Vector2i) -> void:
	hud = p_hud
	game = p_hud.game
	cell = p_cell
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor = game.map.cell_to_world(cell) + Vector3(0, 0.25, 0)
	for type: String in game.level["towers"]:
		var b := RoundButton.new(42.0)
		b.icon_texture = hud.tower_icon(type)
		b.icon_kind = "crystal"
		b.caption = str(game.tower_cost(type))
		b.caption_icon = "coin"
		b.ring_color = (GameData.TOWERS[type]["color"] as Color).lightened(0.2)
		b.pressed.connect(_on_pick.bind(type))
		add_child(b)
		_buttons[type] = b
		UIKit.pop_in(b, 0.03 * _buttons.size(), 0.25)
	_build_tip()
	game.show_cursor(cell)
	_layout()


func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.theme_type_variation = "TipPanel"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(v)
	_tip_title = UIKit.label("", 24, UIKit.GOLD, true)
	_tip_desc = UIKit.label("", 19, UIKit.TEXT_DIM)
	_tip_stats = UIKit.label("", 19, UIKit.TEXT)
	v.add_child(_tip_title)
	v.add_child(_tip_desc)
	v.add_child(_tip_stats)
	_tip.visible = false
	add_child(_tip)


func _process(_delta: float) -> void:
	if game == null:
		return
	for type: String in _buttons:
		var b: RoundButton = _buttons[type]
		var afford := game.gold >= game.tower_cost(type)
		b.disabled = not afford
		b.caption_color = UIKit.TEXT if afford else UIKit.RED
		b.armed = type == armed_type
	if armed_type != "":
		_update_tip_stats()
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var center := game.cam.world_to_screen(_anchor)
	var n := _buttons.size()
	var step := 54.0 if n > 3 else 60.0
	var offsets: Array[Vector2] = []
	for i in n:
		var a := deg_to_rad(-90.0 + (i - (n - 1) * 0.5) * step)
		offsets.append(Vector2(cos(a), sin(a)) * RADIUS_PX)
	# Keep the whole menu on screen.
	var min_c := Vector2(INF, INF)
	var max_c := Vector2(-INF, -INF)
	for o in offsets:
		min_c = min_c.min(o)
		max_c = max_c.max(o)
	var pad := Vector2(56, 56)
	center.x = clampf(center.x, -min_c.x + pad.x, vp.x - max_c.x - pad.x)
	center.y = clampf(center.y, -min_c.y + pad.y + 40.0, vp.y - max_c.y - pad.y - 30.0)
	var i := 0
	for type: String in _buttons:
		var b: RoundButton = _buttons[type]
		b.position = center + offsets[i] - Vector2(b.size.x * 0.5, b.radius + 4.0)
		i += 1
	if _tip.visible:
		_tip.reset_size()
		# Below the lowest button's price pill, or above the whole menu if there is no room.
		var tp := center + Vector2(-_tip.size.x * 0.5, max_c.y + 42.0 + 40.0)
		if tp.y + _tip.size.y > vp.y - 8.0:
			tp.y = center.y + min_c.y - 50.0 - _tip.size.y
		tp.x = clampf(tp.x, 8.0, vp.x - _tip.size.x - 8.0)
		tp.y = clampf(tp.y, 8.0, vp.y - _tip.size.y - 8.0)
		_tip.position = tp


func _on_pick(type: String) -> void:
	if armed_type == type:
		if game.gold < game.tower_cost(type):
			Audio.play("error")
			hud.toast(Loc.t("NOT_ENOUGH_GOLD"))
			return
		var t := game.build_tower(cell, type)
		if t:
			hud.close_menus()
		return
	Audio.play("click", -4.0)
	armed_type = type
	var stats := GameData.tower_stats(type, 0)
	game.show_ghost(cell, type)
	game.show_range(game.map.cell_to_world(cell), float(stats["range"]), (GameData.TOWERS[type]["color"] as Color).lightened(0.3))
	_tip_title.text = Loc.t(GameData.TOWERS[type]["name"])
	var desc := Loc.t(GameData.TOWERS[type]["desc"])
	_tip_desc.text = desc
	_update_tip_stats()
	_tip.visible = true
	_tip.reset_size()
	if game.gold < game.tower_cost(type):
		Audio.play("error")


func _update_tip_stats() -> void:
	var afford := game.gold >= game.tower_cost(armed_type)
	var text := Hud.stats_line(armed_type, 0) + "   •   " + (Loc.t("TAP_AGAIN") if afford else Loc.t("NOT_ENOUGH_GOLD"))
	if _tip_stats.text != text:
		_tip_stats.text = text


func close() -> void:
	if game:
		game.clear_selection()
	queue_free()
