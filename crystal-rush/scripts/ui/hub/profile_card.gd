class_name ProfileCard
extends Control
## The portrait tap menu (UI v2, Genshin: the profile card behind the portrait, no gear beside
## it). A small cream card hangs under the top-left portrait: the portrait, the lead hero's name
## and title, the world and level with the world progress, then three quiet rows with line icons
## in thin gold rings: Герої (the hero screen), Налаштування (Settings) and Мова (switches the
## language in place). Tap outside or the row closes it; soft fade + 16 px drop.
##   hub.open_profile()

const TabPlay := preload("res://scripts/ui/hub/tab_play.gd")
const W := 456.0
const T := {
	"PROFILE_WORLD": ["Світ %d · %s", "World %d · %s"],
	"PROFILE_PROGRESS": ["Прогрес світу", "World progress"],
	"PROFILE_HEROES": ["Герої", "Heroes"],
}

var hub: Hub
var _card: PanelContainer


static func tr2(key: String) -> String:
	if Loc.STRINGS.has(key):
		return Loc.t(key)
	var row: Array = T.get(key, [key, key])
	return str(row[1] if Loc.lang == "en" else row[0])


func setup(p_hub: Hub, _a: Variant = null) -> void:
	hub = p_hub


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := hub.insets()
	_card = UIKit.panel("modal", Vector2(24, 20))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.position = Vector2(ins.x + 14.0, ins.y + 100.0)
	_card.custom_minimum_size = Vector2(W, 0)
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_card.add_child(col)
	# Header: portrait + name, title, world.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var hid := Meta.hero()
	var av := HubTopBar.Avatar.new()
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.custom_minimum_size = Vector2(88, 88)
	av.hero = hid
	av.tex = HubTopBar._portrait_cache.get(hid)
	var lv := Meta.level()
	av.level = lv
	av.progress = float(ArsenalData.level_in_world(lv) - 1) / float(ArsenalData.LEVELS_PER_WORLD)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(av)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var def: Dictionary = Balance.HEROES.get(hid, {})
	var nm := Loc.t(str(def.get("name", hid)))
	var name_l := UIKit.heading(nm, 32, UIKit.INK)
	nv.add_child(name_l)
	var w := ArsenalData.world_of(lv)
	var wl := UIKit.label(tr2("PROFILE_WORLD") % [w, TabPlay.world_name(w)], 20, UITokens.GOLD_TEXT, true)
	nv.add_child(wl)
	nv.add_child(UIKit.label(Loc.f("LEVEL", [lv]), 20, UITokens.INK_DIM))
	head.add_child(nv)
	col.add_child(head)
	# World progress (the amber arc of the portrait ring, spelled out).
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 12)
	var cap := UIKit.caps(tr2("PROFILE_PROGRESS"))
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(cap)
	var done := ArsenalData.level_in_world(lv) - 1
	pr.add_child(UIKit.label("%d / %d" % [done, ArsenalData.LEVELS_PER_WORLD], 20, UIKit.INK, true))
	col.add_child(pr)
	var bar := UIKit.progress(done, ArsenalData.LEVELS_PER_WORLD, W - 48.0, 12, ArsenalData.LEVELS_PER_WORLD)
	col.add_child(bar)
	var div := UIKit.divider(W - 60.0)
	div.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(div)
	# Rows.
	var heroes_locked := hub.tab_bar.is_locked("heroes")
	if not heroes_locked:
		col.add_child(_row("team", tr2("PROFILE_HEROES"), "", func():
			hub.pop_modal()
			hub.select_tab("heroes")))
	col.add_child(_row("settings", Loc.t("SETTINGS"), "", func():
		hub.pop_modal()
		hub.open_settings()))
	col.add_child(_row("globe", Loc.t("LANGUAGE"), Loc.t("LANG_NAME"), func():
		hub.pop_modal()
		Loc.set_language(Loc.next_language()), false))
	UIJuice.soft_in(_card, Vector2(0, -16))


func play_exit() -> Tween:
	return UIJuice.soft_out(_card, Vector2(0, -12))


## A quiet tappable row: cream socket + line icon, ink label, gold value, chevron; hairline under.
func _row(icon: String, text: String, value: String, act: Callable, line := true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var r := HBoxContainer.new()
	r.custom_minimum_size = Vector2(0, 68)
	r.add_theme_constant_override("separation", 14)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := UIKit.socket(icon, 46.0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)
	var l := UIKit.label(text, 24, UIKit.INK, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	r.add_child(l)
	if value != "":
		var vl := UIKit.label(value, 22, UITokens.GOLD_TEXT, true)
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vl.size_flags_vertical = Control.SIZE_FILL
		r.add_child(vl)
	var ch := Icons.make("chevron", 24.0, UITokens.GOLD_TEXT)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(ch)
	v.add_child(r)
	if line:
		v.add_child(UIKit.hairline())
	v.gui_input.connect(func(e: InputEvent):
		if UIJuice.is_tap(e):
			Audio.play("click", -8.0)
			UIJuice.haptic("CLICK", 0.5)
			act.call())
	return v
