class_name PreviewLauncher
extends Control
## The preview build's home (Preview, main.show_preview): one porcelain sheet to pick the run's hero (the
## 12 of HeroData.HEROES), up to 4 champions (ChampionData.CHAMPIONS; team order = tap order, the rules
## seat them by class) and the level, then «Грати» (signal play). The picks live for the session (static),
## so every way back from a run lands on the same choice. A character with a Meshy art model
## (assets/heroes/<id>/model.glb) is marked «3D».

signal play(hero: String, team: Array, level: int)

const LEVEL_MAX := 120
const TEAM_MAX := 4
const COLS := 3
## A picked chip: ink with a 1 px gold line and warm white text (an unpicked one stays cream).
const PICKED_BG := Color("#2B3550")
const PICKED_TEXT := Color("#F7F1E6")

static var pick_hero := "olha"
static var pick_team: Array = ["taras", "mila", "borko", "alba"]
static var pick_level := 41

var _hero_buttons := {}
var _champ_buttons := {}
var _level_label: Label
var _team_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.0627451, 0.0784314, 0.137255)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var ins := UIKit.safe_insets(get_viewport())
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = ins.y + 24.0
	sc.offset_bottom = -ins.w - 24.0
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	var sheet := UIKit.panel("panel", Vector2(28, 28))
	sheet.custom_minimum_size = Vector2(664, 0)
	center.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	sheet.add_child(col)

	var title := UIKit.heading("Пробна збірка", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var note := UIKit.label("Герої й чемпіони в забігу. Нічого не зберігається.", 22, UIKit.INK_DIM_GLASS)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)

	col.add_child(UIKit.section("Герой"))
	var hg := _grid()
	col.add_child(hg)
	for id: String in HeroData.HEROES:
		var b := _chip(HeroesText.hero_name(id), id)
		b.pressed.connect(_on_hero.bind(id))
		hg.add_child(b)
		_hero_buttons[id] = b

	_team_label = UIKit.section("")
	col.add_child(_team_label)
	var cg := _grid()
	col.add_child(cg)
	for id: String in ChampionData.CHAMPIONS:
		var b := _chip(HeroesText.champ_name(id), id)
		b.pressed.connect(_on_champ.bind(id))
		cg.add_child(b)
		_champ_buttons[id] = b

	col.add_child(UIKit.section("Рівень"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for d: int in [-10, -1]:
		row.add_child(_step_button(d))
	_level_label = UIKit.number("", 52)
	_level_label.custom_minimum_size = Vector2(130, 0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_level_label)
	for d2: int in [1, 10]:
		row.add_child(_step_button(d2))

	col.add_child(UIKit.gap(10))
	var go := UIKit.cta_button("Грати", "", Vector2(448, 104), 40)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): play.emit(pick_hero, pick_team.duplicate(), pick_level))
	col.add_child(go)
	_refresh()


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLS
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


## A toggle chip: the character's name, «3D» when it has an art model.
func _chip(name_text: String, id: String) -> Button:
	var has_3d := ResourceLoader.exists("res://assets/heroes/%s/model.glb" % id)
	var b := UIKit.styled_button(name_text + ("  3D" if has_3d else ""), "button", Vector2(196, 64), 22)
	b.toggle_mode = true
	b.clip_text = true
	var picked := UIKit.cbox(PICKED_BG, 10, UIKit.GOLD, 1)
	for st: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, picked)
	for k: String in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, PICKED_TEXT)
	return b


func _step_button(d: int) -> Button:
	var b := UIKit.styled_button(("%+d" % d), "button", Vector2(96, 64), 24)
	b.pressed.connect(func():
		pick_level = clampi(pick_level + d, 1, LEVEL_MAX)
		_refresh())
	return b


func _on_hero(id: String) -> void:
	pick_hero = id
	_refresh()


func _on_champ(id: String) -> void:
	if pick_team.has(id):
		pick_team.erase(id)
	elif pick_team.size() < TEAM_MAX:
		pick_team.append(id)
	_refresh()


func _refresh() -> void:
	for id: String in _hero_buttons:
		(_hero_buttons[id] as Button).set_pressed_no_signal(id == pick_hero)
	for id2: String in _champ_buttons:
		(_champ_buttons[id2] as Button).set_pressed_no_signal(pick_team.has(id2))
	_team_label.text = ("Чемпіони · %d з %d" % [pick_team.size(), TEAM_MAX]).to_upper()
	_level_label.text = str(pick_level)
