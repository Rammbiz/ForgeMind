class_name TowerPanel
extends Control
## Radial actions around a built tower: upgrade, sell, targeting mode.

var hud: Hud
var game: Game
var tower: Tower
var armed := ""
var _upgrade: RoundButton
var _sell: RoundButton
var _target: RoundButton
var _tip: PanelContainer
var _tip_title: Label
var _tip_stats: Label
var _tip_extra: Label
const RADIUS_PX := 104.0
const MODE_KEYS := ["TARGET_FIRST", "TARGET_STRONG", "TARGET_CLOSE"]


func open(p_hud: Hud, p_tower: Tower) -> void:
	hud = p_hud
	game = p_hud.game
	tower = p_tower
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade = RoundButton.new(40.0)
	_upgrade.icon_kind = "up"
	_upgrade.icon_tint = UIKit.GREEN
	_upgrade.caption_icon = "coin"
	_upgrade.pressed.connect(_on_upgrade)
	add_child(_upgrade)
	_sell = RoundButton.new(34.0)
	_sell.icon_kind = "coin"
	_sell.caption_icon = "coin"
	_sell.ring_color = Color(1.0, 0.6, 0.4)
	_sell.pressed.connect(_on_sell)
	add_child(_sell)
	_target = RoundButton.new(34.0)
	_target.icon_kind = "target"
	_target.ring_color = Color(0.6, 0.85, 1.0)
	_target.pressed.connect(_on_target)
	add_child(_target)
	for b in [_upgrade, _sell, _target]:
		UIKit.pop_in(b, 0.0, 0.25)
	_tip = PanelContainer.new()
	_tip.theme_type_variation = "TipPanel"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_tip.add_child(v)
	_tip_title = UIKit.label("", 24, UIKit.GOLD, true)
	_tip_stats = UIKit.label("", 19, UIKit.TEXT)
	_tip_extra = UIKit.label("", 18, UIKit.TEXT_DIM)
	v.add_child(_tip_title)
	v.add_child(_tip_stats)
	v.add_child(_tip_extra)
	add_child(_tip)
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(tower):
		return
	var max_lvl := not tower.can_upgrade()
	_upgrade.caption = Loc.t("MAX") if max_lvl else str(tower.upgrade_cost())
	_upgrade.caption_icon = "" if max_lvl else "coin"
	_upgrade.disabled = max_lvl or game.gold < tower.upgrade_cost()
	_upgrade.caption_color = UIKit.GOLD if max_lvl else (UIKit.TEXT if game.gold >= tower.upgrade_cost() else UIKit.RED)
	_upgrade.armed = armed == "upgrade"
	_sell.caption = "+" + str(tower.sell_value())
	_sell.armed = armed == "sell"
	_target.caption = Loc.t(MODE_KEYS[int(tower.target_mode)])
	var tname := Loc.t(tower.def["name"])
	_tip_title.text = "%s  •  %s" % [tname, Loc.f("LEVEL_SHORT", [tower.level + 1])]
	if armed == "upgrade" and tower.can_upgrade():
		_tip_stats.text = Hud.stats_line(tower.type, tower.level + 1)
		_tip_stats.add_theme_color_override("font_color", UIKit.GREEN)
		_tip_extra.text = Loc.t("TAP_AGAIN")
	else:
		_tip_stats.text = Hud.stats_line(tower.type, tower.level)
		_tip_stats.add_theme_color_override("font_color", UIKit.TEXT)
		var extra := ""
		if not tower.def["air"]:
			extra = Loc.t("NO_AIR")
		if armed == "sell":
			extra = Loc.t("TAP_AGAIN")
		_tip_extra.text = extra
	_tip_extra.visible = _tip_extra.text != ""
	var r := tower.range_radius()
	if armed == "upgrade" and tower.can_upgrade():
		r = float(GameData.tower_stats(tower.type, tower.level + 1)["range"])
	game.show_range(tower.global_position, r, (tower.def["color"] as Color).lightened(0.3))
	game.show_cursor(tower.cell)


func _process(_delta: float) -> void:
	if not is_instance_valid(tower):
		hud.close_menus()
		return
	_refresh()
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var center := game.cam.world_to_screen(tower.global_position + Vector3(0, 0.5, 0))
	var pad := RADIUS_PX + 56.0
	center.x = clampf(center.x, pad, vp.x - pad)
	center.y = clampf(center.y, pad + 20.0, vp.y - pad + 10.0)
	_place(_upgrade, center + Vector2(0, -RADIUS_PX))
	_place(_sell, center + Vector2(cos(deg_to_rad(35.0)), sin(deg_to_rad(35.0))) * RADIUS_PX)
	_place(_target, center + Vector2(cos(deg_to_rad(145.0)), sin(deg_to_rad(145.0))) * RADIUS_PX)
	_tip.reset_size()
	var tp := center + Vector2(RADIUS_PX + 40.0, -_tip.size.y * 0.5 - 30.0)
	if tp.x + _tip.size.x > vp.x - 8.0:
		tp.x = center.x - RADIUS_PX - 40.0 - _tip.size.x
	tp.x = clampf(tp.x, 8.0, vp.x - _tip.size.x - 8.0)
	tp.y = clampf(tp.y, 70.0, vp.y - _tip.size.y - 8.0)
	_tip.position = tp


func _place(b: RoundButton, at: Vector2) -> void:
	b.position = at - Vector2(b.size.x * 0.5, b.radius + 4.0)


func _on_upgrade() -> void:
	if not tower.can_upgrade():
		Audio.play("error")
		return
	if armed != "upgrade":
		armed = "upgrade"
		Audio.play("click", -4.0)
		if game.gold < tower.upgrade_cost():
			hud.toast(Loc.t("NOT_ENOUGH_GOLD"))
		return
	if game.upgrade_tower(tower):
		armed = ""
	else:
		hud.toast(Loc.t("NOT_ENOUGH_GOLD"))


func _on_sell() -> void:
	if armed != "sell":
		armed = "sell"
		Audio.play("click", -4.0)
		return
	game.sell_tower(tower)
	hud.close_menus()


func _on_target() -> void:
	armed = ""
	tower.cycle_target_mode()
	Audio.play("click", -4.0)


func close() -> void:
	if game:
		game.clear_selection()
	queue_free()
