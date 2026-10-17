class_name HeroesHallStub
extends Control
## A minimal «Зала героїв» used by tab_heroes.gd until the Hall screen
## (res://scripts/ui/heroes/hall/heroes_hall.gd) exists: the title, Герої · Чемпіони and a grid of
## HeroCards from HeroesUIModel. Tapping a card opens its Showcase through HeroesNav. Kept tiny on
## purpose; the Hall screen replaces it completely (same contract: setup / refresh / on_show /
## show_sub).

var hub: Hub
var _sub := "heroes"
var _grid: GridContainer
var _title: Label
var _count: Label
var _seg: PanelContainer


func setup(p_hub: Hub, _args: PackedStringArray) -> void:
	hub = p_hub


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = UITokens.GUTTER
	col.offset_right = -UITokens.GUTTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	_title = UIKit.gradient_heading(HeroesText.t("HALL_TITLE"), 40)
	head.add_child(_title)
	_count = UIKit.label("", 24, UITokens.INK_DIM_GLASS, true)
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_count)
	var opts := [["heroes", HeroesText.t("HALL_TAB_HEROES")]]
	if bool(HeroesUIModel.unlocks()["champions"]):
		opts.append(["champions", HeroesText.t("HALL_TAB_CHAMPIONS")])
	_seg = UIKit.segmented(opts, _sub, show_sub)
	col.add_child(_seg)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 24)
	sc.add_child(pad)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", UITokens.GAP)
	_grid.add_theme_constant_override("v_separation", UITokens.GAP + 6)
	pad.add_child(_grid)
	UIKit.scroll_fade(sc)
	HeroesUIModel.bus().changed.connect(func(_w: String): refresh())
	refresh()


func show_sub(id: String) -> void:
	_sub = id
	refresh()


func on_show() -> void:
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	for ch in _grid.get_children():
		ch.queue_free()
	var rows: Array[Dictionary] = HeroesUIModel.heroes() if _sub == "heroes" else HeroesUIModel.champions()
	_grid.columns = 3 if _sub == "heroes" else 4
	var owned := 0
	var listed := 0
	var cards: Array = []
	for d in rows:
		if not bool(d["listed"]):
			continue
		listed += 1
		if bool(d["owned"]):
			owned += 1
		var c := HeroCard.make(d, "L" if _sub == "heroes" else "M")
		c.pressed.connect(_open)
		_grid.add_child(c)
		cards.append(c)
	_count.text = HeroesText.t("HALL_COUNT", [owned, rows.size()])


func _open(id: String) -> void:
	HeroesNav.open(hub, ("hero/" if HeroData.HEROES.has(id) else "champion/") + id)
